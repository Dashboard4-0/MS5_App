#!/bin/bash
#==============================================================================
# MS5.0 Pre-Migration Validation Script
#==============================================================================
#
# Comprehensive pre-migration validation for TimescaleDB migration
# Validates system resources, database connectivity, TimescaleDB extension,
# and migration file integrity before executing migrations.
#
# Usage: ./pre-migration-validation.sh [--environment=production|staging|development]
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
QUICK=false

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

# Migration files to validate
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

#==============================================================================
# Logging Framework
#==============================================================================

# Initialize logging
init_logging() {
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    LOG_FILE="${LOG_DIR}/pre_migration_validation_${ENVIRONMENT}_${timestamp}.log"
    
    mkdir -p "${LOG_DIR}"
    
    # Create log file with header
    cat > "${LOG_FILE}" << EOF
==============================================================================
MS5.0 Pre-Migration Validation Log
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
# System Resource Validation
#==============================================================================

# Validate disk space
validate_disk_space() {
    log_info "Validating disk space..."
    
    # Check root filesystem
    local root_space_kb
    root_space_kb=$(df / | awk 'NR==2 {print $4}')
    local root_space_gb=$((root_space_kb / 1024 / 1024))
    
    # Minimum required: 10GB for migration operations
    if [[ ${root_space_kb} -lt 10485760 ]]; then
        log_error "Insufficient disk space on root filesystem"
        log_error "Required: 10GB, Available: ${root_space_gb}GB"
        return 1
    fi
    
    log_success "Root filesystem space: ${root_space_gb}GB available"
    
    # Check Docker data directory if applicable
    if command -v docker >/dev/null 2>&1; then
        local docker_space_kb
        docker_space_kb=$(df /var/lib/docker 2>/dev/null | awk 'NR==2 {print $4}' || echo "0")
        local docker_space_gb=$((docker_space_kb / 1024 / 1024))
        
        if [[ ${docker_space_kb} -lt 5242880 ]]; then  # 5GB minimum for Docker
            log_warn "Low disk space in Docker directory: ${docker_space_gb}GB"
        else
            log_success "Docker directory space: ${docker_space_gb}GB available"
        fi
    fi
    
    return 0
}

# Validate memory
validate_memory() {
    log_info "Validating system memory..."
    
    local total_memory_mb
    total_memory_mb=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    local available_memory_mb
    available_memory_mb=$(free -m | awk 'NR==2{printf "%.0f", $7}')
    
    # Minimum required: 4GB total, 2GB available
    if [[ ${total_memory_mb} -lt 4096 ]]; then
        log_error "Insufficient total memory"
        log_error "Required: 4GB, Available: ${total_memory_mb}MB"
        return 1
    fi
    
    if [[ ${available_memory_mb} -lt 2048 ]]; then
        log_warn "Low available memory: ${available_memory_mb}MB"
        log_warn "Consider freeing memory before migration"
    fi
    
    log_success "Total memory: ${total_memory_mb}MB, Available: ${available_memory_mb}MB"
    return 0
}

# Validate CPU resources
validate_cpu() {
    log_info "Validating CPU resources..."
    
    local cpu_cores
    cpu_cores=$(nproc)
    
    if [[ ${cpu_cores} -lt 2 ]]; then
        log_warn "Low CPU core count: ${cpu_cores}"
        log_warn "Migration may take longer with limited CPU resources"
    else
        log_success "CPU cores available: ${cpu_cores}"
    fi
    
    # Check CPU load
    local load_avg
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    local load_threshold=$(echo "${cpu_cores} * 0.8" | bc -l)
    
    if (( $(echo "${load_avg} > ${load_threshold}" | bc -l) )); then
        log_warn "High system load detected: ${load_avg}"
        log_warn "Consider waiting for lower load before migration"
    else
        log_success "System load acceptable: ${load_avg}"
    fi
    
    return 0
}

#==============================================================================
# Database Connectivity Validation
#==============================================================================

# Test basic database connectivity
test_database_connectivity() {
    log_info "Testing database connectivity..."
    
    # Test connection with timeout
    if timeout 30 bash -c "PGPASSWORD='${DB_PASSWORD}' psql -h '${DB_HOST}' -p '${DB_PORT}' -U '${DB_USER}' -d '${DB_NAME}' -c 'SELECT 1;' >/dev/null 2>&1"; then
        log_success "Database connection successful"
    else
        log_error "Database connection failed"
        log_error "Host: ${DB_HOST}, Port: ${DB_PORT}, Database: ${DB_NAME}, User: ${DB_USER}"
        return 1
    fi
    
    # Test connection with detailed error reporting
    local connection_test
    connection_test=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c "SELECT version();" 2>&1 || echo "CONNECTION_FAILED")
    
    if [[ "${connection_test}" == "CONNECTION_FAILED" ]]; then
        log_error "Database connection test failed"
        return 1
    fi
    
    log_debug "Database version: $(echo "${connection_test}" | head -1)"
    return 0
}

