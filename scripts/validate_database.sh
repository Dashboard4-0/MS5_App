#!/bin/bash

# MS5.0 Floor Dashboard - Database Validation Script
# This script validates the database schema and data integrity

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${LOG_DIR}/validation_${TIMESTAMP}.log"

# Environment variables
DATABASE_URL=${DATABASE_URL}
VALIDATION_LEVEL=${VALIDATION_LEVEL:-full}

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

log "Starting database validation"

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

# Validation counters
total_checks=0
passed_checks=0
failed_checks=0
warning_checks=0

# Function to run a validation check
run_check() {
    local check_name="$1"
    local check_command="$2"
    local check_type="${3:-required}"  # required, warning, info
    
    ((total_checks++))
    log "Running check: $check_name"
    
    if eval "$check_command" > /dev/null 2>&1; then
        log_success "PASSED: $check_name"
        ((passed_checks++))
        return 0
    else
        case $check_type in
            required)
                log_error "FAILED: $check_name"
                ((failed_checks++))
                return 1
                ;;
            warning)
                log_warning "WARNING: $check_name"
                ((warning_checks++))
                return 0
                ;;
            info)
                log "INFO: $check_name (not critical)"
                return 0
                ;;
        esac
    fi
}

# Schema validation checks
validate_schema() {
    log "=== SCHEMA VALIDATION ==="
    
    # Check if factory_telemetry schema exists
    run_check "Factory telemetry schema exists" \
        "psql \"$DATABASE_URL\" -t -c \"SELECT 1 FROM information_schema.schemata WHERE schema_name = 'factory_telemetry';\" | xargs | grep -q '1'" \
        required
    
    # Check required tables
    local required_tables=(
        "users"
        "equipment_config"
        "context"
        "production_lines"
        "production_schedules"
        "job_assignments"
        "product_types"
        "andon_events"
        "andon_escalations"
        "andon_escalation_rules"
        "andon_escalation_recipients"
        "andon_escalation_history"
        "downtime_events"
        "quality_checks"
        "checklists"
        "checklist_items"
        "oee_calculations"
        "report_templates"
        "report_generations"
    )
    
    for table in "${required_tables[@]}"; do
        run_check "Table exists: factory_telemetry.$table" \
            "psql \"$DATABASE_URL\" -t -c \"SELECT 1 FROM information_schema.tables WHERE table_schema = 'factory_telemetry' AND table_name = '$table';\" | xargs | grep -q '1'" \
            required
    done
    
    # Check required views
    local required_views=(
        "equipment_production_status"
        "production_line_status"
        "active_andon_escalations"
        "andon_escalation_statistics"
    )
    
    for view in "${required_views[@]}"; do
        run_check "View exists: factory_telemetry.$view" \
            "psql \"$DATABASE_URL\" -t -c \"SELECT 1 FROM information_schema.views WHERE table_schema = 'factory_telemetry' AND table_name = '$view';\" | xargs | grep -q '1'" \
            required
    done
    
    # Check required functions
    local required_functions=(
        "get_equipment_production_context"
        "update_equipment_production_context"
        "auto_escalate_andon_events"
        "get_escalation_recipients"
    )
    
    for function in "${required_functions[@]}"; do
        run_check "Function exists: factory_telemetry.$function" \
            "psql \"$DATABASE_URL\" -t -c \"SELECT 1 FROM information_schema.routines WHERE routine_schema = 'factory_telemetry' AND routine_name = '$function';\" | xargs | grep -q '1'" \
            required
    done
    
    # Check indexes
    local required_indexes=(
        "idx_users_username"
        "idx_users_email"
        "idx_users_role"
        "idx_equipment_config_code"
        "idx_equipment_config_line"
        "idx_andon_events_status"
        "idx_andon_events_priority"
        "idx_andon_escalations_status"
    )
    
    for index in "${required_indexes[@]}"; do
        run_check "Index exists: $index" \
            "psql \"$DATABASE_URL\" -t -c \"SELECT 1 FROM pg_indexes WHERE indexname = '$index';\" | xargs | grep -q '1'" \
            warning
    done
}

