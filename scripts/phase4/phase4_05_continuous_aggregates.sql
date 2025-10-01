-- ============================================================================
-- MS5.0 Phase 4: TimescaleDB Continuous Aggregates
-- ============================================================================
-- Purpose: Create materialized views that automatically maintain real-time
--          aggregates of time-series data, dramatically accelerating
--          dashboard and reporting queries.
--
-- Design Philosophy: Continuous aggregates are pre-computed intelligence.
--                    Like a ship's bridge displays that show summarized
--                    sensor data, they transform raw telemetry into
--                    actionable insights with zero query latency.
--
-- Aggregate Strategy:
--   - Metric summaries: 1-minute, 1-hour, 1-day buckets
--   - OEE rollups: Hourly, daily, shift-based aggregates
--   - Energy analysis: Hourly consumption, daily peaks
--   - Refresh policies: Real-time (1-minute lag) for operations
-- ============================================================================

\set ON_ERROR_STOP on
\timing on

-- ----------------------------------------------------------------------------
-- Section 1: Metric History Continuous Aggregates
-- ----------------------------------------------------------------------------

-- 1-minute metric aggregates: For real-time monitoring
-- Reduces query load by 60x (from 1-second to 1-minute granularity)
CREATE MATERIALIZED VIEW IF NOT EXISTS factory_telemetry.metric_hist_1min
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 minute', ts) AS bucket,
    metric_def_id,
    -- Statistical aggregates for numeric values
    COUNT(*) AS sample_count,
    AVG(CASE WHEN value_real IS NOT NULL THEN value_real END) AS avg_real,
    MIN(CASE WHEN value_real IS NOT NULL THEN value_real END) AS min_real,
    MAX(CASE WHEN value_real IS NOT NULL THEN value_real END) AS max_real,
    STDDEV(CASE WHEN value_real IS NOT NULL THEN value_real END) AS stddev_real,
    AVG(CASE WHEN value_int IS NOT NULL THEN value_int::NUMERIC END) AS avg_int,
    MIN(CASE WHEN value_int IS NOT NULL THEN value_int END) AS min_int,
    MAX(CASE WHEN value_int IS NOT NULL THEN value_int END) AS max_int,
    -- Boolean aggregates
    SUM(CASE WHEN value_bool = TRUE THEN 1 ELSE 0 END) AS bool_true_count,
    SUM(CASE WHEN value_bool = FALSE THEN 1 ELSE 0 END) AS bool_false_count,
    -- Latest value (using LAST aggregate)
    LAST(value_real, ts) AS last_real,
    LAST(value_int, ts) AS last_int,
    LAST(value_bool, ts) AS last_bool
FROM factory_telemetry.metric_hist
GROUP BY bucket, metric_def_id;

COMMENT ON MATERIALIZED VIEW factory_telemetry.metric_hist_1min IS 
    '1-minute aggregates of metric history for real-time dashboards';

RAISE NOTICE 'Created continuous aggregate: metric_hist_1min (1-minute buckets)';

-- 1-hour metric aggregates: For trending and analysis
-- Reduces storage and query time for historical analysis
CREATE MATERIALIZED VIEW IF NOT EXISTS factory_telemetry.metric_hist_1hour
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 hour', ts) AS bucket,
    metric_def_id,
    COUNT(*) AS sample_count,
    AVG(CASE WHEN value_real IS NOT NULL THEN value_real END) AS avg_real,
    MIN(CASE WHEN value_real IS NOT NULL THEN value_real END) AS min_real,
    MAX(CASE WHEN value_real IS NOT NULL THEN value_real END) AS max_real,
    STDDEV(CASE WHEN value_real IS NOT NULL THEN value_real END) AS stddev_real,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY value_real) AS median_real,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY value_real) AS p95_real,
    AVG(CASE WHEN value_int IS NOT NULL THEN value_int::NUMERIC END) AS avg_int,
    MIN(CASE WHEN value_int IS NOT NULL THEN value_int END) AS min_int,
    MAX(CASE WHEN value_int IS NOT NULL THEN value_int END) AS max_int
FROM factory_telemetry.metric_hist
GROUP BY bucket, metric_def_id;

COMMENT ON MATERIALIZED VIEW factory_telemetry.metric_hist_1hour IS 
    '1-hour aggregates of metric history for trend analysis and reporting';

RAISE NOTICE 'Created continuous aggregate: metric_hist_1hour (1-hour buckets)';

-- 1-day metric aggregates: For long-term trends and reporting
CREATE MATERIALIZED VIEW IF NOT EXISTS factory_telemetry.metric_hist_1day
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 day', ts) AS bucket,
    metric_def_id,
    COUNT(*) AS sample_count,
    AVG(CASE WHEN value_real IS NOT NULL THEN value_real END) AS avg_real,
    MIN(CASE WHEN value_real IS NOT NULL THEN value_real END) AS min_real,
    MAX(CASE WHEN value_real IS NOT NULL THEN value_real END) AS max_real,
    STDDEV(CASE WHEN value_real IS NOT NULL THEN value_real END) AS stddev_real,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY value_real) AS median_real
