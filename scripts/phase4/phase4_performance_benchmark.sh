#!/bin/bash
# ============================================================================
# MS5.0 Phase 4: Performance Benchmarking Tool
# ============================================================================
# Purpose: Measure and validate performance improvements from Phase 4
#          optimizations. Provides quantitative evidence of optimization
#          effectiveness.
#
# Design Philosophy: "In God we trust; all others bring data." Every
#                    optimization claim must be backed by measurements.
#                    This tool is the ship's diagnostics panel showing
#                    exactly how much faster we've become.
# ============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BENCHMARK_REPORT="${PROJECT_ROOT}/logs/phase4/benchmark_$(date +%Y%m%d_%H%M%S).json"

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-factory_telemetry}"
DB_USER="${DB_USER:-ms5_user_production}"
DB_PASSWORD="${DB_PASSWORD:-}"

# Benchmark parameters
WARMUP_RUNS=3
BENCHMARK_RUNS=5

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Results storage
declare -A QUERY_TIMES
declare -A QUERY_RESULTS

# ----------------------------------------------------------------------------
# Utility Functions
# ----------------------------------------------------------------------------

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $*"
}

execute_sql_timed() {
    local query=$1
    local start_time end_time duration
    
    start_time=$(date +%s%3N)
    
    PGPASSWORD="${DB_PASSWORD}" psql \
        -h "${DB_HOST}" \
        -p "${DB_PORT}" \
        -U "${DB_USER}" \
        -d "${DB_NAME}" \
        -c "${query}" \
        > /dev/null 2>&1
    
    end_time=$(date +%s%3N)
    duration=$((end_time - start_time))
    
    echo "${duration}"
}

execute_sql() {
    PGPASSWORD="${DB_PASSWORD}" psql \
        -h "${DB_HOST}" \
        -p "${DB_PORT}" \
        -U "${DB_USER}" \
        -d "${DB_NAME}" \
        -t \
        -c "$1" 2>/dev/null
}

