import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/groups/application/usecase/get_or_create_invite_code_usecase.dart';
import 'package:foglm/features/groups/domain/group_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockGroupRepository extends Mock implements GroupRepository {}

void main() {
  late MockGroupRepository repository;
  late GetOrCreateInviteCodeUseCase useCase;

  setUp(() {
    repository = MockGroupRepository();
    useCase = GetOrCreateInviteCodeUseCase(repository);
  });

  test('returns the existing code without issuing a new one', () async {
    when(
      () => repository.getInviteCode(groupId: 'group-1'),
    ).thenAnswer((_) async => 'ABC123');

    final result = await useCase.call(groupId: 'group-1');

    expect(result, 'ABC123');
    verifyNever(
      () => repository.createInviteCode(groupId: any(named: 'groupId')),
    );
  });

  test('issues a new code when none exists yet', () async {
    when(
      () => repository.getInviteCode(groupId: 'group-1'),
    ).thenAnswer((_) async => null);
    when(
      () => repository.createInviteCode(groupId: 'group-1'),
    ).thenAnswer((_) async => 'NEWCODE');

    final result = await useCase.call(groupId: 'group-1');

    expect(result, 'NEWCODE');
    verify(() => repository.createInviteCode(groupId: 'group-1')).called(1);
  });

  test('propagates repository failures', () async {
    when(
      () => repository.getInviteCode(groupId: 'group-1'),
    ).thenThrow(Exception('unexpected'));

    expect(
      () => useCase.call(groupId: 'group-1'),
      throwsA(isA<Exception>()),
    );
  });
}
