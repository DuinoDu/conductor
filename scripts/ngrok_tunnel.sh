#!/usr/bin/env bash
set -euo pipefail

# Simple helper to expose local HTTP backend over public HTTPS via ngrok
# Usage: bash scripts/ngrok_tunnel.sh [port]

PORT="${1:-4000}"
NGROK_BIN="${NGROK_BIN:-ngrok}"
LOG_FILE="/tmp/ngrok_${PORT}.log"

have_cmd() { command -v "$1" >/dev/null 2>&1; }

if ! have_cmd "$NGROK_BIN"; then
  echo "ngrok not found. Install with:"
  echo "  brew install ngrok/ngrok/ngrok  # macOS" >&2
  echo "Or download from https://ngrok.com/download" >&2
  exit 1
fi

# Optional: configure authtoken if provided
if [ -n "${NGROK_AUTHTOKEN:-}" ]; then
  "$NGROK_BIN" config add-authtoken "$NGROK_AUTHTOKEN" >/dev/null 2>&1 || true
fi

# Start ngrok if not already running for this port
if ! pgrep -f "ngrok http .*:${PORT}" >/dev/null 2>&1; then
  echo "Starting ngrok tunnel -> http://0.0.0.0:${PORT} ..."
  nohup "$NGROK_BIN" http --log=stdout --log-level=info "http://0.0.0.0:${PORT}" > "$LOG_FILE" 2>&1 &
  NGROK_PID=$!
  echo "$NGROK_PID" > "/tmp/ngrok_${PORT}.pid"
else
  echo "An ngrok http tunnel to :${PORT} seems to be running already."
fi

# Wait for local API (4040) and extract the HTTPS public URL
ATTEMPTS=0
PUB_URL=""
until [ $ATTEMPTS -gt 60 ]; do
  if curl -fsS "http://127.0.0.1:4040/api/tunnels" >/dev/null 2>&1; then
    PUB_URL=$(curl -fsS "http://127.0.0.1:4040/api/tunnels" | \
      python3 - <<'PY'
import json,sys
try:
  d=json.load(sys.stdin)
  for t in d.get('tunnels', []):
    url=t.get('public_url','')
    if url.startswith('https://'):
      print(url)
      break
except Exception:
  pass
PY
    )
    if [ -n "$PUB_URL" ]; then
      break
    fi
  fi
  ATTEMPTS=$((ATTEMPTS+1))
  sleep 0.5
done

if [ -z "$PUB_URL" ]; then
  echo "Failed to discover ngrok public URL. Check logs: $LOG_FILE" >&2
  exit 2
fi

WS_URL=$(python3 - <<PY
from urllib.parse import urlparse, urlunparse
import sys
u=sys.argv[1]
pu=urlparse(u)
scheme='wss'
path='/ws/app'
print(urlunparse((scheme, pu.netloc, path, '', '', '')))
PY
"$PUB_URL")

echo "NGROK_HTTPS_URL=$PUB_URL"
echo "NGROK_WSS_URL=$WS_URL"
echo ""
echo "Use these for the Flutter app (example):"
echo "  cd app/conductor_app && flutter run \\\n+    --dart-define=API_BASE_URL=$PUB_URL \\\n+    --dart-define=WS_URL=$WS_URL"

