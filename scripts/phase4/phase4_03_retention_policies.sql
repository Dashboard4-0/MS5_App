-- ============================================================================
-- MS5.0 Phase 4: TimescaleDB Retention Policies
-- ============================================================================
-- Purpose: Implement automated data retention policies to manage storage
--          growth while preserving data according to operational and
--          compliance requirements.
--
-- Design Philosophy: Data has a lifecycle. Like a ship's sensor logs,
--                    recent data is precious for operations; historical
--                    data serves compliance and analysis; ancient data
--                    can be purged. Retention policies are the automatic
--                    custodians of this lifecycle.
--
-- Retention Strategy:
--   - High-frequency telemetry: 90 days (regulatory + operational buffer)
--   - Calculated metrics: 365 days (annual reporting cycles)
--   - Audit trails: 730 days (2-year compliance requirement)
--   - Low-frequency aggregates: 365 days (annual trends)
-- ============================================================================

\set ON_ERROR_STOP on
\timing on

-- ----------------------------------------------------------------------------
-- Section 1: Pre-Retention Analysis
-- ----------------------------------------------------------------------------

-- Display current data age distribution
DO $$
DECLARE
    v_table_name TEXT;
    v_time_column TEXT;
    v_oldest_record TIMESTAMPTZ;
    v_newest_record TIMESTAMPTZ;
    v_age_days NUMERIC;
    v_total_rows BIGINT;
BEGIN
    RAISE NOTICE E'\n=== Current Data Age Analysis ===';
    
    -- Metric history
    SELECT MIN(ts), MAX(ts), COUNT(*), EXTRACT(DAYS FROM (MAX(ts) - MIN(ts)))
    INTO v_oldest_record, v_newest_record, v_total_rows, v_age_days
    FROM factory_telemetry.metric_hist;
    
    IF v_total_rows > 0 THEN
        RAISE NOTICE 'metric_hist: % rows, age: % days (% to %)',
            v_total_rows, v_age_days, v_oldest_record, v_newest_record;
    ELSE
        RAISE NOTICE 'metric_hist: No data present';
    END IF;
    
    -- OEE calculations
    SELECT MIN(calculation_time), MAX(calculation_time), COUNT(*), 
           EXTRACT(DAYS FROM (MAX(calculation_time) - MIN(calculation_time)))
    INTO v_oldest_record, v_newest_record, v_total_rows, v_age_days
    FROM factory_telemetry.oee_calculations;
    
    IF v_total_rows > 0 THEN
        RAISE NOTICE 'oee_calculations: % rows, age: % days (% to %)',
            v_total_rows, v_age_days, v_oldest_record, v_newest_record;
    ELSE
        RAISE NOTICE 'oee_calculations: No data present';
    END IF;
    
    -- Energy consumption
    SELECT MIN(consumption_time), MAX(consumption_time), COUNT(*),
           EXTRACT(DAYS FROM (MAX(consumption_time) - MIN(consumption_time)))
    INTO v_oldest_record, v_newest_record, v_total_rows, v_age_days
    FROM factory_telemetry.energy_consumption;
    
    IF v_total_rows > 0 THEN
        RAISE NOTICE 'energy_consumption: % rows, age: % days (% to %)',
            v_total_rows, v_age_days, v_oldest_record, v_newest_record;
    ELSE
        RAISE NOTICE 'energy_consumption: No data present';
    END IF;
    
    -- Production KPIs
    SELECT MIN(created_at), MAX(created_at), COUNT(*),
           EXTRACT(DAYS FROM (MAX(created_at) - MIN(created_at)))
    INTO v_oldest_record, v_newest_record, v_total_rows, v_age_days
    FROM factory_telemetry.production_kpis;
    
    IF v_total_rows > 0 THEN
        RAISE NOTICE 'production_kpis: % rows, age: % days (% to %)',
            v_total_rows, v_age_days, v_oldest_record, v_newest_record;
    ELSE
        RAISE NOTICE 'production_kpis: No data present';
    END IF;
    
    -- Production context history
    SELECT MIN(changed_at), MAX(changed_at), COUNT(*),
           EXTRACT(DAYS FROM (MAX(changed_at) - MIN(changed_at)))
    INTO v_oldest_record, v_newest_record, v_total_rows, v_age_days
    FROM factory_telemetry.production_context_history;
    
    IF v_total_rows > 0 THEN
        RAISE NOTICE 'production_context_history: % rows, age: % days (% to %)',
            v_total_rows, v_age_days, v_oldest_record, v_newest_record;
    ELSE
        RAISE NOTICE 'production_context_history: No data present';
    END IF;
    
END $$;

-- ----------------------------------------------------------------------------
-- Section 2: Add Retention Policies
-- ----------------------------------------------------------------------------

-- Metric history: Retain for 90 days
-- Rationale: 
--   - Real-time operations: last 7 days
--   - Weekly/monthly trends: up to 30 days
--   - Quarterly analysis: up to 90 days
--   - Regulatory compliance: covered by continuous aggregates
SELECT add_retention_policy(
    'factory_telemetry.metric_hist',
    INTERVAL '90 days',
    if_not_exists => TRUE
);

