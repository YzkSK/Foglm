import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/album/data/photo_url_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockFunctionsClient extends Mock implements FunctionsClient {}

void main() {
  late MockSupabaseClient client;
  late MockFunctionsClient functions;
  late SupabasePhotoUrlRepository repository;

  setUp(() {
    client = MockSupabaseClient();
    functions = MockFunctionsClient();
    when(() => client.functions).thenReturn(functions);
    repository = SupabasePhotoUrlRepository(client);
  });

  test(
    'invokes get-photo-url with the photo id and returns the url',
    () async {
      when(
        () => functions.invoke('get-photo-url', body: {'photo_id': 'photo-1'}),
      ).thenAnswer(
        (_) async => const FunctionResponse(
          status: 200,
          data: {'url': 'https://example.com/photo-1.jpg'},
        ),
      );

      final url = await repository.getPhotoUrl(photoId: 'photo-1');

      expect(url, 'https://example.com/photo-1.jpg');
      verify(
        () => functions.invoke('get-photo-url', body: {'photo_id': 'photo-1'}),
      ).called(1);
    },
  );

  test('propagates FunctionException without swallowing it', () async {
    when(
      () => functions.invoke('get-photo-url', body: {'photo_id': 'photo-1'}),
    ).thenThrow(
      const FunctionException(status: 404, details: {'error': 'not_found'}),
    );

    await expectLater(
      () => repository.getPhotoUrl(photoId: 'photo-1'),
      throwsA(isA<FunctionException>()),
    );
  });
}
