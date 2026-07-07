import 'package:flutter/material.dart';

/// フィルムカメラ風・レトロな世界観のカラーパレット(仕様書 3.9参照)。
class AppColors {
  AppColors._();

  /// ダスティティール(ヘッダー・主要な塗り面)。
  static const primary = Color(0xFF4E8C87);

  /// クリーム(本文エリアの背景)。
  static const surface = Color(0xFFEFE6D0);

  /// バーントオレンジ(ボタン・アイコン等のアクセント)。
  static const accent = Color(0xFFD97B4A);

  /// ダークネイビー(本文テキスト)。
  static const textDark = Color(0xFF2B3A3F);

  /// オフホワイト(濃色背景上のテキスト)。
  static const textLight = Color(0xFFF5EFE0);
}
