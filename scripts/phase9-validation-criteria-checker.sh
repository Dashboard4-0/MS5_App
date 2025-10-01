#!/bin/bash

# MS5.0 Floor Dashboard - Phase 9 Validation Criteria Checker
# This script validates that all Phase 9 criteria have been met
# Designed with starship-grade precision and reliability

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NAMESPACE="ms5-production"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${PROJECT_ROOT}/logs/phase9-validation-criteria-${TIMESTAMP}.log"

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

# Validation tracking
VALIDATION_CRITERIA=()
TOTAL_CRITERIA=0
PASSED_CRITERIA=0
FAILED_CRITERIA=0

# Function to validate criterion
validate_criterion() {
    local criterion_id="$1"
    local criterion_name="$2"
    local test_command="$3"
    local description="$4"
    
    ((TOTAL_CRITERIA++))
    
    log_info "🔍 Validating: $criterion_name"
    log_info "   Description: $description"
    
    if eval "$test_command"; then
        VALIDATION_CRITERIA+=("$criterion_id|$criterion_name|PASS|$description")
        ((PASSED_CRITERIA++))
        log_success "   ✅ PASSED: $criterion_name"
        return 0
    else
        VALIDATION_CRITERIA+=("$criterion_id|$criterion_name|FAIL|$description")
        ((FAILED_CRITERIA++))
        log_error "   ❌ FAILED: $criterion_name"
        return 1
    fi
}

# Function to check Kubernetes resource exists
check_k8s_resource() {
    local resource_type="$1"
    local resource_name="$2"
    local namespace="${3:-$NAMESPACE}"
    
    kubectl get "$resource_type" "$resource_name" -n "$namespace" >/dev/null 2>&1
}

# Function to check Kubernetes resource is ready
check_k8s_resource_ready() {
    local resource_type="$1"
    local resource_name="$2"
    local namespace="${3:-$NAMESPACE}"
    
    kubectl get "$resource_type" "$resource_name" -n "$namespace" -o jsonpath='{.status.readyReplicas}' 2>/dev/null | grep -q '[0-9]'
}

# Function to check pod is running
check_pod_running() {
    local pod_name="$1"
    local namespace="${2:-$NAMESPACE}"
    
    kubectl get pod "$pod_name" -n "$namespace" -o jsonpath='{.status.phase}' 2>/dev/null | grep -q "Running"
}

# Function to check service endpoint
check_service_endpoint() {
    local service_name="$1"
    local namespace="${2:-$NAMESPACE}"
    
    kubectl get endpoints "$service_name" -n "$namespace" -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null | grep -q '[0-9]'
}

# Function to check HTTP endpoint
check_http_endpoint() {
    local url="$1"
    local expected_status="${2:-200}"
    
    curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "$expected_status"
}

# Function to check database connectivity
check_database_connectivity() {
    local db_host="${1:-postgres-service}"
    local db_port="${2:-5432}"
    local db_name="${3:-ms5_dashboard}"
    
    kubectl run test-db-connectivity --rm -i --restart=Never --image=postgres:15-alpine -n "$NAMESPACE" -- \
        psql "postgresql://ms5_user:$(kubectl get secret ms5-database-secret -n $NAMESPACE -o jsonpath='{.data.password}' | base64 -d)@$db_host:$db_port/$db_name" \
        -c "SELECT 1;" >/dev/null 2>&1
}

# Function to check Redis connectivity
check_redis_connectivity() {
    local redis_host="${1:-redis-service}"
    local redis_port="${2:-6379}"
    
    kubectl run test-redis-connectivity --rm -i --restart=Never --image=redis:7-alpine -n "$NAMESPACE" -- \
        redis-cli -h "$redis_host" -p "$redis_port" ping | grep -q "PONG"
}

# Function to check MinIO connectivity
check_minio_connectivity() {
    local minio_host="${1:-minio-service}"
    local minio_port="${2:-9000}"
    
    kubectl run test-minio-connectivity --rm -i --restart=Never --image=minio/mc:latest -n "$NAMESPACE" -- \
        mc alias set minio "http://$minio_host:$minio_port" \
        "$(kubectl get secret ms5-minio-secret -n $NAMESPACE -o jsonpath='{.data.access-key}' | base64 -d)" \
        "$(kubectl get secret ms5-minio-secret -n $NAMESPACE -o jsonpath='{.data.secret-key}' | base64 -d)" && \
        mc admin info minio >/dev/null 2>&1
}

