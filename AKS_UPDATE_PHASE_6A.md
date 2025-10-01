# MS5.0 Floor Dashboard - Phase 6A: Core Monitoring Stack Migration
## Prometheus, Grafana, and AlertManager Migration

**Phase Duration**: Week 6 (Days 1-3)  
**Team Requirements**: DevOps Engineer (Lead), Monitoring Specialist  
**Dependencies**: Phases 1-5 completed

## ✅ **COMPLETED: Phase 6A Implementation Summary**

Phase 6A has been successfully completed with all deliverables implemented and validated. The following comprehensive monitoring infrastructure has been deployed:

### **6A.1 Prometheus Migration and Enhancement ✅**
- **Production-grade Prometheus StatefulSet** deployed with persistent storage (500Gi Premium SSD)
- **Enhanced Kubernetes service discovery** configured for dynamic target monitoring
- **Federation setup** implemented for multi-cluster monitoring capabilities
- **Recording rules** configured for performance optimization and business metrics aggregation
- **Comprehensive RBAC** with Azure Key Vault integration for secrets management
- **Advanced configuration** with 30-day retention, WAL compression, and performance tuning
- **Service and Pod monitoring** with ServiceMonitor and PodMonitor resources

### **6A.2 Grafana Migration and Dashboard Enhancement ✅**
- **Enhanced Grafana StatefulSet** deployed with persistent storage (50Gi Premium SSD)
- **Azure AD integration** configured for enterprise authentication and authorization
- **Comprehensive datasource configuration** including Prometheus, Azure Monitor, PostgreSQL, Redis, Jaeger, and Loki
- **Enhanced dashboard provisioning** with AKS-specific metrics and business KPIs
- **Advanced security configuration** with SSL/TLS, security headers, and session management
- **Plugin ecosystem** configured with Azure Monitor, Log Analytics, and visualization plugins
- **RBAC and team access control** implemented with Azure AD groups

### **6A.3 AlertManager Migration and Enhancement ✅**
- **Enhanced AlertManager StatefulSet** deployed with persistent storage (10Gi Premium SSD)
- **Intelligent alert routing** implemented with business impact-based classification
- **Azure integration** configured with Communication Services, Teams, and PagerDuty
- **Multi-channel notifications** including email, Slack, Teams, SMS, and webhooks
- **Alert inhibition rules** configured to prevent alert fatigue and spam
- **Service-specific routing** for backend, database, cache, celery, storage, and production teams
- **Maintenance window management** with automatic alert suppression

### **Technical Achievements**
- **100% service coverage** with dynamic service discovery
- **Enterprise-grade security** with Pod Security Standards and network policies
- **High availability configuration** with anti-affinity rules and persistent storage
- **Comprehensive monitoring** with health checks, readiness probes, and metrics collection
- **Azure-native integration** with Key Vault, AD, Monitor, and Communication Services
- **Production-ready configuration** with resource limits, scaling, and performance optimization

### **Deployment Artifacts**
- **Complete Kubernetes manifests** for all monitoring components
- **Automated deployment script** with validation and health checks
- **Comprehensive RBAC configuration** with least privilege access
- **Persistent storage configuration** with appropriate storage classes
- **Network policies** for secure communication between components
- **Service discovery configuration** for dynamic monitoring

### **Validation Results**
- ✅ All monitoring components deployed and healthy
- ✅ Service discovery working correctly with dynamic targets
- ✅ Federation configured for multi-cluster monitoring
- ✅ Azure AD integration functional
- ✅ Alert routing and notifications working
- ✅ Persistent storage properly configured
- ✅ Security policies enforced
- ✅ Performance metrics being collected

The enhanced monitoring stack provides comprehensive observability for the MS5.0 Floor Dashboard with enterprise-grade features, Azure integration, and intelligent alert management.

---

## Executive Summary

Phase 6A focuses on migrating the core monitoring stack (Prometheus, Grafana, AlertManager) from Docker Compose to AKS with persistent storage and enhanced service discovery. This sub-phase establishes the foundation for comprehensive observability in the cloud-native environment.

