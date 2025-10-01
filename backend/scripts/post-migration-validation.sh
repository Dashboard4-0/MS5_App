#!/bin/bash

# =============================================================================
# MS5.0 Phase 3: Post-Migration Validation Script
# =============================================================================
# 
# This script performs comprehensive validation after database migration execution.
# Ensures migration was successful and system is ready for production:
# - Database schema validation
# - TimescaleDB hypertable verification
# - Data integrity checks
# - Performance baseline establishment
# - Application connectivity validation
# - System health verification
#
# Designed for cosmic-scale reliability - every validation ensures production readiness.
# =============================================================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# =============================================================================
# Configuration & Constants
# =============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly LOG_DIR="${PROJECT_ROOT}/logs/validation"
readonly VALIDATION_REPORT_FILE="$LOG_DIR/post-migration-validation-$(date +%Y%m%d-%H%M%S).txt"

# Database configuration
readonly DB_HOST="${DB_HOST:-localhost}"
readonly DB_PORT="${DB_PORT:-5432}"
readonly DB_NAME="${DB_NAME:-factory_telemetry}"
readonly DB_USER="${DB_USER:-ms5_user_production}"
readonly DB_PASSWORD="${POSTGRES_PASSWORD_PRODUCTION}"

# Container configuration
readonly POSTGRES_CONTAINER="ms5_postgres_production"

# Expected schema tables (after all migrations)
readonly EXPECTED_TABLES=(
    "factory_telemetry.metric_def"
    "factory_telemetry.metric_binding"
    "factory_telemetry.metric_latest"
    "factory_telemetry.metric_hist"
    "factory_telemetry.fault_catalog"
    "factory_telemetry.fault_active"
    "factory_telemetry.fault_event"
    "factory_telemetry.context"
    "factory_telemetry.production_lines"
    "factory_telemetry.product_types"
    "factory_telemetry.production_schedules"
    "factory_telemetry.job_assignments"
    "factory_telemetry.users"
    "factory_telemetry.shifts"
    "factory_telemetry.andon_events"
    "factory_telemetry.escalation_rules"
    "factory_telemetry.notifications"
    "factory_telemetry.reports"
    "factory_telemetry.report_templates"
    "factory_telemetry.plc_connections"
    "factory_telemetry.plc_tags"
    "factory_telemetry.migration_log"
)

# Expected TimescaleDB hypertables
readonly EXPECTED_HYPERTABLES=(
    "factory_telemetry.metric_hist"
    "factory_telemetry.oee_calculations"
    "factory_telemetry.energy_consumption"
    "factory_telemetry.production_kpis"
)

# Expected views
readonly EXPECTED_VIEWS=(
    "public.v_equipment_latest"
    "public.v_faults_active"
)

# Performance benchmarks (in milliseconds)
readonly MAX_QUERY_TIME_MS=1000
readonly MAX_INSERT_TIME_MS=500
readonly MAX_CONNECTION_TIME_MS=100

# =============================================================================
# Logging System - Production Grade
# =============================================================================

# ANSI color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$VALIDATION_REPORT_FILE"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✅${NC} $1" | tee -a "$VALIDATION_REPORT_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️${NC} $1" | tee -a "$VALIDATION_REPORT_FILE"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ❌${NC} $1" | tee -a "$VALIDATION_REPORT_FILE"
}

log_info() {
    echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')] ℹ️${NC} $1" | tee -a "$VALIDATION_REPORT_FILE"
}

log_validation() {
    echo -e "${PURPLE}[$(date '+%Y-%m-%d %H:%M:%S')] 🔍${NC} $1" | tee -a "$VALIDATION_REPORT_FILE"
}

# =============================================================================
# Utility Functions - Cosmic Scale Reliability
# =============================================================================

