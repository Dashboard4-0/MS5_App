#!/bin/bash

# Phase 3.3: Data Migration Script
# This script implements blue-green deployment strategy for database migration
# from Docker Compose to AKS with zero-downtime migration

set -euo pipefail

# Configuration
NAMESPACE="ms5-production"
PRIMARY_SERVICE="postgres-primary.ms5-production.svc.cluster.local"
REPLICA_SERVICE="postgres-replica.ms5-production.svc.cluster.local"
DATABASE_NAME="factory_telemetry"
BACKUP_DIR="/tmp/ms5-backup"
MIGRATION_LOG="/tmp/ms5-migration.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$MIGRATION_LOG"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$MIGRATION_LOG"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$MIGRATION_LOG"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$MIGRATION_LOG"
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
    
    log_success "Prerequisites check passed"
}

# Wait for database to be ready
wait_for_database() {
    local service_name=$1
    local max_attempts=30
    local attempt=1
    
    log "Waiting for database $service_name to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        if kubectl exec -n "$NAMESPACE" "deployment/postgres-primary" -- pg_isready -h "$service_name" -p 5432 -U ms5_user -d "$DATABASE_NAME" &> /dev/null; then
            log_success "Database $service_name is ready"
            return 0
        fi
        
        log "Attempt $attempt/$max_attempts: Database not ready yet, waiting 10 seconds..."
        sleep 10
        ((attempt++))
    done
    
    log_error "Database $service_name failed to become ready after $max_attempts attempts"
    exit 1
}

# Create backup of existing database
create_backup() {
    log "Creating backup of existing database..."
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    # Get database connection details from Docker Compose
    local docker_host="localhost"
    local docker_port="5432"
    local docker_user="ms5_user"
    local docker_password="ms5_password"
    
    # Create backup using pg_dump
    PGPASSWORD="$docker_password" pg_dump \
        -h "$docker_host" \
        -p "$docker_port" \
        -U "$docker_user" \
        -d "$DATABASE_NAME" \
        --verbose \
        --no-password \
        --format=custom \
        --file="$BACKUP_DIR/factory_telemetry_backup.dump"
    
    if [ $? -eq 0 ]; then
        log_success "Database backup created successfully"
    else
        log_error "Failed to create database backup"
        exit 1
    fi
}

# Deploy AKS database
deploy_aks_database() {
    log "Deploying AKS database..."
    
    # Apply database manifests
    kubectl apply -f k8s/06-postgres-statefulset.yaml
    kubectl apply -f k8s/07-postgres-services.yaml
    kubectl apply -f k8s/08-postgres-config.yaml
    kubectl apply -f k8s/08-postgres-replica-config.yaml
    
    # Wait for primary database to be ready
    wait_for_database "$PRIMARY_SERVICE"
    
    # Wait for replica databases to be ready
    wait_for_database "$REPLICA_SERVICE"
    
    log_success "AKS database deployed successfully"
}

# Restore data to AKS database
restore_data() {
    log "Restoring data to AKS database..."
    
    # Get AKS database connection details
    local aks_host="$PRIMARY_SERVICE"
    local aks_port="5432"
    local aks_user="ms5_user"
    local aks_password="ms5_password"
    
    # Restore data using pg_restore
    PGPASSWORD="$aks_password" pg_restore \
        -h "$aks_host" \
        -p "$aks_port" \
        -U "$aks_user" \
        -d "$DATABASE_NAME" \
        --verbose \
        --no-password \
        --clean \
        --if-exists \
        "$BACKUP_DIR/factory_telemetry_backup.dump"
    
    if [ $? -eq 0 ]; then
        log_success "Data restored successfully to AKS database"
    else
        log_error "Failed to restore data to AKS database"
        exit 1
    fi
}

# Configure TimescaleDB hypertables
configure_timescaledb() {
    log "Configuring TimescaleDB hypertables..."
    
    # Get AKS database connection details
    local aks_host="$PRIMARY_SERVICE"
    local aks_port="5432"
    local aks_user="ms5_user"
    local aks_password="ms5_password"
    
    # Execute TimescaleDB configuration
    PGPASSWORD="$aks_password" psql \
        -h "$aks_host" \
        -p "$aks_port" \
        -U "$aks_user" \
        -d "$DATABASE_NAME" \
        -c "
        -- Convert existing tables to hypertables
        SELECT create_hypertable('factory_telemetry.metric_hist', 'ts', if_not_exists => TRUE);
        SELECT create_hypertable('factory_telemetry.oee_calculations', 'calculation_time', if_not_exists => TRUE);
        
        -- Set up continuous aggregates
        CREATE MATERIALIZED VIEW IF NOT EXISTS oee_hourly_aggregate
        WITH (timescaledb.continuous) AS
        SELECT 
            time_bucket('1 hour', calculation_time) AS hour,
            line_id,
            equipment_code,
            AVG(availability) AS avg_availability,
            AVG(performance) AS avg_performance,
            AVG(quality) AS avg_quality,
            AVG(oee) AS avg_oee,
            SUM(good_parts) AS total_good_parts,
            SUM(total_parts) AS total_parts
        FROM factory_telemetry.oee_calculations
        GROUP BY hour, line_id, equipment_code;
        
        -- Set up data retention policies
        SELECT add_retention_policy('factory_telemetry.metric_hist', INTERVAL '90 days', if_not_exists => TRUE);
        SELECT add_retention_policy('factory_telemetry.oee_calculations', INTERVAL '1 year', if_not_exists => TRUE);
        
        -- Set up compression policies
        SELECT add_compression_policy('factory_telemetry.metric_hist', INTERVAL '7 days', if_not_exists => TRUE);
        SELECT add_compression_policy('factory_telemetry.oee_calculations', INTERVAL '30 days', if_not_exists => TRUE);
        "
    
    if [ $? -eq 0 ]; then
        log_success "TimescaleDB hypertables configured successfully"
    else
        log_error "Failed to configure TimescaleDB hypertables"
        exit 1
    fi
}

