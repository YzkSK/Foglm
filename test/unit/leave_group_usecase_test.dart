import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/groups/application/usecase/leave_group_usecase.dart';
import 'package:foglm/features/groups/domain/group_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockGroupRepository extends Mock implements GroupRepository {}

void main() {
  late MockGroupRepository repository;
  late LeaveGroupUseCase useCase;

  setUp(() {
    repository = MockGroupRepository();
    useCase = LeaveGroupUseCase(repository);
  });

  test('delegates to the repository', () async {
    when(
      () => repository.leaveGroup(groupId: 'group-1'),
    ).thenAnswer((_) async {});

    await useCase.call(groupId: 'group-1');

    verify(() => repository.leaveGroup(groupId: 'group-1')).called(1);
  });

  test('propagates repository failures', () async {
    when(
      () => repository.leaveGroup(groupId: 'group-1'),
    ).thenThrow(Exception('unexpected'));

    expect(
      () => useCase.call(groupId: 'group-1'),
      throwsA(isA<Exception>()),
    );
  });
}
