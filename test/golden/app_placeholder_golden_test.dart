import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foglm/app/app.dart';

void main() {
  unawaited(
    goldenTest(
      'FoglmApp shows the placeholder home screen',
      fileName: 'app_placeholder',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      builder: () => const ProviderScope(child: FoglmApp()),
    ),
  );
}
