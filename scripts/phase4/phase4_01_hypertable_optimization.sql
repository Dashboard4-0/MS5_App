-- ============================================================================
-- MS5.0 Phase 4: TimescaleDB Hypertable Optimization
-- ============================================================================
-- Purpose: Configure optimal chunk intervals and hypertable settings for
--          time-series data tables to maximize query performance and
--          storage efficiency.
--
-- Design Philosophy: Each configuration is calculated based on:
--   - Data ingestion rate (samples/second)
--   - Query patterns (real-time vs historical analysis)
--   - Compression effectiveness (chunk size vs compression ratio)
--   - Memory constraints (chunk cache optimization)
--
-- Starship Principle: Like a ship's sensor array, data flows in continuous
--                     streams. Chunks are time-windows that balance
--                     real-time access with historical compression.
-- ============================================================================

\set ON_ERROR_STOP on
\timing on

-- ----------------------------------------------------------------------------
-- Section 1: Pre-Optimization Validation
-- ----------------------------------------------------------------------------

DO $$
DECLARE
    v_extension_exists BOOLEAN;
    v_hypertable_count INTEGER;
    v_version TEXT;
BEGIN
    -- Verify TimescaleDB extension is installed
    SELECT EXISTS (
        SELECT 1 FROM pg_extension WHERE extname = 'timescaledb'
    ) INTO v_extension_exists;
    
    IF NOT v_extension_exists THEN
        RAISE EXCEPTION 'TimescaleDB extension not found. Cannot proceed with optimization.';
    END IF;
    
    -- Get TimescaleDB version
    SELECT extversion INTO v_version
    FROM pg_extension 
    WHERE extname = 'timescaledb';
    
    RAISE NOTICE 'TimescaleDB version: %', v_version;
    
    -- Count existing hypertables
    SELECT COUNT(*) INTO v_hypertable_count
    FROM timescaledb_information.hypertables
    WHERE schema_name = 'factory_telemetry';
    
    RAISE NOTICE 'Found % hypertables in factory_telemetry schema', v_hypertable_count;
END $$;

-- ----------------------------------------------------------------------------
-- Section 2: Chunk Time Interval Optimization
-- ----------------------------------------------------------------------------
-- Chunk sizing strategy:
--   - High-frequency data (metric_hist): 1 hour chunks
--     Rationale: ~1000 samples/sec × 3600s = 3.6M rows/chunk
--                Optimal for compression and recent data queries
--
--   - Medium-frequency aggregates (oee_calculations): 1 day chunks
--     Rationale: Calculated every 5-60 minutes, ~288-1440 rows/day
--                Balances compression with analytical queries
--
--   - Low-frequency data (energy, kpis, context): 1 day chunks
--     Rationale: Hourly/daily samples, optimized for trend analysis
-- ----------------------------------------------------------------------------

-- Metric history: High-frequency telemetry data
SELECT set_chunk_time_interval(
    'factory_telemetry.metric_hist', 
    INTERVAL '1 hour',
    dimension_name => 'ts'
);

RAISE NOTICE 'Configured metric_hist chunk interval: 1 hour';

-- OEE calculations: Computed metrics
SELECT set_chunk_time_interval(
    'factory_telemetry.oee_calculations', 
    INTERVAL '1 day',
    dimension_name => 'calculation_time'
);

RAISE NOTICE 'Configured oee_calculations chunk interval: 1 day';

-- Energy consumption: Hourly/daily aggregates
SELECT set_chunk_time_interval(
    'factory_telemetry.energy_consumption', 
    INTERVAL '1 day',
    dimension_name => 'consumption_time'
);

RAISE NOTICE 'Configured energy_consumption chunk interval: 1 day';

-- Production KPIs: Daily/shift metrics
SELECT set_chunk_time_interval(
    'factory_telemetry.production_kpis', 
    INTERVAL '1 day',
    dimension_name => 'created_at'
);

RAISE NOTICE 'Configured production_kpis chunk interval: 1 day';

-- Production context history: Audit trail
SELECT set_chunk_time_interval(
    'factory_telemetry.production_context_history', 
    INTERVAL '1 day',
    dimension_name => 'changed_at'
);

RAISE NOTICE 'Configured production_context_history chunk interval: 1 day';

