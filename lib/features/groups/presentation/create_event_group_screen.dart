import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/groups/application/create_event_group_controller.dart';
import 'package:go_router/go_router.dart';

String _formatDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year/$month/$day';
}

/// イベントグループ作成画面(S04b)。
///
/// イベント名・開始日・終了日を入力して作成する(仕様書 3.11 / 4.1 S04b)。
/// グループ一覧画面(S03、#36)が未実装のため、作成成功後は暫定的に
/// カメラ画面('/camera')へ遷移する。
class CreateEventGroupScreen extends ConsumerStatefulWidget {
  const CreateEventGroupScreen({super.key});

  @override
  ConsumerState<CreateEventGroupScreen> createState() =>
      _CreateEventGroupScreenState();
}

class _CreateEventGroupScreenState
    extends ConsumerState<CreateEventGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String? _dateError;
  bool _hasSubmitted = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _submit() async {
    final isFormValid = _formKey.currentState?.validate() ?? false;
    final startDate = _startDate;
    final endDate = _endDate;

    setState(() {
      if (startDate == null || endDate == null) {
        _dateError = '開始日・終了日を選択してください';
      } else if (endDate.isBefore(startDate)) {
        _dateError = '終了日は開始日以降の日付を選択してください';
      } else {
        _dateError = null;
      }
    });

    if (!isFormValid || _dateError != null) {
      // バリデーションエラー時は前回のサーバーエラー表示を消し、
      // 新しいバリデーションエラーだけが見えるようにする。
      setState(() => _hasSubmitted = false);
      return;
    }

    setState(() => _hasSubmitted = true);
    await ref
        .read(createEventGroupControllerProvider.notifier)
        .submit(
          name: _nameController.text,
          startDate: startDate!,
          endDate: endDate!,
        );

    if (!mounted) {
      return;
    }
    final state = ref.read(createEventGroupControllerProvider);
    if (!state.hasError) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('イベントグループを作成しました')));
      context.go('/camera');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createEventGroupControllerProvider);
    final isLoading = state.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('イベントグループ作成')),
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
                  decoration: const InputDecoration(labelText: 'イベント名'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'イベント名を入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: isLoading ? null : _pickStartDate,
                  child: Text(
                    _startDate == null
                        ? '開始日を選択'
                        : '開始日: ${_formatDate(_startDate!)}',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: isLoading ? null : _pickEndDate,
                  child: Text(
                    _endDate == null
                        ? '終了日を選択'
                        : '終了日: ${_formatDate(_endDate!)}',
                  ),
                ),
                if (_dateError != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _dateError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                if (_hasSubmitted && state.hasError) ...[
                  const SizedBox(height: 16),
                  Text(
                    'イベントグループの作成に失敗しました。時間をおいて再度お試しください',
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
