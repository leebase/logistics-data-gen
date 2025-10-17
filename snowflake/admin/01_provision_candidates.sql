-- Provision 10 candidates (C01..C10): users, roles, schemas, grants, and RAW VARCHAR tables
-- Run as ACCOUNTADMIN after 00_provision_base.sql
-- Idempotent and safe to re-run

-- Config
SET DB_NAME = 'ETL_INTERVIEW';
SET WH_NAME = 'ETL_INTERVIEW_WH';
SET NUM_CANDIDATES = 10;

USE DATABASE IDENTIFIER($DB_NAME);
USE WAREHOUSE IDENTIFIER($WH_NAME);

-- Helper: function to LPAD a number with zeros to 2 digits
-- Snowflake Scripting block to iterate candidates
BEGIN
  LET total NUMBER := :NUM_CANDIDATES;
  LET i NUMBER := 1;
  WHILE (i <= total) DO
    LET ci STRING := LPAD(TO_VARCHAR(i), 2, '0');
    LET cand STRING := 'C' || ci;                 -- e.g., C01
    LET role_name STRING := 'ETL_' || cand || '_ROLE';
    LET user_name STRING := 'ETL_' || cand;       -- login name will be lowercased alias
    LET login_name STRING := 'etl_' || LOWER(cand); -- e.g., etl_c01
    LET raw_schema STRING := cand || '_RAW';
    LET model_schema STRING := cand || '_MODEL';

    -- Create role
    EXECUTE IMMEDIATE 'CREATE ROLE IF NOT EXISTS IDENTIFIER(''' || role_name || ''')';

    -- Create user (no password set here). Admin can set later via ALTER USER.
    EXECUTE IMMEDIATE 'CREATE USER IF NOT EXISTS IDENTIFIER(''' || user_name || ''')\n'
      || '  LOGIN_NAME = ''' || login_name || '''\n'
      || '  DEFAULT_ROLE = ''' || role_name || '''\n'
      || '  DEFAULT_WAREHOUSE = ''' || :WH_NAME || '''\n'
      || '  DEFAULT_NAMESPACE = ''' || :DB_NAME || '.' || raw_schema || '''\n'
      || '  MUST_CHANGE_PASSWORD = TRUE\n'
      || '  COMMENT = ''ETL Interview Candidate ' || cand || '''';

    -- Assign role to user
    EXECUTE IMMEDIATE 'GRANT ROLE IDENTIFIER(''' || role_name || ''') TO USER IDENTIFIER(''' || user_name || ''')';

    -- Grants: warehouse, database
    EXECUTE IMMEDIATE 'GRANT USAGE ON WAREHOUSE IDENTIFIER(''' || :WH_NAME || ''') TO ROLE IDENTIFIER(''' || role_name || ''')';
    EXECUTE IMMEDIATE 'GRANT USAGE ON DATABASE IDENTIFIER(''' || :DB_NAME || ''') TO ROLE IDENTIFIER(''' || role_name || ''')';

    -- Create schemas
    EXECUTE IMMEDIATE 'CREATE SCHEMA IF NOT EXISTS IDENTIFIER(''' || :DB_NAME || ''').IDENTIFIER(''' || raw_schema || ''')';
    EXECUTE IMMEDIATE 'CREATE SCHEMA IF NOT EXISTS IDENTIFIER(''' || :DB_NAME || ''').IDENTIFIER(''' || model_schema || ''')';

    -- Schema usage + ownership to candidate role
    EXECUTE IMMEDIATE 'GRANT USAGE ON SCHEMA IDENTIFIER(''' || :DB_NAME || ''').IDENTIFIER(''' || raw_schema || ''') TO ROLE IDENTIFIER(''' || role_name || ''')';
    EXECUTE IMMEDIATE 'GRANT USAGE ON SCHEMA IDENTIFIER(''' || :DB_NAME || ''').IDENTIFIER(''' || model_schema || ''') TO ROLE IDENTIFIER(''' || role_name || ''')';
    EXECUTE IMMEDIATE 'GRANT OWNERSHIP ON SCHEMA IDENTIFIER(''' || :DB_NAME || ''').IDENTIFIER(''' || raw_schema || ''') TO ROLE IDENTIFIER(''' || role_name || ''') REVOKE CURRENT GRANTS';
    EXECUTE IMMEDIATE 'GRANT OWNERSHIP ON SCHEMA IDENTIFIER(''' || :DB_NAME || ''').IDENTIFIER(''' || model_schema || ''') TO ROLE IDENTIFIER(''' || role_name || ''') REVOKE CURRENT GRANTS';

    -- Future privileges (belt-and-suspenders if ownership changes later)
    EXECUTE IMMEDIATE 'GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA IDENTIFIER(''' || :DB_NAME || ''').IDENTIFIER(''' || raw_schema || ''') TO ROLE IDENTIFIER(''' || role_name || ''')';
    EXECUTE IMMEDIATE 'GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA IDENTIFIER(''' || :DB_NAME || ''').IDENTIFIER(''' || model_schema || ''') TO ROLE IDENTIFIER(''' || role_name || ''')';

    -- Pre-create RAW tables (all VARCHAR). Switch to RAW schema context.
    EXECUTE IMMEDIATE 'USE SCHEMA IDENTIFIER(''' || :DB_NAME || ''').IDENTIFIER(''' || raw_schema || ''')';

    -- DIM_CUSTOMER
    EXECUTE IMMEDIATE $$
      CREATE OR REPLACE TABLE DIM_CUSTOMER (
        CUSTOMER_ID VARCHAR,
        NAME VARCHAR,
        SEGMENT VARCHAR,
        REGION VARCHAR,
        LOAD_DATE VARCHAR,
        UPDATE_DATE VARCHAR
      );
    $$;

    -- DIM_CARRIER
    EXECUTE IMMEDIATE $$
      CREATE OR REPLACE TABLE DIM_CARRIER (
        CARRIER_ID VARCHAR,
        NAME VARCHAR,
        MODE VARCHAR,
        MC_NUMBER VARCHAR,
        SCORE_TIER VARCHAR,
        LOAD_DATE VARCHAR,
        UPDATE_DATE VARCHAR
      );
    $$;

    -- DIM_EQUIPMENT
    EXECUTE IMMEDIATE $$
      CREATE OR REPLACE TABLE DIM_EQUIPMENT (
        EQUIPMENT_ID VARCHAR,
        TYPE VARCHAR,
        CAPACITY_LBS VARCHAR,
        LOAD_DATE VARCHAR,
        UPDATE_DATE VARCHAR
      );
    $$;

    -- DIM_LOCATION
    EXECUTE IMMEDIATE $$
      CREATE OR REPLACE TABLE DIM_LOCATION (
        LOC_ID VARCHAR,
        NAME VARCHAR,
        CITY VARCHAR,
        STATE VARCHAR,
        COUNTRY VARCHAR,
        TIMEZONE VARCHAR,
        TYPE VARCHAR,
        LOAD_DATE VARCHAR,
        UPDATE_DATE VARCHAR
      );
    $$;

    -- DIM_LANE
    EXECUTE IMMEDIATE $$
      CREATE OR REPLACE TABLE DIM_LANE (
        LANE_ID VARCHAR,
        ORIGIN_LOC_ID VARCHAR,
        DEST_LOC_ID VARCHAR,
        STANDARD_MILES VARCHAR,
        STD_TRANSIT_DAYS VARCHAR,
        LOAD_DATE VARCHAR,
        UPDATE_DATE VARCHAR
      );
    $$;

    -- DIM_DATE
    EXECUTE IMMEDIATE $$
      CREATE OR REPLACE TABLE DIM_DATE (
        DATE_KEY VARCHAR,
        DATE VARCHAR,
        YEAR VARCHAR,
        QUARTER VARCHAR,
        MONTH VARCHAR,
        WEEK VARCHAR,
        DOW VARCHAR,
        IS_WEEKEND VARCHAR,
        LOAD_DATE VARCHAR,
        UPDATE_DATE VARCHAR
      );
    $$;

    -- FACT_SHIPMENT
    EXECUTE IMMEDIATE $$
      CREATE OR REPLACE TABLE FACT_SHIPMENT (
        SHIPMENT_ID VARCHAR,
        LEG_ID VARCHAR,
        CUSTOMER_ID VARCHAR,
        CARRIER_ID VARCHAR,
        EQUIPMENT_ID VARCHAR,
        ORIGIN_LOC_ID VARCHAR,
        DEST_LOC_ID VARCHAR,
        LANE_ID VARCHAR,
        TENDER_TS VARCHAR,
        PICKUP_PLAN_TS VARCHAR,
        PICKUP_ACTUAL_TS VARCHAR,
        DELIVERY_PLAN_TS VARCHAR,
        DELIVERY_ACTUAL_TS VARCHAR,
        PLANNED_MILES VARCHAR,
        ACTUAL_MILES VARCHAR,
        PIECES VARCHAR,
        WEIGHT_LBS VARCHAR,
        CUBE VARCHAR,
        REVENUE VARCHAR,
        TOTAL_COST VARCHAR,
        FUEL_SURCHARGE VARCHAR,
        ACCESSORIAL_COST VARCHAR,
        STATUS VARCHAR,
        ISDELIVEREDONTIME VARCHAR,
        ISINFULL VARCHAR,
        ISOTIF VARCHAR,
        CANCEL_FLAG VARCHAR,
        LOAD_DATE VARCHAR,
        UPDATE_DATE VARCHAR
      );
    $$;

    -- FACT_EVENT
    EXECUTE IMMEDIATE $$
      CREATE OR REPLACE TABLE FACT_EVENT (
        SHIPMENT_ID VARCHAR,
        EVENT_SEQ VARCHAR,
        EVENT_TYPE VARCHAR,
        EVENT_TS VARCHAR,
        FACILITY_LOC_ID VARCHAR,
        NOTES VARCHAR,
        LOAD_DATE VARCHAR,
        UPDATE_DATE VARCHAR
      );
    $$;

    -- FACT_COST
    EXECUTE IMMEDIATE $$
      CREATE OR REPLACE TABLE FACT_COST (
        SHIPMENT_ID VARCHAR,
        COST_TYPE VARCHAR,
        CALC_METHOD VARCHAR,
        RATE_REF VARCHAR,
        COST_AMOUNT VARCHAR,
        CURRENCY VARCHAR,
        LOAD_DATE VARCHAR,
        UPDATE_DATE VARCHAR
      );
    $$;

    -- next candidate
    i := i + 1;
  END WHILE;
END;

-- Optionally set a temporary password for each user (uncomment and set value before running)
-- Example for C01 only:
--   SET TEMP_PASSWORD = 'ChangeMe123!';
--   ALTER USER IDENTIFIER('ETL_C01') SET PASSWORD = $TEMP_PASSWORD, MUST_CHANGE_PASSWORD = TRUE;
-- Repeat as needed per candidate.
