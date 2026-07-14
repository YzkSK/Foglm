import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/album/application/usecase/get_album_usecase.dart';
import 'package:foglm/features/album/domain/album_photo.dart';
import 'package:foglm/features/album/domain/album_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockAlbumRepository extends Mock implements AlbumRepository {}

void main() {
  late MockAlbumRepository repository;
  late GetAlbumUseCase useCase;

  setUp(() {
    repository = MockAlbumRepository();
    useCase = GetAlbumUseCase(repository);
  });

  test('delegates to the repository and returns its result', () async {
    final photos = [
      AlbumPhotoRow(
        id: 'photo-1',
        takenAt: DateTime.utc(2026, 7, 10, 12),
        takenDate: DateTime.utc(2026, 7, 10),
      ),
    ];
    when(
      () => repository.getAlbum(groupId: 'group-1'),
    ).thenAnswer((_) async => photos);

    final result = await useCase.call(groupId: 'group-1');

    expect(result, photos);
    verify(() => repository.getAlbum(groupId: 'group-1')).called(1);
  });

  test('propagates repository failures', () async {
    when(() => repository.getAlbum(groupId: 'group-1')).thenAnswer(
      (_) => Future<List<AlbumPhotoRow>>.error(Exception('unexpected')),
    );

    expect(
      () => useCase.call(groupId: 'group-1'),
      throwsA(isA<Exception>()),
    );
  });
}
