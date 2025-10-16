Snowflake Environment Variables Reference

Purpose: This file documents the minimal set of environment variables used by scripts and worksheets in this repo to connect to Snowflake and select the correct database/schemas for STG and EDW.

Variables
- SNOWFLAKE_ACCOUNT: Your Snowflake account locator, e.g., xy12345.us-east-1
- SNOWFLAKE_USER: Username used for Snowflake connections
- SNOWFLAKE_ROLE: Role with required privileges (e.g., LOGISTICS_APP_ROLE)
- SNOWFLAKE_WAREHOUSE: Compute warehouse to use (e.g., LOGISTICS_WH)
- SNOWFLAKE_DATABASE: Database name (e.g., LOGISTICS_DB)
- SNOWFLAKE_STG_SCHEMA: Landing schema for STG (e.g., STG)
- SNOWFLAKE_EDW_SCHEMA: Curated schema for EDW (e.g., EDW)

Compatibility Aliases (used by scripts/load_snowflake.sh)
- SNOWSQL_ACCOUNT: Same as SNOWFLAKE_ACCOUNT
- SNOWSQL_USER: Same as SNOWFLAKE_USER
- SNOWSQL_ROLE: Same as SNOWFLAKE_ROLE
- SNOWSQL_WAREHOUSE: Same as SNOWFLAKE_WAREHOUSE
- SNOWSQL_DATABASE: Same as SNOWFLAKE_DATABASE
- SNOWSQL_STG_SCHEMA: Same as SNOWFLAKE_STG_SCHEMA

Notes
- Do not commit secrets (passwords, keys). Use local .env files or a secret manager.
- Keboola will store connection credentials in project secrets; match these values there.
# Snowflake Environment Reference

Purpose: Centralize the environment variables used by scripts and SQL in this repo to connect to Snowflake and select the correct database/schemas for STG and EDW.

## Required Variables

- `SNOWFLAKE_ACCOUNT` — Account locator, e.g., `xy12345.us-east-1`
- `SNOWFLAKE_USER` — Username for Snowflake connections
- `SNOWFLAKE_ROLE` — Role with required privileges (e.g., `LOGISTICS_APP_ROLE`)
- `SNOWFLAKE_WAREHOUSE` — Compute warehouse (e.g., `LOGISTICS_WH`)
- `SNOWFLAKE_DATABASE` — Database (e.g., `LOGISTICS_DB`)
- `SNOWFLAKE_STG_SCHEMA` — Landing schema for raw loads (e.g., `STG`)
- `SNOWFLAKE_EDW_SCHEMA` — Curated schema for EDW (e.g., `EDW`)

Compatibility aliases (used by `scripts/load_snowflake.sh`):
- `SNOWSQL_ACCOUNT` ← `SNOWFLAKE_ACCOUNT`
- `SNOWSQL_USER` ← `SNOWFLAKE_USER`
- `SNOWSQL_ROLE` ← `SNOWFLAKE_ROLE`
- `SNOWSQL_WAREHOUSE` ← `SNOWFLAKE_WAREHOUSE`
- `SNOWSQL_DATABASE` ← `SNOWFLAKE_DATABASE`
- `SNOWSQL_STG_SCHEMA` ← `SNOWFLAKE_STG_SCHEMA`

## Example .env File

Create a local `.env.snowflake` (do not commit), or copy the template at `config/.env.snowflake.example`.

```bash
SNOWFLAKE_ACCOUNT=xy12345.us-east-1
SNOWFLAKE_USER=keeboola_logistics_user
SNOWFLAKE_ROLE=LOGISTICS_APP_ROLE
SNOWFLAKE_WAREHOUSE=LOGISTICS_WH
SNOWFLAKE_DATABASE=LOGISTICS_DB
SNOWFLAKE_STG_SCHEMA=STG
SNOWFLAKE_EDW_SCHEMA=EDW

# Aliases for scripts/load_snowflake.sh
SNOWSQL_ACCOUNT=${SNOWFLAKE_ACCOUNT}
SNOWSQL_USER=${SNOWFLAKE_USER}
SNOWSQL_ROLE=${SNOWFLAKE_ROLE}
SNOWSQL_WAREHOUSE=${SNOWFLAKE_WAREHOUSE}
SNOWSQL_DATABASE=${SNOWFLAKE_DATABASE}
SNOWSQL_STG_SCHEMA=${SNOWFLAKE_STG_SCHEMA}

# Choose ONE auth method (examples, keep secrets out of git):
# SNOWSQL_PWD=...                    # Password auth
# SNOWSQL_PRIVATE_KEY_PATH=~/.snowsql/private_key.p8
# SNOWSQL_PRIVATE_KEY_PASSPHRASE=...
```

Load into your shell session:

```bash
set -a; source ./.env.snowflake; set +a
```

Verify:

```bash
echo "$SNOWFLAKE_ACCOUNT $SNOWFLAKE_DATABASE $SNOWFLAKE_STG_SCHEMA"
```

## Using with snowsql

You can reference the variables directly in snowsql commands:

```bash
snowsql \
  -a "$SNOWSQL_ACCOUNT" \
  -u "$SNOWSQL_USER" \
  -r "$SNOWSQL_ROLE" \
  -w "$SNOWSQL_WAREHOUSE" \
  -d "$SNOWSQL_DATABASE" \
  -q "USE SCHEMA ${SNOWSQL_DATABASE}.${SNOWSQL_STG_SCHEMA}; SHOW TABLES;"
```

## Keboola Mapping

Configure the Keboola Snowflake Writer with:
- Account: `SNOWFLAKE_ACCOUNT`
- Warehouse: `SNOWFLAKE_WAREHOUSE`
- Database: `SNOWFLAKE_DATABASE`
- Schema: `SNOWFLAKE_STG_SCHEMA`

SQL Transformations should target `SNOWFLAKE_EDW_SCHEMA` for curated EDW tables.

## Notes

- Do not commit secrets (passwords/keys). Use local `.env.snowflake` and/or a secret manager.
- The provided `config/.env.snowflake.example` is versioned for convenience; copy it locally and fill in your values.
