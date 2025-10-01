#!/bin/bash

# MS5.0 Floor Dashboard - Phase 4 Testing Script
# Backend Services Migration Testing
#
# This script performs comprehensive testing of Phase 4 backend services including:
# - API endpoint testing
# - Celery task execution testing
# - Redis connectivity testing
# - Database connectivity testing
# - Performance testing
# - Integration testing
#
# Usage: ./test-phase4.sh [environment] [test-type]
# Environment: staging|production (default: staging)
# Test Type: smoke|integration|performance|all (default: smoke)

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
NAMESPACE_PREFIX="ms5"
ENVIRONMENT="${1:-staging}"
TEST_TYPE="${2:-smoke}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

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

# Test result tracking
record_test_result() {
    local test_name="$1"
    local result="$2"
    local message="$3"
    
    ((TESTS_TOTAL++))
    
    if [[ "$result" == "PASS" ]]; then
        ((TESTS_PASSED++))
        log_success "TEST PASSED: $test_name - $message"
    else
        ((TESTS_FAILED++))
        log_error "TEST FAILED: $test_name - $message"
    fi
}

# Validation functions
validate_environment() {
    if [[ "$ENVIRONMENT" != "staging" && "$ENVIRONMENT" != "production" ]]; then
        log_error "Invalid environment: $ENVIRONMENT. Must be 'staging' or 'production'"
        exit 1
    fi
    
    if [[ "$TEST_TYPE" != "smoke" && "$TEST_TYPE" != "integration" && "$TEST_TYPE" != "performance" && "$TEST_TYPE" != "all" ]]; then
        log_error "Invalid test type: $TEST_TYPE. Must be 'smoke', 'integration', 'performance', or 'all'"
        exit 1
    fi
}

validate_prerequisites() {
    log_info "Validating test prerequisites..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if we can connect to the cluster
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Check if namespace exists
    local namespace="$NAMESPACE_PREFIX-$ENVIRONMENT"
    if ! kubectl get namespace "$namespace" &> /dev/null; then
        log_error "Namespace $namespace does not exist"
        exit 1
    fi
    
    log_success "Test prerequisites validation passed"
}

# Get service endpoints
get_service_endpoints() {
    local namespace="$NAMESPACE_PREFIX-$ENVIRONMENT"
    
    BACKEND_SERVICE="ms5-backend-service.$namespace.svc.cluster.local:8000"
    FLOWER_SERVICE="ms5-flower.$namespace.svc.cluster.local:5555"
    REDIS_PRIMARY="redis-primary.$namespace.svc.cluster.local:6379"
    REDIS_REPLICA="redis-replica.$namespace.svc.cluster.local:6379"
    
    log_info "Service endpoints configured:"
    log_info "  Backend API: http://$BACKEND_SERVICE"
    log_info "  Flower Monitoring: http://$FLOWER_SERVICE"
    log_info "  Redis Primary: $REDIS_PRIMARY"
    log_info "  Redis Replica: $REDIS_REPLICA"
}

