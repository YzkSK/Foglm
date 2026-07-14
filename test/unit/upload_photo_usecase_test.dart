import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/camera/application/usecase/upload_photo_usecase.dart';
import 'package:foglm/features/camera/domain/photo_repository.dart';
import 'package:foglm/features/camera/domain/upload_photo_failure.dart';
import 'package:mocktail/mocktail.dart';

class MockPhotoRepository extends Mock implements PhotoRepository {}

void main() {
  late MockPhotoRepository repository;
  late UploadPhotoUseCase useCase;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    repository = MockPhotoRepository();
    useCase = UploadPhotoUseCase(repository);
  });

  test('delegates to the repository', () async {
    when(
      () => repository.uploadPhoto(
        groupId: any(named: 'groupId'),
        bytes: any(named: 'bytes'),
      ),
    ).thenAnswer((_) async {});

    await useCase.call(groupId: 'group-1', bytes: Uint8List.fromList([1]));

    verify(
      () => repository.uploadPhoto(
        groupId: 'group-1',
        bytes: Uint8List.fromList([1]),
      ),
    ).called(1);
  });

  test('propagates repository failures', () async {
    when(
      () => repository.uploadPhoto(
        groupId: any(named: 'groupId'),
        bytes: any(named: 'bytes'),
      ),
    ).thenThrow(const DailyLimitReachedFailure());

    expect(
      () => useCase.call(groupId: 'group-1', bytes: Uint8List.fromList([1])),
      throwsA(isA<DailyLimitReachedFailure>()),
    );
  });
}
