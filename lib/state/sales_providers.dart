import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/id_generator.dart';
import '../data/models/batch.dart';
import '../data/models/customer.dart';
import '../data/models/sale.dart';
import 'core_providers.dart';
import 'inventory_providers.dart';

/// One line in the POS cart (ephemeral, not persisted).
class CartItem {
  final String medicineId;
  final String medicineName;
  final String unit;
  final String packName;
  final int unitsPerPack;
  final String batchId;
  final String batchNumber;
  final int expiryDate; // ms
  final int availableQty;
  final int quantity;
  final double unitPrice;
  final double purchasePrice; // Cost per base unit
  final double lineDiscount; // absolute

  const CartItem({
    required this.medicineId,
    required this.medicineName,
    required this.unit,
    this.packName = 'Box',
    this.unitsPerPack = 1,
    required this.batchId,
    required this.batchNumber,
    required this.expiryDate,
    required this.availableQty,
    required this.quantity,
    required this.unitPrice,
    this.purchasePrice = 0,
    this.lineDiscount = 0,
  });

  double get lineTotal => quantity * unitPrice - lineDiscount;

  CartItem copyWith({
    int? quantity,
    double? unitPrice,
    double? purchasePrice,
    double? lineDiscount,
  }) =>
      CartItem(
        medicineId: medicineId,
        medicineName: medicineName,
        unit: unit,
        packName: packName,
        unitsPerPack: unitsPerPack,
        batchId: batchId,
        batchNumber: batchNumber,
        expiryDate: expiryDate,
        availableQty: availableQty,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
        purchasePrice: purchasePrice ?? this.purchasePrice,
        lineDiscount: lineDiscount ?? this.lineDiscount,
      );
}

/// Full POS session: cart + invoice-level meta.
class PosSession {
  final List<CartItem> items;
  final String customerId;
  final String customerName;
  final double discount; // invoice-level
  final double taxRate; // percentage
  final String paymentMethod;
  final double paidAmount;
  final String notes;

  const PosSession({
    this.items = const [],
    this.customerId = Customer.walkInId,
    this.customerName = 'Walk-in Customer',
    this.discount = 0,
    this.taxRate = 0,
    this.paymentMethod = 'Cash',
    this.paidAmount = 0,
    this.notes = '',
  });

  double get subtotal => items.fold(0.0, (s, i) => s + i.lineTotal);
  double get taxableBase => subtotal - discount;
  double get taxAmount => taxableBase * taxRate / 100;
  double get total => taxableBase + taxAmount;
  double get balance => total - paidAmount;
  bool get isEmpty => items.isEmpty;

  PosSession copyWith({
    List<CartItem>? items,
    String? customerId,
    String? customerName,
    double? discount,
    double? taxRate,
    String? paymentMethod,
    double? paidAmount,
    String? notes,
  }) =>
      PosSession(
        items: items ?? this.items,
        customerId: customerId ?? this.customerId,
        customerName: customerName ?? this.customerName,
        discount: discount ?? this.discount,
        taxRate: taxRate ?? this.taxRate,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        paidAmount: paidAmount ?? this.paidAmount,
        notes: notes ?? this.notes,
      );
}

class SalesNotifier extends Notifier<List<Sale>> {
  @override
  List<Sale> build() => ref.read(databaseProvider).getSales();

  Future<void> remove(String id, {bool restoreStock = true}) async {
    final db = ref.read(databaseProvider);
    final sale = state.where((s) => s.id == id).firstOrNull;
    if (sale != null && restoreStock && !sale.isReturned) {
      for (final item in sale.items) {
        final unreturned = item.quantity - item.returnedQuantity;
        if (unreturned > 0) {
          final batch = db.getBatch(item.batchId);
          if (batch != null) {
            await db.saveBatch(
                batch.copyWith(quantity: batch.quantity + unreturned));
          }
        }
      }
      ref.read(batchesProvider.notifier).reload();
    }
    await db.deleteSale(id);
    state = state.where((s) => s.id != id).toList();
  }

