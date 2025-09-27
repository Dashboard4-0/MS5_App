#!/bin/bash

# MS5.0 Floor Dashboard - Database Migration Deployment Script
# This script deploys all database migrations in the correct order

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIGRATIONS_DIR="${SCRIPT_DIR}/../"
LOG_DIR="${SCRIPT_DIR}/logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${LOG_DIR}/migration_${TIMESTAMP}.log"

# Environment variables
ENVIRONMENT=${ENVIRONMENT:-production}
DATABASE_URL=${DATABASE_URL}
BACKUP_ENABLED=${BACKUP_ENABLED:-true}
VALIDATE_MIGRATIONS=${VALIDATE_MIGRATIONS:-true}

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

# Create log directory
mkdir -p "$LOG_DIR"

log "Starting database migration deployment for environment: $ENVIRONMENT"

# Validate required environment variables
if [ -z "$DATABASE_URL" ]; then
    log_error "DATABASE_URL environment variable is required"
    exit 1
fi

# Test database connection
log "Testing database connection..."
if ! psql "$DATABASE_URL" -c "SELECT 1;" > /dev/null 2>&1; then
    log_error "Cannot connect to database. Please check DATABASE_URL"
    exit 1
fi
log_success "Database connection successful"

# Create migration tracking table if it doesn't exist
log "Creating migration tracking table..."
psql "$DATABASE_URL" << 'EOF'
CREATE TABLE IF NOT EXISTS migration_history (
    id SERIAL PRIMARY KEY,
    migration_file VARCHAR(255) NOT NULL UNIQUE,
    applied_at TIMESTAMPTZ DEFAULT NOW(),
    checksum VARCHAR(64),
    environment VARCHAR(50),
    applied_by VARCHAR(100) DEFAULT current_user
);
EOF

# Function to get migration checksum
get_checksum() {
    local file="$1"
    if command -v sha256sum > /dev/null; then
        sha256sum "$file" | cut -d' ' -f1
    elif command -v shasum > /dev/null; then
        shasum -a 256 "$file" | cut -d' ' -f1
    else
        log_warning "No checksum utility found, skipping checksum validation"
        echo "no-checksum"
    fi
}

