import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../core/formatters.dart';
import '../../core/pack_qty.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/status_badge.dart';
import '../../state/catalog_providers.dart';
import '../../state/core_providers.dart';
import '../../state/inventory_providers.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  String _search = '';
  String _filterCategoryId = '';
  String _filterStatus = '';

  @override
  Widget build(BuildContext context) {
    final allStock = ref.watch(medicineStockProvider);
    final categories = ref.watch(categoriesProvider);
    final symbol = ref.watch(settingsProvider).currencySymbol;

    // apply filters
    final filtered = allStock.where((s) {
      final q = _search.toLowerCase();
      final matchSearch = q.isEmpty ||
          s.medicine.name.toLowerCase().contains(q) ||
          s.medicine.genericName.toLowerCase().contains(q) ||
          s.medicine.barcode.contains(q);
      final matchCat = _filterCategoryId.isEmpty ||
          s.medicine.categoryId == _filterCategoryId;
      final matchStatus = _filterStatus.isEmpty ||
          (_filterStatus == 'low' && s.status == StockStatus.lowStock) ||
          (_filterStatus == 'out' && s.status == StockStatus.outOfStock) ||
          (_filterStatus == 'in' && s.status == StockStatus.inStock);
      return matchSearch && matchCat && matchStatus;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Inventory'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.add, color: AppColors.primary),
            label: const Text('Add Medicine',
                style: TextStyle(color: AppColors.primary)),
            onPressed: () => context.go('/inventory/form'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // filters bar
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search by name, generic, barcode…',
                      prefixIcon: Icon(Icons.search, size: 20),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                DropdownButton<String>(
                  value: _filterCategoryId,
                  hint: const Text('All Categories'),
                  underline: const SizedBox.shrink(),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('All Categories')),
                    ...categories.map((c) =>
                        DropdownMenuItem(value: c.id, child: Text(c.name))),
                  ],
                  onChanged: (v) =>
                      setState(() => _filterCategoryId = v ?? ''),
                ),
                DropdownButton<String>(
                  value: _filterStatus,
                  hint: const Text('All Status'),
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('All Status')),
                    DropdownMenuItem(value: 'in', child: Text('In Stock')),
                    DropdownMenuItem(value: 'low', child: Text('Low Stock')),
                    DropdownMenuItem(value: 'out', child: Text('Out of Stock')),
                  ],
                  onChanged: (v) => setState(() => _filterStatus = v ?? ''),
                ),
                Text('${filtered.length} items',
                    style: const TextStyle(color: AppColors.textMuted)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: filtered.isEmpty
                ? EmptyState(
                    icon: Icons.medication_outlined,
                    title: _search.isEmpty
                        ? 'No medicines yet'
                        : 'No results for "$_search"',
                    message: _search.isEmpty
                        ? 'Add your first medicine to get started.'
                        : null,
                    action: _search.isEmpty
                        ? ElevatedButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Add Medicine'),
                            onPressed: () => context.go('/inventory/form'),
                          )
                        : null,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final s = filtered[i];
                      return _MedicineListTile(
                        stockInfo: s,
                        symbol: symbol,
                        onTap: () =>
                            context.go('/inventory/detail/${s.medicine.id}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MedicineListTile extends StatelessWidget {
  final MedicineStockInfo stockInfo;
  final String symbol;
  final VoidCallback onTap;

  const _MedicineListTile({
    required this.stockInfo,
    required this.symbol,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = stockInfo;
    final expBatch = s.nearestExpiryBatch;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.medication, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.medicine.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                if (s.medicine.genericName.isNotEmpty)
                  Text(s.medicine.genericName,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    StockStatusBadge(
                      status: s.status,
                      stock: s.totalStock,
                      stockLabel: PackQty.format(
                        s.totalStock,
                        unitsPerPack: s.medicine.unitsPerPack,
                        unit: s.medicine.unit,
                        packName: s.medicine.packName,
                      ),
                    ),
                    if (expBatch != null)
                      ExpiryBadge(expiryDate: expBatch.expiryDate),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Formatters.currency(s.medicine.salePrice, symbol: symbol),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.primary)),
              Text('${s.batches.length} batch${s.batches.length == 1 ? '' : 'es'}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
