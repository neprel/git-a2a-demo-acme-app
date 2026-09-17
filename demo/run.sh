#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
profile=${DEMO_PROFILE:-full}
case "$profile" in
  full) repeat=${DEMO_REPEAT:-2}; runner=/demo/run-e2e.sh; prefix=run ;;
  npm) repeat=${DEMO_REPEAT:-1}; runner=/demo/run-npm-e2e.sh; prefix=npm-run ;;
  *) echo "DEMO_PROFILE must be full or npm" >&2; exit 2 ;;
esac
mkdir -p demo/evidence

for run in $(seq 1 "$repeat"); do
  evidence_dir="$prefix-$run"
  echo "== git-a2a demo $profile run $run/$repeat =="
  docker compose down --volumes --remove-orphans >/dev/null 2>&1 || true
  rm -rf "demo/evidence/$evidence_dir"
  mkdir -p "demo/evidence/$evidence_dir"
  DEMO_RUN_ID="run-$run" docker compose build
  DEMO_RUN_ID="run-$run" docker compose up -d --wait --wait-timeout 180 git-server lib-agent
  DEMO_RUN_ID="run-$run" docker compose run --rm --no-deps --service-ports --use-aliases \
    -e EVIDENCE_DIR="/evidence/$evidence_dir" app-agent "$runner"

  # Prove that dependency discovery is offline while the endpoint is stopped.
  docker compose stop lib-agent >/dev/null
  DEMO_RUN_ID="run-$run" docker compose run --rm --no-deps \
    -e EVIDENCE_DIR="/evidence/$evidence_dir" \
    app-agent /demo/check-offline.sh
done

echo "PASS: $repeat clean-volume run(s); evidence: demo/evidence/"
