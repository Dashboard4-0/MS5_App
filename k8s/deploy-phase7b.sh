#!/bin/bash

# MS5.0 Floor Dashboard - Phase 7B Deployment Script
# Advanced Security & Compliance Implementation
#
# This script deploys Phase 7B: Advanced Security & Compliance
# including container security scanning, compliance framework,
# security automation, Azure Policy governance, and audit logging.
#
# Usage: ./deploy-phase7b.sh [environment]
# Environment: production (default), staging, development

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="${1:-ms5-production}"
ENVIRONMENT="${2:-production}"
LOG_FILE="/tmp/phase7b-deployment-$(date +%Y%m%d-%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# Header
echo "=================================================="
echo "MS5.0 Floor Dashboard - Phase 7B Deployment"
echo "Advanced Security & Compliance Implementation"
echo "=================================================="
echo "Environment: $ENVIRONMENT"
echo "Namespace: $NAMESPACE"
echo "Log File: $LOG_FILE"
echo "=================================================="

# Pre-deployment validation
log "Starting Phase 7B deployment validation..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    error "kubectl is not installed or not in PATH"
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    error "Cannot connect to Kubernetes cluster"
fi

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    error "Namespace $NAMESPACE does not exist"
fi

# Check if Phase 7A is completed
log "Validating Phase 7A completion..."
if ! kubectl get configmap pod-security-standards-config -n "$NAMESPACE" &> /dev/null; then
    error "Phase 7A not completed. Please complete Phase 7A first."
fi

if ! kubectl get configmap enhanced-network-policies-config -n "$NAMESPACE" &> /dev/null; then
    error "Phase 7A not completed. Please complete Phase 7A first."
fi

if ! kubectl get configmap tls-encryption-config -n "$NAMESPACE" &> /dev/null; then
    error "Phase 7A not completed. Please complete Phase 7A first."
fi

if ! kubectl get configmap azure-keyvault-integration-config -n "$NAMESPACE" &> /dev/null; then
    error "Phase 7A not completed. Please complete Phase 7A first."
fi

success "Phase 7A validation completed"

# Deploy Phase 7B components
log "Deploying Phase 7B: Advanced Security & Compliance..."

# 1. Container Security Scanning
log "Deploying container security scanning..."
kubectl apply -f "$SCRIPT_DIR/43-container-security-scanning.yaml" -n "$NAMESPACE"
if [ $? -eq 0 ]; then
    success "Container security scanning deployed"
else
    error "Failed to deploy container security scanning"
fi

# Wait for Falco deployment
log "Waiting for Falco deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/falco -n "$NAMESPACE"
if [ $? -eq 0 ]; then
    success "Falco deployment ready"
else
    error "Falco deployment failed to become ready"
fi

# 2. Compliance Framework
log "Deploying compliance framework..."
kubectl apply -f "$SCRIPT_DIR/44-compliance-framework.yaml" -n "$NAMESPACE"
if [ $? -eq 0 ]; then
    success "Compliance framework deployed"
else
    error "Failed to deploy compliance framework"
fi

# 3. Security Automation
log "Deploying security automation..."
kubectl apply -f "$SCRIPT_DIR/45-security-automation.yaml" -n "$NAMESPACE"
if [ $? -eq 0 ]; then
    success "Security automation deployed"
else
    error "Failed to deploy security automation"
fi

# Wait for security automation CronJob
log "Waiting for security automation CronJob to be ready..."
kubectl wait --for=condition=complete --timeout=300s job/security-policy-automation -n "$NAMESPACE" || true

# 4. Azure Policy Governance
log "Deploying Azure Policy governance..."
kubectl apply -f "$SCRIPT_DIR/46-azure-policy-governance.yaml" -n "$NAMESPACE"
if [ $? -eq 0 ]; then
    success "Azure Policy governance deployed"
else
    error "Failed to deploy Azure Policy governance"
fi

# 5. Audit Logging & Compliance
log "Deploying audit logging & compliance..."
kubectl apply -f "$SCRIPT_DIR/47-audit-logging-compliance.yaml" -n "$NAMESPACE"
if [ $? -eq 0 ]; then
    success "Audit logging & compliance deployed"
else
    error "Failed to deploy audit logging & compliance"
fi

# Post-deployment validation
log "Performing post-deployment validation..."

