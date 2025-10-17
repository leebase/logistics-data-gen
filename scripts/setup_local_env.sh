#!/usr/bin/env bash
set -euo pipefail

# Create a local Python virtual environment and install requirements.

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
VENV_DIR="${VENV_DIR:-$root/.venv}"
PYTHON_BIN="${PYTHON_BIN:-python3}"

echo "Creating virtual environment at ${VENV_DIR}..."
"${PYTHON_BIN}" -m venv "${VENV_DIR}"

# shellcheck disable=SC1090
source "${VENV_DIR}/bin/activate"

echo "Upgrading pip and installing requirements.txt..."
python -m pip install --upgrade pip
python -m pip install -r "${root}/requirements.txt"

echo
echo "Done. To use the environment, run:"
echo "  source ${VENV_DIR}/bin/activate"
echo
echo "Optional: run the local Streamlit dashboard against Snowflake:"
echo "  ./scripts/run_streamlit_local.sh"

