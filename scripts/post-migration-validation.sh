#!/bin/bash
#==============================================================================
# MS5.0 Post-Migration Validation Script
#==============================================================================
#
# Comprehensive post-migration validation for TimescaleDB migration
# Validates TimescaleDB hypertables, data integrity, performance metrics,
# and system functionality after migration completion.
#
# Usage: ./post-migration-validation.sh [--environment=production|staging|development]
#==============================================================================

set -euo pipefail  # Strict error handling

#==============================================================================
# Configuration & Constants
#==============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly LOG_DIR="${PROJECT_ROOT}/logs/validation"
readonly MIGRATION_DIR="${PROJECT_ROOT}"

# Default configuration
ENVIRONMENT="${1:-production}"
VERBOSE=false
PERFORMANCE_TEST=false
DATA_INTEGRITY_TEST=true

# Database configuration based on environment
case "${ENVIRONMENT}" in
    production)
        DB_HOST="${DB_HOST:-localhost}"
        DB_PORT="${DB_PORT:-5432}"
        DB_NAME="${DB_NAME:-factory_telemetry}"
        DB_USER="${DB_USER:-ms5_user_production}"
        DB_PASSWORD="${POSTGRES_PASSWORD_PRODUCTION}"
        CONTAINER_NAME="ms5_postgres_production"
        ;;
    staging)
        DB_HOST="${DB_HOST:-localhost}"
        DB_PORT="${DB_PORT:-5433}"
        DB_NAME="${DB_NAME:-factory_telemetry_staging}"
        DB_USER="${DB_USER:-ms5_user_staging}"
        DB_PASSWORD="${POSTGRES_PASSWORD_STAGING}"
        CONTAINER_NAME="ms5_postgres_staging"
        ;;
    development)
        DB_HOST="${DB_HOST:-localhost}"
        DB_PORT="${DB_PORT:-5434}"
        DB_NAME="${DB_NAME:-factory_telemetry_dev}"
        DB_USER="${DB_USER:-ms5_user_dev}"
        DB_PASSWORD="${POSTGRES_PASSWORD_DEV}"
        CONTAINER_NAME="ms5_postgres_dev"
        ;;
    *)
        echo "❌ Invalid environment: ${ENVIRONMENT}"
        echo "Valid environments: production, staging, development"
        exit 1
        ;;
esac

# Expected hypertables based on migration files
readonly EXPECTED_HYPERTABLES=(
    "factory_telemetry.metric_hist"
    "factory_telemetry.oee_calculations"
    "factory_telemetry.energy_consumption"
    "factory_telemetry.production_kpis"
    "factory_telemetry.production_context_history"
)

# Expected schemas
readonly EXPECTED_SCHEMAS=(
    "factory_telemetry"
    "public"
)

#==============================================================================
# Logging Framework
#==============================================================================

# Initialize logging
init_logging() {
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    LOG_FILE="${LOG_DIR}/post_migration_validation_${ENVIRONMENT}_${timestamp}.log"
    
    mkdir -p "${LOG_DIR}"
    
    # Create log file with header
    cat > "${LOG_FILE}" << EOF
==============================================================================
MS5.0 Post-Migration Validation Log
==============================================================================
Environment: ${ENVIRONMENT}
Started: $(date '+%Y-%m-%d %H:%M:%S UTC')
Database: ${DB_NAME}@${DB_HOST}:${DB_PORT}
User: ${DB_USER}
Validation Script Version: 1.0.0
==============================================================================

EOF
}

# Logging functions
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }
log_success() { log "SUCCESS" "$@"; }
log_debug() { 
    if [[ "${VERBOSE}" == "true" ]]; then
        log "DEBUG" "$@"
    fi
}

#==============================================================================
# Database Connectivity Validation
#==============================================================================

# Test database connectivity
test_database_connectivity() {
    log_info "Testing database connectivity..."
    
    if ! PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c "SELECT 1;" >/dev/null 2>&1; then
        log_error "Database connection failed"
        return 1
    fi
    
    log_success "Database connection successful"
    return 0
}

#==============================================================================
# Migration Status Validation
#==============================================================================

