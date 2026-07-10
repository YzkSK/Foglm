import { assertEquals } from "jsr:@std/assert@1";
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { getActiveGroupMemberFcmTokens } from "./notification-targets.ts";

function fakeSupabaseClient(
  result: { data: unknown; error: { message: string } | null },
  capture: { groupId?: string },
): SupabaseClient {
  const builder = {
    select: (_columns: string) => builder,
    eq: (column: string, value: string) => {
      if (column === "group_id") capture.groupId = value;
      return builder;
    },
    is: (_column: string, _value: null) => builder,
    not: (_column: string, _operator: string, _value: null) => Promise.resolve(result),
  };
  return {
    from: (_table: string) => builder,
  } as unknown as SupabaseClient;
}

Deno.test("getActiveGroupMemberFcmTokens returns tokens for active members, filtering out nulls", async () => {
  const capture: { groupId?: string } = {};
  const client = fakeSupabaseClient(
    {
      data: [
        { users: { fcm_token: "token-a" } },
        { users: { fcm_token: null } },
        { users: { fcm_token: "token-b" } },
      ],
      error: null,
    },
    capture,
  );

  const tokens = await getActiveGroupMemberFcmTokens(client, "group-1");

  assertEquals(tokens, ["token-a", "token-b"]);
  assertEquals(capture.groupId, "group-1");
});

Deno.test("getActiveGroupMemberFcmTokens throws when the query fails", async () => {
  const client = fakeSupabaseClient({ data: null, error: { message: "boom" } }, {});

  let threw = false;
  try {
    await getActiveGroupMemberFcmTokens(client, "group-1");
  } catch {
    threw = true;
  }
  assertEquals(threw, true);
});
