import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/candidates/application/usecase/cast_vote_usecase.dart';
import 'package:foglm/features/candidates/domain/vote_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockVoteRepository extends Mock implements VoteRepository {}

void main() {
  late MockVoteRepository repository;
  late CastVoteUseCase useCase;

  setUp(() {
    repository = MockVoteRepository();
    useCase = CastVoteUseCase(repository);
  });

  test('delegates to the repository', () async {
    when(
      () => repository.castVote(photoId: 'photo-1'),
    ).thenAnswer((_) async {});

    await useCase.call(photoId: 'photo-1');

    verify(() => repository.castVote(photoId: 'photo-1')).called(1);
  });

  test('propagates repository failures', () async {
    when(
      () => repository.castVote(photoId: 'photo-1'),
    ).thenThrow(Exception('unexpected'));

    expect(
      () => useCase.call(photoId: 'photo-1'),
      throwsA(isA<Exception>()),
    );
  });
}
