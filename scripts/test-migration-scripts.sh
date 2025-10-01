#!/bin/bash
#==============================================================================
# MS5.0 Migration Scripts Test Suite
#==============================================================================
#
# Comprehensive test suite for migration scripts
# Tests migration runner, validation scripts, and backup/rollback procedures
# with automated test execution and reporting.
#
# Usage: ./test-migration-scripts.sh [--environment=test] [--verbose]
#==============================================================================

set -euo pipefail  # Strict error handling

#==============================================================================
# Configuration & Constants
#==============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly TEST_DIR="${PROJECT_ROOT}/tests/migration"
readonly LOG_DIR="${PROJECT_ROOT}/logs/tests"
readonly BACKUP_DIR="${PROJECT_ROOT}/backups"

# Test configuration
ENVIRONMENT="${1:-test}"
VERBOSE=false
CLEANUP=true
PARALLEL_TESTS=false

# Test database configuration
case "${ENVIRONMENT}" in
    test)
        DB_HOST="${DB_HOST:-localhost}"
        DB_PORT="${DB_PORT:-5435}"
        DB_NAME="${DB_NAME:-factory_telemetry_test}"
        DB_USER="${DB_USER:-ms5_user_test}"
        DB_PASSWORD="${POSTGRES_PASSWORD_TEST:-test_password}"
        CONTAINER_NAME="ms5_postgres_test"
        ;;
    *)
        echo "❌ Invalid test environment: ${ENVIRONMENT}"
        echo "Valid environments: test"
        exit 1
        ;;
esac

# Test results tracking
declare -A TEST_RESULTS
declare -A TEST_DURATIONS
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

#==============================================================================
# Logging Framework
#==============================================================================

