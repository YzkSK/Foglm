import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foglm/features/auth/application/sign_out_controller.dart';
import 'package:foglm/features/auth/data/auth_repository.dart';
import 'package:foglm/features/auth/data/current_public_user_provider.dart';
import 'package:foglm/features/auth/domain/public_user.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;
  late ProviderContainer container;

  late int currentPublicUserBuildCount;

  setUp(() {
    repository = MockAuthRepository();
    currentPublicUserBuildCount = 0;
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        currentPublicUserProvider.overrideWith((ref) async {
          currentPublicUserBuildCount++;
          return const PublicUserRow(
            authProvider: 'email',
            emailVerified: true,
          );
        }),
      ],
    );
    addTearDown(container.dispose);
  });

  test('signOut calls repository and resolves to data on success', () async {
    when(() => repository.signOut()).thenAnswer((_) async {});

    await container.read(signOutControllerProvider.notifier).signOut();

    final state = container.read(signOutControllerProvider);
    expect(state, const AsyncData<void>(null));
    verify(() => repository.signOut()).called(1);
  });

  test('signOut invalidates currentPublicUserProvider on success', () async {
    when(() => repository.signOut()).thenAnswer((_) async {});

    await container.read(currentPublicUserProvider.future);
    expect(currentPublicUserBuildCount, 1);

    await container.read(signOutControllerProvider.notifier).signOut();
    await container.read(currentPublicUserProvider.future);

    expect(currentPublicUserBuildCount, 2);
  });

  test('signOut exposes the repository failure as AsyncError', () async {
    when(
      () => repository.signOut(),
    ).thenThrow(const AuthException('network error'));

    await container.read(signOutControllerProvider.notifier).signOut();

    final state = container.read(signOutControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.error, isA<AuthException>());
  });
}
