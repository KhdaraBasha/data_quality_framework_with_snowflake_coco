/*******************************************************************************
 *  DQ_Proposed_Rules.sql
 *  Data Quality Framework – Step 2: Recommended Data Quality Rules
 *  Database : BANKING_DQ_DB
 *  Schema   : RAW
 *
 *  This file documents all recommended System DMFs and Custom DMFs
 *  organized by table, dimension, and priority.
 ******************************************************************************/

/*******************************************************************************
 *  RULE SUMMARY BY TABLE
 *******************************************************************************
 *
 *  BRANCHES           :  8 rules (2 HIGH, 3 MEDIUM, 3 LOW)
 *  CUSTOMERS          : 14 rules (7 HIGH, 4 MEDIUM, 3 LOW)
 *  ACCOUNTS           : 13 rules (5 HIGH, 5 MEDIUM, 3 LOW)
 *  TRANSACTIONS       : 12 rules (5 HIGH, 5 MEDIUM, 2 LOW)
 *  LOAN_APPLICATIONS  : 14 rules (7 HIGH, 4 MEDIUM, 3 LOW)
 *  ---------------------------------------------------
 *  TOTAL              : 61 rules (26 HIGH, 21 MEDIUM, 14 LOW)
 *
 ******************************************************************************/

/*******************************************************************************
 *  RULE TYPES:
 *    - SYSTEM DMF  : Built-in Snowflake Data Metric Functions
 *                    (NULL_COUNT, DUPLICATE_COUNT, UNIQUE_COUNT, ROW_COUNT,
 *                     FRESHNESS)
 *    - CUSTOM DMF  : User-defined Data Metric Functions for business logic
 *
 *  DIMENSIONS:
 *    - Completeness  : Are required fields populated?
 *    - Uniqueness    : Are key values unique?
 *    - Validity      : Do values fall within expected ranges/formats?
 *    - Consistency   : Are categorical values from accepted sets?
 *    - Integrity     : Do foreign keys reference valid parent records?
 *    - Accuracy      : Do business rules hold (e.g., approved <= requested)?
 *    - Timeliness    : Is data fresh enough?
 ******************************************************************************/

-- =============================================================================
-- A. SYSTEM DMFs (BUILT-IN) — Applied across all 5 tables
-- =============================================================================
-- These use SNOWFLAKE.CORE system DMFs:
--   SNOWFLAKE.CORE.NULL_COUNT(REF(column))
--   SNOWFLAKE.CORE.DUPLICATE_COUNT(REF(column))
--   SNOWFLAKE.CORE.UNIQUE_COUNT(REF(column))
--   SNOWFLAKE.CORE.ROW_COUNT(REF(table))
--   SNOWFLAKE.CORE.FRESHNESS(REF(column))

