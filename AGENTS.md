# Repository Guidelines

## Project Structure & Module Organization
- Source code lives in `src/logistics_data/` (pure, importable modules). 
- Scripts/CLIs go in `scripts/` and call library code, not notebooks.
- Data folders: `data/raw/`, `data/processed/`, `data/external/` (large files ignored via `.gitignore`).
- Notebooks in `notebooks/` with cleared outputs; keep logic in `src/`.
- Tests mirror `src/` under `tests/` (e.g., `tests/pipelines/test_orders.py`).
- Configuration in `config/` (`.yaml`/`.env` templates). Never commit secrets.

## Build, Test, and Development Commands
- Install deps: `poetry install` (or `pip install -r requirements.txt`).
- Lint: `ruff check .`; Format: `ruff format .` (or `black .`).
- Types: `mypy src`.
- Tests: `pytest -q` (coverage: `pytest --cov=src`).
- Run pipeline/entrypoint: `python -m logistics_data.main` or `scripts/run_pipeline.sh`.
- If a `Makefile` exists: `make install`, `make lint`, `make test`, `make run`.

## Coding Style & Naming Conventions
- Python 3.11+, PEP 8, 4-space indentation. Prefer `pathlib` over string paths.
- Imports: stdlib, third-party, local (enforced by Ruff). Avoid wildcard imports.
- Naming: modules/packages `snake_case`; classes `PascalCase`; functions/vars `snake_case`; constants `UPPER_SNAKE_CASE`.
- Keep functions small and pure; separate I/O from transforms.

## Testing Guidelines
- Framework: `pytest` with fixtures in `tests/conftest.py`.
- File names: `test_*.py`; structure mirrors `src/`.
- Aim for ≥85% coverage on changed code; include regression tests for bugs.
- For data logic, add small, deterministic sample inputs in `tests/fixtures/`.

## Commit & Pull Request Guidelines
- Commits: small, present-tense, imperative (e.g., "Add orders pipeline").
- Optional scope prefix: `etl:`, `api:`, `docs:`, `ci:`.
- PRs: clear description, linked issues, testing steps, and any screenshots/CLI output showing data diffs.
- Require green lint, type, and test checks before merge.

## Security & Configuration Tips
- Do not commit credentials or raw PII. Use `.env` locally and CI secrets in workflows.
- Provide `config/*.yaml` and `.env.example` templates; validate all external inputs.
- Log sensitive fields in hashed/pseudonymized form where necessary.

