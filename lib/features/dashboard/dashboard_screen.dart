import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/app_colors.dart';
import '../../core/formatters.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/stat_card.dart';
import '../../shared/widgets/status_badge.dart';
import '../../state/core_providers.dart';
import '../../state/dashboard_providers.dart';
import '../../state/inventory_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats    = ref.watch(dashboardStatsProvider);
    final symbol   = ref.watch(settingsProvider).currencySymbol;
    final pharmacy = ref.watch(settingsProvider).pharmacyName;
    final lowStock  = ref.watch(lowStockProvider);
    final nearExpiry = ref.watch(nearExpiryBatchesProvider);
    final medMap   = {for (final m in ref.watch(medicinesProvider)) m.id: m.name};

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── gradient app bar ──────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 110,
            pinned: true,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              title: Row(
                children: [
                  const Icon(Icons.local_pharmacy, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pharmacy,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    Formatters.date(DateTime.now()),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),

          // ── body ─────────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── stat cards ────────────────────────────────────────────
                LayoutBuilder(builder: (ctx, box) {
                  final cols = box.maxWidth > 1100 ? 4
                             : box.maxWidth > 700  ? 2
                             : 1;
                  final w = (box.maxWidth - (cols - 1) * 14) / cols;
                  return Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: [
                      // Financials Row
                      SizedBox(width: w, child: StatCard(
                        title: "Today's Sales",
                        value: Formatters.currencyCompact(stats.todaySales, symbol: symbol),
                        subtitle: '${stats.todaySalesCount} invoice${stats.todaySalesCount == 1 ? '' : 's'}',
                        icon: Icons.point_of_sale_outlined,
                        color: AppColors.accent,
                      )),
                      SizedBox(width: w, child: StatCard(
                        title: "Today's Net Profit",
                        value: Formatters.currencyCompact(stats.todayNetProfit, symbol: symbol),
                        subtitle: 'Gross: ${Formatters.currencyCompact(stats.todayProfit, symbol: symbol)} | Exp: ${Formatters.currencyCompact(stats.todayExpenses, symbol: symbol)}',
                        icon: Icons.account_balance_wallet,
                        color: stats.todayNetProfit >= 0 ? AppColors.inStock : AppColors.outOfStock,
                      )),
                      SizedBox(width: w, child: StatCard(
                        title: 'Month Sales',
                        value: Formatters.currencyCompact(stats.monthSales, symbol: symbol),
                        subtitle: 'Total revenue: ${Formatters.currencyCompact(stats.totalRevenue, symbol: symbol)}',
                        icon: Icons.trending_up,
                        color: AppColors.primaryLight,
                      )),
                      SizedBox(width: w, child: StatCard(
                        title: "Month's Net Profit",
                        value: Formatters.currencyCompact(stats.monthNetProfit, symbol: symbol),
                        subtitle: 'Gross: ${Formatters.currencyCompact(stats.monthProfit, symbol: symbol)} | Exp: ${Formatters.currencyCompact(stats.monthExpenses, symbol: symbol)}',
                        icon: Icons.savings_outlined,
                        color: stats.monthNetProfit >= 0 ? AppColors.inStock : AppColors.outOfStock,
                      )),

                      // Operations Row
                      SizedBox(width: w, child: StatCard(
                        title: 'Total Products',
                        value: '${stats.totalMedicines}',
                        icon: Icons.medication_liquid_outlined,
                        color: AppColors.primary,
                      )),
                      SizedBox(width: w, child: StatCard(
                        title: 'Stock Value',
                        value: Formatters.currencyCompact(stats.stockValue, symbol: symbol),
                        icon: Icons.account_balance_wallet_outlined,
                        color: AppColors.primaryDark,
                      )),
                      SizedBox(width: w, child: StatCard(
                        title: 'Low / Out of Stock',
                        value: '${stats.lowStockCount}',
                        subtitle: stats.lowStockCount == 0 ? 'All good' : 'Need reorder',
                        icon: Icons.warning_amber_outlined,
                        color: AppColors.lowStock,
                        onTap: () => context.go('/inventory'),
                      )),
                      SizedBox(width: w, child: StatCard(
                        title: 'Expiring Soon',
                        value: '${stats.nearExpiryCount}',
                        subtitle: '${stats.expiredCount} already expired',
                        icon: Icons.event_busy_outlined,
                        color: AppColors.nearExpiry,
                        onTap: () => context.go('/inventory'),
                      )),
                    ],
                  );
                }),

                const SizedBox(height: 24),

                // ── charts row ────────────────────────────────────────────
                _TwoCol(
                  left: AppCard(
                    padding: const EdgeInsets.all(20),
                    child: _SalesTrendChart(symbol: symbol),
                  ),
                  right: AppCard(
                    padding: const EdgeInsets.all(20),
                    child: _TopMedicinesChart(symbol: symbol),
                  ),
                  leftFlex: 3,
                  rightFlex: 2,
                ),

                const SizedBox(height: 24),

                // ── alert lists ───────────────────────────────────────────
                _TwoCol(
                  left: _AlertCard(
                    title: 'Low Stock Alert',
                    icon: Icons.warning_amber_outlined,
                    color: AppColors.lowStock,
                    count: lowStock.length,
                    isEmpty: lowStock.isEmpty,
                    emptyText: '✓  All products are well stocked',
                    child: Column(
                      children: [
                        for (final s in lowStock.take(6))
                          _AlertTile(
                            title: s.medicine.name,
                            subtitle: '${s.totalStock} ${s.medicine.unit} remaining',
                            trailing: StockStatusBadge(status: s.status, stock: s.totalStock),
                            onTap: () => context.go('/inventory/detail/${s.medicine.id}'),
                          ),
                        if (lowStock.length > 6)
                          _SeeAllButton(
                            label: '+${lowStock.length - 6} more',
                            onTap: () => context.go('/inventory'),
                          ),
                      ],
                    ),
                  ),
                  right: _AlertCard(
                    title: 'Expiring Soon',
                    icon: Icons.event_busy_outlined,
                    color: AppColors.nearExpiry,
                    count: nearExpiry.length,
                    isEmpty: nearExpiry.isEmpty,
                    emptyText: '✓  No batches expiring soon',
                    child: Column(
                      children: [
                        for (final b in nearExpiry.take(6))
                          _AlertTile(
                            title: medMap[b.medicineId] ?? 'Unknown',
                            subtitle: 'Batch ${b.batchNumber} • ${b.quantity} units',
                            trailing: ExpiryBadge(expiryDate: b.expiryDate),
                          ),
                        if (nearExpiry.length > 6)
                          _SeeAllButton(
                            label: '+${nearExpiry.length - 6} more',
                            onTap: () => context.go('/inventory'),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Two-column responsive layout ────────────────────────────────────────────

class _TwoCol extends StatelessWidget {
  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;

  const _TwoCol({
    required this.left,
    required this.right,
    this.leftFlex = 1,
    this.rightFlex = 1,
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width > 900;
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: leftFlex, child: left),
          const SizedBox(width: 16),
          Expanded(flex: rightFlex, child: right),
        ],
      );
    }
    return Column(
      children: [left, const SizedBox(height: 16), right],
    );
  }
}

// ── Alert card wrapper ───────────────────────────────────────────────────────

class _AlertCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final int count;
  final bool isEmpty;
  final String emptyText;
  final Widget child;

  const _AlertCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.count,
    required this.isEmpty,
    required this.emptyText,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Text(title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
            const Spacer(),
            if (count > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('$count',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ),
          ]),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),
          if (isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(emptyText,
                    style: const TextStyle(
                        color: AppColors.inStock,
                        fontWeight: FontWeight.w500)),
              ),
            )
          else
            child,
        ],
      ),
    );
  }
}

