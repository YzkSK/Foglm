import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/auth/application/reset_password_controller.dart';
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
      () => repository.resetPassword(newPassword: 'Abcdefg1'),
    ).thenAnswer((_) async {});

    await container
        .read(resetPasswordControllerProvider.notifier)
        .submit(newPassword: 'Abcdefg1');

    final state = container.read(resetPasswordControllerProvider);
    expect(state, const AsyncData<void>(null));
    verify(
      () => repository.resetPassword(newPassword: 'Abcdefg1'),
    ).called(1);
  });

  test('submit exposes the repository failure as AsyncError', () async {
    when(
      () => repository.resetPassword(newPassword: 'weak'),
    ).thenThrow(const PasswordResetWeakPasswordFailure());

    await container
        .read(resetPasswordControllerProvider.notifier)
        .submit(newPassword: 'weak');

    final state = container.read(resetPasswordControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.error, isA<PasswordResetWeakPasswordFailure>());
  });
}
