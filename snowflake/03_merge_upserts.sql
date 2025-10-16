-- MERGE templates for incremental loads.
-- Replace <DATABASE>, <STG_SCHEMA>, <EDW_SCHEMA> as needed.

USE DATABASE IDENTIFIER('<DATABASE>');

-- Dimensions (natural keys are the IDs from generator)
MERGE INTO IDENTIFIER('<EDW_SCHEMA>').DIM_CUSTOMER t
USING IDENTIFIER('<STG_SCHEMA>').DIM_CUSTOMER s
ON t.customer_id = s.customer_id
WHEN MATCHED THEN UPDATE SET
  t.name = s.name,
  t.segment = s.segment,
  t.region = s.region,
  t.update_date = COALESCE(s.update_date, CURRENT_TIMESTAMP())
WHEN NOT MATCHED THEN INSERT (
  customer_id, name, segment, region, load_date, update_date
) VALUES (
  s.customer_id, s.name, s.segment, s.region,
  COALESCE(s.load_date, CURRENT_TIMESTAMP()),
  COALESCE(s.update_date, CURRENT_TIMESTAMP())
);

MERGE INTO IDENTIFIER('<EDW_SCHEMA>').DIM_CARRIER t
USING IDENTIFIER('<STG_SCHEMA>').DIM_CARRIER s
ON t.carrier_id = s.carrier_id
WHEN MATCHED THEN UPDATE SET
  t.name = s.name,
  t.mode = s.mode,
  t.mc_number = s.mc_number,
  t.score_tier = s.score_tier,
  t.update_date = COALESCE(s.update_date, CURRENT_TIMESTAMP())
WHEN NOT MATCHED THEN INSERT (
  carrier_id, name, mode, mc_number, score_tier, load_date, update_date
) VALUES (
  s.carrier_id, s.name, s.mode, s.mc_number, s.score_tier,
  COALESCE(s.load_date, CURRENT_TIMESTAMP()),
  COALESCE(s.update_date, CURRENT_TIMESTAMP())
);

MERGE INTO IDENTIFIER('<EDW_SCHEMA>').DIM_EQUIPMENT t
USING IDENTIFIER('<STG_SCHEMA>').DIM_EQUIPMENT s
ON t.equipment_id = s.equipment_id
WHEN MATCHED THEN UPDATE SET
  t.type = s.type,
  t.capacity_lbs = s.capacity_lbs,
  t.update_date = COALESCE(s.update_date, CURRENT_TIMESTAMP())
WHEN NOT MATCHED THEN INSERT (
  equipment_id, type, capacity_lbs, load_date, update_date
) VALUES (
  s.equipment_id, s.type, s.capacity_lbs,
  COALESCE(s.load_date, CURRENT_TIMESTAMP()),
  COALESCE(s.update_date, CURRENT_TIMESTAMP())
);

MERGE INTO IDENTIFIER('<EDW_SCHEMA>').DIM_LOCATION t
USING IDENTIFIER('<STG_SCHEMA>').DIM_LOCATION s
ON t.loc_id = s.loc_id
WHEN MATCHED THEN UPDATE SET
  t.name = s.name,
  t.city = s.city,
  t.state = s.state,
  t.country = s.country,
  t.timezone = s.timezone,
  t.type = s.type,
  t.update_date = COALESCE(s.update_date, CURRENT_TIMESTAMP())
WHEN NOT MATCHED THEN INSERT (
  loc_id, name, city, state, country, timezone, type, load_date, update_date
) VALUES (
  s.loc_id, s.name, s.city, s.state, s.country, s.timezone, s.type,
  COALESCE(s.load_date, CURRENT_TIMESTAMP()),
  COALESCE(s.update_date, CURRENT_TIMESTAMP())
);

MERGE INTO IDENTIFIER('<EDW_SCHEMA>').DIM_LANE t
USING IDENTIFIER('<STG_SCHEMA>').DIM_LANE s
ON t.lane_id = s.lane_id
WHEN MATCHED THEN UPDATE SET
  t.origin_loc_id = s.origin_loc_id,
  t.dest_loc_id = s.dest_loc_id,
  t.standard_miles = s.standard_miles,
  t.std_transit_days = s.std_transit_days,
  t.update_date = COALESCE(s.update_date, CURRENT_TIMESTAMP())
WHEN NOT MATCHED THEN INSERT (
  lane_id, origin_loc_id, dest_loc_id, standard_miles, std_transit_days, load_date, update_date
) VALUES (
  s.lane_id, s.origin_loc_id, s.dest_loc_id, s.standard_miles, s.std_transit_days,
  COALESCE(s.load_date, CURRENT_TIMESTAMP()),
  COALESCE(s.update_date, CURRENT_TIMESTAMP())
);

MERGE INTO IDENTIFIER('<EDW_SCHEMA>').DIM_DATE t
USING IDENTIFIER('<STG_SCHEMA>').DIM_DATE s
ON t.date_key = s.date_key
WHEN MATCHED THEN UPDATE SET
  t.date = s.date,
  t.year = s.year,
  t.quarter = s.quarter,
  t.month = s.month,
  t.week = s.week,
  t.dow = s.dow,
  t.is_weekend = s.is_weekend,
  t.update_date = COALESCE(s.update_date, CURRENT_TIMESTAMP())
