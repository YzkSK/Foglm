import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/auth/data/auth_repository.dart';
import 'package:foglm/features/auth/presentation/email_verification_pending_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

Widget _wrap(
  AuthRepository repository, {
  required String email,
  required String password,
}) {
  final router = GoRouter(
    initialLocation: '/verify-pending',
    routes: [
      GoRoute(
        path: '/verify-pending',
        builder: (context, state) => EmailVerificationPendingScreen(
          email: email,
          password: password,
        ),
      ),
      GoRoute(path: '/', builder: (context, state) => const Text('home')),
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

  testWidgets('shows the destination email address', (tester) async {
    await tester.pumpWidget(
      _wrap(repository, email: 'foo@example.com', password: 'Abcdefg1'),
    );

    expect(find.textContaining('foo@example.com'), findsOneWidget);
  });

  testWidgets('tapping resend calls the repository with the email', (
    tester,
  ) async {
    when(
      () => repository.resendVerificationEmail(email: 'foo@example.com'),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(
      _wrap(repository, email: 'foo@example.com', password: 'Abcdefg1'),
    );
    await tester.tap(find.byKey(const Key('resend_button')));
    await tester.pumpAndSettle();

    verify(
      () => repository.resendVerificationEmail(email: 'foo@example.com'),
    ).called(1);
  });

  testWidgets('tapping confirmed navigates home when verified', (tester) async {
    when(
      () => repository.checkEmailVerifiedBySignIn(
        email: 'foo@example.com',
        password: 'Abcdefg1',
      ),
    ).thenAnswer((_) async => true);

    await tester.pumpWidget(
      _wrap(repository, email: 'foo@example.com', password: 'Abcdefg1'),
    );
    await tester.tap(find.byKey(const Key('confirmed_button')));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('tapping confirmed shows an error when not yet verified', (
    tester,
  ) async {
    when(
      () => repository.checkEmailVerifiedBySignIn(
        email: 'foo@example.com',
        password: 'Abcdefg1',
      ),
    ).thenAnswer((_) async => false);

    await tester.pumpWidget(
      _wrap(repository, email: 'foo@example.com', password: 'Abcdefg1'),
    );
    await tester.tap(find.byKey(const Key('confirmed_button')));
    await tester.pumpAndSettle();

    expect(find.text('まだ確認が完了していません。メール内のリンクを確認してください。'), findsOneWidget);
  });
}
