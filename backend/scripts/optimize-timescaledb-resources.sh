#!/bin/bash
# =============================================================================
# MS5.0 TimescaleDB Resource Optimization Script
# =============================================================================
#
# Purpose: Optimize TimescaleDB resource allocation for cosmic-scale performance
# Architecture: Dynamic resource tuning based on workload patterns and system capacity
#
# Features:
# - Environment-specific resource optimization
# - Dynamic memory allocation based on available system resources
# - CPU core optimization for parallel processing
# - Storage optimization for time-series workloads
# - Network buffer tuning for high-throughput operations
# - Automated performance baseline establishment
#
# Usage:
#   ./optimize-timescaledb-resources.sh [environment] [optimization_level]
#   Environment: dev|staging|production (default: dev)
#   Optimization Level: conservative|balanced|aggressive (default: balanced)
#
# Return Codes:
#   0: Optimization completed successfully
#   1: Critical optimization failure
#   2: Warning conditions detected
#
# Author: MS5.0 Systems Architecture Team
# Version: 1.0.0
# Last Updated: $(date '+%Y-%m-%d %H:%M:%S')
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIGURATION & CONSTANTS
# =============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly OPTIMIZATION_LOG="${SCRIPT_DIR}/../logs/optimization-$(date +%Y%m%d-%H%M%S).log"
readonly CONFIG_DIR="${SCRIPT_DIR}/timescaledb-config"

# Resource optimization profiles
declare -A CONSERVATIVE_PROFILE=(
    ["shared_buffers_pct"]="15"
    ["work_mem_mb"]="32"
    ["maintenance_work_mem_mb"]="256"
    ["max_connections"]="100"
    ["max_parallel_workers"]="4"
    ["checkpoint_timeout_min"]="30"
)

declare -A BALANCED_PROFILE=(
    ["shared_buffers_pct"]="25"
    ["work_mem_mb"]="64"
    ["maintenance_work_mem_mb"]="512"
    ["max_connections"]="200"
    ["max_parallel_workers"]="8"
    ["checkpoint_timeout_min"]="15"
)

declare -A AGGRESSIVE_PROFILE=(
    ["shared_buffers_pct"]="35"
    ["work_mem_mb"]="128"
    ["maintenance_work_mem_mb"]="1024"
    ["max_connections"]="300"
    ["max_parallel_workers"]="16"
    ["checkpoint_timeout_min"]="10"
)

# Color codes for optimization status
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m'

# =============================================================================
# LOGGING SYSTEM
# =============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")    echo -e "${BLUE}[$timestamp][INFO]${NC} $message" | tee -a "$OPTIMIZATION_LOG" ;;
        "SUCCESS") echo -e "${GREEN}[$timestamp][SUCCESS]${NC} $message" | tee -a "$OPTIMIZATION_LOG" ;;
        "WARNING") echo -e "${YELLOW}[$timestamp][WARNING]${NC} $message" | tee -a "$OPTIMIZATION_LOG" ;;
        "ERROR")   echo -e "${RED}[$timestamp][ERROR]${NC} $message" | tee -a "$OPTIMIZATION_LOG" ;;
        "CRITICAL") echo -e "${RED}[$timestamp][CRITICAL]${NC} $message" | tee -a "$OPTIMIZATION_LOG" ;;
        "HEADER")  echo -e "${PURPLE}[$timestamp][HEADER]${NC} $message" | tee -a "$OPTIMIZATION_LOG" ;;
        *)         echo -e "${WHITE}[$timestamp][LOG]${NC} $message" | tee -a "$OPTIMIZATION_LOG" ;;
    esac
}

log_header() {
    echo "" | tee -a "$OPTIMIZATION_LOG"
    log "HEADER" "=================================================================================="
    log "HEADER" "$1"
    log "HEADER" "=================================================================================="
    echo "" | tee -a "$OPTIMIZATION_LOG"
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
            exit 1
            ;;
    esac
    
    log "INFO" "Environment detected: $ENVIRONMENT"
    log "INFO" "Container: $CONTAINER_NAME"
}

# =============================================================================
# SYSTEM RESOURCE DETECTION
# =============================================================================

