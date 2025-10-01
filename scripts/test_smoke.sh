#!/bin/bash

# MS5.0 Floor Dashboard - Smoke Test Script
# This script runs smoke tests to validate deployment health

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Default values
ENVIRONMENT="production"
NAMESPACE="ms5-production"
TIMEOUT="300"
BASE_URL=""
VERBOSE="false"

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Smoke Test Script for MS5.0 Floor Dashboard

OPTIONS:
    --environment ENV             Environment to test (default: production)
    --namespace NAMESPACE         Kubernetes namespace (default: ms5-production)
    --base-url URL               Base URL for testing (optional)
    --timeout SECONDS            Test timeout in seconds (default: 300)
    --verbose                    Enable verbose output
    --help                       Show this help message

EXAMPLES:
    $0 --environment staging
    $0 --environment production --base-url https://ms5floor.com --verbose
    $0 --namespace ms5-staging --timeout 600

EOF
}

# Function to parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            --namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            --base-url)
                BASE_URL="$2"
                shift 2
                ;;
            --timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            --verbose)
                VERBOSE="true"
                shift
                ;;
            --help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Function to set base URL based on environment
set_base_url() {
    if [[ -z "$BASE_URL" ]]; then
        case "$ENVIRONMENT" in
            "production")
                BASE_URL="https://ms5floor.com"
                ;;
            "staging")
                BASE_URL="https://staging.ms5floor.com"
                ;;
            "development")
                BASE_URL="http://localhost:8000"
                ;;
            *)
                BASE_URL="https://$ENVIRONMENT.ms5floor.com"
                ;;
        esac
    fi
    
    log_info "Base URL: $BASE_URL"
}

# Function to validate prerequisites
validate_prerequisites() {
    log_info "Validating prerequisites..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if curl is available
    if ! command -v curl &> /dev/null; then
        log_error "curl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if namespace exists
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_error "Namespace $NAMESPACE does not exist"
        exit 1
    fi
    
    log_success "Prerequisites validated"
}

# Function to check pod health
check_pod_health() {
    log_info "Checking pod health..."
    
    # Get all pods in namespace
    local pods=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
    
    if [[ -z "$pods" ]]; then
        log_error "No pods found in namespace $NAMESPACE"
        return 1
    fi
    
    local healthy_pods=0
    local total_pods=0
    
    for pod in $pods; do
        total_pods=$((total_pods + 1))
        
        # Get pod status
        local pod_status=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
        local pod_ready=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
        local restart_count=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.containerStatuses[0].restartCount}')
        
        if [[ "$VERBOSE" == "true" ]]; then
            log_info "Pod $pod: status=$pod_status, ready=$pod_ready, restarts=$restart_count"
        fi
        
        # Check if pod is healthy
        if [[ "$pod_status" == "Running" ]] && [[ "$pod_ready" == "True" ]] && [[ "$restart_count" -lt 5 ]]; then
            healthy_pods=$((healthy_pods + 1))
        else
            log_warning "Pod $pod is not healthy: status=$pod_status, ready=$pod_ready, restarts=$restart_count"
        fi
    done
    
    local health_percentage=$((healthy_pods * 100 / total_pods))
    
    if [[ "$health_percentage" -lt 80 ]]; then
        log_error "Only $health_percentage% of pods are healthy"
        return 1
    fi
    
    log_success "Pod health check passed: $health_percentage% pods healthy"
    return 0
}

