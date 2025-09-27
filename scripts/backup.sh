#!/bin/bash

# MS5.0 Floor Dashboard - Backup Script
# This script creates comprehensive backups of the MS5.0 system

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="${SCRIPT_DIR}/backups"
LOG_DIR="${SCRIPT_DIR}/logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${LOG_DIR}/backup_${TIMESTAMP}.log"

# Environment variables
DATABASE_URL=${DATABASE_URL}
BACKUP_TYPE=${BACKUP_TYPE:-full}  # full, incremental, database, files, config
RETENTION_DAYS=${RETENTION_DAYS:-30}
COMPRESSION=${COMPRESSION:-gzip}  # gzip, bzip2, xz
ENCRYPTION=${ENCRYPTION:-false}
ENCRYPTION_KEY=${ENCRYPTION_KEY}

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

log "Starting MS5.0 system backup - Type: $BACKUP_TYPE"

# Validate required environment variables
if [ -z "$DATABASE_URL" ]; then
    log_error "DATABASE_URL environment variable is required"
    exit 1
fi

# Function to get compression command
get_compression_cmd() {
    case $COMPRESSION in
        gzip)
            echo "gzip"
            ;;
        bzip2)
            echo "bzip2"
            ;;
        xz)
            echo "xz"
            ;;
        *)
            log_error "Unsupported compression type: $COMPRESSION"
            exit 1
            ;;
    esac
}

# Function to get file extension
get_compression_ext() {
    case $COMPRESSION in
        gzip)
            echo "gz"
            ;;
        bzip2)
            echo "bz2"
            ;;
        xz)
            echo "xz"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Function to create database backup
backup_database() {
    log "Creating database backup..."
    
    local db_backup_dir="${BACKUP_ROOT}/database"
    local backup_file="${db_backup_dir}/database_backup_${TIMESTAMP}.sql"
    local compressed_file="${backup_file}.$(get_compression_ext)"
    
    mkdir -p "$db_backup_dir"
    
    # Create database dump
    if pg_dump "$DATABASE_URL" > "$backup_file"; then
        log_success "Database dump created: $backup_file"
        
        # Compress backup
        local compression_cmd=$(get_compression_cmd)
        if $compression_cmd "$backup_file"; then
            log_success "Database backup compressed: $compressed_file"
            rm -f "$backup_file"
        else
            log_error "Failed to compress database backup"
            return 1
        fi
        
        # Encrypt if enabled
        if [ "$ENCRYPTION" = "true" ] && [ -n "$ENCRYPTION_KEY" ]; then
            local encrypted_file="${compressed_file}.enc"
            if openssl enc -aes-256-cbc -salt -in "$compressed_file" -out "$encrypted_file" -k "$ENCRYPTION_KEY"; then
                log_success "Database backup encrypted: $encrypted_file"
                rm -f "$compressed_file"
            else
                log_error "Failed to encrypt database backup"
                return 1
            fi
        fi
        
        # Store backup metadata
        local metadata_file="${db_backup_dir}/backup_metadata_${TIMESTAMP}.json"
        cat > "$metadata_file" << EOF
{
    "backup_id": "${TIMESTAMP}",
    "type": "database",
    "timestamp": "$(date -Iseconds)",
    "size": $(stat -c%s "${compressed_file:-$backup_file}"),
    "compression": "${COMPRESSION}",
    "encryption": ${ENCRYPTION},
    "database_url": "${DATABASE_URL%%@*}"
}
EOF
        log_success "Database backup metadata saved: $metadata_file"
        
    else
        log_error "Failed to create database backup"
        return 1
    fi
}

