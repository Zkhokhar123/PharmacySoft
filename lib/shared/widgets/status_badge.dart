import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/formatters.dart';
import '../../state/inventory_providers.dart';

/// Coloured pill describing stock status.
class StockStatusBadge extends StatelessWidget {
  final StockStatus status;
  final int? stock;
  final String? stockLabel;
  final double size;

  const StockStatusBadge({
    super.key,
    required this.status,
    this.stock,
    this.stockLabel,
    this.size = 12,
  });

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      StockStatus.inStock => ('In Stock', AppColors.inStock),
      StockStatus.lowStock => ('Low Stock', AppColors.lowStock),
      StockStatus.outOfStock => ('Out of Stock', AppColors.outOfStock),
    };
    return _Pill(
      label: stockLabel != null
          ? '$label • $stockLabel'
          : stock != null
              ? '$label • $stock'
              : label,
      color: color,
      size: size,
    );
  }
}

/// Coloured pill describing how far a batch is from expiry.
class ExpiryBadge extends StatelessWidget {
  final int expiryDate;
  final double size;

  const ExpiryBadge({super.key, required this.expiryDate, this.size = 12});

  @override
  Widget build(BuildContext context) {
    final days = Formatters.daysUntil(
        DateTime.fromMillisecondsSinceEpoch(expiryDate));
    final (label, color) = days < 0
        ? ('Expired ${days.abs()}d ago', AppColors.expired)
        : days <= 30
            ? ('Expires in ${days}d', AppColors.nearExpiry)
            : ('Exp ${Formatters.date(DateTime.fromMillisecondsSinceEpoch(expiryDate))}',
                AppColors.textMuted);
    return _Pill(label: label, color: color, size: size);
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final double size;

  const _Pill({required this.label, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: size, vertical: size / 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
