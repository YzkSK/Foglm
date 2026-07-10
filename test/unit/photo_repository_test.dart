import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/camera/data/photo_repository.dart';
import 'package:foglm/features/camera/domain/upload_photo_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockFunctionsClient extends Mock implements FunctionsClient {}

class FakeFunctionResponse extends Fake implements FunctionResponse {}

void main() {
  late MockSupabaseClient client;
  late MockFunctionsClient functions;
  late SupabasePhotoRepository repository;

  setUpAll(() {
    registerFallbackValue(FakeFunctionResponse());
  });

  setUp(() {
    client = MockSupabaseClient();
    functions = MockFunctionsClient();
    when(() => client.functions).thenReturn(functions);
    repository = SupabasePhotoRepository(client);
  });

  test('invokes upload-photo with the group id and image bytes', () async {
    when(
      () => functions.invoke(
        'upload-photo',
        body: any(named: 'body'),
        files: any(named: 'files'),
      ),
    ).thenAnswer((_) async => FakeFunctionResponse());

    await repository.uploadPhoto(
      groupId: 'group-1',
      bytes: Uint8List.fromList([1, 2, 3]),
    );

    final captured = verify(
      () => functions.invoke(
        'upload-photo',
        body: captureAny(named: 'body'),
        files: captureAny(named: 'files'),
      ),
    ).captured;
    expect(captured[0], {'group_id': 'group-1'});
    expect(captured[1], hasLength(1));
  });

  test(
    'throws DailyLimitReachedFailure when the Edge Function returns '
    'daily_limit_reached',
    () async {
      when(
        () => functions.invoke(
          'upload-photo',
          body: any(named: 'body'),
          files: any(named: 'files'),
        ),
      ).thenThrow(
        const FunctionException(
          status: 409,
          details: {'error': 'daily_limit_reached'},
        ),
      );

      await expectLater(
        () => repository.uploadPhoto(
          groupId: 'group-1',
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
        throwsA(isA<DailyLimitReachedFailure>()),
      );
    },
  );

  test(
    'throws GroupArchivedFailure when the Edge Function returns '
    'group_archived',
    () async {
      when(
        () => functions.invoke(
          'upload-photo',
          body: any(named: 'body'),
          files: any(named: 'files'),
        ),
      ).thenThrow(
        const FunctionException(
          status: 403,
          details: {'error': 'group_archived'},
        ),
      );

      await expectLater(
        () => repository.uploadPhoto(
          groupId: 'group-1',
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
        throwsA(isA<GroupArchivedFailure>()),
      );
    },
  );

  test(
    'throws NotActiveMemberFailure when the Edge Function returns '
    'not_active_member',
    () async {
      when(
        () => functions.invoke(
          'upload-photo',
          body: any(named: 'body'),
          files: any(named: 'files'),
        ),
      ).thenThrow(
        const FunctionException(
          status: 403,
          details: {'error': 'not_active_member'},
        ),
      );

      await expectLater(
        () => repository.uploadPhoto(
          groupId: 'group-1',
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
        throwsA(isA<NotActiveMemberFailure>()),
      );
    },
  );

  test(
    'throws UnknownUploadPhotoFailure for an unexpected error',
    () async {
      when(
        () => functions.invoke(
          'upload-photo',
          body: any(named: 'body'),
          files: any(named: 'files'),
        ),
      ).thenThrow(Exception('network error'));

      await expectLater(
        () => repository.uploadPhoto(
          groupId: 'group-1',
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
        throwsA(isA<UnknownUploadPhotoFailure>()),
      );
    },
  );
}
