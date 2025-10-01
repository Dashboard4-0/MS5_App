# MS5.0 Floor Dashboard - Phase 5B: Networking & External Access

## Overview

Phase 5B implements comprehensive networking infrastructure and external access capabilities for the MS5.0 Floor Dashboard with the precision and reliability of a starship's nervous system. This phase establishes enterprise-grade networking, SSL/TLS management, security policies, and external access configuration.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           Internet / External Access                            │
└─────────────────────────┬───────────────────────────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────────────────────────┐
│                    Azure Application Gateway WAF                                │
│  • OWASP 3.2 Rules    • Rate Limiting    • Geo-blocking    • Bot Protection   │
└─────────────────────────┬───────────────────────────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────────────────────────┐
│                      Azure Load Balancer                                       │
│  • Health Probes      • Session Affinity    • Traffic Distribution            │
└─────────────────────────┬───────────────────────────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────────────────────────┐
│                    NGINX Ingress Controller                                    │
│  • SSL/TLS Termination • Security Headers  • Performance Optimization         │
│  • WebSocket Support   • Rate Limiting     • Factory Network Optimization     │
└─────────────────────────┬───────────────────────────────────────────────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
┌───────▼──────┐ ┌────────▼────────┐ ┌──────▼──────┐
│   Frontend   │ │   Backend API   │ │ Monitoring  │
│  Namespace   │ │   Namespace     │ │ Services    │
│              │ │                 │ │             │
│ • React App  │ │ • FastAPI       │ │ • Grafana   │
│ • PWA        │ │ • WebSocket     │ │ • Prometheus│
│ • Offline    │ │ • REST API      │ │ • AlertMgr  │
└──────────────┘ └─────────────────┘ └─────────────┘
```

## Components Deployed

### 1. NGINX Ingress Controller
- **Location**: `k8s/ingress/`
- **Features**:
  - High availability with 3 replicas
  - SSL/TLS termination
  - Security headers enforcement
  - WebSocket support
  - Factory network optimizations
  - Performance tuning for tablets

### 2. cert-manager
- **Location**: `k8s/cert-manager/`
- **Features**:
  - Automated SSL/TLS certificate management
  - Let's Encrypt integration
  - DNS-01 and HTTP-01 challenge solvers
  - Certificate auto-renewal
  - Multiple domain support

### 3. Azure Key Vault Integration
- **Location**: `k8s/azure-keyvault/`
- **Features**:
  - Secure secrets management
  - Certificate storage
  - Automated secret synchronization
  - Workload identity integration
  - Secret rotation

### 4. Network Security
- **Location**: `k8s/network-security/`
- **Features**:
  - Zero-trust networking
  - Micro-segmentation
  - Default deny-all policies
  - Service-to-service communication control
  - Ingress controller isolation

### 5. Web Application Firewall
- **Location**: `k8s/azure-waf/`
- **Features**:
  - OWASP 3.2 rule set
  - Custom security rules
  - Rate limiting
  - Geo-blocking
  - Bot protection

## Domains and SSL Certificates

### Primary Domains
- `ms5floor.com` - Main application
- `www.ms5floor.com` - WWW redirect
- `api.ms5floor.com` - API endpoints
- `ws.ms5floor.com` - WebSocket connections
- `wss.ms5floor.com` - Secure WebSocket

### Monitoring Domains
- `monitoring.ms5floor.com` - General monitoring
- `grafana.ms5floor.com` - Grafana dashboards
- `prometheus.ms5floor.com` - Prometheus metrics
- `alerts.ms5floor.com` - AlertManager

### Status Domains
- `status.ms5floor.com` - Public status page
- `health.ms5floor.com` - Health checks

## Security Features

### SSL/TLS Security
- **TLS 1.2/1.3 enforcement**
- **Strong cipher suites only**
- **HSTS headers**
- **Certificate pinning**
- **Automated renewal**

### Network Security
- **Zero-trust networking**
- **Micro-segmentation**
- **Network policies**
- **Traffic encryption**
- **Access control**

### Application Security
- **WAF protection**
- **Rate limiting**
- **DDoS protection**
- **Security headers**
- **Content Security Policy**

### Factory Environment Security
- **IP whitelisting**
- **Factory network isolation**
- **Device authentication**
- **Secure communication**
- **Audit logging**

## Performance Optimizations

### Network Performance
- **Connection pooling**
- **Keep-alive optimization**
- **Compression (Gzip/Brotli)**
- **HTTP/2 support**
- **CDN integration**

### Factory Network Optimization
- **Extended timeouts**
- **Retry mechanisms**
- **Offline capability**
- **Background sync**
- **Network resilience**

### Tablet Optimization
- **Touch-friendly interfaces**
- **Landscape orientation**
- **Haptic feedback**
- **Performance monitoring**
- **Resource optimization**

## Deployment

### Prerequisites
- Kubernetes cluster (AKS)
- Azure CLI authenticated
- kubectl configured
- Helm 3.x installed
- Phase 5A completed

### Automated Deployment
```bash
# Make script executable
chmod +x k8s/deploy-phase5b.sh

