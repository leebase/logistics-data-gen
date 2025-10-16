-- Curate EDW tables from STG. Compute on-time & OTIF flags, ensure lane derivation, normalize types.

USE DATABASE IDENTIFIER('<DATABASE>');

-- Idempotent upserts leveraging MERGE templates defined in snowflake/03_merge_upserts.sql.
-- Option A: Reference MERGE templates directly (preferred).
-- Option B: Inline transforms (simplified below).

-- 1) Upsert dimensions
-- (Assume STG loaded; either call MERGE templates or run inline copies.)
MERGE INTO IDENTIFIER('<EDW_SCHEMA>').DIM_CUSTOMER t
USING IDENTIFIER('<STG_SCHEMA>').DIM_CUSTOMER s
ON t.customer_id = s.customer_id
WHEN MATCHED THEN UPDATE SET name=s.name, segment=s.segment, region=s.region, update_date=s.update_date
WHEN NOT MATCHED THEN INSERT (customer_id,name,segment,region,load_date,update_date)
VALUES (s.customer_id,s.name,s.segment,s.region,COALESCE(s.load_date,CURRENT_TIMESTAMP()),COALESCE(s.update_date,CURRENT_TIMESTAMP()));

MERGE INTO IDENTIFIER('<EDW_SCHEMA>').DIM_CARRIER t
USING IDENTIFIER('<STG_SCHEMA>').DIM_CARRIER s
ON t.carrier_id = s.carrier_id
WHEN MATCHED THEN UPDATE SET name=s.name, mode=s.mode, mc_number=s.mc_number, score_tier=s.score_tier, update_date=s.update_date
WHEN NOT MATCHED THEN INSERT (carrier_id,name,mode,mc_number,score_tier,load_date,update_date)
VALUES (s.carrier_id,s.name,s.mode,s.mc_number,s.score_tier,COALESCE(s.load_date,CURRENT_TIMESTAMP()),COALESCE(s.update_date,CURRENT_TIMESTAMP()));

MERGE INTO IDENTIFIER('<EDW_SCHEMA>').DIM_EQUIPMENT t
USING IDENTIFIER('<STG_SCHEMA>').DIM_EQUIPMENT s
ON t.equipment_id = s.equipment_id
WHEN MATCHED THEN UPDATE SET type=s.type, capacity_lbs=s.capacity_lbs, update_date=s.update_date
WHEN NOT MATCHED THEN INSERT (equipment_id,type,capacity_lbs,load_date,update_date)
VALUES (s.equipment_id,s.type,s.capacity_lbs,COALESCE(s.load_date,CURRENT_TIMESTAMP()),COALESCE(s.update_date,CURRENT_TIMESTAMP()));

MERGE INTO IDENTIFIER('<EDW_SCHEMA>').DIM_LOCATION t
USING IDENTIFIER('<STG_SCHEMA>').DIM_LOCATION s
ON t.loc_id = s.loc_id
WHEN MATCHED THEN UPDATE SET name=s.name, city=s.city, state=s.state, country=s.country, timezone=s.timezone, type=s.type, update_date=s.update_date
WHEN NOT MATCHED THEN INSERT (loc_id,name,city,state,country,timezone,type,load_date,update_date)
VALUES (s.loc_id,s.name,s.city,s.state,s.country,s.timezone,s.type,COALESCE(s.load_date,CURRENT_TIMESTAMP()),COALESCE(s.update_date,CURRENT_TIMESTAMP()));

MERGE INTO IDENTIFIER('<EDW_SCHEMA>').DIM_LANE t
USING IDENTIFIER('<STG_SCHEMA>').DIM_LANE s
ON t.lane_id = s.lane_id
WHEN MATCHED THEN UPDATE SET origin_loc_id=s.origin_loc_id, dest_loc_id=s.dest_loc_id, standard_miles=s.standard_miles, std_transit_days=s.std_transit_days, update_date=s.update_date
WHEN NOT MATCHED THEN INSERT (lane_id,origin_loc_id,dest_loc_id,standard_miles,std_transit_days,load_date,update_date)
VALUES (s.lane_id,s.origin_loc_id,s.dest_loc_id,s.standard_miles,s.std_transit_days,COALESCE(s.load_date,CURRENT_TIMESTAMP()),COALESCE(s.update_date,CURRENT_TIMESTAMP()));

MERGE INTO IDENTIFIER('<EDW_SCHEMA>').DIM_DATE t
USING IDENTIFIER('<STG_SCHEMA>').DIM_DATE s
ON t.date_key = s.date_key
WHEN MATCHED THEN UPDATE SET date=s.date, year=s.year, quarter=s.quarter, month=s.month, week=s.week, dow=s.dow, is_weekend=s.is_weekend, update_date=s.update_date
WHEN NOT MATCHED THEN INSERT (date_key,date,year,quarter,month,week,dow,is_weekend,load_date,update_date)
VALUES (s.date_key,s.date,s.year,s.quarter,s.month,s.week,s.dow,s.is_weekend,COALESCE(s.load_date,CURRENT_TIMESTAMP()),COALESCE(s.update_date,CURRENT_TIMESTAMP()));