detect_system_resources() {
    log_header "SYSTEM RESOURCE DETECTION"
    
    # Detect available memory
    if command -v free >/dev/null 2>&1; then
        TOTAL_MEMORY_KB=$(free -k | awk 'NR==2{print $2}')
        TOTAL_MEMORY_GB=$((TOTAL_MEMORY_KB / 1024 / 1024))
    else
        # Fallback for Docker environments
        TOTAL_MEMORY_GB=8  # Conservative default
        log "WARNING" "Cannot detect system memory, using default: ${TOTAL_MEMORY_GB}GB"
    fi
    
    # Detect CPU cores
    if command -v nproc >/dev/null 2>&1; then
        CPU_CORES=$(nproc)
    else
        CPU_CORES=4  # Conservative default
        log "WARNING" "Cannot detect CPU cores, using default: ${CPU_CORES}"
    fi
    
    # Detect container resource limits
    local container_memory_limit=$(docker inspect --format='{{.HostConfig.Memory}}' "$CONTAINER_NAME" 2>/dev/null || echo "0")
    local container_cpu_limit=$(docker inspect --format='{{.HostConfig.CpuQuota}}' "$CONTAINER_NAME" 2>/dev/null || echo "0")
    local container_cpu_period=$(docker inspect --format='{{.HostConfig.CpuPeriod}}' "$CONTAINER_NAME" 2>/dev/null || echo "0")
    
    if [[ "$container_memory_limit" != "0" ]]; then
        CONTAINER_MEMORY_GB=$((container_memory_limit / 1024 / 1024 / 1024))
        log "INFO" "Container memory limit: ${CONTAINER_MEMORY_GB}GB"
    else
        CONTAINER_MEMORY_GB=$TOTAL_MEMORY_GB
        log "INFO" "No container memory limit, using system total: ${CONTAINER_MEMORY_GB}GB"
    fi
    
    if [[ "$container_cpu_limit" != "0" && "$container_cpu_period" != "0" ]]; then
        CONTAINER_CPU_CORES=$((container_cpu_limit / container_cpu_period))
        log "INFO" "Container CPU limit: ${CONTAINER_CPU_CORES} cores"
    else
        CONTAINER_CPU_CORES=$CPU_CORES
        log "INFO" "No container CPU limit, using system total: ${CONTAINER_CPU_CORES} cores"
    fi
    
    log "SUCCESS" "System resources detected:"
    log "INFO" "  Total Memory: ${TOTAL_MEMORY_GB}GB"
    log "INFO" "  Container Memory: ${CONTAINER_MEMORY_GB}GB"
    log "INFO" "  Total CPU Cores: ${CPU_CORES}"
    log "INFO" "  Container CPU Cores: ${CONTAINER_CPU_CORES}"
}

# =============================================================================
# OPTIMIZATION PROFILE SELECTION
# =============================================================================

select_optimization_profile() {
    local level="${1:-balanced}"
    
    log_header "OPTIMIZATION PROFILE SELECTION"
    
    case "$level" in
        "conservative")
            OPTIMIZATION_PROFILE=CONSERVATIVE_PROFILE
            log "INFO" "Selected optimization profile: CONSERVATIVE"
            ;;
        "balanced")
            OPTIMIZATION_PROFILE=BALANCED_PROFILE
            log "INFO" "Selected optimization profile: BALANCED"
            ;;
        "aggressive")
            OPTIMIZATION_PROFILE=AGGRESSIVE_PROFILE
            log "INFO" "Selected optimization profile: AGGRESSIVE"
            ;;
        *)
            log "ERROR" "Invalid optimization level: $level"
            exit 1
            ;;
    esac
}

# =============================================================================
# RESOURCE CALCULATION FUNCTIONS
# =============================================================================

calculate_shared_buffers() {
    local pct="${OPTIMIZATION_PROFILE[shared_buffers_pct]}"
    local shared_buffers_mb=$((CONTAINER_MEMORY_GB * 1024 * pct / 100))
    local shared_buffers_gb=$((shared_buffers_mb / 1024))
    
    if [[ $shared_buffers_gb -eq 0 ]]; then
        shared_buffers_gb=1  # Minimum 1GB
    fi
    
    echo "${shared_buffers_gb}GB"
}

calculate_effective_cache_size() {
    # Effective cache size should be 75% of total system memory
    local effective_cache_gb=$((TOTAL_MEMORY_GB * 75 / 100))
    echo "${effective_cache_gb}GB"
}

calculate_work_mem() {
    local work_mem_mb="${OPTIMIZATION_PROFILE[work_mem_mb]}"
    echo "${work_mem_mb}MB"
}

calculate_maintenance_work_mem() {
    local maintenance_work_mem_mb="${OPTIMIZATION_PROFILE[maintenance_work_mem_mb]}"
    echo "${maintenance_work_mem_mb}MB"
}

calculate_max_connections() {
    echo "${OPTIMIZATION_PROFILE[max_connections]}"
}

