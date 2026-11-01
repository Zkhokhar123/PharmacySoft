import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../core/formatters.dart';
import '../../core/id_generator.dart';
import '../../data/models/customer.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/empty_state.dart';
import '../../state/catalog_providers.dart';
import '../../state/core_providers.dart';
import '../../state/credit_providers.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider)
        .where((c) => c.id != Customer.walkInId)
        .toList();
    final outstandingMap = ref.watch(outstandingMapProvider);
    final totalOut = ref.watch(totalOutstandingProvider);
    final symbol = ref.watch(settingsProvider).currencySymbol;

    final filtered = _search.isEmpty
        ? customers
        : customers.where((c) {
            final q = _search.toLowerCase();
            return c.name.toLowerCase().contains(q) ||
                c.phone.contains(q);
          }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Customers & Credit'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.person_add, color: AppColors.primary),
            label: const Text('Add Customer',
                style: TextStyle(color: AppColors.primary)),
            onPressed: () => _showAddCustomerDialog(context, ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ── total outstanding banner ──────────────────────────────────
          if (totalOut > 0)
            Container(
              width: double.infinity,
              color: AppColors.nearExpiry.withValues(alpha: 0.12),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                const Icon(Icons.account_balance_wallet,
                    color: AppColors.nearExpiry, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Total Outstanding Credit: ${Formatters.currency(totalOut, symbol: symbol)}',
                  style: const TextStyle(
                      color: AppColors.nearExpiry,
                      fontWeight: FontWeight.w700),
                ),
              ]),
            ),

          // ── search bar ───────────────────────────────────────────────
          Container(
            color: AppColors.surface,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search by name or phone…',
                prefixIcon: Icon(Icons.search, size: 20),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          const Divider(height: 1),

          // ── list ──────────────────────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? EmptyState(
                    icon: Icons.people_outline,
                    title: _search.isEmpty
                        ? 'No customers yet'
                        : 'No results for "$_search"',
                    message: _search.isEmpty
                        ? 'Add a customer to track credit sales.'
                        : null,
                    action: _search.isEmpty
                        ? ElevatedButton.icon(
                            icon: const Icon(Icons.person_add),
                            label: const Text('Add Customer'),
                            onPressed: () =>
                                _showAddCustomerDialog(context, ref),
                          )
                        : null,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final c = filtered[i];
                      final balance =
                          outstandingMap[c.id] ?? 0.0;
                      return _CustomerTile(
                        customer: c,
                        balance: balance,
                        symbol: symbol,
                        onTap: () =>
                            context.go('/customers/ledger/${c.id}'),
                        onDelete: () async {
                          final ok = await showConfirmDialog(
                            context,
                            title: 'Delete Customer',
                            message:
                                'Delete "${c.name}"? Their credit history will also be removed.',
                            confirmText: 'Delete',
                            isDestructive: true,
                          );
                          if (ok) {
                            await ref
                                .read(customersProvider.notifier)
                                .remove(c.id);
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showAddCustomerDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => const _CustomerFormDialog(existing: null),
    );
  }
}

// ── Customer tile ────────────────────────────────────────────────────────────

class _CustomerTile extends StatelessWidget {
  final Customer customer;
  final double balance;
  final String symbol;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _CustomerTile({
    required this.customer,
    required this.balance,
    required this.symbol,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasBalance = balance > 0.005;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          // avatar with initials
          CircleAvatar(
            radius: 24,
            backgroundColor: (hasBalance
                    ? AppColors.nearExpiry
                    : AppColors.primary)
                .withValues(alpha: 0.15),
            child: Text(
              customer.name.isNotEmpty
                  ? customer.name[0].toUpperCase()
                  : '?',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: hasBalance
                      ? AppColors.nearExpiry
                      : AppColors.primary),
            ),
          ),
          const SizedBox(width: 12),

          // name + phone
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
                if (customer.phone.isNotEmpty)
                  Row(children: [
                    const Icon(Icons.phone,
                        size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(customer.phone,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
                  ]),
              ],
            ),
          ),

          // balance badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (hasBalance) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.nearExpiry.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color:
                            AppColors.nearExpiry.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    'Due: ${Formatters.currency(balance, symbol: symbol)}',
                    style: const TextStyle(
                        color: AppColors.nearExpiry,
                        fontWeight: FontWeight.w700,
                        fontSize: 12),
                  ),
                ),
                const SizedBox(height: 4),
                const Text('Tap to pay',
                    style: TextStyle(
                        color: AppColors.textMuted, fontSize: 11)),
              ] else
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.inStock.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Clear',
                      style: TextStyle(
                          color: AppColors.inStock,
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                size: 18, color: AppColors.outOfStock),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ── Add / Edit customer dialog ────────────────────────────────────────────────

class _CustomerFormDialog extends ConsumerStatefulWidget {
  final Customer? existing;
  const _CustomerFormDialog({this.existing});

  @override
  ConsumerState<_CustomerFormDialog> createState() =>
      _CustomerFormDialogState();
}

class _CustomerFormDialogState extends ConsumerState<_CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _notes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _phone = TextEditingController(text: widget.existing?.phone ?? '');
    _address =
        TextEditingController(text: widget.existing?.address ?? '');
    _notes = TextEditingController(text: widget.existing?.notes ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final customer = Customer(
      id: widget.existing?.id ?? IdGenerator.generate('cust'),
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      address: _address.text.trim(),
      notes: _notes.text.trim(),
    );
    if (widget.existing != null) {
      await ref.read(customersProvider.notifier).update(customer);
    } else {
      await ref.read(customersProvider.notifier).add(customer);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(widget.existing != null
          ? 'Edit Customer'
          : 'Add New Customer'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration:
                    const InputDecoration(labelText: 'Full Name *'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                decoration:
                    const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _address,
                decoration: const InputDecoration(labelText: 'Address'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                decoration: const InputDecoration(labelText: 'Notes'),
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
          onPressed: _saving ? null : _save,
          child: Text(widget.existing != null ? 'Update' : 'Add'),
        ),
      ],
    );
  }
}
