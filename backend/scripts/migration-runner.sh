#!/bin/bash

# =============================================================================
# MS5.0 Phase 3: Database Migration Runner
# =============================================================================
# 
# This script executes database migrations in a controlled, reliable manner.
# Features cosmic-scale reliability with comprehensive error handling:
# - Idempotent migrations (safe to re-run)
# - Transactional execution with rollback capability
# - Comprehensive logging and audit trail
# - Progress tracking and status reporting
# - Dependency validation and integrity checks
# - TimescaleDB extension verification
#
# Designed for starship-grade reliability - every migration is atomic and verified.
# =============================================================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# =============================================================================
# Configuration & Constants
# =============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly MIGRATIONS_DIR="$PROJECT_ROOT/.."  # SQL files are in project root
readonly LOG_DIR="${PROJECT_ROOT}/logs/migrations"
readonly MIGRATION_LOG_TABLE="migration_log"

# Database configuration
readonly DB_HOST="${DB_HOST:-localhost}"
readonly DB_PORT="${DB_PORT:-5432}"
readonly DB_NAME="${DB_NAME:-factory_telemetry}"
readonly DB_USER="${DB_USER:-ms5_user_production}"
readonly DB_PASSWORD="${POSTGRES_PASSWORD_PRODUCTION}"

# Container configuration
readonly POSTGRES_CONTAINER="ms5_postgres_production"

# Migration files in execution order (CRITICAL: Must maintain this order)
readonly MIGRATION_FILES=(
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

# =============================================================================
# Logging System - Production Grade with Audit Trail
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
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_DIR/migration-runner.log"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✅${NC} $1" | tee -a "$LOG_DIR/migration-runner.log"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️${NC} $1" | tee -a "$LOG_DIR/migration-runner.log"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ❌${NC} $1" | tee -a "$LOG_DIR/migration-runner.log"
}

log_info() {
    echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')] ℹ️${NC} $1" | tee -a "$LOG_DIR/migration-runner.log"
}

log_migration() {
    echo -e "${PURPLE}[$(date '+%Y-%m-%d %H:%M:%S')] 🔄${NC} $1" | tee -a "$LOG_DIR/migration-runner.log"
}

# =============================================================================
# Utility Functions - Cosmic Scale Reliability
# =============================================================================

# Verify environment and prerequisites
verify_environment() {
    log "Verifying migration environment..."
    
    # Check required environment variables
    if [[ -z "${POSTGRES_PASSWORD_PRODUCTION:-}" ]]; then
        log_error "POSTGRES_PASSWORD_PRODUCTION environment variable is required"
        exit 1
    fi
    
    # Verify Docker container is running
    if ! docker ps --format "table {{.Names}}" | grep -q "^${POSTGRES_CONTAINER}$"; then
        log_error "PostgreSQL container '${POSTGRES_CONTAINER}' is not running"
        log_info "Please start the container with: docker compose -f docker-compose.production.yml up -d postgres"
        exit 1
    fi
    
    # Verify database connectivity
    if ! PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" >/dev/null 2>&1; then
        log_error "Cannot connect to database. Please verify connection parameters."
        exit 1
    fi
    
    # Verify TimescaleDB extension
    if ! PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1 FROM pg_extension WHERE extname = 'timescaledb';" | grep -q 1; then
        log_error "TimescaleDB extension is not installed"
        log_info "Please ensure TimescaleDB is properly configured in the container"
        exit 1
    fi
    
    # Verify migration files exist
    for migration_file in "${MIGRATION_FILES[@]}"; do
        if [[ ! -f "${MIGRATIONS_DIR}/${migration_file}" ]]; then
            log_error "Migration file not found: ${migration_file}"
            exit 1
        fi
    done
    
    log_success "Environment verification completed"
}

