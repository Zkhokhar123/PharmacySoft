import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/id_generator.dart';
import '../data/models/purchase.dart';
import '../data/models/supplier_payment.dart';
import 'catalog_providers.dart';
import 'core_providers.dart';
import 'purchases_providers.dart';

// ---------------------------------------------------------------------------
// SupplierPayment CRUD notifier
// ---------------------------------------------------------------------------

class SupplierPaymentsNotifier extends Notifier<List<SupplierPayment>> {
  @override
  List<SupplierPayment> build() =>
      ref.read(databaseProvider).getSupplierPayments();

  Future<SupplierPayment> add({
    required String supplierId,
    required String supplierName,
    required double amount,
    required String paymentMethod,
    String notes = '',
    String? referencePurchaseNumber,
    DateTime? date,
  }) async {
    final payment = SupplierPayment(
      id: IdGenerator.generate('spay'),
      supplierId: supplierId,
      supplierName: supplierName,
      dateTime: (date ?? DateTime.now()).millisecondsSinceEpoch,
      amount: amount,
      paymentMethod: paymentMethod,
      notes: notes,
      referencePurchaseNumber: referencePurchaseNumber,
    );
    await ref.read(databaseProvider).saveSupplierPayment(payment);
    state = [payment, ...state];
    return payment;
  }

  Future<void> remove(String id) async {
    await ref.read(databaseProvider).deleteSupplierPayment(id);
    state = state.where((p) => p.id != id).toList();
  }

  void reload() {
    state = ref.read(databaseProvider).getSupplierPayments();
  }
}

final supplierPaymentsProvider =
    NotifierProvider<SupplierPaymentsNotifier, List<SupplierPayment>>(
        SupplierPaymentsNotifier.new);

// ---------------------------------------------------------------------------
// Supplier Ledger timeline entries
// ---------------------------------------------------------------------------

sealed class SupplierLedgerEntry {
  final int dateTime;
  final double runningBalance;
  const SupplierLedgerEntry(
      {required this.dateTime, required this.runningBalance});

  DateTime get dateTimeValue =>
      DateTime.fromMillisecondsSinceEpoch(dateTime);
}

class SupplierPurchaseLedgerEntry extends SupplierLedgerEntry {
  final Purchase purchase;
  const SupplierPurchaseLedgerEntry({
    required this.purchase,
    required super.dateTime,
    required super.runningBalance,
  });
}

class SupplierPaymentLedgerEntry extends SupplierLedgerEntry {
  final SupplierPayment payment;
  const SupplierPaymentLedgerEntry({
    required this.payment,
    required super.dateTime,
    required super.runningBalance,
  });
}

class SupplierOpeningLedgerEntry extends SupplierLedgerEntry {
  final double billed;
  final double paid;
  const SupplierOpeningLedgerEntry({
    required this.billed,
    required this.paid,
    required super.dateTime,
    required super.runningBalance,
  });
}

// ---------------------------------------------------------------------------
// Supplier Khata Summary
// ---------------------------------------------------------------------------

class SupplierKhataSummary {
  final String supplierId;
  final String supplierName;
  final double totalMaalAya;
  final double totalCashDiya;
  final double currentBaqi;
  final int totalShipments;
  final int totalPayments;

  const SupplierKhataSummary({
    required this.supplierId,
    required this.supplierName,
    required this.totalMaalAya,
    required this.totalCashDiya,
    required this.currentBaqi,
    required this.totalShipments,
    required this.totalPayments,
  });
}

final supplierKhataSummaryProvider =
    Provider.family<SupplierKhataSummary, String>((ref, supplierId) {
  final suppliers = ref.watch(suppliersProvider);
  final supplier =
      suppliers.where((s) => s.id == supplierId).firstOrNull;

  final allPurchases = ref.watch(purchasesProvider);
  final supPurchases =
      allPurchases.where((p) => p.supplierId == supplierId).toList();

  final allPayments = ref.watch(supplierPaymentsProvider);
  final supPayments =
      allPayments.where((p) => p.supplierId == supplierId).toList();

  final purchaseTotal = supPurchases.fold(0.0, (sum, p) => sum + p.total);
  final paymentsTotal = supPayments.fold(0.0, (sum, p) => sum + p.amount);

  // If supplier has manual totalBilled or paidAmount entered before
  final manualBilled = (supplier?.totalBilled ?? 0.0);
  final manualPaid = (supplier?.paidAmount ?? 0.0);

  final totalMaal = purchaseTotal > 0 ? purchaseTotal : manualBilled;
  final totalPaid = paymentsTotal > 0 ? paymentsTotal : manualPaid;

  return SupplierKhataSummary(
    supplierId: supplierId,
    supplierName: supplier?.name ?? '',
    totalMaalAya: totalMaal,
    totalCashDiya: totalPaid,
    currentBaqi: totalMaal - totalPaid,
    totalShipments: supPurchases.length,
    totalPayments: supPayments.length,
  );
});

// ---------------------------------------------------------------------------
// Chronological Supplier Ledger Provider
// ---------------------------------------------------------------------------

final supplierLedgerProvider =
    Provider.family<List<SupplierLedgerEntry>, String>((ref, supplierId) {
  final allPurchases = ref.watch(purchasesProvider);
  final supPurchases =
      allPurchases.where((p) => p.supplierId == supplierId).toList();

  final allPayments = ref.watch(supplierPaymentsProvider);
  final supPayments =
      allPayments.where((p) => p.supplierId == supplierId).toList();

  // Combine events in ascending time order to compute running balance
  final events = <({int time, dynamic obj, bool isPurchase})>[];

  for (final p in supPurchases) {
    events.add((time: p.dateTime, obj: p, isPurchase: true));
  }
  for (final pay in supPayments) {
    events.add((time: pay.dateTime, obj: pay, isPurchase: false));
  }

  events.sort((a, b) => a.time.compareTo(b.time));

  double running = 0.0;
  final result = <SupplierLedgerEntry>[];

  for (final ev in events) {
    if (ev.isPurchase) {
      final p = ev.obj as Purchase;
      running += p.total;
      result.add(SupplierPurchaseLedgerEntry(
        purchase: p,
        dateTime: p.dateTime,
        runningBalance: running,
      ));
    } else {
      final pay = ev.obj as SupplierPayment;
      running -= pay.amount;
      result.add(SupplierPaymentLedgerEntry(
        payment: pay,
        dateTime: pay.dateTime,
        runningBalance: running,
      ));
    }
  }

  // If there are no purchases recorded yet but the supplier has manual opening figures
  if (result.isEmpty) {
    final supplier = ref
        .watch(suppliersProvider)
        .where((s) => s.id == supplierId)
        .firstOrNull;
    if (supplier != null &&
        (supplier.totalBilled > 0 || supplier.paidAmount > 0)) {
      result.add(SupplierOpeningLedgerEntry(
        billed: supplier.totalBilled,
        paid: supplier.paidAmount,
        dateTime: DateTime.now().millisecondsSinceEpoch,
        runningBalance: supplier.balance,
      ));
    }
  }

  // Return newest first for ledger list display
  return result.reversed.toList();
});
