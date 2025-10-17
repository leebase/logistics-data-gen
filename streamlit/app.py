import os
import pandas as pd
from time import perf_counter
from typing import List, Optional

import streamlit as st

try:
    # Streamlit in Snowflake
    from snowflake.snowpark.context import get_active_session  # type: ignore
except Exception:  # pragma: no cover
    get_active_session = None  # type: ignore

try:  # Local development fallback
    from snowflake.snowpark import Session  # type: ignore
except Exception:  # pragma: no cover
    Session = None  # type: ignore


@st.cache_resource(show_spinner=False)
def get_session():
    """Return a Snowpark session.

    - In Snowflake: use get_active_session.
    - Locally: build a Snowpark Session from environment variables.
    """
    if get_active_session is not None:
        try:
            return get_active_session()
        except Exception:
            pass

    # Local fallback
    if Session is None:
        st.error(
            "Snowpark is not available. For local dev, install dependencies (requirements-dev.txt)\n"
            "and ensure snowflake-snowpark-python is installed."
        )
        st.stop()

    required = [
        "SNOWFLAKE_ACCOUNT",
        "SNOWFLAKE_USER",
        "SF_PASSWORD",
        "SNOWFLAKE_ROLE",
        "SNOWFLAKE_WAREHOUSE",
        "SNOWFLAKE_DATABASE",
        "SNOWFLAKE_STG_SCHEMA",
        "SNOWFLAKE_EDW_SCHEMA",
    ]
    missing = [k for k in required if os.getenv(k) in (None, "")]
    if missing:
        st.error(
            "Missing environment for local run: " + ", ".join(missing) +
            "\nSource .env.snowflake or pass environment variables before running."
        )
        st.stop()

    cfg = {
        "account": os.getenv("SNOWFLAKE_ACCOUNT"),
        "user": os.getenv("SNOWFLAKE_USER"),
        "password": os.getenv("SF_PASSWORD"),
        "role": os.getenv("SNOWFLAKE_ROLE"),
        "warehouse": os.getenv("SNOWFLAKE_WAREHOUSE"),
        "database": os.getenv("SNOWFLAKE_DATABASE"),
        "schema": os.getenv("SNOWFLAKE_EDW_SCHEMA", "EDW"),
    }
    try:
        return Session.builder.configs(cfg).create()
    except Exception as e:  # pragma: no cover
        st.error(f"Failed to create Snowpark session locally: {e}")
        st.stop()


def _in_list(col: str, values: List[str]) -> str:
    if not values:
        return ""
    esc = [v.replace("'", "''") for v in values]
    return f" AND {col} IN (" + ",".join([f"'{v}'" for v in esc]) + ")"


def _filters_clause(
    database: str,
    edw_schema: str,
    customers: List[str],
    carriers: List[str],
    equipment: List[str],
    lanes: List[str],
    date_start: Optional[str],
    date_end: Optional[str],
    quoted_tables: bool,
    quoted_cols: bool,
) -> str:
    """Build a SQL filters clause using names (resolved to IDs inside SQL)."""
    f = []
    if date_start:
        f.append(f" AND DATE(TRY_TO_TIMESTAMP_NTZ(f.delivery_actual_ts)) >= '{date_start}' ")
    if date_end:
        f.append(f" AND DATE(TRY_TO_TIMESTAMP_NTZ(f.delivery_actual_ts)) <= '{date_end}' ")

    # Resolve table/column quoting based on variant
    dim_customer_tbl = (
        f"{database}.{edw_schema}.\"dim_customer\"" if quoted_tables else f"{database}.{edw_schema}.DIM_CUSTOMER"
    )
    dim_carrier_tbl = (
        f"{database}.{edw_schema}.\"dim_carrier\"" if quoted_tables else f"{database}.{edw_schema}.DIM_CARRIER"
    )
    dim_equipment_tbl = (
        f"{database}.{edw_schema}.\"dim_equipment\"" if quoted_tables else f"{database}.{edw_schema}.DIM_EQUIPMENT"
    )
    dim_lane_tbl = (
        f"{database}.{edw_schema}.\"dim_lane\"" if quoted_tables else f"{database}.{edw_schema}.DIM_LANE"
    )
    dim_loc_tbl = (
        f"{database}.{edw_schema}.\"dim_location\"" if quoted_tables else f"{database}.{edw_schema}.DIM_LOCATION"
    )

    name_col = '"name"' if quoted_cols else 'NAME'
    type_col = '"type"' if quoted_cols else 'TYPE'
    lane_id_col = '"lane_id"' if quoted_cols else 'LANE_ID'
    origin_col = '"origin_loc_id"' if quoted_cols else 'ORIGIN_LOC_ID'
    dest_col = '"dest_loc_id"' if quoted_cols else 'DEST_LOC_ID'
    loc_id_col = '"loc_id"' if quoted_cols else 'LOC_ID'
    city_col = '"city"' if quoted_cols else 'CITY'

    # Name filters resolved to IDs via DIM tables
    if customers:
        esc = [c.replace("'", "''") for c in customers]
        s = ",".join([f"'{x}'" for x in esc])
        cust_id_col = '"customer_id"' if quoted_cols else 'CUSTOMER_ID'
        f.append(
            f" AND f.customer_id IN (SELECT {cust_id_col} FROM {dim_customer_tbl} WHERE {name_col} IN ({s})) "
        )
    if carriers:
        esc = [c.replace("'", "''") for c in carriers]
        s = ",".join([f"'{x}'" for x in esc])
        carrier_id_col = '"carrier_id"' if quoted_cols else 'CARRIER_ID'
        f.append(
            f" AND f.carrier_id IN (SELECT {carrier_id_col} FROM {dim_carrier_tbl} WHERE {name_col} IN ({s})) "
        )
    if equipment:
        esc = [e.replace("'", "''") for e in equipment]
        s = ",".join([f"'{x}'" for x in esc])
        equipment_id_col = '"equipment_id"' if quoted_cols else 'EQUIPMENT_ID'
        f.append(
            f" AND f.equipment_id IN (SELECT {equipment_id_col} FROM {dim_equipment_tbl} WHERE {type_col} IN ({s})) "
        )
    if lanes:
        # lanes passed as "Origin → Dest"
        esc = [l.replace("'", "''") for l in lanes]
        s = ",".join([f"'{x}'" for x in esc])
        f.append(
            " AND f.lane_id IN (\n"
            f"   SELECT l.{lane_id_col}\n"
            f"   FROM {dim_lane_tbl} l\n"
            f"   JOIN {dim_loc_tbl} o ON l.{origin_col} = o.{loc_id_col}\n"
            f"   JOIN {dim_loc_tbl} d ON l.{dest_col} = d.{loc_id_col}\n"
            f"   WHERE (o.{city_col} || ' → ' || d.{city_col}) IN ({s})\n"
            ") "
        )
    return "".join(f)


