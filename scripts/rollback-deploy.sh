#!/bin/bash

# MS5.0 Floor Dashboard - Rollback Deployment Script
# This script rolls back deployments to previous versions

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
ROLLBACK_TO=""
TIMEOUT="600"
FORCE_ROLLBACK="false"
SERVICES="backend,frontend"

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Rollback Deployment Script for MS5.0 Floor Dashboard

OPTIONS:
    --namespace NAMESPACE           Kubernetes namespace (default: ms5-production)
    --rollback-to REVISION         Rollback to specific revision (leave empty for previous)
    --timeout SECONDS              Rollback timeout in seconds (default: 600)
    --force                        Force rollback even if current deployment is healthy
    --services SERVICES            Comma-separated list of services to rollback (default: backend,frontend)
    --help                         Show this help message

EXAMPLES:
    $0 --namespace ms5-production
    $0 --rollback-to 2 --timeout 300
    $0 --services backend --force

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
            --rollback-to)
                ROLLBACK_TO="$2"
                shift 2
                ;;
            --timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            --force)
                FORCE_ROLLBACK="true"
                shift
                ;;
            --services)
                SERVICES="$2"
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

# Function to validate prerequisites
validate_prerequisites() {
    log_info "Validating prerequisites..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if namespace exists
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_error "Namespace $NAMESPACE does not exist"
        exit 1
    fi
    
    log_success "Prerequisites validated"
}

