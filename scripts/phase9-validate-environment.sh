#!/bin/bash

# MS5.0 Floor Dashboard - Phase 9 Environment Validation Script
# This script validates all production environment configurations before deployment
# Designed with starship-grade precision and reliability

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NAMESPACE="ms5-production"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${PROJECT_ROOT}/logs/phase9-validation-${TIMESTAMP}.log"

# Environment variables
ENVIRONMENT=${ENVIRONMENT:-production}
VALIDATE_DATABASE=${VALIDATE_DATABASE:-true}
VALIDATE_SECRETS=${VALIDATE_SECRETS:-true}
VALIDATE_NETWORK=${VALIDATE_NETWORK:-true}
VALIDATE_STORAGE=${VALIDATE_STORAGE:-true}
VALIDATE_MONITORING=${VALIDATE_MONITORING:-true}

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
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Validation result tracking
declare -A VALIDATION_RESULTS

# Function to record validation result
record_result() {
    local check_name="$1"
    local status="$2"
    local message="$3"
    
    VALIDATION_RESULTS["$check_name"]="$status|$message"
    
    case "$status" in
        "PASS")
            ((PASSED_CHECKS++))
            log_success "$check_name: $message"
            ;;
        "FAIL")
            ((FAILED_CHECKS++))
            log_error "$check_name: $message"
            ;;
        "WARN")
            ((WARNING_CHECKS++))
            log_warning "$check_name: $message"
            ;;
    esac
    
    ((TOTAL_CHECKS++))
}

# Function to validate Kubernetes cluster access
validate_kubectl_access() {
    log_section "Validating Kubernetes Cluster Access"
    
    # Check kubectl installation
    if command -v kubectl &> /dev/null; then
        record_result "kubectl-installed" "PASS" "kubectl is installed"
    else
        record_result "kubectl-installed" "FAIL" "kubectl is not installed"
        return 1
    fi
    
    # Check kubectl version
    local kubectl_version=$(kubectl version --client --short 2>/dev/null | cut -d' ' -f3)
    record_result "kubectl-version" "PASS" "kubectl version: $kubectl_version"
    
    # Check cluster connectivity
    if kubectl cluster-info &> /dev/null; then
        local cluster_info=$(kubectl cluster-info | head -1)
        record_result "cluster-connectivity" "PASS" "Connected to cluster: $cluster_info"
    else
        record_result "cluster-connectivity" "FAIL" "Cannot connect to Kubernetes cluster"
        return 1
    fi
    
    # Check current context
    local current_context=$(kubectl config current-context 2>/dev/null || echo "none")
    record_result "kubectl-context" "PASS" "Current context: $current_context"
    
    # Validate namespace
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        record_result "namespace-exists" "PASS" "Namespace $NAMESPACE exists"
    else
        record_result "namespace-exists" "WARN" "Namespace $NAMESPACE does not exist (will be created)"
    fi
}

# Function to validate Azure resources
validate_azure_resources() {
    log_section "Validating Azure Resources"
    
    # Check Azure CLI installation
    if command -v az &> /dev/null; then
        record_result "azure-cli-installed" "PASS" "Azure CLI is installed"
    else
        record_result "azure-cli-installed" "WARN" "Azure CLI is not installed (optional for validation)"
        return 0
    fi
    
    # Check Azure authentication
    if az account show &> /dev/null; then
        local subscription_id=$(az account show --query id -o tsv 2>/dev/null)
        local subscription_name=$(az account show --query name -o tsv 2>/dev/null)
        record_result "azure-auth" "PASS" "Authenticated to Azure subscription: $subscription_name ($subscription_id)"
    else
        record_result "azure-auth" "WARN" "Not authenticated to Azure CLI"
    fi
    
    # Check AKS cluster access
    if az aks list &> /dev/null; then
        local aks_clusters=$(az aks list --query "[].{name:name,resourceGroup:resourceGroup,provisioningState:provisioningState}" -o table 2>/dev/null)
        record_result "aks-clusters" "PASS" "AKS clusters accessible"
    else
        record_result "aks-clusters" "WARN" "Cannot list AKS clusters"
    fi
}

