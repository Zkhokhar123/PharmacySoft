import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_colors.dart';
import '../../core/app_constants.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../state/catalog_providers.dart';
import '../../state/core_providers.dart';
import '../../state/credit_providers.dart';
import '../../state/expenses_providers.dart';
import '../../state/inventory_providers.dart';
import '../../state/purchases_providers.dart';
import '../../state/sales_providers.dart';
import '../../state/supplier_ledger_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _pharmacyName;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _currency;
  late final TextEditingController _lowStock;
  late final TextEditingController _nearExpiry;
  bool _saving = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    _pharmacyName = TextEditingController(text: s.pharmacyName);
    _address = TextEditingController(text: s.address);
    _phone = TextEditingController(text: s.phone);
    _currency = TextEditingController(text: s.currencySymbol);
    _lowStock = TextEditingController(text: s.lowStockThreshold.toString());
    _nearExpiry = TextEditingController(text: s.nearExpiryDays.toString());
  }

  @override
  void dispose() {
    for (final c in [
      _pharmacyName, _address, _phone, _currency, _lowStock, _nearExpiry
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final current = ref.read(settingsProvider);
    await ref.read(settingsProvider.notifier).update(current.copyWith(
          pharmacyName: _pharmacyName.text.trim().isEmpty
              ? AppConstants.defaultPharmacyName
              : _pharmacyName.text.trim(),
          address: _address.text.trim(),
          phone: _phone.text.trim(),
          currencySymbol: _currency.text.trim().isEmpty
              ? AppConstants.defaultCurrencySymbol
              : _currency.text.trim(),
          lowStockThreshold: int.tryParse(_lowStock.text) ??
              AppConstants.defaultLowStockThreshold,
          nearExpiryDays: int.tryParse(_nearExpiry.text) ??
              AppConstants.defaultNearExpiryDays,
        ));
    setState(() {
      _saving = false;
      _saved = true;
    });
    Future.delayed(const Duration(seconds: 2),
        () => mounted ? setState(() => _saved = false) : null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  AppCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Pharmacy Information',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        const Text(
                            'This information appears on every invoice.',
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 12)),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _pharmacyName,
                          decoration: const InputDecoration(
                              labelText: 'Pharmacy Name',
                              prefixIcon: Icon(Icons.local_pharmacy)),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _address,
                          decoration: const InputDecoration(
                              labelText: 'Address',
                              prefixIcon: Icon(Icons.location_on_outlined)),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phone,
                          decoration: const InputDecoration(
                              labelText: 'Phone Number',
                              prefixIcon: Icon(Icons.phone_outlined)),
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Currency & Thresholds',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _currency,
                                decoration: const InputDecoration(
                                  labelText: 'Currency Symbol',
                                  helperText: 'e.g. Rs, USD, EUR',
                                ),
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'Required'
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: TextFormField(
                                controller: _lowStock,
                                decoration: const InputDecoration(
                                  labelText: 'Low Stock Threshold',
                                  helperText:
                                      'Alert when stock ≤ this per product',
                                ),
                                keyboardType: TextInputType.number,
                                validator: (v) =>
                                    int.tryParse(v ?? '') == null
                                        ? 'Enter a whole number'
                                        : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: 300,
                          child: TextFormField(
                            controller: _nearExpiry,
                            decoration: const InputDecoration(
                              labelText: 'Near-Expiry Window (days)',
                              helperText:
                                  'Alert when expiry is within this many days',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) =>
                                int.tryParse(v ?? '') == null
                                    ? 'Enter a whole number'
                                    : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_saved)
                        const Padding(
                          padding: EdgeInsets.only(right: 12),
                          child: Row(children: [
                            Icon(Icons.check_circle,
                                color: AppColors.inStock, size: 18),
                            SizedBox(width: 6),
                            Text('Saved!',
                                style: TextStyle(color: AppColors.inStock)),
                          ]),
                        ),
                      ElevatedButton.icon(
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                            : const Icon(Icons.save),
                        label: const Text('Save Settings'),
                        onPressed: _saving ? null : _save,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  AppCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.backup_outlined,
                                color: AppColors.primary, size: 22),
                            SizedBox(width: 8),
                            Text('Database Backup & Restore',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Export a full JSON backup of all medicines, sales, purchases, batches, customers, suppliers, and expenses. You can restore this backup anytime to recover or migrate your data.',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.download, size: 18),
                              label: const Text('Export Backup (JSON)'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => _showExportBackupDialog(context),
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.upload_file, size: 18),
                              label: const Text('Restore Backup (JSON)'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.accent,
                                side: const BorderSide(
                                    color: AppColors.accent),
                              ),
                              onPressed: () => _showRestoreBackupDialog(context),
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                              label: const Text('Clear All Demo Data'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.outOfStock,
                                side: const BorderSide(
                                    color: AppColors.outOfStock),
                              ),
                              onPressed: () => _confirmClearDemoData(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showExportBackupDialog(BuildContext context) {
    final json = ref.read(databaseProvider).exportBackupJson();
    final kb = (json.length / 1024).toStringAsFixed(1);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.download_done, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Export Backup ($kb KB)'),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Complete backup has been generated. Copy this JSON and save it in a safe place (e.g. text file or cloud drive):',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              Container(
                height: 180,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: SelectableText(
                  json,
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy to Clipboard'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: json));
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Backup JSON copied to clipboard!')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showRestoreBackupDialog(BuildContext context) {
    final textCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.outOfStock),
            SizedBox(width: 8),
            Text('Restore Database Backup'),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.outOfStock.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Warning: Restoring will overwrite existing data in the database with the contents of this backup file.',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.outOfStock),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: textCtrl,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Paste Backup JSON *',
                  hintText: '{\n  "version": 1,\n  "medicines": [...]\n}',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.outOfStock,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final raw = textCtrl.text.trim();
              if (raw.isEmpty) return;

              final ok = await showConfirmDialog(
                context,
                title: 'Confirm Restore',
                message:
                    'Are you sure you want to restore? Current data will be replaced.',
                confirmText: 'Restore Now',
                isDestructive: true,
              );
              if (!ok) return;

              try {
                await ref.read(databaseProvider).restoreBackupJson(raw);
                ref.read(settingsProvider.notifier).reload();
                ref.read(medicinesProvider.notifier).reload();
                ref.read(batchesProvider.notifier).reload();
                ref.read(salesProvider.notifier).reload();
                ref.read(purchasesProvider.notifier).reload();
                ref.read(categoriesProvider.notifier).reload();
                ref.read(suppliersProvider.notifier).reload();
                ref.read(customersProvider.notifier).reload();
                ref.read(creditPaymentsProvider.notifier).reload();
                ref.read(supplierPaymentsProvider.notifier).reload();
                ref.read(expensesProvider.notifier).reload();

                final s = ref.read(settingsProvider);
                setState(() {
                  _pharmacyName.text = s.pharmacyName;
                  _address.text = s.address;
                  _phone.text = s.phone;
                  _currency.text = s.currencySymbol;
                  _lowStock.text = s.lowStockThreshold.toString();
                  _nearExpiry.text = s.nearExpiryDays.toString();
                });

                if (ctx.mounted) Navigator.of(ctx).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Database restored successfully from backup!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Restore failed: $e')),
                  );
                }
              }
            },
            child: const Text('Restore Data'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearDemoData(BuildContext context) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Clear All Demo Data',
      message:
          'Are you sure you want to clear all demo medicines, batches, sales, purchases, suppliers, and expenses? This will leave the software clean and ready for real pharmacy operations.',
      confirmText: 'Clear Demo Data',
      isDestructive: true,
    );
    if (!ok) return;

    await ref.read(databaseProvider).clearAllData();
    ref.read(settingsProvider.notifier).reload();
    ref.read(medicinesProvider.notifier).reload();
    ref.read(batchesProvider.notifier).reload();
    ref.read(salesProvider.notifier).reload();
    ref.read(purchasesProvider.notifier).reload();
    ref.read(categoriesProvider.notifier).reload();
    ref.read(suppliersProvider.notifier).reload();
    ref.read(customersProvider.notifier).reload();
    ref.read(creditPaymentsProvider.notifier).reload();
    ref.read(supplierPaymentsProvider.notifier).reload();
    ref.read(expensesProvider.notifier).reload();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'All demo data cleared. Software is now ready for production!'),
          backgroundColor: AppColors.inStock,
        ),
      );
    }
  }
}
