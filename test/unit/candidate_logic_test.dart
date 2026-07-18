import 'package:flutter_test/flutter_test.dart';
import 'package:foglm/features/candidates/domain/candidate_logic.dart';
import 'package:foglm/features/candidates/domain/candidate_photo.dart';

void main() {
  group('buildCandidateRows', () {
    test('returns a zero vote count when there are no votes yet', () {
      final result = buildCandidateRows(
        photos: [(id: 'photo-1', blurredStoragePath: 'path/1.jpg')],
        votes: [],
        currentUserId: 'user-1',
        blurredUrlsByPath: {'path/1.jpg': 'https://example.com/1.jpg'},
      );

      expect(result, [
        const CandidatePhotoRow(
          id: 'photo-1',
          blurredUrl: 'https://example.com/1.jpg',
          voteCount: 0,
          votedByMe: false,
        ),
      ]);
    });

    test('aggregates vote counts per photo across multiple voters', () {
      final result = buildCandidateRows(
        photos: [
          (id: 'photo-1', blurredStoragePath: 'path/1.jpg'),
          (id: 'photo-2', blurredStoragePath: 'path/2.jpg'),
        ],
        votes: [
          (userId: 'user-1', photoId: 'photo-1'),
          (userId: 'user-2', photoId: 'photo-1'),
          (userId: 'user-3', photoId: 'photo-2'),
        ],
        currentUserId: 'user-3',
        blurredUrlsByPath: {
          'path/1.jpg': 'https://example.com/1.jpg',
          'path/2.jpg': 'https://example.com/2.jpg',
        },
      );

      expect(result, [
        const CandidatePhotoRow(
          id: 'photo-1',
          blurredUrl: 'https://example.com/1.jpg',
          voteCount: 2,
          votedByMe: false,
        ),
        const CandidatePhotoRow(
          id: 'photo-2',
          blurredUrl: 'https://example.com/2.jpg',
          voteCount: 1,
          votedByMe: true,
        ),
      ]);
    });

    test("marks votedByMe true only for the current user's own vote", () {
      final result = buildCandidateRows(
        photos: [(id: 'photo-1', blurredStoragePath: 'path/1.jpg')],
        votes: [(userId: 'other-user', photoId: 'photo-1')],
        currentUserId: 'user-1',
        blurredUrlsByPath: {'path/1.jpg': 'https://example.com/1.jpg'},
      );

      expect(result.single.votedByMe, isFalse);
    });

    test(
      'falls back to an empty blurredUrl when the signed URL is missing',
      () {
        final result = buildCandidateRows(
          photos: [(id: 'photo-1', blurredStoragePath: 'path/1.jpg')],
          votes: [],
          currentUserId: null,
          blurredUrlsByPath: const {},
        );

        expect(result.single.blurredUrl, '');
      },
    );

    test('handles a null currentUserId without matching any vote', () {
      final result = buildCandidateRows(
        photos: [(id: 'photo-1', blurredStoragePath: 'path/1.jpg')],
        votes: [(userId: 'user-1', photoId: 'photo-1')],
        currentUserId: null,
        blurredUrlsByPath: {'path/1.jpg': 'https://example.com/1.jpg'},
      );

      expect(result.single.votedByMe, isFalse);
    });

    test('preserves the input photo order', () {
      final result = buildCandidateRows(
        photos: [
          (id: 'photo-2', blurredStoragePath: 'path/2.jpg'),
          (id: 'photo-1', blurredStoragePath: 'path/1.jpg'),
        ],
        votes: [],
        currentUserId: null,
        blurredUrlsByPath: const {},
      );

      expect(result.map((row) => row.id), ['photo-2', 'photo-1']);
    });
  });
}
