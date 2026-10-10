/*******************************************************************************
 *  DQ_Rules.sql
 *  Data Quality Framework – Step 3: Create and Attach Data Quality Rules
 *  Database : BANKING_DQ_DB
 *  Schema   : DQ_MONITORING (custom DMF procedures)
 *
 *  NOTE: Native Snowflake DMFs require Enterprise Edition which is not
 *  available on this account. This framework uses custom stored procedures
 *  as Data Metric Functions that return violation counts (0 = healthy).
 *  These are orchestrated by the DQ framework stored procedure (Step 5).
 ******************************************************************************/

USE DATABASE BANKING_DQ_DB;

-- =============================================================================
-- 0. CREATE DQ_MONITORING SCHEMA
-- =============================================================================
CREATE SCHEMA IF NOT EXISTS DQ_MONITORING;
USE SCHEMA DQ_MONITORING;

-- =============================================================================
-- 1. REUSABLE CUSTOM DMF STORED PROCEDURES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1A. DQ_NULL_COUNT: Count null values in a column
-- Returns: Number of rows where the column is NULL
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE DQ_NULL_COUNT(DB_SCHEMA STRING, TABLE_NM STRING, COLUMN_NM STRING)
RETURNS NUMBER
LANGUAGE SQL
AS
BEGIN
  LET sql_stmt := 'SELECT COUNT(*) FROM ' || DB_SCHEMA || '.' || TABLE_NM || ' WHERE ' || COLUMN_NM || ' IS NULL';
  LET rs RESULTSET := (EXECUTE IMMEDIATE :sql_stmt);
  LET c CURSOR FOR rs;
  FOR row_val IN c DO
    RETURN row_val."COUNT(*)";
  END FOR;
  RETURN 0;
END;

-- -----------------------------------------------------------------------------
-- 1B. DQ_DUPLICATE_COUNT: Count distinct values appearing more than once
-- Returns: Number of distinct values that have duplicates
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE DQ_DUPLICATE_COUNT(DB_SCHEMA STRING, TABLE_NM STRING, COLUMN_NM STRING)
RETURNS NUMBER
LANGUAGE SQL
AS
BEGIN
  LET sql_stmt := 'SELECT COUNT(*) AS CNT FROM (SELECT ' || COLUMN_NM || ', COUNT(*) AS C FROM ' || DB_SCHEMA || '.' || TABLE_NM || ' WHERE ' || COLUMN_NM || ' IS NOT NULL GROUP BY ' || COLUMN_NM || ' HAVING COUNT(*) > 1)';
  LET rs RESULTSET := (EXECUTE IMMEDIATE :sql_stmt);
  LET c CURSOR FOR rs;
  FOR row_val IN c DO
    RETURN row_val.CNT;
  END FOR;
  RETURN 0;
END;

-- -----------------------------------------------------------------------------
-- 1C. DQ_ROW_COUNT: Count total rows in a table
-- Returns: Total row count
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE DQ_ROW_COUNT(DB_SCHEMA STRING, TABLE_NM STRING)
RETURNS NUMBER
LANGUAGE SQL
AS
BEGIN
  LET sql_stmt := 'SELECT COUNT(*) FROM ' || DB_SCHEMA || '.' || TABLE_NM;
  LET rs RESULTSET := (EXECUTE IMMEDIATE :sql_stmt);
  LET c CURSOR FOR rs;
  FOR row_val IN c DO
    RETURN row_val."COUNT(*)";
  END FOR;
  RETURN 0;
END;

-- -----------------------------------------------------------------------------
-- 1D. DQ_POSITIVE_CHECK: Count rows where a numeric column is <= 0
-- Returns: Number of violations (non-positive values)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE DQ_POSITIVE_CHECK(DB_SCHEMA STRING, TABLE_NM STRING, COLUMN_NM STRING)
RETURNS NUMBER
LANGUAGE SQL
AS
BEGIN
  LET sql_stmt := 'SELECT COUNT(*) AS CNT FROM ' || DB_SCHEMA || '.' || TABLE_NM || ' WHERE ' || COLUMN_NM || ' IS NOT NULL AND ' || COLUMN_NM || ' <= 0';
  LET rs RESULTSET := (EXECUTE IMMEDIATE :sql_stmt);
  LET c CURSOR FOR rs;
  FOR row_val IN c DO
    RETURN row_val.CNT;
  END FOR;
  RETURN 0;