-- ----------------------------------------------------------------------------
-- Section 3: Chunk Statistics and Validation
-- ----------------------------------------------------------------------------

-- Display current chunk configuration
SELECT 
    hypertable_schema,
    hypertable_name,
    num_dimensions,
    num_chunks,
    compression_enabled,
    tablespaces
FROM timescaledb_information.hypertables
WHERE hypertable_schema = 'factory_telemetry'
ORDER BY hypertable_name;

-- Display chunk time intervals
SELECT 
    h.hypertable_name,
    d.column_name AS time_column,
    d.interval_length AS chunk_interval_microseconds,
    (d.interval_length / 1000000.0 / 3600.0)::NUMERIC(10,2) AS chunk_interval_hours
FROM timescaledb_information.dimensions d
JOIN timescaledb_information.hypertables h 
    ON h.hypertable_schema = d.hypertable_schema 
    AND h.hypertable_name = d.hypertable_name
WHERE h.hypertable_schema = 'factory_telemetry'
ORDER BY h.hypertable_name;

-- ----------------------------------------------------------------------------
-- Section 4: Memory and Performance Tuning
-- ----------------------------------------------------------------------------

-- Set target chunk size for optimal memory usage
-- Target: ~25% of available memory for chunk cache
-- Calculation: 8GB total * 0.25 = 2GB chunk cache
ALTER DATABASE factory_telemetry 
SET timescaledb.max_background_workers = 8;

-- Enable parallel query execution for large chunk scans
ALTER DATABASE factory_telemetry 
SET max_parallel_workers_per_gather = 4;

-- Optimize planner for time-series queries
ALTER DATABASE factory_telemetry 
SET random_page_cost = 1.1;  -- SSD-optimized

ALTER DATABASE factory_telemetry 
SET effective_cache_size = '6GB';  -- 75% of 8GB memory

RAISE NOTICE 'Database performance parameters optimized for TimescaleDB';

-- ----------------------------------------------------------------------------
-- Section 5: Vacuum and Statistics Configuration
-- ----------------------------------------------------------------------------

-- Configure autovacuum for hypertables
-- More aggressive settings for high-throughput metric_hist table
ALTER TABLE factory_telemetry.metric_hist SET (
    autovacuum_vacuum_scale_factor = 0.05,
    autovacuum_analyze_scale_factor = 0.02,
    autovacuum_vacuum_cost_delay = 10
);

-- Standard settings for moderate-frequency tables
ALTER TABLE factory_telemetry.oee_calculations SET (
    autovacuum_vacuum_scale_factor = 0.1,
    autovacuum_analyze_scale_factor = 0.05
);

ALTER TABLE factory_telemetry.energy_consumption SET (
    autovacuum_vacuum_scale_factor = 0.1,
    autovacuum_analyze_scale_factor = 0.05
);

ALTER TABLE factory_telemetry.production_kpis SET (
    autovacuum_vacuum_scale_factor = 0.1,
    autovacuum_analyze_scale_factor = 0.05
);

ALTER TABLE factory_telemetry.production_context_history SET (
    autovacuum_vacuum_scale_factor = 0.1,
    autovacuum_analyze_scale_factor = 0.05
);

RAISE NOTICE 'Autovacuum settings configured for all hypertables';

-- ----------------------------------------------------------------------------
-- Section 6: Completion Summary
-- ----------------------------------------------------------------------------

DO $$
DECLARE
    v_summary TEXT;
BEGIN
    SELECT string_agg(
        format('  • %s: %s chunks, %s compression',
            hypertable_name,
            num_chunks,
            CASE WHEN compression_enabled THEN 'enabled' ELSE 'disabled' END
        ),
        E'\n'
        ORDER BY hypertable_name
    ) INTO v_summary
    FROM timescaledb_information.hypertables
    WHERE hypertable_schema = 'factory_telemetry';
    
    RAISE NOTICE E'\n=== Phase 4.1 Hypertable Optimization Complete ===\n%', v_summary;
END $$;

-- Final analysis to update statistics
ANALYZE factory_telemetry.metric_hist;
ANALYZE factory_telemetry.oee_calculations;
ANALYZE factory_telemetry.energy_consumption;
ANALYZE factory_telemetry.production_kpis;
ANALYZE factory_telemetry.production_context_history;

\echo '✓ Hypertable optimization completed successfully'