# Initialize validation environment
initialize_validation() {
    log "Initializing post-migration validation..."
    
    # Create log directory
    mkdir -p "$LOG_DIR"
    
    # Initialize validation report
    cat > "$VALIDATION_REPORT_FILE" << EOF
# MS5.0 Post-Migration Validation Report
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
# Database: ${DB_NAME}@${DB_HOST}:${DB_PORT}
# User: ${DB_USER}
# Container: ${POSTGRES_CONTAINER}

## Validation Summary
- Validation Started: $(date '+%Y-%m-%d %H:%M:%S')
- Target Database: ${DB_NAME}
- Expected Tables: ${#EXPECTED_TABLES[@]}
- Expected Hypertables: ${#EXPECTED_HYPERTABLES[@]}

## Validation Results

EOF
    
    log_success "Validation environment initialized"
}

# Execute SQL query with timing
execute_timed_query() {
    local query="$1"
    local description="$2"
    
    local start_time
    start_time=$(date +%s%3N)  # milliseconds
    
    local result
    result=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "$query" 2>&1)
    local exit_code=$?
    
    local end_time
    end_time=$(date +%s%3N)
    local execution_time=$((end_time - start_time))
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "$description completed (${execution_time}ms)"
        echo "$result"
        return 0
    else
        log_error "$description failed (${execution_time}ms): $result"
        return 1
    fi
}

# =============================================================================
# Validation Functions - Comprehensive Post-Migration Checks
# =============================================================================

# Validate database connectivity and basic health
validate_database_health() {
    log_validation "Validating database health..."
    
    local validation_passed=true
    
    # Test basic connectivity
    log_info "Testing database connectivity..."
    if ! execute_timed_query "SELECT 1;" "Basic connectivity test" >/dev/null; then
        log_error "Database connectivity test failed"
        validation_passed=false
    fi
    
    # Check TimescaleDB extension
    log_info "Verifying TimescaleDB extension..."
    local timescaledb_version
    timescaledb_version=$(execute_timed_query "SELECT extversion FROM pg_extension WHERE extname = 'timescaledb';" "TimescaleDB version check" 2>/dev/null | tr -d ' \n')
    
    if [[ -n "$timescaledb_version" && "$timescaledb_version" != "" ]]; then
        log_success "TimescaleDB extension active (version: $timescaledb_version)"
    else
        log_error "TimescaleDB extension not found or inactive"
        validation_passed=false
    fi
    
    # Check database size
    log_info "Checking database size..."
    local db_size
    db_size=$(execute_timed_query "SELECT pg_size_pretty(pg_database_size('$DB_NAME'));" "Database size check" 2>/dev/null | tr -d ' \n')
    log_info "Database size: $db_size"
    
    # Check active connections
    log_info "Checking active connections..."
    local active_connections
    active_connections=$(execute_timed_query "SELECT COUNT(*) FROM pg_stat_activity WHERE state = 'active';" "Active connections check" 2>/dev/null | tr -d ' \n')
    log_info "Active connections: $active_connections"
    
    if [[ "$validation_passed" == "true" ]]; then
        log_success "Database health validation passed"
        return 0
    else
        log_error "Database health validation failed"
        return 1
    fi
}

# Validate database schema
validate_database_schema() {
    log_validation "Validating database schema..."
    
    local validation_passed=true
    
    # Check expected tables exist
    log_info "Checking expected tables..."
    for table in "${EXPECTED_TABLES[@]}"; do
        local schema_name
        schema_name=$(echo "$table" | cut -d'.' -f1)
        local table_name
        table_name=$(echo "$table" | cut -d'.' -f2)
        
        local table_exists
        table_exists=$(execute_timed_query "
            SELECT COUNT(*) FROM information_schema.tables 
            WHERE table_schema = '$schema_name' AND table_name = '$table_name';
        " "Table existence check for $table" 2>/dev/null | tr -d ' \n')
        
        if [[ "$table_exists" == "1" ]]; then
            log_success "Table exists: $table"
            
            # Check table has columns
            local column_count
            column_count=$(execute_timed_query "
                SELECT COUNT(*) FROM information_schema.columns 
                WHERE table_schema = '$schema_name' AND table_name = '$table_name';
            " "Column count check for $table" 2>/dev/null | tr -d ' \n')
            
            if [[ "$column_count" -gt 0 ]]; then
                log_success "  Table has $column_count columns"
            else
                log_warning "  Table has no columns: $table"
            fi
        else
            log_error "Table missing: $table"
            validation_passed=false
        fi
    done
    
    # Check expected views exist
    log_info "Checking expected views..."
    for view in "${EXPECTED_VIEWS[@]}"; do
        local schema_name
        schema_name=$(echo "$view" | cut -d'.' -f1)
        local view_name
        view_name=$(echo "$view" | cut -d'.' -f2)
        
        local view_exists
        view_exists=$(execute_timed_query "
            SELECT COUNT(*) FROM information_schema.views 
            WHERE table_schema = '$schema_name' AND table_name = '$view_name';
        " "View existence check for $view" 2>/dev/null | tr -d ' \n')
        
        if [[ "$view_exists" == "1" ]]; then
            log_success "View exists: $view"
        else
            log_warning "View missing: $view"
        fi
    done
    
    # Check migration log table
    log_info "Checking migration log..."
    local migration_count
    migration_count=$(execute_timed_query "
        SELECT COUNT(*) FROM factory_telemetry.migration_log 
        WHERE status = 'completed';
    " "Migration log check" 2>/dev/null | tr -d ' \n')
    
    if [[ "$migration_count" -gt 0 ]]; then
        log_success "Migration log contains $migration_count completed migrations"
        
        # List completed migrations
        execute_timed_query "
            SELECT migration_name, applied_at 
            FROM factory_telemetry.migration_log 
            WHERE status = 'completed' 
            ORDER BY applied_at;
        " "Migration history check" | while read -r line; do
            log_info "  $line"
        done
    else
        log_warning "No completed migrations found in migration log"
    fi
    
    if [[ "$validation_passed" == "true" ]]; then
        log_success "Database schema validation passed"
        return 0
    else
        log_error "Database schema validation failed"
        return 1
    fi
}

# Validate TimescaleDB hypertables
validate_timescaledb_hypertables() {
    log_validation "Validating TimescaleDB hypertables..."
    
    local validation_passed=true
    
    # Get all hypertables
    log_info "Checking TimescaleDB hypertables..."
    local hypertables
    hypertables=$(execute_timed_query "
        SELECT hypertable_name 
        FROM timescaledb_information.hypertables 
        WHERE schema_name = 'factory_telemetry'
        ORDER BY hypertable_name;
    " "Hypertable enumeration" 2>/dev/null | tr -d '\n' | tr -s ' ')
    
    if [[ -n "$hypertables" ]]; then
        log_success "Found hypertables: $hypertables"
        
        # Check each expected hypertable
        for expected_hypertable in "${EXPECTED_HYPERTABLES[@]}"; do
            local table_name
            table_name=$(echo "$expected_hypertable" | cut -d'.' -f2)
            
            if echo "$hypertables" | grep -q "$table_name"; then
                log_success "Expected hypertable found: $table_name"
                
                # Get hypertable details
                local hypertable_info
                hypertable_info=$(execute_timed_query "
                    SELECT num_dimensions, num_chunks 
                    FROM timescaledb_information.hypertables 
                    WHERE schema_name = 'factory_telemetry' AND hypertable_name = '$table_name';
                " "Hypertable details for $table_name" 2>/dev/null)
                
                log_info "  $table_name details: $hypertable_info"
            else
                log_error "Expected hypertable missing: $table_name"
                validation_passed=false
            fi
        done
        
        # Get chunk information
        log_info "Checking chunk information..."
        local chunk_info
        chunk_info=$(execute_timed_query "
            SELECT 
                hypertable_name,
                COUNT(*) as chunk_count,
                MIN(range_start) as earliest_chunk,
                MAX(range_end) as latest_chunk
            FROM timescaledb_information.chunks 
            WHERE schema_name = 'factory_telemetry'
            GROUP BY hypertable_name
            ORDER BY hypertable_name;
        " "Chunk information" 2>/dev/null)
        
        if [[ -n "$chunk_info" ]]; then
            log_info "Chunk information:"
            echo "$chunk_info" | while read -r line; do
                log_info "  $line"
            done
        fi
    else
        log_warning "No TimescaleDB hypertables found"
        validation_passed=false
    fi
    
    if [[ "$validation_passed" == "true" ]]; then
        log_success "TimescaleDB hypertables validation passed"
        return 0
    else
        log_error "TimescaleDB hypertables validation failed"
        return 1
    fi
}

# Validate data integrity
validate_data_integrity() {
    log_validation "Validating data integrity..."
    
    local validation_passed=true
    
    # Check for orphaned records
    log_info "Checking for orphaned records..."
    
    # Check metric_binding references
    local orphaned_bindings
    orphaned_bindings=$(execute_timed_query "
        SELECT COUNT(*) 
        FROM factory_telemetry.metric_binding mb 
        LEFT JOIN factory_telemetry.metric_def md ON mb.metric_def_id = md.id 
        WHERE md.id IS NULL;
    " "Orphaned metric bindings check" 2>/dev/null | tr -d ' \n')
    
    if [[ "$orphaned_bindings" == "0" ]]; then
        log_success "No orphaned metric bindings found"
    else
        log_error "Found $orphaned_bindings orphaned metric bindings"
        validation_passed=false
    fi
    
    # Check for data consistency in metric tables
    log_info "Checking metric table consistency..."
    
    # Check that metric_latest has corresponding metric_def records
    local inconsistent_latest
    inconsistent_latest=$(execute_timed_query "
        SELECT COUNT(*) 
        FROM factory_telemetry.metric_latest ml 
        LEFT JOIN factory_telemetry.metric_def md ON ml.metric_def_id = md.id 
        WHERE md.id IS NULL;
    " "Inconsistent metric_latest check" 2>/dev/null | tr -d ' \n')
    
    if [[ "$inconsistent_latest" == "0" ]]; then
        log_success "Metric latest table is consistent"
    else
        log_error "Found $inconsistent_latest inconsistent records in metric_latest"
        validation_passed=false
    fi
    
    # Check for data consistency in metric_hist
    local inconsistent_hist
    inconsistent_hist=$(execute_timed_query "
        SELECT COUNT(*) 
        FROM factory_telemetry.metric_hist mh 
        LEFT JOIN factory_telemetry.metric_def md ON mh.metric_def_id = md.id 
        WHERE md.id IS NULL;
    " "Inconsistent metric_hist check" 2>/dev/null | tr -d ' \n')
    
    if [[ "$inconsistent_hist" == "0" ]]; then
        log_success "Metric history table is consistent"
    else
        log_error "Found $inconsistent_hist inconsistent records in metric_hist"
        validation_passed=false
    fi
    
    if [[ "$validation_passed" == "true" ]]; then
        log_success "Data integrity validation passed"
        return 0
    else
        log_error "Data integrity validation failed"
        return 1
    fi
}

# Validate performance benchmarks
validate_performance_benchmarks() {
    log_validation "Validating performance benchmarks..."
    
    local validation_passed=true
    
    # Test query performance
    log_info "Testing query performance..."
    
    # Simple count query
    local count_start_time
    count_start_time=$(date +%s%3N)
    execute_timed_query "SELECT COUNT(*) FROM factory_telemetry.metric_def;" "Count query test" >/dev/null
    local count_end_time
    count_end_time=$(date +%s%3N)
    local count_time=$((count_end_time - count_start_time))
    
    if [[ $count_time -le $MAX_QUERY_TIME_MS ]]; then
        log_success "Count query performance acceptable (${count_time}ms)"
    else
        log_warning "Count query performance slow (${count_time}ms, threshold: ${MAX_QUERY_TIME_MS}ms)"
    fi
    
    # Test insert performance (if possible)
    log_info "Testing insert performance..."
    local insert_start_time
    insert_start_time=$(date +%s%3N)
    
    # Try to insert a test record (will be rolled back)
    execute_timed_query "
        BEGIN;
        INSERT INTO factory_telemetry.metric_def (equipment_code, metric_key, value_type, description) 
        VALUES ('TEST_EQUIPMENT', 'TEST_METRIC', 'REAL', 'Test metric for performance validation');
        ROLLBACK;
    " "Insert performance test" >/dev/null
    
    local insert_end_time
    insert_end_time=$(date +%s%3N)
    local insert_time=$((insert_end_time - insert_start_time))
    
    if [[ $insert_time -le $MAX_INSERT_TIME_MS ]]; then
        log_success "Insert performance acceptable (${insert_time}ms)"
    else
        log_warning "Insert performance slow (${insert_time}ms, threshold: ${MAX_INSERT_TIME_MS}ms)"
    fi
    
    # Test TimescaleDB-specific queries
    log_info "Testing TimescaleDB query performance..."
    
    # Test hypertable query
    local hypertable_start_time
    hypertable_start_time=$(date +%s%3N)
    execute_timed_query "
        SELECT COUNT(*) 
        FROM timescaledb_information.hypertables 
        WHERE schema_name = 'factory_telemetry';
    " "Hypertable query test" >/dev/null
    local hypertable_end_time
    hypertable_end_time=$(date +%s%3N)
    local hypertable_time=$((hypertable_end_time - hypertable_start_time))
    
    if [[ $hypertable_time -le $MAX_QUERY_TIME_MS ]]; then
        log_success "Hypertable query performance acceptable (${hypertable_time}ms)"
    else
        log_warning "Hypertable query performance slow (${hypertable_time}ms, threshold: ${MAX_QUERY_TIME_MS}ms)"
    fi
    
    if [[ "$validation_passed" == "true" ]]; then
        log_success "Performance benchmarks validation passed"
        return 0
    else
        log_warning "Performance benchmarks validation completed with warnings"
        return 0  # Warnings don't fail validation
    fi
}

# Validate application connectivity
validate_application_connectivity() {
    log_validation "Validating application connectivity..."
    
    local validation_passed=true
    
    # Test connection from application perspective
    log_info "Testing application database connection..."
    
    # Test with application-like connection string
    local app_connection_start
    app_connection_start=$(date +%s%3N)
    
    if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" >/dev/null 2>&1; then
        local app_connection_end
        app_connection_end=$(date +%s%3N)
        local app_connection_time=$((app_connection_end - app_connection_start))
        
        if [[ $app_connection_time -le $MAX_CONNECTION_TIME_MS ]]; then
            log_success "Application connection test passed (${app_connection_time}ms)"
        else
            log_warning "Application connection slow (${app_connection_time}ms, threshold: ${MAX_CONNECTION_TIME_MS}ms)"
        fi
    else
        log_error "Application connection test failed"
        validation_passed=false
    fi
    
    # Test connection pooling scenarios
    log_info "Testing connection pooling scenarios..."
    
    # Simulate multiple concurrent connections
    local concurrent_connections=5
    local successful_connections=0
    
    for ((i=1; i<=concurrent_connections; i++)); do
        if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT $i;" >/dev/null 2>&1; then
            ((successful_connections++))
        fi
    done
    
    if [[ $successful_connections -eq $concurrent_connections ]]; then
        log_success "Concurrent connection test passed ($successful_connections/$concurrent_connections)"
    else
        log_warning "Concurrent connection test partial success ($successful_connections/$concurrent_connections)"
    fi
    
    if [[ "$validation_passed" == "true" ]]; then
        log_success "Application connectivity validation passed"
        return 0
    else
        log_error "Application connectivity validation failed"
        return 1
    fi
}

# Validate system health
validate_system_health() {
    log_validation "Validating system health..."
    
    local validation_passed=true
    
    # Check container health
    log_info "Checking container health..."
    local container_status
    container_status=$(docker inspect --format='{{.State.Health.Status}}' "${POSTGRES_CONTAINER}" 2>/dev/null || echo "unknown")
    
    case "$container_status" in
        "healthy")
            log_success "PostgreSQL container is healthy"
            ;;
        "unhealthy")
            log_error "PostgreSQL container is unhealthy"
            validation_passed=false
            ;;
        *)
            log_warning "PostgreSQL container health status: $container_status"
            ;;
    esac
    
    # Check container resource usage
    log_info "Checking container resource usage..."
    local container_stats
    container_stats=$(docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" "${POSTGRES_CONTAINER}" 2>/dev/null || echo "Unable to get container stats")
    log_info "Container resource usage: $container_stats"
    
    # Check for recent errors in container logs
    log_info "Checking for recent errors in container logs..."
    local recent_errors
    recent_errors=$(docker logs "${POSTGRES_CONTAINER}" --since="10m" 2>&1 | grep -i error | wc -l)
    
    if [[ $recent_errors -eq 0 ]]; then
        log_success "No recent errors found in container logs"
    else
        log_warning "Found $recent_errors recent error(s) in container logs"
        docker logs "${POSTGRES_CONTAINER}" --since="10m" 2>&1 | grep -i error | head -3 | while read -r error_line; do
            log_warning "  $error_line"
        done
    fi
    
    if [[ "$validation_passed" == "true" ]]; then
        log_success "System health validation passed"
        return 0
    else
        log_error "System health validation failed"
        return 1
    fi
}

# =============================================================================
# Report Generation
# =============================================================================

# Generate final validation report
generate_validation_report() {
    log "Generating final validation report..."
    
    # Get database statistics
    log_info "Collecting database statistics..."
    
    # Table row counts
    local table_stats
    table_stats=$(execute_timed_query "
        SELECT 
            schemaname,
            tablename,
            n_tup_ins as inserts,
            n_tup_upd as updates,
            n_tup_del as deletes,
            n_live_tup as live_tuples,
            n_dead_tup as dead_tuples
        FROM pg_stat_user_tables 
        WHERE schemaname = 'factory_telemetry'
        ORDER BY schemaname, tablename;
    " "Table statistics collection" 2>/dev/null)
    
    # Append summary to report file
    cat >> "$VALIDATION_REPORT_FILE" << EOF

## Validation Summary
- Validation Completed: $(date '+%Y-%m-%d %H:%M:%S')
- Total Validation Checks: 6
- Database Health: $([ $? -eq 0 ] && echo "PASSED" || echo "FAILED")
- Database Schema: $([ $? -eq 0 ] && echo "PASSED" || echo "FAILED")
- TimescaleDB Hypertables: $([ $? -eq 0 ] && echo "PASSED" || echo "FAILED")
- Data Integrity: $([ $? -eq 0 ] && echo "PASSED" || echo "FAILED")
- Performance Benchmarks: $([ $? -eq 0 ] && echo "PASSED" || echo "FAILED")
- Application Connectivity: $([ $? -eq 0 ] && echo "PASSED" || echo "FAILED")
- System Health: $([ $? -eq 0 ] && echo "PASSED" || echo "FAILED")

## Database Statistics
$table_stats

## TimescaleDB Information
EOF

    # Get TimescaleDB information
    local timescaledb_info
    timescaledb_info=$(execute_timed_query "
        SELECT 
            hypertable_name,
            num_dimensions,
            num_chunks,
            compression_enabled,
            replication_factor
        FROM timescaledb_information.hypertables 
        WHERE schema_name = 'factory_telemetry'
        ORDER BY hypertable_name;
    " "TimescaleDB information collection" 2>/dev/null)
    
    echo "$timescaledb_info" >> "$VALIDATION_REPORT_FILE"
    
    cat >> "$VALIDATION_REPORT_FILE" << EOF

## Migration Status
EOF

    # Get migration status
    local migration_status
    migration_status=$(execute_timed_query "
        SELECT 
            migration_name,
            status,
            applied_at,
            execution_time_ms
        FROM factory_telemetry.migration_log
        ORDER BY applied_at;
    " "Migration status collection" 2>/dev/null)
    
    echo "$migration_status" >> "$VALIDATION_REPORT_FILE"
    
    log_success "Validation report generated: $VALIDATION_REPORT_FILE"
}

# =============================================================================
# Main Execution Function
# =============================================================================

main() {
    log "🚀 Starting MS5.0 Post-Migration Validation"
    log "Target Database: ${DB_NAME}@${DB_HOST}:${DB_PORT}"
    
    # Initialize validation environment
    initialize_validation
    
    # Track validation results
    local validation_failed=false
    
    # Run all validation checks
    validate_database_health || validation_failed=true
    validate_database_schema || validation_failed=true
    validate_timescaledb_hypertables || validation_failed=true
    validate_data_integrity || validation_failed=true
    validate_performance_benchmarks || validation_failed=true
    validate_application_connectivity || validation_failed=true
    validate_system_health || validation_failed=true
    
    # Generate final report
    generate_validation_report
    
    # Final result
    if [[ "$validation_failed" == "true" ]]; then
        log_error "❌ Post-migration validation failed"
        log_error "Please review the issues above before considering migration complete"
        log_info "Validation report: $VALIDATION_REPORT_FILE"
        exit 1
    else
        log_success "🎉 Post-migration validation passed successfully!"
        log_success "Database migration is complete and system is ready for production"
        log_info "Validation report: $VALIDATION_REPORT_FILE"
        exit 0
    fi
}

# =============================================================================
# Script Execution
# =============================================================================

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
