# Changelog

## v0.5 — 2025-10-17

Highlights
- Streamlit app hardened for mixed identifier casing (uppercase tables with quoted lowercase columns) and lowercase tables.
- Lane Performance visual updated: bars (Avg Transit Days) + points (OTD%) with a min‑shipments filter for clarity.
- Robust timestamp handling everywhere (TRIM + TRY_TO_TIMESTAMP_TZ + DATEADD for grace minutes).
- Added dashboard SQL pack to validate KPIs/visuals without UI.
- Added EDW normalization script to standardize quoted identifiers.
- Documentation refreshed for deploy/debug and local dev loop.

Changes
- streamlit/app.py
  - Fix ALTER SESSION TIMESTAMP_INPUT_FORMAT quoting.
  - Variant‑aware DIM discovery (lower/mixed/upper) and filter subqueries.
  - Lane chart UX: points for OTD%, tooltips, min‑shipments slider.
- snowflake/dashboard_test.sql
  - Rewrote to use robust casting and bounds derivation; matches app logic.
- snowflake/99_normalize_edw_names.sql
  - Utility to rename quoted columns/tables to canonical uppercase (use with care).
- scripts/deploy_streamlit.sh
  - Better behavior when SYSTEM$SHOW_STREAMLIT_URL is unavailable; fallback guidance.
- docs
  - streamlit_in_snowflake.md: deploy notes + visual details.
  - admin_guide.md: name normalization guidance.
  - codex_cli_cli_guide.md: CLI narrative and end‑to‑end flow.

Security/Repo Hygiene
- No secrets committed; `.env` files remain ignored. Debug helper messages adjusted to satisfy secret scanner.

