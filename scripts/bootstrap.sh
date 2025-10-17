#!/usr/bin/env bash
set -euo pipefail

# Bootstrap local environment, generate data, and print next steps.

PYTHON_BIN="${PYTHON_BIN:-python3}"
VENV_DIR=".venv"

echo "Creating virtual environment in ${VENV_DIR}..."
${PYTHON_BIN} -m venv "${VENV_DIR}"

# shellcheck disable=SC1091
source "${VENV_DIR}/bin/activate"

echo "Upgrading pip and installing dependencies..."
python -m pip install --upgrade pip
python -m pip install pyyaml

echo "Generating data..."
python data/generate_data.py --config data/config.yaml

echo
echo "Done. CSVs are in data/out/"
echo
echo "Next steps:"
echo "1) Review Snowflake DDL in snowflake/00_schema.sql and 01_tables.sql."
echo "2) Load data using scripts/load_snowflake.sh (edit env vars first)."
echo "3) Configure Keboola per keboola/README.md."
echo "4) Build Power BI model using powerbi/* guides."

