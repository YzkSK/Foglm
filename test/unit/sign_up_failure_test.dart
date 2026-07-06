import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/auth/domain/sign_up_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('mapFunctionExceptionToSignUpFailure', () {
    test('maps invalid_email to InvalidEmailFailure', () {
      final result = mapFunctionExceptionToSignUpFailure(
        const FunctionException(
          status: 400,
          details: {'error': 'invalid_email'},
        ),
      );
      expect(result, isA<InvalidEmailFailure>());
    });

    test('maps weak_password to WeakPasswordFailure', () {
      final result = mapFunctionExceptionToSignUpFailure(
        const FunctionException(
          status: 400,
          details: {'error': 'weak_password'},
        ),
      );
      expect(result, isA<WeakPasswordFailure>());
    });

    test('maps email_used_by_sns to EmailUsedBySnsFailure with provider', () {
      final result = mapFunctionExceptionToSignUpFailure(
        const FunctionException(
          status: 409,
          details: {'error': 'email_used_by_sns', 'provider': 'google'},
        ),
      );
      expect(result, isA<EmailUsedBySnsFailure>());
      expect((result as EmailUsedBySnsFailure).provider, 'google');
    });

    test('maps unknown error codes to UnknownSignUpFailure', () {
      final result = mapFunctionExceptionToSignUpFailure(
        const FunctionException(
          status: 500,
          details: {'error': 'unknown'},
        ),
      );
      expect(result, isA<UnknownSignUpFailure>());
    });

    test('maps missing details to UnknownSignUpFailure', () {
      final result = mapFunctionExceptionToSignUpFailure(
        const FunctionException(status: 500),
      );
      expect(result, isA<UnknownSignUpFailure>());
    });
  });
}
