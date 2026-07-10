import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/auth/data/auth_repository.dart';
import 'package:foglm/features/auth/domain/delete_account_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockFunctionsClient extends Mock implements FunctionsClient {}

class FakeFunctionResponse extends Fake implements FunctionResponse {}

void main() {
  late MockSupabaseClient client;
  late MockGoTrueClient auth;
  late MockFunctionsClient functions;
  late SupabaseAuthRepository repository;

  setUpAll(() {
    registerFallbackValue(FakeFunctionResponse());
  });

  setUp(() {
    client = MockSupabaseClient();
    auth = MockGoTrueClient();
    functions = MockFunctionsClient();
    when(() => client.auth).thenReturn(auth);
    when(() => client.functions).thenReturn(functions);
    repository = SupabaseAuthRepository(client);
  });

  group('signOut', () {
    test('delegates to GoTrueClient.signOut', () async {
      when(() => auth.signOut()).thenAnswer((_) async {});

      await repository.signOut();

      verify(() => auth.signOut()).called(1);
    });

    test('does not swallow AuthException', () async {
      when(
        () => auth.signOut(),
      ).thenThrow(const AuthException('network error'));

      expect(() => repository.signOut(), throwsA(isA<AuthException>()));
    });
  });

  group('deleteAccount', () {
    test('invokes the Edge Function then signs out locally', () async {
      when(
        () => functions.invoke('delete-account'),
      ).thenAnswer((_) async => FakeFunctionResponse());
      when(() => auth.signOut()).thenAnswer((_) async {});

      await repository.deleteAccount();

      verify(() => functions.invoke('delete-account')).called(1);
      verify(() => auth.signOut()).called(1);
    });

    test(
      'throws DeleteAccountFailure and skips signOut when the Edge '
      'Function call fails',
      () async {
        when(() => functions.invoke('delete-account')).thenThrow(
          const FunctionException(status: 500, details: {'error': 'unknown'}),
        );

        await expectLater(
          repository.deleteAccount,
          throwsA(isA<DeleteAccountFailure>()),
        );

        verifyNever(() => auth.signOut());
      },
    );

    test(
      'does not throw when the server-side deletion succeeds but the '
      'local signOut fails',
      () async {
        when(
          () => functions.invoke('delete-account'),
        ).thenAnswer((_) async => FakeFunctionResponse());
        when(
          () => auth.signOut(),
        ).thenThrow(const AuthException('network error'));

        await expectLater(repository.deleteAccount(), completes);
      },
    );
  });
}
