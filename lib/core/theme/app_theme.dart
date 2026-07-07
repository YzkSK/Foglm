import 'package:flutter/material.dart';
import 'package:foglm/core/theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';

/// フィルムカメラ風・レトロな世界観のテーマ定義(仕様書 3.9参照)。
/// 見出しは太いディスプレイ体(Alfa Slab One)、本文は読みやすいPoppinsを使う。
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: AppColors.textLight,
      secondary: AppColors.accent,
      onSecondary: AppColors.textLight,
      surface: AppColors.surface,
      onSurface: AppColors.textDark,
    );

    final textTheme = GoogleFonts.poppinsTextTheme().copyWith(
      displayLarge: GoogleFonts.alfaSlabOne(color: AppColors.textDark),
      displayMedium: GoogleFonts.alfaSlabOne(color: AppColors.textDark),
      displaySmall: GoogleFonts.alfaSlabOne(color: AppColors.textDark),
      headlineLarge: GoogleFonts.alfaSlabOne(color: AppColors.textDark),
      headlineMedium: GoogleFonts.alfaSlabOne(color: AppColors.textDark),
      headlineSmall: GoogleFonts.alfaSlabOne(color: AppColors.textDark),
      titleLarge: GoogleFonts.alfaSlabOne(color: AppColors.textDark),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textLight,
        titleTextStyle: GoogleFonts.alfaSlabOne(
          color: AppColors.textLight,
          fontSize: 20,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.textLight,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
    );
  }
}
