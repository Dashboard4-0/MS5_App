#!/bin/bash

# MS5.0 Floor Dashboard - Canary Monitoring Script
# This script monitors canary deployment metrics and health

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
NAMESPACE="ms5-production"
CANARY_PERCENTAGE="10"
MAX_CANARY_PERCENTAGE="50"
PROMOTION_THRESHOLD="1"
TIMEOUT="1800"
MONITORING_INTERVAL="30"
ERROR_RATE_THRESHOLD="5"
RESPONSE_TIME_THRESHOLD="1000"

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Canary Monitoring Script for MS5.0 Floor Dashboard

OPTIONS:
    --namespace NAMESPACE           Kubernetes namespace (default: ms5-production)
    --canary-percentage PERCENT    Current canary traffic percentage (default: 10)
    --max-canary-percentage PERCENT Maximum canary traffic percentage (default: 50)
    --promotion-threshold PERCENT  Error rate threshold for promotion (default: 1)
    --timeout SECONDS              Monitoring timeout in seconds (default: 1800)
    --monitoring-interval SECONDS  Monitoring interval in seconds (default: 30)
    --error-rate-threshold PERCENT Error rate threshold for rollback (default: 5)
    --response-time-threshold MS   Response time threshold for rollback (default: 1000)
    --help                         Show this help message

EXAMPLES:
    $0 --namespace ms5-production --canary-percentage 20
    $0 --canary-percentage 30 --max-canary-percentage 50 --timeout 600

EOF
}

# Function to parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            --canary-percentage)
                CANARY_PERCENTAGE="$2"
                shift 2
                ;;
            --max-canary-percentage)
                MAX_CANARY_PERCENTAGE="$2"
                shift 2
                ;;
            --promotion-threshold)
                PROMOTION_THRESHOLD="$2"
                shift 2
                ;;
            --timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            --monitoring-interval)
                MONITORING_INTERVAL="$2"
                shift 2
                ;;
            --error-rate-threshold)
                ERROR_RATE_THRESHOLD="$2"
                shift 2
                ;;
            --response-time-threshold)
                RESPONSE_TIME_THRESHOLD="$2"
                shift 2
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

