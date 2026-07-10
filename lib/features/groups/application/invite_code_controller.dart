import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/groups/data/group_repository.dart';

class InviteCodeController extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async => null;

  /// 画面表示時に呼ぶ。既存の招待コードがあればそれを表示し、まだ無ければ
  /// 新規発行する(create_invite_codeは呼ぶたびにコードを置き換えてしまうため、
  /// 既存コードを無効化しないようにここでは無条件に発行しない)。
  Future<void> load({required String groupId}) async {
    state = const AsyncLoading<String?>();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(groupRepositoryProvider);
      final existing = await repository.getInviteCode(groupId: groupId);
      if (existing != null) {
        return existing;
      }
      return repository.createInviteCode(groupId: groupId);
    });
  }

  /// 既存の招待コードを無効化し、新しいコードを発行し直す(ユーザーの明示的な操作からのみ呼ぶ)。
  Future<void> reissue({required String groupId}) async {
    state = const AsyncLoading<String?>();
    state = await AsyncValue.guard(
      () => ref
          .read(groupRepositoryProvider)
          .createInviteCode(
            groupId: groupId,
          ),
    );
  }
}

final inviteCodeControllerProvider =
    AsyncNotifierProvider<InviteCodeController, String?>(
      InviteCodeController.new,
    );
