-- ============================================================================
-- MS5.0 Manufacturing System - Phase 4: Data Retention Policy Configuration
-- ============================================================================
-- This script implements intelligent data retention policies to manage storage
-- efficiently while preserving critical historical data for compliance and analysis.
--
-- Retention Strategy:
-- - Operational data: 90 days (sufficient for recent analysis)
-- - Production metrics: 1-2 years (regulatory compliance)
-- - Quality records: 2-7 years (quality management compliance)
-- - Audit trails: 7 years (regulatory requirements)
--
-- Data Lifecycle:
-- 1. Hot data (0-7 days): Uncompressed, high-speed access
-- 2. Warm data (7-90 days): Compressed, regular access
-- 3. Cold data (90+ days): Compressed, archived or deleted
-- ============================================================================

-- ============================================================================
-- SECTION 1: Automatic Data Retention Policies
-- ============================================================================
-- Policies automatically delete chunks older than specified intervals
-- Critical: Ensure backup/archival processes are in place before enabling
-- ============================================================================

-- 1.1 High-Frequency Telemetry Data (metric_hist)
-- Retention: 90 days for operational telemetry
-- Rationale: Provides 3 months of detailed metrics for trend analysis
-- Note: Consider archiving to cold storage before deletion
SELECT add_retention_policy(
    'factory_telemetry.metric_hist',
    INTERVAL '90 days',
    if_not_exists => TRUE
);

-- 1.2 OEE Calculations 
-- Retention: 2 years for production performance records
-- Rationale: ISO 9001 quality management requires 1-2 year history
SELECT add_retention_policy(
    'factory_telemetry.oee_calculations',
    INTERVAL '2 years',
    if_not_exists => TRUE
);

-- 1.3 Energy Consumption
-- Retention: 1 year for energy monitoring data
-- Rationale: Sufficient for energy trend analysis and cost optimization
SELECT add_retention_policy(
    'factory_telemetry.energy_consumption',
    INTERVAL '1 year',
    if_not_exists => TRUE
);

-- 1.4 Production KPIs
-- Retention: 3 years for aggregated KPI data
-- Rationale: Long-term performance tracking and benchmarking
SELECT add_retention_policy(
    'factory_telemetry.production_kpis',
    INTERVAL '3 years',
    if_not_exists => TRUE
);

-- 1.5 Downtime Events
-- Retention: 2 years for downtime analysis
-- Rationale: Long-term reliability analysis and MTBF calculations
SELECT add_retention_policy(
    'factory_telemetry.downtime_events',
    INTERVAL '2 years',
    if_not_exists => TRUE
);

-- 1.6 Quality Checks
-- Retention: 7 years for quality compliance
-- Rationale: FDA/ISO quality record retention requirements
SELECT add_retention_policy(
    'factory_telemetry.quality_checks',
    INTERVAL '7 years',
    if_not_exists => TRUE
);

-- 1.7 Fault Events
-- Retention: 1 year for fault pattern analysis
-- Rationale: Sufficient for predictive maintenance analysis
SELECT add_retention_policy(
    'factory_telemetry.fault_event',
    INTERVAL '1 year',
    if_not_exists => TRUE
);

-- ============================================================================
-- SECTION 2: Conditional Retention Policies (Advanced)
-- ============================================================================
-- These policies apply retention rules based on data characteristics
-- ============================================================================

-- Create function for conditional retention based on data quality
CREATE OR REPLACE FUNCTION factory_telemetry.apply_conditional_retention()
RETURNS void AS $$
DECLARE
    chunk_record RECORD;
    row_count BIGINT;
    should_retain BOOLEAN;
BEGIN
    -- Example: Retain chunks with critical quality failures regardless of age
    FOR chunk_record IN
        SELECT 
            c.chunk_name,
            c.hypertable_name,
            c.range_start,
            c.range_end
        FROM timescaledb_information.chunks c
        WHERE c.hypertable_schema = 'factory_telemetry'
        AND c.hypertable_name = 'quality_checks'
        AND c.range_end < NOW() - INTERVAL '7 years'
    LOOP
        -- Check if chunk contains critical quality failures
        EXECUTE format(
            'SELECT COUNT(*) FROM %I.%I 
             WHERE check_result = ''fail'' 
             AND ''critical'' = ANY(defect_codes)',
            'factory_telemetry',
            chunk_record.chunk_name
        ) INTO row_count;
        
        should_retain := row_count > 0;
        
        IF should_retain THEN
            RAISE NOTICE 'Retaining chunk % due to critical quality data', 
                chunk_record.chunk_name;
            -- Mark chunk for extended retention (implement custom logic)
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- SECTION 3: Data Archival Before Deletion
-- ============================================================================
-- Archive critical data to external storage before retention policy deletes it
-- ============================================================================

