import 'dart:async';
import 'dart:typed_data';

import 'package:alchemist/alchemist.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foglm/features/camera/camera_screen.dart';
import 'package:foglm/features/camera/data/photo_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../widget/features/camera/fake_camera_platform.dart';

class _MockPhotoRepository extends Mock implements PhotoRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

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

  unawaited(
    goldenTest(
      'CameraScreen shows the preview and shutter button',
      fileName: 'camera_screen_preview',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      // CameraController初期化中のCircularProgressIndicatorの無限アニメー
      // ションが絡むため、pumpAndSettleではなく固定回数pumpする戦略を使う
      // (camera_screen_no_cameraと同様)。
      pumpBeforeTest: (tester) async {
        CameraPlatform.instance = FakeCameraPlatform();
        await pumpNTimes(10)(tester);
      },
      builder: () => ProviderScope(
        overrides: [
          photoRepositoryProvider.overrideWithValue(_MockPhotoRepository()),
        ],
        child: const MaterialApp(home: CameraScreen(groupId: 'test-group-id')),
      ),
    ),
  );

  unawaited(
    goldenTest(
      'CameraScreen shows a loading indicator while uploading',
      fileName: 'camera_screen_uploading',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      pumpBeforeTest: (tester) async {
        CameraPlatform.instance = FakeCameraPlatform();
        await pumpNTimes(10)(tester);
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pump();
      },
      builder: () {
        final repository = _MockPhotoRepository();
        when(
          () => repository.uploadPhoto(
            groupId: any(named: 'groupId'),
            bytes: any(named: 'bytes'),
          ),
        ).thenAnswer((_) => Completer<void>().future);
        return ProviderScope(
          overrides: [photoRepositoryProvider.overrideWithValue(repository)],
          child: const MaterialApp(
            home: CameraScreen(groupId: 'test-group-id'),
          ),
        );
      },
    ),
  );
}
