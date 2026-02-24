#!/usr/bin/env bash
set -euo pipefail

# Paths (adjust if needed)
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SESS_DIR="$ROOT/memory/sessions"
OUT_DIR="$ROOT/memory/indexed"
LOG_DIR="$ROOT/logs"
mkdir -p "$SESS_DIR" "$OUT_DIR" "$LOG_DIR"

SNAPSHOT="$OUT_DIR/snapshot-$(date +%F).md"

# Merge session markdown files
cat "$SESS_DIR"/*.md > "$SNAPSHOT" 2>/dev/null || true

# Rebuild a simple ripgrep index (here: ensure files exist)
# This step is a placeholder for QMD or other indexers.
if command -v rg >/dev/null 2>&1; then
  rg --version >/dev/null 2>&1 || true
fi

echo "$(date -u +%FT%TZ) - consolidated sessions into $SNAPSHOT" >> "$LOG_DIR/consolidate.log"

# Optional: call an external indexer if available
# e.g., python3 scripts/reindex_qmd.py "$OUT_DIR"

exit 0
