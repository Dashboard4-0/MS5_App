#!/bin/bash

# MS5.0 Floor Dashboard - Phase 9 Network Policy Testing Script
# This script tests all network policies to ensure proper micro-segmentation
# Designed with starship-grade precision and reliability

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NAMESPACE="ms5-production"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${PROJECT_ROOT}/logs/phase9-network-policy-test-${TIMESTAMP}.log"

# Environment variables
TEST_TIMEOUT=${TEST_TIMEOUT:-30}
VERBOSE=${VERBOSE:-false}
SKIP_CLEANUP=${SKIP_CLEANUP:-false}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_section() {
    echo -e "${PURPLE}[SECTION]${NC} $1" | tee -a "$LOG_FILE"
}

# Create log directory
mkdir -p "$(dirname "$LOG_FILE")"

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
WARNING_TESTS=0

# Test result tracking
declare -A TEST_RESULTS

# Function to record test result
record_test() {
    local test_name="$1"
    local status="$2"
    local message="$3"
    
    TEST_RESULTS["$test_name"]="$status|$message"
    
    case "$status" in
        "PASS")
            ((PASSED_TESTS++))
            log_success "$test_name: $message"
            ;;
        "FAIL")
            ((FAILED_TESTS++))
            log_error "$test_name: $message"
            ;;
        "WARN")
            ((WARNING_TESTS++))
            log_warning "$test_name: $message"
            ;;
    esac
    
    ((TOTAL_TESTS++))
}

# Function to create test pod
create_test_pod() {
    local pod_name="$1"
    local labels="$2"
    local image="${3:-busybox:1.35}"
    
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: $pod_name
  namespace: $NAMESPACE
  labels:
    app: network-test
    $labels
spec:
  containers:
  - name: test-container
    image: $image
    command: ['sleep', '3600']
    resources:
      requests:
        cpu: 10m
        memory: 32Mi
      limits:
        cpu: 50m
        memory: 64Mi
  restartPolicy: Never
EOF
}

# Function to wait for pod to be ready
wait_for_pod() {
    local pod_name="$1"
    local timeout="${2:-60}"
    
    log_info "Waiting for pod $pod_name to be ready (timeout: ${timeout}s)..."
    
    if kubectl wait --for=condition=ready pod/"$pod_name" -n "$NAMESPACE" --timeout="${timeout}s" &> /dev/null; then
        return 0
    else
        log_warning "Pod $pod_name not ready within ${timeout}s"
        return 1
    fi
}

# Function to test network connectivity
test_connectivity() {
    local from_pod="$1"
    local to_host="$2"
    local to_port="$3"
    local protocol="${4:-tcp}"
    local should_succeed="${5:-true}"
    
    local test_name="connectivity-$from_pod-to-$to_host-$to_port"
    
    log_info "Testing $protocol connectivity from $from_pod to $to_host:$to_port"
    
    # Test connectivity using appropriate tool
    local cmd=""
    case "$protocol" in
        "tcp")
            cmd="nc -z -w5 $to_host $to_port"
            ;;
        "udp")
            cmd="nc -u -z -w5 $to_host $to_port"
            ;;
        "http")
            cmd="wget -q --timeout=5 --tries=1 -O- http://$to_host:$to_port"
            ;;
        "https")
            cmd="wget -q --timeout=5 --tries=1 -O- https://$to_host:$to_port"
            ;;
        *)
            log_error "Unsupported protocol: $protocol"
            return 1
            ;;
    esac
    
    # Execute the test
    if kubectl exec "$from_pod" -n "$NAMESPACE" -- sh -c "$cmd" &> /dev/null; then
        if [ "$should_succeed" = "true" ]; then
            record_test "$test_name" "PASS" "Connection successful as expected"
        else
            record_test "$test_name" "FAIL" "Connection succeeded but should have been blocked"
        fi
    else
        if [ "$should_succeed" = "false" ]; then
            record_test "$test_name" "PASS" "Connection blocked as expected"
        else
            record_test "$test_name" "FAIL" "Connection failed but should have succeeded"
        fi
    fi
}

# Function to cleanup test resources
cleanup_test_resources() {
    if [ "$SKIP_CLEANUP" = "true" ]; then
        log_info "Skipping cleanup as requested"
        return 0
    fi
    
    log_section "Cleaning up test resources"
    
    # Delete all test pods
    kubectl delete pods -n "$NAMESPACE" -l app=network-test --ignore-not-found=true
    
    # Wait for pods to be deleted
    kubectl wait --for=delete pod -l app=network-test -n "$NAMESPACE" --timeout=60s || true
    
    log_success "Test resources cleaned up"
}

