import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foglm/features/auth/application/sign_up_controller.dart';
import 'package:foglm/features/auth/data/auth_repository.dart';
import 'package:foglm/features/auth/domain/sign_up_failure.dart';
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
      () => repository.signUpWithEmail(
        email: 'foo@example.com',
        password: 'Abcdefg1',
      ),
    ).thenAnswer((_) async {});

    await container
        .read(signUpControllerProvider.notifier)
        .submit(email: 'foo@example.com', password: 'Abcdefg1');

    final state = container.read(signUpControllerProvider);
    expect(state, const AsyncData<void>(null));
    verify(
      () => repository.signUpWithEmail(
        email: 'foo@example.com',
        password: 'Abcdefg1',
      ),
    ).called(1);
  });

  test('submit exposes the repository failure as AsyncError', () async {
    when(
      () => repository.signUpWithEmail(
        email: 'foo@example.com',
        password: 'weak',
      ),
    ).thenThrow(const WeakPasswordFailure());

    await container
        .read(signUpControllerProvider.notifier)
        .submit(email: 'foo@example.com', password: 'weak');

    final state = container.read(signUpControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.error, isA<WeakPasswordFailure>());
  });
}