# Validate database permissions
validate_database_permissions() {
    log_info "Validating database permissions..."
    
    # Check if user can create tables
    local create_test
    create_test=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c "
        CREATE TEMP TABLE permission_test (id INT);
        DROP TABLE permission_test;
        SELECT 'SUCCESS' as result;
    " 2>&1 || echo "PERMISSION_FAILED")
    
    if [[ "${create_test}" == "PERMISSION_FAILED" ]]; then
        log_error "Insufficient database permissions"
        log_error "User cannot create tables"
        return 1
    fi
    
    # Check if user can create schemas
    local schema_test
    schema_test=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c "
        CREATE SCHEMA IF NOT EXISTS permission_test_schema;
        DROP SCHEMA IF EXISTS permission_test_schema;
        SELECT 'SUCCESS' as result;
    " 2>&1 || echo "PERMISSION_FAILED")
    
    if [[ "${schema_test}" == "PERMISSION_FAILED" ]]; then
        log_error "Insufficient database permissions"
        log_error "User cannot create schemas"
        return 1
    fi
    
    log_success "Database permissions validated"
    return 0
}

#==============================================================================
# TimescaleDB Validation
#==============================================================================

# Verify TimescaleDB extension installation
verify_timescaledb_extension() {
    log_info "Verifying TimescaleDB extension..."
    
    # Check if TimescaleDB extension exists
    local extension_check
    extension_check=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "SELECT 1 FROM pg_extension WHERE extname = 'timescaledb';" 2>/dev/null || echo "")
    
    if [[ -z "${extension_check}" || "${extension_check}" != "1" ]]; then
        log_error "TimescaleDB extension not found"
        log_error "Please install TimescaleDB and create the extension"
        return 1
    fi
    
    # Get TimescaleDB version
    local version
    version=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "SELECT extversion FROM pg_extension WHERE extname = 'timescaledb';" 2>/dev/null | tr -d ' ')
    
    log_success "TimescaleDB extension verified (version: ${version})"
    
    # Check TimescaleDB license
    local license_info
    license_info=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "SELECT license FROM timescaledb_information.license;" 2>/dev/null || echo "UNKNOWN")
    
    log_info "TimescaleDB license: ${license_info}"
    
    return 0
}

# Test TimescaleDB functionality
test_timescaledb_functionality() {
    log_info "Testing TimescaleDB functionality..."
    
    # Test hypertable creation (dry run)
    local hypertable_test
    hypertable_test=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c "
        CREATE TEMP TABLE test_hypertable (time TIMESTAMPTZ NOT NULL, value DOUBLE PRECISION);
        SELECT create_hypertable('test_hypertable', 'time', if_not_exists => TRUE);
        DROP TABLE test_hypertable;
        SELECT 'SUCCESS' as result;
    " 2>&1 || echo "HYPERTABLE_FAILED")
    
    if [[ "${hypertable_test}" == "HYPERTABLE_FAILED" ]]; then
        log_error "TimescaleDB hypertable creation failed"
        log_error "TimescaleDB may not be properly configured"
        return 1
    fi
    
    log_success "TimescaleDB functionality verified"
    return 0
}

#==============================================================================
# Migration File Validation
#==============================================================================

