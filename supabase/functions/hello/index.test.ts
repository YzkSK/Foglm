import { assertEquals } from "jsr:@std/assert@1";
import { buildGreeting } from "./index.ts";

Deno.test("buildGreeting returns a personalized greeting", () => {
  assertEquals(buildGreeting("Foglm"), "Hello, Foglm!");
});

Deno.test("buildGreeting falls back to 'world' for empty input", () => {
  assertEquals(buildGreeting("   "), "Hello, world!");
});
