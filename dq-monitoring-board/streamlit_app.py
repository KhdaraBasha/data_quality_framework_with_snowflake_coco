import os
import streamlit as st

st.set_page_config(page_title="DQ Monitoring Board", page_icon=":shield:", layout="wide")

conn = st.connection("snowflake", ttl=os.getenv("SNOWFLAKE_CONNECTION_TTL"))

# ---------- cached data loaders ----------
@st.cache_data(ttl=120)
def load_rule_config():
    return conn.query("SELECT * FROM BANKING_DQ_DB.DQ_MONITORING.DQ_RULE_CONFIG ORDER BY RULE_ID")

@st.cache_data(ttl=120)
def load_rule_results():
    return conn.query("""
        SELECT r.*, rc.TRIGGERED_BY
        FROM BANKING_DQ_DB.DQ_MONITORING.DQ_RULE_RESULTS r
        JOIN BANKING_DQ_DB.DQ_MONITORING.DQ_RUN_CONTROL rc ON r.RUN_ID = rc.RUN_ID
        ORDER BY r.EXECUTED_AT DESC
    """)

@st.cache_data(ttl=120)
def load_anomalies():
    return conn.query("SELECT * FROM BANKING_DQ_DB.DQ_MONITORING.DQ_ANOMALY_RESULTS ORDER BY DETECTED_AT DESC")

@st.cache_data(ttl=120)
def load_error_records():
    return conn.query("SELECT * FROM BANKING_DQ_DB.DQ_MONITORING.DQ_ERROR_RECORDS ORDER BY CREATED_AT DESC")

@st.cache_data(ttl=120)
def load_run_control():
    return conn.query("SELECT * FROM BANKING_DQ_DB.DQ_MONITORING.DQ_RUN_CONTROL ORDER BY RUN_ID DESC")

# ---------- load data ----------
df_config = load_rule_config()
df_results = load_rule_results()
df_anomalies = load_anomalies()
df_errors = load_error_records()
df_runs = load_run_control()

# ---------- header ----------
st.title(":shield: Data Quality Monitoring Board")
st.caption("BANKING_DQ_DB | Enterprise DQ Framework")

# refresh button
if st.button("Refresh Data", type="secondary"):
    load_rule_config.clear()
    load_rule_results.clear()
    load_anomalies.clear()
    load_error_records.clear()
    load_run_control.clear()
    st.rerun()

# ---------- sidebar filters ----------
with st.sidebar:
    st.header("Filters")
    tables = sorted(df_results["TABLE_NAME"].dropna().unique().tolist()) if len(df_results) > 0 else []
    sel_tables = st.multiselect("Table", tables, default=tables)
    rule_types = sorted(df_results["RULE_TYPE"].dropna().unique().tolist()) if len(df_results) > 0 else []
    sel_rule_types = st.multiselect("Rule Type", rule_types, default=rule_types)
    severities = ["HIGH", "MEDIUM", "LOW"]
    sel_severities = st.multiselect("Severity", severities, default=severities)
    triggered_by_opts = sorted(df_results["TRIGGERED_BY"].dropna().unique().tolist()) if len(df_results) > 0 and "TRIGGERED_BY" in df_results.columns else []
    sel_triggered = st.multiselect("Run Trigger", triggered_by_opts, default=triggered_by_opts)

# apply filters
mask = (
    df_results["TABLE_NAME"].isin(sel_tables)
    & df_results["RULE_TYPE"].isin(sel_rule_types)
    & df_results["SEVERITY"].isin(sel_severities)
)
if "TRIGGERED_BY" in df_results.columns and sel_triggered:
    mask = mask & df_results["TRIGGERED_BY"].isin(sel_triggered)
filtered = df_results[mask].copy()

# get latest result per rule
latest = filtered.sort_values("EXECUTED_AT", ascending=False).drop_duplicates(subset=["RULE_ID"], keep="first")

# ---------- tabs ----------
tab_overview, tab_results, tab_anomalies, tab_coverage = st.tabs(
    [":bar_chart: Overview", ":clipboard: Rule Results", ":warning: Anomalies", ":mag: Coverage"]
)

