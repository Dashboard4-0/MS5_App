#!/bin/bash

# MS5.0 Floor Dashboard - Phase 2 Testing Script
# This script performs comprehensive testing of Phase 2 deployment

set -euo pipefail

# Configuration
NAMESPACE="ms5-production"
CONTEXT="aks-ms5-prod-uksouth"
VERBOSE=${VERBOSE:-false}

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

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Test result tracking
test_result() {
    if [ $1 -eq 0 ]; then
        log_success "$2"
        ((TESTS_PASSED++))
    else
        log_error "$2"
        ((TESTS_FAILED++))
    fi
}

# Test namespace exists
test_namespace() {
    log_info "Testing namespace existence..."
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        test_result 0 "Namespace $NAMESPACE exists"
    else
        test_result 1 "Namespace $NAMESPACE does not exist"
    fi
}

# Test resource quotas
test_resource_quotas() {
    log_info "Testing resource quotas..."
    if kubectl get resourcequota -n "$NAMESPACE" &> /dev/null; then
        test_result 0 "Resource quotas are configured"
    else
        test_result 1 "Resource quotas are not configured"
    fi
}

# Test limit ranges
test_limit_ranges() {
    log_info "Testing limit ranges..."
    if kubectl get limitrange -n "$NAMESPACE" &> /dev/null; then
        test_result 0 "Limit ranges are configured"
    else
        test_result 1 "Limit ranges are not configured"
    fi
}

# Test ConfigMaps
test_configmaps() {
    log_info "Testing ConfigMaps..."
    local configmaps=(
        "ms5-app-config"
        "ms5-database-config"
        "ms5-redis-config"
        "ms5-minio-config"
        "ms5-prometheus-config"
        "ms5-prometheus-rules"
        "ms5-grafana-config"
        "ms5-grafana-dashboards"
        "ms5-alertmanager-config"
        "ms5-sli-definitions"
        "ms5-slo-configuration"
        "ms5-cost-monitoring"
    )
    
    local failed=0
    for cm in "${configmaps[@]}"; do
        if kubectl get configmap "$cm" -n "$NAMESPACE" &> /dev/null; then
            log_success "ConfigMap $cm exists"
        else
            log_error "ConfigMap $cm does not exist"
            ((failed++))
        fi
    done
    
    test_result $failed "ConfigMaps test"
}

# Test Secrets
test_secrets() {
    log_info "Testing Secrets..."
    local secrets=(
        "ms5-app-secrets"
        "ms5-database-secrets"
        "ms5-redis-secrets"
        "ms5-minio-secrets"
        "ms5-grafana-secrets"
    )
    
    local failed=0
    for secret in "${secrets[@]}"; do
        if kubectl get secret "$secret" -n "$NAMESPACE" &> /dev/null; then
            log_success "Secret $secret exists"
        else
            log_error "Secret $secret does not exist"
            ((failed++))
        fi
    done
    
    test_result $failed "Secrets test"
}

# Test RBAC
test_rbac() {
    log_info "Testing RBAC..."
    local service_accounts=(
        "ms5-backend-sa"
        "ms5-database-sa"
        "ms5-monitoring-sa"
    )
    
    local failed=0
    for sa in "${service_accounts[@]}"; do
        if kubectl get serviceaccount "$sa" -n "$NAMESPACE" &> /dev/null; then
            log_success "ServiceAccount $sa exists"
        else
            log_error "ServiceAccount $sa does not exist"
            ((failed++))
        fi
    done
    
    test_result $failed "RBAC test"
}

