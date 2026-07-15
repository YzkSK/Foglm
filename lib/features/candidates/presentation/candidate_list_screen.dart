import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/core/widgets/retryable_error.dart';
import 'package:foglm/features/candidates/application/cast_vote_controller.dart';
import 'package:foglm/features/candidates/data/today_candidates_provider.dart';
import 'package:foglm/features/candidates/domain/candidate_photo.dart';

/// `/candidates`ルートの`extra`として渡す引数。
class CandidateListArgs {
  const CandidateListArgs({required this.groupId});

  final String groupId;
}

/// 今日の候補一覧画面(S07)。
///
/// その日撮影された写真をボヤけた状態で一覧表示し、現在の得票状況を
/// 確認できる(仕様書 3.5 / 4.1 S07参照)。候補写真をタップすると
/// その場でその写真に投票する(再投票可、最後の一票のみ有効)。
/// 候補写真の拡大表示(S08、#23)は別issueで対応する。
class CandidateListScreen extends ConsumerStatefulWidget {
  const CandidateListScreen({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<CandidateListScreen> createState() =>
      _CandidateListScreenState();
}

class _CandidateListScreenState extends ConsumerState<CandidateListScreen> {
  // 投票中はタップ元のタイルにだけローディング表示を出すために、対象の
  // photoIdを保持する(全タイル共通のローディングフラグだけだと、
  // どの写真に投票しようとしたのか分からなくなるため)。
  String? _votingPhotoId;

  Future<void> _vote(String photoId) async {
    setState(() => _votingPhotoId = photoId);
    try {
      await ref
          .read(castVoteControllerProvider.notifier)
          .submit(groupId: widget.groupId, photoId: photoId);
    } finally {
      if (mounted) {
        setState(() => _votingPhotoId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidatesAsync = ref.watch(todayCandidatesProvider(widget.groupId));
    // 連打による二重投票を防ぐため、投票中は全タイルを操作不可にする
    // (cast_voteはUPSERTで冪等だが、どのタップがどの結果に対応するか
    // 分かりにくくなるのを避ける)。どのタイルがタップされたかは
    // _votingPhotoIdで区別し、そのタイルにのみローディング表示を出す。
    final isVoting = ref.watch(
      castVoteControllerProvider.select((state) => state.isLoading),
    );

    ref.listen<AsyncValue<void>>(castVoteControllerProvider, (previous, next) {
      // 投票失敗を握り潰さず、ユーザーにも通知する。
      if (next.hasError) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          const SnackBar(content: Text('投票に失敗しました。時間をおいて再度お試しください')),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('今日の候補')),
      body: SafeArea(
        child: candidatesAsync.when(
          data: (candidates) {
            return RefreshIndicator(
              onRefresh: () => ref.refresh(
                todayCandidatesProvider(widget.groupId).future,
              ),
              child: candidates.isEmpty
                  ? ListView(
                      // 空状態でもpull-to-refreshのジェスチャーが効くように、
                      // コンテンツがビューポートより短くても常にスクロール
                      // 可能な物理挙動にする。
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: Text('まだ候補写真がありません')),
                        ),
                      ],
                    )
                  : GridView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      itemCount: candidates.length,
                      itemBuilder: (context, index) {
                        final candidate = candidates[index];
                        return _CandidateTile(
                          candidate: candidate,
                          enabled: !isVoting,
                          isVoting: _votingPhotoId == candidate.id,
                          onTap: () => _vote(candidate.id),
                        );
                      },
                    ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) {
            // todayCandidatesProviderの取得失敗を握り潰さず記録する。
            developer.log(
              'todayCandidatesProvider failed to load',
              name: 'CandidateListScreen',
              error: error,
              stackTrace: stackTrace,
            );
            return RetryableError(
              message: '候補一覧の取得に失敗しました',
              onRetry: () =>
                  ref.invalidate(todayCandidatesProvider(widget.groupId)),
            );
          },
        ),
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({
    required this.candidate,
    required this.enabled,
    required this.isVoting,
    required this.onTap,
  });

  final CandidatePhotoRow candidate;
  final bool enabled;
  final bool isVoting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: candidate.votedByMe
                ? colorScheme.primary
                : colorScheme.outlineVariant,
            width: candidate.votedByMe ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (candidate.blurredUrl.isEmpty)
              const ColoredBox(
                color: Colors.black12,
                child: Icon(Icons.broken_image_outlined),
              )
            else
              Image.network(
                candidate.blurredUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // 画像読み込み失敗を握り潰さず記録する。
                  developer.log(
                    'failed to load candidate image for photo '
                    '${candidate.id}',
                    name: 'CandidateListScreen',
                    error: error,
                    stackTrace: stackTrace,
                  );
                  return const ColoredBox(
                    color: Colors.black12,
                    child: Icon(Icons.broken_image_outlined),
                  );
                },
              ),
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${candidate.voteCount}票',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
            if (candidate.votedByMe)
              Positioned(
                left: 4,
                top: 4,
                child: Icon(
                  Icons.check_circle,
                  color: colorScheme.primary,
                ),
              ),
            if (isVoting)
              const ColoredBox(
                color: Colors.black38,
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
