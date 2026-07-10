import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/core/router/auth_guard.dart';
import 'package:foglm/features/auth/domain/public_user.dart';

void main() {
  group('emailVerificationRedirect', () {
    test('does not redirect when there is no logged-in user', () {
      final result = emailVerificationRedirect(user: null, location: '/signup');
      expect(result, isNull);
    });

    test(
      'does not redirect an sns-provider user regardless of email_verified',
      () {
        const user = PublicUserRow(
          authProvider: 'google',
          emailVerified: false,
        );
        final result = emailVerificationRedirect(
          user: user,
          location: '/some-future-screen',
        );
        expect(result, isNull);
      },
    );

    test('does not redirect a verified email-provider user', () {
      const user = PublicUserRow(authProvider: 'email', emailVerified: true);
      final result = emailVerificationRedirect(
        user: user,
        location: '/some-future-screen',
      );
      expect(result, isNull);
    });

    test('does not redirect when already on an allow-listed path', () {
      const user = PublicUserRow(authProvider: 'email', emailVerified: false);
      final result = emailVerificationRedirect(
        user: user,
        location: '/verify-pending',
      );
      expect(result, isNull);
    });

    test('redirects an unverified email-provider user to verify-pending', () {
      const user = PublicUserRow(authProvider: 'email', emailVerified: false);
      final result = emailVerificationRedirect(
        user: user,
        location: '/some-future-screen',
      );
      expect(result, '/verify-pending');
    });

    test('does not redirect an unverified user on the debug menu path', () {
      const user = PublicUserRow(authProvider: 'email', emailVerified: false);
      final result = emailVerificationRedirect(
        user: user,
        location: '/debug',
      );
      expect(result, isNull);
    });
  });

  group('profileSetupRedirect', () {
    test('does not redirect when there is no logged-in user', () {
      final result = profileSetupRedirect(user: null, location: '/signup');
      expect(result, isNull);
    });

    test('does not redirect a user who already completed setup', () {
      final user = PublicUserRow(
        authProvider: 'email',
        emailVerified: true,
        profileCompletedAt: DateTime(2026, 7),
      );
      final result = profileSetupRedirect(
        user: user,
        location: '/some-future-screen',
      );
      expect(result, isNull);
    });

    test('does not redirect when already on an allow-listed path', () {
      const user = PublicUserRow(authProvider: 'email', emailVerified: true);
      final result = profileSetupRedirect(
        user: user,
        location: '/profile/setup',
      );
      expect(result, isNull);
    });

    test(
      'redirects a user who has not completed setup to profile/setup',
      () {
        const user = PublicUserRow(authProvider: 'email', emailVerified: true);
        final result = profileSetupRedirect(
          user: user,
          location: '/some-future-screen',
        );
        expect(result, '/profile/setup');
      },
    );

    test('does not redirect an incomplete-profile user on the debug path', () {
      const user = PublicUserRow(authProvider: 'email', emailVerified: true);
      final result = profileSetupRedirect(user: user, location: '/debug');
      expect(result, isNull);
    });

    test(
      'redirects an incomplete-profile user landing on the login screen path',
      () {
        const user = PublicUserRow(authProvider: 'email', emailVerified: true);
        final result = profileSetupRedirect(user: user, location: '/');
        expect(result, '/profile/setup');
      },
    );
  });

  group('authRequiredRedirect', () {
    test('does not redirect a logged-in user', () {
      const user = PublicUserRow(authProvider: 'email', emailVerified: true);
      final result = authRequiredRedirect(
        user: user,
        isLoading: false,
        location: '/some-future-screen',
      );
      expect(result, isNull);
    });

    test('does not redirect when already on an allow-listed path', () {
      final result = authRequiredRedirect(
        user: null,
        isLoading: false,
        location: '/',
      );
      expect(result, isNull);
    });

    test('redirects an unauthenticated user to the login screen', () {
      final result = authRequiredRedirect(
        user: null,
        isLoading: false,
        location: '/some-future-screen',
      );
      expect(result, '/');
    });

    test(
      'does not redirect while the user is still unresolved (loading)',
      () {
        final result = authRequiredRedirect(
          user: null,
          isLoading: true,
          location: '/some-future-screen',
        );
        expect(result, isNull);
      },
    );

    test('does not redirect when already on the debug menu path', () {
      final result = authRequiredRedirect(
        user: null,
        isLoading: false,
        location: '/debug',
      );
      expect(result, isNull);
    });

    test('does not redirect an unauthenticated user on the signup path', () {
      final result = authRequiredRedirect(
        user: null,
        isLoading: false,
        location: '/signup',
      );
      expect(result, isNull);
    });

    test(
      'does not redirect an unauthenticated user on the verify-pending path',
      () {
        final result = authRequiredRedirect(
          user: null,
          isLoading: false,
          location: '/verify-pending',
        );
        expect(result, isNull);
      },
    );
  });
}
