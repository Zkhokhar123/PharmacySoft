/// An operating expense of the pharmacy (Rent, Electricity, Salaries, Food/Tea, etc.)
class Expense {
  final String id;
  final String title;
  final String category; // Rent / Electricity / Salary / Tea-Refreshment / Maintenance / Other
  final double amount;
  final int dateTime; // ms since epoch
  final String notes;

  const Expense({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.dateTime,
    this.notes = '',
  });

  DateTime get dateTimeValue => DateTime.fromMillisecondsSinceEpoch(dateTime);

  Expense copyWith({
    String? title,
    String? category,
    double? amount,
    int? dateTime,
    String? notes,
  }) =>
      Expense(
        id: id,
        title: title ?? this.title,
        category: category ?? this.category,
        amount: amount ?? this.amount,
        dateTime: dateTime ?? this.dateTime,
        notes: notes ?? this.notes,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'amount': amount,
        'dateTime': dateTime,
        'notes': notes,
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        title: (json['title'] as String?) ?? '',
        category: (json['category'] as String?) ?? 'Other',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        dateTime: (json['dateTime'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
        notes: (json['notes'] as String?) ?? '',
      );
}