# Test StatefulSets
test_statefulsets() {
    log_info "Testing StatefulSets..."
    local statefulsets=(
        "postgres-primary"
        "postgres-replica"
        "redis-primary"
        "redis-replica"
        "minio"
        "prometheus"
        "grafana"
    )
    
    local failed=0
    for sts in "${statefulsets[@]}"; do
        if kubectl get statefulset "$sts" -n "$NAMESPACE" &> /dev/null; then
            local ready=$(kubectl get statefulset "$sts" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}')
            local desired=$(kubectl get statefulset "$sts" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}')
            if [ "$ready" = "$desired" ]; then
                log_success "StatefulSet $sts is ready ($ready/$desired)"
            else
                log_warning "StatefulSet $sts is not ready ($ready/$desired)"
                ((failed++))
            fi
        else
            log_error "StatefulSet $sts does not exist"
            ((failed++))
        fi
    done
    
    test_result $failed "StatefulSets test"
}

# Test Deployments
test_deployments() {
    log_info "Testing Deployments..."
    local deployments=(
        "ms5-backend"
        "ms5-celery-worker"
        "ms5-celery-beat"
        "ms5-flower"
        "alertmanager"
    )
    
    local failed=0
    for deploy in "${deployments[@]}"; do
        if kubectl get deployment "$deploy" -n "$NAMESPACE" &> /dev/null; then
            local ready=$(kubectl get deployment "$deploy" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}')
            local desired=$(kubectl get deployment "$deploy" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}')
            if [ "$ready" = "$desired" ]; then
                log_success "Deployment $deploy is ready ($ready/$desired)"
            else
                log_warning "Deployment $deploy is not ready ($ready/$desired)"
                ((failed++))
            fi
        else
            log_error "Deployment $deploy does not exist"
            ((failed++))
        fi
    done
    
    test_result $failed "Deployments test"
}

# Test Services
test_services() {
    log_info "Testing Services..."
    local services=(
        "postgres-primary"
        "postgres-replica"
        "redis-primary"
        "redis-replica"
        "ms5-backend"
        "ms5-flower"
        "minio"
        "prometheus"
        "grafana"
        "alertmanager"
    )
    
    local failed=0
    for svc in "${services[@]}"; do
        if kubectl get service "$svc" -n "$NAMESPACE" &> /dev/null; then
            log_success "Service $svc exists"
        else
            log_error "Service $svc does not exist"
            ((failed++))
        fi
    done
    
    test_result $failed "Services test"
}

# Test HPA
test_hpa() {
    log_info "Testing Horizontal Pod Autoscalers..."
    local hpas=(
        "ms5-backend-hpa"
        "ms5-celery-worker-hpa"
    )
    
    local failed=0
    for hpa in "${hpas[@]}"; do
        if kubectl get hpa "$hpa" -n "$NAMESPACE" &> /dev/null; then
            log_success "HPA $hpa exists"
        else
            log_error "HPA $hpa does not exist"
            ((failed++))
        fi
    done
    
    test_result $failed "HPA test"
}

# Test Network Policies
test_network_policies() {
    log_info "Testing Network Policies..."
    local network_policies=(
        "ms5-deny-all"
        "ms5-backend-network-policy"
        "ms5-database-network-policy"
        "ms5-redis-network-policy"
        "ms5-minio-network-policy"
        "ms5-monitoring-network-policy"
        "ms5-grafana-network-policy"
        "ms5-alertmanager-network-policy"
        "ms5-celery-network-policy"
    )
    
    local failed=0
    for np in "${network_policies[@]}"; do
        if kubectl get networkpolicy "$np" -n "$NAMESPACE" &> /dev/null; then
            log_success "NetworkPolicy $np exists"
        else
            log_error "NetworkPolicy $np does not exist"
            ((failed++))
        fi
    done
    
    test_result $failed "Network Policies test"
}

