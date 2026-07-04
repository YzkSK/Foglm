// This file demonstrates the pattern of mocking an abstract interface
// with mocktail. The abstract class is intentional for demonstrating how to
// mock repository patterns.
// ignore_for_file: one_member_abstracts

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

abstract class GreetingRepository {
  String greet(String name);
}

class MockGreetingRepository extends Mock implements GreetingRepository {}

String buildWelcomeMessage(GreetingRepository repository, String name) {
  return repository.greet(name);
}

void main() {
  group('buildWelcomeMessage', () {
    test('delegates to the repository and returns its result', () {
      final repository = MockGreetingRepository();
      when(() => repository.greet('Foglm')).thenReturn('Hello, Foglm!');

      final result = buildWelcomeMessage(repository, 'Foglm');

      expect(result, 'Hello, Foglm!');
      verify(() => repository.greet('Foglm')).called(1);
    });
  });
}
