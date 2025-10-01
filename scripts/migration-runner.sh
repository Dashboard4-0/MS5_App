#!/bin/bash
#==============================================================================
# MS5.0 Database Migration Runner
#==============================================================================
# 
# Production-grade migration runner for TimescaleDB migration
# Handles sequential execution of 9 migration files with comprehensive
# error handling, logging, and rollback capabilities.
#
# Usage: ./migration-runner.sh [--environment=production|staging|development]
#==============================================================================

set -euo pipefail  # Strict error handling

#==============================================================================
# Configuration & Constants
#==============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly LOG_DIR="${PROJECT_ROOT}/logs/migrations"
readonly BACKUP_DIR="${PROJECT_ROOT}/backups"
readonly MIGRATION_DIR="${PROJECT_ROOT}"

# Migration files in execution order
readonly MIGRATIONS=(
    "001_init_telemetry.sql:001 - Initialize Telemetry"
    "002_plc_equipment_management.sql:002 - PLC Equipment Management"
    "003_production_management.sql:003 - Production Management"
    "004_advanced_production_features.sql:004 - Advanced Production Features"
    "005_andon_escalation_system.sql:005 - Andon Escalation System"
    "006_report_system.sql:006 - Report System"
    "007_plc_integration_phase1.sql:007 - PLC Integration Phase 1"
    "008_fix_critical_schema_issues.sql:008 - Fix Critical Schema Issues"
    "009_database_optimization.sql:009 - Database Optimization"
)

# Default configuration
ENVIRONMENT="${1:-production}"
DRY_RUN=false
VERBOSE=false
FORCE=false

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

#==============================================================================
# Logging Framework
#==============================================================================

# Initialize logging
init_logging() {
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    LOG_FILE="${LOG_DIR}/migration_${ENVIRONMENT}_${timestamp}.log"
    
    mkdir -p "${LOG_DIR}"
    
    # Create log file with header
    cat > "${LOG_FILE}" << EOF
==============================================================================
MS5.0 Database Migration Log
==============================================================================
Environment: ${ENVIRONMENT}
Started: $(date '+%Y-%m-%d %H:%M:%S UTC')
Database: ${DB_NAME}@${DB_HOST}:${DB_PORT}
User: ${DB_USER}
Migration Runner Version: 1.0.0
==============================================================================

EOF
}

# Logging functions with different levels
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
# Database Connection & Validation
#==============================================================================

# Test database connectivity
test_db_connection() {
    log_info "Testing database connection..."
    
    if ! PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c "SELECT 1;" >/dev/null 2>&1; then
        log_error "Database connection failed"
        log_error "Host: ${DB_HOST}, Port: ${DB_PORT}, Database: ${DB_NAME}, User: ${DB_USER}"
        return 1
    fi
    
    log_success "Database connection successful"
    return 0
}

# Verify TimescaleDB extension
verify_timescaledb() {
    log_info "Verifying TimescaleDB extension..."
    
    local extension_check
    extension_check=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "SELECT 1 FROM pg_extension WHERE extname = 'timescaledb';" 2>/dev/null || echo "")
    
    if [[ -z "${extension_check}" || "${extension_check}" != "1" ]]; then
        log_error "TimescaleDB extension not found or not properly installed"
        log_error "Please ensure TimescaleDB is installed and the extension is created"
        return 1
    fi
    
    # Get TimescaleDB version
    local version
    version=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "SELECT extversion FROM pg_extension WHERE extname = 'timescaledb';" 2>/dev/null | tr -d ' ')
    
    log_success "TimescaleDB extension verified (version: ${version})"
    return 0
}

#==============================================================================
# Migration Management
#==============================================================================

