import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';

import 'package:foglm/features/debug/presentation/debug_menu_screen.dart';

void main() {
  unawaited(
    goldenTest(
      'DebugMenuScreen shows the navigation buttons',
      fileName: 'debug_menu_screen',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      builder: () => const MaterialApp(home: DebugMenuScreen()),
    ),
  );
}
