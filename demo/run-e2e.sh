#!/usr/bin/env bash
set -euo pipefail

evidence=${EVIDENCE_DIR:-/evidence/manual}
mkdir -p "$evidence"
exec > >(tee "$evidence/e2e.log") 2>&1

source_url=${DEMO_GIT_URL:?DEMO_GIT_URL is required}
branch=${DEMO_BRANCH:-demo/fallback}
cd /workspace/app
mkdir -p "$TMPDIR"

python /demo/app_agent.py >"$evidence/app-agent.log" 2>&1 &
app_agent_pid=$!
trap 'kill "$app_agent_pid" 2>/dev/null || true' EXIT
for _ in $(seq 1 30); do
  curl -fsS http://localhost:8001/.well-known/agent-card.json > "$evidence/app-agent-card.json" && break
  sleep 1
done
test -s "$evidence/app-agent-card.json"
getent hosts app-agent > "$evidence/app-agent-host.txt"
python /demo/a2a_client.py "$evidence/app-agent-card.json" app-status \
  | tee "$evidence/app-agent-status.json"
python - "$evidence/app-agent-status.json" <<'PY'
import json,sys
response=json.load(open(sys.argv[1]))
assert response == {"action":"status","component":"consumer-app","status":"ok"}, response
PY

git config --global protocol.file.allow always

{
  git-a2a --version
  node --version
  npm --version
  python --version
  uv --version
  go version
  cmake --version | head -1
  git --version
} | tee "$evidence/versions.txt"
git-a2a --version | grep -q '^git-a2a 2\.0\.0 ('
git-a2a --version | grep -q '752eda1db35315592154e7928e61a8f18454d733, linux/[^,]*, channel=binary)'
test ! -e /workspace/lib
PYTHONPATH=/demo python /demo/test_a2a_client.py -v 2>&1 | tee "$evidence/a2a-client-test.txt"

baseline=$(git rev-parse HEAD)
source_app=$(cat .git-a2a/source-app.sha)
source_lib=$(cat .git-a2a/source-lib.sha)
archive_sentinel=$(cat .git-a2a/archive-sentinel-verified)
test "$archive_sentinel" = demo/evidence/run-source-sentinel/ignored-sentinel
test ! -e "$archive_sentinel"
git-a2a add "$source_url" --name acme-lib-utils --ref "$branch"
git-a2a list acme-lib-utils --json | tee "$evidence/list-baseline.json"

readarray -t discovery < <(python - "$evidence/list-baseline.json" <<'PY'
import json,sys
item=json.load(open(sys.argv[1]))[0]
print(item["agent"]["card"])
print(item["surface"])
print(item["commit"])
PY
)
card=${discovery[0]}
surface=${discovery[1]}
locked_baseline=${discovery[2]}
test -f "$card"
test -d "$surface"
test -f "$surface/API.md"
! grep -q 'fallback = ' "$surface/API.md"

/demo/check-phase.sh baseline | tee "$evidence/before.txt"

python /demo/a2a_client.py "$card" describe-contract | tee "$evidence/a2a-question.json"
python - "$evidence/a2a-question.json" <<'PY'
import json,sys
r=json.load(open(sys.argv[1]))
assert r["status"] == "ok" and r["supportsFallback"] is False and r["blankResult"] == "", r
PY

rm -f .git-a2a/unsupported-ran
python /demo/a2a_client.py "$card" unsupported | tee "$evidence/a2a-unsupported.json"
python - "$evidence/a2a-unsupported.json" <<'PY'
import json,sys
r=json.load(open(sys.argv[1]))
assert r["status"] == "unsupported", r
PY
test ! -e .git-a2a/unsupported-ran