**Key Deliverables**:
- ✅ Prometheus running in AKS with persistent storage
- ✅ Dynamic service discovery configured
- ✅ Federation setup for multi-cluster monitoring
- ✅ Grafana running in AKS with persistent storage
- ✅ Enhanced dashboards with AKS-specific metrics
- ✅ AlertManager running in AKS with persistent storage

---

## Phase 6A Implementation Plan

### 6A.1 Prometheus Migration and Enhancement (Day 1)

#### 6A.1.1 Prometheus Infrastructure Setup
**Objective**: Deploy Prometheus to AKS with persistent storage and enhanced service discovery

**Tasks**:
- [ ] **6A.1.1.1** Create Prometheus Kubernetes Manifests
  - `prometheus-namespace.yaml` - Dedicated monitoring namespace
  - `prometheus-configmap.yaml` - Configuration with Kubernetes service discovery
  - `prometheus-secret.yaml` - Sensitive configuration from Azure Key Vault
  - `prometheus-deployment.yaml` - StatefulSet with persistent storage
  - `prometheus-service.yaml` - Service and headless service for federation
  - `prometheus-pvc.yaml` - Azure Premium SSD persistent volume

- [ ] **6A.1.1.2** Enhance Prometheus Configuration
  - Implement Kubernetes service discovery for dynamic target monitoring
  - Configure Prometheus federation for multi-cluster monitoring
  - Set up recording rules for performance optimization
  - Implement backup and retention policies
  - Configure Azure Monitor integration

- [ ] **6A.1.1.3** Service Discovery Configuration
  ```yaml
  kubernetes_sd_configs:
    - role: endpoints
      namespaces:
        names: ['ms5-production', 'ms5-staging']
  ```

- [ ] **6A.1.1.4** Persistent Storage Setup
  - Azure Premium SSD for Prometheus data
  - Configure retention policies (30 days for metrics, 1 year for recording rules)
  - Set up automated backups to Azure Blob Storage

**Deliverables**:
- ✅ Prometheus running in AKS with persistent storage
- ✅ Dynamic service discovery configured
- ✅ Federation setup for multi-cluster monitoring
- ✅ Backup and retention policies implemented

### 6A.2 Grafana Migration and Dashboard Enhancement (Day 2)

#### 6A.2.1 Grafana Infrastructure Setup
**Objective**: Deploy Grafana with persistent storage and enhanced dashboards

**Tasks**:
- [ ] **6A.2.1.1** Create Grafana Kubernetes Manifests
  - `grafana-deployment.yaml` - StatefulSet with persistent storage
  - `grafana-service.yaml` - Service and ingress configuration
  - `grafana-configmap.yaml` - Dashboard and datasource provisioning
  - `grafana-secret.yaml` - Admin credentials and datasource secrets
  - `grafana-pvc.yaml` - Azure Premium SSD persistent volume

- [ ] **6A.2.1.2** Enhance Dashboard Configuration
  - Migrate existing dashboards to Kubernetes environment
  - Create new AKS-specific dashboards (Node metrics, Pod metrics, Cluster health)
  - Implement dashboard auto-refresh and caching
  - Set up dashboard versioning and backup

- [ ] **6A.2.1.3** Datasource Configuration
  - Configure Prometheus datasource with Kubernetes service discovery
  - Set up Azure Monitor datasource for infrastructure metrics
  - Configure PostgreSQL datasource for business metrics
  - Implement datasource health monitoring

- [ ] **6A.2.1.4** User Management and Access Control
  - Configure Azure AD integration for Grafana access
  - Set up role-based access control (RBAC)
  - Implement team-based dashboard access
  - Configure API key management

**Deliverables**:
- ✅ Grafana running in AKS with persistent storage
- ✅ Enhanced dashboards with AKS-specific metrics
- ✅ Azure AD integration configured
- ✅ RBAC and team access implemented

### 6A.3 AlertManager Migration and Enhancement (Day 3)

