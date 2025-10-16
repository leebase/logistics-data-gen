# Project Plan

## Milestones

1) Repository Scaffold (Day 1–2)
- Structure, docs, Makefile, scripts
- Data generator skeleton and config

2) Data Generation Complete (Day 3–4)
- All dims and facts with realistic distributions
- Determinism via seed; CSVs emitted

3) Snowflake Setup (Day 5)
- DDL for roles/warehouse/db/schemas/tables/file formats
- MERGE templates and quality checks

4) Keboola Scaffolding (Day 6)
- Config sample + README, SQL transformation for EDW curation

5) Power BI Guidance (Day 7)
- Modeling guide, DAX measures, visual spec

6) Validation & Polish (Day 8)
- Run generator, proof load, sample checks, finalize docs

## Deliverables

- Complete repo with generated data, SQLs, scripts, and documentation as listed in MANIFEST.

## Dependencies

- Python 3.11+, snowsql (optional), Snowflake account, Power BI Desktop/Service, Keboola project.

## Risks

- Data realism vs. complexity: mitigate with curated distributions and seed.
- Environment differences: mitigate with scripts and clear instructions.
- Volume/time balance: default to ~8k shipments over 6 months, configurable.

