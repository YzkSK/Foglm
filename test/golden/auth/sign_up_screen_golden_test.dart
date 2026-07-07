import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foglm/features/auth/data/auth_repository.dart';
import 'package:foglm/features/auth/domain/sign_up_failure.dart';
import 'package:foglm/features/auth/presentation/sign_up_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

Widget _pumpApp(AuthRepository repository) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repository)],
    child: const MaterialApp(home: SignUpScreen()),
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
      'SignUpScreen shows the initial empty form',
      fileName: 'sign_up_screen_initial',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      builder: () => _pumpApp(_MockAuthRepository()),
    ),
  );

  unawaited(
    goldenTest(
      'SignUpScreen shows validation errors',
      fileName: 'sign_up_screen_validation_error',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      pumpBeforeTest: (tester) async {
        await _enterCredentials(
          tester,
          email: 'not-an-email',
          password: 'weak',
        );
        await tester.tap(find.text('登録する'));
        await tester.pumpAndSettle();
      },
      builder: () => _pumpApp(_MockAuthRepository()),
    ),
  );

  unawaited(
    goldenTest(
      'SignUpScreen shows a server error',
      fileName: 'sign_up_screen_server_error',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      pumpBeforeTest: (tester) async {
        await _enterCredentials(
          tester,
          email: 'foo@example.com',
          password: 'Abcdefg1',
        );
        await tester.tap(find.text('登録する'));
        await tester.pumpAndSettle();
      },
      builder: () {
        final repository = _MockAuthRepository();
        when(
          () => repository.signUpWithEmail(
            email: 'foo@example.com',
            password: 'Abcdefg1',
          ),
        ).thenThrow(const EmailUsedBySnsFailure('google'));
        return _pumpApp(repository);
      },
    ),
  );

  unawaited(
    goldenTest(
      'SignUpScreen shows a loading indicator while submitting',
      fileName: 'sign_up_screen_loading',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      pumpBeforeTest: (tester) async {
        await _enterCredentials(
          tester,
          email: 'foo@example.com',
          password: 'Abcdefg1',
        );
        await tester.tap(find.text('登録する'));
        await tester.pump();
      },
      builder: () {
        final repository = _MockAuthRepository();
        when(
          () => repository.signUpWithEmail(
            email: 'foo@example.com',
            password: 'Abcdefg1',
          ),
        ).thenAnswer((_) => Completer<void>().future);
        return _pumpApp(repository);
      },
    ),
  );
}
