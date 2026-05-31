import "package:flutter/material.dart";

ThemeData buildAppTheme() {
  const primary = Color(0xFF2563EB);

  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      surface: Colors.white
    ),
    scaffoldBackgroundColor: const Color(0xFFF6F7FB),
    useMaterial3: true
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF111827),
      elevation: 0
    ),
    cardTheme: const CardThemeData(
      color: Colors.white,
      elevation: 0.8,
      margin: EdgeInsets.zero
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB))
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB))
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.3)
      )
    )
  );
}
