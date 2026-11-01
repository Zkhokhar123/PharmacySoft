import 'package:intl/intl.dart';

/// Formatting helpers for currency, numbers and dates.
class Formatters {
  Formatters._();

  static String currency(double amount, {String symbol = 'Rs'}) {
    final value = amount.isNaN ? 0.0 : amount;
    return '$symbol ${NumberFormat('#,##0.00').format(value)}';
  }

  /// Compact currency without decimals for stat cards.
  static String currencyCompact(double amount, {String symbol = 'Rs'}) {
    final value = amount.isNaN ? 0.0 : amount;
    if (value.abs() >= 1000000) {
      return '$symbol ${(value / 1000000).toStringAsFixed(2)}M';
    } else if (value.abs() >= 1000) {
      return '$symbol ${(value / 1000).toStringAsFixed(1)}K';
    }
    return '$symbol ${value.toStringAsFixed(0)}';
  }

  static String number(double value) =>
      NumberFormat('#,##0').format(value.isNaN ? 0 : value);

  static String date(DateTime d) => DateFormat('dd MMM yyyy').format(d);
  static String dateShort(DateTime d) => DateFormat('dd/MM/yyyy').format(d);
  static String dateTime(DateTime d) =>
      DateFormat('dd MMM yyyy, hh:mm a').format(d);

  /// Days from now until [date]. Negative if in the past.
  static int daysUntil(DateTime date, {DateTime? from}) {
    final now = (from ?? DateTime.now());
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    return target.difference(today).inDays;
  }
}