  /// Returns/refunds an entire sale, restores batch stock and marks returned.
  Future<void> returnSale(String saleId) async {
    final db = ref.read(databaseProvider);
    final sale = state.where((s) => s.id == saleId).firstOrNull;
    if (sale == null || sale.isReturned) return;

    for (final item in sale.items) {
      final unreturned = item.quantity - item.returnedQuantity;
      if (unreturned > 0) {
        final batch = db.getBatch(item.batchId);
        if (batch != null) {
          await db.saveBatch(
              batch.copyWith(quantity: batch.quantity + unreturned));
        }
      }
    }

    final updatedItems = sale.items
        .map((i) => i.copyWith(returnedQuantity: i.quantity))
        .toList();
    final updated = sale.copyWith(
      items: updatedItems,
      isReturned: true,
      notes: '${sale.notes} [RETURNED & STOCK RESTORED]'.trim(),
    );
    await db.saveSale(updated);
    state = state.map((s) => s.id == saleId ? updated : s).toList();
    ref.read(batchesProvider.notifier).reload();
  }

  void reload() {
    state = ref.read(databaseProvider).getSales();
  }
}

final salesProvider =
    NotifierProvider<SalesNotifier, List<Sale>>(SalesNotifier.new);

// ---------------------------------------------------------------------------
// Held Carts (Park Sale)
// ---------------------------------------------------------------------------

class HeldCart {
  final String id;
  final String label;
  final PosSession session;
  final int createdAt;

  const HeldCart({
    required this.id,
    required this.label,
    required this.session,
    required this.createdAt,
  });
}

class HeldCartsNotifier extends Notifier<List<HeldCart>> {
  @override
  List<HeldCart> build() => [];

  void hold(PosSession session) {
    if (session.isEmpty) return;
    final id = IdGenerator.generate('held');
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final label = session.customerName != 'Walk-in Customer'
        ? '${session.customerName} ($timeStr)'
        : 'Cart ${state.length + 1} ($timeStr • ${session.items.length} items)';
    state = [
      ...state,
      HeldCart(
        id: id,
        label: label,
        session: session,
        createdAt: now.millisecondsSinceEpoch,
      ),
    ];
  }

  PosSession? recall(String id) {
    final cart = state.where((c) => c.id == id).firstOrNull;
    if (cart != null) {
      state = state.where((c) => c.id != id).toList();
      return cart.session;
    }
    return null;
  }

  void remove(String id) {
    state = state.where((c) => c.id != id).toList();
  }
}

final heldCartsProvider =
    NotifierProvider<HeldCartsNotifier, List<HeldCart>>(HeldCartsNotifier.new);

/// Holds the current POS session (cart + meta) and performs checkout.
class PosCartNotifier extends Notifier<PosSession> {
  @override
  PosSession build() => const PosSession();

  void addItem(CartItem item) {
    // merge into an existing line with the same batch
    final existingIndex =
        state.items.indexWhere((i) => i.batchId == item.batchId);
    if (existingIndex != -1) {
      final existing = state.items[existingIndex];
      final merged = existing.copyWith(
        quantity: existing.quantity + item.quantity,
        unitPrice: item.unitPrice != 0 ? item.unitPrice : existing.unitPrice,
      );
      final items = [...state.items];
      items[existingIndex] = merged;
      state = state.copyWith(items: items);
    } else {
      state = state.copyWith(items: [...state.items, item]);
    }
  }

  void updateLine(int index, CartItem item) {
    final items = [...state.items];
    items[index] = item;
    state = state.copyWith(items: items);
  }

  void removeLine(int index) {
    final items = [...state.items]..removeAt(index);
    state = state.copyWith(items: items);
  }

  void setCustomer(String id, String name) {
    state = state.copyWith(customerId: id, customerName: name);
  }

