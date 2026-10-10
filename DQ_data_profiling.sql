/*******************************************************************************
 *  DQ_data_profiling.sql
 *  Data Quality Framework – Step 1: Data Profiling & Analysis
 *  Database : BANKING_DQ_DB
 *  Schema   : RAW
 *  Tables   : BRANCHES, CUSTOMERS, ACCOUNTS, TRANSACTIONS, LOAN_APPLICATIONS
 ******************************************************************************/

-- =============================================================================
-- 0. SET CONTEXT
-- =============================================================================
USE DATABASE BANKING_DQ_DB;
USE SCHEMA RAW;

-- =============================================================================
-- 1. TABLE STRUCTURES
-- =============================================================================
DESCRIBE TABLE BRANCHES;
DESCRIBE TABLE CUSTOMERS;
DESCRIBE TABLE ACCOUNTS;
DESCRIBE TABLE TRANSACTIONS;
DESCRIBE TABLE LOAN_APPLICATIONS;

-- =============================================================================
-- 2. SAMPLE DATA (5 ROWS PER TABLE)
-- =============================================================================
SELECT * FROM BRANCHES LIMIT 5;
SELECT * FROM CUSTOMERS LIMIT 5;
SELECT * FROM ACCOUNTS LIMIT 5;
SELECT * FROM TRANSACTIONS LIMIT 5;
SELECT * FROM LOAN_APPLICATIONS LIMIT 5;

-- =============================================================================
-- 3. ROW COUNTS
-- =============================================================================
SELECT 'BRANCHES' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM BRANCHES
UNION ALL SELECT 'CUSTOMERS', COUNT(*) FROM CUSTOMERS
UNION ALL SELECT 'ACCOUNTS', COUNT(*) FROM ACCOUNTS
UNION ALL SELECT 'TRANSACTIONS', COUNT(*) FROM TRANSACTIONS
UNION ALL SELECT 'LOAN_APPLICATIONS', COUNT(*) FROM LOAN_APPLICATIONS;

-- =============================================================================
-- 4. TABLE-WISE PROFILING
-- =============================================================================

-- 4A. BRANCHES PROFILING
SELECT 
  COUNT(*) AS TOTAL_ROWS,
  COUNT(BRANCH_ID) AS BRANCH_ID_NON_NULL, COUNT(DISTINCT BRANCH_ID) AS BRANCH_ID_DISTINCT,
  COUNT(BRANCH_NAME) AS BRANCH_NAME_NON_NULL, COUNT(DISTINCT BRANCH_NAME) AS BRANCH_NAME_DISTINCT,
  COUNT(CITY) AS CITY_NON_NULL, COUNT(DISTINCT CITY) AS CITY_DISTINCT,
  COUNT(STATE) AS STATE_NON_NULL, COUNT(DISTINCT STATE) AS STATE_DISTINCT,
  COUNT(IFSC_CODE) AS IFSC_NON_NULL, COUNT(DISTINCT IFSC_CODE) AS IFSC_DISTINCT,
  COUNT(IS_ACTIVE) AS IS_ACTIVE_NON_NULL, COUNT(DISTINCT IS_ACTIVE) AS IS_ACTIVE_DISTINCT,
  COUNT(CREATED_AT) AS CREATED_AT_NON_NULL
FROM BRANCHES;

-- 4B. CUSTOMERS PROFILING
SELECT 
  COUNT(*) AS TOTAL_ROWS,
  COUNT(CUSTOMER_ID) AS CUST_ID_NON_NULL, COUNT(DISTINCT CUSTOMER_ID) AS CUST_ID_DISTINCT,
  COUNT(EMAIL) AS EMAIL_NON_NULL, COUNT(DISTINCT EMAIL) AS EMAIL_DISTINCT,
  COUNT(PHONE) AS PHONE_NON_NULL, COUNT(DISTINCT PHONE) AS PHONE_DISTINCT,
  SUM(CASE WHEN KYC_STATUS IS NULL THEN 1 ELSE 0 END) AS KYC_NULLS,
  COUNT(DISTINCT KYC_STATUS) AS KYC_DISTINCT,
  COUNT(DISTINCT RISK_CATEGORY) AS RISK_DISTINCT,
  SUM(CASE WHEN DATE_OF_BIRTH IS NULL THEN 1 ELSE 0 END) AS DOB_NULLS,
  SUM(CASE WHEN BRANCH_ID IS NULL THEN 1 ELSE 0 END) AS BRANCH_ID_NULLS
