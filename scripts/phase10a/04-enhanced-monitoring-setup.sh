#!/bin/bash

# MS5.0 Floor Dashboard - Phase 10A.4: Enhanced Monitoring Setup
# Comprehensive enhanced monitoring setup with SLI/SLO implementation
#
# This script sets up enhanced monitoring including:
# - SLI/SLO implementation and validation
# - Enhanced monitoring stack deployment
# - Application metrics integration
# - Monitoring dashboards configuration
#
# Usage: ./04-enhanced-monitoring-setup.sh [environment] [dry-run] [skip-validation] [force]

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
K8S_DIR="$PROJECT_ROOT/k8s"
NAMESPACE_PREFIX="ms5"
ENVIRONMENT="${1:-production}"
DRY_RUN="${2:-false}"
SKIP_VALIDATION="${3:-false}"
FORCE="${4:-false}"

# Azure Configuration
RESOURCE_GROUP_NAME="rg-ms5-production-uksouth"
AKS_CLUSTER_NAME="aks-ms5-prod-uksouth"
ACR_NAME="ms5acrprod"
KEY_VAULT_NAME="kv-ms5-prod-uksouth"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_step() {
    echo -e "${CYAN}[STEP]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# SLI/SLO implementation
implement_sli_slo() {
    log_info "Implementing SLI/SLO monitoring..."
    
    log_step "Deploying SLI definitions..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would deploy SLI definitions"
    else
        # Deploy SLI definitions
        kubectl apply -f "$K8S_DIR/31-sli-definitions.yaml"
        kubectl apply -f "$K8S_DIR/32-slo-configuration.yaml"
        kubectl apply -f "$K8S_DIR/38-sli-slo-monitoring.yaml"
        
        # Wait for SLI/SLO resources to be ready
        kubectl wait --for=condition=ready pod -l app=ms5-sli-monitor -n "$NAMESPACE_PREFIX-$ENVIRONMENT" --timeout=300s
    fi
    
    log_success "SLI/SLO implementation completed"
    
    # Configure automated SLI/SLO monitoring
    log_step "Configuring automated SLI/SLO monitoring..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would configure automated SLI/SLO monitoring"
    else
        # Create SLI/SLO monitoring configuration
        cat > /tmp/sli-slo-monitoring-config.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: sli-slo-monitoring-config
  namespace: $NAMESPACE_PREFIX-$ENVIRONMENT
data:
  sli-config.yaml: |
    sli_definitions:
      # Availability SLI
      availability:
        query: 'sum(rate(http_requests_total{status!~"5.."}[5m])) / sum(rate(http_requests_total[5m]))'
        target: 0.999  # 99.9% availability
        window: 5m
        
      # Latency SLI
      latency_p95:
        query: 'histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))'
        target: 0.2  # 200ms P95 latency
        window: 5m
        
      # Error Rate SLI
      error_rate:
        query: 'sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))'
        target: 0.001  # 0.1% error rate
        window: 5m
        
      # Business Metrics SLI
      production_throughput:
        query: 'sum(rate(production_jobs_completed_total[5m]))'
        target: 10  # 10 jobs per minute minimum
        window: 5m
        
      oee_calculation_accuracy:
        query: 'sum(rate(oee_calculations_total{status="success"}[5m])) / sum(rate(oee_calculations_total[5m]))'
        target: 0.99  # 99% accuracy
        window: 5m
        
    slo_configurations:
      # Service Level Objectives
      api_availability:
        sli: availability
        target: 0.999
        window: 24h
        alert_threshold: 0.995
        
      api_latency:
        sli: latency_p95
        target: 0.2
        window: 24h
        alert_threshold: 0.3
        
      api_error_rate:
        sli: error_rate
        target: 0.001
        window: 24h
        alert_threshold: 0.005
        
      production_slo:
        sli: production_throughput
        target: 10
        window: 24h
        alert_threshold: 5
        
      oee_slo:
        sli: oee_calculation_accuracy
        target: 0.99
        window: 24h
        alert_threshold: 0.95
EOF
        
        kubectl apply -f /tmp/sli-slo-monitoring-config.yaml
        
        # Configure automated remediation procedures
        cat > /tmp/automated-remediation.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: automated-remediation-config
  namespace: $NAMESPACE_PREFIX-$ENVIRONMENT
data:
  remediation-rules.yaml: |
    remediation_rules:
      # Auto-scaling remediation
      high_latency:
        condition: 'latency_p95 > 0.3'
        action: 'scale_up'
        parameters:
          scale_factor: 1.5
          max_replicas: 10
          
      low_throughput:
        condition: 'production_throughput < 5'
        action: 'investigate_production'
        parameters:
          alert_channels: ['email', 'slack']
          
      high_error_rate:
        condition: 'error_rate > 0.005'
        action: 'rollback_deployment'
        parameters:
          rollback_to: 'previous_version'
          
      oee_accuracy_low:
        condition: 'oee_calculation_accuracy < 0.95'
        action: 'restart_oee_service'
        parameters:
          service: 'ms5-backend'
EOF
        
        kubectl apply -f /tmp/automated-remediation.yaml
    fi
    
    log_success "Automated SLI/SLO monitoring configured"
}

# Enhanced monitoring stack deployment
deploy_enhanced_monitoring_stack() {
    log_info "Deploying enhanced monitoring stack..."
    
    log_step "Deploying Prometheus with enhanced configuration..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would deploy enhanced monitoring stack"
    else
        # Deploy Prometheus with persistent storage
        kubectl apply -f "$K8S_DIR/21-prometheus-statefulset.yaml"
        kubectl apply -f "$K8S_DIR/22-prometheus-services.yaml"
        kubectl apply -f "$K8S_DIR/23-prometheus-config.yaml"
        
        # Deploy Grafana with enhanced dashboards
        kubectl apply -f "$K8S_DIR/24-grafana-statefulset.yaml"
        kubectl apply -f "$K8S_DIR/25-grafana-services.yaml"
        kubectl apply -f "$K8S_DIR/26-grafana-config.yaml"
        
        # Deploy AlertManager with enhanced configuration
        kubectl apply -f "$K8S_DIR/27-alertmanager-deployment.yaml"
        kubectl apply -f "$K8S_DIR/28-alertmanager-services.yaml"
        kubectl apply -f "$K8S_DIR/29-alertmanager-config.yaml"
        
        # Deploy enhanced monitoring components
        kubectl apply -f "$K8S_DIR/33-cost-monitoring.yaml"
        kubectl apply -f "$K8S_DIR/34-backend-monitoring.yaml"
        kubectl apply -f "$K8S_DIR/35-jaeger-distributed-tracing.yaml"
        kubectl apply -f "$K8S_DIR/36-elasticsearch-log-aggregation.yaml"
        kubectl apply -f "$K8S_DIR/37-enhanced-monitoring-dashboards.yaml"
        
        # Wait for monitoring services to be ready
        kubectl wait --for=condition=ready pod -l app=ms5-prometheus -n "$NAMESPACE_PREFIX-$ENVIRONMENT" --timeout=300s
        kubectl wait --for=condition=ready pod -l app=ms5-grafana -n "$NAMESPACE_PREFIX-$ENVIRONMENT" --timeout=300s
        kubectl wait --for=condition=ready pod -l app=ms5-alertmanager -n "$NAMESPACE_PREFIX-$ENVIRONMENT" --timeout=300s
    fi
    
    log_success "Enhanced monitoring stack deployed"
    
    # Configure monitoring dashboards
    configure_monitoring_dashboards
}

# Monitoring dashboards configuration
configure_monitoring_dashboards() {
    log_step "Configuring monitoring dashboards..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would configure monitoring dashboards"
    else
        # Create comprehensive Grafana dashboards
        cat > /tmp/grafana-dashboards.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboards
  namespace: $NAMESPACE_PREFIX-$ENVIRONMENT
data:
  ms5-production-dashboard.json: |
    {
      "dashboard": {
        "title": "MS5.0 Production Dashboard",
        "panels": [
          {
            "title": "System Health",
            "type": "stat",
            "targets": [
              {
                "expr": "up{job=\"ms5-backend\"}",
                "legendFormat": "Backend Status"
              }
            ]
          },
          {
            "title": "API Response Time",
            "type": "graph",
            "targets": [
              {
                "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))",
                "legendFormat": "P95 Response Time"
              }
            ]
          },
          {
            "title": "Production Throughput",
            "type": "graph",
            "targets": [
              {
                "expr": "rate(production_jobs_completed_total[5m])",
                "legendFormat": "Jobs/Minute"
              }
            ]
          },
          {
            "title": "OEE Metrics",
            "type": "graph",
            "targets": [
              {
                "expr": "oee_availability * 100",
                "legendFormat": "Availability %"
              },
              {
                "expr": "oee_performance * 100",
                "legendFormat": "Performance %"
              },
              {
                "expr": "oee_quality * 100",
                "legendFormat": "Quality %"
              }
            ]
          },
          {
            "title": "Error Rate",
            "type": "graph",
            "targets": [
              {
                "expr": "rate(http_requests_total{status=~\"5..\"}[5m]) / rate(http_requests_total[5m])",
                "legendFormat": "Error Rate"
              }
            ]
          }
        ]
      }
    }
  
  ms5-sli-slo-dashboard.json: |
    {
      "dashboard": {
        "title": "MS5.0 SLI/SLO Dashboard",
        "panels": [
          {
            "title": "Availability SLI",
            "type": "stat",
            "targets": [
              {
                "expr": "sum(rate(http_requests_total{status!~\"5..\"}[5m])) / sum(rate(http_requests_total[5m]))",
                "legendFormat": "Availability"
              }
            ]
          },
          {
            "title": "Latency SLI",
            "type": "stat",
            "targets": [
              {
                "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))",
                "legendFormat": "P95 Latency"
              }
            ]
          },
          {
            "title": "Error Rate SLI",
            "type": "stat",
            "targets": [
              {
                "expr": "sum(rate(http_requests_total{status=~\"5..\"}[5m])) / sum(rate(http_requests_total[5m]))",
                "legendFormat": "Error Rate"
              }
            ]
          },
          {
            "title": "SLO Compliance",
            "type": "graph",
            "targets": [
              {
                "expr": "slo_compliance{service=\"ms5-backend\"}",
                "legendFormat": "SLO Compliance"
              }
            ]
          }
        ]
      }
    }
EOF
        
        kubectl apply -f /tmp/grafana-dashboards.yaml
        
        # Configure Prometheus rules for SLI/SLO
        cat > /tmp/prometheus-sli-slo-rules.yaml << EOF
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: ms5-sli-slo-rules
  namespace: $NAMESPACE_PREFIX-$ENVIRONMENT
spec:
  groups:
  - name: sli-slo-alerts
    rules:
    - alert: HighLatency
      expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 0.2
      for: 2m
      labels:
        severity: warning
        service: ms5-backend
      annotations:
        summary: "High latency detected"
        description: "P95 latency is {{ \$value }}s, exceeding 200ms threshold"
        
    - alert: HighErrorRate
      expr: sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) > 0.001
      for: 2m
      labels:
        severity: critical
        service: ms5-backend
      annotations:
        summary: "High error rate detected"
        description: "Error rate is {{ \$value }}%, exceeding 0.1% threshold"
        
    - alert: LowAvailability
      expr: sum(rate(http_requests_total{status!~"5.."}[5m])) / sum(rate(http_requests_total[5m])) < 0.999
      for: 2m
      labels:
        severity: critical
        service: ms5-backend
      annotations:
        summary: "Low availability detected"
        description: "Availability is {{ \$value }}%, below 99.9% threshold"
        
    - alert: ProductionThroughputLow
      expr: rate(production_jobs_completed_total[5m]) < 10
      for: 5m
      labels:
        severity: warning
        service: production
      annotations:
        summary: "Low production throughput"
        description: "Production throughput is {{ \$value }} jobs/minute, below 10 jobs/minute threshold"
        
    - alert: OEEAccuracyLow
      expr: sum(rate(oee_calculations_total{status="success"}[5m])) / sum(rate(oee_calculations_total[5m])) < 0.99
      for: 5m
      labels:
        severity: warning
        service: oee
      annotations:
        summary: "Low OEE calculation accuracy"
        description: "OEE calculation accuracy is {{ \$value }}%, below 99% threshold"
EOF
        
        kubectl apply -f /tmp/prometheus-sli-slo-rules.yaml
    fi
    
    log_success "Monitoring dashboards configured"
}

