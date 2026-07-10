import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { jsonResponse } from "../_shared/http.ts";

interface GroupIdRow {
  group_id: string;
}

/** 更新済みの写真行をgroup_idごとに集計する(通知集約に使う)。 */
export function aggregateDevelopedCountsByGroup(rows: GroupIdRow[]): Map<string, number> {
  const counts = new Map<string, number>();
  for (const row of rows) {
    counts.set(row.group_id, (counts.get(row.group_id) ?? 0) + 1);
  }
  return counts;
}

interface DevelopedPhotoRow {
  group_id: string;
}

export interface DevelopedGroupCount {
  groupId: string;
  developedCount: number;
}

export interface ProcessScheduledDevelopmentResult {
  developedGroupCounts: DevelopedGroupCount[];
}

/** group単位の現像件数集計後に呼び出す通知フックポイント。集約現像通知の送信は別issueで対応するため未実装。 */
function notifyDevelopment(_groupId: string, _developedCount: number): void {
  // 集約現像通知の送信は別issueで対応する(issue #176のスコープ外)。
}

/**
 * status='waiting_random'かつdevelop_scheduled_at <= nowの写真を全件developedへ更新し、
 * group_id単位で件数を集計する(仕様書3.6/6.5参照)。
 * nowを省略した場合はDB側の現在時刻(now())を使う。テストからは固定日時を注入できる
 * (docs/testing-policy.mdの「締切集計は時刻を引数として注入可能にする」方針に従う)。
 */
export async function processScheduledDevelopment(
  supabase: SupabaseClient,
  now: string = new Date().toISOString(),
): Promise<ProcessScheduledDevelopmentResult> {
  const { data: updatedPhotos, error: updateError } = await supabase
    .from("photos")
    .update({ status: "developed", developed_at: new Date().toISOString() })
    .eq("status", "waiting_random")
    .lte("develop_scheduled_at", now)
    .select("group_id");
  if (updateError) {
    throw new Error(`photosの現像更新に失敗しました: ${updateError.message}`);
  }

  const groupCounts = aggregateDevelopedCountsByGroup(
    (updatedPhotos ?? []) as DevelopedPhotoRow[],
  );

  const developedGroupCounts: DevelopedGroupCount[] = [];
  for (const [groupId, developedCount] of groupCounts) {
    notifyDevelopment(groupId, developedCount);
    developedGroupCounts.push({ groupId, developedCount });
  }

  return { developedGroupCounts };
}

Deno.serve(async (_req: Request) => {
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const supabase = createClient(supabaseUrl, serviceRoleKey);

  try {
    const result = await processScheduledDevelopment(supabase);
    return jsonResponse(200, { developedGroupCounts: result.developedGroupCounts });
  } catch (error) {
    return jsonResponse(500, {
      error: "process_scheduled_development_failed",
      message: error instanceof Error ? error.message : "unknown",
    });
  }
});
