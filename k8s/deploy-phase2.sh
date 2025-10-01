#!/bin/bash

# MS5.0 Floor Dashboard - Phase 2 Deployment Script
# This script deploys all Kubernetes manifests for Phase 2

set -euo pipefail

# Configuration
NAMESPACE="ms5-production"
CONTEXT="aks-ms5-prod-uksouth"
DRY_RUN=${DRY_RUN:-false}
VERBOSE=${VERBOSE:-false}

# Colors for output
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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
        exit 1
    fi
    
    # Check if helm is installed
    if ! command -v helm &> /dev/null; then
        log_error "helm is not installed"
        exit 1
    fi
    
    # Check if kubectl context is set
    if ! kubectl config current-context &> /dev/null; then
        log_error "kubectl context is not set"
        exit 1
    fi
    
    # Check if we can connect to the cluster
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Create namespace
create_namespace() {
    log_info "Creating namespace: $NAMESPACE"
    
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_warning "Namespace $NAMESPACE already exists"
    else
        kubectl apply -f 01-namespace.yaml
        log_success "Namespace $NAMESPACE created"
    fi
}

# Deploy base configuration
deploy_base_config() {
    log_info "Deploying base configuration..."
    
    # Apply ConfigMaps
    kubectl apply -f 02-configmap.yaml
    log_success "ConfigMaps deployed"
    
    # Apply Secrets
    kubectl apply -f 03-secrets.yaml
    log_success "Secrets deployed"
    
    # Apply Azure Key Vault CSI driver
    kubectl apply -f 04-keyvault-csi.yaml
    log_success "Azure Key Vault CSI driver deployed"
    
    # Apply RBAC
    kubectl apply -f 05-rbac.yaml
    log_success "RBAC deployed"
}

# Deploy database services
deploy_database() {
    log_info "Deploying database services..."
    
    # Deploy PostgreSQL configuration
    kubectl apply -f 08-postgres-config.yaml
    log_success "PostgreSQL configuration deployed"
    
    # Deploy PostgreSQL StatefulSet
    kubectl apply -f 06-postgres-statefulset.yaml
    log_success "PostgreSQL StatefulSet deployed"
    
    # Deploy PostgreSQL services
    kubectl apply -f 07-postgres-services.yaml
    log_success "PostgreSQL services deployed"
    
    # Wait for PostgreSQL to be ready
    log_info "Waiting for PostgreSQL to be ready..."
    kubectl wait --for=condition=ready pod -l app=ms5-dashboard,component=database,role=primary -n "$NAMESPACE" --timeout=300s
    log_success "PostgreSQL is ready"
}

# Deploy cache services
deploy_cache() {
    log_info "Deploying cache services..."
    
    # Deploy Redis configuration
    kubectl apply -f 11-redis-config.yaml
    log_success "Redis configuration deployed"
    
    # Deploy Redis StatefulSet
    kubectl apply -f 09-redis-statefulset.yaml
    log_success "Redis StatefulSet deployed"
    
    # Deploy Redis services
    kubectl apply -f 10-redis-services.yaml
    log_success "Redis services deployed"
    
    # Wait for Redis to be ready
    log_info "Waiting for Redis to be ready..."
    kubectl wait --for=condition=ready pod -l app=ms5-dashboard,component=redis,role=primary -n "$NAMESPACE" --timeout=300s
    log_success "Redis is ready"
}

# Deploy backend services
deploy_backend() {
    log_info "Deploying backend services..."
    
    # Deploy backend deployment
    kubectl apply -f 12-backend-deployment.yaml
    log_success "Backend deployment deployed"
    
    # Deploy backend services
    kubectl apply -f 13-backend-services.yaml
    log_success "Backend services deployed"
    
    # Deploy HPA
    kubectl apply -f 14-backend-hpa.yaml
    log_success "Backend HPA deployed"
    
    # Deploy Celery worker
    kubectl apply -f 15-celery-worker-deployment.yaml
    log_success "Celery worker deployed"
    
    # Deploy Celery beat
    kubectl apply -f 16-celery-beat-deployment.yaml
    log_success "Celery beat deployed"
    
    # Deploy Flower
    kubectl apply -f 17-flower-deployment.yaml
    log_success "Flower deployed"
    
    # Wait for backend to be ready
    log_info "Waiting for backend to be ready..."
    kubectl wait --for=condition=ready pod -l app=ms5-dashboard,component=backend -n "$NAMESPACE" --timeout=300s
    log_success "Backend is ready"
}

