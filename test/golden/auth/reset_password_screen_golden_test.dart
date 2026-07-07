import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foglm/features/auth/data/auth_repository.dart';
import 'package:foglm/features/auth/domain/password_reset_failure.dart';
import 'package:foglm/features/auth/presentation/reset_password_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

Widget _pumpApp(AuthRepository repository) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repository)],
    child: const MaterialApp(home: ResetPasswordScreen()),
  );
}

Future<void> _enterPassword(WidgetTester tester, String password) {
  return tester.enterText(find.byType(TextFormField), password);
}

void main() {
  unawaited(
    goldenTest(
      'ResetPasswordScreen shows the initial empty form',
      fileName: 'reset_password_screen_initial',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      builder: () => _pumpApp(_MockAuthRepository()),
    ),
  );

  unawaited(
    goldenTest(
      'ResetPasswordScreen shows a validation error',
      fileName: 'reset_password_screen_validation_error',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      pumpBeforeTest: (tester) async {
        await _enterPassword(tester, 'weak');
        await tester.tap(find.text('パスワードを更新する'));
        await tester.pumpAndSettle();
      },
      builder: () => _pumpApp(_MockAuthRepository()),
    ),
  );

  unawaited(
    goldenTest(
      'ResetPasswordScreen shows a server error',
      fileName: 'reset_password_screen_server_error',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      pumpBeforeTest: (tester) async {
        await _enterPassword(tester, 'Abcdefg1');
        await tester.tap(find.text('パスワードを更新する'));
        await tester.pumpAndSettle();
      },
      builder: () {
        final repository = _MockAuthRepository();
        when(
          () => repository.resetPassword(newPassword: 'Abcdefg1'),
        ).thenThrow(const UnknownPasswordResetFailure());
        return _pumpApp(repository);
      },
    ),
  );

  unawaited(
    goldenTest(
      'ResetPasswordScreen shows a loading indicator while submitting',
      fileName: 'reset_password_screen_loading',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      pumpBeforeTest: (tester) async {
        await _enterPassword(tester, 'Abcdefg1');
        await tester.tap(find.text('パスワードを更新する'));
        await tester.pump();
      },
      builder: () {
        final repository = _MockAuthRepository();
        when(
          () => repository.resetPassword(newPassword: 'Abcdefg1'),
        ).thenAnswer((_) => Completer<void>().future);
        return _pumpApp(repository);
      },
    ),
  );
}
