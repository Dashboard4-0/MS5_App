#!/bin/bash

# MS5.0 Floor Dashboard - Canary Promotion Script
# This script promotes canary deployment to stable

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
TIMEOUT="1800"
BACKEND_IMAGE=""
FRONTEND_IMAGE=""
FORCE_PROMOTE="false"

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Canary Promotion Script for MS5.0 Floor Dashboard

OPTIONS:
    --namespace NAMESPACE           Kubernetes namespace (default: ms5-production)
    --timeout SECONDS              Promotion timeout in seconds (default: 1800)
    --backend-image IMAGE          Backend image to promote (optional)
    --frontend-image IMAGE         Frontend image to promote (optional)
    --force                        Force promotion even if canary is not ready
    --help                         Show this help message

EXAMPLES:
    $0 --namespace ms5-production
    $0 --backend-image ms5acrprod.azurecr.io/ms5-backend:v1.2.3-production --frontend-image ms5acrprod.azurecr.io/ms5-frontend:v1.2.3-production
    $0 --force --timeout 600

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
            --timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            --backend-image)
                BACKEND_IMAGE="$2"
                shift 2
                ;;
            --frontend-image)
                FRONTEND_IMAGE="$2"
                shift 2
                ;;
            --force)
                FORCE_PROMOTE="true"
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
    
    # Check if canary deployments exist
    if ! kubectl get deployment ms5-backend-canary -n "$NAMESPACE" &> /dev/null; then
        log_error "Canary backend deployment not found"
        exit 1
    fi
    
    if ! kubectl get deployment ms5-frontend-canary -n "$NAMESPACE" &> /dev/null; then
        log_error "Canary frontend deployment not found"
        exit 1
    fi
    
    # Check if stable deployments exist
    if ! kubectl get deployment ms5-backend -n "$NAMESPACE" &> /dev/null; then
        log_error "Stable backend deployment not found"
        exit 1
    fi
    
    if ! kubectl get deployment ms5-frontend -n "$NAMESPACE" &> /dev/null; then
        log_error "Stable frontend deployment not found"
        exit 1
    fi
    
    log_success "Prerequisites validated"
}

# Function to get canary images
get_canary_images() {
    log_info "Getting canary images..."
    
    if [[ -z "$BACKEND_IMAGE" ]]; then
        BACKEND_IMAGE=$(kubectl get deployment ms5-backend-canary -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].image}')
    fi
    
    if [[ -z "$FRONTEND_IMAGE" ]]; then
        FRONTEND_IMAGE=$(kubectl get deployment ms5-frontend-canary -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].image}')
    fi
    
    log_info "Backend image: $BACKEND_IMAGE"
    log_info "Frontend image: $FRONTEND_IMAGE"
}

