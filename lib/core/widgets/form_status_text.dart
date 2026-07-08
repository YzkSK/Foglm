import 'package:flutter/material.dart';

/// フォーム下部に表示する状態メッセージ(送信エラー・完了通知等)。
///
/// `message`が`null`の場合は何も表示しない(スペースも取らない)。
/// login_screen.dart・sign_up_screen.dart・password_reset_request_screen.dart・
/// reset_password_screen.dart・email_verification_pending_screen.dartで
/// 重複していた表示ロジックを共通化したもの。
class FormStatusText extends StatelessWidget {
  const FormStatusText({required this.message, this.isError = true, super.key});

  final String? message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final message = this.message;
    if (message == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        message,
        style: isError
            ? TextStyle(color: Theme.of(context).colorScheme.error)
            : null,
      ),
    );
  }
}
