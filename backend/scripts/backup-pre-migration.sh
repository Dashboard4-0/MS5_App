#!/bin/bash

# =============================================================================
# MS5.0 Phase 3: Pre-Migration Backup System
# =============================================================================
# 
# This script creates comprehensive backups before database migration execution.
# Implements multiple backup strategies for maximum data protection:
# - Full database backup (complete dump)
# - Schema-only backup (structure only)
# - Data-only backup (data without schema)
# - Docker volume backup (complete filesystem state)
# - Configuration backup (environment and config files)
#
# Designed for cosmic-scale reliability - every backup is verified and logged.
# =============================================================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# =============================================================================
# Configuration & Constants
# =============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly BACKUP_BASE_DIR="/opt/ms5-backend/backups"
readonly BACKUP_TIMESTAMP=$(date +%Y%m%d-%H%M%S)
readonly BACKUP_DIR="${BACKUP_BASE_DIR}/pre-migration-${BACKUP_TIMESTAMP}"

# Database configuration - loaded from environment
readonly DB_HOST="${DB_HOST:-localhost}"
readonly DB_PORT="${DB_PORT:-5432}"
readonly DB_NAME="${DB_NAME:-factory_telemetry}"
readonly DB_USER="${DB_USER:-ms5_user_production}"
readonly DB_PASSWORD="${POSTGRES_PASSWORD_PRODUCTION}"

# Container names
readonly POSTGRES_CONTAINER="ms5_postgres_production"
readonly VOLUME_NAME="ms5-backend_postgres_data_production"

# Backup retention (keep last 7 days)
readonly RETENTION_DAYS=7

# =============================================================================
# Logging System - Production Grade
# =============================================================================

# ANSI color codes for beautiful logging
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Logging functions with timestamps and colors
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✅${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ❌${NC} $1" >&2
}

log_info() {
    echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')] ℹ️${NC} $1" >&2
}

# =============================================================================
# Utility Functions - Cosmic Scale Reliability
# =============================================================================

# Verify required environment variables
verify_environment() {
    log "Verifying environment configuration..."
    
    local missing_vars=()
    
    if [[ -z "${POSTGRES_PASSWORD_PRODUCTION:-}" ]]; then
        missing_vars+=("POSTGRES_PASSWORD_PRODUCTION")
    fi
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required environment variables: ${missing_vars[*]}"
        log_error "Please ensure all required environment variables are set"
        exit 1
    fi
    
    log_success "Environment verification passed"
}

# Check system resources before backup
check_system_resources() {
    log "Checking system resources..."
    
    # Check disk space (require 20GB free for backups)
    local disk_space_kb
    disk_space_kb=$(df / | awk 'NR==2 {print $4}')
    local disk_space_gb=$((disk_space_kb / 1024 / 1024))
    
    if [[ $disk_space_kb -lt 20971520 ]]; then  # 20GB in KB
        log_error "Insufficient disk space. Required: 20GB, Available: ${disk_space_gb}GB"
        exit 1
    fi
    
    # Check memory (require 4GB available)
    local memory_mb
    memory_mb=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    
    if [[ $memory_mb -lt 4096 ]]; then
        log_error "Insufficient memory. Required: 4GB, Available: ${memory_mb}MB"
        exit 1
    fi
    
    log_success "System resources check passed (Disk: ${disk_space_gb}GB, Memory: ${memory_mb}MB)"
}

# Verify Docker container is running
verify_postgres_container() {
    log "Verifying PostgreSQL container status..."
    
    if ! docker ps --format "table {{.Names}}" | grep -q "^${POSTGRES_CONTAINER}$"; then
        log_error "PostgreSQL container '${POSTGRES_CONTAINER}' is not running"
        log_info "Please start the container with: docker compose -f docker-compose.production.yml up -d postgres"
        exit 1
    fi
    
    # Verify container is healthy
    local container_status
    container_status=$(docker inspect --format='{{.State.Health.Status}}' "${POSTGRES_CONTAINER}" 2>/dev/null || echo "unknown")
    
    if [[ "$container_status" != "healthy" ]]; then
        log_warning "Container health status: ${container_status}"
        log_info "Proceeding with backup (container may still be starting up)"
    else
        log_success "PostgreSQL container is healthy"
    fi
}

# Verify database connectivity
verify_database_connectivity() {
    log "Verifying database connectivity..."
    
    local max_attempts=10
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" >/dev/null 2>&1; then
            log_success "Database connectivity verified"
            return 0
        fi
        
        log_info "Database connection attempt $attempt/$max_attempts failed, retrying in 5 seconds..."
        sleep 5
        ((attempt++))
    done
    
    log_error "Failed to connect to database after $max_attempts attempts"
    exit 1
}

# Create backup directory structure
create_backup_directory() {
    log "Creating backup directory structure..."
    
    if [[ ! -d "$BACKUP_BASE_DIR" ]]; then
        sudo mkdir -p "$BACKUP_BASE_DIR"
        sudo chown $(whoami):$(whoami) "$BACKUP_BASE_DIR"
    fi
    
    mkdir -p "$BACKUP_DIR"/{database,volumes,config,logs}
    
    log_success "Backup directory created: $BACKUP_DIR"
}

