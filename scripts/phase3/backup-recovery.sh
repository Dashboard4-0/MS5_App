#!/bin/bash

# Phase 3.4: Backup and Recovery Script
# This script implements comprehensive backup and disaster recovery procedures
# with Azure Blob Storage integration

set -euo pipefail

# Configuration
NAMESPACE="ms5-production"
DATABASE_NAME="factory_telemetry"
AZURE_STORAGE_ACCOUNT="${AZURE_STORAGE_ACCOUNT:-ms5backups}"
AZURE_STORAGE_CONTAINER="${AZURE_STORAGE_CONTAINER:-database-backups}"
AZURE_STORAGE_KEY="${AZURE_STORAGE_KEY:-}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
BACKUP_DIR="/tmp/ms5-backup"
LOG_FILE="/tmp/ms5-backup.log"

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

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if psql is available
    if ! command -v psql &> /dev/null; then
        log_error "psql is not installed or not in PATH"
        exit 1
    fi
    
    # Check if pg_dump is available
    if ! command -v pg_dump &> /dev/null; then
        log_error "pg_dump is not installed or not in PATH"
        exit 1
    fi
    
    # Check if az is available for Azure CLI
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed or not in PATH"
        exit 1
    fi
    
    # Check if AKS cluster is accessible
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot access AKS cluster"
        exit 1
    fi
    
    # Check if namespace exists
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_error "Namespace $NAMESPACE does not exist"
        exit 1
    fi
    
    # Check Azure storage account access
    if [ -z "$AZURE_STORAGE_KEY" ]; then
        log_error "AZURE_STORAGE_KEY environment variable is not set"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Create backup directory
create_backup_directory() {
    log "Creating backup directory..."
    
    # Create backup directory with timestamp
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    BACKUP_DIR="/tmp/ms5-backup-$timestamp"
    mkdir -p "$BACKUP_DIR"
    
    log_success "Backup directory created: $BACKUP_DIR"
}

# Create full database backup
create_full_backup() {
    log "Creating full database backup..."
    
    # Get database connection details
    local db_host="postgres-primary.ms5-production.svc.cluster.local"
    local db_port="5432"
    local db_user="ms5_user"
    local db_password="ms5_password"
    
    # Create full backup using pg_dump
    local backup_file="$BACKUP_DIR/factory_telemetry_full_$(date +%Y%m%d_%H%M%S).dump"
    
    PGPASSWORD="$db_password" pg_dump \
        -h "$db_host" \
        -p "$db_port" \
        -U "$db_user" \
        -d "$DATABASE_NAME" \
        --verbose \
        --no-password \
        --format=custom \
        --compress=9 \
        --file="$backup_file"
    
    if [ $? -eq 0 ]; then
        log_success "Full database backup created: $backup_file"
        echo "$backup_file"
    else
        log_error "Failed to create full database backup"
        exit 1
    fi
}

# Create incremental backup (WAL files)
create_incremental_backup() {
    log "Creating incremental backup..."
    
    # Get WAL files from database
    local db_host="postgres-primary.ms5-production.svc.cluster.local"
    local db_port="5432"
    local db_user="ms5_user"
    local db_password="ms5_password"
    
    # Force WAL switch
    PGPASSWORD="$db_password" psql \
        -h "$db_host" \
        -p "$db_port" \
        -U "$db_user" \
        -d "$DATABASE_NAME" \
        -c "SELECT pg_switch_wal();"
    
    # Copy WAL files to backup directory
    local wal_dir="$BACKUP_DIR/wal"
    mkdir -p "$wal_dir"
    
    # Get WAL files from pod
    kubectl exec -n "$NAMESPACE" "statefulset/postgres-primary" -- \
        find /wal-archive -name "*.wal" -mtime -1 -exec cp {} "$wal_dir" \;
    
    log_success "Incremental backup created"
}