# ========================== TAB 1: OVERVIEW ==========================
with tab_overview:
    total_tables = latest["TABLE_NAME"].nunique()
    total_rules = len(latest)
    passed = int((latest["RESULT_STATUS"] == "PASS").sum())
    failed = int((latest["RESULT_STATUS"] == "FAIL").sum())
    critical = int(((latest["RESULT_STATUS"] == "FAIL") & (latest["SEVERITY"] == "HIGH")).sum())
    active_anomalies = len(df_anomalies[df_anomalies["ANOMALY_STATUS"] == "ANOMALY"]) if len(df_anomalies) > 0 else 0
    health_score = round(passed / total_rules * 100, 1) if total_rules > 0 else 0

    # KPI row
    with st.container(horizontal=True):
        st.metric("Health Score", f"{health_score}%", border=True)
        st.metric("Monitored Tables", total_tables, border=True)
        st.metric("Active Rules", total_rules, border=True)
        st.metric("Passed", passed, border=True)
        st.metric("Failed", failed, border=True)
        st.metric("Critical Failures", critical, border=True)
        st.metric("Active Anomalies", active_anomalies, border=True)

    st.divider()

    # charts row 1
    col1, col2 = st.columns(2)

    with col1:
        with st.container(border=True):
            st.subheader("Table-wise Health Score")
            if len(latest) > 0:
                health_by_table = latest.groupby("TABLE_NAME").apply(
                    lambda g: round((g["RESULT_STATUS"] == "PASS").sum() / len(g) * 100, 1)
                ).reset_index(name="HEALTH_SCORE").sort_values("HEALTH_SCORE")
                st.bar_chart(health_by_table, x="TABLE_NAME", y="HEALTH_SCORE", horizontal=True, color="#29B5E8")

    with col2:
        with st.container(border=True):
            st.subheader("Rule Pass / Fail Distribution")
            if len(latest) > 0:
                pf = latest["RESULT_STATUS"].value_counts().reset_index()
                pf.columns = ["Status", "Count"]
                st.bar_chart(pf, x="Status", y="Count", color="Status")

    # charts row 2
    col3, col4 = st.columns(2)

    with col3:
        with st.container(border=True):
            st.subheader("Failures by Severity")
            if len(latest) > 0:
                fails = latest[latest["RESULT_STATUS"] == "FAIL"]
                if len(fails) > 0:
                    sev = fails["SEVERITY"].value_counts().reset_index()
                    sev.columns = ["Severity", "Count"]
                    st.bar_chart(sev, x="Severity", y="Count", color="Severity")
                else:
                    st.success("No failures!")

    with col4:
        with st.container(border=True):
            st.subheader("Failures by Rule Type")
            if len(latest) > 0:
                fails = latest[latest["RESULT_STATUS"] == "FAIL"]
                if len(fails) > 0:
                    rt = fails["RULE_TYPE"].value_counts().reset_index()
                    rt.columns = ["Rule Type", "Count"]
                    st.bar_chart(rt, x="Rule Type", y="Count", color="#FF4B4B")
                else:
                    st.success("No failures!")

    # charts row 3
    col5, col6 = st.columns(2)

    with col5:
        with st.container(border=True):
            st.subheader("Top Failing Tables")
            if len(latest) > 0:
                fails = latest[latest["RESULT_STATUS"] == "FAIL"]
                if len(fails) > 0:
                    ft = fails["TABLE_NAME"].value_counts().reset_index()
                    ft.columns = ["Table", "Failed Rules"]
                    st.bar_chart(ft, x="Table", y="Failed Rules", color="#FF4B4B", horizontal=True)

    with col6:
        with st.container(border=True):
            st.subheader("Top Failing Columns")
            if len(latest) > 0:
                fails = latest[(latest["RESULT_STATUS"] == "FAIL") & (latest["COLUMN_NAME"].notna())]
                if len(fails) > 0:
                    fc = fails.groupby(["TABLE_NAME", "COLUMN_NAME"]).size().reset_index(name="Failures")
                    fc["Label"] = fc["TABLE_NAME"] + "." + fc["COLUMN_NAME"]
                    fc = fc.sort_values("Failures", ascending=False).head(10)
                    st.bar_chart(fc, x="Label", y="Failures", color="#FF4B4B", horizontal=True)

