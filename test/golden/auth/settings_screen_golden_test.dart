import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/auth/data/auth_repository.dart';
import 'package:foglm/features/auth/data/my_profile_provider.dart';
import 'package:foglm/features/auth/domain/my_profile.dart';
import 'package:foglm/features/auth/presentation/settings_screen.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

Widget _pumpApp({MyProfileRow? profile}) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(_MockAuthRepository()),
      myProfileProvider.overrideWith((ref) async => profile),
    ],
    child: const MaterialApp(home: SettingsScreen()),
  );
}

void main() {
  unawaited(
    goldenTest(
      'SettingsScreen shows the account menu',
      fileName: 'settings_screen_initial',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      builder: () =>
          _pumpApp(profile: const MyProfileRow(displayName: 'テストユーザー')),
    ),
  );

  unawaited(
    goldenTest(
      'SettingsScreen shows an error state',
      fileName: 'settings_screen_error',
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 800),
      builder: _pumpApp,
    ),
  );
}
