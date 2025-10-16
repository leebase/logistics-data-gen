-- Run after loading STG or EDW (adjust schema references).
USE DATABASE IDENTIFIER('<DATABASE>');

-- Parameters (edit schemas if needed)
SET STG = '<STG_SCHEMA>';
SET EDW = '<EDW_SCHEMA>';

-- Day-level counts (deliveries)
SELECT DATE(delivery_actual_ts) AS delivery_date, COUNT(*) AS delivered_cnt
FROM IDENTIFIER($EDW).FACT_SHIPMENT
WHERE delivery_actual_ts IS NOT NULL
GROUP BY 1
ORDER BY 1
LIMIT 100;

-- OTD bounds (0–100%)
WITH delivered AS (
  SELECT COUNT(*) AS n
  FROM IDENTIFIER($EDW).FACT_SHIPMENT
  WHERE delivery_actual_ts IS NOT NULL
),
otd AS (
  SELECT COUNT(*) AS n
  FROM IDENTIFIER($EDW).FACT_SHIPMENT
  WHERE delivery_actual_ts IS NOT NULL AND isdeliveredontime = TRUE
)
SELECT
  otd.n::FLOAT / NULLIF(delivered.n,0) AS otd_rate
FROM delivered, otd;

-- Orphan event checks (events without shipments)
SELECT e.shipment_id, COUNT(*) AS event_rows
FROM IDENTIFIER($EDW).FACT_EVENT e
LEFT JOIN IDENTIFIER($EDW).FACT_SHIPMENT s
  ON s.shipment_id = e.shipment_id
WHERE s.shipment_id IS NULL
GROUP BY 1
HAVING COUNT(*) > 0;

-- Invalid FK checks (location and lane integrity)
SELECT COUNT(*) AS invalid_origin_fk
FROM IDENTIFIER($EDW).FACT_SHIPMENT f
LEFT JOIN IDENTIFIER($EDW).DIM_LOCATION d ON f.origin_loc_id = d.loc_id
WHERE d.loc_id IS NULL;

SELECT COUNT(*) AS invalid_dest_fk
FROM IDENTIFIER($EDW).FACT_SHIPMENT f
LEFT JOIN IDENTIFIER($EDW).DIM_LOCATION d ON f.dest_loc_id = d.loc_id
WHERE d.loc_id IS NULL;

SELECT COUNT(*) AS invalid_lane_fk
FROM IDENTIFIER($EDW).FACT_SHIPMENT f
LEFT JOIN IDENTIFIER($EDW).DIM_LANE l ON f.lane_id = l.lane_id
WHERE l.lane_id IS NULL;

-- Average transit days sanity
SELECT AVG(DATEDIFF('day', pickup_actual_ts, delivery_actual_ts)) AS avg_transit_days
FROM IDENTIFIER($EDW).FACT_SHIPMENT
WHERE pickup_actual_ts IS NOT NULL AND delivery_actual_ts IS NOT NULL;

-- Exception counts
SELECT COUNT(*) AS exceptions
FROM IDENTIFIER($EDW).FACT_EVENT
WHERE event_type = 'Exception';