# Smoke tests - Basic functionality tests
run_smoke_tests() {
    log_info "Running smoke tests..."
    
    local namespace="$NAMESPACE_PREFIX-$ENVIRONMENT"
    
    # Test 1: Backend API Health Check
    log_info "Test 1: Backend API Health Check"
    if kubectl run smoke-test-health --rm -i --restart=Never --image=curlimages/curl:latest -- \
        curl -f -s "http://$BACKEND_SERVICE/health" | grep -q "healthy"; then
        record_test_result "Backend Health Check" "PASS" "API health endpoint responding correctly"
    else
        record_test_result "Backend Health Check" "FAIL" "API health endpoint not responding"
    fi
    
    # Test 2: Backend API Detailed Health Check
    log_info "Test 2: Backend API Detailed Health Check"
    if kubectl run smoke-test-detailed-health --rm -i --restart=Never --image=curlimages/curl:latest -- \
        curl -f -s "http://$BACKEND_SERVICE/health/detailed" | grep -q "healthy"; then
        record_test_result "Backend Detailed Health Check" "PASS" "Detailed health endpoint responding correctly"
    else
        record_test_result "Backend Detailed Health Check" "FAIL" "Detailed health endpoint not responding"
    fi
    
    # Test 3: Backend API Metrics Endpoint
    log_info "Test 3: Backend API Metrics Endpoint"
    if kubectl run smoke-test-metrics --rm -i --restart=Never --image=curlimages/curl:latest -- \
        curl -f -s "http://$BACKEND_SERVICE/metrics" | grep -q "# HELP"; then
        record_test_result "Backend Metrics Endpoint" "PASS" "Metrics endpoint returning Prometheus format"
    else
        record_test_result "Backend Metrics Endpoint" "FAIL" "Metrics endpoint not returning expected format"
    fi
    
    # Test 4: Celery Worker Health Check
    log_info "Test 4: Celery Worker Health Check"
    local worker_pod=$(kubectl get pods -l app=ms5-dashboard,component=celery-worker -n "$namespace" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -n "$worker_pod" ]]; then
        if kubectl exec "$worker_pod" -n "$namespace" -- celery -A app.celery inspect ping &> /dev/null; then
            record_test_result "Celery Worker Health Check" "PASS" "Celery worker responding to ping"
        else
            record_test_result "Celery Worker Health Check" "FAIL" "Celery worker not responding to ping"
        fi
    else
        record_test_result "Celery Worker Health Check" "FAIL" "Celery worker pod not found"
    fi
    
    # Test 5: Celery Beat Scheduler Health Check
    log_info "Test 5: Celery Beat Scheduler Health Check"
    local beat_pod=$(kubectl get pods -l app=ms5-dashboard,component=celery-beat -n "$namespace" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -n "$beat_pod" ]]; then
        if kubectl exec "$beat_pod" -n "$namespace" -- celery -A app.celery inspect ping &> /dev/null; then
            record_test_result "Celery Beat Health Check" "PASS" "Celery Beat scheduler responding to ping"
        else
            record_test_result "Celery Beat Health Check" "FAIL" "Celery Beat scheduler not responding to ping"
        fi
    else
        record_test_result "Celery Beat Health Check" "FAIL" "Celery Beat pod not found"
    fi
    
    # Test 6: Redis Primary Connectivity
    log_info "Test 6: Redis Primary Connectivity"
    local redis_pod=$(kubectl get pods -l app=ms5-dashboard,component=redis,role=primary -n "$namespace" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -n "$redis_pod" ]]; then
        if kubectl exec "$redis_pod" -n "$namespace" -- redis-cli ping | grep -q "PONG"; then
            record_test_result "Redis Primary Connectivity" "PASS" "Redis primary responding to ping"
        else
            record_test_result "Redis Primary Connectivity" "FAIL" "Redis primary not responding to ping"
        fi
    else
        record_test_result "Redis Primary Connectivity" "FAIL" "Redis primary pod not found"
    fi
    
    # Test 7: Redis Replica Connectivity
    log_info "Test 7: Redis Replica Connectivity"
    local redis_replica_pod=$(kubectl get pods -l app=ms5-dashboard,component=redis,role=replica -n "$namespace" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -n "$redis_replica_pod" ]]; then
        if kubectl exec "$redis_replica_pod" -n "$namespace" -- redis-cli ping | grep -q "PONG"; then
            record_test_result "Redis Replica Connectivity" "PASS" "Redis replica responding to ping"
        else
            record_test_result "Redis Replica Connectivity" "FAIL" "Redis replica not responding to ping"
        fi
    else
        record_test_result "Redis Replica Connectivity" "FAIL" "Redis replica pod not found"
    fi
    
    # Test 8: Flower Monitoring Access
    log_info "Test 8: Flower Monitoring Access"
    if kubectl run smoke-test-flower --rm -i --restart=Never --image=curlimages/curl:latest -- \
        curl -f -s "http://$FLOWER_SERVICE" | grep -q "Flower"; then
        record_test_result "Flower Monitoring Access" "PASS" "Flower monitoring interface accessible"
    else
        record_test_result "Flower Monitoring Access" "FAIL" "Flower monitoring interface not accessible"
    fi
}