# Test Persistent Volume Claims
test_pvcs() {
    log_info "Testing Persistent Volume Claims..."
    local pvcs=(
        "postgres-data-pvc"
        "postgres-backup-pvc"
        "redis-data-pvc"
        "minio-data-pvc"
        "prometheus-data-pvc"
        "grafana-data-pvc"
        "alertmanager-data-pvc"
    )
    
    local failed=0
    for pvc in "${pvcs[@]}"; do
        if kubectl get pvc "$pvc" -n "$NAMESPACE" &> /dev/null; then
            local status=$(kubectl get pvc "$pvc" -n "$NAMESPACE" -o jsonpath='{.status.phase}')
            if [ "$status" = "Bound" ]; then
                log_success "PVC $pvc is bound"
            else
                log_warning "PVC $pvc is not bound (status: $status)"
                ((failed++))
            fi
        else
            log_error "PVC $pvc does not exist"
            ((failed++))
        fi
    done
    
    test_result $failed "PVCs test"
}

# Test connectivity
test_connectivity() {
    log_info "Testing service connectivity..."
    
    # Test backend health endpoint
    log_info "Testing backend health endpoint..."
    if kubectl exec -n "$NAMESPACE" deployment/ms5-backend -- curl -f http://localhost:8000/health &> /dev/null; then
        test_result 0 "Backend health endpoint is accessible"
    else
        test_result 1 "Backend health endpoint is not accessible"
    fi
    
    # Test database connectivity
    log_info "Testing database connectivity..."
    if kubectl exec -n "$NAMESPACE" deployment/ms5-backend -- pg_isready -h postgres-primary.ms5-production.svc.cluster.local -p 5432 &> /dev/null; then
        test_result 0 "Database connectivity is working"
    else
        test_result 1 "Database connectivity is not working"
    fi
    
    # Test Redis connectivity
    log_info "Testing Redis connectivity..."
    if kubectl exec -n "$NAMESPACE" deployment/ms5-backend -- redis-cli -h redis-primary.ms5-production.svc.cluster.local -p 6379 ping &> /dev/null; then
        test_result 0 "Redis connectivity is working"
    else
        test_result 1 "Redis connectivity is not working"
    fi
    
    # Test MinIO connectivity
    log_info "Testing MinIO connectivity..."
    if kubectl exec -n "$NAMESPACE" deployment/ms5-backend -- curl -f http://minio.ms5-production.svc.cluster.local:9000/minio/health/live &> /dev/null; then
        test_result 0 "MinIO connectivity is working"
    else
        test_result 1 "MinIO connectivity is not working"
    fi
    
    # Test Prometheus
    log_info "Testing Prometheus..."
    if kubectl exec -n "$NAMESPACE" deployment/prometheus -- curl -f http://localhost:9090/-/healthy &> /dev/null; then
        test_result 0 "Prometheus is healthy"
    else
        test_result 1 "Prometheus is not healthy"
    fi
    
    # Test Grafana
    log_info "Testing Grafana..."
    if kubectl exec -n "$NAMESPACE" deployment/grafana -- curl -f http://localhost:3000/api/health &> /dev/null; then
        test_result 0 "Grafana is healthy"
    else
        test_result 1 "Grafana is not healthy"
    fi
}

# Test Celery workers
test_celery() {
    log_info "Testing Celery workers..."
    
    # Test Celery worker health
    if kubectl exec -n "$NAMESPACE" deployment/ms5-celery-worker -- celery -A app.celery inspect ping &> /dev/null; then
        test_result 0 "Celery workers are healthy"
    else
        test_result 1 "Celery workers are not healthy"
    fi
    
    # Test Celery beat
    if kubectl exec -n "$NAMESPACE" deployment/ms5-celery-beat -- celery -A app.celery inspect ping &> /dev/null; then
        test_result 0 "Celery beat is healthy"
    else
        test_result 1 "Celery beat is not healthy"
    fi
    
    # Test Flower
    if kubectl exec -n "$NAMESPACE" deployment/ms5-flower -- curl -f http://localhost:5555 &> /dev/null; then
        test_result 0 "Flower is accessible"
    else
        test_result 1 "Flower is not accessible"
    fi
}

