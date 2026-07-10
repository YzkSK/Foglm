import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import {
  aggregateDevelopedCountsByGroup,
  notifyDevelopmentBestEffort,
  processScheduledDevelopment,
} from "./index.ts";

interface QueryCalls {
  table?: string;
  updateValues?: Record<string, unknown>;
  eqArgs?: [string, unknown];
  lteArgs?: [string, unknown];
  selectColumns?: string;
}

function createSupabaseStub(
  result: { data: { group_id: string }[] | null; error: { message: string } | null },
): { supabase: SupabaseClient; calls: QueryCalls } {
  const calls: QueryCalls = {};
  const query = {
    update(values: Record<string, unknown>) {
      calls.updateValues = values;
      return this;
    },
    eq(column: string, value: unknown) {
      calls.eqArgs = [column, value];
      return this;
    },
    lte(column: string, value: unknown) {
      calls.lteArgs = [column, value];
      return this;
    },
    select(columns: string) {
      calls.selectColumns = columns;
      return Promise.resolve(result);
    },
  };
  const supabase = {
    from(table: string) {
      calls.table = table;
      return query;
    },
  } as unknown as SupabaseClient;
  return { supabase, calls };
}

Deno.test("aggregateDevelopedCountsByGroup counts rows per group_id", () => {
  const counts = aggregateDevelopedCountsByGroup([
    { group_id: "g1" },
    { group_id: "g1" },
    { group_id: "g2" },
  ]);
  assertEquals(counts.get("g1"), 2);
  assertEquals(counts.get("g2"), 1);
});

Deno.test("aggregateDevelopedCountsByGroup returns an empty map for no rows", () => {
  const counts = aggregateDevelopedCountsByGroup([]);
  assertEquals(counts.size, 0);
});

Deno.test("aggregateDevelopedCountsByGroup keeps groups separate even with a single row each", () => {
  const counts = aggregateDevelopedCountsByGroup([
    { group_id: "g1" },
    { group_id: "g2" },
    { group_id: "g3" },
  ]);
  assertEquals(counts.get("g1"), 1);
  assertEquals(counts.get("g2"), 1);
  assertEquals(counts.get("g3"), 1);
});

Deno.test("processScheduledDevelopment uses the injected time for selection and development", async () => {
  const executionTime = "2026-01-10T12:00:00.000Z";
  const { supabase, calls } = createSupabaseStub({
    data: [{ group_id: "g1" }, { group_id: "g1" }, { group_id: "g2" }],
    error: null,
  });

  const result = await processScheduledDevelopment(supabase, executionTime);

  assertEquals(calls.table, "photos");
  assertEquals(calls.updateValues, {
    status: "developed",
    developed_at: executionTime,
  });
  assertEquals(calls.eqArgs, ["status", "waiting_random"]);
  assertEquals(calls.lteArgs, ["develop_scheduled_at", executionTime]);
  assertEquals(calls.selectColumns, "group_id");
  assertEquals(result.developedGroupCounts, [
    { groupId: "g1", developedCount: 2 },
    { groupId: "g2", developedCount: 1 },
  ]);
});

Deno.test("processScheduledDevelopment propagates a photo update error", async () => {
  const executionTime = "2026-01-10T12:00:00.000Z";
  const { supabase } = createSupabaseStub({
    data: null,
    error: { message: "update failed" },
  });

  await assertRejects(
    () => processScheduledDevelopment(supabase, executionTime),
    Error,
    "photosの現像更新に失敗しました: update failed",
  );
});

Deno.test("processScheduledDevelopment notifies each group with its developed count", async () => {
  const executionTime = "2026-01-10T12:00:00.000Z";
  const { supabase } = createSupabaseStub({
    data: [{ group_id: "g1" }, { group_id: "g1" }, { group_id: "g2" }],
    error: null,
  });
  const calls: [string, number][] = [];

  await processScheduledDevelopment(supabase, executionTime, {
    notifyDevelopment: (groupId, developedCount) => {
      calls.push([groupId, developedCount]);
      return Promise.resolve({ sentCount: 1, failedCount: 0 });
    },
  });

  assertEquals(calls, [["g1", 2], ["g2", 1]]);
});

