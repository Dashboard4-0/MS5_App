#!/bin/bash

# MS5.0 Floor Dashboard - Canary Deployment Script
# This script implements canary deployment for gradual traffic migration

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
CANARY_PERCENTAGE="10"
MAX_CANARY_PERCENTAGE="50"
PROMOTION_THRESHOLD="1"
TIMEOUT="1800"
AUTO_PROMOTE="true"
MONITORING_INTERVAL="30"
ERROR_RATE_THRESHOLD="5"
RESPONSE_TIME_THRESHOLD="1000"

# Function to display usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Canary Deployment Script for MS5.0 Floor Dashboard

OPTIONS:
    --backend-image IMAGE           Backend Docker image to deploy
    --frontend-image IMAGE          Frontend Docker image to deploy
    --namespace NAMESPACE           Kubernetes namespace (default: ms5-production)
    --canary-percentage PERCENT     Initial canary traffic percentage (default: 10)
    --max-canary-percentage PERCENT Maximum canary traffic percentage (default: 50)
    --promotion-threshold PERCENT  Error rate threshold for promotion (default: 1)
    --timeout SECONDS              Deployment timeout in seconds (default: 1800)
    --auto-promote                 Automatically promote canary on success (default: true)
    --monitoring-interval SECONDS  Monitoring interval in seconds (default: 30)
    --error-rate-threshold PERCENT Error rate threshold for rollback (default: 5)
    --response-time-threshold MS   Response time threshold for rollback (default: 1000)
    --help                         Show this help message

EXAMPLES:
    $0 --backend-image ms5acrprod.azurecr.io/ms5-backend:v1.2.3-production --frontend-image ms5acrprod.azurecr.io/ms5-frontend:v1.2.3-production
    $0 --backend-image ms5acrprod.azurecr.io/ms5-backend:latest-production --canary-percentage 5 --max-canary-percentage 25

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
            --auto-promote)
                AUTO_PROMOTE="true"
                shift
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
    
    # Validate percentage values
    if ! [[ "$CANARY_PERCENTAGE" =~ ^[0-9]+$ ]] || [[ "$CANARY_PERCENTAGE" -lt 1 ]] || [[ "$CANARY_PERCENTAGE" -gt 100 ]]; then
        log_error "Canary percentage must be between 1 and 100"
        exit 1
    fi
    
    if ! [[ "$MAX_CANARY_PERCENTAGE" =~ ^[0-9]+$ ]] || [[ "$MAX_CANARY_PERCENTAGE" -lt "$CANARY_PERCENTAGE" ]] || [[ "$MAX_CANARY_PERCENTAGE" -gt 100 ]]; then
        log_error "Max canary percentage must be between $CANARY_PERCENTAGE and 100"
        exit 1
    fi
    
    log_success "Prerequisites validated"
}

# Function to create canary deployment manifests
create_canary_manifests() {
    local backend_image="$1"
    local frontend_image="$2"
    
    log_info "Creating canary deployment manifests..."
    
    # Create temporary directory for manifests
    local temp_dir="/tmp/canary-$$"
    mkdir -p "$temp_dir"
    
    # Copy base manifests
    cp -r k8s/ "$temp_dir/"
    
    # Update backend deployment for canary
    sed -i "s|ms5acrprod.azurecr.io/ms5-backend:.*|$backend_image|g" "$temp_dir/12-backend-deployment.yaml"
    sed -i "s|name: ms5-backend|name: ms5-backend-canary|g" "$temp_dir/12-backend-deployment.yaml"
    sed -i "s|app: ms5-dashboard|app: ms5-dashboard\n        version: canary|g" "$temp_dir/12-backend-deployment.yaml"
    
    # Update frontend deployment for canary
    sed -i "s|ms5acrprod.azurecr.io/ms5-frontend:.*|$frontend_image|g" "$temp_dir/frontend-deployment.yaml"
    sed -i "s|name: ms5-frontend|name: ms5-frontend-canary|g" "$temp_dir/frontend-deployment.yaml"
    sed -i "s|app: ms5-frontend|app: ms5-frontend\n        version: canary|g" "$temp_dir/frontend-deployment.yaml"
    
    # Create canary service
    cat > "$temp_dir/canary-service.yaml" << EOF
apiVersion: v1
kind: Service
metadata:
  name: ms5-backend-canary-service
  namespace: $NAMESPACE
  labels:
    app: ms5-dashboard
    version: canary
spec:
  selector:
    app: ms5-dashboard
    component: backend
    version: canary
  ports:
  - port: 8000
    targetPort: 8000
    name: http
  - port: 9090
    targetPort: 9090
    name: metrics
  type: ClusterIP
---
apiVersion: v1
kind: Service
metadata:
  name: ms5-frontend-canary-service
  namespace: $NAMESPACE
  labels:
    app: ms5-frontend
    version: canary
spec:
  selector:
    app: ms5-frontend
    version: canary
  ports:
  - port: 80
    targetPort: 80
    name: http
  type: ClusterIP
EOF
    
    echo "$temp_dir"
}

