import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/id_generator.dart';
import '../data/models/expense.dart';
import 'core_providers.dart';

class ExpensesNotifier extends Notifier<List<Expense>> {
  @override
  List<Expense> build() => ref.read(databaseProvider).getExpenses();

  Future<Expense> add({
    required String title,
    required String category,
    required double amount,
    String notes = '',
    DateTime? date,
  }) async {
    final expense = Expense(
      id: IdGenerator.generate('exp'),
      title: title,
      category: category,
      amount: amount,
      dateTime: (date ?? DateTime.now()).millisecondsSinceEpoch,
      notes: notes,
    );
    await ref.read(databaseProvider).saveExpense(expense);
    state = [expense, ...state];
    return expense;
  }

  Future<void> update(Expense expense) async {
    await ref.read(databaseProvider).saveExpense(expense);
    state = state.map((e) => e.id == expense.id ? expense : e).toList();
  }

  Future<void> remove(String id) async {
    await ref.read(databaseProvider).deleteExpense(id);
    state = state.where((e) => e.id != id).toList();
  }

  void reload() {
    state = ref.read(databaseProvider).getExpenses();
  }
}

final expensesProvider =
    NotifierProvider<ExpensesNotifier, List<Expense>>(ExpensesNotifier.new);

/// Total expenses for today
final todayExpensesProvider = Provider<double>((ref) {
  final expenses = ref.watch(expensesProvider);
  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  return expenses
      .where((e) => !e.dateTimeValue.isBefore(startOfToday))
      .fold(0.0, (sum, e) => sum + e.amount);
});

/// Total expenses for the current month
final monthExpensesProvider = Provider<double>((ref) {
  final expenses = ref.watch(expensesProvider);
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  return expenses
      .where((e) => !e.dateTimeValue.isBefore(startOfMonth))
      .fold(0.0, (sum, e) => sum + e.amount);
});

/// Total expenses overall
final totalExpensesProvider = Provider<double>((ref) {
  return ref.watch(expensesProvider).fold(0.0, (sum, e) => sum + e.amount);
});
