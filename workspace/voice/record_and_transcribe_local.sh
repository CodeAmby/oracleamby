#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/voice/whisper-cli"
MODEL="$ROOT/voice/models/ggml-small.en.bin"
OUT="$ROOT/state/voice_in.txt"

if [ ! -x "$BIN" ]; then
  echo "whisper-cli binary not found at $BIN"
  exit 1
fi
if [ ! -f "$MODEL" ]; then
  echo "model not found at $MODEL"
  exit 1
fi

# record until Ctrl-C
TMPFILE="/tmp/amby_voice.wav"
echo "Recording to $TMPFILE — press Ctrl-C to stop"
ffmpeg -f avfoundation -i :0 -ac 1 -ar 16000 -y "$TMPFILE"

# transcribe
"$BIN" -m "$MODEL" -f "$TMPFILE" > /tmp/amby_transcript.txt 2>/tmp/amby_transcript.err || true
cat /tmp/amby_transcript.txt | sed -n 's/^text: //p' > "$OUT" || true

echo "Transcription written to $OUT"
