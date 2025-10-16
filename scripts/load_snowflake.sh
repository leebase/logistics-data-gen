#!/usr/bin/env bash
set -euo pipefail

# Example loader using snowsql. Review and edit placeholders first.
# Requires snowsql configured for keypair or password auth (do not hardcode secrets here).

: "${SNOWSQL_ACCOUNT:=<SNOWFLAKE_ACCOUNT>}"
: "${SNOWSQL_USER:=<USER>}"
: "${SNOWSQL_ROLE:=<ROLE>}"
: "${SNOWSQL_WAREHOUSE:=<WAREHOUSE>}"
: "${SNOWSQL_DATABASE:=<DATABASE>}"
: "${SNOWSQL_STG_SCHEMA:=<STG_SCHEMA>}"

echo "Account: ${SNOWSQL_ACCOUNT}"
echo "User: ${SNOWSQL_USER}"
echo "Role: ${SNOWSQL_ROLE}"
echo "Warehouse: ${SNOWSQL_WAREHOUSE}"
echo "Database: ${SNOWSQL_DATABASE}"
echo "STG Schema: ${SNOWSQL_STG_SCHEMA}"
echo

# Print COPY commands for manual execution (default).
echo "COPY command examples (manual):"
for t in DIM_CUSTOMER DIM_CARRIER DIM_EQUIPMENT DIM_LOCATION DIM_LANE DIM_DATE FACT_SHIPMENT FACT_EVENT FACT_COST; do
  echo "PUT file://$(pwd)/data/out/${t}.csv @${SNOWSQL_DATABASE}.${SNOWSQL_STG_SCHEMA}.STAGE_CSV AUTO_COMPRESS=TRUE;"
  echo "COPY INTO ${SNOWSQL_DATABASE}.${SNOWSQL_STG_SCHEMA}.${t} FROM @${SNOWSQL_DATABASE}.${SNOWSQL_STG_SCHEMA}.STAGE_CSV/${t}.csv.gz FILE_FORMAT=(FORMAT_NAME=${SNOWSQL_DATABASE}.${SNOWSQL_STG_SCHEMA}.CSV_FMT) ON_ERROR='ABORT_STATEMENT';"
done

echo
echo "To execute automatically, uncomment the loop below."

# Uncomment to execute PUT/COPY via snowsql (requires stage STAGE_CSV created):
# snowsql -a "${SNOWSQL_ACCOUNT}" -u "${SNOWSQL_USER}" -r "${SNOWSQL_ROLE}" -w "${SNOWSQL_WAREHOUSE}" -d "${SNOWSQL_DATABASE}" -q "
#   USE SCHEMA ${SNOWSQL_DATABASE}.${SNOWSQL_STG_SCHEMA};
#   CREATE OR REPLACE STAGE STAGE_CSV FILE_FORMAT = CSV_FMT;
# "
# for t in DIM_CUSTOMER DIM_CARRIER DIM_EQUIPMENT DIM_LOCATION DIM_LANE DIM_DATE FACT_SHIPMENT FACT_EVENT FACT_COST; do
#   snowsql -a "${SNOWSQL_ACCOUNT}" -u "${SNOWSQL_USER}" -r "${SNOWSQL_ROLE}" -w "${SNOWSQL_WAREHOUSE}" -d "${SNOWSQL_DATABASE}" -q "PUT file://$(pwd)/data/out/${t}.csv @${SNOWSQL_DATABASE}.${SNOWSQL_STG_SCHEMA}.STAGE_CSV AUTO_COMPRESS=TRUE;"
#   snowsql -a "${SNOWSQL_ACCOUNT}" -u "${SNOWSQL_USER}" -r "${SNOWSQL_ROLE}" -w "${SNOWSQL_WAREHOUSE}" -d "${SNOWSQL_DATABASE}" -q "COPY INTO ${SNOWSQL_DATABASE}.${SNOWSQL_STG_SCHEMA}.${t} FROM @${SNOWSQL_DATABASE}.${SNOWSQL_STG_SCHEMA}.STAGE_CSV/${t}.csv.gz FILE_FORMAT=(FORMAT_NAME=${SNOWSQL_DATABASE}.${SNOWSQL_STG_SCHEMA}.CSV_FMT) ON_ERROR='ABORT_STATEMENT';"
# done

