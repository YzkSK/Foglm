import { assertEquals } from "jsr:@std/assert@1";
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import {
  buildDevelopmentNotificationTitle,
  createDevelopmentNotifier,
  type DevelopmentNotificationDependencies,
} from "./development-notification.ts";

function baseDependencies(
  overrides: Partial<DevelopmentNotificationDependencies> = {},
): DevelopmentNotificationDependencies {
  return {
    getTokens: () => Promise.resolve(["token-a", "token-b"]),
    getAccessToken: () => Promise.resolve("access-token"),
    sendMessage: () => Promise.resolve({ ok: true }),
    logError: () => {},
    ...overrides,
  };
}

const unusedSupabase = {} as unknown as SupabaseClient;

Deno.test("buildDevelopmentNotificationTitle uses singular wording for exactly one photo", () => {
  assertEquals(buildDevelopmentNotificationTitle(1), "1枚の写真が現像されました");
});

Deno.test("buildDevelopmentNotificationTitle uses the count for multiple photos", () => {
  assertEquals(buildDevelopmentNotificationTitle(3), "3枚の写真が現像されました");
});

Deno.test("development notifier sends the aggregated notification and summarizes partial failures", async () => {
  const sent: Array<Record<string, unknown>> = [];
  const errors: string[] = [];
  const notifier = createDevelopmentNotifier(
    unusedSupabase,
    JSON.stringify({ project_id: "firebase-project" }),
    baseDependencies({
      sendMessage: (accessToken, projectId, token, notification) => {
        sent.push({ accessToken, projectId, token, notification });
        return Promise.resolve(
          token === "token-a" ? { ok: true } : { ok: false, error: "NOT_FOUND" },
        );
      },
      logError: (message) => errors.push(message),
    }),
  );

  const result = await notifier("group1", 3);

  assertEquals(result, { sentCount: 1, failedCount: 1 });
  assertEquals(sent, [
    {
      accessToken: "access-token",
      projectId: "firebase-project",
      token: "token-a",
      notification: {
        title: "3枚の写真が現像されました",
        body: "アプリを開いて確認しよう",
      },
    },
    {
      accessToken: "access-token",
      projectId: "firebase-project",
      token: "token-b",
      notification: {
        title: "3枚の写真が現像されました",
        body: "アプリを開いて確認しよう",
      },
    },
  ]);
  assertEquals(errors.length, 1);
});

Deno.test("development notifier skips auth and FCM work when no tokens exist", async () => {
  let accessTokenCalls = 0;
  const notifier = createDevelopmentNotifier(
    unusedSupabase,
    "invalid-json-is-never-read",
    baseDependencies({
      getTokens: () => Promise.resolve([]),
      getAccessToken: () => {
        accessTokenCalls++;
        return Promise.resolve("unused");
      },
    }),
  );

  assertEquals(await notifier("group1", 2), { sentCount: 0, failedCount: 0 });
  assertEquals(accessTokenCalls, 0);
});

Deno.test("development notifier reuses one access token across groups", async () => {
  let accessTokenCalls = 0;
  const notifier = createDevelopmentNotifier(
    unusedSupabase,
    JSON.stringify({ project_id: "firebase-project" }),
    baseDependencies({
      getTokens: () => Promise.resolve(["token"]),
      getAccessToken: () => {
        accessTokenCalls++;
        return Promise.resolve("shared-token");
      },
    }),
  );

  await notifier("group1", 1);
  await notifier("group2", 2);
  assertEquals(accessTokenCalls, 1);
});
