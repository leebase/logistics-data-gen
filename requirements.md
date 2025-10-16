# Requirements

## Functional

- Data Generation
  - Generate 5,000–10,000 shipments across ~6 months (configurable).
  - Include dims: Customer, Carrier, Equipment, Location, Lane, Date.
  - Facts: Shipment (leg grain), Event, Cost.
  - UTC timestamps; weekly diesel price curve influencing fuel surcharge.
  - Exception rates 6–9%; dwell with lognormal distribution; carrier score tier affects OTD variance and dwell.

- Snowflake
  - DDL for warehouse, db, schemas, roles, file formats.
  - Tables for dims/facts with LoadDate and UpdateDate.
  - MERGE patterns using natural keys and timestamps for idempotency and incremental loads.
  - Quality checks: daily counts, OTD bounds, orphan events, invalid FKs.

- Keboola
  - Scaffold to ingest `data/out/*.csv` to Snowflake STG.
  - SQL transformations to curate EDW and compute `IsDeliveredOnTime`, `IsInFull`, `IsOTIF`.
  - Configure incremental loads, late-arriving updates as MERGE.

- Power BI
  - Star schema with relationships as per dims/facts.
  - DAX for OTD%, OTIF%, GM/Mile, Tender Acceptance %, Avg Transit Days, Exception counts.
  - Visual spec: KPI cards, lane performance combo chart, exception heatmap, drill-through page.

## Non-Functional

- Deterministic RNG with seed; idempotent generation (same seed -> same outputs).
- Clarity and maintainability: type hints, small functions, PEP 8.
- Security: no secrets in code; use placeholders and env vars.
- Portability: minimal dependencies (PyYAML only).

## Acceptance Criteria

- Running `make data` produces 8k±2k shipments across 6 months by default.
- Snowflake DDL executes successfully; tables created with correct columns.
- Sample COPY statements load CSVs into STG; MERGE templates upsert to EDW.
- Quality checks return plausible results (no orphan events; FK validity).
- Power BI measures compute correctly on curated EDW tables.
- Documentation enables a candidate to complete the exercise end-to-end.

