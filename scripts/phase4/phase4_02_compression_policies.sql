-- ============================================================================
-- MS5.0 Phase 4: TimescaleDB Compression Policies
-- ============================================================================
-- Purpose: Enable and configure compression policies to reduce storage
--          footprint while maintaining query performance. Compression
--          achieves 70-95% reduction in disk usage for time-series data.
--
-- Design Philosophy: Compression is a one-way time machine. Recent data
--                    stays hot and mutable; aged data becomes immutable
--                    and compressed. Like ship logs: recent entries are
--                    working documents, archives are sealed and compact.
--
-- Compression Strategy:
--   - Segment by dimension columns (equipment_code, line_id, etc.)
--   - Order by time descending for optimal decompression
--   - Compress data after it's no longer actively modified
-- ============================================================================

\set ON_ERROR_STOP on
\timing on

-- ----------------------------------------------------------------------------
-- Section 1: Enable Compression on Hypertables
-- ----------------------------------------------------------------------------

-- Metric history: Compress by metric definition, order by time
-- Rationale: Each metric streams independently; time-ordering enables
--            efficient range decompression for dashboard queries
ALTER TABLE factory_telemetry.metric_hist SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'metric_def_id',
    timescaledb.compress_orderby = 'ts DESC'
);

RAISE NOTICE 'Enabled compression on metric_hist (segmentby: metric_def_id)';

-- OEE calculations: Compress by line and equipment
-- Rationale: OEE queries typically filter by production line or equipment;
--            segmenting by both enables parallel decompression
ALTER TABLE factory_telemetry.oee_calculations SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'line_id, equipment_code',
    timescaledb.compress_orderby = 'calculation_time DESC'
);

RAISE NOTICE 'Enabled compression on oee_calculations (segmentby: line_id, equipment_code)';

-- Energy consumption: Compress by equipment
-- Rationale: Energy analysis is equipment-centric; single segment key
--            simplifies queries and compression management
ALTER TABLE factory_telemetry.energy_consumption SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'equipment_code',
    timescaledb.compress_orderby = 'consumption_time DESC'
);

RAISE NOTICE 'Enabled compression on energy_consumption (segmentby: equipment_code)';

-- Production KPIs: Compress by line
-- Rationale: KPIs roll up to production line level; line-based segmentation
--            aligns with reporting and analytics access patterns
ALTER TABLE factory_telemetry.production_kpis SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'line_id',
    timescaledb.compress_orderby = 'created_at DESC'
);

RAISE NOTICE 'Enabled compression on production_kpis (segmentby: line_id)';

-- Production context history: Compress by equipment
-- Rationale: Context changes are equipment-specific audit trails
ALTER TABLE factory_telemetry.production_context_history SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'equipment_code',
    timescaledb.compress_orderby = 'changed_at DESC'
);

RAISE NOTICE 'Enabled compression on production_context_history (segmentby: equipment_code)';

-- ----------------------------------------------------------------------------
-- Section 2: Add Compression Policies
-- ----------------------------------------------------------------------------
-- Compression policies automatically compress chunks after they age beyond
-- the specified interval. This maintains a "hot" window of uncompressed
-- data for writes and recent queries.
--
-- Policy intervals are chosen based on:
--   - Write patterns (when does data stop being modified?)
--   - Query patterns (how far back do real-time queries reach?)
--   - Operational needs (alerting, live dashboards, recent trends)
-- ----------------------------------------------------------------------------

-- Metric history: Compress after 7 days
-- Rationale: Real-time dashboards query last 24-48 hours; weekly trends
--            can tolerate decompression overhead; 7 days balances
--            operational flexibility with storage efficiency
SELECT add_compression_policy(
    'factory_telemetry.metric_hist', 
    INTERVAL '7 days',
    if_not_exists => TRUE
);

RAISE NOTICE 'Added compression policy for metric_hist: compress after 7 days';

-- OEE calculations: Compress after 7 days
-- Rationale: Weekly OEE reports need fast access; monthly reports can
--            decompress. Aligns with typical reporting cycles.
SELECT add_compression_policy(
    'factory_telemetry.oee_calculations', 
    INTERVAL '7 days',
    if_not_exists => TRUE
);

RAISE NOTICE 'Added compression policy for oee_calculations: compress after 7 days';

-- Energy consumption: Compress after 14 days
-- Rationale: Energy analysis often spans 2-4 week periods; 14-day window
--            ensures recent trend analysis remains fast
SELECT add_compression_policy(
    'factory_telemetry.energy_consumption', 
    INTERVAL '14 days',
    if_not_exists => TRUE
);

RAISE NOTICE 'Added compression policy for energy_consumption: compress after 14 days';

-- Production KPIs: Compress after 7 days
-- Rationale: Daily/weekly KPI tracking needs uncompressed access; monthly
--            and quarterly reports can tolerate decompression
SELECT add_compression_policy(
    'factory_telemetry.production_kpis', 
    INTERVAL '7 days',
    if_not_exists => TRUE
);

RAISE NOTICE 'Added compression policy for production_kpis: compress after 7 days';

-- Production context history: Compress after 30 days
-- Rationale: Context history is append-only audit trail; recent month
--            for operational queries, older data for compliance
SELECT add_compression_policy(
    'factory_telemetry.production_context_history', 
    INTERVAL '30 days',
    if_not_exists => TRUE
);

RAISE NOTICE 'Added compression policy for production_context_history: compress after 30 days';

-- ----------------------------------------------------------------------------
-- Section 3: Compression Job Configuration
-- ----------------------------------------------------------------------------

-- Configure compression job scheduling
-- Default: Runs every day, processes chunks eligible for compression
-- Can be adjusted based on system load patterns

