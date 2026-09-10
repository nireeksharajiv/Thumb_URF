import 'package:flutter/material.dart';

abstract final class AppTheme {
  static final light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF0B5D5E),
      brightness: Brightness.light,
      surface: const Color(0xFFF7FAFA),
    ),
    scaffoldBackgroundColor: const Color(0xFFF7FAFA),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE0E9E8)),
      ),
    ),
  );

  static final dark = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF0B5D5E),
      brightness: Brightness.dark,
      surface: const Color(0xFF161D1D),
    ),
    scaffoldBackgroundColor: const Color(0xFF0F1414),
    cardTheme: CardThemeData(
      color: const Color(0xFF1B2323),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF2B3838)),
      ),
    ),
  );
}