// ── Alert list tile ─────────────────────────────────────────────────────────

class _AlertTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _AlertTile({
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _SeeAllButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SeeAllButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Text(label,
            style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ),
    );
  }
}

// ── Sales trend line chart ───────────────────────────────────────────────────

class _SalesTrendChart extends ConsumerWidget {
  final String symbol;
  const _SalesTrendChart({required this.symbol});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trend = ref.watch(salesTrend7Provider);
    final spots = <FlSpot>[
      for (var i = 0; i < trend.length; i++)
        FlSpot(i.toDouble(), trend[i].total),
    ];
    final weekTotal = trend.fold(0.0, (s, p) => s + p.total);
    final maxY = spots.isEmpty ? 100.0
        : (spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.3).clamp(10.0, double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Expanded(
            child: Text('Sales — Last 7 Days',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              Formatters.currencyCompact(weekTotal, symbol: symbol),
              style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 13),
            ),
          ),
        ]),
        const SizedBox(height: 20),
        SizedBox(
          height: 220,
          child: weekTotal == 0
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.show_chart, size: 40, color: AppColors.border),
                      SizedBox(height: 8),
                      Text('No sales this week',
                          style: TextStyle(color: AppColors.textMuted)),
                    ],
                  ),
                )
              : LineChart(LineChartData(
                  minY: 0,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.35,
                      color: AppColors.primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, pct, bar, idx) =>
                            FlDotCirclePainter(
                              radius: 4,
                              color: Colors.white,
                              strokeWidth: 2.5,
                              strokeColor: AppColors.primary,
                            ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.2),
                            AppColors.primary.withValues(alpha: 0.01),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        reservedSize: 28,
                        getTitlesWidget: (v, meta) {
                          final i = v.toInt();
                          if (i < 0 || i >= trend.length) {
                            return const SizedBox.shrink();
                          }
                          final isToday = i == trend.length - 1;
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              DateFormat.E().format(trend[i].day),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isToday
                                    ? FontWeight.w700
                                    : FontWeight.normal,
                                color: isToday
                                    ? AppColors.primary
                                    : AppColors.textMuted,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 58,
                        getTitlesWidget: (v, meta) {
                          if (v == 0) return const SizedBox.shrink();
                          return SideTitleWidget(
                            meta: meta,
                            child: Text(
                              Formatters.currencyCompact(v, symbol: symbol),
                              style: const TextStyle(
                                  fontSize: 10, color: AppColors.textMuted),
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (_) => const FlLine(
                      color: AppColors.border,
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => AppColors.sidebar,
                      getTooltipItems: (spots) => spots.map((s) {
                        final idx = s.spotIndex;
                        final day = idx < trend.length
                            ? DateFormat('EEE d MMM').format(trend[idx].day)
                            : '';
                        return LineTooltipItem(
                          '$day\n${Formatters.currency(s.y, symbol: symbol)}',
                          const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        );
                      }).toList(),
                    ),
                  ),
                )),
        ),
      ],
    );
  }
}

