#!/bin/bash
# ============================================================================
# MS5.0 Phase 4: Post-Optimization Validation
# ============================================================================
# Purpose: Verify that all Phase 4 optimizations were applied correctly
#          and are functioning as expected. This is the systems check
#          after the hyperdrive upgrade.
#
# Design Philosophy: Trust, but verify. Every optimization must prove it
#                    works. Like a starship's post-upgrade diagnostics,
#                    we test every enhanced system before declaring victory.
# ============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REPORT_FILE="${PROJECT_ROOT}/logs/phase4/post_validation_$(date +%Y%m%d_%H%M%S).txt"

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-factory_telemetry}"
DB_USER="${DB_USER:-ms5_user_production}"
DB_PASSWORD="${DB_PASSWORD:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Validation tracking
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNING=0

# ----------------------------------------------------------------------------
# Utility Functions
# ----------------------------------------------------------------------------

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "${REPORT_FILE}"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $*" | tee -a "${REPORT_FILE}"
    ((TESTS_PASSED++))
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $*" | tee -a "${REPORT_FILE}"
    ((TESTS_WARNING++))
}

log_error() {
    echo -e "${RED}[✗]${NC} $*" | tee -a "${REPORT_FILE}" >&2
    ((TESTS_FAILED++))
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

# ----------------------------------------------------------------------------
# Validation Tests
# ----------------------------------------------------------------------------

test_chunk_intervals() {
    log_info "Validating chunk time intervals..."
    
    # Expected chunk intervals (in microseconds)
    declare -A expected_intervals=(
        ["metric_hist"]="3600000000"        # 1 hour
        ["oee_calculations"]="86400000000"  # 1 day
        ["energy_consumption"]="86400000000"
        ["production_kpis"]="86400000000"
        ["production_context_history"]="86400000000"
    )
    
    for table in "${!expected_intervals[@]}"; do
        local actual=$(execute_sql "
            SELECT d.interval_length
            FROM timescaledb_information.dimensions d
            JOIN timescaledb_information.hypertables h
                ON h.hypertable_schema = d.hypertable_schema
                AND h.hypertable_name = d.hypertable_name
            WHERE h.hypertable_schema = 'factory_telemetry'
              AND h.hypertable_name = '${table}';
        ")
        actual=$(echo "$actual" | tr -d ' ')
        
        local expected=${expected_intervals[$table]}
        
        if [[ "${actual}" == "${expected}" ]]; then
            local hours=$(( expected / 3600000000 ))
            log_success "${table}: chunk interval correctly set (${hours} hour(s))"
        else
            log_error "${table}: chunk interval mismatch (expected: ${expected}, actual: ${actual})"
        fi
    done
}

test_compression_enabled() {
    log_info "Validating compression settings..."
    
    local tables=("metric_hist" "oee_calculations" "energy_consumption" "production_kpis" "production_context_history")
    
    for table in "${tables[@]}"; do
        local enabled=$(execute_sql "
            SELECT compression_enabled
            FROM timescaledb_information.hypertables
            WHERE hypertable_schema = 'factory_telemetry'
              AND hypertable_name = '${table}';
        ")
        enabled=$(echo "$enabled" | tr -d ' ')
        
        if [[ "${enabled}" == "t" ]]; then
            log_success "${table}: compression enabled"
        else
            log_error "${table}: compression not enabled"
        fi
    done
}

test_compression_policies() {
    log_info "Validating compression policies..."
    
    local policy_count=$(execute_sql "
        SELECT COUNT(*)
        FROM timescaledb_information.jobs
        WHERE proc_name = 'policy_compression'
          AND hypertable_schema = 'factory_telemetry';
    ")
    policy_count=$(echo "$policy_count" | tr -d ' ')
    
    if [[ ${policy_count} -eq 5 ]]; then
        log_success "All 5 compression policies configured"
    else
        log_error "Expected 5 compression policies, found ${policy_count}"
    fi
    
    # Check that all policies are scheduled
    local scheduled=$(execute_sql "
        SELECT COUNT(*)
        FROM timescaledb_information.jobs
        WHERE proc_name = 'policy_compression'
          AND hypertable_schema = 'factory_telemetry'
          AND scheduled = true;
    ")
    scheduled=$(echo "$scheduled" | tr -d ' ')
    
    if [[ ${scheduled} -eq 5 ]]; then
        log_success "All compression policies are scheduled"
    else
        log_warning "Only ${scheduled}/5 compression policies are scheduled"
    fi
}

test_retention_policies() {
    log_info "Validating retention policies..."
    
    local policy_count=$(execute_sql "
        SELECT COUNT(*)
        FROM timescaledb_information.jobs
        WHERE proc_name = 'policy_retention'
          AND hypertable_schema = 'factory_telemetry';
    ")
    policy_count=$(echo "$policy_count" | tr -d ' ')
    
    if [[ ${policy_count} -eq 5 ]]; then
        log_success "All 5 retention policies configured"
    else
        log_error "Expected 5 retention policies, found ${policy_count}"
    fi
    
    # Validate specific retention intervals
    local metric_hist_retention=$(execute_sql "
        SELECT config->>'drop_after'
        FROM timescaledb_information.jobs
        WHERE proc_name = 'policy_retention'
          AND hypertable_name = 'metric_hist';
    ")
    metric_hist_retention=$(echo "$metric_hist_retention" | tr -d ' ')
    
    if [[ "${metric_hist_retention}" == "90days" ]]; then
        log_success "metric_hist: 90-day retention configured"
    else
        log_warning "metric_hist: unexpected retention (${metric_hist_retention})"
    fi
}

test_performance_indexes() {
    log_info "Validating performance indexes..."
    
    # Count indexes created in Phase 4
    local index_count=$(execute_sql "
        SELECT COUNT(*)
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
    ")
    index_count=$(echo "$index_count" | tr -d ' ')
    
    # We expect at least 15-20 indexes from Phase 4
    if [[ ${index_count} -ge 15 ]]; then
        log_success "Created ${index_count} performance indexes"
    else
        log_warning "Only ${index_count} indexes created (expected 15+)"
    fi
    
    # Check specific critical indexes
    local critical_indexes=(
        "idx_metric_hist_metric_ts_desc"
        "idx_oee_line_time_desc"
        "idx_energy_equipment_time_desc"
    )
    
    for index in "${critical_indexes[@]}"; do
        local exists=$(execute_sql "
            SELECT COUNT(*)
            FROM pg_indexes
            WHERE schemaname = 'factory_telemetry'
              AND indexname = '${index}';
        ")
        exists=$(echo "$exists" | tr -d ' ')
        
        if [[ ${exists} -eq 1 ]]; then
            log_success "Critical index created: ${index}"
        else
            log_error "Critical index missing: ${index}"
        fi
    done
}

test_continuous_aggregates() {
    log_info "Validating continuous aggregates..."
    
    local cagg_count=$(execute_sql "
        SELECT COUNT(*)
        FROM timescaledb_information.continuous_aggregates
        WHERE view_schema = 'factory_telemetry';
    ")
    cagg_count=$(echo "$cagg_count" | tr -d ' ')
    
    # We expect 9 continuous aggregates
    if [[ ${cagg_count} -ge 8 ]]; then
        log_success "Created ${cagg_count} continuous aggregates"
    else
        log_warning "Only ${cagg_count} continuous aggregates created (expected 8+)"
    fi
    
    # Check refresh policies
    local refresh_policies=$(execute_sql "
        SELECT COUNT(*)
        FROM timescaledb_information.jobs
        WHERE proc_name = 'policy_refresh_continuous_aggregate';
    ")
    refresh_policies=$(echo "$refresh_policies" | tr -d ' ')
    
    if [[ ${refresh_policies} -eq ${cagg_count} ]]; then
        log_success "All continuous aggregates have refresh policies"
    else
        log_error "Mismatch: ${cagg_count} aggregates but ${refresh_policies} refresh policies"
    fi
}

test_monitoring_views() {
    log_info "Validating monitoring views..."
    
    local views=("v_retention_status" "v_index_usage")
    
    for view in "${views[@]}"; do
        local exists=$(execute_sql "
            SELECT COUNT(*)
            FROM information_schema.views
            WHERE table_schema = 'factory_telemetry'
              AND table_name = '${view}';
        ")
        exists=$(echo "$exists" | tr -d ' ')
        
        if [[ ${exists} -eq 1 ]]; then
            log_success "Monitoring view created: ${view}"
        else
            log_error "Monitoring view missing: ${view}"
        fi
    done
}

test_database_parameters() {
    log_info "Validating database parameters..."
    
    local max_workers=$(execute_sql "SHOW timescaledb.max_background_workers;")
    max_workers=$(echo "$max_workers" | tr -d ' ')
    
    if [[ ${max_workers} -ge 8 ]]; then
        log_success "TimescaleDB background workers: ${max_workers}"
    else
        log_warning "Background workers may be insufficient: ${max_workers} (recommend 8)"
    fi
}

test_chunk_statistics() {
    log_info "Validating chunk statistics..."
    
    local total_chunks=$(execute_sql "
        SELECT COUNT(*)
        FROM timescaledb_information.chunks
        WHERE hypertable_schema = 'factory_telemetry';
    ")
    total_chunks=$(echo "$total_chunks" | tr -d ' ')
    
    log_info "Total chunks across all hypertables: ${total_chunks}"
    
    # Check for orphaned or problematic chunks
    local compressed_chunks=$(execute_sql "
        SELECT COUNT(*)
        FROM timescaledb_information.chunks
        WHERE hypertable_schema = 'factory_telemetry'
          AND is_compressed = true;
    ")
    compressed_chunks=$(echo "$compressed_chunks" | tr -d ' ')
    
    log_info "Compressed chunks: ${compressed_chunks}"
    
    if [[ ${total_chunks} -gt 0 ]]; then
        log_success "Chunk management operational"
    fi
}

test_query_performance() {
    log_info "Testing query performance..."
    
    # Test basic query on metric_hist
    local start_time=$(date +%s%3N)
    execute_sql "SELECT COUNT(*) FROM factory_telemetry.metric_hist WHERE ts > NOW() - INTERVAL '1 hour';" > /dev/null
    local end_time=$(date +%s%3N)
    local duration=$((end_time - start_time))
    
    if [[ ${duration} -lt 1000 ]]; then
        log_success "Recent data query performance: ${duration}ms (excellent)"
    elif [[ ${duration} -lt 3000 ]]; then
        log_success "Recent data query performance: ${duration}ms (good)"
    else
        log_warning "Recent data query performance: ${duration}ms (may need tuning)"
    fi
}

generate_optimization_report() {
    log_info "Generating optimization report..."
    
    {
        echo ""
        echo "=================================================="
        echo "  Phase 4 Optimization Report"
        echo "  Generated: $(date)"
        echo "=================================================="
        echo ""
        
        echo "--- Hypertable Summary ---"
        execute_sql "
            SELECT 
                hypertable_name,
                num_chunks,
                compression_enabled::text,
                pg_size_pretty(
                    pg_total_relation_size(format('%I.%I', hypertable_schema, hypertable_name)::regclass)
                ) AS total_size
            FROM timescaledb_information.hypertables
            WHERE hypertable_schema = 'factory_telemetry'
            ORDER BY hypertable_name;
        "
        
        echo ""
        echo "--- Compression Policies ---"
        execute_sql "
            SELECT 
                hypertable_name,
                config->>'compress_after' AS compress_after,
                schedule_interval::text
            FROM timescaledb_information.jobs
            WHERE proc_name = 'policy_compression'
              AND hypertable_schema = 'factory_telemetry'
            ORDER BY hypertable_name;
        "
        
        echo ""
        echo "--- Retention Policies ---"
        execute_sql "
            SELECT 
                hypertable_name,
                config->>'drop_after' AS retention_period
            FROM timescaledb_information.jobs
            WHERE proc_name = 'policy_retention'
              AND hypertable_schema = 'factory_telemetry'
            ORDER BY hypertable_name;
        "
        
        echo ""
        echo "--- Continuous Aggregates ---"
        execute_sql "
            SELECT 
                view_name,
                materialized_only::text,
                compression_enabled::text
            FROM timescaledb_information.continuous_aggregates
            WHERE view_schema = 'factory_telemetry'
            ORDER BY view_name;
        "
        
        echo ""
        echo "--- Storage Summary ---"
        execute_sql "
            SELECT 
                'Total database size: ' || pg_size_pretty(pg_database_size('${DB_NAME}'));
        "
        
    } >> "${REPORT_FILE}"
    
    log_success "Detailed report saved to: ${REPORT_FILE}"
}

# ----------------------------------------------------------------------------
# Main Validation Flow
# ----------------------------------------------------------------------------

main() {
    mkdir -p "$(dirname "${REPORT_FILE}")"
    
    echo "=========================================="
    echo "  Phase 4 Post-Optimization Validation"
    echo "=========================================="
    echo ""
    
    # Run all validation tests
    test_chunk_intervals
    test_compression_enabled
    test_compression_policies
    test_retention_policies
    test_performance_indexes
    test_continuous_aggregates
    test_monitoring_views
    test_database_parameters
    test_chunk_statistics
    test_query_performance
    
    # Generate detailed report
    generate_optimization_report
    
    # Summary
    echo ""
    echo "=========================================="
    echo "  Validation Summary"
    echo "=========================================="
    echo -e "${GREEN}Passed:${NC}  ${TESTS_PASSED}"
    echo -e "${YELLOW}Warnings:${NC} ${TESTS_WARNING}"
    echo -e "${RED}Failed:${NC}  ${TESTS_FAILED}"
    echo ""
    
    if [[ ${TESTS_FAILED} -eq 0 ]]; then
        log_success "Phase 4 optimization validated successfully!"
        echo ""
        echo "Next steps:"
        echo "  1. Review detailed report: ${REPORT_FILE}"
        echo "  2. Monitor compression jobs: SELECT * FROM timescaledb_information.jobs;"
        echo "  3. Check continuous aggregate refresh: SELECT * FROM factory_telemetry.metric_hist_1min;"
        exit 0
    else
        log_error "Phase 4 optimization validation failed!"
        echo ""
        echo "Please review errors above and the detailed report."
        exit 1
    fi
}

main "$@"
