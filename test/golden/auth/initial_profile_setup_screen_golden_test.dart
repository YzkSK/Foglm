import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foglm/features/auth/data/auth_repository.dart';
import 'package:foglm/features/auth/data/my_profile_provider.dart';
import 'package:foglm/features/auth/domain/my_profile.dart';
import 'package:foglm/features/auth/presentation/initial_profile_setup_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

Widget _pumpApp(
  AuthRepository repository, {
  MyProfileRow profile = const MyProfileRow(displayName: 'ユーザー'),
}) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(repository),
      myProfileProvider.overrideWith((ref) async => profile),
    ],
    child: const MaterialApp(home: InitialProfileSetupScreen()),
  );
}

void main() {
  unawaited(
    goldenTest(
      'InitialProfileSetupScreen shows the pre-filled form',
      fileName: 'initial_profile_setup_screen_initial',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      pumpBeforeTest: (tester) async {
        await tester.pumpAndSettle();
      },
      builder: () => _pumpApp(_MockAuthRepository()),
    ),
  );

  unawaited(
    goldenTest(
      'InitialProfileSetupScreen shows a validation error',
      fileName: 'initial_profile_setup_screen_validation_error',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      pumpBeforeTest: (tester) async {
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).at(0), '   ');
        await tester.tap(find.text('はじめる'));
        await tester.pumpAndSettle();
      },
      builder: () => _pumpApp(_MockAuthRepository()),
    ),
  );

  unawaited(
    goldenTest(
      'InitialProfileSetupScreen shows a loading indicator while saving',
      fileName: 'initial_profile_setup_screen_loading',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      pumpBeforeTest: (tester) async {
        await tester.pumpAndSettle();
        await tester.tap(find.text('はじめる'));
        await tester.pump();
      },
      builder: () {
        final repository = _MockAuthRepository();
        when(
          () => repository.updateProfile(displayName: 'ユーザー'),
        ).thenAnswer((_) => Completer<void>().future);
        return _pumpApp(repository);
      },
    ),
  );

  unawaited(
    goldenTest(
      'InitialProfileSetupScreen shows a server error',
      fileName: 'initial_profile_setup_screen_server_error',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      pumpBeforeTest: (tester) async {
        await tester.pumpAndSettle();
        await tester.tap(find.text('はじめる'));
        await tester.pumpAndSettle();
      },
      builder: () {
        final repository = _MockAuthRepository();
        when(
          () => repository.updateProfile(displayName: 'ユーザー'),
        ).thenThrow(Exception('unexpected'));
        return _pumpApp(repository);
      },
    ),
  );
}
