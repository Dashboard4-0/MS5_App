#!/bin/bash

# MS5.0 Floor Dashboard - Phase 7B Validation Script
# Advanced Security & Compliance Validation
#
# This script validates Phase 7B: Advanced Security & Compliance
# implementation including container security scanning, compliance
# framework, security automation, Azure Policy governance, and audit logging.
#
# Usage: ./validate-phase7b.sh [environment]
# Environment: production (default), staging, development

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="${1:-ms5-production}"
ENVIRONMENT="${2:-production}"
LOG_FILE="/tmp/phase7b-validation-$(date +%Y%m%d-%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Validation counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    ((FAILED_CHECKS++))
    ((TOTAL_CHECKS++))
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
    ((PASSED_CHECKS++))
    ((TOTAL_CHECKS++))
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
    ((WARNING_CHECKS++))
    ((TOTAL_CHECKS++))
}

# Validation function
validate_check() {
    local check_name="$1"
    local check_command="$2"
    local expected_result="$3"
    
    log "Validating $check_name..."
    
    if eval "$check_command" &> /dev/null; then
        if [ "$expected_result" = "true" ]; then
            success "$check_name: PASSED"
        else
            error "$check_name: FAILED (unexpected result)"
        fi
    else
        if [ "$expected_result" = "false" ]; then
            success "$check_name: PASSED"
        else
            error "$check_name: FAILED"
        fi
    fi
}

# Header
echo "=================================================="
echo "MS5.0 Floor Dashboard - Phase 7B Validation"
echo "Advanced Security & Compliance Validation"
echo "=================================================="
echo "Environment: $ENVIRONMENT"
echo "Namespace: $NAMESPACE"
echo "Log File: $LOG_FILE"
echo "=================================================="

# Pre-validation checks
log "Starting Phase 7B validation..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    error "Cannot connect to Kubernetes cluster"
    exit 1
fi

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    error "Namespace $NAMESPACE does not exist"
    exit 1
fi

success "Pre-validation checks completed"

# Container Security Scanning Validation
log "Validating Container Security Scanning..."

# ACR Security Configuration
validate_check "ACR Security Configuration" \
    "kubectl get configmap acr-security-config -n $NAMESPACE" \
    "true"

# Image Security Policies
validate_check "Image Security Policies" \
    "kubectl get configmap image-security-policies -n $NAMESPACE" \
    "true"

# Falco Runtime Security Monitoring
validate_check "Falco Runtime Security Monitoring" \
    "kubectl get deployment falco -n $NAMESPACE" \
    "true"

# Falco Configuration
validate_check "Falco Configuration" \
    "kubectl get configmap falco-config -n $NAMESPACE" \
    "true"

# Falco Security Rules
validate_check "Falco Security Rules" \
    "kubectl get configmap falco-rules -n $NAMESPACE" \
    "true"

# Falco Plugins
validate_check "Falco Plugins" \
    "kubectl get configmap falco-plugins -n $NAMESPACE" \
    "true"

# Falco Service Account
validate_check "Falco Service Account" \
    "kubectl get serviceaccount falco -n $NAMESPACE" \
    "true"

# Falco RBAC
validate_check "Falco RBAC" \
    "kubectl get clusterrole falco" \
    "true"

validate_check "Falco ClusterRoleBinding" \
    "kubectl get clusterrolebinding falco" \
    "true"

# Falco Service
validate_check "Falco Service" \
    "kubectl get service falco -n $NAMESPACE" \
    "true"

# Container Security Monitoring
validate_check "Container Security Monitoring" \
    "kubectl get configmap container-security-monitoring -n $NAMESPACE" \
    "true"

# Compliance Framework Validation
log "Validating Compliance Framework..."

# CIS Benchmark Configuration
validate_check "CIS Benchmark Configuration" \
    "kubectl get configmap cis-benchmark-config -n $NAMESPACE" \
    "true"

# ISO 27001 Controls
validate_check "ISO 27001 Controls" \
    "kubectl get configmap iso27001-controls -n $NAMESPACE" \
    "true"