# A disposable second dependency proves that targeted pull does not touch it.
target=/workspace/app/.git-a2a/target
mkdir -p "$target"
printf '%s\n' 'schema: 2' 'component:' '  id: targeted-consumer' > "$target/a2amodule.yml"
printf '%s\n' '{"name":"targeted-consumer","private":true,"packageManager":"npm@11.6.0"}' > "$target/package.json"
git -C "$target" init -q -b demo
git -C "$target" config user.name fixture
git -C "$target" config user.email fixture@example.invalid
(cd "$target" && git-a2a add "$source_url" --name acme-lib-utils --ref "$branch")
(cd "$target" && git-a2a add https://github.com/neprel/fixture-stable.git --name stable --ref demo)
stable_before=$(cd "$target" && git-a2a list stable --json | python -c 'import json,sys; print(json.load(sys.stdin)[0]["commit"])')
stable_value_before=$(cd "$target" && node --input-type=module -e \
  'import {fixtureValue} from "@acme/fixture-stable"; process.stdout.write(fixtureValue)')
test "$stable_value_before" = fixture-stable

python /demo/a2a_client.py "$card" request-fallback --timeout 300 | tee "$evidence/a2a-change.json"
final_commit=$(python - "$evidence/a2a-change.json" <<'PY'
import json,sys
r=json.load(open(sys.argv[1]))
assert r["status"] in {"changed", "already_changed"}, r
assert r["version"] == "1.1.0", r
print(r["commit"])
PY
)
test "$final_commit" != "$locked_baseline"

curl -fsS --cacert /tls/public/cert.pem -X POST \
  https://github.com/__demo__/advance-fixture-stable \
  | tee "$evidence/fixture-stable-change.json"
stable_upstream=$(python - "$evidence/fixture-stable-change.json" <<'PY'
import json,sys
r=json.load(open(sys.argv[1]))
assert r["before"] != r["after"], r
print(r["after"])
PY
)

# Owner pushed, but installed code remains the baseline until Pull.
/demo/check-phase.sh baseline | tee "$evidence/before-pull.txt"

(cd "$target" && git-a2a pull acme-lib-utils)
stable_after=$(cd "$target" && git-a2a list stable --json | python -c 'import json,sys; print(json.load(sys.stdin)[0]["commit"])')
test "$stable_before" = "$stable_after"
test "$(cd "$target" && git-a2a list acme-lib-utils --json | python -c 'import json,sys; print(json.load(sys.stdin)[0]["commit"])')" = "$final_commit"
test "$(cd "$target" && node --input-type=module -e \
  'import {fixtureValue} from "@acme/fixture-stable"; process.stdout.write(fixtureValue)')" = fixture-stable

(cd "$target" && git-a2a pull)
test "$(cd "$target" && git-a2a list stable --json | python -c 'import json,sys; print(json.load(sys.stdin)[0]["commit"])')" = "$stable_upstream"
test "$(cd "$target" && node --input-type=module -e \
  'import {fixtureValue} from "@acme/fixture-stable"; process.stdout.write(fixtureValue)')" = fixture-stable-next

git-a2a pull acme-lib-utils
git-a2a list acme-lib-utils --json | tee "$evidence/list-final.json"
python - "$evidence/list-final.json" "$final_commit" <<'PY'
import json,sys
item=json.load(open(sys.argv[1]))[0]
assert item["commit"] == sys.argv[2], item
assert item["agent"]["commit"] == sys.argv[2], item
assert {b["adapter"] for b in item["bindings"]} >= {"npm", "pypi", "golang", "submodule", "cmake"}, item
PY
grep -q 'fallback = ' "$surface/API.md"
/demo/check-phase.sh final | tee "$evidence/after.txt"

# The package version stays fixed while the Git commit changes.
test "$(node -p 'require("./node_modules/@acme/lib-utils/package.json").version')" = 1.1.0
.venv/bin/python -c 'from importlib.metadata import version; assert version("acme-lib-utils") == "1.1.0"'

# Pull repairs deleted materializations at the same commit. The entire Go
# module and build caches are emptied, not only the VCS checkout cache.
rm -rf node_modules .venv .demo-build deps/acme-lib-utils
chmod -R u+w /cache/go
find /cache/go -mindepth 1 -delete
test -z "$(find /cache/go -mindepth 1 -print -quit)"
if /demo/check-phase.sh final > "$evidence/missing-materializations.txt" 2>&1; then
  echo "usage check unexpectedly repaired missing materializations" >&2
  exit 1
fi
test ! -e .venv
test ! -e node_modules
test ! -e deps/acme-lib-utils
test -z "$(find /cache/go -mindepth 1 -print -quit)"
if GOPROXY=off GONOPROXY=none GOPRIVATE= GONOSUMDB=none GOSUMDB=off \
    GOVCS='*:off' go run -mod=readonly ./.demo-final-go \
    >> "$evidence/missing-materializations.txt" 2>&1; then
  echo "Go usage unexpectedly succeeded without its materialization" >&2
  exit 1
fi
test -z "$(find /cache/go/pkg/mod/github.com/neprel -maxdepth 1 -type d \
  -name 'git-a2a-demo-acme-lib@*' -print -quit 2>/dev/null)"
git-a2a pull acme-lib-utils
/demo/check-phase.sh final > "$evidence/repair.txt"

# Commit only inside the disposable volume, then prove an idempotent Pull and
# a fresh clone restore all materializations without a manual manager command.
rm -rf .demo-build .demo-final-go .git-a2a/target
git add -A
if git diff --cached --name-only | grep -E '(^|/)(\.demo-|build/|node_modules/|\.venv/)'; then
  echo "temporary artifacts entered the disposable commit" >&2
  exit 1
fi
git commit -q -m "Apply demo dependency at owner revision"
git-a2a pull acme-lib-utils
git diff --exit-code

fresh=/workspace/app/.git-a2a/fresh-app
fresh_go=/workspace/app/.git-a2a/fresh-go
git clone -q /workspace/app "$fresh"
mkdir -p "$fresh_go"
test -z "$(find "$fresh_go" -mindepth 1 -print -quit)"
(cd "$fresh" && \
  GOPATH="$fresh_go" GOMODCACHE="$fresh_go/pkg/mod" GOCACHE="$fresh_go/build" \
  git-a2a pull acme-lib-utils && \
  GOPATH="$fresh_go" GOMODCACHE="$fresh_go/pkg/mod" GOCACHE="$fresh_go/build" \
  DEMO_APP_ROOT="$fresh" /demo/check-phase.sh final) > "$evidence/fresh-clone.txt"
test -n "$(find "$fresh_go/pkg/mod" -mindepth 1 -print -quit)"

/demo/negative-cases.sh "$source_url" "$branch" | tee "$evidence/negative-cases.txt"

cat > "$evidence/summary.json" <<JSON
{"status":"PASS","appSource":"$source_app","libSource":"$source_lib","appBaseline":"$baseline","libBaseline":"$locked_baseline","libFinal":"$final_commit","stableBaseline":"$stable_before","stableFinal":"$stable_upstream","archiveSentinelExcluded":true,"usageChecksOffline":true,"gitA2A":"2.0.0","a2aSDK":"1.1.2","protocol":"A2A 1.0 JSON-RPC"}
JSON
echo "PASS: owner A2A request, commit, Pull, and npm/uv/Go/CMake assertions"
