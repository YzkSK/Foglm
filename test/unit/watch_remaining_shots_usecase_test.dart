import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/camera/application/usecase/watch_remaining_shots_usecase.dart';
import 'package:foglm/features/camera/domain/remaining_shots_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockRemainingShotsRepository extends Mock
    implements RemainingShotsRepository {}

void main() {
  late MockRemainingShotsRepository repository;
  late WatchRemainingShotsUseCase useCase;

  setUp(() {
    repository = MockRemainingShotsRepository();
    useCase = WatchRemainingShotsUseCase(repository);
  });

  test('delegates to the repository and streams its values', () async {
    when(
      () => repository.watchTodayShotsRemaining(groupId: 'group-1'),
    ).thenAnswer((_) => Stream.value(10));

    final result = await useCase.call(groupId: 'group-1').first;

    expect(result, 10);
    verify(
      () => repository.watchTodayShotsRemaining(groupId: 'group-1'),
    ).called(1);
  });

  test('propagates repository stream errors', () async {
    when(
      () => repository.watchTodayShotsRemaining(groupId: 'group-1'),
    ).thenAnswer((_) => Stream<int>.error(Exception('unexpected')));

    expect(
      () => useCase.call(groupId: 'group-1').first,
      throwsA(isA<Exception>()),
    );
  });
}
