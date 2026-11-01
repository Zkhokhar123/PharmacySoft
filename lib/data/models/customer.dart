/// A customer linked to a sale/invoice. A "Walk-in" entry is used when no
/// customer details are captured.
class Customer {
  final String id;
  final String name;
  final String phone;
  final String address;
  final String notes;

  const Customer({
    required this.id,
    required this.name,
    this.phone = '',
    this.address = '',
    this.notes = '',
  });

  static const walkInId = 'walk_in';

  Customer copyWith({
    String? name,
    String? phone,
    String? address,
    String? notes,
  }) =>
      Customer(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        notes: notes ?? this.notes,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'address': address,
        'notes': notes,
      };

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: (json['phone'] as String?) ?? '',
        address: (json['address'] as String?) ?? '',
        notes: (json['notes'] as String?) ?? '',
      );
}
