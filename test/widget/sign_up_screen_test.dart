import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/auth/data/auth_repository.dart';
import 'package:foglm/features/auth/domain/sign_up_failure.dart';
import 'package:foglm/features/auth/presentation/sign_up_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

Widget _wrap(AuthRepository repository) {
  final router = GoRouter(
    initialLocation: '/signup',
    routes: [
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: '/verify-pending',
        builder: (context, state) => Text('verify-pending:${state.extra}'),
      ),
    ],
  );

  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  late MockAuthRepository repository;

  setUp(() {
    repository = MockAuthRepository();
  });

  testWidgets(
    'shows a validation error for an invalid email without calling the '
    'repository',
    (tester) async {
      await tester.pumpWidget(_wrap(repository));

      await tester.enterText(
        find.byKey(const Key('sign_up_email_field')),
        'not-an-email',
      );
      await tester.enterText(
        find.byKey(const Key('sign_up_password_field')),
        'Abcdefg1',
      );
      await tester.tap(find.byKey(const Key('sign_up_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('メールアドレスの形式が正しくありません'), findsOneWidget);
      verifyNever(
        () => repository.signUpWithEmail(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      );
    },
  );

  testWidgets(
    'shows a validation error for a weak password without calling the '
    'repository',
    (tester) async {
      await tester.pumpWidget(_wrap(repository));

      await tester.enterText(
        find.byKey(const Key('sign_up_email_field')),
        'foo@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('sign_up_password_field')),
        'weak',
      );
      await tester.tap(find.byKey(const Key('sign_up_submit_button')));
      await tester.pumpAndSettle();

      expect(
        find.text('パスワードは8文字以上、英大文字・英小文字・数字を全て含めてください'),
        findsOneWidget,
      );
      verifyNever(
        () => repository.signUpWithEmail(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      );
    },
  );

  testWidgets('navigates to verify-pending with the email on success', (
    tester,
  ) async {
    when(
      () => repository.signUpWithEmail(
        email: 'foo@example.com',
        password: 'Abcdefg1',
      ),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(_wrap(repository));

    await tester.enterText(
      find.byKey(const Key('sign_up_email_field')),
      'foo@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('sign_up_password_field')),
      'Abcdefg1',
    );
    await tester.tap(find.byKey(const Key('sign_up_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('verify-pending:foo@example.com'), findsOneWidget);
  });

  testWidgets(
    'shows the sns-conflict message with the provider name on failure',
    (tester) async {
      when(
        () => repository.signUpWithEmail(
          email: 'foo@example.com',
          password: 'Abcdefg1',
        ),
      ).thenThrow(const EmailUsedBySnsFailure('google'));

      await tester.pumpWidget(_wrap(repository));

      await tester.enterText(
        find.byKey(const Key('sign_up_email_field')),
        'foo@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('sign_up_password_field')),
        'Abcdefg1',
      );
      await tester.tap(find.byKey(const Key('sign_up_submit_button')));
      await tester.pumpAndSettle();

      expect(
        find.text('そのメールアドレスはGoogleで登録済みです。Googleでログインしてください。'),
        findsOneWidget,
      );
    },
  );
}
