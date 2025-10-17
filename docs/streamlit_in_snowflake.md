# Streamlit in Snowflake — Logistics Dashboard

This app mirrors the Power BI KPIs/visuals (OTD, OTIF, GM/Mile, Tender Acceptance, Avg Transit Days, Lane performance, Exception heatmap, drill table) and runs natively inside Snowflake using Streamlit in Snowflake.

## Files
- `streamlit/app.py` — the Streamlit app (uses Snowpark and SQL)
- `snowflake/06_streamlit.sql` — SQL to stage code and create the Streamlit object
- `scripts/deploy_streamlit.sh` — convenience script to upload and create the app

## Prerequisites
- Snowflake objects created (warehouse, database, schemas, tables).
- EDW tables populated (via Keboola transformation or manual load).
- `.env.snowflake` configured (see `snowflake/snowflakeInfo.md`).

## Local Development

- Install dependencies:
  - `python -m pip install -r requirements-dev.txt`
- Export env (or copy `.env.snowflake`):
  - `set -a; source ./.env.snowflake; set +a`
- Run locally:
  - `./scripts/run_streamlit_local.sh`

Notes:
- The app will build a Snowpark session locally using your `.env.snowflake` values.
- Keep libraries to those available in Snowflake’s Streamlit runtime (streamlit, pandas, altair, snowflake-snowpark-python).

## Deploy (CLI)

- Upload code and create the app:
  - `./scripts/deploy_streamlit.sh`  (uses `.env.snowflake`)
  - Optional overrides: `--stage APP_CODE --name LOGISTICS_DASH --env ./my.snowflake.env`
- The script will print the Streamlit URL. Click to open the app.

## Deploy (SQL Worksheet)

1) Create a stage and upload code:
- `CREATE OR REPLACE STAGE EDW.APP_CODE;`
- `PUT file://streamlit/app.py @LOGISTICS_DB.EDW.APP_CODE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;`

2) Create the app:
- `CREATE OR REPLACE STREAMLIT LOGISTICS_DASH FROM @LOGISTICS_DB.EDW.APP_CODE MAIN_FILE='app.py' QUERY_WAREHOUSE='LOGISTICS_WH';`
- `SELECT SYSTEM$SHOW_STREAMLIT_URL('LOGISTICS_DASH');`

## Configuration
- App reads database/schema from the active session; override via env vars `STREAMLIT_EDW_DATABASE` and `STREAMLIT_EDW_SCHEMA` if desired.
- Filters and parameters are interactive in the sidebar (Grace Minutes, GM/Mile target, date range, dimension filters).

## Notes
- The app uses SQL queries similar to `snowflake/05_visual_validation.sql` to compute KPIs server-side.
- For large datasets, adjust limits in queries (e.g., lane list and drill table LIMITs).