# Function to test deny-all policy
test_deny_all_policy() {
    log_section "Testing Deny-All Network Policy"
    
    # Create test pods
    create_test_pod "test-pod-1" "component: backend"
    create_test_pod "test-pod-2" "component: database"
    
    # Wait for pods to be ready
    wait_for_pod "test-pod-1" 60
    wait_for_pod "test-pod-2" 60
    
    # Test that pods cannot communicate with each other (should be blocked)
    test_connectivity "test-pod-1" "test-pod-2" "80" "tcp" "false"
    
    # Test external connectivity (should be blocked)
    test_connectivity "test-pod-1" "8.8.8.8" "53" "udp" "false"
}

# Function to test backend network policy
test_backend_network_policy() {
    log_section "Testing Backend Network Policy"
    
    # Create test pods
    create_test_pod "test-backend" "component: backend"
    create_test_pod "test-database" "component: database"
    create_test_pod "test-redis" "component: redis"
    create_test_pod "test-external" "component: external"
    
    # Wait for pods to be ready
    wait_for_pod "test-backend" 60
    wait_for_pod "test-database" 60
    wait_for_pod "test-redis" 60
    wait_for_pod "test-external" 60
    
    # Test allowed connections (should succeed)
    test_connectivity "test-backend" "test-database" "5432" "tcp" "true"
    test_connectivity "test-backend" "test-redis" "6379" "tcp" "true"
    
    # Test blocked connections (should fail)
    test_connectivity "test-backend" "test-external" "80" "tcp" "false"
    test_connectivity "test-backend" "8.8.8.8" "53" "udp" "false"
}

# Function to test database network policy
test_database_network_policy() {
    log_section "Testing Database Network Policy"
    
    # Create test pods
    create_test-pod "test-backend" "component: backend"
    create_test_pod "test-database" "component: database"
    create_test_pod "test-external" "component: external"
    
    # Wait for pods to be ready
    wait_for_pod "test-backend" 60
    wait_for_pod "test-database" 60
    wait_for_pod "test-external" 60
    
    # Test allowed connections (should succeed)
    test_connectivity "test-backend" "test-database" "5432" "tcp" "true"
    
    # Test blocked connections (should fail)
    test_connectivity "test-external" "test-database" "5432" "tcp" "false"
    test_connectivity "test-database" "test-backend" "8000" "tcp" "false"
}

# Function to test Redis network policy
test_redis_network_policy() {
    log_section "Testing Redis Network Policy"
    
    # Create test pods
    create_test_pod "test-backend" "component: backend"
    create_test_pod "test-redis" "component: redis"
    create_test_pod "test-external" "component: external"
    
    # Wait for pods to be ready
    wait_for_pod "test-backend" 60
    wait_for_pod "test-redis" 60
    wait_for_pod "test-external" 60
    
    # Test allowed connections (should succeed)
    test_connectivity "test-backend" "test-redis" "6379" "tcp" "true"
    
    # Test blocked connections (should fail)
    test_connectivity "test-external" "test-redis" "6379" "tcp" "false"
    test_connectivity "test-redis" "test-backend" "8000" "tcp" "false"
}

# Function to test MinIO network policy
test_minio_network_policy() {
    log_section "Testing MinIO Network Policy"
    
    # Create test pods
    create_test_pod "test-backend" "component: backend"
    create_test_pod "test-minio" "component: minio"
    create_test_pod "test-external" "component: external"
    
    # Wait for pods to be ready
    wait_for_pod "test-backend" 60
    wait_for_pod "test-minio" 60
    wait_for_pod "test-external" 60
    
    # Test allowed connections (should succeed)
    test_connectivity "test-backend" "test-minio" "9000" "tcp" "true"
    test_connectivity "test-backend" "test-minio" "9001" "tcp" "true"
    
    # Test blocked connections (should fail)
    test_connectivity "test-external" "test-minio" "9000" "tcp" "false"
    test_connectivity "test-minio" "test-backend" "8000" "tcp" "false"
}

# Function to test monitoring network policy
test_monitoring_network_policy() {
    log_section "Testing Monitoring Network Policy"
    
    # Create test pods
    create_test_pod "test-prometheus" "component: prometheus"
    create_test_pod "test-grafana" "component: grafana"
    create_test_pod "test-backend" "component: backend"
    create_test_pod "test-external" "component: external"
    
    # Wait for pods to be ready
    wait_for_pod "test-prometheus" 60
    wait_for_pod "test-grafana" 60
    wait_for_pod "test-backend" 60
    wait_for_pod "test-external" 60
    
    # Test allowed connections (should succeed)
    test_connectivity "test-grafana" "test-prometheus" "9090" "tcp" "true"
    test_connectivity "test-prometheus" "test-backend" "8000" "tcp" "true"
    
    # Test blocked connections (should fail)
    test_connectivity "test-external" "test-prometheus" "9090" "tcp" "false"
    test_connectivity "test-prometheus" "test-external" "80" "tcp" "false"
}

