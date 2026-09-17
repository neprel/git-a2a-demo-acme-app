#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose down --volumes --remove-orphans
echo "Removed git-a2a demo containers, network, and named volumes."
