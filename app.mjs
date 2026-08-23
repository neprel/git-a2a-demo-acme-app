import { formatLabel, slugify } from "@acme/lib-utils";

export function describe(value) {
  return formatLabel("slug", slugify(value));
}

if (process.argv[1] === new URL(import.meta.url).pathname) {
  console.log(describe("  Acme Demo App  "));
}
