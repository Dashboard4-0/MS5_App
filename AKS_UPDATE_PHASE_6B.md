# MS5.0 Floor Dashboard - Phase 6B: Advanced Monitoring and Observability
## Application Metrics, Distributed Tracing, and Enhanced Dashboards

**Phase Duration**: Week 6 (Days 4-5)  
**Team Requirements**: DevOps Engineer (Lead), Backend Developer, Monitoring Specialist  
**Dependencies**: Phase 6A completed (Core Monitoring Stack Migration)

---

## Executive Summary

Phase 6B focuses on implementing advanced monitoring capabilities including application metrics integration, distributed tracing, log aggregation, and comprehensive dashboards. This sub-phase enhances the monitoring foundation with enterprise-grade observability features.

**Key Deliverables**:
- ✅ Enhanced application metrics collection
- ✅ Distributed tracing implemented
- ✅ Log aggregation working
- ✅ Custom business metrics configured
- ✅ Comprehensive dashboard suite created
- ✅ Real-time monitoring implemented

---

## Phase 6B Implementation Plan

### 6B.1 Application Metrics Integration and Enhancement (Day 4)

#### 6B.1.1 Application Metrics Enhancement
**Objective**: Enhance application metrics collection and integrate with Azure Monitor

**Tasks**:
- [ ] **6B.1.1.1** Application Metrics Enhancement
  - Migrate existing application metrics to Kubernetes environment
  - Implement custom metrics for business KPIs
  - Set up metrics aggregation and recording rules
  - Configure metrics export for Azure Monitor

- [ ] **6B.1.1.2** Custom Business Metrics
  - Implement real-time OEE calculations
  - Set up production efficiency metrics
  - Configure quality metrics tracking
  - Implement maintenance metrics

**Deliverables**:
- ✅ Enhanced application metrics collection
- ✅ Custom business metrics configured

#### 6B.1.2 Distributed Tracing Setup
**Objective**: Implement distributed tracing for comprehensive observability

**Tasks**:
- [ ] **6B.1.2.1** Deploy Jaeger for distributed tracing
  - Deploy Jaeger to AKS cluster
  - Configure Jaeger collector and query services
  - Set up Jaeger storage backend
  - Configure Jaeger UI access

- [ ] **6B.1.2.2** Integrate tracing with FastAPI backend
  - Add OpenTelemetry instrumentation to FastAPI
  - Configure trace correlation with metrics and logs
  - Set up trace sampling and retention
  - Configure trace export to Jaeger

**Deliverables**:
- ✅ Distributed tracing implemented
- ✅ Trace correlation configured

#### 6B.1.3 Log Aggregation Implementation
**Objective**: Implement comprehensive log aggregation and analysis

**Tasks**:
- [ ] **6B.1.3.1** Deploy ELK stack or configure Azure Monitor
  - Deploy Elasticsearch, Logstash, Kibana to AKS
  - Configure log collection from all services
  - Set up log parsing and indexing
  - Implement log-based alerting

- [ ] **6B.1.3.2** Configure log collection
  - Set up Fluentd or Fluent Bit for log collection
  - Configure log forwarding to Elasticsearch
  - Set up log parsing and enrichment
  - Configure log retention policies

**Deliverables**:
- ✅ Log aggregation working
- ✅ Log-based alerting implemented

### 6B.2 Advanced Dashboards and Visualization (Day 5)

#### 6B.2.1 System Health Dashboards
**Objective**: Create comprehensive monitoring dashboards for all stakeholders

**Tasks**:
- [ ] **6B.2.1.1** System Health Dashboards
  - AKS cluster health and performance
  - Node metrics and resource utilization
  - Pod metrics and scaling events
  - Network performance and latency

- [ ] **6B.2.1.2** Application Performance Dashboards
  - API performance and error rates
  - Database performance and query metrics
  - WebSocket connection monitoring
  - Background task processing

**Deliverables**:
- ✅ System health dashboards created
- ✅ Application performance dashboards created

#### 6B.2.2 Business Metrics Dashboards
**Objective**: Create business-focused monitoring dashboards

**Tasks**:
- [ ] **6B.2.2.1** Business Metrics Dashboards
  - Production line performance and OEE
  - Quality metrics and defect tracking
  - Maintenance efficiency and downtime
  - Energy consumption and efficiency

