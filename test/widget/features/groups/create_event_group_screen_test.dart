import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foglm/features/groups/data/group_repository.dart';
import 'package:foglm/features/groups/presentation/create_event_group_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockGroupRepository extends Mock implements GroupRepository {}

void main() {
  late MockGroupRepository repository;

  setUp(() {
    repository = MockGroupRepository();
  });

  Future<void> pumpScreen(WidgetTester tester) {
    final router = GoRouter(
      initialLocation: '/groups/new-event',
      routes: [
        GoRoute(
          path: '/camera',
          builder: (context, state) =>
              const Scaffold(body: Text('カメラ画面プレースホルダー')),
        ),
        GoRoute(
          path: '/groups/new-event',
          builder: (context, state) => const CreateEventGroupScreen(),
        ),
      ],
    );

    return tester.pumpWidget(
      ProviderScope(
        overrides: [groupRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  /// 開始日・終了日ともに「今日」を選択する(月をまたぐナビゲーション操作を
  /// 避けるため、常に確実にカレンダー上に表示されている日付を使う)。
  Future<void> pickTodayAsStartAndEnd(WidgetTester tester) async {
    final today = DateTime.now().day.toString();

    await tester.tap(find.text('開始日を選択'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(today).last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('終了日を選択'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(today).last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows a validation error for a blank name', (tester) async {
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('作成する'));
    await tester.pump();

    expect(find.text('イベント名を入力してください'), findsOneWidget);
    verifyNever(
      () => repository.createEventGroup(
        name: any(named: 'name'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    );
  });

  testWidgets('shows a validation error when dates are not selected', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.enterText(find.byType(TextFormField), 'My Trip');

    await tester.tap(find.text('作成する'));
    await tester.pump();

    expect(find.text('開始日・終了日を選択してください'), findsOneWidget);
    verifyNever(
      () => repository.createEventGroup(
        name: any(named: 'name'),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    );
  });

  testWidgets('navigates to the camera screen on success', (tester) async {
    when(
      () => repository.createEventGroup(
        name: 'My Trip',
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenAnswer((_) async {});

    await pumpScreen(tester);
    await tester.enterText(find.byType(TextFormField), 'My Trip');
    await pickTodayAsStartAndEnd(tester);

    await tester.tap(find.text('作成する'));
    await tester.pumpAndSettle();

    expect(find.text('カメラ画面プレースホルダー'), findsOneWidget);
  });

  testWidgets('shows an error message when the repository fails', (
    tester,
  ) async {
    when(
      () => repository.createEventGroup(
        name: 'My Trip',
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenThrow(Exception('unexpected'));

    await pumpScreen(tester);
    await tester.enterText(find.byType(TextFormField), 'My Trip');
    await pickTodayAsStartAndEnd(tester);

    await tester.tap(find.text('作成する'));
    await tester.pumpAndSettle();

    expect(find.text('イベントグループの作成に失敗しました。時間をおいて再度お試しください'), findsOneWidget);
  });
}