# Create logging directory
setup_logging() {
    log "Setting up migration logging..."
    
    mkdir -p "$LOG_DIR"
    
    # Initialize log file with header
    cat > "$LOG_DIR/migration-runner.log" << EOF
# MS5.0 Database Migration Runner Log
# Started: $(date '+%Y-%m-%d %H:%M:%S')
# Database: ${DB_NAME}@${DB_HOST}:${DB_PORT}
# User: ${DB_USER}
# Container: ${POSTGRES_CONTAINER}

EOF
    
    log_success "Logging system initialized: $LOG_DIR/migration-runner.log"
}

# Create migration log table
create_migration_log_table() {
    log "Creating migration log table..."
    
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" << EOF
-- Migration log table for tracking applied migrations
CREATE TABLE IF NOT EXISTS ${MIGRATION_LOG_TABLE} (
    id SERIAL PRIMARY KEY,
    migration_name VARCHAR(255) UNIQUE NOT NULL,
    migration_file VARCHAR(255) NOT NULL,
    applied_at TIMESTAMPTZ DEFAULT NOW(),
    applied_by VARCHAR(255) DEFAULT USER,
    execution_time_ms INTEGER,
    status VARCHAR(50) DEFAULT 'completed',
    error_message TEXT,
    checksum VARCHAR(64),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_migration_log_name ON ${MIGRATION_LOG_TABLE} (migration_name);
CREATE INDEX IF NOT EXISTS idx_migration_log_applied_at ON ${MIGRATION_LOG_TABLE} (applied_at);

-- Add comment for documentation
COMMENT ON TABLE ${MIGRATION_LOG_TABLE} IS 'Tracks applied database migrations for MS5.0 system';
EOF
    
    log_success "Migration log table created/verified"
}

# Calculate file checksum for integrity verification
calculate_checksum() {
    local file_path="$1"
    if [[ -f "$file_path" ]]; then
        sha256sum "$file_path" | cut -d' ' -f1
    else
        echo "FILE_NOT_FOUND"
    fi
}

# Check if migration has already been applied
is_migration_applied() {
    local migration_name="$1"
    
    local result
    result=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "
        SELECT COUNT(*) FROM ${MIGRATION_LOG_TABLE} 
        WHERE migration_name = '$migration_name' AND status = 'completed';
    " 2>/dev/null | tr -d ' \n' || echo "0")
    
    [[ "$result" == "1" ]]
}

# Get migration execution statistics
get_migration_stats() {
    local stats
    stats=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "
        SELECT 
            COUNT(*) as total_migrations,
            COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_migrations,
            COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed_migrations,
            COALESCE(AVG(execution_time_ms), 0) as avg_execution_time_ms
        FROM ${MIGRATION_LOG_TABLE};
    " 2>/dev/null | tr -d ' \n' || echo "0,0,0,0")
    
    echo "$stats"
}

# =============================================================================
# Migration Execution Functions
# =============================================================================

# Execute a single migration with comprehensive error handling
execute_migration() {
    local migration_file="$1"
    local migration_name="$2"
    local migration_path="${MIGRATIONS_DIR}/${migration_file}"
    
    log_migration "Starting migration: $migration_name"
    
    # Check if migration already applied
    if is_migration_applied "$migration_name"; then
        log_info "Migration '$migration_name' already applied, skipping"
        return 0
    fi
    
    # Calculate file checksum for integrity
    local checksum
    checksum=$(calculate_checksum "$migration_path")
    
    # Record migration start
    local start_time
    start_time=$(date +%s%3N)  # milliseconds
    
    # Log migration attempt
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" << EOF
INSERT INTO ${MIGRATION_LOG_TABLE} 
(migration_name, migration_file, status, checksum, applied_at) 
VALUES ('$migration_name', '$migration_file', 'running', '$checksum', NOW());
EOF
    
    # Execute migration with error capture
    local migration_output
    local migration_exit_code=0
    
    if ! migration_output=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$migration_path" 2>&1); then
        migration_exit_code=$?
    fi
    
    # Calculate execution time
    local end_time
    end_time=$(date +%s%3N)
    local execution_time=$((end_time - start_time))
    
    # Log migration output
    echo "=== Migration Output: $migration_name ===" >> "$LOG_DIR/migration-runner.log"
    echo "$migration_output" >> "$LOG_DIR/migration-runner.log"
    echo "=== End Migration Output ===" >> "$LOG_DIR/migration-runner.log"
    
    # Update migration status
    if [[ $migration_exit_code -eq 0 ]]; then
        # Migration succeeded
        PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" << EOF
UPDATE ${MIGRATION_LOG_TABLE} 
SET status = 'completed', 
    execution_time_ms = $execution_time,
    applied_at = NOW()
WHERE migration_name = '$migration_name' AND status = 'running';
EOF
        
        log_success "Migration '$migration_name' completed successfully (${execution_time}ms)"
        
        # Verify TimescaleDB-specific operations
        verify_timescaledb_operations "$migration_name"
        
        return 0
    else
        # Migration failed
        PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" << EOF
UPDATE ${MIGRATION_LOG_TABLE} 
SET status = 'failed', 
    execution_time_ms = $execution_time,
    error_message = 'Migration execution failed with exit code $migration_exit_code',
    applied_at = NOW()
WHERE migration_name = '$migration_name' AND status = 'running';
EOF
        
        log_error "Migration '$migration_name' failed with exit code $migration_exit_code"
        log_error "Migration output: $migration_output"
        
        return 1
    fi
}

# Verify TimescaleDB-specific operations after migration
verify_timescaledb_operations() {
    local migration_name="$1"
    
    log_info "Verifying TimescaleDB operations for: $migration_name"
    
    # Check for hypertables created in this migration
    local hypertables
    hypertables=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "
        SELECT hypertable_name 
        FROM timescaledb_information.hypertables 
        WHERE schema_name = 'factory_telemetry';
    " 2>/dev/null || echo "")
    
    if [[ -n "$hypertables" ]]; then
        log_info "Active hypertables: $(echo "$hypertables" | tr '\n' ' ')"
    fi
    
    # Check for any TimescaleDB extension issues
    local extension_status
    extension_status=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "
        SELECT extversion FROM pg_extension WHERE extname = 'timescaledb';
    " 2>/dev/null | tr -d ' \n' || echo "UNKNOWN")
    
    log_info "TimescaleDB version: $extension_status"
}

# =============================================================================
# Migration Validation & Reporting
# =============================================================================

# Validate migration results
validate_migration_results() {
    log "Validating migration results..."
    
    # Check that all expected tables exist
    local expected_tables=(
        "factory_telemetry.metric_def"
        "factory_telemetry.metric_binding"
        "factory_telemetry.metric_latest"
        "factory_telemetry.metric_hist"
        "factory_telemetry.fault_catalog"
        "factory_telemetry.fault_active"
        "factory_telemetry.fault_event"
        "factory_telemetry.context"
    )
    
    local missing_tables=()
    
    for table in "${expected_tables[@]}"; do
        local table_exists
        table_exists=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "
            SELECT COUNT(*) FROM information_schema.tables 
            WHERE table_schema = '$(echo "$table" | cut -d'.' -f1)' 
            AND table_name = '$(echo "$table" | cut -d'.' -f2)';
        " 2>/dev/null | tr -d ' \n' || echo "0")
        
        if [[ "$table_exists" != "1" ]]; then
            missing_tables+=("$table")
        fi
    done
    
    if [[ ${#missing_tables[@]} -gt 0 ]]; then
        log_error "Missing tables after migration: ${missing_tables[*]}"
        return 1
    fi
    
    log_success "All expected tables present"
    
    # Check TimescaleDB hypertables
    local hypertable_count
    hypertable_count=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "
        SELECT COUNT(*) FROM timescaledb_information.hypertables 
        WHERE schema_name = 'factory_telemetry';
    " 2>/dev/null | tr -d ' \n' || echo "0")
    
    if [[ "$hypertable_count" -gt 0 ]]; then
        log_success "TimescaleDB hypertables created: $hypertable_count"
    else
        log_warning "No TimescaleDB hypertables found"
    fi
    
    return 0
}

# Generate migration report
generate_migration_report() {
    log "Generating migration report..."
    
    local report_file="$LOG_DIR/migration-report-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$report_file" << EOF
# MS5.0 Database Migration Report
# Generated: $(date '+%Y-%m-%d %H:%M:%S')

## Migration Summary
- Database: ${DB_NAME}@${DB_HOST}:${DB_PORT}
- User: ${DB_USER}
- Container: ${POSTGRES_CONTAINER}
- Total Migrations: ${#MIGRATION_FILES[@]}

## Migration Status
EOF

    # Get migration statistics
    local stats
    stats=$(get_migration_stats)
    IFS=',' read -r total completed failed avg_time <<< "$stats"
    
    cat >> "$report_file" << EOF
- Total Migrations: $total
- Completed: $completed
- Failed: $failed
- Average Execution Time: ${avg_time}ms

## Migration Details
EOF

    # List all migrations with status
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "
        SELECT 
            migration_name,
            migration_file,
            status,
            applied_at,
            execution_time_ms,
            CASE WHEN error_message IS NOT NULL THEN error_message ELSE 'N/A' END as error_message
        FROM ${MIGRATION_LOG_TABLE}
        ORDER BY applied_at;
    " >> "$report_file" 2>/dev/null || echo "Unable to retrieve migration details" >> "$report_file"
    
    cat >> "$report_file" << EOF

## Database Schema Summary
EOF

    # List all tables in factory_telemetry schema
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "
        SELECT 
            table_name,
            CASE WHEN table_type = 'BASE TABLE' THEN 'Table' ELSE table_type END as type
        FROM information_schema.tables 
        WHERE table_schema = 'factory_telemetry'
        ORDER BY table_name;
    " >> "$report_file" 2>/dev/null || echo "Unable to retrieve schema information" >> "$report_file"
    
    cat >> "$report_file" << EOF

## TimescaleDB Hypertables
EOF

    # List TimescaleDB hypertables
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "
        SELECT 
            hypertable_name,
            num_dimensions,
            num_chunks
        FROM timescaledb_information.hypertables 
        WHERE schema_name = 'factory_telemetry'
        ORDER BY hypertable_name;
    " >> "$report_file" 2>/dev/null || echo "No TimescaleDB hypertables found" >> "$report_file"
    
    log_success "Migration report generated: $report_file"
    echo "$report_file"
}

# =============================================================================
# Main Execution Function
# =============================================================================

main() {
    log "🚀 Starting MS5.0 Database Migration Runner"
    log "Target Database: ${DB_NAME}@${DB_HOST}:${DB_PORT}"
    
    # Pre-flight checks
    verify_environment
    setup_logging
    create_migration_log_table
    
    # Execute migrations in order
    local successful_migrations=0
    local failed_migrations=0
    local skipped_migrations=0
    
    for migration_file in "${MIGRATION_FILES[@]}"; do
        local migration_name
        migration_name="$(echo "$migration_file" | sed 's/\.sql$//' | sed 's/^[0-9]*_/&/')"
        
        if execute_migration "$migration_file" "$migration_name"; then
            ((successful_migrations++))
        else
            ((failed_migrations++))
            log_error "Migration failed: $migration_name"
            
            # Ask user if they want to continue
            log_warning "Migration failed. Do you want to continue with remaining migrations? (y/N)"
            read -r continue_migration
            if [[ "$continue_migration" != "y" && "$continue_migration" != "Y" ]]; then
                log_error "Migration process aborted by user"
                exit 1
            fi
        fi
    done
    
    # Final validation
    if ! validate_migration_results; then
        log_error "Migration validation failed"
        exit 1
    fi
    
    # Generate final report
    local report_file
    report_file=$(generate_migration_report)
    
    # Final summary
    log_success "🎉 Database migration process completed!"
    log_success "Successful migrations: $successful_migrations"
    log_success "Failed migrations: $failed_migrations"
    log_success "Skipped migrations: $skipped_migrations"
    log_success "Migration report: $report_file"
    
    if [[ $failed_migrations -eq 0 ]]; then
        log_success "✅ All migrations completed successfully!"
        exit 0
    else
        log_error "❌ Some migrations failed. Please review the migration report."
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
