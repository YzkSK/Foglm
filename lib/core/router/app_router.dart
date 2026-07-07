import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foglm/core/router/auth_guard.dart';
import 'package:foglm/features/auth/data/current_public_user_provider.dart';
import 'package:foglm/features/auth/presentation/password_reset_request_screen.dart';
import 'package:foglm/features/auth/presentation/sign_up_screen.dart';
import 'package:foglm/features/camera/camera_screen.dart';
import 'package:go_router/go_router.dart';

/// `currentPublicUserProvider`の値が変わるたび(ローディング→取得完了を含む)に
/// `GoRouter`の`redirect`を再評価させるための`Listenable`。
class AuthRedirectRefreshNotifier extends ChangeNotifier {
  AuthRedirectRefreshNotifier(Ref ref) {
    ref.listen(currentPublicUserProvider, (previous, next) {
      notifyListeners();
    });
  }
}

final authRedirectRefreshNotifierProvider =
    Provider<AuthRedirectRefreshNotifier>((ref) {
      final notifier = AuthRedirectRefreshNotifier(ref);
      ref.onDispose(notifier.dispose);
      return notifier;
    });

/// アプリ全体のルーティング定義の土台。
/// 各画面(S01〜S13)は別Issueで追加していく。
final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ref.watch(authRedirectRefreshNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final userAsync = ref.read(currentPublicUserProvider);
      final user = userAsync.value;
      final authRedirect = authRequiredRedirect(
        user: user,
        isLoading: userAsync.isLoading && !userAsync.hasValue,
        location: state.matchedLocation,
      );
      if (authRedirect != null) {
        return authRedirect;
      }
      return emailVerificationRedirect(
        user: user,
        location: state.matchedLocation,
      );
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const _PlaceholderHome(),
      ),

      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpScreen(),
      ),

      // '/verify-pending' は別issue(#95)でUI実装時に追加する。
      GoRoute(
        path: '/password-reset',
        builder: (context, state) => const PasswordResetRequestScreen(),
      ),

      GoRoute(
        path: '/camera',
        builder: (context, state) => const CameraScreen(),
      ),
    ],
  );
});

class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Foglm'),
            ElevatedButton(
              onPressed: () => context.go('/camera'),
              child: const Text('カメラ'),
            ),
            ElevatedButton(
              onPressed: () => context.go('/signup'),
              child: const Text('サインアップ'),
            ),
            ElevatedButton(
              onPressed: () => context.go('/password-reset'),
              child: const Text('パスワードリセット'),
            ),
          ],
        ),
      ),
    );
  }
}
