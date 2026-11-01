/// A single line on a purchase (stock-in) order.
class PurchaseItem {
  final String medicineId;
  final String medicineName;
  final String batchNumber;
  /// Stock added in base units (tabs).
  final int quantity;
  final int packQty;
  final int unitsPerPack;
  final String packName;
  final String unit;
  /// Cost per tab, used for stock valuation.
  final double purchasePrice;
  /// Rate paid per box.
  final double packPurchasePrice;
  /// Sale price per tab.
  final double salePrice;
  final int expiryDate; // ms since epoch

  const PurchaseItem({
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

  Map<String, dynamic> toJson() => {
        'medicineId': medicineId,
        'medicineName': medicineName,
        'batchNumber': batchNumber,
        'quantity': quantity,
        'packQty': packQty,
        'unitsPerPack': unitsPerPack,
        'packName': packName,
        'unit': unit,
        'purchasePrice': purchasePrice,
        'packPurchasePrice': packPurchasePrice,
        'salePrice': salePrice,
        'expiryDate': expiryDate,
      };

  factory PurchaseItem.fromJson(Map<String, dynamic> json) => PurchaseItem(
        medicineId: json['medicineId'] as String,
        medicineName: (json['medicineName'] as String?) ?? '',
        batchNumber: (json['batchNumber'] as String?) ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 0,
        packQty: (json['packQty'] as num?)?.toInt() ?? 0,
        unitsPerPack: (json['unitsPerPack'] as num?)?.toInt() ?? 1,
        packName: (json['packName'] as String?) ?? 'Box',
        unit: (json['unit'] as String?) ?? 'Tab',
        purchasePrice: (json['purchasePrice'] as num?)?.toDouble() ?? 0,
        packPurchasePrice:
            (json['packPurchasePrice'] as num?)?.toDouble() ?? 0,
        salePrice: (json['salePrice'] as num?)?.toDouble() ?? 0,
        expiryDate: (json['expiryDate'] as num?)?.toInt() ?? 0,
      );
}

/// A purchase / stock-in record.
class Purchase {
  final String id;
  final String purchaseNumber;
  final int dateTime;
  final String supplierId;
  final String supplierName;
  final List<PurchaseItem> items;
  final double total;
  final String notes;

  const Purchase({
    required this.id,
    required this.purchaseNumber,
    required this.dateTime,
    this.supplierId = '',
    this.supplierName = '',
    required this.items,
    required this.total,
    this.notes = '',
  });

  DateTime get dateTimeValue => DateTime.fromMillisecondsSinceEpoch(dateTime);

  Map<String, dynamic> toJson() => {
        'id': id,
        'purchaseNumber': purchaseNumber,
        'dateTime': dateTime,
        'supplierId': supplierId,
        'supplierName': supplierName,
        'items': items.map((e) => e.toJson()).toList(),
        'total': total,
        'notes': notes,
      };

  factory Purchase.fromJson(Map<String, dynamic> json) => Purchase(
        id: json['id'] as String,
        purchaseNumber: (json['purchaseNumber'] as String?) ?? '',
        dateTime: (json['dateTime'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
        supplierId: (json['supplierId'] as String?) ?? '',
        supplierName: (json['supplierName'] as String?) ?? '',
        items: ((json['items'] as List?) ?? [])
            .map((e) => PurchaseItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: (json['total'] as num?)?.toDouble() ?? 0,
        notes: (json['notes'] as String?) ?? '',
      );
}
