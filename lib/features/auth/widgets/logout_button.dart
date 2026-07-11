import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/auth/application/sign_out_controller.dart';

/// 設定・マイページ画面(S12)に到達できない画面(メール確認待ち・
/// 初回プロフィール設定など)向けのログアウトボタン。仕様書3.1.1の
/// 「いつでもログアウトできる」を満たすため、そうした画面にも置く。
class LogoutButton extends ConsumerWidget {
  const LogoutButton({required this.isBusy, super.key});

  final bool isBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton(
      onPressed: isBusy
          ? null
          : () => ref.read(signOutControllerProvider.notifier).signOut(),
      child: isBusy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('ログアウト'),
    );
  }
}