END;

-- -----------------------------------------------------------------------------
-- 1E. DQ_ACCEPTED_VALUES: Count rows where column value is not in accepted set
-- ACCEPTED_LIST should be comma-separated quoted values e.g. '''A'',''B'''
-- Returns: Number of violations
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE DQ_ACCEPTED_VALUES(DB_SCHEMA STRING, TABLE_NM STRING, COLUMN_NM STRING, ACCEPTED_LIST STRING)
RETURNS NUMBER
LANGUAGE SQL
AS
BEGIN
  LET sql_stmt := 'SELECT COUNT(*) AS CNT FROM ' || DB_SCHEMA || '.' || TABLE_NM || ' WHERE ' || COLUMN_NM || ' IS NOT NULL AND ' || COLUMN_NM || ' NOT IN (' || ACCEPTED_LIST || ')';
  LET rs RESULTSET := (EXECUTE IMMEDIATE :sql_stmt);
  LET c CURSOR FOR rs;
  FOR row_val IN c DO
    RETURN row_val.CNT;
  END FOR;
  RETURN 0;
END;

-- -----------------------------------------------------------------------------
-- 1F. DQ_REFERENTIAL_INTEGRITY: Count orphan rows (FK violations)
-- Returns: Number of rows where FK value has no match in parent table
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE DQ_REFERENTIAL_INTEGRITY(DB_SCHEMA STRING, TABLE_NM STRING, FK_COLUMN STRING, REF_DB_SCHEMA STRING, REF_TABLE STRING, REF_COLUMN STRING)
RETURNS NUMBER
LANGUAGE SQL
AS
BEGIN
  LET sql_stmt := 'SELECT COUNT(*) AS CNT FROM ' || DB_SCHEMA || '.' || TABLE_NM || ' a LEFT JOIN ' || REF_DB_SCHEMA || '.' || REF_TABLE || ' b ON a.' || FK_COLUMN || ' = b.' || REF_COLUMN || ' WHERE a.' || FK_COLUMN || ' IS NOT NULL AND b.' || REF_COLUMN || ' IS NULL';
  LET rs RESULTSET := (EXECUTE IMMEDIATE :sql_stmt);
  LET c CURSOR FOR rs;
  FOR row_val IN c DO
    RETURN row_val.CNT;
  END FOR;
  RETURN 0;
END;

-- -----------------------------------------------------------------------------
-- 1G. DQ_FUTURE_DATE_CHECK: Count rows with future dates
-- Returns: Number of rows where date/timestamp is in the future
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE DQ_FUTURE_DATE_CHECK(DB_SCHEMA STRING, TABLE_NM STRING, COLUMN_NM STRING)
RETURNS NUMBER
LANGUAGE SQL
AS
BEGIN
  LET sql_stmt := 'SELECT COUNT(*) AS CNT FROM ' || DB_SCHEMA || '.' || TABLE_NM || ' WHERE ' || COLUMN_NM || ' IS NOT NULL AND ' || COLUMN_NM || ' > CURRENT_DATE()';
  LET rs RESULTSET := (EXECUTE IMMEDIATE :sql_stmt);
  LET c CURSOR FOR rs;
  FOR row_val IN c DO
    RETURN row_val.CNT;
  END FOR;
  RETURN 0;
END;

-- -----------------------------------------------------------------------------
-- 1H. DQ_INVALID_EMAIL: Count rows with invalid email format
-- Returns: Number of rows with malformed email addresses
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE DQ_INVALID_EMAIL(DB_SCHEMA STRING, TABLE_NM STRING, COLUMN_NM STRING)
RETURNS NUMBER
LANGUAGE SQL
AS
BEGIN
  LET sql_stmt := 'SELECT COUNT(*) AS CNT FROM ' || DB_SCHEMA || '.' || TABLE_NM || ' WHERE ' || COLUMN_NM || ' IS NOT NULL AND NOT RLIKE(' || COLUMN_NM || ', ''^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$'')';
  LET rs RESULTSET := (EXECUTE IMMEDIATE :sql_stmt);
  LET c CURSOR FOR rs;
  FOR row_val IN c DO
    RETURN row_val.CNT;
  END FOR;
  RETURN 0;
END;