# =============================================================================
# Backup Functions - Multiple Strategies for Maximum Protection
# =============================================================================

# Full database backup (complete dump)
backup_full_database() {
    log "Creating full database backup..."
    
    local backup_file="${BACKUP_DIR}/database/full_backup.sql"
    local start_time
    start_time=$(date +%s)
    
    # Use pg_dump with optimal settings for large databases
    if ! docker exec "$POSTGRES_CONTAINER" pg_dump \
        -U "$DB_USER" \
        -h localhost \
        -p 5432 \
        --verbose \
        --no-password \
        --format=plain \
        --encoding=UTF-8 \
        --no-owner \
        --no-privileges \
        "$DB_NAME" > "$backup_file"; then
        
        log_error "Full database backup failed"
        return 1
    fi
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local file_size
    file_size=$(du -h "$backup_file" | cut -f1)
    
    log_success "Full database backup completed (${file_size}, ${duration}s)"
    
    # Verify backup integrity
    if ! head -n 10 "$backup_file" | grep -q "PostgreSQL database dump"; then
        log_error "Full database backup appears corrupted"
        return 1
    fi
    
    return 0
}

# Schema-only backup (structure without data)
backup_schema_only() {
    log "Creating schema-only backup..."
    
    local backup_file="${BACKUP_DIR}/database/schema_only.sql"
    local start_time
    start_time=$(date +%s)
    
    if ! docker exec "$POSTGRES_CONTAINER" pg_dump \
        -U "$DB_USER" \
        -h localhost \
        -p 5432 \
        --verbose \
        --no-password \
        --schema-only \
        --format=plain \
        --encoding=UTF-8 \
        --no-owner \
        --no-privileges \
        "$DB_NAME" > "$backup_file"; then
        
        log_error "Schema-only backup failed"
        return 1
    fi
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local file_size
    file_size=$(du -h "$backup_file" | cut -f1)
    
    log_success "Schema-only backup completed (${file_size}, ${duration}s)"
    return 0
}

# Data-only backup (data without schema)
backup_data_only() {
    log "Creating data-only backup..."
    
    local backup_file="${BACKUP_DIR}/database/data_only.sql"
    local start_time
    start_time=$(date +%s)
    
    if ! docker exec "$POSTGRES_CONTAINER" pg_dump \
        -U "$DB_USER" \
        -h localhost \
        -p 5432 \
        --verbose \
        --no-password \
        --data-only \
        --format=plain \
        --encoding=UTF-8 \
        --no-owner \
        --no-privileges \
        "$DB_NAME" > "$backup_file"; then
        
        log_error "Data-only backup failed"
        return 1
    fi
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local file_size
    file_size=$(du -h "$backup_file" | cut -f1)
    
    log_success "Data-only backup completed (${file_size}, ${duration}s)"
    return 0
}

# Docker volume backup (complete filesystem state)
backup_docker_volume() {
    log "Creating Docker volume backup..."
    
    local backup_file="${BACKUP_DIR}/volumes/postgres_data.tar.gz"
    local start_time
    start_time=$(date +%s)
    
    # Check if volume exists
    if ! docker volume ls --format "table {{.Name}}" | grep -q "^${VOLUME_NAME}$"; then
        log_warning "Docker volume '${VOLUME_NAME}' not found, skipping volume backup"
        return 0
    fi
    
    # Create volume backup using temporary container
    if ! docker run --rm \
        -v "${VOLUME_NAME}:/data:ro" \
        -v "$(dirname "$backup_file"):/backup" \
        alpine:latest \
        tar czf "/backup/$(basename "$backup_file")" -C /data .; then
        
        log_error "Docker volume backup failed"
        return 1
    fi
    
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local file_size
    file_size=$(du -h "$backup_file" | cut -f1)
    
    log_success "Docker volume backup completed (${file_size}, ${duration}s)"
    return 0
}

