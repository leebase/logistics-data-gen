#!/usr/bin/env python3
"""
Run the key SQL queries used by the Streamlit app via Snowpark and print row counts and sample rows.
Helps debug data/permissions without running a web server.
"""
import os
import sys
from snowflake.snowpark import Session


def env(k: str, default: str | None = None) -> str:
    v = os.getenv(k) or default
    if not v:
        print(f"Missing env: {k}", file=sys.stderr)
        sys.exit(2)
    return v


def main() -> None:
    account = env("SNOWFLAKE_ACCOUNT")
    user = env("SNOWFLAKE_USER")
    password = os.getenv("SF_PASSWORD") or os.getenv("SNOWSQL_PWD")
    if not password:
        print("Set SF_PASSWORD (or SNOWSQL_PWD) in your shell.", file=sys.stderr)
        sys.exit(2)
    role = env("SNOWFLAKE_ROLE")
    warehouse = env("SNOWFLAKE_WAREHOUSE")
    database = env("SNOWFLAKE_DATABASE")
    edw_schema = os.getenv("SNOWFLAKE_EDW_SCHEMA", "EDW")

    s = Session.builder.configs(
        {
            "account": account,
            "user": user,
            "password": password,
            "role": role,
            "warehouse": warehouse,
            "database": database,
            "schema": edw_schema,
        }
    ).create()

    s.sql("ALTER SESSION SET STATEMENT_TIMEOUT_IN_SECONDS=15").collect()

    def run(label: str, sql: str) -> None:
        try:
            df = s.sql(sql).to_pandas()
            print(f"\n[{label}] rows={len(df)}")
            if not df.empty:
                print(df.head(3).to_string(index=False))
        except Exception as e:
            print(f"\n[{label}] ERROR: {e}")

    run(
        "DIM lists",
        f"""
        WITH c AS (SELECT name FROM {database}.{edw_schema}.DIM_CUSTOMER ORDER BY name LIMIT 5),
             cr AS (SELECT name FROM {database}.{edw_schema}.DIM_CARRIER ORDER BY name LIMIT 5),
             eq AS (SELECT DISTINCT type AS name FROM {database}.{edw_schema}.DIM_EQUIPMENT ORDER BY 1 LIMIT 5)
        SELECT 'customer' k, name v FROM c
        UNION ALL SELECT 'carrier', name FROM cr
        UNION ALL SELECT 'equipment', name FROM eq
        """,
    )

    run(
        "KPI OTD last/prior",
        f"""
        WITH params AS (SELECT 60 AS grace),
             delivered AS (
               SELECT DATE(delivery_actual_ts) d,
                      IFF(delivery_actual_ts <= delivery_plan_ts + (SELECT grace FROM params) * INTERVAL '1 MINUTE', 1, 0) is_otd
               FROM {database}.{edw_schema}.FACT_SHIPMENT WHERE delivery_actual_ts IS NOT NULL
             ), anchor AS (
               SELECT MAX(d) anchor_date FROM delivered
             ), win AS (
               SELECT anchor_date,
                      DATEADD('day', -29, anchor_date) last30_start,
                      anchor_date last30_end,
                      DATEADD('day', -60, anchor_date) prev30_start,
                      DATEADD('day', -30, anchor_date) prev30_end
               FROM anchor
             ), last30 AS (
               SELECT COUNT(*) n_deliv, SUM(is_otd) n_otd FROM delivered, win WHERE delivered.d BETWEEN win.last30_start AND win.last30_end
             ), prev30 AS (
               SELECT COUNT(*) n_deliv, SUM(is_otd) n_otd FROM delivered, win WHERE delivered.d BETWEEN win.prev30_start AND win.prev30_end
             )
        SELECT (last30.n_otd::FLOAT / NULLIF(last30.n_deliv,0)) otd_last_30,
               (prev30.n_otd::FLOAT / NULLIF(prev30.n_deliv,0)) otd_prior_30
        FROM last30, prev30
        """,
    )

    run(
        "Lane perf",
        f"""
        WITH params AS (SELECT 60 AS grace)
        SELECT COUNT(*) shipments,
               AVG(DATEDIFF('day', f.pickup_actual_ts, f.delivery_actual_ts)) avg_transit_days,
               AVG(IFF(f.delivery_actual_ts IS NOT NULL AND f.delivery_actual_ts <= f.delivery_plan_ts + (SELECT grace FROM params) * INTERVAL '1 MINUTE', 1, 0)) otd_rate
        FROM {database}.{edw_schema}.FACT_SHIPMENT f
        WHERE f.pickup_actual_ts IS NOT NULL AND f.delivery_actual_ts IS NOT NULL
        """,
    )

    s.close()


if __name__ == "__main__":
    main()

