-- Dashboard Test SQL Pack (robust timestamp handling)
-- Mirrors the dashboard queries and uses the exact inline pattern you provided
-- so there are no ambiguous column names:
--   COUNT(NULLIF(TRIM(col), ''))
--   CAST(TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(col), '')) AS DATE)

-- 0) Snapshot: confirm data presence + min/max delivery dates
SELECT
  COUNT(*) AS total_rows,
  COUNT(NULLIF(TRIM(delivery_actual_ts), '')) AS delivered_rows,
  MIN(CAST(TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(delivery_actual_ts), '')) AS DATE)) AS min_delivery_date,
  MAX(CAST(TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(delivery_actual_ts), '')) AS DATE)) AS max_delivery_date
FROM LOGISTICS_DB.EDW.FACT_SHIPMENT;

-- 1) Bounds: last 180 days from latest delivered date
WITH delivered AS (
  SELECT CAST(TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(delivery_actual_ts), '')) AS DATE) AS d
  FROM LOGISTICS_DB.EDW.FACT_SHIPMENT
  WHERE NULLIF(TRIM(delivery_actual_ts), '') IS NOT NULL
),
anchor AS (
  SELECT MAX(d) AS anchor_date FROM delivered
),
bounds AS (
  SELECT DATEADD('day', -180, anchor_date) AS start_d, anchor_date AS end_d
  FROM anchor
)
SELECT start_d, end_d FROM bounds;

-- 2) OTD % (Last 30 vs Prior 30) within bounds (grace=60 minutes)
WITH delivered AS (
  SELECT CAST(TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(delivery_actual_ts), '')) AS DATE) AS d
  FROM LOGISTICS_DB.EDW.FACT_SHIPMENT
  WHERE NULLIF(TRIM(delivery_actual_ts), '') IS NOT NULL
),
bounds AS (
  SELECT DATEADD('day', -180, MAX(d)) AS start_d, MAX(d) AS end_d FROM delivered
),
params AS (SELECT 60::NUMBER AS grace),
otd_src AS (
  SELECT
    CAST(TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(delivery_actual_ts), '')) AS DATE) AS d,
    IFF(
      TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(delivery_actual_ts), ''))
        <= DATEADD('minute', (SELECT grace FROM params), TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(delivery_plan_ts), ''))),
      1, 0
    ) AS is_otd
  FROM LOGISTICS_DB.EDW.FACT_SHIPMENT
  WHERE NULLIF(TRIM(delivery_actual_ts), '') IS NOT NULL
    AND CAST(TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(delivery_actual_ts), '')) AS DATE)
        BETWEEN (SELECT start_d FROM bounds) AND (SELECT end_d FROM bounds)
),
anchor AS (SELECT MAX(d) AS anchor_date FROM otd_src),
win AS (
  SELECT anchor_date,
         DATEADD('day', -29, anchor_date) AS last30_start,
         anchor_date AS last30_end,
         DATEADD('day', -60, anchor_date) AS prev30_start,
         DATEADD('day', -30, anchor_date) AS prev30_end
  FROM anchor
),
last30 AS (
  SELECT COUNT(1) AS n_deliv, SUM(is_otd) AS n_otd
  FROM otd_src, win
  WHERE otd_src.d BETWEEN win.last30_start AND win.last30_end
),
prev30 AS (
  SELECT COUNT(1) AS n_deliv, SUM(is_otd) AS n_otd
  FROM otd_src, win
  WHERE otd_src.d BETWEEN win.prev30_start AND win.prev30_end
)
SELECT
  (last30.n_otd::FLOAT / NULLIF(last30.n_deliv,0)) AS otd_last_30,
  (prev30.n_otd::FLOAT / NULLIF(prev30.n_deliv,0)) AS otd_prior_30,
  (last30.n_otd::FLOAT / NULLIF(last30.n_deliv,0)) - (prev30.n_otd::FLOAT / NULLIF(prev30.n_deliv,0)) AS otd_delta_pp
FROM last30, prev30;

-- 3) GM per Mile (YTD) relative to anchor
WITH delivered AS (
  SELECT CAST(TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(delivery_actual_ts), '')) AS DATE) AS d
  FROM LOGISTICS_DB.EDW.FACT_SHIPMENT
  WHERE NULLIF(TRIM(delivery_actual_ts), '') IS NOT NULL
),
anchor AS (
  SELECT MAX(d) AS anchor_date FROM delivered
),
ytd AS (
  SELECT SUM(revenue) AS rev, SUM(total_cost) AS cost, SUM(planned_miles) AS miles
  FROM LOGISTICS_DB.EDW.FACT_SHIPMENT, anchor
  WHERE NULLIF(TRIM(delivery_actual_ts), '') IS NOT NULL
    AND CAST(TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(delivery_actual_ts), '')) AS DATE)
        BETWEEN DATE_TRUNC('year', anchor.anchor_date) AND anchor.anchor_date
)
SELECT (rev - cost) / NULLIF(miles, 0) AS gm_per_mile
FROM ytd;

