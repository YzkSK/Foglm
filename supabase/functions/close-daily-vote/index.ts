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

import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { jsonResponse } from "../_shared/http.ts";

interface DailyVoteRow {
  id: string;
  group_id: string;
  vote_date: string;
}

interface PhotoIdRow {
  id: string;
}

interface LosingPhotoRow {
  id: string;
  taken_date: string;
}

export interface CloseDailyVoteResult {
  processedCount: number;
}

/** 当選写真確定後に呼び出す通知フックポイント。現像完了通知の送信は別issueで対応するため未実装。 */
function notifyWinner(_winnerPhotoId: string): void {
  // 現像完了通知(今日の1枚)の送信は別issueで対応する(issue #175のスコープ外)。
}

async function selectWinnerPhotoId(
  supabase: SupabaseClient,
  dailyVote: DailyVoteRow,
): Promise<string | null> {
  const { data: entries, error: entriesError } = await supabase
    .from("vote_entries")
    .select("photo_id")
    .eq("daily_vote_id", dailyVote.id);
  if (entriesError) {
    throw new Error(`vote_entriesの取得に失敗しました: ${entriesError.message}`);
  }

  const votedWinner = pickTopPhotoId(tallyVotesByPhoto((entries ?? []) as { photo_id: string }[]));
  if (votedWinner) return votedWinner;

  const { data: candidatePhotos, error: photosError } = await supabase
    .from("photos")
    .select("id")
    .eq("group_id", dailyVote.group_id)
    .eq("taken_date", dailyVote.vote_date)
    .eq("status", "pending_vote");
  if (photosError) {
    throw new Error(`photosの取得に失敗しました: ${photosError.message}`);
  }

  const candidateIds = ((candidatePhotos ?? []) as PhotoIdRow[]).map((photo) => photo.id);
  return pickRandomPhotoId(candidateIds);
}

async function closeSingleDailyVote(
  supabase: SupabaseClient,
  dailyVote: DailyVoteRow,
  winnerPhotoId: string,
): Promise<void> {
  const { error: winnerUpdateError } = await supabase
    .from("photos")
    .update({ status: "developed", developed_at: new Date().toISOString() })
    .eq("id", winnerPhotoId);
  if (winnerUpdateError) {
    throw new Error(`当選写真の更新に失敗しました: ${winnerUpdateError.message}`);
  }

  const { data: losingPhotos, error: losingPhotosError } = await supabase
    .from("photos")
    .select("id, taken_date")
    .eq("group_id", dailyVote.group_id)
    .eq("taken_date", dailyVote.vote_date)
    .eq("status", "pending_vote")
    .neq("id", winnerPhotoId);
  if (losingPhotosError) {
    throw new Error(`落選写真の取得に失敗しました: ${losingPhotosError.message}`);
  }

  for (const photo of (losingPhotos ?? []) as LosingPhotoRow[]) {
    const { error: loserUpdateError } = await supabase
      .from("photos")
      .update({
        status: "waiting_random",
        develop_scheduled_at: randomDevelopScheduledDate(photo.taken_date),
      })
      .eq("id", photo.id);
    if (loserUpdateError) {
      throw new Error(`落選写真の更新に失敗しました: ${loserUpdateError.message}`);
    }
  }

  const { error: closeError } = await supabase
    .from("daily_votes")
    .update({
      winner_photo_id: winnerPhotoId,
      status: "closed",
      closed_at: new Date().toISOString(),
    })
    .eq("id", dailyVote.id);
  if (closeError) {
    throw new Error(`daily_votesのクローズに失敗しました: ${closeError.message}`);
  }

  notifyWinner(winnerPhotoId);
}

/**
 * status=openかつvote_date <= todayのdaily_votesを全件処理し、当選写真の即時現像・
 * 落選写真のランダム現像予約・daily_votesのクローズを行う(仕様書3.5/3.6/6.4参照)。
 * todayを省略した場合はUTC基準の現在日付を使う。テストからは固定日付を注入できる
 * (docs/testing-policy.mdの「締切集計は時刻を引数として注入可能にする」方針に従う)。
 */
export async function closeDailyVote(
  supabase: SupabaseClient,
  today: string = todayUtcDateString(),
): Promise<CloseDailyVoteResult> {
  const { data: openVotes, error: openVotesError } = await supabase
    .from("daily_votes")
    .select("id, group_id, vote_date")
    .eq("status", "open")
    .lte("vote_date", today);
  if (openVotesError) {
    throw new Error(`daily_votesの取得に失敗しました: ${openVotesError.message}`);
  }

  let processedCount = 0;
  for (const dailyVote of (openVotes ?? []) as DailyVoteRow[]) {
    const winnerPhotoId = await selectWinnerPhotoId(supabase, dailyVote);
    if (!winnerPhotoId) continue;
    await closeSingleDailyVote(supabase, dailyVote, winnerPhotoId);
    processedCount++;
  }
  return { processedCount };
}

Deno.serve(async (_req: Request) => {
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const supabase = createClient(supabaseUrl, serviceRoleKey);

  try {
    const result = await closeDailyVote(supabase);
    return jsonResponse(200, { processedCount: result.processedCount });
  } catch (error) {
    return jsonResponse(500, {
      error: "close_daily_vote_failed",
      message: error instanceof Error ? error.message : "unknown",
    });
  }
});
