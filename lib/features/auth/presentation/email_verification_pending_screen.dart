import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/core/widgets/form_status_text.dart';
import 'package:foglm/features/auth/data/auth_repository.dart';
import 'package:foglm/features/auth/data/current_public_user_provider.dart';
import 'package:go_router/go_router.dart';

/// `/verify-pending`ルートの`extra`として渡す引数。
///
/// パスワードは本画面で「確認した」ボタン押下時に再サインインするために
/// メモリ上でのみ引き回す(永続化・ログ出力は一切行わない)。
class VerifyPendingArgs {
  const VerifyPendingArgs({required this.email, required this.password});

  final String email;
  final String password;
}

/// メール確認待ち画面(S01c)。
///
/// サインアップ直後に表示され、確認メールのリンクを踏むまでの案内・
/// 確認メール再送導線を提供する(仕様書 3.1 / 4.1 S01c / 6.1 verify_email)。
/// 確認完了後はプロフィール初期設定画面(S02、#5)へ遷移する想定だが、
/// そちらが未実装のためログイン画面('/')へ遷移するに留める。
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
  bool _isMessageError = false;

  Future<void> _resend() async {
    setState(() {
      _isBusy = true;
      _message = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .resendVerificationEmail(email: widget.email);
      if (mounted) {
        setState(() {
          _message = '確認メールを再送しました';
          _isMessageError = false;
        });
      }
    } on Object catch (_) {
      // AuthException(レート制限等)に限らず、通信エラー等も含めて
      // 必ずユーザーに結果を伝える(エラーを握り潰さない)。
      if (mounted) {
        setState(() {
          _message = '確認メールの再送に失敗しました。時間をおいて再度お試しください';
          _isMessageError = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _checkConfirmed() async {
    setState(() {
      _isBusy = true;
      _message = null;
    });
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
        setState(() {
          _message = 'まだ確認が完了していません。メール内のリンクを確認してください';
          _isMessageError = true;
        });
      }
    } on Object catch (_) {
      // AuthExceptionに限らず、通信エラー等も含めて必ずユーザーに結果を伝える
      // (エラーを握り潰さない)。
      if (mounted) {
        setState(() {
          _message = '確認状態の確認に失敗しました。時間をおいて再度お試しください';
          _isMessageError = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // '/verify-pending'への直接アクセス・ディープリンク・再起動等でextraが
    // 渡されなかった場合、email/passwordが空文字になる(app_router.dart参照)。
    // その状態のまま再送・再サインインを試みてもエラーになるだけなので、
    // サインアップへ案内する専用の表示にする。
    if (widget.email.isEmpty || widget.password.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('メール確認待ち')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('このページには直接アクセスできません。サインアップからやり直してください。'),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go('/signup'),
                  child: const Text('サインアップ画面へ'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('メール確認待ち')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.email} 宛に確認メールを送信しました。'
                '\nメール内のリンクを開いて確認を完了してください。',
              ),
              FormStatusText(message: _message, isError: _isMessageError),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isBusy ? null : _resend,
                child: const Text('確認メールを再送する'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _isBusy ? null : _checkConfirmed,
                child: _isBusy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('確認した'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
