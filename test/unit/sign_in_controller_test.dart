import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/auth/application/sign_in_controller.dart';
import 'package:foglm/features/auth/data/auth_repository.dart';
import 'package:foglm/features/auth/domain/sign_in_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = MockAuthRepository();
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
  });

  group('submitEmail', () {
    test('calls repository and resolves to data on success', () async {
      when(
        () => repository.signInWithEmail(
          email: 'foo@example.com',
          password: 'Abcdefg1',
        ),
      ).thenAnswer((_) async {});

      await container
          .read(signInControllerProvider.notifier)
          .submitEmail(email: 'foo@example.com', password: 'Abcdefg1');

      final state = container.read(signInControllerProvider);
      expect(state, const AsyncData<void>(null));
    });

    test('exposes the repository failure as AsyncError', () async {
      when(
        () => repository.signInWithEmail(
          email: 'foo@example.com',
          password: 'wrong',
        ),
      ).thenThrow(const SignInFailure.invalidCredentials());

      await container
          .read(signInControllerProvider.notifier)
          .submitEmail(email: 'foo@example.com', password: 'wrong');

      final state = container.read(signInControllerProvider);
      expect(state.hasError, isTrue);
      expect(state.error, isA<InvalidCredentialsFailure>());
    });
  });

  group('submitSns', () {
    test('calls repository and resolves to data on success', () async {
      when(
        () => repository.signInWithSns(OAuthProvider.google),
      ).thenAnswer((_) async {});

      await container
          .read(signInControllerProvider.notifier)
          .submitSns(OAuthProvider.google);

      final state = container.read(signInControllerProvider);
      expect(state, const AsyncData<void>(null));
    });
  });
}
