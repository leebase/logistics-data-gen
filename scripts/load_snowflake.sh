#!/usr/bin/env bash
set -euo pipefail

# Parameter-driven Snowflake loader. Prints COPY commands by default; use --apply to execute.

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"

APPLY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    --env) set -a; source "$2"; set +a; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Auto-source .env.snowflake if present
if [[ -f "$root/.env.snowflake" ]]; then
  set -a; source "$root/.env.snowflake"; set +a
fi

STAGE_NAME="${STAGE_NAME:-STAGE_CSV}"

: "${SNOWSQL_ACCOUNT:?Set SNOWSQL_ACCOUNT or SNOWFLAKE_ACCOUNT in .env.snowflake}"
: "${SNOWSQL_USER:?Set SNOWSQL_USER or SNOWFLAKE_USER in .env.snowflake}"
: "${SNOWSQL_ROLE:=${SNOWFLAKE_ROLE:-LOGISTICS_APP_ROLE}}"
: "${SNOWSQL_WAREHOUSE:=${SNOWFLAKE_WAREHOUSE:-LOGISTICS_WH}}"
: "${SNOWSQL_DATABASE:=${SNOWFLAKE_DATABASE:-LOGISTICS_DB}}"
: "${SNOWSQL_STG_SCHEMA:=${SNOWFLAKE_STG_SCHEMA:-STG}}"

echo "Account: ${SNOWSQL_ACCOUNT}"
echo "User: ${SNOWSQL_USER}"
echo "Role: ${SNOWSQL_ROLE}"
echo "Warehouse: ${SNOWSQL_WAREHOUSE}"
echo "Database: ${SNOWSQL_DATABASE}"
echo "STG Schema: ${SNOWSQL_STG_SCHEMA}"
echo "Stage: ${STAGE_NAME}"
echo

echo "COPY command examples (manual):"
echo "PUT file://$(pwd)/data/out/*.csv @${SNOWSQL_DATABASE}.${SNOWSQL_STG_SCHEMA}.${STAGE_NAME} AUTO_COMPRESS=TRUE;"
for t in DIM_CUSTOMER DIM_CARRIER DIM_EQUIPMENT DIM_LOCATION DIM_LANE DIM_DATE FACT_SHIPMENT FACT_EVENT FACT_COST; do
  echo "PUT file://$(pwd)/data/out/${t}.csv @${SNOWSQL_DATABASE}.${SNOWSQL_STG_SCHEMA}.${STAGE_NAME} AUTO_COMPRESS=TRUE;"
  echo "COPY INTO ${SNOWSQL_DATABASE}.${SNOWSQL_STG_SCHEMA}.${t} FROM @${SNOWSQL_DATABASE}.${SNOWSQL_STG_SCHEMA}.${STAGE_NAME}/${t}.csv.gz FILE_FORMAT=(FORMAT_NAME=${SNOWSQL_DATABASE}.${SNOWSQL_STG_SCHEMA}.CSV_FMT) ON_ERROR='ABORT_STATEMENT';"
done

if [[ "$APPLY" -eq 1 ]]; then
  snowsql -a "${SNOWSQL_ACCOUNT}" -u "${SNOWSQL_USER}" -r "${SNOWSQL_ROLE}" -w "${SNOWSQL_WAREHOUSE}" -d "${SNOWSQL_DATABASE}" -q "
    USE SCHEMA ${SNOWSQL_DATABASE}.${SNOWSQL_STG_SCHEMA};
    CREATE OR REPLACE STAGE ${STAGE_NAME} FILE_FORMAT = CSV_FMT;
  "
  for t in DIM_CUSTOMER DIM_CARRIER DIM_EQUIPMENT DIM_LOCATION DIM_LANE DIM_DATE FACT_SHIPMENT FACT_EVENT FACT_COST; do
    snowsql -a "${SNOWSQL_ACCOUNT}" -u "${SNOWSQL_USER}" -r "${SNOWSQL_ROLE}" -w "${SNOWSQL_WAREHOUSE}" -d "${SNOWSQL_DATABASE}" -q "PUT file://$(pwd)/data/out/${t}.csv @${SNOWSQL_DATABASE}.${SNOWSQL_STG_SCHEMA}.${STAGE_NAME} AUTO_COMPRESS=TRUE;"
    snowsql -a "${SNOWSQL_ACCOUNT}" -u "${SNOWSQL_USER}" -r "${SNOWSQL_ROLE}" -w "${SNOWSQL_WAREHOUSE}" -d "${SNOWSQL_DATABASE}" -q "COPY INTO ${SNOWSQL_DATABASE}.${SNOWSQL_STG_SCHEMA}.${t} FROM @${SNOWSQL_DATABASE}.${SNOWSQL_STG_SCHEMA}.${STAGE_NAME}/${t}.csv.gz FILE_FORMAT=(FORMAT_NAME=${SNOWSQL_DATABASE}.${SNOWSQL_STG_SCHEMA}.CSV_FMT) ON_ERROR='ABORT_STATEMENT';"
  done
fi
