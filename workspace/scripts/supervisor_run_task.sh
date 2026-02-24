#!/usr/bin/env bash
set -euo pipefail

# Supervisor: picks up queued tasks from state/tasks.json and runs them in a pty-like sandbox.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATE="$ROOT/state/tasks.json"
LOG_DIR="$ROOT/logs/tasks"
mkdir -p "$ROOT/state" "$LOG_DIR"

if [ ! -f "$STATE" ]; then
  echo '{"tasks": []}' > "$STATE"
fi

# Iterate queued tasks
jq -c '.tasks[] | select(.status=="queued")' "$STATE" | while read -r task; do
  id=$(echo "$task" | jq -r '.id')
  cmd=$(echo "$task" | jq -r '.command')
  attempts=$(echo "$task" | jq -r '.attempts')

  logfile="$LOG_DIR/$id.log"
  echo "$(date -u +%FT%TZ) - Starting task $id: $cmd" >> "$logfile"

  # mark running
  jq --arg id "$id" '(.tasks[] | select(.id==$id) | .status) = "running" | (.tasks[] | select(.id==$id) | .last_update) = now' "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"

  # Run command with timeout (example 30m) and capture output
  if timeout 1800 bash -lc "$cmd" >> "$logfile" 2>&1; then
    jq --arg id "$id" '(.tasks[] | select(.id==$id) | .status) = "done" | (.tasks[] | select(.id==$id) | .completed) = now' "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
    echo "$(date -u +%FT%TZ) - Task $id completed" >> "$logfile"
    # notify controller of completion
    if command -v security >/dev/null 2>&1; then
      controller_cid=$(security find-generic-password -s CONTROLLER_CHAT_ID -a amby -w 2>/dev/null || true)
    fi
    if [ -n "$controller_cid" ]; then
      "$ROOT/scripts/telegram_send.sh" "[Felix] Task $id completed successfully."
    fi
  else
    jq --arg id "$id" '(.tasks[] | select(.id==$id) | .status) = "failed" | (.tasks[] | select(.id==$id) | .attempts) += 1' "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
    echo "$(date -u +%FT%TZ) - Task $id failed" >> "$logfile"
    # notify controller of failure
    if command -v security >/dev/null 2>&1; then
      controller_cid=$(security find-generic-password -s CONTROLLER_CHAT_ID -a amby -w 2>/dev/null || true)
    fi
    if [ -n "$controller_cid" ]; then
      "$ROOT/scripts/telegram_send.sh" "[Felix] Task $id failed. Check logs: $logfile"
    fi
  fi
done

exit 0
