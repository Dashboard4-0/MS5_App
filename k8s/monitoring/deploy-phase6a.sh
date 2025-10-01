#!/bin/bash

# MS5.0 Floor Dashboard - Phase 6A Deployment Script
# Enhanced Monitoring Stack Migration (Prometheus, Grafana, AlertManager)
# 
# This script deploys the enhanced monitoring stack with:
# - Prometheus with Kubernetes service discovery and federation
# - Grafana with Azure AD integration and enhanced dashboards
# - AlertManager with intelligent alert routing and Azure integration
#
# Author: MS5.0 DevOps Team
# Version: 1.0.0
# Date: $(date +%Y-%m-%d)

set -euo pipefail

# Configuration
NAMESPACE="monitoring"
TIMEOUT="600s"
LOG_PREFIX="[Phase 6A]"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}${LOG_PREFIX} INFO: $1${NC}"
}

log_success() {
    echo -e "${GREEN}${LOG_PREFIX} SUCCESS: $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}${LOG_PREFIX} WARNING: $1${NC}"
}

log_error() {
    echo -e "${RED}${LOG_PREFIX} ERROR: $1${NC}"
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
    
    # Check if the namespace exists
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_warning "Namespace $NAMESPACE does not exist. Creating it..."
        kubectl create namespace "$NAMESPACE" || error_exit "Failed to create namespace $NAMESPACE"
    fi
    
    log_success "Prerequisites check completed"
}

# Deploy namespace and base configuration
deploy_namespace() {
    log_info "Deploying monitoring namespace and base configuration..."
    
    kubectl apply -f namespace/monitoring-namespace.yaml
    log_success "Monitoring namespace deployed"
    
    # Wait for namespace to be ready
    kubectl wait --for=condition=Active namespace "$NAMESPACE" --timeout="$TIMEOUT"
    log_success "Namespace is ready"
}

# Deploy Prometheus components
deploy_prometheus() {
    log_info "Deploying Prometheus components..."
    
    # Deploy RBAC first
    kubectl apply -f prometheus/prometheus-rbac.yaml
    log_success "Prometheus RBAC deployed"
    
    # Deploy secrets
    kubectl apply -f prometheus/prometheus-secret.yaml
    log_success "Prometheus secrets deployed"
    
    # Deploy ConfigMap
    kubectl apply -f prometheus/prometheus-configmap.yaml
    log_success "Prometheus ConfigMap deployed"
    
    # Deploy PVCs
    kubectl apply -f prometheus/prometheus-pvc.yaml
    log_success "Prometheus PVCs deployed"
    
    # Deploy StatefulSet
    kubectl apply -f prometheus/prometheus-deployment.yaml
    log_success "Prometheus StatefulSet deployed"
    
    # Deploy services
    kubectl apply -f prometheus/prometheus-service.yaml
    log_success "Prometheus services deployed"
    
    # Wait for Prometheus to be ready
    log_info "Waiting for Prometheus to be ready..."
    kubectl wait --for=condition=ready pod -l app=ms5-dashboard,component=prometheus -n "$NAMESPACE" --timeout="$TIMEOUT"
    log_success "Prometheus is ready"
}

# Deploy Grafana components
deploy_grafana() {
    log_info "Deploying Grafana components..."
    
    # Deploy RBAC first
    kubectl apply -f grafana/grafana-secret.yaml
    log_success "Grafana RBAC deployed"
    
    # Deploy ConfigMap
    kubectl apply -f grafana/grafana-configmap.yaml
    log_success "Grafana ConfigMap deployed"
    
    # Deploy PVCs
    kubectl apply -f grafana/grafana-pvc.yaml
    log_success "Grafana PVCs deployed"
    
    # Deploy StatefulSet
    kubectl apply -f grafana/grafana-deployment.yaml
    log_success "Grafana StatefulSet deployed"
    
    # Deploy services
    kubectl apply -f grafana/grafana-service.yaml
    log_success "Grafana services deployed"
    
    # Wait for Grafana to be ready
    log_info "Waiting for Grafana to be ready..."
    kubectl wait --for=condition=ready pod -l app=ms5-dashboard,component=grafana -n "$NAMESPACE" --timeout="$TIMEOUT"
    log_success "Grafana is ready"
}

# Deploy AlertManager components
deploy_alertmanager() {
    log_info "Deploying AlertManager components..."
    
    # Deploy RBAC first
    kubectl apply -f alertmanager/alertmanager-secret.yaml
    log_success "AlertManager RBAC deployed"
    
    # Deploy ConfigMap
    kubectl apply -f alertmanager/alertmanager-configmap.yaml
    log_success "AlertManager ConfigMap deployed"
    
    # Deploy PVCs
    kubectl apply -f alertmanager/alertmanager-pvc.yaml
    log_success "AlertManager PVCs deployed"
    
    # Deploy StatefulSet
    kubectl apply -f alertmanager/alertmanager-deployment.yaml
    log_success "AlertManager StatefulSet deployed"
    
    # Deploy services
    kubectl apply -f alertmanager/alertmanager-service.yaml
    log_success "AlertManager services deployed"
    
    # Wait for AlertManager to be ready
    log_info "Waiting for AlertManager to be ready..."
    kubectl wait --for=condition=ready pod -l app=ms5-dashboard,component=alertmanager -n "$NAMESPACE" --timeout="$TIMEOUT"
    log_success "AlertManager is ready"
}