-- 4) Tender Acceptance % (events-derived) inside bounds
WITH delivered AS (
  SELECT CAST(TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(delivery_actual_ts), '')) AS DATE) AS d
  FROM LOGISTICS_DB.EDW.FACT_SHIPMENT
  WHERE NULLIF(TRIM(delivery_actual_ts), '') IS NOT NULL
),
bounds AS (
  SELECT DATEADD('day', -180, MAX(d)) AS start_d, MAX(d) AS end_d FROM delivered
),
e AS (
  SELECT shipment_id,
         event_type,
         TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(event_ts), '')) AS event_ts
  FROM LOGISTICS_DB.EDW.FACT_EVENT
),
tendered AS (
  SELECT DISTINCT shipment_id
  FROM e
  WHERE event_type = 'Tendered'
    AND CAST(event_ts AS DATE) BETWEEN (SELECT start_d FROM bounds) AND (SELECT end_d FROM bounds)
),
accepted AS (
  SELECT DISTINCT shipment_id
  FROM e
  WHERE event_type = 'Accepted'
    AND CAST(event_ts AS DATE) BETWEEN (SELECT start_d FROM bounds) AND (SELECT end_d FROM bounds)
)
SELECT (SELECT COUNT(1) FROM accepted)::FLOAT / NULLIF((SELECT COUNT(1) FROM tendered), 0) AS tender_acceptance_rate;

-- 5) Avg Transit Days inside bounds
WITH delivered AS (
  SELECT CAST(TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(delivery_actual_ts), '')) AS DATE) AS d
  FROM LOGISTICS_DB.EDW.FACT_SHIPMENT
  WHERE NULLIF(TRIM(delivery_actual_ts), '') IS NOT NULL
),
bounds AS (
  SELECT DATEADD('day', -180, MAX(d)) AS start_d, MAX(d) AS end_d FROM delivered
)
SELECT AVG(DATEDIFF(
           'day',
           TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(pickup_actual_ts), '')),
           TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(delivery_actual_ts), ''))
       )) AS avg_transit_days
FROM LOGISTICS_DB.EDW.FACT_SHIPMENT
WHERE NULLIF(TRIM(pickup_actual_ts), '') IS NOT NULL
  AND NULLIF(TRIM(delivery_actual_ts), '') IS NOT NULL
  AND CAST(TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(delivery_actual_ts), '')) AS DATE)
        BETWEEN (SELECT start_d FROM bounds) AND (SELECT end_d FROM bounds);

-- 6) Lane Performance (Avg Transit Days, OTD %) inside bounds
WITH delivered AS (
  SELECT CAST(TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(delivery_actual_ts), '')) AS DATE) AS d
  FROM LOGISTICS_DB.EDW.FACT_SHIPMENT
  WHERE NULLIF(TRIM(delivery_actual_ts), '') IS NOT NULL
),
bounds AS (
  SELECT DATEADD('day', -180, MAX(d)) AS start_d, MAX(d) AS end_d FROM delivered
),
params AS (SELECT 60::NUMBER AS grace)
SELECT
  o.city || ' → ' || d.city AS lane,
  COUNT(1) AS shipments,
  AVG(DATEDIFF(
        'day',
        TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(f.pickup_actual_ts), '')),
        TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(f.delivery_actual_ts), ''))
      )) AS avg_transit_days,
  AVG(IFF(
        NULLIF(TRIM(f.delivery_actual_ts), '') IS NOT NULL
        AND TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(f.delivery_actual_ts), ''))
              <= DATEADD('minute', (SELECT grace FROM params), TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(f.delivery_plan_ts), ''))),
        1, 0
      )) AS otd_rate
FROM LOGISTICS_DB.EDW.FACT_SHIPMENT f
JOIN LOGISTICS_DB.EDW.DIM_LANE l ON f.lane_id = l.lane_id
JOIN LOGISTICS_DB.EDW.DIM_LOCATION o ON l.origin_loc_id = o.loc_id
JOIN LOGISTICS_DB.EDW.DIM_LOCATION d ON l.dest_loc_id = d.loc_id
WHERE NULLIF(TRIM(f.pickup_actual_ts), '') IS NOT NULL
  AND NULLIF(TRIM(f.delivery_actual_ts), '') IS NOT NULL
  AND CAST(TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(f.delivery_actual_ts), '')) AS DATE)
        BETWEEN (SELECT start_d FROM bounds) AND (SELECT end_d FROM bounds)
