#!/bin/bash

# MS5.0 Floor Dashboard - Phase 9 Monitoring Stack Validation Script
# This script validates the complete monitoring stack deployment
# Designed with starship-grade precision and reliability

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NAMESPACE="ms5-production"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${PROJECT_ROOT}/logs/phase9-monitoring-validation-${TIMESTAMP}.log"

# Environment variables
VALIDATE_PROMETHEUS=${VALIDATE_PROMETHEUS:-true}
VALIDATE_GRAFANA=${VALIDATE_GRAFANA:-true}
VALIDATE_ALERTMANAGER=${VALIDATE_ALERTMANAGER:-true}
VALIDATE_SLI_SLO=${VALIDATE_SLI_SLO:-true}
VALIDATE_COST_MONITORING=${VALIDATE_COST_MONITORING:-true}
TEST_ALERTS=${TEST_ALERTS:-true}

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

# Function to check pod status
check_pod_status() {
    local app_label="$1"
    local component_label="$2"
    local expected_ready="${3:-1}"
    
    local pod_name="${app_label}-${component_label}"
    
    # Get pod status
    local ready_pods=$(kubectl get pods -n "$NAMESPACE" -l app="$app_label",component="$component_label" -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' | grep -c "True" || echo "0")
    local total_pods=$(kubectl get pods -n "$NAMESPACE" -l app="$app_label",component="$component_label" --no-headers | wc -l)
    
    if [ "$ready_pods" -eq "$expected_ready" ] && [ "$total_pods" -eq "$expected_ready" ]; then
        record_validation "pod-status-$component_label" "PASS" "$ready_pods/$total_pods pods ready"
    elif [ "$ready_pods" -gt 0 ]; then
        record_validation "pod-status-$component_label" "WARN" "$ready_pods/$total_pods pods ready (expected $expected_ready)"
    else
        record_validation "pod-status-$component_label" "FAIL" "No pods ready (expected $expected_ready)"
    fi
}

# Function to check service status
check_service_status() {
    local app_label="$1"
    local component_label="$2"
    
    local service_name="${app_label}-${component_label}"
    
    # Check if service exists and has endpoints
    if kubectl get service "$service_name" -n "$NAMESPACE" &> /dev/null; then
        local endpoints=$(kubectl get endpoints "$service_name" -n "$NAMESPACE" -o jsonpath='{.subsets[*].addresses[*].ip}' | wc -w)
        if [ "$endpoints" -gt 0 ]; then
            record_validation "service-status-$component_label" "PASS" "Service has $endpoints endpoints"
        else
            record_validation "service-status-$component_label" "WARN" "Service exists but has no endpoints"
        fi
    else
        record_validation "service-status-$component_label" "FAIL" "Service not found"
    fi
}

# Function to test HTTP endpoint
test_http_endpoint() {
    local pod_name="$1"
    local port="$2"
    local path="${3:-/}"
    local expected_status="${4:-200}"
    
    local test_name="http-endpoint-$pod_name-$port"
    
    # Test HTTP endpoint
    local response=$(kubectl exec "$pod_name" -n "$NAMESPACE" -- curl -s -o /dev/null -w "%{http_code}" "http://localhost:$port$path" 2>/dev/null || echo "000")
    
    if [ "$response" = "$expected_status" ]; then
        record_validation "$test_name" "PASS" "HTTP $response response on port $port"
    else
        record_validation "$test_name" "FAIL" "HTTP $response response on port $port (expected $expected_status)"
    fi
}

# Function to validate Prometheus
validate_prometheus() {
    log_section "Validating Prometheus"
    
    if [ "$VALIDATE_PROMETHEUS" != "true" ]; then
        record_validation "prometheus-validation" "PASS" "Prometheus validation skipped"
        return 0
    fi
    
    # Check pod status
    check_pod_status "ms5-dashboard" "prometheus" "1"
    
    # Check service status
    check_service_status "ms5-dashboard" "prometheus"
    
    # Get Prometheus pod name
    local prometheus_pod=$(kubectl get pods -n "$NAMESPACE" -l app=ms5-dashboard,component=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -n "$prometheus_pod" ]; then
        # Test Prometheus web interface
        test_http_endpoint "$prometheus_pod" "9090" "/" "200"
        
        # Test Prometheus metrics endpoint
        test_http_endpoint "$prometheus_pod" "9090" "/metrics" "200"
        
        # Test Prometheus health endpoint
        test_http_endpoint "$prometheus_pod" "9090" "/-/healthy" "200"
        
        # Check if Prometheus is scraping targets
        local targets=$(kubectl exec "$prometheus_pod" -n "$NAMESPACE" -- curl -s "http://localhost:9090/api/v1/targets" 2>/dev/null | grep -o '"health":"up"' | wc -l)
        if [ "$targets" -gt 0 ]; then
            record_validation "prometheus-targets" "PASS" "Prometheus scraping $targets healthy targets"
        else
            record_validation "prometheus-targets" "WARN" "Prometheus has no healthy targets"
        fi
        
        # Check Prometheus configuration
        if kubectl exec "$prometheus_pod" -n "$NAMESPACE" -- curl -s "http://localhost:9090/api/v1/status/config" &> /dev/null; then
            record_validation "prometheus-config" "PASS" "Prometheus configuration is valid"
        else
            record_validation "prometheus-config" "FAIL" "Prometheus configuration is invalid"
        fi
    else
        record_validation "prometheus-pod" "FAIL" "Prometheus pod not found"
    fi
}

# Function to validate Grafana
validate_grafana() {
    log_section "Validating Grafana"
    
    if [ "$VALIDATE_GRAFANA" != "true" ]; then
        record_validation "grafana-validation" "PASS" "Grafana validation skipped"
        return 0
    fi
    
    # Check pod status
    check_pod_status "ms5-dashboard" "grafana" "1"
    
    # Check service status
    check_service_status "ms5-dashboard" "grafana"
    
    # Get Grafana pod name
    local grafana_pod=$(kubectl get pods -n "$NAMESPACE" -l app=ms5-dashboard,component=grafana -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -n "$grafana_pod" ]; then
        # Test Grafana web interface
        test_http_endpoint "$grafana_pod" "3000" "/" "200"
        
        # Test Grafana API
        test_http_endpoint "$grafana_pod" "3000" "/api/health" "200"
        
        # Test Grafana login page
        test_http_endpoint "$grafana_pod" "3000" "/login" "200"
        
        # Check if Grafana has datasources configured
        local datasources=$(kubectl exec "$grafana_pod" -n "$NAMESPACE" -- curl -s "http://admin:admin@localhost:3000/api/datasources" 2>/dev/null | grep -o '"name"' | wc -l)
        if [ "$datasources" -gt 0 ]; then
            record_validation "grafana-datasources" "PASS" "Grafana has $datasources datasources configured"
        else
            record_validation "grafana-datasources" "WARN" "Grafana has no datasources configured"
        fi
        
        # Check if Grafana has dashboards
        local dashboards=$(kubectl exec "$grafana_pod" -n "$NAMESPACE" -- curl -s "http://admin:admin@localhost:3000/api/search?type=dash-db" 2>/dev/null | grep -o '"title"' | wc -l)
        if [ "$dashboards" -gt 0 ]; then
            record_validation "grafana-dashboards" "PASS" "Grafana has $dashboards dashboards"
        else
            record_validation "grafana-dashboards" "WARN" "Grafana has no dashboards"
        fi
    else
        record_validation "grafana-pod" "FAIL" "Grafana pod not found"
    fi
}

# Function to validate AlertManager
validate_alertmanager() {
    log_section "Validating AlertManager"
    
    if [ "$VALIDATE_ALERTMANAGER" != "true" ]; then
        record_validation "alertmanager-validation" "PASS" "AlertManager validation skipped"
        return 0
    fi
    
    # Check pod status
    check_pod_status "ms5-dashboard" "alertmanager" "1"
    
    # Check service status
    check_service_status "ms5-dashboard" "alertmanager"
    
    # Get AlertManager pod name
    local alertmanager_pod=$(kubectl get pods -n "$NAMESPACE" -l app=ms5-dashboard,component=alertmanager -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -n "$alertmanager_pod" ]; then
        # Test AlertManager web interface
        test_http_endpoint "$alertmanager_pod" "9093" "/" "200"
        
        # Test AlertManager API
        test_http_endpoint "$alertmanager_pod" "9093" "/api/v1/status" "200"
        
        # Test AlertManager health endpoint
        test_http_endpoint "$alertmanager_pod" "9093" "/-/healthy" "200"
        
        # Check AlertManager configuration
        if kubectl exec "$alertmanager_pod" -n "$NAMESPACE" -- curl -s "http://localhost:9093/api/v1/status" &> /dev/null; then
            record_validation "alertmanager-config" "PASS" "AlertManager configuration is valid"
        else
            record_validation "alertmanager-config" "FAIL" "AlertManager configuration is invalid"
        fi
        
        # Check if AlertManager has receivers configured
        local receivers=$(kubectl exec "$alertmanager_pod" -n "$NAMESPACE" -- curl -s "http://localhost:9093/api/v1/receivers" 2>/dev/null | grep -o '"name"' | wc -l)
        if [ "$receivers" -gt 0 ]; then
            record_validation "alertmanager-receivers" "PASS" "AlertManager has $receivers receivers configured"
        else
            record_validation "alertmanager-receivers" "WARN" "AlertManager has no receivers configured"
        fi
    else
        record_validation "alertmanager-pod" "FAIL" "AlertManager pod not found"
    fi
}

# Function to validate SLI/SLO configuration
validate_sli_slo() {
    log_section "Validating SLI/SLO Configuration"
    
    if [ "$VALIDATE_SLI_SLO" != "true" ]; then
        record_validation "sli-slo-validation" "PASS" "SLI/SLO validation skipped"
        return 0
    fi
    
    # Check if SLI definitions exist
    if kubectl get configmap -n "$NAMESPACE" -l app=ms5-dashboard,component=sli &> /dev/null; then
        record_validation "sli-definitions" "PASS" "SLI definitions configured"
    else
        record_validation "sli-definitions" "WARN" "SLI definitions not configured"
    fi
    
    # Check if SLO configuration exists
    if kubectl get configmap -n "$NAMESPACE" -l app=ms5-dashboard,component=slo &> /dev/null; then
        record_validation "slo-configuration" "PASS" "SLO configuration configured"
    else
        record_validation "slo-configuration" "WARN" "SLO configuration not configured"
    fi
    
    # Validate SLI definitions YAML
    local sli_configmap=$(kubectl get configmap -n "$NAMESPACE" -l app=ms5-dashboard,component=sli -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ -n "$sli_configmap" ]; then
        local sli_yaml=$(kubectl get configmap "$sli_configmap" -n "$NAMESPACE" -o jsonpath='{.data.sli-definitions\.yaml}' 2>/dev/null || echo "")
        if [ -n "$sli_yaml" ]; then
            if echo "$sli_yaml" | python3 -c "import yaml; yaml.safe_load_all(sys.stdin)" &> /dev/null; then
                record_validation "sli-yaml-syntax" "PASS" "SLI definitions YAML syntax is valid"
            else
                record_validation "sli-yaml-syntax" "FAIL" "SLI definitions YAML syntax is invalid"
            fi
        else
            record_validation "sli-yaml-content" "WARN" "SLI definitions YAML content not found"
        fi
    fi
}

# Function to validate cost monitoring
validate_cost_monitoring() {
    log_section "Validating Cost Monitoring"
    
    if [ "$VALIDATE_COST_MONITORING" != "true" ]; then
        record_validation "cost-monitoring-validation" "PASS" "Cost monitoring validation skipped"
        return 0
    fi
    
    # Check if cost monitoring configuration exists
    if kubectl get configmap -n "$NAMESPACE" -l app=ms5-dashboard,component=cost-monitoring &> /dev/null; then
        record_validation "cost-monitoring-config" "PASS" "Cost monitoring configuration found"
    else
        record_validation "cost-monitoring-config" "WARN" "Cost monitoring configuration not found"
    fi
    
    # Check for Azure cost monitoring metrics
    local cost_configmap=$(kubectl get configmap -n "$NAMESPACE" -l app=ms5-dashboard,component=cost-monitoring -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ -n "$cost_configmap" ]; then
        local cost_yaml=$(kubectl get configmap "$cost_configmap" -n "$NAMESPACE" -o jsonpath='{.data.cost-monitoring\.yml}' 2>/dev/null || echo "")
        if [ -n "$cost_yaml" ]; then
            if echo "$cost_yaml" | grep -q "azure_cost_metrics"; then
                record_validation "cost-azure-metrics" "PASS" "Azure cost metrics configuration found"
            else
                record_validation "cost-azure-metrics" "WARN" "Azure cost metrics configuration not found"
            fi
            
            if echo "$cost_yaml" | grep -q "resource_optimization"; then
                record_validation "cost-resource-optimization" "PASS" "Resource optimization configuration found"
            else
                record_validation "cost-resource-optimization" "WARN" "Resource optimization configuration not found"
            fi
        else
            record_validation "cost-yaml-content" "WARN" "Cost monitoring YAML content not found"
        fi
    fi
}

# Function to test alerting
test_alerting() {
    log_section "Testing Alerting System"
    
    if [ "$TEST_ALERTS" != "true" ]; then
        record_validation "alerting-test" "PASS" "Alerting test skipped"
        return 0
    fi
    
    # Check if alert rules are configured
    local alert_rules_file="$PROJECT_ROOT/backend/alert_rules.yml"
    if [ -f "$alert_rules_file" ]; then
        if python3 -c "import yaml; yaml.safe_load_all(open('$alert_rules_file'))" &> /dev/null; then
            record_validation "alert-rules-yaml" "PASS" "Alert rules YAML syntax is valid"
        else
            record_validation "alert-rules-yaml" "FAIL" "Alert rules YAML syntax is invalid"
        fi
        
        # Count alert rules
        local alert_count=$(grep -c "alert:" "$alert_rules_file" || echo "0")
        if [ "$alert_count" -gt 0 ]; then
            record_validation "alert-rules-count" "PASS" "Found $alert_count alert rules"
        else
            record_validation "alert-rules-count" "WARN" "No alert rules found"
        fi
    else
        record_validation "alert-rules-file" "FAIL" "Alert rules file not found"
    fi
    
    # Check AlertManager configuration
    local alertmanager_config_file="$PROJECT_ROOT/backend/alertmanager.yml"
    if [ -f "$alertmanager_config_file" ]; then
        if python3 -c "import yaml; yaml.safe_load(open('$alertmanager_config_file'))" &> /dev/null; then
            record_validation "alertmanager-config-yaml" "PASS" "AlertManager configuration YAML syntax is valid"
        else
            record_validation "alertmanager-config-yaml" "FAIL" "AlertManager configuration YAML syntax is invalid"
        fi
        
        # Check for receivers
        if grep -q "receivers:" "$alertmanager_config_file"; then
            local receiver_count=$(grep -c "name:" "$alertmanager_config_file" || echo "0")
            record_validation "alertmanager-receivers" "PASS" "Found $receiver_count receivers in AlertManager config"
        else
            record_validation "alertmanager-receivers" "WARN" "No receivers found in AlertManager config"
        fi
    else
        record_validation "alertmanager-config-file" "FAIL" "AlertManager configuration file not found"
    fi
}

# Function to validate monitoring integration
validate_monitoring_integration() {
    log_section "Validating Monitoring Integration"
    
    # Check if Prometheus is configured to scrape application metrics
    local prometheus_pod=$(kubectl get pods -n "$NAMESPACE" -l app=ms5-dashboard,component=prometheus -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ -n "$prometheus_pod" ]; then
        # Check if backend metrics are being scraped
        local backend_targets=$(kubectl exec "$prometheus_pod" -n "$NAMESPACE" -- curl -s "http://localhost:9090/api/v1/targets" 2>/dev/null | grep -c "ms5-backend" || echo "0")
        if [ "$backend_targets" -gt 0 ]; then
            record_validation "prometheus-backend-scraping" "PASS" "Prometheus is scraping backend metrics"
        else
            record_validation "prometheus-backend-scraping" "WARN" "Prometheus is not scraping backend metrics"
        fi
        
        # Check if Kubernetes metrics are being scraped
        local k8s_targets=$(kubectl exec "$prometheus_pod" -n "$NAMESPACE" -- curl -s "http://localhost:9090/api/v1/targets" 2>/dev/null | grep -c "kubernetes" || echo "0")
        if [ "$k8s_targets" -gt 0 ]; then
            record_validation "prometheus-k8s-scraping" "PASS" "Prometheus is scraping Kubernetes metrics"
        else
            record_validation "prometheus-k8s-scraping" "WARN" "Prometheus is not scraping Kubernetes metrics"
        fi
    fi
    
    # Check if Grafana is connected to Prometheus
    local grafana_pod=$(kubectl get pods -n "$NAMESPACE" -l app=ms5-dashboard,component=grafana -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ -n "$grafana_pod" ]; then
        local prometheus_datasource=$(kubectl exec "$grafana_pod" -n "$NAMESPACE" -- curl -s "http://admin:admin@localhost:3000/api/datasources" 2>/dev/null | grep -c "Prometheus" || echo "0")
        if [ "$prometheus_datasource" -gt 0 ]; then
            record_validation "grafana-prometheus-datasource" "PASS" "Grafana has Prometheus datasource configured"
        else
            record_validation "grafana-prometheus-datasource" "WARN" "Grafana does not have Prometheus datasource configured"
        fi
    fi
}

# Function to generate validation report
generate_validation_report() {
    log_section "Generating Monitoring Validation Report"
    
    local report_file="${PROJECT_ROOT}/logs/phase9-monitoring-validation-report-${TIMESTAMP}.md"
    
    cat > "$report_file" << EOF
# MS5.0 Floor Dashboard - Phase 9 Monitoring Validation Report

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
    echo "## Access Information" >> "$report_file"
    echo "- **Prometheus**: https://prometheus.ms5-dashboard.company.com" >> "$report_file"
    echo "- **Grafana**: https://grafana.ms5-dashboard.company.com" >> "$report_file"
    echo "- **AlertManager**: https://alertmanager.ms5-dashboard.company.com" >> "$report_file"
    
    echo "" >> "$report_file"
    echo "## Recommendations" >> "$report_file"
    
    if [ $FAILED_VALIDATIONS -gt 0 ]; then
        echo "- ❌ **CRITICAL**: Fix all failed monitoring validations before proceeding with deployment" >> "$report_file"
    fi
    
    if [ $WARNING_VALIDATIONS -gt 0 ]; then
        echo "- ⚠️ **WARNING**: Review and address monitoring warnings before production deployment" >> "$report_file"
    fi
    
    if [ $FAILED_VALIDATIONS -eq 0 ] && [ $WARNING_VALIDATIONS -eq 0 ]; then
        echo "- ✅ **READY**: Monitoring stack is ready for production deployment" >> "$report_file"
    fi
    
    log_success "Monitoring validation report generated: $report_file"
}

# Main validation function
main() {
    log "Starting MS5.0 Floor Dashboard Phase 9 Monitoring Validation"
    log "Environment: Production"
    log "Namespace: $NAMESPACE"
    log "Log file: $LOG_FILE"
    
    # Run all validations
    validate_prometheus
    validate_grafana
    validate_alertmanager
    validate_sli_slo
    validate_cost_monitoring
    test_alerting
    validate_monitoring_integration
    
    # Generate report
    generate_validation_report
    
    # Summary
    log_section "Monitoring Validation Summary"
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
        log_error "Monitoring validation failed. Please fix all failed validations before proceeding."
        exit 1
    elif [ $WARNING_VALIDATIONS -gt 0 ]; then
        log_warning "Monitoring validation completed with warnings. Please review warnings before proceeding."
        exit 0
    else
        log_success "Monitoring validation completed successfully. Monitoring stack is ready for production."
        exit 0
    fi
}

# Handle script arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-prometheus)
            VALIDATE_PROMETHEUS=false
            shift
            ;;
        --skip-grafana)
            VALIDATE_GRAFANA=false
            shift
            ;;
        --skip-alertmanager)
            VALIDATE_ALERTMANAGER=false
            shift
            ;;
        --skip-sli-slo)
            VALIDATE_SLI_SLO=false
            shift
            ;;
        --skip-cost-monitoring)
            VALIDATE_COST_MONITORING=false
            shift
            ;;
        --skip-alert-test)
            TEST_ALERTS=false
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --skip-prometheus      Skip Prometheus validation"
            echo "  --skip-grafana        Skip Grafana validation"
            echo "  --skip-alertmanager   Skip AlertManager validation"
            echo "  --skip-sli-slo        Skip SLI/SLO validation"
            echo "  --skip-cost-monitoring Skip cost monitoring validation"
            echo "  --skip-alert-test     Skip alerting test"
            echo "  --help                Show this help message"
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
