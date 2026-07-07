import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/auth/application/password_reset_request_controller.dart';
import 'package:foglm/features/auth/data/auth_repository.dart';
import 'package:foglm/features/auth/domain/password_reset_failure.dart';
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
      () => repository.requestPasswordReset(email: 'foo@example.com'),
    ).thenAnswer((_) async {});

    await container
        .read(passwordResetRequestControllerProvider.notifier)
        .submit(email: 'foo@example.com');

    final state = container.read(passwordResetRequestControllerProvider);
    expect(state, const AsyncData<void>(null));
    verify(
      () => repository.requestPasswordReset(email: 'foo@example.com'),
    ).called(1);
  });

  test('submit exposes the repository failure as AsyncError', () async {
    when(
      () => repository.requestPasswordReset(email: 'not-an-email'),
    ).thenThrow(const PasswordResetInvalidEmailFailure());

    await container
        .read(passwordResetRequestControllerProvider.notifier)
        .submit(email: 'not-an-email');

    final state = container.read(passwordResetRequestControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.error, isA<PasswordResetInvalidEmailFailure>());
  });
}
