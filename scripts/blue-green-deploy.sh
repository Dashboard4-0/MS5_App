#!/bin/bash

# MS5.0 Floor Dashboard - Blue-Green Deployment Script
# This script implements blue-green deployment for zero-downtime deployments

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
BACKEND_IMAGE=""
FRONTEND_IMAGE=""
TIMEOUT="1800"
ROLLBACK_ON_FAILURE="true"
HEALTH_CHECK_TIMEOUT="300"
TRAFFIC_SWITCH_TIMEOUT="60"

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Blue-Green Deployment Script for MS5.0 Floor Dashboard

OPTIONS:
    --backend-image IMAGE     Backend Docker image to deploy
    --frontend-image IMAGE    Frontend Docker image to deploy
    --namespace NAMESPACE     Kubernetes namespace (default: ms5-production)
    --timeout SECONDS         Deployment timeout in seconds (default: 1800)
    --rollback-on-failure     Automatically rollback on failure (default: true)
    --health-check-timeout    Health check timeout in seconds (default: 300)
    --traffic-switch-timeout  Traffic switch timeout in seconds (default: 60)
    --help                    Show this help message

EXAMPLES:
    $0 --backend-image ms5acrprod.azurecr.io/ms5-backend:v1.2.3-production --frontend-image ms5acrprod.azurecr.io/ms5-frontend:v1.2.3-production
    $0 --backend-image ms5acrprod.azurecr.io/ms5-backend:latest-production --namespace ms5-staging --timeout 600

EOF
}

# Function to parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --backend-image)
                BACKEND_IMAGE="$2"
                shift 2
                ;;
            --frontend-image)
                FRONTEND_IMAGE="$2"
                shift 2
                ;;
            --namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            --timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            --rollback-on-failure)
                ROLLBACK_ON_FAILURE="true"
                shift
                ;;
            --health-check-timeout)
                HEALTH_CHECK_TIMEOUT="$2"
                shift 2
                ;;
            --traffic-switch-timeout)
                TRAFFIC_SWITCH_TIMEOUT="$2"
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
    
    # Check if required images are provided
    if [[ -z "$BACKEND_IMAGE" ]]; then
        log_error "Backend image is required"
        exit 1
    fi
    
    if [[ -z "$FRONTEND_IMAGE" ]]; then
        log_error "Frontend image is required"
        exit 1
    fi
    
    # Check if images exist in registry
    if ! docker manifest inspect "$BACKEND_IMAGE" &> /dev/null; then
        log_error "Backend image $BACKEND_IMAGE not found in registry"
        exit 1
    fi
    
    if ! docker manifest inspect "$FRONTEND_IMAGE" &> /dev/null; then
        log_error "Frontend image $FRONTEND_IMAGE not found in registry"
        exit 1
    fi
    
    log_success "Prerequisites validated"
}

# Function to get current deployment color
get_current_color() {
    local service_name="$1"
    local current_color
    
    # Try to get color from service selector
    current_color=$(kubectl get service "$service_name" -n "$NAMESPACE" -o jsonpath='{.spec.selector.color}' 2>/dev/null || echo "")
    
    if [[ -z "$current_color" ]]; then
        # Try to get color from deployment labels
        current_color=$(kubectl get deployment "$service_name" -n "$NAMESPACE" -o jsonpath='{.spec.template.metadata.labels.color}' 2>/dev/null || echo "")
    fi
    
    if [[ -z "$current_color" ]]; then
        # Default to blue if no color is found
        current_color="blue"
        log_warning "No current color found for $service_name, defaulting to blue"
    fi
    
    echo "$current_color"
}

# Function to determine new color
get_new_color() {
    local current_color="$1"
    
    if [[ "$current_color" == "blue" ]]; then
        echo "green"
    else
        echo "blue"
    fi
}

