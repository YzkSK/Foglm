import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/auth/application/update_profile_controller.dart';
import 'package:foglm/features/auth/data/auth_repository.dart';
import 'package:mocktail/mocktail.dart';

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
