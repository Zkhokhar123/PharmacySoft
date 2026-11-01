import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../core/formatters.dart';
import '../../core/id_generator.dart';
import '../../data/models/supplier.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/empty_state.dart';
import '../../state/catalog_providers.dart';
import '../../state/core_providers.dart';
import '../../state/supplier_ledger_providers.dart';

class SuppliersScreen extends ConsumerWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliers = ref.watch(suppliersProvider);
    final symbol = ref.watch(settingsProvider).currencySymbol;

    final totalMaalAya = suppliers.fold<double>(0.0, (s, sup) => s + sup.totalBilled);
    final totalCashDiya = suppliers.fold<double>(0.0, (s, sup) => s + sup.paidAmount);
    final totalBaqi = suppliers.fold<double>(0.0, (s, sup) => s + sup.balance);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Suppliers & Khata'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.add, color: AppColors.primary),
            label: const Text('Add Supplier',
                style: TextStyle(color: AppColors.primary)),
            onPressed: () => _showForm(context, ref, null),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: suppliers.isEmpty
          ? EmptyState(
              icon: Icons.local_shipping_outlined,
              title: 'No suppliers yet',
              action: ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Supplier'),
                onPressed: () => _showForm(context, ref, null),
              ),
            )
          : Column(
              children: [
                // ── top overall summary bar ──────────────────────────────
                Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Wrap(
                    spacing: 24,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${suppliers.length} Supplier${suppliers.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      Wrap(
                        spacing: 16,
                        runSpacing: 6,
                        children: [
                          _SummaryChip(
                            label: 'Total Maal Aya',
                            value: Formatters.currency(totalMaalAya, symbol: symbol),
                            color: AppColors.primaryDark,
                          ),
                          _SummaryChip(
                            label: 'Total Cash Diya',
                            value: Formatters.currency(totalCashDiya, symbol: symbol),
                            color: AppColors.inStock,
                          ),
                          _SummaryChip(
                            label: 'Total Baqi (Payable)',
                            value: Formatters.currency(totalBaqi, symbol: symbol),
                            color: totalBaqi > 0.005 ? AppColors.nearExpiry : AppColors.inStock,
                            isBold: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // ── suppliers list ───────────────────────────────────────
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: suppliers.length,
                    itemBuilder: (context, i) {
                      final sup = suppliers[i];
                      final hasBaqi = sup.balance > 0.005;

                      return AppCard(
                        onTap: () => context.go('/suppliers/ledger/${sup.id}'),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              backgroundColor: (hasBaqi
                                      ? AppColors.nearExpiry
                                      : AppColors.primary)
                                  .withValues(alpha: 0.12),
                              radius: 22,
                              child: Icon(
                                Icons.local_shipping,
                                color: hasBaqi
                                    ? AppColors.nearExpiry
                                    : AppColors.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            // Supplier contact details
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sup.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16),
                                  ),
                                  const SizedBox(height: 2),
                                  if (sup.contactPerson.isNotEmpty)
                                    Text(
                                      'Contact: ${sup.contactPerson}',
                                      style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 13),
                                    ),
                                  if (sup.phone.isNotEmpty)
                                    Row(
                                      children: [
                                        const Icon(Icons.phone,
                                            size: 12,
                                            color: AppColors.textMuted),
                                        const SizedBox(width: 4),
                                        Text(
                                          sup.phone,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Khata figures (Maal Aya, Cash Diya, Baqi)
                            Expanded(
                              flex: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: (hasBaqi
                                          ? AppColors.nearExpiry
                                          : AppColors.inStock)
                                      .withValues(alpha: 0.07),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: (hasBaqi
                                            ? AppColors.nearExpiry
                                            : AppColors.inStock)
                                        .withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _KhataColumn(
                                      label: 'Maal Aya',
                                      value: Formatters.currency(
                                          sup.totalBilled,
                                          symbol: symbol),
                                      color: AppColors.primaryDark,
                                    ),
                                    const Text('•',
                                        style: TextStyle(
                                            color: AppColors.border,
                                            fontSize: 18)),
                                    _KhataColumn(
                                      label: 'Cash Diya',
                                      value: Formatters.currency(
                                          sup.paidAmount,
                                          symbol: symbol),
                                      color: AppColors.inStock,
                                    ),
                                    const Text('•',
                                        style: TextStyle(
                                            color: AppColors.border,
                                            fontSize: 18)),
                                    _KhataColumn(
                                      label: 'Baqi (Dena Hai)',
                                      value: Formatters.currency(
                                          sup.balance,
                                          symbol: symbol),
                                      color: hasBaqi
                                          ? AppColors.nearExpiry
                                          : AppColors.inStock,
                                      isBold: true,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Actions
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.history, size: 16),
                                  label: const Text('Khata Details',
                                      style: TextStyle(fontSize: 12)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    side: const BorderSide(
                                        color: AppColors.primary),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                    minimumSize: const Size(0, 32),
                                  ),
                                  onPressed: () => context
                                      .go('/suppliers/ledger/${sup.id}'),
                                ),
                                const SizedBox(width: 6),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.add_card, size: 16),
                                  label: const Text('Cash Jama',
                                      style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: hasBaqi
                                        ? AppColors.accent
                                        : AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                    minimumSize: const Size(0, 32),
                                  ),
                                  onPressed: () => _showQuickPaymentDialog(
                                      context, ref, sup, symbol),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined,
                                      size: 20),
                                  tooltip: 'Edit Supplier & Hisaab',
                                  color: AppColors.primary,
                                  onPressed: () =>
                                      _showForm(context, ref, sup),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 20),
                                  tooltip: 'Delete Supplier',
                                  color: AppColors.outOfStock,
                                  onPressed: () async {
                                    final ok = await showConfirmDialog(
                                      context,
                                      title: 'Delete Supplier',
                                      message: 'Delete "${sup.name}"?',
                                      confirmText: 'Delete',
                                      isDestructive: true,
                                    );
                                    if (ok) {
                                      await ref
                                          .read(suppliersProvider.notifier)
                                          .remove(sup.id);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  void _showQuickPaymentDialog(BuildContext context, WidgetRef ref,
      Supplier supplier, String symbol) {
    final addPaidCtrl = TextEditingController(
      text: supplier.balance > 0 ? supplier.balance.toStringAsFixed(0) : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cash Jama Karein — ${supplier.name}'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.nearExpiry.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Current Baqi: ',
                        style: TextStyle(fontSize: 13)),
                    Text(
                      Formatters.currency(supplier.balance, symbol: symbol),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.nearExpiry,
                      ),
                    ),
                  ],
                ),
              ),
              TextField(
                controller: addPaidCtrl,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Jama Karwayi Raqam (Cash Diya)',
                  prefixText: '$symbol ',
                  hintText: 'e.g. 10000',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Yeh raqam pehle se diye gaye cash mein add ho jaye gi aur baqi khud kam ho jaye ga.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final added = double.tryParse(addPaidCtrl.text.trim());
              if (added == null || added <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid amount')),
                );
                return;
              }
              final newPaid = supplier.paidAmount + added;
              await ref.read(suppliersProvider.notifier).update(
                    supplier.copyWith(paidAmount: newPaid),
                  );
              await ref.read(supplierPaymentsProvider.notifier).add(
                    supplierId: supplier.id,
                    supplierName: supplier.name,
                    amount: added,
                    paymentMethod: 'Cash',
                    notes: 'Direct cash payment',
                  );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Jama Karein'),
          ),
        ],
      ),
    );
  }

  void _showForm(BuildContext context, WidgetRef ref, Supplier? existing) {
    showDialog(
      context: context,
      builder: (context) => _SupplierFormDialog(existing: existing),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isBold;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _KhataColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isBold;

  const _KhataColumn({
    required this.label,
    required this.value,
    required this.color,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _SupplierFormDialog extends ConsumerStatefulWidget {
  final Supplier? existing;
  const _SupplierFormDialog({this.existing});

  @override
  ConsumerState<_SupplierFormDialog> createState() =>
      _SupplierFormDialogState();
}

class _SupplierFormDialogState extends ConsumerState<_SupplierFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _contact;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _notes;
  late final TextEditingController _totalBilled;
  late final TextEditingController _paidAmount;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    _name = TextEditingController(text: s?.name ?? '');
    _contact = TextEditingController(text: s?.contactPerson ?? '');
    _phone = TextEditingController(text: s?.phone ?? '');
    _email = TextEditingController(text: s?.email ?? '');
    _address = TextEditingController(text: s?.address ?? '');
    _notes = TextEditingController(text: s?.notes ?? '');
    _totalBilled = TextEditingController(
        text: s != null && s.totalBilled > 0 ? s.totalBilled.toStringAsFixed(0) : '0');
    _paidAmount = TextEditingController(
        text: s != null && s.paidAmount > 0 ? s.paidAmount.toStringAsFixed(0) : '0');
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _contact,
      _phone,
      _email,
      _address,
      _notes,
      _totalBilled,
      _paidAmount
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final billed = double.tryParse(_totalBilled.text.trim()) ?? 0.0;
    final paid = double.tryParse(_paidAmount.text.trim()) ?? 0.0;

    final supplier = Supplier(
      id: widget.existing?.id ?? IdGenerator.generate('sup'),
      name: _name.text.trim(),
      contactPerson: _contact.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      address: _address.text.trim(),
      notes: _notes.text.trim(),
      totalBilled: billed,
      paidAmount: paid,
    );
    if (widget.existing != null) {
      await ref.read(suppliersProvider.notifier).update(supplier);
    } else {
      await ref.read(suppliersProvider.notifier).add(supplier);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final symbol = ref.watch(settingsProvider).currencySymbol;
    final billed = double.tryParse(_totalBilled.text.trim()) ?? 0.0;
    final paid = double.tryParse(_paidAmount.text.trim()) ?? 0.0;
    final baqi = billed - paid;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(
          widget.existing != null ? 'Edit Supplier & Hisaab' : 'Add Supplier & Hisaab'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _name,
                  decoration:
                      const InputDecoration(labelText: 'Supplier Name *'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _contact,
                    decoration:
                        const InputDecoration(labelText: 'Contact Person')),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: TextFormField(
                          controller: _phone,
                          decoration:
                              const InputDecoration(labelText: 'Phone'))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: TextFormField(
                          controller: _email,
                          decoration:
                              const InputDecoration(labelText: 'Email'))),
                ]),
                const SizedBox(height: 16),

                // ── Khata Box (Maal Aya, Cash Diya, Baqi) ───────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Supplier Ka Khata / Hisaab',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppColors.primaryDark),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _totalBilled,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Maal Aya (Total Bill)',
                                prefixText: '$symbol ',
                                isDense: true,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _paidAmount,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              decoration: InputDecoration(
                                labelText: 'Cash Diya (Paid)',
                                prefixText: '$symbol ',
                                isDense: true,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: (baqi > 0.005
                                  ? AppColors.nearExpiry
                                  : AppColors.inStock)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Baqi (Kitna Dena Hai):',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: baqi > 0.005
                                    ? AppColors.nearExpiry
                                    : AppColors.inStock,
                              ),
                            ),
                            Text(
                              Formatters.currency(baqi, symbol: symbol),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: baqi > 0.005
                                    ? AppColors.nearExpiry
                                    : AppColors.inStock,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                TextFormField(
                    controller: _address,
                    decoration:
                        const InputDecoration(labelText: 'Address'),
                    maxLines: 2),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _notes,
                    decoration:
                        const InputDecoration(labelText: 'Notes'),
                    maxLines: 2),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: Text(widget.existing != null ? 'Update' : 'Add'),
        ),
      ],
    );
  }
}
