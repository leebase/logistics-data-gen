SHELL := /bin/bash

.PHONY: venv data snowflake_ddl load checks clean

VENV := .venv
PY := $(VENV)/bin/python

venv:
	@echo "Creating venv and installing deps..."
	python3 -m venv $(VENV)
	. $(VENV)/bin/activate && python -m pip install --upgrade pip pyyaml

data: venv
	@echo "Generating synthetic data..."
	$(PY) data/generate_data.py --config data/config.yaml

snowflake_ddl:
	@echo "Run these to create objects:"
	@echo "snowsql -a <SNOWFLAKE_ACCOUNT> -u <USER> -r <ROLE> -f snowflake/00_schema.sql"
	@echo "snowsql -a <SNOWFLAKE_ACCOUNT> -u <USER> -r <ROLE> -f snowflake/01_tables.sql"
	@echo "snowsql -a <SNOWFLAKE_ACCOUNT> -u <USER> -r <ROLE> -f snowflake/02_stages_and_pipes.sql"

load:
	@bash scripts/load_snowflake.sh

checks:
	@echo "Run quality checks:"
	@echo "snowsql -a <SNOWFLAKE_ACCOUNT> -u <USER> -r <ROLE> -f snowflake/04_quality_checks.sql"

clean:
	rm -rf $(VENV)
	rm -f data/out/*.csv