# Function to backup application files
backup_files() {
    log "Creating application files backup..."
    
    local files_backup_dir="${BACKUP_ROOT}/files"
    local backup_file="${files_backup_dir}/files_backup_${TIMESTAMP}.tar"
    local compressed_file="${backup_file}.$(get_compression_ext)"
    
    mkdir -p "$files_backup_dir"
    
    # Define directories to backup
    local backup_dirs=(
        "logs"
        "reports"
        "uploads"
        "config"
        "static"
    )
    
    # Create tar archive
    local tar_files=()
    for dir in "${backup_dirs[@]}"; do
        if [ -d "$dir" ]; then
            tar_files+=("$dir")
        else
            log_warning "Directory not found: $dir"
        fi
    done
    
    if [ ${#tar_files[@]} -gt 0 ]; then
        if tar -cf "$backup_file" "${tar_files[@]}"; then
            log_success "Files archive created: $backup_file"
            
            # Compress backup
            local compression_cmd=$(get_compression_cmd)
            if $compression_cmd "$backup_file"; then
                log_success "Files backup compressed: $compressed_file"
                rm -f "$backup_file"
            else
                log_error "Failed to compress files backup"
                return 1
            fi
            
            # Encrypt if enabled
            if [ "$ENCRYPTION" = "true" ] && [ -n "$ENCRYPTION_KEY" ]; then
                local encrypted_file="${compressed_file}.enc"
                if openssl enc -aes-256-cbc -salt -in "$compressed_file" -out "$encrypted_file" -k "$ENCRYPTION_KEY"; then
                    log_success "Files backup encrypted: $encrypted_file"
                    rm -f "$compressed_file"
                else
                    log_error "Failed to encrypt files backup"
                    return 1
                fi
            fi
            
            # Store backup metadata
            local metadata_file="${files_backup_dir}/backup_metadata_${TIMESTAMP}.json"
            cat > "$metadata_file" << EOF
{
    "backup_id": "${TIMESTAMP}",
    "type": "files",
    "timestamp": "$(date -Iseconds)",
    "size": $(stat -c%s "${compressed_file:-$backup_file}"),
    "compression": "${COMPRESSION}",
    "encryption": ${ENCRYPTION},
    "directories": [$(printf '"%s",' "${tar_files[@]}" | sed 's/,$//')]
}
EOF
            log_success "Files backup metadata saved: $metadata_file"
            
        else
            log_error "Failed to create files backup"
            return 1
        fi
    else
        log_warning "No directories found to backup"
    fi
}

# Function to backup configuration files
backup_config() {
    log "Creating configuration backup..."
    
    local config_backup_dir="${BACKUP_ROOT}/config"
    local backup_file="${config_backup_dir}/config_backup_${TIMESTAMP}.tar"
    local compressed_file="${backup_file}.$(get_compression_ext)"
    
    mkdir -p "$config_backup_dir"
    
    # Define configuration files to backup
    local config_files=(
        "docker-compose.yml"
        "docker-compose.production.yml"
        "docker-compose.staging.yml"
        "Dockerfile"
        "Dockerfile.production"
        "Dockerfile.staging"
        "nginx.conf"
        "nginx.production.conf"
        "nginx.staging.conf"
        "prometheus.yml"
        "prometheus.production.yml"
        "prometheus.staging.conf"
        "alert_rules.yml"
        "alertmanager.yml"
        "requirements.txt"
        "deploy_migrations.sh"
        "validate_database.sh"
        "backup.sh"
        "restore.sh"
    )
    
    # Create tar archive
    local tar_files=()
    for file in "${config_files[@]}"; do
        if [ -f "$file" ]; then
            tar_files+=("$file")
        else
            log_warning "Configuration file not found: $file"
        fi
    done
    
    if [ ${#tar_files[@]} -gt 0 ]; then
        if tar -cf "$backup_file" "${tar_files[@]}"; then
            log_success "Configuration archive created: $backup_file"
            
            # Compress backup
            local compression_cmd=$(get_compression_cmd)
            if $compression_cmd "$backup_file"; then
                log_success "Configuration backup compressed: $compressed_file"
                rm -f "$backup_file"
            else
                log_error "Failed to compress configuration backup"
                return 1
            fi
            
            # Encrypt if enabled
            if [ "$ENCRYPTION" = "true" ] && [ -n "$ENCRYPTION_KEY" ]; then
                local encrypted_file="${compressed_file}.enc"
                if openssl enc -aes-256-cbc -salt -in "$compressed_file" -out "$encrypted_file" -k "$ENCRYPTION_KEY"; then
                    log_success "Configuration backup encrypted: $encrypted_file"
                    rm -f "$compressed_file"
                else
                    log_error "Failed to encrypt configuration backup"
                    return 1
                fi
            fi
            
            # Store backup metadata
            local metadata_file="${config_backup_dir}/backup_metadata_${TIMESTAMP}.json"
            cat > "$metadata_file" << EOF
{
    "backup_id": "${TIMESTAMP}",
    "type": "config",
    "timestamp": "$(date -Iseconds)",
    "size": $(stat -c%s "${compressed_file:-$backup_file}"),
    "compression": "${COMPRESSION}",
    "encryption": ${ENCRYPTION},
    "files": [$(printf '"%s",' "${tar_files[@]}" | sed 's/,$//')]
}
EOF
            log_success "Configuration backup metadata saved: $metadata_file"
            
        else
            log_error "Failed to create configuration backup"
            return 1
        fi
    else
        log_warning "No configuration files found to backup"
    fi
}

# Function to cleanup old backups
cleanup_old_backups() {
    log "Cleaning up old backups (retention: $RETENTION_DAYS days)..."
    
    local cutoff_date=$(date -d "$RETENTION_DAYS days ago" +%Y%m%d)
    
    find "$BACKUP_ROOT" -name "*.sql.*" -o -name "*.tar.*" | while read -r backup_file; do
        local file_date=$(echo "$backup_file" | grep -o '[0-9]\{8\}' | head -1)
        if [ -n "$file_date" ] && [ "$file_date" -lt "$cutoff_date" ]; then
            log "Removing old backup: $backup_file"
            rm -f "$backup_file"
        fi
    done
    
    # Remove old metadata files
    find "$BACKUP_ROOT" -name "backup_metadata_*.json" | while read -r metadata_file; do
        local file_date=$(echo "$metadata_file" | grep -o '[0-9]\{8\}' | head -1)
        if [ -n "$file_date" ] && [ "$file_date" -lt "$cutoff_date" ]; then
            log "Removing old metadata: $metadata_file"
            rm -f "$metadata_file"
        fi
    done
    
    log_success "Old backups cleaned up"
}

# Function to verify backup integrity
verify_backup() {
    log "Verifying backup integrity..."
    
    local backup_dir="${BACKUP_ROOT}/database"
    local latest_backup=$(find "$backup_dir" -name "database_backup_*.sql.*" | sort | tail -1)
    
    if [ -n "$latest_backup" ]; then
        log "Verifying: $latest_backup"
        
        # Check if file is encrypted
        if [[ "$latest_backup" == *.enc ]]; then
            log "Backup is encrypted, skipping integrity check"
        else
            # Check compression integrity
            local compression_cmd=$(get_compression_cmd)
            if $compression_cmd -t "$latest_backup" 2>/dev/null; then
                log_success "Backup integrity verified: $latest_backup"
            else
                log_error "Backup integrity check failed: $latest_backup"
                return 1
            fi
        fi
    else
        log_warning "No database backups found to verify"
    fi
}

# Function to generate backup report
generate_backup_report() {
    log "Generating backup report..."
    
    local report_file="${LOG_DIR}/backup_report_${TIMESTAMP}.md"
    
    cat > "$report_file" << EOF
# MS5.0 Floor Dashboard - Backup Report

**Backup Date:** $(date)
**Backup Type:** $BACKUP_TYPE
**Retention Period:** $RETENTION_DAYS days
**Compression:** $COMPRESSION
**Encryption:** $ENCRYPTION

## Backup Summary

### Database Backups
EOF
    
    local db_backup_dir="${BACKUP_ROOT}/database"
    if [ -d "$db_backup_dir" ]; then
        ls -la "$db_backup_dir" >> "$report_file"
    else
        echo "No database backups found" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

### File Backups
EOF
    
    local files_backup_dir="${BACKUP_ROOT}/files"
    if [ -d "$files_backup_dir" ]; then
        ls -la "$files_backup_dir" >> "$report_file"
    else
        echo "No file backups found" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

### Configuration Backups
EOF
    
    local config_backup_dir="${BACKUP_ROOT}/config"
    if [ -d "$config_backup_dir" ]; then
        ls -la "$config_backup_dir" >> "$report_file"
    else
        echo "No configuration backups found" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

## Backup Statistics

- **Total Backup Size:** $(du -sh "$BACKUP_ROOT" 2>/dev/null | cut -f1)
- **Backup Count:** $(find "$BACKUP_ROOT" -name "*.sql.*" -o -name "*.tar.*" | wc -l)
- **Log File:** $LOG_FILE

## Next Steps

1. Test backup restoration procedures
2. Verify backup integrity
3. Schedule regular backups
4. Monitor backup storage usage

EOF
    
    log_success "Backup report generated: $report_file"
}

# Main backup function
main() {
    log "Starting MS5.0 system backup process..."
    
    # Change to script directory
    cd "$SCRIPT_DIR"
    
    local start_time=$(date +%s)
    local backup_success=true
    
    # Perform backup based on type
    case $BACKUP_TYPE in
        full)
            backup_database || backup_success=false
            backup_files || backup_success=false
            backup_config || backup_success=false
            ;;
        incremental)
            backup_database || backup_success=false
            ;;
        database)
            backup_database || backup_success=false
            ;;
        files)
            backup_files || backup_success=false
            ;;
        config)
            backup_config || backup_success=false
            ;;
        *)
            log_error "Invalid backup type: $BACKUP_TYPE"
            exit 1
            ;;
    esac
    
    # Verify backup if successful
    if [ "$backup_success" = "true" ]; then
        verify_backup || backup_success=false
    fi
    
    # Cleanup old backups
    cleanup_old_backups
    
    # Generate report
    generate_backup_report
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [ "$backup_success" = "true" ]; then
        log_success "Backup completed successfully in ${duration}s"
        log "Backup location: $BACKUP_ROOT"
        log "Log file: $LOG_FILE"
        exit 0
    else
        log_error "Backup completed with errors in ${duration}s"
        exit 1
    fi
}