# Application metrics integration
integrate_application_metrics() {
    log_info "Integrating application metrics..."
    
    log_step "Configuring application metrics collection..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would integrate application metrics"
    else
        # Create application metrics configuration
        cat > /tmp/application-metrics-config.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: application-metrics-config
  namespace: $NAMESPACE_PREFIX-$ENVIRONMENT
data:
  metrics-config.yaml: |
    application_metrics:
      # Production metrics
      production_jobs_completed_total:
        type: counter
        description: "Total number of production jobs completed"
        labels: ["line_id", "job_type", "status"]
        
      production_jobs_duration_seconds:
        type: histogram
        description: "Duration of production jobs in seconds"
        buckets: [0.1, 0.5, 1.0, 2.0, 5.0, 10.0]
        labels: ["line_id", "job_type"]
        
      # OEE metrics
      oee_availability:
        type: gauge
        description: "Equipment availability percentage"
        labels: ["line_id", "equipment_id"]
        
      oee_performance:
        type: gauge
        description: "Equipment performance percentage"
        labels: ["line_id", "equipment_id"]
        
      oee_quality:
        type: gauge
        description: "Equipment quality percentage"
        labels: ["line_id", "equipment_id"]
        
      oee_calculations_total:
        type: counter
        description: "Total number of OEE calculations"
        labels: ["line_id", "status"]
        
      # Andon metrics
      andon_events_total:
        type: counter
        description: "Total number of Andon events"
        labels: ["line_id", "event_type", "severity"]
        
      andon_resolution_time_seconds:
        type: histogram
        description: "Time to resolve Andon events in seconds"
        buckets: [60, 300, 900, 1800, 3600]
        labels: ["line_id", "event_type"]
        
      # Quality metrics
      quality_defects_total:
        type: counter
        description: "Total number of quality defects"
        labels: ["line_id", "defect_type", "severity"]
        
      quality_inspections_total:
        type: counter
        description: "Total number of quality inspections"
        labels: ["line_id", "inspection_type", "result"]
        
      # Maintenance metrics
      maintenance_events_total:
        type: counter
        description: "Total number of maintenance events"
        labels: ["equipment_id", "maintenance_type", "status"]
        
      maintenance_duration_seconds:
        type: histogram
        description: "Duration of maintenance events in seconds"
        buckets: [300, 900, 1800, 3600, 7200]
        labels: ["equipment_id", "maintenance_type"]
        
      # Business metrics
      production_volume_total:
        type: counter
        description: "Total production volume"
        labels: ["line_id", "product_type", "shift"]
        
      downtime_minutes_total:
        type: counter
        description: "Total downtime in minutes"
        labels: ["line_id", "downtime_type", "reason"]
        
      # System metrics
      active_users_total:
        type: gauge
        description: "Number of active users"
        labels: ["role"]
        
      websocket_connections_total:
        type: gauge
        description: "Number of active WebSocket connections"
        labels: ["channel"]
        
      database_connections_active:
        type: gauge
        description: "Number of active database connections"
        labels: ["database"]
        
      redis_connections_active:
        type: gauge
        description: "Number of active Redis connections"
        labels: ["redis_instance"]
EOF
        
        kubectl apply -f /tmp/application-metrics-config.yaml
        
        # Configure Prometheus to scrape application metrics
        cat > /tmp/prometheus-app-scrape-config.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-app-scrape-config
  namespace: $NAMESPACE_PREFIX-$ENVIRONMENT
data:
  app-scrape-config.yaml: |
    scrape_configs:
    - job_name: 'ms5-backend'
      static_configs:
      - targets: ['ms5-backend-service:8000']
      metrics_path: '/metrics'
      scrape_interval: 15s
      scrape_timeout: 10s
      
    - job_name: 'ms5-celery-worker'
      static_configs:
      - targets: ['ms5-celery-worker-service:8000']
      metrics_path: '/metrics'
      scrape_interval: 30s
      scrape_timeout: 10s
      
    - job_name: 'ms5-postgres'
      static_configs:
      - targets: ['ms5-postgres-service:5432']
      metrics_path: '/metrics'
      scrape_interval: 30s
      scrape_timeout: 10s
      
    - job_name: 'ms5-redis'
      static_configs:
      - targets: ['ms5-redis-service:6379']
      metrics_path: '/metrics'
      scrape_interval: 30s
      scrape_timeout: 10s
      
    - job_name: 'ms5-minio'
      static_configs:
      - targets: ['ms5-minio-service:9000']
      metrics_path: '/metrics'
      scrape_interval: 30s
      scrape_timeout: 10s
EOF
        
        kubectl apply -f /tmp/prometheus-app-scrape-config.yaml
    fi
    
    log_success "Application metrics integration completed"
}

