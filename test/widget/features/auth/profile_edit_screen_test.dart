import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foglm/features/auth/data/auth_repository.dart';
import 'package:foglm/features/auth/data/my_profile_provider.dart';
import 'package:foglm/features/auth/domain/my_profile.dart';
import 'package:foglm/features/auth/presentation/profile_edit_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;

  setUp(() {
    repository = MockAuthRepository();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    MyProfileRow profile = const MyProfileRow(displayName: 'Old Name'),
  }) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          myProfileProvider.overrideWith((ref) async => profile),
        ],
        child: const MaterialApp(home: ProfileEditScreen()),
      ),
    );
  }

  testWidgets('pre-fills the current display name and avatar url', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      profile: const MyProfileRow(
        displayName: 'Old Name',
        avatarUrl: 'https://example.com/old.png',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Old Name'), findsOneWidget);
    expect(find.text('https://example.com/old.png'), findsOneWidget);
  });

  testWidgets('shows a validation error for a blank display name', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '   ');
    await tester.tap(find.text('保存する'));
    await tester.pump();

    expect(find.text('ニックネームを入力してください'), findsOneWidget);
    verifyNever(
      () => repository.updateProfile(
        displayName: any(named: 'displayName'),
        avatarUrl: any(named: 'avatarUrl'),
      ),
    );
  });

  testWidgets('shows a snack bar and calls the repository on success', (
    tester,
  ) async {
    when(
      () => repository.updateProfile(
        displayName: 'New Name',
        avatarUrl: 'https://example.com/new.png',
      ),
    ).thenAnswer((_) async {});

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'New Name');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'https://example.com/new.png',
    );
    await tester.tap(find.text('保存する'));
    await tester.pumpAndSettle();

    verify(
      () => repository.updateProfile(
        displayName: 'New Name',
        avatarUrl: 'https://example.com/new.png',
      ),
    ).called(1);
    expect(find.text('プロフィールを更新しました'), findsOneWidget);
  });

  testWidgets('trims leading/trailing whitespace before submitting', (
    tester,
  ) async {
    when(
      () => repository.updateProfile(displayName: 'New Name'),
    ).thenAnswer((_) async {});

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '  New Name  ');
    await tester.tap(find.text('保存する'));
    await tester.pumpAndSettle();

    verify(
      () => repository.updateProfile(displayName: 'New Name'),
    ).called(1);
  });

  testWidgets('passes null avatarUrl when the field is cleared', (
    tester,
  ) async {
    when(
      () => repository.updateProfile(displayName: 'New Name'),
    ).thenAnswer((_) async {});

    await pumpScreen(
      tester,
      profile: const MyProfileRow(
        displayName: 'Old Name',
        avatarUrl: 'https://example.com/old.png',
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'New Name');
    await tester.enterText(find.byType(TextFormField).at(1), '');
    await tester.tap(find.text('保存する'));
    await tester.pumpAndSettle();

    verify(
      () => repository.updateProfile(displayName: 'New Name'),
    ).called(1);
  });

  testWidgets('shows an error message when the repository fails', (
    tester,
  ) async {
    when(
      () => repository.updateProfile(displayName: 'New Name'),
    ).thenThrow(Exception('unexpected'));

    await pumpScreen(tester);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'New Name');
    await tester.tap(find.text('保存する'));
    await tester.pumpAndSettle();

    expect(find.text('プロフィールの更新に失敗しました。時間をおいて再度お試しください'), findsOneWidget);
  });

  testWidgets(
    'clears the stale server error when a later submit fails validation',
    (tester) async {
      when(
        () => repository.updateProfile(displayName: 'New Name'),
      ).thenThrow(Exception('unexpected'));

      await pumpScreen(tester);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'New Name');
      await tester.tap(find.text('保存する'));
      await tester.pumpAndSettle();
      expect(find.text('プロフィールの更新に失敗しました。時間をおいて再度お試しください'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), '   ');
      await tester.tap(find.text('保存する'));
      await tester.pump();

      expect(find.text('ニックネームを入力してください'), findsOneWidget);
      expect(
        find.text('プロフィールの更新に失敗しました。時間をおいて再度お試しください'),
        findsNothing,
      );
    },
  );
}