def main():
    st.set_page_config(page_title="Logistics KPIs", layout="wide")
    is_local = os.getenv("USE_LOCAL_DATA", "0").strip() in {"1", "true", "True"}
    session = None if is_local else get_session()

    # Set a short statement timeout to avoid long hangs in UI (seconds)
    try:
        timeout_s = int(os.getenv("STATEMENT_TIMEOUT", "45"))
        session.sql(f"ALTER SESSION SET STATEMENT_TIMEOUT_IN_SECONDS={timeout_s}").collect()
        # Ensure ISO8601 with timezone offsets parse reliably if EDW was loaded as VARCHAR
        session.sql(
            """ALTER SESSION SET TIMESTAMP_INPUT_FORMAT='YYYY-MM-DD"T"HH24:MI:SS.FF TZH:TZM'"""
        ).collect()
    except Exception:
        pass

    # Context
    if not is_local:
        current_db = session.sql("SELECT CURRENT_DATABASE(), CURRENT_SCHEMA() ").to_pandas()
        default_db = current_db.iloc[0, 0]
        database = os.getenv("STREAMLIT_EDW_DATABASE", default_db)
        edw_schema = os.getenv("STREAMLIT_EDW_SCHEMA", "EDW")
    else:
        database = "LOCAL"
        edw_schema = "EDW"

    st.sidebar.header("Filters")
    # Diagnostic snapshot: show counts and date span to guide filters
    diag_sql = f"""
    SELECT
      COUNT(*) AS total,
      COUNT_IF(TRY_TO_TIMESTAMP_NTZ(delivery_actual_ts) IS NOT NULL) AS delivered,
      MIN(DATE(TRY_TO_TIMESTAMP_NTZ(delivery_actual_ts))) AS min_delivery_date,
      MAX(DATE(TRY_TO_TIMESTAMP_NTZ(delivery_actual_ts))) AS max_delivery_date
    FROM {database}.{edw_schema}.FACT_SHIPMENT
    """
    try:
        diag = None if is_local else run_df(diag_sql)
        if diag is not None and not diag.empty:
            with st.expander("Data Snapshot (EDW.FACT_SHIPMENT)", expanded=False):
                st.write(diag)
    except Exception:
        pass

    # Fetch lists
    @st.cache_data(show_spinner=False, ttl=60)
    def run_df(sql: str) -> pd.DataFrame:
        t0 = perf_counter()
        if not is_local:
            df = session.sql(sql).to_pandas()
            df.columns = [str(c).lower() for c in df.columns]
        else:
            df = _run_local(sql)
        t1 = perf_counter()
        st.session_state.setdefault("_query_times", []).append({"sql": sql[:80] + ("..." if len(sql) > 80 else ""), "ms": int((t1 - t0)*1000)})
        return df

    @st.cache_resource(show_spinner=False)
    def _load_local() -> dict:
        base = os.getenv("LOCAL_DATA_DIR", "data/out")
        def read(name: str, parse_ts: list[str] | None = None) -> pd.DataFrame:
            df = pd.read_csv(os.path.join(base, name))
            if parse_ts:
                for c in parse_ts:
                    if c in df.columns:
                        df[c] = pd.to_datetime(df[c], errors="coerce", utc=True)
            return df
        return {
            "dim_customer": read("DIM_CUSTOMER.csv"),
            "dim_carrier": read("DIM_CARRIER.csv"),
            "dim_equipment": read("DIM_EQUIPMENT.csv"),
            "dim_location": read("DIM_LOCATION.csv"),
            "dim_lane": read("DIM_LANE.csv"),
            "fact_shipment": read("FACT_SHIPMENT.csv", ["tender_ts","pickup_plan_ts","pickup_actual_ts","delivery_plan_ts","delivery_actual_ts"]),
            "fact_event": read("FACT_EVENT.csv", ["event_ts"]),
        }

    def _run_local(sql: str) -> pd.DataFrame:
        # Heuristic mapping of known queries to local pandas computations
        data = _load_local()
        dc = data["dim_customer"].copy()
        dcar = data["dim_carrier"].copy()
        deq = data["dim_equipment"].copy()
        dloc = data["dim_location"].copy()
        dlane = data["dim_lane"].copy()
        fs = data["fact_shipment"].copy()
        fe = data["fact_event"].copy()

        # DIM lists
        if "DIM_CUSTOMER" in sql and "DIM_CARRIER" in sql and "DIM_EQUIPMENT" in sql and "UNION ALL" in sql and "label" in sql:
            ln = dlane.merge(dloc.add_prefix("o_"), left_on="origin_loc_id", right_on="o_loc_id") \
                      .merge(dloc.add_prefix("d_"), left_on="dest_loc_id", right_on="d_loc_id")
            lane_labels = (ln["o_city"] + " → " + ln["d_city"]).rename("v").to_frame()
            out = []
            out.append(pd.DataFrame({"k": "customer", "v": sorted(dc["name"].dropna().unique().tolist())}))
            out.append(pd.DataFrame({"k": "carrier", "v": sorted(dcar["name"].dropna().unique().tolist())}))
            out.append(pd.DataFrame({"k": "equipment", "v": sorted(deq["type"].dropna().unique().tolist())}))
            lane_top = lane_labels.dropna().drop_duplicates().sort_values("v").head(5000)
            out.append(pd.DataFrame({"k": ["lane"] * len(lane_top), "v": lane_top["v"].tolist()}))
            return pd.concat(out, ignore_index=True)

        # Anchor date
        if "MAX(DATE(delivery_actual_ts)) AS d" in sql:
            dmax = fs["delivery_actual_ts"].dropna()
            d = dmax.max().date() if len(dmax) else None
            return pd.DataFrame({"d": [d]})

        # Lane perf
        if "FROM" in sql and "DIM_LANE" in sql and "AVG(DATEDIFF('day'" in sql and "otd_rate" in sql:
            # Apply no filters in local mapping
            df = fs.dropna(subset=["pickup_actual_ts","delivery_actual_ts"]).copy()
            # grace from slider is embedded in SQL; assume 60 here for preview
            grace = 60
            df["is_otd"] = (df["delivery_actual_ts"] <= df["delivery_plan_ts"] + pd.to_timedelta(grace, unit="m"))
            ln = dlane.merge(dloc.add_prefix("o_"), left_on="origin_loc_id", right_on="o_loc_id") \
                      .merge(dloc.add_prefix("d_"), left_on="dest_loc_id", right_on="d_loc_id")
            lab = (ln["o_city"] + " → " + ln["d_city"]).rename("lane").to_frame()
            df = df.merge(dlane[["lane_id"]], left_on="lane_id", right_on="lane_id", how="left")
            df = df.merge(lab.join(dlane.set_index("lane_id"), how="right").reset_index()[["lane_id","lane"]], on="lane_id", how="left")
            g = df.groupby("lane", dropna=False).agg(shipments=("shipment_id","count"), avg_transit_days=(lambda x: None))
            df["transit_days"] = (df["delivery_actual_ts"] - df["pickup_actual_ts"]).dt.days
            g = df.groupby("lane", dropna=False).agg(shipments=("shipment_id","count"), avg_transit_days=("transit_days","mean"), otd_rate=("is_otd","mean")).reset_index()
            return g.sort_values("shipments", ascending=False).head(50)

        # OTD last/prior
        if "otd_last_30" in sql or ("DATEADD('day', -29" in sql and "prev30" in sql):
            df = fs.dropna(subset=["delivery_actual_ts"]).copy()
            if df.empty:
                return pd.DataFrame({"otd_last_30":[0.0],"otd_prior_30":[0.0]})
            anchor = df["delivery_actual_ts"].dt.date.max()
            last_start = anchor - pd.Timedelta(days=29)
            prev_start = anchor - pd.Timedelta(days=60)
            prev_end = anchor - pd.Timedelta(days=30)
            grace = 60
            df["is_otd"] = (df["delivery_actual_ts"] <= df["delivery_plan_ts"] + pd.to_timedelta(grace, unit="m"))
            d = df["delivery_actual_ts"].dt.date
            last = df[(d >= last_start) & (d <= anchor)]
            prev = df[(d >= prev_start) & (d <= prev_end)]
            def rate(x):
                n = len(x)
                return float(x["is_otd"].sum())/n if n else 0.0
            return pd.DataFrame({"otd_last_30":[rate(last)], "otd_prior_30":[rate(prev)]})

        # Average transit days
        if "AVG(DATEDIFF('day', pickup_actual_ts, delivery_actual_ts))" in sql:
            df = fs.dropna(subset=["pickup_actual_ts","delivery_actual_ts"]).copy()
            if df.empty:
                return pd.DataFrame({"avg_transit_days":[0.0]})
            df["td"] = (df["delivery_actual_ts"] - df["pickup_actual_ts"]).dt.days
            return pd.DataFrame({"avg_transit_days":[df["td"].mean()]})

        # Tender acceptance (events)
        if "FROM" in sql and "FACT_EVENT" in sql and "Tendered" in sql and "Accepted" in sql:
            tendered = set(fe.loc[fe["event_type"]=="Tendered","shipment_id"].unique().tolist())
            accepted = set(fe.loc[fe["event_type"]=="Accepted","shipment_id"].unique().tolist())
            rate = float(len(accepted))/float(len(tendered)) if tendered else 0.0
            return pd.DataFrame({"tender_acceptance_events":[rate]})

        # Exception heatmap (counts)
        if "Exception" in sql and "DIM_CUSTOMER" in sql:
            ex = fe[fe["event_type"]=="Exception"].copy()
            if ex.empty:
                return pd.DataFrame(columns=["customer_name","exception_type","exceptions"])
            # Map shipment->customer
            ex = ex.merge(fs[["shipment_id","customer_id"]], on="shipment_id", how="left")
            ex = ex.merge(dc[["customer_id","name"]].rename(columns={"name":"customer_name"}), on="customer_id", how="left")
            ex["exception_type"] = ex["notes"].fillna("Unknown")
            g = ex.groupby(["customer_name","exception_type"], dropna=False).size().reset_index(name="exceptions")
            return g

        # Drill table
        if "SELECT" in sql and "Shipment Details" not in sql and "gm_per_mile" in sql:
            df = fs.copy()
            df = df.merge(dc[["customer_id","name"]].rename(columns={"name":"customer_name"}), on="customer_id", how="left")
            df = df.merge(dcar[["carrier_id","name"]].rename(columns={"name":"carrier_name"}), on="carrier_id", how="left")
            ln = dlane.merge(dloc.add_prefix("o_"), left_on="origin_loc_id", right_on="o_loc_id") \
                      .merge(dloc.add_prefix("d_"), left_on="dest_loc_id", right_on="d_loc_id")
            label_map = ln.set_index("lane_id").apply(lambda r: f"{r['o_city']} → {r['d_city']}", axis=1)
            df["lane"] = df["lane_id"].map(label_map)
            df["isdeliveredontime_calc"] = (df["delivery_actual_ts"] <= df["delivery_plan_ts"] + pd.to_timedelta(60, unit="m"))
            df["isotif"] = df["isdeliveredontime_calc"] & df["isinfull"].fillna(False)
            df["gm_per_mile"] = (df["revenue"] - df["total_cost"]) / df["planned_miles"].replace(0, pd.NA)
            cols = [
                "shipment_id","leg_id","customer_name","carrier_name","lane","status",
                "pickup_plan_ts","pickup_actual_ts","delivery_plan_ts","delivery_actual_ts",
                "isdeliveredontime_calc","isinfull","isotif","planned_miles","actual_miles","revenue","total_cost","gm_per_mile"
            ]
            return df[cols].head(1000)

        # Fallback empty
        return pd.DataFrame()

    def run_df_first(sqls: list[str]) -> pd.DataFrame:
        last_err: Exception | None = None
        for q in sqls:
            try:
                df = run_df(q)
                return df
            except Exception as e:  # pragma: no cover
                last_err = e
                continue
        if last_err:
            raise last_err
        return pd.DataFrame()

    # Three variants:
    #  - lower: quoted-lowercase tables + quoted-lowercase columns
    #  - mixed: UPPERCASE tables + quoted-lowercase columns
    #  - upper: UPPERCASE tables + UPPERCASE columns
    dims_sql_upper = (
        f"""
        WITH c AS (
            SELECT NAME AS name FROM {database}.{edw_schema}.DIM_CUSTOMER ORDER BY NAME LIMIT 5000
        ), cr AS (
            SELECT NAME AS name FROM {database}.{edw_schema}.DIM_CARRIER ORDER BY NAME LIMIT 5000
        ), eq AS (
            SELECT DISTINCT TYPE AS name FROM {database}.{edw_schema}.DIM_EQUIPMENT ORDER BY 1
        ), ln AS (
            SELECT (o.CITY || ' → ' || d.CITY) AS label
            FROM {database}.{edw_schema}.DIM_LANE l
            JOIN {database}.{edw_schema}.DIM_LOCATION o ON l.ORIGIN_LOC_ID = o.LOC_ID
            JOIN {database}.{edw_schema}.DIM_LOCATION d ON l.DEST_LOC_ID = d.LOC_ID
            QUALIFY ROW_NUMBER() OVER (ORDER BY label) <= 5000
        )
        SELECT 'customer' AS "k", name AS "v" FROM c
        UNION ALL SELECT 'carrier' AS "k", name AS "v" FROM cr
        UNION ALL SELECT 'equipment' AS "k", name AS "v" FROM eq
        UNION ALL SELECT 'lane' AS "k", label AS "v" FROM ln
        """
    )

    dims_sql_lower = (
        f"""
        WITH c AS (
            SELECT "name" AS name FROM {database}.{edw_schema}."dim_customer" ORDER BY "name" LIMIT 5000
        ), cr AS (
            SELECT "name" AS name FROM {database}.{edw_schema}."dim_carrier" ORDER BY "name" LIMIT 5000
        ), eq AS (
            SELECT DISTINCT "type" AS name FROM {database}.{edw_schema}."dim_equipment" ORDER BY 1
        ), ln AS (
            SELECT (o."city" || ' → ' || d."city") AS label
            FROM {database}.{edw_schema}."dim_lane" l
            JOIN {database}.{edw_schema}."dim_location" o ON l."origin_loc_id" = o."loc_id"
            JOIN {database}.{edw_schema}."dim_location" d ON l."dest_loc_id" = d."loc_id"
            QUALIFY ROW_NUMBER() OVER (ORDER BY label) <= 5000
        )
        SELECT 'customer' AS "k", name AS "v" FROM c
        UNION ALL SELECT 'carrier' AS "k", name AS "v" FROM cr
        UNION ALL SELECT 'equipment' AS "k", name AS "v" FROM eq
        UNION ALL SELECT 'lane' AS "k", label AS "v" FROM ln
        """
    )

    dims_sql_mixed = (
        f"""
        WITH c AS (
            SELECT "name" AS name FROM {database}.{edw_schema}.DIM_CUSTOMER ORDER BY "name" LIMIT 5000
        ), cr AS (
            SELECT "name" AS name FROM {database}.{edw_schema}.DIM_CARRIER ORDER BY "name" LIMIT 5000
        ), eq AS (
            SELECT DISTINCT "type" AS name FROM {database}.{edw_schema}.DIM_EQUIPMENT ORDER BY 1
        ), ln AS (
            SELECT (o."city" || ' → ' || d."city") AS label
            FROM {database}.{edw_schema}.DIM_LANE l
            JOIN {database}.{edw_schema}.DIM_LOCATION o ON l."origin_loc_id" = o."loc_id"
            JOIN {database}.{edw_schema}.DIM_LOCATION d ON l."dest_loc_id" = d."loc_id"
            QUALIFY ROW_NUMBER() OVER (ORDER BY label) <= 5000
        )
        SELECT 'customer' AS "k", name AS "v" FROM c
        UNION ALL SELECT 'carrier' AS "k", name AS "v" FROM cr
        UNION ALL SELECT 'equipment' AS "k", name AS "v" FROM eq
        UNION ALL SELECT 'lane' AS "k", label AS "v" FROM ln
        """
    )

    # Try lower (quoted tables), then mixed (upper tables, quoted cols), then upper (upper tables/cols)
    for variant, sql in (("lower", dims_sql_lower), ("mixed", dims_sql_mixed), ("upper", dims_sql_upper)):
        try:
            dim_df = run_df(sql)
            dims_variant = variant
            break
        except Exception:
            continue
    else:
        # If all fail, raise the last error by running upper to surface message
        dim_df = run_df(dims_sql_upper)
        dims_variant = "upper"

    customers = dim_df.loc[dim_df["k"] == "customer", "v"].tolist() if not dim_df.empty else []
    carriers = dim_df.loc[dim_df["k"] == "carrier", "v"].tolist() if not dim_df.empty else []
    equipments = dim_df.loc[dim_df["k"] == "equipment", "v"].tolist() if not dim_df.empty else []
    lanes = dim_df.loc[dim_df["k"] == "lane", "v"].tolist() if not dim_df.empty else []

    # Parameters
    grace = st.sidebar.slider("Grace Minutes (OTD/OTIF)", min_value=0, max_value=120, value=60, step=5)
    gm_target = st.sidebar.slider("GM/Mile Target", min_value=0.10, max_value=1.00, value=0.40, step=0.05)

    # Date range defaults
    anchor_df = run_df(
        f"SELECT MIN(CAST(TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(delivery_actual_ts), '')) AS DATE)) AS min_d, "
        f"MAX(CAST(TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(delivery_actual_ts), '')) AS DATE)) AS max_d "
        f"FROM {database}.{edw_schema}.FACT_SHIPMENT WHERE NULLIF(TRIM(delivery_actual_ts), '') IS NOT NULL"
    )
    min_d = anchor_df.get("min_d").iloc[0] if not anchor_df.empty else None
    max_d = anchor_df.get("max_d").iloc[0] if not anchor_df.empty else None
    default_start = min_d
    default_end = max_d

    dr = st.sidebar.date_input(
        "Delivery Date Range",
        value=(default_start, default_end) if default_start and default_end else (),
    )
    date_start = dr[0].isoformat() if isinstance(dr, tuple) and len(dr) == 2 and dr[0] else None
    date_end = dr[1].isoformat() if isinstance(dr, tuple) and len(dr) == 2 and dr[1] else None

    sel_customers = st.sidebar.multiselect("Customers", options=customers)
    sel_carriers = st.sidebar.multiselect("Carriers", options=carriers)
    sel_equipment = st.sidebar.multiselect("Equipment", options=equipments)
    sel_lanes = st.sidebar.multiselect("Lanes", options=lanes)

    filters = _filters_clause(
        database,
        edw_schema,
        sel_customers,
        sel_carriers,
        sel_equipment,
        sel_lanes,
        date_start,
        date_end,
        quoted_tables=(dims_variant == "lower"),
        quoted_cols=(dims_variant in ("lower", "mixed")),
    )

    st.sidebar.caption(f"Context: DB={database}, EDW={edw_schema}")

    # KPIs: OTD last 30 vs prior 30, GM/Mile YTD, Tender Acceptance, Avg Transit Days
    col1, col2, col3, col4 = st.columns(4)

    otd_sql = f"""
    WITH params AS (SELECT {grace} AS grace),
    delivered AS (
      SELECT CAST(TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(f.delivery_actual_ts), '')) AS DATE) AS d,
             IFF(TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(f.delivery_actual_ts), '')) <= DATEADD(minute, (SELECT grace FROM params), TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(f.delivery_plan_ts), ''))), 1, 0) AS is_otd
      FROM {database}.{edw_schema}.FACT_SHIPMENT f
      WHERE NULLIF(TRIM(f.delivery_actual_ts), '') IS NOT NULL {filters}
    ), anchor AS (
      SELECT MAX(d) AS anchor_date FROM delivered
    ), win AS (
      SELECT anchor_date,
             DATEADD('day', -29, anchor_date) AS last30_start,
             anchor_date AS last30_end,
             DATEADD('day', -60, anchor_date) AS prev30_start,
             DATEADD('day', -30, anchor_date) AS prev30_end
      FROM anchor
    ), last30 AS (
      SELECT COUNT(*) AS n_deliv, SUM(is_otd) AS n_otd FROM delivered, win
      WHERE delivered.d BETWEEN win.last30_start AND win.last30_end
    ), prev30 AS (
      SELECT COUNT(*) AS n_deliv, SUM(is_otd) AS n_otd FROM delivered, win
      WHERE delivered.d BETWEEN win.prev30_start AND win.prev30_end
    )
    SELECT
      (last30.n_otd::FLOAT / NULLIF(last30.n_deliv,0)) AS otd_last_30,
      (prev30.n_otd::FLOAT / NULLIF(prev30.n_deliv,0)) AS otd_prior_30
    FROM last30, prev30
    """
    otd = run_df(otd_sql)
    otd_last = float(otd.iloc[0, 0]) if not otd.empty and otd.iloc[0, 0] is not None else 0.0
    otd_prior = float(otd.iloc[0, 1]) if not otd.empty and otd.iloc[0, 1] is not None else 0.0
    otd_delta = otd_last - otd_prior
    col1.metric("OTD % (Last 30)", f"{otd_last:.1%}", delta=f"{otd_delta:+.1%}")

    gmm_sql = f"""
    WITH anchor AS (
      SELECT MAX(DATE(delivery_actual_ts)) AS anchor_date
      FROM {database}.{edw_schema}.FACT_SHIPMENT f
      WHERE f.delivery_actual_ts IS NOT NULL {filters}
    ), ytd AS (
      SELECT SUM(revenue) AS rev, SUM(total_cost) AS cost, SUM(planned_miles) AS miles
      FROM {database}.{edw_schema}.FACT_SHIPMENT f, anchor
      WHERE f.delivery_actual_ts IS NOT NULL {filters}
        AND DATE(f.delivery_actual_ts) BETWEEN DATE_TRUNC('year', anchor.anchor_date) AND anchor.anchor_date
    )
    SELECT (rev - cost) / NULLIF(miles, 0) AS gm_per_mile FROM ytd
    """
    gmm = run_df(gmm_sql)
    gm_mile = float(gmm.iloc[0, 0]) if not gmm.empty and gmm.iloc[0, 0] is not None else 0.0
    col2.metric("GM/Mile (YTD)", f"${gm_mile:.2f}", delta=f"{gm_mile - gm_target:+.2f} vs {gm_target:.2f}")

    ta_sql = f"""
    WITH tendered AS (
      SELECT DISTINCT shipment_id
      FROM {database}.{edw_schema}.FACT_EVENT
      WHERE event_type = 'Tendered'
    ), accepted AS (
      SELECT DISTINCT shipment_id
      FROM {database}.{edw_schema}.FACT_EVENT
      WHERE event_type = 'Accepted'
    )
    SELECT (SELECT COUNT(*) FROM accepted)::FLOAT / NULLIF((SELECT COUNT(*) FROM tendered), 0) AS tender_acceptance_events
    """
    ta = run_df(ta_sql)
    ta_rate = float(ta.iloc[0, 0]) if not ta.empty and ta.iloc[0, 0] is not None else 0.0
    col3.metric("Tender Acceptance %", f"{ta_rate:.1%}")

    atd_sql = f"""
    SELECT AVG(DATEDIFF('day', TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(pickup_actual_ts), '')), TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(delivery_actual_ts), '')))) AS avg_transit_days
    FROM {database}.{edw_schema}.FACT_SHIPMENT f
    WHERE NULLIF(TRIM(pickup_actual_ts), '') IS NOT NULL AND NULLIF(TRIM(delivery_actual_ts), '') IS NOT NULL {filters}
    """
    atd = run_df(atd_sql)
    avg_transit = float(atd.iloc[0, 0]) if not atd.empty and atd.iloc[0, 0] is not None else 0.0
    col4.metric("Avg Transit Days", f"{avg_transit:.2f}")

    st.divider()
    # Show quick perf of last queries (debug aid)
    if "_query_times" in st.session_state:
        with st.expander("Query timings (last run)"):
            st.dataframe(pd.DataFrame(st.session_state["_query_times"]))

    # Lane Performance (bar: Avg Transit Days, line: OTD %)
    # Build expressions for column case based on DIM variant
    quoted = (dims_variant in ("lower", "mixed"))
    cust_name_col = 'c."name"' if quoted else 'c.NAME'
    car_name_col = 'cr."name"' if quoted else 'cr.NAME'
    o_city_expr = 'o."city"' if quoted else 'o.CITY'
    d_city_expr = 'd."city"' if quoted else 'd.CITY'
    l_lane_id = 'l."lane_id"' if quoted else 'l.LANE_ID'
    l_origin_id = 'l."origin_loc_id"' if quoted else 'l.ORIGIN_LOC_ID'
    l_dest_id = 'l."dest_loc_id"' if quoted else 'l.DEST_LOC_ID'
    o_loc_id = 'o."loc_id"' if quoted else 'o.LOC_ID'
    d_loc_id = 'd."loc_id"' if quoted else 'd.LOC_ID'
    c_cust_id = 'c."customer_id"' if quoted else 'c.CUSTOMER_ID'
    cr_carrier_id = 'cr."carrier_id"' if quoted else 'cr.CARRIER_ID'

    tbl_lane = (
        f"{database}.{edw_schema}.\"dim_lane\"" if dims_variant == "lower" else f"{database}.{edw_schema}.DIM_LANE"
    )
    tbl_loc = (
        f"{database}.{edw_schema}.\"dim_location\"" if dims_variant == "lower" else f"{database}.{edw_schema}.DIM_LOCATION"
    )
    tbl_cust = (
        f"{database}.{edw_schema}.\"dim_customer\"" if dims_variant == "lower" else f"{database}.{edw_schema}.DIM_CUSTOMER"
    )
    tbl_carrier = (
        f"{database}.{edw_schema}.\"dim_carrier\"" if dims_variant == "lower" else f"{database}.{edw_schema}.DIM_CARRIER"
    )

    lane_sql = f"""
    WITH params AS (SELECT {grace} AS grace)
    SELECT
      {o_city_expr} || ' → ' || {d_city_expr} AS lane,
      COUNT(*) AS shipments,
      AVG(DATEDIFF('day', TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(f.pickup_actual_ts), '')), TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(f.delivery_actual_ts), '')))) AS avg_transit_days,
      AVG(IFF(TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(f.delivery_actual_ts), '')) IS NOT NULL AND TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(f.delivery_actual_ts), '')) <= DATEADD(minute, (SELECT grace FROM params), TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(f.delivery_plan_ts), ''))), 1, 0)) AS otd_rate
    FROM {database}.{edw_schema}.FACT_SHIPMENT f
    JOIN {tbl_lane} l ON f.lane_id = {l_lane_id}
    JOIN {tbl_loc} o ON {l_origin_id} = {o_loc_id}
    JOIN {tbl_loc} d ON {l_dest_id} = {d_loc_id}
    WHERE NULLIF(TRIM(f.pickup_actual_ts), '') IS NOT NULL AND NULLIF(TRIM(f.delivery_actual_ts), '') IS NOT NULL {filters}
    GROUP BY 1
    ORDER BY shipments DESC
    LIMIT 50
    """
    lane_df = run_df(lane_sql)
    import altair as alt  # type: ignore

    if not lane_df.empty:
        # Optional filter to reduce noise
        min_ship = st.slider("Min shipments per lane (chart)", 1, int(lane_df["shipments"].max()), 5)
        lane_df = lane_df[lane_df["shipments"] >= min_ship]
        if lane_df.empty:
            st.info("No lanes meet the minimum shipments filter.")
        else:
            base = alt.Chart(lane_df).encode(
                x=alt.X("lane:N", sort='-y', title="Lane (Origin → Dest)")
            )
            bars = base.mark_bar(color="#4C78A8").encode(
                y=alt.Y("avg_transit_days:Q", title="Avg Transit Days"),
                tooltip=[
                    alt.Tooltip("lane:N"),
                    alt.Tooltip("shipments:Q"),
                    alt.Tooltip("avg_transit_days:Q", format=".2f"),
                    alt.Tooltip("otd_rate:Q", format=".1%"),
                ],
            )
            # Use points instead of a connecting line across categories
            points = base.mark_point(color="#F58518", filled=True, size=70).encode(
                y=alt.Y("otd_rate:Q", axis=alt.Axis(format="%", title="OTD %")),
                tooltip=[
                    alt.Tooltip("lane:N"),
                    alt.Tooltip("shipments:Q"),
                    alt.Tooltip("avg_transit_days:Q", format=".2f"),
                    alt.Tooltip("otd_rate:Q", format=".1%"),
                ],
            )
            st.altair_chart((bars + points).resolve_scale(y='independent'), use_container_width=True)
    else:
        st.info("No lane data for selected filters.")

    st.divider()

    # Exception Heatmap: Exception Type × Customer
    ex_sql = f"""
    WITH ex AS (
      SELECT e.shipment_id, COALESCE(NULLIF(TRIM(e.notes), ''), 'Unknown') AS exception_type
      FROM {database}.{edw_schema}.FACT_EVENT e
      WHERE e.event_type = 'Exception'
    )
    SELECT {cust_name_col} AS customer_name, ex.exception_type, COUNT(*) AS exceptions
    FROM ex
    JOIN {database}.{edw_schema}.FACT_SHIPMENT f ON f.shipment_id = ex.shipment_id
    JOIN {tbl_cust} c ON {c_cust_id} = f.customer_id
    WHERE 1=1 {filters}
    GROUP BY 1,2
    """
    ex_df = run_df(ex_sql)
    if not ex_df.empty:
        heat = (
            alt.Chart(ex_df)
            .mark_rect()
            .encode(x=alt.X("customer_name:N", sort='-y', title="Customer"), y=alt.Y("exception_type:N", title="Exception Type"), color=alt.Color("exceptions:Q"))
        )
        st.altair_chart(heat, use_container_width=True)
    else:
        st.info("No exceptions for selected filters.")

    st.divider()

    # Drill table
    drill_sql = f"""
    SELECT
      f.shipment_id, f.leg_id,
      {cust_name_col} AS customer_name,
      {car_name_col} AS carrier_name,
      {o_city_expr} || ' → ' || {d_city_expr} AS lane,
      f.status,
      TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(f.pickup_plan_ts), '')) AS pickup_plan_ts,
      TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(f.pickup_actual_ts), '')) AS pickup_actual_ts,
      TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(f.delivery_plan_ts), '')) AS delivery_plan_ts,
      TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(f.delivery_actual_ts), '')) AS delivery_actual_ts,
      IFF(TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(f.delivery_actual_ts), '')) IS NOT NULL AND TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(f.delivery_actual_ts), '')) <= DATEADD(minute, {grace}, TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(f.delivery_plan_ts), ''))), TRUE, FALSE) AS isdeliveredontime,
      f.isinfull,
      (IFF(TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(f.delivery_actual_ts), '')) IS NOT NULL AND TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(f.delivery_actual_ts), '')) <= DATEADD(minute, {grace}, TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(f.delivery_plan_ts), ''))), TRUE, FALSE) AND f.isinfull) AS isotif,
      f.planned_miles, f.actual_miles, f.revenue, f.total_cost,
      (f.revenue - f.total_cost) / NULLIF(f.planned_miles, 0) AS gm_per_mile
    FROM {database}.{edw_schema}.FACT_SHIPMENT f
    JOIN {tbl_cust} c ON {c_cust_id} = f.customer_id
    JOIN {tbl_carrier} cr ON {cr_carrier_id} = f.carrier_id
    JOIN {tbl_lane} l ON {l_lane_id} = f.lane_id
    JOIN {tbl_loc} o ON {o_loc_id} = {l_origin_id}
    JOIN {tbl_loc} d ON {d_loc_id} = {l_dest_id}
    WHERE 1=1 {filters}
    ORDER BY f.shipment_id, f.leg_id
    LIMIT 1000
    """
    drill_df = run_df(drill_sql)
    st.subheader("Shipment Details (top 1000)")
    st.dataframe(drill_df, use_container_width=True)


if __name__ == "__main__":
    main()
