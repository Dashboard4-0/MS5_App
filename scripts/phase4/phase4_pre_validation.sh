#!/bin/bash
# ============================================================================
# MS5.0 Phase 4: Pre-Optimization Validation
# ============================================================================
# Purpose: Comprehensive validation checks before running Phase 4 optimization.
#          Ensures all prerequisites are met and identifies potential issues
#          that could cause optimization failures.
#
# Design Philosophy: Preflight checks prevent in-flight disasters. Every
#                    requirement is verified before we commit to changes.
#                    Like a starship's launch sequence, we check every
#                    system before engaging the hyperdrive.
# ============================================================================

set -euo pipefail

# Source common functions if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-factory_telemetry}"
DB_USER="${DB_USER:-ms5_user_production}"
DB_PASSWORD="${DB_PASSWORD:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Validation results
VALIDATION_ERRORS=0
VALIDATION_WARNINGS=0

# ----------------------------------------------------------------------------
# Utility Functions
# ----------------------------------------------------------------------------

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $*"
    ((VALIDATION_WARNINGS++))
}

log_error() {
    echo -e "${RED}[✗]${NC} $*" >&2
    ((VALIDATION_ERRORS++))
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
# Validation Checks
# ----------------------------------------------------------------------------

check_database_connection() {
    log_info "Checking database connection..."
    
    if PGPASSWORD="${DB_PASSWORD}" psql \
        -h "${DB_HOST}" \
        -p "${DB_PORT}" \
        -U "${DB_USER}" \
        -d "${DB_NAME}" \
        -c "SELECT 1;" > /dev/null 2>&1; then
        log_success "Database connection successful"
    else
        log_error "Failed to connect to database ${DB_NAME} at ${DB_HOST}:${DB_PORT}"
        return 1
    fi
}

check_timescaledb_extension() {
    log_info "Checking TimescaleDB extension..."
    
    local version=$(execute_sql "SELECT extversion FROM pg_extension WHERE extname = 'timescaledb';")
    
    if [[ -n "${version}" ]]; then
        version=$(echo "$version" | tr -d ' ')
        log_success "TimescaleDB ${version} is installed"
        
        # Check version is 2.x or higher
        local major_version=$(echo "$version" | cut -d'.' -f1)
        if [[ ${major_version} -lt 2 ]]; then
            log_error "TimescaleDB version ${version} is too old. Version 2.0+ required."
        fi
    else
        log_error "TimescaleDB extension not installed"
    fi
}

check_database_size() {
    log_info "Checking database size..."
    
    local db_size=$(execute_sql "SELECT pg_size_pretty(pg_database_size('${DB_NAME}'));")
    db_size=$(echo "$db_size" | tr -d ' ')
    
    log_success "Database size: ${db_size}"
    
    # Check available disk space
    local available=$(df "${SCRIPT_DIR}" | awk 'NR==2 {print $4}')
    local available_gb=$(( available / 1024 / 1024 ))
    
    if [[ ${available_gb} -lt 10 ]]; then
        log_error "Low disk space: ${available_gb}GB available (recommend 10GB+)"
    else
        log_success "Available disk space: ${available_gb}GB"
    fi
}

check_hypertables_exist() {
    log_info "Checking hypertables..."
    
    local expected_tables=(
        "metric_hist"
        "oee_calculations"
        "energy_consumption"
        "production_kpis"
        "production_context_history"
    )
    
    for table in "${expected_tables[@]}"; do
        local exists=$(execute_sql "
            SELECT COUNT(*) 
            FROM timescaledb_information.hypertables 
            WHERE hypertable_schema = 'factory_telemetry' 
              AND hypertable_name = '${table}';
        ")
        
        exists=$(echo "$exists" | tr -d ' ')
        
        if [[ "${exists}" -eq 1 ]]; then
            log_success "Hypertable exists: factory_telemetry.${table}"
        else
            log_error "Hypertable not found: factory_telemetry.${table}"
        fi
    done
}

check_existing_policies() {
    log_info "Checking existing policies..."
    
    # Check compression policies
    local compression_count=$(execute_sql "
        SELECT COUNT(*) 
        FROM timescaledb_information.jobs 
        WHERE proc_name = 'policy_compression'
          AND hypertable_schema = 'factory_telemetry';
    ")
    compression_count=$(echo "$compression_count" | tr -d ' ')
    
    if [[ ${compression_count} -gt 0 ]]; then
        log_warning "Found ${compression_count} existing compression policies (will be updated)"
    else
        log_success "No existing compression policies"
    fi
    
    # Check retention policies
    local retention_count=$(execute_sql "
        SELECT COUNT(*) 
        FROM timescaledb_information.jobs 
        WHERE proc_name = 'policy_retention'
          AND hypertable_schema = 'factory_telemetry';
    ")
    retention_count=$(echo "$retention_count" | tr -d ' ')
    
    if [[ ${retention_count} -gt 0 ]]; then
        log_warning "Found ${retention_count} existing retention policies (will be updated)"
    else
        log_success "No existing retention policies"
    fi
    
    # Check continuous aggregates
    local cagg_count=$(execute_sql "
        SELECT COUNT(*) 
        FROM timescaledb_information.continuous_aggregates
        WHERE view_schema = 'factory_telemetry';
    ")
    cagg_count=$(echo "$cagg_count" | tr -d ' ')
    
    if [[ ${cagg_count} -gt 0 ]]; then
        log_warning "Found ${cagg_count} existing continuous aggregates (will be updated)"
    else
        log_success "No existing continuous aggregates"
    fi
}

check_database_permissions() {
    log_info "Checking database permissions..."
    
    # Check if user can create indexes
    local can_create=$(execute_sql "
        SELECT has_schema_privilege('${DB_USER}', 'factory_telemetry', 'CREATE');
    ")
    can_create=$(echo "$can_create" | tr -d ' ')
    
    if [[ "${can_create}" == "t" ]]; then
        log_success "User has CREATE privilege on factory_telemetry schema"
    else
        log_error "User lacks CREATE privilege on factory_telemetry schema"
    fi
    
    # Check if user can alter tables
    local can_alter=$(execute_sql "
        SELECT has_table_privilege('${DB_USER}', 'factory_telemetry.metric_hist', 'UPDATE');
    ")
    can_alter=$(echo "$can_alter" | tr -d ' ')
    
    if [[ "${can_alter}" == "t" ]]; then
        log_success "User has ALTER privilege on tables"
    else
        log_error "User lacks ALTER privilege on tables"
    fi
}

check_active_connections() {
    log_info "Checking active connections..."
    
    local active_connections=$(execute_sql "
        SELECT COUNT(*) 
        FROM pg_stat_activity 
        WHERE datname = '${DB_NAME}' 
          AND state = 'active'
          AND pid != pg_backend_pid();
    ")
    active_connections=$(echo "$active_connections" | tr -d ' ')
    
    if [[ ${active_connections} -gt 50 ]]; then
        log_warning "High number of active connections: ${active_connections}"
    else
        log_success "Active connections: ${active_connections}"
    fi
}

check_table_bloat() {
    log_info "Checking table bloat..."
    
    # Simple bloat check - count dead tuples
    local tables=("metric_hist" "oee_calculations" "energy_consumption")
    
    for table in "${tables[@]}"; do
        local dead_tuples=$(execute_sql "
            SELECT n_dead_tup 
            FROM pg_stat_user_tables 
            WHERE schemaname = 'factory_telemetry' 
              AND relname = '${table}';
        ")
        dead_tuples=$(echo "$dead_tuples" | tr -d ' ')
        
        if [[ -n "${dead_tuples}" && ${dead_tuples} -gt 100000 ]]; then
            log_warning "${table} has ${dead_tuples} dead tuples (consider VACUUM)"
        fi
    done
    
    log_success "Table bloat check complete"
}

check_postgresql_version() {
    log_info "Checking PostgreSQL version..."
    
    local pg_version=$(execute_sql "SHOW server_version;")
    pg_version=$(echo "$pg_version" | tr -d ' ')
    
    local major_version=$(echo "$pg_version" | cut -d'.' -f1)
    
    if [[ ${major_version} -ge 13 ]]; then
        log_success "PostgreSQL version: ${pg_version}"
    else
        log_warning "PostgreSQL version ${pg_version} is older than recommended (13+)"
    fi
}

check_maintenance_window() {
    log_info "Checking system load..."
    
    # Check if current time is within recommended maintenance window
    local current_hour=$(date +%H)
    
    if [[ ${current_hour} -ge 22 || ${current_hour} -le 6 ]]; then
        log_success "Currently in recommended maintenance window (22:00-06:00)"
    else
        log_warning "Not in recommended maintenance window (current hour: ${current_hour}:00)"
    fi
}

check_backup_availability() {
    log_info "Checking backup directory..."
    
    local backup_dir="${SCRIPT_DIR}/../../backups/phase4"
    
    if [[ -d "${backup_dir}" ]]; then
        local backup_count=$(find "${backup_dir}" -name "*.sql.gz" 2>/dev/null | wc -l)
        log_success "Backup directory exists (${backup_count} previous backups)"
    else
        log_warning "Backup directory does not exist (will be created)"
    fi
}

check_timescaledb_config() {
    log_info "Checking TimescaleDB configuration..."
    
    # Check background workers
    local max_bg_workers=$(execute_sql "SHOW timescaledb.max_background_workers;")
    max_bg_workers=$(echo "$max_bg_workers" | tr -d ' ')
    
    if [[ -n "${max_bg_workers}" ]]; then
        if [[ ${max_bg_workers} -ge 4 ]]; then
            log_success "TimescaleDB background workers: ${max_bg_workers}"
        else
            log_warning "Low background worker count: ${max_bg_workers} (recommend 8+)"
        fi
    fi
    
    # Check chunk time intervals (if already set)
    local chunk_info=$(execute_sql "
        SELECT hypertable_name, interval_length 
        FROM timescaledb_information.dimensions 
        WHERE hypertable_schema = 'factory_telemetry' 
        LIMIT 1;
    ")
    
    if [[ -n "${chunk_info}" ]]; then
        log_info "Chunk intervals already configured"
    fi
}

# ----------------------------------------------------------------------------
# Main Validation Flow
# ----------------------------------------------------------------------------

main() {
    echo "=========================================="
    echo "  Phase 4 Pre-Optimization Validation"
    echo "=========================================="
    echo ""
    
    # Check if database password is set
    if [[ -z "${DB_PASSWORD}" ]]; then
        log_error "DB_PASSWORD environment variable is not set"
        exit 1
    fi
    
    # Run all validation checks
    check_database_connection || exit 1
    check_timescaledb_extension
    check_postgresql_version
    check_database_size
    check_hypertables_exist
    check_existing_policies
    check_database_permissions
    check_active_connections
    check_table_bloat
    check_maintenance_window
    check_backup_availability
    check_timescaledb_config
    
    # Summary
    echo ""
    echo "=========================================="
    echo "  Validation Summary"
    echo "=========================================="
    
    if [[ ${VALIDATION_ERRORS} -eq 0 ]]; then
        log_success "All validation checks passed"
        
        if [[ ${VALIDATION_WARNINGS} -gt 0 ]]; then
            log_warning "${VALIDATION_WARNINGS} warnings (review above)"
        fi
        
        echo ""
        log_success "System is ready for Phase 4 optimization"
        exit 0
    else
        log_error "${VALIDATION_ERRORS} errors, ${VALIDATION_WARNINGS} warnings"
        echo ""
        log_error "System is NOT ready for Phase 4 optimization"
        exit 1
    fi
}

main "$@"