# Function to create blue-green deployment manifests
create_blue_green_manifests() {
    local color="$1"
    local backend_image="$2"
    local frontend_image="$3"
    
    log_info "Creating blue-green deployment manifests for color: $color"
    
    # Create temporary directory for manifests
    local temp_dir="/tmp/blue-green-$color-$$"
    mkdir -p "$temp_dir"
    
    # Copy base manifests
    cp -r k8s/ "$temp_dir/"
    
    # Update backend deployment
    sed -i "s|ms5acrprod.azurecr.io/ms5-backend:.*|$backend_image|g" "$temp_dir/12-backend-deployment.yaml"
    sed -i "s|name: ms5-backend|name: ms5-backend-$color|g" "$temp_dir/12-backend-deployment.yaml"
    sed -i "s|app: ms5-dashboard|app: ms5-dashboard\n        color: $color|g" "$temp_dir/12-backend-deployment.yaml"
    
    # Update frontend deployment
    sed -i "s|ms5acrprod.azurecr.io/ms5-frontend:.*|$frontend_image|g" "$temp_dir/frontend-deployment.yaml"
    sed -i "s|name: ms5-frontend|name: ms5-frontend-$color|g" "$temp_dir/frontend-deployment.yaml"
    sed -i "s|app: ms5-frontend|app: ms5-frontend\n        color: $color|g" "$temp_dir/frontend-deployment.yaml"
    
    # Update services to point to new color
    sed -i "s|app: ms5-dashboard|app: ms5-dashboard\n        color: $color|g" "$temp_dir/13-backend-services.yaml"
    sed -i "s|app: ms5-frontend|app: ms5-frontend\n        color: $color|g" "$temp_dir/frontend-services.yaml"
    
    echo "$temp_dir"
}

# Function to deploy to new color
deploy_to_new_color() {
    local color="$1"
    local manifests_dir="$2"
    
    log_info "Deploying to $color environment..."
    
    # Deploy backend
    kubectl apply -f "$manifests_dir/12-backend-deployment.yaml" -n "$NAMESPACE"
    kubectl apply -f "$manifests_dir/13-backend-services.yaml" -n "$NAMESPACE"
    kubectl apply -f "$manifests_dir/14-backend-hpa.yaml" -n "$NAMESPACE"
    
    # Deploy frontend
    kubectl apply -f "$manifests_dir/frontend-deployment.yaml" -n "$NAMESPACE"
    kubectl apply -f "$manifests_dir/frontend-services.yaml" -n "$NAMESPACE"
    
    # Wait for deployments to be ready
    log_info "Waiting for $color deployments to be ready..."
    kubectl rollout status deployment/ms5-backend-$color -n "$NAMESPACE" --timeout="$TIMEOUT"
    kubectl rollout status deployment/ms5-frontend-$color -n "$NAMESPACE" --timeout="$TIMEOUT"
    
    log_success "Deployed to $color environment"
}