// ── Top medicines bar chart ──────────────────────────────────────────────────

class _TopMedicinesChart extends ConsumerWidget {
  final String symbol;
  const _TopMedicinesChart({required this.symbol});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = ref.watch(topMedicinesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Top Selling Medicines',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        if (top.isEmpty)
          const SizedBox(
            height: 200,
            child: EmptyState(
              icon: Icons.bar_chart,
              title: 'No sales yet',
              message: 'Top medicines appear after the first sale.',
            ),
          )
        else ...[
          const SizedBox(height: 4),
          ...() {
            final maxQty = top.map((t) => t.qty).reduce((a, b) => a > b ? a : b);
            const barColors = [
              AppColors.primary,
              AppColors.accent,
              AppColors.lowStock,
              AppColors.nearExpiry,
              AppColors.primaryDark,
            ];
            return top.asMap().entries.map((e) {
              final i = e.key;
              final m = e.value;
              final pct = maxQty == 0 ? 0.0 : m.qty / maxQty;
              final col = barColors[i % barColors.length];
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: col,
                            shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(m.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13)),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${m.qty} sold',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: col),
                      ),
                    ]),
                    const SizedBox(height: 5),
                    Stack(children: [
                      Container(
                          height: 8,
                          decoration: BoxDecoration(
                              color: AppColors.border,
                              borderRadius: BorderRadius.circular(6))),
                      FractionallySizedBox(
                        widthFactor: pct,
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                              color: col,
                              borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ]),
                  ],
                ),
              );
            }).toList();
          }(),
        ],
      ],
    );
  }
}