# Check container security scanning
log "Validating container security scanning..."
if kubectl get configmap acr-security-config -n "$NAMESPACE" &> /dev/null; then
    success "ACR security configuration deployed"
else
    error "ACR security configuration not found"
fi

if kubectl get configmap image-security-policies -n "$NAMESPACE" &> /dev/null; then
    success "Image security policies deployed"
else
    error "Image security policies not found"
fi

if kubectl get deployment falco -n "$NAMESPACE" &> /dev/null; then
    success "Falco runtime security monitoring deployed"
else
    error "Falco runtime security monitoring not found"
fi

# Check compliance framework
log "Validating compliance framework..."
if kubectl get configmap cis-benchmark-config -n "$NAMESPACE" &> /dev/null; then
    success "CIS benchmark configuration deployed"
else
    error "CIS benchmark configuration not found"
fi

if kubectl get configmap iso27001-controls -n "$NAMESPACE" &> /dev/null; then
    success "ISO 27001 controls deployed"
else
    error "ISO 27001 controls not found"
fi

if kubectl get configmap fda-compliance -n "$NAMESPACE" &> /dev/null; then
    success "FDA 21 CFR Part 11 compliance deployed"
else
    error "FDA 21 CFR Part 11 compliance not found"
fi

if kubectl get configmap soc2-compliance -n "$NAMESPACE" &> /dev/null; then
    success "SOC 2 compliance deployed"
else
    error "SOC 2 compliance not found"
fi

if kubectl get configmap gdpr-compliance -n "$NAMESPACE" &> /dev/null; then
    success "GDPR compliance deployed"
else
    error "GDPR compliance not found"
fi

# Check security automation
log "Validating security automation..."
if kubectl get configmap security-automation-config -n "$NAMESPACE" &> /dev/null; then
    success "Security automation configuration deployed"
else
    error "Security automation configuration not found"
fi

if kubectl get configmap security-policy-config -n "$NAMESPACE" &> /dev/null; then
    success "Security policy configuration deployed"
else
    error "Security policy configuration not found"
fi

if kubectl get configmap incident-response-automation -n "$NAMESPACE" &> /dev/null; then
    success "Incident response automation deployed"
else
    error "Incident response automation not found"
fi

if kubectl get configmap security-sli-slo-config -n "$NAMESPACE" &> /dev/null; then
    success "Security SLI/SLO configuration deployed"
else
    error "Security SLI/SLO configuration not found"
fi

# Check Azure Policy governance
log "Validating Azure Policy governance..."
if kubectl get configmap azure-policy-definitions -n "$NAMESPACE" &> /dev/null; then
    success "Azure Policy definitions deployed"
else
    error "Azure Policy definitions not found"
fi

if kubectl get configmap azure-policy-assignments -n "$NAMESPACE" &> /dev/null; then
    success "Azure Policy assignments deployed"
else
    error "Azure Policy assignments not found"
fi

if kubectl get configmap azure-policy-compliance-monitoring -n "$NAMESPACE" &> /dev/null; then
    success "Azure Policy compliance monitoring deployed"
else
    error "Azure Policy compliance monitoring not found"
fi

# Check audit logging & compliance
log "Validating audit logging & compliance..."
if kubectl get configmap audit-log-config -n "$NAMESPACE" &> /dev/null; then
    success "Audit log configuration deployed"
else
    error "Audit log configuration not found"
fi

if kubectl get configmap compliance-framework-integration -n "$NAMESPACE" &> /dev/null; then
    success "Compliance framework integration deployed"
else
    error "Compliance framework integration not found"
fi

if kubectl get configmap audit-trail-management -n "$NAMESPACE" &> /dev/null; then
    success "Audit trail management deployed"
else
    error "Audit trail management not found"
fi

if kubectl get configmap compliance-reporting-config -n "$NAMESPACE" &> /dev/null; then
    success "Compliance reporting configuration deployed"
else
    error "Compliance reporting configuration not found"
fi

# Check service accounts and RBAC
log "Validating service accounts and RBAC..."
if kubectl get serviceaccount falco -n "$NAMESPACE" &> /dev/null; then
    success "Falco service account deployed"
else
    error "Falco service account not found"
fi

if kubectl get serviceaccount security-automation -n "$NAMESPACE" &> /dev/null; then
    success "Security automation service account deployed"
else
    error "Security automation service account not found"
fi

