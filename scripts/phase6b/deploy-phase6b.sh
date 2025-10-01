#!/bin/bash

# MS5.0 Floor Dashboard - Phase 6B: Advanced Monitoring and Observability Deployment
# Comprehensive deployment script for enhanced monitoring capabilities

set -euo pipefail

# Configuration
NAMESPACE="ms5-production"
LOGGING_NAMESPACE="logging"
JAEGER_NAMESPACE="jaeger"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if we can connect to the cluster
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Check if namespaces exist
    if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
        log_error "Namespace $NAMESPACE does not exist"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Deploy enhanced application metrics
deploy_enhanced_metrics() {
    log_info "Deploying enhanced application metrics..."
    
    # Copy enhanced metrics to backend pod
    kubectl cp "$PROJECT_ROOT/backend/monitoring/aks_application_metrics.py" \
        "$NAMESPACE/$(kubectl get pods -l app=ms5-dashboard,component=backend -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}'):/app/monitoring/aks_application_metrics.py"
    
    log_success "Enhanced application metrics deployed"
}

# Deploy Jaeger distributed tracing
deploy_jaeger() {
    log_info "Deploying Jaeger distributed tracing..."
    
    # Create Jaeger namespace if it doesn't exist
    kubectl create namespace "$JAEGER_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy Jaeger components
    kubectl apply -f "$PROJECT_ROOT/k8s/35-jaeger-distributed-tracing.yaml"
    
    # Wait for Jaeger to be ready
    log_info "Waiting for Jaeger to be ready..."
    kubectl wait --for=condition=ready pod -l app=ms5-dashboard,component=tracing -n "$JAEGER_NAMESPACE" --timeout=300s
    
    log_success "Jaeger distributed tracing deployed"
}

# Deploy ELK stack for log aggregation
deploy_elk_stack() {
    log_info "Deploying ELK stack for log aggregation..."
    
    # Create logging namespace if it doesn't exist
    kubectl create namespace "$LOGGING_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    
    # Deploy ELK stack components
    kubectl apply -f "$PROJECT_ROOT/k8s/36-elasticsearch-log-aggregation.yaml"
    
    # Wait for Elasticsearch to be ready
    log_info "Waiting for Elasticsearch to be ready..."
    kubectl wait --for=condition=ready pod -l app=ms5-dashboard,component=logging,service=elasticsearch -n "$LOGGING_NAMESPACE" --timeout=600s
    
    # Wait for Logstash to be ready
    log_info "Waiting for Logstash to be ready..."
    kubectl wait --for=condition=ready pod -l app=ms5-dashboard,component=logging,service=logstash -n "$LOGGING_NAMESPACE" --timeout=300s
    
    # Wait for Kibana to be ready
    log_info "Waiting for Kibana to be ready..."
    kubectl wait --for=condition=ready pod -l app=ms5-dashboard,component=logging,service=kibana -n "$LOGGING_NAMESPACE" --timeout=300s
    
    # Wait for Filebeat to be ready
    log_info "Waiting for Filebeat to be ready..."
    kubectl wait --for=condition=ready pod -l app=ms5-dashboard,component=logging,service=filebeat -n "$LOGGING_NAMESPACE" --timeout=300s
    
    log_success "ELK stack deployed"
}

# Deploy enhanced monitoring dashboards
deploy_enhanced_dashboards() {
    log_info "Deploying enhanced monitoring dashboards..."
    
    # Deploy enhanced dashboards
    kubectl apply -f "$PROJECT_ROOT/k8s/37-enhanced-monitoring-dashboards.yaml"
    
    # Restart Grafana to load new dashboards
    kubectl rollout restart deployment/grafana -n "$NAMESPACE"
    
    # Wait for Grafana to be ready
    log_info "Waiting for Grafana to be ready..."
    kubectl wait --for=condition=ready pod -l app=ms5-dashboard,component=grafana -n "$NAMESPACE" --timeout=300s
    
    log_success "Enhanced monitoring dashboards deployed"
}

# Deploy SLI/SLO monitoring
deploy_sli_slo_monitoring() {
    log_info "Deploying SLI/SLO monitoring..."
    
    # Deploy SLI/SLO monitoring components
    kubectl apply -f "$PROJECT_ROOT/k8s/38-sli-slo-monitoring.yaml"
    
    # Wait for SLI/SLO calculator to be ready
    log_info "Waiting for SLI/SLO calculator to be ready..."
    kubectl wait --for=condition=ready pod -l app=ms5-dashboard,component=monitoring,service=sli-slo-calculator -n "$NAMESPACE" --timeout=300s
    
    log_success "SLI/SLO monitoring deployed"
}

