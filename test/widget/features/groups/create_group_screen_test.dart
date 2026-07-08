import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foglm/features/groups/data/group_repository.dart';
import 'package:foglm/features/groups/presentation/create_group_screen.dart';
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
      initialLocation: '/groups/new',
      routes: [
        GoRoute(
          path: '/camera',
          builder: (context, state) =>
              const Scaffold(body: Text('カメラ画面プレースホルダー')),
        ),
        GoRoute(
          path: '/groups/new',
          builder: (context, state) => const CreateGroupScreen(),
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

  testWidgets('shows a validation error for a blank name', (tester) async {
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('作成する'));
    await tester.pump();

    expect(find.text('グループ名を入力してください'), findsOneWidget);
    verifyNever(
      () => repository.createGroup(name: any(named: 'name')),
    );
  });

  testWidgets('navigates to the camera screen on success', (tester) async {
    when(
      () => repository.createGroup(name: 'My Group'),
    ).thenAnswer((_) async {});

    await pumpScreen(tester);
    await tester.enterText(find.byType(TextFormField), 'My Group');

    await tester.tap(find.text('作成する'));
    await tester.pumpAndSettle();

    expect(find.text('カメラ画面プレースホルダー'), findsOneWidget);
  });

  testWidgets('shows an error message when the repository fails', (
    tester,
  ) async {
    when(
      () => repository.createGroup(name: 'My Group'),
    ).thenThrow(Exception('unexpected'));

    await pumpScreen(tester);
    await tester.enterText(find.byType(TextFormField), 'My Group');

    await tester.tap(find.text('作成する'));
    await tester.pumpAndSettle();

    expect(find.text('グループの作成に失敗しました。時間をおいて再度お試しください'), findsOneWidget);
  });

  testWidgets(
    'clears the stale server error when a later submit fails validation',
    (tester) async {
      when(
        () => repository.createGroup(name: 'My Group'),
      ).thenThrow(Exception('unexpected'));

      await pumpScreen(tester);
      await tester.enterText(find.byType(TextFormField), 'My Group');
      await tester.tap(find.text('作成する'));
      await tester.pumpAndSettle();
      expect(find.text('グループの作成に失敗しました。時間をおいて再度お試しください'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), '   ');
      await tester.tap(find.text('作成する'));
      await tester.pump();

      expect(find.text('グループ名を入力してください'), findsOneWidget);
      expect(
        find.text('グループの作成に失敗しました。時間をおいて再度お試しください'),
        findsNothing,
      );
    },
  );
}
