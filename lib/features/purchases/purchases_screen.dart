import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../core/formatters.dart';
import '../../data/models/purchase.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/empty_state.dart';
import '../../state/core_providers.dart';
import '../../state/purchases_providers.dart';

class PurchasesScreen extends ConsumerStatefulWidget {
  const PurchasesScreen({super.key});

  @override
  ConsumerState<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends ConsumerState<PurchasesScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final purchases = ref.watch(purchasesProvider);
    final symbol = ref.watch(settingsProvider).currencySymbol;
    final filtered = _search.isEmpty
        ? purchases
        : purchases.where((p) {
            final q = _search.toLowerCase();
            return p.purchaseNumber.toLowerCase().contains(q) ||
                p.supplierName.toLowerCase().contains(q);
          }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Purchases / Stock-In'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.add, color: AppColors.primary),
            label: const Text('New Purchase',
                style: TextStyle(color: AppColors.primary)),
            onPressed: () => context.go('/purchases/form'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search by PO# or supplier…',
                      prefixIcon: Icon(Icons.search, size: 20),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                const SizedBox(width: 12),
                Text('${filtered.length} records',
                    style: const TextStyle(color: AppColors.textMuted)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: filtered.isEmpty
                ? EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: _search.isEmpty
                        ? 'No purchases yet'
                        : 'No results',
                    action: _search.isEmpty
                        ? ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('New Purchase'),
                            onPressed: () => context.go('/purchases/form'),
                          )
                        : null,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final pur = filtered[i];
                      return AppCard(
                        onTap: () =>
                            _showPurchaseDetailDialog(context, pur, symbol),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primaryDark
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.inventory_2,
                                  color: AppColors.primaryDark, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(pur.purchaseNumber,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15)),
                                  if (pur.supplierName.isNotEmpty)
                                    Text(pur.supplierName,
                                        style: const TextStyle(
                                            color: AppColors.textMuted,
                                            fontSize: 13)),
                                  Text(
                                      Formatters.dateTime(
                                          pur.dateTimeValue),
                                      style: const TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                    Formatters.currency(pur.total,
                                        symbol: symbol),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: AppColors.primaryDark)),
                                Text(
                                    '${pur.items.length} item${pur.items.length == 1 ? '' : 's'}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted)),
                              ],
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  size: 18, color: AppColors.outOfStock),
                              onPressed: () async {
                                final ok = await showConfirmDialog(
                                  context,
                                  title: 'Delete Purchase',
                                  message:
                                      'Delete ${pur.purchaseNumber}? Stock added by this shipment and supplier balance will be reversed.',
                                  confirmText: 'Delete',
                                  isDestructive: true,
                                );
                                if (ok && context.mounted) {
                                  await ref
                                      .read(purchasesProvider.notifier)
                                      .remove(pur.id, revertStock: true);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            '${pur.purchaseNumber} deleted and stock reversed.'),
                                      ),
                                    );
                                  }
                                }
                              },
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

  void _showPurchaseDetailDialog(
      BuildContext context, Purchase pur, String symbol) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.inventory_2, color: AppColors.primaryDark),
            const SizedBox(width: 8),
            Expanded(child: Text('${pur.purchaseNumber} — Stock Details')),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Supplier: ${pur.supplierName.isEmpty ? 'Unknown' : pur.supplierName}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.access_time,
                                size: 12, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              Formatters.dateTime(pur.dateTimeValue),
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      Formatters.currency(pur.total, symbol: symbol),
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryDark),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text('Items received in this shipment:',
                  style:
                      TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: pur.items.map((item) {
                      final qtyText = item.packQty > 0
                          ? '${item.packQty} ${item.packName} (${item.quantity} ${item.unit})'
                          : '${item.quantity} ${item.unit}';
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: const BoxDecoration(
                          border: Border(
                              bottom: BorderSide(
                                  color: AppColors.border, width: 0.5)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(item.medicineName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                  Text(
                                    'Batch: ${item.batchNumber}  •  Exp: ${Formatters.date(DateTime.fromMillisecondsSinceEpoch(item.expiryDate))}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(qtyText,
                                  style: const TextStyle(fontSize: 12)),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                Formatters.currency(item.lineTotal,
                                    symbol: symbol),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
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
        ],
      ),
    );
  }
}
