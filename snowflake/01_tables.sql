-- Use placeholders: <DATABASE>, <STG_SCHEMA>, <EDW_SCHEMA>

USE DATABASE IDENTIFIER('<DATABASE>');

-- STG tables (landing)
CREATE OR REPLACE TABLE IDENTIFIER('<STG_SCHEMA>').DIM_CUSTOMER (
  customer_id INTEGER,
  name STRING,
  segment STRING,
  region STRING,
  load_date TIMESTAMP_NTZ,
  update_date TIMESTAMP_NTZ
);

CREATE OR REPLACE TABLE IDENTIFIER('<STG_SCHEMA>').DIM_CARRIER (
  carrier_id INTEGER,
  name STRING,
  mode STRING,             -- LTL/TL/Intermodal
  mc_number STRING,
  score_tier STRING,       -- Bronze/Silver/Gold/Platinum
  load_date TIMESTAMP_NTZ,
  update_date TIMESTAMP_NTZ
);

CREATE OR REPLACE TABLE IDENTIFIER('<STG_SCHEMA>').DIM_EQUIPMENT (
  equipment_id INTEGER,
  type STRING,             -- Van/Reefer/Flat
  capacity_lbs INTEGER,
  load_date TIMESTAMP_NTZ,
  update_date TIMESTAMP_NTZ
);

CREATE OR REPLACE TABLE IDENTIFIER('<STG_SCHEMA>').DIM_LOCATION (
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

CREATE OR REPLACE TABLE IDENTIFIER('<STG_SCHEMA>').DIM_LANE (
  lane_id INTEGER,
  origin_loc_id INTEGER,
  dest_loc_id INTEGER,
  standard_miles NUMBER(10,2),
  std_transit_days INTEGER,
  load_date TIMESTAMP_NTZ,
  update_date TIMESTAMP_NTZ
);

CREATE OR REPLACE TABLE IDENTIFIER('<STG_SCHEMA>').DIM_DATE (
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

CREATE OR REPLACE TABLE IDENTIFIER('<STG_SCHEMA>').FACT_SHIPMENT (
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

CREATE OR REPLACE TABLE IDENTIFIER('<STG_SCHEMA>').FACT_EVENT (
  shipment_id STRING,
  event_seq INTEGER,
  event_type STRING,       -- Tendered, Accepted, AtOrigin, PickedUp, AtDest, Delivered, Exception, DwellStart, DwellEnd
  event_ts TIMESTAMP_NTZ,
  facility_loc_id INTEGER,
  notes STRING,
  load_date TIMESTAMP_NTZ,
  update_date TIMESTAMP_NTZ
);

CREATE OR REPLACE TABLE IDENTIFIER('<STG_SCHEMA>').FACT_COST (
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
CREATE OR REPLACE TABLE IDENTIFIER('<EDW_SCHEMA>').DIM_CUSTOMER LIKE IDENTIFIER('<STG_SCHEMA>').DIM_CUSTOMER;
ALTER TABLE IDENTIFIER('<EDW_SCHEMA>').DIM_CUSTOMER ADD PRIMARY KEY (customer_id);

CREATE OR REPLACE TABLE IDENTIFIER('<EDW_SCHEMA>').DIM_CARRIER LIKE IDENTIFIER('<STG_SCHEMA>').DIM_CARRIER;
ALTER TABLE IDENTIFIER('<EDW_SCHEMA>').DIM_CARRIER ADD PRIMARY KEY (carrier_id);

CREATE OR REPLACE TABLE IDENTIFIER('<EDW_SCHEMA>').DIM_EQUIPMENT LIKE IDENTIFIER('<STG_SCHEMA>').DIM_EQUIPMENT;
ALTER TABLE IDENTIFIER('<EDW_SCHEMA>').DIM_EQUIPMENT ADD PRIMARY KEY (equipment_id);

CREATE OR REPLACE TABLE IDENTIFIER('<EDW_SCHEMA>').DIM_LOCATION LIKE IDENTIFIER('<STG_SCHEMA>').DIM_LOCATION;
ALTER TABLE IDENTIFIER('<EDW_SCHEMA>').DIM_LOCATION ADD PRIMARY KEY (loc_id);

CREATE OR REPLACE TABLE IDENTIFIER('<EDW_SCHEMA>').DIM_LANE LIKE IDENTIFIER('<STG_SCHEMA>').DIM_LANE;
ALTER TABLE IDENTIFIER('<EDW_SCHEMA>').DIM_LANE ADD PRIMARY KEY (lane_id);

CREATE OR REPLACE TABLE IDENTIFIER('<EDW_SCHEMA>').DIM_DATE LIKE IDENTIFIER('<STG_SCHEMA>').DIM_DATE;
ALTER TABLE IDENTIFIER('<EDW_SCHEMA>').DIM_DATE ADD PRIMARY KEY (date_key);

CREATE OR REPLACE TABLE IDENTIFIER('<EDW_SCHEMA>').FACT_SHIPMENT LIKE IDENTIFIER('<STG_SCHEMA>').FACT_SHIPMENT;
CREATE OR REPLACE TABLE IDENTIFIER('<EDW_SCHEMA>').FACT_EVENT LIKE IDENTIFIER('<STG_SCHEMA>').FACT_EVENT;
CREATE OR REPLACE TABLE IDENTIFIER('<EDW_SCHEMA>').FACT_COST LIKE IDENTIFIER('<STG_SCHEMA>').FACT_COST;