# Set required environment variables
export AZURE_SUBSCRIPTION_ID="your-subscription-id"
export AZURE_RESOURCE_GROUP="your-resource-group"
export AZURE_CLIENT_ID="your-client-id"
export AZURE_TENANT_ID="your-tenant-id"
export AZURE_KEYVAULT_NAME="your-keyvault-name"

# Run deployment
./k8s/deploy-phase5b.sh
```

### Manual Deployment
```bash
# 1. Deploy NGINX Ingress Controller
kubectl apply -f k8s/ingress/01-nginx-namespace.yaml
kubectl apply -f k8s/ingress/02-nginx-deployment.yaml
kubectl apply -f k8s/ingress/03-nginx-service.yaml
kubectl apply -f k8s/ingress/04-nginx-configmap.yaml
kubectl apply -f k8s/ingress/05-nginx-ingressclass.yaml

# 2. Deploy cert-manager
kubectl apply -f k8s/cert-manager/01-cert-manager-namespace.yaml
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager --namespace cert-manager --version v1.13.2
kubectl apply -f k8s/cert-manager/02-cluster-issuer.yaml
kubectl apply -f k8s/cert-manager/03-certificates.yaml

# 3. Deploy Azure Key Vault CSI Driver
helm repo add csi-secrets-store-provider-azure https://azure.github.io/secrets-store-csi-driver-provider-azure/charts
helm install csi-secrets-store-driver secrets-store-csi-driver/secrets-store-csi-driver --namespace kube-system
helm install csi-secrets-store-provider-azure csi-secrets-store-provider-azure/csi-secrets-store-provider-azure --namespace kube-system
kubectl apply -f k8s/azure-keyvault/01-keyvault-csi-driver.yaml

# 4. Apply Network Security
kubectl apply -f k8s/network-security/01-enhanced-network-policies.yaml

# 5. Deploy Ingress Rules
kubectl apply -f k8s/ingress/06-ms5-comprehensive-ingress.yaml

# 6. Configure WAF
kubectl apply -f k8s/azure-waf/01-application-gateway-waf.yaml
```

## Validation

### Health Checks
```bash
# Check NGINX Ingress Controller
kubectl get pods -n ingress-nginx
kubectl get service ingress-nginx-controller -n ingress-nginx

# Check cert-manager
kubectl get pods -n cert-manager
kubectl get certificates -n ms5-production

# Check ingress resources
kubectl get ingress -A

# Check network policies
kubectl get networkpolicies -A
```

### External Access Testing
```bash
# Test main application
curl -I https://ms5floor.com

# Test API endpoint
curl -I https://api.ms5floor.com/health

# Test WebSocket (requires wscat)
wscat -c wss://ws.ms5floor.com/ws

# Test monitoring (requires authentication)
curl -I https://grafana.ms5floor.com
```

### SSL Certificate Validation
```bash
# Check certificate status
kubectl describe certificate ms5-tls-certificate -n ms5-production

