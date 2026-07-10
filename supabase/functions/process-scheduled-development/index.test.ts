import { assertEquals } from "jsr:@std/assert@1";
import { aggregateDevelopedCountsByGroup } from "./index.ts";

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
