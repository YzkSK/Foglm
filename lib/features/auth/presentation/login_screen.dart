import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/auth/application/sign_in_controller.dart';
import 'package:foglm/features/auth/application/sign_out_controller.dart';
import 'package:foglm/features/auth/data/current_public_user_provider.dart';
import 'package:foglm/features/auth/domain/sign_in_failure.dart';
import 'package:foglm/features/auth/domain/validators.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ログイン画面(S01)。
///
/// SNSログイン(Google/Apple/X)・メールアドレス/パスワードログインの
/// 入口(仕様書 3.1 / 4.1 S01)。ログイン済みの場合は、グループ一覧画面
/// (S03、#36)が未実装のため暫定的なプレースホルダーを表示する。
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
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

  Future<void> _submitEmail() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _hasSubmitted = true);
    await ref
        .read(signInControllerProvider.notifier)
        .submitEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
  }

  Future<void> _submitSns(OAuthProvider provider) async {
    setState(() => _hasSubmitted = true);
    await ref.read(signInControllerProvider.notifier).submitSns(provider);
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentPublicUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Foglm')),
      body: SafeArea(
        child: switch (userAsync) {
          AsyncData(:final value) when value != null =>
            const _LoggedInPlaceholder(),
          AsyncError() => _buildLoginForm(),
          _ when userAsync.isLoading => const Center(
            child: CircularProgressIndicator(),
          ),
          _ => _buildLoginForm(),
        },
      ),
    );
  }

  Widget _buildLoginForm() {
    final state = ref.watch(signInControllerProvider);
    final isLoading = state.isLoading;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: isLoading
                ? null
                : () => _submitSns(OAuthProvider.google),
            icon: const Icon(Icons.g_mobiledata),
            label: const Text('Googleでログイン'),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: isLoading ? null : () => _submitSns(OAuthProvider.apple),
            icon: const Icon(Icons.apple),
            label: const Text('Appleでログイン'),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: isLoading
                ? null
                : () => _submitSns(OAuthProvider.twitter),
            icon: const Icon(Icons.alternate_email),
            label: const Text('X(Twitter)でログイン'),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _emailController,
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
                  controller: _passwordController,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(labelText: 'パスワード'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'パスワードを入力してください';
                    }
                    return null;
                  },
                ),
                if (_hasSubmitted && state.hasError) ...[
                  const SizedBox(height: 16),
                  Text(
                    signInFailureMessage(state.error),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: isLoading ? null : _submitEmail,
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('ログイン'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.go('/signup'),
            child: const Text('アカウントをお持ちでない方はこちら'),
          ),
          TextButton(
            onPressed: () => context.go('/password-reset'),
            child: const Text('パスワードを忘れた方はこちら'),
          ),
        ],
      ),
    );
  }
}

/// [SignInFailure]を画面表示用の日本語メッセージに変換する。
String signInFailureMessage(Object? error) {
  return switch (error) {
    InvalidCredentialsFailure() => 'メールアドレスまたはパスワードが正しくありません',
    EmailNotConfirmedFailure() => 'メールアドレスが確認されていません。確認メールをご確認ください',
    DeletedAccountFailure() => 'このアカウントは削除済みのため、ご利用いただけません',
    _ => 'ログインに失敗しました。時間をおいて再度お試しください',
  };
}

class _LoggedInPlaceholder extends ConsumerWidget {
  const _LoggedInPlaceholder();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('ログイン済み'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.go('/camera'),
            child: const Text('カメラ'),
          ),
          TextButton(
            onPressed: () =>
                ref.read(signOutControllerProvider.notifier).signOut(),
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );
  }
}
