-- Reviewer role to read candidate MODEL schemas for scoring
-- Run after candidate provisioning; idempotent

SET DB_NAME = 'ETL_INTERVIEW';

CREATE ROLE IF NOT EXISTS ETL_REVIEWER;

-- Grant USAGE on database
GRANT USAGE ON DATABASE IDENTIFIER($DB_NAME) TO ROLE ETL_REVIEWER;

-- Grant USAGE + SELECT on all MODEL schemas
BEGIN
  LET i NUMBER := 1;
  WHILE (i <= 10) DO
    LET ci STRING := LPAD(TO_VARCHAR(i), 2, '0');
    LET cand STRING := 'C' || ci;                 -- e.g., C01
    LET model_schema STRING := cand || '_MODEL';

    EXECUTE IMMEDIATE 'GRANT USAGE ON SCHEMA IDENTIFIER(''' || :DB_NAME || ''').IDENTIFIER(''' || model_schema || ''') TO ROLE ETL_REVIEWER';
    EXECUTE IMMEDIATE 'GRANT SELECT ON ALL TABLES IN SCHEMA IDENTIFIER(''' || :DB_NAME || ''').IDENTIFIER(''' || model_schema || ''') TO ROLE ETL_REVIEWER';
    EXECUTE IMMEDIATE 'GRANT SELECT ON FUTURE TABLES IN SCHEMA IDENTIFIER(''' || :DB_NAME || ''').IDENTIFIER(''' || model_schema || ''') TO ROLE ETL_REVIEWER';

    i := i + 1;
  END WHILE;
END;

-- Assign ETL_REVIEWER to the admin/reviewer user manually as appropriate.