GROUP BY 1
ORDER BY shipments DESC
LIMIT 50;

-- 7) Exception Heatmap (Exception Type × Customer) inside bounds
WITH delivered AS (
  SELECT CAST(TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(delivery_actual_ts), '')) AS DATE) AS d
  FROM LOGISTICS_DB.EDW.FACT_SHIPMENT
  WHERE NULLIF(TRIM(delivery_actual_ts), '') IS NOT NULL
),
bounds AS (
  SELECT DATEADD('day', -180, MAX(d)) AS start_d, MAX(d) AS end_d FROM delivered
),
ex_raw AS (
  SELECT
    shipment_id,
    COALESCE(NULLIF(TRIM(notes), ''), 'Unknown') AS exception_type,
    TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(event_ts), '')) AS event_ts
  FROM LOGISTICS_DB.EDW.FACT_EVENT
  WHERE event_type = 'Exception'
),
ex AS (
  SELECT shipment_id, exception_type
  FROM ex_raw
  WHERE CAST(event_ts AS DATE) BETWEEN (SELECT start_d FROM bounds) AND (SELECT end_d FROM bounds)
)
SELECT c.name AS customer_name, ex.exception_type, COUNT(1) AS exceptions
FROM ex
JOIN LOGISTICS_DB.EDW.FACT_SHIPMENT f ON f.shipment_id = ex.shipment_id
JOIN LOGISTICS_DB.EDW.DIM_CUSTOMER c ON c.customer_id = f.customer_id
GROUP BY 1,2
ORDER BY 1,2;

-- 8) Drill (top 1000) inside bounds
WITH delivered AS (
  SELECT CAST(TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(delivery_actual_ts), '')) AS DATE) AS d
  FROM LOGISTICS_DB.EDW.FACT_SHIPMENT
  WHERE NULLIF(TRIM(delivery_actual_ts), '') IS NOT NULL
),
bounds AS (
  SELECT DATEADD('day', -180, MAX(d)) AS start_d, MAX(d) AS end_d FROM delivered
)
SELECT
  f.shipment_id, f.leg_id,
  c.name AS customer_name,
  cr.name AS carrier_name,
  o.city || ' → ' || d.city AS lane,
  f.status,
  TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(f.pickup_plan_ts), ''))    AS pickup_plan_ts,
  TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(f.pickup_actual_ts), ''))  AS pickup_actual_ts,
  TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(f.delivery_plan_ts), ''))  AS delivery_plan_ts,
  TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(f.delivery_actual_ts), '')) AS delivery_actual_ts,
  IFF(
      NULLIF(TRIM(f.delivery_actual_ts), '') IS NOT NULL
      AND TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(f.delivery_actual_ts), ''))
            <= DATEADD('minute', 60, TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(f.delivery_plan_ts), ''))),
      TRUE, FALSE
    ) AS isdeliveredontime,
  f.isinfull,
  (IFF(
      NULLIF(TRIM(f.delivery_actual_ts), '') IS NOT NULL
      AND TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(f.delivery_actual_ts), ''))
            <= DATEADD('minute', 60, TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(f.delivery_plan_ts), ''))),
      TRUE, FALSE
    ) AND f.isinfull) AS isotif,
  f.planned_miles, f.actual_miles, f.revenue, f.total_cost,
  (f.revenue - f.total_cost) / NULLIF(f.planned_miles, 0) AS gm_per_mile
FROM LOGISTICS_DB.EDW.FACT_SHIPMENT f
JOIN LOGISTICS_DB.EDW.DIM_CUSTOMER c ON c.customer_id = f.customer_id
JOIN LOGISTICS_DB.EDW.DIM_CARRIER cr ON cr.carrier_id = f.carrier_id
JOIN LOGISTICS_DB.EDW.DIM_LANE l ON l.lane_id = f.lane_id
JOIN LOGISTICS_DB.EDW.DIM_LOCATION o ON o.loc_id = l.origin_loc_id
JOIN LOGISTICS_DB.EDW.DIM_LOCATION d ON d.loc_id = l.dest_loc_id
WHERE CAST(TRY_TO_TIMESTAMP_TZ(NULLIF(TRIM(f.delivery_actual_ts), '')) AS DATE)
        BETWEEN (SELECT start_d FROM bounds) AND (SELECT end_d FROM bounds)
ORDER BY f.shipment_id, f.leg_id
LIMIT 1000;

