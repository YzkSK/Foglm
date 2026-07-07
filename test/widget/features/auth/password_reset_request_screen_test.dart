import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foglm/features/auth/data/auth_repository.dart';
import 'package:foglm/features/auth/domain/password_reset_failure.dart';
import 'package:foglm/features/auth/presentation/password_reset_request_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;

  setUp(() {
    repository = MockAuthRepository();
  });

  Future<void> pumpScreen(WidgetTester tester) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: PasswordResetRequestScreen()),
      ),
    );
  }

  testWidgets('shows a validation error for an invalid email', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.enterText(find.byType(TextFormField), 'not-an-email');

    await tester.tap(find.text('リセットリンクを送信する'));
    await tester.pump();

    expect(find.text('メールアドレスの形式が正しくありません'), findsOneWidget);
    verifyNever(
      () => repository.requestPasswordReset(email: any(named: 'email')),
    );
  });

  testWidgets('shows a confirmation message on success', (tester) async {
    when(
      () => repository.requestPasswordReset(email: 'foo@example.com'),
    ).thenAnswer((_) async {});

    await pumpScreen(tester);
    await tester.enterText(find.byType(TextFormField), 'foo@example.com');

    await tester.tap(find.text('リセットリンクを送信する'));
    await tester.pumpAndSettle();

    expect(find.text('パスワードリセットメールを送信しました'), findsOneWidget);
  });

  testWidgets('shows a mapped error message when the repository fails', (
    tester,
  ) async {
    when(
      () => repository.requestPasswordReset(email: 'foo@example.com'),
    ).thenThrow(const UnknownPasswordResetFailure());

    await pumpScreen(tester);
    await tester.enterText(find.byType(TextFormField), 'foo@example.com');

    await tester.tap(find.text('リセットリンクを送信する'));
    await tester.pumpAndSettle();

    expect(find.text('送信に失敗しました。時間をおいて再度お試しください'), findsOneWidget);
  });
}