/*
=============================================================================
TABLE: BRANCHES
=============================================================================

| # | RULE NAME                      | RULE TYPE   | DIMENSION    | DESCRIPTION                                        | PRIORITY |
|---|--------------------------------|-------------|--------------|----------------------------------------------------|----------|
| 1 | BRANCH_ID not null             | System DMF  | Completeness | BRANCH_ID must not be null                         | HIGH     |
| 2 | BRANCH_ID uniqueness           | System DMF  | Uniqueness   | BRANCH_ID must be unique                           | HIGH     |
| 3 | BRANCH_NAME not null           | System DMF  | Completeness | BRANCH_NAME must not be null (1 NULL found: B007)  | HIGH     |
| 4 | IFSC_CODE not null             | System DMF  | Completeness | IFSC_CODE must not be null                         | MEDIUM   |
| 5 | IFSC_CODE uniqueness           | System DMF  | Uniqueness   | IFSC_CODE must be unique                           | MEDIUM   |
| 6 | Row count check                | System DMF  | Completeness | Monitor row count for unexpected drops             | MEDIUM   |
| 7 | IS_ACTIVE accepted values      | Custom DMF  | Validity     | IS_ACTIVE must be 'true' or 'false'                | LOW      |
| 8 | Freshness check                | System DMF  | Timeliness   | CREATED_AT freshness monitoring                    | LOW      |

=============================================================================
TABLE: CUSTOMERS
=============================================================================

| # | RULE NAME                      | RULE TYPE   | DIMENSION    | DESCRIPTION                                                          | PRIORITY |
|---|--------------------------------|-------------|--------------|----------------------------------------------------------------------|----------|
| 1 | CUSTOMER_ID not null           | System DMF  | Completeness | CUSTOMER_ID must not be null                                         | HIGH     |
| 2 | CUSTOMER_ID uniqueness         | System DMF  | Uniqueness   | CUSTOMER_ID must be unique                                           | HIGH     |
| 3 | EMAIL not null                 | System DMF  | Completeness | EMAIL must not be null                                               | HIGH     |
| 4 | EMAIL uniqueness               | System DMF  | Uniqueness   | EMAIL must be unique per customer                                    | HIGH     |
| 5 | EMAIL format validity          | Custom DMF  | Validity     | EMAIL must match valid email pattern                                 | HIGH     |
| 6 | PHONE not null                 | System DMF  | Completeness | PHONE must not be null                                               | HIGH     |
| 7 | PHONE uniqueness               | System DMF  | Uniqueness   | PHONE must be unique                                                 | MEDIUM   |
| 8 | KYC_STATUS accepted values     | Custom DMF  | Consistency  | KYC_STATUS must be VERIFIED/PENDING/REJECTED ('DONE' is suspicious)  | HIGH     |
| 9 | RISK_CATEGORY accepted values  | Custom DMF  | Validity     | RISK_CATEGORY must be LOW/MEDIUM/HIGH                                | MEDIUM   |
|10 | BRANCH_ID referential integrity| Custom DMF  | Integrity    | BRANCH_ID must exist in BRANCHES                                     | HIGH     |
|11 | DATE_OF_BIRTH range check      | Custom DMF  | Validity     | DOB: customer must be between 18-100 years old                       | MEDIUM   |
|12 | Row count check                | System DMF  | Completeness | Monitor row count trends                                             | MEDIUM   |
|13 | Freshness check                | System DMF  | Timeliness   | CREATED_AT freshness                                                 | LOW      |
|14 | Duplicate check                | System DMF  | Uniqueness   | Check duplicate rows                                                 | LOW      |

=============================================================================
TABLE: ACCOUNTS
=============================================================================

| # | RULE NAME                       | RULE TYPE   | DIMENSION    | DESCRIPTION                                                 | PRIORITY |
|---|---------------------------------|-------------|--------------|-------------------------------------------------------------|----------|
| 1 | ACCOUNT_ID not null             | System DMF  | Completeness | ACCOUNT_ID must not be null                                 | HIGH     |
| 2 | ACCOUNT_ID uniqueness           | System DMF  | Uniqueness   | ACCOUNT_ID must be unique                                   | HIGH     |
| 3 | CUSTOMER_ID not null            | System DMF  | Completeness | CUSTOMER_ID must not be null                                | HIGH     |
| 4 | CUSTOMER_ID ref integrity       | Custom DMF  | Integrity    | CUSTOMER_ID must exist in CUSTOMERS                         | HIGH     |
| 5 | BRANCH_ID ref integrity         | Custom DMF  | Integrity    | BRANCH_ID must exist in BRANCHES                            | HIGH     |
| 6 | BALANCE non-negative (savings)  | Custom DMF  | Validity     | Savings accounts should not have negative balance           | HIGH     |
| 7 | ACCOUNT_TYPE accepted values    | Custom DMF  | Validity     | Must be SAVINGS/CURRENT/LOAN                                | MEDIUM   |
| 8 | ACCOUNT_STATUS accepted values  | Custom DMF  | Validity     | Must be ACTIVE/CLOSED/DORMANT                               | MEDIUM   |
| 9 | CURRENCY accepted values        | Custom DMF  | Consistency  | Must be INR or monitored set                                | MEDIUM   |
|10 | OPEN_DATE not future            | Custom DMF  | Validity     | OPEN_DATE must not be in the future                         | MEDIUM   |
|11 | Row count check                 | System DMF  | Completeness | Monitor row count trends                                    | MEDIUM   |
|12 | Duplicate check                 | System DMF  | Uniqueness   | Check duplicate rows                                        | LOW      |
|13 | Freshness check                 | System DMF  | Timeliness   | CREATED_AT freshness                                        | LOW      |

=============================================================================
TABLE: TRANSACTIONS
=============================================================================

| # | RULE NAME                        | RULE TYPE   | DIMENSION    | DESCRIPTION                                                        | PRIORITY |
|---|----------------------------------|-------------|--------------|--------------------------------------------------------------------|----------|
| 1 | TRANSACTION_ID not null          | System DMF  | Completeness | TRANSACTION_ID must not be null                                    | HIGH     |
| 2 | TRANSACTION_ID uniqueness        | System DMF  | Uniqueness   | TRANSACTION_ID must be unique                                      | HIGH     |
| 3 | ACCOUNT_ID not null              | System DMF  | Completeness | ACCOUNT_ID must not be null                                        | HIGH     |
| 4 | ACCOUNT_ID ref integrity         | Custom DMF  | Integrity    | ACCOUNT_ID must exist in ACCOUNTS                                  | HIGH     |
| 5 | AMOUNT positive                  | Custom DMF  | Validity     | Transaction AMOUNT must be > 0                                     | HIGH     |
| 6 | TXN_STATUS accepted values       | Custom DMF  | Consistency  | Must be SUCCESS/FAILED/PENDING ('DONE' is suspicious)              | HIGH     |
| 7 | TRANSACTION_TYPE accepted values | Custom DMF  | Validity     | Must be CREDIT/DEBIT/PAYMENT                                       | MEDIUM   |
| 8 | CHANNEL accepted values          | Custom DMF  | Validity     | Must be UPI/CARD/NEFT/IMPS/ATM/CHEQUE                              | MEDIUM   |
| 9 | TRANSACTION_DATE not future      | Custom DMF  | Validity     | Must not be in the future                                          | MEDIUM   |
|10 | Row count check                  | System DMF  | Completeness | Monitor row count trends (high-volume table)                       | HIGH     |
|11 | Duplicate check                  | System DMF  | Uniqueness   | Check duplicate rows                                               | MEDIUM   |
|12 | Freshness check                  | System DMF  | Timeliness   | CREATED_AT freshness                                               | MEDIUM   |

=============================================================================
TABLE: LOAN_APPLICATIONS
=============================================================================

| # | RULE NAME                            | RULE TYPE   | DIMENSION    | DESCRIPTION                                                        | PRIORITY |
|---|--------------------------------------|-------------|--------------|--------------------------------------------------------------------|----------|
| 1 | APPLICATION_ID not null              | System DMF  | Completeness | APPLICATION_ID must not be null                                    | HIGH     |
| 2 | APPLICATION_ID uniqueness            | System DMF  | Uniqueness   | APPLICATION_ID must be unique                                      | HIGH     |
| 3 | CUSTOMER_ID not null                 | System DMF  | Completeness | CUSTOMER_ID must not be null                                       | HIGH     |
| 4 | CUSTOMER_ID ref integrity            | Custom DMF  | Integrity    | CUSTOMER_ID must exist in CUSTOMERS                                | HIGH     |
| 5 | BRANCH_ID ref integrity              | Custom DMF  | Integrity    | BRANCH_ID must exist in BRANCHES                                   | HIGH     |
| 6 | REQUESTED_AMOUNT positive            | Custom DMF  | Validity     | REQUESTED_AMOUNT must be > 0                                       | HIGH     |
| 7 | CREDIT_SCORE range                   | Custom DMF  | Validity     | CREDIT_SCORE must be between 300 and 900                           | HIGH     |
| 8 | APPROVED <= REQUESTED                | Custom DMF  | Accuracy     | APPROVED_AMOUNT must not exceed REQUESTED_AMOUNT                   | HIGH     |
| 9 | APPLICATION_STATUS accepted values   | Custom DMF  | Validity     | Must be APPROVED/PENDING/REJECTED                                  | MEDIUM   |
|10 | LOAN_TYPE accepted values            | Custom DMF  | Validity     | Must be HOME/PERSONAL/CAR/EDUCATION/BUSINESS                       | MEDIUM   |
|11 | APPROVED null for non-approved       | Custom DMF  | Consistency  | If PENDING/REJECTED, APPROVED_AMOUNT should be null                | MEDIUM   |
|12 | Row count check                      | System DMF  | Completeness | Monitor row count trends                                           | MEDIUM   |
|13 | Duplicate check                      | System DMF  | Uniqueness   | Check duplicate rows                                               | LOW      |
|14 | Freshness check                      | System DMF  | Timeliness   | CREATED_AT freshness                                               | LOW      |

*/

