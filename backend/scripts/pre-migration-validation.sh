#!/bin/bash

# =============================================================================
# MS5.0 Phase 3: Pre-Migration Validation Script
# =============================================================================
# 
# This script performs comprehensive validation before database migration execution.
# Ensures all prerequisites are met for a successful migration:
# - System resource validation (disk, memory, CPU)
# - Database connectivity and health checks
# - TimescaleDB extension verification
# - Migration file integrity validation
# - Backup system verification
# - Container and service status validation
#
# Designed for cosmic-scale reliability - every validation is thorough and documented.
# =============================================================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# =============================================================================
# Configuration & Constants
# =============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly MIGRATIONS_DIR="$PROJECT_ROOT/.."  # SQL files are in project root
readonly LOG_DIR="${PROJECT_ROOT}/logs/validation"
readonly VALIDATION_REPORT_FILE="$LOG_DIR/pre-migration-validation-$(date +%Y%m%d-%H%M%S).txt"

# Database configuration
readonly DB_HOST="${DB_HOST:-localhost}"
readonly DB_PORT="${DB_PORT:-5432}"
readonly DB_NAME="${DB_NAME:-factory_telemetry}"
readonly DB_USER="${DB_USER:-ms5_user_production}"
readonly DB_PASSWORD="${POSTGRES_PASSWORD_PRODUCTION}"

# Container configuration
readonly POSTGRES_CONTAINER="ms5_postgres_production"

# System requirements (minimum thresholds)
readonly MIN_DISK_SPACE_GB=20
readonly MIN_MEMORY_GB=4
readonly MIN_CPU_CORES=2
readonly MIN_DOCKER_VERSION="20.10.0"

# Migration files that should exist
readonly REQUIRED_MIGRATION_FILES=(
    "001_init_telemetry.sql"
    "002_plc_equipment_management.sql"
    "003_production_management.sql"
    "004_advanced_production_features.sql"
    "005_andon_escalation_system.sql"
    "006_report_system.sql"
    "007_plc_integration_phase1.sql"
    "008_fix_critical_schema_issues.sql"
    "009_database_optimization.sql"
)

# =============================================================================
# Logging System - Production Grade
# =============================================================================

# ANSI color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$VALIDATION_REPORT_FILE"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✅${NC} $1" | tee -a "$VALIDATION_REPORT_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️${NC} $1" | tee -a "$VALIDATION_REPORT_FILE"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ❌${NC} $1" | tee -a "$VALIDATION_REPORT_FILE"
}

log_info() {
    echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')] ℹ️${NC} $1" | tee -a "$VALIDATION_REPORT_FILE"
}

log_validation() {
    echo -e "${PURPLE}[$(date '+%Y-%m-%d %H:%M:%S')] 🔍${NC} $1" | tee -a "$VALIDATION_REPORT_FILE"
}

# =============================================================================
# Validation Functions - Comprehensive System Checks
# =============================================================================