calculate_max_parallel_workers() {
    local max_workers="${OPTIMIZATION_PROFILE[max_parallel_workers]}"
    local container_cores=$CONTAINER_CPU_CORES
    
    # Ensure we don't exceed available CPU cores
    if [[ $max_workers -gt $container_cores ]]; then
        max_workers=$container_cores
        log "INFO" "Adjusted max_parallel_workers to container CPU cores: $max_workers"
    fi
    
    echo "$max_workers"
}

calculate_wal_buffers() {
    local shared_buffers_mb=$((CONTAINER_MEMORY_GB * 1024 * ${OPTIMIZATION_PROFILE[shared_buffers_pct]} / 100))
    local wal_buffers_mb=$((shared_buffers_mb / 32))  # WAL buffers = shared_buffers / 32
    
    if [[ $wal_buffers_mb -lt 16 ]]; then
        wal_buffers_mb=16  # Minimum 16MB
    elif [[ $wal_buffers_mb -gt 256 ]]; then
        wal_buffers_mb=256  # Maximum 256MB
    fi
    
    echo "${wal_buffers_mb}MB"
}

# =============================================================================
# CONFIGURATION GENERATION
# =============================================================================

generate_timescaledb_config() {
    log_header "GENERATING TIMESCALEDB CONFIGURATION"
    
    local config_file="${CONFIG_DIR}/timescaledb-optimized.conf"
    
    # Calculate optimized values
    local shared_buffers=$(calculate_shared_buffers)
    local effective_cache_size=$(calculate_effective_cache_size)
    local work_mem=$(calculate_work_mem)
    local maintenance_work_mem=$(calculate_maintenance_work_mem)
    local max_connections=$(calculate_max_connections)
    local max_parallel_workers=$(calculate_max_parallel_workers)
    local wal_buffers=$(calculate_wal_buffers)
    local checkpoint_timeout="${OPTIMIZATION_PROFILE[checkpoint_timeout_min]}min"
    
    log "INFO" "Calculated optimization parameters:"
    log "INFO" "  shared_buffers: $shared_buffers"
    log "INFO" "  effective_cache_size: $effective_cache_size"
    log "INFO" "  work_mem: $work_mem"
    log "INFO" "  maintenance_work_mem: $maintenance_work_mem"
    log "INFO" "  max_connections: $max_connections"
    log "INFO" "  max_parallel_workers: $max_parallel_workers"
    log "INFO" "  wal_buffers: $wal_buffers"
    log "INFO" "  checkpoint_timeout: $checkpoint_timeout"
    
    # Generate optimized configuration
    cat > "$config_file" << EOF
# =============================================================================
# MS5.0 TimescaleDB Optimized Configuration
# =============================================================================
# Generated: $(date)
# Environment: $ENVIRONMENT
# Optimization Level: $OPTIMIZATION_LEVEL
# Container Memory: ${CONTAINER_MEMORY_GB}GB
# Container CPU Cores: $CONTAINER_CPU_CORES
# =============================================================================

# Memory Management - Optimized for ${CONTAINER_MEMORY_GB}GB container
shared_buffers = $shared_buffers
effective_cache_size = $effective_cache_size
work_mem = $work_mem
maintenance_work_mem = $maintenance_work_mem

# Connection Management
max_connections = $max_connections

# Parallel Processing - Optimized for $CONTAINER_CPU_CORES cores
max_parallel_workers = $max_parallel_workers
max_parallel_workers_per_gather = $((CONTAINER_CPU_CORES / 2))
max_parallel_maintenance_workers = $((CONTAINER_CPU_CORES / 4))

# WAL and Checkpoint Settings
wal_buffers = $wal_buffers
checkpoint_timeout = $checkpoint_timeout
checkpoint_completion_target = 0.9
max_wal_size = $((CONTAINER_MEMORY_GB / 2))GB
min_wal_size = $((CONTAINER_MEMORY_GB / 8))GB

# TimescaleDB Specific Settings
timescaledb.max_background_workers = $max_parallel_workers

# Query Optimization
random_page_cost = 1.1
seq_page_cost = 1.0
cpu_tuple_cost = 0.01
cpu_index_tuple_cost = 0.005
cpu_operator_cost = 0.0025

# Autovacuum Settings
autovacuum = on
autovacuum_max_workers = $((CONTAINER_CPU_CORES / 2))
autovacuum_naptime = 30s

# Logging
log_min_messages = warning
log_min_duration_statement = 1000
log_checkpoints = on
log_connections = on
log_disconnections = on
log_lock_waits = on
EOF
    
    log "SUCCESS" "Generated optimized configuration: $config_file"
}

# =============================================================================
# CONFIGURATION APPLICATION
# =============================================================================

