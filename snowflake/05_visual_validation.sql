-- Visual Validation Pack
-- Purpose: Reproduce the Power BI visual calculations directly in Snowflake to validate curated EDW data.
-- How to run:
--   1) Replace placeholders <DATABASE>, <EDW_SCHEMA> as needed, or USE DATABASE and SET EDW.
--   2) Optionally override parameters (GRACE_MINUTES, TARGET_GM_PER_MILE).
--   3) Execute each section independently to inspect results.

USE DATABASE IDENTIFIER('<DATABASE>');
SET EDW = '<EDW_SCHEMA>';

-- Parameters
SET GRACE_MINUTES = 60;          -- Match PBI What-If parameter (0–120)
SET TARGET_GM_PER_MILE = 0.40;   -- Match PBI GM/Mile target parameter

-- Anchor date (latest delivery date in data)
WITH maxd AS (
  SELECT MAX(DATE(delivery_actual_ts)) AS anchor_date
  FROM IDENTIFIER($EDW).FACT_SHIPMENT
  WHERE delivery_actual_ts IS NOT NULL
)
SELECT * FROM maxd;

/* ======================================================================
   1) KPI — OTD % Last 30 vs Prior 30, and Delta (percentage points)
   Purpose: Validates time-window OTD calculations based on delivery_plan_ts
            and a configurable grace period in minutes.
   Mirrors PBI measures: [OTD % Last 30 Days], [OTD % Prior 30 Days], [OTD % 30d Delta]
====================================================================== */
WITH params AS (
  SELECT $GRACE_MINUTES::NUMBER AS grace
), anchor AS (
  SELECT MAX(DATE(delivery_actual_ts)) AS anchor_date
  FROM IDENTIFIER($EDW).FACT_SHIPMENT
  WHERE delivery_actual_ts IS NOT NULL
), delivered AS (
  SELECT
    DATE(delivery_actual_ts) AS d,
    IFF(delivery_actual_ts <= delivery_plan_ts + (SELECT grace FROM params) * INTERVAL '1 MINUTE', 1, 0) AS is_otd
  FROM IDENTIFIER($EDW).FACT_SHIPMENT
  WHERE delivery_actual_ts IS NOT NULL
), win AS (
  SELECT a.anchor_date,
         DATEADD('day', -29, a.anchor_date) AS last30_start,
         a.anchor_date AS last30_end,
         DATEADD('day', -60, a.anchor_date) AS prev30_start,
         DATEADD('day', -30, a.anchor_date) AS prev30_end
  FROM anchor a
), last30 AS (
  SELECT COUNT(*) AS n_deliv, SUM(is_otd) AS n_otd
  FROM delivered, win
  WHERE delivered.d BETWEEN win.last30_start AND win.last30_end
), prev30 AS (
  SELECT COUNT(*) AS n_deliv, SUM(is_otd) AS n_otd
  FROM delivered, win
  WHERE delivered.d BETWEEN win.prev30_start AND win.prev30_end
)
SELECT
  win.anchor_date,
  (last30.n_otd::FLOAT / NULLIF(last30.n_deliv,0)) AS otd_last_30,
  (prev30.n_otd::FLOAT / NULLIF(prev30.n_deliv,0)) AS otd_prior_30,
  (last30.n_otd::FLOAT / NULLIF(last30.n_deliv,0)) - (prev30.n_otd::FLOAT / NULLIF(prev30.n_deliv,0)) AS otd_delta_pp,
  last30.n_deliv AS delivered_last_30,
  prev30.n_deliv AS delivered_prior_30,
  (SELECT grace FROM params) AS grace_minutes
FROM win, last30, prev30
;

