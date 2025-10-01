# MS5.0 Floor Dashboard - Phase 2 Kubernetes Manifests

This directory contains all Kubernetes manifests and configurations for Phase 2 of the MS5.0 Floor Dashboard AKS migration.

## Overview

Phase 2 focuses on creating comprehensive Kubernetes manifests for all services, implementing proper resource management and scaling, and configuring service discovery and networking.

## Architecture

The MS5.0 Floor Dashboard consists of the following components:

### Core Services
- **PostgreSQL with TimescaleDB**: Primary database with time-series capabilities
- **Redis**: Cache and session storage
- **FastAPI Backend**: Main application server
- **Celery Workers**: Background task processing
- **Celery Beat**: Scheduled task scheduler
- **Flower**: Celery monitoring interface
- **MinIO**: Object storage service

### Monitoring Stack
- **Prometheus**: Metrics collection and storage
- **Grafana**: Monitoring dashboards
- **AlertManager**: Alert management and notification

### Infrastructure
- **Network Policies**: Traffic control and security
- **RBAC**: Role-based access control
- **Secrets Management**: Secure credential handling
- **ConfigMaps**: Configuration management
- **SLI/SLO**: Service level monitoring
- **Cost Monitoring**: Resource cost tracking

## File Structure

```
k8s/
├── 01-namespace.yaml              # Namespace and resource quotas
├── 02-configmap.yaml              # Application configuration
├── 03-secrets.yaml                # Sensitive data (temporary)
├── 04-keyvault-csi.yaml           # Azure Key Vault integration
├── 05-rbac.yaml                   # Role-based access control
├── 06-postgres-statefulset.yaml  # PostgreSQL with TimescaleDB
├── 07-postgres-services.yaml      # PostgreSQL services
├── 08-postgres-config.yaml        # PostgreSQL configuration
├── 09-redis-statefulset.yaml     # Redis cache
├── 10-redis-services.yaml         # Redis services
├── 11-redis-config.yaml           # Redis configuration
├── 12-backend-deployment.yaml     # FastAPI backend
├── 13-backend-services.yaml       # Backend services
├── 14-backend-hpa.yaml            # Horizontal Pod Autoscaler
├── 15-celery-worker-deployment.yaml # Celery workers
├── 16-celery-beat-deployment.yaml # Celery beat scheduler
├── 17-flower-deployment.yaml      # Flower monitoring
├── 18-minio-statefulset.yaml     # MinIO object storage
├── 19-minio-services.yaml         # MinIO services
├── 20-minio-config.yaml           # MinIO configuration
├── 21-prometheus-statefulset.yaml # Prometheus monitoring
├── 22-prometheus-services.yaml    # Prometheus services
├── 23-prometheus-config.yaml      # Prometheus configuration
├── 24-grafana-statefulset.yaml   # Grafana dashboards
├── 25-grafana-services.yaml       # Grafana services
├── 26-grafana-config.yaml         # Grafana configuration
├── 27-alertmanager-deployment.yaml # AlertManager
├── 28-alertmanager-services.yaml   # AlertManager services
├── 29-alertmanager-config.yaml    # AlertManager configuration
├── 30-network-policies.yaml       # Network security policies
├── 31-sli-definitions.yaml        # Service Level Indicators
├── 32-slo-configuration.yaml      # Service Level Objectives
├── 33-cost-monitoring.yaml        # Cost monitoring
├── deploy-phase2.sh               # Deployment script
├── test-phase2.sh                 # Testing script
├── helm/                          # Helm chart
│   └── ms5-dashboard/
│       ├── Chart.yaml
│       └── values.yaml
└── istio/                         # Service mesh (optional)
```

## Prerequisites

Before deploying Phase 2, ensure the following prerequisites are met:

### Azure Infrastructure (Phase 1)
- AKS cluster is running and accessible
- Azure Container Registry is configured
- Azure Key Vault is set up
- Azure Monitor is configured
- Network security groups are configured

### Local Tools
- `kubectl` configured to access the AKS cluster
- `helm` installed (version 3.x)
- `jq` for JSON processing
- `curl` for health checks

### Permissions
- Cluster admin access to the AKS cluster
- Azure Key Vault access permissions
- Azure Container Registry pull permissions

## Deployment

### Quick Deployment