SELECT alter_job(
    job_id,
    schedule_interval => INTERVAL '12 hours',  -- Run twice daily
    max_runtime => INTERVAL '4 hours',         -- Prevent runaway jobs
    retry_period => INTERVAL '1 hour'          -- Retry failed compressions
)
FROM timescaledb_information.jobs
WHERE proc_name = 'policy_compression'
  AND hypertable_name IN (
      'metric_hist',
      'oee_calculations', 
      'energy_consumption',
      'production_kpis',
      'production_context_history'
  );

RAISE NOTICE 'Configured compression jobs: 12-hour intervals, 4-hour max runtime';

-- ----------------------------------------------------------------------------
-- Section 4: Display Compression Configuration
-- ----------------------------------------------------------------------------

-- Show compression settings for all hypertables
SELECT 
    h.hypertable_name,
    h.compression_enabled,
    pg_size_pretty(
        pg_total_relation_size(format('%I.%I', h.hypertable_schema, h.hypertable_name)::regclass)
    ) AS total_size,
    (
        SELECT string_agg(attname, ', ' ORDER BY attname)
        FROM pg_attribute
        WHERE attrelid = format('%I.%I', h.hypertable_schema, h.hypertable_name)::regclass
          AND attname = ANY(
              SELECT unnest(compress_segmentby)
              FROM _timescaledb_catalog.hypertable ht
              WHERE ht.id = h.hypertable_id
          )
    ) AS segment_by_columns,
    (
        SELECT string_agg(attname || ' ' || orderby_desc, ', ' ORDER BY orderby_index)
        FROM (
            SELECT 
                attname,
                CASE WHEN orderby_desc THEN 'DESC' ELSE 'ASC' END AS orderby_desc,
                orderby_index
            FROM _timescaledb_catalog.hypertable ht
            JOIN _timescaledb_catalog.dimension d ON d.hypertable_id = ht.id
            JOIN pg_attribute a ON a.attrelid = format('%I.%I', h.hypertable_schema, h.hypertable_name)::regclass
                AND a.attnum = ANY(orderby)
            WHERE ht.id = h.hypertable_id
        ) sub
    ) AS order_by_columns
FROM timescaledb_information.hypertables h
WHERE h.hypertable_schema = 'factory_telemetry'
ORDER BY h.hypertable_name;

-- Show active compression policies
SELECT 
    j.hypertable_name,
    j.schedule_interval,
    j.config->>'compress_after' AS compress_after_interval,
    j.max_runtime,
    j.next_start
FROM timescaledb_information.jobs j
WHERE j.proc_name = 'policy_compression'
  AND j.hypertable_schema = 'factory_telemetry'
ORDER BY j.hypertable_name;

-- ----------------------------------------------------------------------------
-- Section 5: Initial Manual Compression (Optional)
-- ----------------------------------------------------------------------------
-- Compress existing chunks that fall within the policy window
-- This brings the database to the desired compression state immediately
-- rather than waiting for the policy jobs to run

DO $$
DECLARE
    v_chunk_count INTEGER;
BEGIN
    -- Count and compress eligible chunks for metric_hist
    SELECT COUNT(*) INTO v_chunk_count
    FROM timescaledb_information.chunks
    WHERE hypertable_name = 'metric_hist'
      AND range_end < NOW() - INTERVAL '7 days'
      AND NOT is_compressed;
    
    IF v_chunk_count > 0 THEN
        RAISE NOTICE 'Manually compressing % eligible metric_hist chunks...', v_chunk_count;
        PERFORM compress_chunk(c.chunk_schema || '.' || c.chunk_name)
        FROM timescaledb_information.chunks c
        WHERE c.hypertable_name = 'metric_hist'
          AND c.range_end < NOW() - INTERVAL '7 days'
          AND NOT c.is_compressed;
        RAISE NOTICE 'Compressed % metric_hist chunks', v_chunk_count;
    END IF;
    
    -- Repeat for other tables if needed
    -- (Commented out to avoid long-running operations; enable if desired)
    
    /*
    SELECT COUNT(*) INTO v_chunk_count
    FROM timescaledb_information.chunks
    WHERE hypertable_name = 'oee_calculations'
      AND range_end < NOW() - INTERVAL '7 days'
      AND NOT is_compressed;
    
    IF v_chunk_count > 0 THEN
        PERFORM compress_chunk(c.chunk_schema || '.' || c.chunk_name)
        FROM timescaledb_information.chunks c
        WHERE c.hypertable_name = 'oee_calculations'
          AND c.range_end < NOW() - INTERVAL '7 days'
          AND NOT c.is_compressed;
        RAISE NOTICE 'Compressed % oee_calculations chunks', v_chunk_count;
    END IF;
    */
    
END $$;

-- ----------------------------------------------------------------------------
-- Section 6: Completion Summary
-- ----------------------------------------------------------------------------

DO $$
DECLARE
    v_summary TEXT;
BEGIN
    SELECT string_agg(
        format('  • %s: compression %s, policy %s',
            hypertable_name,
            CASE WHEN compression_enabled THEN 'enabled' ELSE 'disabled' END,
            (SELECT 'active (' || (config->>'compress_after') || ')'
             FROM timescaledb_information.jobs j
             WHERE j.hypertable_name = h.hypertable_name
               AND j.proc_name = 'policy_compression'
             LIMIT 1)
        ),
        E'\n'
        ORDER BY hypertable_name
    ) INTO v_summary
    FROM timescaledb_information.hypertables h
    WHERE hypertable_schema = 'factory_telemetry';
    
    RAISE NOTICE E'\n=== Phase 4.2 Compression Policies Complete ===\n%', v_summary;
END $$;

\echo '✓ Compression policies configured successfully'
