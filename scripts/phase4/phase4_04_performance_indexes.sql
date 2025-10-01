-- ============================================================================
-- MS5.0 Phase 4: TimescaleDB Performance Indexes
-- ============================================================================
-- Purpose: Create optimized indexes for time-series queries, balancing
--          query performance with write throughput and storage overhead.
--
-- Design Philosophy: Indexes are the nervous system's reflexes—fast paths
--                    for common operations. Each index must earn its keep
--                    through measurable query acceleration without unduly
--                    slowing writes or bloating storage.
--
-- Index Strategy:
--   - Time + Dimension: Most queries filter by time range + entity
--   - Covering Indexes: Include frequently selected columns
--   - BRIN for large tables: Block Range INdexes for time-ordered data
--   - Partial Indexes: Target specific query patterns
--   - DESC order: Match time-series query patterns (latest first)
-- ============================================================================

\set ON_ERROR_STOP on
\timing on

-- ----------------------------------------------------------------------------
-- Section 1: Pre-Index Analysis
-- ----------------------------------------------------------------------------

-- Analyze current index usage and table statistics
DO $$
DECLARE
    v_table_name TEXT;
    v_table_size TEXT;
    v_index_size TEXT;
    v_total_rows BIGINT;
BEGIN
    RAISE NOTICE E'\n=== Pre-Index Table Statistics ===';
    
    FOR v_table_name IN 
        SELECT tablename 
        FROM pg_tables 
        WHERE schemaname = 'factory_telemetry'
          AND tablename IN (
              'metric_hist',
              'oee_calculations',
              'energy_consumption',
              'production_kpis',
              'production_context_history'
          )
    LOOP
        EXECUTE format(
            'SELECT COUNT(*) FROM factory_telemetry.%I',
            v_table_name
        ) INTO v_total_rows;
        
        SELECT 
            pg_size_pretty(pg_total_relation_size('factory_telemetry.' || v_table_name)),
            pg_size_pretty(pg_indexes_size('factory_telemetry.' || v_table_name))
        INTO v_table_size, v_index_size;
        
        RAISE NOTICE '%: % rows, table: %, indexes: %',
            v_table_name, v_total_rows, v_table_size, v_index_size;
    END LOOP;
END $$;

-- ----------------------------------------------------------------------------
-- Section 2: Metric History Indexes
-- ----------------------------------------------------------------------------
-- Query patterns:
--   1. Latest values by metric: WHERE metric_def_id = ? ORDER BY ts DESC
--   2. Time range by metric: WHERE metric_def_id = ? AND ts BETWEEN ? AND ?
--   3. Recent data scan: WHERE ts > NOW() - INTERVAL '1 hour'
--   4. Metric + value filters: WHERE metric_def_id = ? AND value_real > ?
-- ----------------------------------------------------------------------------

-- Primary time-series index: metric + time descending
-- This is the workhorse index for dashboard queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_metric_hist_metric_ts_desc
ON factory_telemetry.metric_hist (metric_def_id, ts DESC)
INCLUDE (value_bool, value_int, value_real);

RAISE NOTICE 'Created metric_hist index: (metric_def_id, ts DESC) INCLUDE (values)';

-- Time-first index for time-range scans across all metrics
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_metric_hist_ts_desc
ON factory_telemetry.metric_hist (ts DESC);

RAISE NOTICE 'Created metric_hist index: (ts DESC)';

-- BRIN index for historical data (extremely space-efficient)
-- Effective for large tables with natural time-ordering
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_metric_hist_ts_brin
ON factory_telemetry.metric_hist USING BRIN (ts)
WITH (pages_per_range = 128);  -- Tune based on chunk size

RAISE NOTICE 'Created metric_hist BRIN index: (ts) for historical scans';

-- Partial index for real-time data (last 24 hours)
-- Dramatically speeds up live dashboard queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_metric_hist_realtime
ON factory_telemetry.metric_hist (metric_def_id, ts DESC)
WHERE ts > NOW() - INTERVAL '24 hours';

RAISE NOTICE 'Created metric_hist partial index: realtime (last 24 hours)';

-- ----------------------------------------------------------------------------
-- Section 3: OEE Calculations Indexes
-- ----------------------------------------------------------------------------
-- Query patterns:
--   1. Latest OEE by line: WHERE line_id = ? ORDER BY calculation_time DESC
--   2. Equipment OEE trend: WHERE equipment_code = ? AND calculation_time >= ?
--   3. Multi-line comparison: WHERE line_id IN (?,?) AND calculation_time >= ?
--   4. OEE threshold alerts: WHERE oee < ? AND calculation_time > ?
-- ----------------------------------------------------------------------------

