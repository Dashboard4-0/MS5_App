#!/bin/bash

# MS5.0 Floor Dashboard - Smoke Test Script
# This script performs smoke tests to verify basic system functionality

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${LOG_DIR}/smoke_test_${TIMESTAMP}.log"

# Environment variables
ENVIRONMENT=${ENVIRONMENT:-staging}
BASE_URL=${BASE_URL:-http://localhost:8000}
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

log "Starting MS5.0 smoke tests - Environment: $ENVIRONMENT"

# Change to script directory
cd "$SCRIPT_DIR"

# Function to test API health endpoint
test_api_health() {
    log "Testing API health endpoint..."
    
    local response=$(curl -s --max-time "$TIMEOUT" "$BASE_URL/api/health")
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "$BASE_URL/api/health")
    
    if [ "$status_code" -eq 200 ]; then
        log_success "API health endpoint returned 200 OK"
        echo "Response: $response" | tee -a "$LOG_FILE"
        return 0
    else
        log_error "API health endpoint returned $status_code"
        return 1
    fi
}

# Function to test API status endpoint
test_api_status() {
    log "Testing API status endpoint..."
    
    local response=$(curl -s --max-time "$TIMEOUT" "$BASE_URL/api/status")
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "$BASE_URL/api/status")
    
    if [ "$status_code" -eq 200 ]; then
        log_success "API status endpoint returned 200 OK"
        echo "Response: $response" | tee -a "$LOG_FILE"
        return 0
    else
        log_error "API status endpoint returned $status_code"
        return 1
    fi
}

# Function to test API version endpoint
test_api_version() {
    log "Testing API version endpoint..."
    
    local response=$(curl -s --max-time "$TIMEOUT" "$BASE_URL/api/version")
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "$BASE_URL/api/version")
    
    if [ "$status_code" -eq 200 ]; then
        log_success "API version endpoint returned 200 OK"
        echo "Response: $response" | tee -a "$LOG_FILE"
        return 0
    else
        log_error "API version endpoint returned $status_code"
        return 1
    fi
}

# Function to test database connectivity
test_database_connectivity() {
    log "Testing database connectivity..."
    
    local response=$(curl -s --max-time "$TIMEOUT" "$BASE_URL/api/database/status")
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "$BASE_URL/api/database/status")
    
    if [ "$status_code" -eq 200 ]; then
        log_success "Database connectivity test passed"
        echo "Response: $response" | tee -a "$LOG_FILE"
        return 0
    else
        log_error "Database connectivity test failed with status $status_code"
        return 1
    fi
}

# Function to test Redis connectivity
test_redis_connectivity() {
    log "Testing Redis connectivity..."
    
    local response=$(curl -s --max-time "$TIMEOUT" "$BASE_URL/api/redis/status")
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "$BASE_URL/api/redis/status")
    
    if [ "$status_code" -eq 200 ]; then
        log_success "Redis connectivity test passed"
        echo "Response: $response" | tee -a "$LOG_FILE"
        return 0
    else
        log_error "Redis connectivity test failed with status $status_code"
        return 1
    fi
}

# Function to test WebSocket connectivity
test_websocket_connectivity() {
    log "Testing WebSocket connectivity..."
    
    # Test WebSocket endpoint
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "$BASE_URL/ws")
    
    if [ "$status_code" -eq 101 ]; then
        log_success "WebSocket endpoint is accessible"
        return 0
    else
        log_error "WebSocket endpoint returned $status_code"
        return 1
    fi
}

# Function to test authentication endpoints
test_authentication() {
    log "Testing authentication endpoints..."
    
    # Test login endpoint (should return 422 for missing credentials)
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" -X POST "$BASE_URL/api/auth/login")
    
    if [ "$status_code" -eq 422 ]; then
        log_success "Authentication endpoint is accessible (422 for missing credentials)"
        return 0
    else
        log_error "Authentication endpoint returned $status_code"
        return 1
    fi
}

# Function to test production endpoints
test_production_endpoints() {
    log "Testing production endpoints..."
    
    local endpoints=(
        "/api/production/status"
        "/api/production/equipment"
        "/api/production/jobs"
        "/api/production/oee"
    )
    
    for endpoint in "${endpoints[@]}"; do
        local status_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "$BASE_URL$endpoint")
        
        if [ "$status_code" -eq 200 ] || [ "$status_code" -eq 401 ]; then
            log_success "Production endpoint $endpoint is accessible (status: $status_code)"
        else
            log_error "Production endpoint $endpoint returned $status_code"
            return 1
        fi
    done
    
    return 0
}

