import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foglm/features/auth/data/auth_repository.dart';
import 'package:foglm/features/auth/domain/sign_up_failure.dart';
import 'package:foglm/features/auth/presentation/sign_up_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;

  setUp(() {
    repository = MockAuthRepository();
  });

  Future<void> pumpSignUpScreen(WidgetTester tester) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: SignUpScreen()),
      ),
    );
  }

  Future<void> enterCredentials(
    WidgetTester tester, {
    required String email,
    required String password,
  }) async {
    await tester.enterText(find.byType(TextFormField).at(0), email);
    await tester.enterText(find.byType(TextFormField).at(1), password);
  }

  testWidgets('shows validation errors for invalid email and password', (
    tester,
  ) async {
    await pumpSignUpScreen(tester);
    await enterCredentials(tester, email: 'not-an-email', password: 'weak');

    await tester.tap(find.text('登録する'));
    await tester.pump();

    expect(find.text('メールアドレスの形式が正しくありません'), findsOneWidget);
    expect(find.text('8文字以上、英大文字・小文字・数字を全て含めてください'), findsOneWidget);
    verifyNever(
      () => repository.signUpWithEmail(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets('shows a confirmation message on success', (tester) async {
    when(
      () => repository.signUpWithEmail(
        email: 'foo@example.com',
        password: 'Abcdefg1',
      ),
    ).thenAnswer((_) async {});

    await pumpSignUpScreen(tester);
    await enterCredentials(
      tester,
      email: 'foo@example.com',
      password: 'Abcdefg1',
    );

    await tester.tap(find.text('登録する'));
    await tester.pumpAndSettle();

    expect(find.text('確認メールを送信しました'), findsOneWidget);
  });

  testWidgets('shows a mapped error message when the repository fails', (
    tester,
  ) async {
    when(
      () => repository.signUpWithEmail(
        email: 'foo@example.com',
        password: 'Abcdefg1',
      ),
    ).thenThrow(const EmailUsedBySnsFailure('google'));

    await pumpSignUpScreen(tester);
    await enterCredentials(
      tester,
      email: 'foo@example.com',
      password: 'Abcdefg1',
    );

    await tester.tap(find.text('登録する'));
    await tester.pumpAndSettle();

    expect(
      find.text('このメールアドレスはGoogleで登録済みです。Googleでログインしてください'),
      findsOneWidget,
    );
  });
}
