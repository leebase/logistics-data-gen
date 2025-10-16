#!/usr/bin/env bash
set -euo pipefail

# Setup Snowflake environment (Option A) using repo SQL files.
# - Renders placeholders in snowflake/00_schema.sql and 01_tables.sql
# - Dry-run prints snowsql commands; use --apply to execute them.

here="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$here/.." && pwd)"

env_file="${ENV_FILE:-$repo_root/.env.snowflake}"
apply=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) apply=1; shift ;;
    --env) env_file="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ -f "$env_file" ]]; then
  # shellcheck disable=SC1090
  set -a; source "$env_file"; set +a
  echo "Loaded env from $env_file"
else
  echo "Note: env file $env_file not found. Using current environment variables." >&2
fi

# Defaults if not provided
WAREHOUSE=${WAREHOUSE:-${SNOWFLAKE_WAREHOUSE:-LOGISTICS_WH}}
DATABASE=${DATABASE:-${SNOWFLAKE_DATABASE:-LOGISTICS_DB}}
STG_SCHEMA=${STG_SCHEMA:-${SNOWFLAKE_STG_SCHEMA:-STG}}
EDW_SCHEMA=${EDW_SCHEMA:-${SNOWFLAKE_EDW_SCHEMA:-EDW}}

ACCOUNT=${SNOWSQL_ACCOUNT:-${SNOWFLAKE_ACCOUNT:-}}
USER=${SNOWSQL_USER:-${SNOWFLAKE_USER:-}}
ROLE=${SNOWSQL_ROLE:-${SNOWFLAKE_ROLE:-ACCOUNTADMIN}}
BOOTSTRAP_ROLE=${SNOWSQL_BOOTSTRAP_ROLE:-${BOOTSTRAP_ROLE:-ACCOUNTADMIN}}
WAREHOUSE_CONN=${SNOWSQL_WAREHOUSE:-$WAREHOUSE}
DATABASE_CONN=${SNOWSQL_DATABASE:-$DATABASE}
AUTHENTICATOR=${SNOWSQL_AUTHENTICATOR:-${AUTHENTICATOR:-}}

if [[ -z "${ACCOUNT}" || -z "${USER}" ]]; then
  echo "ERROR: Missing SNOWFLAKE account/user. Set SNOWFLAKE_ACCOUNT and SNOWFLAKE_USER (or SNOWSQL_* aliases) in $env_file." >&2
  exit 1
fi

gen_dir="$repo_root/snowflake/.generated"
mkdir -p "$gen_dir"

render() {
  in="$1"; out="$2"
  sed -e "s/<WAREHOUSE>/$WAREHOUSE/g" \
      -e "s/<DATABASE>/$DATABASE/g" \
      -e "s/<STG_SCHEMA>/$STG_SCHEMA/g" \
      -e "s/<EDW_SCHEMA>/$EDW_SCHEMA/g" \
      "$in" > "$out"
}

render "$repo_root/snowflake/00_schema.sql" "$gen_dir/00_schema_resolved.sql"
render "$repo_root/snowflake/01_tables.sql" "$gen_dir/01_tables_resolved.sql"

# Roles & user
APP_ROLE=${SNOWFLAKE_APP_ROLE:-${APP_ROLE:-LOGISTICS_APP_ROLE}}
APP_USER=${SNOWFLAKE_APP_USER:-${APP_USER:-KEBOOLA_LOGISTICS_USER}}
sed -e "s/<WAREHOUSE>/$WAREHOUSE/g" \
    -e "s/<DATABASE>/$DATABASE/g" \
    -e "s/<STG_SCHEMA>/$STG_SCHEMA/g" \
    -e "s/<EDW_SCHEMA>/$EDW_SCHEMA/g" \
    -e "s/<APP_ROLE>/$APP_ROLE/g" \
    -e "s/<APP_USER>/$APP_USER/g" \
    "$repo_root/snowflake/00_roles_and_users.sql" > "$gen_dir/00_roles_and_users_resolved.sql"

echo "--- Context ---"
echo "Account: $ACCOUNT"
echo "User:    $USER"
echo "Role:    $BOOTSTRAP_ROLE (bootstrap)"
echo "WH:      $WAREHOUSE_CONN"
echo "DB:      $DATABASE_CONN"
echo "Schemas: STG=$STG_SCHEMA, EDW=$EDW_SCHEMA"
echo "Generated SQL in $gen_dir"

base_login=(snowsql -a "$ACCOUNT" -u "$USER" -r "$BOOTSTRAP_ROLE")
if [[ -n "$AUTHENTICATOR" ]]; then
  base_login+=( -o "authenticator=$AUTHENTICATOR" )
fi

# For bootstrap (00), avoid selecting non-existent DB/WH
cmd_schema=("${base_login[@]}" -f "$gen_dir/00_schema_resolved.sql")

# For tables (01), set DB/WH context created by 00 step
cmd_tables=("${base_login[@]}" -w "$WAREHOUSE_CONN" -d "$DATABASE_CONN" -f "$gen_dir/01_tables_resolved.sql")

printf "\nDry-run commands:\n"
printf ' %q' "${cmd_schema[@]}"; printf "\n"
printf ' %q' "${cmd_tables[@]}"; printf "\n"
printf ' %q' "${base_login[@]}" -f "$gen_dir/00_roles_and_users_resolved.sql"; printf "\n"

if [[ "$apply" -eq 1 ]]; then
  if ! command -v snowsql >/dev/null 2>&1; then
    echo "ERROR: snowsql not found in PATH. Install SnowSQL first." >&2
    exit 1
  fi
  echo "\nApplying 00_schema_resolved.sql ..."
  "${cmd_schema[@]}"
  echo "Applying 01_tables_resolved.sql ..."
  "${cmd_tables[@]}"
  echo "Applying 00_roles_and_users_resolved.sql ..."
  "${base_login[@]}" -f "$gen_dir/00_roles_and_users_resolved.sql"
  echo "Done. Schemas and tables created."
else
  echo "\nNote: This was a dry-run. Re-run with --apply to execute the commands."
fi