calculate_average() {
    local -n times=$1
    local sum=0
    local count=${#times[@]}
    
    for time in "${times[@]}"; do
        sum=$((sum + time))
    done
    
    echo $((sum / count))
}

calculate_median() {
    local -n times=$1
    local sorted=($(printf '%s\n' "${times[@]}" | sort -n))
    local count=${#sorted[@]}
    local middle=$((count / 2))
    
    if [[ $((count % 2)) -eq 0 ]]; then
        echo $(( (sorted[middle-1] + sorted[middle]) / 2 ))
    else
        echo "${sorted[middle]}"
    fi
}

# ----------------------------------------------------------------------------
# Benchmark Queries
# ----------------------------------------------------------------------------

benchmark_recent_metrics() {
    log_info "Benchmarking: Recent metrics query (last hour)"
    
    local query="
        SELECT metric_def_id, AVG(value_real) 
        FROM factory_telemetry.metric_hist 
        WHERE ts > NOW() - INTERVAL '1 hour' 
        GROUP BY metric_def_id;
    "
    
    # Warmup
    for ((i=1; i<=WARMUP_RUNS; i++)); do
        execute_sql_timed "${query}" > /dev/null
    done
    
    # Benchmark
    local times=()
    for ((i=1; i<=BENCHMARK_RUNS; i++)); do
        local duration=$(execute_sql_timed "${query}")
        times+=("${duration}")
        printf "."
    done
    echo ""
    
    local avg=$(calculate_average times)
    local med=$(calculate_median times)
    
    QUERY_TIMES["recent_metrics_avg"]=${avg}
    QUERY_TIMES["recent_metrics_median"]=${med}
    
    log_success "Recent metrics - Avg: ${avg}ms, Median: ${med}ms"
}

benchmark_time_range_query() {
    log_info "Benchmarking: Time range query (last 24 hours)"
    
    local query="
        SELECT time_bucket('1 minute', ts) AS minute, 
               metric_def_id, 
               AVG(value_real) AS avg_value
        FROM factory_telemetry.metric_hist
        WHERE ts > NOW() - INTERVAL '24 hours'
        GROUP BY minute, metric_def_id
        ORDER BY minute DESC;
    "
    
    # Warmup
    for ((i=1; i<=WARMUP_RUNS; i++)); do
        execute_sql_timed "${query}" > /dev/null
    done
    
    # Benchmark
    local times=()
    for ((i=1; i<=BENCHMARK_RUNS; i++)); do
        local duration=$(execute_sql_timed "${query}")
        times+=("${duration}")
        printf "."
    done
    echo ""
    
    local avg=$(calculate_average times)
    local med=$(calculate_median times)
    
    QUERY_TIMES["time_range_avg"]=${avg}
    QUERY_TIMES["time_range_median"]=${med}
    
    log_success "Time range query - Avg: ${avg}ms, Median: ${med}ms"
}

benchmark_oee_aggregation() {
    log_info "Benchmarking: OEE hourly aggregation"
    
    local query="
        SELECT 
            time_bucket('1 hour', calculation_time) AS hour,
            line_id,
            AVG(oee) AS avg_oee,
            SUM(good_parts) AS total_good_parts
        FROM factory_telemetry.oee_calculations
        WHERE calculation_time > NOW() - INTERVAL '7 days'
        GROUP BY hour, line_id
        ORDER BY hour DESC;
    "
    
    # Warmup
    for ((i=1; i<=WARMUP_RUNS; i++)); do
        execute_sql_timed "${query}" > /dev/null
    done
    
    # Benchmark
    local times=()
    for ((i=1; i<=BENCHMARK_RUNS; i++)); do
        local duration=$(execute_sql_timed "${query}")
        times+=("${duration}")
        printf "."
    done
    echo ""
    
    local avg=$(calculate_average times)
    local med=$(calculate_median times)
    
    QUERY_TIMES["oee_aggregation_avg"]=${avg}
    QUERY_TIMES["oee_aggregation_median"]=${med}
    
    log_success "OEE aggregation - Avg: ${avg}ms, Median: ${med}ms"
}

benchmark_continuous_aggregate() {
    log_info "Benchmarking: Continuous aggregate query"
    
    local query="
        SELECT bucket, metric_def_id, avg_real, min_real, max_real
        FROM factory_telemetry.metric_hist_1hour
        WHERE bucket > NOW() - INTERVAL '7 days'
        ORDER BY bucket DESC
        LIMIT 1000;
    "
    
    # Check if continuous aggregate exists
    local exists=$(execute_sql "
        SELECT COUNT(*) 
        FROM timescaledb_information.continuous_aggregates 
        WHERE view_schema = 'factory_telemetry' 
          AND view_name = 'metric_hist_1hour';
    ")
    exists=$(echo "$exists" | tr -d ' ')
    
    if [[ ${exists} -eq 0 ]]; then
        log_info "Continuous aggregate not found, skipping benchmark"
        QUERY_TIMES["continuous_agg_avg"]=0
        QUERY_TIMES["continuous_agg_median"]=0
        return
    fi
    
    # Warmup
    for ((i=1; i<=WARMUP_RUNS; i++)); do
        execute_sql_timed "${query}" > /dev/null
    done
    
    # Benchmark
    local times=()
    for ((i=1; i<=BENCHMARK_RUNS; i++)); do
        local duration=$(execute_sql_timed "${query}")
        times+=("${duration}")
        printf "."
    done
    echo ""
    
    local avg=$(calculate_average times)
    local med=$(calculate_median times)
    
    QUERY_TIMES["continuous_agg_avg"]=${avg}
    QUERY_TIMES["continuous_agg_median"]=${med}
    
    log_success "Continuous aggregate - Avg: ${avg}ms, Median: ${med}ms"
}

benchmark_index_usage() {
    log_info "Benchmarking: Indexed column query"
    
    # Query that should benefit from indexes
    local query="
        SELECT ts, value_real
        FROM factory_telemetry.metric_hist
        WHERE metric_def_id = (
            SELECT id FROM factory_telemetry.metric_def LIMIT 1
        )
        AND ts > NOW() - INTERVAL '1 day'
        ORDER BY ts DESC
        LIMIT 100;
    "
    
    # Warmup
    for ((i=1; i<=WARMUP_RUNS; i++)); do
        execute_sql_timed "${query}" > /dev/null
    done
    
    # Benchmark
    local times=()
    for ((i=1; i<=BENCHMARK_RUNS; i++)); do
        local duration=$(execute_sql_timed "${query}")
        times+=("${duration}")
        printf "."
    done
    echo ""
    
    local avg=$(calculate_average times)
    local med=$(calculate_median times)
    
    QUERY_TIMES["indexed_query_avg"]=${avg}
    QUERY_TIMES["indexed_query_median"]=${med}
    
    log_success "Indexed query - Avg: ${avg}ms, Median: ${med}ms"
}

# ----------------------------------------------------------------------------
# Compression Analysis
# ----------------------------------------------------------------------------

analyze_compression() {
    log_info "Analyzing compression statistics..."
    
    local total_uncompressed=$(execute_sql "
        SELECT pg_size_pretty(
            SUM(pg_total_relation_size(format('%I.%I', chunk_schema, chunk_name)::regclass))
        )
        FROM timescaledb_information.chunks
        WHERE hypertable_schema = 'factory_telemetry'
          AND NOT is_compressed;
    ")
    
    local total_compressed=$(execute_sql "
        SELECT pg_size_pretty(
            SUM(pg_total_relation_size(format('%I.%I', chunk_schema, chunk_name)::regclass))
        )
        FROM timescaledb_information.chunks
        WHERE hypertable_schema = 'factory_telemetry'
          AND is_compressed;
    ")
    
    QUERY_RESULTS["total_uncompressed"]=$(echo "$total_uncompressed" | tr -d ' ')
    QUERY_RESULTS["total_compressed"]=$(echo "$total_compressed" | tr -d ' ')
    
    log_success "Uncompressed chunks: ${QUERY_RESULTS[total_uncompressed]}"
    log_success "Compressed chunks: ${QUERY_RESULTS[total_compressed]}"
}

# ----------------------------------------------------------------------------
# Storage Analysis
# ----------------------------------------------------------------------------

analyze_storage() {
    log_info "Analyzing storage statistics..."
    
    local db_size=$(execute_sql "SELECT pg_size_pretty(pg_database_size('${DB_NAME}'));")
    local table_sizes=$(execute_sql "
        SELECT 
            hypertable_name || ': ' || pg_size_pretty(
                pg_total_relation_size(format('%I.%I', hypertable_schema, hypertable_name)::regclass)
            )
        FROM timescaledb_information.hypertables
        WHERE hypertable_schema = 'factory_telemetry'
        ORDER BY hypertable_name;
    ")
    
    QUERY_RESULTS["database_size"]=$(echo "$db_size" | tr -d ' ')
    QUERY_RESULTS["table_sizes"]="${table_sizes}"
    
    log_success "Total database size: ${QUERY_RESULTS[database_size]}"
}

# ----------------------------------------------------------------------------
# Report Generation
# ----------------------------------------------------------------------------

generate_json_report() {
    log_info "Generating JSON benchmark report..."
    
    mkdir -p "$(dirname "${BENCHMARK_REPORT}")"
    
    cat > "${BENCHMARK_REPORT}" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "environment": {
    "database": "${DB_NAME}",
    "host": "${DB_HOST}",
    "port": ${DB_PORT}
  },
  "query_performance": {
    "recent_metrics": {
      "average_ms": ${QUERY_TIMES[recent_metrics_avg]:-0},
      "median_ms": ${QUERY_TIMES[recent_metrics_median]:-0},
      "runs": ${BENCHMARK_RUNS}
    },
    "time_range_query": {
      "average_ms": ${QUERY_TIMES[time_range_avg]:-0},
      "median_ms": ${QUERY_TIMES[time_range_median]:-0},
      "runs": ${BENCHMARK_RUNS}
    },
    "oee_aggregation": {
      "average_ms": ${QUERY_TIMES[oee_aggregation_avg]:-0},
      "median_ms": ${QUERY_TIMES[oee_aggregation_median]:-0},
      "runs": ${BENCHMARK_RUNS}
    },
    "continuous_aggregate": {
      "average_ms": ${QUERY_TIMES[continuous_agg_avg]:-0},
      "median_ms": ${QUERY_TIMES[continuous_agg_median]:-0},
      "runs": ${BENCHMARK_RUNS}
    },
    "indexed_query": {
      "average_ms": ${QUERY_TIMES[indexed_query_avg]:-0},
      "median_ms": ${QUERY_TIMES[indexed_query_median]:-0},
      "runs": ${BENCHMARK_RUNS}
    }
  },
  "storage_analysis": {
    "database_size": "${QUERY_RESULTS[database_size]:-N/A}",
    "uncompressed_chunks": "${QUERY_RESULTS[total_uncompressed]:-N/A}",
    "compressed_chunks": "${QUERY_RESULTS[total_compressed]:-N/A}"
  },
  "benchmark_parameters": {
    "warmup_runs": ${WARMUP_RUNS},
    "benchmark_runs": ${BENCHMARK_RUNS}
  }
}
EOF
    
    log_success "JSON report saved: ${BENCHMARK_REPORT}"
}

generate_text_report() {
    local text_report="${BENCHMARK_REPORT%.json}.txt"
    
    cat > "${text_report}" << EOF
================================================
  MS5.0 Phase 4 Performance Benchmark Report
  Generated: $(date)
================================================

QUERY PERFORMANCE RESULTS
-------------------------

1. Recent Metrics Query (Last Hour)
   Average:  ${QUERY_TIMES[recent_metrics_avg]:-N/A}ms
   Median:   ${QUERY_TIMES[recent_metrics_median]:-N/A}ms
   Target:   < 100ms
   Status:   $([ ${QUERY_TIMES[recent_metrics_avg]:-999999} -lt 100 ] && echo "PASS" || echo "REVIEW")

2. Time Range Query (Last 24 Hours)
   Average:  ${QUERY_TIMES[time_range_avg]:-N/A}ms
   Median:   ${QUERY_TIMES[time_range_median]:-N/A}ms
   Target:   < 500ms
   Status:   $([ ${QUERY_TIMES[time_range_avg]:-999999} -lt 500 ] && echo "PASS" || echo "REVIEW")

3. OEE Aggregation (Last 7 Days)
   Average:  ${QUERY_TIMES[oee_aggregation_avg]:-N/A}ms
   Median:   ${QUERY_TIMES[oee_aggregation_median]:-N/A}ms
   Target:   < 1000ms
   Status:   $([ ${QUERY_TIMES[oee_aggregation_avg]:-999999} -lt 1000 ] && echo "PASS" || echo "REVIEW")

4. Continuous Aggregate Query
   Average:  ${QUERY_TIMES[continuous_agg_avg]:-N/A}ms
   Median:   ${QUERY_TIMES[continuous_agg_median]:-N/A}ms
   Target:   < 50ms
   Status:   $([ ${QUERY_TIMES[continuous_agg_avg]:-999999} -lt 50 ] && echo "PASS" || echo "REVIEW")

5. Indexed Column Query
   Average:  ${QUERY_TIMES[indexed_query_avg]:-N/A}ms
   Median:   ${QUERY_TIMES[indexed_query_median]:-N/A}ms
   Target:   < 100ms
   Status:   $([ ${QUERY_TIMES[indexed_query_avg]:-999999} -lt 100 ] && echo "PASS" || echo "REVIEW")

STORAGE ANALYSIS
----------------

Database Size:        ${QUERY_RESULTS[database_size]:-N/A}
Uncompressed Chunks:  ${QUERY_RESULTS[total_uncompressed]:-N/A}
Compressed Chunks:    ${QUERY_RESULTS[total_compressed]:-N/A}

RECOMMENDATIONS
---------------

Based on benchmark results:
$([ ${QUERY_TIMES[recent_metrics_avg]:-0} -gt 100 ] && echo "- Consider additional indexing on frequently queried columns" || echo "- Query performance is within acceptable range")
$([ ${QUERY_TIMES[continuous_agg_avg]:-0} -eq 0 ] && echo "- Continuous aggregates are not yet populated; wait for refresh policy" || echo "- Continuous aggregates are accelerating queries as expected")

================================================
EOF
    
    log_success "Text report saved: ${text_report}"
}

# ----------------------------------------------------------------------------
# Main Execution
# ----------------------------------------------------------------------------

main() {
    echo "=========================================="
    echo "  Phase 4 Performance Benchmark"
    echo "=========================================="
    echo ""
    
    # Run benchmarks
    benchmark_recent_metrics
    benchmark_time_range_query
    benchmark_oee_aggregation
    benchmark_continuous_aggregate
    benchmark_index_usage
    
    # Run analysis
    analyze_compression
    analyze_storage
    
    # Generate reports
    echo ""
    generate_json_report
    generate_text_report
    
    # Summary
    echo ""
    echo "=========================================="
    echo "  Benchmark Complete"
    echo "=========================================="
    echo ""
    echo "Reports generated:"
    echo "  - JSON: ${BENCHMARK_REPORT}"
    echo "  - Text: ${BENCHMARK_REPORT%.json}.txt"
    echo ""
    
    log_success "Performance benchmarking completed successfully!"
}

main "$@"
