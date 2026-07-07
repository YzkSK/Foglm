import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/auth/application/password_reset_request_controller.dart';
import 'package:foglm/features/auth/domain/password_reset_failure.dart';
import 'package:foglm/features/auth/domain/validators.dart';

/// パスワードリセット申請画面(S01d)。
///
/// メールアドレスを入力し、リセットリンクを送信する(仕様書 3.1 / 4.1 S01d)。
/// リセットリンクはメール経由でS01e(新パスワード設定画面、#97)へ遷移する
/// 想定のため、本画面からS01eへのアプリ内ナビゲーションは行わない。
class PasswordResetRequestScreen extends ConsumerStatefulWidget {
  const PasswordResetRequestScreen({super.key});

  @override
  ConsumerState<PasswordResetRequestScreen> createState() =>
      _PasswordResetRequestScreenState();
}

class _PasswordResetRequestScreenState
    extends ConsumerState<PasswordResetRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _hasSubmitted = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _hasSubmitted = true);
    await ref
        .read(passwordResetRequestControllerProvider.notifier)
        .submit(email: _emailController.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(passwordResetRequestControllerProvider);
    final isLoading = state.isLoading;
    // AsyncNotifier<void>はhasValueが常にtrueになる(Riverpodが直前の値を
    // 自動的に引き継ぐため)ので、成功判定にはhasErrorの不在を使う。
    final isSuccess = _hasSubmitted && !isLoading && !state.hasError;

    return Scaffold(
      appBar: AppBar(title: const Text('パスワードリセット')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: isSuccess
              ? const _PasswordResetRequestSuccessMessage()
              : _PasswordResetRequestForm(
                  formKey: _formKey,
                  emailController: _emailController,
                  isLoading: isLoading,
                  errorMessage: _hasSubmitted && state.hasError
                      ? passwordResetFailureMessage(state.error)
                      : null,
                  onSubmit: _submit,
                ),
        ),
      ),
    );
  }
}

class _PasswordResetRequestForm extends StatelessWidget {
  const _PasswordResetRequestForm({
    required this.formKey,
    required this.emailController,
    required this.isLoading,
    required this.errorMessage,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'メールアドレス'),
            validator: (value) {
              if (value == null || !isValidEmail(value)) {
                return 'メールアドレスの形式が正しくありません';
              }
              return null;
            },
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: isLoading ? null : onSubmit,
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('リセットリンクを送信する'),
          ),
        ],
      ),
    );
  }
}

/// [PasswordResetFailure]を画面表示用の日本語メッセージに変換する。
String passwordResetFailureMessage(Object? error) {
  return switch (error) {
    PasswordResetInvalidEmailFailure() => 'メールアドレスの形式が正しくありません',
    PasswordResetWeakPasswordFailure() => '8文字以上、英大文字・小文字・数字を全て含めてください',
    PasswordResetUpdateFailedFailure() => 'パスワードの更新に失敗しました。時間をおいて再度お試しください',
    _ => '送信に失敗しました。時間をおいて再度お試しください',
  };
}

class _PasswordResetRequestSuccessMessage extends StatelessWidget {
  const _PasswordResetRequestSuccessMessage();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.mail_outline, size: 48),
        const SizedBox(height: 16),
        Text(
          'パスワードリセットメールを送信しました',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'メール内のリンクをクリックして新しいパスワードを設定してください',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