```bash
# Deploy all Phase 2 components
./deploy-phase2.sh

# Deploy with dry run
./deploy-phase2.sh --dry-run

# Deploy with verbose output
./deploy-phase2.sh --verbose
```

### Manual Deployment

```bash
# 1. Create namespace and base configuration
kubectl apply -f 01-namespace.yaml
kubectl apply -f 02-configmap.yaml
kubectl apply -f 03-secrets.yaml
kubectl apply -f 04-keyvault-csi.yaml
kubectl apply -f 05-rbac.yaml

# 2. Deploy database services
kubectl apply -f 08-postgres-config.yaml
kubectl apply -f 06-postgres-statefulset.yaml
kubectl apply -f 07-postgres-services.yaml

# 3. Deploy cache services
kubectl apply -f 11-redis-config.yaml
kubectl apply -f 09-redis-statefulset.yaml
kubectl apply -f 10-redis-services.yaml

# 4. Deploy backend services
kubectl apply -f 12-backend-deployment.yaml
kubectl apply -f 13-backend-services.yaml
kubectl apply -f 14-backend-hpa.yaml
kubectl apply -f 15-celery-worker-deployment.yaml
kubectl apply -f 16-celery-beat-deployment.yaml
kubectl apply -f 17-flower-deployment.yaml

# 5. Deploy storage services
kubectl apply -f 20-minio-config.yaml
kubectl apply -f 18-minio-statefulset.yaml
kubectl apply -f 19-minio-services.yaml

# 6. Deploy monitoring services
kubectl apply -f 23-prometheus-config.yaml
kubectl apply -f 21-prometheus-statefulset.yaml
kubectl apply -f 22-prometheus-services.yaml
kubectl apply -f 24-grafana-statefulset.yaml
kubectl apply -f 25-grafana-services.yaml
kubectl apply -f 26-grafana-config.yaml
kubectl apply -f 27-alertmanager-deployment.yaml
kubectl apply -f 28-alertmanager-services.yaml
kubectl apply -f 29-alertmanager-config.yaml

# 7. Deploy networking and monitoring
kubectl apply -f 30-network-policies.yaml
kubectl apply -f 31-sli-definitions.yaml
kubectl apply -f 32-slo-configuration.yaml
kubectl apply -f 33-cost-monitoring.yaml
```

### Helm Deployment

```bash
# Add required repositories
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Deploy using Helm
helm install ms5-dashboard ./helm/ms5-dashboard -n ms5-production --create-namespace
```

## Testing

### Comprehensive Testing

```bash
# Run all Phase 2 tests
./test-phase2.sh

# Run tests with verbose output
./test-phase2.sh --verbose
```

### Manual Testing

```bash
# Check pod status
kubectl get pods -n ms5-production

# Check service status
kubectl get services -n ms5-production

# Check StatefulSet status
kubectl get statefulsets -n ms5-production

# Check Deployment status
kubectl get deployments -n ms5-production

# Check HPA status
kubectl get hpa -n ms5-production

# Check NetworkPolicy status
kubectl get networkpolicies -n ms5-production

# Check PVC status
kubectl get pvc -n ms5-production
```

### Health Checks

```bash
# Backend health
kubectl exec -n ms5-production deployment/ms5-backend -- curl -f http://localhost:8000/health

# Database connectivity
kubectl exec -n ms5-production deployment/ms5-backend -- pg_isready -h postgres-primary.ms5-production.svc.cluster.local -p 5432

# Redis connectivity
kubectl exec -n ms5-production deployment/ms5-backend -- redis-cli -h redis-primary.ms5-production.svc.cluster.local -p 6379 ping

# MinIO connectivity
kubectl exec -n ms5-production deployment/ms5-backend -- curl -f http://minio.ms5-production.svc.cluster.local:9000/minio/health/live

# Prometheus health
kubectl exec -n ms5-production deployment/prometheus -- curl -f http://localhost:9090/-/healthy

# Grafana health
kubectl exec -n ms5-production deployment/grafana -- curl -f http://localhost:3000/api/health
```

## Configuration

### Environment Variables

Key environment variables are configured in the ConfigMaps and Secrets:

- **Application Settings**: Environment, debug mode, log level
- **Database Settings**: Connection strings, pool sizes
- **Redis Settings**: Cache configuration, memory limits
- **Security Settings**: JWT secrets, encryption keys
- **Monitoring Settings**: Metrics collection, alerting