-- 2) Normalize types and compute flags for shipments
CREATE OR REPLACE TEMP TABLE TMP_FACT_SHIPMENT AS
SELECT
  shipment_id,
  leg_id,
  customer_id,
  carrier_id,
  equipment_id,
  origin_loc_id,
  dest_loc_id,
  lane_id,
  CAST(tender_ts AS TIMESTAMP_NTZ) AS tender_ts,
  CAST(pickup_plan_ts AS TIMESTAMP_NTZ) AS pickup_plan_ts,
  CAST(pickup_actual_ts AS TIMESTAMP_NTZ) AS pickup_actual_ts,
  CAST(delivery_plan_ts AS TIMESTAMP_NTZ) AS delivery_plan_ts,
  CAST(delivery_actual_ts AS TIMESTAMP_NTZ) AS delivery_actual_ts,
  planned_miles,
  actual_miles,
  pieces,
  weight_lbs,
  cube,
  revenue,
  total_cost,
  fuel_surcharge,
  accessorial_cost,
  status,
  -- Recompute with grace minutes parameter (default 60)
  IFF(delivery_actual_ts IS NOT NULL AND delivery_actual_ts <= delivery_plan_ts + INTERVAL '60' MINUTE, TRUE, FALSE) AS isdeliveredontime,
  isinfull,
  IFF(
    (delivery_actual_ts IS NOT NULL AND delivery_actual_ts <= delivery_plan_ts + INTERVAL '60' MINUTE) AND (isinfull = TRUE),
    TRUE, FALSE
  ) AS isotif,
  cancel_flag,
  load_date,
  update_date
FROM IDENTIFIER('<STG_SCHEMA>').FACT_SHIPMENT;

MERGE INTO IDENTIFIER('<EDW_SCHEMA>').FACT_SHIPMENT t
USING TMP_FACT_SHIPMENT s
ON t.shipment_id = s.shipment_id AND t.leg_id = s.leg_id
WHEN MATCHED AND s.update_date >= t.update_date THEN UPDATE SET
  customer_id=s.customer_id, carrier_id=s.carrier_id, equipment_id=s.equipment_id,
  origin_loc_id=s.origin_loc_id, dest_loc_id=s.dest_loc_id, lane_id=s.lane_id,
  tender_ts=s.tender_ts, pickup_plan_ts=s.pickup_plan_ts, pickup_actual_ts=s.pickup_actual_ts,
  delivery_plan_ts=s.delivery_plan_ts, delivery_actual_ts=s.delivery_actual_ts,
  planned_miles=s.planned_miles, actual_miles=s.actual_miles, pieces=s.pieces, weight_lbs=s.weight_lbs, cube=s.cube,
  revenue=s.revenue, total_cost=s.total_cost, fuel_surcharge=s.fuel_surcharge, accessorial_cost=s.accessorial_cost,
  status=s.status, isdeliveredontime=s.isdeliveredontime, isinfull=s.isinfull, isotif=s.isotif,
  cancel_flag=s.cancel_flag, update_date=s.update_date
WHEN NOT MATCHED THEN INSERT (
  shipment_id, leg_id, customer_id, carrier_id, equipment_id, origin_loc_id, dest_loc_id, lane_id,
  tender_ts, pickup_plan_ts, pickup_actual_ts, delivery_plan_ts, delivery_actual_ts,
  planned_miles, actual_miles, pieces, weight_lbs, cube, revenue, total_cost, fuel_surcharge, accessorial_cost,
  status, isdeliveredontime, isinfull, isotif, cancel_flag, load_date, update_date
) VALUES (
  s.shipment_id, s.leg_id, s.customer_id, s.carrier_id, s.equipment_id, s.origin_loc_id, s.dest_loc_id, s.lane_id,
  s.tender_ts, s.pickup_plan_ts, s.pickup_actual_ts, s.delivery_plan_ts, s.delivery_actual_ts,
  s.planned_miles, s.actual_miles, s.pieces, s.weight_lbs, s.cube, s.revenue, s.total_cost, s.fuel_surcharge, s.accessorial_cost,
  s.status, s.isdeliveredontime, s.isinfull, s.isotif, s.cancel_flag, s.load_date, s.update_date
);

-- 3) Events and Costs (pass-through upserts)
MERGE INTO IDENTIFIER('<EDW_SCHEMA>').FACT_EVENT t
USING IDENTIFIER('<STG_SCHEMA>').FACT_EVENT s
ON t.shipment_id = s.shipment_id AND t.event_seq = s.event_seq
WHEN MATCHED AND s.update_date >= t.update_date THEN
  UPDATE SET event_type=s.event_type, event_ts=s.event_ts, facility_loc_id=s.facility_loc_id, notes=s.notes, update_date=s.update_date
WHEN NOT MATCHED THEN
  INSERT (shipment_id,event_seq,event_type,event_ts,facility_loc_id,notes,load_date,update_date)
  VALUES (s.shipment_id,s.event_seq,s.event_type,s.event_ts,s.facility_loc_id,s.notes,s.load_date,s.update_date);

MERGE INTO IDENTIFIER('<EDW_SCHEMA>').FACT_COST t
USING IDENTIFIER('<STG_SCHEMA>').FACT_COST s
ON t.shipment_id = s.shipment_id AND NVL(t.rate_ref,'') = NVL(s.rate_ref,'') AND t.cost_type = s.cost_type
WHEN MATCHED AND s.update_date >= t.update_date THEN
  UPDATE SET calc_method=s.calc_method, cost_amount=s.cost_amount, currency=s.currency, update_date=s.update_date
WHEN NOT MATCHED THEN
  INSERT (shipment_id,cost_type,calc_method,rate_ref,cost_amount,currency,load_date,update_date)
  VALUES (s.shipment_id,s.cost_type,s.calc_method,s.rate_ref,s.cost_amount,s.currency,s.load_date,s.update_date);

