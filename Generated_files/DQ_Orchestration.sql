/*******************************************************************************
 *  DQ_Orchestration.sql
 *  Data Quality Framework – Step 5: Orchestration Stored Procedure
 *  Database : BANKING_DQ_DB
 *  Schema   : DQ_MONITORING
 *
 *  Procedure: RUN_DQ_FRAMEWORK(P_TRIGGERED_BY VARCHAR)
 *  - Iterates through all active rules in DQ_RULE_CONFIG
 *  - Executes each rule SQL dynamically via RESULTSET
 *  - Logs results into DQ_RUN_CONTROL and DQ_RULE_RESULTS
 *  - Captures error samples into DQ_ERROR_RECORDS
 *  - Returns execution summary string
 ******************************************************************************/

USE DATABASE BANKING_DQ_DB;
USE SCHEMA DQ_MONITORING;

-- =============================================================================
-- ORCHESTRATION STORED PROCEDURE
-- =============================================================================
CREATE OR REPLACE PROCEDURE RUN_DQ_FRAMEWORK(P_TRIGGERED_BY VARCHAR DEFAULT 'MANUAL')
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_rule_id NUMBER;
    v_rule_name VARCHAR;
    v_rule_type VARCHAR;
    v_criticality VARCHAR;
    v_db_name VARCHAR;
    v_table_nm VARCHAR;
    v_column_nm VARCHAR;
    v_rule_sql VARCHAR;
    v_threshold NUMBER;
    v_rule_description VARCHAR;
    v_run_id NUMBER;
    v_output_value NUMBER;
    v_total_rows NUMBER;
    v_pass_pct FLOAT;
    v_result_status VARCHAR;
    v_exec_result VARCHAR;
    v_error_msg VARCHAR;
    v_run_start TIMESTAMP_NTZ;
    v_run_end TIMESTAMP_NTZ;
    v_rules_passed NUMBER DEFAULT 0;
    v_rules_failed NUMBER DEFAULT 0;
    v_rules_error NUMBER DEFAULT 0;
    v_total_rules NUMBER DEFAULT 0;
    v_row_count_sql VARCHAR;
    v_error_sample_query VARCHAR;
    v_wrapper_sql VARCHAR;
    
    -- Cursor for active rules
    rs RESULTSET;
    c1 CURSOR FOR 
        SELECT RULE_ID, RULE_NAME, RULE_TYPE, CRITICALITY, DB_NAME, TABLE_NM, 
               COLUMN_NM, RULE_SQL, THRESHOLD_VALUE, RULE_DESCRIPTION
        FROM BANKING_DQ_DB.DQ_MONITORING.DQ_RULE_CONFIG 
        WHERE IS_ACTIVE = TRUE
        ORDER BY RULE_ID;
