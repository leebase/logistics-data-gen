# Logistics BI Candidate Assessment Scaffold

This repository provides a complete, runnable scaffold for a logistics BI exercise. Candidates will:
- Generate synthetic but realistic logistics data (5k–10k shipments across ~6 months).
- Ingest it into Snowflake (via Keboola scaffolding) and curate EDW tables.
- Build a Power BI dashboard with KPIs and visuals.

Key deliverables:
- Data generator + CSV outputs.
- Snowflake DDL/DML and quality checks.
- Keboola configuration scaffolding and orchestration guidance.
- Power BI modeling and DAX measures.
- Automation (Makefile + scripts) and documentation.

## Quickstart

1) Bootstrap environment and generate data
- Requires Python 3.11+ and snowsql (optional for load).
- macOS/Linux:
  - `bash scripts/bootstrap.sh`
- Or run manually:
  - `python3 -m venv .venv && source .venv/bin/activate`
  - `python -m pip install --upgrade pip pyyaml`
  - `python data/generate_data.py --config data/config.yaml`

2) Inspect outputs
- CSVs are written to `data/out/`: `Dim*.csv`, `Fact*.csv`.

3) Snowflake setup (admin)
- Configure environment variables: see `snowflake/snowflakeInfo.md` and copy `config/.env.snowflake.example` to `.env.snowflake`.
- Create objects and grants: `make snowflake_ddl` (prints commands) or run `snowflake/00_schema.sql` and `snowflake/01_tables.sql` via snowsql.
- Load data using `scripts/load_snowflake.sh` (review and edit env vars first). Note: In this assessment, Keboola performs data loading; use the loader only for manual testing.

4) Keboola orchestration
- See `keboola/README.md` and `keboola/config_sample.json` for wiring extractors/writers and SQL transformations.
- Curate EDW with `keboola/transformations/sql/10_curate_edw.sql`.

5) Power BI
- Use `powerbi/modeling_guide.md`, `powerbi/dax_measures.md`, and `powerbi/visual_spec.md`.
- Build star schema and KPIs (OTD%, OTIF%, GM/Mile, Tender Acceptance %, Avg Transit Days, Exceptions).

## Repo Layout

- Code and scripts: `data/`, `scripts/`, `snowflake/`, `keboola/`, `powerbi/`.
- Docs and plans: root `architecture.md`, `requirements.md`, `projectplan.md`, `sprintplan.md`, and `docs/`.

## Tooling

- `make venv` — Create `.venv` and install deps.
- `make data` — Generate CSVs to `data/out/`.
- `make snowflake_ddl` — Print DDL guidance.
- `make load` — Example Snowflake load via snowsql.
- `make checks` — Run quality checks SQL (prints commands).
- `make clean` — Remove `.venv` and outputs.

## Secrets

- Do not commit credentials. Use environment variables and `<PLACEHOLDER>` patterns in SQL/scripts. See `docs/admin_guide.md` for details.
 - Snowflake env reference: `snowflake/snowflakeInfo.md`. Template: `config/.env.snowflake.example`.

## What the candidate must do

- Implement Keboola orchestration to ingest CSVs, map to Snowflake, run SQL transformations for curated EDW, and configure incremental MERGE.
- Build Power BI model and visuals per spec with working DAX measures.

See `docs/user_guide.md` and `docs/scoring_rubric.md` for expectations and scoring.