FROM CUSTOMERS;

-- 4C. ACCOUNTS PROFILING
SELECT 
  COUNT(*) AS TOTAL_ROWS,
  COUNT(ACCOUNT_ID) AS ACCT_ID_NON_NULL, COUNT(DISTINCT ACCOUNT_ID) AS ACCT_ID_DISTINCT,
  COUNT(DISTINCT ACCOUNT_TYPE) AS ACCT_TYPE_DISTINCT, COUNT(DISTINCT ACCOUNT_STATUS) AS ACCT_STATUS_DISTINCT,
  SUM(CASE WHEN BALANCE IS NULL THEN 1 ELSE 0 END) AS BALANCE_NULLS,
  MIN(BALANCE) AS MIN_BALANCE, MAX(BALANCE) AS MAX_BALANCE, AVG(BALANCE) AS AVG_BALANCE,
  COUNT(DISTINCT CURRENCY) AS CURRENCY_DISTINCT,
  SUM(CASE WHEN CUSTOMER_ID IS NULL THEN 1 ELSE 0 END) AS CUST_ID_NULLS,
  SUM(CASE WHEN BRANCH_ID IS NULL THEN 1 ELSE 0 END) AS BRANCH_ID_NULLS
FROM ACCOUNTS;

-- 4D. TRANSACTIONS PROFILING
SELECT 
  COUNT(*) AS TOTAL_ROWS,
  COUNT(TRANSACTION_ID) AS TXN_ID_NON_NULL, COUNT(DISTINCT TRANSACTION_ID) AS TXN_ID_DISTINCT,
  COUNT(DISTINCT TRANSACTION_TYPE) AS TXN_TYPE_DISTINCT,
  COUNT(DISTINCT CHANNEL) AS CHANNEL_DISTINCT,
  COUNT(DISTINCT MERCHANT_CATEGORY) AS MERCHANT_DISTINCT,
  COUNT(DISTINCT TRANSACTION_STATUS) AS STATUS_DISTINCT,
  SUM(CASE WHEN AMOUNT IS NULL THEN 1 ELSE 0 END) AS AMOUNT_NULLS,
  MIN(AMOUNT) AS MIN_AMOUNT, MAX(AMOUNT) AS MAX_AMOUNT, AVG(AMOUNT) AS AVG_AMOUNT,
  SUM(CASE WHEN ACCOUNT_ID IS NULL THEN 1 ELSE 0 END) AS ACCT_ID_NULLS
FROM TRANSACTIONS;

-- 4E. LOAN_APPLICATIONS PROFILING
SELECT 
  COUNT(*) AS TOTAL_ROWS,
  COUNT(APPLICATION_ID) AS APP_ID_NON_NULL, COUNT(DISTINCT APPLICATION_ID) AS APP_ID_DISTINCT,
  COUNT(DISTINCT LOAN_TYPE) AS LOAN_TYPE_DISTINCT,
  COUNT(DISTINCT APPLICATION_STATUS) AS STATUS_DISTINCT,
  SUM(CASE WHEN APPROVED_AMOUNT IS NULL THEN 1 ELSE 0 END) AS APPROVED_AMT_NULLS,
  SUM(CASE WHEN CREDIT_SCORE IS NULL THEN 1 ELSE 0 END) AS CREDIT_SCORE_NULLS,
  MIN(REQUESTED_AMOUNT) AS MIN_REQ_AMT, MAX(REQUESTED_AMOUNT) AS MAX_REQ_AMT,
  MIN(CREDIT_SCORE) AS MIN_CREDIT, MAX(CREDIT_SCORE) AS MAX_CREDIT,
  SUM(CASE WHEN CUSTOMER_ID IS NULL THEN 1 ELSE 0 END) AS CUST_ID_NULLS,
  SUM(CASE WHEN BRANCH_ID IS NULL THEN 1 ELSE 0 END) AS BRANCH_ID_NULLS
