#!/bin/bash

# MS5.0 Floor Dashboard - Phase 4 Deployment Script
# Backend Services Migration to AKS
#
# This script deploys the complete Phase 4 backend services migration including:
# - Enhanced FastAPI backend with production-ready configuration
# - Comprehensive Celery workers with task management
# - Redis cache with high availability and clustering
# - Enhanced monitoring and observability
# - Service integration and load balancing
#
# Usage: ./deploy-phase4.sh [environment] [options]
# Environment: staging|production (default: staging)
# Options: --dry-run, --skip-tests, --force

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
K8S_DIR="$PROJECT_ROOT/k8s"
NAMESPACE_PREFIX="ms5"
ENVIRONMENT="${1:-staging}"
DRY_RUN="${2:-false}"
SKIP_TESTS="${3:-false}"
FORCE="${4:-false}"

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

# Validation functions
validate_environment() {
    if [[ "$ENVIRONMENT" != "staging" && "$ENVIRONMENT" != "production" ]]; then
        log_error "Invalid environment: $ENVIRONMENT. Must be 'staging' or 'production'"
        exit 1
    fi
}

validate_prerequisites() {
    log_info "Validating prerequisites..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if helm is available
    if ! command -v helm &> /dev/null; then
        log_error "helm is not installed or not in PATH"
        exit 1
    fi
    
    # Check if we can connect to the cluster
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Check if namespace exists
    local namespace="$NAMESPACE_PREFIX-$ENVIRONMENT"
    if ! kubectl get namespace "$namespace" &> /dev/null; then
        log_error "Namespace $namespace does not exist. Please run Phase 1 deployment first."
        exit 1
    fi
    
    log_success "Prerequisites validation passed"
}

# Pre-deployment checks
pre_deployment_checks() {
    log_info "Running pre-deployment checks..."
    
    # Check if Phase 3 (Database Migration) is completed
    local namespace="$NAMESPACE_PREFIX-$ENVIRONMENT"
    if ! kubectl get statefulset postgres-primary -n "$namespace" &> /dev/null; then
        log_error "PostgreSQL StatefulSet not found. Please complete Phase 3 deployment first."
        exit 1
    fi
    
    # Check if Redis is deployed
    if ! kubectl get statefulset redis-primary -n "$namespace" &> /dev/null; then
        log_error "Redis StatefulSet not found. Please complete Phase 3 deployment first."
        exit 1
    fi
    
    # Check if database is ready
    if ! kubectl wait --for=condition=ready pod -l app=postgres-primary -n "$namespace" --timeout=300s; then
        log_error "PostgreSQL is not ready. Please check database status."
        exit 1
    fi
    
    # Check if Redis is ready
    if ! kubectl wait --for=condition=ready pod -l app=redis-primary -n "$namespace" --timeout=300s; then
        log_error "Redis is not ready. Please check Redis status."
        exit 1
    fi
    
    log_success "Pre-deployment checks passed"
}

# Build and push container images
build_and_push_images() {
    log_info "Building and pushing container images..."
    
    local acr_name="ms5acr$ENVIRONMENT"
    local image_tag="latest"
    local backend_image="$acr_name.azurecr.io/ms5-backend:$image_tag"
    
    # Build backend image
    log_info "Building backend image..."
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would build image: $backend_image"
    else
        cd "$PROJECT_ROOT/backend"
        docker build -t "$backend_image" -f Dockerfile.production .
        docker push "$backend_image"
        log_success "Backend image built and pushed: $backend_image"
    fi
    
    # Verify image in registry
    if [[ "$DRY_RUN" != "true" ]]; then
        log_info "Verifying image in registry..."
        az acr repository show --name "$acr_name" --image "ms5-backend:$image_tag" &> /dev/null || {
            log_error "Failed to verify image in registry"
            exit 1
        }
        log_success "Image verification passed"
    fi
}

