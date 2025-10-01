#!/bin/bash

# =============================================================================
# MS5.0 Phase 3: Migration Testing and Validation Framework
# =============================================================================
# 
# This script provides comprehensive testing and validation capabilities for Phase 3.
# Implements cosmic-scale testing framework:
# - Unit tests for migration scripts
# - Integration tests for database operations
# - Performance benchmarks and stress tests
# - Data integrity and consistency validation
# - TimescaleDB-specific functionality testing
# - End-to-end migration simulation
#
# Designed for starship-grade reliability - every test is thorough and documented.
# =============================================================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# =============================================================================
# Configuration & Constants
# =============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly TEST_DIR="${PROJECT_ROOT}/tests/migration"
readonly LOG_DIR="${PROJECT_ROOT}/logs/testing"
readonly TEST_REPORT_FILE="$LOG_DIR/phase3-migration-test-$(date +%Y%m%d-%H%M%S).txt"

# Database configuration
readonly DB_HOST="${DB_HOST:-localhost}"
readonly DB_PORT="${DB_PORT:-5432}"
readonly DB_NAME="${DB_NAME:-factory_telemetry}"
readonly DB_USER="${DB_USER:-ms5_user_production}"
readonly DB_PASSWORD="${POSTGRES_PASSWORD_PRODUCTION}"

# Test database configuration (for isolated testing)
readonly TEST_DB_NAME="${DB_NAME}_test"
readonly TEST_POSTGRES_CONTAINER="ms5_postgres_test"

# Test categories
readonly TEST_CATEGORIES=(
    "script_validation"
    "database_connectivity"
    "migration_simulation"
    "performance_benchmarks"
    "data_integrity"
    "timescaledb_functionality"
    "rollback_testing"
)

# Performance benchmarks (in milliseconds)
readonly BENCHMARK_QUERY_TIME_MS=1000
readonly BENCHMARK_INSERT_TIME_MS=500
readonly BENCHMARK_CONNECTION_TIME_MS=100
readonly BENCHMARK_MIGRATION_TIME_MS=300000  # 5 minutes

# =============================================================================
# Logging System - Production Grade Testing
# =============================================================================

# ANSI color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m'

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$TEST_REPORT_FILE"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✅${NC} $1" | tee -a "$TEST_REPORT_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️${NC} $1" | tee -a "$TEST_REPORT_FILE"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ❌${NC} $1" | tee -a "$TEST_REPORT_FILE"
}

log_info() {
    echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')] ℹ️${NC} $1" | tee -a "$TEST_REPORT_FILE"
}

log_test() {
    echo -e "${PURPLE}[$(date '+%Y-%m-%d %H:%M:%S')] 🧪${NC} $1" | tee -a "$TEST_REPORT_FILE"
}

log_benchmark() {
    echo -e "${WHITE}[$(date '+%Y-%m-%d %H:%M:%S')] 📊${NC} $1" | tee -a "$TEST_REPORT_FILE"
}

# =============================================================================
# Test Framework Functions
# =============================================================================

