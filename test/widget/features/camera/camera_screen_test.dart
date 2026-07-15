import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foglm/features/camera/camera_screen.dart';
import 'package:foglm/features/camera/data/photo_repository.dart';
import 'package:foglm/features/camera/data/remaining_shots_repository.dart';
import 'package:foglm/features/camera/domain/upload_photo_failure.dart';
import 'package:mocktail/mocktail.dart';

import 'fake_camera_platform.dart';

class MockPhotoRepository extends Mock implements PhotoRepository {}

class MockRemainingShotsRepository extends Mock
    implements RemainingShotsRepository {}

void main() {
  late MockPhotoRepository repository;
  late MockRemainingShotsRepository remainingShotsRepository;
  late CameraPlatform originalPlatform;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    repository = MockPhotoRepository();
    remainingShotsRepository = MockRemainingShotsRepository();
    when(
      () => remainingShotsRepository.watchTodayShotsRemaining(
        groupId: any(named: 'groupId'),
      ),
    ).thenAnswer((_) => Stream.value(10));
    originalPlatform = CameraPlatform.instance;
    CameraPlatform.instance = FakeCameraPlatform();
  });

  tearDown(() {
    CameraPlatform.instance = originalPlatform;
  });

  Widget pumpApp() {
    return ProviderScope(
      overrides: [
        photoRepositoryProvider.overrideWithValue(repository),
        remainingShotsRepositoryProvider.overrideWithValue(
          remainingShotsRepository,
        ),
      ],
      child: const MaterialApp(home: CameraScreen(groupId: 'group-1')),
    );
  }

  testWidgets(
    'optimistically decrements the remaining count on a successful upload, '
    'ahead of the Realtime confirmation',
    (tester) async {
      final controller = StreamController<int>();
      addTearDown(controller.close);
      when(
        () => remainingShotsRepository.watchTodayShotsRemaining(
          groupId: any(named: 'groupId'),
        ),
      ).thenAnswer((_) => controller.stream);
      when(
        () => repository.uploadPhoto(
          groupId: any(named: 'groupId'),
          bytes: any(named: 'bytes'),
        ),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(pumpApp());
      controller.add(10);
      await tester.pumpAndSettle();

      expect(find.text('残り 10 枚'), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      verify(
        () => repository.uploadPhoto(
          groupId: 'group-1',
          bytes: any(named: 'bytes'),
        ),
      ).called(1);
      // 自分のphotos INSERTがRealtime経由で反映されるまでのラグの間、
      // ローカルの楽観的減算により先に9枚と表示する(仕様書 5.2.3参照)。
      expect(find.text('残り 9 枚'), findsOneWidget);

      // Realtimeが自分の撮影を反映して9を発行しても、楽観的減算が二重に
      // 効いて8枚にはならず、9枚のまま変わらないことを確認する。
      controller.add(9);
      await tester.pumpAndSettle();

      expect(find.text('残り 9 枚'), findsOneWidget);
    },
  );

  testWidgets(
    'reflects a Realtime update pushed after another member shoots',
    (tester) async {
      final controller = StreamController<int>();
      addTearDown(controller.close);
      when(
        () => remainingShotsRepository.watchTodayShotsRemaining(
          groupId: any(named: 'groupId'),
        ),
      ).thenAnswer((_) => controller.stream);

      await tester.pumpWidget(pumpApp());
      controller.add(10);
      await tester.pumpAndSettle();

      expect(find.text('残り 10 枚'), findsOneWidget);

      controller.add(9);
      await tester.pumpAndSettle();

      expect(find.text('残り 9 枚'), findsOneWidget);
    },
  );

  testWidgets('shows a loading indicator while uploading', (tester) async {
    when(
      () => repository.uploadPhoto(
        groupId: any(named: 'groupId'),
        bytes: any(named: 'bytes'),
      ),
    ).thenAnswer((_) => Completer<void>().future);

    await tester.pumpWidget(pumpApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets(
    'shows the daily limit message, zeroes the remaining count immediately, '
    'and stays at 0 once the forced refetch confirms it',
    (tester) async {
      // 別メンバーの撮影と競合して自分の撮影だけが上限超過で弾かれた状況を
      // 模す: 購読開始時点では残り1枚に見えていたが、実際にはDB側で既に
      // 上限に達しており(自分の撮影はphotosにINSERTされない)、明示的な
      // 再取得(invalidate)が呼ばれて初めて本当の値(0枚)が届く。
      var watchCallCount = 0;
      when(
        () => remainingShotsRepository.watchTodayShotsRemaining(
          groupId: any(named: 'groupId'),
        ),
      ).thenAnswer((_) {
        watchCallCount++;
        return Stream.value(watchCallCount == 1 ? 1 : 0);
      });
      when(
        () => repository.uploadPhoto(
          groupId: any(named: 'groupId'),
          bytes: any(named: 'bytes'),
        ),
      ).thenThrow(const DailyLimitReachedFailure());

      await tester.pumpWidget(pumpApp());
      await tester.pumpAndSettle();

      expect(find.text('残り 1 枚'), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('本日の撮影上限に達しました'), findsOneWidget);
      // 再取得が本当の値(0枚)を確認した後も、上書き解除で古い1枚に
      // 戻ったりせず0枚のまま表示され続けることを確認する。
      expect(find.text('残り 0 枚'), findsOneWidget);
    },
  );

  testWidgets('shows a generic error message on an unexpected failure', (
    tester,
  ) async {
    when(
      () => repository.uploadPhoto(
        groupId: any(named: 'groupId'),
        bytes: any(named: 'bytes'),
      ),
    ).thenThrow(const UnknownUploadPhotoFailure());

    await tester.pumpWidget(pumpApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('写真のアップロードに失敗しました。時間をおいて再度お試しください'), findsOneWidget);
    expect(find.text('残り 10 枚'), findsOneWidget);
  });

  testWidgets(
    'fails safe (shutter disabled) without crashing when the remaining '
    'count stream errors',
    (tester) async {
      when(
        () => remainingShotsRepository.watchTodayShotsRemaining(
          groupId: any(named: 'groupId'),
        ),
      ).thenAnswer(
        (_) => Stream<int>.error(Exception('get_today_shots_remaining failed')),
      );

      await tester.pumpWidget(pumpApp());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('残り 0 枚'), findsOneWidget);
      final shutterButton = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(shutterButton.onPressed, isNull);
    },
  );

  testWidgets(
    'shows a settings button when camera access is denied',
    (tester) async {
      CameraPlatform.instance = FakeCameraPlatform(
        createCameraError: CameraException(
          'CameraAccessDenied',
          'Camera access permission was denied.',
        ),
      );

      await tester.pumpWidget(pumpApp());
      await tester.pumpAndSettle();

      expect(find.text('カメラへのアクセスが許可されていません'), findsOneWidget);
      expect(find.text('設定を開く'), findsOneWidget);
      expect(find.text('再試行'), findsNothing);
    },
  );

  testWidgets(
    'shows a retry button for non-permission failures, and retrying '
    'recovers once the underlying cause is resolved',
    (tester) async {
      final fakePlatform = FakeCameraPlatform(
        createCameraError: CameraException(
          'cameraNotFound',
          'No camera available.',
        ),
      );
      CameraPlatform.instance = fakePlatform;

      await tester.pumpWidget(pumpApp());
      await tester.pumpAndSettle();

      expect(find.text('カメラを利用できません'), findsOneWidget);
      expect(find.text('再試行'), findsOneWidget);
      expect(find.text('設定を開く'), findsNothing);

      fakePlatform.createCameraError = null;
      await tester.tap(find.text('再試行'));
      await tester.pumpAndSettle();

      expect(find.byType(CameraPreview), findsOneWidget);
    },
  );

  testWidgets('ignores a second tap while the first capture is in flight', (
    tester,
  ) async {
    when(
      () => repository.uploadPhoto(
        groupId: any(named: 'groupId'),
        bytes: any(named: 'bytes'),
      ),
    ).thenAnswer((_) => Completer<void>().future);

    await tester.pumpWidget(pumpApp());
    await tester.pumpAndSettle();

    // 1回目のtapで_isCapturingが即座にtrueになるため、rebuildを挟まずに
    // 連打しても2回目は_onShutterPressed冒頭のガードで弾かれるはず。
    await tester.tap(find.byType(FloatingActionButton));
    await tester.tap(find.byType(FloatingActionButton), warnIfMissed: false);
    await tester.pump();

    verify(
      () => repository.uploadPhoto(
        groupId: any(named: 'groupId'),
        bytes: any(named: 'bytes'),
      ),
    ).called(1);
  });
}
