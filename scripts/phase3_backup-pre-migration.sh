#!/bin/bash

# ============================================================================
# MS5.0 Phase 3: Pre-Migration Backup Script
# ============================================================================
# This script creates comprehensive backups before executing database migrations
# Designed for starship-grade reliability and fault tolerance
# ============================================================================

set -euo pipefail

# ============================================================================
# CONFIGURATION - Starship-grade precision
# ============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly BACKUP_ROOT="/opt/ms5-backend/backups"
readonly TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
readonly BACKUP_DIR="${BACKUP_ROOT}/pre-migration-${TIMESTAMP}"

# Database connection parameters
readonly DB_HOST="${DB_HOST:-localhost}"
readonly DB_PORT="${DB_PORT:-5432}"
readonly DB_NAME="${DB_NAME:-factory_telemetry}"
readonly DB_USER="${DB_USER:-ms5_user_production}"
readonly DB_PASSWORD="${POSTGRES_PASSWORD_PRODUCTION}"

# Docker container names
readonly POSTGRES_CONTAINER="ms5_postgres_production"
readonly POSTGRES_VOLUME="ms5-backend_postgres_data_production"

# Backup retention settings
readonly BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"

# ============================================================================
# LOGGING SYSTEM - NASA-grade precision
# ============================================================================

