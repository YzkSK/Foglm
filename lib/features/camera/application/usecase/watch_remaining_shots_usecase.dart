import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foglm/features/camera/data/remaining_shots_repository.dart';
import 'package:foglm/features/camera/domain/remaining_shots_repository.dart';

/// 指定したグループの当日の残り撮影可能枚数を購読する(仕様書 5.2.3参照)。
class WatchRemainingShotsUseCase {
  WatchRemainingShotsUseCase(this._repository);

  final RemainingShotsRepository _repository;

  Stream<int> call({required String groupId}) {
    return _repository.watchTodayShotsRemaining(groupId: groupId);
  }
}

final watchRemainingShotsUseCaseProvider = Provider<WatchRemainingShotsUseCase>(
  (ref) {
    return WatchRemainingShotsUseCase(
      ref.watch(remainingShotsRepositoryProvider),
    );
  },
);