# ========================== TAB 2: RULE RESULTS ==========================
with tab_results:
    st.subheader("Rule Execution Results")

    if len(filtered) > 0:
        display_cols = [
            "RULE_NAME", "TABLE_NAME", "COLUMN_NAME", "RULE_TYPE", "SEVERITY",
            "EXPECTED_VALUE", "ACTUAL_VALUE", "PASS_PERCENTAGE", "RESULT_STATUS",
            "TRIGGERED_BY", "EXECUTED_AT"
        ]
        display_cols = [c for c in display_cols if c in filtered.columns]
        st.dataframe(
            filtered[display_cols].sort_values(["EXECUTED_AT"], ascending=False),
            use_container_width=True,
            hide_index=True,
            column_config={
                "PASS_PERCENTAGE": st.column_config.ProgressColumn("Pass %", min_value=0, max_value=100, format="%.1f%%"),
                "RESULT_STATUS": st.column_config.TextColumn("Status"),
            },
        )
    else:
        st.info("No results match the current filters.")

    # drill-down
    st.divider()
    st.subheader("Table Drill-Down")
    if len(latest) > 0:
        drill_table = st.selectbox("Select a table to drill down", ["-- Select --"] + tables)
        if drill_table != "-- Select --":
            tbl_results = latest[latest["TABLE_NAME"] == drill_table]

            # table health
            tbl_passed = int((tbl_results["RESULT_STATUS"] == "PASS").sum())
            tbl_failed = int((tbl_results["RESULT_STATUS"] == "FAIL").sum())
            tbl_total = len(tbl_results)
            tbl_health = round(tbl_passed / tbl_total * 100, 1) if tbl_total > 0 else 0

            with st.container(horizontal=True):
                st.metric("Table Health", f"{tbl_health}%", border=True)
                st.metric("Rules", tbl_total, border=True)
                st.metric("Passed", tbl_passed, border=True)
                st.metric("Failed", tbl_failed, border=True)

            # failed rules for this table
            tbl_fails = tbl_results[tbl_results["RESULT_STATUS"] == "FAIL"]
            if len(tbl_fails) > 0:
                st.markdown("**Failed Rules**")
                st.dataframe(
                    tbl_fails[["RULE_NAME", "COLUMN_NAME", "RULE_TYPE", "SEVERITY", "ACTUAL_VALUE", "PASS_PERCENTAGE"]],
                    use_container_width=True, hide_index=True,
                )

                # failed columns
                fail_cols = tbl_fails["COLUMN_NAME"].dropna().unique().tolist()
                if fail_cols:
                    st.markdown("**Failing Columns:** " + ", ".join(f"`{c}`" for c in fail_cols))

            # recent anomalies
            tbl_anomalies = df_anomalies[df_anomalies["TABLE_NAME"] == drill_table] if len(df_anomalies) > 0 else None
            if tbl_anomalies is not None and len(tbl_anomalies) > 0:
                st.markdown("**Recent Anomalies**")
                st.dataframe(
                    tbl_anomalies[["METRIC_NAME", "CURRENT_VALUE", "BASELINE_AVG", "ANOMALY_STATUS", "ANOMALY_REASON", "DETECTED_AT"]],
                    use_container_width=True, hide_index=True,
                )

            # sample error records
            tbl_errors = df_errors[df_errors["TABLE_NAME"] == drill_table] if len(df_errors) > 0 else None
            if tbl_errors is not None and len(tbl_errors) > 0:
                st.markdown("**Sample Error Records**")
                st.dataframe(
                    tbl_errors[["ERROR_REASON", "ERROR_RECORD_VARIANT", "CREATED_AT"]],
                    use_container_width=True, hide_index=True,
                )

            # recommended fixes
            if len(tbl_fails) > 0:
                st.markdown("**Recommended Fixes**")
                for _, row in tbl_fails.iterrows():
                    rn = row["RULE_NAME"]
                    rt = row["RULE_TYPE"]
                    col = row.get("COLUMN_NAME", "")
                    if rt == "NULL_CHECK":
                        st.markdown(f"- **{rn}**: Populate missing `{col}` values or add a DEFAULT constraint.")
                    elif rt == "REFERENTIAL_INTEGRITY":
                        st.markdown(f"- **{rn}**: Insert missing parent record or correct `{col}` FK value.")
                    elif rt == "ACCEPTED_VALUES":
                        st.markdown(f"- **{rn}**: Standardize `{col}` to the accepted value set.")
                    elif rt == "POSITIVE_CHECK":
                        st.markdown(f"- **{rn}**: Fix non-positive `{col}` values (must be > 0).")
                    elif rt == "BUSINESS_RULE":
                        st.markdown(f"- **{rn}**: Review business logic violation and correct source data.")
                    elif rt == "RANGE_CHECK":
                        st.markdown(f"- **{rn}**: Fix `{col}` values outside the valid range.")
                    elif rt == "FORMAT_CHECK":
                        st.markdown(f"- **{rn}**: Fix invalid format in `{col}` (e.g., email pattern).")
                    elif rt == "FRESHNESS":
                        st.markdown(f"- **{rn}**: Data is stale. Trigger a data refresh/load pipeline.")
                    else:
                        st.markdown(f"- **{rn}**: Review and remediate `{col}`.")

