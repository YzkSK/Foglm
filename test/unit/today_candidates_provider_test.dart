import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/candidates/application/today_candidates_provider.dart';
import 'package:foglm/features/candidates/application/usecase/get_today_candidates_usecase.dart';
import 'package:foglm/features/candidates/data/candidate_repository.dart'
    show candidateRepositoryProvider;
import 'package:foglm/features/candidates/domain/candidate_photo.dart';
import 'package:foglm/features/candidates/domain/candidate_repository.dart'
    show CandidateRepository;
import 'package:mocktail/mocktail.dart';

class MockGetTodayCandidatesUseCase extends Mock
    implements GetTodayCandidatesUseCase {}

class MockCandidateRepository extends Mock implements CandidateRepository {}

void main() {
  late MockGetTodayCandidatesUseCase useCase;
  late ProviderContainer container;

  setUp(() {
    useCase = MockGetTodayCandidatesUseCase();
    container = ProviderContainer(
      overrides: [getTodayCandidatesUseCaseProvider.overrideWithValue(useCase)],
    );
    addTearDown(container.dispose);
  });

  test('resolves to the candidates returned by the usecase', () async {
    const candidates = [
      CandidatePhotoRow(
        id: 'photo-1',
        blurredUrl: 'https://example.com/1.jpg',
        voteCount: 1,
        votedByMe: true,
      ),
    ];
    when(
      () => useCase.call(groupId: 'group-1'),
    ).thenAnswer((_) async => candidates);

    final result = await container.read(
      todayCandidatesProvider('group-1').future,
    );

    expect(result, candidates);
    verify(() => useCase.call(groupId: 'group-1')).called(1);
  });

  test('requests candidates independently per groupId', () async {
    when(
      () => useCase.call(groupId: any(named: 'groupId')),
    ).thenAnswer((_) async => []);

    await container.read(todayCandidatesProvider('group-1').future);
    await container.read(todayCandidatesProvider('group-2').future);

    verify(() => useCase.call(groupId: 'group-1')).called(1);
    verify(() => useCase.call(groupId: 'group-2')).called(1);
  });

  test('exposes the usecase failure as AsyncError', () async {
    when(() => useCase.call(groupId: 'group-1')).thenAnswer(
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

  group('default wiring', () {
    test(
      'todayCandidatesProvider uses the repository through the default '
      'usecase provider',
      () async {
        final repository = MockCandidateRepository();
        final wiredContainer = ProviderContainer(
          overrides: [
            candidateRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(wiredContainer.dispose);

        when(
          () => repository.getTodayCandidates(groupId: 'group-1'),
        ).thenAnswer((_) async => []);

        final result = await wiredContainer.read(
          todayCandidatesProvider('group-1').future,
        );

        expect(result, isEmpty);
        verify(
          () => repository.getTodayCandidates(groupId: 'group-1'),
        ).called(1);
      },
    );
  });
}