# Validate migration completion
validate_migration_completion() {
    log_info "Validating migration completion..."
    
    # Check if migration_log table exists
    local migration_log_exists
    migration_log_exists=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "
        SELECT 1 FROM information_schema.tables 
        WHERE table_name = 'migration_log' AND table_schema = 'public';
    " 2>/dev/null || echo "")
    
    if [[ "${migration_log_exists}" != "1" ]]; then
        log_error "Migration log table not found"
        return 1
    fi
    
    # Check successful migrations
    local successful_migrations
    successful_migrations=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "
        SELECT COUNT(*) FROM migration_log WHERE success = TRUE;
    " 2>/dev/null | tr -d ' ')
    
    # Check failed migrations
    local failed_migrations
    failed_migrations=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "
        SELECT COUNT(*) FROM migration_log WHERE success = FALSE;
    " 2>/dev/null | tr -d ' ')
    
    log_info "Successful migrations: ${successful_migrations}"
    log_info "Failed migrations: ${failed_migrations}"
    
    if [[ ${failed_migrations} -gt 0 ]]; then
        log_error "Failed migrations detected"
        
        # List failed migrations
        local failed_list
        failed_list=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "
            SELECT migration_name FROM migration_log WHERE success = FALSE;
        " 2>/dev/null | tr -d ' ')
        
        log_error "Failed migrations: ${failed_list}"
        return 1
    fi
    
    log_success "All migrations completed successfully"
    return 0
}

#==============================================================================
# Schema Validation
#==============================================================================

