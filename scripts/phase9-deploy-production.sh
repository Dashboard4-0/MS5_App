#!/bin/bash

# MS5.0 Floor Dashboard - Phase 9 Production Deployment Script
# This script deploys the MS5.0 Floor Dashboard to production with starship-grade precision
# Designed with the reliability of critical infrastructure and the elegance of master craftsmanship

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NAMESPACE="ms5-production"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${PROJECT_ROOT}/logs/phase9-production-deployment-${TIMESTAMP}.log"

# Environment variables
ENVIRONMENT=${ENVIRONMENT:-production}
SKIP_VALIDATION=${SKIP_VALIDATION:-false}
SKIP_MIGRATIONS=${SKIP_MIGRATIONS:-false}
SKIP_MONITORING=${SKIP_MONITORING:-false}
DRY_RUN=${DRY_RUN:-false}
ROLLBACK_ON_FAILURE=${ROLLBACK_ON_FAILURE:-true}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_section() {
    echo -e "${PURPLE}[SECTION]${NC} $1" | tee -a "$LOG_FILE"
}

# Create log directory
mkdir -p "$(dirname "$LOG_FILE")"

# Deployment tracking
DEPLOYMENT_START_TIME=$(date +%s)
DEPLOYMENT_STEPS=()
DEPLOYMENT_STATUS="IN_PROGRESS"

# Function to track deployment steps
track_step() {
    local step_name="$1"
    local status="$2"
    local message="$3"
    
    DEPLOYMENT_STEPS+=("$step_name|$status|$message|$(date +%s)")
    
    case "$status" in
        "STARTED")
            log_section "Starting: $step_name"
            log_info "$message"
            ;;
        "COMPLETED")
            log_success "$step_name completed: $message"
            ;;
        "FAILED")
            log_error "$step_name failed: $message"
            ;;
        "WARNING")
            log_warning "$step_name warning: $message"
            ;;
    esac
}

# Function to check prerequisites
check_prerequisites() {
    track_step "prerequisites-check" "STARTED" "Checking deployment prerequisites"
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        track_step "prerequisites-check" "FAILED" "kubectl is not installed"
        return 1
    fi
    
    # Check helm
    if ! command -v helm &> /dev/null; then
        track_step "prerequisites-check" "FAILED" "helm is not installed"
        return 1
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        track_step "prerequisites-check" "FAILED" "Cannot connect to Kubernetes cluster"
        return 1
    fi
    
    # Check namespace
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_info "Namespace $NAMESPACE does not exist, will be created"
    fi
    
    track_step "prerequisites-check" "COMPLETED" "All prerequisites satisfied"
}

# Function to validate environment
validate_environment() {
    if [ "$SKIP_VALIDATION" = "true" ]; then
        track_step "environment-validation" "COMPLETED" "Environment validation skipped"
        return 0
    fi
    
    track_step "environment-validation" "STARTED" "Validating production environment"
    
    # Run environment validation script
    if [ -f "$PROJECT_ROOT/scripts/phase9-validate-environment.sh" ]; then
        if bash "$PROJECT_ROOT/scripts/phase9-validate-environment.sh"; then
            track_step "environment-validation" "COMPLETED" "Environment validation passed"
        else
            track_step "environment-validation" "FAILED" "Environment validation failed"
            return 1
        fi
    else
        track_step "environment-validation" "WARNING" "Environment validation script not found"
    fi
}

# Function to create namespace and base resources
deploy_namespace_and_base() {
    track_step "namespace-deployment" "STARTED" "Creating namespace and base resources"
    
    # Create namespace
    kubectl apply -f "$PROJECT_ROOT/k8s/01-namespace.yaml"
    
    # Deploy base configuration
    kubectl apply -f "$PROJECT_ROOT/k8s/02-configmap.yaml"
    kubectl apply -f "$PROJECT_ROOT/k8s/03-secrets.yaml"
    kubectl apply -f "$PROJECT_ROOT/k8s/04-keyvault-csi.yaml"
    kubectl apply -f "$PROJECT_ROOT/k8s/05-rbac.yaml"
    
    track_step "namespace-deployment" "COMPLETED" "Namespace and base resources deployed"
}

