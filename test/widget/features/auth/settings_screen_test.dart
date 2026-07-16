import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foglm/features/auth/application/my_profile_provider.dart';
import 'package:foglm/features/auth/data/auth_repository.dart';
import 'package:foglm/features/auth/domain/my_profile.dart';
import 'package:foglm/features/auth/presentation/settings_screen.dart';
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
    MyProfileRow? profile = const MyProfileRow(displayName: 'テストユーザー'),
  }) {
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) =>
              const Scaffold(body: Text('プロフィール編集画面プレースホルダー')),
        ),
        GoRoute(
          path: '/account/delete',
          builder: (context, state) =>
              const Scaffold(body: Text('アカウント削除確認画面プレースホルダー')),
        ),
      ],
    );

    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          myProfileProvider.overrideWith((ref) async => profile),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  testWidgets('shows the display name', (tester) async {
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    expect(find.text('テストユーザー'), findsOneWidget);
  });

  testWidgets('shows an error state when the profile is unavailable', (
    tester,
  ) async {
    await pumpScreen(tester, profile: null);
    await tester.pumpAndSettle();

    expect(find.text('アカウント情報を取得できませんでした'), findsOneWidget);
  });

  testWidgets('navigates to the profile edit screen', (tester) async {
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('プロフィール編集'));
    await tester.pumpAndSettle();

    expect(find.text('プロフィール編集画面プレースホルダー'), findsOneWidget);
  });

  testWidgets('navigates to the delete account confirm screen', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('アカウント削除'));
    await tester.pumpAndSettle();

    expect(find.text('アカウント削除確認画面プレースホルダー'), findsOneWidget);
  });

  testWidgets('calls signOut when logout is tapped', (tester) async {
    when(repository.signOut).thenAnswer((_) async {});

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('ログアウト'));
    await tester.pumpAndSettle();

    verify(repository.signOut).called(1);
  });

  testWidgets('disables the logout tile while signing out', (tester) async {
    when(repository.signOut).thenAnswer((_) => Completer<void>().future);

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('ログアウト'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(find.text('ログアウト'));
    await tester.pump();

    verify(repository.signOut).called(1);
  });

  testWidgets('shows a snackbar when signOut fails', (tester) async {
    when(repository.signOut).thenThrow(Exception('unexpected'));

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('ログアウト'));
    await tester.pumpAndSettle();

    expect(find.text('ログアウトに失敗しました。時間をおいて再度お試しください'), findsOneWidget);
  });
}
