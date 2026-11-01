/// A stock batch for a [Medicine]. Multiple batches can exist per medicine;
/// each carries its own quantity, expiry date and pricing. Selling reduces
/// the quantity of the specific batch sold.
class Batch {
  final String id;
  final String medicineId;
  final String batchNumber;
  final int quantity;
  final int expiryDate; // ms since epoch
  final double purchasePrice; // cost at which this batch was bought
  final double salePrice; // selling price for this batch (may differ)
  final int receivedDate; // ms since epoch
  final String supplierId;

  const Batch({
    required this.id,
    required this.medicineId,
    required this.batchNumber,
    required this.quantity,
    required this.expiryDate,
    this.purchasePrice = 0,
    this.salePrice = 0,
    this.receivedDate = 0,
    this.supplierId = '',
  });

  Batch copyWith({
    String? batchNumber,
    int? quantity,
    int? expiryDate,
    double? purchasePrice,
    double? salePrice,
    int? receivedDate,
    String? supplierId,
  }) =>
      Batch(
        id: id,
        medicineId: medicineId,
        batchNumber: batchNumber ?? this.batchNumber,
        quantity: quantity ?? this.quantity,
        expiryDate: expiryDate ?? this.expiryDate,
        purchasePrice: purchasePrice ?? this.purchasePrice,
        salePrice: salePrice ?? this.salePrice,
        receivedDate: receivedDate ?? this.receivedDate,
        supplierId: supplierId ?? this.supplierId,
      );

  DateTime get expiryDateTime =>
      DateTime.fromMillisecondsSinceEpoch(expiryDate);

  Map<String, dynamic> toJson() => {
        'id': id,
        'medicineId': medicineId,
        'batchNumber': batchNumber,
        'quantity': quantity,
        'expiryDate': expiryDate,
        'purchasePrice': purchasePrice,
        'salePrice': salePrice,
        'receivedDate': receivedDate,
        'supplierId': supplierId,
      };

  factory Batch.fromJson(Map<String, dynamic> json) => Batch(
        id: json['id'] as String,
        medicineId: json['medicineId'] as String,
        batchNumber: (json['batchNumber'] as String?) ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 0,
        expiryDate: (json['expiryDate'] as num?)?.toInt() ?? 0,
        purchasePrice: (json['purchasePrice'] as num?)?.toDouble() ?? 0,
        salePrice: (json['salePrice'] as num?)?.toDouble() ?? 0,
        receivedDate: (json['receivedDate'] as num?)?.toInt() ?? 0,
        supplierId: (json['supplierId'] as String?) ?? '',
      );
}