FROM LOAN_APPLICATIONS;

-- =============================================================================
-- 5. CATEGORICAL COLUMN VALUE DISTRIBUTION
-- =============================================================================
SELECT 'CUSTOMERS.KYC_STATUS' AS COL, KYC_STATUS AS VAL, COUNT(*) AS CNT FROM CUSTOMERS GROUP BY KYC_STATUS
UNION ALL SELECT 'CUSTOMERS.RISK_CATEGORY', RISK_CATEGORY, COUNT(*) FROM CUSTOMERS GROUP BY RISK_CATEGORY
UNION ALL SELECT 'ACCOUNTS.ACCOUNT_TYPE', ACCOUNT_TYPE, COUNT(*) FROM ACCOUNTS GROUP BY ACCOUNT_TYPE
UNION ALL SELECT 'ACCOUNTS.ACCOUNT_STATUS', ACCOUNT_STATUS, COUNT(*) FROM ACCOUNTS GROUP BY ACCOUNT_STATUS
UNION ALL SELECT 'ACCOUNTS.CURRENCY', CURRENCY, COUNT(*) FROM ACCOUNTS GROUP BY CURRENCY
UNION ALL SELECT 'TRANSACTIONS.TRANSACTION_TYPE', TRANSACTION_TYPE, COUNT(*) FROM TRANSACTIONS GROUP BY TRANSACTION_TYPE
UNION ALL SELECT 'TRANSACTIONS.TRANSACTION_STATUS', TRANSACTION_STATUS, COUNT(*) FROM TRANSACTIONS GROUP BY TRANSACTION_STATUS
UNION ALL SELECT 'TRANSACTIONS.CHANNEL', CHANNEL, COUNT(*) FROM TRANSACTIONS GROUP BY CHANNEL
UNION ALL SELECT 'LOAN_APPLICATIONS.LOAN_TYPE', LOAN_TYPE, COUNT(*) FROM LOAN_APPLICATIONS GROUP BY LOAN_TYPE
UNION ALL SELECT 'LOAN_APPLICATIONS.APPLICATION_STATUS', APPLICATION_STATUS, COUNT(*) FROM LOAN_APPLICATIONS GROUP BY APPLICATION_STATUS
UNION ALL SELECT 'BRANCHES.IS_ACTIVE', IS_ACTIVE, COUNT(*) FROM BRANCHES GROUP BY IS_ACTIVE
ORDER BY COL, VAL;

-- =============================================================================
-- 6. DATA QUALITY ISSUES DETECTED
-- =============================================================================

-- 6A. Negative balances
SELECT 'NEGATIVE_BALANCE' AS ISSUE, ACCOUNT_ID, BALANCE AS VALUE FROM ACCOUNTS WHERE BALANCE < 0;

-- 6B. Negative transaction amounts
SELECT 'NEGATIVE_TXN_AMOUNT' AS ISSUE, TRANSACTION_ID, AMOUNT AS VALUE FROM TRANSACTIONS WHERE AMOUNT < 0;

-- 6C. Zero/negative loan requested amounts
SELECT 'ZERO_LOAN_REQ_AMT' AS ISSUE, APPLICATION_ID, REQUESTED_AMOUNT AS VALUE FROM LOAN_APPLICATIONS WHERE REQUESTED_AMOUNT <= 0;

-- 6D. NULL BRANCH_NAME
SELECT * FROM BRANCHES WHERE BRANCH_NAME IS NULL;

