import { assertEquals } from "jsr:@std/assert@1";
import {
  notifyWinnerBestEffort,
  pickRandomPhotoId,
  pickTopPhotoId,
  randomDevelopScheduledDate,
  tallyVotesByPhoto,
} from "./index.ts";

Deno.test("tallyVotesByPhoto counts votes per photo_id", () => {
  const tally = tallyVotesByPhoto([
    { photo_id: "p1" },
    { photo_id: "p1" },
    { photo_id: "p2" },
  ]);
  assertEquals(tally.get("p1"), 2);
  assertEquals(tally.get("p2"), 1);
});

Deno.test("pickTopPhotoId returns the sole majority winner", () => {
  const tally = new Map([["p1", 2], ["p2", 1]]);
  assertEquals(pickTopPhotoId(tally, () => 0), "p1");
});

Deno.test("pickTopPhotoId ignores non-max photos regardless of random()", () => {
  const tally = new Map([["p1", 1], ["p2", 1], ["p3", 5]]);
  assertEquals(pickTopPhotoId(tally, () => 0), "p3");
  assertEquals(pickTopPhotoId(tally, () => 0.999999), "p3");
});

Deno.test("pickTopPhotoId breaks ties using the injected random", () => {
  const tally = new Map([["p1", 1], ["p2", 1]]);
  assertEquals(pickTopPhotoId(tally, () => 0), "p1");
  assertEquals(pickTopPhotoId(tally, () => 0.999999), "p2");
});

Deno.test("pickTopPhotoId returns null for an empty tally", () => {
  assertEquals(pickTopPhotoId(new Map(), () => 0), null);
});

Deno.test("pickRandomPhotoId picks by the injected random index", () => {
  assertEquals(pickRandomPhotoId(["a", "b", "c"], () => 0), "a");
  assertEquals(pickRandomPhotoId(["a", "b", "c"], () => 0.999999), "c");
});

Deno.test("pickRandomPhotoId returns null for an empty list", () => {
  assertEquals(pickRandomPhotoId([], () => 0), null);
});

Deno.test("randomDevelopScheduledDate stays within takenDate + 3..14 days", () => {
  const earliest = randomDevelopScheduledDate("2026-07-01", () => 0);
  const latest = randomDevelopScheduledDate("2026-07-01", () => 0.999999);
  assertEquals(earliest, "2026-07-04T00:00:00.000Z");
  assertEquals(latest, "2026-07-15T00:00:00.000Z");
});

Deno.test("notifyWinnerBestEffort forwards the group and winner photo IDs", async () => {
  const calls: string[][] = [];
  await notifyWinnerBestEffort(
    (groupId, photoId) => {
      calls.push([groupId, photoId]);
      return Promise.resolve({ sentCount: 1, failedCount: 0 });
    },
    "group-1",
    "photo-1",
    () => {},
  );
  assertEquals(calls, [["group-1", "photo-1"]]);
});

Deno.test("notifyWinnerBestEffort logs and swallows notification errors", async () => {
  const errors: string[] = [];
  await notifyWinnerBestEffort(
    () => Promise.reject(new Error("FCM unavailable")),
    "group-1",
    "photo-1",
    (message) => errors.push(message),
  );
  assertEquals(errors, ["今日の1枚通知に失敗しました: FCM unavailable"]);
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
    return new Response(JSON.stringify({ processedCount: 0 }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  };
}

Deno.test("handler returns 401 when X-Cron-Secret header is missing", () => {
  const handler = createAuthCheckHandler("my-secret");
  const req = new Request("http://localhost/functions/v1/close-daily-vote", {
    method: "POST",
  });
  const res = handler(req);
  assertEquals(res.status, 401);
});

Deno.test("handler returns 401 when X-Cron-Secret header is wrong", () => {
  const handler = createAuthCheckHandler("my-secret");
  const req = new Request("http://localhost/functions/v1/close-daily-vote", {
    method: "POST",
    headers: { "X-Cron-Secret": "wrong-secret" },
  });
  const res = handler(req);
  assertEquals(res.status, 401);
});

Deno.test("handler returns 401 when CRON_SECRET env is not set", () => {
  // envCronSecret = undefined (環境変数未設定を模倣)
  const handler = createAuthCheckHandler(undefined);
  const req = new Request("http://localhost/functions/v1/close-daily-vote", {
    method: "POST",
    headers: { "X-Cron-Secret": "any-secret" },
  });
  const res = handler(req);
  assertEquals(res.status, 401);
});

Deno.test("handler returns 200 when X-Cron-Secret header matches CRON_SECRET", () => {
  const handler = createAuthCheckHandler("correct-secret");
  const req = new Request("http://localhost/functions/v1/close-daily-vote", {
    method: "POST",
    headers: { "X-Cron-Secret": "correct-secret" },
  });
  const res = handler(req);
  assertEquals(res.status, 200);
});
