#!/bin/bash

# MS5.0 Floor Dashboard - Restore Script
# This script restores the MS5.0 system from backups

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="${SCRIPT_DIR}/backups"
LOG_DIR="${SCRIPT_DIR}/logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${LOG_DIR}/restore_${TIMESTAMP}.log"

# Environment variables
DATABASE_URL=${DATABASE_URL}
BACKUP_ID=${BACKUP_ID}
RESTORE_TYPE=${RESTORE_TYPE:-full}  # full, database, files, config
ENCRYPTION_KEY=${ENCRYPTION_KEY}
DRY_RUN=${DRY_RUN:-false}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# Create directories
mkdir -p "$BACKUP_ROOT" "$LOG_DIR"

log "Starting MS5.0 system restore - Type: $RESTORE_TYPE"

# Validate required environment variables
if [ -z "$DATABASE_URL" ]; then
    log_error "DATABASE_URL environment variable is required"
    exit 1
fi

# Function to list available backups
list_backups() {
    log "Available backups:"
    
    echo "Database Backups:"
    find "$BACKUP_ROOT/database" -name "database_backup_*.sql.*" 2>/dev/null | sort -r | head -10 | while read -r backup; do
        local backup_id=$(basename "$backup" | sed 's/database_backup_\([0-9_]*\)\.sql.*/\1/')
        local size=$(du -h "$backup" | cut -f1)
        local date=$(stat -c %y "$backup" | cut -d' ' -f1)
        echo "  - ID: $backup_id, Size: $size, Date: $date"
    done
    
    echo "File Backups:"
    find "$BACKUP_ROOT/files" -name "files_backup_*.tar.*" 2>/dev/null | sort -r | head -10 | while read -r backup; do
        local backup_id=$(basename "$backup" | sed 's/files_backup_\([0-9_]*\)\.tar.*/\1/')
        local size=$(du -h "$backup" | cut -f1)
        local date=$(stat -c %y "$backup" | cut -d' ' -f1)
        echo "  - ID: $backup_id, Size: $size, Date: $date"
    done
    
    echo "Configuration Backups:"
    find "$BACKUP_ROOT/config" -name "config_backup_*.tar.*" 2>/dev/null | sort -r | head -10 | while read -r backup; do
        local backup_id=$(basename "$backup" | sed 's/config_backup_\([0-9_]*\)\.tar.*/\1/')
        local size=$(du -h "$backup" | cut -f1)
        local date=$(stat -c %y "$backup" | cut -d' ' -f1)
        echo "  - ID: $backup_id, Size: $size, Date: $date"
    done
}

# Function to find latest backup if no backup ID specified
find_latest_backup() {
    local backup_type="$1"
    local latest_backup=""
    
    case $backup_type in
        database)
            latest_backup=$(find "$BACKUP_ROOT/database" -name "database_backup_*.sql.*" 2>/dev/null | sort -r | head -1)
            ;;
        files)
            latest_backup=$(find "$BACKUP_ROOT/files" -name "files_backup_*.tar.*" 2>/dev/null | sort -r | head -1)
            ;;
        config)
            latest_backup=$(find "$BACKUP_ROOT/config" -name "config_backup_*.tar.*" 2>/dev/null | sort -r | head -1)
            ;;
    esac
    
    echo "$latest_backup"
}

# Function to find backup by ID
find_backup_by_id() {
    local backup_type="$1"
    local backup_id="$2"
    local backup_file=""
    
    case $backup_type in
        database)
            backup_file=$(find "$BACKUP_ROOT/database" -name "database_backup_${backup_id}.sql.*" 2>/dev/null | head -1)
            ;;
        files)
            backup_file=$(find "$BACKUP_ROOT/files" -name "files_backup_${backup_id}.tar.*" 2>/dev/null | head -1)
            ;;
        config)
            backup_file=$(find "$BACKUP_ROOT/config" -name "config_backup_${backup_id}.tar.*" 2>/dev/null | head -1)
            ;;
    esac
    
    echo "$backup_file"
}

# Function to decrypt backup if encrypted
decrypt_backup() {
    local encrypted_file="$1"
    local decrypted_file="$2"
    
    if [ -z "$ENCRYPTION_KEY" ]; then
        log_error "Encryption key is required for encrypted backups"
        return 1
    fi
    
    log "Decrypting backup: $encrypted_file"
    if openssl enc -aes-256-cbc -d -in "$encrypted_file" -out "$decrypted_file" -k "$ENCRYPTION_KEY"; then
        log_success "Backup decrypted: $decrypted_file"
        return 0
    else
        log_error "Failed to decrypt backup"
        return 1
    fi
}

