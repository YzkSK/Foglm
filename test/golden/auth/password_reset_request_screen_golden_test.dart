import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foglm/features/auth/data/auth_repository.dart';
import 'package:foglm/features/auth/domain/password_reset_failure.dart';
import 'package:foglm/features/auth/presentation/password_reset_request_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

Widget _pumpApp(AuthRepository repository) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repository)],
    child: const MaterialApp(home: PasswordResetRequestScreen()),
  );
}

Future<void> _enterEmail(WidgetTester tester, String email) {
  return tester.enterText(find.byType(TextFormField), email);
}

void main() {
  unawaited(
    goldenTest(
      'PasswordResetRequestScreen shows the initial empty form',
      fileName: 'password_reset_request_screen_initial',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      builder: () => _pumpApp(_MockAuthRepository()),
    ),
  );

  unawaited(
    goldenTest(
      'PasswordResetRequestScreen shows a validation error',
      fileName: 'password_reset_request_screen_validation_error',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      pumpBeforeTest: (tester) async {
        await _enterEmail(tester, 'not-an-email');
        await tester.tap(find.text('リセットリンクを送信する'));
        await tester.pumpAndSettle();
      },
      builder: () => _pumpApp(_MockAuthRepository()),
    ),
  );

  unawaited(
    goldenTest(
      'PasswordResetRequestScreen shows a server error',
      fileName: 'password_reset_request_screen_server_error',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      pumpBeforeTest: (tester) async {
        await _enterEmail(tester, 'foo@example.com');
        await tester.tap(find.text('リセットリンクを送信する'));
        await tester.pumpAndSettle();
      },
      builder: () {
        final repository = _MockAuthRepository();
        when(
          () => repository.requestPasswordReset(email: 'foo@example.com'),
        ).thenThrow(const UnknownPasswordResetFailure());
        return _pumpApp(repository);
      },
    ),
  );

  unawaited(
    goldenTest(
      'PasswordResetRequestScreen shows a loading indicator while submitting',
      fileName: 'password_reset_request_screen_loading',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      pumpBeforeTest: (tester) async {
        await _enterEmail(tester, 'foo@example.com');
        await tester.tap(find.text('リセットリンクを送信する'));
        await tester.pump();
      },
      builder: () {
        final repository = _MockAuthRepository();
        when(
          () => repository.requestPasswordReset(email: 'foo@example.com'),
        ).thenAnswer((_) => Completer<void>().future);
        return _pumpApp(repository);
      },
    ),
  );

  unawaited(
    goldenTest(
      'PasswordResetRequestScreen shows a confirmation message on success',
      fileName: 'password_reset_request_screen_success',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      pumpBeforeTest: (tester) async {
        await _enterEmail(tester, 'foo@example.com');
        await tester.tap(find.text('リセットリンクを送信する'));
        await tester.pumpAndSettle();
      },
      builder: () {
        final repository = _MockAuthRepository();
        when(
          () => repository.requestPasswordReset(email: 'foo@example.com'),
        ).thenAnswer((_) async {});
        return _pumpApp(repository);
      },
    ),
  );
}