# Integration tests - Component interaction tests
run_integration_tests() {
    log_info "Running integration tests..."
    
    local namespace="$NAMESPACE_PREFIX-$ENVIRONMENT"
    
    # Test 1: Celery Task Execution
    log_info "Test 1: Celery Task Execution"
    local worker_pod=$(kubectl get pods -l app=ms5-dashboard,component=celery-worker -n "$namespace" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -n "$worker_pod" ]]; then
        if kubectl exec "$worker_pod" -n "$namespace" -- python -c "
from app.celery import celery_app
try:
    result = celery_app.send_task('health_check')
    print(f'Task {result.id} sent successfully')
    exit(0)
except Exception as e:
    print(f'Task execution failed: {e}')
    exit(1)
" &> /dev/null; then
            record_test_result "Celery Task Execution" "PASS" "Health check task executed successfully"
        else
            record_test_result "Celery Task Execution" "FAIL" "Health check task execution failed"
        fi
    else
        record_test_result "Celery Task Execution" "FAIL" "Celery worker pod not found"
    fi
    
    # Test 2: Redis Cache Operations
    log_info "Test 2: Redis Cache Operations"
    local redis_pod=$(kubectl get pods -l app=ms5-dashboard,component=redis,role=primary -n "$namespace" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -n "$redis_pod" ]]; then
        # Test SET and GET operations
        if kubectl exec "$redis_pod" -n "$namespace" -- redis-cli set test_key "test_value" &> /dev/null && \
           kubectl exec "$redis_pod" -n "$namespace" -- redis-cli get test_key | grep -q "test_value"; then
            record_test_result "Redis Cache Operations" "PASS" "Redis SET/GET operations working correctly"
            # Clean up test key
            kubectl exec "$redis_pod" -n "$namespace" -- redis-cli del test_key &> /dev/null || true
        else
            record_test_result "Redis Cache Operations" "FAIL" "Redis SET/GET operations failed"
        fi
    else
        record_test_result "Redis Cache Operations" "FAIL" "Redis primary pod not found"
    fi
    
    # Test 3: Database Connectivity from Backend
    log_info "Test 3: Database Connectivity from Backend"
    local backend_pod=$(kubectl get pods -l app=ms5-dashboard,component=backend -n "$namespace" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -n "$backend_pod" ]]; then
        if kubectl exec "$backend_pod" -n "$namespace" -- python -c "
import asyncio
from app.database import init_db
async def test_db():
    try:
        await init_db()
        print('Database connection successful')
        return True
    except Exception as e:
        print(f'Database connection failed: {e}')
        return False

result = asyncio.run(test_db())
exit(0 if result else 1)
" &> /dev/null; then
            record_test_result "Database Connectivity" "PASS" "Backend can connect to database"
        else
            record_test_result "Database Connectivity" "FAIL" "Backend cannot connect to database"
        fi
    else
        record_test_result "Database Connectivity" "FAIL" "Backend pod not found"
    fi
    
    # Test 4: Service Discovery
    log_info "Test 4: Service Discovery"
    if kubectl run integration-test-service-discovery --rm -i --restart=Never --image=curlimages/curl:latest -- \
        curl -f -s "http://$BACKEND_SERVICE/health" &> /dev/null; then
        record_test_result "Service Discovery" "PASS" "Services discoverable via DNS"
    else
        record_test_result "Service Discovery" "FAIL" "Service discovery failed"
    fi
    
    # Test 5: Cross-Service Communication
    log_info "Test 5: Cross-Service Communication"
    local backend_pod=$(kubectl get pods -l app=ms5-dashboard,component=backend -n "$namespace" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -n "$backend_pod" ]]; then
        if kubectl exec "$backend_pod" -n "$namespace" -- python -c "
import requests
try:
    response = requests.get('http://ms5-flower.$namespace.svc.cluster.local:5555', timeout=10)
    if response.status_code == 200:
        print('Cross-service communication successful')
        exit(0)
    else:
        print(f'Cross-service communication failed: {response.status_code}')
        exit(1)
except Exception as e:
    print(f'Cross-service communication failed: {e}')
    exit(1)
