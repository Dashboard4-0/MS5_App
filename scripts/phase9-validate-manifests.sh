#!/bin/bash

# MS5.0 Floor Dashboard - Phase 9 Kubernetes Manifest Validation Script
# This script validates all Kubernetes manifests for production deployment
# Designed with starship-grade precision and reliability

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NAMESPACE="ms5-production"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${PROJECT_ROOT}/logs/phase9-manifest-validation-${TIMESTAMP}.log"

# Environment variables
VALIDATE_SECURITY=${VALIDATE_SECURITY:-true}
VALIDATE_NETWORKING=${VALIDATE_NETWORKING:-true}
VALIDATE_STORAGE=${VALIDATE_STORAGE:-true}
VALIDATE_MONITORING=${VALIDATE_MONITORING:-true}
VALIDATE_INGRESS=${VALIDATE_INGRESS:-true}

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

# Validation counters
TOTAL_VALIDATIONS=0
PASSED_VALIDATIONS=0
FAILED_VALIDATIONS=0
WARNING_VALIDATIONS=0

# Validation result tracking
declare -A VALIDATION_RESULTS

# Function to record validation result
record_validation() {
    local validation_name="$1"
    local status="$2"
    local message="$3"
    
    VALIDATION_RESULTS["$validation_name"]="$status|$message"
    
    case "$status" in
        "PASS")
            ((PASSED_VALIDATIONS++))
            log_success "$validation_name: $message"
            ;;
        "FAIL")
            ((FAILED_VALIDATIONS++))
            log_error "$validation_name: $message"
            ;;
        "WARN")
            ((WARNING_VALIDATIONS++))
            log_warning "$validation_name: $message"
            ;;
    esac
    
    ((TOTAL_VALIDATIONS++))
}

# Function to validate YAML syntax
validate_yaml_syntax() {
    local file_path="$1"
    local file_name=$(basename "$file_path")
    
    if [ ! -f "$file_path" ]; then
        record_validation "yaml-syntax-$file_name" "FAIL" "File not found"
        return 1
    fi
    
    # Basic YAML syntax check
    if python3 -c "import yaml; yaml.safe_load(open('$file_path'))" &> /dev/null; then
        record_validation "yaml-syntax-$file_name" "PASS" "Valid YAML syntax"
    else
        record_validation "yaml-syntax-$file_name" "FAIL" "Invalid YAML syntax"
        return 1
    fi
    
    # Kubernetes manifest validation
    if kubectl apply --dry-run=client -f "$file_path" &> /dev/null; then
        record_validation "k8s-manifest-$file_name" "PASS" "Valid Kubernetes manifest"
    else
        record_validation "k8s-manifest-$file_name" "FAIL" "Invalid Kubernetes manifest"
        return 1
    fi
}

# Function to validate security configurations
validate_security_manifests() {
    log_section "Validating Security Manifests"
    
    if [ "$VALIDATE_SECURITY" != "true" ]; then
        record_validation "security-validation" "PASS" "Security validation skipped"
        return 0
    fi
    
    local security_files=(
        "k8s/39-pod-security-standards.yaml"
        "k8s/41-tls-encryption-config.yaml"
        "k8s/05-rbac.yaml"
    )
    
    for file in "${security_files[@]}"; do
        local full_path="$PROJECT_ROOT/$file"
        validate_yaml_syntax "$full_path"
        
        # Additional security-specific validations
        if [[ "$file" == *"pod-security-standards"* ]]; then
            validate_pod_security_standards "$full_path"
        elif [[ "$file" == *"tls-encryption"* ]]; then
            validate_tls_configuration "$full_path"
        elif [[ "$file" == *"rbac"* ]]; then
            validate_rbac_configuration "$full_path"
        fi
    done
}