# Function to check current deployment status
check_current_deployment_status() {
    log_info "Checking current deployment status..."
    
    # Get current deployments
    local deployments=$(kubectl get deployments -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
    
    if [[ -z "$deployments" ]]; then
        log_error "No deployments found in namespace $NAMESPACE"
        return 1
    fi
    
    log_info "Current deployments: $deployments"
    
    # Check deployment status
    for deployment in $deployments; do
        local replicas=$(kubectl get deployment "$deployment" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}')
        local ready_replicas=$(kubectl get deployment "$deployment" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}')
        local available_replicas=$(kubectl get deployment "$deployment" -n "$NAMESPACE" -o jsonpath='{.status.availableReplicas}')
        
        log_info "Deployment $deployment: $ready_replicas/$replicas ready, $available_replicas available"
        
        if [[ "$ready_replicas" != "$replicas" ]]; then
            log_warning "Deployment $deployment is not fully ready"
        fi
    done
    
    log_success "Current deployment status checked"
}

# Function to get rollout history
get_rollout_history() {
    local deployment="$1"
    
    log_info "Getting rollout history for $deployment..."
    
    kubectl rollout history deployment/"$deployment" -n "$NAMESPACE"
}

# Function to rollback deployment
rollback_deployment() {
    local deployment="$1"
    local rollback_to="$2"
    
    log_info "Rolling back deployment $deployment..."
    
    if [[ -n "$rollback_to" ]]; then
        log_info "Rolling back to revision $rollback_to"
        kubectl rollout undo deployment/"$deployment" --to-revision="$rollback_to" -n "$NAMESPACE"
    else
        log_info "Rolling back to previous revision"
        kubectl rollout undo deployment/"$deployment" -n "$NAMESPACE"
    fi
    
    # Wait for rollout to complete
    log_info "Waiting for rollout to complete..."
    kubectl rollout status deployment/"$deployment" -n "$NAMESPACE" --timeout="$TIMEOUT"
    
    log_success "Deployment $deployment rolled back successfully"
}

# Function to verify rollback
verify_rollback() {
    local deployment="$1"
    
    log_info "Verifying rollback for $deployment..."
    
    # Check if deployment is ready
    local replicas=$(kubectl get deployment "$deployment" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}')
    local ready_replicas=$(kubectl get deployment "$deployment" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}')
    local available_replicas=$(kubectl get deployment "$deployment" -n "$NAMESPACE" -o jsonpath='{.status.availableReplicas}')
    
    log_info "Deployment $deployment: $ready_replicas/$replicas ready, $available_replicas available"
    
    if [[ "$ready_replicas" != "$replicas" ]]; then
        log_error "Deployment $deployment is not fully ready after rollback"
        return 1
    fi
    
    if [[ "$available_replicas" != "$replicas" ]]; then
        log_error "Deployment $deployment is not fully available after rollback"
        return 1
    fi
    
    # Check pod health
    local pods=$(kubectl get pods -l app=ms5-dashboard -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
    
    for pod in $pods; do
        local pod_status=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
        local pod_ready=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
        
        if [[ "$pod_status" != "Running" ]] || [[ "$pod_ready" != "True" ]]; then
            log_error "Pod $pod is not healthy after rollback: status=$pod_status, ready=$pod_ready"
            return 1
        fi
    done
    
    log_success "Rollback verification passed for $deployment"
    return 0
}

# Function to run health checks
run_health_checks() {
    log_info "Running health checks..."
    
    # Get backend pods
    local backend_pods=$(kubectl get pods -l app=ms5-dashboard,component=backend -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
    
    for pod in $backend_pods; do
        log_info "Running health check on pod: $pod"
        
        # Check if pod is ready
        if ! kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' | grep -q "True"; then
            log_error "Pod $pod is not ready"
            return 1
        fi
        
        # Run health check endpoint
        if ! kubectl exec "$pod" -n "$NAMESPACE" -- curl -f http://localhost:8000/health &> /dev/null; then
            log_error "Health check failed for pod: $pod"
            return 1
        fi
    done
    
    log_success "Health checks passed"
    return 0
}

# Function to generate rollback report
generate_rollback_report() {
    local rollback_result="$1"
    
    local report_file="/tmp/rollback-report-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$report_file" << EOF
MS5.0 Floor Dashboard - Rollback Report
Generated: $(date)
Namespace: $NAMESPACE
Rollback Result: $rollback_result

Configuration:
- Rollback To: ${ROLLBACK_TO:-"previous revision"}
- Timeout: ${TIMEOUT}s
- Force Rollback: $FORCE_ROLLBACK
- Services: $SERVICES

Current Deployments:
$(kubectl get deployments -n "$NAMESPACE" -o wide)

Current Pods:
$(kubectl get pods -n "$NAMESPACE" -o wide)

Current Services:
$(kubectl get services -n "$NAMESPACE" -o wide)

Rollout History:
EOF
    
    # Add rollout history for each service
    IFS=',' read -ra SERVICE_ARRAY <<< "$SERVICES"
    for service in "${SERVICE_ARRAY[@]}"; do
        echo "" >> "$report_file"
        echo "=== $service ===" >> "$report_file"
        kubectl rollout history deployment/"ms5-$service" -n "$NAMESPACE" >> "$report_file" 2>/dev/null || echo "No history available" >> "$report_file"
    done
    
    echo "" >> "$report_file"
    echo "Recommendations:" >> "$report_file"
    
    if [[ "$rollback_result" == "success" ]]; then
        echo "- Rollback completed successfully" >> "$report_file"
        echo "- All services are healthy and ready" >> "$report_file"
        echo "- Monitor system performance and user experience" >> "$report_file"
        echo "- Consider investigating the cause of the original issue" >> "$report_file"
    else
        echo "- Rollback failed or incomplete" >> "$report_file"
        echo "- Check deployment status and pod health" >> "$report_file"
        echo "- Consider manual intervention" >> "$report_file"
        echo "- Review logs for error details" >> "$report_file"
    fi
    
    log_info "Rollback report generated: $report_file"
    echo "$report_file"
}

# Main function
main() {
    log_info "Starting rollback for MS5.0 Floor Dashboard"
    
    # Parse command line arguments
    parse_args "$@"
    
    log_info "Rollback configuration:"
    log_info "  Namespace: $NAMESPACE"
    log_info "  Rollback to: ${ROLLBACK_TO:-"previous revision"}"
    log_info "  Timeout: ${TIMEOUT}s"
    log_info "  Force rollback: $FORCE_ROLLBACK"
    log_info "  Services: $SERVICES"
    
    # Validate prerequisites
    validate_prerequisites
    
    # Check current deployment status
    if ! check_current_deployment_status; then
        log_error "Failed to check current deployment status"
        exit 1
    fi
    
    # Rollback each service
    IFS=',' read -ra SERVICE_ARRAY <<< "$SERVICES"
    local rollback_success=true
    
    for service in "${SERVICE_ARRAY[@]}"; do
        local deployment="ms5-$service"
        
        # Check if deployment exists
        if ! kubectl get deployment "$deployment" -n "$NAMESPACE" &> /dev/null; then
            log_warning "Deployment $deployment not found, skipping"
            continue
        fi
        
        # Get rollout history
        get_rollout_history "$deployment"
        
        # Rollback deployment
        if ! rollback_deployment "$deployment" "$ROLLBACK_TO"; then
            log_error "Failed to rollback deployment $deployment"
            rollback_success=false
            continue
        fi
        
        # Verify rollback
        if ! verify_rollback "$deployment"; then
            log_error "Rollback verification failed for $deployment"
            rollback_success=false
            continue
        fi
    done
    
    # Run health checks
    if ! run_health_checks; then
        log_error "Health checks failed after rollback"
        rollback_success=false
    fi
    
    # Generate rollback report
    local result="success"
    if [[ "$rollback_success" != "true" ]]; then
        result="failure"
    fi
    
    local report_file=$(generate_rollback_report "$result")
    
    # Display summary
    echo ""
    log_info "Rollback Summary:"
    log_info "  Result: $result"
    log_info "  Report: $report_file"
    
    if [[ "$rollback_success" == "true" ]]; then
        log_success "Rollback completed successfully!"
        exit 0
    else
        log_error "Rollback completed with errors"
        exit 1
    fi
}

# Run main function
main "$@"
