import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/camera/camera_screen.dart';

void main() {
  unawaited(
    goldenTest(
      'CameraScreen shows an error when no camera is available',
      fileName: 'camera_screen_no_camera',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      // カメラ未接続時のエラー表示にはCircularProgressIndicatorの
      // 無限アニメーションが絡むため、pumpAndSettleではなく固定回数
      // pumpする戦略を使う。
      pumpBeforeTest: pumpNTimes(10),
      builder: () => const ProviderScope(
        child: MaterialApp(home: CameraScreen(groupId: 'test-group-id')),
      ),
    ),
  );
}