# Function to validate configuration files
validate_config_files() {
    log_section "Validating Configuration Files"
    
    local config_files=(
        "k8s/01-namespace.yaml"
        "k8s/02-configmap.yaml"
        "k8s/03-secrets.yaml"
        "k8s/04-keyvault-csi.yaml"
        "k8s/05-rbac.yaml"
        "k8s/06-postgres-statefulset.yaml"
        "k8s/07-postgres-services.yaml"
        "k8s/08-postgres-config.yaml"
        "k8s/09-redis-statefulset.yaml"
        "k8s/10-redis-services.yaml"
        "k8s/11-redis-config.yaml"
        "k8s/12-backend-deployment.yaml"
        "k8s/13-backend-services.yaml"
        "k8s/14-backend-hpa.yaml"
        "k8s/15-celery-worker-deployment.yaml"
        "k8s/16-celery-beat-deployment.yaml"
        "k8s/17-flower-deployment.yaml"
        "k8s/18-minio-statefulset.yaml"
        "k8s/19-minio-services.yaml"
        "k8s/20-minio-config.yaml"
        "k8s/21-prometheus-statefulset.yaml"
        "k8s/22-prometheus-services.yaml"
        "k8s/23-prometheus-config.yaml"
        "k8s/24-grafana-statefulset.yaml"
        "k8s/25-grafana-services.yaml"
        "k8s/26-grafana-config.yaml"
        "k8s/27-alertmanager-deployment.yaml"
        "k8s/28-alertmanager-services.yaml"
        "k8s/29-alertmanager-config.yaml"
        "k8s/30-network-policies.yaml"
        "k8s/31-sli-definitions.yaml"
        "k8s/32-slo-configuration.yaml"
        "k8s/33-cost-monitoring.yaml"
        "k8s/39-pod-security-standards.yaml"
        "k8s/41-tls-encryption-config.yaml"
    )
    
    for config_file in "${config_files[@]}"; do
        local full_path="$PROJECT_ROOT/$config_file"
        if [ -f "$full_path" ]; then
            # Validate YAML syntax
            if kubectl apply --dry-run=client -f "$full_path" &> /dev/null; then
                record_result "config-$config_file" "PASS" "Valid YAML syntax"
            else
                record_result "config-$config_file" "FAIL" "Invalid YAML syntax or Kubernetes manifest"
            fi
        else
            record_result "config-$config_file" "FAIL" "File not found"
        fi
    done
}

# Function to validate secrets
validate_secrets() {
    log_section "Validating Secrets Configuration"
    
    if [ "$VALIDATE_SECRETS" != "true" ]; then
        record_result "secrets-validation" "PASS" "Secrets validation skipped"
        return 0
    fi
    
    local secrets_file="$PROJECT_ROOT/k8s/03-secrets.yaml"
    
    if [ -f "$secrets_file" ]; then
        # Check if secrets contain placeholder values
        if grep -q "my-host-secret-key-change-in-production" "$secrets_file"; then
            record_result "secrets-placeholders" "WARN" "Secrets contain placeholder values - update before production"
        else
            record_result "secrets-placeholders" "PASS" "Secrets do not contain obvious placeholder values"
        fi
        
        # Validate base64 encoding
        if kubectl apply --dry-run=client -f "$secrets_file" &> /dev/null; then
            record_result "secrets-yaml" "PASS" "Secrets YAML is valid"
        else
            record_result "secrets-yaml" "FAIL" "Secrets YAML is invalid"
        fi
    else
        record_result "secrets-file" "FAIL" "Secrets file not found"
    fi
}

