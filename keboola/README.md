# Keboola Configuration Guide

This scaffold explains how to wire Keboola components to ingest local CSVs into Snowflake STG and run SQL transformations to populate EDW.

## Components

- Extractor: CSV Files (or generic file extractor)
  - Source: Upload generated files from `data/out/`
  - Output: Storage bucket tables (e.g., `in.c-logistics`)
- Writer: Snowflake
  - Destination: `<DATABASE>.<STG_SCHEMA>` tables
- Transformation: Snowflake SQL
  - Script: `keboola/transformations/sql/10_curate_edw.sql`

## Mapping

Map each CSV to a Storage table and then to Snowflake:

- `DIM_CUSTOMER.csv` -> `DIM_CUSTOMER`
- `DIM_CARRIER.csv` -> `DIM_CARRIER`
- `DIM_EQUIPMENT.csv` -> `DIM_EQUIPMENT`
- `DIM_LOCATION.csv` -> `DIM_LOCATION`
- `DIM_LANE.csv` -> `DIM_LANE`
- `DIM_DATE.csv` -> `DIM_DATE`
- `FACT_SHIPMENT.csv` -> `FACT_SHIPMENT`
- `FACT_EVENT.csv` -> `FACT_EVENT`
- `FACT_COST.csv` -> `FACT_COST`

Schema in Snowflake should match `snowflake/01_tables.sql`.

## Transformations

Create a Snowflake transformation and paste `keboola/transformations/sql/10_curate_edw.sql`. Configure:
- Input: STG tables
- Output: EDW tables
- Run Order:
  1) Load STG dims
  2) Load STG facts
  3) Run transformation to EDW via MERGE patterns (or invoke MERGE SQLs)
- Incremental: set STG tables as full loads (overwrite or incremental append) and EDW as MERGE targets.

## Incremental & Late-Arriving

- Shipments may update (e.g., delivery_actual_ts). Use `update_date` to MERGE only newer records.
- Configure transformations to run MERGE statements from `snowflake/03_merge_upserts.sql` or embed MERGE logic.

## Credentials

- Configure Keboola Snowflake Writer with:
  - Account: `<SNOWFLAKE_ACCOUNT>`
  - Warehouse: `<WAREHOUSE>`
  - Database: `<DATABASE>`
  - Schema: `<STG_SCHEMA>`
  - User/Password: use Keboola project secrets

