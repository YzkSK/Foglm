import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/auth/application/reset_password_controller.dart';
import 'package:foglm/features/auth/domain/validators.dart';
import 'package:foglm/features/auth/presentation/password_reset_request_screen.dart'
    show passwordResetFailureMessage;
import 'package:go_router/go_router.dart';

/// 新パスワード設定画面(S01e)。
///
/// パスワードリセットメール内のリンクから遷移し、新しいパスワードを
/// 設定する(仕様書 3.1 / 4.1 S01e)。設定完了後はログイン画面(S01、'/')
/// へ戻る。
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _hasSubmitted = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _hasSubmitted = true);
    await ref
        .read(resetPasswordControllerProvider.notifier)
        .submit(newPassword: _passwordController.text);

    if (!mounted) {
      return;
    }
    final state = ref.read(resetPasswordControllerProvider);
    if (!state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('パスワードを更新しました')),
      );
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(resetPasswordControllerProvider);
    final isLoading = state.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('新しいパスワードの設定')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: const InputDecoration(
                    labelText: '新しいパスワード',
                    helperText: '8文字以上、英大文字・小文字・数字を全て含む',
                    helperMaxLines: 2,
                  ),
                  validator: (value) {
                    if (value == null || !isValidPassword(value)) {
                      return '8文字以上、英大文字・小文字・数字を全て含めてください';
                    }
                    return null;
                  },
                ),
                if (_hasSubmitted && state.hasError) ...[
                  const SizedBox(height: 16),
                  Text(
                    passwordResetFailureMessage(state.error),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('パスワードを更新する'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