  void setDiscount(double value) => state = state.copyWith(discount: value);
  void setTaxRate(double value) => state = state.copyWith(taxRate: value);
  void setPaymentMethod(String method) =>
      state = state.copyWith(paymentMethod: method);
  void setPaid(double value) => state = state.copyWith(paidAmount: value);
  void setNotes(String value) => state = state.copyWith(notes: value);

  void clear() => state = const PosSession();
  void loadSession(PosSession session) => state = session;

  /// Finalises the sale: decrements batch stock, persists the sale, advances
  /// the invoice counter and reloads dependent providers. Returns the sale.
  /// Throws if the cart is empty or a line exceeds available stock.
  Future<Sale> checkout() async {
    final session = state;
    if (session.isEmpty) {
      throw StateError('Cart is empty');
    }
    final db = ref.read(databaseProvider);

    // validate stock
    for (final item in session.items) {
      final batch = db.getBatch(item.batchId);
      if (batch == null || batch.quantity < item.quantity) {
        throw StateError(
            'Not enough stock for ${item.medicineName} (batch ${item.batchNumber})');
      }
    }

    // decrement batches
    for (final item in session.items) {
      final batch = db.getBatch(item.batchId)!;
      await db.saveBatch(batch.copyWith(quantity: batch.quantity - item.quantity));
    }

    // build sale
    final settings = ref.read(settingsProvider);
    final invoiceNo =
        'INV-${settings.nextInvoiceNumber.toString().padLeft(6, '0')}';
    final now = DateTime.now().millisecondsSinceEpoch;

    final sale = Sale(
      id: IdGenerator.generate('sale'),
      invoiceNumber: invoiceNo,
      dateTime: now,
      customerId: session.customerId,
      customerName: session.customerName,
      items: session.items
          .map((i) => SaleItem(
                medicineId: i.medicineId,
                medicineName: i.medicineName,
                batchId: i.batchId,
                batchNumber: i.batchNumber,
                quantity: i.quantity,
                unitsPerPack: i.unitsPerPack,
                packName: i.packName,
                unit: i.unit,
                unitPrice: i.unitPrice,
                purchasePrice: i.purchasePrice,
                lineDiscount: i.lineDiscount,
                expiryDate: i.expiryDate,
              ))
          .toList(),
      subtotal: session.subtotal,
      discount: session.discount,
      taxRate: session.taxRate,
      taxAmount: session.taxAmount,
      total: session.total,
      // If paymentMethod is 'Credit' OR user explicitly typed a partial
      // amount, record exactly what was paid (even 0). Only default to
      // full payment when the field was never touched (paidAmount == 0
      // AND method is NOT credit).
      paid: (session.paymentMethod == 'Credit')
          ? session.paidAmount  // respect partial / zero explicitly
          : (session.paidAmount <= 0 ? session.total : session.paidAmount),
      paymentMethod: session.paymentMethod,
      notes: session.notes,
    );

    await db.saveSale(sale);
    await ref
        .read(settingsProvider.notifier)
        .update(settings.copyWith(nextInvoiceNumber: settings.nextInvoiceNumber + 1));

    ref.read(salesProvider.notifier).reload();
    ref.read(batchesProvider.notifier).reload();
    clear();
    return sale;
  }
}

final posCartProvider =
    NotifierProvider<PosCartNotifier, PosSession>(PosCartNotifier.new);

/// Picks the best available batch (earliest non-expired with stock) for a
/// medicine, useful for auto-adding from the barcode field.
Batch? bestBatchForSale(WidgetRef ref, String medicineId) {
  final batches = ref.read(batchesProvider)
      .where((b) => b.medicineId == medicineId && b.quantity > 0);
  final now = DateTime.now().millisecondsSinceEpoch;
  final valid =
      batches.where((b) => b.expiryDate > now).toList()
        ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
  return valid.isEmpty ? null : valid.first;
}