# Function to decompress backup
decompress_backup() {
    local compressed_file="$1"
    local decompressed_file="$2"
    
    log "Decompressing backup: $compressed_file"
    
    if [[ "$compressed_file" == *.gz ]]; then
        if gunzip -c "$compressed_file" > "$decompressed_file"; then
            log_success "Backup decompressed: $decompressed_file"
            return 0
        fi
    elif [[ "$compressed_file" == *.bz2 ]]; then
        if bunzip2 -c "$compressed_file" > "$decompressed_file"; then
            log_success "Backup decompressed: $decompressed_file"
            return 0
        fi
    elif [[ "$compressed_file" == *.xz ]]; then
        if xz -dc "$compressed_file" > "$decompressed_file"; then
            log_success "Backup decompressed: $decompressed_file"
            return 0
        fi
    else
        log_error "Unknown compression format: $compressed_file"
        return 1
    fi
    
    log_error "Failed to decompress backup"
    return 1
}

# Function to restore database
restore_database() {
    log "Restoring database..."
    
    local backup_file
    if [ -n "$BACKUP_ID" ]; then
        backup_file=$(find_backup_by_id "database" "$BACKUP_ID")
    else
        backup_file=$(find_latest_backup "database")
    fi
    
    if [ -z "$backup_file" ]; then
        log_error "No database backup found"
        return 1
    fi
    
    log "Using database backup: $backup_file"
    
    # Create temporary file for processing
    local temp_file=$(mktemp)
    local final_file=$(mktemp)
    
    # Decrypt if necessary
    if [[ "$backup_file" == *.enc ]]; then
        if ! decrypt_backup "$backup_file" "$temp_file"; then
            rm -f "$temp_file" "$final_file"
            return 1
        fi
    else
        cp "$backup_file" "$temp_file"
    fi
    
    # Decompress if necessary
    if [[ "$temp_file" == *.gz ]] || [[ "$temp_file" == *.bz2 ]] || [[ "$temp_file" == *.xz ]]; then
        if ! decompress_backup "$temp_file" "$final_file"; then
            rm -f "$temp_file" "$final_file"
            return 1
        fi
    else
        mv "$temp_file" "$final_file"
    fi
    
    # Verify database connection
    if ! psql "$DATABASE_URL" -c "SELECT 1;" > /dev/null 2>&1; then
        log_error "Cannot connect to database. Please check DATABASE_URL"
        rm -f "$temp_file" "$final_file"
        return 1
    fi
    
    if [ "$DRY_RUN" = "true" ]; then
        log "DRY RUN: Would restore database from $final_file"
        rm -f "$temp_file" "$final_file"
        return 0
    fi
    
    # Create backup of current database before restore
    local current_backup="${BACKUP_ROOT}/database/pre_restore_backup_${TIMESTAMP}.sql"
    log "Creating backup of current database before restore..."
    if pg_dump "$DATABASE_URL" > "$current_backup"; then
        log_success "Current database backed up: $current_backup"
    else
        log_warning "Failed to backup current database"
    fi
    
    # Restore database
    log "Restoring database from backup..."
    if psql "$DATABASE_URL" -f "$final_file"; then
        log_success "Database restored successfully"
    else
        log_error "Failed to restore database"
        rm -f "$temp_file" "$final_file"
        return 1
    fi
    
    # Cleanup temporary files
    rm -f "$temp_file" "$final_file"
    
    # Verify restore
    log "Verifying database restore..."
    if psql "$DATABASE_URL" -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'factory_telemetry';" > /dev/null 2>&1; then
        log_success "Database restore verified"
    else
        log_error "Database restore verification failed"
        return 1
    fi
}

