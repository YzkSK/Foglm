import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/groups/application/invite_code_controller.dart';

/// `InviteScreen`への遷移時にgo_routerの`extra`で渡す引数。
class InviteArgs {
  const InviteArgs({required this.groupId, required this.groupName});

  final String groupId;
  final String groupName;
}

/// 招待画面(S05)。
///
/// 固定グループ・イベントグループ共通で、グループホームから遷移して
/// 招待コードを発行・共有する(仕様書 3.2 / 4.1 S05参照)。
/// 招待リンクの共有基盤は未整備のため、当面は招待コードのコピーのみ提供する。
class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({
    required this.groupId,
    required this.groupName,
    super.key,
  });

  final String groupId;
  final String groupName;

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(
      Future.microtask(
        () => ref
            .read(inviteCodeControllerProvider.notifier)
            .load(groupId: widget.groupId),
      ),
    );
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('招待コードをコピーしました')));
  }

  Future<void> _reissueCode() async {
    await ref
        .read(inviteCodeControllerProvider.notifier)
        .reissue(groupId: widget.groupId);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inviteCodeControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('招待')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '「${widget.groupName}」への招待コード',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              if (state.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (state.hasError)
                Text(
                  '招待コードの発行に失敗しました。時間をおいて再度お試しください',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                )
              else if (state.value != null) ...[
                SelectableText(
                  state.value!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _copyCode(state.value!),
                  child: const Text('コードをコピー'),
                ),
                const SizedBox(height: 24),
                const Text(
                  '再発行すると、これまでに共有した招待コードは使えなくなります。',
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _reissueCode,
                  child: const Text('コードを再発行する'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