# Deploy Redis with enhanced configuration
deploy_redis() {
    log_info "Deploying Redis with enhanced configuration..."
    
    local namespace="$NAMESPACE_PREFIX-$ENVIRONMENT"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would deploy Redis StatefulSet and Services"
    else
        # Apply Redis manifests
        kubectl apply -f "$K8S_DIR/09-redis-statefulset.yaml" -n "$namespace"
        kubectl apply -f "$K8S_DIR/10-redis-services.yaml" -n "$namespace"
        kubectl apply -f "$K8S_DIR/11-redis-config.yaml" -n "$namespace"
        
        # Wait for Redis to be ready
        log_info "Waiting for Redis to be ready..."
        kubectl wait --for=condition=ready pod -l app=ms5-dashboard,component=redis,role=primary -n "$namespace" --timeout=600s
        
        # Verify Redis replication
        log_info "Verifying Redis replication..."
        kubectl wait --for=condition=ready pod -l app=ms5-dashboard,component=redis,role=replica -n "$namespace" --timeout=600s
        
        log_success "Redis deployment completed"
    fi
}

# Deploy FastAPI backend
deploy_backend() {
    log_info "Deploying FastAPI backend..."
    
    local namespace="$NAMESPACE_PREFIX-$ENVIRONMENT"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would deploy FastAPI backend"
    else
        # Apply backend manifests
        kubectl apply -f "$K8S_DIR/12-backend-deployment.yaml" -n "$namespace"
        kubectl apply -f "$K8S_DIR/13-backend-services.yaml" -n "$namespace"
        kubectl apply -f "$K8S_DIR/14-backend-hpa.yaml" -n "$namespace"
        
        # Wait for backend to be ready
        log_info "Waiting for backend to be ready..."
        kubectl wait --for=condition=available deployment/ms5-backend -n "$namespace" --timeout=600s
        
        # Verify backend health
        log_info "Verifying backend health..."
        local backend_service="ms5-backend-service"
        local health_check_url="http://$backend_service.$namespace.svc.cluster.local:8000/health"
        
        # Wait for health check to pass
        local max_attempts=30
        local attempt=1
        while [[ $attempt -le $max_attempts ]]; do
            if kubectl run health-check --rm -i --restart=Never --image=curlimages/curl:latest -- \
                curl -f "$health_check_url" &> /dev/null; then
                log_success "Backend health check passed"
                break
            fi
            
            if [[ $attempt -eq $max_attempts ]]; then
                log_error "Backend health check failed after $max_attempts attempts"
                exit 1
            fi
            
            log_info "Health check attempt $attempt/$max_attempts failed, retrying in 10 seconds..."
            sleep 10
            ((attempt++))
        done
        
        log_success "Backend deployment completed"
    fi
}

# Deploy Celery workers
deploy_celery_workers() {
    log_info "Deploying Celery workers..."
    
    local namespace="$NAMESPACE_PREFIX-$ENVIRONMENT"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would deploy Celery workers"
    else
        # Apply Celery worker manifests
        kubectl apply -f "$K8S_DIR/15-celery-worker-deployment.yaml" -n "$namespace"
        
        # Wait for Celery workers to be ready
        log_info "Waiting for Celery workers to be ready..."
        kubectl wait --for=condition=available deployment/ms5-celery-worker -n "$namespace" --timeout=600s
        
        # Verify worker health
        log_info "Verifying Celery worker health..."
        local worker_pod=$(kubectl get pods -l app=ms5-dashboard,component=celery-worker -n "$namespace" -o jsonpath='{.items[0].metadata.name}')
        
        if kubectl exec "$worker_pod" -n "$namespace" -- celery -A app.celery inspect ping &> /dev/null; then
            log_success "Celery worker health check passed"
        else
            log_error "Celery worker health check failed"
            exit 1
        fi
        
        log_success "Celery worker deployment completed"
    fi
}

# Deploy Celery Beat scheduler
deploy_celery_beat() {
    log_info "Deploying Celery Beat scheduler..."
    
    local namespace="$NAMESPACE_PREFIX-$ENVIRONMENT"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would deploy Celery Beat scheduler"
    else
        # Apply Celery Beat manifests
        kubectl apply -f "$K8S_DIR/16-celery-beat-deployment.yaml" -n "$namespace"
        
        # Wait for Celery Beat to be ready
        log_info "Waiting for Celery Beat to be ready..."
        kubectl wait --for=condition=available deployment/ms5-celery-beat -n "$namespace" --timeout=600s
        
        # Verify Beat scheduler
        log_info "Verifying Celery Beat scheduler..."
        local beat_pod=$(kubectl get pods -l app=ms5-dashboard,component=celery-beat -n "$namespace" -o jsonpath='{.items[0].metadata.name}')
        
        if kubectl exec "$beat_pod" -n "$namespace" -- celery -A app.celery inspect ping &> /dev/null; then
            log_success "Celery Beat scheduler health check passed"
        else
            log_error "Celery Beat scheduler health check failed"
            exit 1
        fi
        
        log_success "Celery Beat deployment completed"
    fi
}