FROM factory_telemetry.metric_hist
GROUP BY bucket, metric_def_id;

COMMENT ON MATERIALIZED VIEW factory_telemetry.metric_hist_1day IS 
    '1-day aggregates of metric history for long-term trend analysis';

RAISE NOTICE 'Created continuous aggregate: metric_hist_1day (1-day buckets)';

-- ----------------------------------------------------------------------------
-- Section 2: OEE Continuous Aggregates
-- ----------------------------------------------------------------------------

-- Hourly OEE rollups: For shift analysis and real-time monitoring
CREATE MATERIALIZED VIEW IF NOT EXISTS factory_telemetry.oee_hourly
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 hour', calculation_time) AS bucket,
    line_id,
    equipment_code,
    COUNT(*) AS calculation_count,
    AVG(availability) AS avg_availability,
    MIN(availability) AS min_availability,
    MAX(availability) AS max_availability,
    AVG(performance) AS avg_performance,
    MIN(performance) AS min_performance,
    MAX(performance) AS max_performance,
    AVG(quality) AS avg_quality,
    MIN(quality) AS min_quality,
    MAX(quality) AS max_quality,
    AVG(oee) AS avg_oee,
    MIN(oee) AS min_oee,
    MAX(oee) AS max_oee,
    SUM(good_parts) AS total_good_parts,
    SUM(total_parts) AS total_parts,
    SUM(downtime_minutes) AS total_downtime_minutes
FROM factory_telemetry.oee_calculations
GROUP BY bucket, line_id, equipment_code;

COMMENT ON MATERIALIZED VIEW factory_telemetry.oee_hourly IS 
    'Hourly OEE aggregates for shift analysis and real-time monitoring';

RAISE NOTICE 'Created continuous aggregate: oee_hourly (1-hour buckets)';

-- Daily OEE rollups: For daily reports and trend analysis
CREATE MATERIALIZED VIEW IF NOT EXISTS factory_telemetry.oee_daily
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 day', calculation_time) AS bucket,
    line_id,
    equipment_code,
    COUNT(*) AS calculation_count,
    AVG(availability) AS avg_availability,
    AVG(performance) AS avg_performance,
    AVG(quality) AS avg_quality,
    AVG(oee) AS avg_oee,
    SUM(good_parts) AS total_good_parts,
    SUM(total_parts) AS total_parts,
    SUM(downtime_minutes) AS total_downtime_minutes,
    -- Additional insights
    MAX(oee) AS best_oee,
    MIN(oee) AS worst_oee,
    STDDEV(oee) AS oee_stddev
FROM factory_telemetry.oee_calculations
GROUP BY bucket, line_id, equipment_code;

COMMENT ON MATERIALIZED VIEW factory_telemetry.oee_daily IS 
    'Daily OEE aggregates for reporting and trend analysis';

RAISE NOTICE 'Created continuous aggregate: oee_daily (1-day buckets)';

-- Weekly OEE rollups: For management reporting
CREATE MATERIALIZED VIEW IF NOT EXISTS factory_telemetry.oee_weekly
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 week', calculation_time) AS bucket,
    line_id,
    equipment_code,
    AVG(availability) AS avg_availability,
    AVG(performance) AS avg_performance,
    AVG(quality) AS avg_quality,
    AVG(oee) AS avg_oee,
    SUM(good_parts) AS total_good_parts,
    SUM(total_parts) AS total_parts,
    SUM(downtime_minutes) AS total_downtime_minutes
FROM factory_telemetry.oee_calculations
GROUP BY bucket, line_id, equipment_code;

COMMENT ON MATERIALIZED VIEW factory_telemetry.oee_weekly IS 
    'Weekly OEE aggregates for management reporting and KPI tracking';

RAISE NOTICE 'Created continuous aggregate: oee_weekly (1-week buckets)';

-- ----------------------------------------------------------------------------
-- Section 3: Energy Consumption Continuous Aggregates
-- ----------------------------------------------------------------------------

-- Hourly energy aggregates: For energy monitoring and peak analysis
CREATE MATERIALIZED VIEW IF NOT EXISTS factory_telemetry.energy_hourly
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 hour', consumption_time) AS bucket,
    equipment_code,
    COUNT(*) AS reading_count,
    SUM(consumption_kwh) AS total_consumption_kwh,
    AVG(consumption_kwh) AS avg_consumption_kwh,
    MAX(peak_power_kw) AS peak_power_kw,
    AVG(power_factor) AS avg_power_factor,
    SUM(CASE WHEN peak_power_kw > 100 THEN 1 ELSE 0 END) AS high_demand_events
