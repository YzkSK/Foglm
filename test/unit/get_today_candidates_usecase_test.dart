import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/candidates/application/usecase/get_today_candidates_usecase.dart';
import 'package:foglm/features/candidates/domain/candidate_photo.dart';
import 'package:foglm/features/candidates/domain/candidate_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockCandidateRepository extends Mock implements CandidateRepository {}

void main() {
  late MockCandidateRepository repository;
  late GetTodayCandidatesUseCase useCase;

  setUp(() {
    repository = MockCandidateRepository();
    useCase = GetTodayCandidatesUseCase(repository);
  });

  test('delegates to the repository and returns its result', () async {
    const candidates = [
      CandidatePhotoRow(
        id: 'photo-1',
        blurredUrl: 'https://example.com/1.jpg',
        voteCount: 1,
        votedByMe: true,
      ),
    ];
    when(
      () => repository.getTodayCandidates(groupId: 'group-1'),
    ).thenAnswer((_) async => candidates);

    final result = await useCase.call(groupId: 'group-1');

    expect(result, candidates);
    verify(() => repository.getTodayCandidates(groupId: 'group-1')).called(1);
  });

  test('propagates repository failures', () async {
    when(() => repository.getTodayCandidates(groupId: 'group-1')).thenAnswer(
      (_) => Future<List<CandidatePhotoRow>>.error(Exception('unexpected')),
    );

    expect(
      () => useCase.call(groupId: 'group-1'),
      throwsA(isA<Exception>()),
    );
  });
}
