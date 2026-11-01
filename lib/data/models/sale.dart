import 'customer.dart';

/// A single line on an invoice.
class SaleItem {
  final String medicineId;
  final String medicineName;
  final String batchId;
  final String batchNumber;
  /// Quantity in base units (tabs).
  final int quantity;
  final int unitsPerPack;
  final String packName;
  final String unit;
  final double unitPrice;
  final double purchasePrice; // Cost per base unit at the time of sale
  final double lineDiscount; // absolute discount for this line
  final int expiryDate; // ms snapshot for display
  final int returnedQuantity; // Quantity returned/refunded

  const SaleItem({
    required this.medicineId,
    required this.medicineName,
    required this.batchId,
    required this.batchNumber,
    required this.quantity,
    this.unitsPerPack = 1,
    this.packName = 'Box',
    this.unit = 'Tab',
    required this.unitPrice,
    this.purchasePrice = 0,
    this.lineDiscount = 0,
    required this.expiryDate,
    this.returnedQuantity = 0,
  });

  double get grossTotal => quantity * unitPrice;
  double get lineTotal => grossTotal - lineDiscount;
  double get cost => (quantity - returnedQuantity) * purchasePrice;
  double get netLineTotal => (quantity - returnedQuantity) * unitPrice - lineDiscount;
  double get profit => netLineTotal - cost;
  bool get isFullyReturned => quantity > 0 && returnedQuantity >= quantity;

  SaleItem copyWith({
    int? quantity,
    int? returnedQuantity,
    double? unitPrice,
    double? purchasePrice,
    double? lineDiscount,
  }) =>
      SaleItem(
        medicineId: medicineId,
        medicineName: medicineName,
        batchId: batchId,
        batchNumber: batchNumber,
        quantity: quantity ?? this.quantity,
        unitsPerPack: unitsPerPack,
        packName: packName,
        unit: unit,
        unitPrice: unitPrice ?? this.unitPrice,
        purchasePrice: purchasePrice ?? this.purchasePrice,
        lineDiscount: lineDiscount ?? this.lineDiscount,
        expiryDate: expiryDate,
        returnedQuantity: returnedQuantity ?? this.returnedQuantity,
      );

  Map<String, dynamic> toJson() => {
        'medicineId': medicineId,
        'medicineName': medicineName,
        'batchId': batchId,
        'batchNumber': batchNumber,
        'quantity': quantity,
        'unitsPerPack': unitsPerPack,
        'packName': packName,
        'unit': unit,
        'unitPrice': unitPrice,
        'purchasePrice': purchasePrice,
        'lineDiscount': lineDiscount,
        'expiryDate': expiryDate,
        'returnedQuantity': returnedQuantity,
      };

  factory SaleItem.fromJson(Map<String, dynamic> json) => SaleItem(
        medicineId: json['medicineId'] as String,
        medicineName: (json['medicineName'] as String?) ?? '',
        batchId: json['batchId'] as String,
        batchNumber: (json['batchNumber'] as String?) ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 0,
        unitsPerPack: (json['unitsPerPack'] as num?)?.toInt() ?? 1,
        packName: (json['packName'] as String?) ?? 'Box',
        unit: (json['unit'] as String?) ?? 'Tab',
        unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
        purchasePrice: (json['purchasePrice'] as num?)?.toDouble() ?? 0,
        lineDiscount: (json['lineDiscount'] as num?)?.toDouble() ?? 0,
        expiryDate: (json['expiryDate'] as num?)?.toInt() ?? 0,
        returnedQuantity: (json['returnedQuantity'] as num?)?.toInt() ?? 0,
      );
}

/// A sale / invoice. Stock is deducted from the sold batches when the sale is
/// saved.
class Sale {
  final String id;
  final String invoiceNumber;
  final int dateTime; // ms since epoch
  final String customerId;
  final String customerName;
  final List<SaleItem> items;
  final double subtotal; // sum of line totals before invoice discount/tax
  final double discount; // invoice-level discount
  final double taxRate; // percentage, e.g. 0 for none
  final double taxAmount;
  final double total;
  final double paid;
  final String paymentMethod; // Cash / Card / Online / Credit
  final String notes;
  final bool isReturned; // Whether this invoice was refunded / returned

  const Sale({
    required this.id,
    required this.invoiceNumber,
    required this.dateTime,
    this.customerId = Customer.walkInId,
    this.customerName = 'Walk-in Customer',
    required this.items,
    required this.subtotal,
    this.discount = 0,
    this.taxRate = 0,
    this.taxAmount = 0,
    required this.total,
    required this.paid,
    this.paymentMethod = 'Cash',
    this.notes = '',
    this.isReturned = false,
  });

  double get balance => total - paid;
  bool get isFullyPaid => balance.abs() < 0.001;
  bool get isCredit => !isFullyPaid;
  DateTime get dateTimeValue =>
      DateTime.fromMillisecondsSinceEpoch(dateTime);
  int get itemCount => items.fold(0, (s, i) => s + (i.quantity - i.returnedQuantity));
  double get totalCost => items.fold(0.0, (s, i) => s + i.cost);
  double get grossProfit => isReturned ? 0.0 : (total - totalCost);

  Sale copyWith({
    String? customerId,
    String? customerName,
    List<SaleItem>? items,
    double? subtotal,
    double? discount,
    double? taxRate,
    double? taxAmount,
    double? total,
    double? paid,
    String? paymentMethod,
    String? notes,
    bool? isReturned,
  }) =>
      Sale(
        id: id,
        invoiceNumber: invoiceNumber,
        dateTime: dateTime,
        customerId: customerId ?? this.customerId,
        customerName: customerName ?? this.customerName,
        items: items ?? this.items,
        subtotal: subtotal ?? this.subtotal,
        discount: discount ?? this.discount,
        taxRate: taxRate ?? this.taxRate,
        taxAmount: taxAmount ?? this.taxAmount,
        total: total ?? this.total,
        paid: paid ?? this.paid,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        notes: notes ?? this.notes,
        isReturned: isReturned ?? this.isReturned,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'invoiceNumber': invoiceNumber,
        'dateTime': dateTime,
        'customerId': customerId,
        'customerName': customerName,
        'items': items.map((e) => e.toJson()).toList(),
        'subtotal': subtotal,
        'discount': discount,
        'taxRate': taxRate,
        'taxAmount': taxAmount,
        'total': total,
        'paid': paid,
        'paymentMethod': paymentMethod,
        'notes': notes,
        'isReturned': isReturned,
      };

  factory Sale.fromJson(Map<String, dynamic> json) => Sale(
        id: json['id'] as String,
        invoiceNumber: (json['invoiceNumber'] as String?) ?? '',
        dateTime: (json['dateTime'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
        customerId: (json['customerId'] as String?) ?? Customer.walkInId,
        customerName: (json['customerName'] as String?) ?? 'Walk-in Customer',
        items: ((json['items'] as List?) ?? [])
            .map((e) => SaleItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
        discount: (json['discount'] as num?)?.toDouble() ?? 0,
        taxRate: (json['taxRate'] as num?)?.toDouble() ?? 0,
        taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0,
        total: (json['total'] as num?)?.toDouble() ?? 0,
        paid: (json['paid'] as num?)?.toDouble() ?? 0,
        paymentMethod: (json['paymentMethod'] as String?) ?? 'Cash',
        notes: (json['notes'] as String?) ?? '',
        isReturned: (json['isReturned'] as bool?) ?? false,
      );
}