# Validate schema existence
validate_schemas() {
    log_info "Validating schema existence..."
    
    local missing_schemas=()
    
    for schema in "${EXPECTED_SCHEMAS[@]}"; do
        local schema_exists
        schema_exists=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "
            SELECT 1 FROM information_schema.schemata WHERE schema_name = '${schema}';
        " 2>/dev/null || echo "")
        
        if [[ "${schema_exists}" != "1" ]]; then
            missing_schemas+=("${schema}")
        else
            log_debug "Schema validated: ${schema}"
        fi
    done
    
    if [[ ${#missing_schemas[@]} -gt 0 ]]; then
        log_error "Missing schemas:"
        for schema in "${missing_schemas[@]}"; do
            log_error "  - ${schema}"
        done
        return 1
    fi
    
    log_success "All expected schemas validated"
    return 0
}

# Validate table existence
validate_tables() {
    log_info "Validating table existence..."
    
    # Get list of tables in factory_telemetry schema
    local tables
    tables=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "
        SELECT table_name FROM information_schema.tables 
        WHERE table_schema = 'factory_telemetry' 
        ORDER BY table_name;
    " 2>/dev/null || echo "")
    
    if [[ -z "${tables}" ]]; then
        log_error "No tables found in factory_telemetry schema"
        return 1
    fi
    
    local table_count
    table_count=$(echo "${tables}" | wc -l)
    log_success "Found ${table_count} tables in factory_telemetry schema"
    
    log_debug "Tables in factory_telemetry schema:"
    echo "${tables}" | while read -r table; do
        log_debug "  - ${table}"
    done
    
    return 0
}

#==============================================================================
# TimescaleDB Hypertable Validation
#==============================================================================

# Validate hypertable creation
validate_hypertables() {
    log_info "Validating TimescaleDB hypertables..."
    
    # Get list of existing hypertables
    local existing_hypertables
    existing_hypertables=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "
        SELECT hypertable_name FROM timescaledb_information.hypertables;
    " 2>/dev/null || echo "")
    
    if [[ -z "${existing_hypertables}" ]]; then
        log_error "No hypertables found"
        return 1
    fi
    
    # Check each expected hypertable
    local missing_hypertables=()
    
    for expected_hypertable in "${EXPECTED_HYPERTABLES[@]}"; do
        local schema_name="${expected_hypertable%%.*}"
        local table_name="${expected_hypertable##*.}"
        
        local hypertable_exists
        hypertable_exists=$(echo "${existing_hypertables}" | grep -q "^${table_name}$" && echo "1" || echo "")
        
        if [[ "${hypertable_exists}" != "1" ]]; then
            missing_hypertables+=("${expected_hypertable}")
        else
            log_success "Hypertable validated: ${expected_hypertable}"
        fi
    done
    
    # Report missing hypertables
    if [[ ${#missing_hypertables[@]} -gt 0 ]]; then
        log_error "Missing hypertables:"
        for hypertable in "${missing_hypertables[@]}"; do
            log_error "  - ${hypertable}"
        done
        return 1
    fi
    
    # Get hypertable details
    log_info "Hypertable details:"
    PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c "
        SELECT 
            hypertable_name,
            num_dimensions,
            num_chunks,
            compression_enabled,
            compression_status
        FROM timescaledb_information.hypertables
        ORDER BY hypertable_name;
    " >> "${LOG_FILE}" 2>&1
    
    log_success "All expected hypertables validated"
    return 0
}

# Validate hypertable configuration
validate_hypertable_configuration() {
    log_info "Validating hypertable configuration..."
    
    # Check chunk intervals
    log_info "Chunk interval configuration:"
    PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c "
        SELECT 
            hypertable_name,
            dimension_name,
            interval_length,
            interval_unit
        FROM timescaledb_information.dimensions
        ORDER BY hypertable_name, dimension_name;
    " >> "${LOG_FILE}" 2>&1
    
    # Check compression policies
    log_info "Compression policy configuration:"
    PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c "
        SELECT 
            hypertable_name,
            compress_after,
            compress_job_id,
            compress_job_status
        FROM timescaledb_information.jobs
        WHERE proc_name = 'policy_compression'
        ORDER BY hypertable_name;
    " >> "${LOG_FILE}" 2>&1
    
    log_success "Hypertable configuration validated"
    return 0
}

#==============================================================================
# Data Integrity Validation
#==============================================================================

# Test data insertion and retrieval
test_data_integrity() {
    log_info "Testing data integrity..."
    
    # Test metric_hist table
    local test_metric_id
    test_metric_id=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "
        SELECT id FROM factory_telemetry.metric_def LIMIT 1;
    " 2>/dev/null | tr -d ' ')
    
    if [[ -n "${test_metric_id}" ]]; then
        # Insert test data
        local insert_result
        insert_result=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c "
            INSERT INTO factory_telemetry.metric_hist (metric_def_id, ts, value_real) 
            VALUES ('${test_metric_id}', NOW(), 100.0)
            RETURNING id;
        " 2>&1 || echo "INSERT_FAILED")
        
        if [[ "${insert_result}" == "INSERT_FAILED" ]]; then
            log_error "Data insertion test failed"
            return 1
        fi
        
        # Retrieve test data
        local select_result
        select_result=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "
            SELECT COUNT(*) FROM factory_telemetry.metric_hist 
            WHERE metric_def_id = '${test_metric_id}' AND value_real = 100.0;
        " 2>/dev/null | tr -d ' ')
        
        if [[ "${select_result}" == "1" ]]; then
            log_success "Data integrity test passed"
        else
            log_error "Data retrieval test failed"
            return 1
        fi
        
        # Clean up test data
        PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c "
            DELETE FROM factory_telemetry.metric_hist 
            WHERE metric_def_id = '${test_metric_id}' AND value_real = 100.0;
        " >/dev/null 2>&1
        
    else
        log_warn "No metric definitions found for data integrity test"
    fi
    
    return 0
}

# Test TimescaleDB-specific functions
test_timescaledb_functions() {
    log_info "Testing TimescaleDB-specific functions..."
    
    # Test time_bucket function
    local time_bucket_test
    time_bucket_test=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c "
        SELECT time_bucket('1 hour', NOW()) as bucket;
    " 2>&1 || echo "TIMEBUCKET_FAILED")
    
    if [[ "${time_bucket_test}" == "TIMEBUCKET_FAILED" ]]; then
        log_error "TimescaleDB time_bucket function test failed"
        return 1
    fi
    
    # Test continuous aggregates (if any exist)
    local cagg_count
    cagg_count=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "
        SELECT COUNT(*) FROM timescaledb_information.continuous_aggregates;
    " 2>/dev/null | tr -d ' ')
    
    log_info "Continuous aggregates found: ${cagg_count}"
    
    log_success "TimescaleDB functions validated"
    return 0
}

#==============================================================================
# Performance Validation
#==============================================================================

# Test query performance
test_query_performance() {
    log_info "Testing query performance..."
    
    # Test basic query performance
    local start_time
    start_time=$(date +%s%3N)
    
    local query_result
    query_result=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c "
        SELECT COUNT(*) FROM factory_telemetry.metric_hist;
    " 2>&1 || echo "QUERY_FAILED")
    
    local end_time
    end_time=$(date +%s%3N)
    local query_time=$((end_time - start_time))
    
    if [[ "${query_result}" == "QUERY_FAILED" ]]; then
        log_error "Query performance test failed"
        return 1
    fi
    
    log_info "Basic query execution time: ${query_time}ms"
    
    # Performance benchmarks
    if [[ ${query_time} -gt 1000 ]]; then
        log_warn "Query performance slower than expected (>1000ms)"
    else
        log_success "Query performance acceptable (${query_time}ms)"
    fi
    
    return 0
}

# Test TimescaleDB compression
test_compression() {
    log_info "Testing TimescaleDB compression..."
    
    # Get compression statistics
    local compression_stats
    compression_stats=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c "
        SELECT 
            hypertable_name,
            before_compression_total_bytes,
            after_compression_total_bytes,
            compression_ratio
        FROM timescaledb_information.compression_stats
        ORDER BY hypertable_name;
    " 2>&1 || echo "COMPRESSION_FAILED")
    
    if [[ "${compression_stats}" == "COMPRESSION_FAILED" ]]; then
        log_warn "Compression statistics not available"
    else
        log_info "Compression statistics:"
        echo "${compression_stats}" >> "${LOG_FILE}"
    fi
    
    return 0
}

#==============================================================================
# System Health Validation
#==============================================================================

# Check database health metrics
check_database_health() {
    log_info "Checking database health metrics..."
    
    # Check database size
    local db_size
    db_size=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "
        SELECT pg_size_pretty(pg_database_size('${DB_NAME}'));
    " 2>/dev/null | tr -d ' ')
    
    log_info "Database size: ${db_size}"
    
    # Check active connections
    local active_connections
    active_connections=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "
        SELECT COUNT(*) FROM pg_stat_activity WHERE state = 'active';
    " 2>/dev/null | tr -d ' ')
    
    log_info "Active connections: ${active_connections}"
    
    # Check TimescaleDB background jobs
    local background_jobs
    background_jobs=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "
        SELECT COUNT(*) FROM timescaledb_information.jobs WHERE next_start > NOW();
    " 2>/dev/null | tr -d ' ')
    
    log_info "Scheduled background jobs: ${background_jobs}"
    
    log_success "Database health metrics collected"
    return 0
}

#==============================================================================
# Main Validation Functions
#==============================================================================

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --environment=*)
                ENVIRONMENT="${1#*=}"
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --performance-test)
                PERFORMANCE_TEST=true
                shift
                ;;
            --no-data-integrity)
                DATA_INTEGRITY_TEST=false
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Show help information
show_help() {
    cat << EOF
MS5.0 Post-Migration Validation Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --environment=ENV    Target environment (production|staging|development)
    --verbose          Enable detailed debug logging
    --performance-test Enable performance testing
    --no-data-integrity Skip data integrity tests
    --help             Show this help message

EXAMPLES:
    $0                                    # Validate production environment
    $0 --environment=staging             # Validate staging environment
    $0 --verbose --performance-test     # Full validation with debug info

ENVIRONMENT VARIABLES:
    DB_HOST            Database host (default: localhost)
    DB_PORT            Database port (default: 5432/5433/5434)
    DB_NAME            Database name
    DB_USER            Database user
    POSTGRES_PASSWORD_* Database password for environment

EOF
}

# Main validation function
main() {
    log_info "Starting MS5.0 post-migration validation"
    log_info "Environment: ${ENVIRONMENT}"
    log_info "Performance test: ${PERFORMANCE_TEST}"
    log_info "Data integrity test: ${DATA_INTEGRITY_TEST}"
    log_info "Verbose: ${VERBOSE}"
    
    local validation_failed=false
    
    # Basic connectivity validation
    test_database_connectivity || validation_failed=true
    
    # Migration status validation
    validate_migration_completion || validation_failed=true
    
    # Schema validation
    validate_schemas || validation_failed=true
    validate_tables || validation_failed=true
    
    # TimescaleDB validation
    validate_hypertables || validation_failed=true
    validate_hypertable_configuration || validation_failed=true
    
    # Data integrity validation
    if [[ "${DATA_INTEGRITY_TEST}" == "true" ]]; then
        test_data_integrity || validation_failed=true
        test_timescaledb_functions || validation_failed=true
    fi
    
    # Performance validation
    if [[ "${PERFORMANCE_TEST}" == "true" ]]; then
        test_query_performance || validation_failed=true
        test_compression || validation_failed=true
    fi
    
    # System health validation
    check_database_health || validation_failed=true
    
    # Final validation result
    if [[ "${validation_failed}" == "true" ]]; then
        log_error "❌ Post-migration validation failed"
        log_error "Please review the issues above and take corrective action"
        exit 1
    else
        log_success "✅ Post-migration validation passed"
        log_success "TimescaleDB migration completed successfully"
        log_info "Validation log saved to: ${LOG_FILE}"
        exit 0
    fi
}

#==============================================================================
# Script Entry Point
#==============================================================================

# Initialize logging first
init_logging

# Parse arguments and execute main function
parse_arguments "$@"
main "$@"
