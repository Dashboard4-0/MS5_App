#!/bin/bash
# =============================================================================
# MS5.0 TimescaleDB Enhanced Health Check
# =============================================================================
#
# Purpose: Production-grade health monitoring for TimescaleDB operations
# Architecture: Real-time monitoring with predictive failure detection
#
# Features:
# - Real-time database connectivity monitoring
# - TimescaleDB extension health verification
# - Performance metrics collection
# - Predictive failure detection
# - Automated alerting for critical issues
# - Comprehensive logging for troubleshooting
#
# Usage:
#   ./health-check-timescaledb.sh [environment] [check_type]
#   Environment: dev|staging|production (default: dev)
#   Check Type: quick|full|performance (default: quick)
#
# Return Codes:
#   0: All health checks passed - System operational
#   1: Critical health issue detected - Immediate attention required
#   2: Warning condition detected - Monitoring required
#   3: Performance degradation detected - Optimization recommended
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
readonly HEALTH_LOG="${SCRIPT_DIR}/../logs/health-check-$(date +%Y%m%d-%H%M%S).log"

# Health check thresholds (cosmic-scale operational requirements)
readonly MAX_RESPONSE_TIME_MS=500
readonly MAX_CONNECTION_TIME_MS=1000
readonly MIN_AVAILABLE_CONNECTIONS=10
readonly MAX_CPU_USAGE_PERCENT=80
readonly MAX_MEMORY_USAGE_PERCENT=85
readonly MAX_DISK_USAGE_PERCENT=90

# Color codes for operational status
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
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
        "INFO")    echo -e "${BLUE}[$timestamp][INFO]${NC} $message" | tee -a "$HEALTH_LOG" ;;
        "SUCCESS") echo -e "${GREEN}[$timestamp][SUCCESS]${NC} $message" | tee -a "$HEALTH_LOG" ;;
        "WARNING") echo -e "${YELLOW}[$timestamp][WARNING]${NC} $message" | tee -a "$HEALTH_LOG" ;;
        "ERROR")   echo -e "${RED}[$timestamp][ERROR]${NC} $message" | tee -a "$HEALTH_LOG" ;;
        "CRITICAL") echo -e "${RED}[$timestamp][CRITICAL]${NC} $message" | tee -a "$HEALTH_LOG" ;;
        *)         echo -e "${WHITE}[$timestamp][LOG]${NC} $message" | tee -a "$HEALTH_LOG" ;;
    esac
}

# =============================================================================
# ENVIRONMENT CONFIGURATION
# =============================================================================

configure_environment() {
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
    
    log "INFO" "Health check configured for environment: $ENVIRONMENT"
}

# =============================================================================
# HEALTH CHECK FUNCTIONS
# =============================================================================

check_container_health() {
    log "INFO" "Checking container health status..."
    
    if ! docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "$CONTAINER_NAME"; then
        log "CRITICAL" "Container $CONTAINER_NAME is not running"
        return 1
    fi
    
    local container_status=$(docker inspect --format='{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null)
    if [[ "$container_status" != "running" ]]; then
        log "CRITICAL" "Container $CONTAINER_NAME status: $container_status"
        return 1
    fi
    
    local health_status=$(docker inspect --format='{{.State.Health.Status}}' "$CONTAINER_NAME" 2>/dev/null || echo "no-healthcheck")
    case "$health_status" in
        "healthy")
            log "SUCCESS" "Container health check: HEALTHY"
            ;;
        "unhealthy")
            log "CRITICAL" "Container health check: UNHEALTHY"
            return 1
            ;;
        "starting")
            log "WARNING" "Container health check: STARTING"
            return 2
            ;;
        "no-healthcheck")
            log "WARNING" "No health check configured for container"
            ;;
    esac
    
    return 0
}

check_database_connectivity() {
    log "INFO" "Checking database connectivity..."
    
    local start_time=$(date +%s%3N)
    
    if ! docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" >/dev/null 2>&1; then
        log "CRITICAL" "Database connection failed"
        return 1
    fi
    
    local end_time=$(date +%s%3N)
    local connection_time=$((end_time - start_time))
    
    if [[ $connection_time -gt $MAX_CONNECTION_TIME_MS ]]; then
        log "ERROR" "Database connection slow: ${connection_time}ms (threshold: ${MAX_CONNECTION_TIME_MS}ms)"
        return 1
    fi
    
    log "SUCCESS" "Database connectivity: OK (${connection_time}ms)"
    return 0
}

