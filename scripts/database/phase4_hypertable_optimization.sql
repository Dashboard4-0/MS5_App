-- ============================================================================
-- MS5.0 Manufacturing System - Phase 4: TimescaleDB Hypertable Optimization
-- ============================================================================
-- This script configures optimal hypertable settings for all time-series
-- tables in the factory_telemetry schema. Each configuration is tuned based
-- on data characteristics and query patterns.
--
-- Target: Production-grade TimescaleDB deployment
-- Prerequisites: TimescaleDB extension installed
-- Execution: Run after all migrations (001-009) are complete
-- ============================================================================

-- Verify TimescaleDB extension is available
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_extension WHERE extname = 'timescaledb'
    ) THEN
        RAISE EXCEPTION 'TimescaleDB extension not found. Install before proceeding.';
    END IF;
    
    RAISE NOTICE 'TimescaleDB version: %', 
        (SELECT extversion FROM pg_extension WHERE extname = 'timescaledb');
END $$;

-- ============================================================================
-- SECTION 1: Hypertable Creation with Optimal Chunk Intervals
-- ============================================================================
-- Chunk intervals are optimized based on data ingestion rate and query patterns:
-- - High-frequency data (metric_hist): 1 hour chunks
-- - Medium-frequency data (oee_calculations, energy): 1 day chunks  
-- - Low-frequency data (kpis, downtime): 1 week chunks
-- ============================================================================

-- 1.1 High-Frequency Telemetry Data (metric_hist)
-- Expected rate: 100-1000 records/second across all metrics
-- Query pattern: Recent data (last hour to last day)
-- Chunk strategy: 1-hour chunks for optimal recent data access
SELECT create_hypertable(
    'factory_telemetry.metric_hist',
    'ts',
    chunk_time_interval => INTERVAL '1 hour',
    if_not_exists => TRUE,
    migrate_data => TRUE
);

-- Set number of partitions for parallel processing
-- Based on available CPU cores (typically 8-16 in production)
SELECT set_number_partitions('factory_telemetry.metric_hist', 4);

-- 1.2 OEE Calculations (oee_calculations)
-- Expected rate: ~10-100 records/minute
-- Query pattern: Hourly, daily, and shift-based aggregations
-- Chunk strategy: 1-day chunks for balanced performance
SELECT create_hypertable(
    'factory_telemetry.oee_calculations',
    'calculation_time',
    chunk_time_interval => INTERVAL '1 day',
    if_not_exists => TRUE,
    migrate_data => TRUE
);

-- 1.3 Energy Consumption (energy_consumption)
-- Expected rate: ~10-50 records/minute per equipment
-- Query pattern: Hourly and daily energy analysis
-- Chunk strategy: 1-day chunks for efficient aggregation
SELECT create_hypertable(
    'factory_telemetry.energy_consumption',
    'consumption_time',
    chunk_time_interval => INTERVAL '1 day',
    if_not_exists => TRUE,
    migrate_data => TRUE
);

-- 1.4 Production KPIs (production_kpis)
-- Expected rate: ~10-50 records/day
-- Query pattern: Daily, weekly, and monthly reporting
-- Chunk strategy: 7-day chunks for reporting efficiency
SELECT create_hypertable(
    'factory_telemetry.production_kpis',
    'created_at',
    chunk_time_interval => INTERVAL '7 days',
    if_not_exists => TRUE,
    migrate_data => TRUE
);

-- 1.5 Downtime Events (downtime_events)
-- Expected rate: ~5-20 events/day
-- Query pattern: Recent events and historical analysis
-- Chunk strategy: 7-day chunks for event analysis
SELECT create_hypertable(
    'factory_telemetry.downtime_events',
    'start_time',
    chunk_time_interval => INTERVAL '7 days',
    if_not_exists => TRUE,
    migrate_data => TRUE
);

-- 1.6 Quality Checks (quality_checks)
-- Expected rate: ~10-50 checks/day
-- Query pattern: Recent checks and trend analysis
-- Chunk strategy: 7-day chunks for quality trending
SELECT create_hypertable(
    'factory_telemetry.quality_checks',
    'check_time',
    chunk_time_interval => INTERVAL '7 days',
    if_not_exists => TRUE,
    migrate_data => TRUE
);