# ========================== TAB 3: ANOMALIES ==========================
with tab_anomalies:
    st.subheader("Anomaly Detection Results")

    if len(df_anomalies) > 0:
        anom_filtered = df_anomalies[df_anomalies["TABLE_NAME"].isin(sel_tables)] if sel_tables else df_anomalies

        # summary
        anom_count = len(anom_filtered[anom_filtered["ANOMALY_STATUS"] == "ANOMALY"])
        with st.container(horizontal=True):
            st.metric("Total Anomalies", anom_count, border=True)
            st.metric("Tables Affected", anom_filtered["TABLE_NAME"].nunique(), border=True)

        # anomalies by table
        with st.container(border=True):
            st.subheader("Anomalies by Table")
            at = anom_filtered.groupby("TABLE_NAME").size().reset_index(name="Count")
            st.bar_chart(at, x="TABLE_NAME", y="Count", color="#FFA500")

        # anomalies by metric type
        with st.container(border=True):
            st.subheader("Anomalies by Metric")
            am = anom_filtered.groupby("METRIC_NAME").size().reset_index(name="Count").sort_values("Count", ascending=False)
            st.bar_chart(am, x="METRIC_NAME", y="Count", color="#FFA500", horizontal=True)

        # detail table
        st.markdown("**Anomaly Details**")
        st.dataframe(
            anom_filtered[[
                "TABLE_NAME", "METRIC_NAME", "CURRENT_VALUE", "BASELINE_AVG",
                "ANOMALY_STATUS", "ANOMALY_REASON", "DETECTED_AT"
            ]],
            use_container_width=True, hide_index=True,
        )
    else:
        st.info("No anomalies detected.")

# ========================== TAB 4: COVERAGE ==========================
with tab_coverage:
    st.subheader("DQ Rule Coverage")

    if len(df_config) > 0:
        active_config = df_config[df_config["IS_ACTIVE"] == True]

        with st.container(horizontal=True):
            st.metric("Total Rules", len(active_config), border=True)
            st.metric("Tables Covered", active_config["TABLE_NM"].nunique(), border=True)
            st.metric("Rule Types", active_config["RULE_TYPE"].nunique(), border=True)

        col1, col2 = st.columns(2)

        with col1:
            with st.container(border=True):
                st.subheader("Rules per Table")
                rpt = active_config.groupby("TABLE_NM").size().reset_index(name="Rules")
                st.bar_chart(rpt, x="TABLE_NM", y="Rules", color="#29B5E8")

        with col2:
            with st.container(border=True):
                st.subheader("Rules per Type")
                rptype = active_config.groupby("RULE_TYPE").size().reset_index(name="Rules").sort_values("Rules", ascending=False)
                st.bar_chart(rptype, x="RULE_TYPE", y="Rules", color="#29B5E8", horizontal=True)

        # rules per criticality
        with st.container(border=True):
            st.subheader("Rules by Criticality")
            rpc = active_config.groupby("CRITICALITY").size().reset_index(name="Rules")
            st.bar_chart(rpc, x="CRITICALITY", y="Rules", color="CRITICALITY")

        # full config table
        st.markdown("**All Active Rules**")
        st.dataframe(
            active_config[["RULE_ID", "RULE_NAME", "RULE_TYPE", "CRITICALITY", "TABLE_NM", "COLUMN_NM", "RULE_DESCRIPTION", "IS_ACTIVE"]],
            use_container_width=True, hide_index=True,
        )
    else:
        st.info("No rules configured.")