-- Composite index: line + time descending
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_oee_line_time_desc
ON factory_telemetry.oee_calculations (line_id, calculation_time DESC)
INCLUDE (availability, performance, quality, oee);

RAISE NOTICE 'Created oee_calculations index: (line_id, calculation_time DESC)';

-- Equipment-focused index
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_oee_equipment_time_desc
ON factory_telemetry.oee_calculations (equipment_code, calculation_time DESC)
INCLUDE (oee, good_parts, total_parts);

RAISE NOTICE 'Created oee_calculations index: (equipment_code, calculation_time DESC)';

-- Time-first index for global OEE queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_oee_time_desc
ON factory_telemetry.oee_calculations (calculation_time DESC);

RAISE NOTICE 'Created oee_calculations index: (calculation_time DESC)';

-- Partial index for low OEE alerts (< 80%)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_oee_low_performance
ON factory_telemetry.oee_calculations (line_id, calculation_time DESC)
WHERE oee < 0.80;

RAISE NOTICE 'Created oee_calculations partial index: low performance (OEE < 80%)';

-- ----------------------------------------------------------------------------
-- Section 4: Energy Consumption Indexes
-- ----------------------------------------------------------------------------
-- Query patterns:
--   1. Equipment energy trend: WHERE equipment_code = ? AND consumption_time >= ?
--   2. Peak consumption analysis: WHERE consumption_kwh > ? ORDER BY consumption_time
--   3. Time-range aggregation: WHERE consumption_time BETWEEN ? AND ?
-- ----------------------------------------------------------------------------

-- Equipment + time index
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_energy_equipment_time_desc
ON factory_telemetry.energy_consumption (equipment_code, consumption_time DESC)
INCLUDE (consumption_kwh, peak_power_kw);

RAISE NOTICE 'Created energy_consumption index: (equipment_code, consumption_time DESC)';

-- Time-first index for global energy queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_energy_time_desc
ON factory_telemetry.energy_consumption (consumption_time DESC);

RAISE NOTICE 'Created energy_consumption index: (consumption_time DESC)';

-- Partial index for high consumption events (> 100 kWh)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_energy_high_consumption
ON factory_telemetry.energy_consumption (equipment_code, consumption_time DESC)
WHERE consumption_kwh > 100;

RAISE NOTICE 'Created energy_consumption partial index: high consumption (> 100 kWh)';

-- ----------------------------------------------------------------------------
-- Section 5: Production KPIs Indexes
-- ----------------------------------------------------------------------------
-- Query patterns:
--   1. Latest KPIs by line: WHERE line_id = ? ORDER BY created_at DESC
--   2. KPI trends: WHERE line_id = ? AND kpi_date >= ?
--   3. Cross-line comparison: WHERE kpi_date = ? ORDER BY line_id
-- ----------------------------------------------------------------------------

-- Line + date index (most common query pattern)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_kpi_line_date_desc
ON factory_telemetry.production_kpis (line_id, kpi_date DESC)
INCLUDE (shift_name, total_production, scrap_count, uptime_minutes);

RAISE NOTICE 'Created production_kpis index: (line_id, kpi_date DESC)';

-- Date-first index for cross-line analysis
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_kpi_date_desc
ON factory_telemetry.production_kpis (kpi_date DESC);

RAISE NOTICE 'Created production_kpis index: (kpi_date DESC)';

-- Created_at index for audit trail
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_kpi_created_at_desc
ON factory_telemetry.production_kpis (created_at DESC);

RAISE NOTICE 'Created production_kpis index: (created_at DESC)';

-- ----------------------------------------------------------------------------
-- Section 6: Production Context History Indexes
-- ----------------------------------------------------------------------------
-- Query patterns:
--   1. Equipment audit trail: WHERE equipment_code = ? ORDER BY changed_at DESC
--   2. Operator history: WHERE new_operator = ? AND changed_at >= ?
--   3. Recent changes: WHERE changed_at > NOW() - INTERVAL '1 day'
-- ----------------------------------------------------------------------------

-- Equipment + time index
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_context_equipment_time_desc
ON factory_telemetry.production_context_history (equipment_code, changed_at DESC)
INCLUDE (old_operator, new_operator, old_shift, new_shift);

RAISE NOTICE 'Created production_context_history index: (equipment_code, changed_at DESC)';

-- Time-first index for recent changes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_context_time_desc
ON factory_telemetry.production_context_history (changed_at DESC);

RAISE NOTICE 'Created production_context_history index: (changed_at DESC)';

-- Operator-focused partial index
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_context_operator_changes
ON factory_telemetry.production_context_history (new_operator, changed_at DESC)
WHERE new_operator IS NOT NULL;

RAISE NOTICE 'Created production_context_history partial index: operator changes';

-- ----------------------------------------------------------------------------
-- Section 7: Update Table Statistics
-- ----------------------------------------------------------------------------