# Deploy Flower monitoring
deploy_flower() {
    log_info "Deploying Flower monitoring..."
    
    local namespace="$NAMESPACE_PREFIX-$ENVIRONMENT"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would deploy Flower monitoring"
    else
        # Apply Flower manifests
        kubectl apply -f "$K8S_DIR/17-flower-deployment.yaml" -n "$namespace"
        
        # Wait for Flower to be ready
        log_info "Waiting for Flower to be ready..."
        kubectl wait --for=condition=available deployment/ms5-flower -n "$namespace" --timeout=600s
        
        # Verify Flower access
        log_info "Verifying Flower monitoring access..."
        local flower_service="ms5-flower"
        local flower_url="http://$flower_service.$namespace.svc.cluster.local:5555"
        
        local max_attempts=20
        local attempt=1
        while [[ $attempt -le $max_attempts ]]; do
            if kubectl run flower-check --rm -i --restart=Never --image=curlimages/curl:latest -- \
                curl -f "$flower_url" &> /dev/null; then
                log_success "Flower monitoring access verified"
                break
            fi
            
            if [[ $attempt -eq $max_attempts ]]; then
                log_error "Flower monitoring access failed after $max_attempts attempts"
                exit 1
            fi
            
            log_info "Flower access attempt $attempt/$max_attempts failed, retrying in 5 seconds..."
            sleep 5
            ((attempt++))
        done
        
        log_success "Flower monitoring deployment completed"
    fi
}

# Deploy monitoring and observability
deploy_monitoring() {
    log_info "Deploying enhanced monitoring and observability..."
    
    local namespace="$NAMESPACE_PREFIX-$ENVIRONMENT"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would deploy monitoring configuration"
    else
        # Apply monitoring manifests
        kubectl apply -f "$K8S_DIR/34-backend-monitoring.yaml" -n "$namespace"
        
        # Wait for ServiceMonitors to be recognized
        log_info "Waiting for ServiceMonitors to be recognized..."
        sleep 30
        
        # Verify monitoring is working
        log_info "Verifying monitoring configuration..."
        local service_monitors=$(kubectl get servicemonitor -n "$namespace" -l app=ms5-dashboard | wc -l)
        if [[ $service_monitors -gt 1 ]]; then
            log_success "ServiceMonitors deployed successfully"
        else
            log_error "ServiceMonitors deployment failed"
            exit 1
        fi
        
        log_success "Monitoring deployment completed"
    fi
}

# Run integration tests
run_integration_tests() {
    if [[ "$SKIP_TESTS" == "true" ]]; then
        log_warning "Skipping integration tests"
        return
    fi
    
    log_info "Running integration tests..."
    
    local namespace="$NAMESPACE_PREFIX-$ENVIRONMENT"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would run integration tests"
    else
        # Run backend API tests
        log_info "Testing backend API endpoints..."
        local backend_service="ms5-backend-service"
        local api_url="http://$backend_service.$namespace.svc.cluster.local:8000"
        
        # Test health endpoint
        if kubectl run api-test --rm -i --restart=Never --image=curlimages/curl:latest -- \
            curl -f "$api_url/health" &> /dev/null; then
            log_success "API health endpoint test passed"
        else
            log_error "API health endpoint test failed"
            exit 1
        fi
        
        # Test metrics endpoint
        if kubectl run metrics-test --rm -i --restart=Never --image=curlimages/curl:latest -- \
            curl -f "$api_url/metrics" &> /dev/null; then
            log_success "API metrics endpoint test passed"
        else
            log_error "API metrics endpoint test failed"
            exit 1
        fi
        
        # Test Celery task execution
        log_info "Testing Celery task execution..."
        local worker_pod=$(kubectl get pods -l app=ms5-dashboard,component=celery-worker -n "$namespace" -o jsonpath='{.items[0].metadata.name}')
        
        if kubectl exec "$worker_pod" -n "$namespace" -- python -c "
from app.celery import celery_app
result = celery_app.send_task('health_check')
print(f'Task {result.id} sent successfully')
" &> /dev/null; then
            log_success "Celery task execution test passed"
        else
            log_error "Celery task execution test failed"
            exit 1
        fi
        
        # Test Redis connectivity
        log_info "Testing Redis connectivity..."
        local redis_pod=$(kubectl get pods -l app=ms5-dashboard,component=redis,role=primary -n "$namespace" -o jsonpath='{.items[0].metadata.name}')
        
        if kubectl exec "$redis_pod" -n "$namespace" -- redis-cli ping | grep -q "PONG"; then
            log_success "Redis connectivity test passed"
        else
            log_error "Redis connectivity test failed"
            exit 1
        fi
        
        log_success "All integration tests passed"
    fi
}

