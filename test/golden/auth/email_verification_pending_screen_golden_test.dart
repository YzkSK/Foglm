import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foglm/features/auth/data/auth_repository.dart';
import 'package:foglm/features/auth/presentation/email_verification_pending_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

Widget _pumpApp(AuthRepository repository) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repository)],
    child: const MaterialApp(
      home: EmailVerificationPendingScreen(
        email: 'foo@example.com',
        password: 'Abcdefg1',
      ),
    ),
  );
}

void main() {
  unawaited(
    goldenTest(
      'EmailVerificationPendingScreen shows the initial guidance',
      fileName: 'email_verification_pending_screen_initial',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      builder: () => _pumpApp(_MockAuthRepository()),
    ),
  );

  unawaited(
    goldenTest(
      'EmailVerificationPendingScreen shows a message after resending',
      fileName: 'email_verification_pending_screen_resent',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      pumpBeforeTest: (tester) async {
        await tester.tap(find.text('確認メールを再送する'));
        await tester.pumpAndSettle();
      },
      builder: () {
        final repository = _MockAuthRepository();
        when(
          () => repository.resendVerificationEmail(email: 'foo@example.com'),
        ).thenAnswer((_) async {});
        return _pumpApp(repository);
      },
    ),
  );

  unawaited(
    goldenTest(
      'EmailVerificationPendingScreen shows a message when not yet verified',
      fileName: 'email_verification_pending_screen_not_verified',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      pumpBeforeTest: (tester) async {
        await tester.tap(find.text('確認した'));
        await tester.pumpAndSettle();
      },
      builder: () {
        final repository = _MockAuthRepository();
        when(
          () => repository.checkEmailVerifiedBySignIn(
            email: 'foo@example.com',
            password: 'Abcdefg1',
          ),
        ).thenAnswer((_) async => false);
        return _pumpApp(repository);
      },
    ),
  );

  unawaited(
    goldenTest(
      'EmailVerificationPendingScreen shows a loading indicator while checking',
      fileName: 'email_verification_pending_screen_loading',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      pumpBeforeTest: (tester) async {
        await tester.tap(find.text('確認した'));
        await tester.pump();
      },
      builder: () {
        final repository = _MockAuthRepository();
        when(
          () => repository.checkEmailVerifiedBySignIn(
            email: 'foo@example.com',
            password: 'Abcdefg1',
          ),
        ).thenAnswer((_) => Completer<bool>().future);
        return _pumpApp(repository);
      },
    ),
  );

  unawaited(
    goldenTest(
      'EmailVerificationPendingScreen shows a loading indicator while '
      'signing out',
      fileName: 'email_verification_pending_screen_signing_out',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      pumpBeforeTest: (tester) async {
        await tester.pumpAndSettle();
        await tester.tap(find.text('ログアウト'));
        await tester.pump();
      },
      builder: () {
        final repository = _MockAuthRepository();
        when(repository.signOut).thenAnswer((_) => Completer<void>().future);
        return _pumpApp(repository);
      },
    ),
  );
}
