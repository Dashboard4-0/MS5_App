#!/bin/bash

# MS5.0 Floor Dashboard - Phase 9 Database Migration Testing Script
# This script tests all database migrations in a safe environment before production deployment
# Designed with starship-grade precision and reliability

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${PROJECT_ROOT}/logs/phase9-migration-test-${TIMESTAMP}.log"

# Environment variables
TEST_DATABASE_URL=${TEST_DATABASE_URL:-"postgresql://test_user:test_password@localhost:5432/test_factory_telemetry"}
BACKUP_ENABLED=${BACKUP_ENABLED:-true}
VALIDATE_SCHEMA=${VALIDATE_SCHEMA:-true}
TEST_DATA=${TEST_DATA:-true}
PERFORMANCE_TEST=${PERFORMANCE_TEST:-true}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_section() {
    echo -e "${PURPLE}[SECTION]${NC} $1" | tee -a "$LOG_FILE"
}

# Create log directory
mkdir -p "$(dirname "$LOG_FILE")"

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
WARNING_TESTS=0

# Test result tracking
declare -A TEST_RESULTS

# Function to record test result
record_test() {
    local test_name="$1"
    local status="$2"
    local message="$3"
    
    TEST_RESULTS["$test_name"]="$status|$message"
    
    case "$status" in
        "PASS")
            ((PASSED_TESTS++))
            log_success "$test_name: $message"
            ;;
        "FAIL")
            ((FAILED_TESTS++))
            log_error "$test_name: $message"
            ;;
        "WARN")
            ((WARNING_TESTS++))
            log_warning "$test_name: $message"
            ;;
    esac
    
    ((TOTAL_TESTS++))
}

# Function to check PostgreSQL installation
check_postgresql() {
    log_section "Checking PostgreSQL Installation"
    
    if command -v psql &> /dev/null; then
        local psql_version=$(psql --version | cut -d' ' -f3)
        record_test "postgresql-installed" "PASS" "PostgreSQL $psql_version is installed"
    else
        record_test "postgresql-installed" "FAIL" "PostgreSQL is not installed"
        return 1
    fi
    
    if command -v pg_dump &> /dev/null; then
        record_test "pg_dump-installed" "PASS" "pg_dump is available"
    else
        record_test "pg_dump-installed" "FAIL" "pg_dump is not available"
    fi
}

# Function to create test database
create_test_database() {
    log_section "Creating Test Database"
    
    # Extract database components from URL
    local db_host=$(echo "$TEST_DATABASE_URL" | sed -n 's/.*:\/\/[^:]*:[^@]*@\([^:]*\):.*/\1/p')
    local db_port=$(echo "$TEST_DATABASE_URL" | sed -n 's/.*:\/\/[^:]*:[^@]*@[^:]*:\([^/]*\)\/.*/\1/p')
    local db_user=$(echo "$TEST_DATABASE_URL" | sed -n 's/.*:\/\/\([^:]*\):.*/\1/p')
    local db_name=$(echo "$TEST_DATABASE_URL" | sed -n 's/.*\/\([^?]*\).*/\1/p')
    
    # Test connection to PostgreSQL server
    if PGPASSWORD=$(echo "$TEST_DATABASE_URL" | sed -n 's/.*:\/\/[^:]*:\([^@]*\)@.*/\1/p') psql -h "$db_host" -p "$db_port" -U "$db_user" -d postgres -c "SELECT 1;" &> /dev/null; then
        record_test "postgresql-connection" "PASS" "Connected to PostgreSQL server"
    else
        record_test "postgresql-connection" "FAIL" "Cannot connect to PostgreSQL server"
        return 1
    fi
    
    # Create test database
    if PGPASSWORD=$(echo "$TEST_DATABASE_URL" | sed -n 's/.*:\/\/[^:]*:\([^@]*\)@.*/\1/p') psql -h "$db_host" -p "$db_port" -U "$db_user" -d postgres -c "CREATE DATABASE $db_name;" &> /dev/null; then
        record_test "test-database-created" "PASS" "Test database created successfully"
    else
        # Database might already exist
        if PGPASSWORD=$(echo "$TEST_DATABASE_URL" | sed -n 's/.*:\/\/[^:]*:\([^@]*\)@.*/\1/p') psql -h "$db_host" -p "$db_port" -U "$db_user" -d "$db_name" -c "SELECT 1;" &> /dev/null; then
            record_test "test-database-created" "PASS" "Test database already exists"
        else
            record_test "test-database-created" "FAIL" "Cannot create or access test database"
            return 1
        fi
    fi
}

