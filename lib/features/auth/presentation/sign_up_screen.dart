import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foglm/features/auth/application/sign_up_controller.dart';
import 'package:foglm/features/auth/domain/sign_up_failure.dart';
import 'package:foglm/features/auth/domain/validators.dart';
import 'package:foglm/features/auth/presentation/email_verification_pending_screen.dart';
import 'package:go_router/go_router.dart';

const _snsProviderDisplayNames = {
  'google': 'Google',
  'apple': 'Apple',
  'x': 'X',
  'instagram': 'Instagram',
};

String _describeFailure(SignUpFailure failure) {
  switch (failure) {
    case InvalidEmailFailure():
      return 'メールアドレスの形式が正しくありません';
    case WeakPasswordFailure():
      return 'パスワードは8文字以上、英大文字・英小文字・数字を全て含めてください';
    case EmailUsedBySnsFailure(:final provider):
      final providerName = _snsProviderDisplayNames[provider] ?? provider;
      return 'そのメールアドレスは$providerNameで登録済みです。$providerNameでログインしてください。';
    case UnknownSignUpFailure():
      return '登録に失敗しました。時間をおいて再度お試しください。';
  }
}

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _localValidationError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (!isValidEmail(email)) {
      setState(() => _localValidationError = 'メールアドレスの形式が正しくありません');
      return;
    }
    if (!isValidPassword(password)) {
      setState(
        () => _localValidationError = 'パスワードは8文字以上、英大文字・英小文字・数字を全て含めてください',
      );
      return;
    }
    setState(() => _localValidationError = null);

    await ref
        .read(signUpControllerProvider.notifier)
        .submit(
          email: email,
          password: password,
        );

    final state = ref.read(signUpControllerProvider);
    if (state.hasError) {
      return;
    }
    if (mounted) {
      context.go(
        '/verify-pending',
        extra: VerifyPendingArgs(email: email, password: password),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(signUpControllerProvider);
    final errorMessage =
        _localValidationError ??
        (state.hasError
            ? _describeFailure(state.error! as SignUpFailure)
            : null);

    return Scaffold(
      appBar: AppBar(title: const Text('サインアップ')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              key: const Key('sign_up_email_field'),
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'メールアドレス'),
            ),
            TextField(
              key: const Key('sign_up_password_field'),
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'パスワード'),
            ),
            if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  errorMessage,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              key: const Key('sign_up_submit_button'),
              onPressed: state.isLoading ? null : _submit,
              child: const Text('登録する'),
            ),
          ],
        ),
      ),
    );
  }
}