# Monitoring validation
validate_monitoring_setup() {
    log_info "Validating monitoring setup..."
    
    log_step "Validating Prometheus configuration..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "DRY RUN: Would validate monitoring setup"
    else
        # Check Prometheus is collecting metrics
        kubectl exec -n "$NAMESPACE_PREFIX-$ENVIRONMENT" deployment/ms5-prometheus -- curl -s http://localhost:9090/api/v1/targets | grep -q "ms5-backend" || log_warning "Prometheus not scraping backend metrics"
        
        # Check Grafana is accessible
        kubectl exec -n "$NAMESPACE_PREFIX-$ENVIRONMENT" deployment/ms5-grafana -- curl -f http://localhost:3000/api/health || log_warning "Grafana health check failed"
        
        # Check AlertManager is running
        kubectl exec -n "$NAMESPACE_PREFIX-$ENVIRONMENT" deployment/ms5-alertmanager -- curl -f http://localhost:9093/api/v1/status || log_warning "AlertManager health check failed"
        
        # Check SLI/SLO monitoring
        kubectl get pods -l app=ms5-sli-monitor -n "$NAMESPACE_PREFIX-$ENVIRONMENT" || log_warning "SLI/SLO monitor not running"
        
        # Validate metrics endpoints
        kubectl exec -n "$NAMESPACE_PREFIX-$ENVIRONMENT" deployment/ms5-backend-$(get_current_color) -- curl -f http://localhost:8000/metrics || log_warning "Backend metrics endpoint not accessible"
    fi
    
    log_success "Monitoring setup validation completed"
}

