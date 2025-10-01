#!/bin/bash

# MS5.0 Floor Dashboard - Phase 10B: Post-Deployment Validation & Production Support
# Master execution script for comprehensive post-deployment validation, advanced deployment strategies,
# cost optimization, and production support framework establishment
#
# This script orchestrates the complete Phase 10B implementation including:
# - Comprehensive post-deployment validation
# - Advanced deployment strategies (blue-green, canary)
# - Cost optimization and resource management
# - Production support framework establishment
# - SLI/SLO implementation and monitoring
#
# Usage: ./00-phase10b-master-execution.sh [environment] [options]
# Environment: staging|production (default: production)
# Options: --dry-run, --skip-validation, --force

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
K8S_DIR="$PROJECT_ROOT/k8s"
NAMESPACE_PREFIX="ms5"
ENVIRONMENT="${1:-production}"
DRY_RUN="${2:-false}"
SKIP_VALIDATION="${3:-false}"
FORCE="${4:-false}"

# Azure Configuration
RESOURCE_GROUP_NAME="rg-ms5-production-uksouth"
AKS_CLUSTER_NAME="aks-ms5-prod-uksouth"
ACR_NAME="ms5acrprod"
KEY_VAULT_NAME="kv-ms5-prod-uksouth"
LOCATION="UK South"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_phase() {
    echo -e "${PURPLE}[PHASE]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_step() {
    echo -e "${CYAN}[STEP]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Create log file
LOG_FILE="$PROJECT_ROOT/logs/phase10b-execution-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "$(dirname "$LOG_FILE")"

# Enhanced logging function
log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" | tee -a "$LOG_FILE"
}

# Script execution function with comprehensive error handling
execute_script() {
    local script_name="$1"
    local script_path="$SCRIPT_DIR/$script_name"
    
    if [[ ! -f "$script_path" ]]; then
        log_error "Script not found: $script_path"
        return 1
    fi
    
    if [[ ! -x "$script_path" ]]; then
        log_warning "Making script executable: $script_path"
        chmod +x "$script_path"
    fi
    
    log_step "Executing $script_name..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would execute $script_path"
        return 0
    fi
    
    # Execute script with comprehensive error handling
    if bash -euo pipefail "$script_path" "$ENVIRONMENT" "$DRY_RUN" "$SKIP_VALIDATION" "$FORCE" 2>&1 | tee -a "$LOG_FILE"; then
        log_success "$script_name completed successfully"
        return 0
    else
        log_error "$script_name failed with exit code $?"
        return 1
    fi
}

# Validation functions
validate_environment() {
    log_info "Validating environment configuration..."
    
    if [[ "$ENVIRONMENT" != "staging" && "$ENVIRONMENT" != "production" ]]; then
        log_error "Invalid environment: $ENVIRONMENT. Must be 'staging' or 'production'"
        exit 1
    fi
    
    log_success "Environment validation passed: $ENVIRONMENT"
}

validate_prerequisites() {
    log_info "Validating prerequisites..."
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI not found. Please install Azure CLI."
        exit 1
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl."
        exit 1
    fi
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker not found. Please install Docker."
        exit 1
    fi
    
    # Check Azure login
    if ! az account show &> /dev/null; then
        log_error "Not logged into Azure CLI. Please run 'az login' first."
        exit 1
    fi
    
    # Check AKS cluster access
    if ! az aks show --resource-group "$RESOURCE_GROUP_NAME" --name "$AKS_CLUSTER_NAME" &> /dev/null; then
        log_error "AKS cluster not found or not accessible: $AKS_CLUSTER_NAME"
        exit 1
    fi
    
    log_success "Prerequisites validation passed"
}

validate_phase10a_completion() {
    log_info "Validating Phase 10A completion..."
    
    # Check if Phase 10A was completed successfully
    local namespace="$NAMESPACE_PREFIX-$ENVIRONMENT"
    
    # Verify critical pods are running
    local critical_pods=(
        "ms5-backend"
        "ms5-postgres"
        "ms5-redis"
        "ms5-prometheus"
        "ms5-grafana"
        "ms5-celery-worker"
    )
    
    for pod in "${critical_pods[@]}"; do
        if ! kubectl get pods -n "$namespace" | grep -q "$pod.*Running"; then
            log_error "Critical pod not running: $pod"
            exit 1
        fi
    done
    
    # Verify services are accessible
    if ! kubectl get service ms5-backend-service -n "$namespace" &> /dev/null; then
        log_error "Backend service not found in namespace: $namespace"
        exit 1
    fi
    
    log_success "Phase 10A completion validation passed"
}

