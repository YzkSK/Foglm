// 他のRepositoryと同じくmocktailでの差し替えテストを可能にするため、
// 単一メソッドでもクラスとして定義する。
// ignore_for_file: one_member_abstracts

import 'package:foglm/features/candidates/domain/candidate_photo.dart';

abstract class CandidateRepository {
  Future<List<CandidatePhotoRow>> getTodayCandidates({
    required String groupId,
  });
}