# Configure OpenTelemetry integration
configure_opentelemetry() {
    log_info "Configuring OpenTelemetry integration..."
    
    # Create OpenTelemetry configuration
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: opentelemetry-config
  namespace: $NAMESPACE
  labels:
    app: ms5-dashboard
    component: tracing
data:
  otel-config.yaml: |
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318
    
    processors:
      batch:
        timeout: 1s
        send_batch_size: 1024
      memory_limiter:
        limit_mib: 512
    
    exporters:
      jaeger:
        endpoint: jaeger-collector.$JAEGER_NAMESPACE.svc.cluster.local:14250
        tls:
          insecure: true
      prometheus:
        endpoint: "0.0.0.0:8889"
    
    service:
      pipelines:
        traces:
          receivers: [otlp]
          processors: [memory_limiter, batch]
          exporters: [jaeger]
        metrics:
          receivers: [otlp]
          processors: [memory_limiter, batch]
          exporters: [prometheus]
EOF
    
    log_success "OpenTelemetry integration configured"
}

# Update backend service with tracing
update_backend_tracing() {
    log_info "Updating backend service with distributed tracing..."
    
    # Create backend tracing configuration
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: backend-tracing-config
  namespace: $NAMESPACE
  labels:
    app: ms5-dashboard
    component: backend
data:
  tracing.py: |
    # OpenTelemetry tracing configuration for MS5.0 backend
    from opentelemetry import trace
    from opentelemetry.exporter.jaeger.thrift import JaegerExporter
    from opentelemetry.sdk.trace import TracerProvider
    from opentelemetry.sdk.trace.export import BatchSpanProcessor
    from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
    from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
    from opentelemetry.instrumentation.redis import RedisInstrumentor
    
    # Configure OpenTelemetry
    trace.set_tracer_provider(TracerProvider())
    tracer = trace.get_tracer(__name__)
    
    # Configure Jaeger exporter
    jaeger_exporter = JaegerExporter(
        agent_host_name="jaeger-agent.$JAEGER_NAMESPACE.svc.cluster.local",
        agent_port=14268,
    )
    
    # Add span processor
    span_processor = BatchSpanProcessor(jaeger_exporter)
    trace.get_tracer_provider().add_span_processor(span_processor)
    
    # Instrument FastAPI
    FastAPIInstrumentor.instrument_app(app)
    
    # Instrument SQLAlchemy
    SQLAlchemyInstrumentor().instrument()
    
    # Instrument Redis
    RedisInstrumentor().instrument()
EOF
    
    # Update backend deployment to include tracing
    kubectl patch deployment ms5-backend -n "$NAMESPACE" -p '{
        "spec": {
            "template": {
                "spec": {
                    "containers": [
                        {
                            "name": "ms5-backend",
                            "env": [
                                {
                                    "name": "OTEL_EXPORTER_JAEGER_ENDPOINT",
                                    "value": "http://jaeger-agent.'$JAEGER_NAMESPACE'.svc.cluster.local:14268"
                                },
                                {
                                    "name": "OTEL_SERVICE_NAME",
                                    "value": "ms5-backend"
                                },
                                {
                                    "name": "OTEL_RESOURCE_ATTRIBUTES",
                                    "value": "service.name=ms5-backend,service.namespace='$NAMESPACE'"
                                }
                            ]
                        }
                    ]
                }
            }
        }
    }'
    
    # Restart backend to apply tracing configuration
    kubectl rollout restart deployment/ms5-backend -n "$NAMESPACE"
    
    # Wait for backend to be ready
    log_info "Waiting for backend to be ready..."
    kubectl wait --for=condition=ready pod -l app=ms5-dashboard,component=backend -n "$NAMESPACE" --timeout=300s
    
    log_success "Backend service updated with distributed tracing"
}

