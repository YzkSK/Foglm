import 'package:flutter/material.dart';

/// フィルムカメラ風・レトロな世界観のテーマ定義の土台。
/// 詳細なデザインシステムは別Issueで拡張する。
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4A3F35)),
    );
  }
}