# Help function
show_help() {
    echo "MS5.0 Floor Dashboard - Backup Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -t, --type TYPE     Backup type (full, incremental, database, files, config) (default: full)"
    echo "  -r, --retention N   Retention period in days (default: 30)"
    echo "  -c, --compression   Compression type (gzip, bzip2, xz) (default: gzip)"
    echo "  -e, --encrypt       Enable encryption"
    echo "  -k, --key KEY       Encryption key"
    echo ""
    echo "Environment Variables:"
    echo "  DATABASE_URL        PostgreSQL connection string (required)"
    echo "  BACKUP_TYPE         Backup type (default: full)"
    echo "  RETENTION_DAYS      Retention period (default: 30)"
    echo "  COMPRESSION         Compression type (default: gzip)"
    echo "  ENCRYPTION          Enable encryption (default: false)"
    echo "  ENCRYPTION_KEY      Encryption key"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Full backup"
    echo "  $0 -t database -r 7                   # Database backup with 7-day retention"
    echo "  $0 -t full -e -k mykey               # Full encrypted backup"
    echo "  DATABASE_URL=postgresql://... $0      # Backup with custom database"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -t|--type)
            BACKUP_TYPE="$2"
            shift 2
            ;;
        -r|--retention)
            RETENTION_DAYS="$2"
            shift 2
            ;;
        -c|--compression)
            COMPRESSION="$2"
            shift 2
            ;;
        -e|--encrypt)
            ENCRYPTION="true"
            shift
            ;;
        -k|--key)
            ENCRYPTION_KEY="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate backup type
if [[ ! "$BACKUP_TYPE" =~ ^(full|incremental|database|files|config)$ ]]; then
    log_error "Invalid backup type: $BACKUP_TYPE (must be 'full', 'incremental', 'database', 'files', or 'config')"
    exit 1
fi

# Validate compression type
if [[ ! "$COMPRESSION" =~ ^(gzip|bzip2|xz)$ ]]; then
    log_error "Invalid compression type: $COMPRESSION (must be 'gzip', 'bzip2', or 'xz')"
    exit 1
fi

# Validate retention days
if ! [[ "$RETENTION_DAYS" =~ ^[0-9]+$ ]] || [ "$RETENTION_DAYS" -lt 1 ]; then
    log_error "Invalid retention days: $RETENTION_DAYS (must be a positive integer)"
    exit 1
fi

# Check encryption requirements
if [ "$ENCRYPTION" = "true" ] && [ -z "$ENCRYPTION_KEY" ]; then
    log_error "Encryption key is required when encryption is enabled"
    exit 1
fi

# Run main function
main
