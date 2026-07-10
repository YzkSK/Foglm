import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { jsonResponse } from "../_shared/http.ts";
import { createDevelopmentNotifier, type DevelopmentNotifier } from "./development-notification.ts";

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

const noOpNotifier: DevelopmentNotifier = () => Promise.resolve({ sentCount: 0, failedCount: 0 });

export interface ProcessScheduledDevelopmentDependencies {
  notifyDevelopment?: DevelopmentNotifier;
  logNotificationError?: (message: string) => void;
}

/** 通知失敗をログへ記録し、現像更新処理には伝播させない。 */
export async function notifyDevelopmentBestEffort(
  notifyDevelopment: DevelopmentNotifier,
  groupId: string,
  developedCount: number,
  logError: (message: string) => void = console.error,
): Promise<void> {
  try {
    await notifyDevelopment(groupId, developedCount);
  } catch (error) {
    logError(
      `集約現像通知に失敗しました: ${error instanceof Error ? error.message : "unknown"}`,
    );
  }
}

/**
 * status='waiting_random'かつdevelop_scheduled_at <= nowの写真を全件developedへ更新し、
 * group_id単位で件数を集計する(仕様書3.6/6.5参照)。
 * nowを省略した場合はEdge Function側の現在時刻を使う。テストからは固定日時を注入できる
 * (docs/testing-policy.mdの「締切集計は時刻を引数として注入可能にする」方針に従う)。
 */
export async function processScheduledDevelopment(
  supabase: SupabaseClient,
  now: string = new Date().toISOString(),
  dependencies: ProcessScheduledDevelopmentDependencies = {},
): Promise<ProcessScheduledDevelopmentResult> {
  const resolvedDependencies: Required<ProcessScheduledDevelopmentDependencies> = {
    notifyDevelopment: dependencies.notifyDevelopment ?? noOpNotifier,
    logNotificationError: dependencies.logNotificationError ?? console.error,
  };

  const { data: updatedPhotos, error: updateError } = await supabase
    .from("photos")
    .update({ status: "developed", developed_at: now })
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
    await notifyDevelopmentBestEffort(
      resolvedDependencies.notifyDevelopment,
      groupId,
      developedCount,
      resolvedDependencies.logNotificationError,
    );
    developedGroupCounts.push({ groupId, developedCount });
  }

  return { developedGroupCounts };
}

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
    const notifyDevelopment = createDevelopmentNotifier(
      supabase,
      Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "",
    );

    try {
      const result = await processScheduledDevelopment(supabase, undefined, { notifyDevelopment });
      return jsonResponse(200, { developedGroupCounts: result.developedGroupCounts });
    } catch (error) {
      console.error("[process-scheduled-development] processScheduledDevelopment failed:", error);
      return jsonResponse(500, {
        error: "process_scheduled_development_failed",
        message: error instanceof Error ? error.message : "unknown",
      });
    }
  });
}