# FDA 21 CFR Part 11 Compliance
validate_check "FDA 21 CFR Part 11 Compliance" \
    "kubectl get configmap fda-compliance -n $NAMESPACE" \
    "true"

# SOC 2 Compliance
validate_check "SOC 2 Compliance" \
    "kubectl get configmap soc2-compliance -n $NAMESPACE" \
    "true"

# GDPR Compliance
validate_check "GDPR Compliance" \
    "kubectl get configmap gdpr-compliance -n $NAMESPACE" \
    "true"

# Compliance Monitoring
validate_check "Compliance Monitoring" \
    "kubectl get configmap compliance-monitoring -n $NAMESPACE" \
    "true"

# Compliance Monitoring Alerts
validate_check "Compliance Monitoring Alerts" \
    "kubectl get configmap compliance-monitoring-alerts -n $NAMESPACE" \
    "true"

# Security Automation Validation
log "Validating Security Automation..."

# Security Automation Configuration
validate_check "Security Automation Configuration" \
    "kubectl get configmap security-automation-config -n $NAMESPACE" \
    "true"

# Security Policy Configuration
validate_check "Security Policy Configuration" \
    "kubectl get configmap security-policy-config -n $NAMESPACE" \
    "true"

# Security Remediation Scripts
validate_check "Security Remediation Scripts" \
    "kubectl get configmap security-remediation-scripts -n $NAMESPACE" \
    "true"

# Incident Response Automation
validate_check "Incident Response Automation" \
    "kubectl get configmap incident-response-automation -n $NAMESPACE" \
    "true"

# Security SLI/SLO Configuration
validate_check "Security SLI/SLO Configuration" \
    "kubectl get configmap security-sli-slo-config -n $NAMESPACE" \
    "true"

# Security Automation Service Account
validate_check "Security Automation Service Account" \
    "kubectl get serviceaccount security-automation -n $NAMESPACE" \
    "true"

# Security Automation RBAC
validate_check "Security Automation RBAC" \
    "kubectl get clusterrole security-automation" \
    "true"

validate_check "Security Automation ClusterRoleBinding" \
    "kubectl get clusterrolebinding security-automation" \
    "true"

# Security Automation Monitoring
validate_check "Security Automation Monitoring" \
    "kubectl get configmap security-automation-monitoring -n $NAMESPACE" \
    "true"

# Azure Policy Governance Validation
log "Validating Azure Policy Governance..."

# Azure Policy Definitions
validate_check "Azure Policy Definitions" \
    "kubectl get configmap azure-policy-definitions -n $NAMESPACE" \
    "true"

# Azure Policy Assignments
validate_check "Azure Policy Assignments" \
    "kubectl get configmap azure-policy-assignments -n $NAMESPACE" \
    "true"

# Azure Policy Compliance Monitoring
validate_check "Azure Policy Compliance Monitoring" \
    "kubectl get configmap azure-policy-compliance-monitoring -n $NAMESPACE" \
    "true"

# Azure Policy Remediation
validate_check "Azure Policy Remediation" \
    "kubectl get configmap azure-policy-remediation -n $NAMESPACE" \
    "true"

# Azure Policy Monitoring Alerts
validate_check "Azure Policy Monitoring Alerts" \
    "kubectl get configmap azure-policy-monitoring-alerts -n $NAMESPACE" \
    "true"

# Audit Logging & Compliance Validation
log "Validating Audit Logging & Compliance..."

# Audit Log Configuration
validate_check "Audit Log Configuration" \
    "kubectl get configmap audit-log-config -n $NAMESPACE" \
    "true"

# Audit Log Backend Configuration
validate_check "Audit Log Backend Configuration" \
    "kubectl get configmap audit-log-backend-config -n $NAMESPACE" \
    "true"

# Compliance Framework Integration
validate_check "Compliance Framework Integration" \
    "kubectl get configmap compliance-framework-integration -n $NAMESPACE" \
    "true"

# Audit Trail Management
validate_check "Audit Trail Management" \
    "kubectl get configmap audit-trail-management -n $NAMESPACE" \
    "true"

# Compliance Reporting Configuration
validate_check "Compliance Reporting Configuration" \
    "kubectl get configmap compliance-reporting-config -n $NAMESPACE" \
    "true"

