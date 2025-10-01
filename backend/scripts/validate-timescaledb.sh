#!/bin/bash
# =============================================================================
# MS5.0 TimescaleDB Validation Script
# =============================================================================
# 
# Purpose: Comprehensive validation of TimescaleDB installation and configuration
# Architecture: Starship-grade validation system with zero-tolerance for failure
# 
# Features:
# - Environment-specific validation (dev/staging/production)
# - TimescaleDB extension verification
# - Performance baseline establishment
# - Resource allocation validation
# - Connection pool testing
# - Hypertable readiness verification
#
# Usage:
#   ./validate-timescaledb.sh [environment]
#   Environment: dev|staging|production (default: dev)
#
# Return Codes:
#   0: All validations passed - System ready for cosmic-scale operations
#   1: Critical validation failed - System not ready
#   2: Warning conditions detected - System functional but suboptimal
#
# Author: MS5.0 Systems Architecture Team
# Version: 1.0.0
# Last Updated: $(date '+%Y-%m-%d %H:%M:%S')
# =============================================================================

set -euo pipefail  # Fail fast, fail hard - like physics

# =============================================================================
# CONFIGURATION & CONSTANTS
# =============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="${SCRIPT_DIR}/../logs/timescaledb-validation-$(date +%Y%m%d-%H%M%S).log"
readonly TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

# Color codes for cosmic-grade output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# Validation thresholds (cosmic-scale performance requirements)
readonly MIN_MEMORY_GB=2
readonly MIN_CPU_CORES=1
readonly MAX_CONNECTION_TIME_MS=1000
readonly MIN_QUERY_PERFORMANCE_MS=100

# =============================================================================
# LOGGING SYSTEM - PRECISION OF NASA FLIGHT LOGS
# =============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local colored_message
    
    case "$level" in
        "INFO")    colored_message="${BLUE}[INFO]${NC} $message" ;;
        "SUCCESS") colored_message="${GREEN}[SUCCESS]${NC} $message" ;;
        "WARNING") colored_message="${YELLOW}[WARNING]${NC} $message" ;;
        "ERROR")   colored_message="${RED}[ERROR]${NC} $message" ;;
        "CRITICAL") colored_message="${RED}[CRITICAL]${NC} $message" ;;
        "HEADER")  colored_message="${PURPLE}[HEADER]${NC} $message" ;;
        *)         colored_message="${WHITE}[LOG]${NC} $message" ;;
    esac
    
    echo -e "$colored_message" | tee -a "$LOG_FILE"
}

log_header() {
    echo "" | tee -a "$LOG_FILE"
    log "HEADER" "=================================================================================="
    log "HEADER" "$1"
    log "HEADER" "=================================================================================="
    echo "" | tee -a "$LOG_FILE"
}

# =============================================================================
# ENVIRONMENT DETECTION & CONFIGURATION
# =============================================================================

detect_environment() {
    local env="${1:-dev}"
    
    case "$env" in
        "dev"|"development")
            ENVIRONMENT="development"
            CONTAINER_NAME="ms5_postgres"
            DB_NAME="factory_telemetry"
            DB_USER="ms5_user"
            DB_PASSWORD="ms5_password"
            ;;
        "staging")
            ENVIRONMENT="staging"
            CONTAINER_NAME="ms5_postgres_staging"
            DB_NAME="factory_telemetry_staging"
            DB_USER="ms5_user_staging"
            DB_PASSWORD="${POSTGRES_PASSWORD_STAGING:-ms5_password}"
            ;;
        "production"|"prod")
            ENVIRONMENT="production"
            CONTAINER_NAME="ms5_postgres_production"
            DB_NAME="factory_telemetry"
            DB_USER="ms5_user_production"
            DB_PASSWORD="${POSTGRES_PASSWORD_PRODUCTION:-ms5_password}"
            ;;
        *)
            log "ERROR" "Invalid environment: $env"
            log "INFO" "Valid environments: dev, staging, production"
            exit 1
            ;;
    esac
    
    log "INFO" "Environment detected: $ENVIRONMENT"
    log "INFO" "Container: $CONTAINER_NAME"
    log "INFO" "Database: $DB_NAME"
    log "INFO" "User: $DB_USER"
}

# =============================================================================
# VALIDATION FUNCTIONS - EACH ONE A PRECISION INSTRUMENT
# =============================================================================

