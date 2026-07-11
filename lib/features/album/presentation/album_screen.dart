import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:foglm/core/utils/date_formatting.dart';
import 'package:foglm/features/album/data/album_provider.dart';
import 'package:foglm/features/album/data/photo_url_repository.dart';
import 'package:foglm/features/album/domain/album_photo.dart';

/// `/album`ルートの`extra`として渡す引数。
class AlbumArgs {
  const AlbumArgs({required this.groupId});

  final String groupId;
}

/// 撮影日ごとにグループ化した現像済み写真一覧。`albumProvider`は
/// 撮影日時の新しい順で返すため、挿入順を保つ`LinkedHashMap`相当の
/// 順序を維持できるようMap生成時の走査順をそのまま使う。
Map<DateTime, List<AlbumPhotoRow>> _groupByTakenDate(
  List<AlbumPhotoRow> photos,
) {
  final grouped = <DateTime, List<AlbumPhotoRow>>{};
  for (final photo in photos) {
    grouped.putIfAbsent(photo.takenDate, () => []).add(photo);
  }
  return grouped;
}

/// アルバム画面(S09)。
///
/// グループの現像済み写真を撮影日の新しい順に一覧表示する(仕様書 3.7 /
/// 4.1 S09参照)。イベントグループのクローズ後・固定グループのアーカイブ後も、
/// 現役メンバーである限りRLS経由でこの画面から引き続き閲覧できる
/// (`get_album`側の仕様、`album_repository.dart`参照)。写真の拡大表示・
/// リアクション・コメント(S10)は別issueで対応する。
class AlbumScreen extends ConsumerWidget {
  const AlbumScreen({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumAsync = ref.watch(albumProvider(groupId));

    return Scaffold(
      appBar: AppBar(title: const Text('アルバム')),
      body: SafeArea(
        child: albumAsync.when(
          data: (photos) {
            if (photos.isEmpty) {
              return const Center(child: Text('まだ現像済みの写真がありません'));
            }
            final grouped = _groupByTakenDate(photos).entries.toList();
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: grouped.length,
              itemBuilder: (context, index) {
                final entry = grouped[index];
                return _AlbumDateSection(date: entry.key, photos: entry.value);
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) {
            // albumProviderの取得失敗を握り潰さず記録する。
            developer.log(
              'albumProvider failed to load',
              name: 'AlbumScreen',
              error: error,
              stackTrace: stackTrace,
            );
            return const Center(child: Text('アルバムの取得に失敗しました'));
          },
        ),
      ),
    );
  }
}

class _AlbumDateSection extends StatelessWidget {
  const _AlbumDateSection({required this.date, required this.photos});

  final DateTime date;
  final List<AlbumPhotoRow> photos;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            formatDateOnly(date, separator: '/'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: photos.length,
          itemBuilder: (context, index) => _AlbumPhotoTile(
            photo: photos[index],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _AlbumPhotoTile extends ConsumerWidget {
  const _AlbumPhotoTile({required this.photo});

  final AlbumPhotoRow photo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photoUrlAsync = ref.watch(photoUrlProvider(photo.id));

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: photoUrlAsync.when(
        data: (url) => url.isEmpty
            ? const ColoredBox(
                color: Colors.black12,
                child: Icon(Icons.broken_image_outlined),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // 画像読み込み失敗を握り潰さず記録する。
                  developer.log(
                    'failed to load album image for photo ${photo.id}',
                    name: 'AlbumScreen',
                    error: error,
                    stackTrace: stackTrace,
                  );
                  return const ColoredBox(
                    color: Colors.black12,
                    child: Icon(Icons.broken_image_outlined),
                  );
                },
              ),
        loading: () => const ColoredBox(
          color: Colors.black12,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) {
          // photoUrlProviderの取得失敗を握り潰さず記録する。
          developer.log(
            'photoUrlProvider failed to load for photo ${photo.id}',
            name: 'AlbumScreen',
            error: error,
            stackTrace: stackTrace,
          );
          return const ColoredBox(
            color: Colors.black12,
            child: Icon(Icons.broken_image_outlined),
          );
        },
      ),
    );
  }
}
