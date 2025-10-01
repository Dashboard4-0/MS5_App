#!/bin/bash
# ArgoCD Deployment Script
# Starship-grade deployment automation for GitOps infrastructure

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="argocd"
ARGOCD_VERSION="v2.8.4"
TIMEOUT="600s"

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

# Error handling
error_exit() {
    log_error "$1"
    exit 1
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        error_exit "kubectl is not installed or not in PATH"
    fi
    
    # Check if we can connect to the cluster
    if ! kubectl cluster-info &> /dev/null; then
        error_exit "Cannot connect to Kubernetes cluster"
    fi
    
    # Check if we have cluster admin permissions
    if ! kubectl auth can-i create clusterroles &> /dev/null; then
        error_exit "Insufficient permissions. Cluster admin access required."
    fi
    
    log_success "Prerequisites check passed"
}

# Create namespace
create_namespace() {
    log_info "Creating ArgoCD namespace..."
    
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_warning "Namespace $NAMESPACE already exists"
    else
        kubectl apply -f "$SCRIPT_DIR/01-argocd-namespace.yaml"
        log_success "Namespace $NAMESPACE created"
    fi
}

# Deploy ArgoCD components
deploy_argocd_components() {
    log_info "Deploying ArgoCD components..."
    
    # Deploy in order
    local components=(
        "01-argocd-namespace.yaml"
        "03-argocd-rbac.yaml"
        "08-argocd-configmaps.yaml"
        "07-argocd-redis.yaml"
        "05-argocd-repo-server.yaml"
        "06-argocd-application-controller.yaml"
        "02-argocd-install.yaml"
        "04-argocd-services.yaml"
    )
    
    for component in "${components[@]}"; do
        log_info "Deploying $component..."
        kubectl apply -f "$SCRIPT_DIR/$component"
        log_success "$component deployed"
    done
}

# Wait for ArgoCD to be ready
wait_for_argocd() {
    log_info "Waiting for ArgoCD components to be ready..."
    
    # Wait for Redis
    log_info "Waiting for Redis..."
    kubectl wait --for=condition=available deployment/argocd-redis -n "$NAMESPACE" --timeout="$TIMEOUT"
    log_success "Redis is ready"
    
    # Wait for Repo Server
    log_info "Waiting for Repo Server..."
    kubectl wait --for=condition=available deployment/argocd-repo-server -n "$NAMESPACE" --timeout="$TIMEOUT"
    log_success "Repo Server is ready"
    
    # Wait for Application Controller
    log_info "Waiting for Application Controller..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-application-controller -n "$NAMESPACE" --timeout="$TIMEOUT"
    log_success "Application Controller is ready"
    
    # Wait for Server
    log_info "Waiting for ArgoCD Server..."
    kubectl wait --for=condition=available deployment/argocd-server -n "$NAMESPACE" --timeout="$TIMEOUT"
    log_success "ArgoCD Server is ready"
}

# Configure ArgoCD
configure_argocd() {
    log_info "Configuring ArgoCD..."
    
    # Apply MS5.0 project configuration
    kubectl apply -f "$SCRIPT_DIR/09-ms5-project.yaml"
    log_success "MS5.0 project configuration applied"
    
    # Apply MS5.0 applications
    kubectl apply -f "$SCRIPT_DIR/10-ms5-applications.yaml"
    log_success "MS5.0 applications configured"
}

# Get ArgoCD admin password
get_admin_password() {
    log_info "Retrieving ArgoCD admin password..."
    
    # Wait for the secret to be created
    local retries=0
    local max_retries=30
    
    while [ $retries -lt $max_retries ]; do
        if kubectl get secret argocd-initial-admin-secret -n "$NAMESPACE" &> /dev/null; then
            break
        fi
        log_info "Waiting for admin secret to be created... (attempt $((retries + 1))/$max_retries)"
        sleep 10
        ((retries++))
    done
    
    if [ $retries -eq $max_retries ]; then
        log_warning "Admin secret not found. You may need to reset the password manually."
        return
    fi
    
    local admin_password
    admin_password=$(kubectl get secret argocd-initial-admin-secret -n "$NAMESPACE" -o jsonpath="{.data.password}" | base64 -d)
    
    echo
    log_success "ArgoCD is ready!"
    echo -e "${GREEN}Admin Username:${NC} admin"
    echo -e "${GREEN}Admin Password:${NC} $admin_password"
    echo
}

