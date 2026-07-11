import 'dart:async';
import 'dart:typed_data';

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

  testWidgets('shows the remaining count reported by Realtime and uploads '
      'the captured photo', (tester) async {
    when(
      () => repository.uploadPhoto(
        groupId: any(named: 'groupId'),
        bytes: any(named: 'bytes'),
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(pumpApp());
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
    // 残数の減少はupload成功そのものではなく、Realtime経由での
    // get_today_shots_remaining再取得によって反映される(仕様書 5.2.3参照)。
    expect(find.text('残り 10 枚'), findsOneWidget);
  });

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
    'shows the daily limit message and zeroes the remaining count when '
    'the server reports daily_limit_reached',
    (tester) async {
      when(
        () => repository.uploadPhoto(
          groupId: any(named: 'groupId'),
          bytes: any(named: 'bytes'),
        ),
      ).thenThrow(const DailyLimitReachedFailure());

      await tester.pumpWidget(pumpApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      expect(find.text('本日の撮影上限に達しました'), findsOneWidget);
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