# Validate migration file existence and integrity
validate_migration_files() {
    log_info "Validating migration files..."
    
    local missing_files=()
    local invalid_files=()
    
    for migration_file in "${MIGRATION_FILES[@]}"; do
        local migration_path="${MIGRATION_DIR}/${migration_file}"
        
        # Check file existence
        if [[ ! -f "${migration_path}" ]]; then
            missing_files+=("${migration_file}")
            continue
        fi
        
        # Check file readability
        if [[ ! -r "${migration_path}" ]]; then
            invalid_files+=("${migration_file} (not readable)")
            continue
        fi
        
        # Check file size (should not be empty)
        if [[ ! -s "${migration_path}" ]]; then
            invalid_files+=("${migration_file} (empty)")
            continue
        fi
        
        # Basic SQL syntax check (if sqlparse is available)
        if command -v sqlparse >/dev/null 2>&1; then
            if ! sqlparse --parse "${migration_path}" >/dev/null 2>&1; then
                log_warn "Potential SQL syntax issues in ${migration_file}"
            fi
        fi
        
        log_debug "Migration file validated: ${migration_file}"
    done
    
    # Report missing files
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        log_error "Missing migration files:"
        for file in "${missing_files[@]}"; do
            log_error "  - ${file}"
        done
        return 1
    fi
    
    # Report invalid files
    if [[ ${#invalid_files[@]} -gt 0 ]]; then
        log_error "Invalid migration files:"
        for file in "${invalid_files[@]}"; do
            log_error "  - ${file}"
        done
        return 1
    fi
    
    log_success "All migration files validated"
    return 0
}

# Check migration file dependencies
validate_migration_dependencies() {
    log_info "Validating migration dependencies..."
    
    # Check for TimescaleDB-specific calls in migration files
    local timescaledb_files=()
    
    for migration_file in "${MIGRATION_FILES[@]}"; do
        local migration_path="${MIGRATION_DIR}/${migration_file}"
        
        if grep -q "create_hypertable\|timescaledb\|hypertable" "${migration_path}" 2>/dev/null; then
            timescaledb_files+=("${migration_file}")
        fi
    done
    
    if [[ ${#timescaledb_files[@]} -gt 0 ]]; then
        log_info "Migration files with TimescaleDB dependencies:"
        for file in "${timescaledb_files[@]}"; do
            log_info "  - ${file}"
        done
    fi
    
    log_success "Migration dependencies validated"
    return 0
}

#==============================================================================
# Docker Environment Validation
#==============================================================================

# Validate Docker environment if applicable
validate_docker_environment() {
    log_info "Validating Docker environment..."
    
    if ! command -v docker >/dev/null 2>&1; then
        log_info "Docker not available, skipping Docker validation"
        return 0
    fi
    
    # Check if Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        log_warn "Docker daemon not running"
        return 0
    fi
    
    # Check if target container exists
    if docker ps -a --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        log_success "Target container found: ${CONTAINER_NAME}"
        
        # Check container status
        local container_status
        container_status=$(docker inspect --format='{{.State.Status}}' "${CONTAINER_NAME}" 2>/dev/null || echo "unknown")
        
        if [[ "${container_status}" == "running" ]]; then
            log_success "Container is running"
        else
            log_warn "Container status: ${container_status}"
        fi
        
        # Check container health
        local health_status
        health_status=$(docker inspect --format='{{.State.Health.Status}}' "${CONTAINER_NAME}" 2>/dev/null || echo "no-healthcheck")
        
        if [[ "${health_status}" == "healthy" ]]; then
            log_success "Container health check passed"
        elif [[ "${health_status}" == "no-healthcheck" ]]; then
            log_info "No health check configured"
        else
            log_warn "Container health status: ${health_status}"
        fi
    else
        log_warn "Target container not found: ${CONTAINER_NAME}"
    fi
    
    return 0
}

#==============================================================================
# Network and Connectivity Validation
#==============================================================================

# Validate network connectivity
validate_network_connectivity() {
    log_info "Validating network connectivity..."
    
    # Test DNS resolution
    if ! nslookup "${DB_HOST}" >/dev/null 2>&1; then
        log_warn "DNS resolution failed for ${DB_HOST}"
    else
        log_success "DNS resolution successful for ${DB_HOST}"
    fi
    
    # Test port connectivity
    if timeout 5 bash -c "echo > /dev/tcp/${DB_HOST}/${DB_PORT}" 2>/dev/null; then
        log_success "Port ${DB_PORT} accessible on ${DB_HOST}"
    else
        log_error "Port ${DB_PORT} not accessible on ${DB_HOST}"
        return 1
    fi
    
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
            --quick)
                QUICK=true
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
MS5.0 Pre-Migration Validation Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --environment=ENV    Target environment (production|staging|development)
    --verbose          Enable detailed debug logging
    --quick            Skip time-consuming validations
    --help             Show this help message

EXAMPLES:
    $0                                    # Validate production environment
    $0 --environment=staging             # Validate staging environment
    $0 --verbose --quick                 # Quick validation with debug info

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
    log_info "Starting MS5.0 pre-migration validation"
    log_info "Environment: ${ENVIRONMENT}"
    log_info "Quick mode: ${QUICK}"
    log_info "Verbose: ${VERBOSE}"
    
    local validation_failed=false
    
    # System resource validation
    validate_disk_space || validation_failed=true
    validate_memory || validation_failed=true
    validate_cpu || validation_failed=true
    
    # Database connectivity validation
    validate_network_connectivity || validation_failed=true
    test_database_connectivity || validation_failed=true
    validate_database_permissions || validation_failed=true
    
    # TimescaleDB validation
    verify_timescaledb_extension || validation_failed=true
    test_timescaledb_functionality || validation_failed=true
    
    # Migration file validation
    validate_migration_files || validation_failed=true
    validate_migration_dependencies || validation_failed=true
    
    # Docker environment validation (if applicable)
    validate_docker_environment || validation_failed=true
    
    # Final validation result
    if [[ "${validation_failed}" == "true" ]]; then
        log_error "❌ Pre-migration validation failed"
        log_error "Please address the issues above before running migrations"
        exit 1
    else
        log_success "✅ Pre-migration validation passed"
        log_success "System is ready for migration"
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
