#!/bin/bash
# ============================================================================
# MS5.0 Phase 4: TimescaleDB Optimization Orchestrator
# ============================================================================
# Purpose: Master orchestration script that executes all Phase 4 optimization
#          steps in the correct sequence with comprehensive error handling,
#          logging, and rollback capabilities.
#
# Design Philosophy: This is mission control. Every action is logged, every
#                    failure is caught, every state is validated. Like a
#                    starship's preflight checklist, we verify each system
#                    before proceeding to the next.
#
# Usage:
#   ./phase4_orchestrator.sh [--environment production|staging|development]
#                           [--dry-run]
#                           [--skip-validation]
#
# Requirements:
#   - PostgreSQL client tools (psql)
#   - TimescaleDB 2.x or higher
#   - Sufficient privileges to modify database
# ============================================================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures
IFS=$'\n\t'        # Sane word splitting

# ----------------------------------------------------------------------------
# Configuration and Constants
# ----------------------------------------------------------------------------

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly LOG_DIR="${PROJECT_ROOT}/logs/phase4"
readonly BACKUP_DIR="${PROJECT_ROOT}/backups/phase4"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
readonly LOG_FILE="${LOG_DIR}/phase4_${TIMESTAMP}.log"

# Default configuration
ENVIRONMENT="${PHASE4_ENV:-production}"
DRY_RUN=false
SKIP_VALIDATION=false
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-factory_telemetry}"
DB_USER="${DB_USER:-ms5_user_production}"
DB_PASSWORD="${DB_PASSWORD:-}"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Phase 4 SQL scripts in execution order
readonly SQL_SCRIPTS=(
    "phase4_01_hypertable_optimization.sql"
    "phase4_02_compression_policies.sql"
    "phase4_03_retention_policies.sql"
    "phase4_04_performance_indexes.sql"
    "phase4_05_continuous_aggregates.sql"
)

# ----------------------------------------------------------------------------
# Utility Functions
# ----------------------------------------------------------------------------

# Logging functions with timestamps and color
log_info() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $*"
    echo -e "${BLUE}${msg}${NC}" | tee -a "${LOG_FILE}"
}

log_success() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] [SUCCESS] $*"
    echo -e "${GREEN}${msg}${NC}" | tee -a "${LOG_FILE}"
}

log_warning() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] [WARNING] $*"
    echo -e "${YELLOW}${msg}${NC}" | tee -a "${LOG_FILE}"
}

log_error() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $*"
    echo -e "${RED}${msg}${NC}" | tee -a "${LOG_FILE}" >&2
}

log_section() {
    local msg="$*"
    echo -e "\n${MAGENTA}========================================${NC}" | tee -a "${LOG_FILE}"
    echo -e "${MAGENTA}  ${msg}${NC}" | tee -a "${LOG_FILE}"
    echo -e "${MAGENTA}========================================${NC}\n" | tee -a "${LOG_FILE}"
}

# Progress bar display
show_progress() {
    local current=$1
    local total=$2
    local step_name=$3
    local percent=$((current * 100 / total))
    local completed=$((percent / 2))
    local remaining=$((50 - completed))
    
    printf "\r${CYAN}Progress: [%s%s] %d%% - %s${NC}" \
        "$(printf '█%.0s' $(seq 1 $completed))" \
        "$(printf '░%.0s' $(seq 1 $remaining))" \
        "$percent" \
        "$step_name"
}

# ----------------------------------------------------------------------------
# Database Connection Functions
# ----------------------------------------------------------------------------

# Test database connectivity
test_db_connection() {
    log_info "Testing database connection to ${DB_HOST}:${DB_PORT}/${DB_NAME}"
    
    if PGPASSWORD="${DB_PASSWORD}" psql \
        -h "${DB_HOST}" \
        -p "${DB_PORT}" \
        -U "${DB_USER}" \
        -d "${DB_NAME}" \
        -c "SELECT 1;" \
        > /dev/null 2>&1; then
        log_success "Database connection successful"
        return 0
    else
        log_error "Failed to connect to database"
        return 1
    fi
}

# Execute SQL file with error handling
execute_sql_file() {
    local sql_file=$1
    local description=${2:-"Executing ${sql_file}"}
    
    log_info "${description}"
    
    if [[ "${DRY_RUN}" == true ]]; then
        log_warning "DRY RUN: Would execute ${sql_file}"
        return 0
    fi
    
    local start_time=$(date +%s)
    
    if PGPASSWORD="${DB_PASSWORD}" psql \
        -h "${DB_HOST}" \
        -p "${DB_PORT}" \
        -U "${DB_USER}" \
        -d "${DB_NAME}" \
        -f "${sql_file}" \
        >> "${LOG_FILE}" 2>&1; then
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_success "${description} completed in ${duration}s"
        return 0
    else
        log_error "${description} failed"
        return 1
    fi
}

