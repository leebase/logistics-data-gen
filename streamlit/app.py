import os
import pandas as pd
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
) -> str:
    """Build a SQL filters clause using names (resolved to IDs inside SQL)."""
    f = []
    if date_start:
        f.append(f" AND DATE(f.delivery_actual_ts) >= '{date_start}' ")
    if date_end:
        f.append(f" AND DATE(f.delivery_actual_ts) <= '{date_end}' ")

    # Name filters resolved to IDs via DIM tables
    if customers:
        esc = [c.replace("'", "''") for c in customers]
        s = ",".join([f"'{x}'" for x in esc])
        f.append(
            f" AND f.customer_id IN (SELECT customer_id FROM {database}.{edw_schema}.DIM_CUSTOMER WHERE name IN ({s})) "
        )
    if carriers:
        esc = [c.replace("'", "''") for c in carriers]
        s = ",".join([f"'{x}'" for x in esc])
        f.append(
            f" AND f.carrier_id IN (SELECT carrier_id FROM {database}.{edw_schema}.DIM_CARRIER WHERE name IN ({s})) "
        )
    if equipment:
        esc = [e.replace("'", "''") for e in equipment]
        s = ",".join([f"'{x}'" for x in esc])
        f.append(
            f" AND f.equipment_id IN (SELECT equipment_id FROM {database}.{edw_schema}.DIM_EQUIPMENT WHERE type IN ({s})) "
        )
    if lanes:
        # lanes passed as "Origin → Dest"
        esc = [l.replace("'", "''") for l in lanes]
        s = ",".join([f"'{x}'" for x in esc])
        f.append(
            " AND f.lane_id IN (\n"
            f"   SELECT l.lane_id\n"
            f"   FROM {database}.{edw_schema}.DIM_LANE l\n"
            f"   JOIN {database}.{edw_schema}.DIM_LOCATION o ON l.origin_loc_id = o.loc_id\n"
            f"   JOIN {database}.{edw_schema}.DIM_LOCATION d ON l.dest_loc_id = d.loc_id\n"
            f"   WHERE (o.city || ' → ' || d.city) IN ({s})\n"
            ") "
        )
    return "".join(f)


