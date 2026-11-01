/// A payment received from a customer to clear (part of) their credit balance.
///
/// How the ledger works:
///   - Each [Sale] already records how much was paid at the time (`paid`).
///     The difference `total - paid` is the initial credit for that sale.
///   - Whenever the customer pays off some or all of that credit later, we
///     create a [CreditPayment] record linked to that customer.
///   - Outstanding balance = sum(sale.total - sale.paid)
///                         - sum(credit_payments for that customer)
class CreditPayment {
  final String id;
  final String customerId;
  final String customerName;
  final int dateTime; // ms since epoch
  final double amount;
  final String paymentMethod; // Cash / Card / Online
  final String notes;
  /// Optional: which sale this partially clears (display hint only).
  final String? referenceInvoice;

  const CreditPayment({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.dateTime,
    required this.amount,
    this.paymentMethod = 'Cash',
    this.notes = '',
    this.referenceInvoice,
  });

  DateTime get dateTimeValue =>
      DateTime.fromMillisecondsSinceEpoch(dateTime);

  Map<String, dynamic> toJson() => {
        'id': id,
        'customerId': customerId,
        'customerName': customerName,
        'dateTime': dateTime,
        'amount': amount,
        'paymentMethod': paymentMethod,
        'notes': notes,
        'referenceInvoice': referenceInvoice,
      };

  factory CreditPayment.fromJson(Map<String, dynamic> json) => CreditPayment(
        id: json['id'] as String,
        customerId: json['customerId'] as String,
        customerName: (json['customerName'] as String?) ?? '',
        dateTime: (json['dateTime'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        paymentMethod: (json['paymentMethod'] as String?) ?? 'Cash',
        notes: (json['notes'] as String?) ?? '',
        referenceInvoice: json['referenceInvoice'] as String?,
      );
}
