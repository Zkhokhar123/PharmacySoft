import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../core/formatters.dart';
import '../../core/pack_qty.dart';
import '../../data/models/batch.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/status_badge.dart';
import '../../state/catalog_providers.dart';
import '../../state/core_providers.dart';
import '../../state/inventory_providers.dart';

class MedicineDetailScreen extends ConsumerWidget {
  final String medicineId;
  const MedicineDetailScreen({super.key, required this.medicineId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stock = ref.watch(medicineStockProvider);
    final info = stock.where((s) => s.medicine.id == medicineId).firstOrNull;
    final symbol = ref.watch(settingsProvider).currencySymbol;
    final catMap = ref.watch(categoryMapProvider);
    final supMap = ref.watch(supplierMapProvider);

    if (info == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Medicine Detail')),
        body: const Center(child: Text('Medicine not found')),
      );
    }

    final med = info.medicine;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(med.name),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        leading: BackButton(onPressed: () => context.go('/inventory')),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.add_shopping_cart, color: AppColors.primary),
            label: const Text('Add Stock',
                style: TextStyle(color: AppColors.primary)),
            onPressed: () =>
                context.go('/purchases/form?medicineId=$medicineId'),
          ),
          TextButton.icon(
            icon: const Icon(Icons.edit, color: AppColors.primary),
            label: const Text('Edit', style: TextStyle(color: AppColors.primary)),
            onPressed: () => context.go('/inventory/form?id=$medicineId'),
          ),
          TextButton.icon(
            icon: const Icon(Icons.delete, color: AppColors.outOfStock),
            label: const Text('Delete',
                style: TextStyle(color: AppColors.outOfStock)),
            onPressed: () async {
              final ok = await showConfirmDialog(
                context,
                title: 'Delete Medicine',
                message:
                    'Delete "${med.name}" and all its batches? This cannot be undone.',
                confirmText: 'Delete',
                isDestructive: true,
              );
              if (ok && context.mounted) {
                await ref.read(medicinesProvider.notifier).remove(med.id);
                if (context.mounted) context.go('/inventory');
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product card
            AppCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.medication,
                        color: AppColors.primary, size: 40),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(med.name,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w700)),
                        if (med.genericName.isNotEmpty)
                          Text(med.genericName,
                              style: const TextStyle(
                                  color: AppColors.textMuted, fontSize: 14)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            StockStatusBadge(
                              status: info.status,
                              stock: info.totalStock,
                              stockLabel: PackQty.format(
                                info.totalStock,
                                unitsPerPack: med.unitsPerPack,
                                unit: med.unit,
                                packName: med.packName,
                              ),
                            ),
                            if (info.nearestExpiryBatch != null)
                              ExpiryBadge(
                                  expiryDate:
                                      info.nearestExpiryBatch!.expiryDate),
                            if (med.shelfLocation.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: AppColors.primary
                                          .withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.shelves,
                                        size: 14, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Text('Shelf: ${med.shelfLocation}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Details grid
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Product Details',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const Divider(height: 18),
                  Wrap(
                    spacing: 24,
                    runSpacing: 12,
                    children: [
                      _Detail(
                          label: 'Category',
                          value: catMap[med.categoryId]?.name ?? '-'),
                      _Detail(label: 'Manufacturer', value: med.manufacturer.isEmpty ? '-' : med.manufacturer),
                      _Detail(label: 'Unit', value: med.unit),
                      _Detail(label: 'Pack', value: '1 ${med.packName} = ${med.unitsPerPack} ${med.unit}'),
                      _Detail(label: 'Barcode', value: med.barcode.isEmpty ? '-' : med.barcode),
                      _Detail(
                          label: 'Total Stock',
                          value: PackQty.format(
                            info.totalStock,
                            unitsPerPack: med.unitsPerPack,
                            unit: med.unit,
                            packName: med.packName,
                          )),
                      _Detail(label: 'Stock Value', value: Formatters.currency(info.stockValue, symbol: symbol)),
                      _Detail(label: 'Sale Price', value: Formatters.currency(med.salePrice, symbol: symbol)),
                      _Detail(label: 'Purchase Price', value: Formatters.currency(med.purchasePrice, symbol: symbol)),
                      _Detail(label: 'Reorder Level', value: '${med.reorderLevel} ${med.unit}'),
                      _Detail(label: 'Shelf / Location', value: med.shelfLocation.isEmpty ? '-' : med.shelfLocation),
                    ],
                  ),
                  if (med.description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Description',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(med.description),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Batches
            Row(
              children: [
                const Text('Batches',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Text('(${info.batches.length})',
                    style: const TextStyle(color: AppColors.textMuted)),
                const Spacer(),
                OutlinedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Stock-In'),
                  onPressed: () =>
                      context.go('/purchases/form?medicineId=$medicineId'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (info.batches.isEmpty)
              AppCard(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(Icons.inventory_2_outlined,
                            size: 36, color: AppColors.textMuted),
                        const SizedBox(height: 8),
                        const Text('No stock batches found yet.',
                            style: TextStyle(color: AppColors.textMuted)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add_shopping_cart, size: 18),
                          label: const Text('Add Stock / Purchase'),
                          onPressed: () => context.go(
                              '/purchases/form?medicineId=$medicineId'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ...info.batches.map((b) => _BatchCard(
                    batch: b,
                    symbol: symbol,
                    supplierName: supMap[b.supplierId]?.name ?? '',
                  )),
          ],
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  final String label;
  final String value;
  const _Detail({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }
}

class _BatchCard extends ConsumerWidget {
  final Batch batch;
  final String symbol;
  final String supplierName;
  const _BatchCard(
      {required this.batch,
      required this.symbol,
      required this.supplierName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.inventory_2_outlined,
                      size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text('Batch: ${batch.batchNumber}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 6),
                Wrap(spacing: 16, runSpacing: 4, children: [
                  _BatchDetail('Qty', '${batch.quantity}'),
                  _BatchDetail('Sale',
                      Formatters.currency(batch.salePrice, symbol: symbol)),
                  _BatchDetail('Purchase',
                      Formatters.currency(batch.purchasePrice, symbol: symbol)),
                  if (supplierName.isNotEmpty)
                    _BatchDetail('Supplier', supplierName),
                  if (batch.receivedDate > 0)
                    _BatchDetail(
                        'Received',
                        Formatters.date(DateTime.fromMillisecondsSinceEpoch(
                            batch.receivedDate))),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ExpiryBadge(expiryDate: batch.expiryDate, size: 12),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Adjust Stock / Breakage / Wastage',
            icon: const Icon(Icons.tune, size: 20, color: AppColors.textMuted),
            onPressed: () => _showAdjustStockDialog(context, ref, batch),
          ),
        ],
      ),
    );
  }

  void _showAdjustStockDialog(BuildContext context, WidgetRef ref, Batch batch) {
    final qtyCtrl = TextEditingController(text: '${batch.quantity}');
    final notesCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.inventory, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Adjust Batch ${batch.batchNumber}'),
          ],
        ),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current Stock: ${batch.quantity}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'New Correct Quantity *',
                  hintText: 'Enter physical count',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reason (Breakage / Wastage / Audit)',
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
            onPressed: () async {
              final newQty = int.tryParse(qtyCtrl.text.trim());
              if (newQty == null || newQty < 0) return;
              await ref.read(batchesProvider.notifier).setQuantity(batch.id, newQty);
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Batch ${batch.batchNumber} stock adjusted to $newQty.'),
                  ),
                );
              }
            },
            child: const Text('Update Stock'),
          ),
        ],
      ),
    );
  }
}

class _BatchDetail extends StatelessWidget {
  final String label;
  final String value;
  const _BatchDetail(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
        children: [
          TextSpan(
              text: '$label: ',
              style: const TextStyle(color: AppColors.textMuted)),
          TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
