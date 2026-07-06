import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foglm/core/router/auth_guard.dart';
import 'package:foglm/features/auth/data/current_public_user_provider.dart';
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
      // '/signup', '/verify-pending' は別issueでUI実装時に追加する。
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
