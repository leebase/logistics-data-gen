# Security and Secrets Handling

This repository is configured to avoid accidental secret leakage. Follow these guidelines when working locally or in CI.

## Never Commit Secrets
- Do not commit passwords, tokens, API keys, or private keys.
- Keep real credentials in local environment files (untracked) or secret managers.
- Only sanitized templates (e.g., `config/.env.snowflake.example`) are versioned.

## Environment Variables
- Copy `config/.env.snowflake.example` to `.env.snowflake` and fill in your values.
- Do not commit `.env.snowflake`. It is ignored via `.gitignore`.
- Export to your shell for local runs:
  - `set -a; source ./.env.snowflake; set +a`

## Pre-commit Secret Scan (Local)
- A pre-commit hook is provided at `.githooks/pre-commit` to block commits that contain likely secrets.
- Install it with:
  - `bash scripts/install_git_hooks.sh`
- The hook scans staged changes and blocks if it detects patterns like `SNOWSQL_PWD`, `password=`, or PEM private key headers.
- If you hit a false positive, comment the line out before committing (the hook ignores commented lines).

## Accidental Secret Commit? Act Fast
1) Remove from tracking and rotate the credential immediately.
   - `git rm --cached path/to/secret && git commit -m "Remove secret" && git push`
2) Purge from history (required to fully remove):
   - Use BFG Repo-Cleaner or `git filter-repo`.
3) Force push after cleanup and invalidate any dependent tokens.

## CI/Tooling
- Use CI secrets for pipelines (never plaintext in YAML).
- Prefer key-based auth to Snowflake and rotate keys periodically.