- [ ] **6B.2.2.2** Real-time Monitoring
  - Live production status dashboard
  - Real-time Andon event monitoring
  - Live equipment status tracking
  - Real-time alert status

**Deliverables**:
- ✅ Business metrics dashboards created
- ✅ Real-time monitoring implemented

#### 6B.2.3 Stakeholder-Specific Dashboards
**Objective**: Create dashboards tailored to different user roles

**Tasks**:
- [ ] **6B.2.3.1** Executive Dashboards
  - High-level business metrics
  - Cost optimization metrics
  - Compliance status
  - ROI and performance indicators

- [ ] **6B.2.3.2** Operations Dashboards
  - Detailed system metrics
  - Alert management
  - Performance optimization
  - Troubleshooting information

- [ ] **6B.2.3.3** Factory Floor Dashboards
  - Production line status
  - Equipment health
  - Quality metrics
  - Maintenance schedules

**Deliverables**:
- ✅ Stakeholder-specific dashboards
- ✅ Role-based dashboard access

---

## Technical Implementation Details

### Application Metrics Integration

#### Custom Metrics Collection
```python
# Enhanced application metrics for AKS
class AKSApplicationMetrics(ApplicationMetrics):
    def __init__(self):
        super().__init__()
        self._initialize_aks_metrics()
    
    def _initialize_aks_metrics(self):
        # Kubernetes-specific metrics
        self.pod_restarts = Counter(
            'ms5_pod_restarts_total',
            'Total number of pod restarts',
            ['namespace', 'pod_name', 'container_name'],
            registry=self.registry
        )
        
        self.node_utilization = Gauge(
            'ms5_node_utilization_percent',
            'Node resource utilization percentage',
            ['node_name', 'resource_type'],
            registry=self.registry
        )
        
        self.cluster_health = Gauge(
            'ms5_cluster_health_score',
            'Overall cluster health score',
            registry=self.registry
        )
```

#### Business Metrics Enhancement
```python
async def calculate_real_time_oee(self, line_id: str) -> Dict[str, Any]:
    """Calculate real-time OEE with enhanced metrics."""
    # Get current production data
    production_data = await self.get_production_data(line_id)
    
    # Calculate OEE components
    availability = production_data['actual_runtime'] / production_data['planned_runtime']
    performance = production_data['actual_output'] / production_data['theoretical_output']
    quality = production_data['good_output'] / production_data['actual_output']
    
    oee = availability * performance * quality
    
    # Record metrics
    self.record_oee(line_id, production_data['equipment_code'], oee)
    
    return {
        'line_id': line_id,
        'oee': oee,
        'availability': availability,
        'performance': performance,
        'quality': quality,
        'timestamp': datetime.now()
    }
```

### Distributed Tracing Configuration

#### Jaeger Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jaeger
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jaeger
  template:
    metadata:
      labels:
        app: jaeger
    spec:
      containers:
      - name: jaeger
        image: jaegertracing/all-in-one:latest
        ports:
        - containerPort: 16686
        - containerPort: 14268
        env:
        - name: COLLECTOR_OTLP_ENABLED
          value: "true"
```

#### OpenTelemetry Integration
```python
from opentelemetry import trace
from opentelemetry.exporter.jaeger.thrift import JaegerExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

# Configure OpenTelemetry
trace.set_tracer_provider(TracerProvider())
tracer = trace.get_tracer(__name__)

# Configure Jaeger exporter
jaeger_exporter = JaegerExporter(
    agent_host_name="jaeger.monitoring.svc.cluster.local",
    agent_port=14268,
)

# Add span processor
span_processor = BatchSpanProcessor(jaeger_exporter)
trace.get_tracer_provider().add_span_processor(span_processor)
```

### Log Aggregation Setup

#### ELK Stack Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: elasticsearch
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: elasticsearch
  template:
    metadata:
      labels:
        app: elasticsearch
    spec:
      containers:
      - name: elasticsearch
        image: docker.elastic.co/elasticsearch/elasticsearch:8.8.0
        ports:
        - containerPort: 9200
        env:
        - name: discovery.type
          value: "single-node"
        - name: xpack.security.enabled
          value: "false"
```

