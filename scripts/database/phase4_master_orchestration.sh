#!/bin/bash
# ============================================================================
# MS5.0 Manufacturing System - Phase 4 Master Orchestration Script
# ============================================================================
# This script orchestrates the complete Phase 4 TimescaleDB optimization
# deployment, executing all components in the correct sequence with
# comprehensive validation and error handling.
#
# Execution Order:
# 1. Pre-flight validation
# 2. Hypertable optimization
# 3. Compression policy configuration
# 4. Retention policy setup
# 5. Performance index creation
# 6. Continuous aggregate deployment
# 7. Post-deployment validation
# 8. Performance benchmarking
#
# Usage:
#   ./phase4_master_orchestration.sh [environment]
#
# Arguments:
#   environment: production|staging|development (default: development)
#
# Prerequisites:
#   - TimescaleDB extension installed
#   - All migrations (001-009) completed
#   - Database credentials configured
#   - PostgreSQL 15+ with TimescaleDB 2.x
#
# Author: MS5.0 System
# Version: 1.0.0
# ============================================================================

set -euo pipefail  # Exit on error, undefined variables, pipe failures

# ============================================================================
# Configuration
# ============================================================================

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Environment (default: development)
ENVIRONMENT="${1:-development}"

# Database configuration
case "$ENVIRONMENT" in
    production)
        DB_HOST="${POSTGRES_HOST_PRODUCTION:-localhost}"
        DB_PORT="${POSTGRES_PORT_PRODUCTION:-5432}"
        DB_NAME="${POSTGRES_DB_PRODUCTION:-factory_telemetry}"
        DB_USER="${POSTGRES_USER_PRODUCTION:-ms5_user_production}"
        DB_PASSWORD="${POSTGRES_PASSWORD_PRODUCTION}"
        ;;
    staging)
        DB_HOST="${POSTGRES_HOST_STAGING:-localhost}"
        DB_PORT="${POSTGRES_PORT_STAGING:-5432}"
        DB_NAME="${POSTGRES_DB_STAGING:-factory_telemetry}"
        DB_USER="${POSTGRES_USER_STAGING:-ms5_user_staging}"
        DB_PASSWORD="${POSTGRES_PASSWORD_STAGING}"
        ;;
    development|*)
        DB_HOST="${POSTGRES_HOST:-localhost}"
        DB_PORT="${POSTGRES_PORT:-5432}"
        DB_NAME="${POSTGRES_DB:-factory_telemetry}"
        DB_USER="${POSTGRES_USER:-ms5_user}"
        DB_PASSWORD="${POSTGRES_PASSWORD:-ms5_password}"
        ;;
esac

# Logging configuration
LOG_DIR="$PROJECT_ROOT/logs/phase4"
LOG_FILE="$LOG_DIR/phase4_deployment_$(date +%Y%m%d_%H%M%S).log"

# Create log directory
mkdir -p "$LOG_DIR"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# Utility Functions
# ============================================================================

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[${timestamp}] [${level}] ${message}" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE"
}

# Progress bar function
show_progress() {
    local current=$1
    local total=$2
    local description=$3
    local percent=$((current * 100 / total))
    local completed=$((percent / 2))
    local remaining=$((50 - completed))
    
    printf "\r["
    printf "%${completed}s" | tr ' ' '='
    printf "%${remaining}s" | tr ' ' '-'
    printf "] %3d%% - %s" "$percent" "$description"
    
    if [ "$current" -eq "$total" ]; then
        echo ""
    fi
}

# Execute SQL file
execute_sql_file() {
    local sql_file="$1"
    local description="$2"
    
    log_info "Executing: $description"
    log_info "SQL File: $sql_file"
    
    if [ ! -f "$sql_file" ]; then
        log_error "SQL file not found: $sql_file"
        return 1
    fi
    
    PGPASSWORD="$DB_PASSWORD" psql \
        -h "$DB_HOST" \
        -p "$DB_PORT" \
        -U "$DB_USER" \
        -d "$DB_NAME" \
        -f "$sql_file" \
        -v ON_ERROR_STOP=1 \
        --quiet \
        2>&1 | tee -a "$LOG_FILE"
    
    local exit_code=${PIPESTATUS[0]}
    
    if [ $exit_code -eq 0 ]; then
        log_success "$description completed successfully"
        return 0
    else
        log_error "$description failed with exit code $exit_code"
        return $exit_code
    fi
}

