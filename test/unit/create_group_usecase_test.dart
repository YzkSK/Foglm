import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/groups/application/usecase/create_group_usecase.dart';
import 'package:foglm/features/groups/domain/group_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockGroupRepository extends Mock implements GroupRepository {}

void main() {
  late MockGroupRepository repository;
  late CreateGroupUseCase useCase;

  setUp(() {
    repository = MockGroupRepository();
    useCase = CreateGroupUseCase(repository);
  });

  test('delegates to the repository', () async {
    when(
      () => repository.createGroup(name: 'My Group'),
    ).thenAnswer((_) async {});

    await useCase.call(name: 'My Group');

    verify(() => repository.createGroup(name: 'My Group')).called(1);
  });

  test('propagates repository failures', () async {
    when(
      () => repository.createGroup(name: 'My Group'),
    ).thenThrow(Exception('unexpected'));

    expect(
      () => useCase.call(name: 'My Group'),
      throwsA(isA<Exception>()),
    );
  });
}
