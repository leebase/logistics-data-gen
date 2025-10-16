# User Guide

This guide explains how to use the scaffold to complete the assessment.

## What You Build

- Ingest `data/out/*.csv` into Snowflake using Keboola
- Transform STG data into curated EDW star schema
- Build a Power BI report with defined KPIs and visuals

## Steps

1) Generate data
- `make data` (or `bash scripts/bootstrap.sh` for first run)
- Review CSVs in `data/out/`

2) Keboola ingest
- Create a CSV extractor for the local (or uploaded) files
- Map each file to a Storage bucket and then to Snowflake STG tables via Snowflake Writer
- Use `keboola/README.md` and `keboola/config_sample.json` as a mapping guide

3) Keboola transform
- Create a Snowflake SQL transformation
- Use `keboola/transformations/sql/10_curate_edw.sql`
- Configure incremental processing and MERGE to EDW tables
- Handle late-arriving delivery updates by using UpdateDate and MERGE

4) Power BI model
- Connect to EDW tables
- Follow `powerbi/modeling_guide.md` to set relationships and calculation groups (optional)
- Paste measures from `powerbi/dax_measures.md`
- Build visuals per `powerbi/visual_spec.md`

## Expected Outcomes

- EDW curated star schema populated with dims/facts
- KPIs:
  - OTD%, OTIF%, GM/Mile, Tender Acceptance %, Avg Transit Days, Exception counts
- Visuals:
  - KPI tiles, Lane performance (combo), Exception heatmap, Drill-through page

## Tips

- Use UTC timestamps; TIMESTAMP_NTZ in Snowflake
- Ensure referential integrity: no orphan FactEvent/FactCost without FactShipment
- Validate DAX with small filters (Customer/Carrier/Lane)

