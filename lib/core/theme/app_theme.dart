import 'package:flutter/material.dart';
import 'package:foglm/core/theme/app_colors.dart';

/// フィルムカメラ風・レトロな世界観のテーマ定義(仕様書 3.9参照)。
/// 見出しは太いディスプレイ体(Alfa Slab One)、本文は読みやすいPoppinsを使う。
/// 初回起動時のフォントちらつきを避けるため、Google Fontsを実行時取得せず
/// `assets/fonts/`に同梱したフォントファイルを`pubspec.yaml`経由で読み込む。
class AppTheme {
  AppTheme._();

  static const _poppins = 'Poppins';
  static const _alfaSlabOne = 'AlfaSlabOne';

  static ThemeData get light {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: AppColors.textLight,
          secondary: AppColors.accent,
          onSecondary: AppColors.textLight,
          surface: AppColors.surface,
          onSurface: AppColors.textDark,
        );

    const alfaSlabOneStyle = TextStyle(fontFamily: _alfaSlabOne);
    const poppinsStyle = TextStyle(fontFamily: _poppins);

    // fontSize・fontWeightは指定しないことで、ThemeDataがMaterial3標準の
    // タイプスケール(Typography.material2021)を継承して補完する
    // (titleMedium等のfontWeight: w500もここで正しく反映される)。
    // titleMedium・bodyLarge等も含めた全スタイルにtextDarkを適用する
    // (display/headline/titleLargeは直後にAlfa Slab Oneで上書きされる)。
    final textTheme =
        const TextTheme(
              displayLarge: poppinsStyle,
              displayMedium: poppinsStyle,
              displaySmall: poppinsStyle,
              headlineLarge: poppinsStyle,
              headlineMedium: poppinsStyle,
              headlineSmall: poppinsStyle,
              titleLarge: poppinsStyle,
              titleMedium: poppinsStyle,
              titleSmall: poppinsStyle,
              bodyLarge: poppinsStyle,
              bodyMedium: poppinsStyle,
              bodySmall: poppinsStyle,
              labelLarge: poppinsStyle,
              labelMedium: poppinsStyle,
              labelSmall: poppinsStyle,
            )
            .apply(
              bodyColor: AppColors.textDark,
              displayColor: AppColors.textDark,
            )
            .copyWith(
              displayLarge: alfaSlabOneStyle.copyWith(
                color: AppColors.textDark,
              ),
              displayMedium: alfaSlabOneStyle.copyWith(
                color: AppColors.textDark,
              ),
              displaySmall: alfaSlabOneStyle.copyWith(
                color: AppColors.textDark,
              ),
              headlineLarge: alfaSlabOneStyle.copyWith(
                color: AppColors.textDark,
              ),
              headlineMedium: alfaSlabOneStyle.copyWith(
                color: AppColors.textDark,
              ),
              headlineSmall: alfaSlabOneStyle.copyWith(
                color: AppColors.textDark,
              ),
              titleLarge: alfaSlabOneStyle.copyWith(color: AppColors.textDark),
            );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.surface,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textLight,
        titleTextStyle: TextStyle(
          fontFamily: _alfaSlabOne,
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
