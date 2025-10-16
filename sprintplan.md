# Sprint Plan

Goal: Small, testable increments to enable recovery if context resets. Each story delivers a runnable artifact and includes a simple validation step.

## Sprint 1 (1 week) — Data Generation & Repo

- [x] Initialize repo, .gitignore, and remote
  - DoD: `git status` is clean on `main`; remote set
  - Test: `git log -1` shows initial scaffold commit

- [x] Bootstrap scripts and Makefile
  - DoD: `scripts/bootstrap.sh` creates venv and runs generator; Make targets print commands
  - Test: `bash scripts/bootstrap.sh` completes; `make data` prints and runs

- [x] Generator scaffolding and config
  - DoD: `data/generate_data.py` reads `data/config.yaml`
  - Test: `python data/generate_data.py --config data/config.yaml` exits 0

- [x] Dimension tables generation
  - DoD: DIM_CUSTOMER, DIM_CARRIER, DIM_EQUIPMENT, DIM_LOCATION, DIM_LANE, DIM_DATE CSVs emitted
  - Test: `ls data/out/DIM_*.csv` shows 6 files; headers match spec

- [x] Lane miles via Haversine and date dimension
  - DoD: `DIM_LANE.standard_miles` populated; `DIM_DATE` covers range
  - Test: `head -n 2 data/out/DIM_LANE.csv` shows non-zero miles

- [x] Weekly diesel curve and seasonality
  - DoD: Diesel prices influence fuel surcharge; EOM ramp alters distribution
  - Test: Compare shipments near EOM vs mid-month counts

- [x] FactShipment basic lifecycle
  - DoD: Tender→Pickup→AtDest→Delivered events present; statuses set
  - Test: `grep -c Delivered data/out/FACT_EVENT.csv` > 0

- [x] FactEvent and dwell/exception modeling
  - DoD: DwellStart/DwellEnd pairs for ~25%; Exceptions in 6–9%
  - Test: Count DwellStart vs DwellEnd rows ≈ equal; Exception ratio in range

- [x] FactCost base/fuel/accessorials
  - DoD: Base + Fuel for most; 10–15% accessorials
  - Test: `grep -c "Accessorial" data/out/FACT_COST.csv` within expected range

## Sprint 2 (1 week) — Snowflake, Keboola, Power BI

- [x] Snowflake DDL and file formats (00–01)
  - DoD: Scripts compile in Snowflake; schemas/tables created
  - Test: `snowsql -f snowflake/01_tables.sql` completes (with placeholders set)

- [x] Stages and COPY samples (02)
  - DoD: Internal stage created; PUT/COPY examples provided
  - Test: Review `scripts/load_snowflake.sh` outputs commands

- [x] MERGE templates for EDW (03)
  - DoD: MERGE upserts for dims/facts with UpdateDate semantics
  - Test: Run on a small sample; updates reflect latest `update_date`

- [x] EDW curation SQL for Keboola
  - DoD: `keboola/transformations/sql/10_curate_edw.sql` merges STG→EDW and recomputes flags
  - Test: Execute against STG; EDW populated with IsDeliveredOnTime/IsOTIF recalculated

- [x] Quality checks pack (04)
  - DoD: Daily counts, OTD bounds, orphan and FK checks
  - Test: `snowsql -f snowflake/04_quality_checks.sql` returns plausible results

- [x] Keboola scaffolding
  - DoD: README + sample config mapping CSVs→STG, transform step
  - Test: Import sample JSON and wire components in Keboola UI

- [x] Power BI modeling & DAX
  - DoD: Modeling guide, measures, visual spec included
  - Test: Paste measures; visuals return values on sample dataset

- [ ] End-to-end smoke test
  - DoD: Generate fresh data, load to Snowflake STG, run curation, open PBI model
  - Test: KPIs populated; OTD/OTIF/GM/Mile within expected ranges

### Estimation Notes
- Each story is 1–3 pts; sprint aims for 18–22 pts.
- Stories are independently testable and resumable after context resets.
