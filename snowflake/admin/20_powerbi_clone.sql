-- Create POWERBI_DWH schema and zero-copy clone EDW tables into it
-- Defaults assume source EDW is LOGISTICS_DB.EDW and target DB is ETL_INTERVIEW
-- Run as ACCOUNTADMIN (or role with create/clone privileges)

-- Parameters
SET SRC_DB = 'LOGISTICS_DB';
SET SRC_SCHEMA = 'EDW';
SET TGT_DB = 'ETL_INTERVIEW';
SET TGT_SCHEMA = 'POWERBI_DWH';

-- Create target schema
CREATE SCHEMA IF NOT EXISTS IDENTIFIER($TGT_DB).IDENTIFIER($TGT_SCHEMA);

-- List of tables to clone
SET TABS = (
  SELECT COLUMN1 AS T FROM VALUES
    ('DIM_CUSTOMER'),
    ('DIM_CARRIER'),
    ('DIM_EQUIPMENT'),
    ('DIM_LOCATION'),
    ('DIM_LANE'),
    ('DIM_DATE'),
    ('FACT_SHIPMENT'),
    ('FACT_EVENT'),
    ('FACT_COST')
);

-- Clone each table
BEGIN
  FOR rec IN (SELECT T FROM TABLE($TABS)) DO
    LET t STRING := rec.T;
    EXECUTE IMMEDIATE 'CREATE OR REPLACE TABLE ' || IDENTIFIER($TGT_DB) || '.' || IDENTIFIER($TGT_SCHEMA) || '.' || IDENTIFIER(:t)
      || ' CLONE ' || IDENTIFIER($SRC_DB) || '.' || IDENTIFIER($SRC_SCHEMA) || '.' || IDENTIFIER(:t);
  END FOR;
END;

-- Optional: verify row counts
SELECT table_name, row_count
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = $TGT_SCHEMA
ORDER BY table_name;