# Function to run health checks
run_health_checks() {
    local color="$1"
    
    log_info "Running health checks for $color environment..."
    
    # Get service endpoints
    local backend_service="ms5-backend-service-$color"
    local frontend_service="ms5-frontend-service-$color"
    
    # Wait for services to be ready
    kubectl wait --for=condition=ready pod -l app=ms5-dashboard,color="$color" -n "$NAMESPACE" --timeout="$HEALTH_CHECK_TIMEOUT"
    
    # Run health checks
    local backend_pods=$(kubectl get pods -l app=ms5-dashboard,component=backend,color="$color" -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
    
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
    
    log_success "Health checks passed for $color environment"
}

# Function to switch traffic
switch_traffic() {
    local new_color="$1"
    
    log_info "Switching traffic to $new_color environment..."
    
    # Update main service selectors
    kubectl patch service ms5-backend-service -n "$NAMESPACE" -p "{\"spec\":{\"selector\":{\"color\":\"$new_color\"}}}"
    kubectl patch service ms5-frontend-service -n "$NAMESPACE" -p "{\"spec\":{\"selector\":{\"color\":\"$new_color\"}}}"
    
    # Wait for traffic switch to complete
    sleep "$TRAFFIC_SWITCH_TIMEOUT"
    
    # Verify traffic switch
    local backend_pods=$(kubectl get pods -l app=ms5-dashboard,component=backend,color="$new_color" -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
    
    for pod in $backend_pods; do
        # Check if pod is receiving traffic
        local pod_ip=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.podIP}')
        if ! kubectl get endpoints ms5-backend-service -n "$NAMESPACE" -o jsonpath='{.subsets[*].addresses[*].ip}' | grep -q "$pod_ip"; then
            log_error "Pod $pod is not receiving traffic"
            return 1
        fi
    done
    
    log_success "Traffic switched to $new_color environment"
}

# Function to cleanup old color
cleanup_old_color() {
    local old_color="$1"
    
    log_info "Cleaning up $old_color environment..."
    
    # Scale down old deployments
    kubectl scale deployment ms5-backend-$old_color --replicas=0 -n "$NAMESPACE"
    kubectl scale deployment ms5-frontend-$old_color --replicas=0 -n "$NAMESPACE"
    
    # Wait for pods to terminate
    kubectl wait --for=delete pod -l app=ms5-dashboard,color="$old_color" -n "$NAMESPACE" --timeout=300s
    
    # Delete old services
    kubectl delete service ms5-backend-service-$old_color -n "$NAMESPACE" --ignore-not-found=true
    kubectl delete service ms5-frontend-service-$old_color -n "$NAMESPACE" --ignore-not-found=true
    
    log_success "Cleaned up $old_color environment"
}

# Function to rollback
rollback() {
    local old_color="$1"
    local new_color="$2"
    
    log_warning "Rolling back to $old_color environment..."
    
    # Switch traffic back to old color
    switch_traffic "$old_color"
    
    # Cleanup new color
    cleanup_old_color "$new_color"
    
    log_success "Rollback completed"
}

# Function to cleanup temporary files
cleanup_temp_files() {
    local temp_dir="$1"
    
    if [[ -d "$temp_dir" ]]; then
        rm -rf "$temp_dir"
        log_info "Cleaned up temporary files"
    fi
}

# Main function
main() {
    log_info "Starting blue-green deployment for MS5.0 Floor Dashboard"
    
    # Parse command line arguments
    parse_args "$@"
    
    # Validate prerequisites
    validate_prerequisites
    
    # Get current deployment color
    local current_color=$(get_current_color "ms5-backend")
    local new_color=$(get_new_color "$current_color")
    
    log_info "Current color: $current_color"
    log_info "New color: $new_color"
    log_info "Backend image: $BACKEND_IMAGE"
    log_info "Frontend image: $FRONTEND_IMAGE"
    log_info "Namespace: $NAMESPACE"
    
    # Create blue-green deployment manifests
    local manifests_dir=$(create_blue_green_manifests "$new_color" "$BACKEND_IMAGE" "$FRONTEND_IMAGE")
    
    # Set up cleanup trap
    trap "cleanup_temp_files '$manifests_dir'" EXIT
    
    # Deploy to new color
    if ! deploy_to_new_color "$new_color" "$manifests_dir"; then
        log_error "Failed to deploy to $new_color environment"
        cleanup_temp_files "$manifests_dir"
        exit 1
    fi
    
    # Run health checks
    if ! run_health_checks "$new_color"; then
        log_error "Health checks failed for $new_color environment"
        if [[ "$ROLLBACK_ON_FAILURE" == "true" ]]; then
            rollback "$current_color" "$new_color"
        fi
        cleanup_temp_files "$manifests_dir"
        exit 1
    fi
    
    # Switch traffic
    if ! switch_traffic "$new_color"; then
        log_error "Failed to switch traffic to $new_color environment"
        if [[ "$ROLLBACK_ON_FAILURE" == "true" ]]; then
            rollback "$current_color" "$new_color"
        fi
        cleanup_temp_files "$manifests_dir"
        exit 1
    fi
    
    # Cleanup old color
    cleanup_old_color "$current_color"
    
    # Cleanup temporary files
    cleanup_temp_files "$manifests_dir"
    
    log_success "Blue-green deployment completed successfully!"
    log_info "New color: $new_color"
    log_info "Old color: $current_color (cleaned up)"
}

# Run main function
main "$@"
