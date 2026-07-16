import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/core/supabase/supabase_providers.dart';
import 'package:foglm/features/auth/data/auth_repository.dart';
import 'package:foglm/features/auth/data/auth_state_listener.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockUser extends Mock implements User {}

final _refProvider = Provider<Ref>((ref) => ref);

void main() {
  late MockSupabaseClient client;
  late MockGoTrueClient auth;
  late MockAuthRepository repository;
  late StreamController<AuthState> authStateController;
  late StreamController<String> tokenRefreshController;
  late ProviderContainer container;

  setUp(() {
    client = MockSupabaseClient();
    auth = MockGoTrueClient();
    repository = MockAuthRepository();
    authStateController = StreamController<AuthState>.broadcast();
    tokenRefreshController = StreamController<String>.broadcast();

    when(() => client.auth).thenReturn(auth);
    when(
      () => auth.onAuthStateChange,
    ).thenAnswer((_) => authStateController.stream);
    when(() => auth.currentUser).thenReturn(null);
    when(() => repository.updateFcmToken(any())).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        supabaseClientProvider.overrideWithValue(client),
        authRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(authStateController.close);
    addTearDown(tokenRefreshController.close);
  });

  AuthStateListener createListener({Future<String?> Function()? getFcmToken}) {
    return AuthStateListener(
      container.read(_refProvider),
      client,
      isAccountDeleted: () async => false,
      getFcmToken: getFcmToken ?? () async => 'token-abc',
      getTokenRefreshStream: () => tokenRefreshController.stream,
    );
  }

  test('registers the FCM token when signed in', () async {
    final listener = createListener();
    addTearDown(listener.dispose);

    authStateController.add(const AuthState(AuthChangeEvent.signedIn, null));
    await Future<void>.delayed(Duration.zero);

    verify(() => repository.updateFcmToken('token-abc')).called(1);
  });

  test(
    'logs and does not throw when obtaining the FCM token fails',
    () async {
      final listener = createListener(
        getFcmToken: () async => throw Exception('no token'),
      );
      addTearDown(listener.dispose);

      authStateController.add(
        const AuthState(AuthChangeEvent.signedIn, null),
      );
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => repository.updateFcmToken(any()));
    },
  );

  test(
    'does not register the FCM token for unrelated auth events',
    () async {
      final listener = createListener();
      addTearDown(listener.dispose);

      authStateController.add(
        const AuthState(AuthChangeEvent.tokenRefreshed, null),
      );
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => repository.updateFcmToken(any()));
    },
  );

  test(
    'updates the FCM token on refresh while signed in',
    () async {
      when(() => auth.currentUser).thenReturn(MockUser());
      final listener = createListener();
      addTearDown(listener.dispose);

      tokenRefreshController.add('refreshed-token');
      await Future<void>.delayed(Duration.zero);

      verify(() => repository.updateFcmToken('refreshed-token')).called(1);
    },
  );

  test(
    'ignores FCM token refresh while signed out',
    () async {
      final listener = createListener();
      addTearDown(listener.dispose);

      tokenRefreshController.add('refreshed-token');
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => repository.updateFcmToken(any()));
    },
  );

  test(
    'signs out and does not register the FCM token for a deleted account',
    () async {
      when(() => auth.signOut()).thenAnswer((_) async {});
      final listener = AuthStateListener(
        container.read(_refProvider),
        client,
        isAccountDeleted: () async => true,
        getFcmToken: () async => 'token-abc',
        getTokenRefreshStream: () => tokenRefreshController.stream,
      );
      addTearDown(listener.dispose);

      authStateController.add(
        const AuthState(AuthChangeEvent.signedIn, null),
      );
      await Future<void>.delayed(Duration.zero);

      verify(() => auth.signOut()).called(1);
      verifyNever(() => repository.updateFcmToken(any()));
    },
  );

  test(
    'does not crash when the repository fails to persist the FCM token',
    () async {
      when(
        () => repository.updateFcmToken(any()),
      ).thenThrow(Exception('network error'));
      final listener = createListener();
      addTearDown(listener.dispose);

      authStateController.add(
        const AuthState(AuthChangeEvent.signedIn, null),
      );
      await Future<void>.delayed(Duration.zero);

      verify(() => repository.updateFcmToken('token-abc')).called(1);
    },
  );
}
