#!/bin/bash

# MS5.0 Floor Dashboard - Performance Test Script
# This script runs performance tests to validate system performance

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
BASE_URL=""
TIMEOUT="600"
USERS="10"
SPAWN_RATE="2"
RUN_TIME="60"
VERBOSE="false"

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Performance Test Script for MS5.0 Floor Dashboard

OPTIONS:
    --environment ENV             Environment to test (default: production)
    --namespace NAMESPACE         Kubernetes namespace (default: ms5-production)
    --base-url URL               Base URL for testing (optional)
    --timeout SECONDS            Test timeout in seconds (default: 600)
    --users USERS                Number of concurrent users (default: 10)
    --spawn-rate RATE            User spawn rate per second (default: 2)
    --run-time SECONDS           Test run time in seconds (default: 60)
    --verbose                    Enable verbose output
    --help                       Show this help message

EXAMPLES:
    $0 --environment staging --users 20 --run-time 120
    $0 --environment production --base-url https://ms5floor.com --users 50 --spawn-rate 5
    $0 --namespace ms5-staging --timeout 300 --verbose

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
            --users)
                USERS="$2"
                shift 2
                ;;
            --spawn-rate)
                SPAWN_RATE="$2"
                shift 2
                ;;
            --run-time)
                RUN_TIME="$2"
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

# Function to check system resources
check_system_resources() {
    log_info "Checking system resources..."
    
    # Get node resources
    local nodes=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}')
    
    for node in $nodes; do
        local cpu_capacity=$(kubectl get node "$node" -o jsonpath='{.status.capacity.cpu}')
        local memory_capacity=$(kubectl get node "$node" -o jsonpath='{.status.capacity.memory}')
        local cpu_allocatable=$(kubectl get node "$node" -o jsonpath='{.status.allocatable.cpu}')
        local memory_allocatable=$(kubectl get node "$node" -o jsonpath='{.status.allocatable.memory}')
        
        if [[ "$VERBOSE" == "true" ]]; then
            log_info "Node $node: CPU=$cpu_capacity/$cpu_allocatable, Memory=$memory_capacity/$memory_allocatable"
        fi
    done
    
    # Get pod resource usage
    local pods=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
    
    for pod in $pods; do
        local pod_metrics=$(kubectl top pod "$pod" -n "$NAMESPACE" --no-headers 2>/dev/null || echo "0 0")
        local cpu_usage=$(echo "$pod_metrics" | awk '{print $2}' | sed 's/%//')
        local memory_usage=$(echo "$pod_metrics" | awk '{print $3}' | sed 's/%//')
        
        if [[ "$VERBOSE" == "true" ]]; then
            log_info "Pod $pod: CPU=${cpu_usage}%, Memory=${memory_usage}%"
        fi
        
        # Check if pod is using too many resources
        if [[ "$cpu_usage" -gt 80 ]]; then
            log_warning "High CPU usage on pod $pod: ${cpu_usage}%"
        fi
        
        if [[ "$memory_usage" -gt 80 ]]; then
            log_warning "High memory usage on pod $pod: ${memory_usage}%"
        fi
    done
    
    log_success "System resources checked"
}