# Function to restore files
restore_files() {
    log "Restoring application files..."
    
    local backup_file
    if [ -n "$BACKUP_ID" ]; then
        backup_file=$(find_backup_by_id "files" "$BACKUP_ID")
    else
        backup_file=$(find_latest_backup "files")
    fi
    
    if [ -z "$backup_file" ]; then
        log_error "No files backup found"
        return 1
    fi
    
    log "Using files backup: $backup_file"
    
    # Create temporary file for processing
    local temp_file=$(mktemp)
    local final_file=$(mktemp)
    
    # Decrypt if necessary
    if [[ "$backup_file" == *.enc ]]; then
        if ! decrypt_backup "$backup_file" "$temp_file"; then
            rm -f "$temp_file" "$final_file"
            return 1
        fi
    else
        cp "$backup_file" "$temp_file"
    fi
    
    # Decompress if necessary
    if [[ "$temp_file" == *.gz ]] || [[ "$temp_file" == *.bz2 ]] || [[ "$temp_file" == *.xz ]]; then
        if ! decompress_backup "$temp_file" "$final_file"; then
            rm -f "$temp_file" "$final_file"
            return 1
        fi
    else
        mv "$temp_file" "$final_file"
    fi
    
    if [ "$DRY_RUN" = "true" ]; then
        log "DRY RUN: Would restore files from $final_file"
        log "DRY RUN: Would extract to current directory"
        rm -f "$temp_file" "$final_file"
        return 0
    fi
    
    # Create backup of current files
    local current_backup_dir="${BACKUP_ROOT}/files/pre_restore_${TIMESTAMP}"
    mkdir -p "$current_backup_dir"
    
    local backup_dirs=("logs" "reports" "uploads" "config" "static")
    for dir in "${backup_dirs[@]}"; do
        if [ -d "$dir" ]; then
            cp -r "$dir" "$current_backup_dir/"
            log "Backed up current $dir to $current_backup_dir"
        fi
    done
    
    # Extract files
    log "Extracting files from backup..."
    if tar -xf "$final_file"; then
        log_success "Files restored successfully"
    else
        log_error "Failed to restore files"
        rm -f "$temp_file" "$final_file"
        return 1
    fi
    
    # Cleanup temporary files
    rm -f "$temp_file" "$final_file"
    
    # Set proper permissions
    log "Setting file permissions..."
    chmod -R 755 logs reports uploads config static 2>/dev/null || true
    
    log_success "Files restore completed"
}

# Function to restore configuration
restore_config() {
    log "Restoring configuration files..."
    
    local backup_file
    if [ -n "$BACKUP_ID" ]; then
        backup_file=$(find_backup_by_id "config" "$BACKUP_ID")
    else
        backup_file=$(find_latest_backup "config")
    fi
    
    if [ -z "$backup_file" ]; then
        log_error "No configuration backup found"
        return 1
    fi
    
    log "Using configuration backup: $backup_file"
    
    # Create temporary file for processing
    local temp_file=$(mktemp)
    local final_file=$(mktemp)
    
    # Decrypt if necessary
    if [[ "$backup_file" == *.enc ]]; then
        if ! decrypt_backup "$backup_file" "$temp_file"; then
            rm -f "$temp_file" "$final_file"
            return 1
        fi
    else
        cp "$backup_file" "$temp_file"
    fi
    
    # Decompress if necessary
    if [[ "$temp_file" == *.gz ]] || [[ "$temp_file" == *.bz2 ]] || [[ "$temp_file" == *.xz ]]; then
        if ! decompress_backup "$temp_file" "$final_file"; then
            rm -f "$temp_file" "$final_file"
            return 1
        fi
    else
        mv "$temp_file" "$final_file"
    fi
    
    if [ "$DRY_RUN" = "true" ]; then
        log "DRY RUN: Would restore configuration from $final_file"
        log "DRY RUN: Would extract to current directory"
        rm -f "$temp_file" "$final_file"
        return 0
    fi
    
    # Create backup of current configuration
    local current_backup_dir="${BACKUP_ROOT}/config/pre_restore_${TIMESTAMP}"
    mkdir -p "$current_backup_dir"
    
    local config_files=(
        "docker-compose.yml" "docker-compose.production.yml" "docker-compose.staging.yml"
        "Dockerfile" "Dockerfile.production" "Dockerfile.staging"
        "nginx.conf" "nginx.production.conf" "nginx.staging.conf"
        "prometheus.yml" "prometheus.production.yml" "prometheus.staging.conf"
        "alert_rules.yml" "alertmanager.yml" "requirements.txt"
        "deploy_migrations.sh" "validate_database.sh" "backup.sh" "restore.sh"
    )
    
    for file in "${config_files[@]}"; do
        if [ -f "$file" ]; then
            cp "$file" "$current_backup_dir/"
        fi
    done
    
    # Extract configuration
    log "Extracting configuration from backup..."
    if tar -xf "$final_file"; then
        log_success "Configuration restored successfully"
    else
        log_error "Failed to restore configuration"
        rm -f "$temp_file" "$final_file"
        return 1
    fi
    
    # Cleanup temporary files
    rm -f "$temp_file" "$final_file"
    
    # Set proper permissions
    log "Setting configuration file permissions..."
    chmod 755 deploy_migrations.sh validate_database.sh backup.sh restore.sh 2>/dev/null || true
    chmod 644 *.yml *.conf requirements.txt 2>/dev/null || true
    
    log_success "Configuration restore completed"
}