# Function to get canary pod metrics
get_canary_pod_metrics() {
    local pod_name="$1"
    
    # Get pod resource usage
    local pod_metrics=$(kubectl top pod "$pod_name" -n "$NAMESPACE" --no-headers 2>/dev/null || echo "0 0")
    local cpu_usage=$(echo "$pod_metrics" | awk '{print $2}' | sed 's/%//')
    local memory_usage=$(echo "$pod_metrics" | awk '{print $3}' | sed 's/%//')
    
    # Get pod status
    local pod_status=$(kubectl get pod "$pod_name" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
    local pod_ready=$(kubectl get pod "$pod_name" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
    
    # Get pod restart count
    local restart_count=$(kubectl get pod "$pod_name" -n "$NAMESPACE" -o jsonpath='{.status.containerStatuses[0].restartCount}')
    
    echo "$cpu_usage,$memory_usage,$pod_status,$pod_ready,$restart_count"
}

# Function to get canary service metrics
get_canary_service_metrics() {
    local service_name="$1"
    
    # Get service endpoints
    local endpoints=$(kubectl get endpoints "$service_name" -n "$NAMESPACE" -o jsonpath='{.subsets[*].addresses[*].ip}' | wc -w)
    
    # Get service port
    local service_port=$(kubectl get service "$service_name" -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].port}')
    
    echo "$endpoints,$service_port"
}

# Function to simulate application metrics (in real implementation, this would query Prometheus)
get_application_metrics() {
    local canary_percentage="$1"
    
    # Simulate metrics based on canary percentage
    local base_requests=$((100 + canary_percentage * 2))
    local base_errors=$((RANDOM % 3))
    local base_response_time=$((200 + RANDOM % 100))
    
    # Add some variance based on canary percentage
    local variance=$((canary_percentage / 10))
    local requests=$((base_requests + RANDOM % variance))
    local errors=$((base_errors + RANDOM % variance))
    local response_time=$((base_response_time + RANDOM % variance))
    
    # Calculate error rate
    local error_rate=$((errors * 100 / requests))
    
    echo "$requests,$errors,$error_rate,$response_time"
}

# Function to check canary health
check_canary_health() {
    local canary_percentage="$1"
    
    log_info "Checking canary health for $canary_percentage% traffic..."
    
    # Get canary pods
    local canary_pods=$(kubectl get pods -l app=ms5-dashboard,version=canary -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
    
    if [[ -z "$canary_pods" ]]; then
        log_error "No canary pods found"
        return 1
    fi
    
    local healthy_pods=0
    local total_pods=0
    
    for pod in $canary_pods; do
        total_pods=$((total_pods + 1))
        
        # Get pod metrics
        local metrics=$(get_canary_pod_metrics "$pod")
        IFS=',' read -r cpu_usage memory_usage pod_status pod_ready restart_count <<< "$metrics"
        
        log_info "Pod $pod: CPU=${cpu_usage}%, Memory=${memory_usage}%, Status=$pod_status, Ready=$pod_ready, Restarts=$restart_count"
        
        # Check if pod is healthy
        if [[ "$pod_status" == "Running" ]] && [[ "$pod_ready" == "True" ]] && [[ "$restart_count" -lt 3 ]]; then
            healthy_pods=$((healthy_pods + 1))
        else
            log_warning "Pod $pod is not healthy"
        fi
        
        # Check resource usage thresholds
        if [[ "$cpu_usage" -gt 80 ]]; then
            log_warning "High CPU usage on pod $pod: ${cpu_usage}%"
        fi
        
        if [[ "$memory_usage" -gt 80 ]]; then
            log_warning "High memory usage on pod $pod: ${memory_usage}%"
        fi
    done
    
    # Check if majority of pods are healthy
    local health_percentage=$((healthy_pods * 100 / total_pods))
    if [[ "$health_percentage" -lt 80 ]]; then
        log_error "Only $health_percentage% of canary pods are healthy"
        return 1
    fi
    
    log_success "Canary health check passed: $health_percentage% pods healthy"
    return 0
}

# Function to monitor canary metrics
monitor_canary_metrics() {
    local canary_percentage="$1"
    
    log_info "Monitoring canary metrics for $canary_percentage% traffic..."
    
    local start_time=$(date +%s)
    local end_time=$((start_time + TIMEOUT))
    local total_requests=0
    local total_errors=0
    local max_response_time=0
    local min_response_time=999999
    
    while [[ $(date +%s) -lt $end_time ]]; do
        # Check canary health
        if ! check_canary_health "$canary_percentage"; then
            log_error "Canary health check failed"
            return 1
        fi
        
        # Get application metrics
        local metrics=$(get_application_metrics "$canary_percentage")
        IFS=',' read -r requests errors error_rate response_time <<< "$metrics"
        
        # Update totals
        total_requests=$((total_requests + requests))
        total_errors=$((total_errors + errors))
        
        # Update response time extremes
        if [[ "$response_time" -gt "$max_response_time" ]]; then
            max_response_time="$response_time"
        fi
        if [[ "$response_time" -lt "$min_response_time" ]]; then
            min_response_time="$response_time"
        fi
        
        # Calculate overall error rate
        local overall_error_rate=$((total_errors * 100 / total_requests))
        
        log_info "Metrics: ${requests} requests, ${errors} errors, ${error_rate}% error rate, ${response_time}ms response time"
        log_info "Totals: ${total_requests} requests, ${total_errors} errors, ${overall_error_rate}% overall error rate"
        
        # Check error rate threshold
        if [[ "$overall_error_rate" -gt "$ERROR_RATE_THRESHOLD" ]]; then
            log_error "Overall error rate ${overall_error_rate}% exceeds threshold ${ERROR_RATE_THRESHOLD}%"
            return 1
        fi
        
        # Check response time threshold
        if [[ "$response_time" -gt "$RESPONSE_TIME_THRESHOLD" ]]; then
            log_error "Response time ${response_time}ms exceeds threshold ${RESPONSE_TIME_THRESHOLD}ms"
            return 1
        fi
        
        # Check promotion threshold
        if [[ "$overall_error_rate" -lt "$PROMOTION_THRESHOLD" ]]; then
            log_success "Error rate ${overall_error_rate}% is below promotion threshold ${PROMOTION_THRESHOLD}%"
            return 0
        fi
        
        sleep "$MONITORING_INTERVAL"
    done
    
    log_success "Canary monitoring completed successfully"
    log_info "Final metrics: ${total_requests} total requests, ${total_errors} total errors, ${overall_error_rate}% overall error rate"
    log_info "Response time range: ${min_response_time}ms - ${max_response_time}ms"
    
    return 0
}

# Function to generate monitoring report
generate_monitoring_report() {
    local canary_percentage="$1"
    local monitoring_result="$2"
    
    local report_file="/tmp/canary-monitoring-report-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$report_file" << EOF
MS5.0 Floor Dashboard - Canary Monitoring Report
Generated: $(date)
Namespace: $NAMESPACE
Canary Percentage: $canary_percentage%
Monitoring Result: $monitoring_result

Configuration:
- Max Canary Percentage: $MAX_CANARY_PERCENTAGE%
- Promotion Threshold: $PROMOTION_THRESHOLD%
- Error Rate Threshold: $ERROR_RATE_THRESHOLD%
- Response Time Threshold: ${RESPONSE_TIME_THRESHOLD}ms
- Monitoring Interval: ${MONITORING_INTERVAL}s
- Timeout: ${TIMEOUT}s

Canary Pods:
$(kubectl get pods -l app=ms5-dashboard,version=canary -n "$NAMESPACE" -o wide)

Canary Services:
$(kubectl get services -l version=canary -n "$NAMESPACE" -o wide)

Recommendations:
EOF
    
    if [[ "$monitoring_result" == "success" ]]; then
        echo "- Canary deployment is healthy and ready for promotion" >> "$report_file"
        if [[ "$canary_percentage" -lt "$MAX_CANARY_PERCENTAGE" ]]; then
            echo "- Consider increasing canary traffic percentage" >> "$report_file"
        else
            echo "- Canary has reached maximum traffic percentage" >> "$report_file"
        fi
    else
        echo "- Canary deployment has issues and should be rolled back" >> "$report_file"
        echo "- Investigate error rates and response times" >> "$report_file"
        echo "- Check pod health and resource usage" >> "$report_file"
    fi
    
    log_info "Monitoring report generated: $report_file"
    echo "$report_file"
}

# Main function
main() {
    log_info "Starting canary monitoring for MS5.0 Floor Dashboard"
    
    # Parse command line arguments
    parse_args "$@"
    
    log_info "Canary monitoring configuration:"
    log_info "  Namespace: $NAMESPACE"
    log_info "  Canary percentage: $CANARY_PERCENTAGE%"
    log_info "  Max canary percentage: $MAX_CANARY_PERCENTAGE%"
    log_info "  Promotion threshold: $PROMOTION_THRESHOLD%"
    log_info "  Error rate threshold: $ERROR_RATE_THRESHOLD%"
    log_info "  Response time threshold: ${RESPONSE_TIME_THRESHOLD}ms"
    log_info "  Monitoring interval: ${MONITORING_INTERVAL}s"
    log_info "  Timeout: ${TIMEOUT}s"
    
    # Monitor canary metrics
    if monitor_canary_metrics "$CANARY_PERCENTAGE"; then
        local result="success"
        log_success "Canary monitoring completed successfully"
    else
        local result="failure"
        log_error "Canary monitoring failed"
    fi
    
    # Generate monitoring report
    local report_file=$(generate_monitoring_report "$CANARY_PERCENTAGE" "$result")
    
    # Display summary
    echo ""
    log_info "Monitoring Summary:"
    log_info "  Result: $result"
    log_info "  Report: $report_file"
    
    if [[ "$result" == "success" ]]; then
        log_info "  Recommendation: Canary is ready for promotion"
        exit 0
    else
        log_info "  Recommendation: Canary should be rolled back"
        exit 1
    fi
}

# Run main function
main "$@"
