import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/features/candidates/data/today_candidates_provider.dart';
import 'package:foglm/features/candidates/domain/candidate_photo.dart';
import 'package:foglm/features/candidates/presentation/vote_screen.dart';
import 'package:go_router/go_router.dart';

/// `/candidates`ルートの`extra`として渡す引数。
class CandidateListArgs {
  const CandidateListArgs({required this.groupId});

  final String groupId;
}

/// 今日の候補一覧画面(S07)。
///
/// その日撮影された写真をボヤけた状態で一覧表示し、現在の得票状況を
/// 確認できる(仕様書 3.5 / 4.1 S07参照)。候補写真をタップすると
/// 投票画面(S08、#23)へ遷移し、そこで投票する。
class CandidateListScreen extends ConsumerWidget {
  const CandidateListScreen({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidatesAsync = ref.watch(todayCandidatesProvider(groupId));

    return Scaffold(
      appBar: AppBar(title: const Text('今日の候補')),
      body: SafeArea(
        child: candidatesAsync.when(
          data: (candidates) {
            if (candidates.isEmpty) {
              return const Center(child: Text('まだ候補写真がありません'));
            }
            return GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: candidates.length,
              itemBuilder: (context, index) {
                final candidate = candidates[index];
                return _CandidateTile(
                  candidate: candidate,
                  onTap: () => context.push(
                    '/candidates/vote',
                    extra: VoteArgs(groupId: groupId, photoId: candidate.id),
                  ),
                );
              },
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
            return const Center(child: Text('候補一覧の取得に失敗しました'));
          },
        ),
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({required this.candidate, required this.onTap});

  final CandidatePhotoRow candidate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
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
          ],
        ),
      ),
    );
  }
}