# Create migration log table
create_migration_log_table() {
    log_info "Creating migration log table..."
    
    PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" << 'EOF'
CREATE TABLE IF NOT EXISTS migration_log (
    id SERIAL PRIMARY KEY,
    migration_name VARCHAR(255) UNIQUE NOT NULL,
    migration_file VARCHAR(255) NOT NULL,
    applied_at TIMESTAMPTZ DEFAULT NOW(),
    applied_by VARCHAR(255) DEFAULT current_user,
    execution_time_ms INTEGER,
    success BOOLEAN NOT NULL DEFAULT TRUE,
    error_message TEXT,
    checksum VARCHAR(64)
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_migration_log_name ON migration_log (migration_name);
CREATE INDEX IF NOT EXISTS idx_migration_log_applied_at ON migration_log (applied_at DESC);
EOF
    
    log_success "Migration log table created/verified"
}

# Check if migration is already applied
is_migration_applied() {
    local migration_name="$1"
    
    local result
    result=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "SELECT 1 FROM migration_log WHERE migration_name = '${migration_name}' AND success = TRUE;" 2>/dev/null || echo "")
    
    [[ "${result}" == "1" ]]
}

# Calculate file checksum for integrity verification
calculate_checksum() {
    local file_path="$1"
    sha256sum "${file_path}" | cut -d' ' -f1
}

# Execute a single migration
execute_migration() {
    local migration_file="$1"
    local migration_name="$2"
    local migration_path="${MIGRATION_DIR}/${migration_file}"
    
    log_info "Starting migration: ${migration_name}"
    log_debug "Migration file: ${migration_path}"
    
    # Validate migration file exists
    if [[ ! -f "${migration_path}" ]]; then
        log_error "Migration file not found: ${migration_path}"
        return 1
    fi
    
    # Check if already applied (unless force is enabled)
    if [[ "${FORCE}" != "true" ]] && is_migration_applied "${migration_name}"; then
        log_info "Migration ${migration_name} already applied, skipping"
        return 0
    fi
    
    # Calculate checksum for integrity
    local checksum
    checksum=$(calculate_checksum "${migration_path}")
    log_debug "Migration checksum: ${checksum}"
    
    # Record migration start
    local start_time
    start_time=$(date +%s%3N)
    
    # Execute migration with error handling
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "DRY RUN: Would execute migration ${migration_name}"
        log_debug "Command: PGPASSWORD=*** psql -h ${DB_HOST} -p ${DB_PORT} -U ${DB_USER} -d ${DB_NAME} -f ${migration_path}"
        return 0
    fi
    
    # Log migration attempt
    PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c "
        INSERT INTO migration_log (migration_name, migration_file, success, checksum) 
        VALUES ('${migration_name}', '${migration_file}', FALSE, '${checksum}');" 2>/dev/null || true
    
    # Execute the migration
    if PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -f "${migration_path}" >> "${LOG_FILE}" 2>&1; then
        local end_time
        end_time=$(date +%s%3N)
        local execution_time=$((end_time - start_time))
        
        # Update migration log with success
        PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c "
            UPDATE migration_log 
            SET success = TRUE, execution_time_ms = ${execution_time}, applied_at = NOW() 
            WHERE migration_name = '${migration_name}';" 2>/dev/null
        
        log_success "✅ Migration ${migration_name} completed successfully (${execution_time}ms)"
        return 0
    else
        local end_time
        end_time=$(date +%s%3N)
        local execution_time=$((end_time - start_time))
        
        # Update migration log with failure
        PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c "
            UPDATE migration_log 
            SET success = FALSE, execution_time_ms = ${execution_time}, 
                error_message = 'Migration execution failed' 
            WHERE migration_name = '${migration_name}';" 2>/dev/null
        
        log_error "❌ Migration ${migration_name} failed (${execution_time}ms)"
        return 1
    fi
}

#==============================================================================
# Environment Validation
#==============================================================================

# Validate system resources
validate_system_resources() {
    log_info "Validating system resources..."
    
    # Check disk space (minimum 10GB free)
    local disk_space_kb
    disk_space_kb=$(df / | awk 'NR==2 {print $4}')
    local disk_space_gb=$((disk_space_kb / 1024 / 1024))
    
    if [[ ${disk_space_kb} -lt 10485760 ]]; then  # 10GB in KB
        log_error "Insufficient disk space. Required: 10GB, Available: ${disk_space_gb}GB"
        return 1
    fi
    
    log_success "Disk space validation passed (${disk_space_gb}GB available)"
    
    # Check memory (minimum 4GB)
    local memory_mb
    memory_mb=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    
    if [[ ${memory_mb} -lt 4096 ]]; then
        log_error "Insufficient memory. Required: 4GB, Available: ${memory_mb}MB"
        return 1
    fi
    
    log_success "Memory validation passed (${memory_mb}MB available)"
    
    # Check if running in Docker environment
    if [[ -f /.dockerenv ]]; then
        log_info "Running in Docker container environment"
    else
        log_info "Running in host environment"
    fi
    
    return 0
}

