import 'package:flutter/material.dart';

/// 取得失敗時に、原因メッセージと再読み込みボタンを表示する。
///
/// group_list_screen.dart・candidate_list_screen.dartで重複していた
/// 表示ロジックを共通化したもの。
class RetryableError extends StatelessWidget {
  const RetryableError({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('再読み込み')),
        ],
      ),
    );
  }
}