# Color codes for terminal output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions with timestamps and levels
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS:${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

# ============================================================================
# VALIDATION FUNCTIONS - Starship-grade safety checks
# ============================================================================

validate_environment() {
    log "Validating environment for backup operation..."
    
    # Check if running as root or with appropriate permissions
    if [[ $EUID -eq 0 ]]; then
        log_warning "Running as root - ensure this is intentional"
    fi
    
    # Check disk space (require 20GB free space)
    local disk_space_kb
    disk_space_kb=$(df "$BACKUP_ROOT" 2>/dev/null | awk 'NR==2 {print $4}' || echo "0")
    local disk_space_gb=$((disk_space_kb / 1024 / 1024))
    
    if [[ $disk_space_kb -lt 20971520 ]]; then  # 20GB in KB
        log_error "Insufficient disk space. Required: 20GB, Available: ${disk_space_gb}GB"
        log_error "Backup directory: $BACKUP_ROOT"
        exit 1
    fi
    
    log_success "Disk space validation passed: ${disk_space_gb}GB available"
    
    # Check if PostgreSQL container is running
    if ! docker ps --format "table {{.Names}}" | grep -q "^${POSTGRES_CONTAINER}$"; then
        log_error "PostgreSQL container '${POSTGRES_CONTAINER}' is not running"
        log_error "Please start the database container before running backup"
        exit 1
    fi
    
    log_success "PostgreSQL container validation passed"
    
    # Check database connectivity
    if ! docker exec "$POSTGRES_CONTAINER" pg_isready -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1; then
        log_error "Database connectivity test failed"
        log_error "Container: $POSTGRES_CONTAINER, User: $DB_USER, Database: $DB_NAME"
        exit 1
    fi
    
    log_success "Database connectivity validation passed"
}

# ============================================================================
# BACKUP FUNCTIONS - Starship-grade reliability
# ============================================================================

create_backup_directory() {
    log "Creating backup directory structure..."
    
    if [[ -d "$BACKUP_DIR" ]]; then
        log_warning "Backup directory already exists: $BACKUP_DIR"
        rm -rf "$BACKUP_DIR"
    fi
    
    mkdir -p "$BACKUP_DIR"/{sql,volumes,metadata}
    
    if [[ ! -d "$BACKUP_DIR" ]]; then
        log_error "Failed to create backup directory: $BACKUP_DIR"
        exit 1
    fi
    
    log_success "Backup directory created: $BACKUP_DIR"
}

backup_database_full() {
    log "Creating full database backup..."
    
    local backup_file="$BACKUP_DIR/sql/full_backup.sql"
    local start_time
    start_time=$(date +%s)
    
    # Create full database dump with comprehensive options
    if ! docker exec "$POSTGRES_CONTAINER" pg_dump \
        --verbose \
        --host=localhost \
        --port=5432 \
        --username="$DB_USER" \
        --dbname="$DB_NAME" \
        --no-password \
        --format=plain \
        --encoding=UTF8 \
        --clean \
        --create \
        --if-exists \
        --verbose \
        > "$backup_file" 2>"$BACKUP_DIR/sql/full_backup.log"; then
        
        log_error "Full database backup failed"
        log_error "Check log file: $BACKUP_DIR/sql/full_backup.log"
        exit 1
    fi
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local file_size
    file_size=$(du -h "$backup_file" | cut -f1)
    
    log_success "Full database backup completed in ${duration}s (${file_size})"
}

backup_database_schema() {
    log "Creating schema-only backup..."
    
    local backup_file="$BACKUP_DIR/sql/schema_only.sql"
    local start_time
    start_time=$(date +%s)
    
    # Create schema-only dump
    if ! docker exec "$POSTGRES_CONTAINER" pg_dump \
        --verbose \
        --host=localhost \
        --port=5432 \
        --username="$DB_USER" \
        --dbname="$DB_NAME" \
        --no-password \
        --format=plain \
        --schema-only \
        --encoding=UTF8 \
        --clean \
        --create \
        --if-exists \
        --verbose \
        > "$backup_file" 2>"$BACKUP_DIR/sql/schema_backup.log"; then
        
        log_error "Schema-only backup failed"
        log_error "Check log file: $BACKUP_DIR/sql/schema_backup.log"
        exit 1
    fi
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local file_size
    file_size=$(du -h "$backup_file" | cut -f1)
    
    log_success "Schema-only backup completed in ${duration}s (${file_size})"
}

backup_database_data() {
    log "Creating data-only backup..."
    
    local backup_file="$BACKUP_DIR/sql/data_only.sql"
    local start_time
    start_time=$(date +%s)
    
    # Create data-only dump
    if ! docker exec "$POSTGRES_CONTAINER" pg_dump \
        --verbose \
        --host=localhost \
        --port=5432 \
        --username="$DB_USER" \
        --dbname="$DB_NAME" \
        --no-password \
        --format=plain \
        --data-only \
        --encoding=UTF8 \
        --verbose \
        > "$backup_file" 2>"$BACKUP_DIR/sql/data_backup.log"; then
        
        log_error "Data-only backup failed"
        log_error "Check log file: $BACKUP_DIR/sql/data_backup.log"
        exit 1
    fi
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local file_size
    file_size=$(du -h "$backup_file" | cut -f1)
    
    log_success "Data-only backup completed in ${duration}s (${file_size})"
}

backup_docker_volumes() {
    log "Creating Docker volume backup..."
    
    local volume_backup="$BACKUP_DIR/volumes/postgres_data.tar.gz"
    local start_time
    start_time=$(date +%s)
    
    # Check if volume exists
    if ! docker volume inspect "$POSTGRES_VOLUME" >/dev/null 2>&1; then
        log_warning "PostgreSQL volume '$POSTGRES_VOLUME' not found - skipping volume backup"
        return 0
    fi
    
    # Create volume backup using temporary container
    if ! docker run --rm \
        --volume "$POSTGRES_VOLUME":/data:ro \
        --volume "$BACKUP_DIR/volumes":/backup \
        alpine:latest \
        tar czf /backup/postgres_data.tar.gz -C /data . 2>"$BACKUP_DIR/volumes/volume_backup.log"; then
        
        log_error "Docker volume backup failed"
        log_error "Check log file: $BACKUP_DIR/volumes/volume_backup.log"
        exit 1
    fi
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local file_size
    file_size=$(du -h "$volume_backup" | cut -f1)
    
    log_success "Docker volume backup completed in ${duration}s (${file_size})"
}

backup_metadata() {
    log "Creating metadata backup..."
    
    local metadata_file="$BACKUP_DIR/metadata/backup_metadata.json"
    
    # Collect system metadata
    cat > "$metadata_file" << EOF
{
    "backup_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "backup_version": "1.0.0",
    "database_info": {
        "host": "$DB_HOST",
        "port": "$DB_PORT",
        "database": "$DB_NAME",
        "user": "$DB_USER",
        "container": "$POSTGRES_CONTAINER"
    },
    "system_info": {
        "hostname": "$(hostname)",
        "os": "$(uname -s)",
        "kernel": "$(uname -r)",
        "architecture": "$(uname -m)",
        "docker_version": "$(docker --version 2>/dev/null || echo 'N/A')"
    },
    "backup_files": {
        "full_backup": "sql/full_backup.sql",
        "schema_backup": "sql/schema_only.sql",
        "data_backup": "sql/data_only.sql",
        "volume_backup": "volumes/postgres_data.tar.gz"
    },
    "validation": {
        "environment_validated": true,
        "disk_space_checked": true,
        "database_connectivity_verified": true
    }
}
EOF
    
    log_success "Metadata backup created: $metadata_file"
}

# ============================================================================
# VERIFICATION FUNCTIONS - Starship-grade validation
# ============================================================================

verify_backup_integrity() {
    log "Verifying backup integrity..."
    
    local verification_failed=false
    
    # Verify full backup
    if [[ ! -f "$BACKUP_DIR/sql/full_backup.sql" ]] || [[ ! -s "$BACKUP_DIR/sql/full_backup.sql" ]]; then
        log_error "Full backup file is missing or empty"
        verification_failed=true
    fi
    
    # Verify schema backup
    if [[ ! -f "$BACKUP_DIR/sql/schema_only.sql" ]] || [[ ! -s "$BACKUP_DIR/sql/schema_only.sql" ]]; then
        log_error "Schema backup file is missing or empty"
        verification_failed=true
    fi
    
    # Verify data backup
    if [[ ! -f "$BACKUP_DIR/sql/data_only.sql" ]] || [[ ! -s "$BACKUP_DIR/sql/data_only.sql" ]]; then
        log_error "Data backup file is missing or empty"
        verification_failed=true
    fi
    
    # Verify volume backup (if it exists)
    if [[ -f "$BACKUP_DIR/volumes/postgres_data.tar.gz" ]]; then
        if ! tar -tzf "$BACKUP_DIR/volumes/postgres_data.tar.gz" >/dev/null 2>&1; then
            log_error "Volume backup file is corrupted"
            verification_failed=true
        fi
    fi
    
    # Verify metadata
    if [[ ! -f "$BACKUP_DIR/metadata/backup_metadata.json" ]] || [[ ! -s "$BACKUP_DIR/metadata/backup_metadata.json" ]]; then
        log_error "Metadata file is missing or empty"
        verification_failed=true
    fi
    
    if [[ "$verification_failed" == true ]]; then
        log_error "Backup integrity verification failed"
        exit 1
    fi
    
    log_success "Backup integrity verification passed"
}

# ============================================================================
# CLEANUP FUNCTIONS - Starship-grade maintenance
# ============================================================================

cleanup_old_backups() {
    log "Cleaning up old backups (retention: ${BACKUP_RETENTION_DAYS} days)..."
    
    if [[ ! -d "$BACKUP_ROOT" ]]; then
        log_warning "Backup root directory does not exist: $BACKUP_ROOT"
        return 0
    fi
    
    local deleted_count=0
    
    # Find and delete old backup directories
    while IFS= read -r -d '' backup_dir; do
        if [[ -d "$backup_dir" ]]; then
            log "Deleting old backup: $(basename "$backup_dir")"
            rm -rf "$backup_dir"
            ((deleted_count++))
        fi
    done < <(find "$BACKUP_ROOT" -maxdepth 1 -type d -name "pre-migration-*" -mtime +"$BACKUP_RETENTION_DAYS" -print0)
    
    log_success "Cleaned up $deleted_count old backup(s)"
}

# ============================================================================
# MAIN EXECUTION - Starship-grade orchestration
# ============================================================================

main() {
    log "============================================================================"
    log "MS5.0 PHASE 3: PRE-MIGRATION BACKUP"
    log "============================================================================"
    log "Starting comprehensive backup operation..."
    log "Backup directory: $BACKUP_DIR"
    log "Database: $DB_NAME@$DB_HOST:$DB_PORT"
    log "Container: $POSTGRES_CONTAINER"
    log "============================================================================"
    
    # Execute backup sequence with error handling
    local start_time
    start_time=$(date +%s)
    
    validate_environment
    create_backup_directory
    backup_database_full
    backup_database_schema
    backup_database_data
    backup_docker_volumes
    backup_metadata
    verify_backup_integrity
    cleanup_old_backups
    
    local end_time
    end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    
    # Create backup summary
    local summary_file="$BACKUP_DIR/BACKUP_SUMMARY.txt"
    cat > "$summary_file" << EOF
============================================================================
MS5.0 PRE-MIGRATION BACKUP SUMMARY
============================================================================
Backup Timestamp: $(date)
Backup Duration: ${total_duration} seconds
Backup Directory: $BACKUP_DIR

Database Information:
- Host: $DB_HOST:$DB_PORT
- Database: $DB_NAME
- User: $DB_USER
- Container: $POSTGRES_CONTAINER

Backup Files Created:
$(find "$BACKUP_DIR" -type f -exec ls -lh {} \; | sed 's/^/- /')

Backup Verification:
- Full backup: $([ -f "$BACKUP_DIR/sql/full_backup.sql" ] && echo "✓ PASS" || echo "✗ FAIL")
- Schema backup: $([ -f "$BACKUP_DIR/sql/schema_only.sql" ] && echo "✓ PASS" || echo "✗ FAIL")
- Data backup: $([ -f "$BACKUP_DIR/sql/data_only.sql" ] && echo "✓ PASS" || echo "✗ FAIL")
- Volume backup: $([ -f "$BACKUP_DIR/volumes/postgres_data.tar.gz" ] && echo "✓ PASS" || echo "✗ FAIL")
- Metadata: $([ -f "$BACKUP_DIR/metadata/backup_metadata.json" ] && echo "✓ PASS" || echo "✗ FAIL")

Total Backup Size: $(du -sh "$BACKUP_DIR" | cut -f1)

Status: BACKUP COMPLETED SUCCESSFULLY
============================================================================
EOF
    
    log_success "============================================================================"
    log_success "PRE-MIGRATION BACKUP COMPLETED SUCCESSFULLY"
    log_success "============================================================================"
    log_success "Backup directory: $BACKUP_DIR"
    log_success "Total duration: ${total_duration} seconds"
    log_success "Total size: $(du -sh "$BACKUP_DIR" | cut -f1)"
    log_success "Summary file: $summary_file"
    log_success "============================================================================"
    
    # Export backup directory path for use by other scripts
    echo "$BACKUP_DIR" > "$BACKUP_ROOT/latest_backup_path"
    
    return 0
}

# ============================================================================
# ERROR HANDLING - Starship-grade fault tolerance
# ============================================================================

# Trap errors and provide detailed information
trap 'log_error "Backup failed at line $LINENO. Check logs for details."; exit 1' ERR

# Handle script interruption
trap 'log_warning "Backup interrupted by user"; exit 130' INT TERM

# ============================================================================
# SCRIPT EXECUTION
# ============================================================================

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
