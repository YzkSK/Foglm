import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foglm/features/auth/application/current_public_user_provider.dart';
import 'package:foglm/features/auth/application/my_profile_provider.dart';
import 'package:foglm/features/auth/data/auth_repository.dart';
import 'package:foglm/features/auth/domain/my_profile.dart';
import 'package:foglm/features/auth/domain/public_user.dart';
import 'package:foglm/features/auth/presentation/initial_profile_setup_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;

  setUp(() {
    repository = MockAuthRepository();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    MyProfileRow profile = const MyProfileRow(displayName: 'ユーザー'),
    // update_profile成功後にsubmit()が再取得するcurrentPublicUserProvider。
    // 未overrideだと実クライアント未初期化により再取得が常に失敗し、
    // 保存成功パスが一度も正しく検証されないため、明示的に渡す
    // (デフォルトは保存完了後を模した「設定済み」の状態)。
    PublicUserRow? currentPublicUser = const PublicUserRow(
      authProvider: 'email',
      emailVerified: true,
    ),
    Exception? currentPublicUserError,
  }) async {
    final router = GoRouter(
      initialLocation: '/profile/setup',
      routes: [
        GoRoute(
          path: '/profile/setup',
          builder: (context, state) => const InitialProfileSetupScreen(),
        ),
        GoRoute(
          path: '/groups',
          builder: (context, state) =>
              const Scaffold(body: Text('グループ一覧画面プレースホルダー')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        // riverpodのデフォルトのリトライ機構を無効化する。currentPublicUser
        // Providerを常に失敗させるテストで、リトライのTimerがスケジュール
        // され続けてpumpAndSettle()が終わらなくなるのを防ぐため。
        retry: (retryCount, error) => null,
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          myProfileProvider.overrideWith((ref) async => profile),
          currentPublicUserProvider.overrideWith((ref) async {
            if (currentPublicUserError != null) {
              throw currentPublicUserError;
            }
            return currentPublicUser;
          }),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('pre-fills the auto-generated display name', (tester) async {
    await pumpScreen(tester);

    expect(find.text('ユーザー'), findsOneWidget);
  });

  testWidgets('shows a validation error for a blank display name', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextFormField).at(0), '   ');
    await tester.tap(find.text('はじめる'));
    await tester.pump();

    expect(find.text('ニックネームを入力してください'), findsOneWidget);
    verifyNever(
      () => repository.updateProfile(
        displayName: any(named: 'displayName'),
        avatarUrl: any(named: 'avatarUrl'),
      ),
    );
  });

  testWidgets(
    'saves the profile and navigates to the group list on success',
    (tester) async {
      when(
        () => repository.updateProfile(displayName: 'ユーザー'),
      ).thenAnswer((_) async {});

      await pumpScreen(tester);

      await tester.tap(find.text('はじめる'));
      await tester.pumpAndSettle();

      verify(
        () => repository.updateProfile(displayName: 'ユーザー'),
      ).called(1);
      expect(find.text('グループ一覧画面プレースホルダー'), findsOneWidget);
    },
  );

  testWidgets(
    'does not navigate and shows an error when the profile update succeeds '
    'but the follow-up currentPublicUser refetch fails',
    (tester) async {
      // update_profile自体は成功したが、その後のcurrentPublicUserProvider
      // 再取得(profileSetupRedirectが参照する)が失敗するケース。ここで
      // 何もエラー表示せずcontext.goしてしまうと、ルーターが古い(未設定の
      // ままの)値を見て設定画面へ押し戻し続けるのに、ユーザーには理由が
      // 全く分からない不具合になる(レビュー指摘: PR #200)。
      when(
        () => repository.updateProfile(displayName: 'ユーザー'),
      ).thenAnswer((_) async {});

      await pumpScreen(
        tester,
        currentPublicUserError: Exception('currentPublicUser fetch failed'),
      );

      await tester.tap(find.text('はじめる'));
      await tester.pumpAndSettle();

      verify(
        () => repository.updateProfile(displayName: 'ユーザー'),
      ).called(1);
      expect(find.text('グループ一覧画面プレースホルダー'), findsNothing);
      expect(find.text('プロフィールの保存に失敗しました。時間をおいて再度お試しください'), findsOneWidget);
    },
  );

  testWidgets('shows an error message when the repository fails', (
    tester,
  ) async {
    when(
      () => repository.updateProfile(displayName: 'ユーザー'),
    ).thenThrow(Exception('unexpected'));

    await pumpScreen(tester);

    await tester.tap(find.text('はじめる'));
    await tester.pumpAndSettle();

    expect(find.text('プロフィールの保存に失敗しました。時間をおいて再度お試しください'), findsOneWidget);
  });

  testWidgets('tapping logout calls signOut', (tester) async {
    when(() => repository.signOut()).thenAnswer((_) async {});

    await pumpScreen(tester);

    await tester.tap(find.text('ログアウト'));
    await tester.pumpAndSettle();

    verify(() => repository.signOut()).called(1);
  });
}