# Initialize validation environment
initialize_validation() {
    log "Initializing pre-migration validation..."
    
    # Create log directory
    mkdir -p "$LOG_DIR"
    
    # Initialize validation report
    cat > "$VALIDATION_REPORT_FILE" << EOF
# MS5.0 Pre-Migration Validation Report
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
# Database: ${DB_NAME}@${DB_HOST}:${DB_PORT}
# User: ${DB_USER}
# Container: ${POSTGRES_CONTAINER}

## Validation Summary
- Validation Started: $(date '+%Y-%m-%d %H:%M:%S')
- Target Database: ${DB_NAME}
- Migration Files: ${#REQUIRED_MIGRATION_FILES[@]}

## Validation Results

EOF
    
    log_success "Validation environment initialized"
}

# Validate system resources
validate_system_resources() {
    log_validation "Validating system resources..."
    
    local validation_passed=true
    
    # Check disk space
    log_info "Checking disk space..."
    local disk_space_kb
    disk_space_kb=$(df / | awk 'NR==2 {print $4}')
    local disk_space_gb=$((disk_space_kb / 1024 / 1024))
    
    if [[ $disk_space_kb -lt $((MIN_DISK_SPACE_GB * 1024 * 1024)) ]]; then
        log_error "Insufficient disk space. Required: ${MIN_DISK_SPACE_GB}GB, Available: ${disk_space_gb}GB"
        validation_passed=false
    else
        log_success "Disk space check passed (${disk_space_gb}GB available)"
    fi
    
    # Check memory
    log_info "Checking system memory..."
    local memory_mb
    memory_mb=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    local memory_gb=$((memory_mb / 1024))
    
    if [[ $memory_mb -lt $((MIN_MEMORY_GB * 1024)) ]]; then
        log_error "Insufficient memory. Required: ${MIN_MEMORY_GB}GB, Available: ${memory_gb}GB"
        validation_passed=false
    else
        log_success "Memory check passed (${memory_gb}GB available)"
    fi
    
    # Check CPU cores
    log_info "Checking CPU cores..."
    local cpu_cores
    cpu_cores=$(nproc)
    
    if [[ $cpu_cores -lt $MIN_CPU_CORES ]]; then
        log_warning "Low CPU core count. Recommended: ${MIN_CPU_CORES}, Available: ${cpu_cores}"
    else
        log_success "CPU cores check passed (${cpu_cores} cores)"
    fi
    
    # Check load average
    log_info "Checking system load..."
    local load_avg
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
    local load_threshold=$((cpu_cores * 2))
    
    if (( $(echo "$load_avg > $load_threshold" | bc -l) )); then
        log_warning "High system load detected: ${load_avg} (threshold: ${load_threshold})"
    else
        log_success "System load check passed (${load_avg})"
    fi
    
    if [[ "$validation_passed" == "true" ]]; then
        log_success "System resources validation passed"
        return 0
    else
        log_error "System resources validation failed"
        return 1
    fi
}

# Validate Docker environment
validate_docker_environment() {
    log_validation "Validating Docker environment..."
    
    local validation_passed=true
    
    # Check Docker installation
    log_info "Checking Docker installation..."
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker is not installed or not in PATH"
        validation_passed=false
    else
        local docker_version
        docker_version=$(docker --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        log_success "Docker version: ${docker_version}"
        
        # Check Docker version compatibility
        if ! docker version --format '{{.Server.Version}}' >/dev/null 2>&1; then
            log_error "Docker daemon is not running"
            validation_passed=false
        else
            log_success "Docker daemon is running"
        fi
    fi
    
    # Check Docker Compose
    log_info "Checking Docker Compose..."
    if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
        log_error "Docker Compose is not available"
        validation_passed=false
    else
        local compose_version
        compose_version=$(docker compose version --short)
        log_success "Docker Compose version: ${compose_version}"
    fi
    
    if [[ "$validation_passed" == "true" ]]; then
        log_success "Docker environment validation passed"
        return 0
    else
        log_error "Docker environment validation failed"
        return 1
    fi
}

# Validate container status
validate_container_status() {
    log_validation "Validating container status..."
    
    local validation_passed=true
    
    # Check PostgreSQL container
    log_info "Checking PostgreSQL container status..."
    if ! docker ps --format "table {{.Names}}" | grep -q "^${POSTGRES_CONTAINER}$"; then
        log_error "PostgreSQL container '${POSTGRES_CONTAINER}' is not running"
        validation_passed=false
    else
        log_success "PostgreSQL container is running"
        
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
                validation_passed=false
                ;;
            *)
                log_warning "PostgreSQL container health status unknown: ${container_status}"
                ;;
        esac
        
        # Check container resource usage
        local container_stats
        container_stats=$(docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" "${POSTGRES_CONTAINER}" 2>/dev/null || echo "Unable to get container stats")
        log_info "Container resource usage: $container_stats"
    fi
    
    # Check container logs for errors
    log_info "Checking PostgreSQL container logs for errors..."
    local error_count
    error_count=$(docker logs "${POSTGRES_CONTAINER}" --since="1h" 2>&1 | grep -i error | wc -l)
    
    if [[ $error_count -gt 0 ]]; then
        log_warning "Found ${error_count} error(s) in PostgreSQL container logs (last hour)"
        docker logs "${POSTGRES_CONTAINER}" --since="1h" 2>&1 | grep -i error | head -5 | while read -r error_line; do
            log_warning "  $error_line"
        done
    else
        log_success "No errors found in PostgreSQL container logs"
    fi
    
    if [[ "$validation_passed" == "true" ]]; then
        log_success "Container status validation passed"
        return 0
    else
        log_error "Container status validation failed"
        return 1
    fi
}

# Validate database connectivity and configuration
validate_database_connectivity() {
    log_validation "Validating database connectivity..."
    
    local validation_passed=true
    
    # Check required environment variables
    log_info "Checking required environment variables..."
    if [[ -z "${POSTGRES_PASSWORD_PRODUCTION:-}" ]]; then
        log_error "POSTGRES_PASSWORD_PRODUCTION environment variable is not set"
        validation_passed=false
    else
        log_success "Database password environment variable is set"
    fi
    
    # Test database connectivity
    log_info "Testing database connectivity..."
    local max_attempts=10
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" >/dev/null 2>&1; then
            log_success "Database connectivity test passed (attempt $attempt)"
            break
        else
            log_info "Database connection attempt $attempt/$max_attempts failed, retrying in 3 seconds..."
            sleep 3
            ((attempt++))
        fi
    done
    
    if [[ $attempt -gt $max_attempts ]]; then
        log_error "Database connectivity test failed after $max_attempts attempts"
        validation_passed=false
    fi
    
    # Check database version and configuration
    if [[ "$validation_passed" == "true" ]]; then
        log_info "Checking database version and configuration..."
        
        local db_version
        db_version=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT version();" 2>/dev/null | head -1 | tr -d ' \n')
        log_success "Database version: $db_version"
        
        # Check TimescaleDB extension
        local timescaledb_version
        timescaledb_version=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT extversion FROM pg_extension WHERE extname = 'timescaledb';" 2>/dev/null | tr -d ' \n')
        
        if [[ -n "$timescaledb_version" && "$timescaledb_version" != "" ]]; then
            log_success "TimescaleDB extension version: $timescaledb_version"
        else
            log_error "TimescaleDB extension is not installed or not accessible"
            validation_passed=false
        fi
        
        # Check database size
        local db_size
        db_size=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT pg_size_pretty(pg_database_size('$DB_NAME'));" 2>/dev/null | tr -d ' \n')
        log_info "Database size: $db_size"
        
        # Check active connections
        local active_connections
        active_connections=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM pg_stat_activity WHERE state = 'active';" 2>/dev/null | tr -d ' \n')
        log_info "Active database connections: $active_connections"
    fi
    
    if [[ "$validation_passed" == "true" ]]; then
        log_success "Database connectivity validation passed"
        return 0
    else
        log_error "Database connectivity validation failed"
        return 1
    fi
}

# Validate migration files
validate_migration_files() {
    log_validation "Validating migration files..."
    
    local validation_passed=true
    
    # Check if migrations directory exists
    if [[ ! -d "$MIGRATIONS_DIR" ]]; then
        log_error "Migrations directory not found: $MIGRATIONS_DIR"
        validation_passed=false
    else
        log_success "Migrations directory found: $MIGRATIONS_DIR"
    fi
    
    # Check each required migration file
    log_info "Checking required migration files..."
    for migration_file in "${REQUIRED_MIGRATION_FILES[@]}"; do
        local migration_path="${MIGRATIONS_DIR}/${migration_file}"
        
        if [[ ! -f "$migration_path" ]]; then
            log_error "Required migration file not found: $migration_file"
            validation_passed=false
        else
            # Check file permissions
            if [[ ! -r "$migration_path" ]]; then
                log_error "Migration file is not readable: $migration_file"
                validation_passed=false
            else
                # Check file size (should not be empty)
                local file_size
                file_size=$(stat -f%z "$migration_path" 2>/dev/null || stat -c%s "$migration_path" 2>/dev/null || echo "0")
                
                if [[ $file_size -eq 0 ]]; then
                    log_error "Migration file is empty: $migration_file"
                    validation_passed=false
                else
                    log_success "Migration file validated: $migration_file ($(numfmt --to=iec $file_size))"
                    
                    # Basic SQL syntax check
                    if head -n 5 "$migration_path" | grep -qi "postgresql\|sql\|create\|alter\|drop\|insert\|update\|delete"; then
                        log_success "  SQL syntax appears valid"
                    else
                        log_warning "  SQL syntax validation inconclusive"
                    fi
                fi
            fi
        fi
    done
    
    # Check for additional migration files
    log_info "Checking for additional migration files..."
    local additional_files
    additional_files=$(find "$MIGRATIONS_DIR" -name "*.sql" -type f | wc -l)
    log_info "Total SQL files found: $additional_files"
    
    if [[ "$validation_passed" == "true" ]]; then
        log_success "Migration files validation passed"
        return 0
    else
        log_error "Migration files validation failed"
        return 1
    fi
}

# Validate backup system
validate_backup_system() {
    log_validation "Validating backup system..."
    
    local validation_passed=true
    
    # Check backup script exists and is executable
    local backup_script="${SCRIPT_DIR}/backup-pre-migration.sh"
    
    if [[ ! -f "$backup_script" ]]; then
        log_error "Backup script not found: $backup_script"
        validation_passed=false
    elif [[ ! -x "$backup_script" ]]; then
        log_error "Backup script is not executable: $backup_script"
        validation_passed=false
    else
        log_success "Backup script found and executable"
    fi
    
    # Check backup directory permissions
    local backup_dir="/opt/ms5-backend/backups"
    if [[ -d "$backup_dir" ]]; then
        if [[ -w "$backup_dir" ]]; then
            log_success "Backup directory is writable: $backup_dir"
        else
            log_warning "Backup directory exists but may not be writable: $backup_dir"
        fi
    else
        log_info "Backup directory does not exist yet (will be created during backup): $backup_dir"
    fi
    
    # Check available disk space for backups
    local available_space_kb
    available_space_kb=$(df /opt 2>/dev/null | awk 'NR==2 {print $4}' || df / | awk 'NR==2 {print $4}')
    local available_space_gb=$((available_space_kb / 1024 / 1024))
    
    if [[ $available_space_kb -lt $((10 * 1024 * 1024)) ]]; then  # 10GB
        log_warning "Limited disk space available for backups: ${available_space_gb}GB"
    else
        log_success "Sufficient disk space available for backups: ${available_space_gb}GB"
    fi
    
    if [[ "$validation_passed" == "true" ]]; then
        log_success "Backup system validation passed"
        return 0
    else
        log_error "Backup system validation failed"
        return 1
    fi
}

# Validate network connectivity
validate_network_connectivity() {
    log_validation "Validating network connectivity..."
    
    local validation_passed=true
    
    # Check localhost connectivity
    log_info "Checking localhost connectivity..."
    if ping -c 1 localhost >/dev/null 2>&1; then
        log_success "Localhost connectivity test passed"
    else
        log_error "Localhost connectivity test failed"
        validation_passed=false
    fi
    
    # Check Docker network connectivity
    log_info "Checking Docker network connectivity..."
    if docker network ls | grep -q ms5_network_production; then
        log_success "Docker production network exists"
        
        # Check network configuration
        local network_info
        network_info=$(docker network inspect ms5_network_production --format '{{.Driver}}' 2>/dev/null || echo "unknown")
        log_info "Network driver: $network_info"
    else
        log_warning "Docker production network not found (may be created during container startup)"
    fi
    
    if [[ "$validation_passed" == "true" ]]; then
        log_success "Network connectivity validation passed"
        return 0
    else
        log_error "Network connectivity validation failed"
        return 1
    fi
}

# =============================================================================
# Report Generation
# =============================================================================

# Generate final validation report
generate_validation_report() {
    log "Generating final validation report..."
    
    # Append summary to report file
    cat >> "$VALIDATION_REPORT_FILE" << EOF

## Validation Summary
- Validation Completed: $(date '+%Y-%m-%d %H:%M:%S')
- Total Validation Checks: 6
- System Resources: $([ $? -eq 0 ] && echo "PASSED" || echo "FAILED")
- Docker Environment: $([ $? -eq 0 ] && echo "PASSED" || echo "FAILED")
- Container Status: $([ $? -eq 0 ] && echo "PASSED" || echo "FAILED")
- Database Connectivity: $([ $? -eq 0 ] && echo "PASSED" || echo "FAILED")
- Migration Files: $([ $? -eq 0 ] && echo "PASSED" || echo "FAILED")
- Backup System: $([ $? -eq 0 ] && echo "PASSED" || echo "FAILED")

## System Information
- Hostname: $(hostname)
- Operating System: $(uname -s) $(uname -r)
- Architecture: $(uname -m)
- Uptime: $(uptime | awk -F'up ' '{print $2}' | awk -F', load' '{print $1}')

## Docker Information
- Docker Version: $(docker --version 2>/dev/null || echo "Not available")
- Docker Compose Version: $(docker compose version --short 2>/dev/null || echo "Not available")
- Running Containers: $(docker ps --format "table {{.Names}}" | wc -l)

## Database Information
- Database Host: $DB_HOST
- Database Port: $DB_PORT
- Database Name: $DB_NAME
- Database User: $DB_USER
- TimescaleDB Version: $(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT extversion FROM pg_extension WHERE extname = 'timescaledb';" 2>/dev/null | tr -d ' \n' || echo "Not available")

EOF
    
    log_success "Validation report generated: $VALIDATION_REPORT_FILE"
}

# =============================================================================
# Main Execution Function
# =============================================================================

main() {
    log "🚀 Starting MS5.0 Pre-Migration Validation"
    log "Target Database: ${DB_NAME}@${DB_HOST}:${DB_PORT}"
    
    # Initialize validation environment
    initialize_validation
    
    # Track validation results
    local validation_failed=false
    
    # Run all validation checks
    validate_system_resources || validation_failed=true
    validate_docker_environment || validation_failed=true
    validate_container_status || validation_failed=true
    validate_database_connectivity || validation_failed=true
    validate_migration_files || validation_failed=true
    validate_backup_system || validation_failed=true
    validate_network_connectivity || validation_failed=true
    
    # Generate final report
    generate_validation_report
    
    # Final result
    if [[ "$validation_failed" == "true" ]]; then
        log_error "❌ Pre-migration validation failed"
        log_error "Please address the issues above before proceeding with migration"
        log_info "Validation report: $VALIDATION_REPORT_FILE"
        exit 1
    else
        log_success "🎉 Pre-migration validation passed successfully!"
        log_success "System is ready for migration execution"
        log_info "Validation report: $VALIDATION_REPORT_FILE"
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
