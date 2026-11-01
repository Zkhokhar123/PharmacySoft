import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_colors.dart';
import '../../core/formatters.dart';
import '../../data/models/expense.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/stat_card.dart';
import '../../state/core_providers.dart';
import '../../state/expenses_providers.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  String _search = '';
  String _selectedCategory = 'All';

  static const _categories = [
    'All',
    'Rent',
    'Electricity',
    'Salaries',
    'Tea & Refreshment',
    'Maintenance',
    'Transport',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(expensesProvider);
    final todayExp = ref.watch(todayExpensesProvider);
    final monthExp = ref.watch(monthExpensesProvider);
    final totalExp = ref.watch(totalExpensesProvider);
    final symbol = ref.watch(settingsProvider).currencySymbol;

    final filtered = expenses.where((e) {
      if (_selectedCategory != 'All' && e.category != _selectedCategory) {
        return false;
      }
      if (_search.isNotEmpty) {
        final query = _search.toLowerCase();
        final matchTitle = e.title.toLowerCase().contains(query);
        final matchNotes = e.notes.toLowerCase().contains(query);
        final matchCat = e.category.toLowerCase().contains(query);
        if (!matchTitle && !matchNotes && !matchCat) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Expenses Management'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Expense'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => _showAddExpenseDialog(context),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stat Cards
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 800;
                return GridView.count(
                  crossAxisCount: isWide ? 3 : 1,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: isWide ? 2.8 : 3.8,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    StatCard(
                      title: "Today's Expenses",
                      value: Formatters.currency(todayExp, symbol: symbol),
                      icon: Icons.today,
                      color: AppColors.outOfStock,
                      subtitle: 'Spent today',
                    ),
                    StatCard(
                      title: "This Month's Expenses",
                      value: Formatters.currency(monthExp, symbol: symbol),
                      icon: Icons.calendar_month,
                      color: AppColors.nearExpiry,
                      subtitle: 'Spent this month',
                    ),
                    StatCard(
                      title: 'Total Expenses',
                      value: Formatters.currency(totalExp, symbol: symbol),
                      icon: Icons.account_balance_wallet,
                      color: AppColors.primary,
                      subtitle: '${expenses.length} records in total',
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // Filter Bar
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search, size: 20),
                        hintText: 'Search expense title, category, or notes...',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      onChanged: (v) => setState(() => _search = v.trim()),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Filter Category',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      items: _categories
                          .map((c) =>
                              DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedCategory = v ?? 'All'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Expense List Table
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Expense Records (${filtered.length})',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Filtered Total: ${Formatters.currency(filtered.fold(0.0, (sum, e) => sum + e.amount), symbol: symbol)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.outOfStock),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  if (filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'No expenses found.',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 14),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final e = filtered[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          leading: CircleAvatar(
                            backgroundColor: _getCategoryColor(e.category)
                                .withValues(alpha: 0.15),
                            child: Icon(
                              _getCategoryIcon(e.category),
                              color: _getCategoryColor(e.category),
                              size: 20,
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(e.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getCategoryColor(e.category)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  e.category,
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _getCategoryColor(e.category)),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text(
                                Formatters.dateTime(e.dateTimeValue),
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textMuted),
                              ),
                              if (e.notes.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  e.notes,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                      fontStyle: FontStyle.italic),
                                ),
                              ],
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '- ${Formatters.currency(e.amount, symbol: symbol)}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: AppColors.outOfStock),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: AppColors.textMuted, size: 20),
                                onPressed: () =>
                                    _confirmDelete(context, ref, e),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Rent':
        return Colors.indigo;
      case 'Electricity':
        return Colors.amber.shade800;
      case 'Salaries':
        return Colors.purple;
      case 'Tea & Refreshment':
        return Colors.brown;
      case 'Maintenance':
        return Colors.orange;
      case 'Transport':
        return Colors.teal;
      default:
        return AppColors.textMuted;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Rent':
        return Icons.store_mall_directory_outlined;
      case 'Electricity':
        return Icons.bolt;
      case 'Salaries':
        return Icons.people_outline;
      case 'Tea & Refreshment':
        return Icons.coffee_outlined;
      case 'Maintenance':
        return Icons.build_outlined;
      case 'Transport':
        return Icons.local_shipping_outlined;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  void _showAddExpenseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const _AddExpenseDialog(),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Expense expense) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete Expense',
      message: 'Delete expense "${expense.title}"? This cannot be undone.',
      confirmText: 'Delete',
      isDestructive: true,
    );
    if (ok) {
      await ref.read(expensesProvider.notifier).remove(expense.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense deleted successfully.')),
        );
      }
    }
  }
}

class _AddExpenseDialog extends ConsumerStatefulWidget {
  const _AddExpenseDialog();

  @override
  ConsumerState<_AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends ConsumerState<_AddExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _category = 'Rent';
  DateTime _date = DateTime.now();
  bool _saving = false;

  static const _categoryOptions = [
    'Rent',
    'Electricity',
    'Salaries',
    'Tea & Refreshment',
    'Maintenance',
    'Transport',
    'Other',
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amt = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amt <= 0) return;

    setState(() => _saving = true);
    await ref.read(expensesProvider.notifier).add(
          title: _titleCtrl.text.trim(),
          category: _category,
          amount: amt,
          date: _date,
          notes: _notesCtrl.text.trim(),
        );

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final symbol = ref.watch(settingsProvider).currencySymbol;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Row(
        children: [
          Icon(Icons.add_circle_outline, color: AppColors.primary),
          SizedBox(width: 8),
          Text('Add Operating Expense'),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Title / Purpose *',
                  hintText: 'e.g. Monthly Shop Rent, Tea for staff',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: _categoryOptions
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v ?? 'Other'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount *',
                  prefixText: '$symbol ',
                ),
                validator: (v) {
                  final d = double.tryParse(v ?? '');
                  if (d == null || d <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() => _date = picked);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    suffixIcon: Icon(Icons.calendar_today, size: 18),
                  ),
                  child: Text(Formatters.date(_date)),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Bill number, person paid, details...',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Save Expense'),
        ),
      ],
    );
  }
}
