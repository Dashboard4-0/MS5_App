-- ============================================================================
-- MS5.0 Manufacturing System - Phase 4: Compression Policy Configuration
-- ============================================================================
-- This script implements intelligent compression policies to achieve 70%+
-- compression ratios while maintaining query performance. Compression is
-- configured per table based on data access patterns and storage requirements.
--
-- Compression Strategy:
-- - Recent data (hot): Uncompressed for fast writes and updates
-- - Historical data (warm): Compressed for storage efficiency
-- - Archive data (cold): Heavily compressed, rarely accessed
--
-- Expected Results:
-- - 70-85% compression ratio for metric_hist
-- - 60-75% compression ratio for OEE and energy data
-- - 50-65% compression ratio for event data
-- ============================================================================

-- ============================================================================
-- SECTION 1: Enable Compression with Optimal Settings
-- ============================================================================
-- Compression is configured with segment_by and order_by clauses to maximize
-- compression ratio while preserving query performance for common access patterns
-- ============================================================================

-- 1.1 High-Frequency Telemetry Data (metric_hist)
-- Segment by metric_def_id: Groups similar metrics together
-- Order by ts DESC: Optimizes for recent-data queries
ALTER TABLE factory_telemetry.metric_hist SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'metric_def_id',
    timescaledb.compress_orderby = 'ts DESC'
);

-- 1.2 OEE Calculations
-- Segment by line_id and equipment_code: Groups by production line
-- Order by calculation_time DESC: Optimizes for recent calculations
ALTER TABLE factory_telemetry.oee_calculations SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'line_id, equipment_code',
    timescaledb.compress_orderby = 'calculation_time DESC'
);

-- 1.3 Energy Consumption
-- Segment by equipment_code: Groups by equipment
-- Order by consumption_time DESC: Optimizes for recent energy queries
ALTER TABLE factory_telemetry.energy_consumption SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'equipment_code',
    timescaledb.compress_orderby = 'consumption_time DESC'
);

-- 1.4 Production KPIs
-- Segment by line_id and shift_id: Groups by line and shift
-- Order by kpi_date DESC: Optimizes for recent KPI queries
ALTER TABLE factory_telemetry.production_kpis SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'line_id, shift_id',
    timescaledb.compress_orderby = 'kpi_date DESC, created_at DESC'
);

-- 1.5 Downtime Events
-- Segment by line_id and category: Groups by line and downtime type
-- Order by start_time DESC: Optimizes for recent event queries
ALTER TABLE factory_telemetry.downtime_events SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'line_id, category',
    timescaledb.compress_orderby = 'start_time DESC'
);

-- 1.6 Quality Checks
-- Segment by line_id and check_type: Groups by line and check type
-- Order by check_time DESC: Optimizes for recent quality queries
ALTER TABLE factory_telemetry.quality_checks SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'line_id, check_type',
    timescaledb.compress_orderby = 'check_time DESC'
);

-- 1.7 Fault Events
-- Segment by equipment_code: Groups by equipment
-- Order by ts_on DESC: Optimizes for recent fault queries
ALTER TABLE factory_telemetry.fault_event SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'equipment_code',
    timescaledb.compress_orderby = 'ts_on DESC'
);

-- ============================================================================
-- SECTION 2: Automatic Compression Policies
-- ============================================================================
-- Policies automatically compress chunks after data becomes "warm"
-- Compression thresholds are set based on typical data access patterns:
-- - Hot data: Actively written, frequently queried (uncompressed)
-- - Warm data: Read-only, occasionally queried (compressed)
-- - Cold data: Archived, rarely queried (compressed)
-- ============================================================================

-- 2.1 High-Frequency Telemetry (compress after 7 days)
-- Recent week: Kept uncompressed for active monitoring and updates
-- Older data: Compressed for storage efficiency
SELECT add_compression_policy(
    'factory_telemetry.metric_hist',
    INTERVAL '7 days',
    if_not_exists => TRUE
);

-- 2.2 OEE Calculations (compress after 7 days)
-- Recent week: Active for shift reports and daily analysis
-- Historical: Compressed for trend analysis
SELECT add_compression_policy(
    'factory_telemetry.oee_calculations',
    INTERVAL '7 days',
    if_not_exists => TRUE
);

-- 2.3 Energy Consumption (compress after 7 days)
-- Recent week: Active for energy monitoring
-- Historical: Compressed for trend analysis
SELECT add_compression_policy(
    'factory_telemetry.energy_consumption',
    INTERVAL '7 days',
    if_not_exists => TRUE
);

-- 2.4 Production KPIs (compress after 14 days)
-- Recent two weeks: Active for reporting
-- Historical: Compressed for long-term analysis
SELECT add_compression_policy(
    'factory_telemetry.production_kpis',
    INTERVAL '14 days',
    if_not_exists => TRUE
);

