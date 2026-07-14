import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foglm/features/camera/application/upload_photo_controller.dart';
import 'package:foglm/features/camera/application/usecase/upload_photo_usecase.dart';
import 'package:foglm/features/camera/data/photo_repository.dart';
import 'package:foglm/features/camera/domain/photo_repository.dart';
import 'package:foglm/features/camera/domain/upload_photo_failure.dart';
import 'package:mocktail/mocktail.dart';

class MockUploadPhotoUseCase extends Mock implements UploadPhotoUseCase {}

class MockPhotoRepository extends Mock implements PhotoRepository {}

void main() {
  late MockUploadPhotoUseCase useCase;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    useCase = MockUploadPhotoUseCase();
    container = ProviderContainer(
      overrides: [uploadPhotoUseCaseProvider.overrideWithValue(useCase)],
    );
    addTearDown(container.dispose);
  });

  test('submit calls the usecase and resolves to data on success', () async {
    when(
      () => useCase.call(
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
      () => useCase.call(groupId: 'group-1', bytes: Uint8List.fromList([1])),
    ).called(1);
  });

  test('submit exposes the usecase failure as AsyncError', () async {
    when(
      () => useCase.call(
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

  group('default wiring', () {
    test(
      'uploadPhotoControllerProvider uses the repository through the '
      'default usecase provider',
      () async {
        final repository = MockPhotoRepository();
        final wiredContainer = ProviderContainer(
          overrides: [photoRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(wiredContainer.dispose);

        when(
          () => repository.uploadPhoto(
            groupId: any(named: 'groupId'),
            bytes: any(named: 'bytes'),
          ),
        ).thenAnswer((_) async {});

        await wiredContainer
            .read(uploadPhotoControllerProvider.notifier)
            .submit(groupId: 'group-1', bytes: Uint8List.fromList([1]));

        verify(
          () => repository.uploadPhoto(
            groupId: 'group-1',
            bytes: Uint8List.fromList([1]),
          ),
        ).called(1);
      },
    );
  });
}
