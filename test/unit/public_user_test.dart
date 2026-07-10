import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/auth/domain/public_user.dart';

void main() {
  group('PublicUserRow.fromMap', () {
    test('maps nullable profile_completed_at', () {
      final completedAt = DateTime.parse('2026-07-01T00:00:00Z');

      final row = PublicUserRow.fromMap({
        'auth_provider': 'email',
        'email_verified': true,
        'profile_completed_at': completedAt.toIso8601String(),
      });

      expect(row.authProvider, 'email');
      expect(row.emailVerified, isTrue);
      expect(row.profileCompletedAt, completedAt);
    });

    test('keeps profileCompletedAt null when profile_completed_at is null', () {
      final row = PublicUserRow.fromMap({
        'auth_provider': 'google',
        'email_verified': false,
        'profile_completed_at': null,
      });

      expect(row.profileCompletedAt, isNull);
    });
  });
}
