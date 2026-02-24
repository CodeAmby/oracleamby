#!/usr/bin/env bash
set -euo pipefail

URL="$1"
TIMEOUT=${2:-10}

if curl -fsS --max-time "$TIMEOUT" "$URL" >/dev/null; then
  echo "OK: $URL is reachable"
  exit 0
else
  echo "FAIL: $URL not reachable"
  exit 2
fi
