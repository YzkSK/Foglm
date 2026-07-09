import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/groups/data/group_repository.dart';

class InviteCodeController extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async => null;

  Future<void> issue({required String groupId}) async {
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
