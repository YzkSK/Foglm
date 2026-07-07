import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foglm/features/auth/data/auth_repository.dart';
import 'package:foglm/features/auth/domain/password_reset_failure.dart';
import 'package:foglm/features/auth/presentation/reset_password_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;

  setUp(() {
    repository = MockAuthRepository();
  });

  Future<void> pumpScreen(WidgetTester tester) {
    final router = GoRouter(
      initialLocation: '/reset-password',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: Text('ログイン画面プレースホルダー')),
        ),
        GoRoute(
          path: '/reset-password',
          builder: (context, state) => const ResetPasswordScreen(),
        ),
      ],
    );

    return tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  testWidgets('shows a validation error for a weak password', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(find.byType(TextFormField), 'weak');

    await tester.tap(find.text('パスワードを更新する'));
    await tester.pump();

    expect(find.text('8文字以上、英大文字・小文字・数字を全て含めてください'), findsOneWidget);
    verifyNever(
      () => repository.resetPassword(newPassword: any(named: 'newPassword')),
    );
  });

  testWidgets('navigates to the login screen on success', (tester) async {
    when(
      () => repository.resetPassword(newPassword: 'Abcdefg1'),
    ).thenAnswer((_) async {});

    await pumpScreen(tester);
    await tester.enterText(find.byType(TextFormField), 'Abcdefg1');

    await tester.tap(find.text('パスワードを更新する'));
    await tester.pumpAndSettle();

    expect(find.text('ログイン画面プレースホルダー'), findsOneWidget);
  });

  testWidgets('shows a mapped error message when the repository fails', (
    tester,
  ) async {
    when(
      () => repository.resetPassword(newPassword: 'Abcdefg1'),
    ).thenThrow(const UnknownPasswordResetFailure());

    await pumpScreen(tester);
    await tester.enterText(find.byType(TextFormField), 'Abcdefg1');

    await tester.tap(find.text('パスワードを更新する'));
    await tester.pumpAndSettle();

    expect(find.text('送信に失敗しました。時間をおいて再度お試しください'), findsOneWidget);
  });
}