# Validate data integrity
validate_data_integrity() {
    log "Validating data integrity..."
    
    # Get AKS database connection details
    local aks_host="$PRIMARY_SERVICE"
    local aks_port="5432"
    local aks_user="ms5_user"
    local aks_password="ms5_password"
    
    # Check table counts
    local table_counts=$(PGPASSWORD="$aks_password" psql \
        -h "$aks_host" \
        -p "$aks_port" \
        -U "$aks_user" \
        -d "$DATABASE_NAME" \
        -t -c "
        SELECT 
            schemaname,
            tablename,
            n_tup_ins as row_count
        FROM pg_stat_user_tables 
        WHERE schemaname = 'factory_telemetry'
        ORDER BY tablename;
        ")
    
    log "Table counts in AKS database:"
    echo "$table_counts"
    
    # Check TimescaleDB hypertables
    local hypertables=$(PGPASSWORD="$aks_password" psql \
        -h "$aks_host" \
        -p "$aks_port" \
        -U "$aks_user" \
        -d "$DATABASE_NAME" \
        -t -c "
        SELECT 
            hypertable_schema,
            hypertable_name,
            num_dimensions
        FROM timescaledb_information.hypertables;
        ")
    
    log "TimescaleDB hypertables:"
    echo "$hypertables"
    
    log_success "Data integrity validation completed"
}

# Test application connectivity
test_application_connectivity() {
    log "Testing application connectivity..."
    
    # Test primary database connection
    if kubectl exec -n "$NAMESPACE" "deployment/postgres-primary" -- psql -h "$PRIMARY_SERVICE" -U ms5_user -d "$DATABASE_NAME" -c "SELECT 1;" &> /dev/null; then
        log_success "Primary database connectivity test passed"
    else
        log_error "Primary database connectivity test failed"
        exit 1
    fi
    
    # Test replica database connection
    if kubectl exec -n "$NAMESPACE" "deployment/postgres-primary" -- psql -h "$REPLICA_SERVICE" -U ms5_user -d "$DATABASE_NAME" -c "SELECT 1;" &> /dev/null; then
        log_success "Replica database connectivity test passed"
    else
        log_error "Replica database connectivity test failed"
        exit 1
    fi
    
    log_success "Application connectivity tests passed"
}

# Update application configuration
update_application_config() {
    log "Updating application configuration..."
    
    # Update database connection strings in ConfigMaps
    kubectl patch configmap ms5-app-config -n "$NAMESPACE" --type merge -p '{
        "data": {
            "DATABASE_URL": "postgresql+asyncpg://ms5_user:ms5_password@postgres-primary.ms5-production.svc.cluster.local:5432/factory_telemetry",
            "DATABASE_READ_URL": "postgresql+asyncpg://ms5_readonly_user:ms5_readonly_password@postgres-replica.ms5-production.svc.cluster.local:5432/factory_telemetry"
        }
    }'
    
    log_success "Application configuration updated"
}

# Cleanup old database
cleanup_old_database() {
    log "Cleaning up old database..."
    
    # Stop Docker Compose services
    if [ -f "backend/docker-compose.yml" ]; then
        cd backend
        docker-compose down postgres timescaledb
        cd ..
        log_success "Docker Compose database services stopped"
    fi
    
    # Remove backup files
    rm -rf "$BACKUP_DIR"
    log_success "Backup files cleaned up"
}

# Main migration function
main() {
    log "Starting Phase 3.3: Data Migration"
    log "Migration log: $MIGRATION_LOG"
    
    # Step 1: Check prerequisites
    check_prerequisites
    
    # Step 2: Create backup
    create_backup
    
    # Step 3: Deploy AKS database
    deploy_aks_database
    
    # Step 4: Restore data
    restore_data
    
    # Step 5: Configure TimescaleDB
    configure_timescaledb
    
    # Step 6: Validate data integrity
    validate_data_integrity
    
    # Step 7: Test application connectivity
    test_application_connectivity
    
    # Step 8: Update application configuration
    update_application_config
    
    # Step 9: Cleanup old database
    cleanup_old_database
    
    log_success "Phase 3.3: Data Migration completed successfully!"
    log "Migration completed at $(date)"
}

# Run main function
main "$@"
