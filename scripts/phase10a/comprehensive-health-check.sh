#!/bin/bash

# MS5.0 Floor Dashboard - Comprehensive Health Check Script
# Production-ready health check script for AKS deployment validation
#
# This script provides comprehensive health checks including:
# - Pod status and readiness checks
# - Service endpoint validation
# - Database connectivity tests
# - Application health endpoints
# - External service connectivity
# - Performance and resource validation
#
# Usage: ./comprehensive-health-check.sh [service-name] [namespace] [options]
# Options: --verbose, --timeout=300, --retries=3

set -euo pipefail

# Configuration
SERVICE_NAME="${1:-ms5-backend}"
NAMESPACE="${2:-ms5-production}"
VERBOSE="${3:-false}"
TIMEOUT="${4:-300}"
RETRIES="${5:-3}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_step() {
    echo -e "${CYAN}[STEP]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Health check functions
check_pod_status() {
    local service_name="$1"
    local namespace="$2"
    
    log_step "Checking pod status for $service_name in namespace $namespace"
    
    # Get pod status
    local pod_status=$(kubectl get pods -l app="$service_name" -n "$namespace" -o jsonpath='{.items[*].status.phase}' 2>/dev/null || echo "")
    
    if [[ -z "$pod_status" ]]; then
        log_error "No pods found for service $service_name"
        return 1
    fi
    
    # Check if all pods are running
    local running_pods=$(echo "$pod_status" | tr ' ' '\n' | grep -c "Running" || echo "0")
    local total_pods=$(echo "$pod_status" | tr ' ' '\n' | wc -l)
    
    if [[ "$running_pods" -eq "$total_pods" ]]; then
        log_success "All $total_pods pods are running"
        return 0
    else
        log_error "Only $running_pods out of $total_pods pods are running"
        return 1
    fi
}

check_pod_readiness() {
    local service_name="$1"
    local namespace="$2"
    
    log_step "Checking pod readiness for $service_name"
    
    # Get pod readiness
    local ready_pods=$(kubectl get pods -l app="$service_name" -n "$namespace" -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | tr ' ' '\n' | grep -c "True" || echo "0")
    local total_pods=$(kubectl get pods -l app="$service_name" -n "$namespace" --no-headers | wc -l)
    
    if [[ "$ready_pods" -eq "$total_pods" ]]; then
        log_success "All $total_pods pods are ready"
        return 0
    else
        log_error "Only $ready_pods out of $total_pods pods are ready"
        return 1
    fi
}

check_service_endpoints() {
    local service_name="$1"
    local namespace="$2"
    
    log_step "Checking service endpoints for $service_name"
    
    # Get service endpoints
    local endpoints=$(kubectl get endpoints "$service_name-service" -n "$namespace" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || echo "")
    
    if [[ -z "$endpoints" ]]; then
        log_error "No endpoints found for service $service_name-service"
        return 1
    fi
    
    local endpoint_count=$(echo "$endpoints" | tr ' ' '\n' | wc -l)
    log_success "Service $service_name-service has $endpoint_count endpoints"
    
    if [[ "$VERBOSE" == "true" ]]; then
        log_info "Endpoints: $endpoints"
    fi
    
    return 0
}

