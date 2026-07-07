import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/auth/application/update_profile_controller.dart';
import 'package:foglm/features/auth/data/my_profile_provider.dart';
import 'package:foglm/features/auth/domain/my_profile.dart';

/// プロフィール編集画面(S12内)。
///
/// ニックネーム・アイコンをいつでも変更できる(仕様書 3.1.2)。
/// アイコンは画像アップロード基盤が未実装のため、当面はURLを直接
/// 入力する簡易的な実装に留める。
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
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
    _displayNameController.text = profile.displayName;
    _avatarUrlController.text = profile.avatarUrl ?? '';
    _initialized = true;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      // バリデーションエラー時は前回のサーバーエラー表示を消し、
      // 新しいバリデーションエラーだけが見えるようにする。
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('プロフィールを更新しました')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);
    final updateState = ref.watch(updateProfileControllerProvider);
    final isLoading = updateState.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('プロフィール編集')),
      body: SafeArea(
        child: profileAsync.when(
          data: (profile) {
            if (profile == null) {
              return const Center(child: Text('プロフィールを取得できませんでした'));
            }
            _initializeIfNeeded(profile);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                    if (_hasSubmitted && updateState.hasError) ...[
                      const SizedBox(height: 16),
                      Text(
                        'プロフィールの更新に失敗しました。時間をおいて再度お試しください',
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
                          : const Text('保存する'),
                    ),
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
              name: 'ProfileEditScreen',
              error: error,
              stackTrace: stackTrace,
            );
            return const Center(child: Text('プロフィールの取得に失敗しました'));
          },
        ),
      ),
    );
  }
}
