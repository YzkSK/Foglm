import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/core/theme/app_colors.dart';
import 'package:foglm/core/theme/app_theme.dart';

void main() {
  group('AppTheme.light', () {
    testWidgets('uses the retro color palette for the color scheme', (
      tester,
    ) async {
      final theme = AppTheme.light;

      expect(theme.colorScheme.primary, AppColors.primary);
      expect(theme.colorScheme.onPrimary, AppColors.textLight);
      expect(theme.colorScheme.secondary, AppColors.accent);
      expect(theme.colorScheme.onSecondary, AppColors.textLight);
      expect(theme.colorScheme.surface, AppColors.surface);
      expect(theme.colorScheme.onSurface, AppColors.textDark);
    });

    testWidgets('uses the primary color as the scaffold background', (
      tester,
    ) async {
      expect(AppTheme.light.scaffoldBackgroundColor, AppColors.surface);
    });

    testWidgets('styles the app bar with the primary color', (tester) async {
      final theme = AppTheme.light;

      expect(theme.appBarTheme.backgroundColor, AppColors.primary);
      expect(theme.appBarTheme.foregroundColor, AppColors.textLight);
    });

    testWidgets(
      'styles elevated buttons with the accent color and a pill shape',
      (tester) async {
        final buttonStyle = AppTheme.light.elevatedButtonTheme.style;

        expect(buttonStyle?.backgroundColor?.resolve({}), AppColors.accent);
        expect(
          buttonStyle?.foregroundColor?.resolve({}),
          AppColors.textLight,
        );
        expect(buttonStyle?.shape?.resolve({}), isA<StadiumBorder>());
      },
    );

    testWidgets(
      'applies textDark to body/title/label styles not overridden with '
      'Alfa Slab One',
      (tester) async {
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
