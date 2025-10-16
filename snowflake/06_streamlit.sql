-- Deploy Streamlit app in Snowflake (Streamlit in Snowflake)
-- Replace placeholders before running or use scripts/deploy_streamlit.sh

USE DATABASE IDENTIFIER('<DATABASE>');
USE SCHEMA IDENTIFIER('<EDW_SCHEMA>'); -- context only; app queries use fully qualified names

-- Stage for app code
CREATE OR REPLACE STAGE IDENTIFIER('<APP_STAGE>');

-- From your workstation (SnowSQL) upload the app code:
-- PUT file://streamlit/app.py @<DATABASE>.<EDW_SCHEMA>.<APP_STAGE> AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

-- Create the Streamlit app
CREATE OR REPLACE STREAMLIT IDENTIFIER('<APP_NAME>')
  FROM @<DATABASE>.<EDW_SCHEMA>.<APP_STAGE>
  MAIN_FILE='app.py'
  QUERY_WAREHOUSE = IDENTIFIER('<WAREHOUSE>');

-- Show the URL
-- SELECT SYSTEM$SHOW_STREAMLIT_URL('<APP_NAME>');