# Function to validate database configuration
validate_database_config() {
    log_section "Validating Database Configuration"
    
    if [ "$VALIDATE_DATABASE" != "true" ]; then
        record_result "database-validation" "PASS" "Database validation skipped"
        return 0
    fi
    
    # Check database migration files
    local migration_files=(
        "001_init_telemetry.sql"
        "002_plc_equipment_management.sql"
        "003_production_management.sql"
        "004_advanced_production_features.sql"
        "005_andon_escalation_system.sql"
        "006_report_system.sql"
        "007_plc_integration_phase1.sql"
        "008_fix_critical_schema_issues.sql"
        "009_database_optimization.sql"
    )
    
    for migration_file in "${migration_files[@]}"; do
        local full_path="$PROJECT_ROOT/$migration_file"
        if [ -f "$full_path" ]; then
            # Basic SQL syntax check
            if head -5 "$full_path" | grep -qi "CREATE\|ALTER\|INSERT\|UPDATE\|DELETE"; then
                record_result "migration-$migration_file" "PASS" "Contains SQL statements"
            else
                record_result "migration-$migration_file" "WARN" "Does not contain obvious SQL statements"
            fi
        else
            record_result "migration-$migration_file" "FAIL" "Migration file not found"
        fi
    done
    
    # Check database deployment script
    local deploy_script="$PROJECT_ROOT/scripts/deploy_migrations.sh"
    if [ -f "$deploy_script" ] && [ -x "$deploy_script" ]; then
        record_result "migration-script" "PASS" "Migration deployment script exists and is executable"
    else
        record_result "migration-script" "WARN" "Migration deployment script not found or not executable"
    fi
}

# Function to validate network configuration
validate_network_config() {
    log_section "Validating Network Configuration"
    
    if [ "$VALIDATE_NETWORK" != "true" ]; then
        record_result "network-validation" "PASS" "Network validation skipped"
        return 0
    fi
    
    # Check network policies
    local network_policy_file="$PROJECT_ROOT/k8s/30-network-policies.yaml"
    if [ -f "$network_policy_file" ]; then
        if kubectl apply --dry-run=client -f "$network_policy_file" &> /dev/null; then
            record_result "network-policies" "PASS" "Network policies YAML is valid"
        else
            record_result "network-policies" "FAIL" "Network policies YAML is invalid"
        fi
    else
        record_result "network-policies" "FAIL" "Network policies file not found"
    fi
    
    # Check TLS configuration
    local tls_config_file="$PROJECT_ROOT/k8s/41-tls-encryption-config.yaml"
    if [ -f "$tls_config_file" ]; then
        if kubectl apply --dry-run=client -f "$tls_config_file" &> /dev/null; then
            record_result "tls-config" "PASS" "TLS configuration YAML is valid"
        else
            record_result "tls-config" "FAIL" "TLS configuration YAML is invalid"
        fi
    else
        record_result "tls-config" "FAIL" "TLS configuration file not found"
    fi
}

# Function to validate storage configuration
validate_storage_config() {
    log_section "Validating Storage Configuration"
    
    if [ "$VALIDATE_STORAGE" != "true" ]; then
        record_result "storage-validation" "PASS" "Storage validation skipped"
        return 0
    fi
    
    # Check storage class configuration
    if kubectl get storageclass &> /dev/null; then
        local storage_classes=$(kubectl get storageclass -o name | wc -l)
        record_result "storage-classes" "PASS" "Found $storage_classes storage classes"
    else
        record_result "storage-classes" "WARN" "Cannot retrieve storage classes"
    fi
    
    # Check MinIO configuration
    local minio_config_file="$PROJECT_ROOT/k8s/20-minio-config.yaml"
    if [ -f "$minio_config_file" ]; then
        if kubectl apply --dry-run=client -f "$minio_config_file" &> /dev/null; then
            record_result "minio-config" "PASS" "MinIO configuration YAML is valid"
        else
            record_result "minio-config" "FAIL" "MinIO configuration YAML is invalid"
        fi
    else
        record_result "minio-config" "FAIL" "MinIO configuration file not found"
    fi
}

