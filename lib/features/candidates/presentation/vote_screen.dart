import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/candidates/application/cast_vote_controller.dart';
import 'package:foglm/features/candidates/data/today_candidates_provider.dart';
import 'package:foglm/features/candidates/domain/candidate_photo.dart';

/// `/candidates/vote`ルートの`extra`として渡す引数。
class VoteArgs {
  const VoteArgs({required this.groupId, required this.photoId});

  final String groupId;
  final String photoId;
}

/// 投票画面(S08)。
///
/// 候補写真をボヤけたまま拡大表示し、その1枚に投票する(仕様書 3.5 /
/// 4.1 S08参照)。投票は何度でも投票し直せる(最後の一票のみ有効)ため、
/// 既に投票済みの写真でも再度投票できる。
class VoteScreen extends ConsumerWidget {
  const VoteScreen({required this.groupId, required this.photoId, super.key});

  final String groupId;
  final String photoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidatesAsync = ref.watch(todayCandidatesProvider(groupId));

    return Scaffold(
      appBar: AppBar(title: const Text('投票')),
      body: SafeArea(
        child: candidatesAsync.when(
          data: (candidates) {
            final candidate = candidates
                .where((c) => c.id == photoId)
                .firstOrNull;
            if (candidate == null) {
              // 投票中に候補一覧が更新され、対象の写真が候補から
              // 外れた場合(通常は起こらない想定)。
              return const Center(child: Text('この写真は表示できません'));
            }
            return _VoteBody(groupId: groupId, candidate: candidate);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) {
            // todayCandidatesProviderの取得失敗を握り潰さず記録する。
            developer.log(
              'todayCandidatesProvider failed to load',
              name: 'VoteScreen',
              error: error,
              stackTrace: stackTrace,
            );
            return const Center(child: Text('候補一覧の取得に失敗しました'));
          },
        ),
      ),
    );
  }
}

class _VoteBody extends ConsumerWidget {
  const _VoteBody({required this.groupId, required this.candidate});

  final String groupId;
  final CandidatePhotoRow candidate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (candidate.blurredUrl.isEmpty)
                const ColoredBox(
                  color: Colors.black12,
                  child: Icon(Icons.broken_image_outlined, size: 64),
                )
              else
                Image.network(
                  candidate.blurredUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    // 画像読み込み失敗を握り潰さず記録する。
                    developer.log(
                      'failed to load candidate image for photo '
                      '${candidate.id}',
                      name: 'VoteScreen',
                      error: error,
                      stackTrace: stackTrace,
                    );
                    return const ColoredBox(
                      color: Colors.black12,
                      child: Icon(Icons.broken_image_outlined, size: 64),
                    );
                  },
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                candidate.votedByMe
                    ? '${candidate.voteCount}票(投票済み)'
                    : '${candidate.voteCount}票',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: isVoting
                    ? null
                    : () => ref
                          .read(castVoteControllerProvider.notifier)
                          .submit(groupId: groupId, photoId: candidate.id),
                child: isVoting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(candidate.votedByMe ? 'この写真に投票し直す' : 'この写真に投票する'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
