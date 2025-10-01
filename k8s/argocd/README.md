# MS5.0 Floor Dashboard - ArgoCD GitOps Implementation
## Phase 9B: GitOps & Quality Gates - Complete Implementation

This directory contains the complete ArgoCD GitOps implementation for the MS5.0 Floor Dashboard, providing starship-grade deployment automation and quality assurance.

## 🚀 Overview

The ArgoCD implementation provides:
- **Declarative GitOps**: Infrastructure and applications managed as code
- **Automated Synchronization**: Continuous deployment with self-healing capabilities
- **Multi-Environment Support**: Staging and production environment management
- **Security-First Design**: RBAC, network policies, and secure secrets management
- **Comprehensive Monitoring**: Deployment observability and alerting

## 📁 Directory Structure

```
k8s/argocd/
├── 01-argocd-namespace.yaml      # Namespace and resource quotas
├── 02-argocd-install.yaml        # ArgoCD server deployment
├── 03-argocd-rbac.yaml           # Service accounts and RBAC
├── 04-argocd-services.yaml       # Service definitions
├── 05-argocd-repo-server.yaml    # Repository server deployment
├── 06-argocd-application-controller.yaml  # Application controller
├── 07-argocd-redis.yaml          # Redis cache for ArgoCD
├── 08-argocd-configmaps.yaml     # Configuration data
├── 09-ms5-project.yaml           # MS5.0 project definitions
├── 10-ms5-applications.yaml      # MS5.0 application definitions
├── deploy-argocd.sh              # Deployment automation script
└── README.md                     # This documentation
```

## 🛠 Installation

### Prerequisites

- Kubernetes cluster with admin access
- kubectl configured and connected
- Cluster admin permissions

### Quick Installation

```bash
# Deploy ArgoCD with all MS5.0 configurations
./deploy-argocd.sh
```

### Manual Installation

```bash
# 1. Create namespace and base configuration
kubectl apply -f 01-argocd-namespace.yaml

# 2. Deploy RBAC and configuration
kubectl apply -f 03-argocd-rbac.yaml
kubectl apply -f 08-argocd-configmaps.yaml

# 3. Deploy ArgoCD components
kubectl apply -f 07-argocd-redis.yaml
kubectl apply -f 05-argocd-repo-server.yaml
kubectl apply -f 06-argocd-application-controller.yaml
kubectl apply -f 02-argocd-install.yaml
kubectl apply -f 04-argocd-services.yaml

# 4. Configure MS5.0 projects and applications
kubectl apply -f 09-ms5-project.yaml
kubectl apply -f 10-ms5-applications.yaml
```

## 🔐 Access and Authentication

### Initial Setup

1. **Get Admin Password**:
   ```bash
   kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
   ```

2. **Access ArgoCD UI**:
   ```bash
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   ```
   Navigate to: https://localhost:8080

3. **Login Credentials**:
   - Username: `admin`
   - Password: (from step 1)

### RBAC Configuration

The implementation includes comprehensive RBAC with three roles:

- **Admin**: Full access to all applications and repositories
- **Developer**: Read/sync access to applications, read access to repositories
- **Readonly**: Read-only access to applications and logs

## 🏗 GitOps Repository Structure

```
k8s/gitops/
├── staging/
│   └── backend/
│       └── kustomization.yaml    # Staging-specific configurations
├── production/
│   └── backend/
│       └── kustomization.yaml    # Production-specific configurations
└── base/
    └── backend/                  # Base Kubernetes manifests
```

## 📊 Applications Configured

### Production Environment

- **ms5-backend**: FastAPI backend services
- **ms5-database**: PostgreSQL with TimescaleDB
- **ms5-monitoring**: Prometheus, Grafana, AlertManager
- **ms5-frontend**: React Native frontend application

### Staging Environment

- **ms5-backend-staging**: Staging backend with reduced resources
- **ms5-database-staging**: Staging database instance
- **ms5-monitoring-staging**: Staging monitoring stack

## 🔄 Sync Policies