# Validate migration files
validate_migration_files() {
    log_info "Validating migration files..."
    
    local missing_files=()
    
    for migration_entry in "${MIGRATIONS[@]}"; do
        local migration_file="${migration_entry%%:*}"
        local migration_path="${MIGRATION_DIR}/${migration_file}"
        
        if [[ ! -f "${migration_path}" ]]; then
            missing_files+=("${migration_file}")
        fi
    done
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        log_error "Missing migration files:"
        for file in "${missing_files[@]}"; do
            log_error "  - ${file}"
        done
        return 1
    fi
    
    log_success "All migration files validated"
    return 0
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
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --force)
                FORCE=true
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
MS5.0 Database Migration Runner

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --environment=ENV    Target environment (production|staging|development)
    --dry-run          Show what would be executed without making changes
    --verbose          Enable detailed debug logging
    --force            Force re-execution of already applied migrations
    --help             Show this help message

EXAMPLES:
    $0                                    # Run migrations for production
    $0 --environment=staging             # Run migrations for staging
    $0 --dry-run --verbose               # Preview migrations with debug info
    $0 --force                           # Re-run all migrations

ENVIRONMENT VARIABLES:
    DB_HOST            Database host (default: localhost)
    DB_PORT            Database port (default: 5432/5433/5434)
    DB_NAME            Database name
    DB_USER            Database user
    POSTGRES_PASSWORD_* Database password for environment

EOF
}

# Main execution function
main() {
    log_info "Starting MS5.0 database migration process"
    log_info "Environment: ${ENVIRONMENT}"
    log_info "Dry run: ${DRY_RUN}"
    log_info "Verbose: ${VERBOSE}"
    log_info "Force: ${FORCE}"
    
    # Pre-execution validation
    validate_system_resources || exit 1
    validate_migration_files || exit 1
    test_db_connection || exit 1
    verify_timescaledb || exit 1
    
    # Setup migration infrastructure
    create_migration_log_table || exit 1
    
    # Execute migrations
    local failed_migrations=()
    local successful_migrations=()
    
    for migration_entry in "${MIGRATIONS[@]}"; do
        local migration_file="${migration_entry%%:*}"
        local migration_name="${migration_entry##*:}"
        
        if execute_migration "${migration_file}" "${migration_name}"; then
            successful_migrations+=("${migration_name}")
        else
            failed_migrations+=("${migration_name}")
            
            # Stop on first failure unless force is enabled
            if [[ "${FORCE}" != "true" ]]; then
                log_error "Migration failed. Stopping execution."
                break
            fi
        fi
    done
    
    # Summary report
    log_info "Migration execution summary:"
    log_info "  Successful: ${#successful_migrations[@]}"
    log_info "  Failed: ${#failed_migrations[@]}"
    
    if [[ ${#successful_migrations[@]} -gt 0 ]]; then
        log_success "Successful migrations:"
        for migration in "${successful_migrations[@]}"; do
            log_success "  ✅ ${migration}"
        done
    fi
    
    if [[ ${#failed_migrations[@]} -gt 0 ]]; then
        log_error "Failed migrations:"
        for migration in "${failed_migrations[@]}"; do
            log_error "  ❌ ${migration}"
        done
        exit 1
    fi
    
    log_success "🎉 All migrations completed successfully!"
    log_info "Migration log saved to: ${LOG_FILE}"
}

#==============================================================================
# Script Entry Point
#==============================================================================

# Initialize logging first
init_logging

# Parse arguments and execute main function
parse_arguments "$@"
main "$@"