# Upload backup to Azure Blob Storage
upload_to_azure() {
    local backup_file=$1
    
    log "Uploading backup to Azure Blob Storage..."
    
    # Upload backup file
    az storage blob upload \
        --account-name "$AZURE_STORAGE_ACCOUNT" \
        --account-key "$AZURE_STORAGE_KEY" \
        --container-name "$AZURE_STORAGE_CONTAINER" \
        --file "$backup_file" \
        --name "$(basename "$backup_file")" \
        --overwrite
    
    if [ $? -eq 0 ]; then
        log_success "Backup uploaded to Azure Blob Storage"
    else
        log_error "Failed to upload backup to Azure Blob Storage"
        exit 1
    fi
    
    # Upload WAL files if they exist
    local wal_dir="$BACKUP_DIR/wal"
    if [ -d "$wal_dir" ] && [ "$(ls -A "$wal_dir")" ]; then
        log "Uploading WAL files to Azure Blob Storage..."
        
        for wal_file in "$wal_dir"/*; do
            if [ -f "$wal_file" ]; then
                az storage blob upload \
                    --account-name "$AZURE_STORAGE_ACCOUNT" \
                    --account-key "$AZURE_STORAGE_KEY" \
                    --container-name "$AZURE_STORAGE_CONTAINER" \
                    --file "$wal_file" \
                    --name "wal/$(basename "$wal_file")" \
                    --overwrite
            fi
        done
        
        log_success "WAL files uploaded to Azure Blob Storage"
    fi
}

# Clean up old backups
cleanup_old_backups() {
    log "Cleaning up old backups..."
    
    # Calculate cutoff date
    local cutoff_date=$(date -d "$BACKUP_RETENTION_DAYS days ago" +"%Y-%m-%d")
    
    # List and delete old backups from Azure Blob Storage
    az storage blob list \
        --account-name "$AZURE_STORAGE_ACCOUNT" \
        --account-key "$AZURE_STORAGE_KEY" \
        --container-name "$AZURE_STORAGE_CONTAINER" \
        --query "[?properties.lastModified < '$cutoff_date'].name" \
        --output tsv | while read -r blob_name; do
            if [ -n "$blob_name" ]; then
                log "Deleting old backup: $blob_name"
                az storage blob delete \
                    --account-name "$AZURE_STORAGE_ACCOUNT" \
                    --account-key "$AZURE_STORAGE_KEY" \
                    --container-name "$AZURE_STORAGE_CONTAINER" \
                    --name "$blob_name"
            fi
        done
    
    log_success "Old backups cleaned up"
}

# Test backup integrity
test_backup_integrity() {
    local backup_file=$1
    
    log "Testing backup integrity..."
    
    # Test backup file using pg_restore --list
    pg_restore --list "$backup_file" > /dev/null
    
    if [ $? -eq 0 ]; then
        log_success "Backup integrity test passed"
    else
        log_error "Backup integrity test failed"
        exit 1
    fi
}

# Create point-in-time recovery script
create_pitr_script() {
    log "Creating point-in-time recovery script..."
    
    local pitr_script="$BACKUP_DIR/point-in-time-recovery.sh"
    
    cat > "$pitr_script" << 'EOF'
#!/bin/bash

# Point-in-Time Recovery Script for MS5.0 Database
# Usage: ./point-in-time-recovery.sh <backup_file> <target_time>

set -euo pipefail

BACKUP_FILE=$1
TARGET_TIME=$2
NAMESPACE="ms5-production"
DATABASE_NAME="factory_telemetry"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Validate inputs
if [ $# -ne 2 ]; then
    log_error "Usage: $0 <backup_file> <target_time>"
    log_error "Example: $0 factory_telemetry_full_20231201_120000.dump '2023-12-01 11:30:00'"
    exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
    log_error "Backup file $BACKUP_FILE does not exist"
    exit 1
fi

log "Starting point-in-time recovery to $TARGET_TIME"

# Stop application services
log "Stopping application services..."
kubectl scale deployment ms5-backend --replicas=0 -n "$NAMESPACE"
kubectl scale statefulset postgres-replica --replicas=0 -n "$NAMESPACE"

# Restore base backup
log "Restoring base backup..."
kubectl exec -n "$NAMESPACE" "statefulset/postgres-primary" -- \
    pg_restore --clean --if-exists --dbname="$DATABASE_NAME" "$BACKUP_FILE"

# Apply WAL files up to target time
log "Applying WAL files up to target time..."
kubectl exec -n "$NAMESPACE" "statefulset/postgres-primary" -- \
    pg_recovery_target_time="$TARGET_TIME" \
    pg_recovery_target_action=promote

# Start replica services
log "Starting replica services..."
kubectl scale statefulset postgres-replica --replicas=2 -n "$NAMESPACE"

# Start application services
log "Starting application services..."
kubectl scale deployment ms5-backend --replicas=3 -n "$NAMESPACE"

log_success "Point-in-time recovery completed successfully"
EOF

    chmod +x "$pitr_script"
    log_success "Point-in-time recovery script created: $pitr_script"
}

# Main backup function
main_backup() {
    log "Starting Phase 3.4: Backup and Recovery"
    log "Backup log: $LOG_FILE"
    
    # Step 1: Check prerequisites
    check_prerequisites
    
    # Step 2: Create backup directory
    create_backup_directory
    
    # Step 3: Create full backup
    local backup_file=$(create_full_backup)
    
    # Step 4: Create incremental backup
    create_incremental_backup
    
    # Step 5: Test backup integrity
    test_backup_integrity "$backup_file"
    
    # Step 6: Upload to Azure Blob Storage
    upload_to_azure "$backup_file"
    
    # Step 7: Clean up old backups
    cleanup_old_backups
    
    # Step 8: Create point-in-time recovery script
    create_pitr_script
    
    log_success "Phase 3.4: Backup and Recovery completed successfully!"
    log "Backup completed at $(date)"
    log "Backup file: $backup_file"
}

# Recovery function
recover_from_backup() {
    local backup_file=$1
    local target_time=${2:-""}
    
    log "Starting recovery from backup: $backup_file"
    
    if [ -n "$target_time" ]; then
        log "Point-in-time recovery to: $target_time"
        # Use point-in-time recovery script
        "$BACKUP_DIR/point-in-time-recovery.sh" "$backup_file" "$target_time"
    else
        log "Full recovery from backup"
        
        # Stop application services
        kubectl scale deployment ms5-backend --replicas=0 -n "$NAMESPACE"
        kubectl scale statefulset postgres-replica --replicas=0 -n "$NAMESPACE"
        
        # Restore backup
        kubectl exec -n "$NAMESPACE" "statefulset/postgres-primary" -- \
            pg_restore --clean --if-exists --dbname="$DATABASE_NAME" "$backup_file"
        
        # Start services
        kubectl scale statefulset postgres-replica --replicas=2 -n "$NAMESPACE"
        kubectl scale deployment ms5-backend --replicas=3 -n "$NAMESPACE"
    fi
    
    log_success "Recovery completed successfully"
}

# Main function
main() {
    case "${1:-backup}" in
        "backup")
            main_backup
            ;;
        "recover")
            if [ $# -lt 2 ]; then
                log_error "Usage: $0 recover <backup_file> [target_time]"
                exit 1
            fi
            recover_from_backup "$2" "${3:-}"
            ;;
        *)
            log_error "Usage: $0 [backup|recover]"
            log_error "  backup: Create backup and upload to Azure Blob Storage"
            log_error "  recover <backup_file> [target_time]: Recover from backup"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
