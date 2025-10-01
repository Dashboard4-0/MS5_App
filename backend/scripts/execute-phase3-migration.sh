#!/bin/bash

# =============================================================================
# MS5.0 Phase 3: Database Migration Execution - Main Orchestrator
# =============================================================================
# 
# This script orchestrates the complete Phase 3 database migration execution process.
# Implements a cosmic-scale reliable migration pipeline:
# - Pre-migration validation and backup
# - Database migration execution with rollback capability
# - Post-migration validation and verification
# - Comprehensive logging and audit trail
# - System health monitoring throughout the process
#
# Designed for starship-grade reliability - every step is atomic, verified, and logged.
# =============================================================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# =============================================================================
# Configuration & Constants
# =============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly LOG_DIR="${PROJECT_ROOT}/logs/phase3"
readonly EXECUTION_LOG_FILE="$LOG_DIR/phase3-execution-$(date +%Y%m%d-%H%M%S).log"

# Script paths
readonly BACKUP_SCRIPT="${SCRIPT_DIR}/backup-pre-migration.sh"
readonly VALIDATION_SCRIPT="${SCRIPT_DIR}/pre-migration-validation.sh"
readonly MIGRATION_SCRIPT="${SCRIPT_DIR}/migration-runner.sh"
readonly POST_VALIDATION_SCRIPT="${SCRIPT_DIR}/post-migration-validation.sh"

# Database configuration
readonly DB_HOST="${DB_HOST:-localhost}"
readonly DB_PORT="${DB_PORT:-5432}"
readonly DB_NAME="${DB_NAME:-factory_telemetry}"
readonly DB_USER="${DB_USER:-ms5_user_production}"
readonly DB_PASSWORD="${POSTGRES_PASSWORD_PRODUCTION}"

# Container configuration
readonly POSTGRES_CONTAINER="ms5_postgres_production"

# Phase 3 execution steps
readonly PHASE3_STEPS=(
    "pre_validation"
    "backup_creation"
    "migration_execution"
    "post_validation"
    "system_verification"
)

# =============================================================================
# Logging System - Production Grade with Execution Tracking
# =============================================================================

# ANSI color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m'

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$EXECUTION_LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✅${NC} $1" | tee -a "$EXECUTION_LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️${NC} $1" | tee -a "$EXECUTION_LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ❌${NC} $1" | tee -a "$EXECUTION_LOG_FILE"
}

log_info() {
    echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')] ℹ️${NC} $1" | tee -a "$EXECUTION_LOG_FILE"
}

log_step() {
    echo -e "${PURPLE}[$(date '+%Y-%m-%d %H:%M:%S')] 🔄${NC} $1" | tee -a "$EXECUTION_LOG_FILE"
}

log_header() {
    echo -e "${WHITE}[$(date '+%Y-%m-%d %H:%M:%S')] 🚀${NC} $1" | tee -a "$EXECUTION_LOG_FILE"
}

# =============================================================================
# Utility Functions - Cosmic Scale Reliability
# =============================================================================

# Initialize execution environment
initialize_execution() {
    log_header "Initializing MS5.0 Phase 3 Database Migration Execution"
    log "Execution ID: phase3-$(date +%Y%m%d-%H%M%S)"
    log "Target Database: ${DB_NAME}@${DB_HOST}:${DB_PORT}"
    
    # Create log directory
    mkdir -p "$LOG_DIR"
    
    # Initialize execution log file
    cat > "$EXECUTION_LOG_FILE" << EOF
# MS5.0 Phase 3 Database Migration Execution Log
# Started: $(date '+%Y-%m-%d %H:%M:%S')
# Database: ${DB_NAME}@${DB_HOST}:${DB_PORT}
# User: ${DB_USER}
# Container: ${POSTGRES_CONTAINER}
# Execution ID: phase3-$(date +%Y%m%d-%H%M%S)

## Phase 3 Execution Plan
- Step 1: Pre-Migration Validation
- Step 2: Comprehensive Backup Creation
- Step 3: Database Migration Execution
- Step 4: Post-Migration Validation
- Step 5: System Verification

## Execution Log

EOF
    
    log_success "Execution environment initialized"
    log_info "Execution log: $EXECUTION_LOG_FILE"
}

