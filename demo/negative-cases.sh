#!/usr/bin/env bash
set -euo pipefail

source_url=${1:?source URL required}
branch=${2:?branch required}
base=/workspace/app/.git-a2a/negative
rm -rf "$base"
mkdir -p "$base"

new_npm_consumer() {
  local root=$1
  mkdir -p "$root"
  printf '%s\n' 'schema: 2' 'component:' "  id: negative-$(basename "$root")-consumer" > "$root/a2amodule.yml"
  printf '%s\n' '{"name":"negative-consumer","private":true,"packageManager":"npm@11.6.0","dependencies":{"is-number":"7.0.0"}}' > "$root/package.json"
  git -C "$root" init -q -b demo
  git -C "$root" config user.name fixture
  git -C "$root" config user.email fixture@example.invalid
}

# Missing manager is a failed transaction: no false lock and no adapter drift.
manager="$base/manager-failure"
new_npm_consumer "$manager"
before=$(sha256sum "$manager/a2amodule.yml" "$manager/package.json")
if (cd "$manager" && PATH=/usr/local/bin:/usr/bin:/bin git-a2a add "$source_url" --name lib --ref "$branch" >failure.log 2>&1); then
  echo "manager failure unexpectedly succeeded" >&2; exit 1
fi
test "$before" = "$(sha256sum "$manager/a2amodule.yml" "$manager/package.json")"
test ! -e "$manager/a2amodule.lock"

# An unsafe repository-relative card is rejected before dependency state exists.
bad="$base/bad-card"
new_npm_consumer "$bad"
if (cd "$bad" && git-a2a add https://github.com/neprel/bad-card.git --name bad --ref demo >failure.log 2>&1); then
  echo "unsafe card unexpectedly succeeded" >&2; exit 1
fi
test ! -e "$bad/a2amodule.lock"

# Surface is optional; list must not invent one.
none="$base/no-surface"
new_npm_consumer "$none"
(cd "$none" && npm install --ignore-scripts --no-audit --no-fund >/dev/null && git-a2a add https://github.com/neprel/no-surface.git --name none --ref demo)
(cd "$none" && git-a2a list none --json) | python -c 'import json,sys; assert not json.load(sys.stdin)[0].get("surface")'
(cd "$none" && git-a2a remove none)
(cd "$none" && node -e 'if(!require("is-number")(7)) process.exit(1)')
grep -q '"is-number"' "$none/package.json"
! grep -q '@acme/no-surface' "$none/package.json"
! grep -q '@acme/no-surface' "$none/package-lock.json"
test ! -e "$none/node_modules/@acme/no-surface"
if (cd "$none" && git-a2a list none --json >/dev/null 2>&1); then
  echo "removed dependency still appears in git-a2a list" >&2; exit 1
fi

# No compatible native export falls back to an ordinary submodule. Dirty
# user content prevents pull/remove and remains byte-for-byte intact.
fallback="$base/fallback"
new_npm_consumer "$fallback"
(cd "$fallback" && git-a2a add https://github.com/neprel/fallback-only.git --name fallback --ref demo)
(cd "$fallback" && git-a2a list fallback --json) | python -c 'import json,sys; i=json.load(sys.stdin)[0]; assert [b["adapter"] for b in i["bindings"]]==["submodule"]'
submodule=$(cd "$fallback" && git-a2a list fallback --json | python -c 'import json,sys; print(json.load(sys.stdin)[0]["bindings"][0]["path"])')
printf 'user work\n' > "$fallback/$submodule/UNCOMMITTED.txt"
if (cd "$fallback" && git-a2a pull fallback >failure.log 2>&1); then
  echo "dirty submodule pull unexpectedly succeeded" >&2; exit 1
fi
if (cd "$fallback" && git-a2a remove fallback >>failure.log 2>&1); then
  echo "dirty submodule remove unexpectedly succeeded" >&2; exit 1
fi
test "$(cat "$fallback/$submodule/UNCOMMITTED.txt")" = "user work"

echo "PASS: manager rollback, bad card, absent surface, remove retention, fallback, dirty preservation"