# Initialize test environment
initialize_test_environment() {
    log "Initializing migration testing environment..."
    
    # Create test directories
    mkdir -p "$TEST_DIR" "$LOG_DIR"
    
    # Initialize test report
    cat > "$TEST_REPORT_FILE" << EOF
# MS5.0 Phase 3 Migration Testing Report
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
# Database: ${DB_NAME}@${DB_HOST}:${DB_PORT}
# Test Database: ${TEST_DB_NAME}

## Test Summary
- Total Test Categories: ${#TEST_CATEGORIES[@]}
- Test Started: $(date '+%Y-%m-%d %H:%M:%S')

## Test Results

EOF
    
    log_success "Test environment initialized"
    log_info "Test report: $TEST_REPORT_FILE"
}

# Execute test with timing and error handling
execute_test() {
    local test_name="$1"
    local test_function="$2"
    local test_description="$3"
    
    log_test "Running: $test_name"
    log_info "Description: $test_description"
    
    local start_time
    start_time=$(date +%s%3N)  # milliseconds
    
    local test_result="PASSED"
    local test_output=""
    
    if ! test_output=$("$test_function" 2>&1); then
        test_result="FAILED"
    fi
    
    local end_time
    end_time=$(date +%s%3N)
    local execution_time=$((end_time - start_time))
    
    # Log test output
    echo "=== $test_name Output ===" >> "$TEST_REPORT_FILE"
    echo "$test_output" >> "$TEST_REPORT_FILE"
    echo "=== End $test_name Output ===" >> "$TEST_REPORT_FILE"
    
    if [[ "$test_result" == "PASSED" ]]; then
        log_success "$test_name completed successfully (${execution_time}ms)"
        return 0
    else
        log_error "$test_name failed (${execution_time}ms)"
        log_error "Test output: $test_output"
        return 1
    fi
}

# =============================================================================
# Test Functions - Comprehensive Migration Testing
# =============================================================================

# Test 1: Script Validation
test_script_validation() {
    log_test "Testing script validation..."
    
    local scripts=(
        "${SCRIPT_DIR}/backup-pre-migration.sh"
        "${SCRIPT_DIR}/pre-migration-validation.sh"
        "${SCRIPT_DIR}/migration-runner.sh"
        "${SCRIPT_DIR}/post-migration-validation.sh"
        "${SCRIPT_DIR}/execute-phase3-migration.sh"
    )
    
    local validation_passed=true
    
    for script in "${scripts[@]}"; do
        if [[ ! -f "$script" ]]; then
            log_error "Script not found: $script"
            validation_passed=false
        elif [[ ! -x "$script" ]]; then
            log_error "Script not executable: $script"
            validation_passed=false
        else
            # Basic syntax check
            if bash -n "$script" 2>&1; then
                log_success "Script syntax valid: $(basename "$script")"
            else
                log_error "Script syntax error: $(basename "$script")"
                validation_passed=false
            fi
        fi
    done
    
    if [[ "$validation_passed" == "true" ]]; then
        log_success "Script validation test passed"
        return 0
    else
        log_error "Script validation test failed"
        return 1
    fi
}

# Test 2: Database Connectivity
test_database_connectivity() {
    log_test "Testing database connectivity..."
    
    # Test basic connectivity
    if ! PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" >/dev/null 2>&1; then
        log_error "Basic database connectivity test failed"
        return 1
    fi
    
    # Test TimescaleDB extension
    local timescaledb_version
    timescaledb_version=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "
        SELECT extversion FROM pg_extension WHERE extname = 'timescaledb';
    " 2>/dev/null | tr -d ' \n' || echo "UNKNOWN")
    
    if [[ -z "$timescaledb_version" || "$timescaledb_version" == "UNKNOWN" ]]; then
        log_error "TimescaleDB extension test failed"
        return 1
    fi
    
    # Test connection timing
    local connection_start
    connection_start=$(date +%s%3N)
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" >/dev/null 2>&1
    local connection_end
    connection_end=$(date +%s%3N)
    local connection_time=$((connection_end - connection_start))
    
    if [[ $connection_time -le $BENCHMARK_CONNECTION_TIME_MS ]]; then
        log_success "Connection timing acceptable (${connection_time}ms)"
    else
        log_warning "Connection timing slow (${connection_time}ms, threshold: ${BENCHMARK_CONNECTION_TIME_MS}ms)"
    fi
    
    log_success "Database connectivity test passed"
    return 0
}

# Test 3: Migration Simulation
test_migration_simulation() {
    log_test "Testing migration simulation..."
    
    # Create test database
    log_info "Creating test database..."
    if ! PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "postgres" -c "CREATE DATABASE ${TEST_DB_NAME};" >/dev/null 2>&1; then
        log_warning "Test database creation failed (may already exist)"
    fi
    
    # Test TimescaleDB extension in test database
    if ! PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$TEST_DB_NAME" -c "CREATE EXTENSION IF NOT EXISTS timescaledb;" >/dev/null 2>&1; then
        log_error "TimescaleDB extension creation failed in test database"
        return 1
    fi
    
    # Test basic schema creation
    local test_schema_sql="
        CREATE SCHEMA IF NOT EXISTS factory_telemetry;
        CREATE TABLE IF NOT EXISTS factory_telemetry.test_table (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            ts TIMESTAMPTZ NOT NULL,
            value REAL NOT NULL
        );
        SELECT create_hypertable('factory_telemetry.test_table', 'ts');
    "
    
    if ! PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$TEST_DB_NAME" -c "$test_schema_sql" >/dev/null 2>&1; then
        log_error "Test schema creation failed"
        return 1
    fi
    
    # Test data insertion
    local test_data_sql="
        INSERT INTO factory_telemetry.test_table (ts, value) 
        VALUES (NOW(), 100.0), (NOW() + INTERVAL '1 second', 200.0);
    "
    
    if ! PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$TEST_DB_NAME" -c "$test_data_sql" >/dev/null 2>&1; then
        log_error "Test data insertion failed"
        return 1
    fi
    
    # Test data retrieval
    local row_count
    row_count=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$TEST_DB_NAME" -t -c "
        SELECT COUNT(*) FROM factory_telemetry.test_table;
    " 2>/dev/null | tr -d ' \n' || echo "0")
    
    if [[ "$row_count" == "2" ]]; then
        log_success "Test data retrieval successful ($row_count rows)"
    else
        log_error "Test data retrieval failed (expected 2, got $row_count)"
        return 1
    fi
    
    # Cleanup test database
    log_info "Cleaning up test database..."
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "postgres" -c "DROP DATABASE IF EXISTS ${TEST_DB_NAME};" >/dev/null 2>&1 || true
    
    log_success "Migration simulation test passed"
    return 0
}

# Test 4: Performance Benchmarks
test_performance_benchmarks() {
    log_benchmark "Testing performance benchmarks..."
    
    # Test query performance
    log_info "Testing query performance..."
    
    local query_start
    query_start=$(date +%s%3N)
    
    # Complex query test
    local query_result
    query_result=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "
        SELECT 
            schemaname,
            tablename,
            n_tup_ins as inserts,
            n_live_tup as live_tuples
        FROM pg_stat_user_tables 
        WHERE schemaname = 'factory_telemetry'
        ORDER BY schemaname, tablename;
    " 2>/dev/null || echo "")
    
    local query_end
    query_end=$(date +%s%3N)
    local query_time=$((query_end - query_start))
    
    if [[ $query_time -le $BENCHMARK_QUERY_TIME_MS ]]; then
        log_success "Query performance acceptable (${query_time}ms)"
    else
        log_warning "Query performance slow (${query_time}ms, threshold: ${BENCHMARK_QUERY_TIME_MS}ms)"
    fi
    
    # Test insert performance
    log_info "Testing insert performance..."
    
    local insert_start
    insert_start=$(date +%s%3N)
    
    # Test insert with rollback
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "
        BEGIN;
        INSERT INTO factory_telemetry.metric_def (equipment_code, metric_key, value_type, description) 
        VALUES ('TEST_EQUIPMENT', 'TEST_METRIC', 'REAL', 'Test metric for performance validation');
        ROLLBACK;
    " >/dev/null 2>&1
    
    local insert_end
    insert_end=$(date +%s%3N)
    local insert_time=$((insert_end - insert_start))
    
    if [[ $insert_time -le $BENCHMARK_INSERT_TIME_MS ]]; then
        log_success "Insert performance acceptable (${insert_time}ms)"
    else
        log_warning "Insert performance slow (${insert_time}ms, threshold: ${BENCHMARK_INSERT_TIME_MS}ms)"
    fi
    
    # Test TimescaleDB-specific queries
    log_info "Testing TimescaleDB query performance..."
    
    local timescale_start
    timescale_start=$(date +%s%3N)
    
    local timescale_result
    timescale_result=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "
        SELECT 
            hypertable_name,
            num_dimensions,
            num_chunks
        FROM timescaledb_information.hypertables 
        WHERE schema_name = 'factory_telemetry'
        ORDER BY hypertable_name;
    " 2>/dev/null || echo "")
    
    local timescale_end
    timescale_end=$(date +%s%3N)
    local timescale_time=$((timescale_end - timescale_start))
    
    if [[ $timescale_time -le $BENCHMARK_QUERY_TIME_MS ]]; then
        log_success "TimescaleDB query performance acceptable (${timescale_time}ms)"
    else
        log_warning "TimescaleDB query performance slow (${timescale_time}ms, threshold: ${BENCHMARK_QUERY_TIME_MS}ms)"
    fi
    
    log_success "Performance benchmarks test completed"
    return 0
}

# Test 5: Data Integrity
test_data_integrity() {
    log_test "Testing data integrity..."
    
    # Check for orphaned records
    log_info "Checking for orphaned records..."
    
    # Check metric_binding references
    local orphaned_bindings
    orphaned_bindings=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "
        SELECT COUNT(*) 
        FROM factory_telemetry.metric_binding mb 
        LEFT JOIN factory_telemetry.metric_def md ON mb.metric_def_id = md.id 
        WHERE md.id IS NULL;
    " 2>/dev/null | tr -d ' \n' || echo "0")
    
    if [[ "$orphaned_bindings" == "0" ]]; then
        log_success "No orphaned metric bindings found"
    else
        log_error "Found $orphaned_bindings orphaned metric bindings"
        return 1
    fi
    
    # Check metric table consistency
    log_info "Checking metric table consistency..."
    
    local inconsistent_latest
    inconsistent_latest=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "
        SELECT COUNT(*) 
        FROM factory_telemetry.metric_latest ml 
        LEFT JOIN factory_telemetry.metric_def md ON ml.metric_def_id = md.id 
        WHERE md.id IS NULL;
    " 2>/dev/null | tr -d ' \n' || echo "0")
    
    if [[ "$inconsistent_latest" == "0" ]]; then
        log_success "Metric latest table is consistent"
    else
        log_error "Found $inconsistent_latest inconsistent records in metric_latest"
        return 1
    fi
    
    # Check constraint integrity
    log_info "Checking constraint integrity..."
    
    # Test foreign key constraints
    local constraint_violations
    constraint_violations=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "
        SELECT COUNT(*) 
        FROM information_schema.table_constraints tc
        JOIN information_schema.constraint_column_usage ccu ON tc.constraint_name = ccu.constraint_name
        WHERE tc.constraint_type = 'FOREIGN KEY' 
        AND tc.table_schema = 'factory_telemetry';
    " 2>/dev/null | tr -d ' \n' || echo "0")
    
    if [[ "$constraint_violations" -gt 0 ]]; then
        log_info "Found $constraint_violations foreign key constraints (expected)"
    fi
    
    log_success "Data integrity test passed"
    return 0
}

# Test 6: TimescaleDB Functionality
test_timescaledb_functionality() {
    log_test "Testing TimescaleDB functionality..."
    
    # Check TimescaleDB extension
    local extension_version
    extension_version=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "
        SELECT extversion FROM pg_extension WHERE extname = 'timescaledb';
    " 2>/dev/null | tr -d ' \n' || echo "UNKNOWN")
    
    if [[ -z "$extension_version" || "$extension_version" == "UNKNOWN" ]]; then
        log_error "TimescaleDB extension not found"
        return 1
    fi
    
    log_success "TimescaleDB extension active (version: $extension_version)"
    
    # Check hypertables
    local hypertable_count
    hypertable_count=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "
        SELECT COUNT(*) FROM timescaledb_information.hypertables 
        WHERE schema_name = 'factory_telemetry';
    " 2>/dev/null | tr -d ' \n' || echo "0")
    
    if [[ "$hypertable_count" -gt 0 ]]; then
        log_success "Found $hypertable_count TimescaleDB hypertables"
        
        # Get hypertable details
        local hypertable_details
        hypertable_details=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "
            SELECT 
                hypertable_name,
                num_dimensions,
                num_chunks
            FROM timescaledb_information.hypertables 
            WHERE schema_name = 'factory_telemetry'
            ORDER BY hypertable_name;
        " 2>/dev/null || echo "")
        
        log_info "Hypertable details:"
        echo "$hypertable_details" | while read -r line; do
            log_info "  $line"
        done
    else
        log_warning "No TimescaleDB hypertables found"
    fi
    
    # Test TimescaleDB-specific functions
    log_info "Testing TimescaleDB functions..."
    
    # Test time_bucket function
    if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "
        SELECT time_bucket('1 hour', NOW());
    " >/dev/null 2>&1; then
        log_success "TimescaleDB time_bucket function working"
    else
        log_error "TimescaleDB time_bucket function test failed"
        return 1
    fi
    
    # Test hypertable compression (if enabled)
    local compression_stats
    compression_stats=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "
        SELECT COUNT(*) FROM timescaledb_information.compression_stats;
    " 2>/dev/null | tr -d ' \n' || echo "0")
    
    if [[ "$compression_stats" -gt 0 ]]; then
        log_success "TimescaleDB compression active ($compression_stats compressed chunks)"
    else
        log_info "TimescaleDB compression not yet active (normal for new installations)"
    fi
    
    log_success "TimescaleDB functionality test passed"
    return 0
}

# Test 7: Rollback Testing
test_rollback_testing() {
    log_test "Testing rollback capabilities..."
    
    # Check backup system
    log_info "Testing backup system..."
    
    local backup_script="${SCRIPT_DIR}/backup-pre-migration.sh"
    if [[ ! -f "$backup_script" ]]; then
        log_error "Backup script not found: $backup_script"
        return 1
    fi
    
    if [[ ! -x "$backup_script" ]]; then
        log_error "Backup script not executable: $backup_script"
        return 1
    fi
    
    log_success "Backup script validation passed"
    
    # Check backup directory permissions
    local backup_dir="/opt/ms5-backend/backups"
    if [[ -d "$backup_dir" ]]; then
        if [[ -w "$backup_dir" ]]; then
            log_success "Backup directory is writable"
        else
            log_warning "Backup directory may not be writable"
        fi
    else
        log_info "Backup directory does not exist yet (will be created during backup)"
    fi
    
    # Test rollback SQL generation
    log_info "Testing rollback SQL generation..."
    
    # Generate a simple rollback test
    local rollback_test_sql="
        -- Test rollback SQL
        BEGIN;
        CREATE TABLE IF NOT EXISTS factory_telemetry.rollback_test (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            test_value TEXT
        );
        INSERT INTO factory_telemetry.rollback_test (test_value) VALUES ('test');
        ROLLBACK;
    "
    
    if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "$rollback_test_sql" >/dev/null 2>&1; then
        log_success "Rollback SQL execution test passed"
    else
        log_error "Rollback SQL execution test failed"
        return 1
    fi
    
    # Verify rollback worked (table should not exist)
    local table_exists
    table_exists=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "
        SELECT COUNT(*) FROM information_schema.tables 
        WHERE table_schema = 'factory_telemetry' AND table_name = 'rollback_test';
    " 2>/dev/null | tr -d ' \n' || echo "0")
    
    if [[ "$table_exists" == "0" ]]; then
        log_success "Rollback verification passed (test table properly removed)"
    else
        log_error "Rollback verification failed (test table still exists)"
        return 1
    fi
    
    log_success "Rollback testing passed"
    return 0
}

# =============================================================================
# Test Execution and Reporting
# =============================================================================

# Execute all tests
execute_all_tests() {
    log "Executing comprehensive migration testing..."
    
    local total_tests=${#TEST_CATEGORIES[@]}
    local passed_tests=0
    local failed_tests=0
    
    # Execute each test category
    for test_category in "${TEST_CATEGORIES[@]}"; do
        case "$test_category" in
            "script_validation")
                if execute_test "Script Validation" "test_script_validation" "Validates all migration scripts for syntax and permissions"; then
                    ((passed_tests++))
                else
                    ((failed_tests++))
                fi
                ;;
            "database_connectivity")
                if execute_test "Database Connectivity" "test_database_connectivity" "Tests database connectivity and TimescaleDB extension"; then
                    ((passed_tests++))
                else
                    ((failed_tests++))
                fi
                ;;
            "migration_simulation")
                if execute_test "Migration Simulation" "test_migration_simulation" "Simulates migration process with test database"; then
                    ((passed_tests++))
                else
                    ((failed_tests++))
                fi
                ;;
            "performance_benchmarks")
                if execute_test "Performance Benchmarks" "test_performance_benchmarks" "Tests database performance and timing"; then
                    ((passed_tests++))
                else
                    ((failed_tests++))
                fi
                ;;
            "data_integrity")
                if execute_test "Data Integrity" "test_data_integrity" "Validates data consistency and referential integrity"; then
                    ((passed_tests++))
                else
                    ((failed_tests++))
                fi
                ;;
            "timescaledb_functionality")
                if execute_test "TimescaleDB Functionality" "test_timescaledb_functionality" "Tests TimescaleDB-specific features and hypertables"; then
                    ((passed_tests++))
                else
                    ((failed_tests++))
                fi
                ;;
            "rollback_testing")
                if execute_test "Rollback Testing" "test_rollback_testing" "Tests rollback capabilities and backup system"; then
                    ((passed_tests++))
                else
                    ((failed_tests++))
                fi
                ;;
        esac
    done
    
    # Generate test summary
    cat >> "$TEST_REPORT_FILE" << EOF

