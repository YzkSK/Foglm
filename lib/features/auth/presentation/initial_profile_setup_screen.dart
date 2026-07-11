import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/core/widgets/form_status_text.dart';
import 'package:foglm/features/auth/application/sign_out_controller.dart';
import 'package:foglm/features/auth/application/update_profile_controller.dart';
import 'package:foglm/features/auth/data/my_profile_provider.dart';
import 'package:foglm/features/auth/domain/my_profile.dart';
import 'package:foglm/features/auth/widgets/logout_button.dart';
import 'package:go_router/go_router.dart';

/// プロフィール初期設定画面(S02)。
///
/// 初回ログイン時にニックネーム・アイコンを設定する(仕様書 3.1 / 4.1
/// S02参照)。`update_profile`はニックネームを自動生成された仮の値
/// (SNSプロフィール名やメールのローカル部)のまま呼ばれても
/// `profile_completed_at`を設定する(初回呼び出しのみ)ため、ここでの
/// 保存操作自体が「初回設定完了」の合図になる。保存後はグループ一覧
/// 画面(S03)へ遷移する。
class InitialProfileSetupScreen extends ConsumerStatefulWidget {
  const InitialProfileSetupScreen({super.key});

  @override
  ConsumerState<InitialProfileSetupScreen> createState() =>
      _InitialProfileSetupScreenState();
}

class _InitialProfileSetupScreenState
    extends ConsumerState<InitialProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _avatarUrlController = TextEditingController();
  bool _initialized = false;
  bool _hasSubmitted = false;

  @override
  void dispose() {
    _displayNameController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  void _initializeIfNeeded(MyProfileRow profile) {
    if (_initialized) {
      return;
    }
    // サインアップ時に自動生成された仮のニックネームを初期値として
    // 埋めておき、そのままでも変更してでも保存できるようにする。
    _displayNameController.text = profile.displayName;
    _avatarUrlController.text = profile.avatarUrl ?? '';
    _initialized = true;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _hasSubmitted = false);
      return;
    }
    setState(() => _hasSubmitted = true);
    final displayName = _displayNameController.text.trim();
    final avatarUrl = _avatarUrlController.text.trim();
    await ref
        .read(updateProfileControllerProvider.notifier)
        .submit(
          displayName: displayName,
          avatarUrl: avatarUrl.isEmpty ? null : avatarUrl,
        );

    if (!mounted) {
      return;
    }
    final state = ref.read(updateProfileControllerProvider);
    if (!state.hasError) {
      context.go('/groups');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);
    final updateState = ref.watch(updateProfileControllerProvider);
    final isSigningOut = ref.watch(
      signOutControllerProvider.select((state) => state.isLoading),
    );
    final isLoading = updateState.isLoading || isSigningOut;

    ref.listen<AsyncValue<void>>(signOutControllerProvider, (previous, next) {
      // signOut失敗を握り潰さず、ユーザーにも通知する。
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ログアウトに失敗しました。時間をおいて再度お試しください')),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('プロフィール設定'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: profileAsync.when(
          data: (profile) {
            if (profile == null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('プロフィールを取得できませんでした'),
                    const SizedBox(height: 16),
                    LogoutButton(isBusy: isSigningOut),
                  ],
                ),
              );
            }
            _initializeIfNeeded(profile);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('ニックネームとアイコンを設定しましょう。あとから設定画面でいつでも変更できます。'),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _displayNameController,
                      decoration: const InputDecoration(labelText: 'ニックネーム'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'ニックネームを入力してください';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _avatarUrlController,
                      decoration: const InputDecoration(
                        labelText: 'アイコン画像URL(任意)',
                      ),
                    ),
                    FormStatusText(
                      message: _hasSubmitted && updateState.hasError
                          ? 'プロフィールの保存に失敗しました。時間をおいて再度お試しください'
                          : null,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: isLoading ? null : _submit,
                      child: updateState.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('はじめる'),
                    ),
                    const SizedBox(height: 8),
                    // プロフィール保存中でも常にログアウトできるようにする
                    // ため、isLoading(保存中も含む)ではなくisSigningOutの
                    // みを見る(他の呼び出し箇所と同様)。
                    LogoutButton(isBusy: isSigningOut),
                  ],
                ),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) {
            // myProfileProviderの取得失敗を握り潰さず記録する。
            developer.log(
              'myProfileProvider failed to load',
              name: 'InitialProfileSetupScreen',
              error: error,
              stackTrace: stackTrace,
            );
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('プロフィールの取得に失敗しました'),
                  const SizedBox(height: 16),
                  LogoutButton(isBusy: isSigningOut),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
