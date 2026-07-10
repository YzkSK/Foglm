import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/groups/application/join_group_controller.dart';
import 'package:foglm/features/groups/data/my_groups_provider.dart';
import 'package:foglm/features/groups/domain/my_group.dart';
import 'package:foglm/features/groups/presentation/invite_screen.dart';
import 'package:foglm/features/groups/presentation/leave_group_confirm_screen.dart';
import 'package:go_router/go_router.dart';

/// グループ一覧画面(S03)。
///
/// 所属する固定グループ・イベントグループ・ソロモード枠を一覧表示し、
/// 新規作成・招待コードでの参加への導線を提供する(仕様書 4.1 S03参照)。
/// グループホーム画面が未実装のため、グループ選択時は暫定的に
/// カメラ画面('/camera')へ遷移する。
class GroupListScreen extends ConsumerWidget {
  const GroupListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(myGroupsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('グループ一覧')),
      body: SafeArea(
        child: groupsAsync.when(
          data: (groups) => _GroupListBody(groups: groups),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) {
            // myGroupsProviderの取得失敗を握り潰さず記録する。
            developer.log(
              'myGroupsProvider failed to load',
              name: 'GroupListScreen',
              error: error,
              stackTrace: stackTrace,
            );
            return const Center(child: Text('グループ一覧の取得に失敗しました'));
          },
        ),
      ),
    );
  }
}

/// グループタイルのサブタイトル文言(種別、アーカイブ済みの場合はその旨を付記)。
/// アーカイブ状態でも閲覧・リアクション・コメントは可能なため一覧からは除外しない
/// (仕様書 3.2.1/3.11参照)。
String _groupSubtitle(MyGroupRow group) {
  final kind = group.mode == 'event' ? 'イベントグループ' : '固定グループ';
  return group.status == 'archived' ? '$kind(アーカイブ済み)' : kind;
}

class _GroupListBody extends StatelessWidget {
  const _GroupListBody({required this.groups});

  final List<MyGroupRow> groups;

  @override
  Widget build(BuildContext context) {
    final soloGroup = groups.where((g) => g.mode == 'solo').firstOrNull;
    final otherGroups = groups.where((g) => g.mode != 'solo').toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (soloGroup != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.person),
              title: const Text('自分'),
              subtitle: const Text('ソロモード'),
              onTap: () => context.go('/camera'),
            ),
          ),
        const SizedBox(height: 8),
        if (otherGroups.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('参加しているグループはまだありません')),
          )
        else
          ...otherGroups.map(
            (group) => Card(
              child: ListTile(
                title: Text(group.name),
                subtitle: Text(_groupSubtitle(group)),
                onTap: () => context.go('/camera'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => context.push(
                        '/groups/invite',
                        extra: InviteArgs(
                          groupId: group.id,
                          groupName: group.name,
                        ),
                      ),
                      child: const Text('招待'),
                    ),
                    TextButton(
                      onPressed: () => context.push(
                        '/groups/leave',
                        extra: LeaveGroupArgs(
                          groupId: group.id,
                          groupName: group.name,
                        ),
                      ),
                      child: const Text('脱退'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => context.go('/groups/new'),
          child: const Text('固定グループを作成'),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () => context.go('/groups/new-event'),
          child: const Text('イベントグループを作成'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => showDialog<void>(
            context: context,
            useRootNavigator: false,
            builder: (context) => const _JoinGroupDialog(),
          ),
          child: const Text('招待コードで参加する'),
        ),
      ],
    );
  }
}

class _JoinGroupDialog extends ConsumerStatefulWidget {
  const _JoinGroupDialog();

  @override
  ConsumerState<_JoinGroupDialog> createState() => _JoinGroupDialogState();
}

class _JoinGroupDialogState extends ConsumerState<_JoinGroupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _hasSubmitted = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      // バリデーションエラー時は前回のサーバーエラー表示を消し、
      // 新しいバリデーションエラーだけが見えるようにする。
      setState(() => _hasSubmitted = false);
      return;
    }
    setState(() => _hasSubmitted = true);
    await ref
        .read(joinGroupControllerProvider.notifier)
        .submit(code: _codeController.text.trim());

    if (!mounted) {
      return;
    }
    final state = ref.read(joinGroupControllerProvider);
    if (!state.hasError) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('グループに参加しました')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(joinGroupControllerProvider);
    final isLoading = state.isLoading;

    return AlertDialog(
      title: const Text('招待コードで参加する'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: '招待コード'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '招待コードを入力してください';
                }
                return null;
              },
            ),
            if (_hasSubmitted && state.hasError) ...[
              const SizedBox(height: 16),
              Text(
                '招待コードが正しくないか、参加できませんでした',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: isLoading ? null : _submit,
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('参加する'),
        ),
      ],
    );
  }
}