/* ======================================================================
   2) KPI — GM per Mile (YTD) and variance to target
   Purpose: Validates profitability metric over YTD window relative to target.
   Mirrors PBI measures: [GM/Mile YTD], [GM/Mile vs Target (pp)]
====================================================================== */
WITH anchor AS (
  SELECT MAX(DATE(delivery_actual_ts)) AS anchor_date
  FROM IDENTIFIER($EDW).FACT_SHIPMENT
  WHERE delivery_actual_ts IS NOT NULL
), ytd AS (
  SELECT
    SUM(revenue) AS rev,
    SUM(total_cost) AS cost,
    SUM(planned_miles) AS miles
  FROM IDENTIFIER($EDW).FACT_SHIPMENT, anchor
  WHERE delivery_actual_ts IS NOT NULL
    AND DATE(delivery_actual_ts) BETWEEN DATE_TRUNC('year', anchor.anchor_date) AND anchor.anchor_date
)
SELECT
  (rev - cost) / NULLIF(miles, 0) AS gm_per_mile_ytd,
  $TARGET_GM_PER_MILE AS target_gm_per_mile,
  ((rev - cost) / NULLIF(miles, 0)) - $TARGET_GM_PER_MILE AS variance_pp
FROM ytd
;

/* ======================================================================
   3) KPI — Tender Acceptance %
   Purpose: Validates acceptance rate using two approaches:
     A) Events-derived (distinct shipments with Accepted over Tendered)
     B) Status-derived (shipments not Cancelled out of Tendered universe)
   Mirrors PBI measure: [Tender Acceptance %]
====================================================================== */
-- A) Events-derived
WITH tendered AS (
  SELECT DISTINCT shipment_id
  FROM IDENTIFIER($EDW).FACT_EVENT
  WHERE event_type = 'Tendered'
), accepted AS (
  SELECT DISTINCT shipment_id
  FROM IDENTIFIER($EDW).FACT_EVENT
  WHERE event_type = 'Accepted'
)
SELECT
  (SELECT COUNT(*) FROM accepted)::FLOAT / NULLIF((SELECT COUNT(*) FROM tendered), 0) AS tender_acceptance_events
;

-- B) Status-derived (informational; depends on generator semantics)
SELECT
  COUNT_IF(status IN ('Accepted','In-Transit','Delivered','Exception'))::FLOAT
  / NULLIF(COUNT_IF(status IN ('Tendered','Accepted','In-Transit','Delivered','Exception','Cancelled')), 0)
  AS tender_acceptance_status
FROM IDENTIFIER($EDW).FACT_SHIPMENT
;

/* ======================================================================
   4) KPI — Avg Transit Days (overall and by month)
   Purpose: Validates transit-time metric for shipped freight.
   Mirrors PBI measure: [Avg Transit Days]
====================================================================== */
-- Overall
SELECT AVG(DATEDIFF('day', pickup_actual_ts, delivery_actual_ts)) AS avg_transit_days
FROM IDENTIFIER($EDW).FACT_SHIPMENT
WHERE pickup_actual_ts IS NOT NULL AND delivery_actual_ts IS NOT NULL
;

-- By calendar month of delivery
SELECT
  DATE_TRUNC('month', delivery_actual_ts) AS month,
  AVG(DATEDIFF('day', pickup_actual_ts, delivery_actual_ts)) AS avg_transit_days
FROM IDENTIFIER($EDW).FACT_SHIPMENT
WHERE pickup_actual_ts IS NOT NULL AND delivery_actual_ts IS NOT NULL
GROUP BY 1
ORDER BY 1
;