-- =============================================================================
-- 7. REFERENTIAL INTEGRITY CHECKS
-- =============================================================================
SELECT 'ACCOUNTS.CUSTOMER_ID -> CUSTOMERS' AS FK_CHECK, COUNT(*) AS ORPHAN_COUNT
FROM ACCOUNTS a LEFT JOIN CUSTOMERS c ON a.CUSTOMER_ID = c.CUSTOMER_ID WHERE c.CUSTOMER_ID IS NULL
UNION ALL
SELECT 'ACCOUNTS.BRANCH_ID -> BRANCHES', COUNT(*)
FROM ACCOUNTS a LEFT JOIN BRANCHES b ON a.BRANCH_ID = b.BRANCH_ID WHERE b.BRANCH_ID IS NULL
UNION ALL
SELECT 'TRANSACTIONS.ACCOUNT_ID -> ACCOUNTS', COUNT(*)
FROM TRANSACTIONS t LEFT JOIN ACCOUNTS a ON t.ACCOUNT_ID = a.ACCOUNT_ID WHERE a.ACCOUNT_ID IS NULL
UNION ALL
SELECT 'CUSTOMERS.BRANCH_ID -> BRANCHES', COUNT(*)
FROM CUSTOMERS c LEFT JOIN BRANCHES b ON c.BRANCH_ID = b.BRANCH_ID WHERE b.BRANCH_ID IS NULL
UNION ALL
SELECT 'LOAN_APPLICATIONS.CUSTOMER_ID -> CUSTOMERS', COUNT(*)
FROM LOAN_APPLICATIONS la LEFT JOIN CUSTOMERS c ON la.CUSTOMER_ID = c.CUSTOMER_ID WHERE c.CUSTOMER_ID IS NULL
UNION ALL
SELECT 'LOAN_APPLICATIONS.BRANCH_ID -> BRANCHES', COUNT(*)
FROM LOAN_APPLICATIONS la LEFT JOIN BRANCHES b ON la.BRANCH_ID = b.BRANCH_ID WHERE b.BRANCH_ID IS NULL;

