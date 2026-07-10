import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/core/utils/fallback.dart';

void main() {
  group('tryWithFallback', () {
    test(
      'returns the primary result without calling fallback on success',
      () async {
        var fallbackCalled = false;
        var errorLogged = false;

        final result = await tryWithFallback<String>(
          primary: () async => 'primary',
          fallback: () async {
            fallbackCalled = true;
            return 'fallback';
          },
          onPrimaryError: (_, _) => errorLogged = true,
        );

        expect(result, 'primary');
        expect(fallbackCalled, isFalse);
        expect(errorLogged, isFalse);
      },
    );

    test(
      'calls fallback and reports the primary error when primary fails',
      () async {
        Object? reportedError;

        final result = await tryWithFallback<String>(
          primary: () async => throw Exception('primary failed'),
          fallback: () async => 'fallback',
          onPrimaryError: (error, _) => reportedError = error,
        );

        expect(result, 'fallback');
        expect(reportedError, isA<Exception>());
      },
    );

    test(
      'propagates the fallback error when both primary and fallback fail',
      () async {
        final fallbackError = Exception('fallback failed');

        expect(
          () => tryWithFallback<String>(
            primary: () async => throw Exception('primary failed'),
            fallback: () async => throw fallbackError,
            onPrimaryError: (_, _) {},
          ),
          throwsA(same(fallbackError)),
        );
      },
    );
  });
}