WHEN NOT MATCHED THEN INSERT (
  date_key, date, year, quarter, month, week, dow, is_weekend, load_date, update_date
) VALUES (
  s.date_key, s.date, s.year, s.quarter, s.month, s.week, s.dow, s.is_weekend,
  COALESCE(s.load_date, CURRENT_TIMESTAMP()),
  COALESCE(s.update_date, CURRENT_TIMESTAMP())
);

-- Facts (late-arriving updates handled by UpdateDate and deterministic natural keys)
MERGE INTO IDENTIFIER('<EDW_SCHEMA>').FACT_SHIPMENT t
USING IDENTIFIER('<STG_SCHEMA>').FACT_SHIPMENT s
ON t.shipment_id = s.shipment_id AND t.leg_id = s.leg_id
WHEN MATCHED AND s.update_date >= t.update_date THEN UPDATE SET
  customer_id = s.customer_id,
  carrier_id = s.carrier_id,
  equipment_id = s.equipment_id,
  origin_loc_id = s.origin_loc_id,
  dest_loc_id = s.dest_loc_id,
  lane_id = s.lane_id,
  tender_ts = s.tender_ts,
  pickup_plan_ts = s.pickup_plan_ts,
  pickup_actual_ts = s.pickup_actual_ts,
  delivery_plan_ts = s.delivery_plan_ts,
  delivery_actual_ts = s.delivery_actual_ts,
  planned_miles = s.planned_miles,
  actual_miles = s.actual_miles,
  pieces = s.pieces,
  weight_lbs = s.weight_lbs,
  cube = s.cube,
  revenue = s.revenue,
  total_cost = s.total_cost,
  fuel_surcharge = s.fuel_surcharge,
  accessorial_cost = s.accessorial_cost,
  status = s.status,
  isdeliveredontime = s.isdeliveredontime,
  isinfull = s.isinfull,
  isotif = s.isotif,
  cancel_flag = s.cancel_flag,
  update_date = COALESCE(s.update_date, CURRENT_TIMESTAMP())
WHEN NOT MATCHED THEN INSERT (
  shipment_id, leg_id, customer_id, carrier_id, equipment_id, origin_loc_id, dest_loc_id, lane_id,
  tender_ts, pickup_plan_ts, pickup_actual_ts, delivery_plan_ts, delivery_actual_ts,
  planned_miles, actual_miles, pieces, weight_lbs, cube, revenue, total_cost, fuel_surcharge, accessorial_cost,
  status, isdeliveredontime, isinfull, isotif, cancel_flag, load_date, update_date
) VALUES (
  s.shipment_id, s.leg_id, s.customer_id, s.carrier_id, s.equipment_id, s.origin_loc_id, s.dest_loc_id, s.lane_id,
  s.tender_ts, s.pickup_plan_ts, s.pickup_actual_ts, s.delivery_plan_ts, s.delivery_actual_ts,
  s.planned_miles, s.actual_miles, s.pieces, s.weight_lbs, s.cube, s.revenue, s.total_cost, s.fuel_surcharge, s.accessorial_cost,
  s.status, s.isdeliveredontime, s.isinfull, s.isotif, s.cancel_flag, COALESCE(s.load_date, CURRENT_TIMESTAMP()),
  COALESCE(s.update_date, CURRENT_TIMESTAMP())
);

MERGE INTO IDENTIFIER('<EDW_SCHEMA>').FACT_EVENT t
USING IDENTIFIER('<STG_SCHEMA>').FACT_EVENT s
ON t.shipment_id = s.shipment_id AND t.event_seq = s.event_seq
WHEN MATCHED AND s.update_date >= t.update_date THEN UPDATE SET
  event_type = s.event_type,
  event_ts = s.event_ts,
  facility_loc_id = s.facility_loc_id,
  notes = s.notes,
  update_date = COALESCE(s.update_date, CURRENT_TIMESTAMP())
WHEN NOT MATCHED THEN INSERT (
  shipment_id, event_seq, event_type, event_ts, facility_loc_id, notes, load_date, update_date
) VALUES (
  s.shipment_id, s.event_seq, s.event_type, s.event_ts, s.facility_loc_id, s.notes,
  COALESCE(s.load_date, CURRENT_TIMESTAMP()),
  COALESCE(s.update_date, CURRENT_TIMESTAMP())
);

-- Costs are append-only by (shipment_id, cost_type, rate_ref); merge to avoid duplicates
MERGE INTO IDENTIFIER('<EDW_SCHEMA>').FACT_COST t
USING IDENTIFIER('<STG_SCHEMA>').FACT_COST s
ON t.shipment_id = s.shipment_id
   AND t.cost_type = s.cost_type
   AND NVL(t.rate_ref,'') = NVL(s.rate_ref,'')
WHEN MATCHED AND s.update_date >= t.update_date THEN UPDATE SET
  calc_method = s.calc_method,
  cost_amount = s.cost_amount,
  currency = s.currency,
  update_date = COALESCE(s.update_date, CURRENT_TIMESTAMP())
WHEN NOT MATCHED THEN INSERT (
  shipment_id, cost_type, calc_method, rate_ref, cost_amount, currency, load_date, update_date
) VALUES (
  s.shipment_id, s.cost_type, s.calc_method, s.rate_ref, s.cost_amount, s.currency,
  COALESCE(s.load_date, CURRENT_TIMESTAMP()),
  COALESCE(s.update_date, CURRENT_TIMESTAMP())
);

