import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/id_generator.dart';
import '../data/database/local_database.dart';
import '../data/models/batch.dart';
import '../data/models/purchase.dart';
import 'catalog_providers.dart';
import 'core_providers.dart';
import 'inventory_providers.dart';

/// One line being composed in the purchase form. Ephemeral — not persisted.
class PurchaseDraftItem {
  final String medicineId;
  final String medicineName;
  final String batchNumber;
  final int quantity;
  final int packQty;
  final int unitsPerPack;
  final String packName;
  final String unit;
  final double purchasePrice;
  final double packPurchasePrice;
  final double salePrice;
  final int expiryDate; // ms

  const PurchaseDraftItem({
    required this.medicineId,
    required this.medicineName,
    required this.batchNumber,
    required this.quantity,
    this.packQty = 0,
    this.unitsPerPack = 1,
    this.packName = 'Box',
    this.unit = 'Tab',
    required this.purchasePrice,
    this.packPurchasePrice = 0,
    required this.salePrice,
    required this.expiryDate,
  });

  double get lineTotal => packQty > 0 && packPurchasePrice > 0
      ? packQty * packPurchasePrice
      : quantity * purchasePrice;

  PurchaseItem toPurchaseItem() => PurchaseItem(
        medicineId: medicineId,
        medicineName: medicineName,
        batchNumber: batchNumber,
        quantity: quantity,
        packQty: packQty,
        unitsPerPack: unitsPerPack,
        packName: packName,
        unit: unit,
        purchasePrice: purchasePrice,
        packPurchasePrice: packPurchasePrice,
        salePrice: salePrice,
        expiryDate: expiryDate,
      );
}

class PurchasesNotifier extends Notifier<List<Purchase>> {
  @override
  List<Purchase> build() => ref.read(databaseProvider).getPurchases();

  Future<Purchase> createPurchase({
    required String supplierId,
    required String supplierName,
    required List<PurchaseDraftItem> draftItems,
    String notes = '',
  }) async {
    if (draftItems.isEmpty) throw StateError('Add at least one item');

    final db = ref.read(databaseProvider);
    final settings = ref.read(settingsProvider);
    final purchaseNo =
        'PO-${settings.nextPurchaseNumber.toString().padLeft(6, '0')}';
    final now = DateTime.now().millisecondsSinceEpoch;

    final purchaseItems = <PurchaseItem>[];
    for (final draft in draftItems) {
      final existing = _findExistingBatch(db, draft);
      if (existing != null) {
        await db.saveBatch(existing.copyWith(
          quantity: existing.quantity + draft.quantity,
          purchasePrice: draft.purchasePrice != 0
              ? draft.purchasePrice
              : existing.purchasePrice,
          salePrice:
              draft.salePrice != 0 ? draft.salePrice : existing.salePrice,
          expiryDate: draft.expiryDate != 0
              ? draft.expiryDate
              : existing.expiryDate,
          supplierId:
              supplierId.isNotEmpty ? supplierId : existing.supplierId,
        ));
      } else {
        await db.saveBatch(Batch(
          id: IdGenerator.generate('bat'),
          medicineId: draft.medicineId,
          batchNumber: draft.batchNumber,
          quantity: draft.quantity,
          expiryDate: draft.expiryDate,
          purchasePrice: draft.purchasePrice,
          salePrice: draft.salePrice,
          receivedDate: now,
          supplierId: supplierId,
        ));
      }
      purchaseItems.add(draft.toPurchaseItem());
    }

    final total = draftItems.fold(0.0, (s, i) => s + i.lineTotal);
    final purchase = Purchase(
      id: IdGenerator.generate('pur'),
      purchaseNumber: purchaseNo,
      dateTime: now,
      supplierId: supplierId,
      supplierName: supplierName,
      items: purchaseItems,
      total: total,
      notes: notes,
    );
    await db.savePurchase(purchase);
    await ref.read(settingsProvider.notifier).update(settings.copyWith(
        nextPurchaseNumber: settings.nextPurchaseNumber + 1));

    // Update supplier's totalBilled in suppliers box
    if (supplierId.isNotEmpty) {
      final sup =
          db.getSuppliers().where((s) => s.id == supplierId).firstOrNull;
      if (sup != null) {
        await ref.read(suppliersProvider.notifier).update(
              sup.copyWith(totalBilled: sup.totalBilled + total),
            );
      }
    }

    state = [...state, purchase];
    ref.read(batchesProvider.notifier).reload();
    return purchase;
  }

  Future<void> remove(String id, {bool revertStock = true}) async {
    final db = ref.read(databaseProvider);
    final purchase = state.where((p) => p.id == id).firstOrNull;
    if (purchase != null) {
      if (revertStock) {
        for (final item in purchase.items) {
          final batches = db.batchesForMedicine(item.medicineId);
          final match = batches
              .where((b) => b.batchNumber.trim() == item.batchNumber.trim())
              .firstOrNull;
          if (match != null) {
            final newQty = match.quantity - item.quantity;
            await db
                .saveBatch(match.copyWith(quantity: newQty < 0 ? 0 : newQty));
          }
        }
        ref.read(batchesProvider.notifier).reload();

        if (purchase.supplierId.isNotEmpty) {
          final sup = db
              .getSuppliers()
              .where((s) => s.id == purchase.supplierId)
              .firstOrNull;
          if (sup != null) {
            final newBilled = sup.totalBilled - purchase.total;
            await ref.read(suppliersProvider.notifier).update(
                  sup.copyWith(totalBilled: newBilled < 0 ? 0 : newBilled),
                );
          }
        }
      }
      await db.deletePurchase(id);
      state = state.where((p) => p.id != id).toList();
    }
  }

  void reload() {
    state = ref.read(databaseProvider).getPurchases();
  }

  Batch? _findExistingBatch(LocalDatabase db, PurchaseDraftItem draft) {
    for (final b in db.batchesForMedicine(draft.medicineId)) {
      if (b.batchNumber.trim() == draft.batchNumber.trim() &&
          draft.batchNumber.trim().isNotEmpty) {
        return b;
      }
    }
    return null;
  }
}

final purchasesProvider =
    NotifierProvider<PurchasesNotifier, List<Purchase>>(PurchasesNotifier.new);
