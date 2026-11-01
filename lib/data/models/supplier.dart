/// A supplier / vendor from whom stock is procured.
class Supplier {
  final String id;
  final String name;
  final String contactPerson;
  final String phone;
  final String email;
  final String address;
  final String notes;
  final double totalBilled; // Kitna ka maal aya
  final double paidAmount;  // Kitna cash diya

  const Supplier({
    required this.id,
    required this.name,
    this.contactPerson = '',
    this.phone = '',
    this.email = '',
    this.address = '',
    this.notes = '',
    this.totalBilled = 0,
    this.paidAmount = 0,
  });

  double get balance => totalBilled - paidAmount; // Kitna baqi hai

  Supplier copyWith({
    String? name,
    String? contactPerson,
    String? phone,
    String? email,
    String? address,
    String? notes,
    double? totalBilled,
    double? paidAmount,
  }) =>
      Supplier(
        id: id,
        name: name ?? this.name,
        contactPerson: contactPerson ?? this.contactPerson,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        address: address ?? this.address,
        notes: notes ?? this.notes,
        totalBilled: totalBilled ?? this.totalBilled,
        paidAmount: paidAmount ?? this.paidAmount,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'contactPerson': contactPerson,
        'phone': phone,
        'email': email,
        'address': address,
        'notes': notes,
        'totalBilled': totalBilled,
        'paidAmount': paidAmount,
      };

  factory Supplier.fromJson(Map<String, dynamic> json) => Supplier(
        id: json['id'] as String,
        name: json['name'] as String,
        contactPerson: (json['contactPerson'] as String?) ?? '',
        phone: (json['phone'] as String?) ?? '',
        email: (json['email'] as String?) ?? '',
        address: (json['address'] as String?) ?? '',
        notes: (json['notes'] as String?) ?? '',
        totalBilled: (json['totalBilled'] as num?)?.toDouble() ?? 0,
        paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0,
      );
}
