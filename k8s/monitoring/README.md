# MS5.0 Floor Dashboard - Enhanced Monitoring Stack

## Overview

This directory contains the enhanced monitoring stack for the MS5.0 Floor Dashboard, implemented as part of Phase 6A of the AKS optimization plan. The monitoring stack provides comprehensive observability with enterprise-grade features, Azure integration, and intelligent alert management.

## Architecture

The monitoring stack consists of three core components:

### 1. Prometheus
- **Purpose**: Metrics collection and storage
- **Features**: 
  - Kubernetes service discovery
  - Federation for multi-cluster monitoring
  - Recording rules for performance optimization
  - 30-day data retention
  - WAL compression for efficiency

### 2. Grafana
- **Purpose**: Visualization and dashboards
- **Features**:
  - Azure AD integration
  - Comprehensive datasource configuration
  - Enhanced dashboards with AKS-specific metrics
  - Plugin ecosystem for Azure services
  - RBAC and team access control

### 3. AlertManager
- **Purpose**: Alert routing and notifications
- **Features**:
  - Intelligent alert routing based on business impact
  - Multi-channel notifications (email, Slack, Teams, SMS, webhooks)
  - Alert inhibition rules to prevent spam
  - Service-specific routing
  - Maintenance window management

## Directory Structure

```
k8s/monitoring/
├── namespace/
│   └── monitoring-namespace.yaml          # Namespace with resource quotas and network policies
├── prometheus/
│   ├── prometheus-configmap.yaml          # Prometheus configuration with service discovery
│   ├── prometheus-secret.yaml             # Secrets and RBAC configuration
│   ├── prometheus-deployment.yaml         # StatefulSet with persistent storage
│   ├── prometheus-service.yaml            # Services and ServiceMonitor resources
│   ├── prometheus-pvc.yaml                # Persistent Volume Claims
│   └── prometheus-rbac.yaml               # RBAC and service accounts
├── grafana/
│   ├── grafana-configmap.yaml             # Grafana configuration with datasources
│   ├── grafana-secret.yaml                # Secrets and RBAC configuration
│   ├── grafana-deployment.yaml            # StatefulSet with persistent storage
│   ├── grafana-service.yaml               # Services and ServiceMonitor resources
│   └── grafana-pvc.yaml                   # Persistent Volume Claims
├── alertmanager/
│   ├── alertmanager-configmap.yaml        # AlertManager configuration with routing
│   ├── alertmanager-secret.yaml           # Secrets and RBAC configuration
│   ├── alertmanager-deployment.yaml       # StatefulSet with persistent storage
│   ├── alertmanager-service.yaml          # Services and ServiceMonitor resources
│   └── alertmanager-pvc.yaml              # Persistent Volume Claims
├── deploy-phase6a.sh                      # Automated deployment script
└── README.md                              # This file
```

## Deployment

### Prerequisites

1. **Kubernetes cluster** with AKS or compatible environment
2. **kubectl** configured to access the cluster
3. **Azure Key Vault** configured with required secrets
4. **Storage classes** available (managed-premium, managed-standard)

### Quick Deployment

```bash
# Deploy the complete monitoring stack
./deploy-phase6a.sh deploy

# Validate the deployment
./deploy-phase6a.sh validate

# Display deployment information
./deploy-phase6a.sh info
```

### Manual Deployment

```bash
# 1. Create namespace and base configuration
kubectl apply -f namespace/monitoring-namespace.yaml

# 2. Deploy Prometheus
kubectl apply -f prometheus/prometheus-rbac.yaml
kubectl apply -f prometheus/prometheus-secret.yaml
kubectl apply -f prometheus/prometheus-configmap.yaml
kubectl apply -f prometheus/prometheus-pvc.yaml
kubectl apply -f prometheus/prometheus-deployment.yaml
kubectl apply -f prometheus/prometheus-service.yaml

# 3. Deploy Grafana
kubectl apply -f grafana/grafana-secret.yaml
kubectl apply -f grafana/grafana-configmap.yaml
kubectl apply -f grafana/grafana-pvc.yaml
kubectl apply -f grafana/grafana-deployment.yaml
kubectl apply -f grafana/grafana-service.yaml

# 4. Deploy AlertManager
kubectl apply -f alertmanager/alertmanager-secret.yaml
kubectl apply -f alertmanager/alertmanager-configmap.yaml
kubectl apply -f alertmanager/alertmanager-pvc.yaml
kubectl apply -f alertmanager/alertmanager-deployment.yaml
kubectl apply -f alertmanager/alertmanager-service.yaml
```

## Configuration

### Secrets Management

All sensitive configuration is managed through Kubernetes secrets and Azure Key Vault integration. The following secrets need to be configured:

#### Prometheus Secrets
- `AZURE_CLIENT_ID`: Azure AD client ID
- `AZURE_CLIENT_SECRET`: Azure AD client secret
- `AZURE_TENANT_ID`: Azure AD tenant ID
- `AZURE_SUBSCRIPTION_ID`: Azure subscription ID

#### Grafana Secrets
- `GF_SECURITY_ADMIN_PASSWORD`: Grafana admin password
- `GF_SECURITY_SECRET_KEY`: Grafana secret key
- `AZURE_AD_CLIENT_ID`: Azure AD client ID for authentication
- `AZURE_AD_CLIENT_SECRET`: Azure AD client secret
- `POSTGRES_MONITORING_PASSWORD`: PostgreSQL monitoring user password