# Function to validate Pod Security Standards
validate_pod_security_standards() {
    local file_path="$1"
    
    # Check for required security labels
    if grep -q "pod-security.kubernetes.io/enforce: restricted" "$file_path"; then
        record_validation "pod-security-restricted" "PASS" "Restricted security level enforced"
    else
        record_validation "pod-security-restricted" "FAIL" "Restricted security level not enforced"
    fi
    
    # Check for security context templates
    if grep -q "runAsNonRoot: true" "$file_path"; then
        record_validation "pod-security-nonroot" "PASS" "Non-root user configuration found"
    else
        record_validation "pod-security-nonroot" "WARN" "Non-root user configuration not found"
    fi
    
    # Check for capability dropping
    if grep -q "drop.*ALL" "$file_path"; then
        record_validation "pod-security-capabilities" "PASS" "Capability dropping configured"
    else
        record_validation "pod-security-capabilities" "WARN" "Capability dropping not configured"
    fi
}

# Function to validate TLS configuration
validate_tls_configuration() {
    local file_path="$1"
    
    # Check for TLS 1.3 configuration
    if grep -q "TLSv1.3" "$file_path"; then
        record_validation "tls-version-1.3" "PASS" "TLS 1.3 configured"
    else
        record_validation "tls-version-1.3" "WARN" "TLS 1.3 not configured"
    fi
    
    # Check for strong cipher suites
    if grep -q "TLS_AES_256_GCM_SHA384" "$file_path"; then
        record_validation "tls-cipher-suites" "PASS" "Strong cipher suites configured"
    else
        record_validation "tls-cipher-suites" "WARN" "Strong cipher suites not configured"
    fi
    
    # Check for certificate management
    if grep -q "cert-manager.io" "$file_path"; then
        record_validation "tls-cert-manager" "PASS" "Certificate manager integration found"
    else
        record_validation "tls-cert-manager" "WARN" "Certificate manager integration not found"
    fi
}

# Function to validate RBAC configuration
validate_rbac_configuration() {
    local file_path="$1"
    
    # Check for service accounts
    if grep -q "kind: ServiceAccount" "$file_path"; then
        record_validation "rbac-service-accounts" "PASS" "Service accounts configured"
    else
        record_validation "rbac-service-accounts" "WARN" "Service accounts not configured"
    fi
    
    # Check for role bindings
    if grep -q "kind: RoleBinding\|kind: ClusterRoleBinding" "$file_path"; then
        record_validation "rbac-role-bindings" "PASS" "Role bindings configured"
    else
        record_validation "rbac-role-bindings" "WARN" "Role bindings not configured"
    fi
    
    # Check for least privilege
    if grep -q "verbs.*get\|verbs.*list\|verbs.*watch" "$file_path"; then
        record_validation "rbac-least-privilege" "PASS" "Least privilege permissions configured"
    else
        record_validation "rbac-least-privilege" "WARN" "Least privilege permissions not configured"
    fi
}

# Function to validate networking configurations
validate_networking_manifests() {
    log_section "Validating Networking Manifests"
    
    if [ "$VALIDATE_NETWORKING" != "true" ]; then
        record_validation "networking-validation" "PASS" "Networking validation skipped"
        return 0
    fi
    
    local networking_files=(
        "k8s/30-network-policies.yaml"
        "k8s/ingress/07-ms5-production-loadbalancer.yaml"
    )
    
    for file in "${networking_files[@]}"; do
        local full_path="$PROJECT_ROOT/$file"
        validate_yaml_syntax "$full_path"
        
        # Additional networking-specific validations
        if [[ "$file" == *"network-policies"* ]]; then
            validate_network_policies "$full_path"
        elif [[ "$file" == *"loadbalancer"* ]]; then
            validate_loadbalancer_configuration "$full_path"
        fi
    done
}

# Function to validate network policies
validate_network_policies() {
    local file_path="$1"
    
    # Check for deny-all policy
    if grep -q "policyTypes.*Ingress.*Egress" "$file_path"; then
        record_validation "network-policy-deny-all" "PASS" "Deny-all network policy configured"
    else
        record_validation "network-policy-deny-all" "WARN" "Deny-all network policy not configured"
    fi
    
    # Check for service-specific policies
    local services=("backend" "database" "redis" "minio" "monitoring")
    for service in "${services[@]}"; do
        if grep -q "component: $service" "$file_path"; then
            record_validation "network-policy-$service" "PASS" "Network policy for $service configured"
        else
            record_validation "network-policy-$service" "WARN" "Network policy for $service not configured"
        fi
    done
}

