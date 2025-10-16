# Project Plan

## Milestones & Master Checklist

- [x] Repository Scaffold
  - [x] MANIFEST, README, architecture/requirements docs
  - [x] Makefile + scripts (`bootstrap.sh`, `load_snowflake.sh`)
  - [x] Data generator + config (`data/generate_data.py`, `data/config.yaml`)
  - [x] Snowflake SQL set (00–04)
  - [x] Keboola scaffolding (README, sample config, transform SQL)
  - [x] Power BI docs (modeling, DAX, visual spec)
  - [x] Initialize git, add .gitignore, set remote

- [ ] Data Generation Validation & Tuning
  - [ ] Run `make data` and confirm 5k–10k shipments across ~6 months
  - [ ] Inspect exceptions (6–9%), OTD (80–95%), GM/Mile (0.25–0.60)
  - [ ] Adjust knobs in `data/config.yaml` if outside ranges

- [ ] Snowflake Environment & Load
  - [ ] Apply `snowflake/00_schema.sql` and `01_tables.sql`
  - [ ] Create stage and load CSVs (manual PUT/COPY or script)
  - [ ] Run MERGE templates (`03_merge_upserts.sql`) to EDW
  - [ ] Execute quality checks (`04_quality_checks.sql`) and review results

- [ ] Keboola Orchestration
  - [ ] Create CSV extractor and Storage bucket mapping
  - [ ] Configure Snowflake writer to STG tables
  - [ ] Add SQL transformation using `keboola/transformations/sql/10_curate_edw.sql`
  - [ ] Enable incremental runs and handle late-arriving updates

- [ ] Power BI Report Build
  - [ ] Import EDW tables and set relationships
  - [ ] Add DAX measures and What-If parameters
  - [ ] Build KPI tiles, lane performance, exception heatmap, drill page
  - [ ] Validate visuals with slicers and spot-check numbers

- [ ] Finalization
  - [ ] Update Admin/User guides with any environment-specific notes
  - [ ] (Optional) Archive a sample dataset (commit excluded) and screenshots
  - [ ] Tag release `v0.1.0` and record summary

## Deliverables

- Complete repo with generated data, SQLs, scripts, and documentation as listed in MANIFEST.

## Dependencies

- Python 3.11+, snowsql (optional), Snowflake account, Power BI Desktop/Service, Keboola project.

## Risks

- Data realism vs. complexity: mitigate with curated distributions and seed.
- Environment differences: mitigate with scripts and clear instructions.
- Volume/time balance: default to ~8k shipments over 6 months, configurable.
