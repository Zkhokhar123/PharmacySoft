/// A payment made to a supplier/vendor to clear (part of) a payable balance.
class SupplierPayment {
  final String id;
  final String supplierId;
  final String supplierName;
  final int dateTime; // ms since epoch
  final double amount;
  final String paymentMethod; // Cash / Bank / Cheque / Online
  final String notes;
  final String? referencePurchaseNumber;

  const SupplierPayment({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    required this.dateTime,
    required this.amount,
    this.paymentMethod = 'Cash',
    this.notes = '',
    this.referencePurchaseNumber,
  });

  DateTime get dateTimeValue =>
      DateTime.fromMillisecondsSinceEpoch(dateTime);

  SupplierPayment copyWith({
    String? id,
    String? supplierId,
    String? supplierName,
    int? dateTime,
    double? amount,
    String? paymentMethod,
    String? notes,
    String? referencePurchaseNumber,
  }) =>
      SupplierPayment(
        id: id ?? this.id,
        supplierId: supplierId ?? this.supplierId,
        supplierName: supplierName ?? this.supplierName,
        dateTime: dateTime ?? this.dateTime,
        amount: amount ?? this.amount,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        notes: notes ?? this.notes,
        referencePurchaseNumber:
            referencePurchaseNumber ?? this.referencePurchaseNumber,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'supplierId': supplierId,
        'supplierName': supplierName,
        'dateTime': dateTime,
        'amount': amount,
        'paymentMethod': paymentMethod,
        'notes': notes,
        'referencePurchaseNumber': referencePurchaseNumber,
      };

  factory SupplierPayment.fromJson(Map<String, dynamic> json) =>
      SupplierPayment(
        id: json['id'] as String,
        supplierId: (json['supplierId'] as String?) ?? '',
        supplierName: (json['supplierName'] as String?) ?? '',
        dateTime: (json['dateTime'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        paymentMethod: (json['paymentMethod'] as String?) ?? 'Cash',
        notes: (json['notes'] as String?) ?? '',
        referencePurchaseNumber: json['referencePurchaseNumber'] as String?,
      );
}