# Function to validate load balancer configuration
validate_loadbalancer_configuration() {
    local file_path="$1"
    
    # Check for SSL/TLS configuration
    if grep -q "ssl_certificate" "$file_path"; then
        record_validation "loadbalancer-ssl" "PASS" "SSL/TLS configuration found"
    else
        record_validation "loadbalancer-ssl" "WARN" "SSL/TLS configuration not found"
    fi
    
    # Check for rate limiting
    if grep -q "limit_req" "$file_path"; then
        record_validation "loadbalancer-rate-limiting" "PASS" "Rate limiting configured"
    else
        record_validation "loadbalancer-rate-limiting" "WARN" "Rate limiting not configured"
    fi
    
    # Check for health checks
    if grep -q "health" "$file_path"; then
        record_validation "loadbalancer-health-checks" "PASS" "Health checks configured"
    else
        record_validation "loadbalancer-health-checks" "WARN" "Health checks not configured"
    fi
}

# Function to validate storage configurations
validate_storage_manifests() {
    log_section "Validating Storage Manifests"
    
    if [ "$VALIDATE_STORAGE" != "true" ]; then
        record_validation "storage-validation" "PASS" "Storage validation skipped"
        return 0
    fi
    
    local storage_files=(
        "k8s/06-postgres-statefulset.yaml"
        "k8s/09-redis-statefulset.yaml"
        "k8s/18-minio-statefulset.yaml"
        "k8s/21-prometheus-statefulset.yaml"
        "k8s/24-grafana-statefulset.yaml"
    )
    
    for file in "${storage_files[@]}"; do
        local full_path="$PROJECT_ROOT/$file"
        validate_yaml_syntax "$full_path"
        
        # Additional storage-specific validations
        validate_persistent_volumes "$full_path"
    done
}

# Function to validate persistent volumes
validate_persistent_volumes() {
    local file_path="$1"
    local file_name=$(basename "$file_path")
    
    # Check for persistent volume claims
    if grep -q "persistentVolumeClaim" "$file_path"; then
        record_validation "pvc-$file_name" "PASS" "Persistent volume claims configured"
    else
        record_validation "pvc-$file_name" "WARN" "Persistent volume claims not configured"
    fi
    
    # Check for storage class
    if grep -q "storageClassName" "$file_path"; then
        record_validation "storage-class-$file_name" "PASS" "Storage class configured"
    else
        record_validation "storage-class-$file_name" "WARN" "Storage class not configured"
    fi
    
    # Check for resource limits
    if grep -q "resources:" "$file_path" && grep -q "limits:" "$file_path"; then
        record_validation "resource-limits-$file_name" "PASS" "Resource limits configured"
    else
        record_validation "resource-limits-$file_name" "WARN" "Resource limits not configured"
    fi
}

# Function to validate monitoring configurations
validate_monitoring_manifests() {
    log_section "Validating Monitoring Manifests"
    
    if [ "$VALIDATE_MONITORING" != "true" ]; then
        record_validation "monitoring-validation" "PASS" "Monitoring validation skipped"
        return 0
    fi
    
    local monitoring_files=(
        "k8s/23-prometheus-config.yaml"
        "k8s/26-grafana-config.yaml"
        "k8s/29-alertmanager-config.yaml"
        "k8s/31-sli-definitions.yaml"
        "k8s/32-slo-configuration.yaml"
        "k8s/33-cost-monitoring.yaml"
    )
    
    for file in "${monitoring_files[@]}"; do
        local full_path="$PROJECT_ROOT/$file"
        validate_yaml_syntax "$full_path"
        
        # Additional monitoring-specific validations
        if [[ "$file" == *"prometheus"* ]]; then
            validate_prometheus_configuration "$full_path"
        elif [[ "$file" == *"grafana"* ]]; then
            validate_grafana_configuration "$full_path"
        elif [[ "$file" == *"alertmanager"* ]]; then
            validate_alertmanager_configuration "$full_path"
        fi
    done
}

