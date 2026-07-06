import { assertEquals } from "jsr:@std/assert@1";
import { isValidEmail } from "../_shared/validation.ts";

Deno.test("isValidEmail accepts a well-formed address", () => {
  assertEquals(isValidEmail("foo@example.com"), true);
});

Deno.test("isValidEmail rejects an address without @", () => {
  assertEquals(isValidEmail("foo.example.com"), false);
});

Deno.test("isValidEmail rejects an address without a domain dot", () => {
  assertEquals(isValidEmail("foo@example"), false);
});