# Function to run load test
run_load_test() {
    log_info "Running load test..."
    
    # Create temporary locustfile
    local locustfile="/tmp/locustfile_$$.py"
    
    cat > "$locustfile" << EOF
from locust import HttpUser, task, between
import random

class MS5User(HttpUser):
    wait_time = between(1, 3)
    
    def on_start(self):
        """Called when a user starts"""
        pass
    
    @task(3)
    def health_check(self):
        """Health check endpoint"""
        self.client.get("/health")
    
    @task(2)
    def api_status(self):
        """API status endpoint"""
        self.client.get("/api/v1/status")
    
    @task(1)
    def api_metrics(self):
        """API metrics endpoint"""
        self.client.get("/api/v1/metrics")
    
    @task(1)
    def frontend(self):
        """Frontend page"""
        self.client.get("/")
EOF
    
    # Run locust load test
    log_info "Starting load test with $USERS users, spawn rate $SPAWN_RATE, run time ${RUN_TIME}s"
    
    local locust_output="/tmp/locust_output_$$.txt"
    
    if command -v locust &> /dev/null; then
        # Run locust if available
        locust --headless \
            --users "$USERS" \
            --spawn-rate "$SPAWN_RATE" \
            --run-time "${RUN_TIME}s" \
            --host "$BASE_URL" \
            --locustfile "$locustfile" \
            --html "/tmp/locust_report_$$.html" \
            --csv "/tmp/locust_stats_$$" \
            > "$locust_output" 2>&1
        
        local locust_exit_code=$?
        
        if [[ "$locust_exit_code" -eq 0 ]]; then
            log_success "Load test completed successfully"
        else
            log_error "Load test failed with exit code $locust_exit_code"
            cat "$locust_output"
            rm -f "$locustfile" "$locust_output"
            return 1
        fi
        
        # Parse locust results
        if [[ -f "/tmp/locust_stats_$$_stats.csv" ]]; then
            local total_requests=$(tail -n 1 "/tmp/locust_stats_$$_stats.csv" | cut -d',' -f2)
            local total_failures=$(tail -n 1 "/tmp/locust_stats_$$_stats.csv" | cut -d',' -f3)
            local avg_response_time=$(tail -n 1 "/tmp/locust_stats_$$_stats.csv" | cut -d',' -f4)
            local rps=$(tail -n 1 "/tmp/locust_stats_$$_stats.csv" | cut -d',' -f5)
            
            log_info "Load test results:"
            log_info "  Total requests: $total_requests"
            log_info "  Total failures: $total_failures"
            log_info "  Average response time: ${avg_response_time}ms"
            log_info "  Requests per second: $rps"
            
            # Check if results meet performance criteria
            local failure_rate=$((total_failures * 100 / total_requests))
            
            if [[ "$failure_rate" -gt 5 ]]; then
                log_error "Failure rate ${failure_rate}% exceeds threshold 5%"
                rm -f "$locustfile" "$locust_output"
                return 1
            fi
            
            if [[ "$avg_response_time" -gt 1000 ]]; then
                log_warning "Average response time ${avg_response_time}ms exceeds threshold 1000ms"
            fi
        fi
        
        rm -f "$locustfile" "$locust_output"
        
    else
        # Fallback to curl-based load test
        log_warning "Locust not available, using curl-based load test"
        
        local total_requests=0
        local total_failures=0
        local total_response_time=0
        
        local start_time=$(date +%s)
        local end_time=$((start_time + RUN_TIME))
        
        while [[ $(date +%s) -lt $end_time ]]; do
            # Simulate concurrent requests
            for ((i=1; i<=USERS; i++)); do
                local response_time=$(curl -s -o /dev/null -w "%{time_total}" "$BASE_URL/health" --connect-timeout 10 --max-time 30)
                local response_code=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/health" --connect-timeout 10 --max-time 30)
                
                total_requests=$((total_requests + 1))
                total_response_time=$((total_response_time + $(echo "$response_time * 1000" | bc)))
                
                if [[ "$response_code" != "200" ]]; then
                    total_failures=$((total_failures + 1))
                fi
            done
            
            sleep 1
        done
        
        local avg_response_time=$((total_response_time / total_requests))
        local failure_rate=$((total_failures * 100 / total_requests))
        local rps=$((total_requests / RUN_TIME))
        
        log_info "Load test results:"
        log_info "  Total requests: $total_requests"
        log_info "  Total failures: $total_failures"
        log_info "  Average response time: ${avg_response_time}ms"
        log_info "  Requests per second: $rps"
        
        # Check if results meet performance criteria
        if [[ "$failure_rate" -gt 5 ]]; then
            log_error "Failure rate ${failure_rate}% exceeds threshold 5%"
            return 1
        fi
        
        if [[ "$avg_response_time" -gt 1000 ]]; then
            log_warning "Average response time ${avg_response_time}ms exceeds threshold 1000ms"
        fi
        
        rm -f "$locustfile"
    fi
    
    log_success "Load test completed"
    return 0
}