# Data integrity validation checks
validate_data_integrity() {
    log "=== DATA INTEGRITY VALIDATION ==="
    
    # Check foreign key constraints
    run_check "Foreign key constraints are valid" \
        "psql \"$DATABASE_URL\" -c \"SELECT conname FROM pg_constraint WHERE contype = 'f' AND NOT EXISTS (SELECT 1 FROM pg_constraint c2 WHERE c2.oid = pg_constraint.oid AND pg_constraint_is_valid(c2.oid));\" | grep -q '0 rows'" \
        required
    
    # Check for orphaned records
    run_check "No orphaned equipment config records" \
        "psql \"$DATABASE_URL\" -t -c \"SELECT COUNT(*) FROM factory_telemetry.equipment_config ec LEFT JOIN factory_telemetry.production_lines pl ON ec.production_line_id = pl.id WHERE ec.production_line_id IS NOT NULL AND pl.id IS NULL;\" | xargs | grep -q '^0$'" \
        required
    
    run_check "No orphaned job assignment records" \
        "psql \"$DATABASE_URL\" -t -c \"SELECT COUNT(*) FROM factory_telemetry.job_assignments ja LEFT JOIN factory_telemetry.users u ON ja.assigned_to = u.id WHERE ja.assigned_to IS NOT NULL AND u.id IS NULL;\" | xargs | grep -q '^0$'" \
        required
    
    run_check "No orphaned context records" \
        "psql \"$DATABASE_URL\" -t -c \"SELECT COUNT(*) FROM factory_telemetry.context c LEFT JOIN factory_telemetry.equipment_config ec ON c.equipment_code = ec.equipment_code WHERE c.equipment_code IS NOT NULL AND ec.equipment_code IS NULL;\" | xargs | grep -q '^0$'" \
        required
    
    # Check data consistency
    run_check "User roles are valid" \
        "psql \"$DATABASE_URL\" -t -c \"SELECT COUNT(*) FROM factory_telemetry.users WHERE role NOT IN ('admin', 'production_manager', 'shift_manager', 'engineer', 'operator', 'maintenance', 'quality', 'viewer');\" | xargs | grep -q '^0$'" \
        required
    
    run_check "Andon event priorities are valid" \
        "psql \"$DATABASE_URL\" -t -c \"SELECT COUNT(*) FROM factory_telemetry.andon_events WHERE priority NOT IN ('low', 'medium', 'high', 'critical');\" | xargs | grep -q '^0$'" \
        required
    
    run_check "Job assignment statuses are valid" \
        "psql \"$DATABASE_URL\" -t -c \"SELECT COUNT(*) FROM factory_telemetry.job_assignments WHERE status NOT IN ('pending', 'accepted', 'in_progress', 'completed', 'cancelled');\" | xargs | grep -q '^0$'" \
        required
}

# Performance validation checks
validate_performance() {
    log "=== PERFORMANCE VALIDATION ==="
    
    # Check for missing indexes on frequently queried columns
    run_check "Index on users.username exists" \
        "psql \"$DATABASE_URL\" -t -c \"SELECT 1 FROM pg_indexes WHERE tablename = 'users' AND indexname LIKE '%username%';\" | xargs | grep -q '1'" \
        warning
    
    run_check "Index on andon_events.created_at exists" \
        "psql \"$DATABASE_URL\" -t -c \"SELECT 1 FROM pg_indexes WHERE tablename = 'andon_events' AND indexname LIKE '%created_at%';\" | xargs | grep -q '1'" \
        warning
    
    run_check "Index on job_assignments.status exists" \
        "psql \"$DATABASE_URL\" -t -c \"SELECT 1 FROM pg_indexes WHERE tablename = 'job_assignments' AND indexname LIKE '%status%';\" | xargs | grep -q '1'" \
        warning
    
    # Check database statistics are up to date
    run_check "Database statistics are recent" \
        "psql \"$DATABASE_URL\" -t -c \"SELECT 1 FROM pg_stat_user_tables WHERE schemaname = 'factory_telemetry' AND last_autoanalyze > NOW() - INTERVAL '7 days';\" | head -1 | xargs | grep -q '1'" \
        warning
}