" &> /dev/null; then
            record_test_result "Cross-Service Communication" "PASS" "Services can communicate with each other"
        else
            record_test_result "Cross-Service Communication" "FAIL" "Cross-service communication failed"
        fi
    else
        record_test_result "Cross-Service Communication" "FAIL" "Backend pod not found"
    fi
}

# Performance tests - Load and stress tests
run_performance_tests() {
    log_info "Running performance tests..."
    
    local namespace="$NAMESPACE_PREFIX-$ENVIRONMENT"
    
    # Test 1: API Response Time
    log_info "Test 1: API Response Time"
    local response_time=$(kubectl run perf-test-response-time --rm -i --restart=Never --image=curlimages/curl:latest -- \
        curl -o /dev/null -s -w '%{time_total}' "http://$BACKEND_SERVICE/health" 2>/dev/null || echo "999")
    
    if (( $(echo "$response_time < 1.0" | bc -l) )); then
        record_test_result "API Response Time" "PASS" "Response time ${response_time}s is acceptable"
    else
        record_test_result "API Response Time" "FAIL" "Response time ${response_time}s is too slow"
    fi
    
    # Test 2: API Throughput
    log_info "Test 2: API Throughput"
    local start_time=$(date +%s)
    local request_count=10
    
    for i in $(seq 1 $request_count); do
        kubectl run perf-test-throughput-$i --rm -i --restart=Never --image=curlimages/curl:latest -- \
            curl -f -s "http://$BACKEND_SERVICE/health" &> /dev/null &
    done
    
    wait
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local throughput=$(echo "scale=2; $request_count / $duration" | bc -l)
    
    if (( $(echo "$throughput > 1.0" | bc -l) )); then
        record_test_result "API Throughput" "PASS" "Throughput ${throughput} req/s is acceptable"
    else
        record_test_result "API Throughput" "FAIL" "Throughput ${throughput} req/s is too low"
    fi
    
    # Test 3: Celery Task Processing Rate
    log_info "Test 3: Celery Task Processing Rate"
    local worker_pod=$(kubectl get pods -l app=ms5-dashboard,component=celery-worker -n "$namespace" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -n "$worker_pod" ]]; then
        local start_time=$(date +%s)
        local task_count=5
        
        for i in $(seq 1 $task_count); do
            kubectl exec "$worker_pod" -n "$namespace" -- python -c "
from app.celery import celery_app
result = celery_app.send_task('health_check')
print(f'Task {result.id} sent')
" &> /dev/null &
        done
        
        wait
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        local task_rate=$(echo "scale=2; $task_count / $duration" | bc -l)
        
        if (( $(echo "$task_rate > 0.5" | bc -l) )); then
            record_test_result "Celery Task Processing Rate" "PASS" "Task rate ${task_rate} tasks/s is acceptable"
        else
            record_test_result "Celery Task Processing Rate" "FAIL" "Task rate ${task_rate} tasks/s is too low"
        fi
    else
        record_test_result "Celery Task Processing Rate" "FAIL" "Celery worker pod not found"
    fi
    
    # Test 4: Redis Performance
    log_info "Test 4: Redis Performance"
    local redis_pod=$(kubectl get pods -l app=ms5-dashboard,component=redis,role=primary -n "$namespace" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -n "$redis_pod" ]]; then
        local start_time=$(date +%s)
        local operation_count=100
        
        for i in $(seq 1 $operation_count); do
            kubectl exec "$redis_pod" -n "$namespace" -- redis-cli set "perf_test_$i" "value_$i" &> /dev/null &
        done
        
        wait
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        local redis_ops_per_sec=$(echo "scale=2; $operation_count / $duration" | bc -l)
        
        if (( $(echo "$redis_ops_per_sec > 10.0" | bc -l) )); then
            record_test_result "Redis Performance" "PASS" "Redis operations ${redis_ops_per_sec} ops/s is acceptable"
        else
            record_test_result "Redis Performance" "FAIL" "Redis operations ${redis_ops_per_sec} ops/s is too low"
        fi
        
        # Clean up test keys
        for i in $(seq 1 $operation_count); do
            kubectl exec "$redis_pod" -n "$namespace" -- redis-cli del "perf_test_$i" &> /dev/null &
        done
        wait
    else
        record_test_result "Redis Performance" "FAIL" "Redis primary pod not found"
    fi
}