RAISE NOTICE 'Added retention policy for metric_hist: drop chunks older than 90 days';

-- OEE calculations: Retain for 365 days
-- Rationale:
--   - Annual reporting cycles require full-year data
--   - Year-over-year comparisons are critical for operations
--   - Compressed after 7 days, so storage impact is minimal
SELECT add_retention_policy(
    'factory_telemetry.oee_calculations',
    INTERVAL '365 days',
    if_not_exists => TRUE
);

RAISE NOTICE 'Added retention policy for oee_calculations: drop chunks older than 365 days';

-- Energy consumption: Retain for 365 days
-- Rationale:
--   - Energy audits and reporting require annual data
--   - Seasonal patterns need year-over-year analysis
--   - Environmental compliance reporting
SELECT add_retention_policy(
    'factory_telemetry.energy_consumption',
    INTERVAL '365 days',
    if_not_exists => TRUE
);

RAISE NOTICE 'Added retention policy for energy_consumption: drop chunks older than 365 days';

-- Production KPIs: Retain for 365 days
-- Rationale:
--   - Performance tracking and improvement initiatives span years
--   - Annual reviews and audits require historical KPIs
--   - Continuous aggregates preserve longer-term trends
SELECT add_retention_policy(
    'factory_telemetry.production_kpis',
    INTERVAL '365 days',
    if_not_exists => TRUE
);

RAISE NOTICE 'Added retention policy for production_kpis: drop chunks older than 365 days';

-- Production context history: Retain for 730 days (2 years)
-- Rationale:
--   - Audit trail for regulatory compliance
--   - Long-term operator performance tracking
--   - Historical context for incident investigation
--   - Minimal storage impact (low-frequency updates)
SELECT add_retention_policy(
    'factory_telemetry.production_context_history',
    INTERVAL '730 days',
    if_not_exists => TRUE
);

RAISE NOTICE 'Added retention policy for production_context_history: drop chunks older than 730 days';

-- ----------------------------------------------------------------------------
-- Section 3: Retention Job Configuration
-- ----------------------------------------------------------------------------

-- Configure retention job scheduling
-- Default: Runs daily to drop old chunks
-- Schedule for off-peak hours to minimize operational impact

SELECT alter_job(
    job_id,
    schedule_interval => INTERVAL '1 day',    -- Run daily
    max_runtime => INTERVAL '1 hour',         -- Should complete quickly
    retry_period => INTERVAL '6 hours',       -- Retry on failure
    scheduled => TRUE
)
FROM timescaledb_information.jobs
WHERE proc_name = 'policy_retention'
  AND hypertable_name IN (
      'metric_hist',
      'oee_calculations',
      'energy_consumption',
      'production_kpis',
      'production_context_history'
  );

RAISE NOTICE 'Configured retention jobs: daily execution, 1-hour max runtime';

-- ----------------------------------------------------------------------------
-- Section 4: Create Retention Monitoring View
-- ----------------------------------------------------------------------------

-- Create view to monitor data retention status
CREATE OR REPLACE VIEW factory_telemetry.v_retention_status AS
SELECT 
    h.hypertable_name,
    j.schedule_interval AS job_interval,
    (j.config->>'drop_after')::INTERVAL AS retention_period,
    j.next_start AS next_retention_job,
    j.last_run_success AS last_run_successful,
    j.last_successful_finish AS last_successful_run,
    (
        SELECT COUNT(*)
        FROM timescaledb_information.chunks c
        WHERE c.hypertable_name = h.hypertable_name
    ) AS total_chunks,
    (
        SELECT COUNT(*)
        FROM timescaledb_information.chunks c
        WHERE c.hypertable_name = h.hypertable_name
          AND c.range_end < NOW() - (j.config->>'drop_after')::INTERVAL
    ) AS chunks_eligible_for_drop,
    pg_size_pretty(
        pg_total_relation_size(format('%I.%I', h.hypertable_schema, h.hypertable_name)::regclass)
    ) AS total_size
FROM timescaledb_information.hypertables h
LEFT JOIN timescaledb_information.jobs j 
    ON j.hypertable_name = h.hypertable_name
    AND j.proc_name = 'policy_retention'
WHERE h.hypertable_schema = 'factory_telemetry'
ORDER BY h.hypertable_name;

COMMENT ON VIEW factory_telemetry.v_retention_status IS 
    'Monitoring view for data retention policies across all hypertables';

RAISE NOTICE 'Created retention monitoring view: factory_telemetry.v_retention_status';

-- ----------------------------------------------------------------------------
-- Section 5: Create Manual Retention Management Function
-- ----------------------------------------------------------------------------

