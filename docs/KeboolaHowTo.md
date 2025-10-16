# Keboola How‑To: Load Logistics CSVs into Snowflake

---------- Pre setup ------------------
  What you need to do now

  - Set the password (outside of git) for KEBOOLA_LOGISTICS_USER:
      - Connect as ACCOUNTADMIN (leebase with admin role) and run:
          - ALTER USER KEBOOLA_LOGISTICS_USER SET PASSWORD = '<STRONG_PASSWORD>';
  - Or configure key-pair auth:
      - ALTER USER KEBOOLA_LOGISTICS_USER SET RSA_PUBLIC_KEY = '<PEM_BASE64>';

  Keboola configuration

  - Snowflake Writer connection:
      - Account: YVCGSJW-AF47375
      - User: KEBOOLA_LOGISTICS_USER
      - Role: LOGISTICS_APP_ROLE
      - Warehouse: LOGISTICS_WH
      - Database: LOGISTICS_DB
      - Schema: STG
  - Then follow docs/KeboolaHowTo.md to upload CSVs to Storage, run the Writer, and execute the EDW transformation.

--------------------------------------------

This guide walks you through setting up a fresh Keboola project and wiring it to load the generated CSVs (`data/out/*.csv`) into your Snowflake STG schema, then running a SQL transformation to curate EDW tables.

## Prerequisites

- You have generated the dataset locally:
  - `make data` (CSV outputs in `data/out/`)
- Snowflake connection details you control (no secrets committed):
  - Account locator, user (or keypair), role, warehouse, database (`LOGISTICS_DB`), schemas (`STG`, `EDW`)
  - Use `config/.env.snowflake.example` as a template and see `snowflake/snowflakeInfo.md`.
- Snowflake objects exist (no data yet):
  - Run `snowflake/00_schema.sql` and `snowflake/01_tables.sql` with your placeholders.

## 1) Create a Keboola Account and Project

1. Sign up or log in to Keboola Connection.
2. Create a new project (trial is fine). Choose a region close to your Snowflake region.
3. (Optional) Add teammates; keep Owner/Admin access to yourself.

Notes:
- Keboola project “Storage” is separate from your Snowflake. You’ll configure a Snowflake Writer to your Snowflake account.

## 2) Upload CSVs to Keboola Storage

We’ll upload local CSVs into a Storage bucket `in.c-logistics`.

1. In Keboola, go to Storage → Buckets → Create new → `in.c-logistics` (Input, public name `logistics`).
2. For each file in `data/out/` (DIM_* and FACT_*):
   - Click “New Table” → “From file upload”.
   - Choose the CSV and let Keboola detect the header.
   - Table name must match the file name without extension (e.g., `DIM_CUSTOMER`).
   - Set primary keys if known (recommended):
     - `DIM_*`: the ID column, e.g., `customer_id`, `carrier_id`...
     - `FACT_SHIPMENT`: `shipment_id, leg_id`
     - `FACT_EVENT`: `shipment_id, event_seq`
     - `FACT_COST`: `shipment_id, cost_type, rate_ref`
   - Confirm. Repeat for all CSVs.

Tip: You can re-upload (overwrite) tables later if you regenerate data.

## 3) Configure Snowflake Writer (to STG)

1. Components → Add Component → “Snowflake Writer” (`keboola.wr-db-snowflake`).
2. Set connection parameters to your Snowflake (not Keboola’s backend):
   - Account: `<SNOWFLAKE_ACCOUNT>`
   - Warehouse: `LOGISTICS_WH`
   - Database: `LOGISTICS_DB`
   - Schema: `STG`
   - User / Authentication (password or keypair)
3. In the Writer’s “Tables” tab, add mappings:
   - Source: `in.c-logistics.DIM_CUSTOMER` → Destination: `DIM_CUSTOMER`
   - Repeat for every DIM_* and FACT_* table.
4. Options:
   - “Create tables” enabled (first run) so Writer creates STG tables if missing.
   - “Incremental load” OFF for first load. You may later enable “Incremental” with PKs.
5. Save configuration.

Run the Writer job and confirm it finishes successfully.

## 4) Add SQL Transformation (STG → EDW)

Use the curated SQL provided in this repo to MERGE from STG into EDW with recalculated flags.

1. Components → Add Component → “Snowflake Transformation”.
2. Connection: Point to the same Snowflake database/warehouse as the Writer.
3. Add a SQL script step. Paste contents of `keboola/transformations/sql/10_curate_edw.sql`.
   - Replace placeholders in the script header with your names if needed:
     - `<DATABASE>` → `LOGISTICS_DB`
     - `<STG_SCHEMA>` → `STG`
     - `<EDW_SCHEMA>` → `EDW`
4. Inputs (read): Select all STG tables as inputs (DIM_* and FACT_*).
5. Outputs (write): Select all EDW tables (DIM_* and FACT_*) as outputs.
6. Save, then run the transformation.

Expected: EDW tables are upserted via MERGE; IsDeliveredOnTime and IsOTIF are (re)computed with a 60‑minute grace.

## 5) Orchestrate (Optional but Recommended)

Create an Orchestration to run loads in order whenever you refresh data.

1. Orchestrations → New Orchestration “Logistics EDW Refresh”.
2. Tasks (in order):
   - Snowflake Writer (STG load)
   - Snowflake Transformation (STG → EDW curate)
3. Save and “Run”. Later, schedule it as needed.

## 6) Incremental & Late‑Arriving Updates

- Writer: Enable “Incremental” on tables and set PKs to let Keboola send only changed rows.
- Transform: Our MERGE SQLs (EDW) already use `update_date` to update only newer records.
- Late-arriving delivery events: Re-running the pipeline will update shipments where `delivery_actual_ts` changed.

## 7) Validate Before Power BI

- Run `snowflake/05_visual_validation.sql` in Snowflake to reproduce KPI values and visual summaries.
- Key checks: OTD rates, GM/Mile YTD, Tender Acceptance %, Avg Transit Days, Exceptions by Customer.

## Troubleshooting

- Writer fails to create tables: Ensure `LOGISTICS_APP_ROLE` has `CREATE TABLE` on `LOGISTICS_DB.STG`.
- Timestamp issues: All timestamps are UTC ISO-8601; STG types are `TIMESTAMP_NTZ`. Verify CSV headers present.
- Missing FKs or orphans: Run `snowflake/04_quality_checks.sql` to identify and fix mapping issues.

## References

- Repo: `keboola/README.md`, `keboola/config_sample.json`
- Snowflake env: `snowflake/snowflakeInfo.md`, `config/.env.snowflake.example`
- Curate SQL: `keboola/transformations/sql/10_curate_edw.sql`
- Validation SQL: `snowflake/05_visual_validation.sql`