# Test monitoring
test_monitoring() {
    log_info "Testing monitoring setup..."
    
    # Test Prometheus targets
    log_info "Testing Prometheus targets..."
    local targets=$(kubectl exec -n "$NAMESPACE" deployment/prometheus -- curl -s http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets | length')
    if [ "$targets" -gt 0 ]; then
        test_result 0 "Prometheus has $targets active targets"
    else
        test_result 1 "Prometheus has no active targets"
    fi
    
    # Test Grafana datasources
    log_info "Testing Grafana datasources..."
    if kubectl exec -n "$NAMESPACE" deployment/grafana -- curl -f http://localhost:3000/api/datasources &> /dev/null; then
        test_result 0 "Grafana datasources are configured"
    else
        test_result 1 "Grafana datasources are not configured"
    fi
    
    # Test AlertManager
    log_info "Testing AlertManager..."
    if kubectl exec -n "$NAMESPACE" deployment/alertmanager -- curl -f http://localhost:9093/-/healthy &> /dev/null; then
        test_result 0 "AlertManager is healthy"
    else
        test_result 1 "AlertManager is not healthy"
    fi
}

# Test security
test_security() {
    log_info "Testing security configurations..."
    
    # Test Pod Security Standards
    log_info "Testing Pod Security Standards..."
    local pods=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}')
    local failed=0
    for pod in $pods; do
        local security_context=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.spec.securityContext.runAsNonRoot}')
        if [ "$security_context" = "true" ]; then
            log_success "Pod $pod has non-root security context"
        else
            log_warning "Pod $pod does not have non-root security context"
            ((failed++))
        fi
    done
    
    test_result $failed "Pod Security Standards test"
}

# Test resource usage
test_resource_usage() {
    log_info "Testing resource usage..."
    
    # Check CPU usage
    local cpu_usage=$(kubectl top pods -n "$NAMESPACE" --no-headers | awk '{sum+=$2} END {print sum}')
    if [ "$cpu_usage" -lt 80 ]; then
        test_result 0 "CPU usage is within limits ($cpu_usage%)"
    else
        test_result 1 "CPU usage is high ($cpu_usage%)"
    fi
    
    # Check memory usage
    local memory_usage=$(kubectl top pods -n "$NAMESPACE" --no-headers | awk '{sum+=$3} END {print sum}')
    if [ "$memory_usage" -lt 80 ]; then
        test_result 0 "Memory usage is within limits ($memory_usage%)"
    else
        test_result 1 "Memory usage is high ($memory_usage%)"
    fi
}

# Generate test report
generate_report() {
    log_info "Generating test report..."
    
    local total_tests=$((TESTS_PASSED + TESTS_FAILED))
    local success_rate=$((TESTS_PASSED * 100 / total_tests))
    
    echo ""
    echo "=========================================="
    echo "MS5.0 Floor Dashboard - Phase 2 Test Report"
    echo "=========================================="
    echo "Total Tests: $total_tests"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    echo "Success Rate: $success_rate%"
    echo "=========================================="
    
    if [ $TESTS_FAILED -eq 0 ]; then
        log_success "All tests passed! Phase 2 deployment is successful."
        exit 0
    else
        log_error "Some tests failed. Please review the issues above."
        exit 1
    fi
}

# Main testing function
main() {
    log_info "Starting MS5.0 Floor Dashboard Phase 2 testing..."
    log_info "Namespace: $NAMESPACE"
    log_info "Context: $CONTEXT"
    
    # Execute test steps
    test_namespace
    test_resource_quotas
    test_limit_ranges
    test_configmaps
    test_secrets
    test_rbac
    test_statefulsets
    test_deployments
    test_services
    test_hpa
    test_network_policies
    test_pvcs
    test_connectivity
    test_celery
    test_monitoring
    test_security
    test_resource_usage
    
    generate_report
}

# Handle script arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [--verbose] [--help]"
            echo "  --verbose    Enable verbose output"
            echo "  --help       Show this help message"
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