-- 2.5 Downtime Events (compress after 30 days)
-- Recent month: Active for downtime analysis
-- Historical: Compressed for trend analysis
SELECT add_compression_policy(
    'factory_telemetry.downtime_events',
    INTERVAL '30 days',
    if_not_exists => TRUE
);

-- 2.6 Quality Checks (compress after 30 days)
-- Recent month: Active for quality tracking
-- Historical: Compressed for compliance records
SELECT add_compression_policy(
    'factory_telemetry.quality_checks',
    INTERVAL '30 days',
    if_not_exists => TRUE
);

-- 2.7 Fault Events (compress after 14 days)
-- Recent two weeks: Active for fault analysis
-- Historical: Compressed for pattern analysis
SELECT add_compression_policy(
    'factory_telemetry.fault_event',
    INTERVAL '14 days',
    if_not_exists => TRUE
);

-- ============================================================================
-- SECTION 3: Compression Monitoring and Statistics
-- ============================================================================

-- Create comprehensive compression statistics view
CREATE OR REPLACE VIEW factory_telemetry.v_compression_statistics AS
WITH chunk_stats AS (
    SELECT
        hypertable_name,
        chunk_name,
        is_compressed,
        uncompressed_heap_size,
        uncompressed_index_size,
        uncompressed_toast_size,
        uncompressed_total_bytes,
        compressed_heap_size,
        compressed_index_size,
        compressed_toast_size,
        compressed_total_bytes
    FROM timescaledb_information.chunks c
    LEFT JOIN timescaledb_information.compression_settings cs
        ON c.hypertable_name = cs.hypertable_name
    WHERE c.hypertable_schema = 'factory_telemetry'
)
SELECT
    hypertable_name,
    COUNT(*) AS total_chunks,
    COUNT(*) FILTER (WHERE is_compressed) AS compressed_chunks,
    COUNT(*) FILTER (WHERE NOT is_compressed) AS uncompressed_chunks,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE is_compressed) / NULLIF(COUNT(*), 0),
        2
    ) AS compression_percentage,
    pg_size_pretty(SUM(uncompressed_total_bytes)) AS total_uncompressed_size,
    pg_size_pretty(SUM(compressed_total_bytes)) AS total_compressed_size,
    pg_size_pretty(
        SUM(COALESCE(uncompressed_total_bytes, 0)) - 
        SUM(COALESCE(compressed_total_bytes, 0))
    ) AS space_saved,
    CASE 
        WHEN SUM(compressed_total_bytes) > 0 THEN
            ROUND(
                100.0 * (1 - (SUM(compressed_total_bytes)::NUMERIC / 
                NULLIF(SUM(uncompressed_total_bytes), 0))),
                2
            )
        ELSE 0
    END AS compression_ratio_percent
FROM chunk_stats
GROUP BY hypertable_name
ORDER BY SUM(uncompressed_total_bytes) DESC;

-- Grant SELECT permission
GRANT SELECT ON factory_telemetry.v_compression_statistics TO PUBLIC;

-- Create view for compression job status
CREATE OR REPLACE VIEW factory_telemetry.v_compression_jobs AS
SELECT
    j.hypertable_name,
    j.job_id,
    j.schedule_interval,
    j.max_runtime,
    j.next_start,
    j.config->>'compress_after' AS compress_after_interval,
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
    END AS job_health
FROM timescaledb_information.jobs j
LEFT JOIN timescaledb_information.job_stats js ON j.job_id = js.job_id
WHERE j.proc_name = 'policy_compression'
AND j.hypertable_name IN (
    SELECT hypertable_name 
    FROM timescaledb_information.hypertables 
    WHERE hypertable_schema = 'factory_telemetry'
)
ORDER BY j.hypertable_name;

-- Grant SELECT permission
GRANT SELECT ON factory_telemetry.v_compression_jobs TO PUBLIC;

-- ============================================================================
-- SECTION 4: Manual Compression Functions
-- ============================================================================
-- These functions allow manual compression control for specific scenarios
-- ============================================================================