# Function to test monitoring endpoints
test_monitoring_endpoints() {
    log "Testing monitoring endpoints..."
    
    # Test Prometheus
    local prometheus_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "http://localhost:9090/-/healthy")
    if [ "$prometheus_status" -eq 200 ]; then
        log_success "Prometheus is accessible"
    else
        log_error "Prometheus returned $prometheus_status"
        return 1
    fi
    
    # Test Grafana
    local grafana_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "http://localhost:3000/api/health")
    if [ "$grafana_status" -eq 200 ]; then
        log_success "Grafana is accessible"
    else
        log_error "Grafana returned $grafana_status"
        return 1
    fi
    
    return 0
}

# Function to test system resources
test_system_resources() {
    log "Testing system resources..."
    
    # Check disk space
    local disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$disk_usage" -lt 90 ]; then
        log_success "Disk usage is acceptable ($disk_usage%)"
    else
        log_error "Disk usage is critical ($disk_usage%)"
        return 1
    fi
    
    # Check memory usage
    local memory_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    if [ "$memory_usage" -lt 90 ]; then
        log_success "Memory usage is acceptable ($memory_usage%)"
    else
        log_error "Memory usage is critical ($memory_usage%)"
        return 1
    fi
    
    return 0
}

# Function to test Docker services
test_docker_services() {
    log "Testing Docker services..."
    
    local services=("backend" "frontend" "database" "redis" "nginx" "prometheus" "grafana")
    
    for service in "${services[@]}"; do
        if docker-compose -f "docker-compose.${ENVIRONMENT}.yml" ps "$service" | grep -q "Up"; then
            log_success "Docker service $service is running"
        else
            log_error "Docker service $service is not running"
            return 1
        fi
    done
    
    return 0
}

# Function to generate smoke test report
generate_smoke_test_report() {
    log "Generating smoke test report..."
    
    local report_file="${LOG_DIR}/smoke_test_report_${TIMESTAMP}.md"
    
    cat > "$report_file" << EOF
# MS5.0 Floor Dashboard - Smoke Test Report

**Test Date:** $(date)
**Environment:** $ENVIRONMENT
**Test Status:** $1

## Test Summary

### Tested Components
- API Health Endpoints
- Database Connectivity
- Redis Connectivity
- WebSocket Connectivity
- Authentication Endpoints
- Production Endpoints
- Monitoring Endpoints
- System Resources
- Docker Services

## Test Details

- **Log File:** $LOG_FILE
- **Report File:** $report_file
- **Environment:** $ENVIRONMENT
- **Base URL:** $BASE_URL

## Next Steps

1. Review test results
2. Address any failures
3. Run additional tests if needed
4. Proceed with deployment validation

EOF
    
    log_success "Smoke test report generated: $report_file"
}

# Main smoke test function
main() {
    local start_time=$(date +%s)
    local test_success=true
    
    # Run all smoke tests
    test_api_health || test_success=false
    test_api_status || test_success=false
    test_api_version || test_success=false
    test_database_connectivity || test_success=false
    test_redis_connectivity || test_success=false
    test_websocket_connectivity || test_success=false
    test_authentication || test_success=false
    test_production_endpoints || test_success=false
    test_monitoring_endpoints || test_success=false
    test_system_resources || test_success=false
    test_docker_services || test_success=false
    
    # Generate report
    if [ "$test_success" = "true" ]; then
        generate_smoke_test_report "SUCCESS"
        log_success "Smoke tests completed successfully"
    else
        generate_smoke_test_report "FAILED"
        log_error "Smoke tests failed"
        exit 1
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log "Smoke tests completed in ${duration}s"
    log "Log file: $LOG_FILE"
}

# Help function
show_help() {
    echo "MS5.0 Floor Dashboard - Smoke Test Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -e, --environment ENV   Environment (staging|production) (default: staging)"
    echo "  -u, --url URL          Base URL for API (default: http://localhost:8000)"
    echo "  -T, --timeout SECONDS  Timeout for requests (default: 30)"
    echo ""
    echo "Environment Variables:"
    echo "  ENVIRONMENT            Environment (default: staging)"
    echo "  BASE_URL               Base URL for API (default: http://localhost:8000)"
    echo "  TIMEOUT                Timeout for requests (default: 30)"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Run smoke tests in staging"
    echo "  $0 -e production -u http://prod:8000  # Run smoke tests in production"
    echo "  ENVIRONMENT=production $0            # Run smoke tests in production"
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
        -u|--url)
            BASE_URL="$2"
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

# Run main function
main
