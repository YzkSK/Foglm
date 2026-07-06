import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foglm/features/auth/data/auth_repository.dart';
import 'package:foglm/features/auth/data/current_public_user_provider.dart';
import 'package:go_router/go_router.dart';

/// `/verify-pending`ルートの`extra`として渡す引数。
///
/// パスワードはS01c画面で「確認した」ボタン押下時に再サインインするために
/// メモリ上でのみ引き回す(永続化・ログ出力は一切行わない)。
class VerifyPendingArgs {
  const VerifyPendingArgs({required this.email, required this.password});

  final String email;
  final String password;
}

class EmailVerificationPendingScreen extends ConsumerStatefulWidget {
  const EmailVerificationPendingScreen({
    required this.email,
    required this.password,
    super.key,
  });

  final String email;
  final String password;

  @override
  ConsumerState<EmailVerificationPendingScreen> createState() =>
      _EmailVerificationPendingScreenState();
}

class _EmailVerificationPendingScreenState
    extends ConsumerState<EmailVerificationPendingScreen> {
  bool _isBusy = false;
  String? _message;

  Future<void> _resend() async {
    setState(() => _isBusy = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .resendVerificationEmail(email: widget.email);
      if (mounted) {
        setState(() => _message = '確認メールを再送しました');
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _checkConfirmed() async {
    setState(() => _isBusy = true);
    try {
      final verified = await ref
          .read(authRepositoryProvider)
          .checkEmailVerifiedBySignIn(
            email: widget.email,
            password: widget.password,
          );
      if (!mounted) {
        return;
      }
      if (verified) {
        ref.invalidate(currentPublicUserProvider);
        context.go('/');
      } else {
        setState(() => _message = 'まだ確認が完了していません。メール内のリンクを確認してください。');
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('メール確認待ち')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('${widget.email} 宛に確認メールを送信しました。メール内のリンクを開いて確認を完了してください。'),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_message!),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              key: const Key('resend_button'),
              onPressed: _isBusy ? null : _resend,
              child: const Text('確認メールを再送する'),
            ),
            ElevatedButton(
              key: const Key('confirmed_button'),
              onPressed: _isBusy ? null : _checkConfirmed,
              child: const Text('確認した'),
            ),
          ],
        ),
      ),
    );
  }
}
