import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/auth/domain/validators.dart';

void main() {
  group('isValidEmail', () {
    test('accepts a well-formed address', () {
      expect(isValidEmail('foo@example.com'), isTrue);
    });

    test('rejects an address without @', () {
      expect(isValidEmail('foo.example.com'), isFalse);
    });

    test('rejects an address without a domain dot', () {
      expect(isValidEmail('foo@example'), isFalse);
    });
  });

  group('isValidPassword', () {
    test('accepts 8+ chars containing upper/lower/digit', () {
      expect(isValidPassword('Abcdefg1'), isTrue);
    });

    test('rejects passwords shorter than 8 chars', () {
      expect(isValidPassword('Abc123'), isFalse);
    });

    test('rejects passwords missing an uppercase letter', () {
      expect(isValidPassword('abcdefg1'), isFalse);
    });

    test('rejects passwords missing a lowercase letter', () {
      expect(isValidPassword('ABCDEFG1'), isFalse);
    });

    test('rejects passwords missing a digit', () {
      expect(isValidPassword('Abcdefgh'), isFalse);
    });
  });
}
