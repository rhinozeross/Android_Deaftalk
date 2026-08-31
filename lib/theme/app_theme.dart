import 'package:flutter/material.dart';

/// Farben aus dem Original (res/values/colors.xml).
class DeaftalkColors {
  static const primary = Color(0xFF1CE805);
  static const primaryDark = Color(0xFF03AE0C);
  static const accent = Color(0xFFFFEB3B);
}

/// Zentraler Theme-Aufbau der App.
class AppTheme {
  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: DeaftalkColors.primary,
        primary: DeaftalkColors.primary,
        secondary: DeaftalkColors.accent,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: DeaftalkColors.primaryDark,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: DeaftalkColors.primary,
          foregroundColor: Colors.black,
          minimumSize: const Size.fromHeight(44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}