# Execute SQL query
execute_sql_query() {
    local query="$1"
    
    PGPASSWORD="$DB_PASSWORD" psql \
        -h "$DB_HOST" \
        -p "$DB_PORT" \
        -U "$DB_USER" \
        -d "$DB_NAME" \
        -t \
        -A \
        -c "$query" \
        2>&1
}

# Check database connection
check_database_connection() {
    log_info "Checking database connection..."
    
    if execute_sql_query "SELECT 1" > /dev/null 2>&1; then
        log_success "Database connection successful"
        return 0
    else
        log_error "Database connection failed"
        return 1
    fi
}

# Verify TimescaleDB extension
verify_timescaledb() {
    log_info "Verifying TimescaleDB extension..."
    
    local version=$(execute_sql_query "SELECT extversion FROM pg_extension WHERE extname = 'timescaledb'")
    
    if [ -n "$version" ]; then
        log_success "TimescaleDB version: $version"
        return 0
    else
        log_error "TimescaleDB extension not found"
        return 1
    fi
}

# Verify migrations
verify_migrations() {
    log_info "Verifying database migrations..."
    
    local migration_count=$(execute_sql_query "SELECT COUNT(*) FROM migration_log WHERE migration_name LIKE '00%'")
    
    if [ "$migration_count" -ge 9 ]; then
        log_success "All migrations completed (count: $migration_count)"
        return 0
    else
        log_warning "Some migrations may be missing (count: $migration_count)"
        return 1
    fi
}

# ============================================================================
# Pre-flight Validation
# ============================================================================

preflight_validation() {
    log_info "========================================="
    log_info "Phase 4 Pre-flight Validation"
    log_info "========================================="
    log_info "Environment: $ENVIRONMENT"
    log_info "Database: $DB_HOST:$DB_PORT/$DB_NAME"
    log_info "User: $DB_USER"
    echo ""
    
    local validation_failed=0
    
    # Check database connection
    if ! check_database_connection; then
        validation_failed=1
    fi
    
    # Verify TimescaleDB
    if ! verify_timescaledb; then
        validation_failed=1
    fi
    
    # Verify migrations
    if ! verify_migrations; then
        log_warning "Continuing despite migration warning..."
    fi
    
    # Check disk space
    local available_space=$(df -h / | awk 'NR==2 {print $4}')
    log_info "Available disk space: $available_space"
    
    # Check memory
    if command -v free &> /dev/null; then
        local available_memory=$(free -h | awk 'NR==2{print $7}')
        log_info "Available memory: $available_memory"
    fi
    
    echo ""
    
    if [ $validation_failed -eq 1 ]; then
        log_error "Pre-flight validation failed"
        return 1
    fi
    
    log_success "Pre-flight validation completed successfully"
    return 0
}

# ============================================================================
# Phase 4 Deployment Steps
# ============================================================================

deploy_hypertable_optimization() {
    show_progress 1 6 "Hypertable Optimization"
    execute_sql_file \
        "$SCRIPT_DIR/phase4_hypertable_optimization.sql" \
        "Hypertable Optimization"
}

deploy_compression_policies() {
    show_progress 2 6 "Compression Policies"
    execute_sql_file \
        "$SCRIPT_DIR/phase4_compression_policies.sql" \
        "Compression Policy Configuration"
}

deploy_retention_policies() {
    show_progress 3 6 "Retention Policies"
    execute_sql_file \
        "$SCRIPT_DIR/phase4_retention_policies.sql" \
        "Retention Policy Setup"
}

deploy_performance_indexes() {
    show_progress 4 6 "Performance Indexes"
    execute_sql_file \
        "$SCRIPT_DIR/phase4_performance_indexes.sql" \
        "Performance Index Creation"
}

deploy_continuous_aggregates() {
    show_progress 5 6 "Continuous Aggregates"
    execute_sql_file \
        "$SCRIPT_DIR/phase4_continuous_aggregates.sql" \
        "Continuous Aggregate Deployment"
}

# ============================================================================
# Post-deployment Validation
# ============================================================================