# Function to validate monitoring configuration
validate_monitoring_config() {
    log_section "Validating Monitoring Configuration"
    
    if [ "$VALIDATE_MONITORING" != "true" ]; then
        record_result "monitoring-validation" "PASS" "Monitoring validation skipped"
        return 0
    fi
    
    # Check Prometheus configuration
    local prometheus_config_file="$PROJECT_ROOT/k8s/23-prometheus-config.yaml"
    if [ -f "$prometheus_config_file" ]; then
        if kubectl apply --dry-run=client -f "$prometheus_config_file" &> /dev/null; then
            record_result "prometheus-config" "PASS" "Prometheus configuration YAML is valid"
        else
            record_result "prometheus-config" "FAIL" "Prometheus configuration YAML is invalid"
        fi
    else
        record_result "prometheus-config" "FAIL" "Prometheus configuration file not found"
    fi
    
    # Check Grafana configuration
    local grafana_config_file="$PROJECT_ROOT/k8s/26-grafana-config.yaml"
    if [ -f "$grafana_config_file" ]; then
        if kubectl apply --dry-run=client -f "$grafana_config_file" &> /dev/null; then
            record_result "grafana-config" "PASS" "Grafana configuration YAML is valid"
        else
            record_result "grafana-config" "FAIL" "Grafana configuration YAML is invalid"
        fi
    else
        record_result "grafana-config" "FAIL" "Grafana configuration file not found"
    fi
    
    # Check AlertManager configuration
    local alertmanager_config_file="$PROJECT_ROOT/k8s/29-alertmanager-config.yaml"
    if [ -f "$alertmanager_config_file" ]; then
        if kubectl apply --dry-run=client -f "$alertmanager_config_file" &> /dev/null; then
            record_result "alertmanager-config" "PASS" "AlertManager configuration YAML is valid"
        else
            record_result "alertmanager-config" "FAIL" "AlertManager configuration YAML is invalid"
        fi
    else
        record_result "alertmanager-config" "FAIL" "AlertManager configuration file not found"
    fi
    
    # Check alert rules
    local alert_rules_file="$PROJECT_ROOT/backend/alert_rules.yml"
    if [ -f "$alert_rules_file" ]; then
        # Basic YAML syntax check
        if python3 -c "import yaml; yaml.safe_load(open('$alert_rules_file'))" &> /dev/null; then
            record_result "alert-rules" "PASS" "Alert rules YAML is valid"
        else
            record_result "alert-rules" "FAIL" "Alert rules YAML is invalid"
        fi
    else
        record_result "alert-rules" "FAIL" "Alert rules file not found"
    fi
}

# Function to validate security configuration
validate_security_config() {
    log_section "Validating Security Configuration"
    
    # Check Pod Security Standards
    local pod_security_file="$PROJECT_ROOT/k8s/39-pod-security-standards.yaml"
    if [ -f "$pod_security_file" ]; then
        if kubectl apply --dry-run=client -f "$pod_security_file" &> /dev/null; then
            record_result "pod-security-standards" "PASS" "Pod Security Standards YAML is valid"
        else
            record_result "pod-security-standards" "FAIL" "Pod Security Standards YAML is invalid"
        fi
    else
        record_result "pod-security-standards" "FAIL" "Pod Security Standards file not found"
    fi
    
    # Check RBAC configuration
    local rbac_file="$PROJECT_ROOT/k8s/05-rbac.yaml"
    if [ -f "$rbac_file" ]; then
        if kubectl apply --dry-run=client -f "$rbac_file" &> /dev/null; then
            record_result "rbac-config" "PASS" "RBAC configuration YAML is valid"
        else
            record_result "rbac-config" "FAIL" "RBAC configuration YAML is invalid"
        fi
    else
        record_result "rbac-config" "FAIL" "RBAC configuration file not found"
    fi
}

# Function to validate deployment scripts
validate_deployment_scripts() {
    log_section "Validating Deployment Scripts"
    
    local deployment_scripts=(
        "scripts/phase9-validate-environment.sh"
        "scripts/deploy_migrations.sh"
        "k8s/deploy-phase2.sh"
    )
    
    for script in "${deployment_scripts[@]}"; do
        local full_path="$PROJECT_ROOT/$script"
        if [ -f "$full_path" ]; then
            if [ -x "$full_path" ]; then
                record_result "script-$script" "PASS" "Script exists and is executable"
            else
                record_result "script-$script" "WARN" "Script exists but is not executable"
            fi
        else
            record_result "script-$script" "FAIL" "Script not found"
        fi
    done
}