# Initialize logging
init_logging() {
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    LOG_FILE="${LOG_DIR}/migration_tests_${ENVIRONMENT}_${timestamp}.log"
    
    mkdir -p "${LOG_DIR}"
    
    # Create log file with header
    cat > "${LOG_FILE}" << EOF
==============================================================================
MS5.0 Migration Scripts Test Suite Log
==============================================================================
Environment: ${ENVIRONMENT}
Started: $(date '+%Y-%m-%d %H:%M:%S UTC')
Database: ${DB_NAME}@${DB_HOST}:${DB_PORT}
User: ${DB_USER}
Test Suite Version: 1.0.0
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

# Test result logging
log_test_result() {
    local test_name="$1"
    local result="$2"
    local duration="$3"
    local message="$4"
    
    TEST_RESULTS["${test_name}"]="${result}"
    TEST_DURATIONS["${test_name}"]="${duration}"
    
    if [[ "${result}" == "PASS" ]]; then
        log_success "✅ ${test_name} - PASSED (${duration}ms)"
        ((PASSED_TESTS++))
    else
        log_error "❌ ${test_name} - FAILED (${duration}ms): ${message}"
        ((FAILED_TESTS++))
    fi
    
    ((TOTAL_TESTS++))
}

#==============================================================================
# Test Environment Setup
#==============================================================================

# Setup test database
setup_test_database() {
    log_info "Setting up test database..."
    
    # Create test database
    if ! PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "postgres" -c "
        CREATE DATABASE ${DB_NAME};
    " >/dev/null 2>&1; then
        log_warn "Test database may already exist"
    fi
    
    # Create TimescaleDB extension
    PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c "
        CREATE EXTENSION IF NOT EXISTS timescaledb;
    " >/dev/null 2>&1
    
    log_success "Test database setup completed"
}

# Cleanup test database
cleanup_test_database() {
    if [[ "${CLEANUP}" == "true" ]]; then
        log_info "Cleaning up test database..."
        
        # Drop test database
        PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "postgres" -c "
            DROP DATABASE IF EXISTS ${DB_NAME};
        " >/dev/null 2>&1
        
        log_success "Test database cleanup completed"
    fi
}

# Create test data
create_test_data() {
    log_info "Creating test data..."
    
    # Create basic test schema
    PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c "
        CREATE SCHEMA IF NOT EXISTS factory_telemetry;
        
        CREATE TABLE IF NOT EXISTS factory_telemetry.metric_def (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            equipment_code TEXT NOT NULL,
            metric_key TEXT NOT NULL,
            value_type TEXT NOT NULL CHECK (value_type IN ('BOOL','INT','REAL','TEXT','JSON')),
            unit TEXT NULL,
            description TEXT NOT NULL,
            UNIQUE (equipment_code, metric_key)
        );
        
        INSERT INTO factory_telemetry.metric_def (equipment_code, metric_key, value_type, description) VALUES
            ('EQUIP001', 'temperature', 'REAL', 'Equipment temperature'),
            ('EQUIP001', 'pressure', 'REAL', 'Equipment pressure'),
            ('EQUIP002', 'speed', 'REAL', 'Equipment speed');
    " >/dev/null 2>&1
    
    log_success "Test data created"
}

#==============================================================================
# Test Execution Framework
#==============================================================================

# Execute a single test
execute_test() {
    local test_name="$1"
    local test_function="$2"
    shift 2
    local test_args=("$@")
    
    log_info "Running test: ${test_name}"
    
    local start_time
    start_time=$(date +%s%3N)
    
    if "${test_function}" "${test_args[@]}"; then
        local end_time
        end_time=$(date +%s%3N)
        local duration=$((end_time - start_time))
        log_test_result "${test_name}" "PASS" "${duration}" ""
    else
        local end_time
        end_time=$(date +%s%3N)
        local duration=$((end_time - start_time))
        log_test_result "${test_name}" "FAIL" "${duration}" "Test execution failed"
    fi
}

# Run test suite
run_test_suite() {
    log_info "Starting migration scripts test suite"
    
    # Test environment setup
    execute_test "test_environment_setup" test_environment_setup
    
    # Migration runner tests
    execute_test "test_migration_runner_help" test_migration_runner_help
    execute_test "test_migration_runner_dry_run" test_migration_runner_dry_run
    execute_test "test_migration_runner_validation" test_migration_runner_validation
    
    # Pre-migration validation tests
    execute_test "test_pre_validation_help" test_pre_validation_help
    execute_test "test_pre_validation_environment" test_pre_validation_environment
    execute_test "test_pre_validation_timescaledb" test_pre_validation_timescaledb
    
    # Post-migration validation tests
    execute_test "test_post_validation_help" test_post_validation_help
    execute_test "test_post_validation_connectivity" test_post_validation_connectivity
    
    # Backup and rollback tests
    execute_test "test_backup_manager_help" test_backup_manager_help
    execute_test "test_backup_creation" test_backup_creation
    execute_test "test_backup_verification" test_backup_verification
    execute_test "test_backup_restoration" test_backup_restoration
    
    # Integration tests
    execute_test "test_migration_integration" test_migration_integration
    execute_test "test_rollback_integration" test_rollback_integration
    
    # Performance tests
    execute_test "test_performance_benchmarks" test_performance_benchmarks
    
    # Generate test report
    generate_test_report
}

#==============================================================================
# Individual Test Functions
#==============================================================================

# Test environment setup
test_environment_setup() {
    # Test database connectivity
    if ! PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c "SELECT 1;" >/dev/null 2>&1; then
        log_error "Test database connection failed"
        return 1
    fi
    
    # Test TimescaleDB extension
    local extension_check
    extension_check=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "
        SELECT 1 FROM pg_extension WHERE extname = 'timescaledb';
    " 2>/dev/null || echo "")
    
    if [[ "${extension_check}" != "1" ]]; then
        log_error "TimescaleDB extension not found"
        return 1
    fi
    
    return 0
}

# Test migration runner help
test_migration_runner_help() {
    if ! "${SCRIPT_DIR}/migration-runner.sh" --help >/dev/null 2>&1; then
        log_error "Migration runner help command failed"
        return 1
    fi
    return 0
}

# Test migration runner dry run
test_migration_runner_dry_run() {
    # Test dry run mode
    if ! "${SCRIPT_DIR}/migration-runner.sh" --environment="${ENVIRONMENT}" --dry-run >/dev/null 2>&1; then
        log_error "Migration runner dry run failed"
        return 1
    fi
    return 0
}

# Test migration runner validation
test_migration_runner_validation() {
    # Test with invalid environment
    if "${SCRIPT_DIR}/migration-runner.sh" --environment="invalid" >/dev/null 2>&1; then
        log_error "Migration runner should fail with invalid environment"
        return 1
    fi
    return 0
}

# Test pre-migration validation help
test_pre_validation_help() {
    if ! "${SCRIPT_DIR}/pre-migration-validation.sh" --help >/dev/null 2>&1; then
        log_error "Pre-migration validation help command failed"
        return 1
    fi
    return 0
}

# Test pre-migration validation environment
test_pre_validation_environment() {
    # Test with test environment
    if ! "${SCRIPT_DIR}/pre-migration-validation.sh" --environment="${ENVIRONMENT}" --quick >/dev/null 2>&1; then
        log_error "Pre-migration validation failed for test environment"
        return 1
    fi
    return 0
}

# Test pre-migration validation TimescaleDB
test_pre_validation_timescaledb() {
    # Test TimescaleDB validation
    local validation_output
    validation_output=$("${SCRIPT_DIR}/pre-migration-validation.sh" --environment="${ENVIRONMENT}" --quick 2>&1)
    
    if ! echo "${validation_output}" | grep -q "TimescaleDB extension verified"; then
        log_error "TimescaleDB validation not found in output"
        return 1
    fi
    return 0
}

# Test post-migration validation help
test_post_validation_help() {
    if ! "${SCRIPT_DIR}/post-migration-validation.sh" --help >/dev/null 2>&1; then
        log_error "Post-migration validation help command failed"
        return 1
    fi
    return 0
}

# Test post-migration validation connectivity
test_post_validation_connectivity() {
    # Test connectivity validation
    if ! "${SCRIPT_DIR}/post-migration-validation.sh" --environment="${ENVIRONMENT}" --no-data-integrity >/dev/null 2>&1; then
        log_error "Post-migration validation connectivity test failed"
        return 1
    fi
    return 0
}

# Test backup manager help
test_backup_manager_help() {
    if ! "${SCRIPT_DIR}/backup-rollback-manager.sh" help >/dev/null 2>&1; then
        log_error "Backup manager help command failed"
        return 1
    fi
    return 0
}

# Test backup creation
test_backup_creation() {
    local backup_name="test_backup_$(date +%Y%m%d_%H%M%S)"
    
    # Create test backup
    if ! "${SCRIPT_DIR}/backup-rollback-manager.sh" backup "${backup_name}" schema --environment="${ENVIRONMENT}" >/dev/null 2>&1; then
        log_error "Backup creation failed"
        return 1
    fi
    
    # Verify backup exists
    if [[ ! -d "${BACKUP_DIR}/${backup_name}" ]]; then
        log_error "Backup directory not created"
        return 1
    fi
    
    # Cleanup test backup
    rm -rf "${BACKUP_DIR}/${backup_name}"
    
    return 0
}

# Test backup verification
test_backup_verification() {
    local backup_name="test_verify_$(date +%Y%m%d_%H%M%S)"
    
    # Create test backup
    "${SCRIPT_DIR}/backup-rollback-manager.sh" backup "${backup_name}" schema --environment="${ENVIRONMENT}" >/dev/null 2>&1
    
    # Verify backup
    if ! "${SCRIPT_DIR}/backup-rollback-manager.sh" verify "${backup_name}" --environment="${ENVIRONMENT}" >/dev/null 2>&1; then
        log_error "Backup verification failed"
        rm -rf "${BACKUP_DIR}/${backup_name}"
        return 1
    fi
    
    # Cleanup test backup
    rm -rf "${BACKUP_DIR}/${backup_name}"
    
    return 0
}

# Test backup restoration
test_backup_restoration() {
    local backup_name="test_restore_$(date +%Y%m%d_%H%M%S)"
    
    # Create test backup
    "${SCRIPT_DIR}/backup-rollback-manager.sh" backup "${backup_name}" schema --environment="${ENVIRONMENT}" >/dev/null 2>&1
    
    # Test restoration (dry run)
    if ! "${SCRIPT_DIR}/backup-rollback-manager.sh" restore "${backup_name}" --environment="${ENVIRONMENT}" --force >/dev/null 2>&1; then
        log_error "Backup restoration failed"
        rm -rf "${BACKUP_DIR}/${backup_name}"
        return 1
    fi
    
    # Cleanup test backup
    rm -rf "${BACKUP_DIR}/${backup_name}"
    
    return 0
}

# Test migration integration
test_migration_integration() {
    # Test full migration workflow
    local test_migration_dir="${TEST_DIR}/test_migrations"
    mkdir -p "${test_migration_dir}"
    
    # Create test migration file
    cat > "${test_migration_dir}/001_test_migration.sql" << 'EOF'
-- Test migration
CREATE TABLE IF NOT EXISTS factory_telemetry.test_table (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create hypertable
SELECT create_hypertable('factory_telemetry.test_table', 'created_at', if_not_exists => TRUE);
EOF
    
    # Test migration runner with test migrations
    if ! "${SCRIPT_DIR}/migration-runner.sh" --environment="${ENVIRONMENT}" --dry-run >/dev/null 2>&1; then
        log_error "Migration integration test failed"
        rm -rf "${test_migration_dir}"
        return 1
    fi
    
    # Cleanup
    rm -rf "${test_migration_dir}"
    
    return 0
}

# Test rollback integration
test_rollback_integration() {
    # Test rollback workflow
    local rollback_name="test_rollback_$(date +%Y%m%d_%H%M%S)"
    
    # Create rollback point
    if ! "${SCRIPT_DIR}/backup-rollback-manager.sh" backup "${rollback_name}" full --environment="${ENVIRONMENT}" >/dev/null 2>&1; then
        log_error "Rollback point creation failed"
        return 1
    fi
    
    # Test rollback script creation
    local rollback_dir="${PROJECT_ROOT}/rollback/${rollback_name}"
    if [[ ! -d "${rollback_dir}" ]]; then
        log_error "Rollback directory not created"
        rm -rf "${BACKUP_DIR}/${rollback_name}"
        return 1
    fi
    
    # Cleanup
    rm -rf "${BACKUP_DIR}/${rollback_name}"
    rm -rf "${rollback_dir}"
    
    return 0
}

# Test performance benchmarks
test_performance_benchmarks() {
    # Test script execution performance
    local start_time
    start_time=$(date +%s%3N)
    
    # Run quick validation
    "${SCRIPT_DIR}/pre-migration-validation.sh" --environment="${ENVIRONMENT}" --quick >/dev/null 2>&1
    
    local end_time
    end_time=$(date +%s%3N)
    local duration=$((end_time - start_time))
    
    # Performance threshold: should complete in less than 5 seconds
    if [[ ${duration} -gt 5000 ]]; then
        log_error "Performance test failed: validation took ${duration}ms (>5000ms threshold)"
        return 1
    fi
    
    log_debug "Performance test passed: validation took ${duration}ms"
    return 0
}

#==============================================================================
# Test Report Generation
#==============================================================================

# Generate test report
generate_test_report() {
    local report_file="${LOG_DIR}/test_report_$(date +%Y%m%d_%H%M%S).html"
    
    log_info "Generating test report..."
    
    cat > "${report_file}" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>MS5.0 Migration Scripts Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 20px; border-radius: 5px; }
        .summary { background-color: #e8f5e8; padding: 15px; border-radius: 5px; margin: 20px 0; }
        .failed { background-color: #ffe8e8; }
        .test-results { margin: 20px 0; }
        .test-item { padding: 10px; margin: 5px 0; border-radius: 3px; }
        .pass { background-color: #d4edda; }
        .fail { background-color: #f8d7da; }
        .metrics { display: flex; justify-content: space-around; margin: 20px 0; }
        .metric { text-align: center; padding: 10px; background-color: #f8f9fa; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>MS5.0 Migration Scripts Test Report</h1>
        <p>Generated: $(date '+%Y-%m-%d %H:%M:%S UTC')</p>
        <p>Environment: ${ENVIRONMENT}</p>
        <p>Database: ${DB_NAME}@${DB_HOST}:${DB_PORT}</p>
    </div>
    
    <div class="summary ${FAILED_TESTS -gt 0 && echo 'failed' || echo ''}">
        <h2>Test Summary</h2>
        <div class="metrics">
            <div class="metric">
                <h3>${TOTAL_TESTS}</h3>
                <p>Total Tests</p>
            </div>
            <div class="metric">
                <h3 style="color: green;">${PASSED_TESTS}</h3>
                <p>Passed</p>
            </div>
            <div class="metric">
                <h3 style="color: red;">${FAILED_TESTS}</h3>
                <p>Failed</p>
            </div>
            <div class="metric">
                <h3>$(( (PASSED_TESTS * 100) / TOTAL_TESTS ))%</h3>
                <p>Success Rate</p>
            </div>
        </div>
    </div>
    
    <div class="test-results">
        <h2>Test Results</h2>
EOF
    
    # Add test results
    for test_name in "${!TEST_RESULTS[@]}"; do
        local result="${TEST_RESULTS[${test_name}]}"
        local duration="${TEST_DURATIONS[${test_name}]}"
        local css_class="pass"
        
        if [[ "${result}" == "FAIL" ]]; then
            css_class="fail"
        fi
        
        cat >> "${report_file}" << EOF
        <div class="test-item ${css_class}">
            <strong>${test_name}</strong> - ${result} (${duration}ms)
        </div>
EOF
    done
    
    cat >> "${report_file}" << EOF
    </div>
    
    <div class="footer">
        <p>Test log file: ${LOG_FILE}</p>
        <p>MS5.0 Migration Scripts Test Suite v1.0.0</p>
    </div>
</body>
</html>
EOF
    
    log_success "Test report generated: ${report_file}"
    
    # Print summary to console
    echo ""
    echo "==============================================================================="
    echo "TEST SUMMARY"
    echo "==============================================================================="
    echo "Total Tests: ${TOTAL_TESTS}"
    echo "Passed: ${PASSED_TESTS}"
    echo "Failed: ${FAILED_TESTS}"
    echo "Success Rate: $(( (PASSED_TESTS * 100) / TOTAL_TESTS ))%"
    echo "==============================================================================="
    
    if [[ ${FAILED_TESTS} -gt 0 ]]; then
        echo "❌ Some tests failed. Check the log file for details: ${LOG_FILE}"
        return 1
    else
        echo "✅ All tests passed!"
        return 0
    fi
}

#==============================================================================
# Main Execution
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
            --no-cleanup)
                CLEANUP=false
                shift
                ;;
            --parallel)
                PARALLEL_TESTS=true
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
MS5.0 Migration Scripts Test Suite

USAGE:
    $0 [options]

OPTIONS:
    --environment=ENV    Test environment (default: test)
    --verbose           Enable detailed debug logging
    --no-cleanup        Skip cleanup of test resources
    --parallel          Run tests in parallel (experimental)
    --help              Show this help message

EXAMPLES:
    $0                                    # Run all tests
    $0 --verbose                         # Run tests with debug output
    $0 --no-cleanup                      # Skip cleanup after tests

ENVIRONMENT VARIABLES:
    DB_HOST             Test database host (default: localhost)
    DB_PORT             Test database port (default: 5435)
    DB_NAME             Test database name (default: factory_telemetry_test)
    DB_USER             Test database user (default: ms5_user_test)
    POSTGRES_PASSWORD_TEST Test database password (default: test_password)

EOF
}

# Main execution function
main() {
    # Initialize logging
    init_logging
    
    log_info "Starting MS5.0 migration scripts test suite"
    log_info "Environment: ${ENVIRONMENT}"
    log_info "Verbose: ${VERBOSE}"
    log_info "Cleanup: ${CLEANUP}"
    
    # Setup test environment
    setup_test_database
    create_test_data
    
    # Run test suite
    if run_test_suite; then
        log_success "All tests completed successfully"
        exit_code=0
    else
        log_error "Some tests failed"
        exit_code=1
    fi
    
    # Cleanup
    cleanup_test_database
    
    log_info "Test suite completed"
    exit ${exit_code}
}

#==============================================================================
# Script Entry Point
#==============================================================================

# Parse arguments and execute main function
parse_arguments "$@"
main "$@"