-- Function to manually trigger retention for a specific table
CREATE OR REPLACE FUNCTION factory_telemetry.manual_retention_drop(
    p_hypertable_name TEXT,
    p_older_than INTERVAL
)
RETURNS TABLE(
    dropped_chunk_name TEXT,
    chunk_time_range TSTZRANGE,
    rows_dropped BIGINT
) 
LANGUAGE plpgsql
AS $$
DECLARE
    v_chunk RECORD;
    v_chunk_rows BIGINT;
BEGIN
    FOR v_chunk IN 
        SELECT 
            chunk_schema || '.' || chunk_name AS full_chunk_name,
            range_start,
            range_end
        FROM timescaledb_information.chunks
        WHERE hypertable_schema = 'factory_telemetry'
          AND hypertable_name = p_hypertable_name
          AND range_end < NOW() - p_older_than
        ORDER BY range_end
    LOOP
        -- Count rows before dropping
        EXECUTE format('SELECT COUNT(*) FROM %s', v_chunk.full_chunk_name)
        INTO v_chunk_rows;
        
        -- Drop the chunk
        PERFORM drop_chunks(
            format('factory_telemetry.%I', p_hypertable_name)::regclass,
            older_than => v_chunk.range_end
        );
        
        -- Return dropped chunk info
        dropped_chunk_name := v_chunk.full_chunk_name;
        chunk_time_range := tstzrange(v_chunk.range_start, v_chunk.range_end);
        rows_dropped := v_chunk_rows;
        RETURN NEXT;
    END LOOP;
END;
$$;

COMMENT ON FUNCTION factory_telemetry.manual_retention_drop IS 
    'Manually drop chunks older than specified interval for a hypertable';

RAISE NOTICE 'Created manual retention function: factory_telemetry.manual_retention_drop()';

-- ----------------------------------------------------------------------------
-- Section 6: Display Retention Configuration
-- ----------------------------------------------------------------------------

-- Show all retention policies
SELECT * FROM factory_telemetry.v_retention_status;

-- Show active retention jobs
SELECT 
    j.hypertable_name,
    j.schedule_interval,
    j.config->>'drop_after' AS retention_interval,
    j.scheduled AS job_enabled,
    j.next_start,
    j.last_successful_finish,
    j.total_runs,
    j.total_successes,
    j.total_failures
FROM timescaledb_information.jobs j
WHERE j.proc_name = 'policy_retention'
  AND j.hypertable_schema = 'factory_telemetry'
ORDER BY j.hypertable_name;

-- ----------------------------------------------------------------------------
-- Section 7: Estimate Storage Savings
-- ----------------------------------------------------------------------------

DO $$
DECLARE
    v_total_size BIGINT;
    v_droppable_size BIGINT;
    v_savings_pct NUMERIC;
BEGIN
    -- Calculate current total size
    SELECT SUM(pg_total_relation_size(format('%I.%I', hypertable_schema, hypertable_name)::regclass))
    INTO v_total_size
    FROM timescaledb_information.hypertables
    WHERE hypertable_schema = 'factory_telemetry';
    
    -- Estimate droppable size (approximate)
    -- This is a rough estimate; actual savings depend on chunk distribution
    SELECT COUNT(*) * 100000000  -- Assume ~100MB per old chunk (conservative)
    INTO v_droppable_size
    FROM (
        SELECT 
            c.chunk_name,
            c.range_end,
            (j.config->>'drop_after')::INTERVAL AS retention
        FROM timescaledb_information.chunks c
        JOIN timescaledb_information.jobs j 
            ON j.hypertable_name = c.hypertable_name
            AND j.proc_name = 'policy_retention'
        WHERE c.hypertable_schema = 'factory_telemetry'
          AND c.range_end < NOW() - (j.config->>'drop_after')::INTERVAL
    ) droppable_chunks;
    
    IF v_total_size > 0 THEN
        v_savings_pct := (v_droppable_size::NUMERIC / v_total_size::NUMERIC) * 100;
        
        RAISE NOTICE E'\n=== Storage Impact Analysis ===';
        RAISE NOTICE 'Current total size: %', pg_size_pretty(v_total_size);
        RAISE NOTICE 'Estimated droppable: %', pg_size_pretty(v_droppable_size);
        RAISE NOTICE 'Potential savings: %% after first retention run', ROUND(v_savings_pct, 2);
    ELSE
        RAISE NOTICE 'No data present for storage analysis';
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- Section 8: Completion Summary
-- ----------------------------------------------------------------------------

DO $$
DECLARE
    v_summary TEXT;
BEGIN
    SELECT string_agg(
        format('  • %s: retain %s, next run %s',
            hypertable_name,
            retention_period,
            TO_CHAR(next_retention_job, 'YYYY-MM-DD HH24:MI')
        ),
        E'\n'
        ORDER BY hypertable_name
    ) INTO v_summary
    FROM factory_telemetry.v_retention_status;
    
    RAISE NOTICE E'\n=== Phase 4.3 Retention Policies Complete ===\n%', v_summary;
END $$;

\echo '✓ Retention policies configured successfully'
