#!/bin/bash

# MS5.0 Floor Dashboard - Phase 7A Validation Script
# Core Security Implementation Validation
#
# This script validates the Phase 7A security infrastructure deployment
# including Pod Security Standards, network policies, TLS encryption,
# and Azure Key Vault integration.
#
# Usage: ./validate-phase7a.sh [--verbose] [--fix]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="ms5-production"
VERBOSE=false
FIX_ISSUES=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Validation results
VALIDATION_RESULTS=()
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

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
            --verbose)
                VERBOSE=true
                shift
                ;;
            --fix)
                FIX_ISSUES=true
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
MS5.0 Floor Dashboard - Phase 7A Validation Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --verbose     Show detailed output during validation
    --fix         Attempt to fix validation issues automatically
    -h, --help    Show this help message

DESCRIPTION:
    This script validates Phase 7A security infrastructure including:
    - Pod Security Standards enforcement
    - Enhanced network policies with micro-segmentation
    - TLS encryption for all service communication
    - Azure Key Vault integration for secrets management

EXAMPLES:
    $0                    # Validate with normal output
    $0 --verbose          # Validate with detailed output
    $0 --fix --verbose    # Validate and fix issues with detailed output

EOF
}

# Validation helper functions
add_result() {
    local check_name="$1"
    local status="$2"
    local message="$3"
    
    VALIDATION_RESULTS+=("$status|$check_name|$message")
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    case "$status" in
        "PASS")
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
            log_success "$check_name: $message"
            ;;
        "FAIL")
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
            log_error "$check_name: $message"
            ;;
        "WARN")
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
            log_warning "$check_name: $message"
            ;;
    esac
}

# Validate Pod Security Standards
validate_pod_security() {
    log_info "Validating Pod Security Standards..."
    
    # Check namespace Pod Security Standards labels
    local enforce_label=$(kubectl get namespace "$NAMESPACE" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null || echo "")
    local audit_label=$(kubectl get namespace "$NAMESPACE" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/audit}' 2>/dev/null || echo "")
    local warn_label=$(kubectl get namespace "$NAMESPACE" -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/warn}' 2>/dev/null || echo "")
    
    if [[ "$enforce_label" == "restricted" && "$audit_label" == "restricted" && "$warn_label" == "restricted" ]]; then
        add_result "Pod Security Standards" "PASS" "Namespace configured with restricted security level"
    else
        add_result "Pod Security Standards" "FAIL" "Namespace not properly configured with Pod Security Standards"
    fi
    
    # Check if pods are running with non-root users
    local root_pods=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[?(@.spec.securityContext.runAsUser==0)].metadata.name}' 2>/dev/null || echo "")
    if [[ -z "$root_pods" ]]; then
        add_result "Non-root Execution" "PASS" "No pods running as root user"
    else
        add_result "Non-root Execution" "FAIL" "Pods running as root user: $root_pods"
    fi
    
    # Check security contexts
    local pods_without_security_context=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[?(!@.spec.securityContext)].metadata.name}' 2>/dev/null || echo "")
    if [[ -z "$pods_without_security_context" ]]; then
        add_result "Security Contexts" "PASS" "All pods have security contexts configured"
    else
        add_result "Security Contexts" "WARN" "Pods without security context: $pods_without_security_context"
    fi
}