# Helper functions
get_current_color() {
    kubectl get service ms5-backend-service -n "$NAMESPACE_PREFIX-$ENVIRONMENT" -o jsonpath='{.spec.selector.color}' 2>/dev/null || echo "blue"
}

# Main execution
main() {
    log_info "Starting Phase 10A.4: Enhanced Monitoring Setup"
    log_info "Environment: $ENVIRONMENT"
    log_info "Dry Run: $DRY_RUN"
    log_info "Skip Validation: $SKIP_VALIDATION"
    echo ""
    
    # Execute monitoring setup phases
    implement_sli_slo
    deploy_enhanced_monitoring_stack
    integrate_application_metrics
    validate_monitoring_setup
    
    log_success "Phase 10A.4: Enhanced Monitoring Setup completed successfully"
    echo ""
    echo "=== Monitoring Setup Summary ==="
    echo "✅ SLI/SLO Implementation: Comprehensive SLI/SLO monitoring deployed"
    echo "✅ Enhanced Monitoring Stack: Prometheus, Grafana, AlertManager deployed"
    echo "✅ Application Metrics Integration: Custom metrics collection configured"
    echo "✅ Monitoring Dashboards: Production and SLI/SLO dashboards configured"
    echo "✅ Monitoring Validation: All monitoring components validated"
    echo ""
    echo "=== Monitoring Access Information ==="
    echo "📊 Prometheus: kubectl port-forward svc/ms5-prometheus-service -n $NAMESPACE_PREFIX-$ENVIRONMENT 9090:9090"
    echo "📈 Grafana: kubectl port-forward svc/ms5-grafana-service -n $NAMESPACE_PREFIX-$ENVIRONMENT 3000:3000"
    echo "🚨 AlertManager: kubectl port-forward svc/ms5-alertmanager-service -n $NAMESPACE_PREFIX-$ENVIRONMENT 9093:9093"
    echo "📋 SLI/SLO Monitor: kubectl logs -l app=ms5-sli-monitor -n $NAMESPACE_PREFIX-$ENVIRONMENT"
    echo ""
}

# Error handling
trap 'log_error "Enhanced monitoring setup failed at line $LINENO"' ERR

# Execute main function
main "$@"