# Generate test report
generate_test_report() {
    log_info "Generating test report..."
    
    local namespace="$NAMESPACE_PREFIX-$ENVIRONMENT"
    local report_file="$PROJECT_ROOT/test-reports/phase4-test-report-$ENVIRONMENT-$TEST_TYPE-$(date +%Y%m%d-%H%M%S).txt"
    
    mkdir -p "$(dirname "$report_file")"
    
    local pass_rate=$(echo "scale=2; $TESTS_PASSED * 100 / $TESTS_TOTAL" | bc -l)
    
    cat > "$report_file" << EOF
MS5.0 Floor Dashboard - Phase 4 Test Report
==========================================

Environment: $ENVIRONMENT
Test Type: $TEST_TYPE
Test Date: $(date)
Test Duration: $SECONDS seconds

Test Results Summary:
--------------------
Total Tests: $TESTS_TOTAL
Tests Passed: $TESTS_PASSED
Tests Failed: $TESTS_FAILED
Pass Rate: ${pass_rate}%

Test Status: $([ $TESTS_FAILED -eq 0 ] && echo "PASS" || echo "FAIL")

Detailed Results:
----------------
EOF

    if [[ $TESTS_FAILED -eq 0 ]]; then
        cat >> "$report_file" << EOF

✅ ALL TESTS PASSED

The Phase 4 backend services migration has been successfully validated.
All components are functioning correctly and meet the required performance criteria.

Components Tested:
- FastAPI Backend API
- Celery Workers and Beat Scheduler
- Redis Cache (Primary and Replica)
- Flower Monitoring
- Service Discovery and Communication
- Database Connectivity
- Performance Metrics

Next Steps:
1. Proceed with Phase 5 (Frontend & Networking) deployment
2. Continue monitoring system performance
3. Set up production alerts and notifications

EOF
    else
        cat >> "$report_file" << EOF

❌ SOME TESTS FAILED

The Phase 4 backend services migration has issues that need to be addressed
before proceeding to the next phase.

Failed Tests: $TESTS_FAILED
Passed Tests: $TESTS_PASSED

Recommendations:
1. Review failed tests and identify root causes
2. Check pod logs for error messages
3. Verify service configurations
4. Ensure all dependencies are properly configured
5. Re-run tests after fixes

Troubleshooting Commands:
- View pod logs: kubectl logs -l app=ms5-dashboard -n $namespace
- Check pod status: kubectl get pods -l app=ms5-dashboard -n $namespace
- Check service status: kubectl get services -l app=ms5-dashboard -n $namespace
- Check deployment status: kubectl get deployments -l app=ms5-dashboard -n $namespace

EOF
    fi
    
    log_success "Test report generated: $report_file"
    
    # Print summary to console
    echo ""
    log_info "=== TEST SUMMARY ==="
    log_info "Total Tests: $TESTS_TOTAL"
    log_info "Tests Passed: $TESTS_PASSED"
    log_info "Tests Failed: $TESTS_FAILED"
    log_info "Pass Rate: ${pass_rate}%"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All tests passed! Phase 4 backend services are ready."
        return 0
    else
        log_error "Some tests failed. Please review the test report and fix issues before proceeding."
        return 1
    fi
}

# Main testing function
main() {
    log_info "Starting MS5.0 Phase 4 Backend Services Testing"
    log_info "Environment: $ENVIRONMENT"
    log_info "Test Type: $TEST_TYPE"
    
    # Validate environment and prerequisites
    validate_environment
    validate_prerequisites
    
    # Get service endpoints
    get_service_endpoints
    
    # Run tests based on test type
    case "$TEST_TYPE" in
        "smoke")
            run_smoke_tests
            ;;
        "integration")
            run_integration_tests
            ;;
        "performance")
            run_performance_tests
            ;;
        "all")
            run_smoke_tests
            run_integration_tests
            run_performance_tests
            ;;
        *)
            log_error "Unknown test type: $TEST_TYPE"
            exit 1
            ;;
    esac
    
    # Generate test report
    generate_test_report
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
