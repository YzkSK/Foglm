import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foglm/features/candidates/data/candidate_repository.dart';
import 'package:foglm/features/candidates/domain/candidate_photo.dart';
import 'package:foglm/features/candidates/presentation/candidate_list_screen.dart';
import 'package:foglm/features/candidates/presentation/vote_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockCandidateRepository extends Mock implements CandidateRepository {}

void main() {
  late MockCandidateRepository candidateRepository;

  setUp(() {
    candidateRepository = MockCandidateRepository();
  });

  Future<void> pumpScreen(WidgetTester tester) {
    final router = GoRouter(
      initialLocation: '/candidates',
      routes: [
        GoRoute(
          path: '/candidates',
          builder: (context, state) =>
              const CandidateListScreen(groupId: 'group-1'),
        ),
        GoRoute(
          path: '/candidates/vote',
          builder: (context, state) {
            final args = state.extra as VoteArgs?;
            return Scaffold(
              body: Text('投票画面プレースホルダー: ${args?.photoId}'),
            );
          },
        ),
      ],
    );

    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          candidateRepositoryProvider.overrideWithValue(candidateRepository),
        ],
        child: MaterialApp.router(routerConfig: router),
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

  testWidgets('tapping a candidate navigates to the vote screen', (
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

    expect(find.text('投票画面プレースホルダー: photo-1'), findsOneWidget);
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
