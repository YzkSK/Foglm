import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foglm/features/camera/widgets/shutter_button.dart';

void main() {
  Future<void> pumpShutterButton(
    WidgetTester tester, {
    required int remaining,
    required VoidCallback onPressed,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShutterButton(remaining: remaining, onPressed: onPressed),
        ),
      ),
    );
  }

  testWidgets('is enabled and calls onPressed when shots remain', (
    tester,
  ) async {
    var pressed = false;
    await pumpShutterButton(
      tester,
      remaining: 3,
      onPressed: () => pressed = true,
    );

    final button = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(button.onPressed, isNotNull);

    await tester.tap(find.byType(FloatingActionButton));
    expect(pressed, isTrue);
  });

  testWidgets('is disabled when no shots remain', (tester) async {
    await pumpShutterButton(tester, remaining: 0, onPressed: () {});

    final button = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('exposes a tooltip describing the action when enabled', (
    tester,
  ) async {
    await pumpShutterButton(tester, remaining: 3, onPressed: () {});

    final button = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(button.tooltip, '撮影する');
  });

  testWidgets('exposes a tooltip explaining why it is disabled', (
    tester,
  ) async {
    await pumpShutterButton(tester, remaining: 0, onPressed: () {});

    final button = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(button.tooltip, '本日の撮影上限に達しました');
  });
}
