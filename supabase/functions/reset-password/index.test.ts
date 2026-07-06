import { assertEquals } from "jsr:@std/assert@1";
import { isValidPassword } from "../_shared/validation.ts";

Deno.test("isValidPassword accepts 8+ chars with upper/lower/digit", () => {
  assertEquals(isValidPassword("Abcdefg1"), true);
});

Deno.test("isValidPassword rejects passwords shorter than 8 chars", () => {
  assertEquals(isValidPassword("Abc123"), false);
});

Deno.test("isValidPassword rejects passwords missing an uppercase letter", () => {
  assertEquals(isValidPassword("abcdefg1"), false);
});

Deno.test("isValidPassword rejects passwords missing a lowercase letter", () => {
  assertEquals(isValidPassword("ABCDEFG1"), false);
});

Deno.test("isValidPassword rejects passwords missing a digit", () => {
  assertEquals(isValidPassword("Abcdefgh"), false);
});