-- Function to manually compress a specific chunk
CREATE OR REPLACE FUNCTION factory_telemetry.compress_chunk_manual(
    chunk_name TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
    compression_result BOOLEAN;
BEGIN
    -- Compress the specified chunk
    PERFORM compress_chunk(chunk_name);
    
    -- Verify compression succeeded
    SELECT is_compressed INTO compression_result
    FROM timescaledb_information.chunks
    WHERE chunk_name = compress_chunk_manual.chunk_name;
    
    IF compression_result THEN
        RAISE NOTICE 'Chunk % compressed successfully', chunk_name;
        RETURN TRUE;
    ELSE
        RAISE WARNING 'Chunk % compression may have failed', chunk_name;
        RETURN FALSE;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Error compressing chunk %: %', chunk_name, SQLERRM;
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Function to manually decompress a specific chunk (for updates/deletes)
CREATE OR REPLACE FUNCTION factory_telemetry.decompress_chunk_manual(
    chunk_name TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
    decompression_result BOOLEAN;
BEGIN
    -- Decompress the specified chunk
    PERFORM decompress_chunk(chunk_name);
    
    -- Verify decompression succeeded
    SELECT NOT is_compressed INTO decompression_result
    FROM timescaledb_information.chunks
    WHERE chunk_name = decompress_chunk_manual.chunk_name;
    
    IF decompression_result THEN
        RAISE NOTICE 'Chunk % decompressed successfully', chunk_name;
        RETURN TRUE;
    ELSE
        RAISE WARNING 'Chunk % decompression may have failed', chunk_name;
        RETURN FALSE;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Error decompressing chunk %: %', chunk_name, SQLERRM;
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Function to compress all eligible chunks for a hypertable
CREATE OR REPLACE FUNCTION factory_telemetry.compress_all_eligible_chunks(
    table_name TEXT,
    older_than INTERVAL DEFAULT '7 days'
)
RETURNS TABLE(
    chunk_name TEXT,
    compressed BOOLEAN,
    size_before BIGINT,
    size_after BIGINT,
    compression_ratio NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    WITH chunks_to_compress AS (
        SELECT 
            c.chunk_name,
            c.range_end,
            c.uncompressed_total_bytes,
            c.is_compressed
        FROM timescaledb_information.chunks c
        WHERE c.hypertable_name = table_name
        AND c.hypertable_schema = 'factory_telemetry'
        AND c.is_compressed = FALSE
        AND c.range_end < NOW() - older_than
    ),
    compression_results AS (
        SELECT 
            ctc.chunk_name,
            TRUE AS compressed,
            ctc.uncompressed_total_bytes AS size_before,
            (SELECT compressed_total_bytes 
             FROM timescaledb_information.chunks 
             WHERE chunk_name = ctc.chunk_name) AS size_after
        FROM chunks_to_compress ctc
        WHERE (SELECT compress_chunk(ctc.chunk_name)) IS NOT NULL
    )
    SELECT 
        cr.chunk_name,
        cr.compressed,
        cr.size_before,
        cr.size_after,
        ROUND(
            100.0 * (1 - (cr.size_after::NUMERIC / NULLIF(cr.size_before, 0))),
            2
        ) AS compression_ratio
    FROM compression_results cr;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- SECTION 5: Verification and Validation
-- ============================================================================

-- Verify compression is enabled for all hypertables
DO $$
DECLARE
    ht_record RECORD;
    compression_enabled_count INTEGER := 0;
    total_hypertables INTEGER;
BEGIN
    SELECT COUNT(*) INTO total_hypertables
    FROM timescaledb_information.hypertables
    WHERE hypertable_schema = 'factory_telemetry';
    
    RAISE NOTICE 'Compression policy validation:';
    
    FOR ht_record IN
        SELECT 
            h.hypertable_name,
            h.compression_enabled,
            (SELECT COUNT(*) FROM timescaledb_information.jobs j
             WHERE j.hypertable_name = h.hypertable_name
             AND j.proc_name = 'policy_compression') AS has_compression_policy
        FROM timescaledb_information.hypertables h
        WHERE h.hypertable_schema = 'factory_telemetry'
        ORDER BY h.hypertable_name
    LOOP
        IF ht_record.compression_enabled AND ht_record.has_compression_policy > 0 THEN
            RAISE NOTICE '  ✓ %: Compression enabled with active policy', ht_record.hypertable_name;
            compression_enabled_count := compression_enabled_count + 1;
        ELSIF ht_record.compression_enabled THEN
            RAISE WARNING '  ⚠ %: Compression enabled but NO policy configured', ht_record.hypertable_name;
        ELSE
            RAISE WARNING '  ✗ %: Compression NOT enabled', ht_record.hypertable_name;
        END IF;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE 'Summary: % of % hypertables fully configured', 
        compression_enabled_count, total_hypertables;
    
    IF compression_enabled_count = total_hypertables THEN
        RAISE NOTICE 'Compression configuration: SUCCESS';
    ELSE
        RAISE WARNING 'Compression configuration: INCOMPLETE';
    END IF;
END $$;

-- Display compression statistics
SELECT * FROM factory_telemetry.v_compression_statistics;

-- Display compression job status
SELECT * FROM factory_telemetry.v_compression_jobs;

-- ============================================================================
-- Compression Configuration Complete
-- Next: Run phase4_retention_policies.sql
-- ============================================================================

