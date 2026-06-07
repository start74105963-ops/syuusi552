import 'package:flutter/material.dart';

class AppColors {
  static const primary        = Color(0xFF2563EB);
  static const primaryLight   = Color(0xFFEFF6FF);
  static const win            = Color(0xFF16A34A);
  static const loss           = Color(0xFFDC2626);
  static const even           = Color(0xFF6B7280);
  static const surface        = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF9FAFB);
  static const background     = Color(0xFFF9FAFB);
  static const onSurface      = Color(0xFF111827);
  static const onSurfaceMuted = Color(0xFF6B7280);
  static const cardBorder     = Color(0xFFE5E7EB);
}

ThemeData buildLightTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.primaryLight,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      onPrimary: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.onSurface,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      shadowColor: Color(0x14000000),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.cardBorder, width: 0.5),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      labelStyle: const TextStyle(color: AppColors.onSurfaceMuted),
      hintStyle: const TextStyle(color: AppColors.onSurfaceMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        minimumSize: const Size(0, 44),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.cardBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minimumSize: const Size(0, 44),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 2,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.cardBorder,
      thickness: 0.5,
    ),
    textTheme: const TextTheme(
      headlineLarge:  TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.bold,   fontSize: 28),
      headlineMedium: TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.bold,   fontSize: 22),
      titleLarge:     TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w600,   fontSize: 18),
      titleMedium:    TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w500,   fontSize: 16),
      bodyLarge:      TextStyle(color: AppColors.onSurface, fontSize: 16),
      bodyMedium:     TextStyle(color: AppColors.onSurfaceMuted, fontSize: 14),
      labelLarge:     TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.w600,   fontSize: 14),
      labelSmall:     TextStyle(color: AppColors.onSurfaceMuted, fontWeight: FontWeight.w400, fontSize: 11),
    ),
  );
}
