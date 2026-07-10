import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foglm/features/auth/data/auth_repository.dart';
import 'package:foglm/features/auth/data/my_profile_provider.dart';
import 'package:foglm/features/auth/domain/my_profile.dart';
import 'package:foglm/features/auth/presentation/initial_profile_setup_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;

  setUp(() {
    repository = MockAuthRepository();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    MyProfileRow profile = const MyProfileRow(displayName: 'ユーザー'),
  }) async {
    final router = GoRouter(
      initialLocation: '/profile/setup',
      routes: [
        GoRoute(
          path: '/profile/setup',
          builder: (context, state) => const InitialProfileSetupScreen(),
        ),
        GoRoute(
          path: '/groups',
          builder: (context, state) =>
              const Scaffold(body: Text('グループ一覧画面プレースホルダー')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          myProfileProvider.overrideWith((ref) async => profile),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('pre-fills the auto-generated display name', (tester) async {
    await pumpScreen(tester);

    expect(find.text('ユーザー'), findsOneWidget);
  });

  testWidgets('shows a validation error for a blank display name', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextFormField).at(0), '   ');
    await tester.tap(find.text('はじめる'));
    await tester.pump();

    expect(find.text('ニックネームを入力してください'), findsOneWidget);
    verifyNever(
      () => repository.updateProfile(
        displayName: any(named: 'displayName'),
        avatarUrl: any(named: 'avatarUrl'),
      ),
    );
  });

  testWidgets(
    'saves the profile and navigates to the group list on success',
    (tester) async {
      when(
        () => repository.updateProfile(displayName: 'ユーザー'),
      ).thenAnswer((_) async {});

      await pumpScreen(tester);

      await tester.tap(find.text('はじめる'));
      await tester.pumpAndSettle();

      verify(
        () => repository.updateProfile(displayName: 'ユーザー'),
      ).called(1);
      expect(find.text('グループ一覧画面プレースホルダー'), findsOneWidget);
    },
  );

  testWidgets('shows an error message when the repository fails', (
    tester,
  ) async {
    when(
      () => repository.updateProfile(displayName: 'ユーザー'),
    ).thenThrow(Exception('unexpected'));

    await pumpScreen(tester);

    await tester.tap(find.text('はじめる'));
    await tester.pumpAndSettle();

    expect(find.text('プロフィールの保存に失敗しました。時間をおいて再度お試しください'), findsOneWidget);
  });

  testWidgets('tapping logout calls signOut', (tester) async {
    when(() => repository.signOut()).thenAnswer((_) async {});

    await pumpScreen(tester);

    await tester.tap(find.text('ログアウト'));
    await tester.pumpAndSettle();

    verify(() => repository.signOut()).called(1);
  });
}
