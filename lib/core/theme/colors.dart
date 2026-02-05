import 'package:flutter/material.dart';

/// Application Color Constants - Hiraaj Sahm Brand Colors
class AppColors {
  AppColors._();

  // ============ BRAND COLORS ============
  // Primary Blue - #004c86
  static const Color primary = Color(0xFF004C86);
  static const Color primaryDark = Color(0xFF003A66);
  static const Color primaryLight = Color(0xFF1A6BA8);

  // Secondary Gold - #eeb73e
  static const Color secondary = Color(0xFFEEB73E);
  static const Color secondaryDark = Color(0xFFD4A235);
  static const Color secondaryLight = Color(0xFFF5C75B);

  // Accent Colors
  static const Color accent = Color(0xFF2E7D32);
  static const Color accentDark = Color(0xFF1B5E20);
  static const Color accentLight = Color(0xFF4CAF50);

  // ============ LIGHT THEME COLORS ============
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF8F9FA);
  static const Color surfaceVariant = Color(0xFFF0F4F8);
  static const Color card = Color(0xFFFFFFFF);

  // ============ DARK THEME COLORS ============
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color surfaceVariantDark = Color(0xFF2C2C2C);
  static const Color cardDark = Color(0xFF1E1E1E);

  // ============ INPUT COLORS ============
  static const Color inputBack = Color(0xFFF9FAFB);
  static const Color inputBackDark = Color(0xFF2C2C2C);

  // ============ TEXT COLORS ============
  // Light Theme Text
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnSecondary = Color(0xFF1A1A1A);

  // Dark Theme Text
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color textLightSecondary = Color(0xFFB0B0B0);
  static const Color textLightTertiary = Color(0xFF757575);

  // ============ STATUS COLORS ============
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);

  // ============ BORDER & DIVIDER COLORS ============
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderDark = Color(0xFF374151);
  static const Color divider = Color(0xFFF3F4F6);
  static const Color dividerDark = Color(0xFF2D2D2D);

  // ============ SHIMMER COLORS ============
  static const Color shimmerBase = Color(0xFFE0E0E0);
  static const Color shimmerHighlight = Color(0xFFF5F5F5);
  static const Color shimmerBaseDark = Color(0xFF2D2D2D);
  static const Color shimmerHighlightDark = Color(0xFF3D3D3D);

  // ============ GRADIENTS ============
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryLight],
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondary, secondaryLight],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEEB73E), Color(0xFFF5D77A), Color(0xFFEEB73E)],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [backgroundDark, surfaceDark],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), Color(0xFF34D399)],
  );

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primary, primaryDark],
  );

  // ============ SUBSCRIPTION PACK COLORS ============
  static const Color freePack = Color(0xFF6B7280);
  static const Color silverPack = Color(0xFFC0C0C0);
  static const Color goldPack = Color(0xFFFFD700);
  static const Color platinumPack = Color(0xFFE5E4E2);

  // ============ CATEGORY COLORS ============
  static const List<Color> categoryColors = [
    Color(0xFF004C86),
    Color(0xFFEEB73E),
    Color(0xFF2E7D32),
    Color(0xFF7C3AED),
    Color(0xFFEC4899),
    Color(0xFF06B6D4),
    Color(0xFFF97316),
    Color(0xFF84CC16),
  ];
}