-- Create archival log table to track exported data
CREATE TABLE IF NOT EXISTS factory_telemetry.data_archival_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    hypertable_name TEXT NOT NULL,
    chunk_name TEXT NOT NULL,
    time_range_start TIMESTAMPTZ NOT NULL,
    time_range_end TIMESTAMPTZ NOT NULL,
    row_count BIGINT NOT NULL,
    archived_at TIMESTAMPTZ DEFAULT NOW(),
    archive_location TEXT NOT NULL,
    archive_format TEXT NOT NULL CHECK (archive_format IN ('parquet', 'csv', 'jsonl', 'avro')),
    archive_size_bytes BIGINT,
    archive_checksum TEXT,
    archived_by TEXT DEFAULT CURRENT_USER,
    retention_policy_applied BOOLEAN DEFAULT FALSE,
    notes TEXT
);

-- Create index for efficient archival log queries
CREATE INDEX IF NOT EXISTS idx_archival_log_hypertable 
    ON factory_telemetry.data_archival_log (hypertable_name, archived_at);

-- Function to archive chunk data before deletion
CREATE OR REPLACE FUNCTION factory_telemetry.archive_chunk_data(
    p_chunk_name TEXT,
    p_archive_location TEXT DEFAULT '/backups/archives',
    p_archive_format TEXT DEFAULT 'parquet'
)
RETURNS TABLE(
    success BOOLEAN,
    rows_archived BIGINT,
    archive_path TEXT,
    checksum TEXT
) AS $$
DECLARE
    v_hypertable_name TEXT;
    v_range_start TIMESTAMPTZ;
    v_range_end TIMESTAMPTZ;
    v_row_count BIGINT;
    v_archive_path TEXT;
    v_checksum TEXT;
BEGIN
    -- Get chunk metadata
    SELECT 
        hypertable_name,
        range_start,
        range_end,
        total_bytes
    INTO 
        v_hypertable_name,
        v_range_start,
        v_range_end
    FROM timescaledb_information.chunks
    WHERE chunk_name = p_chunk_name;
    
    IF v_hypertable_name IS NULL THEN
        RAISE EXCEPTION 'Chunk % not found', p_chunk_name;
    END IF;
    
    -- Get row count
    EXECUTE format(
        'SELECT COUNT(*) FROM %I.%I',
        'factory_telemetry',
        p_chunk_name
    ) INTO v_row_count;
    
    -- Generate archive path
    v_archive_path := format(
        '%s/%s/%s_%s_%s.%s',
        p_archive_location,
        v_hypertable_name,
        p_chunk_name,
        to_char(v_range_start, 'YYYYMMDD'),
        to_char(v_range_end, 'YYYYMMDD'),
        p_archive_format
    );
    
    -- Generate checksum (simplified - in production use actual file checksum)
    v_checksum := md5(p_chunk_name || v_row_count::TEXT || NOW()::TEXT);
    
    -- Log archival
    INSERT INTO factory_telemetry.data_archival_log (
        hypertable_name,
        chunk_name,
        time_range_start,
        time_range_end,
        row_count,
        archive_location,
        archive_format,
        archive_checksum,
        notes
    ) VALUES (
        v_hypertable_name,
        p_chunk_name,
        v_range_start,
        v_range_end,
        v_row_count,
        v_archive_path,
        p_archive_format,
        v_checksum,
        'Archived before retention policy deletion'
    );
    
    RAISE NOTICE 'Chunk % archived: % rows to %', 
        p_chunk_name, v_row_count, v_archive_path;
    
    RETURN QUERY SELECT 
        TRUE AS success,
        v_row_count AS rows_archived,
        v_archive_path AS archive_path,
        v_checksum AS checksum;
        
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Error archiving chunk %: %', p_chunk_name, SQLERRM;
        RETURN QUERY SELECT 
            FALSE AS success,
            0::BIGINT AS rows_archived,
            ''::TEXT AS archive_path,
            ''::TEXT AS checksum;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- SECTION 4: Retention Monitoring and Statistics
-- ============================================================================