# Function to check if migration was already applied
is_migration_applied() {
    local migration_file="$1"
    local result=$(psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM migration_history WHERE migration_file = '$migration_file';" | xargs)
    [ "$result" -gt 0 ]
}

# Function to apply migration
apply_migration() {
    local migration_file="$1"
    local full_path="$MIGRATIONS_DIR/$migration_file"
    
    if [ ! -f "$full_path" ]; then
        log_error "Migration file not found: $full_path"
        return 1
    fi
    
    log "Applying migration: $migration_file"
    
    # Get checksum before applying
    local checksum=$(get_checksum "$full_path")
    
    # Apply migration
    if psql "$DATABASE_URL" -f "$full_path" >> "$LOG_FILE" 2>&1; then
        # Record migration in history
        psql "$DATABASE_URL" << EOF
INSERT INTO migration_history (migration_file, checksum, environment, applied_by)
VALUES ('$migration_file', '$checksum', '$ENVIRONMENT', current_user);
EOF
        log_success "Migration applied successfully: $migration_file"
        return 0
    else
        log_error "Failed to apply migration: $migration_file"
        return 1
    fi
}

# Function to create backup
create_backup() {
    if [ "$BACKUP_ENABLED" = "true" ]; then
        local backup_file="${LOG_DIR}/backup_before_migration_${TIMESTAMP}.sql"
        log "Creating database backup: $backup_file"
        
        if pg_dump "$DATABASE_URL" > "$backup_file"; then
            log_success "Database backup created successfully"
            # Compress backup
            gzip "$backup_file"
            log_success "Database backup compressed: ${backup_file}.gz"
        else
            log_error "Failed to create database backup"
            return 1
        fi
    fi
}

# Function to validate migration
validate_migration() {
    local migration_file="$1"
    
    if [ "$VALIDATE_MIGRATIONS" = "true" ]; then
        log "Validating migration: $migration_file"
        
        # Basic validation - check if migration contains only SQL statements
        if grep -q "DROP TABLE\|DROP DATABASE\|DROP SCHEMA" "$MIGRATIONS_DIR/$migration_file"; then
            log_warning "Migration contains potentially destructive operations: $migration_file"
        fi
        
        # Check for syntax errors
        if ! psql "$DATABASE_URL" -f "$MIGRATIONS_DIR/$migration_file" --dry-run > /dev/null 2>&1; then
            log_error "Migration syntax validation failed: $migration_file"
            return 1
        fi
        
        log_success "Migration validation passed: $migration_file"
    fi
}

# Main migration deployment
main() {
    # Create backup before starting migrations
    create_backup
    
    # Define migration files in correct order
    migrations=(
        "001_init_telemetry.sql"
        "002_plc_equipment_management.sql"
        "003_production_management.sql"
        "004_advanced_production_features.sql"
        "005_andon_escalation_system.sql"
        "006_report_system.sql"
        "007_plc_integration_phase1.sql"
        "008_fix_critical_schema_issues.sql"
    )
    
    local applied_count=0
    local skipped_count=0
    local failed_count=0
    
    log "Starting migration deployment process..."
    
    for migration in "${migrations[@]}"; do
        if is_migration_applied "$migration"; then
            log "Migration already applied, skipping: $migration"
            ((skipped_count++))
            continue
        fi
        
        # Validate migration before applying
        if ! validate_migration "$migration"; then
            log_error "Migration validation failed, stopping deployment"
            exit 1
        fi
        
        # Apply migration
        if apply_migration "$migration"; then
            ((applied_count++))
        else
            log_error "Migration failed, stopping deployment"
            ((failed_count++))
            exit 1
        fi
    done
    
    # Final validation
    log "Running final database validation..."
    
    # Check if all required tables exist
    required_tables=(
        "factory_telemetry.users"
        "factory_telemetry.equipment_config"
        "factory_telemetry.context"
        "factory_telemetry.production_lines"
        "factory_telemetry.andon_events"
        "factory_telemetry.andon_escalations"
    )
    
    for table in "${required_tables[@]}"; do
        if psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_name = '${table##*.}' AND table_schema = '${table%%.*}';" | xargs | grep -q "1"; then
            log_success "Table exists: $table"
        else
            log_error "Required table missing: $table"
            exit 1
        fi
    done
    
    # Check if all required views exist
    required_views=(
        "factory_telemetry.equipment_production_status"
        "factory_telemetry.production_line_status"
    )
    
    for view in "${required_views[@]}"; do
        if psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM information_schema.views WHERE table_name = '${view##*.}' AND table_schema = '${view%%.*}';" | xargs | grep -q "1"; then
            log_success "View exists: $view"
        else
            log_error "Required view missing: $view"
            exit 1
        fi
    done
    
    # Check if all required functions exist
    required_functions=(
        "factory_telemetry.get_equipment_production_context"
        "factory_telemetry.update_equipment_production_context"
    )
    
    for function in "${required_functions[@]}"; do
        if psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM information_schema.routines WHERE routine_name = '${function##*.}' AND routine_schema = '${function%%.*}';" | xargs | grep -q "1"; then
            log_success "Function exists: $function"
        else
            log_error "Required function missing: $function"
            exit 1
        fi
    done
    
    # Summary
    log_success "Migration deployment completed successfully!"
    log "Summary:"
    log "  - Applied migrations: $applied_count"
    log "  - Skipped migrations: $skipped_count"
    log "  - Failed migrations: $failed_count"
    log "  - Log file: $LOG_FILE"
    
    if [ "$BACKUP_ENABLED" = "true" ]; then
        log "  - Backup file: ${LOG_DIR}/backup_before_migration_${TIMESTAMP}.sql.gz"
    fi
}

# Rollback function
rollback() {
    log_warning "Rollback functionality not implemented in this version"
    log "Please restore from backup if needed"
    log "Backup location: ${LOG_DIR}/"
}

# Help function
show_help() {
    echo "MS5.0 Floor Dashboard - Database Migration Deployment Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -e, --environment   Set environment (default: production)"
    echo "  -v, --validate      Validate migrations before applying (default: true)"
    echo "  -b, --backup        Enable backup before migration (default: true)"
    echo "  --dry-run           Validate migrations without applying"
    echo "  --rollback          Rollback migrations (not implemented)"
    echo ""
    echo "Environment Variables:"
    echo "  DATABASE_URL        PostgreSQL connection string (required)"
    echo "  ENVIRONMENT         Environment name (default: production)"
    echo "  BACKUP_ENABLED      Enable backup (default: true)"
    echo "  VALIDATE_MIGRATIONS Enable validation (default: true)"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Deploy with defaults"
    echo "  $0 -e staging                         # Deploy to staging"
    echo "  $0 --dry-run                          # Validate without applying"
    echo "  DATABASE_URL=postgresql://... $0      # Deploy with custom database"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -v|--validate)
            VALIDATE_MIGRATIONS="true"
            shift
            ;;
        -b|--backup)
            BACKUP_ENABLED="true"
            shift
            ;;
        --dry-run)
            log "Dry run mode - validating migrations only"
            for migration in "${migrations[@]}"; do
                if ! validate_migration "$migration"; then
                    log_error "Migration validation failed: $migration"
                    exit 1
                fi
            done
            log_success "All migrations validated successfully"
            exit 0
            ;;
        --rollback)
            rollback
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Run main function
main