#### AlertManager Secrets
- `SMTP_PASSWORD`: SMTP password for email notifications
- `SLACK_WEBHOOK_URL`: Slack webhook URL
- `TEAMS_WEBHOOK_URL`: Microsoft Teams webhook URL
- `PAGERDUTY_CRITICAL_SERVICE_KEY`: PagerDuty critical service key
- `PAGERDUTY_HIGH_PRIORITY_SERVICE_KEY`: PagerDuty high priority service key

### Service Discovery

The monitoring stack uses Kubernetes service discovery to automatically detect and monitor services. Services are discovered based on:

1. **Pod annotations**: `prometheus.io/scrape=true`
2. **Service annotations**: `prometheus.io/scrape=true`
3. **Namespace-based discovery**: Automatic discovery in specified namespaces
4. **Label-based selection**: Services with specific labels

### Alert Routing

AlertManager uses intelligent routing based on:

1. **Business Impact**: Critical, High, Medium, Low
2. **Service Type**: Backend, Database, Cache, Celery, Storage, Production
3. **Severity**: Critical, Warning, Info
4. **Maintenance Windows**: Automatic suppression during maintenance

## Access URLs

### Internal Cluster Access
- **Prometheus**: `http://prometheus.monitoring.svc.cluster.local:9090`
- **Grafana**: `http://grafana.monitoring.svc.cluster.local:3000`
- **AlertManager**: `http://alertmanager.monitoring.svc.cluster.local:9093`

### External Access (if configured)
- **Prometheus**: `https://prometheus.ms5floor.com`
- **Grafana**: `https://grafana.ms5floor.com`
- **AlertManager**: `https://alertmanager.ms5floor.com`

## Monitoring and Validation

### Health Checks

All components include comprehensive health checks:

- **Liveness Probes**: Ensure containers are running
- **Readiness Probes**: Ensure services are ready to accept traffic
- **Startup Probes**: Ensure containers start successfully

### Metrics Collection

The monitoring stack collects metrics from:

- **Kubernetes API Server**: Cluster and node metrics
- **Kubernetes Nodes**: System and container metrics
- **Kubernetes Pods**: Application and container metrics
- **MS5.0 Services**: Backend, database, cache, and production metrics
- **Azure Resources**: Infrastructure and service metrics

### Validation Commands

```bash
# Check pod status
kubectl get pods -n monitoring -l app=ms5-dashboard

# Check service status
kubectl get services -n monitoring -l app=ms5-dashboard

# Check PVC status
kubectl get pvc -n monitoring

# Test Prometheus connectivity
kubectl exec -n monitoring deployment/prometheus -- curl -s http://localhost:9090/-/healthy

# Test Grafana connectivity
kubectl exec -n monitoring deployment/grafana -- curl -s http://localhost:3000/api/health

# Test AlertManager connectivity
kubectl exec -n monitoring deployment/alertmanager -- curl -s http://localhost:9093/-/healthy
```

## Troubleshooting

### Common Issues

1. **Pod Startup Issues**
   - Check resource limits and requests
   - Verify persistent volume claims
   - Check security context and RBAC

2. **Service Discovery Issues**
   - Verify service annotations
   - Check namespace configuration
   - Validate RBAC permissions

3. **Alert Delivery Issues**
   - Check secret configuration
   - Verify webhook URLs
   - Test notification channels

### Logs and Debugging

```bash
# View Prometheus logs
kubectl logs -n monitoring deployment/prometheus

# View Grafana logs
kubectl logs -n monitoring deployment/grafana

# View AlertManager logs
kubectl logs -n monitoring deployment/alertmanager

# Describe resources for debugging
kubectl describe pod -n monitoring -l app=ms5-dashboard,component=prometheus
```

## Security

### Network Policies

The monitoring namespace includes comprehensive network policies:

- **Ingress**: Allow traffic from MS5.0 namespaces and kube-system
- **Egress**: Allow traffic to required services and external endpoints
- **Port Restrictions**: Only necessary ports are exposed

### RBAC

All components use least-privilege RBAC:

- **Service Accounts**: Dedicated service accounts for each component
- **Cluster Roles**: Minimal required permissions
- **Role Bindings**: Namespace-specific permissions where possible

### Pod Security

All pods run with:

- **Non-root users**: All containers run as non-root
- **Read-only root filesystem**: Where possible
- **Dropped capabilities**: All unnecessary capabilities removed
- **Security contexts**: Proper security contexts configured

## Maintenance

### Backup

Regular backups should be performed for:

- **Prometheus data**: Metrics and configuration
- **Grafana data**: Dashboards and configuration
- **AlertManager data**: Alert state and silences

### Updates

To update the monitoring stack:

1. Update image versions in deployment manifests
2. Test in staging environment
3. Apply updates using rolling updates
4. Validate functionality after updates

### Scaling

The monitoring stack can be scaled by:

- **Horizontal scaling**: Multiple replicas for high availability
- **Vertical scaling**: Increased resource limits
- **Storage scaling**: Larger persistent volumes

## Support

For issues or questions:

1. Check the troubleshooting section
2. Review component logs
3. Validate configuration
4. Contact the MS5.0 DevOps team

## Version Information

- **Prometheus**: v2.45.0
- **Grafana**: v10.0.0
- **AlertManager**: v0.25.0
- **Kubernetes**: v1.28+
- **AKS**: v1.28+

---

*This monitoring stack was implemented as part of Phase 6A of the MS5.0 Floor Dashboard AKS optimization plan.*
