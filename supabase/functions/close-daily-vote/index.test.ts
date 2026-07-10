import { assertEquals } from "jsr:@std/assert@1";
import {
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