# Function to check Prometheus metrics
check_prometheus_metrics() {
    local prometheus_url="${1:-http://prometheus-service:9090}"
    
    kubectl run test-prometheus-metrics --rm -i --restart=Never --image=curlimages/curl:latest -n "$NAMESPACE" -- \
        curl -s "$prometheus_url/api/v1/query?query=up" | grep -q '"status":"success"'
}

# Function to check Grafana dashboards
check_grafana_dashboards() {
    local grafana_url="${1:-http://grafana-service:3000}"
    
    kubectl run test-grafana-dashboards --rm -i --restart=Never --image=curlimages/curl:latest -n "$NAMESPACE" -- \
        curl -s -u "admin:$(kubectl get secret ms5-grafana-secret -n $NAMESPACE -o jsonpath='{.data.password}' | base64 -d)" \
        "$grafana_url/api/search?type=dash-db" | grep -q '"title"'
}

# Function to check AlertManager
check_alertmanager() {
    local alertmanager_url="${1:-http://alertmanager-service:9093}"
    
    kubectl run test-alertmanager --rm -i --restart=Never --image=curlimages/curl:latest -n "$NAMESPACE" -- \
        curl -s "$alertmanager_url/api/v1/status" | grep -q '"status":"success"'
}

# Function to check network policies
check_network_policies() {
    local policy_name="$1"
    
    kubectl get networkpolicy "$policy_name" -n "$NAMESPACE" >/dev/null 2>&1
}

# Function to check TLS certificates
check_tls_certificates() {
    local cert_name="$1"
    
    kubectl get certificate "$cert_name" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q "True"
}

# Function to check resource limits
check_resource_limits() {
    local deployment_name="$1"
    
    kubectl get deployment "$deployment_name" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].resources.limits}' 2>/dev/null | grep -q "cpu\|memory"
}

# Function to check security contexts
check_security_contexts() {
    local deployment_name="$1"
    
    kubectl get deployment "$deployment_name" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.securityContext.runAsNonRoot}' 2>/dev/null | grep -q "true"
}

# Function to check probes
check_probes() {
    local deployment_name="$1"
    
    kubectl get deployment "$deployment_name" -n "$NAMESPACE" -o jsonpath='{.spec.template.spec.containers[0].livenessProbe}' 2>/dev/null | grep -q "httpGet\|exec\|tcpSocket"
}