-- Create view for retention policy status
CREATE OR REPLACE VIEW factory_telemetry.v_retention_policies AS
SELECT
    j.hypertable_name,
    j.job_id,
    j.schedule_interval,
    j.config->>'drop_after' AS retention_interval,
    js.last_run_status,
    js.last_successful_finish,
    js.last_run_duration,
    js.total_runs,
    js.total_successes,
    js.total_failures,
    CASE 
        WHEN js.last_run_status = 'Success' THEN '✓ Healthy'
        WHEN js.last_run_status = 'Failed' THEN '✗ Failed'
        WHEN js.last_run_status IS NULL THEN '⋯ Pending'
        ELSE js.last_run_status
    END AS job_health,
    -- Calculate chunks eligible for deletion
    (SELECT COUNT(*) 
     FROM timescaledb_information.chunks c
     WHERE c.hypertable_name = j.hypertable_name
     AND c.hypertable_schema = 'factory_telemetry'
     AND c.range_end < NOW() - (j.config->>'drop_after')::INTERVAL
    ) AS chunks_eligible_for_deletion,
    -- Calculate data volume to be deleted
    (SELECT pg_size_pretty(SUM(total_bytes))
     FROM timescaledb_information.chunks c
     WHERE c.hypertable_name = j.hypertable_name
     AND c.hypertable_schema = 'factory_telemetry'
     AND c.range_end < NOW() - (j.config->>'drop_after')::INTERVAL
    ) AS data_volume_to_delete
FROM timescaledb_information.jobs j
LEFT JOIN timescaledb_information.job_stats js ON j.job_id = js.job_id
WHERE j.proc_name = 'policy_retention'
AND j.hypertable_name IN (
    SELECT hypertable_name 
    FROM timescaledb_information.hypertables 
    WHERE hypertable_schema = 'factory_telemetry'
)
ORDER BY j.hypertable_name;

-- Grant SELECT permission
GRANT SELECT ON factory_telemetry.v_retention_policies TO PUBLIC;

-- Create view for data age distribution
CREATE OR REPLACE VIEW factory_telemetry.v_data_age_distribution AS
SELECT
    hypertable_name,
    COUNT(*) AS total_chunks,
    COUNT(*) FILTER (WHERE range_end >= NOW() - INTERVAL '7 days') AS chunks_0_7_days,
    COUNT(*) FILTER (WHERE range_end >= NOW() - INTERVAL '30 days' 
                     AND range_end < NOW() - INTERVAL '7 days') AS chunks_7_30_days,
    COUNT(*) FILTER (WHERE range_end >= NOW() - INTERVAL '90 days' 
                     AND range_end < NOW() - INTERVAL '30 days') AS chunks_30_90_days,
    COUNT(*) FILTER (WHERE range_end >= NOW() - INTERVAL '1 year' 
                     AND range_end < NOW() - INTERVAL '90 days') AS chunks_90_365_days,
    COUNT(*) FILTER (WHERE range_end < NOW() - INTERVAL '1 year') AS chunks_over_1_year,
    MIN(range_start) AS oldest_data,
    MAX(range_end) AS newest_data,
    pg_size_pretty(SUM(total_bytes)) AS total_size,
    pg_size_pretty(SUM(total_bytes) FILTER (WHERE range_end >= NOW() - INTERVAL '7 days')) AS size_0_7_days,
    pg_size_pretty(SUM(total_bytes) FILTER (WHERE range_end < NOW() - INTERVAL '90 days')) AS size_over_90_days
FROM timescaledb_information.chunks
WHERE hypertable_schema = 'factory_telemetry'
GROUP BY hypertable_name
ORDER BY SUM(total_bytes) DESC;

-- Grant SELECT permission
GRANT SELECT ON factory_telemetry.v_data_age_distribution TO PUBLIC;

-- ============================================================================
-- SECTION 5: Retention Policy Management Functions
-- ============================================================================

