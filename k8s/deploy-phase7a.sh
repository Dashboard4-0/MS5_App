#!/bin/bash

# MS5.0 Floor Dashboard - Phase 7A Deployment Script
# Core Security Implementation: Pod Security, Network Security, Secrets Management
#
# This script deploys the complete Phase 7A security infrastructure including:
# - Pod Security Standards enforcement
# - Enhanced network policies with micro-segmentation
# - TLS encryption for all service communication
# - Azure Key Vault integration for secrets management
#
# Usage: ./deploy-phase7a.sh [--dry-run] [--verbose] [--force]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="ms5-production"
DRY_RUN=false
VERBOSE=false
FORCE=false

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

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1"
    fi
}

# Parse command line arguments
parse_args() {
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
            --force)
                FORCE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Show help information
show_help() {
    cat << EOF
MS5.0 Floor Dashboard - Phase 7A Deployment Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --dry-run     Show what would be deployed without making changes
    --verbose     Show detailed output during deployment
    --force       Force deployment even if validation fails
    -h, --help    Show this help message

DESCRIPTION:
    This script deploys Phase 7A security infrastructure including:
    - Pod Security Standards enforcement across all namespaces
    - Enhanced network policies with micro-segmentation
    - TLS encryption for all service communication
    - Azure Key Vault integration for secrets management

EXAMPLES:
    $0                    # Deploy with normal output
    $0 --dry-run          # Show what would be deployed
    $0 --verbose          # Deploy with detailed output
    $0 --force --verbose  # Force deployment with detailed output

EOF
}

# Validate prerequisites
validate_prerequisites() {
    log_info "Validating prerequisites..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if cluster is accessible
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Check if namespace exists
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_error "Namespace '$NAMESPACE' does not exist. Please run Phase 1-2 first."
        exit 1
    fi
    
    # Check if Azure Key Vault CSI driver is available
    if ! kubectl get crd secretproviderclasses.secrets-store.csi.x-k8s.io &> /dev/null; then
        log_warning "Azure Key Vault CSI driver not detected. Secrets will use placeholder values."
    fi
    
    log_success "Prerequisites validation completed"
}

# Deploy Pod Security Standards
deploy_pod_security() {
    log_info "Deploying Pod Security Standards..."
    
    local files=(
        "39-pod-security-standards.yaml"
    )
    
    for file in "${files[@]}"; do
        if [[ -f "$SCRIPT_DIR/$file" ]]; then
            log_verbose "Applying $file..."
            if [[ "$DRY_RUN" == "true" ]]; then
                kubectl apply -f "$SCRIPT_DIR/$file" --dry-run=client
            else
                kubectl apply -f "$SCRIPT_DIR/$file"
            fi
        else
            log_error "File $file not found"
            exit 1
        fi
    done
    
    log_success "Pod Security Standards deployed"
}

# Deploy Enhanced Network Policies
deploy_network_policies() {
    log_info "Deploying Enhanced Network Policies..."
    
    local files=(
        "40-enhanced-network-policies.yaml"
    )
    
    for file in "${files[@]}"; do
        if [[ -f "$SCRIPT_DIR/$file" ]]; then
            log_verbose "Applying $file..."
            if [[ "$DRY_RUN" == "true" ]]; then
                kubectl apply -f "$SCRIPT_DIR/$file" --dry-run=client
            else
                kubectl apply -f "$SCRIPT_DIR/$file"
            fi
        else
            log_error "File $file not found"
            exit 1
        fi
    done
    
    log_success "Enhanced Network Policies deployed"
}

# Deploy TLS Encryption Configuration
deploy_tls_encryption() {
    log_info "Deploying TLS Encryption Configuration..."
    
    local files=(
        "41-tls-encryption-config.yaml"
    )
    
    for file in "${files[@]}"; do
        if [[ -f "$SCRIPT_DIR/$file" ]]; then
            log_verbose "Applying $file..."
            if [[ "$DRY_RUN" == "true" ]]; then
                kubectl apply -f "$SCRIPT_DIR/$file" --dry-run=client
            else
                kubectl apply -f "$SCRIPT_DIR/$file"
            fi
        else
            log_error "File $file not found"
            exit 1
        fi
    done
    
    log_success "TLS Encryption Configuration deployed"
}