### Resource Limits

All services have appropriate resource requests and limits:

- **Backend**: 500m CPU, 1Gi memory (requests) / 2 CPU, 4Gi memory (limits)
- **Database**: 2 CPU, 4Gi memory (requests) / 4 CPU, 8Gi memory (limits)
- **Redis**: 1 CPU, 2Gi memory (requests) / 2 CPU, 4Gi memory (limits)
- **Monitoring**: 500m CPU, 1Gi memory (requests) / 2 CPU, 4Gi memory (limits)

### Storage

Persistent storage is configured for stateful services:

- **PostgreSQL**: 100Gi Premium SSD
- **Redis**: 10Gi Premium SSD
- **MinIO**: 500Gi Premium SSD
- **Prometheus**: 200Gi Premium SSD
- **Grafana**: 10Gi Premium SSD

## Security

### Pod Security Standards

All pods run with:
- Non-root users
- Read-only root filesystems (where possible)
- Dropped capabilities
- Security contexts

### Network Policies

Comprehensive network policies control traffic between services:
- Default deny-all policy
- Service-specific ingress/egress rules
- DNS resolution allowed
- External HTTPS access allowed

### Secrets Management

- Azure Key Vault integration for production secrets
- Kubernetes secrets for development/testing
- Automatic secret rotation support
- Audit logging for secret access

## Monitoring

### Prometheus Metrics

Prometheus collects metrics from:
- Kubernetes cluster components
- Application services
- Database and cache services
- System resources

### Grafana Dashboards

Pre-configured dashboards for:
- System overview
- Production metrics
- Database performance
- Cache performance
- Application performance

### Alerting

AlertManager configured with:
- Critical alerts (email + Slack)
- Warning alerts (email)
- Service-specific alerting
- Escalation policies

## SLI/SLO Monitoring

### Service Level Indicators

Defined SLIs for:
- API availability and response time
- Database performance
- Cache performance
- Celery task processing
- System resource utilization

### Service Level Objectives

Target SLOs:
- 99.9% availability
- < 200ms API response time (95th percentile)
- < 0.1% error rate
- < 5 minute task processing time

## Cost Monitoring

### Cost Tracking

- Azure resource cost monitoring
- Service-level cost allocation
- Resource utilization tracking
- Cost optimization recommendations

### Cost Optimization

- Reserved instance utilization
- Spot instance usage
- Resource right-sizing
- Automated cost alerts

## Troubleshooting

### Common Issues

1. **Pod Startup Failures**
   ```bash
   kubectl describe pod <pod-name> -n ms5-production
   kubectl logs <pod-name> -n ms5-production
   ```

2. **Service Connectivity Issues**
   ```bash
   kubectl get endpoints -n ms5-production
   kubectl get networkpolicies -n ms5-production
   ```

3. **Storage Issues**
   ```bash
   kubectl get pvc -n ms5-production
   kubectl describe pvc <pvc-name> -n ms5-production
   ```

4. **Resource Constraints**
   ```bash
   kubectl top pods -n ms5-production
   kubectl describe nodes
   ```

### Logs

Access logs for troubleshooting:

```bash
# Backend logs
kubectl logs -n ms5-production deployment/ms5-backend

# Database logs
kubectl logs -n ms5-production statefulset/postgres-primary

# Redis logs
kubectl logs -n ms5-production statefulset/redis-primary

# Monitoring logs
kubectl logs -n ms5-production deployment/prometheus
kubectl logs -n ms5-production deployment/grafana
```

## Next Steps

After successful Phase 2 deployment:

1. **Phase 3**: Storage & Database Migration
2. **Phase 4**: Backend Services Migration
3. **Phase 5**: Frontend & Networking
4. **Phase 6**: Monitoring & Observability
5. **Phase 7**: Security & Compliance
6. **Phase 8**: Testing & Optimization
7. **Phase 9**: CI/CD & GitOps
8. **Phase 10**: Production Deployment

## Support

For issues or questions:

- **DevOps Team**: devops@company.com
- **Documentation**: [MS5.0 Documentation](../documentation/)
- **Troubleshooting Guide**: [Troubleshooting Guide](../documentation/guides/TROUBLESHOOTING_GUIDE.md)

## License

Proprietary - MS5.0 Floor Dashboard