# Validate deployment
validate_deployment() {
    log_info "Validating deployment..."
    
    # Check if all pods are running
    local pods_ready
    pods_ready=$(kubectl get pods -n "$NAMESPACE" -l app=ms5-dashboard -o jsonpath='{.items[*].status.phase}' | tr ' ' '\n' | grep -c "Running" || true)
    local total_pods
    total_pods=$(kubectl get pods -n "$NAMESPACE" -l app=ms5-dashboard --no-headers | wc -l)
    
    if [ "$pods_ready" -eq "$total_pods" ] && [ "$total_pods" -gt 0 ]; then
        log_success "All $total_pods pods are running"
    else
        log_error "Only $pods_ready out of $total_pods pods are running"
        return 1
    fi
    
    # Check Prometheus health
    log_info "Checking Prometheus health..."
    if kubectl exec -n "$NAMESPACE" deployment/prometheus -- curl -s http://localhost:9090/-/healthy > /dev/null 2>&1; then
        log_success "Prometheus is healthy"
    else
        log_error "Prometheus health check failed"
        return 1
    fi
    
    # Check Grafana health
    log_info "Checking Grafana health..."
    if kubectl exec -n "$NAMESPACE" deployment/grafana -- curl -s http://localhost:3000/api/health > /dev/null 2>&1; then
        log_success "Grafana is healthy"
    else
        log_error "Grafana health check failed"
        return 1
    fi
    
    # Check AlertManager health
    log_info "Checking AlertManager health..."
    if kubectl exec -n "$NAMESPACE" deployment/alertmanager -- curl -s http://localhost:9093/-/healthy > /dev/null 2>&1; then
        log_success "AlertManager is healthy"
    else
        log_error "AlertManager health check failed"
        return 1
    fi
    
    # Check service discovery
    log_info "Checking service discovery..."
    local service_count
    service_count=$(kubectl get services -n "$NAMESPACE" -l app=ms5-dashboard --no-headers | wc -l)
    if [ "$service_count" -ge 3 ]; then
        log_success "Service discovery is working ($service_count services found)"
    else
        log_warning "Service discovery may not be fully configured ($service_count services found)"
    fi
    
    log_success "Deployment validation completed"
}

# Display deployment information
display_info() {
    log_info "Deployment Information:"
    echo ""
    echo "Namespace: $NAMESPACE"
    echo ""
    echo "Services:"
    kubectl get services -n "$NAMESPACE" -l app=ms5-dashboard
    echo ""
    echo "Pods:"
    kubectl get pods -n "$NAMESPACE" -l app=ms5-dashboard
    echo ""
    echo "Persistent Volume Claims:"
    kubectl get pvc -n "$NAMESPACE"
    echo ""
    echo "Access URLs:"
    echo "  Prometheus: http://prometheus.monitoring.svc.cluster.local:9090"
    echo "  Grafana: http://grafana.monitoring.svc.cluster.local:3000"
    echo "  AlertManager: http://alertmanager.monitoring.svc.cluster.local:9093"
    echo ""
    echo "External Access (if configured):"
    echo "  Prometheus: https://prometheus.ms5floor.com"
    echo "  Grafana: https://grafana.ms5floor.com"
    echo "  AlertManager: https://alertmanager.ms5floor.com"
    echo ""
}

# Cleanup function
cleanup() {
    log_warning "Cleaning up deployment..."
    kubectl delete -f alertmanager/alertmanager-service.yaml --ignore-not-found=true
    kubectl delete -f alertmanager/alertmanager-deployment.yaml --ignore-not-found=true
    kubectl delete -f alertmanager/alertmanager-pvc.yaml --ignore-not-found=true
    kubectl delete -f alertmanager/alertmanager-configmap.yaml --ignore-not-found=true
    kubectl delete -f alertmanager/alertmanager-secret.yaml --ignore-not-found=true
    
    kubectl delete -f grafana/grafana-service.yaml --ignore-not-found=true
    kubectl delete -f grafana/grafana-deployment.yaml --ignore-not-found=true
    kubectl delete -f grafana/grafana-pvc.yaml --ignore-not-found=true
    kubectl delete -f grafana/grafana-configmap.yaml --ignore-not-found=true
    kubectl delete -f grafana/grafana-secret.yaml --ignore-not-found=true
    
    kubectl delete -f prometheus/prometheus-service.yaml --ignore-not-found=true
    kubectl delete -f prometheus/prometheus-deployment.yaml --ignore-not-found=true
    kubectl delete -f prometheus/prometheus-pvc.yaml --ignore-not-found=true
    kubectl delete -f prometheus/prometheus-configmap.yaml --ignore-not-found=true
    kubectl delete -f prometheus/prometheus-secret.yaml --ignore-not-found=true
    kubectl delete -f prometheus/prometheus-rbac.yaml --ignore-not-found=true
    
    kubectl delete -f namespace/monitoring-namespace.yaml --ignore-not-found=true
    
    log_success "Cleanup completed"
}

# Main deployment function
main() {
    local action="${1:-deploy}"
    
    case "$action" in
        "deploy")
            log_info "Starting Phase 6A deployment..."
            check_prerequisites
            deploy_namespace
            deploy_prometheus
            deploy_grafana
            deploy_alertmanager
            validate_deployment
            display_info
            log_success "Phase 6A deployment completed successfully!"
            ;;
        "validate")
            log_info "Validating Phase 6A deployment..."
            validate_deployment
            display_info
            ;;
        "cleanup")
            cleanup
            ;;
        "info")
            display_info
            ;;
        *)
            echo "Usage: $0 {deploy|validate|cleanup|info}"
            echo ""
            echo "Commands:"
            echo "  deploy   - Deploy the complete Phase 6A monitoring stack"
            echo "  validate - Validate the current deployment"
            echo "  cleanup  - Remove all Phase 6A resources"
            echo "  info     - Display deployment information"
            exit 1
            ;;
    esac
}

# Set up error handling
trap 'error_exit "Deployment failed at line $LINENO"' ERR

# Run main function with all arguments
main "$@"
