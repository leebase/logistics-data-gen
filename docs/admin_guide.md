# Admin Guide

## Prerequisites

- Python 3.11+
- Optional: `snowsql`
- Snowflake account with role capable of creating DB/SCHEMA/TABLE
- Keboola project (for orchestration)

## Provision Snowflake

### Environment Variables

- Copy `config/.env.snowflake.example` to `.env.snowflake` and fill your account details.
- Reference: `snowflake/snowflakeInfo.md` for variable descriptions and snowsql usage.
- Optionally export for your shell session:
  - `set -a; source ./.env.snowflake; set +a`

1) Create roles/warehouse/db/schema (edit placeholders).
- Open `snowflake/00_schema.sql` and replace:
  - `<SNOWFLAKE_ACCOUNT>`, `<WAREHOUSE>`, `<DATABASE>`, `<STG_SCHEMA>`, `<EDW_SCHEMA>`, `<ROLE>`, `<USER>`
- Apply via snowsql:
  - `snowsql -a <SNOWFLAKE_ACCOUNT> -u <USER> -r <ROLE> -f snowflake/00_schema.sql`

Or run the parameterized helper script (recommended):
- One‑shot setup using `.env.snowflake` values:
  - `./scripts/setup_snowflake_option_a.sh --apply`
- Flags to override at runtime (optional):
  - `--warehouse LOGISTICS_WH --database LOGISTICS_DB --stg STG --edw EDW --app-role LOGISTICS_APP_ROLE --app-user KEBOOLA_LOGISTICS_USER --authenticator externalbrowser`

2) Create tables and file formats:
- `snowsql ... -f snowflake/01_tables.sql`

3) (Optional) Create stages and review COPY commands:
- `snowsql ... -f snowflake/02_stages_and_pipes.sql`

## Generate Data

- Bootstrap:
  - `bash scripts/bootstrap.sh`
- Or run:
  - `make venv`
  - `make data`

Outputs are in `data/out/`.

## Load Data

- Loader script (manual testing only; Keboola should load data in the assessment):
  - Dry run (print commands): `./scripts/load_snowflake.sh`
  - Execute: `./scripts/load_snowflake.sh --apply`
  - Optionally pass a custom env file: `./scripts/load_snowflake.sh --env ./my.snowflake.env --apply`

## Validate

- Run quality checks:
  - `snowsql ... -f snowflake/04_quality_checks.sql`
- Reasonable ranges:
  - Shipments: ~5,000–10,000; Exceptions: 6–9% of shipments
  - OTD: 80–95% depending on carriers/lanes
  - GM/Mile: typically USD $0.25–$0.60 (synthetic)

### Normalize EDW Names (if needed)
If loads created quoted-lowercase tables/columns (e.g., `"dim_customer"."name"`), you can normalize to canonical uppercase (DIM_CUSTOMER.NAME) using:
- `snowflake/99_normalize_edw_names.sql` — run block-by-block in a worksheet. It renames quoted columns to uppercase and, where safe, renames quoted-lower tables to uppercase. Review counts before altering.
Alternatively, keep mixed case — the Streamlit app now handles uppercase tables with quoted-lower columns ("mixed" variant) automatically.

## Security

- Keep secrets out of repo. Use SNOWSQL env variables and Keboola project secrets.
- Use Snowflake roles/grants; limit writable schemas to STG/EDW as needed.
