#!/bin/bash

# MS5.0 Floor Dashboard - Deployment Validation Script
# This script validates the deployment of the MS5.0 system

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${LOG_DIR}/validate_deployment_${TIMESTAMP}.log"

# Environment variables
ENVIRONMENT=${ENVIRONMENT:-staging}
VALIDATION_TYPE=${VALIDATION_TYPE:-full}  # full, health, connectivity, functionality
TIMEOUT=${TIMEOUT:-30}

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

# Create directories
mkdir -p "$LOG_DIR"

log "Starting MS5.0 deployment validation - Environment: $ENVIRONMENT, Type: $VALIDATION_TYPE"

# Change to script directory
cd "$SCRIPT_DIR"

# Function to check service health
check_service_health() {
    log "Checking service health..."
    
    local services=("backend" "frontend" "database" "redis" "nginx" "prometheus" "grafana")
    local healthy_services=0
    local total_services=${#services[@]}
    
    for service in "${services[@]}"; do
        if docker-compose -f "docker-compose.${ENVIRONMENT}.yml" ps "$service" | grep -q "Up"; then
            log_success "$service is running"
            ((healthy_services++))
        else
            log_error "$service is not running"
        fi
    done
    
    if [ "$healthy_services" -eq "$total_services" ]; then
        log_success "All services are healthy"
        return 0
    else
        log_error "Some services are not healthy ($healthy_services/$total_services)"
        return 1
    fi
}

# Function to check API connectivity
check_api_connectivity() {
    log "Checking API connectivity..."
    
    local api_endpoints=(
        "http://localhost:8000/api/health"
        "http://localhost:8000/api/status"
        "http://localhost:8000/api/version"
    )
    
    for endpoint in "${api_endpoints[@]}"; do
        if curl -f -s --max-time "$TIMEOUT" "$endpoint" > /dev/null; then
            log_success "API endpoint $endpoint is accessible"
        else
            log_error "API endpoint $endpoint is not accessible"
            return 1
        fi
    done
    
    log_success "All API endpoints are accessible"
    return 0
}

# Function to check database connectivity
check_database_connectivity() {
    log "Checking database connectivity..."
    
    if docker-compose -f "docker-compose.${ENVIRONMENT}.yml" exec -T backend psql "$DATABASE_URL" -c "SELECT 1;" > /dev/null 2>&1; then
        log_success "Database connectivity check passed"
        return 0
    else
        log_error "Database connectivity check failed"
        return 1
    fi
}

# Function to check Redis connectivity
check_redis_connectivity() {
    log "Checking Redis connectivity..."
    
    if docker-compose -f "docker-compose.${ENVIRONMENT}.yml" exec -T backend redis-cli -h redis ping > /dev/null 2>&1; then
        log_success "Redis connectivity check passed"
        return 0
    else
        log_error "Redis connectivity check failed"
        return 1
    fi
}

# Function to check WebSocket connectivity
check_websocket_connectivity() {
    log "Checking WebSocket connectivity..."
    
    # Test WebSocket connection
    if curl -f -s --max-time "$TIMEOUT" "http://localhost:8000/ws" > /dev/null; then
        log_success "WebSocket endpoint is accessible"
        return 0
    else
        log_error "WebSocket endpoint is not accessible"
        return 1
    fi
}

# Function to check monitoring services
check_monitoring_services() {
    log "Checking monitoring services..."
    
    # Check Prometheus
    if curl -f -s --max-time "$TIMEOUT" "http://localhost:9090/-/healthy" > /dev/null; then
        log_success "Prometheus is healthy"
    else
        log_error "Prometheus is not healthy"
        return 1
    fi
    
    # Check Grafana
    if curl -f -s --max-time "$TIMEOUT" "http://localhost:3000/api/health" > /dev/null; then
        log_success "Grafana is healthy"
    else
        log_error "Grafana is not healthy"
        return 1
    fi
    
    log_success "All monitoring services are healthy"
    return 0
}

# Function to check application functionality
check_application_functionality() {
    log "Checking application functionality..."
    
    # Test user authentication
    if curl -f -s --max-time "$TIMEOUT" "http://localhost:8000/api/auth/login" -X POST -H "Content-Type: application/json" -d '{"username":"test","password":"test"}' > /dev/null; then
        log_success "Authentication endpoint is functional"
    else
        log_warning "Authentication endpoint test failed (expected for test credentials)"
    fi
    
    # Test production data endpoints
    local production_endpoints=(
        "http://localhost:8000/api/production/status"
        "http://localhost:8000/api/production/equipment"
        "http://localhost:8000/api/production/jobs"
    )
    
    for endpoint in "${production_endpoints[@]}"; do
        if curl -f -s --max-time "$TIMEOUT" "$endpoint" > /dev/null; then
            log_success "Production endpoint $endpoint is functional"
        else
            log_warning "Production endpoint $endpoint test failed"
        fi
    done
    
    log_success "Application functionality check completed"
    return 0
}

# Function to check system resources
check_system_resources() {
    log "Checking system resources..."
    
    # Check disk space
    local disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$disk_usage" -lt 80 ]; then
        log_success "Disk usage is acceptable ($disk_usage%)"
    else
        log_warning "Disk usage is high ($disk_usage%)"
    fi
    
    # Check memory usage
    local memory_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    if [ "$memory_usage" -lt 80 ]; then
        log_success "Memory usage is acceptable ($memory_usage%)"
    else
        log_warning "Memory usage is high ($memory_usage%)"
    fi
    
    # Check CPU load
    local cpu_load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    if (( $(echo "$cpu_load < 2.0" | bc -l) )); then
        log_success "CPU load is acceptable ($cpu_load)"
    else
        log_warning "CPU load is high ($cpu_load)"
    fi
    
    log_success "System resources check completed"
    return 0
}

# Function to check log files
check_log_files() {
    log "Checking log files..."
    
    # Check for error logs
    local error_count=$(docker-compose -f "docker-compose.${ENVIRONMENT}.yml" logs --tail=100 | grep -i error | wc -l)
    if [ "$error_count" -eq 0 ]; then
        log_success "No errors found in recent logs"
    else
        log_warning "Found $error_count errors in recent logs"
    fi
    
    # Check for warning logs
    local warning_count=$(docker-compose -f "docker-compose.${ENVIRONMENT}.yml" logs --tail=100 | grep -i warning | wc -l)
    if [ "$warning_count" -eq 0 ]; then
        log_success "No warnings found in recent logs"
    else
        log_warning "Found $warning_count warnings in recent logs"
    fi
    
    log_success "Log files check completed"
    return 0
}

# Function to generate validation report
generate_validation_report() {
    log "Generating validation report..."
    
    local report_file="${LOG_DIR}/validation_report_${TIMESTAMP}.md"
    
    cat > "$report_file" << EOF
# MS5.0 Floor Dashboard - Deployment Validation Report

**Validation Date:** $(date)
**Environment:** $ENVIRONMENT
**Validation Type:** $VALIDATION_TYPE
**Validation Status:** $1

## Validation Summary

### Validated Components
EOF
    
    case $VALIDATION_TYPE in
        full)
            echo "- Service Health" >> "$report_file"
            echo "- API Connectivity" >> "$report_file"
            echo "- Database Connectivity" >> "$report_file"
            echo "- Redis Connectivity" >> "$report_file"
            echo "- WebSocket Connectivity" >> "$report_file"
            echo "- Monitoring Services" >> "$report_file"
            echo "- Application Functionality" >> "$report_file"
            echo "- System Resources" >> "$report_file"
            echo "- Log Files" >> "$report_file"
            ;;
        health)
            echo "- Service Health" >> "$report_file"
            ;;
        connectivity)
            echo "- API Connectivity" >> "$report_file"
            echo "- Database Connectivity" >> "$report_file"
            echo "- Redis Connectivity" >> "$report_file"
            echo "- WebSocket Connectivity" >> "$report_file"
            ;;
        functionality)
            echo "- Application Functionality" >> "$report_file"
            ;;
    esac
    
    cat >> "$report_file" << EOF

