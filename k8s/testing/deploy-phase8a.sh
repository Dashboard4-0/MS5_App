#!/bin/bash
# MS5.0 Floor Dashboard - Phase 8A: Core Testing & Performance Validation Deployment Script
# Comprehensive testing infrastructure deployment for AKS validation
#
# This script deploys the complete Phase 8A testing infrastructure including:
# - Performance testing infrastructure (k6, Artillery)
# - Security testing infrastructure (OWASP ZAP, Trivy, Falco)
# - Disaster recovery testing infrastructure (Litmus, backup/recovery)
# - Automated testing and validation procedures
#
# Architecture: Starship-grade testing infrastructure deployment script

set -euo pipefail

# Configuration
NAMESPACE="ms5-testing"
PRODUCTION_NAMESPACE="ms5-production"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/phase8a-deployment.log"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# Error handling
error_exit() {
    log_error "$1"
    exit 1
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites for Phase 8A deployment..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        error_exit "kubectl is not installed or not in PATH"
    fi
    
    # Check if kubectl can connect to cluster
    if ! kubectl cluster-info &> /dev/null; then
        error_exit "Cannot connect to Kubernetes cluster"
    fi
    
    # Check if production namespace exists
    if ! kubectl get namespace "$PRODUCTION_NAMESPACE" &> /dev/null; then
        error_exit "Production namespace '$PRODUCTION_NAMESPACE' does not exist"
    fi
    
    # Check if production services are running
    if ! kubectl get pods -n "$PRODUCTION_NAMESPACE" | grep -q Running; then
        error_exit "Production services are not running"
    fi
    
    log_success "Prerequisites check passed"
}

# Create testing namespace
create_testing_namespace() {
    log_info "Creating testing namespace..."
    
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $NAMESPACE
  labels:
    app: ms5-dashboard
    component: testing
    phase: "8a"
    purpose: performance-validation
  annotations:
    description: "Performance testing namespace for MS5.0 Floor Dashboard AKS validation"
    testing-phase: "8a"
    testing-type: "performance-validation"
EOF
    
    log_success "Testing namespace created"
}

# Deploy performance testing infrastructure
deploy_performance_testing() {
    log_info "Deploying performance testing infrastructure..."
    
    # Apply performance testing manifests
    kubectl apply -f "$SCRIPT_DIR/48-performance-testing-infrastructure.yaml"
    
    # Wait for performance testing pods to be ready
    log_info "Waiting for performance testing pods to be ready..."
    kubectl wait --for=condition=ready pod -l app=ms5-dashboard,component=testing,testing-tool=k6 -n "$NAMESPACE" --timeout=300s
    kubectl wait --for=condition=ready pod -l app=ms5-dashboard,component=testing,testing-tool=artillery -n "$NAMESPACE" --timeout=300s
    
    log_success "Performance testing infrastructure deployed"
}

# Deploy security testing infrastructure
deploy_security_testing() {
    log_info "Deploying security testing infrastructure..."
    
    # Apply security testing manifests
    kubectl apply -f "$SCRIPT_DIR/49-security-testing-infrastructure.yaml"
    
    # Wait for security testing pods to be ready
    log_info "Waiting for security testing pods to be ready..."
    kubectl wait --for=condition=ready pod -l app=ms5-dashboard,component=testing,testing-tool=owasp-zap -n "$NAMESPACE" --timeout=300s
    kubectl wait --for=condition=ready pod -l app=ms5-dashboard,component=testing,testing-tool=trivy -n "$NAMESPACE" --timeout=300s
    
    # Wait for Falco DaemonSet to be ready
    log_info "Waiting for Falco runtime security monitoring to be ready..."
    kubectl wait --for=condition=ready pod -l app=ms5-dashboard,component=testing,testing-tool=falco -n "$NAMESPACE" --timeout=300s
    
    log_success "Security testing infrastructure deployed"
}

# Deploy disaster recovery testing infrastructure
deploy_disaster_recovery_testing() {
    log_info "Deploying disaster recovery testing infrastructure..."
    
    # Apply disaster recovery testing manifests
    kubectl apply -f "$SCRIPT_DIR/50-disaster-recovery-testing.yaml"
    
    # Wait for disaster recovery testing pods to be ready
    log_info "Waiting for disaster recovery testing pods to be ready..."
    kubectl wait --for=condition=ready pod -l app=ms5-dashboard,component=testing,testing-tool=litmus -n "$NAMESPACE" --timeout=300s
    kubectl wait --for=condition=ready pod -l app=ms5-dashboard,component=testing,testing-tool=backup-recovery -n "$NAMESPACE" --timeout=300s
    
    log_success "Disaster recovery testing infrastructure deployed"
}