# Function to test Grafana network policy
test_grafana_network_policy() {
    log_section "Testing Grafana Network Policy"
    
    # Create test pods
    create_test_pod "test-grafana" "component: grafana"
    create_test_pod "test-prometheus" "component: prometheus"
    create_test_pod "test-external" "component: external"
    
    # Wait for pods to be ready
    wait_for_pod "test-grafana" 60
    wait_for_pod "test-prometheus" 60
    wait_for_pod "test-external" 60
    
    # Test allowed connections (should succeed)
    test_connectivity "test-grafana" "test-prometheus" "9090" "tcp" "true"
    
    # Test blocked connections (should fail)
    test_connectivity "test-external" "test-grafana" "3000" "tcp" "false"
    test_connectivity "test-grafana" "test-external" "80" "tcp" "false"
}

# Function to test AlertManager network policy
test_alertmanager_network_policy() {
    log_section "Testing AlertManager Network Policy"
    
    # Create test pods
    create_test_pod "test-alertmanager" "component: alertmanager"
    create_test_pod "test-prometheus" "component: prometheus"
    create_test_pod "test-backend" "component: backend"
    create_test_pod "test-external" "component: external"
    
    # Wait for pods to be ready
    wait_for_pod "test-alertmanager" 60
    wait_for_pod "test-prometheus" 60
    wait_for_pod "test-backend" 60
    wait_for_pod "test-external" 60
    
    # Test allowed connections (should succeed)
    test_connectivity "test-prometheus" "test-alertmanager" "9093" "tcp" "true"
    test_connectivity "test-alertmanager" "test-backend" "8000" "tcp" "true"
    
    # Test blocked connections (should fail)
    test_connectivity "test-external" "test-alertmanager" "9093" "tcp" "false"
    test_connectivity "test-alertmanager" "test-external" "80" "tcp" "false"
}

# Function to test Celery network policy
test_celery_network_policy() {
    log_section "Testing Celery Network Policy"
    
    # Create test pods
    create_test_pod "test-celery-worker" "component: celery-worker"
    create_test_pod "test-flower" "component: flower"
    create_test_pod "test-database" "component: database"
    create_test_pod "test-redis" "component: redis"
    create_test_pod "test-minio" "component: minio"
    create_test_pod "test-external" "component: external"
    
    # Wait for pods to be ready
    wait_for_pod "test-celery-worker" 60
    wait_for_pod "test-flower" 60
    wait_for_pod "test-database" 60
    wait_for_pod "test-redis" 60
    wait_for_pod "test-minio" 60
    wait_for_pod "test-external" 60
    
    # Test allowed connections (should succeed)
    test_connectivity "test-flower" "test-celery-worker" "5555" "tcp" "true"
    test_connectivity "test-celery-worker" "test-database" "5432" "tcp" "true"
    test_connectivity "test-celery-worker" "test-redis" "6379" "tcp" "true"
    test_connectivity "test-celery-worker" "test-minio" "9000" "tcp" "true"
    
    # Test blocked connections (should fail)
    test_connectivity "test-external" "test-celery-worker" "5555" "tcp" "false"
    test_connectivity "test-celery-worker" "test-external" "80" "tcp" "false"
}

# Function to test DNS resolution
test_dns_resolution() {
    log_section "Testing DNS Resolution"
    
    # Create test pod
    create_test_pod "test-dns" "component: backend"
    
    # Wait for pod to be ready
    wait_for_pod "test-dns" 60
    
    # Test DNS resolution
    local dns_test_name="dns-resolution"
    
    if kubectl exec "test-dns" -n "$NAMESPACE" -- nslookup kubernetes.default.svc.cluster.local &> /dev/null; then
        record_test "$dns_test_name" "PASS" "DNS resolution working correctly"
    else
        record_test "$dns_test_name" "FAIL" "DNS resolution failed"
    fi
    
    # Test external DNS resolution
    local external_dns_test_name="external-dns-resolution"
    
    if kubectl exec "test-dns" -n "$NAMESPACE" -- nslookup google.com &> /dev/null; then
        record_test "$external_dns_test_name" "PASS" "External DNS resolution working correctly"
    else
        record_test "$external_dns_test_name" "WARN" "External DNS resolution failed (may be expected)"
    fi
}

