import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'expenses_providers.dart';
import 'inventory_providers.dart';
import 'sales_providers.dart';

/// Aggregated numbers for the dashboard header cards.
class DashboardStats {
  final int totalMedicines;
  final double stockValue;
  final int lowStockCount;
  final int nearExpiryCount;
  final int expiredCount;
  final double todaySales;
  final int todaySalesCount;
  final double monthSales;
  final int totalSales;
  final double totalRevenue;
  final double todayProfit;
  final double todayExpenses;
  final double monthProfit;
  final double monthExpenses;

  const DashboardStats({
    required this.totalMedicines,
    required this.stockValue,
    required this.lowStockCount,
    required this.nearExpiryCount,
    required this.expiredCount,
    required this.todaySales,
    required this.todaySalesCount,
    required this.monthSales,
    required this.totalSales,
    required this.totalRevenue,
    this.todayProfit = 0,
    this.todayExpenses = 0,
    this.monthProfit = 0,
    this.monthExpenses = 0,
  });

  double get todayNetProfit => todayProfit - todayExpenses;
  double get monthNetProfit => monthProfit - monthExpenses;
}

/// Total sales value for a single day, used by the trend chart.
typedef TrendPoint = ({DateTime day, double total});

/// Top selling medicine by quantity.
typedef TopMedicine = ({String name, int qty, double revenue});

final dashboardStatsProvider = Provider<DashboardStats>((ref) {
  final medicines = ref.watch(medicineStockProvider);
  final stockValue = ref.watch(totalStockValueProvider);
  final lowStock = ref.watch(lowStockProvider);
  final nearExpiry = ref.watch(nearExpiryBatchesProvider);
  final expired = ref.watch(expiredBatchesProvider);
  final sales = ref.watch(salesProvider);
  final todayExpenses = ref.watch(todayExpensesProvider);
  final monthExpenses = ref.watch(monthExpensesProvider);

  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  final startOfMonth = DateTime(now.year, now.month, 1);

  double todaySales = 0;
  int todayCount = 0;
  double monthSales = 0;
  double totalRevenue = 0;
  double todayProfit = 0;
  double monthProfit = 0;

  for (final s in sales) {
    if (s.isReturned) continue;
    totalRevenue += s.total;
    final d = s.dateTimeValue;
    if (d.isAfter(startOfToday) || d.isAtSameMomentAs(startOfToday)) {
      todaySales += s.total;
      todayProfit += s.grossProfit;
      todayCount++;
    }
    if (d.isAfter(startOfMonth) || d.isAtSameMomentAs(startOfMonth)) {
      monthSales += s.total;
      monthProfit += s.grossProfit;
    }
  }

  return DashboardStats(
    totalMedicines: medicines.length,
    stockValue: stockValue,
    lowStockCount: lowStock.length,
    nearExpiryCount: nearExpiry.length,
    expiredCount: expired.length,
    todaySales: todaySales,
    todaySalesCount: todayCount,
    monthSales: monthSales,
    totalSales: sales.length,
    totalRevenue: totalRevenue,
    todayProfit: todayProfit,
    todayExpenses: todayExpenses,
    monthProfit: monthProfit,
    monthExpenses: monthExpenses,
  );
});

/// Last 7 days of sales totals (oldest first).
final salesTrend7Provider = Provider<List<TrendPoint>>((ref) {
  final sales = ref.watch(salesProvider);
  final today = DateTime.now();
  final days = List.generate(7, (i) {
    final d = today.subtract(Duration(days: 6 - i));
    return DateTime(d.year, d.month, d.day);
  });
  final totals = <DateTime, double>{for (final d in days) d: 0.0};
  for (final s in sales) {
    final d = s.dateTimeValue;
    final day = DateTime(d.year, d.month, d.day);
    if (totals.containsKey(day)) {
      totals[day] = totals[day]! + s.total;
    }
  }
  return days.map((d) => (day: d, total: totals[d]!)).toList();
});

/// Top 5 selling medicines across all sales, by quantity sold.
final topMedicinesProvider = Provider<List<TopMedicine>>((ref) {
  final sales = ref.watch(salesProvider);
  final agg = <String, TopMedicine>{};
  for (final s in sales) {
    for (final item in s.items) {
      final existing =
          agg[item.medicineId] ?? (name: item.medicineName, qty: 0, revenue: 0.0);
      agg[item.medicineId] = (
        name: existing.name,
        qty: existing.qty + item.quantity,
        revenue: existing.revenue + item.lineTotal,
      );
    }
  }
  final list = agg.values.toList()..sort((a, b) => b.qty.compareTo(a.qty));
  return list.take(5).toList();
});
