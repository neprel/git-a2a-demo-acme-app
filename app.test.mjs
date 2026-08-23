import assert from "node:assert/strict";
import test from "node:test";
import { describe } from "./app.mjs";

test("uses the TypeScript implementation", () => {
  assert.equal(describe("  Acme Demo App  "), "slug: acme-demo-app");
});
