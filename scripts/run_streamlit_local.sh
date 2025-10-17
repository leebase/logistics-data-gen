#!/usr/bin/env bash
set -euo pipefail

# Run the Streamlit app locally against Snowflake using Snowpark.

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"

if [[ -f "$root/.env.snowflake" ]]; then
  set -a; source "$root/.env.snowflake"; set +a
fi

# If SF_PASSWORD not set, fall back to SNOWSQL_PWD for convenience
if [[ -z "${SF_PASSWORD:-}" && -n "${SNOWSQL_PWD:-}" ]]; then
  export SF_PASSWORD="${SNOWSQL_PWD}"
fi

if ! command -v streamlit >/dev/null 2>&1; then
  echo "Installing dev dependencies (virtualenv recommended)..." >&2
  python3 -m pip install -r "$root/requirements-dev.txt"
fi

# Allow overriding port and host
PORT="${STREAMLIT_PORT:-8501}"
HOST="${STREAMLIT_HOST:-127.0.0.1}"

exec streamlit run "$root/streamlit/app.py" --server.headless true --server.port "$PORT" --server.address "$HOST"
