import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';

import 'package:foglm/features/camera/widgets/shutter_button.dart';

void main() {
  unawaited(
    goldenTest(
      'ShutterButton shows enabled and disabled states',
      fileName: 'shutter_button',
      constraints: const BoxConstraints(maxWidth: 300, maxHeight: 220),
      builder: () => MaterialApp(
        home: Scaffold(
          body: GoldenTestGroup(
            children: [
              GoldenTestScenario(
                name: 'enabled (shots remaining)',
                child: ShutterButton(remaining: 3, onPressed: () {}),
              ),
              GoldenTestScenario(
                name: 'disabled (no shots remaining)',
                child: ShutterButton(remaining: 0, onPressed: () {}),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