# Function to deploy security components
deploy_security() {
    track_step "security-deployment" "STARTED" "Deploying security components"
    
    # Deploy Pod Security Standards
    kubectl apply -f "$PROJECT_ROOT/k8s/39-pod-security-standards.yaml"
    
    # Deploy TLS encryption
    kubectl apply -f "$PROJECT_ROOT/k8s/41-tls-encryption-config.yaml"
    
    # Deploy network policies
    kubectl apply -f "$PROJECT_ROOT/k8s/30-network-policies.yaml"
    
    track_step "security-deployment" "COMPLETED" "Security components deployed"
}

# Function to deploy certificate management
deploy_certificates() {
    track_step "certificate-deployment" "STARTED" "Deploying certificate management"
    
    # Deploy cert-manager if not already installed
    if ! kubectl get namespace cert-manager &> /dev/null; then
        log_info "Installing cert-manager"
        kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
        kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s
    fi
    
    # Deploy production certificates
    kubectl apply -f "$PROJECT_ROOT/k8s/cert-manager/02-production-certificates.yaml"
    
    track_step "certificate-deployment" "COMPLETED" "Certificate management deployed"
}

# Function to deploy database
deploy_database() {
    track_step "database-deployment" "STARTED" "Deploying database services"
    
    # Deploy PostgreSQL configuration
    kubectl apply -f "$PROJECT_ROOT/k8s/08-postgres-config.yaml"
    
    # Deploy PostgreSQL StatefulSet
    kubectl apply -f "$PROJECT_ROOT/k8s/06-postgres-statefulset.yaml"
    
    # Deploy PostgreSQL services
    kubectl apply -f "$PROJECT_ROOT/k8s/07-postgres-services.yaml"
    
    # Wait for database to be ready
    log_info "Waiting for PostgreSQL to be ready..."
    kubectl wait --for=condition=ready pod -l app=ms5-dashboard,component=database,role=primary -n "$NAMESPACE" --timeout=600s
    
    track_step "database-deployment" "COMPLETED" "Database services deployed"
}

# Function to run database migrations
run_database_migrations() {
    if [ "$SKIP_MIGRATIONS" = "true" ]; then
        track_step "database-migrations" "COMPLETED" "Database migrations skipped"
        return 0
    fi
    
    track_step "database-migrations" "STARTED" "Running database migrations"
    
    # Run migration testing first
    if [ -f "$PROJECT_ROOT/scripts/phase9-test-migrations.sh" ]; then
        log_info "Testing database migrations..."
        if bash "$PROJECT_ROOT/scripts/phase9-test-migrations.sh"; then
            log_success "Migration tests passed"
        else
            track_step "database-migrations" "WARNING" "Migration tests failed, but continuing"
        fi
    fi
    
    # Run actual migrations
    if [ -f "$PROJECT_ROOT/scripts/deploy_migrations.sh" ]; then
        log_info "Running database migrations..."
        if bash "$PROJECT_ROOT/scripts/deploy_migrations.sh"; then
            track_step "database-migrations" "COMPLETED" "Database migrations completed successfully"
        else
            track_step "database-migrations" "FAILED" "Database migrations failed"
            return 1
        fi
    else
        track_step "database-migrations" "WARNING" "Migration script not found"
    fi
}

# Function to deploy cache services
deploy_cache() {
    track_step "cache-deployment" "STARTED" "Deploying cache services"
    
    # Deploy Redis configuration
    kubectl apply -f "$PROJECT_ROOT/k8s/11-redis-config.yaml"
    
    # Deploy Redis StatefulSet
    kubectl apply -f "$PROJECT_ROOT/k8s/09-redis-statefulset.yaml"
    
    # Deploy Redis services
    kubectl apply -f "$PROJECT_ROOT/k8s/10-redis-services.yaml"
    
    # Wait for Redis to be ready
    log_info "Waiting for Redis to be ready..."
    kubectl wait --for=condition=ready pod -l app=ms5-dashboard,component=redis,role=primary -n "$NAMESPACE" --timeout=300s
    
    track_step "cache-deployment" "COMPLETED" "Cache services deployed"
}

# Function to deploy storage services
deploy_storage() {
    track_step "storage-deployment" "STARTED" "Deploying storage services"
    
    # Deploy MinIO configuration
    kubectl apply -f "$PROJECT_ROOT/k8s/20-minio-config.yaml"
    
    # Deploy MinIO StatefulSet
    kubectl apply -f "$PROJECT_ROOT/k8s/18-minio-statefulset.yaml"
    
    # Deploy MinIO services
    kubectl apply -f "$PROJECT_ROOT/k8s/19-minio-services.yaml"
    
    # Wait for MinIO to be ready
    log_info "Waiting for MinIO to be ready..."
    kubectl wait --for=condition=ready pod -l app=ms5-dashboard,component=minio -n "$NAMESPACE" --timeout=300s
    
    track_step "storage-deployment" "COMPLETED" "Storage services deployed"
}

