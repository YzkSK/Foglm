import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foglm/features/candidates/data/candidate_repository.dart';
import 'package:foglm/features/candidates/data/vote_repository.dart';
import 'package:foglm/features/candidates/domain/candidate_photo.dart';
import 'package:foglm/features/candidates/presentation/vote_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockCandidateRepository extends Mock implements CandidateRepository {}

class MockVoteRepository extends Mock implements VoteRepository {}

void main() {
  late MockCandidateRepository candidateRepository;
  late MockVoteRepository voteRepository;

  setUp(() {
    candidateRepository = MockCandidateRepository();
    voteRepository = MockVoteRepository();
  });

  Future<void> pumpScreen(WidgetTester tester, {String photoId = 'photo-1'}) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          candidateRepositoryProvider.overrideWithValue(candidateRepository),
          voteRepositoryProvider.overrideWithValue(voteRepository),
        ],
        child: MaterialApp(
          home: VoteScreen(groupId: 'group-1', photoId: photoId),
        ),
      ),
    );
  }

  testWidgets('shows the vote count for the candidate', (tester) async {
    when(
      () => candidateRepository.getTodayCandidates(groupId: 'group-1'),
    ).thenAnswer(
      (_) async => const [
        CandidatePhotoRow(
          id: 'photo-1',
          blurredUrl: '',
          voteCount: 3,
          votedByMe: false,
        ),
      ],
    );

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.text('3票'), findsOneWidget);
    expect(find.text('この写真に投票する'), findsOneWidget);
  });

  testWidgets('shows the voted state when already voted for this photo', (
    tester,
  ) async {
    when(
      () => candidateRepository.getTodayCandidates(groupId: 'group-1'),
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

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.text('1票(投票済み)'), findsOneWidget);
    expect(find.text('この写真に投票し直す'), findsOneWidget);
  });

  testWidgets('tapping the vote button casts a vote for the photo', (
    tester,
  ) async {
    when(
      () => candidateRepository.getTodayCandidates(groupId: 'group-1'),
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
    when(
      () => voteRepository.castVote(photoId: 'photo-1'),
    ).thenAnswer((_) async {});

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('この写真に投票する'));
    await tester.pumpAndSettle();

    verify(() => voteRepository.castVote(photoId: 'photo-1')).called(1);
  });

  testWidgets('shows a loading indicator while voting', (tester) async {
    when(
      () => candidateRepository.getTodayCandidates(groupId: 'group-1'),
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
    when(
      () => voteRepository.castVote(photoId: 'photo-1'),
    ).thenAnswer((_) => Completer<void>().future);

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('この写真に投票する'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows a snackbar when casting a vote fails', (tester) async {
    when(
      () => candidateRepository.getTodayCandidates(groupId: 'group-1'),
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
    when(
      () => voteRepository.castVote(photoId: 'photo-1'),
    ).thenThrow(Exception('unexpected'));

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('この写真に投票する'));
    await tester.pumpAndSettle();

    expect(find.text('投票に失敗しました。時間をおいて再度お試しください'), findsOneWidget);
  });

  testWidgets(
    'shows a fallback message when the photo is no longer among the '
    'candidates',
    (tester) async {
      when(
        () => candidateRepository.getTodayCandidates(groupId: 'group-1'),
      ).thenAnswer((_) async => const []);

      await pumpScreen(tester, photoId: 'missing-photo');
      await tester.pumpAndSettle();

      expect(find.text('この写真は表示できません'), findsOneWidget);
    },
  );

  testWidgets('shows an error message when the candidates fail to load', (
    tester,
  ) async {
    when(
      () => candidateRepository.getTodayCandidates(groupId: 'group-1'),
    ).thenThrow(Exception('unexpected'));

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.text('候補一覧の取得に失敗しました'), findsOneWidget);
  });
}