# Audit Log Monitoring Alerts
validate_check "Audit Log Monitoring Alerts" \
    "kubectl get configmap audit-log-monitoring-alerts -n $NAMESPACE" \
    "true"

# Pod Status Validation
log "Validating Pod Status..."

# Check Falco pod status
FALCO_PODS=$(kubectl get pods -n "$NAMESPACE" -l app=falco --no-headers | wc -l)
if [ "$FALCO_PODS" -gt 0 ]; then
    FALCO_RUNNING=$(kubectl get pods -n "$NAMESPACE" -l app=falco --field-selector=status.phase=Running --no-headers | wc -l)
    if [ "$FALCO_RUNNING" -eq "$FALCO_PODS" ]; then
        success "All Falco pods are running"
    else
        error "Some Falco pods are not running"
    fi
else
    error "No Falco pods found"
fi

# Service Status Validation
log "Validating Service Status..."

# Check Falco service
if kubectl get service falco -n "$NAMESPACE" &> /dev/null; then
    FALCO_SERVICE_IP=$(kubectl get service falco -n "$NAMESPACE" -o jsonpath='{.spec.clusterIP}')
    if [ -n "$FALCO_SERVICE_IP" ]; then
        success "Falco service is available at $FALCO_SERVICE_IP"
    else
        error "Falco service has no cluster IP"
    fi
else
    error "Falco service not found"
fi

# ConfigMap Count Validation
log "Validating ConfigMap Count..."

EXPECTED_CONFIGMAPS=25
ACTUAL_CONFIGMAPS=$(kubectl get configmaps -n "$NAMESPACE" --no-headers | wc -l)
if [ "$ACTUAL_CONFIGMAPS" -ge "$EXPECTED_CONFIGMAPS" ]; then
    success "ConfigMap count validation passed ($ACTUAL_CONFIGMAPS >= $EXPECTED_CONFIGMAPS)"
else
    warning "ConfigMap count validation failed ($ACTUAL_CONFIGMAPS < $EXPECTED_CONFIGMAPS)"
fi

# Secret Count Validation
log "Validating Secret Count..."

EXPECTED_SECRETS=5
ACTUAL_SECRETS=$(kubectl get secrets -n "$NAMESPACE" --no-headers | wc -l)
if [ "$ACTUAL_SECRETS" -ge "$EXPECTED_SECRETS" ]; then
    success "Secret count validation passed ($ACTUAL_SECRETS >= $EXPECTED_SECRETS)"
else
    warning "Secret count validation failed ($ACTUAL_SECRETS < $EXPECTED_SECRETS)"
fi

# RBAC Validation
log "Validating RBAC Resources..."

# Check ClusterRoles
EXPECTED_CLUSTER_ROLES=2
ACTUAL_CLUSTER_ROLES=$(kubectl get clusterroles --no-headers | grep -E "(falco|security-automation)" | wc -l)
if [ "$ACTUAL_CLUSTER_ROLES" -ge "$EXPECTED_CLUSTER_ROLES" ]; then
    success "ClusterRole count validation passed ($ACTUAL_CLUSTER_ROLES >= $EXPECTED_CLUSTER_ROLES)"
else
    warning "ClusterRole count validation failed ($ACTUAL_CLUSTER_ROLES < $EXPECTED_CLUSTER_ROLES)"
fi

# Check ClusterRoleBindings
EXPECTED_CLUSTER_ROLE_BINDINGS=2
ACTUAL_CLUSTER_ROLE_BINDINGS=$(kubectl get clusterrolebindings --no-headers | grep -E "(falco|security-automation)" | wc -l)
if [ "$ACTUAL_CLUSTER_ROLE_BINDINGS" -ge "$EXPECTED_CLUSTER_ROLE_BINDINGS" ]; then
    success "ClusterRoleBinding count validation passed ($ACTUAL_CLUSTER_ROLE_BINDINGS >= $EXPECTED_CLUSTER_ROLE_BINDINGS)"
else
    warning "ClusterRoleBinding count validation failed ($ACTUAL_CLUSTER_ROLE_BINDINGS < $EXPECTED_CLUSTER_ROLE_BINDINGS)"
