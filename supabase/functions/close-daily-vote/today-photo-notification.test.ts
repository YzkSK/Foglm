import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import {
  createTodayPhotoNotifier,
  type TodayPhotoNotificationDependencies,
} from "./today-photo-notification.ts";

function fakeSupabase(
  rows: Record<string, string>,
  errorMessage?: string,
): SupabaseClient {
  return {
    from: () => ({
      select: () => ({
        eq: (_column: string, photoId: string) => ({
          single: () =>
            Promise.resolve(
              errorMessage
                ? { data: null, error: { message: errorMessage } }
                : { data: { original_storage_path: rows[photoId] }, error: null },
            ),
        }),
      }),
    }),
  } as unknown as SupabaseClient;
}

function baseDependencies(
  overrides: Partial<TodayPhotoNotificationDependencies> = {},
): TodayPhotoNotificationDependencies {
  return {
    getTokens: () => Promise.resolve(["token-a", "token-b"]),
    createThumbnailUrl: (_client, path) => Promise.resolve(`signed:${path}`),
    getAccessToken: () => Promise.resolve("access-token"),
    sendMessage: () => Promise.resolve({ ok: true }),
    logError: () => {},
    ...overrides,
  };
}

Deno.test("today photo notifier sends the fixed notification and summarizes partial failures", async () => {
  const sent: Array<Record<string, unknown>> = [];
  const errors: string[] = [];
  const notifier = createTodayPhotoNotifier(
    fakeSupabase({ photo1: "group/photo1.jpg" }),
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

  const result = await notifier("group1", "photo1");

  assertEquals(result, { sentCount: 1, failedCount: 1 });
  assertEquals(sent, [
    {
      accessToken: "access-token",
      projectId: "firebase-project",
      token: "token-a",
      notification: {
        title: "今日の1枚が現像されました",
        body: "アプリを開いて確認しよう",
        imageUrl: "signed:group/photo1.jpg",
      },
    },
    {
      accessToken: "access-token",
      projectId: "firebase-project",
      token: "token-b",
      notification: {
        title: "今日の1枚が現像されました",
        body: "アプリを開いて確認しよう",
        imageUrl: "signed:group/photo1.jpg",
      },
    },
  ]);
  assertEquals(errors.length, 1);
});

Deno.test("today photo notifier skips photo, auth, and FCM work when no tokens exist", async () => {
  let thumbnailCalls = 0;
  let accessTokenCalls = 0;
  const notifier = createTodayPhotoNotifier(
    fakeSupabase({}),
    "invalid-json-is-never-read",
    baseDependencies({
      getTokens: () => Promise.resolve([]),
      createThumbnailUrl: () => {
        thumbnailCalls++;
        return Promise.resolve("unused");
      },
      getAccessToken: () => {
        accessTokenCalls++;
        return Promise.resolve("unused");
      },
    }),
  );

  assertEquals(await notifier("group1", "photo1"), { sentCount: 0, failedCount: 0 });
  assertEquals(thumbnailCalls, 0);
  assertEquals(accessTokenCalls, 0);
});

Deno.test("today photo notifier reuses one access token across groups", async () => {
  let accessTokenCalls = 0;
  const notifier = createTodayPhotoNotifier(
    fakeSupabase({ photo1: "one.jpg", photo2: "two.jpg" }),
    JSON.stringify({ project_id: "firebase-project" }),
    baseDependencies({
      getTokens: () => Promise.resolve(["token"]),
      getAccessToken: () => {
        accessTokenCalls++;
        return Promise.resolve("shared-token");
      },
    }),
  );

  await notifier("group1", "photo1");
  await notifier("group2", "photo2");
  assertEquals(accessTokenCalls, 1);
});

Deno.test("today photo notifier throws when the winner photo cannot be loaded", async () => {
  const notifier = createTodayPhotoNotifier(
    fakeSupabase({}, "missing"),
    JSON.stringify({ project_id: "firebase-project" }),
    baseDependencies({ getTokens: () => Promise.resolve(["token"]) }),
  );
  await assertRejects(() => notifier("group1", "photo1"), Error, "当選写真");
});
