This repository is a ready-to-run assessment scaffold for a logistics BI exercise. It generates synthetic logistics data, provides Snowflake DDL/DML and quality checks, outlines Keboola orchestration scaffolding, and supplies Power BI modeling guidance with DAX measures. Automation scripts and documentation tie everything together to allow candidates to ingest/transform data into Snowflake and build a Power BI dashboard.

| Path                                      | Purpose |
|-------------------------------------------|---------|
| README.md                                 | Top-level overview, quickstart, and repo usage |
| architecture.md                           | System context, data flow diagrams, component responsibilities |
| requirements.md                           | Functional and non-functional requirements with acceptance criteria |
| projectplan.md                            | Project milestones, deliverables, dependencies, risks |
| sprintplan.md                             | Two-sprint plan with stories, DoD, and estimates |
| docs/admin_guide.md                       | Admin steps for Snowflake, environment, running scripts, validation |
| docs/user_guide.md                        | Candidate instructions for Keboola + Power BI usage and outcomes |
| docs/scoring_rubric.md                    | Scoring rubric for reviewers across ETL/SQL/Modeling/BI/Docs |
| powerbi/modeling_guide.md                 | Star schema relationships, DAX guidance, visuals, slicers, KPIs |
| powerbi/dax_measures.md                   | Final DAX measures for KPIs and helpers |
| powerbi/visual_spec.md                    | Power BI visual layout and interaction/props spec |
| snowflake/00_schema.sql                   | Warehouse/DB/schema/roles scaffolding and file formats |
| snowflake/01_tables.sql                   | DDL for dimensions and facts with appropriate types |
| snowflake/02_stages_and_pipes.sql         | Stages, sample COPY commands, optional Streams/Tasks (commented) |
| snowflake/03_merge_upserts.sql            | MERGE templates for idempotent incremental upserts |
| snowflake/04_quality_checks.sql           | Query pack for data quality checks |
| keboola/README.md                         | Keboola components and configuration mapping guide |
| keboola/config_sample.json                | Illustrative JSON scaffolding for Keboola components |
| keboola/transformations/sql/10_curate_edw.sql | SQL to curate EDW tables and compute flags |
| data/README.md                            | Dataset description, schema, distributions, volumes |
| data/generate_data.py                     | Python script to generate realistic synthetic CSVs |
| data/config.yaml                          | Tuning knobs for data generation (seed, volumes, rates) |
| data/out/.gitkeep                         | Placeholder to keep output directory in git |
| scripts/bootstrap.sh                      | Bootstrap local venv, install deps, run generator, next steps |
| scripts/load_snowflake.sh                 | Example snowsql loader with env vars and COPY commands |
| Makefile                                  | Phony targets for venv, data, snowflake DDL, load, checks, clean |

