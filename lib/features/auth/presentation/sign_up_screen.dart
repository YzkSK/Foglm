import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/core/widgets/form_status_text.dart';
import 'package:foglm/features/auth/application/sign_up_controller.dart';
import 'package:foglm/features/auth/domain/sign_up_failure.dart';
import 'package:foglm/features/auth/domain/validators.dart';
import 'package:foglm/features/auth/presentation/email_verification_pending_screen.dart';
import 'package:go_router/go_router.dart';

/// サインアップ画面(S01b)。
///
/// メールアドレス・パスワードでの新規登録を行う(仕様書 3.1 / 4.1 S01b)。
/// 登録成功後はメール確認待ち画面(S01c)へ遷移する。
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _hasSubmitted = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      // バリデーションエラー時は前回のサーバーエラー表示を消し、
      // 新しいバリデーションエラーだけが見えるようにする。
      setState(() => _hasSubmitted = false);
      return;
    }
    final email = _emailController.text;
    final password = _passwordController.text;
    setState(() => _hasSubmitted = true);
    await ref
        .read(signUpControllerProvider.notifier)
        .submit(email: email, password: password);

    if (!mounted) {
      return;
    }
    final state = ref.read(signUpControllerProvider);
    if (!state.hasError) {
      context.go(
        '/verify-pending',
        extra: VerifyPendingArgs(email: email, password: password),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(signUpControllerProvider);
    final isLoading = state.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('サインアップ')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _SignUpForm(
            formKey: _formKey,
            emailController: _emailController,
            passwordController: _passwordController,
            isLoading: isLoading,
            errorMessage: _hasSubmitted && state.hasError
                ? signUpFailureMessage(state.error)
                : null,
            onSubmit: _submit,
          ),
        ),
      ),
    );
  }
}

class _SignUpForm extends StatelessWidget {
  const _SignUpForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.isLoading,
    required this.errorMessage,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
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
          const SizedBox(height: 16),
          TextFormField(
            controller: passwordController,
            obscureText: true,
            autofillHints: const [AutofillHints.newPassword],
            decoration: const InputDecoration(
              labelText: 'パスワード',
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
          FormStatusText(message: errorMessage),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: isLoading ? null : onSubmit,
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('登録する'),
          ),
        ],
      ),
    );
  }
}

/// SNSプロバイダの生の識別子(Supabaseの実プロバイダ表記)を表示名に変換する。
String _providerDisplayName(String provider) {
  return switch (provider) {
    'google' => 'Google',
    'apple' => 'Apple',
    'twitter' => 'X(Twitter)',
    _ => provider,
  };
}

/// [SignUpFailure]を画面表示用の日本語メッセージに変換する。
String signUpFailureMessage(Object? error) {
  return switch (error) {
    InvalidEmailFailure() => 'メールアドレスの形式が正しくありません',
    WeakPasswordFailure() => '8文字以上、英大文字・小文字・数字を全て含めてください',
    EmailUsedBySnsFailure(:final provider) =>
      'このメールアドレスは${_providerDisplayName(provider)}で登録済みです。'
          '${_providerDisplayName(provider)}でログインしてください',
    _ => '登録に失敗しました。時間をおいて再度お試しください',
  };
}
