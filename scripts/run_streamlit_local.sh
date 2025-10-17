#!/usr/bin/env bash
set -euo pipefail

# Run the Streamlit app locally against Snowflake using Snowpark.

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"

if [[ -f "$root/.env.snowflake" ]]; then
  set -a; source "$root/.env.snowflake"; set +a
fi

# Map SNOWSQL_* -> SNOWFLAKE_* for Snowpark convenience (no manual edits needed)
export SF_PASSWORD="${SF_PASSWORD:-${SNOWSQL_PWD:-}}"
export SNOWFLAKE_ACCOUNT="${SNOWFLAKE_ACCOUNT:-${SNOWSQL_ACCOUNT:-}}"
export SNOWFLAKE_USER="${SNOWFLAKE_USER:-${SNOWSQL_USER:-}}"
export SNOWFLAKE_ROLE="${SNOWFLAKE_ROLE:-${SNOWSQL_ROLE:-}}"
export SNOWFLAKE_WAREHOUSE="${SNOWFLAKE_WAREHOUSE:-${SNOWSQL_WAREHOUSE:-}}"
export SNOWFLAKE_DATABASE="${SNOWFLAKE_DATABASE:-${SNOWSQL_DATABASE:-}}"
export SNOWFLAKE_STG_SCHEMA="${SNOWFLAKE_STG_SCHEMA:-${SNOWSQL_STG_SCHEMA:-STG}}"
export SNOWFLAKE_EDW_SCHEMA="${SNOWFLAKE_EDW_SCHEMA:-${SNOWSQL_EDW_SCHEMA:-EDW}}"

if ! command -v streamlit >/dev/null 2>&1; then
  echo "Installing dev dependencies (virtualenv recommended)..." >&2
  python3 -m pip install -r "$root/requirements-dev.txt"
fi

# Allow overriding port and host
PORT="${STREAMLIT_PORT:-8501}"
HOST="${STREAMLIT_HOST:-127.0.0.1}"

exec streamlit run "$root/streamlit/app.py" --server.headless true --server.port "$PORT" --server.address "$HOST"
