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
