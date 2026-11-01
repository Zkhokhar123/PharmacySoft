import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../core/formatters.dart';
import '../../data/models/sale.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/empty_state.dart';
import '../../state/core_providers.dart';
import '../../state/sales_providers.dart';
import 'thermal_receipt.dart';

enum _DateFilter { all, today, week, month }

class SalesHistoryScreen extends ConsumerStatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  ConsumerState<SalesHistoryScreen> createState() => _SalesHistoryState();
}

class _SalesHistoryState extends ConsumerState<SalesHistoryScreen> {
  String _search = '';
  _DateFilter _dateFilter = _DateFilter.all;
  String _payFilter = '';
  final Set<String> _expanded = {};

  bool _inDateRange(Sale s) {
    final d = s.dateTimeValue;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (_dateFilter) {
      _DateFilter.all => true,
      _DateFilter.today => !d.isBefore(today),
      _DateFilter.week => !d.isBefore(today.subtract(const Duration(days: 7))),
      _DateFilter.month => !d.isBefore(DateTime(now.year, now.month, 1)),
    };
  }

  @override
  Widget build(BuildContext context) {
    final sales = ref.watch(salesProvider);
    final symbol = ref.watch(settingsProvider).currencySymbol;

    final filtered = sales.where((s) {
      if (!_inDateRange(s)) return false;
      if (_payFilter == 'unpaid' && s.isFullyPaid) return false;
      if (_payFilter.isNotEmpty &&
          _payFilter != 'unpaid' &&
          s.paymentMethod != _payFilter) {
        return false;
      }
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      final inItems = s.items.any(
          (i) => i.medicineName.toLowerCase().contains(q));
      return s.invoiceNumber.toLowerCase().contains(q) ||
          s.customerName.toLowerCase().contains(q) ||
          inItems;
    }).toList();

    final invoiceCount = filtered.length;
    final revenue = filtered.fold(0.0, (sum, s) => sum + s.total);
    final paid = filtered.fold(0.0, (sum, s) => sum + s.paid);
    final credit = filtered.fold(0.0, (sum, s) => sum + (s.balance > 0 ? s.balance : 0));
    final units = filtered.fold(0, (sum, s) => sum + s.itemCount);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Sales History'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.point_of_sale, color: AppColors.primary),
            label: const Text('New Sale',
                style: TextStyle(color: AppColors.primary)),
            onPressed: () => context.go('/pos'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search invoice, customer or medicine…',
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
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final f in _DateFilter.values)
                      ChoiceChip(
                        label: Text(switch (f) {
                          _DateFilter.all => 'All',
                          _DateFilter.today => 'Today',
                          _DateFilter.week => '7 days',
                          _DateFilter.month => 'This month',
                        }),
                        selected: _dateFilter == f,
                        onSelected: (_) => setState(() => _dateFilter = f),
                      ),
                    const SizedBox(width: 8),
                    for (final p in const [
                      ('', 'All pay'),
                      ('Cash', 'Cash'),
                      ('Card', 'Card'),
                      ('Online', 'Online'),
                      ('Credit', 'Credit'),
                      ('unpaid', 'Unpaid'),
                    ])
                      FilterChip(
                        label: Text(p.$2),
                        selected: _payFilter == p.$1,
                        onSelected: (_) => setState(
                            () => _payFilter = _payFilter == p.$1 ? '' : p.$1),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                LayoutBuilder(builder: (context, constraints) {
                  final wide = constraints.maxWidth > 720;
                  final cards = [
                    _SummaryChip(
                      label: 'Invoices',
                      value: '$invoiceCount',
                      icon: Icons.receipt_long,
                      color: AppColors.primary,
                    ),
                    _SummaryChip(
                      label: 'Revenue',
                      value: Formatters.currency(revenue, symbol: symbol),
                      icon: Icons.payments_outlined,
                      color: AppColors.inStock,
                    ),
                    _SummaryChip(
                      label: 'Collected',
                      value: Formatters.currency(paid, symbol: symbol),
                      icon: Icons.account_balance_wallet_outlined,
                      color: AppColors.accent,
                    ),
                    _SummaryChip(
                      label: 'Credit due',
                      value: Formatters.currency(credit, symbol: symbol),
                      icon: Icons.hourglass_bottom,
                      color: AppColors.nearExpiry,
                    ),
                    _SummaryChip(
                      label: 'Units sold',
                      value: '$units',
                      icon: Icons.medication_outlined,
                      color: AppColors.primaryDark,
                    ),
                  ];
                  if (wide) {
                    return Row(
                      children: [
                        for (var i = 0; i < cards.length; i++) ...[
                          Expanded(child: cards[i]),
                          if (i < cards.length - 1) const SizedBox(width: 8),
                        ],
                      ],
                    );
                  }
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: cards
                        .map((c) => SizedBox(width: 160, child: c))
                        .toList(),
                  );
                }),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: filtered.isEmpty
                ? EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: _search.isEmpty && _payFilter.isEmpty
                        ? 'No sales yet'
                        : 'No matching sales',
                    action: _search.isEmpty
                        ? ElevatedButton.icon(
                            icon: const Icon(Icons.point_of_sale),
                            label: const Text('New Sale'),
                            onPressed: () => context.go('/pos'),
                          )
                        : null,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final sale = filtered[i];
                      final open = _expanded.contains(sale.id);
                      return _SaleCard(
                        sale: sale,
                        symbol: symbol,
                        expanded: open,
                        onToggle: () => setState(() {
                          if (open) {
                            _expanded.remove(sale.id);
                          } else {
                            _expanded.add(sale.id);
                          }
                        }),
                        onOpen: () =>
                            context.go('/sales/invoice/${sale.id}'),
                        onPrint: () {
                          final settings = ref.read(settingsProvider);
                          ThermalReceipt.printReceipt(sale, settings);
                        },
                        onDelete: () async {
                          final ok = await showConfirmDialog(
                            context,
                            title: 'Delete Sale',
                            message:
                                'Delete invoice ${sale.invoiceNumber}? Note: stock is NOT restored.',
                            confirmText: 'Delete',
                            isDestructive: true,
                          );
                          if (ok) {
                            await ref
                                .read(salesProvider.notifier)
                                .remove(sale.id);
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
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: color)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SaleCard extends StatelessWidget {
  final Sale sale;
  final String symbol;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onOpen;
  final VoidCallback onPrint;
  final VoidCallback onDelete;

  const _SaleCard({
    required this.sale,
    required this.symbol,
    required this.expanded,
    required this.onToggle,
    required this.onOpen,
    required this.onPrint,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final unpaid = sale.balance > 0.005;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        children: [
          InkWell(
            onTap: onOpen,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (unpaid ? AppColors.nearExpiry : AppColors.accent)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.receipt_long,
                      color: unpaid ? AppColors.nearExpiry : AppColors.accent,
                      size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sale.invoiceNumber,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      Text(sale.customerName,
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 13)),
                      Text(Formatters.dateTime(sale.dateTimeValue),
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(Formatters.currency(sale.total, symbol: symbol),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.primary)),
                    const SizedBox(height: 4),
                    _PayBadge(sale: sale),
                    Text(
                      '${sale.itemCount} ${sale.itemCount == 1 ? 'unit' : 'units'}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: 'Print Thermal Receipt',
                  icon: const Icon(Icons.print_outlined,
                      size: 20, color: AppColors.primary),
                  onPressed: onPrint,
                ),
                IconButton(
                  icon: Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textMuted,
                  ),
                  onPressed: onToggle,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: AppColors.outOfStock),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
          if (expanded) ...[
            const Divider(height: 16),
            for (final item in sale.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.medication_outlined,
                        size: 16, color: AppColors.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(item.medicineName,
                          style: const TextStyle(fontSize: 13)),
                    ),
                    Text(
                      '${item.quantity} ${item.unit}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      Formatters.currency(item.lineTotal, symbol: symbol),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                ),
              ),
            if (unpaid)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Balance due: ${Formatters.currency(sale.balance, symbol: symbol)}',
                  style: const TextStyle(
                      color: AppColors.nearExpiry,
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onOpen,
                child: const Text('Open invoice'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PayBadge extends StatelessWidget {
  final Sale sale;
  const _PayBadge({required this.sale});

  @override
  Widget build(BuildContext context) {
    final unpaid = sale.balance > 0.005;
    final label = unpaid
        ? (sale.paid > 0 ? 'Partial' : 'Credit')
        : sale.paymentMethod;
    final color = unpaid ? AppColors.nearExpiry : AppColors.inStock;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
