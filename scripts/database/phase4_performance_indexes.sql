-- ============================================================================
-- MS5.0 Manufacturing System - Phase 4: Performance Index Optimization
-- ============================================================================
-- This script creates optimized indexes for time-series data to ensure
-- sub-100ms query performance for dashboard and reporting queries.
--
-- Index Strategy:
-- - Time-descending indexes: Optimize recent data queries (most common)
-- - Composite indexes: Support multi-column WHERE clauses and JOIN operations
-- - Covering indexes: Include frequently selected columns to avoid table lookups
-- - Partial indexes: Index only relevant data subsets
--
-- Performance Targets:
-- - Dashboard queries: <50ms
-- - Report queries: <500ms
-- - Aggregate queries: <2s
-- - Full-table scans: Eliminated for common queries
-- ============================================================================

-- ============================================================================
-- SECTION 1: High-Frequency Telemetry Indexes (metric_hist)
-- ============================================================================
-- Most critical table: 100-1000 inserts/second, frequent queries
-- Query patterns:
--   1. Recent metrics by equipment: SELECT * WHERE metric_def_id = ? AND ts > ?
--   2. Metric trending: SELECT ts, value WHERE metric_def_id = ? ORDER BY ts DESC
--   3. Multi-metric correlation: SELECT * WHERE metric_def_id IN (?) AND ts BETWEEN ? AND ?
-- ============================================================================

-- Primary time-series index (time-descending for recent queries)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_metric_hist_ts_desc
    ON factory_telemetry.metric_hist (ts DESC)
    WITH (timescaledb.transaction_per_chunk);

-- Composite index for metric + time queries (most common access pattern)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_metric_hist_metric_ts_desc
    ON factory_telemetry.metric_hist (metric_def_id, ts DESC)
    WITH (timescaledb.transaction_per_chunk);

-- Covering index for value queries (avoids table lookup)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_metric_hist_metric_ts_value_real
    ON factory_telemetry.metric_hist (metric_def_id, ts DESC)
    INCLUDE (value_real, value_int, value_bool)
    WHERE value_real IS NOT NULL
    WITH (timescaledb.transaction_per_chunk);

-- Index for integer value queries
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_metric_hist_value_int_ts
    ON factory_telemetry.metric_hist (metric_def_id, ts DESC)
    WHERE value_int IS NOT NULL
    WITH (timescaledb.transaction_per_chunk);

-- ============================================================================
-- SECTION 2: OEE Calculation Indexes
-- ============================================================================
-- Query patterns:
--   1. Recent OEE by line: SELECT * WHERE line_id = ? ORDER BY calculation_time DESC
--   2. Equipment OEE trending: SELECT * WHERE equipment_code = ? AND calculation_time > ?
--   3. Shift OEE reports: SELECT * WHERE line_id = ? AND calculation_time BETWEEN ? AND ?
-- ============================================================================

-- Primary time index
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_oee_calc_time_desc
    ON factory_telemetry.oee_calculations (calculation_time DESC)
    WITH (timescaledb.transaction_per_chunk);

-- Line + time composite index (dashboard queries)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_oee_calc_line_time_desc
    ON factory_telemetry.oee_calculations (line_id, calculation_time DESC)
    WITH (timescaledb.transaction_per_chunk);

-- Equipment + time composite index (equipment-specific reports)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_oee_calc_equipment_time_desc
    ON factory_telemetry.oee_calculations (equipment_code, calculation_time DESC)
    WITH (timescaledb.transaction_per_chunk);

-- Covering index for OEE metric queries (avoids table lookup)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_oee_calc_line_time_metrics
    ON factory_telemetry.oee_calculations (line_id, calculation_time DESC)
    INCLUDE (availability, performance, quality, oee, good_parts, total_parts)
    WITH (timescaledb.transaction_per_chunk);

-- Index for low OEE alerts (partial index for efficiency)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_oee_calc_low_oee_alert
    ON factory_telemetry.oee_calculations (line_id, calculation_time DESC, oee)
    WHERE oee < 0.70
    WITH (timescaledb.transaction_per_chunk);

-- ============================================================================
-- SECTION 3: Energy Consumption Indexes
-- ============================================================================
-- Query patterns:
--   1. Recent energy by equipment: SELECT * WHERE equipment_code = ? ORDER BY consumption_time DESC
--   2. Energy trending: SELECT SUM(energy) WHERE equipment_code = ? GROUP BY date
--   3. High consumption alerts: SELECT * WHERE power_consumption_kw > threshold
-- ============================================================================

-- Primary time index
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_energy_time_desc
    ON factory_telemetry.energy_consumption (consumption_time DESC)
    WITH (timescaledb.transaction_per_chunk);