BEGIN
    FOR rule_rec IN c1 DO
        v_rule_id := rule_rec.RULE_ID;
        v_rule_name := rule_rec.RULE_NAME;
        v_rule_type := rule_rec.RULE_TYPE;
        v_criticality := rule_rec.CRITICALITY;
        v_db_name := rule_rec.DB_NAME;
        v_table_nm := rule_rec.TABLE_NM;
        v_column_nm := rule_rec.COLUMN_NM;
        v_rule_sql := rule_rec.RULE_SQL;
        v_threshold := rule_rec.THRESHOLD_VALUE;
        v_rule_description := rule_rec.RULE_DESCRIPTION;
        v_total_rules := v_total_rules + 1;
        v_run_start := CURRENT_TIMESTAMP();
        v_error_msg := NULL;
        v_output_value := NULL;
        v_exec_result := NULL;
        v_result_status := NULL;

        BEGIN
            -- Execute the CALL statement, then read result via $1 positional reference
            EXECUTE IMMEDIATE :v_rule_sql;
            rs := (SELECT $1 AS VAL FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())));
            LET c2 CURSOR FOR rs;
            FOR val_rec IN c2 DO
                v_output_value := val_rec.VAL;
            END FOR;

            v_run_end := CURRENT_TIMESTAMP();

            -- Determine pass/fail based on rule type
            IF (v_rule_type = 'ROW_COUNT') THEN
                -- ROW_COUNT: output is the actual count (informational), always PASS
                v_exec_result := 'PASS';
                v_result_status := 'PASS';
                v_rules_passed := v_rules_passed + 1;
            ELSEIF (v_rule_type = 'FRESHNESS') THEN
                -- FRESHNESS: output is hours since last update; fail if exceeds threshold
                IF (v_output_value <= v_threshold) THEN
                    v_exec_result := 'PASS';
                    v_result_status := 'PASS';
                    v_rules_passed := v_rules_passed + 1;
                ELSE
                    v_exec_result := 'FAIL';
                    v_result_status := 'FAIL';
                    v_rules_failed := v_rules_failed + 1;
                END IF;
            ELSE
                -- All other rules: output is violation count; 0 = PASS, >threshold = FAIL
                IF (v_output_value <= v_threshold) THEN
                    v_exec_result := 'PASS';
                    v_result_status := 'PASS';
                    v_rules_passed := v_rules_passed + 1;
                ELSE
                    v_exec_result := 'FAIL';
                    v_result_status := 'FAIL';
                    v_rules_failed := v_rules_failed + 1;
                END IF;
            END IF;

            -- Get total row count for the table
            v_total_rows := 0;
            IF (v_table_nm IS NOT NULL) THEN
                v_row_count_sql := 'SELECT COUNT(*) AS CNT FROM ' || v_db_name || '.' || v_table_nm;
                rs := (EXECUTE IMMEDIATE :v_row_count_sql);
                LET c3 CURSOR FOR rs;
                FOR cnt_rec IN c3 DO
                    v_total_rows := cnt_rec.CNT;
                END FOR;
            END IF;

            -- Calculate pass percentage
            IF (v_rule_type IN ('ROW_COUNT', 'FRESHNESS')) THEN
                v_pass_pct := 100.0;
                IF (v_result_status = 'FAIL') THEN
                    v_pass_pct := 0.0;
                END IF;
            ELSEIF (v_total_rows > 0) THEN
                v_pass_pct := ROUND(((v_total_rows - v_output_value) / v_total_rows) * 100, 2);
            ELSE
                v_pass_pct := 100.0;
            END IF;

            -- Insert into DQ_RUN_CONTROL
            INSERT INTO BANKING_DQ_DB.DQ_MONITORING.DQ_RUN_CONTROL 
                (RULE_ID, RUN_START_TIME, RUN_END_TIME, RULE_EXEC_RESULT, RULE_OUTPUT_VALUE, RUN_STATUS, TRIGGERED_BY, ERROR_MESSAGE)
            VALUES 
                (:v_rule_id, :v_run_start, :v_run_end, :v_exec_result, :v_output_value, 'COMPLETED', :P_TRIGGERED_BY, NULL);

            -- Get the RUN_ID just inserted
            SELECT MAX(RUN_ID) INTO :v_run_id FROM BANKING_DQ_DB.DQ_MONITORING.DQ_RUN_CONTROL WHERE RULE_ID = :v_rule_id;

            -- Build error sample query for failed rules
            v_error_sample_query := NULL;
            IF (v_result_status = 'FAIL' AND v_rule_type NOT IN ('ROW_COUNT','FRESHNESS')) THEN
                IF (v_rule_type = 'NULL_CHECK') THEN
                    v_error_sample_query := 'SELECT * FROM ' || v_db_name || '.' || v_table_nm || ' WHERE ' || v_column_nm || ' IS NULL LIMIT 10';
                ELSEIF (v_rule_type = 'POSITIVE_CHECK') THEN
                    v_error_sample_query := 'SELECT * FROM ' || v_db_name || '.' || v_table_nm || ' WHERE ' || v_column_nm || ' <= 0 LIMIT 10';
                ELSEIF (v_rule_type = 'DUPLICATE_CHECK') THEN
                    v_error_sample_query := 'SELECT ' || v_column_nm || ', COUNT(*) FROM ' || v_db_name || '.' || v_table_nm || ' GROUP BY ' || v_column_nm || ' HAVING COUNT(*) > 1 LIMIT 10';
                ELSE
                    v_error_sample_query := 'Review rule: ' || v_rule_name || ' - ' || v_rule_description;
                END IF;
            END IF;

            -- Insert into DQ_RULE_RESULTS
            INSERT INTO BANKING_DQ_DB.DQ_MONITORING.DQ_RULE_RESULTS 
                (RUN_ID, RULE_ID, DB_NAME, TABLE_NAME, COLUMN_NAME, RULE_NAME, RULE_TYPE,
                 EXPECTED_VALUE, ACTUAL_VALUE, FAILED_RECORD_COUNT, TOTAL_RECORD_COUNT,
                 PASS_PERCENTAGE, RESULT_STATUS, SEVERITY, ERROR_SAMPLE_QUERY)
            VALUES 
                (:v_run_id, :v_rule_id, :v_db_name, :v_table_nm, :v_column_nm, :v_rule_name, :v_rule_type,
                 :v_threshold, :v_output_value,
                 CASE WHEN :v_rule_type IN ('ROW_COUNT','FRESHNESS') THEN 0 ELSE :v_output_value END,
                 :v_total_rows, :v_pass_pct, :v_result_status, :v_criticality, :v_error_sample_query);

            -- Insert error records for failed rules (sample)
            IF (v_result_status = 'FAIL' AND v_rule_type NOT IN ('ROW_COUNT','FRESHNESS') AND v_error_sample_query IS NOT NULL AND v_error_sample_query NOT LIKE 'Review%') THEN
                BEGIN
                    INSERT INTO BANKING_DQ_DB.DQ_MONITORING.DQ_ERROR_RECORDS 
                        (RUN_ID, RULE_ID, DB_NAME, TABLE_NAME, ERROR_RECORD_VARIANT, ERROR_REASON)
                    SELECT :v_run_id, :v_rule_id, :v_db_name, :v_table_nm, 
                           OBJECT_CONSTRUCT(*), :v_rule_description
                    FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
                EXCEPTION
                    WHEN OTHER THEN
                        NULL; -- Skip error record capture if it fails
                END;
            END IF;

        EXCEPTION
            WHEN OTHER THEN
                v_run_end := CURRENT_TIMESTAMP();
                v_error_msg := SQLERRM;
                v_rules_error := v_rules_error + 1;

                -- Log the error in DQ_RUN_CONTROL
                INSERT INTO BANKING_DQ_DB.DQ_MONITORING.DQ_RUN_CONTROL 
                    (RULE_ID, RUN_START_TIME, RUN_END_TIME, RULE_EXEC_RESULT, RULE_OUTPUT_VALUE, RUN_STATUS, TRIGGERED_BY, ERROR_MESSAGE)
                VALUES 
                    (:v_rule_id, :v_run_start, :v_run_end, 'ERROR', NULL, 'FAILED', :P_TRIGGERED_BY, :v_error_msg);
        END;
    END FOR;

    -- Return summary
    RETURN 'DQ Framework Run Complete. Total: ' || v_total_rules || 
           ' | Passed: ' || v_rules_passed || 
           ' | Failed: ' || v_rules_failed || 
           ' | Errors: ' || v_rules_error;