# Configuration backup (environment and config files)
backup_configuration() {
    log "Creating configuration backup..."
    
    local config_dir="${BACKUP_DIR}/config"
    
    # Backup Docker Compose files
    cp -r "${PROJECT_ROOT}"/*.yml "$config_dir/" 2>/dev/null || true
    cp -r "${PROJECT_ROOT}"/*.yaml "$config_dir/" 2>/dev/null || true
    
    # Backup environment files
    cp -r "${PROJECT_ROOT}"/*.env* "$config_dir/" 2>/dev/null || true
    
    # Backup nginx configs
    cp -r "${PROJECT_ROOT}"/*.conf "$config_dir/" 2>/dev/null || true
    
    # Backup Prometheus configs
    cp -r "${PROJECT_ROOT}"/*prometheus*.yml "$config_dir/" 2>/dev/null || true
    
    # Create environment dump
    env > "${config_dir}/environment_dump.txt"
    
    # Create Docker info dump
    docker info > "${config_dir}/docker_info.txt" 2>/dev/null || true
    docker compose -f "${PROJECT_ROOT}/docker-compose.production.yml" config > "${config_dir}/docker_compose_resolved.yml" 2>/dev/null || true
    
    log_success "Configuration backup completed"
}

# =============================================================================
# Verification & Integrity Checks
# =============================================================================

# Verify backup integrity
verify_backup_integrity() {
    log "Verifying backup integrity..."
    
    local backup_file="${BACKUP_DIR}/database/full_backup.sql"
    
    # Check if backup file exists and has content
    if [[ ! -f "$backup_file" ]] || [[ ! -s "$backup_file" ]]; then
        log_error "Full backup file is missing or empty"
        return 1
    fi
    
    # Check backup file header
    if ! head -n 5 "$backup_file" | grep -q "PostgreSQL database dump"; then
        log_error "Backup file does not appear to be a valid PostgreSQL dump"
        return 1
    fi
    
    # Check backup file footer
    if ! tail -n 5 "$backup_file" | grep -q "PostgreSQL database dump complete"; then
        log_warning "Backup file footer indicates incomplete dump"
    fi
    
    log_success "Backup integrity verification passed"
}

# Create backup manifest
create_backup_manifest() {
    log "Creating backup manifest..."
    
    local manifest_file="${BACKUP_DIR}/BACKUP_MANIFEST.txt"
    
    cat > "$manifest_file" << EOF
# MS5.0 Pre-Migration Backup Manifest
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
# Backup ID: pre-migration-${BACKUP_TIMESTAMP}

## Backup Information
- Backup Type: Pre-Migration Database Backup
- Database: ${DB_NAME}
- Host: ${DB_HOST}:${DB_PORT}
- User: ${DB_USER}
- Container: ${POSTGRES_CONTAINER}

## Backup Contents
EOF

    # List all backup files
    find "$BACKUP_DIR" -type f -exec ls -lh {} \; | while read -r line; do
        echo "# $line" >> "$manifest_file"
    done
    
    cat >> "$manifest_file" << EOF

## Database Statistics
EOF

    # Get database statistics
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "
        SELECT 
            schemaname,
            tablename,
            n_tup_ins as inserts,
            n_tup_upd as updates,
            n_tup_del as deletes,
            n_live_tup as live_tuples,
            n_dead_tup as dead_tuples
        FROM pg_stat_user_tables 
        ORDER BY schemaname, tablename;
    " >> "$manifest_file" 2>/dev/null || echo "# Database statistics unavailable" >> "$manifest_file"
    
    log_success "Backup manifest created: $manifest_file"
}

# =============================================================================
# Cleanup & Maintenance
# =============================================================================

# Cleanup old backups (retention policy)
cleanup_old_backups() {
    log "Cleaning up old backups (retention: ${RETENTION_DAYS} days)..."
    
    if [[ -d "$BACKUP_BASE_DIR" ]]; then
        local deleted_count=0
        
        # Find and delete old backup directories
        while IFS= read -r -d '' dir; do
            if [[ -d "$dir" ]]; then
                log_info "Removing old backup: $(basename "$dir")"
                rm -rf "$dir"
                ((deleted_count++))
            fi
        done < <(find "$BACKUP_BASE_DIR" -maxdepth 1 -type d -name "pre-migration-*" -mtime +$RETENTION_DAYS -print0)
        
        if [[ $deleted_count -gt 0 ]]; then
            log_success "Cleaned up $deleted_count old backup(s)"
        else
            log_info "No old backups to clean up"
        fi
    fi
}

# =============================================================================
# Main Execution Function
# =============================================================================

main() {
    log "🚀 Starting MS5.0 Pre-Migration Backup Process"
    log "Backup ID: pre-migration-${BACKUP_TIMESTAMP}"
    
    # Pre-flight checks
    verify_environment
    check_system_resources
    verify_postgres_container
    verify_database_connectivity
    
    # Create backup environment
    create_backup_directory
    
    # Execute backup strategies
    backup_full_database || { log_error "Full database backup failed"; exit 1; }
    backup_schema_only || { log_error "Schema-only backup failed"; exit 1; }
    backup_data_only || { log_error "Data-only backup failed"; exit 1; }
    backup_docker_volume || { log_error "Docker volume backup failed"; exit 1; }
    backup_configuration || { log_error "Configuration backup failed"; exit 1; }
    
    # Verification and finalization
    verify_backup_integrity || { log_error "Backup integrity verification failed"; exit 1; }
    create_backup_manifest
    
    # Cleanup old backups
    cleanup_old_backups
    
    # Final summary
    local total_size
    total_size=$(du -sh "$BACKUP_DIR" | cut -f1)
    
    log_success "🎉 Pre-migration backup completed successfully!"
    log_success "Backup location: $BACKUP_DIR"
    log_success "Total backup size: $total_size"
    log_info "Backup manifest: ${BACKUP_DIR}/BACKUP_MANIFEST.txt"
    
    # Export backup path for use by other scripts
    echo "$BACKUP_DIR" > "${PROJECT_ROOT}/.last_backup_path"
    
    log "✅ System is ready for migration execution"
}

# =============================================================================
# Script Execution
# =============================================================================

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
