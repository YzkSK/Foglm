import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/auth/application/current_public_user_provider.dart';
import 'package:foglm/features/auth/application/update_profile_controller.dart';
import 'package:foglm/features/auth/data/auth_repository.dart';
import 'package:foglm/features/auth/domain/public_user.dart';
import 'package:mocktail/mocktail.dart';

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

  test('submit calls repository and resolves to data on success', () async {
    when(
      () => repository.updateProfile(
        displayName: 'New Name',
        avatarUrl: 'https://example.com/a.png',
      ),
    ).thenAnswer((_) async {});

    await container
        .read(updateProfileControllerProvider.notifier)
        .submit(
          displayName: 'New Name',
          avatarUrl: 'https://example.com/a.png',
        );

    final state = container.read(updateProfileControllerProvider);
    expect(state, const AsyncData<void>(null));
    verify(
      () => repository.updateProfile(
        displayName: 'New Name',
        avatarUrl: 'https://example.com/a.png',
      ),
    ).called(1);
  });

  test(
    'submit invalidates currentPublicUserProvider on success '
    '(profile_completed_at may have changed)',
    () async {
      when(
        () => repository.updateProfile(displayName: 'New Name'),
      ).thenAnswer((_) async {});

      await container.read(currentPublicUserProvider.future);
      expect(currentPublicUserBuildCount, 1);

      await container
          .read(updateProfileControllerProvider.notifier)
          .submit(displayName: 'New Name');
      await container.read(currentPublicUserProvider.future);

      expect(currentPublicUserBuildCount, 2);
    },
  );

  test('submit exposes the repository failure as AsyncError', () async {
    when(
      () => repository.updateProfile(displayName: ''),
    ).thenThrow(Exception('display_name must not be blank'));

    await container
        .read(updateProfileControllerProvider.notifier)
        .submit(displayName: '');

    final state = container.read(updateProfileControllerProvider);
    expect(state.hasError, isTrue);
  });
}
