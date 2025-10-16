-- Use placeholders: LOGISTICS_DB, STG, EDW

USE DATABASE IDENTIFIER('LOGISTICS_DB');
USE SCHEMA IDENTIFIER('STG');

-- STG tables (landing)
CREATE OR REPLACE TABLE DIM_CUSTOMER (
  customer_id INTEGER,
  name STRING,
  segment STRING,
  region STRING,
  load_date TIMESTAMP_NTZ,
  update_date TIMESTAMP_NTZ
);

CREATE OR REPLACE TABLE DIM_CARRIER (
  carrier_id INTEGER,
  name STRING,
  mode STRING,             -- LTL/TL/Intermodal
  mc_number STRING,
  score_tier STRING,       -- Bronze/Silver/Gold/Platinum
  load_date TIMESTAMP_NTZ,
  update_date TIMESTAMP_NTZ
);

CREATE OR REPLACE TABLE DIM_EQUIPMENT (
  equipment_id INTEGER,
  type STRING,             -- Van/Reefer/Flat
  capacity_lbs INTEGER,
  load_date TIMESTAMP_NTZ,
  update_date TIMESTAMP_NTZ
);

CREATE OR REPLACE TABLE DIM_LOCATION (
  loc_id INTEGER,
  name STRING,
  city STRING,
  state STRING,
  country STRING,
  timezone STRING,
  type STRING,             -- Origin/Dest/Terminal/DC
  load_date TIMESTAMP_NTZ,
  update_date TIMESTAMP_NTZ
);

CREATE OR REPLACE TABLE DIM_LANE (
  lane_id INTEGER,
  origin_loc_id INTEGER,
  dest_loc_id INTEGER,
  standard_miles NUMBER(10,2),
  std_transit_days INTEGER,
  load_date TIMESTAMP_NTZ,
  update_date TIMESTAMP_NTZ
);

CREATE OR REPLACE TABLE DIM_DATE (
  date_key INTEGER,        -- YYYYMMDD
  date DATE,
  year INTEGER,
  quarter INTEGER,
  month INTEGER,
  week INTEGER,
  dow INTEGER,
  is_weekend BOOLEAN,
  load_date TIMESTAMP_NTZ,
  update_date TIMESTAMP_NTZ
);

CREATE OR REPLACE TABLE FACT_SHIPMENT (
  shipment_id STRING,
  leg_id INTEGER,
  customer_id INTEGER,
  carrier_id INTEGER,
  equipment_id INTEGER,
  origin_loc_id INTEGER,
  dest_loc_id INTEGER,
  lane_id INTEGER,
  tender_ts TIMESTAMP_NTZ,
  pickup_plan_ts TIMESTAMP_NTZ,
  pickup_actual_ts TIMESTAMP_NTZ,
  delivery_plan_ts TIMESTAMP_NTZ,
  delivery_actual_ts TIMESTAMP_NTZ,
  planned_miles NUMBER(10,2),
  actual_miles NUMBER(10,2),
  pieces INTEGER,
  weight_lbs NUMBER(10,2),
  cube NUMBER(10,2),
  revenue NUMBER(12,2),
  total_cost NUMBER(12,2),
  fuel_surcharge NUMBER(12,2),
  accessorial_cost NUMBER(12,2),
  status STRING,           -- Tendered, Accepted, In-Transit, Delivered, Exception, Cancelled
  isdeliveredontime BOOLEAN,
  isinfull BOOLEAN,
  isotif BOOLEAN,
  cancel_flag BOOLEAN,
  load_date TIMESTAMP_NTZ,
  update_date TIMESTAMP_NTZ
);

CREATE OR REPLACE TABLE FACT_EVENT (
  shipment_id STRING,
  event_seq INTEGER,
  event_type STRING,       -- Tendered, Accepted, AtOrigin, PickedUp, AtDest, Delivered, Exception, DwellStart, DwellEnd
  event_ts TIMESTAMP_NTZ,
  facility_loc_id INTEGER,
  notes STRING,
  load_date TIMESTAMP_NTZ,
  update_date TIMESTAMP_NTZ
);

CREATE OR REPLACE TABLE FACT_COST (
  shipment_id STRING,
  cost_type STRING,        -- Base, Fuel, Accessorial: Detention, Lumper, Layover, TONU
  calc_method STRING,      -- flat, per-mile, index
  rate_ref STRING,
  cost_amount NUMBER(12,2),
  currency STRING,
  load_date TIMESTAMP_NTZ,
  update_date TIMESTAMP_NTZ
);

-- EDW tables (curated; same schemas with constraints informational)
USE SCHEMA IDENTIFIER('EDW');
CREATE OR REPLACE TABLE DIM_CUSTOMER LIKE LOGISTICS_DB.STG.DIM_CUSTOMER;
ALTER TABLE DIM_CUSTOMER ADD PRIMARY KEY (customer_id);

CREATE OR REPLACE TABLE DIM_CARRIER LIKE LOGISTICS_DB.STG.DIM_CARRIER;
ALTER TABLE DIM_CARRIER ADD PRIMARY KEY (carrier_id);

CREATE OR REPLACE TABLE DIM_EQUIPMENT LIKE LOGISTICS_DB.STG.DIM_EQUIPMENT;
ALTER TABLE DIM_EQUIPMENT ADD PRIMARY KEY (equipment_id);

CREATE OR REPLACE TABLE DIM_LOCATION LIKE LOGISTICS_DB.STG.DIM_LOCATION;
ALTER TABLE DIM_LOCATION ADD PRIMARY KEY (loc_id);

CREATE OR REPLACE TABLE DIM_LANE LIKE LOGISTICS_DB.STG.DIM_LANE;
ALTER TABLE DIM_LANE ADD PRIMARY KEY (lane_id);

CREATE OR REPLACE TABLE DIM_DATE LIKE LOGISTICS_DB.STG.DIM_DATE;
ALTER TABLE DIM_DATE ADD PRIMARY KEY (date_key);

CREATE OR REPLACE TABLE FACT_SHIPMENT LIKE LOGISTICS_DB.STG.FACT_SHIPMENT;
CREATE OR REPLACE TABLE FACT_EVENT LIKE LOGISTICS_DB.STG.FACT_EVENT;
CREATE OR REPLACE TABLE FACT_COST LIKE LOGISTICS_DB.STG.FACT_COST;