# Function to generate validation report
generate_report() {
    log_section "Generating Validation Report"
    
    local report_file="${PROJECT_ROOT}/logs/phase9-validation-report-${TIMESTAMP}.md"
    
    cat > "$report_file" << EOF
# MS5.0 Floor Dashboard - Phase 9 Environment Validation Report

**Generated**: $(date)
**Environment**: $ENVIRONMENT
**Namespace**: $NAMESPACE

## Summary

- **Total Checks**: $TOTAL_CHECKS
- **Passed**: $PASSED_CHECKS
- **Failed**: $FAILED_CHECKS
- **Warnings**: $WARNING_CHECKS
- **Success Rate**: $(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))%

## Detailed Results

EOF

    # Add detailed results
    for check_name in "${!VALIDATION_RESULTS[@]}"; do
        local result="${VALIDATION_RESULTS[$check_name]}"
        local status="${result%%|*}"
        local message="${result#*|}"
        
        local status_icon=""
        case "$status" in
            "PASS") status_icon="✅" ;;
            "FAIL") status_icon="❌" ;;
            "WARN") status_icon="⚠️" ;;
        esac
        
        echo "- $status_icon **$check_name**: $message" >> "$report_file"
    done
    
    echo "" >> "$report_file"
    echo "## Recommendations" >> "$report_file"
    
    if [ $FAILED_CHECKS -gt 0 ]; then
        echo "- ❌ **CRITICAL**: Fix all failed checks before proceeding with deployment" >> "$report_file"
    fi
    
    if [ $WARNING_CHECKS -gt 0 ]; then
        echo "- ⚠️ **WARNING**: Review and address warnings before production deployment" >> "$report_file"
    fi
    
    if [ $FAILED_CHECKS -eq 0 ] && [ $WARNING_CHECKS -eq 0 ]; then
        echo "- ✅ **READY**: Environment is ready for production deployment" >> "$report_file"
    fi
    
    log_success "Validation report generated: $report_file"
}

# Main validation function
main() {
    log "Starting MS5.0 Floor Dashboard Phase 9 Environment Validation"
    log "Environment: $ENVIRONMENT"
    log "Namespace: $NAMESPACE"
    log "Log file: $LOG_FILE"
    
    # Run all validation checks
    validate_kubectl_access
    validate_azure_resources
    validate_config_files
    validate_secrets
    validate_database_config
    validate_network_config
    validate_storage_config
    validate_monitoring_config
    validate_security_config
    validate_deployment_scripts
    
    # Generate report
    generate_report
    
    # Summary
    log_section "Validation Summary"
    log "Total Checks: $TOTAL_CHECKS"
    log_success "Passed: $PASSED_CHECKS"
    if [ $FAILED_CHECKS -gt 0 ]; then
        log_error "Failed: $FAILED_CHECKS"
    else
        log_success "Failed: $FAILED_CHECKS"
    fi
    if [ $WARNING_CHECKS -gt 0 ]; then
        log_warning "Warnings: $WARNING_CHECKS"
    else
        log_success "Warnings: $WARNING_CHECKS"
    fi
    
    # Exit with appropriate code
    if [ $FAILED_CHECKS -gt 0 ]; then
        log_error "Validation failed. Please fix all failed checks before proceeding."
        exit 1
    elif [ $WARNING_CHECKS -gt 0 ]; then
        log_warning "Validation completed with warnings. Please review warnings before proceeding."
        exit 0
    else
        log_success "Validation completed successfully. Environment is ready for deployment."
        exit 0
    fi
}

# Handle script arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-database)
            VALIDATE_DATABASE=false
            shift
            ;;
        --skip-secrets)
            VALIDATE_SECRETS=false
            shift
            ;;
        --skip-network)
            VALIDATE_NETWORK=false
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
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --skip-database     Skip database validation"
            echo "  --skip-secrets      Skip secrets validation"
            echo "  --skip-network      Skip network validation"
            echo "  --skip-storage      Skip storage validation"
            echo "  --skip-monitoring   Skip monitoring validation"
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
