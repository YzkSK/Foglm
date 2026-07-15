import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foglm/features/candidates/data/candidate_repository.dart';
import 'package:foglm/features/candidates/data/vote_repository.dart';
import 'package:foglm/features/candidates/domain/candidate_photo.dart';
import 'package:foglm/features/candidates/presentation/candidate_list_screen.dart';
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

  Future<void> pumpScreen(WidgetTester tester) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          candidateRepositoryProvider.overrideWithValue(candidateRepository),
          voteRepositoryProvider.overrideWithValue(voteRepository),
        ],
        child: const MaterialApp(
          home: CandidateListScreen(groupId: 'group-1'),
        ),
      ),
    );
  }

  testWidgets('shows the candidates with their vote counts', (tester) async {
    when(
      () => candidateRepository.getTodayCandidates(groupId: 'group-1'),
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

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.text('2票'), findsOneWidget);
  });

  testWidgets('tapping a candidate shows a confirmation dialog', (
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

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(find.text('この写真に投票しますか?'), findsOneWidget);
    verifyNever(() => voteRepository.castVote(photoId: any(named: 'photoId')));
  });

  testWidgets('cancelling the confirmation dialog does not cast a vote', (
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

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();

    expect(find.text('この写真に投票しますか?'), findsNothing);
    verifyNever(() => voteRepository.castVote(photoId: any(named: 'photoId')));
  });

  testWidgets('confirming the dialog casts a vote for the candidate', (
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

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();
    await tester.tap(find.text('投票する'));
    await tester.pumpAndSettle();

    verify(() => voteRepository.castVote(photoId: 'photo-1')).called(1);
  });

  testWidgets(
    'shows a loading indicator only on the tapped tile, and disables '
    'the others',
    (tester) async {
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
          CandidatePhotoRow(
            id: 'photo-2',
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

      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('投票する'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      final tiles = tester.widgetList<InkWell>(find.byType(InkWell)).toList();
      expect(tiles[0].onTap, isNull);
      expect(tiles[1].onTap, isNull);
    },
  );

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

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();
    await tester.tap(find.text('投票する'));
    await tester.pumpAndSettle();

    expect(find.text('投票に失敗しました。時間をおいて再度お試しください'), findsOneWidget);
  });

  testWidgets('shows an empty message when there are no candidates', (
    tester,
  ) async {
    when(
      () => candidateRepository.getTodayCandidates(groupId: 'group-1'),
    ).thenAnswer((_) async => []);

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.text('まだ候補写真がありません'), findsOneWidget);
  });

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
