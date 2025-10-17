# Using Codex CLI Effectively: A Practical Narrative From Prompt → Scaffold → Snowflake + Streamlit

This guide documents exactly how we used Codex CLI to go from a tight prompt to a working logistics analytics app on Snowflake with a Streamlit dashboard. It’s written for engineers who want a repeatable way to drive an agent productively from the command line without wasting cycles.

## 1) Start With A Strong, Specific Prompt

Codex (and ChatGPT) produce the best results when you declare scope, outputs, and acceptance in one message. We began by asking for a complete scaffold and explicit files (including every .md we wanted):

```text
You are a senior solutions engineer tasked with generating a complete, runnable project scaffold for a logistics BI candidate assessment.
High-Level Requirements …
Output Format (MANDATORY): Return a multi-file response using this exact structure:
  - MANIFEST.md
  - README.md
  - architecture.md
  - requirements.md
  - projectplan.md
  - sprintplan.md
  - docs/admin_guide.md
  - docs/user_guide.md
  - docs/scoring_rubric.md
  - docs/KeboolaHowTo.md
  - docs/streamlit_in_snowflake.md
  - powerbi/* (guides)
  - snowflake/* (DDL, merges, checks)
  - keboola/* (README, config, SQL)
  - data/* (generator + config)
  - scripts/* (bootstrap, load, deploy)
  - Makefile
Design Details … (schema, KPIs, diesel curve, seasonality, etc.)
```

Codex then generated the entire scaffold with each markdown and SQL/script file in place.

## 2) Write Files To The Repo (apply_patch) And Commit Frequently

In Codex CLI, we asked the agent to write files using `apply_patch` so the scaffold exists on disk, not just in chat. We committed in small batches. The core docs produced were:

- `MANIFEST.md`
- `README.md`
- `architecture.md`
- `requirements.md`
- `projectplan.md`
- `sprintplan.md`
- `docs/admin_guide.md`
- `docs/user_guide.md`
- `docs/scoring_rubric.md`
- `docs/KeboolaHowTo.md`
- `docs/streamlit_in_snowflake.md`

This ensured anyone cloning the repo sees structure and next actions immediately.

## 3) Parameterize Snowflake Setup (Zero Clicks Later)

We added helper scripts that render and apply Snowflake DDL with your names, not placeholders:

- `scripts/setup_snowflake_option_a.sh` → creates `LOGISTICS_WH`, `LOGISTICS_DB`, schemas `STG`, `EDW`, file formats, and an app role/user.
- `snowflake/00_schema.sql` + `snowflake/01_tables.sql` → bootstrap tables in both STG and EDW.
- `snowflake/00_roles_and_users.sql` → `LOGISTICS_APP_ROLE`, `KEBOOLA_LOGISTICS_USER`, grants on STG/EDW, and Streamlit privileges.

Commands (worksheet or CLI):

```bash
./scripts/setup_snowflake_option_a.sh --apply
```

Tips:
- Bootstrap with `ACCOUNTADMIN`; run app workloads later with the app role.
- Keep credentials out of git. Use `.env.snowflake` locally; the example lives at `config/.env.snowflake.example`.

## 4) Generate Data, Load STG/EDW, And Validate With SQL

- Generate: `make data` → CSVs to `data/out/*.csv`.
- Load (example SnowSQL): `./scripts/load_snowflake.sh --apply` → STG.
- Curate (MERGE): run `keboola/transformations/sql/10_curate_edw.sql` (or `snowflake/03_merge_upserts.sql`) into EDW.
- Validate with a single pack: `snowflake/dashboard_test.sql` (added for fast, UI‑free checks).

The test pack auto‑derives a valid date window and reproduces the dashboard KPIs and visuals via SQL.

## 5) Build + Deploy The Streamlit Dashboard

We kept the Streamlit app simple and Snowflake‑idiomatic (`streamlit/app.py`):

- Uses Snowpark inside Snowflake (get_active_session).
- Computes OTD/OTIF with `DATEADD` for grace minutes (never multiply INTERVALs).
- Adds a diagnostic expander that shows EDW counts and min/max delivery dates.
- Parses timestamps robustly (TRY_TO_TIMESTAMP_NTZ) so it works even if CSVs ever import as strings.

Deploy to Snowflake:

```bash
./scripts/deploy_streamlit.sh
# or manually:
snowsql -a $SNOWSQL_ACCOUNT -u $SNOWSQL_USER -r ACCOUNTADMIN -w $SNOWSQL_WAREHOUSE -d $SNOWSQL_DATABASE \
  -q "PUT file://$(pwd)/streamlit/app.py @LOGISTICS_DB.EDW.APP_CODE AUTO_COMPRESS=FALSE OVERWRITE=TRUE"
snowsql ... -q "CREATE OR REPLACE STREAMLIT LOGISTICS_DB.EDW.LOGISTICS_DASH FROM @LOGISTICS_DB.EDW.APP_CODE MAIN_FILE='app.py' QUERY_WAREHOUSE='LOGISTICS_WH'"
```

Open it: Snowflake UI → Databases → `LOGISTICS_DB` → `EDW` → Streamlit → `LOGISTICS_DASH` → Open → Rerun.

## 6) Local Dev (Fast Iteration) That Mirrors Snowflake Behavior

- One‑command run: `make dev_up` (health check, auto‑open browser; logs at `.streamlit.log`).
- Environment mapping: local scripts map `SNOWSQL_*` → `SNOWFLAKE_*` and set `SF_PASSWORD` automatically so you don’t hand‑edit env files.
- CSV‑only mode (no Snowflake needed): `USE_LOCAL_DATA=1 make dev_up` (reads `data/out/*.csv` and computes the dashboard with pandas).
- Headless run: `make streamlit_local` (binds host/port; good for tunnels).
- Expose for external curl: `make expose` (cloudflared/ngrok).

CLI debug (no UI):

```bash
python scripts/debug_app_sql.py           # Snowpark
USE_LOCAL_DATA=1 python scripts/debug_app_sql.py   # CSV mode
```

## 7) Debug Patterns We Hit — And How To Avoid Them

- INTERVAL multiplication error: replace `(grace * INTERVAL '1 MINUTE')` with `DATEADD(minute, grace, ts)`.
- Mixed types from CSV: if EDW timestamps are ever strings, use `TRY_TO_TIMESTAMP_NTZ(...)` in comparisons and `DATEDIFF`.
- “No matching data”: add a quick snapshot query (counts + min/max delivery date) to guide filters; the app includes this.
- Roles/user mismatch locally: map `SNOWSQL_*` → `SNOWFLAKE_*` automatically; or grant the app role to the dev user.

## 8) Keboola Path (Alternative Load/Curate)

- Upload CSVs to Storage; configure Snowflake Writer to STG.
- Run SQL transformation: `keboola/transformations/sql/10_curate_edw.sql` to MERGE STG → EDW and recompute OTD/OTIF.
- Orchestration: extractor → writer → transform.

Docs to hand teammates:
- `docs/KeboolaHowTo.md` — end‑to‑end Keboola wiring
- `docs/admin_guide.md` — Snowflake provisioning + scripts
- `docs/streamlit_in_snowflake.md` — deploy Streamlit in Snowflake or run locally

## 9) Prompts & Patterns That Work With Codex CLI

- Be explicit in the first prompt: structure, file list, acceptance tests.
- Ask for scripts that you can run **once** to provision everything; avoid manual steps.
- Request a self‑contained SQL pack that mirrors the app’s visuals (`snowflake/dashboard_test.sql`).
- Require defensive SQL (DATEADD, TRY_TO_TIMESTAMP_NTZ) and diagnostic panels early.
- Use `apply_patch` for every change and small, frequent commits.

## 10) TL;DR — The Command Flow We Hand Off To Others

```bash
# 1) Bootstrap Snowflake & roles
./scripts/setup_snowflake_option_a.sh --apply

# 2) Generate data & load
make data
./scripts/load_snowflake.sh --apply     # (optional, STG)
# Run curation SQL (STG → EDW) in Worksheet: keboola/transformations/sql/10_curate_edw.sql

# 3) Validate KPIs via SQL, no UI
snowsql -f snowflake/dashboard_test.sql

# 4) Deploy Streamlit to Snowflake
./scripts/deploy_streamlit.sh

# 5) Local dev (fast iteration)
make dev_up                     # or USE_LOCAL_DATA=1 make dev_up
```

With this flow, Codex CLI becomes your fast teammate: it scaffolds, writes files to the repo, provisions Snowflake, debugs locally in CSV mode, and ships a dashboard you can open in Snowflake — all without manual thrash.