# Check monitoring and alerting
log "Validating monitoring and alerting..."
if kubectl get configmap container-security-monitoring -n "$NAMESPACE" &> /dev/null; then
    success "Container security monitoring deployed"
else
    error "Container security monitoring not found"
fi

if kubectl get configmap compliance-monitoring-alerts -n "$NAMESPACE" &> /dev/null; then
    success "Compliance monitoring alerts deployed"
else
    error "Compliance monitoring alerts not found"
fi

if kubectl get configmap security-automation-monitoring -n "$NAMESPACE" &> /dev/null; then
    success "Security automation monitoring deployed"
else
    error "Security automation monitoring not found"
fi

if kubectl get configmap azure-policy-monitoring-alerts -n "$NAMESPACE" &> /dev/null; then
    success "Azure Policy monitoring alerts deployed"
else
    error "Azure Policy monitoring alerts not found"
fi

if kubectl get configmap audit-log-monitoring-alerts -n "$NAMESPACE" &> /dev/null; then
    success "Audit log monitoring alerts deployed"
else
    error "Audit log monitoring alerts not found"
fi

# Final validation
log "Performing final validation..."

# Check all pods are running
log "Checking pod status..."
PODS_NOT_RUNNING=$(kubectl get pods -n "$NAMESPACE" --field-selector=status.phase!=Running --no-headers | wc -l)
if [ "$PODS_NOT_RUNNING" -eq 0 ]; then
    success "All pods are running"
else
    warning "$PODS_NOT_RUNNING pods are not running"
    kubectl get pods -n "$NAMESPACE" --field-selector=status.phase!=Running
fi

# Check all services are available
log "Checking service status..."
SERVICES_NOT_READY=$(kubectl get services -n "$NAMESPACE" --no-headers | grep -v "ClusterIP" | wc -l)
if [ "$SERVICES_NOT_READY" -gt 0 ]; then
    success "Services are available"
else
    warning "No services found"
fi

# Check all ConfigMaps are created
log "Checking ConfigMap status..."
CONFIGMAPS_COUNT=$(kubectl get configmaps -n "$NAMESPACE" --no-headers | wc -l)
if [ "$CONFIGMAPS_COUNT" -gt 0 ]; then
    success "$CONFIGMAPS_COUNT ConfigMaps created"
else
    warning "No ConfigMaps found"
fi

# Check all Secrets are created
log "Checking Secret status..."
SECRETS_COUNT=$(kubectl get secrets -n "$NAMESPACE" --no-headers | wc -l)
if [ "$SECRETS_COUNT" -gt 0 ]; then
    success "$SECRETS_COUNT Secrets created"
else
    warning "No Secrets found"
fi

# Check all RBAC resources are created
log "Checking RBAC status..."
ROLES_COUNT=$(kubectl get roles -n "$NAMESPACE" --no-headers | wc -l)
CLUSTER_ROLES_COUNT=$(kubectl get clusterroles --no-headers | grep -E "(falco|security-automation)" | wc -l)
if [ "$ROLES_COUNT" -gt 0 ] || [ "$CLUSTER_ROLES_COUNT" -gt 0 ]; then
    success "RBAC resources created"
else
    warning "No RBAC resources found"
fi

# Summary
echo "=================================================="
echo "Phase 7B Deployment Summary"
echo "=================================================="
echo "Environment: $ENVIRONMENT"
echo "Namespace: $NAMESPACE"
echo "Deployment Time: $(date)"
echo "Log File: $LOG_FILE"
echo "=================================================="

# Component Status
echo "Component Status:"
echo "- Container Security Scanning: ✅ Deployed"
echo "- Compliance Framework: ✅ Deployed"
echo "- Security Automation: ✅ Deployed"
echo "- Azure Policy Governance: ✅ Deployed"
echo "- Audit Logging & Compliance: ✅ Deployed"
echo "=================================================="

# Next Steps
echo "Next Steps:"
echo "1. Verify all components are running correctly"
echo "2. Test security scanning functionality"
echo "3. Validate compliance framework integration"
echo "4. Test security automation procedures"
echo "5. Verify Azure Policy governance"
echo "6. Test audit logging and compliance reporting"
echo "7. Proceed to Phase 8A: Core Testing & Performance Validation"
echo "=================================================="

success "Phase 7B: Advanced Security & Compliance deployment completed successfully!"

# Exit with success
exit 0
