import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData getTheme(ColorScheme? colorScheme, Brightness brightness) {
    final ColorScheme finalColorScheme = colorScheme ?? ColorScheme.fromSeed(
      seedColor: const Color(0xFF4285F4),
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: finalColorScheme,
    );
  }
}