check_application_health() {
    local service_name="$1"
    local namespace="$2"
    
    log_step "Checking application health for $service_name"
    
    # Test health endpoint
    local health_response=$(kubectl exec -n "$namespace" deployment/"$service_name" -- curl -s -w "%{http_code}" -o /dev/null http://localhost:8000/health 2>/dev/null || echo "000")
    
    if [[ "$health_response" == "200" ]]; then
        log_success "Application health check passed"
        return 0
    else
        log_error "Application health check failed with status code: $health_response"
        return 1
    fi
}

check_database_connectivity() {
    local service_name="$1"
    local namespace="$2"
    
    log_step "Checking database connectivity"
    
    # Test PostgreSQL connectivity
    local db_test=$(kubectl exec -n "$namespace" deployment/"$service_name" -- python -c "
import psycopg2
import os
try:
    conn = psycopg2.connect(
        host=os.getenv('DATABASE_HOST', 'postgres'),
        port=os.getenv('DATABASE_PORT', '5432'),
        database=os.getenv('DATABASE_NAME', 'ms5'),
        user=os.getenv('DATABASE_USER', 'user'),
        password=os.getenv('DATABASE_PASSWORD', 'pass')
    )
    conn.close()
    print('OK')
except Exception as e:
    print(f'FAILED: {e}')
" 2>/dev/null || echo "FAILED")
    
    if [[ "$db_test" == "OK" ]]; then
        log_success "Database connectivity check passed"
        return 0
    else
        log_error "Database connectivity check failed: $db_test"
        return 1
    fi
}

check_redis_connectivity() {
    local service_name="$1"
    local namespace="$2"
    
    log_step "Checking Redis connectivity"
    
    # Test Redis connectivity
    local redis_test=$(kubectl exec -n "$namespace" deployment/"$service_name" -- python -c "
import redis
import os
try:
    r = redis.Redis(
        host=os.getenv('REDIS_HOST', 'redis'),
        port=int(os.getenv('REDIS_PORT', '6379')),
        password=os.getenv('REDIS_PASSWORD', '')
    )
    r.ping()
    print('OK')
except Exception as e:
    print(f'FAILED: {e}')
" 2>/dev/null || echo "FAILED")
    
    if [[ "$redis_test" == "OK" ]]; then
        log_success "Redis connectivity check passed"
        return 0
    else
        log_error "Redis connectivity check failed: $redis_test"
        return 1
    fi
}

check_minio_connectivity() {
    local service_name="$1"
    local namespace="$2"
    
    log_step "Checking MinIO connectivity"
    
    # Test MinIO connectivity
    local minio_test=$(kubectl exec -n "$namespace" deployment/"$service_name" -- curl -s -w "%{http_code}" -o /dev/null http://minio:9000/minio/health/live 2>/dev/null || echo "000")
    
    if [[ "$minio_test" == "200" ]]; then
        log_success "MinIO connectivity check passed"
        return 0
    else
        log_error "MinIO connectivity check failed with status code: $minio_test"
        return 1
    fi
}

check_external_api_connectivity() {
    local service_name="$1"
    local namespace="$2"
    
    log_step "Checking external API connectivity"
    
    # Test external API connectivity (placeholder)
    local external_test=$(kubectl exec -n "$namespace" deployment/"$service_name" -- curl -s -w "%{http_code}" -o /dev/null https://httpbin.org/status/200 2>/dev/null || echo "000")
    
    if [[ "$external_test" == "200" ]]; then
        log_success "External API connectivity check passed"
        return 0
    else
        log_warning "External API connectivity check failed with status code: $external_test"
        return 1
    fi
}

check_resource_utilization() {
    local service_name="$1"
    local namespace="$2"
    
    log_step "Checking resource utilization"
    
    # Get resource utilization
    local resource_info=$(kubectl top pods -l app="$service_name" -n "$namespace" --no-headers 2>/dev/null || echo "")
    
    if [[ -z "$resource_info" ]]; then
        log_warning "Resource utilization information not available"
        return 1
    fi
    
    log_success "Resource utilization check completed"
    
    if [[ "$VERBOSE" == "true" ]]; then
        log_info "Resource utilization:"
        echo "$resource_info"
    fi
    
    return 0
}

check_logs_for_errors() {
    local service_name="$1"
    local namespace="$2"
    
    log_step "Checking logs for errors"
    
    # Get recent logs and check for errors
    local error_count=$(kubectl logs -l app="$service_name" -n "$namespace" --since=5m 2>/dev/null | grep -c "ERROR" || echo "0")
    
    if [[ "$error_count" -eq 0 ]]; then
        log_success "No errors found in recent logs"
        return 0
    else
        log_warning "Found $error_count errors in recent logs"
        
        if [[ "$VERBOSE" == "true" ]]; then
            log_info "Recent errors:"
            kubectl logs -l app="$service_name" -n "$namespace" --since=5m | grep "ERROR" | tail -10
        fi
        
        return 1
    fi
}

check_websocket_connectivity() {
    local service_name="$1"
    local namespace="$2"
    
    log_step "Checking WebSocket connectivity"
    
    # Test WebSocket connectivity
    local websocket_test=$(kubectl exec -n "$namespace" deployment/"$service_name" -- python -c "
import websocket
import json
import time
try:
    ws = websocket.create_connection('ws://localhost:8000/ws/', timeout=10)
    ws.send(json.dumps({'type': 'ping'}))
    response = ws.recv()
    ws.close()
    print('OK')
except Exception as e:
    print(f'FAILED: {e}')
" 2>/dev/null || echo "FAILED")
    
    if [[ "$websocket_test" == "OK" ]]; then
        log_success "WebSocket connectivity check passed"
        return 0
    else
        log_error "WebSocket connectivity check failed: $websocket_test"
        return 1
    fi
}

check_api_endpoints() {
    local service_name="$1"
    local namespace="$2"
    
    log_step "Checking API endpoints"
    
    # Test critical API endpoints
    local endpoints=(
        "/"
        "/health"
        "/metrics"
        "/api/v1/dashboard/summary"
        "/api/v1/production/lines"
        "/api/v1/oee/lines/1/current"
    )
    
    local failed_endpoints=()
    
    for endpoint in "${endpoints[@]}"; do
        local response_code=$(kubectl exec -n "$namespace" deployment/"$service_name" -- curl -s -w "%{http_code}" -o /dev/null "http://localhost:8000$endpoint" 2>/dev/null || echo "000")
        
        if [[ "$response_code" == "200" ]]; then
            log_success "API endpoint $endpoint: OK"
        else
            log_error "API endpoint $endpoint: FAILED (status: $response_code)"
            failed_endpoints+=("$endpoint")
        fi
    done
    
    if [[ ${#failed_endpoints[@]} -eq 0 ]]; then
        log_success "All API endpoints are accessible"
        return 0
    else
        log_error "Failed API endpoints: ${failed_endpoints[*]}"
        return 1
    fi
}

# Comprehensive health check
run_comprehensive_health_check() {
    local service_name="$1"
    local namespace="$2"
    local timeout="$3"
    local retries="$4"
    
    log_info "Starting comprehensive health check for $service_name in namespace $namespace"
    log_info "Timeout: ${timeout}s, Retries: $retries"
    echo ""
    
    local start_time=$(date +%s)
    local checks_passed=0
    local total_checks=0
    
    # Define health checks
    local health_checks=(
        "check_pod_status"
        "check_pod_readiness"
        "check_service_endpoints"
        "check_application_health"
        "check_database_connectivity"
        "check_redis_connectivity"
        "check_minio_connectivity"
        "check_external_api_connectivity"
        "check_resource_utilization"
        "check_logs_for_errors"
        "check_websocket_connectivity"
        "check_api_endpoints"
    )
    
    # Run health checks with retries
    for check in "${health_checks[@]}"; do
        total_checks=$((total_checks + 1))
        local check_passed=false
        
        for attempt in $(seq 1 "$retries"); do
            if [[ "$attempt" -gt 1 ]]; then
                log_info "Retry attempt $attempt/$retries for $check"
                sleep 10
            fi
            
            if $check "$service_name" "$namespace"; then
                checks_passed=$((checks_passed + 1))
                check_passed=true
                break
            fi
        done
        
        if [[ "$check_passed" == "false" ]]; then
            log_error "Health check $check failed after $retries attempts"
        fi
        
        # Check timeout
        local current_time=$(date +%s)
        local elapsed_time=$((current_time - start_time))
        
        if [[ "$elapsed_time" -gt "$timeout" ]]; then
            log_error "Health check timed out after ${elapsed_time}s"
            break
        fi
    done
    
    # Summary
    local end_time=$(date +%s)
    local total_time=$((end_time - start_time))
    
    echo ""
    log_info "Health check completed in ${total_time}s"
    log_info "Checks passed: $checks_passed/$total_checks"
    
    if [[ "$checks_passed" -eq "$total_checks" ]]; then
        log_success "All health checks passed! Service $service_name is healthy."
        return 0
    else
        log_error "Some health checks failed. Service $service_name may have issues."
        return 1
    fi
}

# Main execution
main() {
    echo "=== MS5.0 Floor Dashboard - Comprehensive Health Check ==="
    echo "Service: $SERVICE_NAME"
    echo "Namespace: $NAMESPACE"
    echo "Verbose: $VERBOSE"
    echo "Timeout: ${TIMEOUT}s"
    echo "Retries: $RETRIES"
    echo ""
    
    # Validate inputs
    if [[ -z "$SERVICE_NAME" || -z "$NAMESPACE" ]]; then
        log_error "Service name and namespace are required"
        exit 1
    fi
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl."
        exit 1
    fi
    
    # Check if namespace exists
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_error "Namespace $NAMESPACE not found"
        exit 1
    fi
    
    # Run comprehensive health check
    run_comprehensive_health_check "$SERVICE_NAME" "$NAMESPACE" "$TIMEOUT" "$RETRIES"
}

# Error handling
trap 'log_error "Health check failed at line $LINENO"' ERR

# Execute main function
main "$@"
