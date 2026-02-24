#!/usr/bin/env bash
set -euo pipefail

# Send a Telegram message using bot token + controller chat id from macOS Keychain
# Usage: ./telegram_send.sh "Your message here"

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <message>"
  exit 2
fi

MSG="$1"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

get_secret() {
  service="$1"
  account="$2"
  security find-generic-password -s "$service" -a "$account" -w 2>/dev/null || true
}

BOT_TOKEN=$(get_secret TELEGRAM_BOT_TOKEN felix)
CHAT_ID=$(get_secret CONTROLLER_CHAT_ID felix)

if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
  echo "Telegram bot token or chat id not configured in Keychain." >&2
  exit 3
fi

# url-encode message lightly
payload=$(python3 - <<PY
import sys,urllib.parse
print(urllib.parse.quote(sys.argv[1]))
PY
"$MSG")

curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" -d "chat_id=${CHAT_ID}&text=${payload}&parse_mode=Markdown" > /tmp/telegram_send_resp.json || true
cat /tmp/telegram_send_resp.json

exit 0
