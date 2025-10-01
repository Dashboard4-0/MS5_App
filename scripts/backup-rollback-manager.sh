#!/bin/bash
#==============================================================================
# MS5.0 Database Backup & Rollback Management Script
#==============================================================================
#
# Production-grade backup and rollback management for TimescaleDB migration
# Provides comprehensive backup creation, restoration, and rollback procedures
# with integrity verification and automated recovery options.
#
# Usage: ./backup-rollback-manager.sh [command] [options]
# Commands: backup, restore, rollback, list, verify
#==============================================================================

set -euo pipefail  # Strict error handling

#==============================================================================
# Configuration & Constants
#==============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly BACKUP_DIR="${PROJECT_ROOT}/backups"
readonly LOG_DIR="${PROJECT_ROOT}/logs/backup"
readonly ROLLBACK_DIR="${PROJECT_ROOT}/rollback"

# Default configuration
ENVIRONMENT="${ENVIRONMENT:-production}"
VERBOSE=false
COMPRESSION=true
PARALLEL_JOBS=4

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

# Backup types
readonly BACKUP_TYPES=("full" "schema" "data" "hypertables" "metadata")

#==============================================================================
# Logging Framework
#==============================================================================

# Initialize logging
init_logging() {
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    LOG_FILE="${LOG_DIR}/backup_rollback_${ENVIRONMENT}_${timestamp}.log"
    
    mkdir -p "${LOG_DIR}"
    
    # Create log file with header
    cat > "${LOG_FILE}" << EOF
==============================================================================
MS5.0 Backup & Rollback Management Log
==============================================================================
Environment: ${ENVIRONMENT}
Started: $(date '+%Y-%m-%d %H:%M:%S UTC')
Database: ${DB_NAME}@${DB_HOST}:${DB_PORT}
User: ${DB_USER}
Backup Manager Version: 1.0.0
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
# Database Connection & Validation
#==============================================================================

# Test database connectivity
test_db_connection() {
    log_info "Testing database connection..."
    
    if ! PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c "SELECT 1;" >/dev/null 2>&1; then
        log_error "Database connection failed"
        return 1
    fi
    
    log_success "Database connection successful"
    return 0
}

# Get database information
get_database_info() {
    log_info "Collecting database information..."
    
    # Database size
    local db_size
    db_size=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "
        SELECT pg_size_pretty(pg_database_size('${DB_NAME}'));
    " 2>/dev/null | tr -d ' ')
    
    # Table count
    local table_count
    table_count=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "
        SELECT COUNT(*) FROM information_schema.tables 
        WHERE table_schema = 'factory_telemetry';
    " 2>/dev/null | tr -d ' ')
    
    # Hypertable count
    local hypertable_count
    hypertable_count=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "
        SELECT COUNT(*) FROM timescaledb_information.hypertables;
    " 2>/dev/null | tr -d ' ')
    
    log_info "Database size: ${db_size}"
    log_info "Tables in factory_telemetry schema: ${table_count}"
    log_info "Hypertables: ${hypertable_count}"
    
    echo "${db_size}|${table_count}|${hypertable_count}"
}

#==============================================================================
# Backup Creation Functions
#==============================================================================

# Create full database backup
create_full_backup() {
    local backup_name="$1"
    local backup_path="${BACKUP_DIR}/${backup_name}"
    
    log_info "Creating full database backup: ${backup_name}"
    
    mkdir -p "${backup_path}"
    
    # Full database dump
    local dump_file="${backup_path}/full_database.sql"
    log_info "Creating full database dump..."
    
    if PGPASSWORD="${DB_PASSWORD}" pg_dump -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" \
        --verbose --no-password --format=plain --create --clean --if-exists \
        --exclude-schema=information_schema --exclude-schema=pg_catalog \
        > "${dump_file}" 2>> "${LOG_FILE}"; then
        log_success "Full database dump created: ${dump_file}"
    else
        log_error "Full database dump failed"
        return 1
    fi
    
    # Compress if enabled
    if [[ "${COMPRESSION}" == "true" ]]; then
        log_info "Compressing backup..."
        gzip "${dump_file}"
        log_success "Backup compressed: ${dump_file}.gz"
    fi
    
    # Create metadata file
    create_backup_metadata "${backup_path}" "full"
    
    log_success "Full backup completed: ${backup_name}"
    return 0
}

# Create schema-only backup
create_schema_backup() {
    local backup_name="$1"
    local backup_path="${BACKUP_DIR}/${backup_name}"
    
    log_info "Creating schema-only backup: ${backup_name}"
    
    mkdir -p "${backup_path}"
    
    # Schema dump
    local schema_file="${backup_path}/schema.sql"
    log_info "Creating schema dump..."
    
    if PGPASSWORD="${DB_PASSWORD}" pg_dump -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" \
        --verbose --no-password --format=plain --schema-only --create --clean --if-exists \
        --exclude-schema=information_schema --exclude-schema=pg_catalog \
        > "${schema_file}" 2>> "${LOG_FILE}"; then
        log_success "Schema dump created: ${schema_file}"
    else
        log_error "Schema dump failed"
        return 1
    fi
    
    # Compress if enabled
    if [[ "${COMPRESSION}" == "true" ]]; then
        gzip "${schema_file}"
        log_success "Schema backup compressed: ${schema_file}.gz"
    fi
    
    # Create metadata file
    create_backup_metadata "${backup_path}" "schema"
    
    log_success "Schema backup completed: ${backup_name}"
    return 0
}

# Create data-only backup
create_data_backup() {
    local backup_name="$1"
    local backup_path="${BACKUP_DIR}/${backup_name}"
    
    log_info "Creating data-only backup: ${backup_name}"
    
    mkdir -p "${backup_path}"
    
    # Data dump
    local data_file="${backup_path}/data.sql"
    log_info "Creating data dump..."
    
    if PGPASSWORD="${DB_PASSWORD}" pg_dump -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" \
        --verbose --no-password --format=plain --data-only \
        --exclude-schema=information_schema --exclude-schema=pg_catalog \
        > "${data_file}" 2>> "${LOG_FILE}"; then
        log_success "Data dump created: ${data_file}"
    else
        log_error "Data dump failed"
        return 1
    fi
    
    # Compress if enabled
    if [[ "${COMPRESSION}" == "true" ]]; then
        gzip "${data_file}"
        log_success "Data backup compressed: ${data_file}.gz"
    fi
    
    # Create metadata file
    create_backup_metadata "${backup_path}" "data"
    
    log_success "Data backup completed: ${backup_name}"
    return 0
}

# Create TimescaleDB-specific backup
create_hypertables_backup() {
    local backup_name="$1"
    local backup_path="${BACKUP_DIR}/${backup_name}"
    
    log_info "Creating TimescaleDB hypertables backup: ${backup_name}"
    
    mkdir -p "${backup_path}"
    
    # Get list of hypertables
    local hypertables
    hypertables=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "
        SELECT hypertable_name FROM timescaledb_information.hypertables;
    " 2>/dev/null | tr -d ' ')
    
    if [[ -z "${hypertables}" ]]; then
        log_warn "No hypertables found for backup"
        return 0
    fi
    
    # Backup each hypertable
    local hypertable_file="${backup_path}/hypertables.sql"
    echo "-- TimescaleDB Hypertables Backup" > "${hypertable_file}"
    echo "-- Created: $(date)" >> "${hypertable_file}"
    echo "" >> "${hypertable_file}"
    
    for hypertable in ${hypertables}; do
        log_info "Backing up hypertable: ${hypertable}"
        
        # Get hypertable data
        PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c "
            COPY factory_telemetry.${hypertable} TO STDOUT WITH CSV HEADER;
        " >> "${hypertable_file}" 2>> "${LOG_FILE}"
        
        echo "" >> "${hypertable_file}"
    done
    
    # Compress if enabled
    if [[ "${COMPRESSION}" == "true" ]]; then
        gzip "${hypertable_file}"
        log_success "Hypertables backup compressed: ${hypertable_file}.gz"
    fi
    
    # Create metadata file
    create_backup_metadata "${backup_path}" "hypertables"
    
    log_success "Hypertables backup completed: ${backup_name}"
    return 0
}

# Create backup metadata
create_backup_metadata() {
    local backup_path="$1"
    local backup_type="$2"
    local metadata_file="${backup_path}/metadata.json"
    
    local db_info
    db_info=$(get_database_info)
    local db_size=$(echo "${db_info}" | cut -d'|' -f1)
    local table_count=$(echo "${db_info}" | cut -d'|' -f2)
    local hypertable_count=$(echo "${db_info}" | cut -d'|' -f3)
    
    cat > "${metadata_file}" << EOF
{
    "backup_name": "$(basename "${backup_path}")",
    "backup_type": "${backup_type}",
    "environment": "${ENVIRONMENT}",
    "database": {
        "host": "${DB_HOST}",
        "port": "${DB_PORT}",
        "name": "${DB_NAME}",
        "user": "${DB_USER}"
    },
    "backup_info": {
        "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
        "created_by": "$(whoami)",
        "database_size": "${db_size}",
        "table_count": "${table_count}",
        "hypertable_count": "${hypertable_count}"
    },
    "files": [
EOF
    
    # List backup files
    local files=()
    for file in "${backup_path}"/*.sql*; do
        if [[ -f "${file}" ]]; then
            files+=("\"$(basename "${file}")\"")
        fi
    done
    
    if [[ ${#files[@]} -gt 0 ]]; then
        printf '%s\n' "${files[@]}" | sed 's/^/        /' | sed '$!s/$/,/' >> "${metadata_file}"
    fi
    
    cat >> "${metadata_file}" << EOF
    ],
    "checksums": {
EOF
    
    # Calculate checksums
    for file in "${backup_path}"/*.sql*; do
        if [[ -f "${file}" ]]; then
            local checksum
            checksum=$(sha256sum "${file}" | cut -d' ' -f1)
            echo "        \"$(basename "${file}")\": \"${checksum}\"," >> "${metadata_file}"
        fi
    done
    
    # Remove trailing comma
    sed -i '$ s/,$//' "${metadata_file}"
    
    cat >> "${metadata_file}" << EOF
    }
}
EOF
    
    log_debug "Backup metadata created: ${metadata_file}"
}

#==============================================================================
# Backup Restoration Functions
#==============================================================================

# Restore from backup
restore_backup() {
    local backup_name="$1"
    local backup_path="${BACKUP_DIR}/${backup_name}"
    local force="${2:-false}"
    
    log_info "Restoring from backup: ${backup_name}"
    
    if [[ ! -d "${backup_path}" ]]; then
        log_error "Backup directory not found: ${backup_path}"
        return 1
    fi
    
    # Verify backup integrity
    if ! verify_backup_integrity "${backup_name}"; then
        log_error "Backup integrity verification failed"
        return 1
    fi
    
    # Check if database exists and has data
    local table_count
    table_count=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "
        SELECT COUNT(*) FROM information_schema.tables 
        WHERE table_schema = 'factory_telemetry';
    " 2>/dev/null | tr -d ' ')
    
    if [[ ${table_count} -gt 0 ]] && [[ "${force}" != "true" ]]; then
        log_error "Database contains data. Use --force to overwrite."
        return 1
    fi
    
    # Find backup file
    local backup_file
    if [[ -f "${backup_path}/full_database.sql.gz" ]]; then
        backup_file="${backup_path}/full_database.sql.gz"
    elif [[ -f "${backup_path}/full_database.sql" ]]; then
        backup_file="${backup_path}/full_database.sql"
    else
        log_error "No full database backup found in ${backup_path}"
        return 1
    fi
    
    # Restore database
    log_info "Restoring database from: ${backup_file}"
    
    if [[ "${backup_file}" == *.gz ]]; then
        if gunzip -c "${backup_file}" | PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" >> "${LOG_FILE}" 2>&1; then
            log_success "Database restored successfully"
        else
            log_error "Database restoration failed"
            return 1
        fi
    else
        if PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -f "${backup_file}" >> "${LOG_FILE}" 2>&1; then
            log_success "Database restored successfully"
        else
            log_error "Database restoration failed"
            return 1
        fi
    fi
    
    # Verify restoration
    verify_restoration || return 1
    
    log_success "Backup restoration completed: ${backup_name}"
    return 0
}

# Verify restoration
verify_restoration() {
    log_info "Verifying restoration..."
    
    # Check if TimescaleDB extension exists
    local extension_check
    extension_check=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "
        SELECT 1 FROM pg_extension WHERE extname = 'timescaledb';
    " 2>/dev/null || echo "")
    
    if [[ "${extension_check}" != "1" ]]; then
        log_error "TimescaleDB extension not found after restoration"
        return 1
    fi
    
    # Check if hypertables exist
    local hypertable_count
    hypertable_count=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "
        SELECT COUNT(*) FROM timescaledb_information.hypertables;
    " 2>/dev/null | tr -d ' ')
    
    if [[ ${hypertable_count} -eq 0 ]]; then
        log_warn "No hypertables found after restoration"
    else
        log_success "Found ${hypertable_count} hypertables after restoration"
    fi
    
    log_success "Restoration verification completed"
    return 0
}

#==============================================================================
# Rollback Functions
#==============================================================================

# Create rollback point
create_rollback_point() {
    local rollback_name="$1"
    local rollback_path="${ROLLBACK_DIR}/${rollback_name}"
    
    log_info "Creating rollback point: ${rollback_name}"
    
    mkdir -p "${rollback_path}"
    
    # Create pre-migration backup
    local backup_name="rollback_${rollback_name}_$(date +%Y%m%d_%H%M%S)"
    create_full_backup "${backup_name}" || return 1
    
    # Create rollback script
    create_rollback_script "${rollback_path}" "${backup_name}"
    
    log_success "Rollback point created: ${rollback_name}"
    return 0
}

# Create rollback script
create_rollback_script() {
    local rollback_path="$1"
    local backup_name="$2"
    local rollback_script="${rollback_path}/rollback.sh"
    
    cat > "${rollback_script}" << EOF
#!/bin/bash
#==============================================================================
# MS5.0 Rollback Script
#==============================================================================
# 
# Automated rollback script for ${ENVIRONMENT} environment
# Created: $(date)
# Backup: ${backup_name}
#
# Usage: ./rollback.sh [--force]
#==============================================================================

set -euo pipefail

# Configuration
ENVIRONMENT="${ENVIRONMENT}"
DB_HOST="${DB_HOST}"
DB_PORT="${DB_PORT}"
DB_NAME="${DB_NAME}"
DB_USER="${DB_USER}"
DB_PASSWORD="${DB_PASSWORD}"
BACKUP_NAME="${backup_name}"

# Logging
LOG_FILE="${rollback_path}/rollback_$(date +%Y%m%d_%H%M%S).log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] \$1" | tee -a "\${LOG_FILE}"
}

log_info() { log "INFO" "\$@"; }
log_error() { log "ERROR" "\$@"; }
log_success() { log "SUCCESS" "\$@"; }

# Main rollback function
main() {
    log_info "Starting rollback process"
    log_info "Environment: \${ENVIRONMENT}"
    log_info "Backup: \${BACKUP_NAME}"
    
    # Test database connection
    if ! PGPASSWORD="\${DB_PASSWORD}" psql -h "\${DB_HOST}" -p "\${DB_PORT}" -U "\${DB_USER}" -d "\${DB_NAME}" -c "SELECT 1;" >/dev/null 2>&1; then
        log_error "Database connection failed"
        exit 1
    fi
    
    # Restore from backup
    log_info "Restoring from backup: \${BACKUP_NAME}"
    
    local backup_file="${BACKUP_DIR}/\${BACKUP_NAME}/full_database.sql"
    if [[ -f "\${backup_file}.gz" ]]; then
        backup_file="\${backup_file}.gz"
    fi
    
    if [[ "\${backup_file}" == *.gz ]]; then
        gunzip -c "\${backup_file}" | PGPASSWORD="\${DB_PASSWORD}" psql -h "\${DB_HOST}" -p "\${DB_PORT}" -U "\${DB_USER}" -d "\${DB_NAME}"
    else
        PGPASSWORD="\${DB_PASSWORD}" psql -h "\${DB_HOST}" -p "\${DB_PORT}" -U "\${DB_USER}" -d "\${DB_NAME}" -f "\${backup_file}"
    fi
    
    log_success "Rollback completed successfully"
}

# Parse arguments
FORCE=false
while [[ \$# -gt 0 ]]; do
    case \$1 in
        --force)
            FORCE=true
            shift
            ;;
        *)
            echo "Unknown option: \$1"
            exit 1
            ;;
    esac
done

main "\$@"
EOF
    
    chmod +x "${rollback_script}"
    log_debug "Rollback script created: ${rollback_script}"
}

# Execute rollback
execute_rollback() {
    local rollback_name="$1"
    local rollback_path="${ROLLBACK_DIR}/${rollback_name}"
    local rollback_script="${rollback_path}/rollback.sh"
    
    if [[ ! -f "${rollback_script}" ]]; then
        log_error "Rollback script not found: ${rollback_script}"
        return 1
    fi
    
    log_info "Executing rollback: ${rollback_name}"
    
    if "${rollback_script}"; then
        log_success "Rollback executed successfully: ${rollback_name}"
    else
        log_error "Rollback execution failed: ${rollback_name}"
        return 1
    fi
    
    return 0
}

#==============================================================================
# Backup Management Functions
#==============================================================================

# List available backups
list_backups() {
    log_info "Listing available backups..."
    
    if [[ ! -d "${BACKUP_DIR}" ]]; then
        log_warn "Backup directory not found: ${BACKUP_DIR}"
        return 0
    fi
    
    echo "Available backups:"
    echo "=================="
    
    for backup_dir in "${BACKUP_DIR}"/*; do
        if [[ -d "${backup_dir}" ]]; then
            local backup_name=$(basename "${backup_dir}")
            local metadata_file="${backup_dir}/metadata.json"
            
            if [[ -f "${metadata_file}" ]]; then
                local created_at
                created_at=$(jq -r '.backup_info.created_at' "${metadata_file}" 2>/dev/null || echo "unknown")
                local backup_type
                backup_type=$(jq -r '.backup_type' "${metadata_file}" 2>/dev/null || echo "unknown")
                local db_size
                db_size=$(jq -r '.backup_info.database_size' "${metadata_file}" 2>/dev/null || echo "unknown")
                
                echo "  ${backup_name}"
                echo "    Type: ${backup_type}"
                echo "    Created: ${created_at}"
                echo "    Size: ${db_size}"
                echo ""
            else
                echo "  ${backup_name} (no metadata)"
            fi
        fi
    done
}

# Verify backup integrity
verify_backup_integrity() {
    local backup_name="$1"
    local backup_path="${BACKUP_DIR}/${backup_name}"
    local metadata_file="${backup_path}/metadata.json"
    
    log_info "Verifying backup integrity: ${backup_name}"
    
    if [[ ! -f "${metadata_file}" ]]; then
        log_error "Backup metadata not found: ${metadata_file}"
        return 1
    fi
    
    # Verify checksums
    local checksums_valid=true
    
    while IFS= read -r line; do
        local file_name=$(echo "${line}" | jq -r 'keys[0]' 2>/dev/null)
        local expected_checksum=$(echo "${line}" | jq -r '.[]' 2>/dev/null)
        
        if [[ -f "${backup_path}/${file_name}" ]]; then
            local actual_checksum
            actual_checksum=$(sha256sum "${backup_path}/${file_name}" | cut -d' ' -f1)
            
            if [[ "${actual_checksum}" != "${expected_checksum}" ]]; then
                log_error "Checksum mismatch for ${file_name}"
                checksums_valid=false
            fi
        else
            log_error "Backup file not found: ${file_name}"
            checksums_valid=false
        fi
    done < <(jq -c '.checksums | to_entries[]' "${metadata_file}" 2>/dev/null)
    
    if [[ "${checksums_valid}" == "true" ]]; then
        log_success "Backup integrity verified: ${backup_name}"
        return 0
    else
        log_error "Backup integrity verification failed: ${backup_name}"
        return 1
    fi
}

# Clean old backups
clean_old_backups() {
    local retention_days="${1:-30}"
    
    log_info "Cleaning backups older than ${retention_days} days..."
    
    if [[ ! -d "${BACKUP_DIR}" ]]; then
        log_warn "Backup directory not found: ${BACKUP_DIR}"
        return 0
    fi
    
    local cleaned_count=0
    
    for backup_dir in "${BACKUP_DIR}"/*; do
        if [[ -d "${backup_dir}" ]]; then
            local backup_age
            backup_age=$(find "${backup_dir}" -maxdepth 1 -type f -name "*.sql*" -printf '%T@\n' | head -1 | xargs -I {} date -d "@{}" +%s)
            local current_time
            current_time=$(date +%s)
            local age_days=$(( (current_time - backup_age) / 86400 ))
            
            if [[ ${age_days} -gt ${retention_days} ]]; then
                log_info "Removing old backup: $(basename "${backup_dir}") (${age_days} days old)"
                rm -rf "${backup_dir}"
                ((cleaned_count++))
            fi
        fi
    done
    
    log_success "Cleaned ${cleaned_count} old backups"
    return 0
}

#==============================================================================
# Main Command Functions
#==============================================================================

# Parse command line arguments
parse_arguments() {
    COMMAND="${1:-help}"
    shift || true
    
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
            --no-compression)
                COMPRESSION=false
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --retention-days=*)
                RETENTION_DAYS="${1#*=}"
                shift
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
MS5.0 Database Backup & Rollback Manager

USAGE:
    $0 <command> [options]

COMMANDS:
    backup <name> [type]     Create backup (full|schema|data|hypertables)
    restore <name>           Restore from backup
    rollback <name>          Execute rollback
    list                     List available backups
    verify <name>            Verify backup integrity
    clean [days]             Clean old backups (default: 30 days)

OPTIONS:
    --environment=ENV       Target environment (production|staging|development)
    --verbose               Enable detailed debug logging
    --no-compression        Disable backup compression
    --force                 Force operation (overwrite existing data)
    --retention-days=N      Backup retention period in days

EXAMPLES:
    $0 backup pre_migration full          # Create full backup before migration
    $0 backup post_migration schema      # Create schema backup after migration
    $0 restore pre_migration             # Restore from pre-migration backup
    $0 rollback migration_failure         # Execute rollback
    $0 list                               # List all available backups
    $0 verify pre_migration               # Verify backup integrity
    $0 clean 7                            # Clean backups older than 7 days

ENVIRONMENT VARIABLES:
    DB_HOST                Database host (default: localhost)
    DB_PORT                Database port (default: 5432/5433/5434)
    DB_NAME                Database name
    DB_USER                Database user
    POSTGRES_PASSWORD_*     Database password for environment

EOF
}

# Main execution function
main() {
    # Initialize logging
    init_logging
    
    # Test database connection
    test_db_connection || exit 1
    
    case "${COMMAND}" in
        backup)
            local backup_name="${1:-backup_$(date +%Y%m%d_%H%M%S)}"
            local backup_type="${2:-full}"
            
            case "${backup_type}" in
                full)
                    create_full_backup "${backup_name}"
                    ;;
                schema)
                    create_schema_backup "${backup_name}"
                    ;;
                data)
                    create_data_backup "${backup_name}"
                    ;;
                hypertables)
                    create_hypertables_backup "${backup_name}"
                    ;;
                *)
                    log_error "Invalid backup type: ${backup_type}"
                    log_error "Valid types: full, schema, data, hypertables"
                    exit 1
                    ;;
            esac
            ;;
        restore)
            local backup_name="${1:-}"
            if [[ -z "${backup_name}" ]]; then
                log_error "Backup name required for restore"
                exit 1
            fi
            restore_backup "${backup_name}" "${FORCE:-false}"
            ;;
        rollback)
            local rollback_name="${1:-}"
            if [[ -z "${rollback_name}" ]]; then
                log_error "Rollback name required"
                exit 1
            fi
            execute_rollback "${rollback_name}"
            ;;
        list)
            list_backups
            ;;
        verify)
            local backup_name="${1:-}"
            if [[ -z "${backup_name}" ]]; then
                log_error "Backup name required for verify"
                exit 1
            fi
            verify_backup_integrity "${backup_name}"
            ;;
        clean)
            local retention_days="${1:-30}"
            clean_old_backups "${retention_days}"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: ${COMMAND}"
            show_help
            exit 1
            ;;
    esac
}

#==============================================================================
# Script Entry Point
#==============================================================================

# Parse arguments and execute main function
parse_arguments "$@"
main "$@"