END;
$$;

-- =============================================================================
-- USAGE
-- =============================================================================
-- Run the DQ framework manually:
-- CALL BANKING_DQ_DB.DQ_MONITORING.RUN_DQ_FRAMEWORK('MANUAL');
--
-- Run via a Snowflake Task (scheduled):
-- CALL BANKING_DQ_DB.DQ_MONITORING.RUN_DQ_FRAMEWORK('SCHEDULED_TASK');

-- =============================================================================
-- OPTIONAL: CREATE A SCHEDULED TASK
-- =============================================================================
-- CREATE OR REPLACE TASK BANKING_DQ_DB.DQ_MONITORING.DQ_SCHEDULED_RUN
--   WAREHOUSE = COMPUTE_WH
--   SCHEDULE = 'USING CRON 0 6 * * * UTC'  -- Daily at 6 AM UTC
-- AS
--   CALL BANKING_DQ_DB.DQ_MONITORING.RUN_DQ_FRAMEWORK('SCHEDULED_TASK');
--
-- ALTER TASK BANKING_DQ_DB.DQ_MONITORING.DQ_SCHEDULED_RUN RESUME;

-- =============================================================================
-- EMAIL NOTIFICATION INTEGRATION
-- =============================================================================
CREATE OR REPLACE NOTIFICATION INTEGRATION DQ_EMAIL_NOTIFICATION
  TYPE = EMAIL
  ENABLED = TRUE
  ALLOWED_RECIPIENTS = ('<email>');  -- Update with your email