# Execute SQL query and return result
execute_sql_query() {
    local query=$1
    
    PGPASSWORD="${DB_PASSWORD}" psql \
        -h "${DB_HOST}" \
        -p "${DB_PORT}" \
        -U "${DB_USER}" \
        -d "${DB_NAME}" \
        -t \
        -c "${query}" 2>/dev/null
}

# ----------------------------------------------------------------------------
# Validation Functions
# ----------------------------------------------------------------------------

# Verify TimescaleDB extension
validate_timescaledb() {
    log_info "Validating TimescaleDB installation"
    
    local version=$(execute_sql_query "SELECT extversion FROM pg_extension WHERE extname = 'timescaledb';")
    
    if [[ -n "${version}" ]]; then
        log_success "TimescaleDB version ${version} detected"
        return 0
    else
        log_error "TimescaleDB extension not found"
        return 1
    fi
}

# Verify hypertables exist
validate_hypertables() {
    log_info "Validating hypertables"
    
    local expected_tables=(
        "metric_hist"
        "oee_calculations"
        "energy_consumption"
        "production_kpis"
        "production_context_history"
    )
    
    local found_count=0
    
    for table in "${expected_tables[@]}"; do
        local exists=$(execute_sql_query "
            SELECT COUNT(*) 
            FROM timescaledb_information.hypertables 
            WHERE hypertable_schema = 'factory_telemetry' 
              AND hypertable_name = '${table}';
        ")
        
        if [[ "${exists}" -eq 1 ]]; then
            log_info "  ✓ ${table} is a hypertable"
            ((found_count++))
        else
            log_warning "  ✗ ${table} is not a hypertable"
        fi
    done
    
    if [[ ${found_count} -eq ${#expected_tables[@]} ]]; then
        log_success "All ${found_count} hypertables validated"
        return 0
    else
        log_error "Only ${found_count}/${#expected_tables[@]} hypertables found"
        return 1
    fi
}

# Check system resources
validate_system_resources() {
    log_info "Validating system resources"
    
    # Check available disk space (require at least 10GB)
    local available_space=$(df "${PROJECT_ROOT}" | awk 'NR==2 {print $4}')
    local required_space=$((10 * 1024 * 1024))  # 10GB in KB
    
    if [[ ${available_space} -lt ${required_space} ]]; then
        log_error "Insufficient disk space: $(( available_space / 1024 / 1024 ))GB available, 10GB required"
        return 1
    fi
    
    log_info "  ✓ Disk space: $(( available_space / 1024 / 1024 ))GB available"
    
    # Check memory (informational only)
    if command -v free &> /dev/null; then
        local total_memory=$(free -m | awk 'NR==2{printf "%.0f", $2}')
        log_info "  ✓ System memory: ${total_memory}MB"
    fi
    
    log_success "System resources validated"
    return 0
}

# ----------------------------------------------------------------------------
# Backup Functions
# ----------------------------------------------------------------------------

# Create pre-optimization backup
create_backup() {
    log_section "Creating Pre-Optimization Backup"
    
    if [[ "${DRY_RUN}" == true ]]; then
        log_warning "DRY RUN: Would create backup"
        return 0
    fi
    
    mkdir -p "${BACKUP_DIR}"
    
    local backup_file="${BACKUP_DIR}/phase4_pre_optimization_${TIMESTAMP}.sql"
    
    log_info "Creating database backup: ${backup_file}"
    
    if PGPASSWORD="${DB_PASSWORD}" pg_dump \
        -h "${DB_HOST}" \
        -p "${DB_PORT}" \
        -U "${DB_USER}" \
        -d "${DB_NAME}" \
        -F plain \
        -f "${backup_file}" \
        >> "${LOG_FILE}" 2>&1; then
        
        local backup_size=$(du -h "${backup_file}" | cut -f1)
        log_success "Backup created successfully (${backup_size})"
        
        # Compress backup
        log_info "Compressing backup..."
        if gzip "${backup_file}"; then
            log_success "Backup compressed: ${backup_file}.gz"
        fi
        
        return 0
    else
        log_error "Backup creation failed"
        return 1
    fi
}

# ----------------------------------------------------------------------------
# Main Orchestration Functions
# ----------------------------------------------------------------------------

# Parse command-line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --skip-validation)
                SKIP_VALIDATION=true
                shift
                ;;
            --db-host)
                DB_HOST="$2"
                shift 2
                ;;
            --db-port)
                DB_PORT="$2"
                shift 2
                ;;
            --db-name)
                DB_NAME="$2"
                shift 2
                ;;
            --db-user)
                DB_USER="$2"
                shift 2
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown argument: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Display usage information
show_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Phase 4 TimescaleDB Optimization Orchestrator