/*******************************************************************************
 *  DATA PROFILING SUMMARY
 *******************************************************************************
 *
 *  TABLE: BRANCHES (7 rows, 7 columns)
 *  -----------------------------------------------------------------------
 *  Purpose        : Reference table for bank branch locations
 *  Primary Key    : BRANCH_ID (7 distinct, 100% unique)
 *  Key Columns    : BRANCH_ID, BRANCH_NAME, IFSC_CODE
 *  Numeric Cols   : None
 *  Date Cols      : CREATED_AT
 *  Categorical    : CITY (7 distinct), STATE (6 distinct), IS_ACTIVE (1 distinct - all 'true')
 *  Issues Found   : 1 NULL BRANCH_NAME (B007), IS_ACTIVE is VARCHAR not BOOLEAN
 *  Focus Areas    : Completeness (BRANCH_NAME), data type consistency (IS_ACTIVE)
 *
 *  TABLE: CUSTOMERS (10 rows, 10 columns)
 *  -----------------------------------------------------------------------
 *  Purpose        : Core customer master with KYC and risk data
 *  Primary Key    : CUSTOMER_ID (10 distinct, 100% unique)
 *  Foreign Keys   : BRANCH_ID -> BRANCHES.BRANCH_ID
 *  Key Columns    : CUSTOMER_ID, EMAIL, PHONE, KYC_STATUS, RISK_CATEGORY
 *  Numeric Cols   : None
 *  Date Cols      : DATE_OF_BIRTH, CREATED_AT
 *  Categorical    : KYC_STATUS (VERIFIED:8, PENDING:1, DONE:1),
 *                   RISK_CATEGORY (LOW:7, MEDIUM:2, HIGH:1)
 *  Issues Found   : KYC_STATUS has inconsistent values ('DONE' vs expected 'VERIFIED'),
 *                   1 orphan BRANCH_ID not in BRANCHES
 *  Focus Areas    : Email/phone format, KYC status accepted values, referential integrity,
 *                   date-of-birth range validity, uniqueness of EMAIL/PHONE
 *
 *  TABLE: ACCOUNTS (10 rows, 9 columns)
 *  -----------------------------------------------------------------------
 *  Purpose        : Customer bank accounts with balances
 *  Primary Key    : ACCOUNT_ID (10 distinct, 100% unique)
 *  Foreign Keys   : CUSTOMER_ID -> CUSTOMERS.CUSTOMER_ID,
 *                   BRANCH_ID -> BRANCHES.BRANCH_ID
 *  Key Columns    : ACCOUNT_ID, CUSTOMER_ID, ACCOUNT_TYPE, ACCOUNT_STATUS, BALANCE
 *  Numeric Cols   : BALANCE (min: -1500, max: 250000, avg: 52650)
 *  Date Cols      : OPEN_DATE, CREATED_AT
 *  Categorical    : ACCOUNT_TYPE (SAVINGS:7, CURRENT:2, LOAN:1),
 *                   ACCOUNT_STATUS (ACTIVE:8, CLOSED:1, DORMANT:1),
 *                   CURRENCY (INR:9, USD:1)
 *  Issues Found   : 1 negative balance (-1500 for A008), 1 orphan CUSTOMER_ID,
 *                   1 orphan BRANCH_ID, mixed currency (INR/USD)
 *  Focus Areas    : Balance range, referential integrity, currency consistency,
 *                   account status transitions
 *
 *  TABLE: TRANSACTIONS (12 rows, 9 columns)
 *  -----------------------------------------------------------------------
 *  Purpose        : Banking transaction records (debits, credits, payments)
 *  Primary Key    : TRANSACTION_ID (12 distinct, 100% unique)
 *  Foreign Keys   : ACCOUNT_ID -> ACCOUNTS.ACCOUNT_ID
 *  Key Columns    : TRANSACTION_ID, ACCOUNT_ID, AMOUNT, TRANSACTION_TYPE, TRANSACTION_STATUS
 *  Numeric Cols   : AMOUNT (min: -50, max: 9900, avg: 3549.92)
 *  Date Cols      : TRANSACTION_DATE, CREATED_AT
 *  Categorical    : TRANSACTION_TYPE (DEBIT:8, CREDIT:3, PAYMENT:1),
 *                   TRANSACTION_STATUS (SUCCESS:10, DONE:1, FAILED:1),
 *                   CHANNEL (UPI:5, CARD:3, ATM:1, CHEQUE:1, IMPS:1, NEFT:1),
 *                   MERCHANT_CATEGORY (9 distinct)
 *  Issues Found   : 1 negative amount (-50 for T008), STATUS has inconsistent values
 *                   ('DONE' vs 'SUCCESS'), 1 orphan ACCOUNT_ID
 *  Focus Areas    : Amount positivity, referential integrity, status accepted values,
 *                   future-dated transactions, row count trends
 *
 *  TABLE: LOAN_APPLICATIONS (10 rows, 10 columns)
 *  -----------------------------------------------------------------------
 *  Purpose        : Loan application tracking with approval status
 *  Primary Key    : APPLICATION_ID (10 distinct, 100% unique)
 *  Foreign Keys   : CUSTOMER_ID -> CUSTOMERS.CUSTOMER_ID,
 *                   BRANCH_ID -> BRANCHES.BRANCH_ID
 *  Key Columns    : APPLICATION_ID, CUSTOMER_ID, LOAN_TYPE, APPLICATION_STATUS,
 *                   REQUESTED_AMOUNT, APPROVED_AMOUNT, CREDIT_SCORE
 *  Numeric Cols   : REQUESTED_AMOUNT (min: 0, max: 5000000),
 *                   APPROVED_AMOUNT (6 NULLs - expected for PENDING/REJECTED),
 *                   CREDIT_SCORE (min: 610, max: 900)
 *  Date Cols      : APPLICATION_DATE, CREATED_AT
 *  Categorical    : LOAN_TYPE (HOME:3, PERSONAL:3, CAR:2, EDUCATION:1, BUSINESS:1),
 *                   APPLICATION_STATUS (PENDING:5, APPROVED:4, REJECTED:1)
 *  Issues Found   : 1 zero REQUESTED_AMOUNT (L006), APPROVED > REQUESTED possible,
 *                   credit score range needs validation (300-900 standard),
 *                   1 orphan CUSTOMER_ID, 1 orphan BRANCH_ID
 *  Focus Areas    : Amount positivity, credit score range, referential integrity,
 *                   business logic (approved <= requested), status consistency
 *
 ******************************************************************************/