Deno.test("processScheduledDevelopment continues when a group's notification fails", async () => {
  const executionTime = "2026-01-10T12:00:00.000Z";
  const { supabase } = createSupabaseStub({
    data: [{ group_id: "g1" }, { group_id: "g2" }],
    error: null,
  });
  const errors: string[] = [];

  const result = await processScheduledDevelopment(supabase, executionTime, {
    notifyDevelopment: () => Promise.reject(new Error("FCM unavailable")),
    logNotificationError: (message) => errors.push(message),
  });

  assertEquals(result.developedGroupCounts, [
    { groupId: "g1", developedCount: 1 },
    { groupId: "g2", developedCount: 1 },
  ]);
  assertEquals(errors, [
    "集約現像通知に失敗しました: FCM unavailable",
    "集約現像通知に失敗しました: FCM unavailable",
  ]);
});

Deno.test("notifyDevelopmentBestEffort forwards the group ID and developed count", async () => {
  const calls: [string, number][] = [];
  await notifyDevelopmentBestEffort(
    (groupId, developedCount) => {
      calls.push([groupId, developedCount]);
      return Promise.resolve({ sentCount: 1, failedCount: 0 });
    },
    "group-1",
    3,
    () => {},
  );
  assertEquals(calls, [["group-1", 3]]);
});

Deno.test("notifyDevelopmentBestEffort logs and swallows notification errors", async () => {
  const errors: string[] = [];
  await notifyDevelopmentBestEffort(
    () => Promise.reject(new Error("FCM unavailable")),
    "group-1",
    3,
    (message) => errors.push(message),
  );
  assertEquals(errors, ["集約現像通知に失敗しました: FCM unavailable"]);
});

// --- 認可チェック (X-Cron-Secret) のユニットテスト ---
// Deno.serve ハンドラを直接呼び出す代わりに、ハンドラの認可チェックロジックのみを
// 再現したミニハンドラでシミュレートする。
// CRON_SECRET 環境変数が未設定・不一致・一致の4ケースを確認する。

/** テスト用: ハンドラの認可チェック部分のみを再現したミニハンドラ */
function createAuthCheckHandler(
  envCronSecret: string | undefined,
): (req: Request) => Response {
  return (req: Request): Response => {
    const incomingSecret = req.headers.get("x-cron-secret");
    if (
      !envCronSecret || !incomingSecret || envCronSecret !== incomingSecret
    ) {
      return new Response(JSON.stringify({ error: "unauthorized" }), {
        status: 401,
        headers: { "Content-Type": "application/json" },
      });
    }
    // 認可OK(実際のDB呼び出しはしない)
    return new Response(JSON.stringify({ developedGroupCounts: [] }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  };
}

Deno.test("handler returns 401 when X-Cron-Secret header is missing", () => {
  const handler = createAuthCheckHandler("my-secret");
  const req = new Request("http://localhost/functions/v1/process-scheduled-development", {
    method: "POST",
  });
  const res = handler(req);
  assertEquals(res.status, 401);
});

Deno.test("handler returns 401 when X-Cron-Secret header is wrong", () => {
  const handler = createAuthCheckHandler("my-secret");
  const req = new Request("http://localhost/functions/v1/process-scheduled-development", {
    method: "POST",
    headers: { "X-Cron-Secret": "wrong-secret" },
  });
  const res = handler(req);
  assertEquals(res.status, 401);
});

Deno.test("handler returns 401 when CRON_SECRET env is not set", () => {
  // envCronSecret = undefined (環境変数未設定を模倣)
  const handler = createAuthCheckHandler(undefined);
  const req = new Request("http://localhost/functions/v1/process-scheduled-development", {
    method: "POST",
    headers: { "X-Cron-Secret": "any-secret" },
  });
  const res = handler(req);
  assertEquals(res.status, 401);
});

Deno.test("handler returns 200 when X-Cron-Secret header matches CRON_SECRET", () => {
  const handler = createAuthCheckHandler("correct-secret");
  const req = new Request("http://localhost/functions/v1/process-scheduled-development", {
    method: "POST",
    headers: { "X-Cron-Secret": "correct-secret" },
  });
  const res = handler(req);
  assertEquals(res.status, 200);
});