#### Fluentd Configuration
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluentd-config
  namespace: monitoring
data:
  fluent.conf: |
    <source>
      @type tail
      path /var/log/containers/*.log
      pos_file /var/log/fluentd-containers.log.pos
      tag kubernetes.*
      format json
      time_key time
      time_format %Y-%m-%dT%H:%M:%S.%NZ
    </source>
    
    <match kubernetes.**>
      @type elasticsearch
      host elasticsearch.monitoring.svc.cluster.local
      port 9200
      index_name ms5-logs
    </match>
```

---

## Enhanced Monitoring Features

### SLI/SLO Implementation

#### Service Level Indicators (SLIs) Definition
```yaml
# SLI Configuration for MS5.0 Services
slis:
  - service: "ms5-api"
    indicators:
      - name: "availability"
        metric: "up"
        target: 99.9%
      - name: "latency"
        metric: "ms5_api_request_duration_seconds"
        target: "p95 < 200ms"
      - name: "error_rate"
        metric: "ms5_api_requests_total{status=~'5..'}"
        target: "< 0.1%"
  
  - service: "ms5-database"
    indicators:
      - name: "availability"
        metric: "pg_up"
        target: 99.95%
      - name: "query_latency"
        metric: "pg_stat_database_tup_returned"
        target: "p95 < 100ms"
      - name: "connection_pool"
        metric: "pg_stat_activity_count"
        target: "< 80% capacity"
```

#### Service Level Objectives (SLOs) Configuration
```yaml
# SLO Configuration with Error Budgets
slos:
  - service: "ms5-api"
    objectives:
      - name: "availability"
        sli: "availability"
        target: 99.9%
        error_budget: 0.1%
        window: "30d"
      - name: "latency"
        sli: "latency"
        target: "p95 < 200ms"
        error_budget: 5%
        window: "7d"
  
  - service: "ms5-database"
    objectives:
      - name: "availability"
        sli: "availability"
        target: 99.95%
        error_budget: 0.05%
        window: "30d"
```

---

## Success Criteria

### Technical Metrics
- **Application Metrics**: Custom metrics being collected
- **Business KPIs**: Visible in dashboards
- **Distributed Tracing**: Working correctly
- **Log Aggregation**: Functional and searchable
- **Dashboard Performance**: Load within 3 seconds
- **Real-time Updates**: Working correctly

### Business Metrics
- **Monitoring Coverage**: 100% service coverage
- **Business Metrics**: Visible and accurate
- **Stakeholder Satisfaction**: Dashboards meet user needs
- **Operational Efficiency**: Improved troubleshooting capabilities

---

## Resource Requirements

### Infrastructure Requirements
- **Additional CPU**: 2 cores for Jaeger and ELK stack
- **Additional Memory**: 4GB for Jaeger and ELK stack
- **Additional Storage**: 200GB for Jaeger and ELK stack

### Dependencies
- **Phase 6A**: Core monitoring stack migration completed
- **Azure Monitor**: For infrastructure metrics integration
- **Elasticsearch**: For log storage and analysis

---

## Risk Management and Mitigation

### High-Risk Areas
1. **Tracing Overhead**: Performance impact of distributed tracing
2. **Log Volume**: High log volume affecting storage and performance
3. **Dashboard Complexity**: Complex dashboards affecting performance
4. **Metrics Cardinality**: High cardinality metrics affecting performance

### Mitigation Strategies
1. **Sampling**: Implement trace sampling to reduce overhead
2. **Log Retention**: Implement log retention policies
3. **Dashboard Optimization**: Optimize dashboard queries and refresh rates
4. **Metrics Optimization**: Optimize metrics cardinality and collection

---

## Deliverables Checklist

### Week 6B Deliverables
- [ ] Enhanced application metrics collection
- [ ] Distributed tracing implemented
- [ ] Log aggregation working
- [ ] Custom business metrics configured
- [ ] Comprehensive dashboard suite created
- [ ] Real-time monitoring implemented
- [ ] Business metrics visualization
- [ ] Stakeholder-specific dashboards
- [ ] SLI/SLO implementation
- [ ] Performance optimization completed

---

*This sub-phase provides advanced monitoring and observability capabilities, ensuring comprehensive visibility into application performance, business metrics, and system health.*
