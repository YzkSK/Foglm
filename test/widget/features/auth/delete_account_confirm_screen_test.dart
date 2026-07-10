import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foglm/features/auth/data/auth_repository.dart';
import 'package:foglm/features/auth/data/current_public_user_provider.dart';
import 'package:foglm/features/auth/domain/public_user.dart';
import 'package:foglm/features/auth/presentation/delete_account_confirm_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;

  setUp(() {
    repository = MockAuthRepository();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/debug',
      routes: [
        GoRoute(
          path: '/debug',
          builder: (context, state) =>
              const Scaffold(body: Text('デバッグメニュープレースホルダー')),
        ),
        GoRoute(
          path: '/account/delete',
          builder: (context, state) => const DeleteAccountConfirmScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          currentPublicUserProvider.overrideWith(
            (ref) async => const PublicUserRow(
              authProvider: 'email',
              emailVerified: true,
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    unawaited(router.push('/account/delete'));
    await tester.pumpAndSettle();
  }

  testWidgets('calls deleteAccount when confirmed', (tester) async {
    when(() => repository.deleteAccount()).thenAnswer((_) async {});

    await pumpScreen(tester);

    await tester.tap(find.text('アカウントを削除する'));
    await tester.pumpAndSettle();

    verify(() => repository.deleteAccount()).called(1);
  });

  testWidgets('shows an error message when the repository fails', (
    tester,
  ) async {
    when(
      () => repository.deleteAccount(),
    ).thenThrow(Exception('unexpected'));

    await pumpScreen(tester);

    await tester.tap(find.text('アカウントを削除する'));
    await tester.pumpAndSettle();

    expect(find.text('アカウント削除に失敗しました。時間をおいて再度お試しください'), findsOneWidget);
  });

  testWidgets('returns to the previous screen when cancelled', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();

    expect(find.text('デバッグメニュープレースホルダー'), findsOneWidget);
    verifyNever(() => repository.deleteAccount());
  });
}