-- =============================================================================
-- DQ SUMMARY EMAIL REPORT PROCEDURE
-- =============================================================================
CREATE OR REPLACE PROCEDURE SEND_DQ_REPORT(P_RECIPIENT VARCHAR DEFAULT '<email>')
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_total_rules NUMBER;
    v_passed NUMBER;
    v_failed NUMBER;
    v_critical NUMBER;
    v_health_score FLOAT;
    v_anomaly_count NUMBER;
    v_report_body VARCHAR;
    v_table_summary VARCHAR DEFAULT '';
    v_failed_details VARCHAR DEFAULT '';
    v_subject VARCHAR;
    v_tbl VARCHAR;
    v_tbl_total NUMBER;
    v_tbl_passed NUMBER;
    v_tbl_failed NUMBER;
    v_tbl_health FLOAT;
    v_rule_name VARCHAR;
    v_col_name VARCHAR;
    v_severity VARCHAR;
    v_actual NUMBER;
    v_pass_pct FLOAT;
    v_run_ts VARCHAR;

    c_tables CURSOR FOR
        SELECT TABLE_NAME, 
               COUNT(*) AS TOTAL,
               SUM(CASE WHEN RESULT_STATUS = 'PASS' THEN 1 ELSE 0 END) AS PASSED,
               SUM(CASE WHEN RESULT_STATUS = 'FAIL' THEN 1 ELSE 0 END) AS FAILED
        FROM BANKING_DQ_DB.DQ_MONITORING.DQ_RULE_RESULTS r
        JOIN BANKING_DQ_DB.DQ_MONITORING.DQ_RUN_CONTROL rc ON r.RUN_ID = rc.RUN_ID
        WHERE rc.RUN_ID IN (SELECT MAX(RUN_ID) FROM BANKING_DQ_DB.DQ_MONITORING.DQ_RUN_CONTROL GROUP BY RULE_ID)
        GROUP BY TABLE_NAME ORDER BY TABLE_NAME;

    c_fails CURSOR FOR
        SELECT r.RULE_NAME, r.TABLE_NAME, r.COLUMN_NAME, r.SEVERITY, r.ACTUAL_VALUE, r.PASS_PERCENTAGE
        FROM BANKING_DQ_DB.DQ_MONITORING.DQ_RULE_RESULTS r
        JOIN BANKING_DQ_DB.DQ_MONITORING.DQ_RUN_CONTROL rc ON r.RUN_ID = rc.RUN_ID
        WHERE rc.RUN_ID IN (SELECT MAX(RUN_ID) FROM BANKING_DQ_DB.DQ_MONITORING.DQ_RUN_CONTROL GROUP BY RULE_ID)
          AND r.RESULT_STATUS = 'FAIL'
        ORDER BY CASE r.SEVERITY WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END, r.TABLE_NAME;
BEGIN
    -- Get overall stats from latest run per rule
    SELECT COUNT(*),
           SUM(CASE WHEN RESULT_STATUS = 'PASS' THEN 1 ELSE 0 END),
           SUM(CASE WHEN RESULT_STATUS = 'FAIL' THEN 1 ELSE 0 END),
           SUM(CASE WHEN RESULT_STATUS = 'FAIL' AND SEVERITY = 'HIGH' THEN 1 ELSE 0 END)
    INTO :v_total_rules, :v_passed, :v_failed, :v_critical
    FROM BANKING_DQ_DB.DQ_MONITORING.DQ_RULE_RESULTS r
    JOIN BANKING_DQ_DB.DQ_MONITORING.DQ_RUN_CONTROL rc ON r.RUN_ID = rc.RUN_ID
    WHERE rc.RUN_ID IN (SELECT MAX(RUN_ID) FROM BANKING_DQ_DB.DQ_MONITORING.DQ_RUN_CONTROL GROUP BY RULE_ID);

    v_health_score := ROUND(v_passed / v_total_rules * 100, 1);

    SELECT COUNT(*) INTO :v_anomaly_count
    FROM BANKING_DQ_DB.DQ_MONITORING.DQ_ANOMALY_RESULTS
    WHERE ANOMALY_STATUS = 'ANOMALY';

    v_run_ts := TO_CHAR(CURRENT_TIMESTAMP(), 'YYYY-MM-DD HH24:MI:SS');

    -- Build table summary
    v_table_summary := '
