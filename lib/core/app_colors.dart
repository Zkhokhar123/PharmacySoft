import 'package:flutter/material.dart';

/// Centralised colour palette for the pharmacy app.
/// Uses a calm medical teal/emerald scheme with semantic colours for stock
/// and expiry states.
class AppColors {
  AppColors._();

  // Brand
  static const primary = Color(0xFF0D9488); // teal-600
  static const primaryDark = Color(0xFF0F766E); // teal-700
  static const primaryLight = Color(0xFF14B8A6); // teal-500
  static const accent = Color(0xFF22C55E); // green-500

  // Surfaces
  static const background = Color(0xFFF4F6F8);
  static const surface = Colors.white;
  static const sidebar = Color(0xFF103A3A); // deep teal sidebar
  static const sidebarText = Color(0xFFB6E0DD);

  // Semantic
  static const inStock = Color(0xFF16A34A); // green-600
  static const lowStock = Color(0xFFF59E0B); // amber-500
  static const outOfStock = Color(0xFFDC2626); // red-600
  static const nearExpiry = Color(0xFFF97316); // orange-500
  static const expired = Color(0xFFB91C1C); // red-700

  static const textPrimary = Color(0xFF1F2937); // gray-800
  static const textMuted = Color(0xFF6B7280); // gray-500
  static const border = Color(0xFFE5E7EB); // gray-200
}
