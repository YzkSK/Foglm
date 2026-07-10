import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foglm/features/camera/application/upload_photo_controller.dart';
import 'package:foglm/features/camera/data/photo_repository.dart';
import 'package:foglm/features/camera/domain/upload_photo_failure.dart';
import 'package:mocktail/mocktail.dart';

class MockPhotoRepository extends Mock implements PhotoRepository {}

void main() {
  late MockPhotoRepository repository;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    repository = MockPhotoRepository();
    container = ProviderContainer(
      overrides: [photoRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
  });

  test('submit calls the repository and resolves to data on success', () async {
    when(
      () => repository.uploadPhoto(
        groupId: any(named: 'groupId'),
        bytes: any(named: 'bytes'),
      ),
    ).thenAnswer((_) async {});

    await container
        .read(uploadPhotoControllerProvider.notifier)
        .submit(groupId: 'group-1', bytes: Uint8List.fromList([1]));

    final state = container.read(uploadPhotoControllerProvider);
    expect(state, const AsyncData<void>(null));
    verify(
      () => repository.uploadPhoto(
        groupId: 'group-1',
        bytes: Uint8List.fromList([1]),
      ),
    ).called(1);
  });

  test('submit exposes the repository failure as AsyncError', () async {
    when(
      () => repository.uploadPhoto(
        groupId: any(named: 'groupId'),
        bytes: any(named: 'bytes'),
      ),
    ).thenThrow(const DailyLimitReachedFailure());

    await container
        .read(uploadPhotoControllerProvider.notifier)
        .submit(groupId: 'group-1', bytes: Uint8List.fromList([1]));

    final state = container.read(uploadPhotoControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.error, isA<DailyLimitReachedFailure>());
  });
}
