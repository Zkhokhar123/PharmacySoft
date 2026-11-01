/// A medicine / product in the catalogue. Stock is tracked per [Batch]
/// (because expiry is batch-specific); the medicine itself holds the
/// product definition plus default pricing.
class Medicine {
  final String id;
  final String name;
  final String genericName;
  final String categoryId;
  final String manufacturer;
  final String barcode;
  final String description;
  final String shelfLocation; // e.g. "Rack A-2", "Shelf 4"
  final String unit; // base unit, e.g. "Tab", "ml"
  final String packName; // outer pack, e.g. "Box" / "Daba"
  /// How many [unit]s are inside one pack. 4 boxes × 50 = 200 tabs.
  final int unitsPerPack;
  final int reorderLevel; // low-stock threshold in base units
  final double salePrice; // default sale price per base unit (tab)
  final double purchasePrice; // default purchase price per base unit (tab)
  final int createdAt; // ms since epoch

  const Medicine({
    required this.id,
    required this.name,
    this.genericName = '',
    this.categoryId = '',
    this.manufacturer = '',
    this.barcode = '',
    this.description = '',
    this.shelfLocation = '',
    this.unit = 'Tab',
    this.packName = 'Box',
    this.unitsPerPack = 1,
    this.reorderLevel = 0,
    this.salePrice = 0,
    this.purchasePrice = 0,
    required this.createdAt,
  });

  Medicine copyWith({
    String? name,
    String? genericName,
    String? categoryId,
    String? manufacturer,
    String? barcode,
    String? description,
    String? shelfLocation,
    String? unit,
    String? packName,
    int? unitsPerPack,
    int? reorderLevel,
    double? salePrice,
    double? purchasePrice,
  }) =>
      Medicine(
        id: id,
        name: name ?? this.name,
        genericName: genericName ?? this.genericName,
        categoryId: categoryId ?? this.categoryId,
        manufacturer: manufacturer ?? this.manufacturer,
        barcode: barcode ?? this.barcode,
        description: description ?? this.description,
        shelfLocation: shelfLocation ?? this.shelfLocation,
        unit: unit ?? this.unit,
        packName: packName ?? this.packName,
        unitsPerPack: unitsPerPack ?? this.unitsPerPack,
        reorderLevel: reorderLevel ?? this.reorderLevel,
        salePrice: salePrice ?? this.salePrice,
        purchasePrice: purchasePrice ?? this.purchasePrice,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'genericName': genericName,
        'categoryId': categoryId,
        'manufacturer': manufacturer,
        'barcode': barcode,
        'description': description,
        'shelfLocation': shelfLocation,
        'unit': unit,
        'packName': packName,
        'unitsPerPack': unitsPerPack,
        'reorderLevel': reorderLevel,
        'salePrice': salePrice,
        'purchasePrice': purchasePrice,
        'createdAt': createdAt,
      };

  factory Medicine.fromJson(Map<String, dynamic> json) => Medicine(
        id: json['id'] as String,
        name: json['name'] as String,
        genericName: (json['genericName'] as String?) ?? '',
        categoryId: (json['categoryId'] as String?) ?? '',
        manufacturer: (json['manufacturer'] as String?) ?? '',
        barcode: (json['barcode'] as String?) ?? '',
        description: (json['description'] as String?) ?? '',
        shelfLocation: (json['shelfLocation'] as String?) ?? '',
        unit: (json['unit'] as String?) ?? 'Tab',
        packName: (json['packName'] as String?) ?? 'Box',
        unitsPerPack: (json['unitsPerPack'] as num?)?.toInt() ?? 1,
        reorderLevel: (json['reorderLevel'] as num?)?.toInt() ?? 0,
        salePrice: (json['salePrice'] as num?)?.toDouble() ?? 0,
        purchasePrice: (json['purchasePrice'] as num?)?.toDouble() ?? 0,
        createdAt: (json['createdAt'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      );
}