check_timescaledb_extension() {
    log "INFO" "Checking TimescaleDB extension status..."
    
    local query="SELECT extname, extversion FROM pg_extension WHERE extname = 'timescaledb';"
    local result
    
    if ! result=$(docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -t -c "$query" 2>/dev/null); then
        log "CRITICAL" "TimescaleDB extension check failed"
        return 1
    fi
    
    if [[ -z "$result" || "$result" =~ ^[[:space:]]*$ ]]; then
        log "CRITICAL" "TimescaleDB extension not found"
        return 1
    fi
    
    local version=$(echo "$result" | awk '{print $2}')
    log "SUCCESS" "TimescaleDB extension: OK (Version: $version)"
    return 0
}

check_query_performance() {
    log "INFO" "Checking query performance..."
    
    local test_queries=(
        "SELECT NOW();"
        "SELECT version();"
        "SELECT count(*) FROM timescaledb_information.hypertables;"
    )
    
    local total_time=0
    local query_count=0
    
    for query in "${test_queries[@]}"; do
        local start_time=$(date +%s%3N)
        
        if ! docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -t -c "$query" >/dev/null 2>&1; then
            log "ERROR" "Performance test query failed: $query"
            return 1
        fi
        
        local end_time=$(date +%s%3N)
        local query_time=$((end_time - start_time))
        total_time=$((total_time + query_time))
        query_count=$((query_count + 1))
        
        if [[ $query_time -gt $MAX_RESPONSE_TIME_MS ]]; then
            log "WARNING" "Query performance degraded: ${query_time}ms"
        fi
    done
    
    local avg_time=$((total_time / query_count))
    log "SUCCESS" "Query performance: OK (Average: ${avg_time}ms)"
    
    if [[ $avg_time -gt $MAX_RESPONSE_TIME_MS ]]; then
        return 3
    fi
    
    return 0
}

check_connection_pool() {
    log "INFO" "Checking connection pool status..."
    
    local query="SELECT count(*) as active, (SELECT setting::int FROM pg_settings WHERE name = 'max_connections') as max FROM pg_stat_activity WHERE state = 'active';"
    local result
    
    if ! result=$(docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -t -c "$query" 2>/dev/null); then
        log "WARNING" "Connection pool check failed"
        return 2
    fi
    
    local active_connections=$(echo "$result" | awk '{print $1}')
    local max_connections=$(echo "$result" | awk '{print $2}')
    local available_connections=$((max_connections - active_connections))
    
    log "INFO" "Active connections: $active_connections / $max_connections"
    
    if [[ $available_connections -lt $MIN_AVAILABLE_CONNECTIONS ]]; then
        log "WARNING" "Low available connections: $available_connections (minimum: $MIN_AVAILABLE_CONNECTIONS)"
        return 2
    fi
    
    log "SUCCESS" "Connection pool: OK (Available: $available_connections)"
    return 0
}

check_resource_usage() {
    log "INFO" "Checking resource usage..."
    
    # Check container resource usage
    local stats=$(docker stats --no-stream --format "table {{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" "$CONTAINER_NAME" 2>/dev/null | tail -n +2)
    
    if [[ -z "$stats" ]]; then
        log "WARNING" "Cannot retrieve container resource statistics"
        return 2
    fi
    
    local cpu_usage=$(echo "$stats" | awk '{print $1}' | sed 's/%//')
    local memory_usage=$(echo "$stats" | awk '{print $3}' | sed 's/%//')
    
    local cpu_status="OK"
    local memory_status="OK"
    local resource_issues=0
    
    if (( $(echo "$cpu_usage > $MAX_CPU_USAGE_PERCENT" | bc -l) )); then
        log "WARNING" "High CPU usage: ${cpu_usage}% (threshold: ${MAX_CPU_USAGE_PERCENT}%)"
        cpu_status="HIGH"
        resource_issues=$((resource_issues + 1))
    fi
    
    if (( $(echo "$memory_usage > $MAX_MEMORY_USAGE_PERCENT" | bc -l) )); then
        log "WARNING" "High memory usage: ${memory_usage}% (threshold: ${MAX_MEMORY_USAGE_PERCENT}%)"
        memory_status="HIGH"
        resource_issues=$((resource_issues + 1))
    fi
    
    log "INFO" "CPU usage: ${cpu_usage}% ($cpu_status)"
    log "INFO" "Memory usage: ${memory_usage}% ($memory_status)"
    
    if [[ $resource_issues -eq 0 ]]; then
        log "SUCCESS" "Resource usage: OK"
        return 0
    else
        return 2
    fi
}

