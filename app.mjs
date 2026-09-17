import { formatDisplayName } from "@acme/lib-utils";

export function describe(value) {
  return formatDisplayName(value);
}

if (process.argv[1] === new URL(import.meta.url).pathname) {
  console.log(describe(process.argv[2] ?? "  Ada   Lovelace  "));
}