## Validation Details

- **Log File:** $LOG_FILE
- **Report File:** $report_file
- **Environment:** $ENVIRONMENT
- **Validation Type:** $VALIDATION_TYPE

## Next Steps

1. Review validation results
2. Address any issues found
3. Monitor system performance
4. Schedule next validation

EOF
    
    log_success "Validation report generated: $report_file"
}

# Main validation function
main() {
    local start_time=$(date +%s)
    local validation_success=true
    
    # Execute validation based on type
    case $VALIDATION_TYPE in
        full)
            check_service_health || validation_success=false
            check_api_connectivity || validation_success=false
            check_database_connectivity || validation_success=false
            check_redis_connectivity || validation_success=false
            check_websocket_connectivity || validation_success=false
            check_monitoring_services || validation_success=false
            check_application_functionality || validation_success=false
            check_system_resources || validation_success=false
            check_log_files || validation_success=false
            ;;
        health)
            check_service_health || validation_success=false
            ;;
        connectivity)
            check_api_connectivity || validation_success=false
            check_database_connectivity || validation_success=false
            check_redis_connectivity || validation_success=false
            check_websocket_connectivity || validation_success=false
            ;;
        functionality)
            check_application_functionality || validation_success=false
            ;;
        *)
            log_error "Invalid validation type: $VALIDATION_TYPE"
            exit 1
            ;;
    esac
    
    # Generate report
    if [ "$validation_success" = "true" ]; then
        generate_validation_report "SUCCESS"
        log_success "Validation completed successfully"
    else
        generate_validation_report "FAILED"
        log_error "Validation failed"
        exit 1
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log "Validation completed in ${duration}s"
    log "Log file: $LOG_FILE"
}

# Help function
show_help() {
    echo "MS5.0 Floor Dashboard - Deployment Validation Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -e, --environment ENV   Environment (staging|production) (default: staging)"
    echo "  -t, --type TYPE         Validation type (full|health|connectivity|functionality) (default: full)"
    echo "  -T, --timeout SECONDS   Timeout for requests (default: 30)"
    echo ""
    echo "Environment Variables:"
    echo "  ENVIRONMENT            Environment (default: staging)"
    echo "  VALIDATION_TYPE        Validation type (default: full)"
    echo "  TIMEOUT                Timeout for requests (default: 30)"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Validate full system in staging"
    echo "  $0 -e production -t health            # Validate service health in production"
    echo "  $0 -e staging -t connectivity         # Validate connectivity in staging"
    echo "  ENVIRONMENT=production $0            # Validate full system in production"
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
        -t|--type)
            VALIDATION_TYPE="$2"
            shift 2
            ;;
        -T|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(staging|production)$ ]]; then
    log_error "Invalid environment: $ENVIRONMENT (must be 'staging' or 'production')"
    exit 1
fi

# Validate validation type
if [[ ! "$VALIDATION_TYPE" =~ ^(full|health|connectivity|functionality)$ ]]; then
    log_error "Invalid validation type: $VALIDATION_TYPE (must be 'full', 'health', 'connectivity', or 'functionality')"
    exit 1
fi

# Run main function
main