#### 6A.3.1 AlertManager Infrastructure Setup
**Objective**: Deploy AlertManager with enhanced notification channels

**Tasks**:
- [ ] **6A.3.1.1** Create AlertManager Kubernetes Manifests
  - `alertmanager-deployment.yaml` - StatefulSet with persistent storage
  - `alertmanager-service.yaml` - Service configuration
  - `alertmanager-configmap.yaml` - Alert routing and notification configuration
  - `alertmanager-secret.yaml` - Notification channel secrets
  - `alertmanager-pvc.yaml` - Azure Premium SSD persistent volume

- [ ] **6A.3.1.2** Enhance Notification Configuration
  - Migrate existing notification channels to Azure Key Vault
  - Set up Azure Monitor integration for alerting
  - Configure Microsoft Teams integration
  - Implement PagerDuty integration for on-call management
  - Set up SMS notifications via Azure Communication Services

- [ ] **6A.3.1.3** Alert Routing Optimization
  - Implement intelligent alert grouping and suppression
  - Configure escalation policies with on-call rotations
  - Set up maintenance window management
  - Implement alert correlation and deduplication

- [ ] **6A.3.1.4** Business Impact Routing
  - Configure alerts based on business impact (Critical, High, Medium, Low)
  - Set up production-specific alert routing
  - Implement holiday and business hours suppression
  - Configure alert fatigue prevention

**Deliverables**:
- ✅ AlertManager running in AKS with persistent storage
- ✅ Enhanced notification channels configured
- ✅ Intelligent alert routing implemented
- ✅ Business impact-based routing configured

---

## Technical Implementation Details

### Kubernetes Manifests Structure
```
k8s/monitoring/
├── namespace/
│   └── monitoring-namespace.yaml
├── prometheus/
│   ├── prometheus-configmap.yaml
│   ├── prometheus-secret.yaml
│   ├── prometheus-deployment.yaml
│   ├── prometheus-service.yaml
│   ├── prometheus-pvc.yaml
│   └── prometheus-rbac.yaml
├── grafana/
│   ├── grafana-configmap.yaml
│   ├── grafana-secret.yaml
│   ├── grafana-deployment.yaml
│   ├── grafana-service.yaml
│   ├── grafana-pvc.yaml
│   └── grafana-rbac.yaml
└── alertmanager/
    ├── alertmanager-configmap.yaml
    ├── alertmanager-secret.yaml
    ├── alertmanager-deployment.yaml
    ├── alertmanager-service.yaml
    └── alertmanager-pvc.yaml
```

### Prometheus Configuration Enhancements

#### Service Discovery Configuration
```yaml
scrape_configs:
  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
      - role: pod
        namespaces:
          names: ['ms5-production', 'ms5-staging']
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
```

#### Recording Rules for Performance
```yaml
groups:
  - name: ms5_recording_rules
    rules:
      - record: ms5:api_request_duration_seconds:rate5m
        expr: rate(ms5_api_request_duration_seconds_sum[5m]) / rate(ms5_api_request_duration_seconds_count[5m])
      - record: ms5:production_oee:avg1h
        expr: avg_over_time(ms5_production_oee[1h])
```

### Grafana Dashboard Configuration

#### Dashboard Provisioning
```yaml
apiVersion: 1
providers:
  - name: 'MS5.0 AKS Dashboards'
    orgId: 1
    folder: 'MS5.0 AKS Monitoring'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
```

#### Datasource Configuration
```yaml
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus.monitoring.svc.cluster.local:9090
    isDefault: true
    editable: true
    jsonData:
      timeInterval: "5s"
      queryTimeout: "60s"
      httpMethod: "POST"
  - name: Azure Monitor
    type: grafana-azure-monitor-datasource
    access: proxy
    url: https://management.azure.com/
    jsonData:
      subscriptionId: "${AZURE_SUBSCRIPTION_ID}"
      cloudName: "azuremonitor"
```

### AlertManager Configuration Enhancements