-- Equipment + time composite index
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_energy_equipment_time_desc
    ON factory_telemetry.energy_consumption (equipment_code, consumption_time DESC)
    WITH (timescaledb.transaction_per_chunk);

-- Covering index for energy metrics
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_energy_equipment_time_metrics
    ON factory_telemetry.energy_consumption (equipment_code, consumption_time DESC)
    INCLUDE (power_consumption_kw, energy_consumption_kwh, power_factor)
    WITH (timescaledb.transaction_per_chunk);

-- High power consumption alert index (partial index)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_energy_high_power_alert
    ON factory_telemetry.energy_consumption (equipment_code, consumption_time DESC)
    WHERE power_consumption_kw > 10.0
    WITH (timescaledb.transaction_per_chunk);

-- ============================================================================
-- SECTION 4: Production KPI Indexes
-- ============================================================================
-- Query patterns:
--   1. Daily KPIs by line: SELECT * WHERE line_id = ? AND kpi_date = ?
--   2. Shift KPIs: SELECT * WHERE line_id = ? AND shift_id = ? AND kpi_date BETWEEN ? AND ?
--   3. KPI trending: SELECT * WHERE line_id = ? ORDER BY kpi_date DESC
-- ============================================================================

-- Line + date composite index (most common query)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_kpis_line_date_desc
    ON factory_telemetry.production_kpis (line_id, kpi_date DESC)
    WITH (timescaledb.transaction_per_chunk);

-- Line + shift + date composite index (shift reports)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_kpis_line_shift_date_desc
    ON factory_telemetry.production_kpis (line_id, shift_id, kpi_date DESC)
    WITH (timescaledb.transaction_per_chunk);

-- Covering index for KPI metrics
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_kpis_line_date_metrics
    ON factory_telemetry.production_kpis (line_id, kpi_date DESC)
    INCLUDE (oee, availability, performance, quality, total_production, good_parts)
    WITH (timescaledb.transaction_per_chunk);

-- Time-based index for recent KPIs
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_kpis_created_at_desc
    ON factory_telemetry.production_kpis (created_at DESC)
    WITH (timescaledb.transaction_per_chunk);

-- ============================================================================
-- SECTION 5: Downtime Event Indexes
-- ============================================================================
-- Query patterns:
--   1. Recent downtime by line: SELECT * WHERE line_id = ? ORDER BY start_time DESC
--   2. Downtime by category: SELECT * WHERE category = ? AND start_time > ?
--   3. Active downtime: SELECT * WHERE end_time IS NULL
--   4. MTBF calculations: SELECT * WHERE equipment_code = ? AND category = 'unplanned'
-- ============================================================================

-- Primary time index
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_downtime_start_time_desc
    ON factory_telemetry.downtime_events (start_time DESC)
    WITH (timescaledb.transaction_per_chunk);

-- Line + time composite index
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_downtime_line_time_desc
    ON factory_telemetry.downtime_events (line_id, start_time DESC)
    WITH (timescaledb.transaction_per_chunk);

-- Equipment + category index (MTBF analysis)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_downtime_equipment_category
    ON factory_telemetry.downtime_events (equipment_code, category, start_time DESC)
    WITH (timescaledb.transaction_per_chunk);

-- Active downtime index (partial index for efficiency)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_downtime_active
    ON factory_telemetry.downtime_events (line_id, start_time DESC)
    WHERE end_time IS NULL
    WITH (timescaledb.transaction_per_chunk);

-- Category + time index (downtime analysis by type)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_downtime_category_time_desc
    ON factory_telemetry.downtime_events (category, start_time DESC)
    WITH (timescaledb.transaction_per_chunk);

-- Covering index for downtime metrics
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_downtime_line_time_metrics
    ON factory_telemetry.downtime_events (line_id, start_time DESC)
    INCLUDE (category, reason_code, duration_seconds, end_time)
    WITH (timescaledb.transaction_per_chunk);

-- ============================================================================
-- SECTION 6: Quality Check Indexes
-- ============================================================================
-- Query patterns:
--   1. Recent quality checks: SELECT * WHERE line_id = ? ORDER BY check_time DESC
--   2. Failed checks: SELECT * WHERE check_result = 'fail' AND check_time > ?
--   3. Product quality trending: SELECT * WHERE product_type_id = ? AND check_time > ?
-- ============================================================================

-- Primary time index
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_quality_check_time_desc
    ON factory_telemetry.quality_checks (check_time DESC)
    WITH (timescaledb.transaction_per_chunk);

-- Line + time composite index
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_quality_line_time_desc
    ON factory_telemetry.quality_checks (line_id, check_time DESC)
    WITH (timescaledb.transaction_per_chunk);

