import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/groups/application/usecase/create_invite_code_usecase.dart';
import 'package:foglm/features/groups/application/usecase/get_or_create_invite_code_usecase.dart';

class InviteCodeController extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async => null;

  /// 画面表示時に呼ぶ。既存の招待コードがあればそれを表示し、まだ無ければ
  /// 新規発行する。
  Future<void> load({required String groupId}) async {
    state = const AsyncLoading<String?>();
    state = await AsyncValue.guard(
      () =>
          ref.read(getOrCreateInviteCodeUseCaseProvider).call(groupId: groupId),
    );
  }

  /// 既存の招待コードを無効化し、新しいコードを発行し直す(ユーザーの明示的な操作からのみ呼ぶ)。
  Future<void> reissue({required String groupId}) async {
    state = const AsyncLoading<String?>();
    state = await AsyncValue.guard(
      () => ref
          .read(createInviteCodeUseCaseProvider)
          .call(
            groupId: groupId,
          ),
    );
  }
}

final inviteCodeControllerProvider =
    AsyncNotifierProvider<InviteCodeController, String?>(
      InviteCodeController.new,
    );
