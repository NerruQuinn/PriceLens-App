import 'package:flutter/material.dart';

class SkinThemeResolver {
  static ThemeData resolveTheme(String? skinId, ThemeData baseTheme) {
    switch (skinId) {
      case 'ocean_blue':
        return baseTheme.copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0096C7)),
        );
      case 'sunset_orange':
        return baseTheme.copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF6B35)),
        );
      case 'cyber_punk':
        return baseTheme.copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF6B48FF),
            brightness: Brightness.dark,
          ),
          brightness: Brightness.dark,
        );
      case 'gold_legend':
        return baseTheme.copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFFD700)),
        );
      case 'dark_mode':
        return baseTheme.copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF4285F4),
            brightness: Brightness.dark,
          ),
          brightness: Brightness.dark,
        );
      case 'neon_frame':
        return baseTheme.copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00FF88)),
        );
      case 'diamond_frame':
        return baseTheme.copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00BCD4)),
        );
      default:
        return baseTheme;
    }
  }

  static Color resolveCardColor(String? skinId, Color defaultColor) {
    switch (skinId) {
      case 'ocean_blue': return const Color(0xFFE0F7FF);
      case 'sunset_orange': return const Color(0xFFFFF3E0);
      case 'cyber_punk': return const Color(0xFF1A1A2E);
      case 'gold_legend': return const Color(0xFFFFFDE7);
      case 'dark_mode': return const Color(0xFF212121);
      case 'neon_frame': return const Color(0xFFE0FFF0);
      case 'diamond_frame': return const Color(0xFFE0F7FA);
      default: return defaultColor;
    }
  }
}