# Function to test ingress connectivity
test_ingress_connectivity() {
    log_section "Testing Ingress Connectivity"
    
    # Create test pod
    create_test_pod "test-ingress" "component: backend"
    
    # Wait for pod to be ready
    wait_for_pod "test-ingress" 60
    
    # Test internal service connectivity
    local services=(
        "ms5-backend:8000"
        "ms5-grafana:3000"
        "ms5-prometheus:9090"
        "ms5-flower:5555"
    )
    
    for service in "${services[@]}"; do
        local service_name=$(echo "$service" | cut -d: -f1)
        local service_port=$(echo "$service" | cut -d: -f2)
        
        local test_name="ingress-$service_name"
        
        if kubectl exec "test-ingress" -n "$NAMESPACE" -- nc -z -w5 "$service_name" "$service_port" &> /dev/null; then
            record_test "$test_name" "PASS" "Service $service_name:$service_port accessible"
        else
            record_test "$test_name" "WARN" "Service $service_name:$service_port not accessible (may not be running)"
        fi
    done
}

# Function to generate test report
generate_test_report() {
    log_section "Generating Network Policy Test Report"
    
    local report_file="${PROJECT_ROOT}/logs/phase9-network-policy-test-report-${TIMESTAMP}.md"
    
    cat > "$report_file" << EOF
# MS5.0 Floor Dashboard - Phase 9 Network Policy Test Report

**Generated**: $(date)
**Environment**: Production
**Namespace**: $NAMESPACE
**Test Timeout**: ${TEST_TIMEOUT}s

## Summary

- **Total Tests**: $TOTAL_TESTS
- **Passed**: $PASSED_TESTS
- **Failed**: $FAILED_TESTS
- **Warnings**: $WARNING_TESTS
- **Success Rate**: $(( (PASSED_TESTS * 100) / TOTAL_TESTS ))%

## Detailed Results

EOF

    # Add detailed results
    for test_name in "${!TEST_RESULTS[@]}"; do
        local result="${TEST_RESULTS[$test_name]}"
        local status="${result%%|*}"
        local message="${result#*|}"
        
        local status_icon=""
        case "$status" in
            "PASS") status_icon="✅" ;;
            "FAIL") status_icon="❌" ;;
            "WARN") status_icon="⚠️" ;;
        esac
        
        echo "- $status_icon **$test_name**: $message" >> "$report_file"
    done
    
    echo "" >> "$report_file"
    echo "## Recommendations" >> "$report_file"
    
    if [ $FAILED_TESTS -gt 0 ]; then
        echo "- ❌ **CRITICAL**: Fix all failed network policy tests before proceeding with deployment" >> "$report_file"
    fi
    
    if [ $WARNING_TESTS -gt 0 ]; then
        echo "- ⚠️ **WARNING**: Review and address network policy warnings before production deployment" >> "$report_file"
    fi
    
    if [ $FAILED_TESTS -eq 0 ] && [ $WARNING_TESTS -eq 0 ]; then
        echo "- ✅ **READY**: Network policies are working correctly and ready for production" >> "$report_file"
    fi
    
    log_success "Network policy test report generated: $report_file"
}

# Main test function
main() {
    log "Starting MS5.0 Floor Dashboard Phase 9 Network Policy Testing"
    log "Environment: Production"
    log "Namespace: $NAMESPACE"
    log "Log file: $LOG_FILE"
    
    # Set up cleanup trap
    trap cleanup_test_resources EXIT
    
    # Run all network policy tests
    test_deny_all_policy
    test_backend_network_policy
    test_database_network_policy
    test_redis_network_policy
    test_minio_network_policy
    test_monitoring_network_policy
    test_grafana_network_policy
    test_alertmanager_network_policy
    test_celery_network_policy
    test_dns_resolution
    test_ingress_connectivity
    
    # Generate report
    generate_test_report
    
    # Summary
    log_section "Network Policy Test Summary"
    log "Total Tests: $TOTAL_TESTS"
    log_success "Passed: $PASSED_TESTS"
    if [ $FAILED_TESTS -gt 0 ]; then
        log_error "Failed: $FAILED_TESTS"
    else
        log_success "Failed: $FAILED_TESTS"
    fi
    if [ $WARNING_TESTS -gt 0 ]; then
        log_warning "Warnings: $WARNING_TESTS"
    else
        log_success "Warnings: $WARNING_TESTS"
    fi
    
    # Exit with appropriate code
    if [ $FAILED_TESTS -gt 0 ]; then
        log_error "Network policy testing failed. Please fix all failed tests before proceeding."
        exit 1
    elif [ $WARNING_TESTS -gt 0 ]; then
        log_warning "Network policy testing completed with warnings. Please review warnings before proceeding."
        exit 0
    else
        log_success "Network policy testing completed successfully. Network policies are working correctly."
        exit 0
    fi
}

# Handle script arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --timeout)
            TEST_TIMEOUT="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --skip-cleanup)
            SKIP_CLEANUP=true
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --timeout SECONDS    Test timeout in seconds (default: 30)"
            echo "  --verbose           Enable verbose output"
            echo "  --skip-cleanup      Skip cleanup of test resources"
            echo "  --help              Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Run main function
main "$@"
