#!/usr/bin/env bash
set -euo pipefail

# Expose local Streamlit to a public URL so it can be curled from outside.
# Tries cloudflared first, then ngrok if installed.

PORT="${STREAMLIT_PORT:-8501}"
LOCAL_URL="http://127.0.0.1:${PORT}"

echo "Exposing local URL: ${LOCAL_URL}" >&2

if command -v cloudflared >/dev/null 2>&1; then
  echo "Using cloudflared (no account required). Press Ctrl+C to stop." >&2
  exec cloudflared tunnel --no-autoupdate --url "${LOCAL_URL}"
fi

if command -v ngrok >/dev/null 2>&1; then
  echo "Using ngrok. Press Ctrl+C to stop." >&2
  exec ngrok http "${PORT}"
fi

echo "Neither cloudflared nor ngrok found. Please install one:" >&2
echo "  brew install cloudflared   # simplest (no login)" >&2
echo "  brew install ngrok         # requires ngrok account/login" >&2
exit 1