# Function to check canary readiness
check_canary_readiness() {
    log_info "Checking canary readiness..."
    
    # Check if canary pods are ready
    local canary_pods=$(kubectl get pods -l app=ms5-dashboard,version=canary -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
    
    if [[ -z "$canary_pods" ]]; then
        log_error "No canary pods found"
        return 1
    fi
    
    local ready_pods=0
    local total_pods=0
    
    for pod in $canary_pods; do
        total_pods=$((total_pods + 1))
        
        # Check if pod is ready
        if kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' | grep -q "True"; then
            ready_pods=$((ready_pods + 1))
        else
            log_warning "Pod $pod is not ready"
        fi
    done
    
    local readiness_percentage=$((ready_pods * 100 / total_pods))
    
    if [[ "$readiness_percentage" -lt 100 ]]; then
        log_warning "Only $readiness_percentage% of canary pods are ready"
        if [[ "$FORCE_PROMOTE" != "true" ]]; then
            log_error "Cannot promote canary with incomplete readiness"
            return 1
        fi
    fi
    
    log_success "Canary readiness check passed: $readiness_percentage% pods ready"
    return 0
}

# Function to route all traffic to stable
route_traffic_to_stable() {
    log_info "Routing all traffic to stable deployments..."
    
    # Update VirtualService to route all traffic to stable
    cat << EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: ms5-backend-vs
  namespace: $NAMESPACE
spec:
  hosts:
  - ms5-backend-service
  http:
  - route:
    - destination:
        host: ms5-backend-service
        port:
          number: 8000
      weight: 100
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: ms5-frontend-vs
  namespace: $NAMESPACE
spec:
  hosts:
  - ms5-frontend-service
  http:
  - route:
    - destination:
        host: ms5-frontend-service
        port:
          number: 80
      weight: 100
EOF
    
    log_success "Traffic routed to stable deployments"
}

# Function to promote canary to stable
promote_canary_to_stable() {
    log_info "Promoting canary to stable..."
    
    # Update stable backend deployment
    log_info "Updating stable backend deployment..."
    kubectl set image deployment/ms5-backend ms5-backend="$BACKEND_IMAGE" -n "$NAMESPACE"
    
    # Update stable frontend deployment
    log_info "Updating stable frontend deployment..."
    kubectl set image deployment/ms5-frontend ms5-frontend="$FRONTEND_IMAGE" -n "$NAMESPACE"
    
    # Wait for stable deployments to be ready
    log_info "Waiting for stable deployments to be ready..."
    kubectl rollout status deployment/ms5-backend -n "$NAMESPACE" --timeout="$TIMEOUT"
    kubectl rollout status deployment/ms5-frontend -n "$NAMESPACE" --timeout="$TIMEOUT"
    
    log_success "Canary promoted to stable"
}

# Function to verify stable deployment
verify_stable_deployment() {
    log_info "Verifying stable deployment..."
    
    # Check if stable pods are ready
    local stable_pods=$(kubectl get pods -l app=ms5-dashboard,version!=canary -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
    
    if [[ -z "$stable_pods" ]]; then
        log_error "No stable pods found"
        return 1
    fi
    
    local ready_pods=0
    local total_pods=0
    
    for pod in $stable_pods; do
        total_pods=$((total_pods + 1))
        
        # Check if pod is ready
        if kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' | grep -q "True"; then
            ready_pods=$((ready_pods + 1))
        else
            log_warning "Pod $pod is not ready"
        fi
    done
    
    local readiness_percentage=$((ready_pods * 100 / total_pods))
    
    if [[ "$readiness_percentage" -lt 100 ]]; then
        log_error "Only $readiness_percentage% of stable pods are ready"
        return 1
    fi
    
    log_success "Stable deployment verification passed: $readiness_percentage% pods ready"
    return 0
}

# Function to cleanup canary resources
cleanup_canary_resources() {
    log_info "Cleaning up canary resources..."
    
    # Delete canary deployments
    kubectl delete deployment ms5-backend-canary -n "$NAMESPACE" --ignore-not-found=true
    kubectl delete deployment ms5-frontend-canary -n "$NAMESPACE" --ignore-not-found=true
    
    # Delete canary services
    kubectl delete service ms5-backend-canary-service -n "$NAMESPACE" --ignore-not-found=true
    kubectl delete service ms5-frontend-canary-service -n "$NAMESPACE" --ignore-not-found=true
    
    # Wait for canary pods to terminate
    kubectl wait --for=delete pod -l app=ms5-dashboard,version=canary -n "$NAMESPACE" --timeout=300s
    
    log_success "Canary resources cleaned up"
}

# Function to generate promotion report
generate_promotion_report() {
    local promotion_result="$1"
    
    local report_file="/tmp/canary-promotion-report-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$report_file" << EOF
MS5.0 Floor Dashboard - Canary Promotion Report
Generated: $(date)
Namespace: $NAMESPACE
Promotion Result: $promotion_result

Configuration:
- Backend Image: $BACKEND_IMAGE
- Frontend Image: $FRONTEND_IMAGE
- Timeout: ${TIMEOUT}s
- Force Promote: $FORCE_PROMOTE

Stable Deployments:
$(kubectl get deployments -l app=ms5-dashboard,version!=canary -n "$NAMESPACE" -o wide)

Stable Services:
$(kubectl get services -l app=ms5-dashboard,version!=canary -n "$NAMESPACE" -o wide)

Stable Pods:
$(kubectl get pods -l app=ms5-dashboard,version!=canary -n "$NAMESPACE" -o wide)

Promotion Details:
EOF
    
    if [[ "$promotion_result" == "success" ]]; then
        echo "- Canary successfully promoted to stable" >> "$report_file"
        echo "- All traffic routed to stable deployments" >> "$report_file"
        echo "- Canary resources cleaned up" >> "$report_file"
        echo "- Stable deployments verified and ready" >> "$report_file"
    else
        echo "- Canary promotion failed" >> "$report_file"
        echo "- Check deployment status and pod health" >> "$report_file"
        echo "- Consider rolling back if necessary" >> "$report_file"
    fi
    
    log_info "Promotion report generated: $report_file"
    echo "$report_file"
}

# Main function
main() {
    log_info "Starting canary promotion for MS5.0 Floor Dashboard"
    
    # Parse command line arguments
    parse_args "$@"
    
    log_info "Canary promotion configuration:"
    log_info "  Namespace: $NAMESPACE"
    log_info "  Timeout: ${TIMEOUT}s"
    log_info "  Force promote: $FORCE_PROMOTE"
    
    # Validate prerequisites
    validate_prerequisites
    
    # Get canary images
    get_canary_images
    
    # Check canary readiness
    if ! check_canary_readiness; then
        log_error "Canary is not ready for promotion"
        exit 1
    fi
    
    # Route all traffic to stable
    route_traffic_to_stable
    
    # Promote canary to stable
    if ! promote_canary_to_stable; then
        log_error "Failed to promote canary to stable"
        exit 1
    fi
    
    # Verify stable deployment
    if ! verify_stable_deployment; then
        log_error "Stable deployment verification failed"
        exit 1
    fi
    
    # Cleanup canary resources
    cleanup_canary_resources
    
    # Generate promotion report
    local report_file=$(generate_promotion_report "success")
    
    log_success "Canary promotion completed successfully!"
    log_info "Promotion report: $report_file"
    
    # Display summary
    echo ""
    log_info "Promotion Summary:"
    log_info "  Backend image: $BACKEND_IMAGE"
    log_info "  Frontend image: $FRONTEND_IMAGE"
    log_info "  Report: $report_file"
    log_info "  Status: Success"
}

# Run main function
main "$@"
