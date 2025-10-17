#!/usr/bin/env bash
set -euo pipefail

# Deploy Streamlit app code to a Snowflake stage and create the Streamlit object.

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"

# Auto-source .env.snowflake if present or a custom env via --env
ENV_FILE="$root/.env.snowflake"
APP_STAGE="${APP_STAGE:-APP_CODE}"
APP_NAME="${APP_NAME:-LOGISTICS_DASH}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV_FILE="$2"; shift 2 ;;
    --stage) APP_STAGE="$2"; shift 2 ;;
    --name) APP_NAME="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ -f "$ENV_FILE" ]]; then
  set -a; source "$ENV_FILE"; set +a
fi

: "${SNOWSQL_ACCOUNT:?Set SNOWSQL_ACCOUNT/SNOWFLAKE_ACCOUNT}"
: "${SNOWSQL_USER:?Set SNOWSQL_USER/SNOWFLAKE_USER}"
: "${SNOWSQL_ROLE:=${SNOWFLAKE_ROLE:-ACCOUNTADMIN}}"
: "${SNOWSQL_WAREHOUSE:=${SNOWFLAKE_WAREHOUSE:-LOGISTICS_WH}}"
: "${SNOWSQL_DATABASE:=${SNOWFLAKE_DATABASE:-LOGISTICS_DB}}"
: "${SNOWSQL_EDW_SCHEMA:=${SNOWFLAKE_EDW_SCHEMA:-EDW}}"

echo "Creating stage and uploading app.py to ${SNOWSQL_DATABASE}.${SNOWSQL_EDW_SCHEMA}.${APP_STAGE} ..."
snowsql -a "$SNOWSQL_ACCOUNT" -u "$SNOWSQL_USER" -r "$SNOWSQL_ROLE" -w "$SNOWSQL_WAREHOUSE" -d "$SNOWSQL_DATABASE" -q \
  "CREATE OR REPLACE STAGE ${SNOWSQL_DATABASE}.${SNOWSQL_EDW_SCHEMA}.${APP_STAGE}"

snowsql -a "$SNOWSQL_ACCOUNT" -u "$SNOWSQL_USER" -r "$SNOWSQL_ROLE" -w "$SNOWSQL_WAREHOUSE" -d "$SNOWSQL_DATABASE" -q \
  "PUT file://${root}/streamlit/app.py @${SNOWSQL_DATABASE}.${SNOWSQL_EDW_SCHEMA}.${APP_STAGE} AUTO_COMPRESS=FALSE OVERWRITE=TRUE"

echo "Creating Streamlit app ${APP_NAME} ..."
snowsql -a "$SNOWSQL_ACCOUNT" -u "$SNOWSQL_USER" -r "$SNOWSQL_ROLE" -w "$SNOWSQL_WAREHOUSE" -d "$SNOWSQL_DATABASE" -q \
  "CREATE OR REPLACE STREAMLIT ${SNOWSQL_DATABASE}.${SNOWSQL_EDW_SCHEMA}.${APP_NAME} FROM @${SNOWSQL_DATABASE}.${SNOWSQL_EDW_SCHEMA}.${APP_STAGE} MAIN_FILE='app.py' QUERY_WAREHOUSE='${SNOWSQL_WAREHOUSE}'"

echo "Fetching Streamlit URL ..."
# Some accounts may not have SYSTEM$SHOW_STREAMLIT_URL. Fallback to SHOW STREAMLITS and RESULT_SCAN.
if snowsql -a "$SNOWSQL_ACCOUNT" -u "$SNOWSQL_USER" -r "$SNOWSQL_ROLE" -w "$SNOWSQL_WAREHOUSE" -d "$SNOWSQL_DATABASE" -q \
  "SELECT SYSTEM\$SHOW_STREAMLIT_URL('${SNOWSQL_DATABASE}.${SNOWSQL_EDW_SCHEMA}.${APP_NAME}') AS url" ; then
  :
else
  snowsql -a "$SNOWSQL_ACCOUNT" -u "$SNOWSQL_USER" -r "$SNOWSQL_ROLE" -w "$SNOWSQL_WAREHOUSE" -d "$SNOWSQL_DATABASE" -q \
    "SHOW STREAMLITS IN SCHEMA ${SNOWSQL_DATABASE}.${SNOWSQL_EDW_SCHEMA};"
  snowsql -a "$SNOWSQL_ACCOUNT" -u "$SNOWSQL_USER" -r "$SNOWSQL_ROLE" -w "$SNOWSQL_WAREHOUSE" -d "$SNOWSQL_DATABASE" -q \
    "SELECT \"url\" FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())) WHERE UPPER(\"name\") = UPPER('${APP_NAME}') LIMIT 1;"
fi