OPTIONS:
    --environment ENV       Target environment (production|staging|development)
    --dry-run              Simulate execution without making changes
    --skip-validation      Skip pre-flight validation checks
    --db-host HOST         Database host (default: localhost)
    --db-port PORT         Database port (default: 5432)
    --db-name NAME         Database name (default: factory_telemetry)
    --db-user USER         Database user (default: ms5_user_production)
    --help                 Display this help message

ENVIRONMENT VARIABLES:
    DB_PASSWORD            Database password (required)
    PHASE4_ENV            Default environment

EXAMPLES:
    # Production deployment
    ./phase4_orchestrator.sh --environment production

    # Dry run for staging
    ./phase4_orchestrator.sh --environment staging --dry-run

    # Skip validation (use with caution)
    ./phase4_orchestrator.sh --skip-validation

EOF
}

# Main execution flow
main() {
    # Initialize logging
    mkdir -p "${LOG_DIR}"
    
    log_section "MS5.0 Phase 4: TimescaleDB Optimization"
    log_info "Timestamp: ${TIMESTAMP}"
    log_info "Environment: ${ENVIRONMENT}"
    log_info "Database: ${DB_HOST}:${DB_PORT}/${DB_NAME}"
    log_info "User: ${DB_USER}"
    log_info "Dry Run: ${DRY_RUN}"
    log_info "Log File: ${LOG_FILE}"
    
    # Verify database password is provided
    if [[ -z "${DB_PASSWORD}" ]]; then
        log_error "DB_PASSWORD environment variable is required"
        exit 1
    fi
    
    # Pre-flight checks
    if [[ "${SKIP_VALIDATION}" == false ]]; then
        log_section "Pre-Flight Validation"
        test_db_connection || exit 1
        validate_timescaledb || exit 1
        validate_hypertables || exit 1
        validate_system_resources || exit 1
    else
        log_warning "Skipping pre-flight validation (--skip-validation)"
    fi
    
    # Create backup
    if [[ "${DRY_RUN}" == false ]]; then
        create_backup || {
            log_error "Backup failed. Aborting optimization."
            exit 1
        }
    fi
    
    # Execute optimization scripts
    log_section "Executing Optimization Scripts"
    
    local total_scripts=${#SQL_SCRIPTS[@]}
    local current_script=0
    
    for script in "${SQL_SCRIPTS[@]}"; do
        ((current_script++))
        
        local script_path="${SCRIPT_DIR}/${script}"
        local script_name="${script%.sql}"
        
        show_progress ${current_script} ${total_scripts} "${script_name}"
        echo ""  # New line after progress bar
        
        if [[ ! -f "${script_path}" ]]; then
            log_error "Script not found: ${script_path}"
            exit 1
        fi
        
        execute_sql_file "${script_path}" "Phase 4.${current_script}: ${script_name}" || {
            log_error "Optimization failed at step ${current_script}: ${script_name}"
            exit 1
        }
    done
    
    echo ""  # Clear progress bar line
    
    # Post-optimization validation
    if [[ "${DRY_RUN}" == false ]]; then
        log_section "Post-Optimization Validation"
        
        "${SCRIPT_DIR}/phase4_post_validation.sh" || {
            log_error "Post-optimization validation failed"
            exit 1
        }
    fi
    
    # Success summary
    log_section "Phase 4 Optimization Complete"
    log_success "All optimization steps completed successfully"
    log_info "Review log file for details: ${LOG_FILE}"
    
    if [[ "${DRY_RUN}" == false ]]; then
        log_info "Backup location: ${BACKUP_DIR}"
    fi
    
    # Display optimization summary
    if [[ "${DRY_RUN}" == false ]]; then
        log_info "\nOptimization Summary:"
        execute_sql_query "
            SELECT 
                '  • Hypertables: ' || COUNT(*) 
            FROM timescaledb_information.hypertables 
            WHERE hypertable_schema = 'factory_telemetry';
        "
        
        execute_sql_query "
            SELECT 
                '  • Compression policies: ' || COUNT(*) 
            FROM timescaledb_information.jobs 
            WHERE proc_name = 'policy_compression';
        "
        
        execute_sql_query "
            SELECT 
                '  • Retention policies: ' || COUNT(*) 
            FROM timescaledb_information.jobs 
            WHERE proc_name = 'policy_retention';
        "
        
        execute_sql_query "
            SELECT 
                '  • Continuous aggregates: ' || COUNT(*) 
            FROM timescaledb_information.continuous_aggregates 
            WHERE view_schema = 'factory_telemetry';
        "
    fi
    
    log_success "\n🚀 Phase 4 optimization completed successfully!"
    
    return 0
}

# ----------------------------------------------------------------------------
# Script Entry Point
# ----------------------------------------------------------------------------

# Trap errors and cleanup
trap 'log_error "Script interrupted"; exit 130' INT
trap 'log_error "Script terminated"; exit 143' TERM

# Parse arguments and execute
parse_arguments "$@"
main

exit 0