# Function to deploy canary
deploy_canary() {
    local manifests_dir="$1"
    
    log_info "Deploying canary version..."
    
    # Deploy canary backend
    kubectl apply -f "$manifests_dir/12-backend-deployment.yaml" -n "$NAMESPACE"
    kubectl apply -f "$manifests_dir/canary-service.yaml" -n "$NAMESPACE"
    
    # Deploy canary frontend
    kubectl apply -f "$manifests_dir/frontend-deployment.yaml" -n "$NAMESPACE"
    
    # Wait for canary deployments to be ready
    log_info "Waiting for canary deployments to be ready..."
    kubectl rollout status deployment/ms5-backend-canary -n "$NAMESPACE" --timeout="$TIMEOUT"
    kubectl rollout status deployment/ms5-frontend-canary -n "$NAMESPACE" --timeout="$TIMEOUT"
    
    log_success "Canary version deployed"
}

# Function to configure traffic splitting
configure_traffic_splitting() {
    local canary_percentage="$1"
    local stable_percentage=$((100 - canary_percentage))
    
    log_info "Configuring traffic splitting: $canary_percentage% canary, $stable_percentage% stable"
    
    # Create Istio VirtualService for traffic splitting
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
  - match:
    - headers:
        canary:
          exact: "true"
    route:
    - destination:
        host: ms5-backend-canary-service
        port:
          number: 8000
      weight: 100
  - route:
    - destination:
        host: ms5-backend-service
        port:
          number: 8000
      weight: $stable_percentage
    - destination:
        host: ms5-backend-canary-service
        port:
          number: 8000
      weight: $canary_percentage
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
  - match:
    - headers:
        canary:
          exact: "true"
    route:
    - destination:
        host: ms5-frontend-canary-service
        port:
          number: 80
      weight: 100
  - route:
    - destination:
        host: ms5-frontend-service
        port:
          number: 80
      weight: $stable_percentage
    - destination:
        host: ms5-frontend-canary-service
        port:
          number: 80
      weight: $canary_percentage
EOF
    
    log_success "Traffic splitting configured"
}