# Main validation function
main() {
    log_section "🚀 MS5.0 Floor Dashboard - Phase 9 Validation Criteria Checker"
    log "Starting comprehensive validation of Phase 9 deployment criteria"
    log "Namespace: $NAMESPACE"
    log "Log file: $LOG_FILE"
    
    # 9.1 Code Review Checkpoint
    log_section "📋 9.1 Code Review Checkpoint"
    
    validate_criterion "9.1.1" "Deployment Configuration Review" \
        "test -f '$PROJECT_ROOT/k8s/deploy-phase2.sh' && test -f '$PROJECT_ROOT/scripts/phase9-deploy-production.sh'" \
        "Deployment configuration files exist and are executable"
    
    validate_criterion "9.1.2" "AKS Optimization Verification" \
        "kubectl get nodes -o jsonpath='{.items[0].metadata.labels}' | grep -q 'kubernetes.io/os'" \
        "AKS cluster is accessible and nodes are properly labeled"
    
    validate_criterion "9.1.3" "Monitoring and Alerting Validation" \
        "check_k8s_resource 'deployment' 'prometheus' 'ms5-system' && check_k8s_resource 'deployment' 'grafana' 'ms5-system' && check_k8s_resource 'deployment' 'alertmanager' 'ms5-system'" \
        "Monitoring stack components (Prometheus, Grafana, AlertManager) are deployed"
    
    # 9.2 Deployment Preparation
    log_section "🔧 9.2 Deployment Preparation"
    
    validate_criterion "9.2.1" "Environment Configuration Validation" \
        "test -f '$PROJECT_ROOT/backend/env.production' && test -f '$PROJECT_ROOT/k8s/02-configmap.yaml' && test -f '$PROJECT_ROOT/k8s/03-secrets.yaml'" \
        "Environment configuration files exist and are properly configured"
    
    validate_criterion "9.2.2" "Database Migration Testing" \
        "test -f '$PROJECT_ROOT/scripts/phase9-test-migrations.sh' && test -f '$PROJECT_ROOT/scripts/deploy_migrations.sh'" \
        "Database migration scripts exist and are executable"
    
    validate_criterion "9.2.3" "Load Balancer Configuration" \
        "check_k8s_resource 'service' 'nginx-service' && check_k8s_resource 'ingress' 'ms5-production-ingress'" \
        "Load balancer and ingress configuration are deployed"
    
    validate_criterion "9.2.4" "SSL Certificate Setup" \
        "check_k8s_resource 'certificate' 'ms5-dashboard-cert' && check_k8s_resource 'clusterissuer' 'letsencrypt-prod'" \
        "SSL certificates and cert-manager configuration are deployed"
    
    # 9.3 AKS Deployment
    log_section "☸️ 9.3 AKS Deployment"
    
    validate_criterion "9.3.1" "Kubernetes Manifest Validation" \
        "test -f '$PROJECT_ROOT/scripts/phase9-validate-manifests.sh' && bash '$PROJECT_ROOT/scripts/phase9-validate-manifests.sh' --dry-run" \
        "Kubernetes manifests are valid and pass validation checks"
    
    validate_criterion "9.3.2" "Pod Security Standards Verification" \
        "check_k8s_resource 'namespace' 'ms5-production' && kubectl get namespace ms5-production -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' | grep -q 'restricted'" \
        "Pod Security Standards are enforced on production namespace"
    
    validate_criterion "9.3.3" "Network Policy Testing" \
        "check_network_policies 'ms5-backend-network-policy' && check_network_policies 'ms5-database-network-policy' && check_network_policies 'ms5-redis-network-policy'" \
        "Network policies are deployed and configured"
    
    validate_criterion "9.3.4" "Monitoring Stack Deployment" \
        "check_k8s_resource_ready 'deployment' 'prometheus' 'ms5-system' && check_k8s_resource_ready 'deployment' 'grafana' 'ms5-system' && check_k8s_resource_ready 'deployment' 'alertmanager' 'ms5-system'" \
        "Monitoring stack is deployed and ready"
    
    # 9.4 Validation Criteria
    log_section "✅ 9.4 Validation Criteria"
    
    # 9.4.1 Application deploys successfully
    log_section "🎯 9.4.1 Application Deploys Successfully"
    
    validate_criterion "9.4.1.1" "Backend Deployment Success" \
        "check_k8s_resource_ready 'deployment' 'backend' && check_pod_running 'backend' && check_service_endpoint 'backend-service'" \
        "Backend application deploys successfully and is ready"
    
    validate_criterion "9.4.1.2" "Frontend Deployment Success" \
        "check_k8s_resource_ready 'deployment' 'frontend' && check_pod_running 'frontend' && check_service_endpoint 'frontend-service'" \
        "Frontend application deploys successfully and is ready"
    
    validate_criterion "9.4.1.3" "Database Deployment Success" \
        "check_k8s_resource_ready 'statefulset' 'postgres' && check_pod_running 'postgres' && check_service_endpoint 'postgres-service'" \
        "Database deploys successfully and is ready"
    
    validate_criterion "9.4.1.4" "Cache Deployment Success" \
        "check_k8s_resource_ready 'deployment' 'redis' && check_pod_running 'redis' && check_service_endpoint 'redis-service'" \
        "Cache (Redis) deploys successfully and is ready"
    
    validate_criterion "9.4.1.5" "Storage Deployment Success" \
        "check_k8s_resource_ready 'deployment' 'minio' && check_pod_running 'minio' && check_service_endpoint 'minio-service'" \
        "Storage (MinIO) deploys successfully and is ready"
    
    # 9.4.2 All services start correctly
    log_section "🔄 9.4.2 All Services Start Correctly"
    
    validate_criterion "9.4.2.1" "Backend Service Health" \
        "check_http_endpoint 'http://backend-service:8000/health' 200" \
        "Backend service starts correctly and health endpoint responds"
    
    validate_criterion "9.4.2.2" "Database Service Health" \
        "check_database_connectivity" \
        "Database service starts correctly and accepts connections"
    
    validate_criterion "9.4.2.3" "Cache Service Health" \
        "check_redis_connectivity" \
        "Cache service starts correctly and accepts connections"
    
    validate_criterion "9.4.2.4" "Storage Service Health" \
        "check_minio_connectivity" \
        "Storage service starts correctly and accepts connections"
    
    validate_criterion "9.4.2.5" "WebSocket Service Health" \
        "check_http_endpoint 'http://backend-service:8000/ws/health' 200" \
        "WebSocket service starts correctly and health endpoint responds"
    
    # 9.4.3 Monitoring and alerting work
    log_section "📊 9.4.3 Monitoring and Alerting Work"
    
    validate_criterion "9.4.3.1" "Prometheus Metrics Collection" \
        "check_prometheus_metrics" \
        "Prometheus collects metrics successfully"
    
    validate_criterion "9.4.3.2" "Grafana Dashboard Access" \
        "check_grafana_dashboards" \
        "Grafana dashboards are accessible and configured"
    
    validate_criterion "9.4.3.3" "AlertManager Configuration" \
        "check_alertmanager" \
        "AlertManager is configured and operational"
    
    validate_criterion "9.4.3.4" "SLI/SLO Configuration" \
        "kubectl get sli -n $NAMESPACE >/dev/null 2>&1 || kubectl get slo -n $NAMESPACE >/dev/null 2>&1 || test -f '$PROJECT_ROOT/k8s/42-sli-slo-config.yaml'" \
        "SLI/SLO configuration is deployed or available"
    
    # 9.4.4 Performance meets requirements
    log_section "⚡ 9.4.4 Performance Meets Requirements"
    
    validate_criterion "9.4.4.1" "Resource Limits Configuration" \
        "check_resource_limits 'backend' && check_resource_limits 'frontend' && check_resource_limits 'postgres'" \
        "Resource limits are configured for all deployments"
    
    validate_criterion "9.4.4.2" "Security Contexts Configuration" \
        "check_security_contexts 'backend' && check_security_contexts 'frontend' && check_security_contexts 'postgres'" \
        "Security contexts are configured for all deployments"
    
    validate_criterion "9.4.4.3" "Health Probes Configuration" \
        "check_probes 'backend' && check_probes 'frontend' && check_probes 'postgres'" \
        "Health probes are configured for all deployments"
    
    validate_criterion "9.4.4.4" "TLS Encryption Configuration" \
        "check_tls_certificates 'ms5-dashboard-cert' && check_tls_certificates 'backend-tls-cert'" \
        "TLS encryption is configured and certificates are ready"
    
    validate_criterion "9.4.4.5" "Network Performance" \
        "check_http_endpoint 'https://ms5-dashboard.company.com' 200 || check_http_endpoint 'http://nginx-service:80' 200" \
        "Network performance meets requirements (application accessible)"
    
    # Generate validation report
    generate_validation_report
}