# Verify required scripts exist and are executable
verify_script_dependencies() {
    log "Verifying script dependencies..."
    
    local missing_scripts=()
    local non_executable_scripts=()
    
    # Check required scripts
    local required_scripts=(
        "$BACKUP_SCRIPT"
        "$VALIDATION_SCRIPT"
        "$MIGRATION_SCRIPT"
        "$POST_VALIDATION_SCRIPT"
    )
    
    for script in "${required_scripts[@]}"; do
        if [[ ! -f "$script" ]]; then
            missing_scripts+=("$(basename "$script")")
        elif [[ ! -x "$script" ]]; then
            non_executable_scripts+=("$(basename "$script")")
        fi
    done
    
    if [[ ${#missing_scripts[@]} -gt 0 ]]; then
        log_error "Missing required scripts: ${missing_scripts[*]}"
        exit 1
    fi
    
    if [[ ${#non_executable_scripts[@]} -gt 0 ]]; then
        log_error "Non-executable scripts: ${non_executable_scripts[*]}"
        exit 1
    fi
    
    log_success "All required scripts are present and executable"
}

# Verify environment variables
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
    
    log_success "Environment configuration verified"
}

# Execute script with comprehensive error handling
execute_script() {
    local script_path="$1"
    local script_name="$2"
    local step_name="$3"
    
    log_step "Executing: $script_name"
    log_info "Script: $script_path"
    
    local start_time
    start_time=$(date +%s)
    
    # Execute script and capture output
    local script_output
    local script_exit_code=0
    
    if script_output=$("$script_path" 2>&1); then
        script_exit_code=$?
    else
        script_exit_code=$?
    fi
    
    local end_time
    end_time=$(date +%s)
    local execution_time=$((end_time - start_time))
    
    # Log script output
    echo "=== $script_name Output ===" >> "$EXECUTION_LOG_FILE"
    echo "$script_output" >> "$EXECUTION_LOG_FILE"
    echo "=== End $script_name Output ===" >> "$EXECUTION_LOG_FILE"
    
    if [[ $script_exit_code -eq 0 ]]; then
        log_success "$script_name completed successfully (${execution_time}s)"
        return 0
    else
        log_error "$script_name failed with exit code $script_exit_code (${execution_time}s)"
        log_error "Script output: $script_output"
        return 1
    fi
}

# Check system health before proceeding
check_system_health() {
    log "Checking system health..."
    
    # Check Docker container status
    if ! docker ps --format "table {{.Names}}" | grep -q "^${POSTGRES_CONTAINER}$"; then
        log_error "PostgreSQL container '${POSTGRES_CONTAINER}' is not running"
        log_info "Please start the container with: docker compose -f docker-compose.production.yml up -d postgres"
        return 1
    fi
    
    # Check container health
    local container_status
    container_status=$(docker inspect --format='{{.State.Health.Status}}' "${POSTGRES_CONTAINER}" 2>/dev/null || echo "unknown")
    
    case "$container_status" in
        "healthy")
            log_success "PostgreSQL container is healthy"
            ;;
        "starting")
            log_warning "PostgreSQL container is still starting up"
            ;;
        "unhealthy")
            log_error "PostgreSQL container is unhealthy"
            return 1
            ;;
        *)
            log_warning "PostgreSQL container health status unknown: ${container_status}"
            ;;
    esac
    
    # Check system resources
    local memory_mb
    memory_mb=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    local disk_space_kb
    disk_space_kb=$(df / | awk 'NR==2 {print $4}')
    local disk_space_gb=$((disk_space_kb / 1024 / 1024))
    
    log_info "System resources - Memory: ${memory_mb}MB, Disk: ${disk_space_gb}GB"
    
    if [[ $memory_mb -lt 4096 ]]; then
        log_warning "Low memory available: ${memory_mb}MB (recommended: 4GB+)"
    fi
    
    if [[ $disk_space_kb -lt 20971520 ]]; then  # 20GB
        log_warning "Low disk space available: ${disk_space_gb}GB (recommended: 20GB+)"
    fi
    
    return 0
}

# =============================================================================
# Phase 3 Execution Steps
# =============================================================================

# Step 1: Pre-Migration Validation
execute_pre_validation() {
    log_step "Phase 3 Step 1: Pre-Migration Validation"
    
    if execute_script "$VALIDATION_SCRIPT" "Pre-Migration Validation" "pre_validation"; then
        log_success "Pre-migration validation completed successfully"
        return 0
    else
        log_error "Pre-migration validation failed"
        log_error "Cannot proceed with migration without passing validation"
        return 1
    fi
}

# Step 2: Comprehensive Backup Creation
execute_backup_creation() {
    log_step "Phase 3 Step 2: Comprehensive Backup Creation"
    
    if execute_script "$BACKUP_SCRIPT" "Pre-Migration Backup" "backup_creation"; then
        log_success "Comprehensive backup creation completed successfully"
        
        # Verify backup was created
        local backup_path_file="${PROJECT_ROOT}/.last_backup_path"
        if [[ -f "$backup_path_file" ]]; then
            local backup_path
            backup_path=$(cat "$backup_path_file")
            log_info "Backup location: $backup_path"
            
            # Verify backup directory exists and has content
            if [[ -d "$backup_path" ]]; then
                local backup_size
                backup_size=$(du -sh "$backup_path" | cut -f1)
                log_success "Backup verified: $backup_size"
            else
                log_error "Backup directory not found: $backup_path"
                return 1
            fi
        else
            log_warning "Backup path file not found: $backup_path_file"
        fi
        
        return 0
    else
        log_error "Backup creation failed"
        log_error "Cannot proceed with migration without backup"
        return 1
    fi
}

# Step 3: Database Migration Execution
execute_migration() {
    log_step "Phase 3 Step 3: Database Migration Execution"
    
    # Final system health check before migration
    if ! check_system_health; then
        log_error "System health check failed before migration"
        return 1
    fi
    
    if execute_script "$MIGRATION_SCRIPT" "Database Migration Runner" "migration_execution"; then
        log_success "Database migration execution completed successfully"
        
        # Verify migration log
        local migration_count
        migration_count=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "
            SELECT COUNT(*) FROM factory_telemetry.migration_log WHERE status = 'completed';
        " 2>/dev/null | tr -d ' \n' || echo "0")
        
        if [[ "$migration_count" -gt 0 ]]; then
            log_success "Migration log verified: $migration_count completed migrations"
        else
            log_warning "No completed migrations found in migration log"
        fi
        
        return 0
    else
        log_error "Database migration execution failed"
        log_error "Migration process encountered errors"
        return 1
    fi
}

# Step 4: Post-Migration Validation
execute_post_validation() {
    log_step "Phase 3 Step 4: Post-Migration Validation"
    
    if execute_script "$POST_VALIDATION_SCRIPT" "Post-Migration Validation" "post_validation"; then
        log_success "Post-migration validation completed successfully"
        return 0
    else
        log_error "Post-migration validation failed"
        log_error "Migration may not have completed successfully"
        return 1
    fi
}

# Step 5: System Verification
execute_system_verification() {
    log_step "Phase 3 Step 5: System Verification"
    
    log_info "Performing final system verification..."
    
    # Verify TimescaleDB extension
    local timescaledb_version
    timescaledb_version=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "
        SELECT extversion FROM pg_extension WHERE extname = 'timescaledb';
    " 2>/dev/null | tr -d ' \n' || echo "UNKNOWN")
    
    if [[ -n "$timescaledb_version" && "$timescaledb_version" != "UNKNOWN" ]]; then
        log_success "TimescaleDB extension verified (version: $timescaledb_version)"
    else
        log_error "TimescaleDB extension verification failed"
        return 1
    fi
    
    # Verify hypertables
    local hypertable_count
    hypertable_count=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "
        SELECT COUNT(*) FROM timescaledb_information.hypertables WHERE schema_name = 'factory_telemetry';
    " 2>/dev/null | tr -d ' \n' || echo "0")
    
    if [[ "$hypertable_count" -gt 0 ]]; then
        log_success "TimescaleDB hypertables verified: $hypertable_count tables"
    else
        log_warning "No TimescaleDB hypertables found"
    fi
    
    # Verify container health
    local container_status
    container_status=$(docker inspect --format='{{.State.Health.Status}}' "${POSTGRES_CONTAINER}" 2>/dev/null || echo "unknown")
    
    if [[ "$container_status" == "healthy" ]]; then
        log_success "PostgreSQL container health verified"
    else
        log_warning "PostgreSQL container health status: $container_status"
    fi
    
    # Final database connectivity test
    if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" >/dev/null 2>&1; then
        log_success "Final database connectivity test passed"
    else
        log_error "Final database connectivity test failed"
        return 1
    fi
    
    log_success "System verification completed successfully"
    return 0
}

# =============================================================================
# Rollback Functions
# =============================================================================

# Execute rollback procedure
execute_rollback() {
    log_error "Executing rollback procedure..."
    
    # Check if backup exists
    local backup_path_file="${PROJECT_ROOT}/.last_backup_path"
    if [[ -f "$backup_path_file" ]]; then
        local backup_path
        backup_path=$(cat "$backup_path_file")
        
        if [[ -d "$backup_path" ]]; then
            log_info "Backup found: $backup_path"
            log_info "To restore from backup, run:"
            log_info "  docker compose -f docker-compose.production.yml down"
            log_info "  docker volume rm ms5-backend_postgres_data_production"
            log_info "  docker compose -f docker-compose.production.yml up -d postgres"
            log_info "  sleep 30"
            log_info "  PGPASSWORD=\$POSTGRES_PASSWORD_PRODUCTION psql -h localhost -p 5432 -U ms5_user_production -d factory_telemetry < ${backup_path}/database/full_backup.sql"
        else
            log_error "Backup directory not found: $backup_path"
        fi
    else
        log_error "No backup path file found for rollback"
    fi
    
    log_error "Manual rollback required - please follow the instructions above"
}

# =============================================================================
# Report Generation
# =============================================================================

# Generate final execution report
generate_execution_report() {
    log "Generating final execution report..."
    
    local report_file="$LOG_DIR/phase3-execution-report-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$report_file" << EOF
# MS5.0 Phase 3 Database Migration Execution Report
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
# Execution ID: phase3-$(date +%Y%m%d-%H%M%S)

## Execution Summary
- Database: ${DB_NAME}@${DB_HOST}:${DB_PORT}
- User: ${DB_USER}
- Container: ${POSTGRES_CONTAINER}
- Total Steps: ${#PHASE3_STEPS[@]}
- Execution Log: $EXECUTION_LOG_FILE

## Step Results
EOF

    # Append execution log to report
    echo "=== Execution Log ===" >> "$report_file"
    cat "$EXECUTION_LOG_FILE" >> "$report_file"
    
    cat >> "$report_file" << EOF

## Database Status
- TimescaleDB Version: $(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT extversion FROM pg_extension WHERE extname = 'timescaledb';" 2>/dev/null | tr -d ' \n' || echo "UNKNOWN")
- Hypertable Count: $(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM timescaledb_information.hypertables WHERE schema_name = 'factory_telemetry';" 2>/dev/null | tr -d ' \n' || echo "0")
- Migration Count: $(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM factory_telemetry.migration_log WHERE status = 'completed';" 2>/dev/null | tr -d ' \n' || echo "0")

## System Information
- Hostname: $(hostname)
- Operating System: $(uname -s) $(uname -r)
- Docker Version: $(docker --version 2>/dev/null || echo "Not available")
- Container Status: $(docker inspect --format='{{.State.Health.Status}}' "${POSTGRES_CONTAINER}" 2>/dev/null || echo "unknown")

EOF
    
    log_success "Execution report generated: $report_file"
    echo "$report_file"
}

# =============================================================================
# Main Execution Function
# =============================================================================

main() {
    local execution_start_time
    execution_start_time=$(date +%s)
    
    # Initialize execution
    initialize_execution
    
    # Verify prerequisites
    verify_script_dependencies
    verify_environment
    
    # Track execution results
    local execution_failed=false
    local failed_step=""
    
    # Execute Phase 3 steps in order
    log_header "Starting Phase 3 Database Migration Execution"
    
    # Step 1: Pre-Migration Validation
    if ! execute_pre_validation; then
        execution_failed=true
        failed_step="pre_validation"
    fi
    
    # Step 2: Comprehensive Backup Creation
    if [[ "$execution_failed" == "false" ]] && ! execute_backup_creation; then
        execution_failed=true
        failed_step="backup_creation"
    fi
    
    # Step 3: Database Migration Execution
    if [[ "$execution_failed" == "false" ]] && ! execute_migration; then
        execution_failed=true
        failed_step="migration_execution"
    fi
    
    # Step 4: Post-Migration Validation
    if [[ "$execution_failed" == "false" ]] && ! execute_post_validation; then
        execution_failed=true
        failed_step="post_validation"
    fi
    
    # Step 5: System Verification
    if [[ "$execution_failed" == "false" ]] && ! execute_system_verification; then
        execution_failed=true
        failed_step="system_verification"
    fi
    
    # Calculate total execution time
    local execution_end_time
    execution_end_time=$(date +%s)
    local total_execution_time=$((execution_end_time - execution_start_time))
    
    # Generate final report
    local report_file
    report_file=$(generate_execution_report)
    
    # Final result
    if [[ "$execution_failed" == "true" ]]; then
        log_error "❌ Phase 3 Database Migration Execution FAILED"
        log_error "Failed at step: $failed_step"
        log_error "Total execution time: ${total_execution_time}s"
        log_error "Execution report: $report_file"
        log_error "Execution log: $EXECUTION_LOG_FILE"
        
        # Execute rollback if migration failed
        if [[ "$failed_step" == "migration_execution" || "$failed_step" == "post_validation" ]]; then
            execute_rollback
        fi
        
        exit 1
    else
        log_success "🎉 Phase 3 Database Migration Execution COMPLETED SUCCESSFULLY!"
        log_success "Total execution time: ${total_execution_time}s"
        log_success "Execution report: $report_file"
        log_success "Execution log: $EXECUTION_LOG_FILE"
        log_success "Database is ready for production use"
        
        exit 0
    fi
}

# =============================================================================
# Script Execution
# =============================================================================

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
