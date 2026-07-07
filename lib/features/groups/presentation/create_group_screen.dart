import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/groups/application/create_group_controller.dart';
import 'package:go_router/go_router.dart';

/// グループ作成画面(S04)。
///
/// 固定グループ名を入力して作成する(仕様書 3.2 / 4.1 S04)。
/// グループ一覧画面(S03、#36)が未実装のため、作成成功後は暫定的に
/// カメラ画面('/camera')へ遷移する。
class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _hasSubmitted = false;

  @override
  void dispose() {
    _nameController.dispose();
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
        .read(createGroupControllerProvider.notifier)
        .submit(name: _nameController.text);

    if (!mounted) {
      return;
    }
    final state = ref.read(createGroupControllerProvider);
    if (!state.hasError) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('グループを作成しました')));
      context.go('/camera');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createGroupControllerProvider);
    final isLoading = state.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('グループ作成')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'グループ名'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'グループ名を入力してください';
                    }
                    return null;
                  },
                ),
                if (_hasSubmitted && state.hasError) ...[
                  const SizedBox(height: 16),
                  Text(
                    'グループの作成に失敗しました。時間をおいて再度お試しください',
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
                      : const Text('作成する'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