# Validate deployment
validate_deployment() {
    log_info "Validating Phase 6B deployment..."
    
    # Check Jaeger
    if kubectl get pods -l app=ms5-dashboard,component=tracing -n "$JAEGER_NAMESPACE" | grep -q "Running"; then
        log_success "Jaeger is running"
    else
        log_error "Jaeger is not running"
        return 1
    fi
    
    # Check ELK stack
    if kubectl get pods -l app=ms5-dashboard,component=logging -n "$LOGGING_NAMESPACE" | grep -q "Running"; then
        log_success "ELK stack is running"
    else
        log_error "ELK stack is not running"
        return 1
    fi
    
    # Check enhanced dashboards
    if kubectl get configmap grafana-dashboards-enhanced -n "$NAMESPACE" &> /dev/null; then
        log_success "Enhanced dashboards are configured"
    else
        log_error "Enhanced dashboards are not configured"
        return 1
    fi
    
    # Check SLI/SLO monitoring
    if kubectl get pods -l app=ms5-dashboard,component=monitoring,service=sli-slo-calculator -n "$NAMESPACE" | grep -q "Running"; then
        log_success "SLI/SLO monitoring is running"
    else
        log_error "SLI/SLO monitoring is not running"
        return 1
    fi
    
    # Check backend tracing
    if kubectl get configmap backend-tracing-config -n "$NAMESPACE" &> /dev/null; then
        log_success "Backend tracing is configured"
    else
        log_error "Backend tracing is not configured"
        return 1
    fi
    
    log_success "Phase 6B deployment validation passed"
}

# Test monitoring endpoints
test_monitoring_endpoints() {
    log_info "Testing monitoring endpoints..."
    
    # Test Jaeger UI
    JAEGER_POD=$(kubectl get pods -l app=ms5-dashboard,component=tracing,service=jaeger-query -n "$JAEGER_NAMESPACE" -o jsonpath='{.items[0].metadata.name}')
    if kubectl exec "$JAEGER_POD" -n "$JAEGER_NAMESPACE" -- curl -s http://localhost:16686/api/services &> /dev/null; then
        log_success "Jaeger UI is accessible"
    else
        log_warning "Jaeger UI is not accessible"
    fi
    
    # Test Kibana
    KIBANA_POD=$(kubectl get pods -l app=ms5-dashboard,component=logging,service=kibana -n "$LOGGING_NAMESPACE" -o jsonpath='{.items[0].metadata.name}')
    if kubectl exec "$KIBANA_POD" -n "$LOGGING_NAMESPACE" -- curl -s http://localhost:5601/api/status &> /dev/null; then
        log_success "Kibana is accessible"
    else
        log_warning "Kibana is not accessible"
    fi
    
    # Test SLI/SLO calculator
    SLI_POD=$(kubectl get pods -l app=ms5-dashboard,component=monitoring,service=sli-slo-calculator -n "$NAMESPACE" -o jsonpath='{.items[0].metadata.name}')
    if kubectl exec "$SLI_POD" -n "$NAMESPACE" -- curl -s http://localhost:8080/health &> /dev/null; then
        log_success "SLI/SLO calculator is accessible"
    else
        log_warning "SLI/SLO calculator is not accessible"
    fi
    
    log_success "Monitoring endpoints testing completed"
}

# Main deployment function
main() {
    log_info "Starting Phase 6B: Advanced Monitoring and Observability deployment"
    
    # Check prerequisites
    check_prerequisites
    
    # Deploy components in order
    deploy_enhanced_metrics
    deploy_jaeger
    deploy_elk_stack
    deploy_enhanced_dashboards
    deploy_sli_slo_monitoring
    configure_opentelemetry
    update_backend_tracing
    
    # Validate deployment
    validate_deployment
    
    # Test endpoints
    test_monitoring_endpoints
    
    log_success "Phase 6B: Advanced Monitoring and Observability deployment completed successfully!"
    
    # Display access information
    echo ""
    log_info "Access Information:"
    echo "  Jaeger UI: https://jaeger.ms5floor.com"
    echo "  Kibana: https://kibana.ms5floor.com"
    echo "  Grafana: https://grafana.ms5floor.com"
    echo "  SLI/SLO Calculator: http://sli-slo-calculator.$NAMESPACE.svc.cluster.local:8080"
    echo ""
    log_info "Enhanced monitoring capabilities are now available:"
    echo "  - Distributed tracing with Jaeger"
    echo "  - Log aggregation with ELK stack"
    echo "  - Enhanced application metrics with Azure Monitor integration"
    echo "  - Comprehensive monitoring dashboards"
    echo "  - SLI/SLO monitoring with error budget tracking"
    echo "  - Real-time business metrics visualization"
}

# Run main function
main "$@"
