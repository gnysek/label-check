import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const green = Color(0xFF1F4D3A);
  static const background = Color(0xFFF4F6F2);
  static const border = Color(0xFFDDE3DE);
  static const muted = Color(0xFF4B5563);
  static const text = Color(0xFF1B1F1D);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.green)
      .copyWith(primary: AppColors.green);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.text,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.text,
      ),
    ),
  );
}
