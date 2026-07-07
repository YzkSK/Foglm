import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foglm/features/auth/data/auth_repository.dart';
import 'package:foglm/features/auth/data/current_public_user_provider.dart';
import 'package:foglm/features/auth/domain/public_user.dart';
import 'package:foglm/features/auth/domain/sign_in_failure.dart';
import 'package:foglm/features/auth/presentation/login_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(OAuthProvider.google);
  });

  late MockAuthRepository repository;

  setUp(() {
    repository = MockAuthRepository();
  });

  Future<void> pumpScreen(WidgetTester tester, {PublicUserRow? user}) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          currentPublicUserProvider.overrideWith((ref) async => user),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
  }

  testWidgets('shows validation errors for invalid email and empty password', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'not-an-email');
    await tester.tap(find.text('ログイン'));
    await tester.pump();

    expect(find.text('メールアドレスの形式が正しくありません'), findsOneWidget);
    expect(find.text('パスワードを入力してください'), findsOneWidget);
    verifyNever(
      () => repository.signInWithEmail(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets('calls signInWithEmail with the entered credentials', (
    tester,
  ) async {
    when(
      () => repository.signInWithEmail(
        email: 'foo@example.com',
        password: 'Abcdefg1',
      ),
    ).thenAnswer((_) async {});

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'foo@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'Abcdefg1');
    await tester.tap(find.text('ログイン'));
    await tester.pumpAndSettle();

    verify(
      () => repository.signInWithEmail(
        email: 'foo@example.com',
        password: 'Abcdefg1',
      ),
    ).called(1);
  });

  testWidgets('shows a mapped error message when sign-in fails', (
    tester,
  ) async {
    when(
      () => repository.signInWithEmail(
        email: 'foo@example.com',
        password: 'wrong',
      ),
    ).thenThrow(const SignInFailure.invalidCredentials());

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'foo@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong');
    await tester.tap(find.text('ログイン'));
    await tester.pumpAndSettle();

    expect(find.text('メールアドレスまたはパスワードが正しくありません'), findsOneWidget);
  });

  testWidgets('calls signInWithSns when an SNS button is tapped', (
    tester,
  ) async {
    when(
      () => repository.signInWithSns(OAuthProvider.google),
    ).thenAnswer((_) async {});

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Googleでログイン'));
    await tester.pumpAndSettle();

    verify(() => repository.signInWithSns(OAuthProvider.google)).called(1);
  });

  testWidgets('shows a logged-in placeholder when a user is present', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      user: const PublicUserRow(authProvider: 'email', emailVerified: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('ログイン済み'), findsOneWidget);
    expect(find.text('ログイン'), findsNothing);
  });
}
