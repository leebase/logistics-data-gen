-- Tear down all ETL interview objects
-- DANGER: This drops users, roles, schemas, database, warehouse, and resource monitor
-- Run as ACCOUNTADMIN; review carefully before execution

SET DB_NAME = 'ETL_INTERVIEW';
SET WH_NAME = 'ETL_INTERVIEW_WH';
SET RM_NAME = 'ETL_INTERVIEW_RM';

-- Drop candidate users and roles
BEGIN
  LET i NUMBER := 1;
  WHILE (i <= 10) DO
    LET ci STRING := LPAD(TO_VARCHAR(i), 2, '0');
    LET cand STRING := 'C' || ci;                 -- e.g., C01
    LET role_name STRING := 'ETL_' || cand || '_ROLE';
    LET user_name STRING := 'ETL_' || cand;

    -- Revoke role from user (ignore failures)
    BEGIN
      EXECUTE IMMEDIATE 'REVOKE ROLE IDENTIFIER(''' || role_name || ''') FROM USER IDENTIFIER(''' || user_name || ''')';
    EXCEPTION WHEN OTHER THEN
      NULL;
    END;

    -- Drop user
    BEGIN
      EXECUTE IMMEDIATE 'DROP USER IF EXISTS IDENTIFIER(''' || user_name || ''')';
    EXCEPTION WHEN OTHER THEN
      NULL;
    END;

    -- Drop role
    BEGIN
      EXECUTE IMMEDIATE 'DROP ROLE IF EXISTS IDENTIFIER(''' || role_name || ''')';
    EXCEPTION WHEN OTHER THEN
      NULL;
    END;

    i := i + 1;
  END WHILE;
END;

-- Drop schemas and database
DROP DATABASE IF EXISTS IDENTIFIER($DB_NAME);

-- Drop warehouse and resource monitor
DROP WAREHOUSE IF EXISTS IDENTIFIER($WH_NAME);
DROP RESOURCE MONITOR IF EXISTS IDENTIFIER($RM_NAME);

-- Optional: drop reviewer role
DROP ROLE IF EXISTS ETL_REVIEWER;