# Test SSL configuration
openssl s_client -connect ms5floor.com:443 -servername ms5floor.com
```

## Monitoring

### Metrics Endpoints
- NGINX Ingress Controller: `:10254/metrics`
- cert-manager: `:9402/metrics`
- Azure Key Vault CSI Driver: `:8080/metrics`

### Dashboards
- **Ingress Controller Performance**
- **SSL Certificate Status**
- **Network Policy Compliance**
- **WAF Security Events**
- **External Access Monitoring**

### Alerts
- Certificate expiry warnings
- Ingress controller failures
- Network policy violations
- WAF attack detection
- External access failures

## Troubleshooting

### Common Issues

#### 1. Certificate Not Issued
```bash
# Check certificate status
kubectl describe certificate ms5-tls-certificate -n ms5-production

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Check ACME challenge
kubectl get challenges -A
```

#### 2. Ingress Not Working
```bash
# Check ingress controller logs
kubectl logs -n ingress-nginx deployment/ingress-nginx-controller

# Check ingress resource
kubectl describe ingress ms5-main-ingress -n ms5-frontend

# Check service endpoints
kubectl get endpoints -n ms5-frontend
```

#### 3. Network Policy Issues
```bash
# Check network policies
kubectl get networkpolicies -A

# Test connectivity
kubectl run test-pod --image=busybox --rm -it -- /bin/sh

# Check policy logs (if available)
kubectl logs -n kube-system -l k8s-app=calico-node
```

#### 4. Azure Key Vault Access
```bash
# Check CSI driver logs
kubectl logs -n kube-system -l app=secrets-store-csi-driver

# Check SecretProviderClass
kubectl describe secretproviderclass ms5-keyvault-secrets -n ms5-production

# Check pod events
kubectl describe pod <pod-name> -n ms5-production
```

## Security Considerations

### Network Security
- All traffic encrypted in transit
- Network policies enforce micro-segmentation
- Default deny-all with explicit allow rules
- Regular security policy audits

### Certificate Management
- Automated certificate renewal
- Certificate monitoring and alerting
- Secure private key storage
- Certificate transparency logging

### Access Control
- RBAC for all components
- Least privilege principles
- Regular access reviews
- Audit logging enabled

### Factory Environment
- IP whitelisting for factory networks
- Device authentication required
- Secure communication protocols
- Physical security considerations

## Performance Metrics

### Target Metrics
- **SSL/TLS Termination**: < 5ms additional latency
- **Ingress Routing**: < 2ms routing decision time
- **Certificate Renewal**: Automated 30 days before expiry
- **Network Policy Enforcement**: < 1ms per packet
- **WAF Inspection**: < 10ms per request
- **Availability**: 99.9% uptime target

### Monitoring KPIs
- Request latency percentiles (p50, p95, p99)
- Error rates by service
- Certificate expiry timeline
- Network policy violations
- WAF blocked requests
- External access success rate

## Next Steps

After Phase 5B completion:

1. **Verify DNS Configuration**: Ensure all DNS records point to the correct IP
2. **Test External Access**: Validate all endpoints are accessible
3. **Monitor Certificate Issuance**: Confirm SSL certificates are issued
4. **Security Testing**: Perform penetration testing
5. **Performance Testing**: Load test all endpoints
6. **Proceed to Phase 6**: Monitoring & Observability implementation

## Support

### Documentation
- **Architecture Diagrams**: Available in `docs/architecture/`
- **Runbooks**: Available in `docs/runbooks/`
- **Troubleshooting Guides**: Available in `docs/troubleshooting/`

### Contact Information
- **Team**: team@ms5floor.com
- **Emergency**: Available 24/7 for production issues
- **Documentation**: Comprehensive guides in repository

### Resources
- **Kubernetes Documentation**: https://kubernetes.io/docs/
- **NGINX Ingress Controller**: https://kubernetes.github.io/ingress-nginx/
- **cert-manager**: https://cert-manager.io/docs/
- **Azure Key Vault CSI Driver**: https://azure.github.io/secrets-store-csi-driver-provider-azure/

---

*This implementation provides enterprise-grade networking infrastructure with the precision and reliability required for mission-critical manufacturing systems.*