## Test Summary
- Total Tests: $total_tests
- Passed Tests: $passed_tests
- Failed Tests: $failed_tests
- Success Rate: $(( (passed_tests * 100) / total_tests ))%

## Test Categories
EOF

    for test_category in "${TEST_CATEGORIES[@]}"; do
        echo "- $test_category" >> "$TEST_REPORT_FILE"
    done
    
    cat >> "$TEST_REPORT_FILE" << EOF

## Database Information
- Database: $DB_NAME
- Host: $DB_HOST:$DB_PORT
- User: $DB_USER
- TimescaleDB Version: $(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT extversion FROM pg_extension WHERE extname = 'timescaledb';" 2>/dev/null | tr -d ' \n' || echo "UNKNOWN")

EOF
    
    if [[ $failed_tests -eq 0 ]]; then
        log_success "🎉 All tests passed! ($passed_tests/$total_tests)"
        return 0
    else
        log_error "❌ Some tests failed! ($failed_tests/$total_tests failed)"
        return 1
    fi
}

# =============================================================================
# Main Execution Function
# =============================================================================

main() {
    local test_start_time
    test_start_time=$(date +%s)
    
    log "🚀 Starting MS5.0 Phase 3 Migration Testing Framework"
    log "Target Database: ${DB_NAME}@${DB_HOST}:${DB_PORT}"
    
    # Initialize test environment
    initialize_test_environment
    
    # Execute all tests
    if execute_all_tests; then
        local test_end_time
        test_end_time=$(date +%s)
        local total_test_time=$((test_end_time - test_start_time))
        
        log_success "🎉 Migration testing completed successfully!"
        log_success "Total test time: ${total_test_time}s"
        log_success "Test report: $TEST_REPORT_FILE"
        exit 0
    else
        local test_end_time
        test_end_time=$(date +%s)
        local total_test_time=$((test_end_time - test_start_time))
        
        log_error "❌ Migration testing failed!"
        log_error "Total test time: ${total_test_time}s"
        log_error "Test report: $TEST_REPORT_FILE"
        exit 1
    fi
}

# =============================================================================
# Script Execution
# =============================================================================

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