-- =============================================================================
-- B. CUSTOM DMF DEFINITIONS (TO BE CREATED IN STEP 3)
-- =============================================================================
-- The following custom DMFs are needed to implement the rules above.
-- They will be created as reusable functions in BANKING_DQ_DB.RAW schema.

/*
=============================================================================
CUSTOM DMF CATALOG
=============================================================================

| # | DMF NAME                                  | APPLIES TO                              | LOGIC SUMMARY                                                     |
|---|-------------------------------------------|-----------------------------------------|-------------------------------------------------------------------|
| 1 | DQ_ACCEPTED_VALUES_KYC_STATUS             | CUSTOMERS.KYC_STATUS                    | Count rows where KYC_STATUS NOT IN ('VERIFIED','PENDING','REJECTED') |
| 2 | DQ_ACCEPTED_VALUES_RISK_CATEGORY          | CUSTOMERS.RISK_CATEGORY                 | Count rows where RISK_CATEGORY NOT IN ('LOW','MEDIUM','HIGH')     |
| 3 | DQ_VALID_EMAIL_FORMAT                     | CUSTOMERS.EMAIL                         | Count rows where EMAIL not matching email regex                   |
| 4 | DQ_DOB_AGE_RANGE                          | CUSTOMERS.DATE_OF_BIRTH                 | Count rows where age < 18 or age > 100                            |
| 5 | DQ_REFERENTIAL_INTEGRITY_BRANCH           | CUSTOMERS/ACCOUNTS/LOANS.BRANCH_ID      | Count orphan BRANCH_IDs not in BRANCHES                           |
| 6 | DQ_REFERENTIAL_INTEGRITY_CUSTOMER         | ACCOUNTS/LOANS.CUSTOMER_ID              | Count orphan CUSTOMER_IDs not in CUSTOMERS                        |
| 7 | DQ_REFERENTIAL_INTEGRITY_ACCOUNT          | TRANSACTIONS.ACCOUNT_ID                 | Count orphan ACCOUNT_IDs not in ACCOUNTS                          |
| 8 | DQ_POSITIVE_AMOUNT                        | TRANSACTIONS.AMOUNT                     | Count rows where AMOUNT <= 0                                      |
| 9 | DQ_POSITIVE_REQUESTED_AMOUNT              | LOAN_APPLICATIONS.REQUESTED_AMOUNT      | Count rows where REQUESTED_AMOUNT <= 0                            |
|10 | DQ_NONNEG_BALANCE_SAVINGS                 | ACCOUNTS.BALANCE                        | Count SAVINGS accounts where BALANCE < 0                          |
|11 | DQ_ACCEPTED_VALUES_ACCT_TYPE              | ACCOUNTS.ACCOUNT_TYPE                   | Count rows where ACCOUNT_TYPE not in accepted set                 |
|12 | DQ_ACCEPTED_VALUES_ACCT_STATUS            | ACCOUNTS.ACCOUNT_STATUS                 | Count rows where ACCOUNT_STATUS not in accepted set               |
|13 | DQ_ACCEPTED_VALUES_CURRENCY               | ACCOUNTS.CURRENCY                       | Count rows where CURRENCY not in accepted set                     |
|14 | DQ_FUTURE_DATE_CHECK                      | ACCOUNTS.OPEN_DATE / TRANSACTIONS.DATE  | Count rows where date is in the future                            |
|15 | DQ_ACCEPTED_VALUES_TXN_STATUS             | TRANSACTIONS.TRANSACTION_STATUS         | Count rows where status NOT IN ('SUCCESS','FAILED','PENDING')     |
|16 | DQ_ACCEPTED_VALUES_TXN_TYPE               | TRANSACTIONS.TRANSACTION_TYPE           | Count rows where type NOT IN ('CREDIT','DEBIT','PAYMENT')         |
|17 | DQ_ACCEPTED_VALUES_CHANNEL                | TRANSACTIONS.CHANNEL                    | Count rows where CHANNEL not in accepted set                      |
|18 | DQ_CREDIT_SCORE_RANGE                     | LOAN_APPLICATIONS.CREDIT_SCORE          | Count rows where CREDIT_SCORE < 300 or > 900                     |
|19 | DQ_APPROVED_LTE_REQUESTED                 | LOAN_APPLICATIONS                       | Count rows where APPROVED_AMOUNT > REQUESTED_AMOUNT               |
|20 | DQ_ACCEPTED_VALUES_APP_STATUS             | LOAN_APPLICATIONS.APPLICATION_STATUS    | Count rows where status NOT IN ('APPROVED','PENDING','REJECTED')  |
|21 | DQ_ACCEPTED_VALUES_LOAN_TYPE              | LOAN_APPLICATIONS.LOAN_TYPE             | Count rows where type not in accepted set                         |
|22 | DQ_APPROVED_NULL_FOR_NON_APPROVED         | LOAN_APPLICATIONS                       | Count rows PENDING/REJECTED with non-null APPROVED_AMOUNT         |
|23 | DQ_ACCEPTED_VALUES_IS_ACTIVE              | BRANCHES.IS_ACTIVE                      | Count rows where IS_ACTIVE NOT IN ('true','false')                |

*/

-- =============================================================================
-- C. RULE PRIORITY SUMMARY
-- =============================================================================
/*
  HIGH (26 rules)   — Business-critical: PKs, FKs, amount validity, status consistency
  MEDIUM (21 rules) — Important: accepted values, date ranges, row counts
  LOW (14 rules)    — Monitoring: freshness, duplicates at table level

  DIMENSIONS BREAKDOWN:
    Completeness  : 15 rules (all NULL_COUNT + ROW_COUNT)
    Uniqueness    : 14 rules (DUPLICATE_COUNT + UNIQUE_COUNT)
    Validity      : 15 rules (range, format, accepted values)
    Integrity     :  6 rules (referential integrity / orphans)
    Consistency   :  5 rules (status/category accepted values)
    Accuracy      :  2 rules (business logic: approved <= requested)
    Timeliness    :  5 rules (freshness checks)
*/
