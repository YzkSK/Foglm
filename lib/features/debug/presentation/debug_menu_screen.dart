import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// devプロファイル限定のデバッグ用ナビゲーション画面。
/// 実装済み各画面へ本番導線を経由せず直接遷移して動作確認するために使う。
/// 本番ビルド(devプロファイル以外)ではルート自体が登録されず到達できない
/// (`lib/core/router/app_router.dart`の`Env.isDevProfile`分岐を参照)。
class DebugMenuScreen extends StatelessWidget {
  const DebugMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('デバッグメニュー')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () => context.go('/camera'),
              child: const Text('カメラ'),
            ),
            ElevatedButton(
              onPressed: () => context.go('/groups/new'),
              child: const Text('グループ作成'),
            ),
            ElevatedButton(
              onPressed: () => context.go('/groups/new-event'),
              child: const Text('イベントグループ作成'),
            ),
            ElevatedButton(
              onPressed: () => context.go('/signup'),
              child: const Text('サインアップ'),
            ),
            ElevatedButton(
              onPressed: () => context.go('/password-reset'),
              child: const Text('パスワードリセット'),
            ),
            ElevatedButton(
              onPressed: () => context.go('/reset-password'),
              child: const Text('新パスワード設定'),
            ),
          ],
        ),
      ),
    );
  }
}