/* ======================================================================
   5) Lane Performance — Avg Transit Days (column) + OTD % (line)
   Purpose: Validates the combo visual values by lane.
   Mirrors PBI Lane Performance chart.
====================================================================== */
WITH params AS (
  SELECT $GRACE_MINUTES::NUMBER AS grace
), lane_perf AS (
  SELECT
    l.lane_id,
    o.city || ' → ' || d.city AS lane_label,
    COUNT(*) AS shipments,
    AVG(DATEDIFF('day', f.pickup_actual_ts, f.delivery_actual_ts)) AS avg_transit_days,
    AVG(IFF(f.delivery_actual_ts IS NOT NULL AND f.delivery_actual_ts <= f.delivery_plan_ts + (SELECT grace FROM params) * INTERVAL '1 MINUTE', 1, 0)) AS otd_rate
  FROM IDENTIFIER($EDW).FACT_SHIPMENT f
  JOIN IDENTIFIER($EDW).DIM_LANE l ON f.lane_id = l.lane_id
  JOIN IDENTIFIER($EDW).DIM_LOCATION o ON l.origin_loc_id = o.loc_id
  JOIN IDENTIFIER($EDW).DIM_LOCATION d ON l.dest_loc_id = d.loc_id
  WHERE f.pickup_actual_ts IS NOT NULL AND f.delivery_actual_ts IS NOT NULL
  GROUP BY 1,2
)
SELECT *
FROM lane_perf
ORDER BY shipments DESC
LIMIT 100
;

/* ======================================================================
   6) Exception Heatmap — Exception Type × Customer
   Purpose: Validates exception counts across customers by type.
   Mirrors PBI heatmap (matrix) values.
====================================================================== */
WITH ex AS (
  SELECT e.shipment_id,
         COALESCE(NULLIF(TRIM(e.notes), ''), 'Unknown') AS exception_type
  FROM IDENTIFIER($EDW).FACT_EVENT e
  WHERE e.event_type = 'Exception'
)
SELECT
  c.name AS customer_name,
  ex.exception_type,
  COUNT(*) AS exceptions
FROM ex
JOIN IDENTIFIER($EDW).FACT_SHIPMENT f ON f.shipment_id = ex.shipment_id
JOIN IDENTIFIER($EDW).DIM_CUSTOMER c ON c.customer_id = f.customer_id
GROUP BY 1,2
ORDER BY 1,2
LIMIT 500
;

/* ======================================================================
   7) Drill Page — Shipment Detail
   Purpose: Returns rows that populate the drill-through table in PBI with core fields.
   Mirrors PBI drill-through table columns.
====================================================================== */
SELECT
  f.shipment_id,
  f.leg_id,
  c.name AS customer_name,
  cr.name AS carrier_name,
  o.city || ' → ' || d.city AS lane_label,
  f.status,
  f.pickup_plan_ts,
  f.pickup_actual_ts,
  f.delivery_plan_ts,
  f.delivery_actual_ts,
  IFF(f.delivery_actual_ts IS NOT NULL AND f.delivery_actual_ts <= f.delivery_plan_ts + $GRACE_MINUTES * INTERVAL '1 MINUTE', TRUE, FALSE) AS isdeliveredontime_calc,
  f.isinfull,
  (IFFIXNULL(isdeliveredontime_calc, FALSE) AND f.isinfull) AS isotif_calc,
  f.planned_miles,
  f.actual_miles,
  f.revenue,
  f.total_cost,
  (f.revenue - f.total_cost) / NULLIF(f.planned_miles, 0) AS gm_per_mile
FROM IDENTIFIER($EDW).FACT_SHIPMENT f
JOIN IDENTIFIER($EDW).DIM_CUSTOMER c ON c.customer_id = f.customer_id
JOIN IDENTIFIER($EDW).DIM_CARRIER cr ON cr.carrier_id = f.carrier_id
JOIN IDENTIFIER($EDW).DIM_LANE l ON l.lane_id = f.lane_id
JOIN IDENTIFIER($EDW).DIM_LOCATION o ON o.loc_id = l.origin_loc_id
JOIN IDENTIFIER($EDW).DIM_LOCATION d ON d.loc_id = l.dest_loc_id
-- Optional filters for drill
-- WHERE DATE(f.delivery_actual_ts) BETWEEN '2024-01-01' AND '2024-06-30'
ORDER BY f.shipment_id, f.leg_id
LIMIT 1000
;

