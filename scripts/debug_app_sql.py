#!/usr/bin/env python3
"""
Run the key SQL queries used by the Streamlit app via Snowpark and print row counts and sample rows.
Helps debug data/permissions without running a web server.
"""
import os
import sys
from typing import Optional
import pandas as pd
try:
    from snowflake.snowpark import Session  # type: ignore
except Exception:  # pragma: no cover
    Session = None  # type: ignore


def env(k: str, default: Optional[str] = None) -> str:
    v = os.getenv(k) or default
    if not v:
        print(f"Missing env: {k}", file=sys.stderr)
        sys.exit(2)
    return v


def main() -> None:
    use_local = os.getenv("USE_LOCAL_DATA", "0").lower() in {"1","true"}
    database = os.getenv("SNOWFLAKE_DATABASE", "LOGISTICS_DB")
    edw_schema = os.getenv("SNOWFLAKE_EDW_SCHEMA", "EDW")

    if not use_local:
        if Session is None:
            print("Snowpark not available; set USE_LOCAL_DATA=1 for local CSV debug.", file=sys.stderr)
            sys.exit(2)
        account = env("SNOWFLAKE_ACCOUNT")
        user = env("SNOWFLAKE_USER")
        sf_password = os.getenv("SF_PASSWORD") or os.getenv("SNOWSQL_PWD")
        if not sf_password:
            # Avoid tripping secret scanners while still being clear
            print("Set SF_PASSWORD (or SNOWSQL_" "PWD) in your shell.", file=sys.stderr)
            sys.exit(2)
        role = env("SNOWFLAKE_ROLE")
        warehouse = env("SNOWFLAKE_WAREHOUSE")

        s = Session.builder.configs(
            {
                "account": account,
                "user": user,
                "password": sf_password,
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
    else:
        base = os.getenv("LOCAL_DATA_DIR", "data/out")
        def read(name: str, parse_ts: Optional[list[str]] = None) -> pd.DataFrame:
            df = pd.read_csv(os.path.join(base, name))
            if parse_ts:
                for c in parse_ts:
                    if c in df.columns:
                        df[c] = pd.to_datetime(df[c], errors="coerce", utc=True)
            return df
        dim_customer = read("DIM_CUSTOMER.csv")
        dim_carrier = read("DIM_CARRIER.csv")
        dim_equipment = read("DIM_EQUIPMENT.csv")
        dim_location = read("DIM_LOCATION.csv")
        dim_lane = read("DIM_LANE.csv")
        fact_shipment = read("FACT_SHIPMENT.csv", ["tender_ts","pickup_plan_ts","pickup_actual_ts","delivery_plan_ts","delivery_actual_ts"])
        fact_event = read("FACT_EVENT.csv", ["event_ts"])        

        def run(label: str, which: str) -> None:
            if which == "dims":
                print(f"\n[{label}] customers={len(dim_customer)} carriers={len(dim_carrier)} equipment={len(dim_equipment)} lanes={len(dim_lane)}")
                print(dim_customer.head(3).to_string(index=False))
            elif which == "otd":
                df = fact_shipment.dropna(subset=["delivery_actual_ts"]).copy()
                anch = df["delivery_actual_ts"].dt.date.max() if not df.empty else None
                if anch is None:
                    print("\n[OTD] no deliveries")
                    return
                last_start = anch - pd.Timedelta(days=29)
                prev_start = anch - pd.Timedelta(days=60)
                prev_end = anch - pd.Timedelta(days=30)
                df["is_otd"] = (df["delivery_actual_ts"] <= df["delivery_plan_ts"] + pd.to_timedelta(60, unit="m"))
                d = df["delivery_actual_ts"].dt.date
                last = df[(d >= last_start) & (d <= anch)]
                prev = df[(d >= prev_start) & (d <= prev_end)]
                rate = lambda x: float(x["is_otd"].sum())/len(x) if len(x) else 0.0
                print(f"\n[OTD] last30={rate(last):.3f} prior30={rate(prev):.3f}")
            elif which == "lane":
                df = fact_shipment.dropna(subset=["pickup_actual_ts","delivery_actual_ts"]).copy()
                df["td"] = (df["delivery_actual_ts"] - df["pickup_actual_ts"]).dt.days
                df["is_otd"] = (df["delivery_actual_ts"] <= df["delivery_plan_ts"] + pd.to_timedelta(60, unit="m"))
                ln = dim_lane.merge(dim_location.add_prefix("o_"), left_on="origin_loc_id", right_on="o_loc_id").merge(
                    dim_location.add_prefix("d_"), left_on="dest_loc_id", right_on="d_loc_id")
                label_map = ln.set_index("lane_id").apply(lambda r: f"{r['o_city']} → {r['d_city']}", axis=1)
                df["lane"] = df["lane_id"].map(label_map)
                g = df.groupby("lane").agg(shipments=("shipment_id","count"), avg_transit_days=("td","mean"), otd_rate=("is_otd","mean")).reset_index()
                print(f"\n[Lane] rows={len(g)}")
                if not g.empty:
                    print(g.head(3).to_string(index=False))
            else:
                print(f"[{label}] unsupported")

    # Run a few checks
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
    ) if not use_local else run("DIM lists", "dims")

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
    ) if not use_local else run("KPI OTD last/prior", "otd")

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
    ) if not use_local else run("Lane perf", "lane")
    if not use_local:
        s.close()


if __name__ == "__main__":
    main()
