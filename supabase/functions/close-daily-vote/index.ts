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
import { createTodayPhotoNotifier, type TodayPhotoNotifier } from "./today-photo-notification.ts";

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

const noOpNotifier: TodayPhotoNotifier = () => Promise.resolve({ sentCount: 0, failedCount: 0 });

export interface CloseDailyVoteDependencies {
  notifyWinner?: TodayPhotoNotifier;
  logNotificationError?: (message: string) => void;
}

/** 通知失敗をログへ記録し、投票締め処理には伝播させない。 */
export async function notifyWinnerBestEffort(
  notifyWinner: TodayPhotoNotifier,
  groupId: string,
  winnerPhotoId: string,
  logError: (message: string) => void = console.error,
): Promise<void> {
  try {
    await notifyWinner(groupId, winnerPhotoId);
  } catch (error) {
    logError(
      `今日の1枚通知に失敗しました: ${error instanceof Error ? error.message : "unknown"}`,
    );
  }
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
  dependencies: Required<CloseDailyVoteDependencies>,
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

  await notifyWinnerBestEffort(
    dependencies.notifyWinner,
    dailyVote.group_id,
    winnerPhotoId,
    dependencies.logNotificationError,
  );
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
  dependencies: CloseDailyVoteDependencies = {},
): Promise<CloseDailyVoteResult> {
  const resolvedDependencies: Required<CloseDailyVoteDependencies> = {
    notifyWinner: dependencies.notifyWinner ?? noOpNotifier,
    logNotificationError: dependencies.logNotificationError ?? console.error,
  };

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
    await closeSingleDailyVote(
      supabase,
      dailyVote,
      winnerPhotoId,
      resolvedDependencies,
    );
    processedCount++;
  }
  return { processedCount };
}

Deno.serve(async (_req: Request) => {
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const supabase = createClient(supabaseUrl, serviceRoleKey);
  const notifyWinner = createTodayPhotoNotifier(
    supabase,
    Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "",
  );

  try {
    const result = await closeDailyVote(supabase, todayUtcDateString(), { notifyWinner });
    return jsonResponse(200, { processedCount: result.processedCount });
  } catch (error) {
    return jsonResponse(500, {
      error: "close_daily_vote_failed",
      message: error instanceof Error ? error.message : "unknown",
    });
  }
});
if (import.meta.main) {
  Deno.serve(async (req: Request) => {
    // 認可チェック: pg_cronからのリクエストのみを受け付ける(共有シークレット方式)。
    // CRON_SECRET環境変数とX-Cron-Secretヘッダーを比較し、不一致なら401を返す。
    const cronSecret = Deno.env.get("CRON_SECRET");
    const incomingSecret = req.headers.get("x-cron-secret");
    if (!cronSecret || !incomingSecret || cronSecret !== incomingSecret) {
      return jsonResponse(401, { error: "unauthorized" });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    try {
      const result = await closeDailyVote(supabase);
      return jsonResponse(200, { processedCount: result.processedCount });
    } catch (error) {
      console.error("[close-daily-vote] closeDailyVote failed:", error);
      return jsonResponse(500, {
        error: "close_daily_vote_failed",
        message: error instanceof Error ? error.message : "unknown",
      });
    }
  });
}