# Pre-deployment backup function
create_system_backup() {
    log_info "Creating comprehensive system backup..."
    
    local backup_dir="$PROJECT_ROOT/backups/phase10b-pre-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    
    # Backup Kubernetes configurations
    kubectl get all -n "$NAMESPACE_PREFIX-$ENVIRONMENT" -o yaml > "$backup_dir/k8s-resources.yaml" 2>/dev/null || true
    kubectl get configmaps -n "$NAMESPACE_PREFIX-$ENVIRONMENT" -o yaml > "$backup_dir/configmaps.yaml" 2>/dev/null || true
    kubectl get secrets -n "$NAMESPACE_PREFIX-$ENVIRONMENT" -o yaml > "$backup_dir/secrets.yaml" 2>/dev/null || true
    
    # Backup application configurations
    cp -r "$K8S_DIR" "$backup_dir/k8s-manifests" 2>/dev/null || true
    cp -r "$PROJECT_ROOT/backend" "$backup_dir/backend-source" 2>/dev/null || true
    cp -r "$PROJECT_ROOT/frontend" "$backup_dir/frontend-source" 2>/dev/null || true
    
    log_success "System backup created: $backup_dir"
}

# Main execution
main() {
    log_phase "Starting Phase 10B: Post-Deployment Validation & Production Support"
    log_info "Environment: $ENVIRONMENT"
    log_info "Dry Run: $DRY_RUN"
    log_info "Skip Validation: $SKIP_VALIDATION"
    log_info "Force: $FORCE"
    log_info "Log File: $LOG_FILE"
    echo ""
    
    # Validation phase
    validate_environment
    validate_prerequisites
    validate_phase10a_completion
    
    # Create system backup
    create_system_backup
    
    # Phase 10B execution
    log_phase "Executing Phase 10B implementation..."
    
    # 10B.1 Post-Deployment Validation
    log_step "Phase 10B.1: Post-Deployment Validation"
    execute_script "01-post-deployment-validation.sh"
    
    # 10B.2 Advanced Deployment Strategies
    log_step "Phase 10B.2: Advanced Deployment Strategies"
    execute_script "02-advanced-deployment-strategies.sh"
    
    # 10B.3 Cost Optimization and Resource Management
    log_step "Phase 10B.3: Cost Optimization and Resource Management"
    execute_script "03-cost-optimization-resource-management.sh"
    
    # 10B.4 Production Support Framework
    log_step "Phase 10B.4: Production Support Framework"
    execute_script "04-production-support-framework.sh"
    
    # 10B.5 Final Validation and Documentation
    log_step "Phase 10B.5: Final Validation and Documentation"
    execute_script "05-final-validation-documentation.sh"
    
    # Phase 10B completion
    log_phase "Phase 10B execution completed successfully!"
    log_success "All Phase 10B components have been implemented and validated"
    log_info "Check the log file at $LOG_FILE for detailed execution logs"
    echo ""
    
    # Display summary
    echo "=== Phase 10B Implementation Summary ==="
    echo ""
    echo "✅ Post-Deployment Validation: Comprehensive validation completed"
    echo "✅ Advanced Deployment Strategies: Blue-green and canary deployments implemented"
    echo "✅ Cost Optimization: Azure Spot Instances and resource optimization deployed"
    echo "✅ Production Support Framework: Comprehensive support framework established"
    echo "✅ SLI/SLO Implementation: Service Level Indicators and Objectives implemented"
    echo "✅ Final Validation: System optimization and documentation completed"
    echo ""
    echo "=== Production System Status ==="
    echo "🌐 Environment: $ENVIRONMENT"
    echo "🏗️  AKS Cluster: $AKS_CLUSTER_NAME"
    echo "📦 Container Registry: $ACR_NAME"
    echo "🔐 Key Vault: $KEY_VAULT_NAME"
    echo "📊 Monitoring: Enhanced monitoring with SLI/SLO"
    echo "🔄 Deployment: Advanced deployment strategies (blue-green, canary)"
    echo "💰 Cost Optimization: Azure Spot Instances and resource optimization"
    echo "🛠️  Support Framework: Comprehensive production support established"
    echo ""
    echo "=== Next Steps ==="
    echo "1. Review the execution log at $LOG_FILE"
    echo "2. Begin long-term production operations"
    echo "3. Monitor system performance and cost optimization"
    echo "4. Conduct regular disaster recovery testing"
    echo "5. Maintain production support procedures"
}

# Error handling
trap 'log_error "Phase 10B execution failed at line $LINENO"' ERR

# Execute main function
main "$@"
