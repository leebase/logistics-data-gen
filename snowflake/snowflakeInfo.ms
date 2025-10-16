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

