import { assertEquals } from "jsr:@std/assert@1";
import { resolveStorageTarget } from "./logic.ts";

Deno.test("resolveStorageTarget returns originals bucket when developed", () => {
  assertEquals(
    resolveStorageTarget("developed", "orig/path.jpg", "blur/path.jpg"),
    { bucket: "photo-originals", path: "orig/path.jpg" },
  );
});

Deno.test("resolveStorageTarget returns blurred bucket for pending_vote", () => {
  assertEquals(
    resolveStorageTarget("pending_vote", "orig/path.jpg", "blur/path.jpg"),
    { bucket: "photo-blurred", path: "blur/path.jpg" },
  );
});

Deno.test("resolveStorageTarget returns blurred bucket for selected_today", () => {
  assertEquals(
    resolveStorageTarget("selected_today", "orig/path.jpg", "blur/path.jpg"),
    { bucket: "photo-blurred", path: "blur/path.jpg" },
  );
});

Deno.test("resolveStorageTarget returns blurred bucket for waiting_random", () => {
  assertEquals(
    resolveStorageTarget("waiting_random", "orig/path.jpg", "blur/path.jpg"),
    { bucket: "photo-blurred", path: "blur/path.jpg" },
  );
});

Deno.test("resolveStorageTarget returns blurred bucket for unknown status", () => {
  assertEquals(
    resolveStorageTarget("some_future_status", "orig/path.jpg", "blur/path.jpg"),
    { bucket: "photo-blurred", path: "blur/path.jpg" },
  );
});

import { CACHE_REFRESH_BUFFER_SECONDS, isCachedUrlUsable, remainingSeconds } from "./logic.ts";

Deno.test("remainingSeconds returns the whole-second difference", () => {
  const now = new Date("2026-07-11T00:00:00.000Z");
  const expiresAt = new Date("2026-07-11T00:05:00.000Z");
  assertEquals(remainingSeconds(expiresAt, now), 300);
});

Deno.test("remainingSeconds floors to zero once expired", () => {
  const now = new Date("2026-07-11T00:05:01.000Z");
  const expiresAt = new Date("2026-07-11T00:05:00.000Z");
  assertEquals(remainingSeconds(expiresAt, now), 0);
});

Deno.test("isCachedUrlUsable is true when remaining time exceeds the buffer", () => {
  const now = new Date("2026-07-11T00:00:00.000Z");
  const expiresAt = new Date(now.getTime() + (CACHE_REFRESH_BUFFER_SECONDS + 1) * 1000);
  assertEquals(isCachedUrlUsable(expiresAt, now), true);
});

Deno.test("isCachedUrlUsable is false exactly at the buffer boundary", () => {
  const now = new Date("2026-07-11T00:00:00.000Z");
  const expiresAt = new Date(now.getTime() + CACHE_REFRESH_BUFFER_SECONDS * 1000);
  assertEquals(isCachedUrlUsable(expiresAt, now), false);
});

Deno.test("isCachedUrlUsable is false when already expired", () => {
  const now = new Date("2026-07-11T00:00:00.000Z");
  const expiresAt = new Date(now.getTime() - 1000);
  assertEquals(isCachedUrlUsable(expiresAt, now), false);
});
