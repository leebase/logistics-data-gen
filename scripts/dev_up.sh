#!/usr/bin/env bash
set -euo pipefail

# One-command local developer UX for the Streamlit dashboard.
# - Creates venv (if missing), installs requirements
# - Sources .env.snowflake (if present)
# - Runs Streamlit headless on 127.0.0.1:8501
# - Polls the health endpoint until ready, then opens browser

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
VENV_DIR="${VENV_DIR:-$root/.venv}"
PORT="${STREAMLIT_PORT:-8501}"
HOST="${STREAMLIT_HOST:-127.0.0.1}"

if [[ ! -d "$VENV_DIR" ]]; then
  "$root/scripts/setup_local_env.sh"
else
  # shellcheck disable=SC1090
  source "$VENV_DIR/bin/activate"
fi

if [[ -f "$root/.env.snowflake" ]]; then
  set -a; source "$root/.env.snowflake"; set +a
fi

# Map SNOWSQL_* -> SNOWFLAKE_* for Snowpark convenience
export SF_PASSWORD="${SF_PASSWORD:-${SNOWSQL_PWD:-}}"
export SNOWFLAKE_ACCOUNT="${SNOWFLAKE_ACCOUNT:-${SNOWSQL_ACCOUNT:-}}"
export SNOWFLAKE_USER="${SNOWFLAKE_USER:-${SNOWSQL_USER:-}}"
export SNOWFLAKE_ROLE="${SNOWFLAKE_ROLE:-${SNOWSQL_ROLE:-}}"
export SNOWFLAKE_WAREHOUSE="${SNOWFLAKE_WAREHOUSE:-${SNOWSQL_WAREHOUSE:-}}"
export SNOWFLAKE_DATABASE="${SNOWFLAKE_DATABASE:-${SNOWSQL_DATABASE:-}}"
export SNOWFLAKE_STG_SCHEMA="${SNOWFLAKE_STG_SCHEMA:-${SNOWSQL_STG_SCHEMA:-STG}}"
export SNOWFLAKE_EDW_SCHEMA="${SNOWFLAKE_EDW_SCHEMA:-${SNOWSQL_EDW_SCHEMA:-EDW}}"
# Start Streamlit in background
logf="$root/.streamlit.log"
rm -f "$logf"
nohup streamlit run "$root/streamlit/app.py" --server.headless true --server.port "$PORT" --server.address "$HOST" >"$logf" 2>&1 &
pid=$!
echo "Streamlit starting (pid=$pid). Logs: $logf"

# Poll health endpoint
url="http://$HOST:$PORT/_stcore/health"
for i in {1..60}; do
  if curl -fsS "$url" >/dev/null 2>&1; then
    echo "Ready at http://$HOST:$PORT"
    if command -v open >/dev/null 2>&1; then open "http://$HOST:$PORT"; fi
    exit 0
  fi
  sleep 1
done

echo "Timed out waiting for Streamlit readiness. Check logs: $logf"
exit 1
