# Admin Runbook (Snowflake)

Run these in order with `ACCOUNTADMIN` (or equivalent privileges).

- Base provisioning
  - `snowflake/admin/00_provision_base.sql`
    - Creates: `ETL_INTERVIEW_RM` resource monitor, `ETL_INTERVIEW_WH` warehouse, `ETL_INTERVIEW` database.

- Candidate provisioning (C01..C10)
  - `snowflake/admin/01_provision_candidates.sql`
    - Creates per-candidate role (`ETL_Cxx_ROLE`), user (`ETL_Cxx`, login name `etl_cxx`), schemas (`Cxx_RAW`, `Cxx_MODEL`).
    - Grants usage/ownership and pre-creates RAW tables (all VARCHAR) in `Cxx_RAW`.
    - Optional: set a temporary password per user via `ALTER USER ... SET PASSWORD = '...' MUST_CHANGE_PASSWORD = TRUE`.

- Reviewer role (optional but recommended)
  - `snowflake/admin/02_reviewer_role.sql`
    - Creates `ETL_REVIEWER`, grants SELECT on all `Cxx_MODEL` schemas.

- Reset a single candidate (fresh start)
  - `snowflake/admin/10_reset_candidate.sql`
    - Set `CAND='Cxx'` at top. Drops and recreates `Cxx_RAW` and `Cxx_MODEL`, re-creates RAW tables, re-grants privileges.
    - Optional: set a temporary password via `TEMP_PASSWORD` and `ALTER USER`.

- Drop everything (danger)
  - `snowflake/admin/99_drop_everything.sql`
    - Drops all candidate users/roles, the `ETL_INTERVIEW` database, warehouse, and resource monitor. Also drops `ETL_REVIEWER`.

## Notes
- All scripts are idempotent (safe to re-run). Secrets are not embedded.
- Passwords should be set by an admin outside version control. Consider a password manager and rotate per reset.
- Network policies: ensure Keboola can connect to Snowflake (default open policy is fine for the interview DB).
- Cost control: `ETL_INTERVIEW_RM` caps weekly credits and suspends the warehouse on limit.

## Power BI Track
- Prepare shared model schema for BI candidates (read-only)
  - `snowflake/admin/20_powerbi_clone.sql` — creates `POWERBI_DWH` and clones EDW tables from `LOGISTICS_DB.EDW` (adjust source if needed)
  - `snowflake/admin/21_powerbi_grants.sql` — grants read to `ETL_Cxx_ROLE` (C01..C10) and `PBI_REVIEWER`
- Candidate-facing materials live under `powerbi_candidate/` for publishing as a separate repository.
