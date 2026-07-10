import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/auth/application/delete_account_controller.dart';
import 'package:go_router/go_router.dart';

/// アカウント削除確認画面。
///
/// 設定・マイページ画面(S12)から遷移し、削除の確認・実行を行う
/// (仕様書 3.1.3参照)。削除は取り消せないため、実行前に警告する。
/// 削除成功後は認証状態が失われ、ルーターのredirectによりログイン画面へ
/// 自動的に戻る。
class DeleteAccountConfirmScreen extends ConsumerStatefulWidget {
  const DeleteAccountConfirmScreen({super.key});

  @override
  ConsumerState<DeleteAccountConfirmScreen> createState() =>
      _DeleteAccountConfirmScreenState();
}

class _DeleteAccountConfirmScreenState
    extends ConsumerState<DeleteAccountConfirmScreen> {
  bool _hasSubmitted = false;

  Future<void> _delete() async {
    setState(() => _hasSubmitted = true);
    await ref.read(deleteAccountControllerProvider.notifier).submit();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(deleteAccountControllerProvider);
    final isLoading = state.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('アカウント削除')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'アカウントを削除しますか?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              const Text(
                'アカウントを削除すると、ログインできなくなります。'
                'この操作は取り消せません。'
                '所属していたグループは全て脱退・解散扱いとなり、'
                'ソロモードの写真は完全に削除されます。',
              ),
              if (_hasSubmitted && state.hasError) ...[
                const SizedBox(height: 16),
                Text(
                  'アカウント削除に失敗しました。時間をおいて再度お試しください',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: isLoading ? null : _delete,
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('アカウントを削除する'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: isLoading ? null : () => context.pop(),
                child: const Text('キャンセル'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
