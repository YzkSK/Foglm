import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foglm/core/router/auth_guard.dart';
import 'package:foglm/features/auth/data/current_public_user_provider.dart';
import 'package:foglm/features/auth/presentation/email_verification_pending_screen.dart';
import 'package:foglm/features/auth/presentation/sign_up_screen.dart';
import 'package:go_router/go_router.dart';

/// アプリ全体のルーティング定義の土台。
/// 各画面(S01〜S13)は別Issueで追加していく。
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final user = ref.read(currentPublicUserProvider).value;
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
    ],
  );
});

class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Foglm')),
    );
  }
}