# Deploy Azure Key Vault Integration
deploy_keyvault_integration() {
    log_info "Deploying Azure Key Vault Integration..."
    
    local files=(
        "42-azure-keyvault-integration.yaml"
    )
    
    for file in "${files[@]}"; do
        if [[ -f "$SCRIPT_DIR/$file" ]]; then
            log_verbose "Applying $file..."
            if [[ "$DRY_RUN" == "true" ]]; then
                kubectl apply -f "$SCRIPT_DIR/$file" --dry-run=client
            else
                kubectl apply -f "$SCRIPT_DIR/$file"
            fi
        else
            log_error "File $file not found"
            exit 1
        fi
    done
    
    log_success "Azure Key Vault Integration deployed"
}

# Update existing deployments with enhanced security contexts
update_existing_deployments() {
    log_info "Updating existing deployments with enhanced security contexts..."
    
    # Update namespace with Pod Security Standards
    log_verbose "Updating namespace with Pod Security Standards..."
    if [[ "$DRY_RUN" == "true" ]]; then
        kubectl apply -f "$SCRIPT_DIR/01-namespace.yaml" --dry-run=client
    else
        kubectl apply -f "$SCRIPT_DIR/01-namespace.yaml"
    fi
    
    # Update backend deployment with enhanced security context
    log_verbose "Updating backend deployment with enhanced security context..."
    if [[ "$DRY_RUN" == "true" ]]; then
        kubectl apply -f "$SCRIPT_DIR/12-backend-deployment.yaml" --dry-run=client
    else
        kubectl apply -f "$SCRIPT_DIR/12-backend-deployment.yaml"
    fi
    
    log_success "Existing deployments updated with enhanced security contexts"
}

# Validate deployment
validate_deployment() {
    log_info "Validating Phase 7A deployment..."
    
    # Check Pod Security Standards
    log_verbose "Checking Pod Security Standards..."
    if kubectl get namespace "$NAMESPACE" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' | grep -q "restricted"; then
        log_success "Pod Security Standards enforced"
    else
        log_error "Pod Security Standards not properly enforced"
        return 1
    fi
    
    # Check Network Policies
    log_verbose "Checking Network Policies..."
    local network_policies=$(kubectl get networkpolicies -n "$NAMESPACE" --no-headers | wc -l)
    if [[ "$network_policies" -ge 8 ]]; then
        log_success "Network Policies deployed ($network_policies policies)"
    else
        log_error "Insufficient Network Policies deployed ($network_policies policies)"
        return 1
    fi
    
    # Check TLS Secrets
    log_verbose "Checking TLS Secrets..."
    local tls_secrets=$(kubectl get secrets -n "$NAMESPACE" -l component=security --no-headers | wc -l)
    if [[ "$tls_secrets" -ge 5 ]]; then
        log_success "TLS Secrets deployed ($tls_secrets secrets)"
    else
        log_warning "TLS Secrets may need manual configuration ($tls_secrets secrets)"
    fi
    
    # Check Secret Provider Classes
    log_verbose "Checking Secret Provider Classes..."
    local spc_count=$(kubectl get secretproviderclasses -n "$NAMESPACE" --no-headers | wc -l)
    if [[ "$spc_count" -ge 5 ]]; then
        log_success "Secret Provider Classes deployed ($spc_count classes)"
    else
        log_warning "Secret Provider Classes may need manual configuration ($spc_count classes)"
    fi
    
    log_success "Phase 7A deployment validation completed"
}

# Show deployment summary
show_summary() {
    log_info "Phase 7A Deployment Summary"
    echo "=================================="
    echo "Namespace: $NAMESPACE"
    echo "Pod Security Standards: Restricted"
    echo "Network Policies: Micro-segmented"
    echo "TLS Encryption: Enabled"
    echo "Secrets Management: Azure Key Vault"
    echo ""
    echo "Security Features Deployed:"
    echo "- Pod Security Standards enforcement"
    echo "- Enhanced network policies with micro-segmentation"
    echo "- TLS encryption for all service communication"
    echo "- Azure Key Vault integration for secrets management"
    echo "- Comprehensive security monitoring and alerting"
    echo ""
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_warning "DRY RUN MODE - No changes were made"
    else
        log_success "Phase 7A deployment completed successfully"
    fi
}

# Main deployment function
main() {
    log_info "Starting Phase 7A: Core Security Implementation"
    echo "=================================================="
    
    # Parse command line arguments
    parse_args "$@"
    
    # Validate prerequisites
    validate_prerequisites
    
    # Deploy security components
    deploy_pod_security
    deploy_network_policies
    deploy_tls_encryption
    deploy_keyvault_integration
    
    # Update existing deployments
    update_existing_deployments
    
    # Validate deployment (unless forced)
    if [[ "$FORCE" != "true" ]]; then
        validate_deployment
    fi
    
    # Show summary
    show_summary
}

# Run main function with all arguments
main "$@"