# Setup port forwarding
setup_port_forward() {
    log_info "Setting up port forwarding..."
    
    # Check if port forwarding is already running
    if pgrep -f "kubectl.*port-forward.*argocd-server" > /dev/null; then
        log_warning "Port forwarding already running"
        return
    fi
    
    # Start port forwarding in background
    kubectl port-forward svc/argocd-server -n "$NAMESPACE" 8080:443 > /dev/null 2>&1 &
    local port_forward_pid=$!
    
    # Wait a moment for port forwarding to establish
    sleep 3
    
    if kill -0 $port_forward_pid 2>/dev/null; then
        log_success "Port forwarding established (PID: $port_forward_pid)"
        echo -e "${GREEN}ArgoCD UI:${NC} https://localhost:8080"
        echo -e "${YELLOW}Note:${NC} You may need to accept the self-signed certificate"
        echo
        echo "To stop port forwarding: kill $port_forward_pid"
    else
        log_warning "Port forwarding failed to start"
    fi
}

# Validate deployment
validate_deployment() {
    log_info "Validating ArgoCD deployment..."
    
    # Check all pods are running
    local pods_ready
    pods_ready=$(kubectl get pods -n "$NAMESPACE" --no-headers | grep -c "Running" || true)
    local total_pods
    total_pods=$(kubectl get pods -n "$NAMESPACE" --no-headers | wc -l)
    
    if [ "$pods_ready" -eq "$total_pods" ] && [ "$total_pods" -gt 0 ]; then
        log_success "All $total_pods pods are running"
    else
        log_error "Only $pods_ready out of $total_pods pods are running"
        kubectl get pods -n "$NAMESPACE"
        return 1
    fi
    
    # Check services
    local services
    services=$(kubectl get services -n "$NAMESPACE" --no-headers | wc -l)
    if [ "$services" -gt 0 ]; then
        log_success "$services services created"
    else
        log_error "No services found"
        return 1
    fi
    
    # Test ArgoCD server health
    if kubectl exec -n "$NAMESPACE" deployment/argocd-server -- curl -k -f https://localhost:8080/healthz &> /dev/null; then
        log_success "ArgoCD server health check passed"
    else
        log_warning "ArgoCD server health check failed (this may be normal during startup)"
    fi
    
    log_success "ArgoCD deployment validation completed"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up..."
    # Kill any background processes
    jobs -p | xargs -r kill 2>/dev/null || true
}

# Main deployment function
main() {
    log_info "Starting ArgoCD deployment..."
    echo "========================================"
    echo "MS5.0 Floor Dashboard - ArgoCD Setup"
    echo "Version: $ARGOCD_VERSION"
    echo "Namespace: $NAMESPACE"
    echo "========================================"
    echo
    
    # Set up cleanup trap
    trap cleanup EXIT
    
    # Execute deployment steps
    check_prerequisites
    create_namespace
    deploy_argocd_components
    wait_for_argocd
    configure_argocd
    validate_deployment
    get_admin_password
    setup_port_forward
    
    echo
    log_success "ArgoCD deployment completed successfully!"
    echo
    echo "Next steps:"
    echo "1. Access ArgoCD UI at https://localhost:8080"
    echo "2. Login with admin credentials shown above"
    echo "3. Configure Git repositories for your applications"
    echo "4. Set up RBAC and user management"
    echo
    echo "For more information, see: https://argo-cd.readthedocs.io/"
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