# Configure network policies
configure_network_policies() {
    log_info "Configuring network policies for testing..."
    
    # Apply network policies
    kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: testing-network-policy
  namespace: $NAMESPACE
spec:
  podSelector:
    matchLabels:
      app: ms5-dashboard
      component: testing
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 8080
  - from:
    - namespaceSelector:
        matchLabels:
          name: $PRODUCTION_NAMESPACE
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          name: $PRODUCTION_NAMESPACE
    ports:
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 5432
    - protocol: TCP
      port: 6379
    - protocol: TCP
      port: 9000
  - to:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 9090
  - to: []
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
EOF
    
    log_success "Network policies configured"
}

# Create test results PVC
create_test_results_pvc() {
    log_info "Creating test results persistent volume claim..."
    
    kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-results-pvc
  namespace: $NAMESPACE
  labels:
    app: ms5-dashboard
    component: testing
    purpose: test-results-storage
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 10Gi
  storageClassName: azurefile-premium
EOF
    
    log_success "Test results PVC created"
}

# Deploy automated testing CronJobs
deploy_automated_testing() {
    log_info "Deploying automated testing CronJobs..."
    
    # Performance testing CronJob
    kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: automated-performance-testing
  namespace: $NAMESPACE
spec:
  schedule: "0 2 * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 7
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: performance-test-runner
            image: grafana/k6:latest
            command: ["k6", "run", "--out", "prometheus=http://prometheus.$PRODUCTION_NAMESPACE.svc.cluster.local:9090/api/v1/write", "/config/k6-config.js"]
            env:
            - name: BASE_URL
              value: "https://ms5floor.com"
            resources:
              requests:
                memory: "512Mi"
                cpu: "500m"
              limits:
                memory: "1Gi"
                cpu: "1000m"
            volumeMounts:
            - name: test-config
              mountPath: /config
            - name: test-results
              mountPath: /results
          volumes:
          - name: test-config
            configMap:
              name: performance-test-config
          - name: test-results
            persistentVolumeClaim:
              claimName: test-results-pvc
          restartPolicy: OnFailure
EOF
    
    # Security testing CronJob
    kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: automated-security-testing
  namespace: $NAMESPACE
spec:
  schedule: "0 3 * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 7
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: security-test-runner
            image: owasp/zap2docker-stable:latest
            command: ["zap-baseline.py", "-t", "https://ms5floor.com", "-r", "/results/zap-report.html"]
            resources:
              requests:
                memory: "1Gi"
                cpu: "500m"
              limits:
                memory: "2Gi"
                cpu: "1000m"
            volumeMounts:
            - name: test-results
              mountPath: /results
          volumes:
          - name: test-results
            persistentVolumeClaim:
              claimName: test-results-pvc
          restartPolicy: OnFailure
EOF
    
    # Disaster recovery testing CronJob
    kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: automated-disaster-recovery-testing
  namespace: $NAMESPACE
spec:
  schedule: "0 4 * * 0"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 4
  failedJobsHistoryLimit: 2
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: disaster-recovery-test-runner
            image: postgres:15
            command: ["/bin/bash", "/scripts/disaster-recovery-test.sh"]
            env:
            - name: NAMESPACE
              value: "$PRODUCTION_NAMESPACE"
            - name: TEST_NAMESPACE
              value: "$NAMESPACE"
            resources:
              requests:
                memory: "512Mi"
                cpu: "250m"
              limits:
                memory: "1Gi"
                cpu: "500m"
            volumeMounts:
            - name: test-scripts
              mountPath: /scripts
            - name: test-results
              mountPath: /results
          volumes:
          - name: test-scripts
            configMap:
              name: disaster-recovery-test-config
              defaultMode: 0755
          - name: test-results
            persistentVolumeClaim:
              claimName: test-results-pvc
          restartPolicy: OnFailure
EOF
    
    log_success "Automated testing CronJobs deployed"
}

# Validate deployment
validate_deployment() {
    log_info "Validating Phase 8A deployment..."
    
    # Check namespace
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        error_exit "Testing namespace not found"
    fi
    
    # Check pods
    local pod_count
    pod_count=$(kubectl get pods -n "$NAMESPACE" --no-headers | wc -l)
    if [ "$pod_count" -eq 0 ]; then
        error_exit "No testing pods found"
    fi
    
    # Check services
    local service_count
    service_count=$(kubectl get services -n "$NAMESPACE" --no-headers | wc -l)
    if [ "$service_count" -eq 0 ]; then
        error_exit "No testing services found"
    fi
    
    # Check CronJobs
    local cronjob_count
    cronjob_count=$(kubectl get cronjobs -n "$NAMESPACE" --no-headers | wc -l)
    if [ "$cronjob_count" -eq 0 ]; then
        error_exit "No testing CronJobs found"
    fi
    
    # Check PVC
    if ! kubectl get pvc test-results-pvc -n "$NAMESPACE" &> /dev/null; then
        error_exit "Test results PVC not found"
    fi
    
    log_success "Phase 8A deployment validation passed"
}