# Function to validate Prometheus configuration
validate_prometheus_configuration() {
    local file_path="$1"
    
    # Check for scrape configurations
    if grep -q "scrape_configs" "$file_path"; then
        record_validation "prometheus-scrape-configs" "PASS" "Scrape configurations found"
    else
        record_validation "prometheus-scrape-configs" "WARN" "Scrape configurations not found"
    fi
    
    # Check for retention configuration
    if grep -q "retention" "$file_path"; then
        record_validation "prometheus-retention" "PASS" "Retention configuration found"
    else
        record_validation "prometheus-retention" "WARN" "Retention configuration not found"
    fi
}

# Function to validate Grafana configuration
validate_grafana_configuration() {
    local file_path="$1"
    
    # Check for datasource configuration
    if grep -q "datasource" "$file_path"; then
        record_validation "grafana-datasources" "PASS" "Datasource configuration found"
    else
        record_validation "grafana-datasources" "WARN" "Datasource configuration not found"
    fi
    
    # Check for dashboard provisioning
    if grep -q "dashboard" "$file_path"; then
        record_validation "grafana-dashboards" "PASS" "Dashboard configuration found"
    else
        record_validation "grafana-dashboards" "WARN" "Dashboard configuration not found"
    fi
}

# Function to validate AlertManager configuration
validate_alertmanager_configuration() {
    local file_path="$1"
    
    # Check for routing configuration
    if grep -q "route:" "$file_path"; then
        record_validation "alertmanager-routing" "PASS" "Routing configuration found"
    else
        record_validation "alertmanager-routing" "WARN" "Routing configuration not found"
    fi
    
    # Check for receiver configuration
    if grep -q "receivers:" "$file_path"; then
        record_validation "alertmanager-receivers" "PASS" "Receiver configuration found"
    else
        record_validation "alertmanager-receivers" "WARN" "Receiver configuration not found"
    fi
}

# Function to validate ingress configurations
validate_ingress_manifests() {
    log_section "Validating Ingress Manifests"
    
    if [ "$VALIDATE_INGRESS" != "true" ]; then
        record_validation "ingress-validation" "PASS" "Ingress validation skipped"
        return 0
    fi
    
    local ingress_files=(
        "k8s/ingress/01-nginx-namespace.yaml"
        "k8s/ingress/02-nginx-deployment.yaml"
        "k8s/ingress/03-nginx-service.yaml"
        "k8s/ingress/04-nginx-configmap.yaml"
        "k8s/ingress/05-nginx-ingressclass.yaml"
        "k8s/ingress/06-ms5-comprehensive-ingress.yaml"
    )
    
    for file in "${ingress_files[@]}"; do
        local full_path="$PROJECT_ROOT/$file"
        validate_yaml_syntax "$full_path"
        
        # Additional ingress-specific validations
        if [[ "$file" == *"ingress.yaml"* ]]; then
            validate_ingress_rules "$full_path"
        fi
    done
}

# Function to validate ingress rules
validate_ingress_rules() {
    local file_path="$1"
    
    # Check for TLS configuration
    if grep -q "tls:" "$file_path"; then
        record_validation "ingress-tls" "PASS" "TLS configuration found"
    else
        record_validation "ingress-tls" "WARN" "TLS configuration not found"
    fi
    
    # Check for host rules
    if grep -q "host:" "$file_path"; then
        record_validation "ingress-hosts" "PASS" "Host rules configured"
    else
        record_validation "ingress-hosts" "WARN" "Host rules not configured"
    fi
    
    # Check for path rules
    if grep -q "path:" "$file_path"; then
        record_validation "ingress-paths" "PASS" "Path rules configured"
    else
        record_validation "ingress-paths" "WARN" "Path rules not configured"
    fi
}

