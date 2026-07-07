import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foglm/features/auth/data/auth_repository.dart';
import 'package:foglm/features/auth/data/current_public_user_provider.dart';
import 'package:foglm/features/auth/domain/public_user.dart';
import 'package:foglm/features/auth/domain/sign_in_failure.dart';
import 'package:foglm/features/auth/presentation/login_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

Widget _pumpApp(
  AuthRepository repository, {
  PublicUserRow? user,
}) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(repository),
      currentPublicUserProvider.overrideWith((ref) async => user),
    ],
    child: const MaterialApp(home: LoginScreen()),
  );
}

Future<void> _enterCredentials(
  WidgetTester tester, {
  required String email,
  required String password,
}) async {
  await tester.enterText(find.byType(TextFormField).at(0), email);
  await tester.enterText(find.byType(TextFormField).at(1), password);
}

void main() {
  unawaited(
    goldenTest(
      'LoginScreen shows the initial form for a logged-out user',
      fileName: 'login_screen_initial',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      builder: () => _pumpApp(_MockAuthRepository()),
    ),
  );

  unawaited(
    goldenTest(
      'LoginScreen shows validation errors',
      fileName: 'login_screen_validation_error',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      pumpBeforeTest: (tester) async {
        await tester.pumpAndSettle();
        await _enterCredentials(tester, email: 'not-an-email', password: '');
        await tester.tap(find.text('ログイン'));
        await tester.pumpAndSettle();
      },
      builder: () => _pumpApp(_MockAuthRepository()),
    ),
  );

  unawaited(
    goldenTest(
      'LoginScreen shows a sign-in error',
      fileName: 'login_screen_sign_in_error',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      pumpBeforeTest: (tester) async {
        await tester.pumpAndSettle();
        await _enterCredentials(
          tester,
          email: 'foo@example.com',
          password: 'wrong-password',
        );
        await tester.tap(find.text('ログイン'));
        await tester.pumpAndSettle();
      },
      builder: () {
        final repository = _MockAuthRepository();
        when(
          () => repository.signInWithEmail(
            email: 'foo@example.com',
            password: 'wrong-password',
          ),
        ).thenThrow(const SignInFailure.invalidCredentials());
        return _pumpApp(repository);
      },
    ),
  );

  unawaited(
    goldenTest(
      'LoginScreen shows a loading indicator while submitting',
      fileName: 'login_screen_loading',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      pumpBeforeTest: (tester) async {
        await tester.pumpAndSettle();
        await _enterCredentials(
          tester,
          email: 'foo@example.com',
          password: 'Abcdefg1',
        );
        await tester.tap(find.text('ログイン'));
        await tester.pump();
      },
      builder: () {
        final repository = _MockAuthRepository();
        when(
          () => repository.signInWithEmail(
            email: 'foo@example.com',
            password: 'Abcdefg1',
          ),
        ).thenAnswer((_) => Completer<void>().future);
        return _pumpApp(repository);
      },
    ),
  );

  unawaited(
    goldenTest(
      'LoginScreen shows a placeholder for a logged-in user',
      fileName: 'login_screen_logged_in',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      builder: () => _pumpApp(
        _MockAuthRepository(),
        user: const PublicUserRow(authProvider: 'email', emailVerified: true),
      ),
    ),
  );
}
