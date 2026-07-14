import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foglm/features/groups/data/group_repository.dart';
import 'package:foglm/features/groups/domain/group_repository.dart';
import 'package:foglm/features/groups/presentation/leave_group_confirm_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockGroupRepository extends Mock implements GroupRepository {}

void main() {
  late MockGroupRepository repository;

  setUp(() {
    repository = MockGroupRepository();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/groups',
      routes: [
        GoRoute(
          path: '/groups',
          builder: (context, state) =>
              const Scaffold(body: Text('グループ一覧画面プレースホルダー')),
        ),
        GoRoute(
          path: '/groups/leave',
          builder: (context, state) => const LeaveGroupConfirmScreen(
            groupId: 'group-1',
            groupName: 'テストグループ',
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [groupRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    unawaited(router.push('/groups/leave'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the group name in the confirmation message', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('「テストグループ」を脱退しますか?'), findsOneWidget);
  });

  testWidgets('navigates to the group list screen on success', (
    tester,
  ) async {
    when(
      () => repository.leaveGroup(groupId: 'group-1'),
    ).thenAnswer((_) async {});

    await pumpScreen(tester);

    await tester.tap(find.text('脱退する'));
    await tester.pumpAndSettle();

    expect(find.text('グループ一覧画面プレースホルダー'), findsOneWidget);
    verify(() => repository.leaveGroup(groupId: 'group-1')).called(1);
  });

  testWidgets('shows an error message when the repository fails', (
    tester,
  ) async {
    when(
      () => repository.leaveGroup(groupId: 'group-1'),
    ).thenThrow(Exception('unexpected'));

    await pumpScreen(tester);

    await tester.tap(find.text('脱退する'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        '脱退に失敗しました。既に脱退済みの可能性があります。'
        'グループ一覧の状態をご確認のうえ、必要であれば再度お試しください',
      ),
      findsOneWidget,
    );
  });

  testWidgets('returns to the previous screen when cancelled', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();

    expect(find.text('グループ一覧画面プレースホルダー'), findsOneWidget);
    verifyNever(() => repository.leaveGroup(groupId: any(named: 'groupId')));
  });

  testWidgets('shows an error state and does not call leaveGroup when '
      'groupId is empty', (tester) async {
    final router = GoRouter(
      initialLocation: '/groups',
      routes: [
        GoRoute(
          path: '/groups',
          builder: (context, state) =>
              const Scaffold(body: Text('グループ一覧画面プレースホルダー')),
        ),
        GoRoute(
          path: '/groups/leave',
          builder: (context, state) =>
              const LeaveGroupConfirmScreen(groupId: '', groupName: ''),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [groupRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    unawaited(router.push('/groups/leave'));
    await tester.pumpAndSettle();

    expect(find.text('グループ情報を取得できませんでした'), findsOneWidget);
    expect(find.text('脱退する'), findsNothing);

    await tester.tap(find.text('戻る'));
    await tester.pumpAndSettle();

    expect(find.text('グループ一覧画面プレースホルダー'), findsOneWidget);
    verifyNever(() => repository.leaveGroup(groupId: any(named: 'groupId')));
  });
}