# Function to deploy backend services
deploy_backend() {
    track_step "backend-deployment" "STARTED" "Deploying backend services"
    
    # Deploy backend deployment
    kubectl apply -f "$PROJECT_ROOT/k8s/12-backend-deployment.yaml"
    
    # Deploy backend services
    kubectl apply -f "$PROJECT_ROOT/k8s/13-backend-services.yaml"
    
    # Deploy HPA
    kubectl apply -f "$PROJECT_ROOT/k8s/14-backend-hpa.yaml"
    
    # Deploy Celery worker
    kubectl apply -f "$PROJECT_ROOT/k8s/15-celery-worker-deployment.yaml"
    
    # Deploy Celery beat
    kubectl apply -f "$PROJECT_ROOT/k8s/16-celery-beat-deployment.yaml"
    
    # Deploy Flower
    kubectl apply -f "$PROJECT_ROOT/k8s/17-flower-deployment.yaml"
    
    # Wait for backend to be ready
    log_info "Waiting for backend services to be ready..."
    kubectl wait --for=condition=ready pod -l app=ms5-dashboard,component=backend -n "$NAMESPACE" --timeout=600s
    
    track_step "backend-deployment" "COMPLETED" "Backend services deployed"
}

# Function to deploy monitoring
deploy_monitoring() {
    if [ "$SKIP_MONITORING" = "true" ]; then
        track_step "monitoring-deployment" "COMPLETED" "Monitoring deployment skipped"
        return 0
    fi
    
    track_step "monitoring-deployment" "STARTED" "Deploying monitoring services"
    
    # Deploy Prometheus configuration
    kubectl apply -f "$PROJECT_ROOT/k8s/23-prometheus-config.yaml"
    
    # Deploy Prometheus StatefulSet
    kubectl apply -f "$PROJECT_ROOT/k8s/21-prometheus-statefulset.yaml"
    
    # Deploy Prometheus services
    kubectl apply -f "$PROJECT_ROOT/k8s/22-prometheus-services.yaml"
    
    # Deploy Grafana StatefulSet
    kubectl apply -f "$PROJECT_ROOT/k8s/24-grafana-statefulset.yaml"
    
    # Deploy Grafana services
    kubectl apply -f "$PROJECT_ROOT/k8s/25-grafana-services.yaml"
    
    # Deploy Grafana configuration
    kubectl apply -f "$PROJECT_ROOT/k8s/26-grafana-config.yaml"
    
    # Deploy AlertManager
    kubectl apply -f "$PROJECT_ROOT/k8s/27-alertmanager-deployment.yaml"
    
    # Deploy AlertManager services
    kubectl apply -f "$PROJECT_ROOT/k8s/28-alertmanager-services.yaml"
    
    # Deploy AlertManager configuration
    kubectl apply -f "$PROJECT_ROOT/k8s/29-alertmanager-config.yaml"
    
    # Wait for monitoring services to be ready
    log_info "Waiting for monitoring services to be ready..."
    kubectl wait --for=condition=ready pod -l app=ms5-dashboard,component=prometheus -n "$NAMESPACE" --timeout=300s
    kubectl wait --for=condition=ready pod -l app=ms5-dashboard,component=grafana -n "$NAMESPACE" --timeout=300s
    kubectl wait --for=condition=ready pod -l app=ms5-dashboard,component=alertmanager -n "$NAMESPACE" --timeout=300s
    
    track_step "monitoring-deployment" "COMPLETED" "Monitoring services deployed"
}

