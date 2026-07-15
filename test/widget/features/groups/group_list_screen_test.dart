import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foglm/features/groups/data/group_repository.dart';
import 'package:foglm/features/groups/data/my_groups_provider.dart';
import 'package:foglm/features/groups/domain/my_group.dart';
import 'package:foglm/features/groups/presentation/group_list_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockGroupRepository extends Mock implements GroupRepository {}

void main() {
  late MockGroupRepository repository;

  setUp(() {
    repository = MockGroupRepository();
  });

  const soloGroup = MyGroupRow(
    id: 'solo-1',
    name: '自分',
    mode: 'solo',
    status: 'active',
  );
  const fixedGroup = MyGroupRow(
    id: 'group-1',
    name: '固定グループA',
    mode: 'group',
    status: 'active',
  );

  Future<void> pumpScreen(
    WidgetTester tester, {
    required List<MyGroupRow> groups,
  }) {
    final router = GoRouter(
      initialLocation: '/groups',
      routes: [
        GoRoute(
          path: '/groups',
          builder: (context, state) => const GroupListScreen(),
        ),
        GoRoute(
          path: '/camera',
          builder: (context, state) =>
              const Scaffold(body: Text('カメラ画面プレースホルダー')),
        ),
        GoRoute(
          path: '/groups/new',
          builder: (context, state) =>
              const Scaffold(body: Text('グループ作成画面プレースホルダー')),
        ),
        GoRoute(
          path: '/groups/new-event',
          builder: (context, state) =>
              const Scaffold(body: Text('イベントグループ作成画面プレースホルダー')),
        ),
      ],
    );

    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupRepositoryProvider.overrideWithValue(repository),
          myGroupsProvider.overrideWith((ref) async => groups),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  testWidgets('shows the solo tile and other groups', (tester) async {
    await pumpScreen(tester, groups: [soloGroup, fixedGroup]);
    await tester.pumpAndSettle();

    expect(find.text('自分'), findsOneWidget);
    expect(find.text('固定グループA'), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no other groups', (
    tester,
  ) async {
    await pumpScreen(tester, groups: [soloGroup]);
    await tester.pumpAndSettle();

    expect(find.text('参加しているグループはまだありません'), findsOneWidget);
  });

  testWidgets('retries loading groups when the retry button is tapped', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/groups',
      routes: [
        GoRoute(
          path: '/groups',
          builder: (context, state) => const GroupListScreen(),
        ),
      ],
    );
    // Riverpod 3のデフォルト自動リトライにより失敗直後の呼び出し回数が
    // 不定になるため、呼び出し回数ではなく最終的な表示状態で検証する。
    var shouldSucceed = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupRepositoryProvider.overrideWithValue(repository),
          myGroupsProvider.overrideWith((ref) async {
            if (!shouldSucceed) {
              throw Exception('unexpected');
            }
            return [soloGroup];
          }),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('グループ一覧の取得に失敗しました'), findsOneWidget);

    shouldSucceed = true;
    await tester.tap(find.text('再読み込み'));
    await tester.pumpAndSettle();

    expect(find.text('自分'), findsOneWidget);
  });

  testWidgets('reloads groups on pull-to-refresh', (tester) async {
    var callCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupRepositoryProvider.overrideWithValue(repository),
          myGroupsProvider.overrideWith((ref) async {
            callCount++;
            return [soloGroup];
          }),
        ],
        child: const MaterialApp(home: GroupListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.fling(
      find.byType(RefreshIndicator),
      const Offset(0, 300),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(callCount, 2);
  });

  testWidgets('navigates to the create-group screen', (tester) async {
    await pumpScreen(tester, groups: [soloGroup]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('固定グループを作成'));
    await tester.pumpAndSettle();

    expect(find.text('グループ作成画面プレースホルダー'), findsOneWidget);
  });

  testWidgets('navigates to the create-event-group screen', (tester) async {
    await pumpScreen(tester, groups: [soloGroup]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('イベントグループを作成'));
    await tester.pumpAndSettle();

    expect(find.text('イベントグループ作成画面プレースホルダー'), findsOneWidget);
  });

  group('join by invite code dialog', () {
    testWidgets('shows a validation error for a blank code', (tester) async {
      await pumpScreen(tester, groups: [soloGroup]);
      await tester.pumpAndSettle();

      await tester.tap(find.text('招待コードで参加する'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('参加する'));
      await tester.pump();

      expect(find.text('招待コードを入力してください'), findsOneWidget);
      verifyNever(
        () => repository.joinGroupByCode(code: any(named: 'code')),
      );
    });

    testWidgets('closes the dialog and refreshes the list on success', (
      tester,
    ) async {
      when(
        () => repository.joinGroupByCode(code: 'ABC123'),
      ).thenAnswer((_) async {});

      await pumpScreen(tester, groups: [soloGroup]);
      await tester.pumpAndSettle();

      await tester.tap(find.text('招待コードで参加する'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'ABC123');
      await tester.tap(find.text('参加する'));
      await tester.pumpAndSettle();

      expect(find.text('招待コードで参加する'), findsOneWidget);
      expect(find.text('グループに参加しました'), findsOneWidget);
      verify(() => repository.joinGroupByCode(code: 'ABC123')).called(1);
    });

    testWidgets('shows an error message when the code is invalid', (
      tester,
    ) async {
      when(
        () => repository.joinGroupByCode(code: 'BADCODE'),
      ).thenThrow(Exception('invalid code'));

      await pumpScreen(tester, groups: [soloGroup]);
      await tester.pumpAndSettle();

      await tester.tap(find.text('招待コードで参加する'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'BADCODE');
      await tester.tap(find.text('参加する'));
      await tester.pumpAndSettle();

      expect(find.text('招待コードが正しくないか、参加できませんでした'), findsOneWidget);
    });
  });
}
