import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { aggregateDevelopedCountsByGroup, processScheduledDevelopment } from "./index.ts";

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