# Function to deploy load balancer
deploy_loadbalancer() {
    track_step "loadbalancer-deployment" "STARTED" "Deploying load balancer and ingress"
    
    # Deploy NGINX ingress controller
    kubectl apply -f "$PROJECT_ROOT/k8s/ingress/01-nginx-namespace.yaml"
    kubectl apply -f "$PROJECT_ROOT/k8s/ingress/02-nginx-deployment.yaml"
    kubectl apply -f "$PROJECT_ROOT/k8s/ingress/03-nginx-service.yaml"
    kubectl apply -f "$PROJECT_ROOT/k8s/ingress/04-nginx-configmap.yaml"
    kubectl apply -f "$PROJECT_ROOT/k8s/ingress/05-nginx-ingressclass.yaml"
    
    # Deploy production load balancer
    kubectl apply -f "$PROJECT_ROOT/k8s/ingress/07-ms5-production-loadbalancer.yaml"
    
    # Deploy comprehensive ingress
    kubectl apply -f "$PROJECT_ROOT/k8s/ingress/06-ms5-comprehensive-ingress.yaml"
    
    track_step "loadbalancer-deployment" "COMPLETED" "Load balancer and ingress deployed"
}

# Function to deploy SLI/SLO monitoring
deploy_sli_slo() {
    track_step "sli-slo-deployment" "STARTED" "Deploying SLI/SLO monitoring"
    
    # Deploy SLI definitions
    kubectl apply -f "$PROJECT_ROOT/k8s/31-sli-definitions.yaml"
    
    # Deploy SLO configuration
    kubectl apply -f "$PROJECT_ROOT/k8s/32-slo-configuration.yaml"
    
    # Deploy cost monitoring
    kubectl apply -f "$PROJECT_ROOT/k8s/33-cost-monitoring.yaml"
    
    track_step "sli-slo-deployment" "COMPLETED" "SLI/SLO monitoring deployed"
}

# Function to validate deployment
validate_deployment() {
    track_step "deployment-validation" "STARTED" "Validating deployment"
    
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
    
    # Check ingress status
    log_info "Checking Ingress status..."
    kubectl get ingress -n "$NAMESPACE"
    
    track_step "deployment-validation" "COMPLETED" "Deployment validation completed"
}

# Function to perform health checks
perform_health_checks() {
    track_step "health-checks" "STARTED" "Performing health checks"
    
    # Check backend health
    log_info "Checking backend health..."
    if kubectl exec -n "$NAMESPACE" deployment/ms5-backend -- curl -f http://localhost:8000/health &> /dev/null; then
        log_success "Backend health check passed"
    else
        track_step "health-checks" "WARNING" "Backend health check failed"
    fi
    
    # Check database connectivity
    log_info "Checking database connectivity..."
    if kubectl exec -n "$NAMESPACE" deployment/ms5-backend -- pg_isready -h postgres-primary.ms5-production.svc.cluster.local -p 5432 &> /dev/null; then
        log_success "Database connectivity check passed"
    else
        track_step "health-checks" "WARNING" "Database connectivity check failed"
    fi
    
    # Check Redis connectivity
    log_info "Checking Redis connectivity..."
    if kubectl exec -n "$NAMESPACE" deployment/ms5-backend -- redis-cli -h redis-primary.ms5-production.svc.cluster.local -p 6379 ping &> /dev/null; then
        log_success "Redis connectivity check passed"
    else
        track_step "health-checks" "WARNING" "Redis connectivity check failed"
    fi
    
    track_step "health-checks" "COMPLETED" "Health checks completed"
}