# Security validation checks
validate_security() {
    log "=== SECURITY VALIDATION ==="
    
    # Check for default passwords (basic check)
    run_check "No default passwords in users table" \
        "psql \"$DATABASE_URL\" -t -c \"SELECT COUNT(*) FROM factory_telemetry.users WHERE password_hash = 'default' OR password_hash = 'password' OR password_hash = 'admin';\" | xargs | grep -q '^0$'" \
        warning
    
    # Check for proper permissions
    run_check "Appropriate user permissions" \
        "psql \"$DATABASE_URL\" -t -c \"SELECT 1 FROM information_schema.role_table_grants WHERE table_schema = 'factory_telemetry' AND privilege_type = 'SELECT';\" | head -1 | xargs | grep -q '1'" \
        warning
    
    # Check for sensitive data encryption (basic check)
    run_check "Password hashes are not plain text" \
        "psql \"$DATABASE_URL\" -t -c \"SELECT COUNT(*) FROM factory_telemetry.users WHERE password_hash = username OR LENGTH(password_hash) < 32;\" | xargs | grep -q '^0$'" \
        warning
}

# Migration history validation
validate_migration_history() {
    log "=== MIGRATION HISTORY VALIDATION ==="
    
    # Check if migration history table exists
    run_check "Migration history table exists" \
        "psql \"$DATABASE_URL\" -t -c \"SELECT 1 FROM information_schema.tables WHERE table_name = 'migration_history';\" | xargs | grep -q '1'" \
        warning
    
    if psql "$DATABASE_URL" -t -c "SELECT 1 FROM information_schema.tables WHERE table_name = 'migration_history';" | xargs | grep -q "1"; then
        # Check for expected migrations
        local expected_migrations=(
            "001_init_telemetry.sql"
            "002_plc_equipment_management.sql"
            "003_production_management.sql"
            "004_advanced_production_features.sql"
            "005_andon_escalation_system.sql"
            "006_report_system.sql"
            "007_plc_integration_phase1.sql"
            "008_fix_critical_schema_issues.sql"
        )
        
        for migration in "${expected_migrations[@]}"; do
            run_check "Migration applied: $migration" \
                "psql \"$DATABASE_URL\" -t -c \"SELECT 1 FROM migration_history WHERE migration_file = '$migration';\" | xargs | grep -q '1'" \
                warning
        done
    fi
}

# Main validation function
main() {
    log "Starting database validation with level: $VALIDATION_LEVEL"
    
    # Always run schema validation
    validate_schema
    
    if [ "$VALIDATION_LEVEL" = "full" ]; then
        validate_data_integrity
        validate_performance
        validate_security
        validate_migration_history
    elif [ "$VALIDATION_LEVEL" = "basic" ]; then
        validate_data_integrity
    fi
    
    # Summary
    log "=== VALIDATION SUMMARY ==="
    log "Total checks: $total_checks"
    log_success "Passed: $passed_checks"
    if [ $failed_checks -gt 0 ]; then
        log_error "Failed: $failed_checks"
    else
        log "Failed: $failed_checks"
    fi
    if [ $warning_checks -gt 0 ]; then
        log_warning "Warnings: $warning_checks"
    else
        log "Warnings: $warning_checks"
    fi
    
    log "Validation log: $LOG_FILE"
    
    if [ $failed_checks -gt 0 ]; then
        log_error "Database validation failed with $failed_checks critical errors"
        exit 1
    else
        log_success "Database validation completed successfully"
        exit 0
    fi
}

# Help function
show_help() {
    echo "MS5.0 Floor Dashboard - Database Validation Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -l, --level LEVEL   Validation level: basic, full (default: full)"
    echo ""
    echo "Environment Variables:"
    echo "  DATABASE_URL        PostgreSQL connection string (required)"
    echo "  VALIDATION_LEVEL    Validation level: basic, full (default: full)"
    echo ""
    echo "Validation Levels:"
    echo "  basic              Schema and data integrity checks only"
    echo "  full               All checks including performance and security"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Full validation"
    echo "  $0 -l basic                           # Basic validation only"
    echo "  DATABASE_URL=postgresql://... $0      # Validate with custom database"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -l|--level)
            VALIDATION_LEVEL="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate validation level
if [[ ! "$VALIDATION_LEVEL" =~ ^(basic|full)$ ]]; then
    log_error "Invalid validation level: $VALIDATION_LEVEL (must be 'basic' or 'full')"
    exit 1
fi

# Run main function
main
