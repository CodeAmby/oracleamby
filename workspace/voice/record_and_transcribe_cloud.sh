#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/state/voice_in.txt"
TMPFILE="/tmp/amby_voice_cloud.wav"

# record with ffmpeg until Ctrl-C
echo "Recording to $TMPFILE — press Ctrl-C to stop"
ffmpeg -f avfoundation -i :0 -ac 1 -ar 16000 -y "$TMPFILE"

# read key
KEY=$(security find-generic-password -s OPENAI_API_KEY -a amby -w 2>/dev/null || true)
if [ -z "$KEY" ]; then
  echo "OPENAI_API_KEY not found in Keychain (service OPENAI_API_KEY, account amby)"
  exit 1
fi

resp=$(curl -s -X POST "https://api.openai.com/v1/audio/transcriptions" \
  -H "Authorization: Bearer $KEY" \
  -F file=@"$TMPFILE" \
  -F model=whisper-1)

echo "$resp" | jq -r '.text' > "$OUT"

echo "Transcription written to $OUT"