-- -----------------------------------------------------------------------------
-- 1I. DQ_RANGE_CHECK: Count rows where numeric value is outside [min, max]
-- Returns: Number of violations (out-of-range values)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE DQ_RANGE_CHECK(DB_SCHEMA STRING, TABLE_NM STRING, COLUMN_NM STRING, MIN_VAL STRING, MAX_VAL STRING)
RETURNS NUMBER
LANGUAGE SQL
AS
BEGIN
  LET sql_stmt := 'SELECT COUNT(*) AS CNT FROM ' || DB_SCHEMA || '.' || TABLE_NM || ' WHERE ' || COLUMN_NM || ' IS NOT NULL AND (' || COLUMN_NM || ' < ' || MIN_VAL || ' OR ' || COLUMN_NM || ' > ' || MAX_VAL || ')';
  LET rs RESULTSET := (EXECUTE IMMEDIATE :sql_stmt);
  LET c CURSOR FOR rs;
  FOR row_val IN c DO
    RETURN row_val.CNT;
  END FOR;
  RETURN 0;
END;

-- -----------------------------------------------------------------------------
-- 1J. DQ_DOB_AGE_RANGE: Count rows where age from DOB is outside [min, max]
-- Returns: Number of violations
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE DQ_DOB_AGE_RANGE(DB_SCHEMA STRING, TABLE_NM STRING, COLUMN_NM STRING, MIN_AGE NUMBER, MAX_AGE NUMBER)
RETURNS NUMBER
LANGUAGE SQL
AS
BEGIN
  LET sql_stmt := 'SELECT COUNT(*) AS CNT FROM ' || DB_SCHEMA || '.' || TABLE_NM || ' WHERE ' || COLUMN_NM || ' IS NOT NULL AND (DATEDIFF(YEAR, ' || COLUMN_NM || ', CURRENT_DATE()) < ' || :MIN_AGE || ' OR DATEDIFF(YEAR, ' || COLUMN_NM || ', CURRENT_DATE()) > ' || :MAX_AGE || ')';
  LET rs RESULTSET := (EXECUTE IMMEDIATE :sql_stmt);
  LET c CURSOR FOR rs;
  FOR row_val IN c DO
    RETURN row_val.CNT;
  END FOR;
  RETURN 0;
END;

-- -----------------------------------------------------------------------------
-- 1K. DQ_FRESHNESS_HOURS: Hours since last record in a timestamp column
-- Returns: Number of hours since the most recent timestamp (higher = staler)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE DQ_FRESHNESS_HOURS(DB_SCHEMA STRING, TABLE_NM STRING, COLUMN_NM STRING)
RETURNS NUMBER
LANGUAGE SQL
AS
BEGIN
  LET sql_stmt := 'SELECT DATEDIFF(HOUR, MAX(' || COLUMN_NM || '), CURRENT_TIMESTAMP()) AS HOURS_SINCE_LAST FROM ' || DB_SCHEMA || '.' || TABLE_NM;
  LET rs RESULTSET := (EXECUTE IMMEDIATE :sql_stmt);
  LET c CURSOR FOR rs;
  FOR row_val IN c DO
    RETURN row_val.HOURS_SINCE_LAST;
  END FOR;
  RETURN -1;
END;

-- =============================================================================
-- 2. BUSINESS-SPECIFIC DMF STORED PROCEDURES
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 2A. DQ_NONNEG_BALANCE_SAVINGS: Savings accounts with negative balance
-- Returns: Number of savings accounts with BALANCE < 0
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE DQ_NONNEG_BALANCE_SAVINGS()
RETURNS NUMBER
LANGUAGE SQL
AS
BEGIN
  LET sql_stmt := 'SELECT COUNT(*) AS CNT FROM BANKING_DQ_DB.RAW.ACCOUNTS WHERE ACCOUNT_TYPE = ''SAVINGS'' AND BALANCE < 0';
  LET rs RESULTSET := (EXECUTE IMMEDIATE :sql_stmt);
  LET c CURSOR FOR rs;
  FOR row_val IN c DO
    RETURN row_val.CNT;
  END FOR;
  RETURN 0;
END;