# Deploy storage services
deploy_storage() {
    log_info "Deploying storage services..."
    
    # Deploy MinIO configuration
    kubectl apply -f 20-minio-config.yaml
    log_success "MinIO configuration deployed"
    
    # Deploy MinIO StatefulSet
    kubectl apply -f 18-minio-statefulset.yaml
    log_success "MinIO StatefulSet deployed"
    
    # Deploy MinIO services
    kubectl apply -f 19-minio-services.yaml
    log_success "MinIO services deployed"
    
    # Wait for MinIO to be ready
    log_info "Waiting for MinIO to be ready..."
    kubectl wait --for=condition=ready pod -l app=ms5-dashboard,component=minio -n "$NAMESPACE" --timeout=300s
    log_success "MinIO is ready"
}

# Deploy monitoring services
deploy_monitoring() {
    log_info "Deploying monitoring services..."
    
    # Deploy Prometheus configuration
    kubectl apply -f 23-prometheus-config.yaml
    log_success "Prometheus configuration deployed"
    
    # Deploy Prometheus StatefulSet
    kubectl apply -f 21-prometheus-statefulset.yaml
    log_success "Prometheus StatefulSet deployed"
    
    # Deploy Prometheus services
    kubectl apply -f 22-prometheus-services.yaml
    log_success "Prometheus services deployed"
    
    # Deploy Grafana StatefulSet
    kubectl apply -f 24-grafana-statefulset.yaml
    log_success "Grafana StatefulSet deployed"
    
    # Deploy Grafana services
    kubectl apply -f 25-grafana-services.yaml
    log_success "Grafana services deployed"
    
    # Deploy Grafana configuration
    kubectl apply -f 26-grafana-config.yaml
    log_success "Grafana configuration deployed"
    
    # Deploy AlertManager
    kubectl apply -f 27-alertmanager-deployment.yaml
    log_success "AlertManager deployed"
    
    # Deploy AlertManager services
    kubectl apply -f 28-alertmanager-services.yaml
    log_success "AlertManager services deployed"
    
    # Deploy AlertManager configuration
    kubectl apply -f 29-alertmanager-config.yaml
    log_success "AlertManager configuration deployed"
    
    # Wait for monitoring to be ready
    log_info "Waiting for monitoring services to be ready..."
    kubectl wait --for=condition=ready pod -l app=ms5-dashboard,component=prometheus -n "$NAMESPACE" --timeout=300s
    kubectl wait --for=condition=ready pod -l app=ms5-dashboard,component=grafana -n "$NAMESPACE" --timeout=300s
    kubectl wait --for=condition=ready pod -l app=ms5-dashboard,component=alertmanager -n "$NAMESPACE" --timeout=300s
    log_success "Monitoring services are ready"
}

# Deploy network policies
deploy_networking() {
    log_info "Deploying network policies..."
    
    kubectl apply -f 30-network-policies.yaml
    log_success "Network policies deployed"
}

# Deploy SLI/SLO and cost monitoring
deploy_sli_slo() {
    log_info "Deploying SLI/SLO and cost monitoring..."
    
    kubectl apply -f 31-sli-definitions.yaml
    log_success "SLI definitions deployed"
    
    kubectl apply -f 32-slo-configuration.yaml
    log_success "SLO configuration deployed"
    
    kubectl apply -f 33-cost-monitoring.yaml
    log_success "Cost monitoring deployed"
}