validate_container_running() {
    log_header "CONTAINER STATUS VALIDATION"
    
    if ! docker ps --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        log "CRITICAL" "Container $CONTAINER_NAME is not running"
        return 1
    fi
    
    local container_status=$(docker inspect --format='{{.State.Status}}' "$CONTAINER_NAME")
    if [[ "$container_status" != "running" ]]; then
        log "CRITICAL" "Container $CONTAINER_NAME is in state: $container_status"
        return 1
    fi
    
    log "SUCCESS" "Container $CONTAINER_NAME is running and healthy"
    return 0
}

validate_timescaledb_extension() {
    log_header "TIMESCALEDB EXTENSION VALIDATION"
    
    local query="SELECT extname, extversion, extrelocatable FROM pg_extension WHERE extname = 'timescaledb';"
    local result
    
    if ! result=$(docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -t -c "$query" 2>/dev/null); then
        log "CRITICAL" "Failed to connect to database or execute TimescaleDB query"
        return 1
    fi
    
    if [[ -z "$result" || "$result" =~ ^[[:space:]]*$ ]]; then
        log "CRITICAL" "TimescaleDB extension not found in database"
        return 1
    fi
    
    local version=$(echo "$result" | awk '{print $2}')
    log "SUCCESS" "TimescaleDB extension found - Version: $version"
    
    # Verify extension is properly loaded
    local hypertables_query="SELECT count(*) FROM timescaledb_information.hypertables;"
    if ! docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -t -c "$hypertables_query" >/dev/null 2>&1; then
        log "WARNING" "TimescaleDB information schema not accessible"
        return 2
    fi
    
    log "SUCCESS" "TimescaleDB information schema accessible"
    return 0
}

validate_database_connectivity() {
    log_header "DATABASE CONNECTIVITY VALIDATION"
    
    local start_time=$(date +%s%3N)
    
    if ! docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" >/dev/null 2>&1; then
        log "CRITICAL" "Cannot connect to database"
        return 1
    fi
    
    local end_time=$(date +%s%3N)
    local connection_time=$((end_time - start_time))
    
    if [[ $connection_time -gt $MAX_CONNECTION_TIME_MS ]]; then
        log "WARNING" "Database connection time ($connection_time ms) exceeds threshold ($MAX_CONNECTION_TIME_MS ms)"
        return 2
    fi
    
    log "SUCCESS" "Database connectivity verified - Connection time: ${connection_time}ms"
    return 0
}

validate_resource_allocation() {
    log_header "RESOURCE ALLOCATION VALIDATION"
    
    # Check container resource limits
    local memory_limit=$(docker inspect --format='{{.HostConfig.Memory}}' "$CONTAINER_NAME")
    local cpu_limit=$(docker inspect --format='{{.HostConfig.CpuQuota}}' "$CONTAINER_NAME")
    local cpu_period=$(docker inspect --format='{{.HostConfig.CpuPeriod}}' "$CONTAINER_NAME")
    
    if [[ "$memory_limit" != "0" ]]; then
        local memory_gb=$((memory_limit / 1024 / 1024 / 1024))
        log "INFO" "Memory limit: ${memory_gb}GB"
        
        if [[ $memory_gb -lt $MIN_MEMORY_GB ]]; then
            log "WARNING" "Memory allocation (${memory_gb}GB) below recommended minimum (${MIN_MEMORY_GB}GB)"
        else
            log "SUCCESS" "Memory allocation adequate"
        fi
    else
        log "WARNING" "No memory limit set - may cause resource contention"
    fi
    
    if [[ "$cpu_limit" != "0" && "$cpu_period" != "0" ]]; then
        local cpu_cores=$((cpu_limit / cpu_period))
        log "INFO" "CPU limit: ${cpu_cores} cores"
        
        if [[ $cpu_cores -lt $MIN_CPU_CORES ]]; then
            log "WARNING" "CPU allocation (${cpu_cores} cores) below recommended minimum (${MIN_CPU_CORES} cores)"
        else
            log "SUCCESS" "CPU allocation adequate"
        fi
    else
        log "WARNING" "No CPU limit set - may cause resource contention"
    fi
    
    return 0
}

