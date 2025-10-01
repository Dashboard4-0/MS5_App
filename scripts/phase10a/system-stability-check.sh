#!/bin/bash

# MS5.0 Floor Dashboard - System Stability Check Script
# Production-ready system stability validation for AKS deployment
#
# This script provides comprehensive system stability checks including:
# - System performance metrics validation
# - Error rate monitoring
# - Resource utilization analysis
# - Service response time validation
# - Database performance checks
# - Real-time monitoring validation
#
# Usage: ./system-stability-check.sh [namespace] [options]
# Options: --duration=300, --threshold=0.1, --verbose

set -euo pipefail

# Configuration
NAMESPACE="${1:-ms5-production}"
DURATION="${2:-300}"
THRESHOLD="${3:-0.1}"
VERBOSE="${4:-false}"

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

# Stability check functions
check_error_rates() {
    local namespace="$1"
    local duration="$2"
    local threshold="$3"
    
    log_step "Checking error rates for the last ${duration}s"
    
    # Get error count from logs
    local error_count=$(kubectl logs -l app=ms5-backend -n "$namespace" --since="${duration}s" 2>/dev/null | grep -c "ERROR" || echo "0")
    
    # Get total log entries
    local total_logs=$(kubectl logs -l app=ms5-backend -n "$namespace" --since="${duration}s" 2>/dev/null | wc -l)
    
    # Calculate error rate
    local error_rate=0
    if [[ "$total_logs" -gt 0 ]]; then
        error_rate=$(echo "scale=4; $error_count / $total_logs" | bc -l)
    fi
    
    log_info "Error count: $error_count"
    log_info "Total logs: $total_logs"
    log_info "Error rate: $(echo "scale=2; $error_rate * 100" | bc -l)%"
    
    if (( $(echo "$error_rate <= $threshold" | bc -l) )); then
        log_success "Error rate within acceptable threshold ($(echo "scale=2; $threshold * 100" | bc -l)%)"
        return 0
    else
        log_error "Error rate exceeds threshold: $(echo "scale=2; $error_rate * 100" | bc -l)% > $(echo "scale=2; $threshold * 100" | bc -l)%"
        return 1
    fi
}