### Automated Sync (Production)
- **Enabled**: Backend, Frontend, Monitoring
- **Self-Heal**: Automatically corrects configuration drift
- **Prune**: Removes resources not defined in Git

### Manual Sync (Database)
- **Database**: Requires manual approval for safety
- **Critical Infrastructure**: Manual sync for controlled changes

### Sync Windows
- **Business Hours**: Monday-Friday, 9 AM - 5 PM (allowed)
- **Off Hours**: Restricted for critical services
- **Manual Override**: Available for emergency deployments

## 📈 Monitoring and Observability

### ArgoCD Metrics
- Application sync status
- Deployment success/failure rates
- Resource health status
- Git repository connectivity

### Integration with Prometheus
```yaml
# ServiceMonitor for ArgoCD metrics
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-metrics
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-server-metrics
  endpoints:
  - port: metrics
```

### Grafana Dashboards
- ArgoCD Application Status
- Deployment Success Rate
- Sync Performance Metrics
- Resource Health Overview

## 🚨 Alerting

### Critical Alerts
- Application out of sync for >15 minutes
- Application unhealthy for >10 minutes
- Sync failure for >5 minutes
- Repository connectivity issues

### Alert Channels
- Slack: `#ms5-ci-cd`
- Email: DevOps team
- PagerDuty: Critical issues only

## 🔧 Troubleshooting

### Common Issues

1. **Application Out of Sync**
   ```bash
   # Force sync
   argocd app sync ms5-backend --force
   
   # Check sync status
   argocd app get ms5-backend
   ```

2. **Repository Access Issues**
   ```bash
   # Check repository connectivity
   argocd repo list
   
   # Test repository access
   argocd repo get https://github.com/your-org/MS5.0_App
   ```

3. **Resource Health Issues**
   ```bash
   # Check application health
   kubectl get applications -n argocd
   
   # Describe application for details
   kubectl describe application ms5-backend -n argocd
   ```

### Logs and Debugging

```bash
# ArgoCD server logs
kubectl logs -n argocd deployment/argocd-server

# Application controller logs
kubectl logs -n argocd statefulset/argocd-application-controller

# Repository server logs
kubectl logs -n argocd deployment/argocd-repo-server
```

## 🔄 Backup and Recovery

### Configuration Backup
```bash
# Export all ArgoCD applications
kubectl get applications -n argocd -o yaml > argocd-applications-backup.yaml

# Export projects
kubectl get appprojects -n argocd -o yaml > argocd-projects-backup.yaml
```

### Disaster Recovery
1. Redeploy ArgoCD using `deploy-argocd.sh`
2. Restore applications: `kubectl apply -f argocd-applications-backup.yaml`
3. Restore projects: `kubectl apply -f argocd-projects-backup.yaml`
4. Verify sync status and trigger manual sync if needed

## 🚀 Advanced Features

### Multi-Cluster Support
```yaml
# Add external cluster
argocd cluster add my-cluster-context --name production-cluster
```

### Application Sets (Future Enhancement)
```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: ms5-environments
spec:
  generators:
  - clusters: {}
  template:
    metadata:
      name: 'ms5-{{name}}'
    spec:
      project: ms5-production
      source:
        repoURL: https://github.com/your-org/MS5.0_App
        path: 'k8s/{{name}}'
      destination:
        server: '{{server}}'
        namespace: 'ms5-{{name}}'
```

### Progressive Delivery (Future Enhancement)
Integration with Argo Rollouts for:
- Blue-Green deployments
- Canary releases
- Automated rollbacks based on metrics

## 📚 Additional Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [GitOps Best Practices](https://www.gitops.tech/)
- [Kubernetes RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Kustomize Documentation](https://kustomize.io/)

## 🤝 Support

For issues and questions:
1. Check ArgoCD logs and application status
2. Review Git repository for configuration issues
3. Consult the troubleshooting section above
4. Contact the DevOps team via Slack: `#ms5-devops`

---

*This ArgoCD implementation provides enterprise-grade GitOps capabilities for the MS5.0 Floor Dashboard, ensuring reliable, secure, and automated deployments across all environments.*