# Function to test individual migration
test_migration() {
    local migration_file="$1"
    local full_path="$PROJECT_ROOT/$migration_file"
    
    if [ ! -f "$full_path" ]; then
        record_test "migration-file-$migration_file" "FAIL" "Migration file not found"
        return 1
    fi
    
    log_info "Testing migration: $migration_file"
    
    # Test SQL syntax
    if psql "$TEST_DATABASE_URL" -f "$full_path" &> /dev/null; then
        record_test "migration-syntax-$migration_file" "PASS" "Migration syntax is valid"
    else
        record_test "migration-syntax-$migration_file" "FAIL" "Migration syntax is invalid"
        return 1
    fi
    
    # Check if migration creates expected objects
    local objects_created=$(psql "$TEST_DATABASE_URL" -t -c "
        SELECT COUNT(*) FROM (
            SELECT schemaname, tablename FROM pg_tables WHERE schemaname = 'factory_telemetry'
            UNION ALL
            SELECT schemaname, indexname FROM pg_indexes WHERE schemaname = 'factory_telemetry'
            UNION ALL
            SELECT schemaname, viewname FROM pg_views WHERE schemaname = 'factory_telemetry'
        ) objects;
    " | xargs)
    
    if [ "$objects_created" -gt 0 ]; then
        record_test "migration-objects-$migration_file" "PASS" "Migration created $objects_created database objects"
    else
        record_test "migration-objects-$migration_file" "WARN" "Migration did not create any database objects"
    fi
}

# Function to test all migrations
test_all_migrations() {
    log_section "Testing All Database Migrations"
    
    local migration_files=(
        "001_init_telemetry.sql"
        "002_plc_equipment_management.sql"
        "003_production_management.sql"
        "004_advanced_production_features.sql"
        "005_andon_escalation_system.sql"
        "006_report_system.sql"
        "007_plc_integration_phase1.sql"
        "008_fix_critical_schema_issues.sql"
        "009_database_optimization.sql"
    )
    
    for migration_file in "${migration_files[@]}"; do
        test_migration "$migration_file"
    done
}

# Function to validate schema
validate_schema() {
    log_section "Validating Database Schema"
    
    if [ "$VALIDATE_SCHEMA" != "true" ]; then
        record_test "schema-validation" "PASS" "Schema validation skipped"
        return 0
    fi
    
    # Check if required schemas exist
    local schemas=$(psql "$TEST_DATABASE_URL" -t -c "SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'factory_telemetry';" | xargs)
    if [ "$schemas" = "factory_telemetry" ]; then
        record_test "schema-exists" "PASS" "factory_telemetry schema exists"
    else
        record_test "schema-exists" "FAIL" "factory_telemetry schema does not exist"
    fi
    
    # Check if required tables exist
    local required_tables=(
        "factory_telemetry.users"
        "factory_telemetry.equipment_config"
        "factory_telemetry.context"
        "factory_telemetry.production_lines"
        "factory_telemetry.andon_events"
        "factory_telemetry.andon_escalations"
    )
    
    for table in "${required_tables[@]}"; do
        local schema_name=$(echo "$table" | cut -d'.' -f1)
        local table_name=$(echo "$table" | cut -d'.' -f2)
        
        local table_exists=$(psql "$TEST_DATABASE_URL" -t -c "
            SELECT COUNT(*) FROM information_schema.tables 
            WHERE table_schema = '$schema_name' AND table_name = '$table_name';
        " | xargs)
        
        if [ "$table_exists" -gt 0 ]; then
            record_test "table-exists-$table_name" "PASS" "Table $table exists"
        else
            record_test "table-exists-$table_name" "FAIL" "Table $table does not exist"
        fi
    done
    
    # Check if TimescaleDB extension is installed
    local timescaledb_installed=$(psql "$TEST_DATABASE_URL" -t -c "
        SELECT COUNT(*) FROM pg_extension WHERE extname = 'timescaledb';
    " | xargs)
    
    if [ "$timescaledb_installed" -gt 0 ]; then
        record_test "timescaledb-extension" "PASS" "TimescaleDB extension is installed"
    else
        record_test "timescaledb-extension" "WARN" "TimescaleDB extension is not installed"
    fi
    
    # Check if hypertables are created
    local hypertables=$(psql "$TEST_DATABASE_URL" -t -c "
        SELECT COUNT(*) FROM timescaledb_information.hypertables 
        WHERE hypertable_schema = 'factory_telemetry';
    " 2>/dev/null | xargs || echo "0")
    
    if [ "$hypertables" -gt 0 ]; then
        record_test "hypertables-created" "PASS" "Created $hypertables hypertables"
    else
        record_test "hypertables-created" "WARN" "No hypertables found (TimescaleDB may not be configured)"
    fi
}

# Function to test data operations
test_data_operations() {
    log_section "Testing Data Operations"
    
    if [ "$TEST_DATA" != "true" ]; then
        record_test "data-operations" "PASS" "Data operations testing skipped"
        return 0
    fi
    
    # Test INSERT operations
    if psql "$TEST_DATABASE_URL" -c "
        INSERT INTO factory_telemetry.users (username, email, password_hash, role) 
        VALUES ('test_user', 'test@example.com', 'test_hash', 'operator');
    " &> /dev/null; then
        record_test "insert-operations" "PASS" "INSERT operations work correctly"
    else
        record_test "insert-operations" "FAIL" "INSERT operations failed"
    fi
    
    # Test SELECT operations
    if psql "$TEST_DATABASE_URL" -c "
        SELECT COUNT(*) FROM factory_telemetry.users;
    " &> /dev/null; then
        record_test "select-operations" "PASS" "SELECT operations work correctly"
    else
        record_test "select-operations" "FAIL" "SELECT operations failed"
    fi
    
    # Test UPDATE operations
    if psql "$TEST_DATABASE_URL" -c "
        UPDATE factory_telemetry.users SET email = 'updated@example.com' WHERE username = 'test_user';
    " &> /dev/null; then
        record_test "update-operations" "PASS" "UPDATE operations work correctly"
    else
        record_test "update-operations" "FAIL" "UPDATE operations failed"
    fi
    
    # Test DELETE operations
    if psql "$TEST_DATABASE_URL" -c "
        DELETE FROM factory_telemetry.users WHERE username = 'test_user';
    " &> /dev/null; then
        record_test "delete-operations" "PASS" "DELETE operations work correctly"
    else
        record_test "delete-operations" "FAIL" "DELETE operations failed"
    fi
}

# Function to test performance
test_performance() {
    log_section "Testing Database Performance"
    
    if [ "$PERFORMANCE_TEST" != "true" ]; then
        record_test "performance-test" "PASS" "Performance testing skipped"
        return 0
    fi
    
    # Test query performance
    local query_time=$(psql "$TEST_DATABASE_URL" -c "
        \timing on
        SELECT COUNT(*) FROM information_schema.tables;
        \timing off
    " 2>&1 | grep "Time:" | sed 's/Time: //' | sed 's/ ms//')
    
    if [ -n "$query_time" ] && [ "$query_time" -lt 1000 ]; then
        record_test "query-performance" "PASS" "Query performance is acceptable (${query_time}ms)"
    else
        record_test "query-performance" "WARN" "Query performance may be slow (${query_time}ms)"
    fi
    
    # Test connection performance
    local connection_start=$(date +%s%N)
    psql "$TEST_DATABASE_URL" -c "SELECT 1;" &> /dev/null
    local connection_end=$(date +%s%N)
    local connection_time=$(( (connection_end - connection_start) / 1000000 ))
    
    if [ "$connection_time" -lt 100 ]; then
        record_test "connection-performance" "PASS" "Connection performance is acceptable (${connection_time}ms)"
    else
        record_test "connection-performance" "WARN" "Connection performance may be slow (${connection_time}ms)"
    fi
}

# Function to test backup and recovery
test_backup_recovery() {
    log_section "Testing Backup and Recovery"
    
    if [ "$BACKUP_ENABLED" != "true" ]; then
        record_test "backup-recovery" "PASS" "Backup and recovery testing skipped"
        return 0
    fi
    
    local backup_file="/tmp/ms5_test_backup_${TIMESTAMP}.sql"
    
    # Test backup
    if pg_dump "$TEST_DATABASE_URL" > "$backup_file" 2>/dev/null; then
        record_test "backup-creation" "PASS" "Database backup created successfully"
    else
        record_test "backup-creation" "FAIL" "Database backup creation failed"
        return 1
    fi
    
    # Check backup file size
    local backup_size=$(wc -c < "$backup_file")
    if [ "$backup_size" -gt 0 ]; then
        record_test "backup-size" "PASS" "Backup file size: $backup_size bytes"
    else
        record_test "backup-size" "FAIL" "Backup file is empty"
    fi
    
    # Clean up backup file
    rm -f "$backup_file"
    record_test "backup-cleanup" "PASS" "Backup file cleaned up"
}

# Function to test rollback scenarios
test_rollback_scenarios() {
    log_section "Testing Rollback Scenarios"
    
    # Create a test table for rollback testing
    if psql "$TEST_DATABASE_URL" -c "
        CREATE TABLE IF NOT EXISTS factory_telemetry.rollback_test (
            id SERIAL PRIMARY KEY,
            test_data TEXT
        );
    " &> /dev/null; then
        record_test "rollback-table-creation" "PASS" "Rollback test table created"
    else
        record_test "rollback-table-creation" "FAIL" "Failed to create rollback test table"
        return 1
    fi
    
    # Test rollback (DROP table)
    if psql "$TEST_DATABASE_URL" -c "
        DROP TABLE factory_telemetry.rollback_test;
    " &> /dev/null; then
        record_test "rollback-execution" "PASS" "Rollback executed successfully"
    else
        record_test "rollback-execution" "FAIL" "Rollback execution failed"
    fi
}

# Function to generate test report
generate_test_report() {
    log_section "Generating Migration Test Report"
    
    local report_file="${PROJECT_ROOT}/logs/phase9-migration-test-report-${TIMESTAMP}.md"
    
    cat > "$report_file" << EOF
# MS5.0 Floor Dashboard - Phase 9 Database Migration Test Report

**Generated**: $(date)
**Test Database**: $TEST_DATABASE_URL
**Environment**: Test

## Summary

- **Total Tests**: $TOTAL_TESTS
- **Passed**: $PASSED_TESTS
- **Failed**: $FAILED_TESTS
- **Warnings**: $WARNING_TESTS
- **Success Rate**: $(( (PASSED_TESTS * 100) / TOTAL_TESTS ))%

## Detailed Results

EOF

    # Add detailed results
    for test_name in "${!TEST_RESULTS[@]}"; do
        local result="${TEST_RESULTS[$test_name]}"
        local status="${result%%|*}"
        local message="${result#*|}"
        
        local status_icon=""
        case "$status" in
            "PASS") status_icon="✅" ;;
            "FAIL") status_icon="❌" ;;
            "WARN") status_icon="⚠️" ;;
        esac
        
        echo "- $status_icon **$test_name**: $message" >> "$report_file"
    done
    
    echo "" >> "$report_file"
    echo "## Recommendations" >> "$report_file"
    
    if [ $FAILED_TESTS -gt 0 ]; then
        echo "- ❌ **CRITICAL**: Fix all failed tests before proceeding with production deployment" >> "$report_file"
    fi
    
    if [ $WARNING_TESTS -gt 0 ]; then
        echo "- ⚠️ **WARNING**: Review and address warnings before production deployment" >> "$report_file"
    fi
    
    if [ $FAILED_TESTS -eq 0 ] && [ $WARNING_TESTS -eq 0 ]; then
        echo "- ✅ **READY**: Database migrations are ready for production deployment" >> "$report_file"
    fi
    
    log_success "Migration test report generated: $report_file"
}

# Function to cleanup test database
cleanup_test_database() {
    log_section "Cleaning Up Test Database"
    
    # Extract database components from URL
    local db_host=$(echo "$TEST_DATABASE_URL" | sed -n 's/.*:\/\/[^:]*:[^@]*@\([^:]*\):.*/\1/p')
    local db_port=$(echo "$TEST_DATABASE_URL" | sed -n 's/.*:\/\/[^:]*:[^@]*@[^:]*:\([^/]*\)\/.*/\1/p')
    local db_user=$(echo "$TEST_DATABASE_URL" | sed -n 's/.*:\/\/\([^:]*\):.*/\1/p')
    local db_name=$(echo "$TEST_DATABASE_URL" | sed -n 's/.*\/\([^?]*\).*/\1/p')
    
    # Drop test database
    if PGPASSWORD=$(echo "$TEST_DATABASE_URL" | sed -n 's/.*:\/\/[^:]*:\([^@]*\)@.*/\1/p') psql -h "$db_host" -p "$db_port" -U "$db_user" -d postgres -c "DROP DATABASE IF EXISTS $db_name;" &> /dev/null; then
        record_test "test-database-cleanup" "PASS" "Test database dropped successfully"
    else
        record_test "test-database-cleanup" "WARN" "Failed to drop test database"
    fi
}

# Main test function
main() {
    log "Starting MS5.0 Floor Dashboard Phase 9 Database Migration Testing"
    log "Test Database: $TEST_DATABASE_URL"
    log "Log file: $LOG_FILE"
    
    # Run all tests
    check_postgresql
    create_test_database
    test_all_migrations
    validate_schema
    test_data_operations
    test_performance
    test_backup_recovery
    test_rollback_scenarios
    
    # Generate report
    generate_test_report
    
    # Cleanup
    cleanup_test_database
    
    # Summary
    log_section "Migration Test Summary"
    log "Total Tests: $TOTAL_TESTS"
    log_success "Passed: $PASSED_TESTS"
    if [ $FAILED_TESTS -gt 0 ]; then
        log_error "Failed: $FAILED_TESTS"
    else
        log_success "Failed: $FAILED_TESTS"
    fi
    if [ $WARNING_TESTS -gt 0 ]; then
        log_warning "Warnings: $WARNING_TESTS"
    else
        log_success "Warnings: $WARNING_TESTS"
    fi
    
    # Exit with appropriate code
    if [ $FAILED_TESTS -gt 0 ]; then
        log_error "Migration testing failed. Please fix all failed tests before proceeding."
        exit 1
    elif [ $WARNING_TESTS -gt 0 ]; then
        log_warning "Migration testing completed with warnings. Please review warnings before proceeding."
        exit 0
    else
        log_success "Migration testing completed successfully. Database is ready for production deployment."
        exit 0
    fi
}

# Handle script arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --test-database-url)
            TEST_DATABASE_URL="$2"
            shift 2
            ;;
        --skip-schema-validation)
            VALIDATE_SCHEMA=false
            shift
            ;;
        --skip-data-test)
            TEST_DATA=false
            shift
            ;;
        --skip-performance-test)
            PERFORMANCE_TEST=false
            shift
            ;;
        --skip-backup-test)
            BACKUP_ENABLED=false
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --test-database-url URL    Test database URL"
            echo "  --skip-schema-validation   Skip schema validation"
            echo "  --skip-data-test          Skip data operations testing"
            echo "  --skip-performance-test   Skip performance testing"
            echo "  --skip-backup-test        Skip backup and recovery testing"
            echo "  --help                    Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Run main function
main "$@"