FROM factory_telemetry.energy_consumption
GROUP BY bucket, equipment_code;

COMMENT ON MATERIALIZED VIEW factory_telemetry.energy_hourly IS 
    'Hourly energy consumption aggregates for monitoring and peak analysis';

RAISE NOTICE 'Created continuous aggregate: energy_hourly (1-hour buckets)';

-- Daily energy aggregates: For cost analysis and reporting
CREATE MATERIALIZED VIEW IF NOT EXISTS factory_telemetry.energy_daily
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 day', consumption_time) AS bucket,
    equipment_code,
    SUM(consumption_kwh) AS total_consumption_kwh,
    AVG(consumption_kwh) AS avg_consumption_kwh,
    MAX(peak_power_kw) AS peak_power_kw,
    MIN(consumption_kwh) AS min_consumption_kwh,
    MAX(consumption_kwh) AS max_consumption_kwh,
    AVG(power_factor) AS avg_power_factor
FROM factory_telemetry.energy_consumption
GROUP BY bucket, equipment_code;

COMMENT ON MATERIALIZED VIEW factory_telemetry.energy_daily IS 
    'Daily energy consumption aggregates for cost analysis and reporting';

RAISE NOTICE 'Created continuous aggregate: energy_daily (1-day buckets)';

-- ----------------------------------------------------------------------------
-- Section 4: Add Refresh Policies
-- ----------------------------------------------------------------------------

-- Metric aggregates: Refresh every 1 minute for real-time data
SELECT add_continuous_aggregate_policy(
    'factory_telemetry.metric_hist_1min',
    start_offset => INTERVAL '3 hours',      -- Materialize 3 hours back
    end_offset => INTERVAL '1 minute',       -- Up to 1 minute ago
    schedule_interval => INTERVAL '1 minute', -- Refresh every minute
    if_not_exists => TRUE
);

RAISE NOTICE 'Added refresh policy for metric_hist_1min: every 1 minute';

-- 1-hour aggregates: Refresh every 10 minutes
SELECT add_continuous_aggregate_policy(
    'factory_telemetry.metric_hist_1hour',
    start_offset => INTERVAL '1 day',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '10 minutes',
    if_not_exists => TRUE
);

RAISE NOTICE 'Added refresh policy for metric_hist_1hour: every 10 minutes';

-- 1-day aggregates: Refresh every hour
SELECT add_continuous_aggregate_policy(
    'factory_telemetry.metric_hist_1day',
    start_offset => INTERVAL '7 days',
    end_offset => INTERVAL '1 day',
    schedule_interval => INTERVAL '1 hour',
    if_not_exists => TRUE
);

RAISE NOTICE 'Added refresh policy for metric_hist_1day: every 1 hour';

-- OEE hourly: Refresh every 5 minutes
SELECT add_continuous_aggregate_policy(
    'factory_telemetry.oee_hourly',
    start_offset => INTERVAL '1 day',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '5 minutes',
    if_not_exists => TRUE
);

RAISE NOTICE 'Added refresh policy for oee_hourly: every 5 minutes';

-- OEE daily: Refresh every hour
SELECT add_continuous_aggregate_policy(
    'factory_telemetry.oee_daily',
    start_offset => INTERVAL '7 days',
    end_offset => INTERVAL '1 day',
    schedule_interval => INTERVAL '1 hour',
    if_not_exists => TRUE
);

RAISE NOTICE 'Added refresh policy for oee_daily: every 1 hour';

-- OEE weekly: Refresh once daily
SELECT add_continuous_aggregate_policy(
    'factory_telemetry.oee_weekly',
    start_offset => INTERVAL '30 days',
    end_offset => INTERVAL '1 week',
    schedule_interval => INTERVAL '1 day',
    if_not_exists => TRUE
);

RAISE NOTICE 'Added refresh policy for oee_weekly: every 1 day';

-- Energy hourly: Refresh every 10 minutes
SELECT add_continuous_aggregate_policy(
    'factory_telemetry.energy_hourly',
    start_offset => INTERVAL '1 day',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '10 minutes',
    if_not_exists => TRUE
);

RAISE NOTICE 'Added refresh policy for energy_hourly: every 10 minutes';

-- Energy daily: Refresh every hour
SELECT add_continuous_aggregate_policy(
    'factory_telemetry.energy_daily',
    start_offset => INTERVAL '7 days',
    end_offset => INTERVAL '1 day',
    schedule_interval => INTERVAL '1 hour',
    if_not_exists => TRUE
);

RAISE NOTICE 'Added refresh policy for energy_daily: every 1 hour';

-- ----------------------------------------------------------------------------
-- Section 5: Create Indexes on Continuous Aggregates
-- ----------------------------------------------------------------------------