-- -----------------------------------------------------------------------------
-- 2B. DQ_APPROVED_LTE_REQUESTED: Approved amount exceeds requested amount
-- Returns: Number of loans where APPROVED_AMOUNT > REQUESTED_AMOUNT
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE DQ_APPROVED_LTE_REQUESTED()
RETURNS NUMBER
LANGUAGE SQL
AS
BEGIN
  LET sql_stmt := 'SELECT COUNT(*) AS CNT FROM BANKING_DQ_DB.RAW.LOAN_APPLICATIONS WHERE APPROVED_AMOUNT IS NOT NULL AND REQUESTED_AMOUNT IS NOT NULL AND APPROVED_AMOUNT > REQUESTED_AMOUNT';
  LET rs RESULTSET := (EXECUTE IMMEDIATE :sql_stmt);
  LET c CURSOR FOR rs;
  FOR row_val IN c DO
    RETURN row_val.CNT;
  END FOR;
  RETURN 0;
END;

-- -----------------------------------------------------------------------------
-- 2C. DQ_APPROVED_NULL_WHEN_NOT_APPROVED: Non-approved loans with approved amount
-- Returns: Count of PENDING/REJECTED loans that have a non-null APPROVED_AMOUNT
-- -----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE DQ_APPROVED_NULL_WHEN_NOT_APPROVED()
RETURNS NUMBER
LANGUAGE SQL
AS
BEGIN
  LET sql_stmt := 'SELECT COUNT(*) AS CNT FROM BANKING_DQ_DB.RAW.LOAN_APPLICATIONS WHERE APPLICATION_STATUS IN (''PENDING'',''REJECTED'') AND APPROVED_AMOUNT IS NOT NULL';
  LET rs RESULTSET := (EXECUTE IMMEDIATE :sql_stmt);
  LET c CURSOR FOR rs;
  FOR row_val IN c DO
    RETURN row_val.CNT;
  END FOR;
  RETURN 0;
END;

-- =============================================================================
-- 3. RULE DEFINITIONS — SQL FOR EACH TABLE/COLUMN COMBINATION
-- =============================================================================
-- These SQL statements define the specific rule for each table.
-- They will be loaded into DQ_RULE_CONFIG table in Step 4.
-- Each returns a violation count (0 = pass, >0 = fail).

