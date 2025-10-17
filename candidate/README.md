# ETL Interview: CSV → Snowflake via Keboola

Welcome! This exercise evaluates your ability to load flat files into Snowflake using Keboola, design typed target tables, and write clear SQL transforms with basic data quality checks.

We’ve pre-provisioned a Snowflake environment for you. Your goal is to:
- Use your own Keboola free trial to load the provided CSVs into pre-created RAW tables (VARCHAR columns).
- Create typed tables in MODEL and transform the RAW data into those tables.
- Add quality checks and a short README of your approach.

We do not provide tool-specific setup instructions for Keboola — discovering and configuring it is part of the assessment.

## Connection & Environment
- You will receive a unique candidate code (e.g., `C07`) and Snowflake credentials separately.
- Database: `ETL_INTERVIEW`
- Warehouse: `ETL_INTERVIEW_WH`
- Schemas (yours only):
  - RAW: `Cxx_RAW` (landing area, all VARCHAR; tables pre-created)
  - MODEL: `Cxx_MODEL` (you create typed tables & populate via SQL)
- Your Snowflake user defaults to the RAW schema; you can switch to MODEL as needed.

## Input Data
CSV files are available in this repository under `data/out/`:
- Dimensions: `DIM_CUSTOMER.csv`, `DIM_CARRIER.csv`, `DIM_EQUIPMENT.csv`, `DIM_LOCATION.csv`, `DIM_LANE.csv`, `DIM_DATE.csv`
- Facts: `FACT_SHIPMENT.csv`, `FACT_EVENT.csv`, `FACT_COST.csv`

RAW table names match these CSVs exactly and already exist in your `Cxx_RAW` schema with all columns as `VARCHAR`.

### Data Dictionary (key fields)
- `DIM_CUSTOMER`: `CUSTOMER_ID` (PK)
- `DIM_CARRIER`: `CARRIER_ID` (PK)
- `DIM_EQUIPMENT`: `EQUIPMENT_ID` (PK)
- `DIM_LOCATION`: `LOC_ID` (PK)
- `DIM_LANE`: `LANE_ID` (PK), `ORIGIN_LOC_ID`, `DEST_LOC_ID`
- `DIM_DATE`: `DATE_KEY` (PK, YYYYMMDD), `DATE`
- `FACT_SHIPMENT`: `(SHIPMENT_ID, LEG_ID)` composite key; FK-like references to dims (IDs above)
- `FACT_EVENT`: `(SHIPMENT_ID, EVENT_SEQ)`; references shipments
- `FACT_COST`: `SHIPMENT_ID`, `COST_TYPE`, `RATE_REF` (unique-ish); references shipments

## What You Need To Do
1) Ingest (Keboola required)
- Create a Keboola project (free trial) and configure a pipeline to load each CSV from `data/out/` into the corresponding table in your `Cxx_RAW` schema.
- Choose any reasonable mapping and load strategy (full replace is fine). Handle delimiter, header, quotes, and NULLs.

2) Model (SQL in Snowflake)
- Design and create typed target tables in `Cxx_MODEL` with appropriate data types and keys.
- Implement transformations from RAW to MODEL with explicit casting, trimming, deduping, and sensible key logic.
- Ensure your scripts are idempotent (re-runnable without creating duplicates or errors). MERGE or TRUNCATE+INSERT are both acceptable.

3) Quality Checks
- Provide simple QC queries to verify row counts, PK uniqueness, and basic FK coverage (e.g., shipments to dims).

## Deliverables (commit in this repo)
- `candidate/sql/03_model_ddl.sql`: CREATE TABLE statements for `Cxx_MODEL`.
- `candidate/sql/04_transform.sql`: RAW → MODEL transforms (idempotent).
- `candidate/sql/05_qc.sql`: QC queries (row counts, PK/FK checks, basic sanity).
- `candidate/README_SUBMISSION.md`: a short write-up covering:
  - Load strategy (full/incremental) and idempotency approach
  - Notable data quality handling (NULLs, whitespace, bad rows)
  - Any assumptions or trade-offs
  - How to re-run end-to-end

Note: Keep credentials out of code. If you use scripts to run SQL, read Snowflake connection info from environment variables or a local config file not committed to source control.

## Evaluation Criteria
- Ingestion correctness (35%): RAW tables loaded from all CSVs; row counts match; sensible delimiter/NULL/quote handling.
- Idempotency & reliability (25%): Re-running produces consistent results (no duplicates); clear approach to resets.
- Transform & typing quality (25%): Appropriate data types and key definitions; reasonable casts/joins/deduping; simple derived fields OK.
- Clarity & structure (15%): Organized SQL; readable; concise README of decisions and how to run.

## Getting Started
- You’ll receive a Snowflake connection card and your candidate code. Confirm you can log in and query `ETL_INTERVIEW.Cxx_RAW.DIM_CUSTOMER`.
- Build your Keboola pipeline to write into `ETL_INTERVIEW.Cxx_RAW` tables.
- Implement your SQL in the provided `candidate/sql/` files (update schema names to your `Cxx` code).
- Test idempotency by re-running your ingestion and transforms.

Good luck!