TABLE HEALTH SUMMARY
----------------------------------------------
';
    FOR t IN c_tables DO
        v_tbl_health := ROUND(t.PASSED / t.TOTAL * 100, 1);
        v_table_summary := v_table_summary || '  ' || t.TABLE_NAME || ': ' || v_tbl_health || '% (' || t.PASSED || '/' || t.TOTAL || ' passed, ' || t.FAILED || ' failed)
';
    END FOR;

    -- Build failed rules detail
    v_failed_details := '
FAILED RULES DETAIL
----------------------------------------------
';
    FOR f IN c_fails DO
        v_failed_details := v_failed_details || '  [' || f.SEVERITY || '] ' || f.RULE_NAME || ' | ' || f.TABLE_NAME || '.' || COALESCE(f.COLUMN_NAME, '-') || ' | Violations: ' || f.ACTUAL_VALUE || ' | Pass: ' || f.PASS_PERCENTAGE || '%
';
    END FOR;

    IF (v_failed = 0) THEN
        v_failed_details := '
  No failures detected. All rules passed!
';
    END IF;

    -- Compose full report
    v_subject := 'DQ Report: BANKING_DQ_DB | Health: ' || v_health_score || '% | ' || v_run_ts;

    v_report_body := '
==============================================
  DATA QUALITY SUMMARY REPORT
  BANKING_DQ_DB | ' || v_run_ts || '
==============================================

OVERALL METRICS
----------------------------------------------
  Health Score:       ' || v_health_score || '%
  Total Rules:        ' || v_total_rules || '
  Passed:             ' || v_passed || '
  Failed:             ' || v_failed || '
  Critical (HIGH):    ' || v_critical || '
  Active Anomalies:   ' || v_anomaly_count || '
' || v_table_summary || v_failed_details || '
----------------------------------------------
  Report generated by BANKING_DQ_DB.DQ_MONITORING
  DQ Monitoring Board available in Snowsight
==============================================
';

    -- Send email
    CALL SYSTEM$SEND_EMAIL(
        'DQ_EMAIL_NOTIFICATION',
        :P_RECIPIENT,
        :v_subject,
        :v_report_body
    );

    RETURN 'DQ Report sent to ' || P_RECIPIENT || ' | Health: ' || v_health_score || '% | Failed: ' || v_failed;
END;
$$;

-- =============================================================================
-- USAGE: Run DQ framework + send report
-- =============================================================================
-- CALL BANKING_DQ_DB.DQ_MONITORING.RUN_DQ_FRAMEWORK('MANUAL');
-- CALL BANKING_DQ_DB.DQ_MONITORING.SEND_DQ_REPORT('<email>');
--
-- OPTIONAL: Scheduled task that runs DQ + sends report daily
-- CREATE OR REPLACE TASK BANKING_DQ_DB.DQ_MONITORING.DQ_DAILY_RUN_AND_REPORT
--   WAREHOUSE = COMPUTE_WH
--   SCHEDULE = 'USING CRON 0 7 * * * UTC'
-- AS
--   BEGIN
--     CALL BANKING_DQ_DB.DQ_MONITORING.RUN_DQ_FRAMEWORK('SCHEDULED_TASK');
--     CALL BANKING_DQ_DB.DQ_MONITORING.SEND_DQ_REPORT('<email>');
--   END;
--
-- ALTER TASK BANKING_DQ_DB.DQ_MONITORING.DQ_DAILY_RUN_AND_REPORT RESUME;