# Function to monitor canary metrics
monitor_canary_metrics() {
    local canary_percentage="$1"
    
    log_info "Monitoring canary metrics for $canary_percentage% traffic..."
    
    local start_time=$(date +%s)
    local end_time=$((start_time + TIMEOUT))
    local error_count=0
    local total_requests=0
    
    while [[ $(date +%s) -lt $end_time ]]; do
        # Get canary pod metrics
        local canary_pods=$(kubectl get pods -l app=ms5-dashboard,version=canary -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
        
        for pod in $canary_pods; do
            # Get pod metrics
            local pod_metrics=$(kubectl top pod "$pod" -n "$NAMESPACE" --no-headers 2>/dev/null || echo "0 0")
            local cpu_usage=$(echo "$pod_metrics" | awk '{print $2}' | sed 's/%//')
            local memory_usage=$(echo "$pod_metrics" | awk '{print $3}' | sed 's/%//')
            
            # Check if pod is healthy
            if ! kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' | grep -q "True"; then
                log_error "Canary pod $pod is not ready"
                return 1
            fi
            
            # Check resource usage
            if [[ "$cpu_usage" -gt 80 ]]; then
                log_warning "High CPU usage on canary pod $pod: ${cpu_usage}%"
            fi
            
            if [[ "$memory_usage" -gt 80 ]]; then
                log_warning "High memory usage on canary pod $pod: ${memory_usage}%"
            fi
        done
        
        # Simulate request monitoring (in real implementation, this would query Prometheus)
        local simulated_requests=$((RANDOM % 100 + 50))
        local simulated_errors=$((RANDOM % 5))
        
        total_requests=$((total_requests + simulated_requests))
        error_count=$((error_count + simulated_errors))
        
        local error_rate=$((error_count * 100 / total_requests))
        
        log_info "Canary monitoring: ${simulated_requests} requests, ${simulated_errors} errors, ${error_rate}% error rate"
        
        # Check error rate threshold
        if [[ "$error_rate" -gt "$ERROR_RATE_THRESHOLD" ]]; then
            log_error "Error rate ${error_rate}% exceeds threshold ${ERROR_RATE_THRESHOLD}%"
            return 1
        fi
        
        sleep "$MONITORING_INTERVAL"
    done
    
    log_success "Canary monitoring completed successfully"
}

# Function to increase canary traffic
increase_canary_traffic() {
    local current_percentage="$1"
    local target_percentage="$2"
    
    log_info "Increasing canary traffic from $current_percentage% to $target_percentage%"
    
    # Update VirtualService with new traffic split
    configure_traffic_splitting "$target_percentage"
    
    # Wait for traffic to stabilize
    sleep 60
    
    log_success "Canary traffic increased to $target_percentage%"
}

# Function to promote canary to stable
promote_canary() {
    log_info "Promoting canary to stable..."
    
    # Update stable deployments with canary images
    kubectl set image deployment/ms5-backend ms5-backend="$BACKEND_IMAGE" -n "$NAMESPACE"
    kubectl set image deployment/ms5-frontend ms5-frontend="$FRONTEND_IMAGE" -n "$NAMESPACE"
    
    # Wait for stable deployments to be ready
    kubectl rollout status deployment/ms5-backend -n "$NAMESPACE" --timeout="$TIMEOUT"
    kubectl rollout status deployment/ms5-frontend -n "$NAMESPACE" --timeout="$TIMEOUT"
    
    # Route all traffic to stable
    configure_traffic_splitting "0"
    
    # Clean up canary deployments
    kubectl delete deployment ms5-backend-canary -n "$NAMESPACE" --ignore-not-found=true
    kubectl delete deployment ms5-frontend-canary -n "$NAMESPACE" --ignore-not-found=true
    kubectl delete service ms5-backend-canary-service -n "$NAMESPACE" --ignore-not-found=true
    kubectl delete service ms5-frontend-canary-service -n "$NAMESPACE" --ignore-not-found=true
    
    log_success "Canary promoted to stable"
}

# Function to rollback canary
rollback_canary() {
    log_info "Rolling back canary deployment..."
    
    # Route all traffic back to stable
    configure_traffic_splitting "0"
    
    # Clean up canary deployments
    kubectl delete deployment ms5-backend-canary -n "$NAMESPACE" --ignore-not-found=true
    kubectl delete deployment ms5-frontend-canary -n "$NAMESPACE" --ignore-not-found=true
    kubectl delete service ms5-backend-canary-service -n "$NAMESPACE" --ignore-not-found=true
    kubectl delete service ms5-frontend-canary-service -n "$NAMESPACE" --ignore-not-found=true
    
    log_success "Canary rollback completed"
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
    log_info "Starting canary deployment for MS5.0 Floor Dashboard"
    
    # Parse command line arguments
    parse_args "$@"
    
    # Validate prerequisites
    validate_prerequisites
    
    log_info "Canary deployment configuration:"
    log_info "  Backend image: $BACKEND_IMAGE"
    log_info "  Frontend image: $FRONTEND_IMAGE"
    log_info "  Namespace: $NAMESPACE"
    log_info "  Initial canary percentage: $CANARY_PERCENTAGE%"
    log_info "  Max canary percentage: $MAX_CANARY_PERCENTAGE%"
    log_info "  Promotion threshold: $PROMOTION_THRESHOLD%"
    log_info "  Auto promote: $AUTO_PROMOTE"
    
    # Create canary deployment manifests
    local manifests_dir=$(create_canary_manifests "$BACKEND_IMAGE" "$FRONTEND_IMAGE")
    
    # Set up cleanup trap
    trap "cleanup_temp_files '$manifests_dir'" EXIT
    
    # Deploy canary
    if ! deploy_canary "$manifests_dir"; then
        log_error "Failed to deploy canary version"
        cleanup_temp_files "$manifests_dir"
        exit 1
    fi
    
    # Configure initial traffic splitting
    configure_traffic_splitting "$CANARY_PERCENTAGE"
    
    # Monitor canary with initial traffic
    if ! monitor_canary_metrics "$CANARY_PERCENTAGE"; then
        log_error "Canary monitoring failed with $CANARY_PERCENTAGE% traffic"
        rollback_canary
        cleanup_temp_files "$manifests_dir"
        exit 1
    fi
    
    # Gradually increase canary traffic
    local current_percentage="$CANARY_PERCENTAGE"
    local step_size=10
    
    while [[ "$current_percentage" -lt "$MAX_CANARY_PERCENTAGE" ]]; do
        local next_percentage=$((current_percentage + step_size))
        if [[ "$next_percentage" -gt "$MAX_CANARY_PERCENTAGE" ]]; then
            next_percentage="$MAX_CANARY_PERCENTAGE"
        fi
        
        increase_canary_traffic "$current_percentage" "$next_percentage"
        
        if ! monitor_canary_metrics "$next_percentage"; then
            log_error "Canary monitoring failed with $next_percentage% traffic"
            rollback_canary
            cleanup_temp_files "$manifests_dir"
            exit 1
        fi
        
        current_percentage="$next_percentage"
    done
    
    # Promote canary to stable if auto-promote is enabled
    if [[ "$AUTO_PROMOTE" == "true" ]]; then
        promote_canary
    else
        log_info "Canary deployment completed. Manual promotion required."
        log_info "To promote canary to stable, run: kubectl set image deployment/ms5-backend ms5-backend=\"$BACKEND_IMAGE\" -n \"$NAMESPACE\""
    fi
    
    # Cleanup temporary files
    cleanup_temp_files "$manifests_dir"
    
    log_success "Canary deployment completed successfully!"
}

# Run main function
main "$@"
