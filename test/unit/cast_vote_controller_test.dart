import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/candidates/application/cast_vote_controller.dart';
import 'package:foglm/features/candidates/application/today_candidates_provider.dart';
import 'package:foglm/features/candidates/application/usecase/cast_vote_usecase.dart';
import 'package:foglm/features/candidates/application/usecase/get_today_candidates_usecase.dart';
import 'package:foglm/features/candidates/data/vote_repository.dart';
import 'package:foglm/features/candidates/domain/vote_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockCastVoteUseCase extends Mock implements CastVoteUseCase {}

class MockGetTodayCandidatesUseCase extends Mock
    implements GetTodayCandidatesUseCase {}

class MockVoteRepository extends Mock implements VoteRepository {}

void main() {
  late MockCastVoteUseCase castVoteUseCase;
  late MockGetTodayCandidatesUseCase getTodayCandidatesUseCase;
  late ProviderContainer container;

  setUp(() {
    castVoteUseCase = MockCastVoteUseCase();
    getTodayCandidatesUseCase = MockGetTodayCandidatesUseCase();
    container = ProviderContainer(
      overrides: [
        castVoteUseCaseProvider.overrideWithValue(castVoteUseCase),
        getTodayCandidatesUseCaseProvider.overrideWithValue(
          getTodayCandidatesUseCase,
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  test('submit calls the usecase and resolves to data on success', () async {
    when(
      () => castVoteUseCase.call(photoId: 'photo-1'),
    ).thenAnswer((_) async {});
    when(
      () => getTodayCandidatesUseCase.call(groupId: 'group-1'),
    ).thenAnswer((_) async => []);

    await container
        .read(castVoteControllerProvider.notifier)
        .submit(groupId: 'group-1', photoId: 'photo-1');

    final state = container.read(castVoteControllerProvider);
    expect(state, const AsyncData<void>(null));
    verify(() => castVoteUseCase.call(photoId: 'photo-1')).called(1);
  });

  test(
    'invalidates todayCandidatesProvider for the group on success',
    () async {
      when(
        () => castVoteUseCase.call(photoId: 'photo-1'),
      ).thenAnswer((_) async {});
      when(
        () => getTodayCandidatesUseCase.call(groupId: 'group-1'),
      ).thenAnswer((_) async => []);

      await container.read(todayCandidatesProvider('group-1').future);
      await container
          .read(castVoteControllerProvider.notifier)
          .submit(groupId: 'group-1', photoId: 'photo-1');
      await container.read(todayCandidatesProvider('group-1').future);

      verify(
        () => getTodayCandidatesUseCase.call(groupId: 'group-1'),
      ).called(2);
    },
  );

  test('submit exposes the usecase failure as AsyncError', () async {
    when(
      () => castVoteUseCase.call(photoId: 'photo-1'),
    ).thenThrow(Exception('unexpected'));

    await container
        .read(castVoteControllerProvider.notifier)
        .submit(groupId: 'group-1', photoId: 'photo-1');

    final state = container.read(castVoteControllerProvider);
    expect(state.hasError, isTrue);
    verifyNever(
      () => getTodayCandidatesUseCase.call(groupId: 'group-1'),
    );
  });

  group('default wiring', () {
    test(
      'castVoteControllerProvider uses the repository through the default '
      'usecase provider',
      () async {
        final repository = MockVoteRepository();
        final wiredContainer = ProviderContainer(
          overrides: [voteRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(wiredContainer.dispose);

        when(
          () => repository.castVote(photoId: 'photo-1'),
        ).thenAnswer((_) async {});

        await wiredContainer
            .read(castVoteControllerProvider.notifier)
            .submit(groupId: 'group-1', photoId: 'photo-1');

        verify(() => repository.castVote(photoId: 'photo-1')).called(1);
      },
    );
  });
}