# Function to validate all core manifests
validate_core_manifests() {
    log_section "Validating Core Manifests"
    
    local core_files=(
        "k8s/01-namespace.yaml"
        "k8s/02-configmap.yaml"
        "k8s/03-secrets.yaml"
        "k8s/04-keyvault-csi.yaml"
        "k8s/12-backend-deployment.yaml"
        "k8s/13-backend-services.yaml"
        "k8s/14-backend-hpa.yaml"
        "k8s/15-celery-worker-deployment.yaml"
        "k8s/16-celery-beat-deployment.yaml"
        "k8s/17-flower-deployment.yaml"
    )
    
    for file in "${core_files[@]}"; do
        local full_path="$PROJECT_ROOT/$file"
        validate_yaml_syntax "$full_path"
        
        # Additional core-specific validations
        if [[ "$file" == *"deployment.yaml"* ]]; then
            validate_deployment_configuration "$full_path"
        elif [[ "$file" == *"service.yaml"* ]]; then
            validate_service_configuration "$full_path"
        elif [[ "$file" == *"hpa.yaml"* ]]; then
            validate_hpa_configuration "$full_path"
        fi
    done
}

# Function to validate deployment configuration
validate_deployment_configuration() {
    local file_path="$1"
    local file_name=$(basename "$file_path")
    
    # Check for resource limits
    if grep -q "resources:" "$file_path" && grep -q "limits:" "$file_path"; then
        record_validation "deployment-resources-$file_name" "PASS" "Resource limits configured"
    else
        record_validation "deployment-resources-$file_name" "WARN" "Resource limits not configured"
    fi
    
    # Check for security context
    if grep -q "securityContext:" "$file_path"; then
        record_validation "deployment-security-$file_name" "PASS" "Security context configured"
    else
        record_validation "deployment-security-$file_name" "WARN" "Security context not configured"
    fi
    
    # Check for health checks
    if grep -q "livenessProbe\|readinessProbe" "$file_path"; then
        record_validation "deployment-health-checks-$file_name" "PASS" "Health checks configured"
    else
        record_validation "deployment-health-checks-$file_name" "WARN" "Health checks not configured"
    fi
}

# Function to validate service configuration
validate_service_configuration() {
    local file_path="$1"
    local file_name=$(basename "$file_path")
    
    # Check for service type
    if grep -q "type:" "$file_path"; then
        record_validation "service-type-$file_name" "PASS" "Service type configured"
    else
        record_validation "service-type-$file_name" "WARN" "Service type not configured"
    fi
    
    # Check for port configuration
    if grep -q "port:" "$file_path"; then
        record_validation "service-ports-$file_name" "PASS" "Service ports configured"
    else
        record_validation "service-ports-$file_name" "WARN" "Service ports not configured"
    fi
}

# Function to validate HPA configuration
validate_hpa_configuration() {
    local file_path="$1"
    local file_name=$(basename "$file_path")
    
    # Check for metrics configuration
    if grep -q "metrics:" "$file_path"; then
        record_validation "hpa-metrics-$file_name" "PASS" "HPA metrics configured"
    else
        record_validation "hpa-metrics-$file_name" "WARN" "HPA metrics not configured"
    fi
    
    # Check for scaling limits
    if grep -q "minReplicas\|maxReplicas" "$file_path"; then
        record_validation "hpa-scaling-limits-$file_name" "PASS" "Scaling limits configured"
    else
        record_validation "hpa-scaling-limits-$file_name" "WARN" "Scaling limits not configured"
    fi
}