check_response_times() {
    local namespace="$1"
    local duration="$2"
    
    log_step "Checking response times"
    
    # Get current color
    local current_color=$(kubectl get service ms5-backend-service -n "$namespace" -o jsonpath='{.spec.selector.color}' 2>/dev/null || echo "blue")
    
    # Test response time
    local response_time=$(kubectl exec -n "$namespace" deployment/ms5-backend-$current_color -- curl -w "%{time_total}" -s -o /dev/null http://localhost:8000/health 2>/dev/null || echo "0")
    
    log_info "Response time: ${response_time}s"
    
    # Check against threshold (200ms)
    if (( $(echo "$response_time <= 0.2" | bc -l) )); then
        log_success "Response time within acceptable threshold (200ms)"
        return 0
    else
        log_warning "Response time exceeds threshold: ${response_time}s > 0.2s"
        return 1
    fi
}

check_resource_utilization() {
    local namespace="$1"
    
    log_step "Checking resource utilization"
    
    # Get resource utilization
    local resource_info=$(kubectl top pods -n "$namespace" --no-headers 2>/dev/null || echo "")
    
    if [[ -z "$resource_info" ]]; then
        log_warning "Resource utilization information not available"
        return 1
    fi
    
    # Parse resource utilization
    local high_cpu_pods=0
    local high_memory_pods=0
    
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            local pod_name=$(echo "$line" | awk '{print $1}')
            local cpu_usage=$(echo "$line" | awk '{print $2}' | sed 's/m//')
            local memory_usage=$(echo "$line" | awk '{print $3}' | sed 's/Mi//')
            
            # Check CPU usage (assuming 1000m = 100%)
            if [[ "$cpu_usage" -gt 800 ]]; then
                high_cpu_pods=$((high_cpu_pods + 1))
                log_warning "High CPU usage on pod $pod_name: ${cpu_usage}m"
            fi
            
            # Check memory usage (assuming 1Gi = 100%)
            if [[ "$memory_usage" -gt 800 ]]; then
                high_memory_pods=$((high_memory_pods + 1))
                log_warning "High memory usage on pod $pod_name: ${memory_usage}Mi"
            fi
        fi
    done <<< "$resource_info"
    
    if [[ "$high_cpu_pods" -eq 0 && "$high_memory_pods" -eq 0 ]]; then
        log_success "Resource utilization within acceptable limits"
        return 0
    else
        log_warning "High resource utilization detected: $high_cpu_pods pods with high CPU, $high_memory_pods pods with high memory"
        return 1
    fi
}

check_database_performance() {
    local namespace="$1"
    
    log_step "Checking database performance"
    
    # Get current color
    local current_color=$(kubectl get service ms5-backend-service -n "$namespace" -o jsonpath='{.spec.selector.color}' 2>/dev/null || echo "blue")
    
    # Test database query performance
    local db_performance=$(kubectl exec -n "$namespace" deployment/ms5-backend-$current_color -- python -c "
import psycopg2
import time
import os

try:
    conn = psycopg2.connect(
        host=os.getenv('DATABASE_HOST', 'postgres'),
        port=os.getenv('DATABASE_PORT', '5432'),
        database=os.getenv('DATABASE_NAME', 'ms5'),
        user=os.getenv('DATABASE_USER', 'user'),
        password=os.getenv('DATABASE_PASSWORD', 'pass')
    )
    
    # Test simple query performance
    start_time = time.time()
    cursor = conn.cursor()
    cursor.execute('SELECT 1')
    cursor.fetchone()
    query_time = time.time() - start_time
    
    # Test complex query performance
    start_time = time.time()
    cursor.execute('SELECT COUNT(*) FROM information_schema.tables')
    cursor.fetchone()
    complex_query_time = time.time() - start_time
    
    conn.close()
    
    print(f'Simple query: {query_time:.3f}s')
    print(f'Complex query: {complex_query_time:.3f}s')
    
except Exception as e:
    print(f'FAILED: {e}')
" 2>/dev/null || echo "FAILED")
    
    if [[ "$db_performance" == "FAILED" ]]; then
        log_error "Database performance check failed"
        return 1
    else
        log_success "Database performance check passed"
        if [[ "$VERBOSE" == "true" ]]; then
            log_info "Database performance: $db_performance"
        fi
        return 0
    fi
}

check_service_discovery() {
    local namespace="$1"
    
    log_step "Checking service discovery"
    
    # Get current color
    local current_color=$(kubectl get service ms5-backend-service -n "$namespace" -o jsonpath='{.spec.selector.color}' 2>/dev/null || echo "blue")
    
    # Test service discovery
    local service_discovery=$(kubectl exec -n "$namespace" deployment/ms5-backend-$current_color -- python -c "
import socket
import time

services = ['postgres', 'redis', 'minio']
results = []

for service in services:
    try:
        start_time = time.time()
        socket.gethostbyname(service)
        resolve_time = time.time() - start_time
        results.append(f'{service}: OK ({resolve_time:.3f}s)')
    except Exception as e:
        results.append(f'{service}: FAILED - {e}')

for result in results:
    print(result)
" 2>/dev/null || echo "FAILED")
    
    if [[ "$service_discovery" == "FAILED" ]]; then
        log_error "Service discovery check failed"
        return 1
    else
        log_success "Service discovery check passed"
        if [[ "$VERBOSE" == "true" ]]; then
            log_info "Service discovery: $service_discovery"
        fi
        return 0
    fi
}

check_websocket_stability() {
    local namespace="$1"
    local duration="$2"
    
    log_step "Checking WebSocket stability"
    
    # Get current color
    local current_color=$(kubectl get service ms5-backend-service -n "$namespace" -o jsonpath='{.spec.selector.color}' 2>/dev/null || echo "blue")
    
    # Test WebSocket stability
    local websocket_test=$(kubectl exec -n "$namespace" deployment/ms5-backend-$current_color -- python -c "
import websocket
import json
import time
import threading

def test_websocket_stability():
    try:
        ws = websocket.create_connection('ws://localhost:8000/ws/', timeout=10)
        
        # Send ping and wait for response
        ws.send(json.dumps({'type': 'ping'}))
        response = ws.recv()
        
        # Test subscription
        ws.send(json.dumps({'type': 'subscribe', 'channel': 'production_lines'}))
        
        # Keep connection alive for a short time
        time.sleep(2)
        
        # Send unsubscribe
        ws.send(json.dumps({'type': 'unsubscribe', 'channel': 'production_lines'}))
        
        ws.close()
        print('OK')
        
    except Exception as e:
        print(f'FAILED: {e}')

test_websocket_stability()
" 2>/dev/null || echo "FAILED")
    
    if [[ "$websocket_test" == "OK" ]]; then
        log_success "WebSocket stability check passed"
        return 0
    else
        log_error "WebSocket stability check failed: $websocket_test"
        return 1
    fi
}

check_monitoring_health() {
    local namespace="$1"
    
    log_step "Checking monitoring health"
    
    # Check Prometheus
    local prometheus_status=$(kubectl exec -n "$namespace" deployment/ms5-prometheus -- curl -s http://localhost:9090/api/v1/status 2>/dev/null | grep -q "ready" && echo "OK" || echo "FAILED")
    
    # Check Grafana
    local grafana_status=$(kubectl exec -n "$namespace" deployment/ms5-grafana -- curl -s http://localhost:3000/api/health 2>/dev/null | grep -q "ok" && echo "OK" || echo "FAILED")
    
    # Check AlertManager
    local alertmanager_status=$(kubectl exec -n "$namespace" deployment/ms5-alertmanager -- curl -s http://localhost:9093/api/v1/status 2>/dev/null | grep -q "ready" && echo "OK" || echo "FAILED")
    
    log_info "Prometheus status: $prometheus_status"
    log_info "Grafana status: $grafana_status"
    log_info "AlertManager status: $alertmanager_status"
    
    if [[ "$prometheus_status" == "OK" && "$grafana_status" == "OK" && "$alertmanager_status" == "OK" ]]; then
        log_success "All monitoring services are healthy"
        return 0
    else
        log_error "Some monitoring services are not healthy"
        return 1
    fi
}

check_api_endpoint_stability() {
    local namespace="$1"
    local duration="$2"
    
    log_step "Checking API endpoint stability"
    
    # Get current color
    local current_color=$(kubectl get service ms5-backend-service -n "$namespace" -o jsonpath='{.spec.selector.color}' 2>/dev/null || echo "blue")
    
    # Test critical API endpoints
    local endpoints=(
        "/health"
        "/api/v1/dashboard/summary"
        "/api/v1/production/lines"
        "/api/v1/oee/lines/1/current"
    )
    
    local failed_endpoints=()
    local total_requests=0
    local successful_requests=0
    
    for endpoint in "${endpoints[@]}"; do
        for i in {1..5}; do  # Test each endpoint 5 times
            total_requests=$((total_requests + 1))
            local response_code=$(kubectl exec -n "$namespace" deployment/ms5-backend-$current_color -- curl -s -w "%{http_code}" -o /dev/null "http://localhost:8000$endpoint" 2>/dev/null || echo "000")
            
            if [[ "$response_code" == "200" ]]; then
                successful_requests=$((successful_requests + 1))
            else
                failed_endpoints+=("$endpoint")
            fi
        done
    done
    
    local success_rate=$(echo "scale=2; $successful_requests / $total_requests * 100" | bc -l)
    
    log_info "API endpoint stability: $successful_requests/$total_requests requests successful ($success_rate%)"
    
    if [[ "$success_rate" -ge 95 ]]; then
        log_success "API endpoint stability check passed"
        return 0
    else
        log_error "API endpoint stability check failed: $success_rate% < 95%"
        if [[ "$VERBOSE" == "true" ]]; then
            log_info "Failed endpoints: ${failed_endpoints[*]}"
        fi
        return 1
    fi
}

# Comprehensive stability check
run_comprehensive_stability_check() {
    local namespace="$1"
    local duration="$2"
    local threshold="$3"
    
    log_info "Starting comprehensive system stability check"
    log_info "Namespace: $namespace"
    log_info "Duration: ${duration}s"
    log_info "Error threshold: $(echo "scale=2; $threshold * 100" | bc -l)%"
    echo ""
    
    local start_time=$(date +%s)
    local checks_passed=0
    local total_checks=0
    
    # Define stability checks
    local stability_checks=(
        "check_error_rates"
        "check_response_times"
        "check_resource_utilization"
        "check_database_performance"
        "check_service_discovery"
        "check_websocket_stability"
        "check_monitoring_health"
        "check_api_endpoint_stability"
    )
    
    # Run stability checks
    for check in "${stability_checks[@]}"; do
        total_checks=$((total_checks + 1))
        
        if $check "$namespace" "$duration" "$threshold"; then
            checks_passed=$((checks_passed + 1))
        fi
        
        echo ""
    done
    
    # Summary
    local end_time=$(date +%s)
    local total_time=$((end_time - start_time))
    
    log_info "System stability check completed in ${total_time}s"
    log_info "Checks passed: $checks_passed/$total_checks"
    
    if [[ "$checks_passed" -eq "$total_checks" ]]; then
        log_success "All stability checks passed! System is stable."
        return 0
    else
        log_error "Some stability checks failed. System may have stability issues."
        return 1
    fi
}

# Main execution
main() {
    echo "=== MS5.0 Floor Dashboard - System Stability Check ==="
    echo "Namespace: $NAMESPACE"
    echo "Duration: ${DURATION}s"
    echo "Error Threshold: $(echo "scale=2; $THRESHOLD * 100" | bc -l)%"
    echo "Verbose: $VERBOSE"
    echo ""
    
    # Validate inputs
    if [[ -z "$NAMESPACE" ]]; then
        log_error "Namespace is required"
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
    
    # Run comprehensive stability check
    run_comprehensive_stability_check "$NAMESPACE" "$DURATION" "$THRESHOLD"
}

# Error handling
trap 'log_error "System stability check failed at line $LINENO"' ERR

# Execute main function
main "$@"