# Validate Network Policies
validate_network_policies() {
    log_info "Validating Network Policies..."
    
    # Check if network policies exist
    local network_policies=$(kubectl get networkpolicies -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
    if [[ "$network_policies" -ge 8 ]]; then
        add_result "Network Policies Count" "PASS" "Sufficient network policies deployed ($network_policies policies)"
    else
        add_result "Network Policies Count" "FAIL" "Insufficient network policies ($network_policies policies, expected >= 8)"
    fi
    
    # Check for default deny policy
    local default_deny=$(kubectl get networkpolicy ms5-default-deny-all -n "$NAMESPACE" 2>/dev/null || echo "")
    if [[ -n "$default_deny" ]]; then
        add_result "Default Deny Policy" "PASS" "Default deny policy exists"
    else
        add_result "Default Deny Policy" "FAIL" "Default deny policy missing"
    fi
    
    # Check for DNS resolution policy
    local dns_policy=$(kubectl get networkpolicy ms5-dns-resolution -n "$NAMESPACE" 2>/dev/null || echo "")
    if [[ -n "$dns_policy" ]]; then
        add_result "DNS Resolution Policy" "PASS" "DNS resolution policy exists"
    else
        add_result "DNS Resolution Policy" "FAIL" "DNS resolution policy missing"
    fi
    
    # Check service-specific policies
    local service_policies=("ms5-backend-network-policy" "ms5-database-network-policy" "ms5-redis-network-policy" "ms5-minio-network-policy")
    local missing_policies=()
    
    for policy in "${service_policies[@]}"; do
        if ! kubectl get networkpolicy "$policy" -n "$NAMESPACE" &>/dev/null; then
            missing_policies+=("$policy")
        fi
    done
    
    if [[ ${#missing_policies[@]} -eq 0 ]]; then
        add_result "Service Network Policies" "PASS" "All service-specific network policies exist"
    else
        add_result "Service Network Policies" "FAIL" "Missing network policies: ${missing_policies[*]}"
    fi
}

# Validate TLS Configuration
validate_tls_configuration() {
    log_info "Validating TLS Configuration..."
    
    # Check TLS secrets
    local tls_secrets=$(kubectl get secrets -n "$NAMESPACE" -l component=security --no-headers 2>/dev/null | wc -l)
    if [[ "$tls_secrets" -ge 5 ]]; then
        add_result "TLS Secrets" "PASS" "Sufficient TLS secrets deployed ($tls_secrets secrets)"
    else
        add_result "TLS Secrets" "WARN" "TLS secrets may need manual configuration ($tls_secrets secrets)"
    fi
    
    # Check CA certificate
    local ca_cert=$(kubectl get secret ca-cert -n "$NAMESPACE" 2>/dev/null || echo "")
    if [[ -n "$ca_cert" ]]; then
        add_result "CA Certificate" "PASS" "CA certificate secret exists"
    else
        add_result "CA Certificate" "WARN" "CA certificate secret missing"
    fi
    
    # Check service TLS certificates
    local service_certs=("backend-tls-cert" "database-tls-cert" "redis-tls-cert" "minio-tls-cert")
    local missing_certs=()
    
    for cert in "${service_certs[@]}"; do
        if ! kubectl get secret "$cert" -n "$NAMESPACE" &>/dev/null; then
            missing_certs+=("$cert")
        fi
    done
    
    if [[ ${#missing_certs[@]} -eq 0 ]]; then
        add_result "Service TLS Certificates" "PASS" "All service TLS certificates exist"
    else
        add_result "Service TLS Certificates" "WARN" "Missing TLS certificates: ${missing_certs[*]}"
    fi
}

# Validate Azure Key Vault Integration
validate_keyvault_integration() {
    log_info "Validating Azure Key Vault Integration..."
    
    # Check if Secret Provider Classes exist
    local spc_count=$(kubectl get secretproviderclasses -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
    if [[ "$spc_count" -ge 5 ]]; then
        add_result "Secret Provider Classes" "PASS" "Sufficient Secret Provider Classes deployed ($spc_count classes)"
    else
        add_result "Secret Provider Classes" "WARN" "Secret Provider Classes may need manual configuration ($spc_count classes)"
    fi
    
    # Check specific Secret Provider Classes
    local spc_classes=("ms5-database-secrets" "ms5-redis-secrets" "ms5-minio-secrets" "ms5-backend-secrets" "ms5-monitoring-secrets")
    local missing_spcs=()
    
    for spc in "${spc_classes[@]}"; do
        if ! kubectl get secretproviderclass "$spc" -n "$NAMESPACE" &>/dev/null; then
            missing_spcs+=("$spc")
        fi
    done
    
    if [[ ${#missing_spcs[@]} -eq 0 ]]; then
        add_result "Secret Provider Classes" "PASS" "All required Secret Provider Classes exist"
    else
        add_result "Secret Provider Classes" "WARN" "Missing Secret Provider Classes: ${missing_spcs[*]}"
    fi
    
    # Check Azure credentials secret
    local azure_creds=$(kubectl get secret azure-credentials -n "$NAMESPACE" 2>/dev/null || echo "")
    if [[ -n "$azure_creds" ]]; then
        add_result "Azure Credentials" "PASS" "Azure credentials secret exists"
    else
        add_result "Azure Credentials" "WARN" "Azure credentials secret missing"
    fi
    
    # Check CSI driver deployment
    local csi_driver=$(kubectl get daemonset csi-secrets-store-driver -n "$NAMESPACE" 2>/dev/null || echo "")
    if [[ -n "$csi_driver" ]]; then
        add_result "CSI Driver" "PASS" "Azure Key Vault CSI driver deployed"
    else
        add_result "CSI Driver" "WARN" "Azure Key Vault CSI driver not detected"
    fi
}

# Validate Security Monitoring
validate_security_monitoring() {
    log_info "Validating Security Monitoring..."
    
    # Check security monitoring configmaps
    local security_configs=("pod-security-policy-config" "security-context-templates" "security-monitoring-config")
    local missing_configs=()
    
    for config in "${security_configs[@]}"; do
        if ! kubectl get configmap "$config" -n "$NAMESPACE" &>/dev/null; then
            missing_configs+=("$config")
        fi
    done
    
    if [[ ${#missing_configs[@]} -eq 0 ]]; then
        add_result "Security Monitoring Configs" "PASS" "All security monitoring configurations exist"
    else
        add_result "Security Monitoring Configs" "WARN" "Missing security configurations: ${missing_configs[*]}"
    fi
    
    # Check network security monitoring
    local network_monitoring=$(kubectl get configmap network-security-monitoring -n "$NAMESPACE" 2>/dev/null || echo "")
    if [[ -n "$network_monitoring" ]]; then
        add_result "Network Security Monitoring" "PASS" "Network security monitoring configuration exists"
    else
        add_result "Network Security Monitoring" "WARN" "Network security monitoring configuration missing"
    fi
    
    # Check TLS monitoring
    local tls_monitoring=$(kubectl get configmap tls-monitoring-config -n "$NAMESPACE" 2>/dev/null || echo "")
    if [[ -n "$tls_monitoring" ]]; then
        add_result "TLS Monitoring" "PASS" "TLS monitoring configuration exists"
    else
        add_result "TLS Monitoring" "WARN" "TLS monitoring configuration missing"
    fi
}

# Generate validation report
generate_report() {
    log_info "Generating validation report..."
    
    echo ""
    echo "=========================================="
    echo "Phase 7A Security Validation Report"
    echo "=========================================="
    echo "Namespace: $NAMESPACE"
    echo "Total Checks: $TOTAL_CHECKS"
    echo "Passed: $PASSED_CHECKS"
    echo "Failed: $FAILED_CHECKS"
    echo "Warnings: $WARNING_CHECKS"
    echo ""
    
    if [[ "$FAILED_CHECKS" -eq 0 && "$WARNING_CHECKS" -eq 0 ]]; then
        log_success "All validations passed! Phase 7A security infrastructure is properly configured."
        return 0
    elif [[ "$FAILED_CHECKS" -eq 0 ]]; then
        log_warning "All critical validations passed, but there are warnings that should be addressed."
        return 1
    else
        log_error "Some validations failed. Please address the issues before proceeding."
        return 2
    fi
}

# Show detailed results
show_detailed_results() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo ""
        echo "Detailed Validation Results:"
        echo "============================"
        
        for result in "${VALIDATION_RESULTS[@]}"; do
            IFS='|' read -r status check_name message <<< "$result"
            case "$status" in
                "PASS")
                    echo -e "${GREEN}✓${NC} $check_name: $message"
                    ;;
                "FAIL")
                    echo -e "${RED}✗${NC} $check_name: $message"
                    ;;
                "WARN")
                    echo -e "${YELLOW}⚠${NC} $check_name: $message"
                    ;;
            esac
        done
        echo ""
    fi
}

# Main validation function
main() {
    log_info "Starting Phase 7A Security Validation"
    echo "========================================"
    
    # Parse command line arguments
    parse_args "$@"
    
    # Check if namespace exists
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_error "Namespace '$NAMESPACE' does not exist. Please run Phase 1-2 first."
        exit 1
    fi
    
    # Run validations
    validate_pod_security
    validate_network_policies
    validate_tls_configuration
    validate_keyvault_integration
    validate_security_monitoring
    
    # Show detailed results if verbose
    show_detailed_results
    
    # Generate report
    generate_report
    local exit_code=$?
    
    exit $exit_code
}

# Run main function with all arguments
main "$@"