validate_performance_baseline() {
    log_header "PERFORMANCE BASELINE VALIDATION"
    
    # Test basic query performance
    local test_query="SELECT NOW(), version(), current_setting('timescaledb.version');"
    local start_time=$(date +%s%3N)
    
    if ! docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -t -c "$test_query" >/dev/null 2>&1; then
        log "ERROR" "Performance test query failed"
        return 1
    fi
    
    local end_time=$(date +%s%3N)
    local query_time=$((end_time - start_time))
    
    if [[ $query_time -gt $MIN_QUERY_PERFORMANCE_MS ]]; then
        log "WARNING" "Query performance ($query_time ms) slower than baseline ($MIN_QUERY_PERFORMANCE_MS ms)"
        return 2
    fi
    
    log "SUCCESS" "Performance baseline established - Query time: ${query_time}ms"
    return 0
}

validate_schema_readiness() {
    log_header "SCHEMA READINESS VALIDATION"
    
    # Check if factory_telemetry schema exists
    local schema_query="SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'factory_telemetry';"
    local schema_exists
    
    if ! schema_exists=$(docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -t -c "$schema_query" 2>/dev/null); then
        log "WARNING" "Cannot check schema existence"
        return 2
    fi
    
    if [[ -z "$schema_exists" || "$schema_exists" =~ ^[[:space:]]*$ ]]; then
        log "WARNING" "factory_telemetry schema not found - migrations may be required"
        return 2
    fi
    
    log "SUCCESS" "factory_telemetry schema found"
    
    # Check for hypertables
    local hypertable_query="SELECT hypertable_name FROM timescaledb_information.hypertables WHERE hypertable_schema = 'factory_telemetry';"
    local hypertables
    
    if hypertables=$(docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -t -c "$hypertable_query" 2>/dev/null); then
        local count=$(echo "$hypertables" | grep -c "metric_hist\|oee_calculations\|energy_consumption\|production_kpis" || true)
        if [[ $count -gt 0 ]]; then
            log "SUCCESS" "Found $count TimescaleDB hypertables in factory_telemetry schema"
        else
            log "WARNING" "No TimescaleDB hypertables found - migrations may be required"
        fi
    else
        log "WARNING" "Cannot check for existing hypertables"
    fi
    
    return 0
}

# =============================================================================
# MAIN VALIDATION ORCHESTRATION
# =============================================================================

main() {
    local environment="${1:-dev}"
    local exit_code=0
    
    # Initialize logging
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "TimescaleDB Validation Log - Started at $TIMESTAMP" > "$LOG_FILE"
    
    log_header "MS5.0 TIMESCALEDB VALIDATION SYSTEM INITIALIZATION"
    log "INFO" "Validation started for environment: $environment"
    log "INFO" "Log file: $LOG_FILE"
    
    # Detect and configure environment
    detect_environment "$environment"
    
    # Execute validation sequence
    local validations=(
        "validate_container_running"
        "validate_database_connectivity"
        "validate_timescaledb_extension"
        "validate_resource_allocation"
        "validate_performance_baseline"
        "validate_schema_readiness"
    )
    
    for validation in "${validations[@]}"; do
        log "INFO" "Executing: $validation"
        if ! $validation; then
            local validation_exit_code=$?
            if [[ $validation_exit_code -eq 1 ]]; then
                log "CRITICAL" "Validation failed: $validation"
                exit_code=1
                break  # Stop on critical failure
            elif [[ $validation_exit_code -eq 2 ]]; then
                log "WARNING" "Validation warning: $validation"
                exit_code=2
            fi
        fi
    done
    
    # Final status report
    log_header "VALIDATION COMPLETE"
    case $exit_code in
        0)
            log "SUCCESS" "🎉 All validations passed - System ready for cosmic-scale operations"
            log "SUCCESS" "TimescaleDB is properly configured and ready for Phase 2 migration"
            ;;
        2)
            log "WARNING" "⚠️  System functional but with warnings - Review log for details"
            log "INFO" "System ready for Phase 2 migration with monitoring"
            ;;
        1)
            log "CRITICAL" "❌ Critical validation failures detected - System not ready"
            log "ERROR" "Must resolve critical issues before proceeding to Phase 2"
            ;;
    esac
    
    log "INFO" "Validation completed at $(date '+%Y-%m-%d %H:%M:%S')"
    log "INFO" "Full log available at: $LOG_FILE"
    
    exit $exit_code
}

# =============================================================================
# SCRIPT EXECUTION
# =============================================================================

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
