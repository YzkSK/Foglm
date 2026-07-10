import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/candidates/data/candidate_repository.dart';
import 'package:foglm/features/candidates/data/today_candidates_provider.dart';
import 'package:foglm/features/candidates/domain/candidate_photo.dart';
import 'package:mocktail/mocktail.dart';

class MockCandidateRepository extends Mock implements CandidateRepository {}

void main() {
  late MockCandidateRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = MockCandidateRepository();
    container = ProviderContainer(
      overrides: [candidateRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
  });

  test('resolves to the candidates returned by the repository', () async {
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

    final result = await container.read(
      todayCandidatesProvider('group-1').future,
    );

    expect(result, candidates);
    verify(() => repository.getTodayCandidates(groupId: 'group-1')).called(1);
  });

  test('requests candidates independently per groupId', () async {
    when(
      () => repository.getTodayCandidates(groupId: any(named: 'groupId')),
    ).thenAnswer((_) async => []);

    await container.read(todayCandidatesProvider('group-1').future);
    await container.read(todayCandidatesProvider('group-2').future);

    verify(() => repository.getTodayCandidates(groupId: 'group-1')).called(1);
    verify(() => repository.getTodayCandidates(groupId: 'group-2')).called(1);
  });

  test('exposes the repository failure as AsyncError', () async {
    when(() => repository.getTodayCandidates(groupId: 'group-1')).thenAnswer(
      (_) => Future<List<CandidatePhotoRow>>.error(Exception('unexpected')),
    );

    final subscription = container.listen(
      todayCandidatesProvider('group-1'),
      (_, _) {},
    );
    addTearDown(subscription.close);

    await pumpEventQueue();

    expect(container.read(todayCandidatesProvider('group-1')).hasError, isTrue);
  });
}
