import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/core/router/app_router.dart';
import 'package:foglm/features/auth/application/current_public_user_provider.dart';
import 'package:foglm/features/auth/domain/public_user.dart';

void main() {
  test(
    'notifies listeners once currentPublicUserProvider resolves after being '
    'in a loading state',
    () async {
      final completer = Completer<PublicUserRow?>();
      final container = ProviderContainer(
        overrides: [
          currentPublicUserProvider.overrideWith((ref) => completer.future),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authRedirectRefreshNotifierProvider);
      var notifyCount = 0;
      notifier.addListener(() => notifyCount++);

      expect(notifyCount, 0);

      completer.complete(
        const PublicUserRow(authProvider: 'email', emailVerified: false),
      );
      await Future<void>.delayed(Duration.zero);

      expect(notifyCount, 1);
    },
  );
}