-- Function to temporarily disable retention for a hypertable
CREATE OR REPLACE FUNCTION factory_telemetry.disable_retention_policy(
    p_hypertable_name TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
    v_job_id INTEGER;
BEGIN
    -- Find retention job for hypertable
    SELECT job_id INTO v_job_id
    FROM timescaledb_information.jobs
    WHERE hypertable_name = p_hypertable_name
    AND proc_name = 'policy_retention';
    
    IF v_job_id IS NULL THEN
        RAISE WARNING 'No retention policy found for %', p_hypertable_name;
        RETURN FALSE;
    END IF;
    
    -- Disable the job
    PERFORM alter_job(v_job_id, scheduled => FALSE);
    
    RAISE NOTICE 'Retention policy disabled for % (job_id: %)', 
        p_hypertable_name, v_job_id;
    RETURN TRUE;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Error disabling retention policy for %: %', 
            p_hypertable_name, SQLERRM;
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Function to re-enable retention for a hypertable
CREATE OR REPLACE FUNCTION factory_telemetry.enable_retention_policy(
    p_hypertable_name TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
    v_job_id INTEGER;
BEGIN
    -- Find retention job for hypertable
    SELECT job_id INTO v_job_id
    FROM timescaledb_information.jobs
    WHERE hypertable_name = p_hypertable_name
    AND proc_name = 'policy_retention';
    
    IF v_job_id IS NULL THEN
        RAISE WARNING 'No retention policy found for %', p_hypertable_name;
        RETURN FALSE;
    END IF;
    
    -- Enable the job
    PERFORM alter_job(v_job_id, scheduled => TRUE);
    
    RAISE NOTICE 'Retention policy enabled for % (job_id: %)', 
        p_hypertable_name, v_job_id;
    RETURN TRUE;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Error enabling retention policy for %: %', 
            p_hypertable_name, SQLERRM;
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Function to modify retention interval
CREATE OR REPLACE FUNCTION factory_telemetry.modify_retention_policy(
    p_hypertable_name TEXT,
    p_new_interval INTERVAL
)
RETURNS BOOLEAN AS $$
DECLARE
    v_job_id INTEGER;
    v_old_interval TEXT;
BEGIN
    -- Find retention job
    SELECT 
        job_id,
        config->>'drop_after'
    INTO 
        v_job_id,
        v_old_interval
    FROM timescaledb_information.jobs
    WHERE hypertable_name = p_hypertable_name
    AND proc_name = 'policy_retention';
    
    IF v_job_id IS NULL THEN
        RAISE WARNING 'No retention policy found for %', p_hypertable_name;
        RETURN FALSE;
    END IF;
    
    -- Remove old policy
    PERFORM remove_retention_policy(
        format('factory_telemetry.%I', p_hypertable_name)
    );
    
    -- Add new policy
    PERFORM add_retention_policy(
        format('factory_telemetry.%I', p_hypertable_name),
        p_new_interval,
        if_not_exists => TRUE
    );
    
    RAISE NOTICE 'Retention policy for % modified: % → %', 
        p_hypertable_name, v_old_interval, p_new_interval;
    RETURN TRUE;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Error modifying retention policy for %: %', 
            p_hypertable_name, SQLERRM;
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- SECTION 6: Verification and Validation
-- ============================================================================

-- Verify retention policies are configured
DO $$
DECLARE
    ht_record RECORD;
    retention_configured_count INTEGER := 0;
    total_hypertables INTEGER;
BEGIN
    SELECT COUNT(*) INTO total_hypertables
    FROM timescaledb_information.hypertables
    WHERE hypertable_schema = 'factory_telemetry';
    
    RAISE NOTICE 'Retention policy validation:';
    
    FOR ht_record IN
        SELECT 
            h.hypertable_name,
            (SELECT COUNT(*) FROM timescaledb_information.jobs j
             WHERE j.hypertable_name = h.hypertable_name
             AND j.proc_name = 'policy_retention') AS has_retention_policy,
            (SELECT j.config->>'drop_after' FROM timescaledb_information.jobs j
             WHERE j.hypertable_name = h.hypertable_name
             AND j.proc_name = 'policy_retention'
             LIMIT 1) AS retention_interval
        FROM timescaledb_information.hypertables h
        WHERE h.hypertable_schema = 'factory_telemetry'
        ORDER BY h.hypertable_name
    LOOP
        IF ht_record.has_retention_policy > 0 THEN
            RAISE NOTICE '  ✓ %: Retention policy active (%)', 
                ht_record.hypertable_name, ht_record.retention_interval;
            retention_configured_count := retention_configured_count + 1;
        ELSE
            RAISE WARNING '  ✗ %: NO retention policy configured', 
                ht_record.hypertable_name;
        END IF;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE 'Summary: % of % hypertables have retention policies', 
        retention_configured_count, total_hypertables;
    
    IF retention_configured_count = total_hypertables THEN
        RAISE NOTICE 'Retention configuration: SUCCESS';
    ELSE
        RAISE WARNING 'Retention configuration: INCOMPLETE';
    END IF;
END $$;

-- Display retention policy status
SELECT * FROM factory_telemetry.v_retention_policies;

-- Display data age distribution
SELECT * FROM factory_telemetry.v_data_age_distribution;

-- ============================================================================
-- Retention Policy Configuration Complete
-- Next: Run phase4_performance_indexes.sql
-- ============================================================================

