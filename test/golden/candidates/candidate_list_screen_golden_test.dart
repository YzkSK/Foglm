import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/candidates/data/candidate_repository.dart';
import 'package:foglm/features/candidates/data/vote_repository.dart';
import 'package:foglm/features/candidates/domain/candidate_photo.dart';
import 'package:foglm/features/candidates/presentation/candidate_list_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockCandidateRepository extends Mock implements CandidateRepository {}

class _MockVoteRepository extends Mock implements VoteRepository {}

Widget _pumpApp({CandidateRepository? candidateRepository}) {
  return ProviderScope(
    overrides: [
      candidateRepositoryProvider.overrideWithValue(
        candidateRepository ?? _MockCandidateRepository(),
      ),
      voteRepositoryProvider.overrideWithValue(_MockVoteRepository()),
    ],
    child: const MaterialApp(
      home: CandidateListScreen(groupId: 'test-group-id'),
    ),
  );
}

void main() {
  unawaited(
    goldenTest(
      'CandidateListScreen shows a loading indicator',
      fileName: 'candidate_list_screen_loading',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      // CircularProgressIndicatorの無限アニメーションが絡むため、
      // pumpAndSettleではなく固定回数pumpする戦略を使う
      // (camera_screen_no_cameraと同様)。
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
      'CandidateListScreen shows an error state',
      fileName: 'candidate_list_screen_error',
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
      'CandidateListScreen shows an empty state',
      fileName: 'candidate_list_screen_empty',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      builder: () {
        final repository = _MockCandidateRepository();
        when(
          () => repository.getTodayCandidates(groupId: 'test-group-id'),
        ).thenAnswer((_) async => []);
        return _pumpApp(candidateRepository: repository);
      },
    ),
  );

  unawaited(
    goldenTest(
      'CandidateListScreen shows the candidate grid with vote status',
      fileName: 'candidate_list_screen_normal',
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
              votedByMe: true,
            ),
            CandidatePhotoRow(
              id: 'photo-2',
              blurredUrl: '',
              voteCount: 1,
              votedByMe: false,
            ),
          ],
        );
        return _pumpApp(candidateRepository: repository);
      },
    ),
  );
}