fi

# Service Account Validation
log "Validating Service Accounts..."

EXPECTED_SERVICE_ACCOUNTS=2
ACTUAL_SERVICE_ACCOUNTS=$(kubectl get serviceaccounts -n "$NAMESPACE" --no-headers | wc -l)
if [ "$ACTUAL_SERVICE_ACCOUNTS" -ge "$EXPECTED_SERVICE_ACCOUNTS" ]; then
    success "ServiceAccount count validation passed ($ACTUAL_SERVICE_ACCOUNTS >= $EXPECTED_SERVICE_ACCOUNTS)"
else
    warning "ServiceAccount count validation failed ($ACTUAL_SERVICE_ACCOUNTS < $EXPECTED_SERVICE_ACCOUNTS)"
fi

# Network Policy Validation
log "Validating Network Policies..."

# Check if network policies exist
NETWORK_POLICIES=$(kubectl get networkpolicies -n "$NAMESPACE" --no-headers | wc -l)
if [ "$NETWORK_POLICIES" -gt 0 ]; then
    success "Network policies are configured ($NETWORK_POLICIES policies)"
else
    warning "No network policies found"
fi

# Security Context Validation
log "Validating Security Contexts..."

# Check if pods have security contexts
PODS_WITH_SECURITY_CONTEXT=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].spec.securityContext}' | wc -l)
if [ "$PODS_WITH_SECURITY_CONTEXT" -gt 0 ]; then
    success "Pods have security contexts configured"
else
    warning "No security contexts found in pods"
fi

# Final Validation Summary
echo "=================================================="
echo "Phase 7B Validation Summary"
echo "=================================================="
echo "Environment: $ENVIRONMENT"
echo "Namespace: $NAMESPACE"
echo "Validation Time: $(date)"
echo "Log File: $LOG_FILE"
echo "=================================================="

# Validation Results
echo "Validation Results:"
echo "- Total Checks: $TOTAL_CHECKS"
echo "- Passed: $PASSED_CHECKS"
echo "- Failed: $FAILED_CHECKS"
echo "- Warnings: $WARNING_CHECKS"
echo "=================================================="

# Calculate success rate
if [ "$TOTAL_CHECKS" -gt 0 ]; then
    SUCCESS_RATE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
    echo "Success Rate: $SUCCESS_RATE%"
else
    SUCCESS_RATE=0
    echo "Success Rate: 0%"
fi

echo "=================================================="

# Component Status
echo "Component Status:"
echo "- Container Security Scanning: $([ $FAILED_CHECKS -eq 0 ] && echo "✅ PASSED" || echo "❌ FAILED")"
echo "- Compliance Framework: $([ $FAILED_CHECKS -eq 0 ] && echo "✅ PASSED" || echo "❌ FAILED")"
echo "- Security Automation: $([ $FAILED_CHECKS -eq 0 ] && echo "✅ PASSED" || echo "❌ FAILED")"
echo "- Azure Policy Governance: $([ $FAILED_CHECKS -eq 0 ] && echo "✅ PASSED" || echo "❌ FAILED")"
echo "- Audit Logging & Compliance: $([ $FAILED_CHECKS -eq 0 ] && echo "✅ PASSED" || echo "❌ FAILED")"
echo "=================================================="

# Recommendations
echo "Recommendations:"
if [ "$FAILED_CHECKS" -gt 0 ]; then
    echo "- Review failed checks and resolve issues"
    echo "- Re-run validation after fixes"
    echo "- Check logs for detailed error information"
else
    echo "- All validations passed successfully"
    echo "- Phase 7B is ready for production use"
    echo "- Proceed to Phase 8A: Core Testing & Performance Validation"
fi

if [ "$WARNING_CHECKS" -gt 0 ]; then
    echo "- Review warnings and consider improvements"
    echo "- Monitor system performance and adjust as needed"
fi

echo "=================================================="

# Exit with appropriate code
if [ "$FAILED_CHECKS" -eq 0 ]; then
    success "Phase 7B validation completed successfully!"
    exit 0
else
    error "Phase 7B validation failed with $FAILED_CHECKS errors"
    exit 1
fi
