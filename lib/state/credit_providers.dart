import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/id_generator.dart';
import '../data/models/credit_payment.dart';
import '../data/models/sale.dart';
import 'core_providers.dart';
import 'sales_providers.dart';

// ---------------------------------------------------------------------------
// CreditPayment CRUD notifier
// ---------------------------------------------------------------------------

class CreditPaymentsNotifier extends Notifier<List<CreditPayment>> {
  @override
  List<CreditPayment> build() =>
      ref.read(databaseProvider).getCreditPayments();

  Future<CreditPayment> add({
    required String customerId,
    required String customerName,
    required double amount,
    required String paymentMethod,
    String notes = '',
    String? referenceInvoice,
  }) async {
    final payment = CreditPayment(
      id: IdGenerator.generate('cpay'),
      customerId: customerId,
      customerName: customerName,
      dateTime: DateTime.now().millisecondsSinceEpoch,
      amount: amount,
      paymentMethod: paymentMethod,
      notes: notes,
      referenceInvoice: referenceInvoice,
    );
    await ref.read(databaseProvider).saveCreditPayment(payment);
    state = [payment, ...state];
    return payment;
  }

  Future<void> remove(String id) async {
    await ref.read(databaseProvider).deleteCreditPayment(id);
    state = state.where((p) => p.id != id).toList();
  }

  void reload() {
    state = ref.read(databaseProvider).getCreditPayments();
  }
}

final creditPaymentsProvider =
    NotifierProvider<CreditPaymentsNotifier, List<CreditPayment>>(
        CreditPaymentsNotifier.new);

// ---------------------------------------------------------------------------
// Per-customer summary
// ---------------------------------------------------------------------------

/// All financial info for one customer in a single object.
class CustomerCreditSummary {
  final String customerId;
  final String customerName;

  /// Total amount charged across all sales.
  final double totalCharged;

  /// Total paid at time of sale.
  final double totalPaidAtSale;

  /// Total credit payments received after the sale.
  final double totalCreditReceived;

  /// Outstanding balance still owed. Negative means overpaid (change).
  final double outstanding;

  /// Sales that still have an unpaid balance.
  final List<Sale> creditSales;

  /// Credit payments received from this customer.
  final List<CreditPayment> payments;

  const CustomerCreditSummary({
    required this.customerId,
    required this.customerName,
    required this.totalCharged,
    required this.totalPaidAtSale,
    required this.totalCreditReceived,
    required this.outstanding,
    required this.creditSales,
    required this.payments,
  });

  bool get hasBalance => outstanding > 0.005;
}

/// Computes [CustomerCreditSummary] for every named customer who has
/// at least one credit sale or credit payment. Walk-in customers excluded.
final customerCreditProvider =
    Provider<List<CustomerCreditSummary>>((ref) {
  final sales = ref.watch(salesProvider);
  final payments = ref.watch(creditPaymentsProvider);

  // group sales by customerId (skip walk-in)
  final Map<String, List<Sale>> saleMap = {};
  for (final s in sales) {
    if (s.customerId == 'walk_in') continue;
    saleMap.putIfAbsent(s.customerId, () => []).add(s);
  }

  // group credit payments by customerId
  final Map<String, List<CreditPayment>> payMap = {};
  for (final p in payments) {
    payMap.putIfAbsent(p.customerId, () => []).add(p);
  }

  // union of all customer ids that appear in either map
  final ids = <String>{...saleMap.keys, ...payMap.keys};

  return ids.map((cid) {
    final cSales = saleMap[cid] ?? [];
    final cPays = payMap[cid] ?? [];

    final charged = cSales.fold(0.0, (s, sale) => s + sale.total);
    final paidAtSale = cSales.fold(0.0, (s, sale) => s + sale.paid);
    final creditReceived = cPays.fold(0.0, (s, p) => s + p.amount);
    final outstanding = charged - paidAtSale - creditReceived;

    final creditSales =
        cSales.where((s) => s.total - s.paid > 0.005).toList()
          ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    final name = cSales.isNotEmpty
        ? cSales.first.customerName
        : (cPays.isNotEmpty ? cPays.first.customerName : cid);

    return CustomerCreditSummary(
      customerId: cid,
      customerName: name,
      totalCharged: charged,
      totalPaidAtSale: paidAtSale,
      totalCreditReceived: creditReceived,
      outstanding: outstanding,
      creditSales: creditSales,
      payments: cPays..sort((a, b) => b.dateTime.compareTo(a.dateTime)),
    );
  }).toList()
    ..sort((a, b) => b.outstanding.compareTo(a.outstanding));
});

/// Quick lookup: customerId → outstanding balance (0 if not in ledger).
final outstandingMapProvider = Provider<Map<String, double>>((ref) {
  final summaries = ref.watch(customerCreditProvider);
  return {for (final s in summaries) s.customerId: s.outstanding};
});

/// Total outstanding across ALL customers.
final totalOutstandingProvider = Provider<double>((ref) {
  return ref
      .watch(customerCreditProvider)
      .where((s) => s.hasBalance)
      .fold(0.0, (sum, s) => sum + s.outstanding);
});

/// Ledger entries for a single customer — combines sales and credit payments
/// into one chronological list for display.
sealed class LedgerEntry {
  final int dateTime;
  const LedgerEntry(this.dateTime);
}

class LedgerSaleEntry extends LedgerEntry {
  final Sale sale;
  LedgerSaleEntry(this.sale) : super(sale.dateTime);
}

class LedgerPaymentEntry extends LedgerEntry {
  final CreditPayment payment;
  LedgerPaymentEntry(this.payment) : super(payment.dateTime);
}

final customerLedgerProvider =
    Provider.family<List<LedgerEntry>, String>((ref, customerId) {
  final summaries = ref.watch(customerCreditProvider);
  final summary =
      summaries.where((s) => s.customerId == customerId).firstOrNull;
  if (summary == null) return [];

  final entries = <LedgerEntry>[
    ...summary.creditSales.map(LedgerSaleEntry.new),
    ...summary.payments.map(LedgerPaymentEntry.new),
    // also include fully-paid sales so the full history is visible
    ...ref
        .watch(salesProvider)
        .where((s) =>
            s.customerId == customerId && s.total - s.paid <= 0.005)
        .map(LedgerSaleEntry.new),
  ];

  // de-duplicate sale entries (creditSales are a subset of all sales)
  final seen = <String>{};
  final deduped = <LedgerEntry>[];
  for (final e in entries) {
    final key = e is LedgerSaleEntry ? 'sale_${e.sale.id}' : 'pay_${(e as LedgerPaymentEntry).payment.id}';
    if (seen.add(key)) deduped.add(e);
  }

  deduped.sort((a, b) => b.dateTime.compareTo(a.dateTime));
  return deduped;
});
