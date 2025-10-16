# Admin Guide

## Prerequisites

- Python 3.11+
- Optional: `snowsql`
- Snowflake account with role capable of creating DB/SCHEMA/TABLE
- Keboola project (for orchestration)

## Provision Snowflake

1) Create roles/warehouse/db/schema (edit placeholders).
- Open `snowflake/00_schema.sql` and replace:
  - `<SNOWFLAKE_ACCOUNT>`, `<WAREHOUSE>`, `<DATABASE>`, `<STG_SCHEMA>`, `<EDW_SCHEMA>`, `<ROLE>`, `<USER>`
- Apply via snowsql:
  - `snowsql -a <SNOWFLAKE_ACCOUNT> -u <USER> -r <ROLE> -f snowflake/00_schema.sql`

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

- Edit env vars in `scripts/load_snowflake.sh`
- Run:
  - `bash scripts/load_snowflake.sh`
- This prints example COPY statements or runs COPY (uncomment to execute).

## Validate

- Run quality checks:
  - `snowsql ... -f snowflake/04_quality_checks.sql`
- Reasonable ranges:
  - Shipments: ~5,000–10,000; Exceptions: 6–9% of shipments
  - OTD: 80–95% depending on carriers/lanes
  - GM/Mile: typically USD $0.25–$0.60 (synthetic)

## Security

- Keep secrets out of repo. Use SNOWSQL env variables and Keboola project secrets.
- Use Snowflake roles/grants; limit writable schemas to STG/EDW as needed.

