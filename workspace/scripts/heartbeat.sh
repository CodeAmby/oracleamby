#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATE="$ROOT/state/tasks.json"
LOG_DIR="$ROOT/logs"
LOG_FILE="$LOG_DIR/heartbeat.log"

# Keychain service name to read controller chat id from
KEYCHAIN_SERVICE="CONTROLLER_CHAT_ID"
KEYCHAIN_ACCOUNT="amby"

mkdir -p "$ROOT/state" "$LOG_DIR"

now_epoch=$(date -u +%s)

# Ensure tasks.json exists
if [ ! -f "$STATE" ]; then
  echo '{"tasks": []}' > "$STATE"
fi

# Try to read controller chat id from macOS Keychain (if available)
get_controller_chat_id() {
  if command -v security >/dev/null 2>&1; then
    security find-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_ACCOUNT" -w 2>/dev/null || true
  fi
}

controller_cid=$(get_controller_chat_id || true)

# Find running tasks that haven't updated in 1 hour (3600s)
stalled=$(jq --arg now "$now_epoch" '.tasks[] | select(.status=="running" and ((now|tonumber) - (.last_update|fromdateiso8601|tonumber)) > 3600) | .id' "$STATE" 2>/dev/null || true)

if [ -n "$stalled" ]; then
  echo "$(date -u +%FT%TZ) - Found stalled tasks: $stalled" >> "$LOG_FILE"
  # For each stalled task, mark as stalled and notify controller (if chat id present)
  while read -r taskid; do
    taskid=$(echo "$taskid" | tr -d '"')
    jq --arg id "$taskid" '(.tasks[] | select(.id==$id) | .status) = "stalled"' "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
    if [ -n "$controller_cid" ]; then
      echo "$(date -u +%FT%TZ) - Task $taskid stalled and marked. Notify controller: $controller_cid" >> "$LOG_DIR/notifications.log"
      # Send Telegram notification
      "$ROOT/scripts/telegram_send.sh" "[Felix] Task $taskid stalled and marked. Please investigate."
    else
      echo "$(date -u +%FT%TZ) - Task $taskid stalled and marked. No controller chat id configured." >> "$LOG_DIR/notifications.log"
    fi
  done <<< "$stalled"
fi

# Add a heartbeat tick
echo "$(date -u +%FT%TZ) - heartbeat ran" >> "$LOG_FILE"

exit 0
