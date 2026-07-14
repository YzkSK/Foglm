import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/groups/application/usecase/create_invite_code_usecase.dart';
import 'package:foglm/features/groups/domain/group_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockGroupRepository extends Mock implements GroupRepository {}

void main() {
  late MockGroupRepository repository;
  late CreateInviteCodeUseCase useCase;

  setUp(() {
    repository = MockGroupRepository();
    useCase = CreateInviteCodeUseCase(repository);
  });

  test('delegates to the repository and returns its result', () async {
    when(
      () => repository.createInviteCode(groupId: 'group-1'),
    ).thenAnswer((_) async => 'ABC123');

    final result = await useCase.call(groupId: 'group-1');

    expect(result, 'ABC123');
    verify(() => repository.createInviteCode(groupId: 'group-1')).called(1);
  });

  test('propagates repository failures', () async {
    when(
      () => repository.createInviteCode(groupId: 'group-1'),
    ).thenThrow(Exception('unexpected'));

    expect(
      () => useCase.call(groupId: 'group-1'),
      throwsA(isA<Exception>()),
    );
  });
}
