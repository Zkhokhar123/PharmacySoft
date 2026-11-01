/// A product grouping (e.g. Tablets, Syrups, Antibiotics).
/// `colorValue` is stored as an ARGB int; the UI converts it to a [Color].
class Category {
  final String id;
  final String name;
  final String description;
  final int colorValue;

  const Category({
    required this.id,
    required this.name,
    this.description = '',
    this.colorValue = 0xFF0D9488,
  });

  Category copyWith({
    String? name,
    String? description,
    int? colorValue,
  }) =>
      Category(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        colorValue: colorValue ?? this.colorValue,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'colorValue': colorValue,
      };

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        name: json['name'] as String,
        description: (json['description'] as String?) ?? '',
        colorValue: (json['colorValue'] as int?) ?? 0xFF0D9488,
      );
}
