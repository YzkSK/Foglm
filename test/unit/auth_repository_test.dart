import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/auth/data/auth_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

void main() {
  late MockSupabaseClient client;
  late MockGoTrueClient auth;
  late SupabaseAuthRepository repository;

  setUp(() {
    client = MockSupabaseClient();
    auth = MockGoTrueClient();
    when(() => client.auth).thenReturn(auth);
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
}
