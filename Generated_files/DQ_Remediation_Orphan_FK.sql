/*******************************************************************************
 *  DQ_Remediation_Orphan_FK.sql
 *  Data Quality Framework – Remediation: Fix Orphan Foreign Key Records
 *  Database : BANKING_DQ_DB
 *  Schema   : RAW
 *
 *  SUMMARY OF ORPHAN RECORDS:
 *    B999 (Branch)   — Referenced by CUSTOMERS(C010), ACCOUNTS(A010), LOAN_APPLICATIONS(L009)
 *    C999 (Customer) — Referenced by ACCOUNTS(A009), LOAN_APPLICATIONS(L008)
 *    A999 (Account)  — Referenced by TRANSACTIONS(T009)
 *
 *  CHOOSE ONE OPTION BELOW. DO NOT RUN BOTH.
 ******************************************************************************/

USE DATABASE BANKING_DQ_DB;
USE SCHEMA RAW;

-- =============================================================================
-- OPTION A: INSERT MISSING PARENT RECORDS
-- Use when: The parent records genuinely should exist but were missed during load.
-- These insert placeholder records that need manual verification/update.
-- =============================================================================

-- A1. Insert missing branch B999
-- Affected: CUSTOMERS(C010), ACCOUNTS(A010), LOAN_APPLICATIONS(L009)
INSERT INTO BRANCHES (BRANCH_ID, BRANCH_NAME, CITY, STATE, IFSC_CODE, IS_ACTIVE, CREATED_AT)
VALUES ('B999', 'Unknown Branch - Pending Verification', 'UNKNOWN', 'UNKNOWN', 'BKID0000999', 'true', CURRENT_TIMESTAMP());

-- A2. Insert missing customer C999
-- Affected: ACCOUNTS(A009), LOAN_APPLICATIONS(L008)
INSERT INTO CUSTOMERS (CUSTOMER_ID, FIRST_NAME, LAST_NAME, EMAIL, PHONE, DATE_OF_BIRTH, KYC_STATUS, RISK_CATEGORY, BRANCH_ID, CREATED_AT)
VALUES ('C999', 'Unknown', 'Customer', 'unknown.c999@placeholder.com', '0000000000', '1990-01-01', 'PENDING', 'HIGH', 'B001', CURRENT_TIMESTAMP());

-- A3. Insert missing account A999
-- Affected: TRANSACTIONS(T009)
INSERT INTO ACCOUNTS (ACCOUNT_ID, CUSTOMER_ID, BRANCH_ID, ACCOUNT_TYPE, ACCOUNT_STATUS, OPEN_DATE, BALANCE, CURRENCY, CREATED_AT)
VALUES ('A999', 'C001', 'B001', 'SAVINGS', 'ACTIVE', CURRENT_DATE(), 0.00, 'INR', CURRENT_TIMESTAMP());

-- =============================================================================
-- OPTION B: REASSIGN ORPHANS TO VALID PARENT RECORDS
-- Use when: The FK values were data entry errors and should point to real records.
-- Update the target IDs below to the correct values for your business context.
-- =============================================================================

-- B1. CUSTOMERS: Reassign C010 from non-existent B999 to valid branch B003 (Andheri East, Mumbai)
UPDATE CUSTOMERS 
SET BRANCH_ID = 'B003'  -- <-- Change to correct branch
WHERE BRANCH_ID = 'B999';
-- Rows affected: 1 (C010 - Sara Thomas)

-- B2. ACCOUNTS: Reassign A010 from non-existent B999 to valid branch B003
UPDATE ACCOUNTS 
SET BRANCH_ID = 'B003'  -- <-- Change to correct branch
WHERE BRANCH_ID = 'B999';
-- Rows affected: 1 (A010 - Loan account, C010, 10000 USD)

-- B3. LOAN_APPLICATIONS: Reassign L009 from non-existent B999 to valid branch B003
UPDATE LOAN_APPLICATIONS 
SET BRANCH_ID = 'B003'  -- <-- Change to correct branch
WHERE BRANCH_ID = 'B999';
-- Rows affected: 1 (L009 - Business loan, C008, 2M)

-- B4. ACCOUNTS: Reassign A009 from non-existent C999 to valid customer C001
UPDATE ACCOUNTS 
SET CUSTOMER_ID = 'C001'  -- <-- Change to correct customer
WHERE CUSTOMER_ID = 'C999';
-- Rows affected: 1 (A009 - Savings, 23000 INR)

-- B5. LOAN_APPLICATIONS: Reassign L008 from non-existent C999 to valid customer C001
UPDATE LOAN_APPLICATIONS 
SET CUSTOMER_ID = 'C001'  -- <-- Change to correct customer
WHERE CUSTOMER_ID = 'C999';
-- Rows affected: 1 (L008 - Home loan, 4M, PENDING)

-- B6. TRANSACTIONS: Reassign T009 from non-existent A999 to valid account A001
UPDATE TRANSACTIONS 
SET ACCOUNT_ID = 'A001'  -- <-- Change to correct account
WHERE ACCOUNT_ID = 'A999';
-- Rows affected: 1 (T009 - Debit, 1500, CARD/FUEL)

-- =============================================================================
-- VERIFICATION: Run after applying either option
-- =============================================================================
-- Re-check referential integrity (all should return 0)
SELECT 'ACCOUNTS.CUSTOMER_ID' AS FK_CHECK, COUNT(*) AS ORPHANS
FROM ACCOUNTS a LEFT JOIN CUSTOMERS c ON a.CUSTOMER_ID = c.CUSTOMER_ID WHERE c.CUSTOMER_ID IS NULL
UNION ALL
SELECT 'ACCOUNTS.BRANCH_ID', COUNT(*)
FROM ACCOUNTS a LEFT JOIN BRANCHES b ON a.BRANCH_ID = b.BRANCH_ID WHERE b.BRANCH_ID IS NULL
UNION ALL
SELECT 'TRANSACTIONS.ACCOUNT_ID', COUNT(*)
FROM TRANSACTIONS t LEFT JOIN ACCOUNTS a ON t.ACCOUNT_ID = a.ACCOUNT_ID WHERE a.ACCOUNT_ID IS NULL
UNION ALL
SELECT 'CUSTOMERS.BRANCH_ID', COUNT(*)
FROM CUSTOMERS c LEFT JOIN BRANCHES b ON c.BRANCH_ID = b.BRANCH_ID WHERE b.BRANCH_ID IS NULL
UNION ALL
SELECT 'LOAN_APPLICATIONS.CUSTOMER_ID', COUNT(*)
FROM LOAN_APPLICATIONS la LEFT JOIN CUSTOMERS c ON la.CUSTOMER_ID = c.CUSTOMER_ID WHERE c.CUSTOMER_ID IS NULL
UNION ALL
SELECT 'LOAN_APPLICATIONS.BRANCH_ID', COUNT(*)
FROM LOAN_APPLICATIONS la LEFT JOIN BRANCHES b ON la.BRANCH_ID = b.BRANCH_ID WHERE b.BRANCH_ID IS NULL;

-- Re-run DQ framework to verify fixes:
-- CALL BANKING_DQ_DB.DQ_MONITORING.RUN_DQ_FRAMEWORK('POST_REMEDIATION');