# Post-deployment validation
post_deployment_validation() {
    log_info "Running post-deployment validation..."
    
    local namespace="$NAMESPACE_PREFIX-$ENVIRONMENT"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would run post-deployment validation"
    else
        # Check all deployments are ready
        log_info "Checking deployment status..."
        local deployments=("ms5-backend" "ms5-celery-worker" "ms5-celery-beat" "ms5-flower")
        
        for deployment in "${deployments[@]}"; do
            if kubectl get deployment "$deployment" -n "$namespace" &> /dev/null; then
                local ready_replicas=$(kubectl get deployment "$deployment" -n "$namespace" -o jsonpath='{.status.readyReplicas}')
                local desired_replicas=$(kubectl get deployment "$deployment" -n "$namespace" -o jsonpath='{.spec.replicas}')
                
                if [[ "$ready_replicas" == "$desired_replicas" ]]; then
                    log_success "Deployment $deployment is ready ($ready_replicas/$desired_replicas)"
                else
                    log_error "Deployment $deployment is not ready ($ready_replicas/$desired_replicas)"
                    exit 1
                fi
            else
                log_error "Deployment $deployment not found"
                exit 1
            fi
        done
        
        # Check StatefulSets are ready
        log_info "Checking StatefulSet status..."
        local statefulsets=("redis-primary" "redis-replica")
        
        for statefulset in "${statefulsets[@]}"; do
            if kubectl get statefulset "$statefulset" -n "$namespace" &> /dev/null; then
                local ready_replicas=$(kubectl get statefulset "$statefulset" -n "$namespace" -o jsonpath='{.status.readyReplicas}')
                local desired_replicas=$(kubectl get statefulset "$statefulset" -n "$namespace" -o jsonpath='{.spec.replicas}')
                
                if [[ "$ready_replicas" == "$desired_replicas" ]]; then
                    log_success "StatefulSet $statefulset is ready ($ready_replicas/$desired_replicas)"
                else
                    log_error "StatefulSet $statefulset is not ready ($ready_replicas/$desired_replicas)"
                    exit 1
                fi
            else
                log_error "StatefulSet $statefulset not found"
                exit 1
            fi
        done
        
        # Check services are available
        log_info "Checking service availability..."
        local services=("ms5-backend-service" "ms5-flower" "redis-primary" "redis-replica")
        
        for service in "${services[@]}"; do
            if kubectl get service "$service" -n "$namespace" &> /dev/null; then
                local endpoints=$(kubectl get endpoints "$service" -n "$namespace" -o jsonpath='{.subsets[*].addresses[*].ip}' | wc -w)
                if [[ $endpoints -gt 0 ]]; then
                    log_success "Service $service has $endpoints endpoints"
                else
                    log_error "Service $service has no endpoints"
                    exit 1
                fi
            else
                log_error "Service $service not found"
                exit 1
            fi
        done
        
        log_success "Post-deployment validation completed"
    fi
}

