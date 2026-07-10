import { assertEquals } from "jsr:@std/assert@1";
import { isValidEmail, isValidPassword, isValidUuid } from "./validation.ts";

Deno.test("isValidEmail accepts a well-formed address", () => {
  assertEquals(isValidEmail("foo@example.com"), true);
});

Deno.test("isValidEmail rejects an address without @", () => {
  assertEquals(isValidEmail("foo.example.com"), false);
});

Deno.test("isValidEmail rejects an address without a domain dot", () => {
  assertEquals(isValidEmail("foo@example"), false);
});

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

Deno.test("isValidUuid accepts a well-formed v4 uuid", () => {
  assertEquals(isValidUuid("123e4567-e89b-12d3-a456-426614174000"), true);
});

Deno.test("isValidUuid accepts uppercase hex digits", () => {
  assertEquals(isValidUuid("AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"), true);
});

Deno.test("isValidUuid rejects a malformed value", () => {
  assertEquals(isValidUuid("not-a-uuid"), false);
  assertEquals(isValidUuid(""), false);
});