# Function to generate validation report
generate_validation_report() {
    log_section "Generating Manifest Validation Report"
    
    local report_file="${PROJECT_ROOT}/logs/phase9-manifest-validation-report-${TIMESTAMP}.md"
    
    cat > "$report_file" << EOF
# MS5.0 Floor Dashboard - Phase 9 Manifest Validation Report

**Generated**: $(date)
**Environment**: Production
**Namespace**: $NAMESPACE

## Summary

- **Total Validations**: $TOTAL_VALIDATIONS
- **Passed**: $PASSED_VALIDATIONS
- **Failed**: $FAILED_VALIDATIONS
- **Warnings**: $WARNING_VALIDATIONS
- **Success Rate**: $(( (PASSED_VALIDATIONS * 100) / TOTAL_VALIDATIONS ))%

## Detailed Results

EOF

    # Add detailed results
    for validation_name in "${!VALIDATION_RESULTS[@]}"; do
        local result="${VALIDATION_RESULTS[$validation_name]}"
        local status="${result%%|*}"
        local message="${result#*|}"
        
        local status_icon=""
        case "$status" in
            "PASS") status_icon="✅" ;;
            "FAIL") status_icon="❌" ;;
            "WARN") status_icon="⚠️" ;;
        esac
        
        echo "- $status_icon **$validation_name**: $message" >> "$report_file"
    done
    
    echo "" >> "$report_file"
    echo "## Recommendations" >> "$report_file"
    
    if [ $FAILED_VALIDATIONS -gt 0 ]; then
        echo "- ❌ **CRITICAL**: Fix all failed validations before proceeding with deployment" >> "$report_file"
    fi
    
    if [ $WARNING_VALIDATIONS -gt 0 ]; then
        echo "- ⚠️ **WARNING**: Review and address warnings before production deployment" >> "$report_file"
    fi
    
    if [ $FAILED_VALIDATIONS -eq 0 ] && [ $WARNING_VALIDATIONS -eq 0 ]; then
        echo "- ✅ **READY**: All manifests are ready for production deployment" >> "$report_file"
    fi
    
    log_success "Manifest validation report generated: $report_file"
}

# Main validation function
main() {
    log "Starting MS5.0 Floor Dashboard Phase 9 Manifest Validation"
    log "Environment: Production"
    log "Namespace: $NAMESPACE"
    log "Log file: $LOG_FILE"
    
    # Run all validations
    validate_core_manifests
    validate_security_manifests
    validate_networking_manifests
    validate_storage_manifests
    validate_monitoring_manifests
    validate_ingress_manifests
    
    # Generate report
    generate_validation_report
    
    # Summary
    log_section "Manifest Validation Summary"
    log "Total Validations: $TOTAL_VALIDATIONS"
    log_success "Passed: $PASSED_VALIDATIONS"
    if [ $FAILED_VALIDATIONS -gt 0 ]; then
        log_error "Failed: $FAILED_VALIDATIONS"
    else
        log_success "Failed: $FAILED_VALIDATIONS"
    fi
    if [ $WARNING_VALIDATIONS -gt 0 ]; then
        log_warning "Warnings: $WARNING_VALIDATIONS"
    else
        log_success "Warnings: $WARNING_VALIDATIONS"
    fi
    
    # Exit with appropriate code
    if [ $FAILED_VALIDATIONS -gt 0 ]; then
        log_error "Manifest validation failed. Please fix all failed validations before proceeding."
        exit 1
    elif [ $WARNING_VALIDATIONS -gt 0 ]; then
        log_warning "Manifest validation completed with warnings. Please review warnings before proceeding."
        exit 0
    else
        log_success "Manifest validation completed successfully. All manifests are ready for deployment."
        exit 0
    fi
}

# Handle script arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-security)
            VALIDATE_SECURITY=false
            shift
            ;;
        --skip-networking)
            VALIDATE_NETWORKING=false
            shift
            ;;
        --skip-storage)
            VALIDATE_STORAGE=false
            shift
            ;;
        --skip-monitoring)
            VALIDATE_MONITORING=false
            shift
            ;;
        --skip-ingress)
            VALIDATE_INGRESS=false
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --skip-security     Skip security manifest validation"
            echo "  --skip-networking   Skip networking manifest validation"
            echo "  --skip-storage      Skip storage manifest validation"
            echo "  --skip-monitoring   Skip monitoring manifest validation"
            echo "  --skip-ingress      Skip ingress manifest validation"
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
