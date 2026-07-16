import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foglm/features/candidates/data/candidate_repository.dart';
import 'package:foglm/features/candidates/data/vote_repository.dart';
import 'package:foglm/features/candidates/domain/candidate_photo.dart';
import 'package:foglm/features/candidates/presentation/vote_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockCandidateRepository extends Mock implements CandidateRepository {}

class _MockVoteRepository extends Mock implements VoteRepository {}

Widget _pumpApp({
  CandidateRepository? candidateRepository,
  VoteRepository? voteRepository,
  String photoId = 'photo-1',
}) {
  return ProviderScope(
    overrides: [
      candidateRepositoryProvider.overrideWithValue(
        candidateRepository ?? _MockCandidateRepository(),
      ),
      voteRepositoryProvider.overrideWithValue(
        voteRepository ?? _MockVoteRepository(),
      ),
    ],
    child: MaterialApp(
      home: VoteScreen(groupId: 'test-group-id', photoId: photoId),
    ),
  );
}

void main() {
  unawaited(
    goldenTest(
      'VoteScreen shows a loading indicator',
      fileName: 'vote_screen_loading',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      pumpBeforeTest: pumpNTimes(10),
      builder: () {
        final repository = _MockCandidateRepository();
        when(
          () => repository.getTodayCandidates(groupId: 'test-group-id'),
        ).thenAnswer((_) => Completer<List<CandidatePhotoRow>>().future);
        return _pumpApp(candidateRepository: repository);
      },
    ),
  );

  unawaited(
    goldenTest(
      'VoteScreen shows an error state',
      fileName: 'vote_screen_error',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      builder: () {
        final repository = _MockCandidateRepository();
        when(
          () => repository.getTodayCandidates(groupId: 'test-group-id'),
        ).thenThrow(Exception('unexpected'));
        return _pumpApp(candidateRepository: repository);
      },
    ),
  );

  unawaited(
    goldenTest(
      'VoteScreen shows the enlarged photo with a vote button',
      fileName: 'vote_screen_normal',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      builder: () {
        final repository = _MockCandidateRepository();
        when(
          () => repository.getTodayCandidates(groupId: 'test-group-id'),
        ).thenAnswer(
          (_) async => const [
            CandidatePhotoRow(
              id: 'photo-1',
              blurredUrl: '',
              voteCount: 2,
              votedByMe: false,
            ),
          ],
        );
        return _pumpApp(candidateRepository: repository);
      },
    ),
  );

  unawaited(
    goldenTest(
      'VoteScreen shows the voted state',
      fileName: 'vote_screen_voted',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      builder: () {
        final repository = _MockCandidateRepository();
        when(
          () => repository.getTodayCandidates(groupId: 'test-group-id'),
        ).thenAnswer(
          (_) async => const [
            CandidatePhotoRow(
              id: 'photo-1',
              blurredUrl: '',
              voteCount: 1,
              votedByMe: true,
            ),
          ],
        );
        return _pumpApp(candidateRepository: repository);
      },
    ),
  );

  unawaited(
    goldenTest(
      'VoteScreen shows a loading indicator while voting',
      fileName: 'vote_screen_submitting',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      pumpBeforeTest: (tester) async {
        await tester.pumpAndSettle();
        await tester.tap(find.text('この写真に投票する'));
        await tester.pump();
      },
      builder: () {
        final candidateRepository = _MockCandidateRepository();
        when(
          () => candidateRepository.getTodayCandidates(
            groupId: 'test-group-id',
          ),
        ).thenAnswer(
          (_) async => const [
            CandidatePhotoRow(
              id: 'photo-1',
              blurredUrl: '',
              voteCount: 0,
              votedByMe: false,
            ),
          ],
        );
        final voteRepository = _MockVoteRepository();
        when(
          () => voteRepository.castVote(photoId: 'photo-1'),
        ).thenAnswer((_) => Completer<void>().future);
        return _pumpApp(
          candidateRepository: candidateRepository,
          voteRepository: voteRepository,
        );
      },
    ),
  );
}
