// 他のRepositoryと同じくmocktailでの差し替えテストを可能にするため、
// 単一メソッドでもクラスとして定義する。
// ignore_for_file: one_member_abstracts

abstract class RemainingShotsRepository {
  /// 指定したグループの当日の残り撮影可能枚数を購読する。
  ///
  /// 購読開始時に`get_today_shots_remaining`で現在値を取得し、以降は
  /// `photos`テーブルへのINSERT(Supabase Realtime)を検知するたびに
  /// 再取得して流す。他メンバーの撮影による残数減少も即座に反映する
  /// (仕様書 5.2.3参照)。
  Stream<int> watchTodayShotsRemaining({required String groupId});
}
