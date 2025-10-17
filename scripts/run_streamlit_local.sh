#!/usr/bin/env bash
set -euo pipefail

# Run the Streamlit app locally against Snowflake using Snowpark.

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"

if [[ -f "$root/.env.snowflake" ]]; then
  set -a; source "$root/.env.snowflake"; set +a
fi

if ! command -v streamlit >/dev/null 2>&1; then
  echo "Installing dev dependencies (virtualenv recommended)..." >&2
  python3 -m pip install -r "$root/requirements-dev.txt"
fi

exec streamlit run "$root/streamlit/app.py"