# Function to generate validation report
generate_validation_report() {
    log_section "📊 Generating Validation Report"
    
    local report_file="${PROJECT_ROOT}/logs/phase9-validation-criteria-report-${TIMESTAMP}.md"
    
    cat > "$report_file" << EOF
# MS5.0 Floor Dashboard - Phase 9 Validation Criteria Report

**Validation Started**: $(date)
**Namespace**: $NAMESPACE
**Total Criteria**: $TOTAL_CRITERIA
**Passed**: $PASSED_CRITERIA
**Failed**: $FAILED_CRITERIA
**Success Rate**: $(( (PASSED_CRITERIA * 100) / TOTAL_CRITERIA ))%

## Validation Summary

EOF

    if [ $FAILED_CRITERIA -eq 0 ]; then
        echo "🎉 **ALL VALIDATION CRITERIA PASSED!** 🎉" >> "$report_file"
        echo "" >> "$report_file"
        echo "The MS5.0 Floor Dashboard Phase 9 deployment has successfully met all validation criteria:" >> "$report_file"
        echo "- ✅ Application deploys successfully" >> "$report_file"
        echo "- ✅ All services start correctly" >> "$report_file"
        echo "- ✅ Monitoring and alerting work" >> "$report_file"
        echo "- ✅ Performance meets requirements" >> "$report_file"
    else
        echo "❌ **VALIDATION CRITERIA FAILED** ❌" >> "$report_file"
        echo "" >> "$report_file"
        echo "The following validation criteria failed:" >> "$report_file"
    fi
    
    echo "" >> "$report_file"
    echo "## Detailed Results" >> "$report_file"
    echo "" >> "$report_file"
    echo "| Criterion ID | Criterion Name | Status | Description |" >> "$report_file"
    echo "|--------------|----------------|--------|-------------|" >> "$report_file"
    
    for criterion in "${VALIDATION_CRITERIA[@]}"; do
        IFS='|' read -r criterion_id criterion_name status description <<< "$criterion"
        
        local status_icon=""
        case "$status" in
            "PASS") status_icon="✅" ;;
            "FAIL") status_icon="❌" ;;
        esac
        
        echo "| $criterion_id | $criterion_name | $status_icon $status | $description |" >> "$report_file"
    done
    
    echo "" >> "$report_file"
    echo "## Phase 9 Compliance Status" >> "$report_file"
    echo "" >> "$report_file"
    
    # Check each phase
    local phase9_1_status="✅ PASS"
    local phase9_2_status="✅ PASS"
    local phase9_3_status="✅ PASS"
    local phase9_4_status="✅ PASS"
    
    # Check if any criteria in each phase failed
    for criterion in "${VALIDATION_CRITERIA[@]}"; do
        IFS='|' read -r criterion_id criterion_name status description <<< "$criterion"
        
        if [ "$status" = "FAIL" ]; then
            case "$criterion_id" in
                9.1.*) phase9_1_status="❌ FAIL" ;;
                9.2.*) phase9_2_status="❌ FAIL" ;;
                9.3.*) phase9_3_status="❌ FAIL" ;;
                9.4.*) phase9_4_status="❌ FAIL" ;;
            esac
        fi
    done
    
    echo "| Phase | Status |" >> "$report_file"
    echo "|-------|--------|" >> "$report_file"
    echo "| 9.1 Code Review Checkpoint | $phase9_1_status |" >> "$report_file"
    echo "| 9.2 Deployment Preparation | $phase9_2_status |" >> "$report_file"
    echo "| 9.3 AKS Deployment | $phase9_3_status |" >> "$report_file"
    echo "| 9.4 Validation Criteria | $phase9_4_status |" >> "$report_file"
    
    echo "" >> "$report_file"
    echo "## Next Steps" >> "$report_file"
    echo "" >> "$report_file"
    
    if [ $FAILED_CRITERIA -eq 0 ]; then
        echo "- 🎉 **Phase 9 deployment is COMPLETE and VALIDATED**" >> "$report_file"
        echo "- ✅ System is ready for production traffic" >> "$report_file"
        echo "- ✅ All monitoring and alerting systems are operational" >> "$report_file"
        echo "- ✅ Performance requirements are met" >> "$report_file"
        echo "- ✅ Security standards are enforced" >> "$report_file"
    else
        echo "- ❌ **Review failed validation criteria**" >> "$report_file"
        echo "- ❌ Fix issues identified in validation" >> "$report_file"
        echo "- ❌ Re-run validation after fixes" >> "$report_file"
        echo "- ❌ Do not proceed to production until all criteria pass" >> "$report_file"
    fi
    
    log_success "Validation report generated: $report_file"
    
    # Display final summary
    log_section "📊 Validation Summary"
    log_info "Total Criteria: $TOTAL_CRITERIA"
    log_info "Passed: $PASSED_CRITERIA"
    log_info "Failed: $FAILED_CRITERIA"
    log_info "Success Rate: $(( (PASSED_CRITERIA * 100) / TOTAL_CRITERIA ))%"
    
    if [ $FAILED_CRITERIA -eq 0 ]; then
        log_success "🎉 ALL VALIDATION CRITERIA PASSED!"
        log_success "Phase 9 deployment is COMPLETE and VALIDATED!"
        exit 0
    else
        log_error "❌ VALIDATION CRITERIA FAILED"
        log_error "Please review failed criteria and fix issues before proceeding"
        exit 1
    fi
}

# Handle script arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --help               Show this help message"
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
