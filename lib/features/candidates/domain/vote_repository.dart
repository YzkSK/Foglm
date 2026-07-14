// 他のRepositoryと同じくmocktailでの差し替えテストを可能にするため、
// 単一メソッドでもクラスとして定義する。
// ignore_for_file: one_member_abstracts

abstract class VoteRepository {
  Future<void> castVote({required String photoId});
}
