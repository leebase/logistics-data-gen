# Streamlit Logistics App — Usage & Guide

This Streamlit app runs inside Snowflake (or locally) and mirrors the Power BI deliverable so you can validate data and iterate fast.

## What You Get
- KPIs: On‑Time Delivery (OTD), On‑Time In‑Full (OTIF), Gross Margin per Mile, Tender Acceptance %, Avg Transit Days.
- Visuals:
  - Lane Performance: blue bars (Avg Transit Days) + orange points (OTD%).
  - Exception Heatmap: Exception Type × Customer.
  - Drill Table: Shipment detail with computed flags and GM/Mile.
- Filters: Date range, Customer, Carrier, Equipment, Lane, plus a Grace Minutes slider and GM/Mile target.

## Data Source
- Curated tables in `EDW`: `DIM_CUSTOMER`, `DIM_CARRIER`, `DIM_EQUIPMENT`, `DIM_LOCATION`, `DIM_LANE`, `FACT_SHIPMENT`, `FACT_EVENT`.
- The app is resilient to identifier casing:
  - Uppercase tables + uppercase columns (canonical)
  - Uppercase tables + quoted‑lower columns (mixed)
  - Quoted‑lower tables + quoted‑lower columns

## Run Locally (Fast Iteration)
1) Install dev dependencies:
   - `python -m pip install -r requirements-dev.txt`
2) Provide Snowflake environment via `.env.snowflake` (see `config/.env.snowflake.example`) or use CSV‑only mode:
   - CSV‑only: `USE_LOCAL_DATA=1 ./scripts/run_streamlit_local.sh`
   - Snowflake: `./scripts/run_streamlit_local.sh`
3) Open the printed URL. Logs are written to `.streamlit.log`.

Notes:
- CSV‑only mode reads `data/out/*.csv` and computes KPIs with pandas.
- With Snowflake, the app uses Snowpark and executes SQL inside your account.

## Deploy In Snowflake
1) Upload and create the app: `./scripts/deploy_streamlit.sh`.
2) Open from the Snowflake UI:
   - Databases → your `LOGISTICS_DB` → `EDW` → Streamlit → `LOGISTICS_DASH` → Open → Rerun.

Troubleshooting:
- If a URL function isn’t available, the script will not print it; use the UI path above.
- Role or permission errors: ensure your role can query EDW and run Streamlit.

## Using The App
- Sidebar:
  - Date Range: defaults to min/max delivered date in EDW.
  - Customers/Carriers/Equipment/Lanes: multi‑select (resolved by DIM names).
  - Grace Minutes: 0–120 (used in OTD/OTIF).
  - GM/Mile Target: reference value for the KPI tile.
- Lane Performance:
  - Bars = Avg Transit Days; Points = OTD% (secondary axis).
  - “Min shipments per lane” slider filters out sparse lanes.
- Exception Heatmap:
  - Counts of exceptions by customer. Notes are normalized (blank → “Unknown”).
- Drill Table:
  - Shows status, actual/plan timestamps (cast safely), computed `isdeliveredontime` and `isotif`, and GM/Mile.

## Identifier Case & Normalization
- If your EDW was loaded with quoted‑lowercase tables or columns, the app adapts automatically.
- For a canonical schema going forward, consider running `snowflake/99_normalize_edw_names.sql` in a worksheet (review statements first).

## Performance Tips
- Use the date range and dimension filters to narrow the scope.
- Increase warehouse size for heavy queries; the app sets a modest statement timeout by default.

## Validating With SQL
- Run `snowflake/dashboard_test.sql` to reproduce KPIs/visuals in pure SQL before opening the app.

## Common Errors
- Object not found (e.g., quoted‑lower tables): confirm your EDW object names; the app supports lower/mixed/upper, but permissions still apply.
- Invalid identifier NAME/CITY: indicates quoted‑lower columns; either normalize EDW or rely on the mixed variant (the app does this automatically).
- Ambiguous timestamps or casting errors: timestamps are handled with `TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(col), ''))` and `DATEADD` for grace minutes; if raw strings persist in EDW, this still works.

