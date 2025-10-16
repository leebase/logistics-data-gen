# Architecture

This assessment spans synthetic data generation, ingestion into Snowflake (optionally via Keboola), curation into an EDW, and visualization in Power BI.

## System Context

- Data Generator: Creates realistic logistics CSVs (facts/dims) with UTC timestamps.
- Storage: Local filesystem `data/out/*.csv` (source for Keboola extractors or direct Snowflake COPY).
- Snowflake: Landing/STG schemas for raw CSVs and EDW schema for curated star model.
- Keboola: Orchestrates ingest and SQL transformations, incremental MERGE patterns.
- Power BI: Connects to curated EDW tables and computes KPIs.

## Data Flow

```mermaid
flowchart LR
    A[Data Generator\n(data/generate_data.py)] -->|CSV files| B[Local Filesystem\n(data/out/*.csv)]
    B -->|Keboola Extractors| C[Keboola Storage]
    C -->|Snowflake Writer| D[(Snowflake STG)]
    D -->|SQL Transformations| E[(Snowflake EDW)]
    E -->|Direct Query/Import| F[[Power BI Model]]
    F --> G[Dashboards & KPIs]
```

## Component Responsibilities

- Generator
  - Produce dims: Customer, Carrier, Equipment, Location, Lane, Date
  - Produce facts: Shipment (leg grain), Event, Cost
  - Ensure deterministic outputs via seed; weekly diesel curve; seasonality; dwell and exceptions
  - Columns: see `requirements.md` and `data/README.md`

- Snowflake
  - Create roles/warehouse/db/schema, file formats
  - Create STG and EDW tables
  - Provide MERGE-based upserts for incremental loads, LoadDate/UpdateDate patterns
  - Provide quality checks

- Keboola
  - Configure extractors/writers mapping CSVs to STG tables
  - Run SQL transformations to normalize/curate EDW tables and compute flags IsDeliveredOnTime, IsOTIF
  - Configure incremental and late-arriving updates (MERGE)

- Power BI
  - Build star schema: facts to dims
  - Implement DAX for OTD%, OTIF%, GM/Mile, Tender Acceptance %, Avg Transit Days, Exception counts
  - Create visuals: KPI tiles, lane performance combo, exception heatmap, drill page

## Environments & Security

- All credentials are placeholders; use env vars and secret managers.
- Timestamps are UTC (TIMESTAMP_NTZ in Snowflake).
- Idempotent/incremental: use MERGE and load/update timestamps.

