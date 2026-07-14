import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/candidates/application/today_candidates_provider.dart';
import 'package:foglm/features/candidates/application/usecase/cast_vote_usecase.dart';

class CastVoteController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submit({
    required String groupId,
    required String photoId,
  }) async {
    state = const AsyncLoading<void>();
    state = await AsyncValue.guard(
      () => ref.read(castVoteUseCaseProvider).call(photoId: photoId),
    );
    if (!state.hasError) {
      // 得票数・自分の投票状態を反映させるため、候補一覧を再取得させる。
      ref.invalidate(todayCandidatesProvider(groupId));
    }
  }
}

final castVoteControllerProvider =
    AsyncNotifierProvider<CastVoteController, void>(
      CastVoteController.new,
    );
