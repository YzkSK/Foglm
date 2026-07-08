import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/core/theme/app_colors.dart';
import 'package:foglm/core/theme/app_theme.dart';

void main() {
  group('AppTheme.light', () {
    test('uses the retro color palette for the color scheme', () {
      final theme = AppTheme.light;

      expect(theme.colorScheme.primary, AppColors.primary);
      expect(theme.colorScheme.onPrimary, AppColors.textLight);
      expect(theme.colorScheme.secondary, AppColors.accent);
      expect(theme.colorScheme.onSecondary, AppColors.textLight);
      expect(theme.colorScheme.surface, AppColors.surface);
      expect(theme.colorScheme.onSurface, AppColors.textDark);
    });

    test('uses the primary color as the scaffold background', () {
      expect(AppTheme.light.scaffoldBackgroundColor, AppColors.surface);
    });

    test('styles the app bar with the primary color', () {
      final theme = AppTheme.light;

      expect(theme.appBarTheme.backgroundColor, AppColors.primary);
      expect(theme.appBarTheme.foregroundColor, AppColors.textLight);
    });

    test('styles elevated buttons with the accent color and a pill shape', () {
      final buttonStyle = AppTheme.light.elevatedButtonTheme.style;

      expect(buttonStyle?.backgroundColor?.resolve({}), AppColors.accent);
      expect(buttonStyle?.foregroundColor?.resolve({}), AppColors.textLight);
      expect(buttonStyle?.shape?.resolve({}), isA<StadiumBorder>());
    });

    test(
      'applies textDark to body/title/label styles not overridden with '
      'Alfa Slab One',
      () {
        final textTheme = AppTheme.light.textTheme;

        expect(textTheme.titleMedium?.color, AppColors.textDark);
        expect(textTheme.titleSmall?.color, AppColors.textDark);
        expect(textTheme.bodyLarge?.color, AppColors.textDark);
        expect(textTheme.bodyMedium?.color, AppColors.textDark);
        expect(textTheme.bodySmall?.color, AppColors.textDark);
        expect(textTheme.labelLarge?.color, AppColors.textDark);
      },
    );
  });
}
