#!/usr/bin/env bash
# Amanuense — transcribe un audio y guarda el .md en la carpeta actual (o en $AMANUENSE_DIR).
# Uso:  bash scripts/transcribir.sh audio.m4a "Título opcional"
# Vars: AMANUENSE_SERVER (def http://localhost:8000), AMANUENSE_API_KEY, AMANUENSE_DIR
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$HERE/banner.txt" ] && cat "$HERE/banner.txt"
AUDIO="${1:?Uso: transcribir.sh <audio> [titulo]}"
TITLE="${2:-}"
SERVER="${AMANUENSE_SERVER:-http://localhost:8000}"
OUT="${AMANUENSE_DIR:-.}"
mkdir -p "$OUT"
TMP=$(mktemp); HDR=$(mktemp)
ARGS=(-sS -D "$HDR" -o "$TMP" -F "audio=@${AUDIO}")
[ -n "$TITLE" ] && ARGS+=(-F "title=${TITLE}")
[ -n "${AMANUENSE_API_KEY:-}" ] && ARGS+=(-H "X-API-Key: ${AMANUENSE_API_KEY}")
echo "Transcribiendo $AUDIO ..."
CODE=$(curl "${ARGS[@]}" -w '%{http_code}' "$SERVER/transcribe/md")
if [ "$CODE" != "200" ]; then
  echo "❌ Error $CODE: $(cat "$TMP")" >&2; rm -f "$TMP" "$HDR"; exit 1
fi
NAME=$(grep -i '^content-disposition' "$HDR" | sed -E 's/.*filename="([^"]+)".*/\1/' | tr -d '\r')
mv "$TMP" "$OUT/${NAME:-nota.md}"; rm -f "$HDR"
echo "✅ Guardado: $OUT/${NAME:-nota.md}"
echo "                                                   — by wilo"