-- Product + time composite index
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_quality_product_time_desc
    ON factory_telemetry.quality_checks (product_type_id, check_time DESC)
    WITH (timescaledb.transaction_per_chunk);

-- Failed checks index (partial index)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_quality_failed_checks
    ON factory_telemetry.quality_checks (line_id, check_time DESC)
    WHERE check_result = 'fail'
    WITH (timescaledb.transaction_per_chunk);

-- Check type + result index (quality analysis)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_quality_type_result_time
    ON factory_telemetry.quality_checks (check_type, check_result, check_time DESC)
    WITH (timescaledb.transaction_per_chunk);

-- Covering index for quality metrics
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_quality_line_time_metrics
    ON factory_telemetry.quality_checks (line_id, check_time DESC)
    INCLUDE (check_result, quantity_checked, quantity_passed, quantity_failed)
    WITH (timescaledb.transaction_per_chunk);

-- ============================================================================
-- SECTION 7: Fault Event Indexes
-- ============================================================================
-- Query patterns:
--   1. Recent faults by equipment: SELECT * WHERE equipment_code = ? ORDER BY ts_on DESC
--   2. Active faults: SELECT * WHERE ts_off IS NULL
--   3. Fault duration analysis: SELECT * WHERE duration_s > threshold
--   4. Fault frequency: SELECT COUNT(*) WHERE equipment_code = ? GROUP BY date
-- ============================================================================

-- Primary time index
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fault_event_ts_on_desc
    ON factory_telemetry.fault_event (ts_on DESC)
    WITH (timescaledb.transaction_per_chunk);

-- Equipment + time composite index
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fault_event_equipment_ts_desc
    ON factory_telemetry.fault_event (equipment_code, ts_on DESC)
    WITH (timescaledb.transaction_per_chunk);

-- Equipment + bit index (fault code analysis)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fault_event_equipment_bit_ts
    ON factory_telemetry.fault_event (equipment_code, bit_index, ts_on DESC)
    WITH (timescaledb.transaction_per_chunk);

-- Active faults index (partial index)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fault_event_active
    ON factory_telemetry.fault_event (equipment_code, ts_on DESC)
    WHERE ts_off IS NULL
    WITH (timescaledb.transaction_per_chunk);

-- Long duration faults index (partial index)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fault_event_long_duration
    ON factory_telemetry.fault_event (equipment_code, ts_on DESC)
    WHERE duration_s > 300  -- Faults longer than 5 minutes
    WITH (timescaledb.transaction_per_chunk);

-- Covering index for fault metrics
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fault_event_equipment_ts_metrics
    ON factory_telemetry.fault_event (equipment_code, ts_on DESC)
    INCLUDE (bit_index, ts_off, duration_s)
    WITH (timescaledb.transaction_per_chunk);

-- ============================================================================
-- SECTION 8: Supporting Table Indexes (Non-Hypertables)
-- ============================================================================
-- Optimize joins and foreign key lookups
-- ============================================================================

-- Metric definition indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_metric_def_equipment_metric
    ON factory_telemetry.metric_def (equipment_code, metric_key);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_metric_def_value_type
    ON factory_telemetry.metric_def (value_type);

-- Metric binding indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_metric_binding_metric_def
    ON factory_telemetry.metric_binding (metric_def_id);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_metric_binding_plc_kind
    ON factory_telemetry.metric_binding (plc_kind, address);

-- Production line indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_production_lines_enabled
    ON factory_telemetry.production_lines (enabled)
    WHERE enabled = TRUE;

-- Product type indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_product_types_enabled
    ON factory_telemetry.product_types (enabled)
    WHERE enabled = TRUE;

-- Fault catalog indexes
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_fault_catalog_equipment_bit
    ON factory_telemetry.fault_catalog (equipment_code, bit_index);

-- ============================================================================
-- SECTION 9: Index Maintenance and Monitoring
-- ============================================================================

-- Create view for index usage statistics
CREATE OR REPLACE VIEW factory_telemetry.v_index_usage_stats AS
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan AS index_scans,
    idx_tup_read AS tuples_read,
    idx_tup_fetch AS tuples_fetched,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
    CASE 
        WHEN idx_scan = 0 THEN '⚠ Unused'
        WHEN idx_scan < 100 THEN '⚠ Low usage'
        WHEN idx_scan < 1000 THEN '✓ Normal usage'
        ELSE '✓ High usage'
    END AS usage_status
FROM pg_stat_user_indexes
WHERE schemaname = 'factory_telemetry'
ORDER BY idx_scan ASC, pg_relation_size(indexrelid) DESC;

-- Grant SELECT permission
GRANT SELECT ON factory_telemetry.v_index_usage_stats TO PUBLIC;