-- Analyze all tables to update query planner statistics
ANALYZE factory_telemetry.metric_hist;
ANALYZE factory_telemetry.oee_calculations;
ANALYZE factory_telemetry.energy_consumption;
ANALYZE factory_telemetry.production_kpis;
ANALYZE factory_telemetry.production_context_history;

RAISE NOTICE 'Updated table statistics for query planner';

-- ----------------------------------------------------------------------------
-- Section 8: Index Usage Monitoring View
-- ----------------------------------------------------------------------------

-- Create view to monitor index effectiveness
CREATE OR REPLACE VIEW factory_telemetry.v_index_usage AS
SELECT
    schemaname AS schema_name,
    tablename AS table_name,
    indexname AS index_name,
    idx_scan AS index_scans,
    idx_tup_read AS tuples_read,
    idx_tup_fetch AS tuples_fetched,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
    CASE 
        WHEN idx_scan = 0 THEN 'UNUSED'
        WHEN idx_scan < 100 THEN 'LOW USAGE'
        WHEN idx_scan < 1000 THEN 'MODERATE USAGE'
        ELSE 'HIGH USAGE'
    END AS usage_category
FROM pg_stat_user_indexes
WHERE schemaname = 'factory_telemetry'
  AND tablename IN (
      'metric_hist',
      'oee_calculations',
      'energy_consumption',
      'production_kpis',
      'production_context_history'
  )
ORDER BY idx_scan DESC;

COMMENT ON VIEW factory_telemetry.v_index_usage IS 
    'Monitor index usage statistics to identify unused or underutilized indexes';

RAISE NOTICE 'Created index monitoring view: factory_telemetry.v_index_usage';

-- ----------------------------------------------------------------------------
-- Section 9: Display Index Summary
-- ----------------------------------------------------------------------------

-- Show all indexes created
SELECT 
    tablename AS table_name,
    indexname AS index_name,
    indexdef AS index_definition,
    pg_size_pretty(pg_relation_size(indexname::regclass)) AS index_size
FROM pg_indexes
WHERE schemaname = 'factory_telemetry'
  AND tablename IN (
      'metric_hist',
      'oee_calculations',
      'energy_consumption',
      'production_kpis',
      'production_context_history'
  )
  AND indexname LIKE 'idx_%'
ORDER BY tablename, indexname;

-- Show index usage statistics
SELECT * FROM factory_telemetry.v_index_usage;

-- ----------------------------------------------------------------------------
-- Section 10: Post-Index Size Analysis
-- ----------------------------------------------------------------------------

DO $$
DECLARE
    v_table_name TEXT;
    v_table_size TEXT;
    v_index_size TEXT;
    v_total_size TEXT;
BEGIN
    RAISE NOTICE E'\n=== Post-Index Size Analysis ===';
    
    FOR v_table_name IN 
        SELECT tablename 
        FROM pg_tables 
        WHERE schemaname = 'factory_telemetry'
          AND tablename IN (
              'metric_hist',
              'oee_calculations',
              'energy_consumption',
              'production_kpis',
              'production_context_history'
          )
    LOOP
        SELECT 
            pg_size_pretty(pg_table_size('factory_telemetry.' || v_table_name)),
            pg_size_pretty(pg_indexes_size('factory_telemetry.' || v_table_name)),
            pg_size_pretty(pg_total_relation_size('factory_telemetry.' || v_table_name))
        INTO v_table_size, v_index_size, v_total_size;
        
        RAISE NOTICE '%: table: %, indexes: %, total: %',
            v_table_name, v_table_size, v_index_size, v_total_size;
    END LOOP;
END $$;

-- ----------------------------------------------------------------------------
-- Section 11: Completion Summary
-- ----------------------------------------------------------------------------

DO $$
DECLARE
    v_index_count INTEGER;
    v_total_index_size TEXT;
BEGIN
    SELECT 
        COUNT(*),
        pg_size_pretty(SUM(pg_relation_size(indexname::regclass)))
    INTO v_index_count, v_total_index_size
    FROM pg_indexes
    WHERE schemaname = 'factory_telemetry'
      AND indexname LIKE 'idx_%'
      AND tablename IN (
          'metric_hist',
          'oee_calculations',
          'energy_consumption',
          'production_kpis',
          'production_context_history'
      );
    
    RAISE NOTICE E'\n=== Phase 4.4 Performance Indexes Complete ===';
    RAISE NOTICE 'Total indexes created: %', v_index_count;
    RAISE NOTICE 'Total index size: %', v_total_index_size;
    RAISE NOTICE 'Index monitoring view: factory_telemetry.v_index_usage';
END $$;

\echo '✓ Performance indexes created successfully'