# Run initial tests
run_initial_tests() {
    log_info "Running initial tests to validate testing infrastructure..."
    
    # Test performance testing infrastructure
    log_info "Testing performance testing infrastructure..."
    kubectl exec -n "$NAMESPACE" deployment/k6-load-tester -- k6 version || log_warning "k6 version check failed"
    kubectl exec -n "$NAMESPACE" deployment/artillery-load-tester -- artillery --version || log_warning "Artillery version check failed"
    
    # Test security testing infrastructure
    log_info "Testing security testing infrastructure..."
    kubectl exec -n "$NAMESPACE" deployment/owasp-zap-scanner -- curl -f http://localhost:8080/JSON/core/view/version/ || log_warning "OWASP ZAP health check failed"
    kubectl exec -n "$NAMESPACE" deployment/trivy-scanner -- trivy --version || log_warning "Trivy version check failed"
    
    # Test disaster recovery testing infrastructure
    log_info "Testing disaster recovery testing infrastructure..."
    kubectl exec -n "$NAMESPACE" deployment/litmus-chaos-engine -- litmus version || log_warning "Litmus version check failed"
    kubectl exec -n "$NAMESPACE" deployment/backup-recovery-tester -- pg_dump --version || log_warning "PostgreSQL version check failed"
    
    log_success "Initial tests completed"
}

# Generate deployment report
generate_deployment_report() {
    log_info "Generating Phase 8A deployment report..."
    
    local report_file="/tmp/phase8a-deployment-report.md"
    
    cat > "$report_file" << EOF
# MS5.0 Floor Dashboard - Phase 8A Deployment Report

## Deployment Summary
- **Deployment Date**: $(date)
- **Namespace**: $NAMESPACE
- **Production Namespace**: $PRODUCTION_NAMESPACE
- **Deployment Status**: SUCCESS

## Deployed Components

### Performance Testing Infrastructure
- **k6 Load Tester**: $(kubectl get pods -n "$NAMESPACE" -l testing-tool=k6 --no-headers | wc -l) pods
- **Artillery Load Tester**: $(kubectl get pods -n "$NAMESPACE" -l testing-tool=artillery --no-headers | wc -l) pods
- **Performance Monitoring**: $(kubectl get services -n "$NAMESPACE" -l testing-type=performance-monitoring --no-headers | wc -l) services

### Security Testing Infrastructure
- **OWASP ZAP Scanner**: $(kubectl get pods -n "$NAMESPACE" -l testing-tool=owasp-zap --no-headers | wc -l) pods
- **Trivy Scanner**: $(kubectl get pods -n "$NAMESPACE" -l testing-tool=trivy --no-headers | wc -l) pods
- **Falco Runtime Security**: $(kubectl get pods -n "$NAMESPACE" -l testing-tool=falco --no-headers | wc -l) pods

### Disaster Recovery Testing Infrastructure
- **Litmus Chaos Engine**: $(kubectl get pods -n "$NAMESPACE" -l testing-tool=litmus --no-headers | wc -l) pods
- **Backup Recovery Tester**: $(kubectl get pods -n "$NAMESPACE" -l testing-tool=backup-recovery --no-headers | wc -l) pods

### Automated Testing
- **Performance Testing CronJob**: $(kubectl get cronjobs -n "$NAMESPACE" -l testing-type=automated-performance --no-headers | wc -l) jobs
- **Security Testing CronJob**: $(kubectl get cronjobs -n "$NAMESPACE" -l testing-type=automated-security --no-headers | wc -l) jobs
- **Disaster Recovery Testing CronJob**: $(kubectl get cronjobs -n "$NAMESPACE" -l testing-type=automated-disaster-recovery --no-headers | wc -l) jobs

## Network Policies
- **Testing Network Policy**: $(kubectl get networkpolicies -n "$NAMESPACE" --no-headers | wc -l) policies

## Storage
- **Test Results PVC**: $(kubectl get pvc -n "$NAMESPACE" --no-headers | wc -l) claims

## Next Steps
1. Run comprehensive performance testing
2. Execute security validation procedures
3. Perform disaster recovery testing
4. Validate all success criteria
5. Generate final testing report

## Access Information
- **Namespace**: $NAMESPACE
- **Log File**: $LOG_FILE
- **Report File**: $report_file

EOF
    
    log_success "Deployment report generated: $report_file"
}

# Main deployment function
main() {
    log_info "Starting Phase 8A: Core Testing & Performance Validation deployment"
    
    # Check prerequisites
    check_prerequisites
    
    # Create testing namespace
    create_testing_namespace
    
    # Create test results PVC
    create_test_results_pvc
    
    # Deploy testing infrastructure
    deploy_performance_testing
    deploy_security_testing
    deploy_disaster_recovery_testing
    
    # Configure network policies
    configure_network_policies
    
    # Deploy automated testing
    deploy_automated_testing
    
    # Validate deployment
    validate_deployment
    
    # Run initial tests
    run_initial_tests
    
    # Generate deployment report
    generate_deployment_report
    
    log_success "Phase 8A deployment completed successfully"
    log_info "Testing infrastructure is ready for comprehensive validation"
}

# Run main function
main "$@"
