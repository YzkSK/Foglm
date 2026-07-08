import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foglm/features/auth/data/auth_repository.dart';
import 'package:foglm/features/auth/data/my_profile_provider.dart';
import 'package:foglm/features/auth/domain/my_profile.dart';
import 'package:foglm/features/auth/presentation/profile_edit_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

Widget _pumpApp(
  AuthRepository repository, {
  MyProfileRow profile = const MyProfileRow(
    displayName: 'Old Name',
    avatarUrl: 'https://example.com/old.png',
  ),
}) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(repository),
      myProfileProvider.overrideWith((ref) async => profile),
    ],
    child: const MaterialApp(home: ProfileEditScreen()),
  );
}

void main() {
  unawaited(
    goldenTest(
      'ProfileEditScreen shows the pre-filled form',
      fileName: 'profile_edit_screen_initial',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      pumpBeforeTest: (tester) async {
        await tester.pumpAndSettle();
      },
      builder: () => _pumpApp(_MockAuthRepository()),
    ),
  );

  unawaited(
    goldenTest(
      'ProfileEditScreen shows a validation error',
      fileName: 'profile_edit_screen_validation_error',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      pumpBeforeTest: (tester) async {
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).at(0), '   ');
        await tester.tap(find.text('保存する'));
        await tester.pumpAndSettle();
      },
      builder: () => _pumpApp(_MockAuthRepository()),
    ),
  );

  unawaited(
    goldenTest(
      'ProfileEditScreen shows a loading indicator while saving',
      fileName: 'profile_edit_screen_loading',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      pumpBeforeTest: (tester) async {
        await tester.pumpAndSettle();
        await tester.tap(find.text('保存する'));
        await tester.pump();
      },
      builder: () {
        final repository = _MockAuthRepository();
        when(
          () => repository.updateProfile(
            displayName: 'Old Name',
            avatarUrl: 'https://example.com/old.png',
          ),
        ).thenAnswer((_) => Completer<void>().future);
        return _pumpApp(repository);
      },
    ),
  );

  unawaited(
    goldenTest(
      'ProfileEditScreen shows a server error',
      fileName: 'profile_edit_screen_server_error',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      pumpBeforeTest: (tester) async {
        await tester.pumpAndSettle();
        await tester.tap(find.text('保存する'));
        await tester.pumpAndSettle();
      },
      builder: () {
        final repository = _MockAuthRepository();
        when(
          () => repository.updateProfile(
            displayName: 'Old Name',
            avatarUrl: 'https://example.com/old.png',
          ),
        ).thenThrow(Exception('unexpected'));
        return _pumpApp(repository);
      },
    ),
  );
}
