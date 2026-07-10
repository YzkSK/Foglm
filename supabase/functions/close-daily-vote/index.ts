interface VoteEntryRow {
  photo_id: string;
}

/** UTC基準の今日の日付(YYYY-MM-DD)を返す。daily_votes.vote_dateの締切判定に使用する。 */
export function todayUtcDateString(): string {
  return new Date().toISOString().slice(0, 10);
}

/** vote_entriesをphoto_idごとに集計する。 */
export function tallyVotesByPhoto(entries: VoteEntryRow[]): Map<string, number> {
  const tally = new Map<string, number>();
  for (const entry of entries) {
    tally.set(entry.photo_id, (tally.get(entry.photo_id) ?? 0) + 1);
  }
  return tally;
}

/** 最多得票の写真IDを返す。同数の場合はrandomでタイブレークする。tallyが空ならnull。 */
export function pickTopPhotoId(
  tally: Map<string, number>,
  random: () => number = Math.random,
): string | null {
  if (tally.size === 0) return null;
  const maxVotes = Math.max(...tally.values());
  const topPhotoIds = [...tally.entries()]
    .filter(([, count]) => count === maxVotes)
    .map(([photoId]) => photoId);
  return topPhotoIds[Math.floor(random() * topPhotoIds.length)];
}

/** photoIdsからrandomで1件選ぶ。空配列ならnull。 */
export function pickRandomPhotoId(
  photoIds: string[],
  random: () => number = Math.random,
): string | null {
  if (photoIds.length === 0) return null;
  return photoIds[Math.floor(random() * photoIds.length)];
}

// 落選写真の現像予定日は撮影日+3〜14日のランダムな日にする(仕様書3.6参照)。
const MIN_DEVELOP_DELAY_DAYS = 3;
const MAX_DEVELOP_DELAY_DAYS = 14;

/** takenDate(YYYY-MM-DD) + 3〜14日のランダムな現像予定日時(ISO文字列)を返す。 */
export function randomDevelopScheduledDate(
  takenDate: string,
  random: () => number = Math.random,
): string {
  const rangeDays = MAX_DEVELOP_DELAY_DAYS - MIN_DEVELOP_DELAY_DAYS + 1;
  const days = MIN_DEVELOP_DELAY_DAYS + Math.floor(random() * rangeDays);
  const scheduled = new Date(`${takenDate}T00:00:00.000Z`);
  scheduled.setUTCDate(scheduled.getUTCDate() + days);
  return scheduled.toISOString();
}