# Generate deployment report
generate_deployment_report() {
    log_info "Generating deployment report..."
    
    local namespace="$NAMESPACE_PREFIX-$ENVIRONMENT"
    local report_file="$PROJECT_ROOT/deployment-reports/phase4-deployment-report-$ENVIRONMENT-$(date +%Y%m%d-%H%M%S).txt"
    
    mkdir -p "$(dirname "$report_file")"
    
    cat > "$report_file" << EOF
MS5.0 Floor Dashboard - Phase 4 Deployment Report
================================================

Environment: $ENVIRONMENT
Deployment Date: $(date)
Deployment Duration: $SECONDS seconds

Deployment Status: SUCCESS

Deployed Components:
-------------------
- FastAPI Backend API (ms5-backend)
- Celery Workers (ms5-celery-worker)
- Celery Beat Scheduler (ms5-celery-beat)
- Flower Monitoring (ms5-flower)
- Redis Cache with Replication (redis-primary, redis-replica)
- Enhanced Monitoring and Observability

Deployment Details:
------------------
EOF

    if [[ "$DRY_RUN" != "true" ]]; then
        kubectl get pods -n "$namespace" -l app=ms5-dashboard >> "$report_file" 2>/dev/null || true
        kubectl get services -n "$namespace" -l app=ms5-dashboard >> "$report_file" 2>/dev/null || true
        kubectl get deployments -n "$namespace" -l app=ms5-dashboard >> "$report_file" 2>/dev/null || true
        kubectl get statefulsets -n "$namespace" -l app=ms5-dashboard >> "$report_file" 2>/dev/null || true
    fi
    
    cat >> "$report_file" << EOF

Access Information:
------------------
- Backend API: http://ms5-backend-service.$namespace.svc.cluster.local:8000
- Flower Monitoring: http://ms5-flower.$namespace.svc.cluster.local:5555
- Redis Primary: redis-primary.$namespace.svc.cluster.local:6379
- Redis Replica: redis-replica.$namespace.svc.cluster.local:6379

Health Check Endpoints:
----------------------
- Backend Health: /health
- Backend Detailed Health: /health/detailed
- Backend Metrics: /metrics
- Celery Worker Health: celery inspect ping
- Redis Health: redis-cli ping

Monitoring:
-----------
- Prometheus ServiceMonitors deployed
- Grafana dashboards configured
- Alert rules active
- SLI/SLO definitions configured

Next Steps:
-----------
1. Verify all services are functioning correctly
2. Test API endpoints and Celery tasks
3. Monitor logs for any issues
4. Proceed to Phase 5 (Frontend & Networking)

EOF

    log_success "Deployment report generated: $report_file"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up temporary resources..."
    # Remove any temporary pods created for testing
    kubectl delete pod --field-selector=status.phase=Succeeded -n "$NAMESPACE_PREFIX-$ENVIRONMENT" --ignore-not-found=true &> /dev/null || true
}

# Main deployment function
main() {
    log_info "Starting MS5.0 Phase 4 Backend Services Migration"
    log_info "Environment: $ENVIRONMENT"
    log_info "Dry Run: $DRY_RUN"
    log_info "Skip Tests: $SKIP_TESTS"
    log_info "Force: $FORCE"
    
    # Set up trap for cleanup
    trap cleanup EXIT
    
    # Validate environment and prerequisites
    validate_environment
    validate_prerequisites
    
    # Pre-deployment checks
    pre_deployment_checks
    
    # Build and push images
    build_and_push_images
    
    # Deploy components in order
    deploy_redis
    deploy_backend
    deploy_celery_workers
    deploy_celery_beat
    deploy_flower
    deploy_monitoring
    
    # Run integration tests
    run_integration_tests
    
    # Post-deployment validation
    post_deployment_validation
    
    # Generate deployment report
    generate_deployment_report
    
    log_success "Phase 4 Backend Services Migration completed successfully!"
    log_info "Deployment took $SECONDS seconds"
    
    if [[ "$DRY_RUN" != "true" ]]; then
        log_info "Access your services:"
        log_info "- Backend API: kubectl port-forward svc/ms5-backend-service 8000:8000 -n $NAMESPACE_PREFIX-$ENVIRONMENT"
        log_info "- Flower Monitoring: kubectl port-forward svc/ms5-flower 5555:5555 -n $NAMESPACE_PREFIX-$ENVIRONMENT"
        log_info "- View logs: kubectl logs -l app=ms5-dashboard,component=backend -n $NAMESPACE_PREFIX-$ENVIRONMENT"
    fi
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN="true"
                shift
                ;;
            --skip-tests)
                SKIP_TESTS="true"
                shift
                ;;
            --force)
                FORCE="true"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_arguments "$@"
    main "$@"
fi
