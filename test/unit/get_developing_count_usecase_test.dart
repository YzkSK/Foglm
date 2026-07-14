import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/album/application/usecase/get_developing_count_usecase.dart';
import 'package:foglm/features/album/domain/album_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockAlbumRepository extends Mock implements AlbumRepository {}

void main() {
  late MockAlbumRepository repository;
  late GetDevelopingCountUseCase useCase;

  setUp(() {
    repository = MockAlbumRepository();
    useCase = GetDevelopingCountUseCase(repository);
  });

  test('delegates to the repository and returns its result', () async {
    when(
      () => repository.getDevelopingCount(groupId: 'group-1'),
    ).thenAnswer((_) async => 3);

    final result = await useCase.call(groupId: 'group-1');

    expect(result, 3);
    verify(() => repository.getDevelopingCount(groupId: 'group-1')).called(1);
  });

  test('propagates repository failures', () async {
    when(
      () => repository.getDevelopingCount(groupId: 'group-1'),
    ).thenAnswer((_) => Future<int>.error(Exception('unexpected')));

    expect(
      () => useCase.call(groupId: 'group-1'),
      throwsA(isA<Exception>()),
    );
  });
}