# Function to check service health
check_service_health() {
    log_info "Checking service health..."
    
    # Get all services in namespace
    local services=$(kubectl get services -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
    
    if [[ -z "$services" ]]; then
        log_error "No services found in namespace $NAMESPACE"
        return 1
    fi
    
    for service in $services; do
        # Get service endpoints
        local endpoints=$(kubectl get endpoints "$service" -n "$NAMESPACE" -o jsonpath='{.subsets[*].addresses[*].ip}' | wc -w)
        
        if [[ "$VERBOSE" == "true" ]]; then
            log_info "Service $service: $endpoints endpoints"
        fi
        
        if [[ "$endpoints" -eq 0 ]]; then
            log_error "Service $service has no endpoints"
            return 1
        fi
    done
    
    log_success "Service health check passed"
    return 0
}

# Function to check deployment health
check_deployment_health() {
    log_info "Checking deployment health..."
    
    # Get all deployments in namespace
    local deployments=$(kubectl get deployments -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
    
    if [[ -z "$deployments" ]]; then
        log_error "No deployments found in namespace $NAMESPACE"
        return 1
    fi
    
    for deployment in $deployments; do
        # Get deployment status
        local replicas=$(kubectl get deployment "$deployment" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}')
        local ready_replicas=$(kubectl get deployment "$deployment" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}')
        local available_replicas=$(kubectl get deployment "$deployment" -n "$NAMESPACE" -o jsonpath='{.status.availableReplicas}')
        
        if [[ "$VERBOSE" == "true" ]]; then
            log_info "Deployment $deployment: $ready_replicas/$replicas ready, $available_replicas available"
        fi
        
        # Check if deployment is healthy
        if [[ "$ready_replicas" != "$replicas" ]] || [[ "$available_replicas" != "$replicas" ]]; then
            log_error "Deployment $deployment is not healthy: $ready_replicas/$replicas ready, $available_replicas available"
            return 1
        fi
    done
    
    log_success "Deployment health check passed"
    return 0
}

# Function to test API endpoints
test_api_endpoints() {
    log_info "Testing API endpoints..."
    
    # Test health endpoint
    local health_url="$BASE_URL/health"
    log_info "Testing health endpoint: $health_url"
    
    local health_response=$(curl -s -o /dev/null -w "%{http_code}" "$health_url" --connect-timeout 10 --max-time 30)
    
    if [[ "$health_response" != "200" ]]; then
        log_error "Health endpoint returned status $health_response"
        return 1
    fi
    
    log_success "Health endpoint test passed"
    
    # Test API endpoints
    local api_endpoints=(
        "/api/v1/status"
        "/api/v1/health"
        "/api/v1/metrics"
    )
    
    for endpoint in "${api_endpoints[@]}"; do
        local api_url="$BASE_URL$endpoint"
        log_info "Testing API endpoint: $api_url"
        
        local api_response=$(curl -s -o /dev/null -w "%{http_code}" "$api_url" --connect-timeout 10 --max-time 30)
        
        if [[ "$api_response" != "200" ]]; then
            log_warning "API endpoint $endpoint returned status $api_response"
        else
            log_success "API endpoint $endpoint test passed"
        fi
    done
    
    return 0
}

# Function to test database connectivity
test_database_connectivity() {
    log_info "Testing database connectivity..."
    
    # Get backend pods
    local backend_pods=$(kubectl get pods -l app=ms5-dashboard,component=backend -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
    
    if [[ -z "$backend_pods" ]]; then
        log_error "No backend pods found"
        return 1
    fi
    
    # Test database connectivity on first backend pod
    local first_pod=$(echo "$backend_pods" | awk '{print $1}')
    
    log_info "Testing database connectivity on pod: $first_pod"
    
    # Test database connection
    if ! kubectl exec "$first_pod" -n "$NAMESPACE" -- python -c "
import asyncio
import asyncpg
import os

async def test_db():
    try:
        conn = await asyncpg.connect(os.getenv('DATABASE_URL'))
        result = await conn.fetchval('SELECT 1')
        await conn.close()
        print('Database connection successful')
        return True
    except Exception as e:
        print(f'Database connection failed: {e}')
        return False

asyncio.run(test_db())
" &> /dev/null; then
        log_error "Database connectivity test failed"
        return 1
    fi
    
    log_success "Database connectivity test passed"
    return 0
}

# Function to test Redis connectivity
test_redis_connectivity() {
    log_info "Testing Redis connectivity..."
    
    # Get backend pods
    local backend_pods=$(kubectl get pods -l app=ms5-dashboard,component=backend -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
    
    if [[ -z "$backend_pods" ]]; then
        log_error "No backend pods found"
        return 1
    fi
    
    # Test Redis connectivity on first backend pod
    local first_pod=$(echo "$backend_pods" | awk '{print $1}')
    
    log_info "Testing Redis connectivity on pod: $first_pod"
    
    # Test Redis connection
    if ! kubectl exec "$first_pod" -n "$NAMESPACE" -- python -c "
import redis
import os

try:
    r = redis.from_url(os.getenv('REDIS_URL'))
    r.ping()
    print('Redis connection successful')
except Exception as e:
    print(f'Redis connection failed: {e}')
    exit(1)
" &> /dev/null; then
        log_error "Redis connectivity test failed"
        return 1
    fi
    
    log_success "Redis connectivity test passed"
    return 0
}

# Function to test frontend accessibility
test_frontend_accessibility() {
    log_info "Testing frontend accessibility..."
    
    # Test frontend endpoint
    local frontend_url="$BASE_URL"
    log_info "Testing frontend endpoint: $frontend_url"
    
    local frontend_response=$(curl -s -o /dev/null -w "%{http_code}" "$frontend_url" --connect-timeout 10 --max-time 30)
    
    if [[ "$frontend_response" != "200" ]]; then
        log_error "Frontend endpoint returned status $frontend_response"
        return 1
    fi
    
    log_success "Frontend accessibility test passed"
    return 0
}

# Function to generate smoke test report
generate_smoke_test_report() {
    local test_result="$1"
    
    local report_file="/tmp/smoke-test-report-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$report_file" << EOF
MS5.0 Floor Dashboard - Smoke Test Report
Generated: $(date)
Environment: $ENVIRONMENT
Namespace: $NAMESPACE
Base URL: $BASE_URL
Test Result: $test_result

Configuration:
- Timeout: ${TIMEOUT}s
- Verbose: $VERBOSE

Current Deployments:
$(kubectl get deployments -n "$NAMESPACE" -o wide)

Current Pods:
$(kubectl get pods -n "$NAMESPACE" -o wide)

Current Services:
$(kubectl get services -n "$NAMESPACE" -o wide)

Test Results:
EOF
    
    if [[ "$test_result" == "success" ]]; then
        echo "- All smoke tests passed" >> "$report_file"
        echo "- System is healthy and ready" >> "$report_file"
        echo "- All services are accessible" >> "$report_file"
        echo "- Database and Redis connectivity confirmed" >> "$report_file"
    else
        echo "- Some smoke tests failed" >> "$report_file"
        echo "- System may have issues" >> "$report_file"
        echo "- Check logs for error details" >> "$report_file"
        echo "- Consider rolling back if necessary" >> "$report_file"
    fi
    
    log_info "Smoke test report generated: $report_file"
    echo "$report_file"
}

# Main function
main() {
    log_info "Starting smoke tests for MS5.0 Floor Dashboard"
    
    # Parse command line arguments
    parse_args "$@"
    
    # Set base URL
    set_base_url
    
    log_info "Smoke test configuration:"
    log_info "  Environment: $ENVIRONMENT"
    log_info "  Namespace: $NAMESPACE"
    log_info "  Base URL: $BASE_URL"
    log_info "  Timeout: ${TIMEOUT}s"
    log_info "  Verbose: $VERBOSE"
    
    # Validate prerequisites
    validate_prerequisites
    
    # Run smoke tests
    local test_success=true
    
    # Check pod health
    if ! check_pod_health; then
        log_error "Pod health check failed"
        test_success=false
    fi
    
    # Check service health
    if ! check_service_health; then
        log_error "Service health check failed"
        test_success=false
    fi
    
    # Check deployment health
    if ! check_deployment_health; then
        log_error "Deployment health check failed"
        test_success=false
    fi
    
    # Test API endpoints
    if ! test_api_endpoints; then
        log_error "API endpoints test failed"
        test_success=false
    fi
    
    # Test database connectivity
    if ! test_database_connectivity; then
        log_error "Database connectivity test failed"
        test_success=false
    fi
    
    # Test Redis connectivity
    if ! test_redis_connectivity; then
        log_error "Redis connectivity test failed"
        test_success=false
    fi
    
    # Test frontend accessibility
    if ! test_frontend_accessibility; then
        log_error "Frontend accessibility test failed"
        test_success=false
    fi
    
    # Generate smoke test report
    local result="success"
    if [[ "$test_success" != "true" ]]; then
        result="failure"
    fi
    
    local report_file=$(generate_smoke_test_report "$result")
    
    # Display summary
    echo ""
    log_info "Smoke Test Summary:"
    log_info "  Result: $result"
    log_info "  Report: $report_file"
    
    if [[ "$test_success" == "true" ]]; then
        log_success "All smoke tests passed!"
        exit 0
    else
        log_error "Some smoke tests failed"
        exit 1
    fi
}

# Run main function
main "$@"