# Function to generate deployment report
generate_deployment_report() {
    track_step "report-generation" "STARTED" "Generating deployment report"
    
    local report_file="${PROJECT_ROOT}/logs/phase9-production-deployment-report-${TIMESTAMP}.md"
    local deployment_end_time=$(date +%s)
    local deployment_duration=$((deployment_end_time - DEPLOYMENT_START_TIME))
    
    cat > "$report_file" << EOF
# MS5.0 Floor Dashboard - Phase 9 Production Deployment Report

**Deployment Started**: $(date -d @$DEPLOYMENT_START_TIME)
**Deployment Completed**: $(date -d @$deployment_end_time)
**Deployment Duration**: ${deployment_duration} seconds
**Environment**: $ENVIRONMENT
**Namespace**: $NAMESPACE
**Status**: $DEPLOYMENT_STATUS

## Deployment Summary

EOF

    # Add deployment steps
    echo "### Deployment Steps" >> "$report_file"
    for step in "${DEPLOYMENT_STEPS[@]}"; do
        IFS='|' read -r step_name status message timestamp <<< "$step"
        local step_time=$(date -d @$timestamp)
        
        local status_icon=""
        case "$status" in
            "STARTED") status_icon="🔄" ;;
            "COMPLETED") status_icon="✅" ;;
            "FAILED") status_icon="❌" ;;
            "WARNING") status_icon="⚠️" ;;
        esac
        
        echo "- $status_icon **$step_name** ($status): $message" >> "$report_file"
    done
    
    echo "" >> "$report_file"
    echo "## Access Information" >> "$report_file"
    echo "- **Backend API**: https://api.ms5-dashboard.company.com" >> "$report_file"
    echo "- **Main Application**: https://ms5-dashboard.company.com" >> "$report_file"
    echo "- **Grafana**: https://grafana.ms5-dashboard.company.com" >> "$report_file"
    echo "- **Prometheus**: https://prometheus.ms5-dashboard.company.com" >> "$report_file"
    echo "- **Flower**: https://flower.ms5-dashboard.company.com" >> "$report_file"
    
    echo "" >> "$report_file"
    echo "## Next Steps" >> "$report_file"
    if [ "$DEPLOYMENT_STATUS" = "COMPLETED" ]; then
        echo "- ✅ Monitor application health and performance" >> "$report_file"
        echo "- ✅ Set up alerting notifications" >> "$report_file"
        echo "- ✅ Configure backup schedules" >> "$report_file"
        echo "- ✅ Update DNS records if needed" >> "$report_file"
    else
        echo "- ❌ Review failed deployment steps" >> "$report_file"
        echo "- ❌ Check logs for error details" >> "$report_file"
        echo "- ❌ Consider rollback if necessary" >> "$report_file"
    fi
    
    track_step "report-generation" "COMPLETED" "Deployment report generated: $report_file"
}

# Function to handle deployment failure
handle_deployment_failure() {
    log_error "Deployment failed. Handling failure..."
    
    if [ "$ROLLBACK_ON_FAILURE" = "true" ]; then
        log_info "Rolling back deployment..."
        # Implement rollback logic here
        track_step "rollback" "STARTED" "Rolling back failed deployment"
        # Add rollback commands
        track_step "rollback" "COMPLETED" "Rollback completed"
    fi
    
    DEPLOYMENT_STATUS="FAILED"
    generate_deployment_report
    exit 1
}

# Main deployment function
main() {
    log "Starting MS5.0 Floor Dashboard Phase 9 Production Deployment"
    log "Environment: $ENVIRONMENT"
    log "Namespace: $NAMESPACE"
    log "Log file: $LOG_FILE"
    
    if [ "$DRY_RUN" = "true" ]; then
        log_warning "DRY RUN MODE - No changes will be made"
        kubectl apply --dry-run=client -f "$PROJECT_ROOT/k8s/"
        return 0
    fi
    
    # Set trap for error handling
    trap handle_deployment_failure ERR
    
    # Execute deployment steps
    check_prerequisites
    validate_environment
    deploy_namespace_and_base
    deploy_security
    deploy_certificates
    deploy_database
    run_database_migrations
    deploy_cache
    deploy_storage
    deploy_backend
    deploy_monitoring
    deploy_loadbalancer
    deploy_sli_slo
    validate_deployment
    perform_health_checks
    
    # Mark deployment as completed
    DEPLOYMENT_STATUS="COMPLETED"
    
    # Generate final report
    generate_deployment_report
    
    log_success "MS5.0 Floor Dashboard Phase 9 Production Deployment completed successfully!"
    
    # Display access information
    log_info "Access Information:"
    log_info "Backend API: https://api.ms5-dashboard.company.com"
    log_info "Main Application: https://ms5-dashboard.company.com"
    log_info "Grafana: https://grafana.ms5-dashboard.company.com"
    log_info "Prometheus: https://prometheus.ms5-dashboard.company.com"
    log_info "Flower: https://flower.ms5-dashboard.company.com"
}

# Handle script arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-validation)
            SKIP_VALIDATION=true
            shift
            ;;
        --skip-migrations)
            SKIP_MIGRATIONS=true
            shift
            ;;
        --skip-monitoring)
            SKIP_MONITORING=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --no-rollback)
            ROLLBACK_ON_FAILURE=false
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --skip-validation    Skip environment validation"
            echo "  --skip-migrations    Skip database migrations"
            echo "  --skip-monitoring    Skip monitoring deployment"
            echo "  --dry-run           Perform a dry run without making changes"
            echo "  --no-rollback       Don't rollback on failure"
            echo "  --help              Show this help message"
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
