#!/usr/bin/env bash
set -euo pipefail
BASE=$(cd "$(dirname "$0")/.." && pwd)
PROPOSALS_DIR="$BASE/state/proposals"
TEST_PROPOSAL="$PROPOSALS_DIR/proposal-TEST-0001.json"

mkdir -p "$PROPOSALS_DIR"
cat > "$TEST_PROPOSAL" <<'JSON'
{
  "id": "TEST-0001",
  "approved": true,
  "fulfilled": false
}
JSON

# run worker
$BASE/scripts/fulfillment_worker.py

# check result
if grep -q '"fulfilled": true' "$TEST_PROPOSAL"; then
  echo "SMOKE: success - proposal marked fulfilled"
  exit 0
else
  echo "SMOKE: failure - proposal not marked fulfilled" >&2
  cat "$TEST_PROPOSAL" >&2
  exit 2
fi