# Function to generate restore report
generate_restore_report() {
    log "Generating restore report..."
    
    local report_file="${LOG_DIR}/restore_report_${TIMESTAMP}.md"
    
    cat > "$report_file" << EOF
# MS5.0 Floor Dashboard - Restore Report

**Restore Date:** $(date)
**Restore Type:** $RESTORE_TYPE
**Backup ID:** ${BACKUP_ID:-"Latest"}
**Dry Run:** $DRY_RUN

## Restore Summary

### Restored Components
EOF
    
    case $RESTORE_TYPE in
        full)
            echo "- Database" >> "$report_file"
            echo "- Application Files" >> "$report_file"
            echo "- Configuration Files" >> "$report_file"
            ;;
        database)
            echo "- Database" >> "$report_file"
            ;;
        files)
            echo "- Application Files" >> "$report_file"
            ;;
        config)
            echo "- Configuration Files" >> "$report_file"
            ;;
    esac
    
    cat >> "$report_file" << EOF

## Backup Information

- **Backup Location:** $BACKUP_ROOT
- **Log File:** $LOG_FILE
- **Report File:** $report_file

## Next Steps

1. Verify system functionality
2. Test application features
3. Monitor system performance
4. Update monitoring and alerting if needed

EOF
    
    log_success "Restore report generated: $report_file"
}

# Main restore function
main() {
    log "Starting MS5.0 system restore process..."
    
    # Change to script directory
    cd "$SCRIPT_DIR"
    
    local start_time=$(date +%s)
    local restore_success=true
    
    # List available backups if no backup ID specified and not dry run
    if [ -z "$BACKUP_ID" ] && [ "$DRY_RUN" = "false" ]; then
        list_backups
        echo ""
        log "Using latest backup for each component"
    fi
    
    # Perform restore based on type
    case $RESTORE_TYPE in
        full)
            restore_database || restore_success=false
            restore_files || restore_success=false
            restore_config || restore_success=false
            ;;
        database)
            restore_database || restore_success=false
            ;;
        files)
            restore_files || restore_success=false
            ;;
        config)
            restore_config || restore_success=false
            ;;
        *)
            log_error "Invalid restore type: $RESTORE_TYPE"
            exit 1
            ;;
    esac
    
    # Generate report
    generate_restore_report
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [ "$restore_success" = "true" ]; then
        log_success "Restore completed successfully in ${duration}s"
        log "Log file: $LOG_FILE"
        exit 0
    else
        log_error "Restore completed with errors in ${duration}s"
        exit 1
    fi
}

# Help function
show_help() {
    echo "MS5.0 Floor Dashboard - Restore Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -t, --type TYPE     Restore type (full, database, files, config) (default: full)"
    echo "  -i, --id ID         Backup ID to restore (default: latest)"
    echo "  -k, --key KEY       Encryption key for encrypted backups"
    echo "  -d, --dry-run       Perform a dry run without making changes"
    echo "  -l, --list          List available backups and exit"
    echo ""
    echo "Environment Variables:"
    echo "  DATABASE_URL        PostgreSQL connection string (required)"
    echo "  BACKUP_ID          Backup ID to restore (default: latest)"
    echo "  RESTORE_TYPE       Restore type (default: full)"
    echo "  ENCRYPTION_KEY     Encryption key for encrypted backups"
    echo "  DRY_RUN            Perform dry run (default: false)"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Restore latest full backup"
    echo "  $0 -t database -i 20240101_120000    # Restore specific database backup"
    echo "  $0 -t config --dry-run               # Dry run configuration restore"
    echo "  $0 -l                                # List available backups"
    echo "  DATABASE_URL=postgresql://... $0     # Restore with custom database"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -t|--type)
            RESTORE_TYPE="$2"
            shift 2
            ;;
        -i|--id)
            BACKUP_ID="$2"
            shift 2
            ;;
        -k|--key)
            ENCRYPTION_KEY="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN="true"
            shift
            ;;
        -l|--list)
            list_backups
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate restore type
if [[ ! "$RESTORE_TYPE" =~ ^(full|database|files|config)$ ]]; then
    log_error "Invalid restore type: $RESTORE_TYPE (must be 'full', 'database', 'files', or 'config')"
    exit 1
fi

# Run main function
main
