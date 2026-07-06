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
  });
}
