import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foglm/features/auth/data/auth_repository.dart';
import 'package:foglm/features/auth/presentation/delete_account_confirm_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

Widget _pumpApp(AuthRepository repository) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repository)],
    child: const MaterialApp(home: DeleteAccountConfirmScreen()),
  );
}

void main() {
  unawaited(
    goldenTest(
      'DeleteAccountConfirmScreen shows the confirmation message',
      fileName: 'delete_account_confirm_screen_initial',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      builder: () => _pumpApp(_MockAuthRepository()),
    ),
  );

  unawaited(
    goldenTest(
      'DeleteAccountConfirmScreen shows a loading indicator while submitting',
      fileName: 'delete_account_confirm_screen_loading',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      pumpBeforeTest: (tester) async {
        await tester.pumpAndSettle();
        await tester.tap(find.text('アカウントを削除する'));
        await tester.pump();
      },
      builder: () {
        final repository = _MockAuthRepository();
        when(
          repository.deleteAccount,
        ).thenAnswer((_) => Completer<void>().future);
        return _pumpApp(repository);
      },
    ),
  );

  unawaited(
    goldenTest(
      'DeleteAccountConfirmScreen shows a server error',
      fileName: 'delete_account_confirm_screen_server_error',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      pumpBeforeTest: (tester) async {
        await tester.pumpAndSettle();
        await tester.tap(find.text('アカウントを削除する'));
        await tester.pumpAndSettle();
      },
      builder: () {
        final repository = _MockAuthRepository();
        when(repository.deleteAccount).thenThrow(Exception('unexpected'));
        return _pumpApp(repository);
      },
    ),
  );
}