# Function to run stress test
run_stress_test() {
    log_info "Running stress test..."
    
    # Increase load gradually
    local stress_users=("$USERS" "$((USERS * 2))" "$((USERS * 3))")
    local stress_times=(30 30 30)
    
    for i in "${!stress_users[@]}"; do
        local stress_user_count="${stress_users[$i]}"
        local stress_time="${stress_times[$i]}"
        
        log_info "Stress test phase $((i+1)): $stress_user_count users for ${stress_time}s"
        
        # Run stress test phase
        local start_time=$(date +%s)
        local end_time=$((start_time + stress_time))
        local phase_requests=0
        local phase_failures=0
        
        while [[ $(date +%s) -lt $end_time ]]; do
            # Simulate concurrent requests
            for ((j=1; j<=stress_user_count; j++)); do
                local response_code=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/health" --connect-timeout 5 --max-time 10)
                
                phase_requests=$((phase_requests + 1))
                
                if [[ "$response_code" != "200" ]]; then
                    phase_failures=$((phase_failures + 1))
                fi
            done
            
            sleep 1
        done
        
        local phase_failure_rate=$((phase_failures * 100 / phase_requests))
        
        log_info "Stress test phase $((i+1)) results:"
        log_info "  Requests: $phase_requests"
        log_info "  Failures: $phase_failures"
        log_info "  Failure rate: ${phase_failure_rate}%"
        
        # Check if system is still responsive
        if [[ "$phase_failure_rate" -gt 20 ]]; then
            log_error "System became unresponsive during stress test phase $((i+1))"
            return 1
        fi
        
        # Check system resources after stress test
        check_system_resources
    done
    
    log_success "Stress test completed"
    return 0
}

# Function to generate performance test report
generate_performance_report() {
    local test_result="$1"
    
    local report_file="/tmp/performance-test-report-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$report_file" << EOF
MS5.0 Floor Dashboard - Performance Test Report
Generated: $(date)
Environment: $ENVIRONMENT
Namespace: $NAMESPACE
Base URL: $BASE_URL
Test Result: $test_result

Configuration:
- Users: $USERS
- Spawn Rate: $SPAWN_RATE
- Run Time: ${RUN_TIME}s
- Timeout: ${TIMEOUT}s
- Verbose: $VERBOSE

System Resources:
$(kubectl top nodes)

Pod Resources:
$(kubectl top pods -n "$NAMESPACE")

Test Results:
EOF
    
    if [[ "$test_result" == "success" ]]; then
        echo "- All performance tests passed" >> "$report_file"
        echo "- System handled load successfully" >> "$report_file"
        echo "- Response times within acceptable limits" >> "$report_file"
        echo "- No significant resource exhaustion" >> "$report_file"
    else
        echo "- Some performance tests failed" >> "$report_file"
        echo "- System may have performance issues" >> "$report_file"
        echo "- Check response times and resource usage" >> "$report_file"
        echo "- Consider scaling or optimization" >> "$report_file"
    fi
    
    log_info "Performance test report generated: $report_file"
    echo "$report_file"
}

# Main function
main() {
    log_info "Starting performance tests for MS5.0 Floor Dashboard"
    
    # Parse command line arguments
    parse_args "$@"
    
    # Set base URL
    set_base_url
    
    log_info "Performance test configuration:"
    log_info "  Environment: $ENVIRONMENT"
    log_info "  Namespace: $NAMESPACE"
    log_info "  Base URL: $BASE_URL"
    log_info "  Users: $USERS"
    log_info "  Spawn Rate: $SPAWN_RATE"
    log_info "  Run Time: ${RUN_TIME}s"
    log_info "  Timeout: ${TIMEOUT}s"
    log_info "  Verbose: $VERBOSE"
    
    # Validate prerequisites
    validate_prerequisites
    
    # Run performance tests
    local test_success=true
    
    # Check system resources
    if ! check_system_resources; then
        log_error "System resource check failed"
        test_success=false
    fi
    
    # Run load test
    if ! run_load_test; then
        log_error "Load test failed"
        test_success=false
    fi
    
    # Run stress test
    if ! run_stress_test; then
        log_error "Stress test failed"
        test_success=false
    fi
    
    # Generate performance test report
    local result="success"
    if [[ "$test_success" != "true" ]]; then
        result="failure"
    fi
    
    local report_file=$(generate_performance_report "$result")
    
    # Display summary
    echo ""
    log_info "Performance Test Summary:"
    log_info "  Result: $result"
    log_info "  Report: $report_file"
    
    if [[ "$test_success" == "true" ]]; then
        log_success "All performance tests passed!"
        exit 0
    else
        log_error "Some performance tests failed"
        exit 1
    fi
}

# Run main function
main "$@"
