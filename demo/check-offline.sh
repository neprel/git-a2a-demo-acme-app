#!/usr/bin/env bash
set -euo pipefail

evidence=${EVIDENCE_DIR:?EVIDENCE_DIR is required}
cd /workspace/app
git-a2a list acme-lib-utils --json > "$evidence/list-endpoint-stopped.json"
card=$(python - "$evidence/list-endpoint-stopped.json" <<'PY'
import json,sys
print(json.load(open(sys.argv[1]))[0]["agent"]["card"])
PY
)
if python /demo/a2a_client.py "$card" describe-contract --timeout 2 > "$evidence/a2a-stopped.txt" 2>&1; then
  echo "A2A request unexpectedly succeeded with lib-agent stopped" >&2
  exit 1
fi
test -s "$evidence/list-endpoint-stopped.json"
echo "PASS: list remained offline; A2A transport failed while endpoint was stopped"