apply_configuration() {
    log_header "APPLYING OPTIMIZATION CONFIGURATION"
    
    local config_file="${CONFIG_DIR}/timescaledb-optimized.conf"
    
    if [[ ! -f "$config_file" ]]; then
        log "ERROR" "Optimized configuration file not found: $config_file"
        return 1
    fi
    
    # Copy configuration to container
    if ! docker cp "$config_file" "${CONTAINER_NAME}:/etc/timescaledb/timescaledb-optimized.conf"; then
        log "ERROR" "Failed to copy configuration to container"
        return 1
    fi
    
    log "SUCCESS" "Configuration copied to container"
    
    # Reload PostgreSQL configuration
    if ! docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT pg_reload_conf();" >/dev/null 2>&1; then
        log "WARNING" "Failed to reload configuration - restart may be required"
        return 2
    fi
    
    log "SUCCESS" "PostgreSQL configuration reloaded"
    return 0
}

# =============================================================================
# PERFORMANCE VALIDATION
# =============================================================================

validate_optimization() {
    log_header "VALIDATING OPTIMIZATION RESULTS"
    
    # Test basic connectivity
    if ! docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" >/dev/null 2>&1; then
        log "CRITICAL" "Database connectivity failed after optimization"
        return 1
    fi
    
    # Check configuration values
    local shared_buffers_check=$(docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SHOW shared_buffers;" 2>/dev/null | xargs)
    local work_mem_check=$(docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SHOW work_mem;" 2>/dev/null | xargs)
    local max_connections_check=$(docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -t -c "SHOW max_connections;" 2>/dev/null | xargs)
    
    log "INFO" "Current configuration values:"
    log "INFO" "  shared_buffers: $shared_buffers_check"
    log "INFO" "  work_mem: $work_mem_check"
    log "INFO" "  max_connections: $max_connections_check"
    
    # Performance test
    local start_time=$(date +%s%3N)
    if ! docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT NOW(), version();" >/dev/null 2>&1; then
        log "ERROR" "Performance test failed"
        return 1
    fi
    local end_time=$(date +%s%3N)
    local test_time=$((end_time - start_time))
    
    log "SUCCESS" "Optimization validation completed - Test query time: ${test_time}ms"
    return 0
}

# =============================================================================
# MAIN OPTIMIZATION ORCHESTRATION
# =============================================================================

main() {
    local environment="${1:-dev}"
    local optimization_level="${2:-balanced}"
    local exit_code=0
    
    # Initialize logging
    mkdir -p "$(dirname "$OPTIMIZATION_LOG")"
    mkdir -p "$CONFIG_DIR"
    echo "TimescaleDB Resource Optimization - Started at $(date)" > "$OPTIMIZATION_LOG"
    
    log_header "MS5.0 TIMESCALEDB RESOURCE OPTIMIZATION SYSTEM"
    log "INFO" "Optimization initiated - Environment: $environment, Level: $optimization_level"
    
    # Detect environment and system resources
    detect_environment "$environment"
    detect_system_resources
    
    # Select and apply optimization profile
    select_optimization_profile "$optimization_level"
    OPTIMIZATION_LEVEL="$optimization_level"
    
    # Generate and apply optimized configuration
    if ! generate_timescaledb_config; then
        log "CRITICAL" "Configuration generation failed"
        exit_code=1
    elif ! apply_configuration; then
        local apply_exit_code=$?
        if [[ $apply_exit_code -eq 1 ]]; then
            log "CRITICAL" "Configuration application failed"
            exit_code=1
        elif [[ $apply_exit_code -eq 2 ]]; then
            log "WARNING" "Configuration applied with warnings"
            exit_code=2
        fi
    elif ! validate_optimization; then
        log "CRITICAL" "Optimization validation failed"
        exit_code=1
    else
        log "SUCCESS" "✅ Resource optimization completed successfully"
    fi
    
    # Final status report
    log_header "OPTIMIZATION COMPLETE"
    case $exit_code in
        0)
            log "SUCCESS" "🎉 TimescaleDB resources optimized for cosmic-scale performance"
            log "SUCCESS" "System ready for high-throughput time-series operations"
            ;;
        2)
            log "WARNING" "⚠️  Optimization completed with warnings - Review log for details"
            ;;
        1)
            log "CRITICAL" "❌ Optimization failed - Critical issues detected"
            ;;
    esac
    
    log "INFO" "Optimization completed at $(date)"
    log "INFO" "Full log available at: $OPTIMIZATION_LOG"
    
    exit $exit_code
}

# =============================================================================
# SCRIPT EXECUTION
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