-- Metric aggregates indexes
CREATE INDEX IF NOT EXISTS idx_metric_1min_bucket_metric 
ON factory_telemetry.metric_hist_1min (bucket DESC, metric_def_id);

CREATE INDEX IF NOT EXISTS idx_metric_1hour_bucket_metric 
ON factory_telemetry.metric_hist_1hour (bucket DESC, metric_def_id);

CREATE INDEX IF NOT EXISTS idx_metric_1day_bucket_metric 
ON factory_telemetry.metric_hist_1day (bucket DESC, metric_def_id);

-- OEE aggregates indexes
CREATE INDEX IF NOT EXISTS idx_oee_hourly_bucket_line 
ON factory_telemetry.oee_hourly (bucket DESC, line_id);

CREATE INDEX IF NOT EXISTS idx_oee_daily_bucket_line 
ON factory_telemetry.oee_daily (bucket DESC, line_id);

CREATE INDEX IF NOT EXISTS idx_oee_weekly_bucket_line 
ON factory_telemetry.oee_weekly (bucket DESC, line_id);

-- Energy aggregates indexes
CREATE INDEX IF NOT EXISTS idx_energy_hourly_bucket_equipment 
ON factory_telemetry.energy_hourly (bucket DESC, equipment_code);

CREATE INDEX IF NOT EXISTS idx_energy_daily_bucket_equipment 
ON factory_telemetry.energy_daily (bucket DESC, equipment_code);

RAISE NOTICE 'Created indexes on all continuous aggregates';

-- ----------------------------------------------------------------------------
-- Section 6: Create Convenience Views
-- ----------------------------------------------------------------------------

-- View for latest OEE by line (last 24 hours)
CREATE OR REPLACE VIEW factory_telemetry.v_oee_latest_24h AS
SELECT 
    bucket,
    line_id,
    equipment_code,
    avg_oee,
    total_good_parts,
    total_parts,
    total_downtime_minutes
FROM factory_telemetry.oee_hourly
WHERE bucket > NOW() - INTERVAL '24 hours'
ORDER BY bucket DESC;

COMMENT ON VIEW factory_telemetry.v_oee_latest_24h IS 
    'Latest 24 hours of OEE data from hourly aggregates';

-- View for energy consumption trends (last 7 days)
CREATE OR REPLACE VIEW factory_telemetry.v_energy_week AS
SELECT 
    bucket,
    equipment_code,
    total_consumption_kwh,
    peak_power_kw,
    avg_power_factor
FROM factory_telemetry.energy_daily
WHERE bucket > NOW() - INTERVAL '7 days'
ORDER BY bucket DESC;

COMMENT ON VIEW factory_telemetry.v_energy_week IS 
    'Last 7 days of energy consumption from daily aggregates';

RAISE NOTICE 'Created convenience views for dashboards';

-- ----------------------------------------------------------------------------
-- Section 7: Display Continuous Aggregate Summary
-- ----------------------------------------------------------------------------

-- Show all continuous aggregates
SELECT 
    view_name,
    materialized_only,
    compression_enabled,
    pg_size_pretty(
        pg_total_relation_size(format('factory_telemetry.%I', view_name)::regclass)
    ) AS materialized_size
FROM timescaledb_information.continuous_aggregates
WHERE view_schema = 'factory_telemetry'
ORDER BY view_name;

-- Show refresh policies
SELECT 
    ca.view_name,
    j.schedule_interval,
    j.config->>'start_offset' AS start_offset,
    j.config->>'end_offset' AS end_offset,
    j.next_start,
    j.last_successful_finish
FROM timescaledb_information.continuous_aggregates ca
JOIN timescaledb_information.jobs j 
    ON j.proc_name = 'policy_refresh_continuous_aggregate'
    AND j.hypertable_name = ca.view_name
WHERE ca.view_schema = 'factory_telemetry'
ORDER BY ca.view_name;

-- ----------------------------------------------------------------------------
-- Section 8: Completion Summary
-- ----------------------------------------------------------------------------

DO $$
DECLARE
    v_aggregate_count INTEGER;
    v_total_size TEXT;
BEGIN
    SELECT 
        COUNT(*),
        pg_size_pretty(SUM(
            pg_total_relation_size(format('factory_telemetry.%I', view_name)::regclass)
        ))
    INTO v_aggregate_count, v_total_size
    FROM timescaledb_information.continuous_aggregates
    WHERE view_schema = 'factory_telemetry';
    
    RAISE NOTICE E'\n=== Phase 4.5 Continuous Aggregates Complete ===';
    RAISE NOTICE 'Total continuous aggregates: %', v_aggregate_count;
    RAISE NOTICE 'Total materialized size: %', v_total_size;
    RAISE NOTICE 'Aggregates refresh automatically based on configured policies';
END $$;

\echo '✓ Continuous aggregates configured successfully'