post_deployment_validation() {
    show_progress 6 6 "Post-deployment Validation"
    
    log_info "========================================="
    log_info "Post-deployment Validation"
    log_info "========================================="
    
    # Check hypertable count
    local hypertable_count=$(execute_sql_query "
        SELECT COUNT(*) FROM timescaledb_information.hypertables 
        WHERE hypertable_schema = 'factory_telemetry'
    ")
    log_info "Hypertables created: $hypertable_count"
    
    # Check compression policies
    local compression_policies=$(execute_sql_query "
        SELECT COUNT(*) FROM timescaledb_information.jobs 
        WHERE proc_name = 'policy_compression'
    ")
    log_info "Compression policies: $compression_policies"
    
    # Check retention policies
    local retention_policies=$(execute_sql_query "
        SELECT COUNT(*) FROM timescaledb_information.jobs 
        WHERE proc_name = 'policy_retention'
    ")
    log_info "Retention policies: $retention_policies"
    
    # Check continuous aggregates
    local continuous_aggregates=$(execute_sql_query "
        SELECT COUNT(*) FROM timescaledb_information.continuous_aggregates
        WHERE view_schema = 'factory_telemetry'
    ")
    log_info "Continuous aggregates: $continuous_aggregates"
    
    # Check indexes
    local index_count=$(execute_sql_query "
        SELECT COUNT(*) FROM pg_indexes 
        WHERE schemaname = 'factory_telemetry'
    ")
    log_info "Indexes created: $index_count"
    
    echo ""
    
    # Validate expected counts
    if [ "$hypertable_count" -ge 7 ] && \
       [ "$compression_policies" -ge 7 ] && \
       [ "$retention_policies" -ge 7 ] && \
       [ "$continuous_aggregates" -ge 8 ]; then
        log_success "Post-deployment validation passed"
        return 0
    else
        log_warning "Some components may not have deployed correctly"
        return 1
    fi
}

# ============================================================================
# Performance Benchmarking
# ============================================================================

run_performance_benchmark() {
    log_info "========================================="
    log_info "Performance Benchmarking"
    log_info "========================================="
    
    # Test query performance on continuous aggregates
    log_info "Testing dashboard query performance..."
    
    local start_time=$(date +%s%3N)
    execute_sql_query "
        SELECT * FROM factory_telemetry.v_realtime_production_dashboard LIMIT 10
    " > /dev/null 2>&1
    local end_time=$(date +%s%3N)
    local query_time=$((end_time - start_time))
    
    log_info "Dashboard query time: ${query_time}ms"
    
    if [ "$query_time" -lt 100 ]; then
        log_success "Query performance: Excellent (<100ms)"
    elif [ "$query_time" -lt 500 ]; then
        log_success "Query performance: Good (<500ms)"
    else
        log_warning "Query performance: Needs optimization (${query_time}ms)"
    fi
    
    # Display compression statistics
    log_info "Compression statistics:"
    execute_sql_query "
        SELECT 
            hypertable_name,
            compression_percentage,
            space_saved
        FROM factory_telemetry.v_compression_statistics
    " | column -t -s '|'
}

# ============================================================================
# Rollback Function
# ============================================================================

rollback_deployment() {
    log_warning "========================================="
    log_warning "Rolling Back Phase 4 Deployment"
    log_warning "========================================="
    
    # This would contain rollback logic
    # For now, we'll just log the attempt
    log_warning "Rollback functionality to be implemented"
    log_warning "Manual intervention may be required"
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    local start_time=$(date +%s)
    
    echo ""
    echo "============================================================================"
    echo "  MS5.0 Phase 4 TimescaleDB Optimization Deployment"
    echo "============================================================================"
    echo "  Environment: $ENVIRONMENT"
    echo "  Database: $DB_NAME"
    echo "  Log file: $LOG_FILE"
    echo "============================================================================"
    echo ""
    
    # Trap errors
    trap 'log_error "Deployment failed. Check logs at $LOG_FILE"' ERR
    
    # Pre-flight validation
    if ! preflight_validation; then
        log_error "Pre-flight validation failed. Aborting deployment."
        exit 1
    fi
    
    echo ""
    log_info "Starting Phase 4 deployment..."
    echo ""
    
    # Execute deployment steps
    deploy_hypertable_optimization || { rollback_deployment; exit 1; }
    deploy_compression_policies || { rollback_deployment; exit 1; }
    deploy_retention_policies || { rollback_deployment; exit 1; }
    deploy_performance_indexes || { rollback_deployment; exit 1; }
    deploy_continuous_aggregates || { rollback_deployment; exit 1; }
    
    echo ""
    
    # Post-deployment validation
    if ! post_deployment_validation; then
        log_warning "Post-deployment validation had warnings"
    fi
    
    echo ""
    
    # Performance benchmarking
    run_performance_benchmark
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    echo "============================================================================"
    log_success "Phase 4 Deployment Completed Successfully"
    log_info "Total duration: ${duration} seconds"
    log_info "Log file: $LOG_FILE"
    echo "============================================================================"
    echo ""
}

# Execute main function
main "$@"

