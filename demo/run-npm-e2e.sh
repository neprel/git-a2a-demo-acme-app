#!/usr/bin/env bash
set -euo pipefail

evidence=${EVIDENCE_DIR:-/evidence/npm-manual}
source_url=${DEMO_GIT_URL:?DEMO_GIT_URL is required}
branch=${DEMO_BRANCH:-demo/fallback}
mkdir -p "$evidence" "${TMPDIR:-/tmp}"
exec > >(tee "$evidence/e2e.log") 2>&1
cd /workspace/app

# This profile deliberately exposes only an npm consumer manifest. The full
# default profile is the authoritative polyglot and resilience demonstration.
rm -rf CMakeLists.txt cmake go.mod go.sum pyproject.toml uv.lock

python /demo/app_agent.py >"$evidence/app-agent.log" 2>&1 &
app_agent_pid=$!
trap 'kill "$app_agent_pid" 2>/dev/null || true' EXIT
for _ in $(seq 1 30); do
  curl -fsS http://localhost:8001/.well-known/agent-card.json > "$evidence/app-agent-card.json" && break
  sleep 1
done
getent hosts app-agent > "$evidence/app-agent-host.txt"
python /demo/a2a_client.py "$evidence/app-agent-card.json" app-status \
  | tee "$evidence/app-agent-status.json"
python - "$evidence/app-agent-status.json" <<'PY'
import json,sys
response=json.load(open(sys.argv[1]))
assert response == {"action":"status","component":"consumer-app","status":"ok"}, response
PY

git-a2a add "$source_url" --name acme-lib-utils --ref "$branch"
git-a2a list acme-lib-utils --json | tee "$evidence/list-baseline.json"
readarray -t discovery < <(python - "$evidence/list-baseline.json" <<'PY'
import json,sys
item=json.load(open(sys.argv[1]))[0]
assert {binding["adapter"] for binding in item["bindings"]} == {"npm"}, item
print(item["agent"]["card"])
print(item["surface"])
print(item["commit"])
PY
)
card=${discovery[0]}
surface=${discovery[1]}
baseline=${discovery[2]}
source_app=$(cat .git-a2a/source-app.sha)
source_lib=$(cat .git-a2a/source-lib.sha)
test -f "$card" && test -f "$surface/API.md"
test -z "$(node app.mjs '   ')"

python /demo/a2a_client.py "$card" request-fallback --timeout 300 \
  | tee "$evidence/a2a-change.json"
final=$(python - "$evidence/a2a-change.json" <<'PY'
import json,sys
response=json.load(open(sys.argv[1]))
assert response["status"] in {"changed", "already_changed"}, response
assert response["version"] == "1.1.0", response
print(response["commit"])
PY
)
test "$baseline" != "$final"
test -z "$(node app.mjs '   ')"
git-a2a pull acme-lib-utils
test "$(git-a2a list acme-lib-utils --json | python -c 'import json,sys; print(json.load(sys.stdin)[0]["commit"])')" = "$final"
result=$(node --input-type=module -e \
  'import {formatDisplayName} from "@acme/lib-utils"; console.log(formatDisplayName("  ", " Anonymous "))')
test "$result" = Anonymous
printf 'npm blank+fallback => %q\n' "$result" | tee "$evidence/after.txt"
printf '{"status":"PASS","profile":"npm","appSource":"%s","libSource":"%s","libBaseline":"%s","libFinal":"%s"}\n' \
  "$source_app" "$source_lib" "$baseline" "$final" > "$evidence/summary.json"
echo "PASS: short npm add, discovery, A2A change, pull, and runtime assertion"