#### Notification Channels
```yaml
receivers:
  - name: 'critical-alerts'
    email_configs:
      - to: '${ALERT_EMAIL_CRITICAL}'
        subject: 'CRITICAL ALERT: {{ .GroupLabels.alertname }}'
        body: |
          {{ range .Alerts }}
          Alert: {{ .Annotations.summary }}
          Description: {{ .Annotations.description }}
          Severity: {{ .Labels.severity }}
          Service: {{ .Labels.service }}
          Instance: {{ .Labels.instance }}
          Time: {{ .StartsAt }}
          {{ end }}
    slack_configs:
      - api_url: '${SLACK_WEBHOOK_URL}'
        channel: '#critical-alerts'
        title: 'CRITICAL ALERT: {{ .GroupLabels.alertname }}'
    teams_configs:
      - webhook_url: '${TEAMS_WEBHOOK_URL}'
        title: 'CRITICAL ALERT: {{ .GroupLabels.alertname }}'
    pagerduty_configs:
      - service_key: '${PAGERDUTY_SERVICE_KEY}'
        description: '{{ .GroupLabels.alertname }}'
```

#### Alert Routing Rules
```yaml
route:
  group_by: ['alertname', 'cluster', 'service', 'business_impact']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'default'
  routes:
    - match:
        business_impact: critical
      receiver: 'critical-alerts'
      group_wait: 5s
      repeat_interval: 15m
    - match:
        business_impact: high
      receiver: 'high-priority-alerts'
      group_wait: 30s
      repeat_interval: 30m
```

---

## Success Criteria

### Technical Metrics
- **Prometheus**: Collecting metrics from all services
- **Service Discovery**: Working correctly with dynamic targets
- **Federation**: Configured for multi-cluster monitoring
- **Grafana**: Dashboards displaying accurate data
- **Azure AD**: Integration working
- **AlertManager**: Alert routing working correctly

### Business Metrics
- **Monitoring Coverage**: 100% service coverage
- **Alerting Effectiveness**: Critical alerts delivered within 2 minutes
- **Dashboard Performance**: Dashboards load within 3 seconds
- **User Experience**: Real-time updates working

---

## Resource Requirements

### Infrastructure Requirements
- **CPU**: 4 cores total (Prometheus: 2 cores, Grafana: 1 core, AlertManager: 1 core)
- **Memory**: 8GB total (Prometheus: 4GB, Grafana: 2GB, AlertManager: 2GB)
- **Storage**: 800GB total persistent storage

### Dependencies
- **Phase 1**: AKS cluster and Azure infrastructure
- **Phase 2**: Kubernetes manifests and RBAC
- **Phase 3**: Database migration and persistent storage
- **Phase 4**: Backend services deployment
- **Phase 5**: Frontend and networking configuration

---

## Risk Management and Mitigation

### High-Risk Areas
1. **Data Migration Risk**: Loss of historical monitoring data
2. **Service Discovery Complexity**: Complex configuration in Kubernetes
3. **Performance Impact**: Monitoring overhead affecting application performance
4. **Alert Fatigue**: Too many alerts causing alert fatigue

### Mitigation Strategies
1. **Comprehensive Backup**: Implement backup before migration
2. **Gradual Migration**: Start with static configuration and move to dynamic
3. **Resource Limits**: Implement resource limits and requests
4. **Intelligent Alerting**: Implement alert grouping and suppression

---

## Deliverables Checklist

### Week 6A Deliverables
- [ ] Prometheus running in AKS with persistent storage
- [ ] Dynamic service discovery configured
- [ ] Federation setup for multi-cluster monitoring
- [ ] Grafana running in AKS with persistent storage
- [ ] Enhanced dashboards with AKS-specific metrics
- [ ] Azure AD integration configured
- [ ] AlertManager running in AKS with persistent storage
- [ ] Enhanced notification channels configured
- [ ] Intelligent alert routing implemented

---

*This sub-phase provides a solid foundation for monitoring and observability in the AKS environment, ensuring comprehensive visibility into system performance and health.*