def main():
    st.set_page_config(page_title="Logistics KPIs", layout="wide")
    session = get_session()

    # Set a short statement timeout to avoid long hangs in UI (seconds)
    try:
        timeout_s = int(os.getenv("STATEMENT_TIMEOUT", "45"))
        session.sql(f"ALTER SESSION SET STATEMENT_TIMEOUT_IN_SECONDS={timeout_s}").collect()
    except Exception:
        pass

    # Context
    current_db = session.sql("SELECT CURRENT_DATABASE(), CURRENT_SCHEMA() ").to_pandas()
    default_db = current_db.iloc[0, 0]
    database = os.getenv("STREAMLIT_EDW_DATABASE", default_db)
    edw_schema = os.getenv("STREAMLIT_EDW_SCHEMA", "EDW")

    st.sidebar.header("Filters")
    # Fetch lists
    def run_df(sql: str) -> pd.DataFrame:
        try:
            df = session.sql(sql).to_pandas()
            df.columns = [str(c).lower() for c in df.columns]
            return df
        except Exception as e:
            st.error(f"Query failed: {e}")
            return pd.DataFrame()

    dim_df = run_df(
        f"""
        WITH c AS (
            SELECT name FROM {database}.{edw_schema}.DIM_CUSTOMER ORDER BY name LIMIT 5000
        ), cr AS (
            SELECT name FROM {database}.{edw_schema}.DIM_CARRIER ORDER BY name LIMIT 5000
        ), eq AS (
            SELECT DISTINCT type AS name FROM {database}.{edw_schema}.DIM_EQUIPMENT ORDER BY 1
        ), ln AS (
            SELECT (o.city || ' → ' || d.city) AS label
            FROM {database}.{edw_schema}.DIM_LANE l
            JOIN {database}.{edw_schema}.DIM_LOCATION o ON l.origin_loc_id = o.loc_id
            JOIN {database}.{edw_schema}.DIM_LOCATION d ON l.dest_loc_id = d.loc_id
            QUALIFY ROW_NUMBER() OVER (ORDER BY label) <= 5000
        )
        SELECT 'customer' AS "k", name AS "v" FROM c
        UNION ALL SELECT 'carrier' AS "k", name AS "v" FROM cr
        UNION ALL SELECT 'equipment' AS "k", name AS "v" FROM eq
        UNION ALL SELECT 'lane' AS "k", label AS "v" FROM ln
        """
    )

    customers = dim_df.loc[dim_df["k"] == "customer", "v"].tolist() if not dim_df.empty else []
    carriers = dim_df.loc[dim_df["k"] == "carrier", "v"].tolist() if not dim_df.empty else []
    equipments = dim_df.loc[dim_df["k"] == "equipment", "v"].tolist() if not dim_df.empty else []
    lanes = dim_df.loc[dim_df["k"] == "lane", "v"].tolist() if not dim_df.empty else []

    # Parameters
    grace = st.sidebar.slider("Grace Minutes (OTD/OTIF)", min_value=0, max_value=120, value=60, step=5)
    gm_target = st.sidebar.slider("GM/Mile Target", min_value=0.10, max_value=1.00, value=0.40, step=0.05)

    # Date range defaults
    anchor_df = run_df(
        f"SELECT MAX(DATE(delivery_actual_ts)) AS d FROM {database}.{edw_schema}.FACT_SHIPMENT"
    )
    anchor = anchor_df["d"].iloc[0] if not anchor_df.empty else None
    default_start = None
    default_end = None
    if anchor is not None:
        import datetime as _dt

        default_end = anchor
        default_start = anchor - _dt.timedelta(days=180)

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

    filters = _filters_clause(database, edw_schema, sel_customers, sel_carriers, sel_equipment, sel_lanes, date_start, date_end)

    st.sidebar.caption(f"Context: DB={database}, EDW={edw_schema}")

    # KPIs: OTD last 30 vs prior 30, GM/Mile YTD, Tender Acceptance, Avg Transit Days
    col1, col2, col3, col4 = st.columns(4)

    otd_sql = f"""
    WITH params AS (SELECT {grace} AS grace),
    delivered AS (
      SELECT DATE(f.delivery_actual_ts) AS d,
             IFF(f.delivery_actual_ts <= f.delivery_plan_ts + (SELECT grace FROM params) * INTERVAL '1 MINUTE', 1, 0) AS is_otd
      FROM {database}.{edw_schema}.FACT_SHIPMENT f
      WHERE f.delivery_actual_ts IS NOT NULL {filters}
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
    SELECT AVG(DATEDIFF('day', pickup_actual_ts, delivery_actual_ts)) AS avg_transit_days
    FROM {database}.{edw_schema}.FACT_SHIPMENT f
    WHERE pickup_actual_ts IS NOT NULL AND delivery_actual_ts IS NOT NULL {filters}
    """
    atd = run_df(atd_sql)
    avg_transit = float(atd.iloc[0, 0]) if not atd.empty and atd.iloc[0, 0] is not None else 0.0
    col4.metric("Avg Transit Days", f"{avg_transit:.2f}")

    st.divider()

    # Lane Performance (bar: Avg Transit Days, line: OTD %)
    lane_sql = f"""
    WITH params AS (SELECT {grace} AS grace)
    SELECT
      o.city || ' → ' || d.city AS lane,
      COUNT(*) AS shipments,
      AVG(DATEDIFF('day', f.pickup_actual_ts, f.delivery_actual_ts)) AS avg_transit_days,
      AVG(IFF(f.delivery_actual_ts IS NOT NULL AND f.delivery_actual_ts <= f.delivery_plan_ts + (SELECT grace FROM params) * INTERVAL '1 MINUTE', 1, 0)) AS otd_rate
    FROM {database}.{edw_schema}.FACT_SHIPMENT f
    JOIN {database}.{edw_schema}.DIM_LANE l ON f.lane_id = l.lane_id
    JOIN {database}.{edw_schema}.DIM_LOCATION o ON l.origin_loc_id = o.loc_id
    JOIN {database}.{edw_schema}.DIM_LOCATION d ON l.dest_loc_id = d.loc_id
    WHERE f.pickup_actual_ts IS NOT NULL AND f.delivery_actual_ts IS NOT NULL {filters}
    GROUP BY 1
    ORDER BY shipments DESC
    LIMIT 50
    """
    lane_df = run_df(lane_sql)
    import altair as alt  # type: ignore

    if not lane_df.empty:
        base = alt.Chart(lane_df).encode(x=alt.X("lane:N", sort='-y'))
        bars = base.mark_bar(color="#4C78A8").encode(y=alt.Y("avg_transit_days:Q", title="Avg Transit Days"))
        line = base.mark_line(color="#F58518").encode(y=alt.Y("otd_rate:Q", axis=alt.Axis(format="%"), title="OTD %"))
        st.altair_chart((bars + line).resolve_scale(y='independent'), use_container_width=True)
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
    SELECT c.name AS customer_name, ex.exception_type, COUNT(*) AS exceptions
    FROM ex
    JOIN {database}.{edw_schema}.FACT_SHIPMENT f ON f.shipment_id = ex.shipment_id
    JOIN {database}.{edw_schema}.DIM_CUSTOMER c ON c.customer_id = f.customer_id
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
      c.name AS customer_name,
      cr.name AS carrier_name,
      o.city || ' → ' || d.city AS lane,
      f.status,
      f.pickup_plan_ts, f.pickup_actual_ts,
      f.delivery_plan_ts, f.delivery_actual_ts,
      IFF(f.delivery_actual_ts IS NOT NULL AND f.delivery_actual_ts <= f.delivery_plan_ts + {grace} * INTERVAL '1 MINUTE', TRUE, FALSE) AS isdeliveredontime,
      f.isinfull, (IFF(f.delivery_actual_ts IS NOT NULL AND f.delivery_actual_ts <= f.delivery_plan_ts + {grace} * INTERVAL '1 MINUTE', TRUE, FALSE) AND f.isinfull) AS isotif,
      f.planned_miles, f.actual_miles, f.revenue, f.total_cost,
      (f.revenue - f.total_cost) / NULLIF(f.planned_miles, 0) AS gm_per_mile
    FROM {database}.{edw_schema}.FACT_SHIPMENT f
    JOIN {database}.{edw_schema}.DIM_CUSTOMER c ON c.customer_id = f.customer_id
    JOIN {database}.{edw_schema}.DIM_CARRIER cr ON cr.carrier_id = f.carrier_id
    JOIN {database}.{edw_schema}.DIM_LANE l ON l.lane_id = f.lane_id
    JOIN {database}.{edw_schema}.DIM_LOCATION o ON o.loc_id = l.origin_loc_id
    JOIN {database}.{edw_schema}.DIM_LOCATION d ON d.loc_id = l.dest_loc_id
    WHERE 1=1 {filters}
    ORDER BY f.shipment_id, f.leg_id
    LIMIT 1000
    """
    drill_df = run_df(drill_sql)
    st.subheader("Shipment Details (top 1000)")
    st.dataframe(drill_df, use_container_width=True)


if __name__ == "__main__":
    main()