# Validate deployment
validate_deployment() {
    log_info "Validating deployment..."
    
    # Check all pods are running
    log_info "Checking pod status..."
    kubectl get pods -n "$NAMESPACE" -o wide
    
    # Check all services are running
    log_info "Checking service status..."
    kubectl get services -n "$NAMESPACE"
    
    # Check all StatefulSets are ready
    log_info "Checking StatefulSet status..."
    kubectl get statefulsets -n "$NAMESPACE"
    
    # Check all Deployments are ready
    log_info "Checking Deployment status..."
    kubectl get deployments -n "$NAMESPACE"
    
    # Check HPA status
    log_info "Checking HPA status..."
    kubectl get hpa -n "$NAMESPACE"
    
    # Check network policies
    log_info "Checking NetworkPolicy status..."
    kubectl get networkpolicies -n "$NAMESPACE"
    
    log_success "Deployment validation completed"
}

# Health check
health_check() {
    log_info "Performing health checks..."
    
    # Check backend health
    log_info "Checking backend health..."
    kubectl exec -n "$NAMESPACE" deployment/ms5-backend -- curl -f http://localhost:8000/health || log_warning "Backend health check failed"
    
    # Check database connectivity
    log_info "Checking database connectivity..."
    kubectl exec -n "$NAMESPACE" deployment/ms5-backend -- pg_isready -h postgres-primary.ms5-production.svc.cluster.local -p 5432 || log_warning "Database connectivity check failed"
    
    # Check Redis connectivity
    log_info "Checking Redis connectivity..."
    kubectl exec -n "$NAMESPACE" deployment/ms5-backend -- redis-cli -h redis-primary.ms5-production.svc.cluster.local -p 6379 ping || log_warning "Redis connectivity check failed"
    
    # Check MinIO connectivity
    log_info "Checking MinIO connectivity..."
    kubectl exec -n "$NAMESPACE" deployment/ms5-backend -- curl -f http://minio.ms5-production.svc.cluster.local:9000/minio/health/live || log_warning "MinIO connectivity check failed"
    
    # Check Prometheus
    log_info "Checking Prometheus..."
    kubectl exec -n "$NAMESPACE" deployment/prometheus -- curl -f http://localhost:9090/-/healthy || log_warning "Prometheus health check failed"
    
    # Check Grafana
    log_info "Checking Grafana..."
    kubectl exec -n "$NAMESPACE" deployment/grafana -- curl -f http://localhost:3000/api/health || log_warning "Grafana health check failed"
    
    log_success "Health checks completed"
}

# Main deployment function
main() {
    log_info "Starting MS5.0 Floor Dashboard Phase 2 deployment..."
    log_info "Namespace: $NAMESPACE"
    log_info "Context: $CONTEXT"
    log_info "Dry run: $DRY_RUN"
    
    if [ "$DRY_RUN" = "true" ]; then
        log_warning "DRY RUN MODE - No changes will be made"
        kubectl apply --dry-run=client -f .
        return 0
    fi
    
    # Execute deployment steps
    check_prerequisites
    create_namespace
    deploy_base_config
    deploy_database
    deploy_cache
    deploy_backend
    deploy_storage
    deploy_monitoring
    deploy_networking
    deploy_sli_slo
    validate_deployment
    health_check
    
    log_success "MS5.0 Floor Dashboard Phase 2 deployment completed successfully!"
    
    # Display access information
    log_info "Access Information:"
    log_info "Backend API: http://ms5-backend-loadbalancer.ms5-production.svc.cluster.local:8000"
    log_info "Grafana: http://grafana-loadbalancer.ms5-production.svc.cluster.local:3000"
    log_info "Prometheus: http://prometheus-loadbalancer.ms5-production.svc.cluster.local:9090"
    log_info "Flower: http://ms5-flower-loadbalancer.ms5-production.svc.cluster.local:5555"
    log_info "MinIO Console: http://minio-loadbalancer.ms5-production.svc.cluster.local:9001"
}

# Handle script arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [--dry-run] [--verbose] [--help]"
            echo "  --dry-run    Perform a dry run without making changes"
            echo "  --verbose    Enable verbose output"
            echo "  --help       Show this help message"
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
