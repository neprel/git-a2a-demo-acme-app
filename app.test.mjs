import assert from "node:assert/strict";
import test from "node:test";
import { describe } from "./app.mjs";

test("uses the installed npm implementation", () => {
  assert.equal(describe("  Ada   Lovelace  "), "Ada Lovelace");
});