/*
=============================================================================
TABLE: BRANCHES — 8 Rules
=============================================================================

Rule 1: CALL DQ_NULL_COUNT('BANKING_DQ_DB.RAW','BRANCHES','BRANCH_ID')
Rule 2: CALL DQ_DUPLICATE_COUNT('BANKING_DQ_DB.RAW','BRANCHES','BRANCH_ID')
Rule 3: CALL DQ_NULL_COUNT('BANKING_DQ_DB.RAW','BRANCHES','BRANCH_NAME')
Rule 4: CALL DQ_NULL_COUNT('BANKING_DQ_DB.RAW','BRANCHES','IFSC_CODE')
Rule 5: CALL DQ_DUPLICATE_COUNT('BANKING_DQ_DB.RAW','BRANCHES','IFSC_CODE')
Rule 6: CALL DQ_ROW_COUNT('BANKING_DQ_DB.RAW','BRANCHES')
Rule 7: CALL DQ_ACCEPTED_VALUES('BANKING_DQ_DB.RAW','BRANCHES','IS_ACTIVE','''true'',''false''')
Rule 8: CALL DQ_FRESHNESS_HOURS('BANKING_DQ_DB.RAW','BRANCHES','CREATED_AT')

=============================================================================
TABLE: CUSTOMERS — 14 Rules
=============================================================================

Rule 9:  CALL DQ_NULL_COUNT('BANKING_DQ_DB.RAW','CUSTOMERS','CUSTOMER_ID')
Rule 10: CALL DQ_DUPLICATE_COUNT('BANKING_DQ_DB.RAW','CUSTOMERS','CUSTOMER_ID')
Rule 11: CALL DQ_NULL_COUNT('BANKING_DQ_DB.RAW','CUSTOMERS','EMAIL')
Rule 12: CALL DQ_DUPLICATE_COUNT('BANKING_DQ_DB.RAW','CUSTOMERS','EMAIL')
Rule 13: CALL DQ_INVALID_EMAIL('BANKING_DQ_DB.RAW','CUSTOMERS','EMAIL')
Rule 14: CALL DQ_NULL_COUNT('BANKING_DQ_DB.RAW','CUSTOMERS','PHONE')
Rule 15: CALL DQ_DUPLICATE_COUNT('BANKING_DQ_DB.RAW','CUSTOMERS','PHONE')
Rule 16: CALL DQ_ACCEPTED_VALUES('BANKING_DQ_DB.RAW','CUSTOMERS','KYC_STATUS','''VERIFIED'',''PENDING'',''REJECTED''')
Rule 17: CALL DQ_ACCEPTED_VALUES('BANKING_DQ_DB.RAW','CUSTOMERS','RISK_CATEGORY','''LOW'',''MEDIUM'',''HIGH''')
Rule 18: CALL DQ_REFERENTIAL_INTEGRITY('BANKING_DQ_DB.RAW','CUSTOMERS','BRANCH_ID','BANKING_DQ_DB.RAW','BRANCHES','BRANCH_ID')
Rule 19: CALL DQ_DOB_AGE_RANGE('BANKING_DQ_DB.RAW','CUSTOMERS','DATE_OF_BIRTH',18,100)
Rule 20: CALL DQ_ROW_COUNT('BANKING_DQ_DB.RAW','CUSTOMERS')
Rule 21: CALL DQ_FRESHNESS_HOURS('BANKING_DQ_DB.RAW','CUSTOMERS','CREATED_AT')
Rule 22: CALL DQ_DUPLICATE_COUNT('BANKING_DQ_DB.RAW','CUSTOMERS','CUSTOMER_ID')

=============================================================================
TABLE: ACCOUNTS — 13 Rules
=============================================================================

Rule 23: CALL DQ_NULL_COUNT('BANKING_DQ_DB.RAW','ACCOUNTS','ACCOUNT_ID')
Rule 24: CALL DQ_DUPLICATE_COUNT('BANKING_DQ_DB.RAW','ACCOUNTS','ACCOUNT_ID')
Rule 25: CALL DQ_NULL_COUNT('BANKING_DQ_DB.RAW','ACCOUNTS','CUSTOMER_ID')
Rule 26: CALL DQ_REFERENTIAL_INTEGRITY('BANKING_DQ_DB.RAW','ACCOUNTS','CUSTOMER_ID','BANKING_DQ_DB.RAW','CUSTOMERS','CUSTOMER_ID')
Rule 27: CALL DQ_REFERENTIAL_INTEGRITY('BANKING_DQ_DB.RAW','ACCOUNTS','BRANCH_ID','BANKING_DQ_DB.RAW','BRANCHES','BRANCH_ID')
Rule 28: CALL DQ_NONNEG_BALANCE_SAVINGS()
Rule 29: CALL DQ_ACCEPTED_VALUES('BANKING_DQ_DB.RAW','ACCOUNTS','ACCOUNT_TYPE','''SAVINGS'',''CURRENT'',''LOAN''')
Rule 30: CALL DQ_ACCEPTED_VALUES('BANKING_DQ_DB.RAW','ACCOUNTS','ACCOUNT_STATUS','''ACTIVE'',''CLOSED'',''DORMANT''')
Rule 31: CALL DQ_ACCEPTED_VALUES('BANKING_DQ_DB.RAW','ACCOUNTS','CURRENCY','''INR'',''USD''')
Rule 32: CALL DQ_FUTURE_DATE_CHECK('BANKING_DQ_DB.RAW','ACCOUNTS','OPEN_DATE')
Rule 33: CALL DQ_ROW_COUNT('BANKING_DQ_DB.RAW','ACCOUNTS')
Rule 34: CALL DQ_DUPLICATE_COUNT('BANKING_DQ_DB.RAW','ACCOUNTS','ACCOUNT_ID')
Rule 35: CALL DQ_FRESHNESS_HOURS('BANKING_DQ_DB.RAW','ACCOUNTS','CREATED_AT')

=============================================================================
TABLE: TRANSACTIONS — 12 Rules
=============================================================================

Rule 36: CALL DQ_NULL_COUNT('BANKING_DQ_DB.RAW','TRANSACTIONS','TRANSACTION_ID')
Rule 37: CALL DQ_DUPLICATE_COUNT('BANKING_DQ_DB.RAW','TRANSACTIONS','TRANSACTION_ID')
Rule 38: CALL DQ_NULL_COUNT('BANKING_DQ_DB.RAW','TRANSACTIONS','ACCOUNT_ID')
Rule 39: CALL DQ_REFERENTIAL_INTEGRITY('BANKING_DQ_DB.RAW','TRANSACTIONS','ACCOUNT_ID','BANKING_DQ_DB.RAW','ACCOUNTS','ACCOUNT_ID')
Rule 40: CALL DQ_POSITIVE_CHECK('BANKING_DQ_DB.RAW','TRANSACTIONS','AMOUNT')
Rule 41: CALL DQ_ACCEPTED_VALUES('BANKING_DQ_DB.RAW','TRANSACTIONS','TRANSACTION_STATUS','''SUCCESS'',''FAILED'',''PENDING''')
Rule 42: CALL DQ_ACCEPTED_VALUES('BANKING_DQ_DB.RAW','TRANSACTIONS','TRANSACTION_TYPE','''CREDIT'',''DEBIT'',''PAYMENT''')
Rule 43: CALL DQ_ACCEPTED_VALUES('BANKING_DQ_DB.RAW','TRANSACTIONS','CHANNEL','''UPI'',''CARD'',''NEFT'',''IMPS'',''ATM'',''CHEQUE''')
Rule 44: CALL DQ_FUTURE_DATE_CHECK('BANKING_DQ_DB.RAW','TRANSACTIONS','TRANSACTION_DATE')
Rule 45: CALL DQ_ROW_COUNT('BANKING_DQ_DB.RAW','TRANSACTIONS')
Rule 46: CALL DQ_DUPLICATE_COUNT('BANKING_DQ_DB.RAW','TRANSACTIONS','TRANSACTION_ID')
Rule 47: CALL DQ_FRESHNESS_HOURS('BANKING_DQ_DB.RAW','TRANSACTIONS','CREATED_AT')

=============================================================================
TABLE: LOAN_APPLICATIONS — 14 Rules
=============================================================================

Rule 48: CALL DQ_NULL_COUNT('BANKING_DQ_DB.RAW','LOAN_APPLICATIONS','APPLICATION_ID')
Rule 49: CALL DQ_DUPLICATE_COUNT('BANKING_DQ_DB.RAW','LOAN_APPLICATIONS','APPLICATION_ID')
Rule 50: CALL DQ_NULL_COUNT('BANKING_DQ_DB.RAW','LOAN_APPLICATIONS','CUSTOMER_ID')
Rule 51: CALL DQ_REFERENTIAL_INTEGRITY('BANKING_DQ_DB.RAW','LOAN_APPLICATIONS','CUSTOMER_ID','BANKING_DQ_DB.RAW','CUSTOMERS','CUSTOMER_ID')
Rule 52: CALL DQ_REFERENTIAL_INTEGRITY('BANKING_DQ_DB.RAW','LOAN_APPLICATIONS','BRANCH_ID','BANKING_DQ_DB.RAW','BRANCHES','BRANCH_ID')
Rule 53: CALL DQ_POSITIVE_CHECK('BANKING_DQ_DB.RAW','LOAN_APPLICATIONS','REQUESTED_AMOUNT')
Rule 54: CALL DQ_RANGE_CHECK('BANKING_DQ_DB.RAW','LOAN_APPLICATIONS','CREDIT_SCORE','300','900')
Rule 55: CALL DQ_APPROVED_LTE_REQUESTED()
Rule 56: CALL DQ_ACCEPTED_VALUES('BANKING_DQ_DB.RAW','LOAN_APPLICATIONS','APPLICATION_STATUS','''APPROVED'',''PENDING'',''REJECTED''')
Rule 57: CALL DQ_ACCEPTED_VALUES('BANKING_DQ_DB.RAW','LOAN_APPLICATIONS','LOAN_TYPE','''HOME'',''PERSONAL'',''CAR'',''EDUCATION'',''BUSINESS''')
Rule 58: CALL DQ_APPROVED_NULL_WHEN_NOT_APPROVED()
Rule 59: CALL DQ_ROW_COUNT('BANKING_DQ_DB.RAW','LOAN_APPLICATIONS')
Rule 60: CALL DQ_DUPLICATE_COUNT('BANKING_DQ_DB.RAW','LOAN_APPLICATIONS','APPLICATION_ID')
Rule 61: CALL DQ_FRESHNESS_HOURS('BANKING_DQ_DB.RAW','LOAN_APPLICATIONS','CREATED_AT')

*/