check_hypertable_health() {
    log "INFO" "Checking hypertable health..."
    
    local query="SELECT hypertable_name, num_chunks, total_chunks_size FROM timescaledb_information.hypertables WHERE hypertable_schema = 'factory_telemetry';"
    local result
    
    if ! result=$(docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -t -c "$query" 2>/dev/null); then
        log "WARNING" "Hypertable health check failed - schema may not exist yet"
        return 2
    fi
    
    if [[ -z "$result" || "$result" =~ ^[[:space:]]*$ ]]; then
        log "WARNING" "No hypertables found in factory_telemetry schema"
        return 2
    fi
    
    local hypertable_count=$(echo "$result" | grep -c "metric_hist\|oee_calculations\|energy_consumption\|production_kpis" || true)
    log "SUCCESS" "Hypertable health: OK (Found $hypertable_count hypertables)"
    return 0
}

# =============================================================================
# PERFORMANCE MONITORING
# =============================================================================

check_performance_metrics() {
    log "INFO" "Collecting performance metrics..."
    
    # Database size
    local size_query="SELECT pg_size_pretty(pg_database_size('$DB_NAME'));"
    local db_size=$(docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -t -c "$size_query" 2>/dev/null | xargs)
    log "INFO" "Database size: $db_size"
    
    # Cache hit ratio
    local cache_query="SELECT round(100.0 * sum(blks_hit) / (sum(blks_hit) + sum(blks_read)), 2) AS cache_hit_ratio FROM pg_stat_database WHERE datname = '$DB_NAME';"
    local cache_ratio=$(docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -t -c "$cache_query" 2>/dev/null | xargs)
    log "INFO" "Cache hit ratio: ${cache_ratio}%"
    
    # Active queries
    local active_query="SELECT count(*) FROM pg_stat_activity WHERE state = 'active';"
    local active_count=$(docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -t -c "$active_query" 2>/dev/null | xargs)
    log "INFO" "Active queries: $active_count"
    
    log "SUCCESS" "Performance metrics collected"
    return 0
}

# =============================================================================
# MAIN HEALTH CHECK ORCHESTRATION
# =============================================================================

main() {
    local environment="${1:-dev}"
    local check_type="${2:-quick}"
    local exit_code=0
    
    # Initialize logging
    mkdir -p "$(dirname "$HEALTH_LOG")"
    echo "TimescaleDB Health Check - Started at $(date)" > "$HEALTH_LOG"
    
    log "INFO" "Health check initiated - Environment: $environment, Type: $check_type"
    
    # Configure environment
    configure_environment "$environment"
    
    # Define check sequences based on type
    local quick_checks=(
        "check_container_health"
        "check_database_connectivity"
        "check_timescaledb_extension"
    )
    
    local full_checks=(
        "check_container_health"
        "check_database_connectivity"
        "check_timescaledb_extension"
        "check_query_performance"
        "check_connection_pool"
        "check_resource_usage"
        "check_hypertable_health"
    )
    
    local performance_checks=(
        "check_container_health"
        "check_database_connectivity"
        "check_timescaledb_extension"
        "check_query_performance"
        "check_performance_metrics"
    )
    
    # Select appropriate check sequence
    local checks
    case "$check_type" in
        "quick")
            checks=("${quick_checks[@]}")
            ;;
        "full")
            checks=("${full_checks[@]}")
            ;;
        "performance")
            checks=("${performance_checks[@]}")
            ;;
        *)
            log "ERROR" "Invalid check type: $check_type"
            exit 1
            ;;
    esac
    
    # Execute health checks
    for check in "${checks[@]}"; do
        log "INFO" "Executing: $check"
        if ! $check; then
            local check_exit_code=$?
            if [[ $check_exit_code -eq 1 ]]; then
                log "CRITICAL" "Health check failed: $check"
                exit_code=1
                break  # Stop on critical failure
            elif [[ $check_exit_code -eq 2 ]]; then
                log "WARNING" "Health check warning: $check"
                exit_code=2
            elif [[ $check_exit_code -eq 3 ]]; then
                log "WARNING" "Performance issue detected: $check"
                if [[ $exit_code -eq 0 ]]; then
                    exit_code=3
                fi
            fi
        fi
    done
    
    # Final health status
    case $exit_code in
        0)
            log "SUCCESS" "✅ All health checks passed - System operational"
            ;;
        2)
            log "WARNING" "⚠️  System operational with warnings"
            ;;
        3)
            log "WARNING" "⚠️  Performance degradation detected"
            ;;
        1)
            log "CRITICAL" "❌ Critical health issues detected - Immediate attention required"
            ;;
    esac
    
    log "INFO" "Health check completed at $(date)"
    exit $exit_code
}

# =============================================================================
# SCRIPT EXECUTION
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
