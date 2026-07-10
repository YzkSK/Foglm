import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/candidates/application/cast_vote_controller.dart';
import 'package:foglm/features/candidates/data/candidate_repository.dart';
import 'package:foglm/features/candidates/data/today_candidates_provider.dart';
import 'package:foglm/features/candidates/data/vote_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockVoteRepository extends Mock implements VoteRepository {}

class MockCandidateRepository extends Mock implements CandidateRepository {}

void main() {
  late MockVoteRepository voteRepository;
  late MockCandidateRepository candidateRepository;
  late ProviderContainer container;

  setUp(() {
    voteRepository = MockVoteRepository();
    candidateRepository = MockCandidateRepository();
    container = ProviderContainer(
      overrides: [
        voteRepositoryProvider.overrideWithValue(voteRepository),
        candidateRepositoryProvider.overrideWithValue(candidateRepository),
      ],
    );
    addTearDown(container.dispose);
  });

  test('submit calls the repository and resolves to data on success', () async {
    when(
      () => voteRepository.castVote(photoId: 'photo-1'),
    ).thenAnswer((_) async {});
    when(
      () => candidateRepository.getTodayCandidates(groupId: 'group-1'),
    ).thenAnswer((_) async => []);

    await container
        .read(castVoteControllerProvider.notifier)
        .submit(groupId: 'group-1', photoId: 'photo-1');

    final state = container.read(castVoteControllerProvider);
    expect(state, const AsyncData<void>(null));
    verify(() => voteRepository.castVote(photoId: 'photo-1')).called(1);
  });

  test(
    'invalidates todayCandidatesProvider for the group on success',
    () async {
      when(
        () => voteRepository.castVote(photoId: 'photo-1'),
      ).thenAnswer((_) async {});
      when(
        () => candidateRepository.getTodayCandidates(groupId: 'group-1'),
      ).thenAnswer((_) async => []);

      await container.read(todayCandidatesProvider('group-1').future);
      await container
          .read(castVoteControllerProvider.notifier)
          .submit(groupId: 'group-1', photoId: 'photo-1');
      await container.read(todayCandidatesProvider('group-1').future);

      verify(
        () => candidateRepository.getTodayCandidates(groupId: 'group-1'),
      ).called(2);
    },
  );

  test('submit exposes the repository failure as AsyncError', () async {
    when(
      () => voteRepository.castVote(photoId: 'photo-1'),
    ).thenThrow(Exception('unexpected'));

    await container
        .read(castVoteControllerProvider.notifier)
        .submit(groupId: 'group-1', photoId: 'photo-1');

    final state = container.read(castVoteControllerProvider);
    expect(state.hasError, isTrue);
    verifyNever(
      () => candidateRepository.getTodayCandidates(groupId: 'group-1'),
    );
  });
}
