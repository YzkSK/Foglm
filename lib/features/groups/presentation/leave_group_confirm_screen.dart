import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/groups/application/leave_group_controller.dart';
import 'package:go_router/go_router.dart';

/// `LeaveGroupConfirmScreen`への遷移時にgo_routerの`extra`で渡す引数。
class LeaveGroupArgs {
  const LeaveGroupArgs({required this.groupId, required this.groupName});

  final String groupId;
  final String groupName;
}

/// グループ脱退確認画面(S13)。
///
/// 固定グループ・イベントグループ共通で、グループホームから遷移して
/// 脱退の確認・実行を行う(仕様書 3.2.1 / 4.1 S13参照)。
/// 脱退実行後はグループ一覧画面(S03)へ戻る。
class LeaveGroupConfirmScreen extends ConsumerStatefulWidget {
  const LeaveGroupConfirmScreen({
    required this.groupId,
    required this.groupName,
    super.key,
  });

  final String groupId;
  final String groupName;

  @override
  ConsumerState<LeaveGroupConfirmScreen> createState() =>
      _LeaveGroupConfirmScreenState();
}

class _LeaveGroupConfirmScreenState
    extends ConsumerState<LeaveGroupConfirmScreen> {
  bool _hasSubmitted = false;

  Future<void> _leave() async {
    setState(() => _hasSubmitted = true);
    await ref
        .read(leaveGroupControllerProvider.notifier)
        .submit(groupId: widget.groupId);

    if (!mounted) {
      return;
    }
    final state = ref.read(leaveGroupControllerProvider);
    if (!state.hasError) {
      context.go('/groups');
    }
  }

  @override
  Widget build(BuildContext context) {
    // groupIdが空の場合(不正な遷移。通常はcontext.push経由でのみ到達するため
    // 起こらない想定)は、脱退を実行させず早期にエラー表示する。
    if (widget.groupId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('グループを脱退')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('グループ情報を取得できませんでした'),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () => context.pop(),
                  child: const Text('戻る'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final state = ref.watch(leaveGroupControllerProvider);
    final isLoading = state.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('グループを脱退')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '「${widget.groupName}」を脱退しますか?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              const Text(
                '脱退すると、このグループの写真を今後閲覧できなくなります。'
                'この操作は取り消せません。',
              ),
              if (_hasSubmitted && state.hasError) ...[
                const SizedBox(height: 16),
                Text(
                  '脱退に失敗しました。既に脱退済みの可能性があります。'
                  'グループ一覧の状態をご確認のうえ、必要であれば再度お試しください',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: isLoading ? null : _leave,
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('脱退する'),
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