-- 1.7 Fault Events (fault_event)
-- Expected rate: ~10-100 events/hour during active faults
-- Query pattern: Recent faults and historical patterns
-- Chunk strategy: 1-day chunks for fault analysis
SELECT create_hypertable(
    'factory_telemetry.fault_event',
    'ts_on',
    chunk_time_interval => INTERVAL '1 day',
    if_not_exists => TRUE,
    migrate_data => TRUE
);

-- ============================================================================
-- SECTION 2: Advanced Chunk Tuning
-- ============================================================================
-- Fine-tune chunk time intervals based on actual data volume
-- These can be adjusted post-deployment based on monitoring
-- ============================================================================

-- Adjust metric_hist chunk interval if data volume is extreme
-- Uncomment and adjust if ingestion exceeds 10,000 records/second
-- SELECT set_chunk_time_interval('factory_telemetry.metric_hist', INTERVAL '30 minutes');

-- ============================================================================
-- SECTION 3: Chunk Statistics and Monitoring
-- ============================================================================

-- Create view for chunk health monitoring
CREATE OR REPLACE VIEW factory_telemetry.v_chunk_statistics AS
SELECT
    hypertable_schema,
    hypertable_name,
    num_chunks,
    num_dimensions,
    total_size_bytes,
    pg_size_pretty(total_size_bytes) AS total_size,
    total_size_bytes / NULLIF(num_chunks, 0) AS avg_chunk_size_bytes,
    pg_size_pretty(total_size_bytes / NULLIF(num_chunks, 0)) AS avg_chunk_size,
    compression_enabled,
    CASE 
        WHEN compression_enabled THEN 
            (SELECT COUNT(*) FROM timescaledb_information.chunks 
             WHERE hypertable_name = h.hypertable_name 
             AND is_compressed = TRUE)
        ELSE 0
    END AS compressed_chunks,
    CASE 
        WHEN compression_enabled THEN 
            ROUND(100.0 * (SELECT COUNT(*) FROM timescaledb_information.chunks 
                          WHERE hypertable_name = h.hypertable_name 
                          AND is_compressed = TRUE) / NULLIF(num_chunks, 0), 2)
        ELSE 0
    END AS compression_percentage
FROM timescaledb_information.hypertables h
WHERE hypertable_schema = 'factory_telemetry'
ORDER BY total_size_bytes DESC;

-- Grant SELECT permission on the view
GRANT SELECT ON factory_telemetry.v_chunk_statistics TO PUBLIC;

-- ============================================================================
-- SECTION 4: Verification and Validation
-- ============================================================================

-- Verify all hypertables are created successfully
DO $$
DECLARE
    expected_hypertables TEXT[] := ARRAY[
        'metric_hist',
        'oee_calculations',
        'energy_consumption',
        'production_kpis',
        'downtime_events',
        'quality_checks',
        'fault_event'
    ];
    actual_count INTEGER;
    ht TEXT;
BEGIN
    SELECT COUNT(*) INTO actual_count
    FROM timescaledb_information.hypertables
    WHERE hypertable_schema = 'factory_telemetry';
    
    RAISE NOTICE 'Hypertable creation validation:';
    RAISE NOTICE '  Expected: % hypertables', array_length(expected_hypertables, 1);
    RAISE NOTICE '  Actual: % hypertables', actual_count;
    
    -- Verify each expected hypertable
    FOREACH ht IN ARRAY expected_hypertables
    LOOP
        IF EXISTS (
            SELECT 1 FROM timescaledb_information.hypertables
            WHERE hypertable_schema = 'factory_telemetry'
            AND hypertable_name = ht
        ) THEN
            RAISE NOTICE '  ✓ % configured', ht;
        ELSE
            RAISE WARNING '  ✗ % NOT FOUND', ht;
        END IF;
    END LOOP;
    
    IF actual_count = array_length(expected_hypertables, 1) THEN
        RAISE NOTICE 'Hypertable optimization: SUCCESS';
    ELSE
        RAISE WARNING 'Hypertable optimization: INCOMPLETE';
    END IF;
END $$;

-- Display chunk statistics
SELECT * FROM factory_telemetry.v_chunk_statistics;

-- ============================================================================
-- Optimization Complete
-- Next: Run phase4_compression_policies.sql
-- ============================================================================