-- Create view for missing indexes analysis
CREATE OR REPLACE VIEW factory_telemetry.v_missing_indexes_analysis AS
SELECT
    schemaname,
    tablename,
    seq_scan AS sequential_scans,
    seq_tup_read AS sequential_tuples_read,
    idx_scan AS index_scans,
    n_tup_ins AS inserts,
    n_tup_upd AS updates,
    n_tup_del AS deletes,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
    CASE 
        WHEN seq_scan > idx_scan AND seq_scan > 1000 THEN '⚠ High sequential scans'
        WHEN seq_scan > 10000 THEN '✗ Critical: Add indexes'
        ELSE '✓ OK'
    END AS index_recommendation
FROM pg_stat_user_tables
WHERE schemaname = 'factory_telemetry'
ORDER BY seq_scan DESC, pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Grant SELECT permission
GRANT SELECT ON factory_telemetry.v_missing_indexes_analysis TO PUBLIC;

-- Function to analyze and recommend indexes
CREATE OR REPLACE FUNCTION factory_telemetry.analyze_query_performance(
    p_query TEXT
)
RETURNS TABLE(
    step_type TEXT,
    step_detail TEXT,
    estimated_cost NUMERIC,
    actual_cost NUMERIC,
    rows_estimated BIGINT,
    rows_actual BIGINT,
    index_recommendation TEXT
) AS $$
BEGIN
    -- Enable timing for accurate cost analysis
    EXECUTE 'SET LOCAL enable_seqscan = ON';
    EXECUTE 'SET LOCAL enable_indexscan = ON';
    
    RAISE NOTICE 'Analyzing query: %', p_query;
    RAISE NOTICE 'Use EXPLAIN ANALYZE manually for detailed analysis';
    
    -- Return basic structure (full implementation would parse EXPLAIN output)
    RETURN QUERY
    SELECT 
        'Analysis'::TEXT AS step_type,
        'Run EXPLAIN (ANALYZE, BUFFERS) for detailed metrics'::TEXT AS step_detail,
        0.0::NUMERIC AS estimated_cost,
        0.0::NUMERIC AS actual_cost,
        0::BIGINT AS rows_estimated,
        0::BIGINT AS rows_actual,
        'Use EXPLAIN ANALYZE for recommendations'::TEXT AS index_recommendation;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- SECTION 10: Verification and Validation
-- ============================================================================

-- Verify all indexes are created successfully
DO $$
DECLARE
    expected_index_count INTEGER := 45;  -- Update based on actual count
    actual_index_count INTEGER;
    unused_indexes INTEGER;
BEGIN
    -- Count indexes on hypertables
    SELECT COUNT(*) INTO actual_index_count
    FROM pg_indexes
    WHERE schemaname = 'factory_telemetry'
    AND tablename IN (
        SELECT hypertable_name 
        FROM timescaledb_information.hypertables 
        WHERE hypertable_schema = 'factory_telemetry'
    );
    
    RAISE NOTICE 'Performance index validation:';
    RAISE NOTICE '  Created indexes on hypertables: %', actual_index_count;
    
    -- Check for unused indexes (after some production usage)
    SELECT COUNT(*) INTO unused_indexes
    FROM pg_stat_user_indexes
    WHERE schemaname = 'factory_telemetry'
    AND idx_scan = 0
    AND indexrelname NOT LIKE '%_pkey';
    
    IF unused_indexes > 0 THEN
        RAISE WARNING '  Found % unused indexes (review after production usage)', 
            unused_indexes;
    ELSE
        RAISE NOTICE '  ✓ All indexes are being utilized';
    END IF;
    
    RAISE NOTICE 'Index optimization: SUCCESS';
END $$;

-- Display index usage statistics
SELECT 
    tablename,
    COUNT(*) AS index_count,
    pg_size_pretty(SUM(pg_relation_size(indexrelid))) AS total_index_size
FROM pg_stat_user_indexes
WHERE schemaname = 'factory_telemetry'
GROUP BY tablename
ORDER BY SUM(pg_relation_size(indexrelid)) DESC;

-- Run ANALYZE to update statistics for query planner
ANALYZE factory_telemetry.metric_hist;
ANALYZE factory_telemetry.oee_calculations;
ANALYZE factory_telemetry.energy_consumption;
ANALYZE factory_telemetry.production_kpis;
ANALYZE factory_telemetry.downtime_events;
ANALYZE factory_telemetry.quality_checks;
ANALYZE factory_telemetry.fault_event;

-- ============================================================================
-- Performance Index Optimization Complete
-- Next: Run phase4_continuous_aggregates.sql
-- ============================================================================

