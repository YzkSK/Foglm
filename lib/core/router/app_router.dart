import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foglm/core/config/env.dart';
import 'package:foglm/core/router/auth_guard.dart';
import 'package:foglm/features/auth/data/auth_state_listener.dart';
import 'package:foglm/features/auth/data/current_public_user_provider.dart';
import 'package:foglm/features/auth/presentation/email_verification_pending_screen.dart';
import 'package:foglm/features/auth/presentation/login_screen.dart';
import 'package:foglm/features/auth/presentation/password_reset_request_screen.dart';
import 'package:foglm/features/auth/presentation/reset_password_screen.dart';
import 'package:foglm/features/auth/presentation/sign_up_screen.dart';

import 'package:foglm/features/camera/camera_screen.dart';
import 'package:foglm/features/debug/presentation/debug_menu_screen.dart';
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
  // アプリ起動中ずっと認証状態を監視させるため、ここでインスタンス化する
  // (SNSログイン完了・削除済みアカウント判定の検知。詳細はdocコメント参照)。
  ref.watch(authStateListenerProvider);

  return GoRouter(
    initialLocation: Env.isDevProfile ? '/debug' : '/',
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
        builder: (context, state) => const LoginScreen(),
      ),

      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignUpScreen(),
      ),

      GoRoute(
        path: '/verify-pending',
        builder: (context, state) {
          final args = state.extra as VerifyPendingArgs?;
          return EmailVerificationPendingScreen(
            email: args?.email ?? '',
            password: args?.password ?? '',
          );
        },
      ),

      GoRoute(
        path: '/password-reset',
        builder: (context, state) => const PasswordResetRequestScreen(),
      ),

      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
      ),

      GoRoute(
        path: '/camera',
        builder: (context, state) => const CameraScreen(),
      ),

      if (Env.isDevProfile)
        GoRoute(
          path: '/debug',
          builder: (context, state) => const DebugMenuScreen(),
        ),
    ],
  );
});
