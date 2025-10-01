# MS5.0 Floor Dashboard - AKS Optimization Work Plan

## Executive Summary

This document provides a comprehensive, phased work plan to optimize the MS5.0 Floor Dashboard codebase for full deployment, hosting, and operation on Azure Kubernetes Service (AKS). The current system is architected for Docker Compose deployment and requires significant transformation to be AKS-ready.

**Project Duration**: 10-12 weeks  
**Team Size**: 3-4 engineers (DevOps, Backend, Frontend, Database)  
**Estimated Cost**: $750-1,400/month operational costs  

## Current System Analysis

### Architecture Overview
- **Backend**: FastAPI with PostgreSQL/TimescaleDB, Redis, Celery workers
- **Frontend**: React Native tablet application
- **Monitoring**: Prometheus, Grafana, AlertManager
- **Storage**: MinIO object storage
- **Infrastructure**: Docker Compose with Nginx reverse proxy

### Services Inventory
1. **postgres** - PostgreSQL 15 with TimescaleDB extension
2. **redis** - Redis 7 cache and session storage
3. **backend** - FastAPI application server
4. **nginx** - Reverse proxy and load balancer
5. **prometheus** - Metrics collection and storage
6. **grafana** - Monitoring dashboards
7. **minio** - Object storage service
8. **celery_worker** - Background task processing
9. **celery_beat** - Scheduled task scheduler
10. **flower** - Celery monitoring interface

---

## Phase 1: Infrastructure Preparation (Week 1-2)

### Objectives
- Set up Azure infrastructure foundation
- Configure container registry and AKS cluster
- Establish security and secrets management

### Detailed Tasks

#### 1.1 Azure Resource Setup
- [ ] Create Azure Resource Group for MS5.0 AKS deployment
- [ ] Set up Azure Container Registry (ACR) with geo-replication
- [ ] Configure ACR with vulnerability scanning and image signing
- [ ] Create Azure Key Vault for secrets management
- [ ] Set up Azure Monitor and Log Analytics workspace

#### 1.2 AKS Cluster Configuration
- [ ] Create AKS cluster with 3+ nodes (Standard_D4s_v3 minimum)
- [ ] Configure node pools for different workload types
- [ ] Set up Azure CNI networking for advanced networking features
- [ ] Configure cluster autoscaling and node auto-repair
- [ ] Enable Azure Policy for governance and compliance

#### 1.3 Security Foundation
- [ ] Configure Azure AD integration for cluster access
- [ ] Set up RBAC with least privilege access
- [ ] Enable Pod Security Standards enforcement
- [ ] Configure network policies for traffic control
- [ ] Set up Azure Security Center integration

#### 1.4 Container Registry Setup
- [ ] Push all existing Docker images to ACR
- [ ] Configure ACR authentication for AKS cluster
- [ ] Set up image scanning and vulnerability management
- [ ] Create image retention policies
- [ ] Configure ACR webhooks for automated builds

### Deliverables
- ✅ AKS cluster running and accessible
- ✅ ACR configured with all images pushed
- ✅ Azure Key Vault configured with initial secrets
- ✅ Security policies and RBAC configured
- ✅ Monitoring and logging infrastructure ready

### Success Criteria
- AKS cluster is healthy and accessible via kubectl
- All Docker images are available in ACR
- Security scanning is enabled and passing
- Azure Monitor is collecting cluster metrics

---

## Phase 2: Kubernetes Manifests Creation (Week 2-3)

### Objectives
- Create comprehensive Kubernetes manifests for all services
- Implement proper resource management and scaling
- Configure service discovery and networking

### Detailed Tasks

#### 2.1 Namespace and Base Configuration
- [ ] Create `ms5-namespace.yaml` with resource quotas
- [ ] Create `configmap.yaml` for non-sensitive configuration
- [ ] Create `secrets.yaml` for sensitive data (passwords, keys)
- [ ] Set up Azure Key Vault CSI driver for secret injection

#### 2.2 Database Services Manifests
- [ ] Create PostgreSQL deployment with persistent storage
- [ ] Configure TimescaleDB extension in PostgreSQL
- [ ] Set up PostgreSQL service and headless service
- [ ] Create PersistentVolumeClaim for database storage
- [ ] Configure PostgreSQL ConfigMap with initialization scripts
- [ ] Implement database backup and restore procedures

#### 2.3 Cache and Session Storage
- [ ] Create Redis deployment with persistence
- [ ] Configure Redis service and headless service
- [ ] Create PersistentVolumeClaim for Redis data
- [ ] Set up Redis ConfigMap with configuration
- [ ] Configure Redis clustering for high availability

#### 2.4 Backend Application Services
- [ ] Create FastAPI backend deployment
- [ ] Configure backend service and load balancer
- [ ] Set up Horizontal Pod Autoscaler (HPA) for backend
- [ ] Create Celery worker deployment with scaling
- [ ] Create Celery beat scheduler deployment
- [ ] Create Flower monitoring deployment
- [ ] Configure resource requests and limits for all services

#### 2.5 Storage Services
- [ ] Create MinIO deployment with persistent storage
- [ ] Configure MinIO service and ingress
- [ ] Create PersistentVolumeClaim for object storage
- [ ] Set up MinIO ConfigMap with policies and buckets

#### 2.6 Monitoring Stack
- [ ] Create Prometheus deployment with persistent storage
- [ ] Configure Prometheus service and ConfigMap
- [ ] Create Grafana deployment with persistent storage
- [ ] Set up Grafana ConfigMap with dashboards and datasources
- [ ] Create AlertManager deployment and configuration
- [ ] Configure PersistentVolumeClaims for monitoring data

### Deliverables
- ✅ Complete set of Kubernetes manifests for all services
- ✅ Resource management and scaling configurations
- ✅ Service discovery and networking setup
- ✅ Persistent storage configurations
- ✅ Monitoring and alerting configurations

### Success Criteria
- All manifests are syntactically correct and validated
- Resource requests and limits are properly configured
- Services can discover each other via DNS
- Persistent storage is properly configured

---

## Phase 3: Storage & Database Migration (Week 3-4)

### Objectives
- Migrate PostgreSQL database to AKS with persistent storage
- Configure TimescaleDB extension and time-series data
- Implement backup and disaster recovery procedures

### Detailed Tasks

#### 3.1 Database Infrastructure Setup
- [ ] Deploy PostgreSQL StatefulSet with persistent storage
- [ ] Configure Azure Premium SSD storage for database
- [ ] Set up database initialization scripts and migrations
- [ ] Configure PostgreSQL connection pooling and optimization
- [ ] Implement database health checks and readiness probes

#### 3.2 TimescaleDB Configuration
- [ ] Install and configure TimescaleDB extension
- [ ] Set up time-series tables and hypertables
- [ ] Configure data retention policies
- [ ] Optimize TimescaleDB for telemetry data
- [ ] Test time-series query performance

#### 3.3 Data Migration
- [ ] Export existing database schema and data
- [ ] Create database migration scripts
- [ ] Test migration process in staging environment
- [ ] Execute production data migration
- [ ] Validate data integrity and consistency
- [ ] Update application connection strings

#### 3.4 Backup and Recovery
- [ ] Set up automated database backups to Azure Blob Storage
- [ ] Configure point-in-time recovery procedures
- [ ] Test backup and restore processes
- [ ] Document disaster recovery procedures
- [ ] Set up database monitoring and alerting

#### 3.5 Performance Optimization
- [ ] Configure PostgreSQL performance parameters
- [ ] Set up database connection pooling
- [ ] Implement query optimization and indexing
- [ ] Configure database monitoring and metrics
- [ ] Test database performance under load

### Deliverables
- ✅ PostgreSQL running in AKS with persistent storage
- ✅ TimescaleDB extension configured and optimized
- ✅ Database migration completed successfully
- ✅ Backup and recovery procedures implemented
- ✅ Database performance optimized and monitored

### Success Criteria
- Database is accessible and responding to queries
- TimescaleDB extension is working correctly
- Data migration is complete with no data loss
- Backup procedures are tested and working
- Database performance meets requirements

---

## Phase 4: Backend Services Migration (Week 4-5)

### Objectives
- Deploy FastAPI backend services to AKS
- Configure Celery workers and background tasks
- Set up Redis cache and session management

### Detailed Tasks

#### 4.1 Backend API Deployment
- [ ] Deploy FastAPI backend with proper resource allocation
- [ ] Configure environment variables from ConfigMaps and Secrets
- [ ] Set up health checks and readiness probes
- [ ] Configure horizontal pod autoscaling
- [ ] Implement graceful shutdown and startup procedures

#### 4.2 Celery Workers Configuration
- [ ] Deploy Celery worker pods with scaling configuration
- [ ] Configure Celery beat scheduler for periodic tasks
- [ ] Set up Flower monitoring interface
- [ ] Configure task routing and queue management
- [ ] Implement worker health monitoring and auto-restart

#### 4.3 Redis Cache Setup
- [ ] Deploy Redis with persistence and clustering
- [ ] Configure Redis for session storage and caching
- [ ] Set up Redis monitoring and metrics collection
- [ ] Configure Redis backup and recovery procedures
- [ ] Test Redis performance and failover scenarios

#### 4.4 Service Integration
- [ ] Configure service-to-service communication
- [ ] Set up API gateway and load balancing
- [ ] Implement circuit breakers and retry policies
- [ ] Configure request tracing and logging
- [ ] Test end-to-end service communication

#### 4.5 Background Tasks Migration
- [ ] Migrate existing Celery tasks to AKS environment
- [ ] Configure task scheduling and monitoring
- [ ] Set up task failure handling and retry mechanisms
- [ ] Implement task result storage and retrieval
- [ ] Test background task execution and performance

### Deliverables
- ✅ FastAPI backend running in AKS
- ✅ Celery workers and beat scheduler deployed
- ✅ Redis cache configured and operational
- ✅ Service communication working correctly
- ✅ Background tasks executing properly

### Success Criteria
- Backend API is responding to requests
- Celery workers are processing tasks
- Redis cache is working correctly
- Service discovery and communication is functional
- Background tasks are executing as expected

---

## Phase 5: Frontend & Networking (Week 5-6)

### Objectives
- Deploy React Native frontend application
- Configure ingress controller and external access
- Set up SSL/TLS certificates and security

### Detailed Tasks

#### 5.1 Frontend Application Deployment
- [ ] Build React Native application for production
- [ ] Create frontend deployment manifests
- [ ] Configure static file serving and CDN
- [ ] Set up frontend health checks and monitoring
- [ ] Implement frontend scaling and load balancing

#### 5.2 Ingress Controller Setup
- [ ] Deploy NGINX Ingress Controller or Azure Application Gateway
- [ ] Configure ingress rules for external access
- [ ] Set up SSL/TLS certificates with Let's Encrypt or Azure Key Vault
- [ ] Configure custom domains and DNS
- [ ] Implement rate limiting and DDoS protection

#### 5.3 Network Security Configuration
- [ ] Set up network policies for traffic control
- [ ] Configure firewall rules and security groups
- [ ] Implement Web Application Firewall (WAF)
- [ ] Set up VPN or private endpoint access
- [ ] Configure network monitoring and logging

#### 5.4 Load Balancing and Traffic Management
- [ ] Configure Azure Load Balancer or Application Gateway
- [ ] Set up traffic routing and load balancing algorithms
- [ ] Implement blue-green or canary deployment strategies
- [ ] Configure session affinity and sticky sessions
- [ ] Test load balancing and failover scenarios

#### 5.5 External Access Configuration
- [ ] Set up public IP addresses and DNS records
- [ ] Configure external access policies and restrictions
- [ ] Implement API rate limiting and throttling
- [ ] Set up monitoring for external access and performance
- [ ] Test external connectivity and performance

### Deliverables
- ✅ React Native frontend deployed and accessible
- ✅ Ingress controller configured with SSL/TLS
- ✅ External access working correctly
- ✅ Network security policies implemented
- ✅ Load balancing and traffic management configured

### Success Criteria
- Frontend application is accessible via external URL
- SSL/TLS certificates are valid and working
- Network security policies are enforced
- Load balancing is distributing traffic correctly
- External access performance meets requirements

---

## Phase 6: Monitoring & Observability (Week 6-7)

### Objectives
- Deploy comprehensive monitoring stack
- Configure alerting and notification systems
- Set up log aggregation and analysis

### Detailed Tasks

#### 6.1 Prometheus Deployment
- [ ] Deploy Prometheus with persistent storage
- [ ] Configure Prometheus ConfigMap with scrape targets
- [ ] Set up service discovery for dynamic target monitoring
- [ ] Configure Prometheus federation for multi-cluster monitoring
- [ ] Implement Prometheus backup and retention policies

#### 6.2 Grafana Configuration
- [ ] Deploy Grafana with persistent storage
- [ ] Configure Grafana datasources and dashboards
- [ ] Set up custom dashboards for MS5.0 metrics
- [ ] Configure Grafana alerting rules and notifications
- [ ] Implement Grafana user management and access control

#### 6.3 AlertManager Setup
- [ ] Deploy AlertManager with configuration
- [ ] Configure alert routing and notification channels
- [ ] Set up email, Slack, and SMS notifications
- [ ] Implement alert grouping and suppression
- [ ] Configure escalation policies and on-call rotations

#### 6.4 Application Metrics Integration
- [ ] Integrate application metrics with Prometheus
- [ ] Configure custom metrics for business KPIs
- [ ] Set up distributed tracing with Jaeger or Zipkin
- [ ] Implement log aggregation with ELK stack or Azure Monitor
- [ ] Configure metrics export for Azure Monitor

#### 6.5 Monitoring Dashboards
- [ ] Create system health dashboards
- [ ] Set up application performance dashboards
- [ ] Configure business metrics dashboards
- [ ] Implement real-time monitoring and alerting
- [ ] Set up capacity planning and resource utilization dashboards

### Deliverables
- ✅ Prometheus collecting metrics from all services
- ✅ Grafana dashboards displaying key metrics
- ✅ AlertManager configured with notification channels
- ✅ Application metrics integrated and visible
- ✅ Log aggregation and analysis working

### Success Criteria
- All services are being monitored by Prometheus
- Grafana dashboards are displaying accurate data
- Alerting is working and notifications are being sent
- Application metrics are being collected and displayed
- Log aggregation is working correctly

---

## Phase 7: Security & Compliance (Week 7-8)

### Objectives
- Implement comprehensive security measures
- Configure compliance and governance policies
- Set up security scanning and vulnerability management

### Detailed Tasks

#### 7.1 Pod Security Implementation
- [ ] Enforce Pod Security Standards across all namespaces
- [ ] Configure security contexts for all containers
- [ ] Implement non-root user execution
- [ ] Set up read-only root filesystems where possible
- [ ] Configure security capabilities and drop unnecessary ones

#### 7.2 Network Security Configuration
- [ ] Implement network policies for traffic control
- [ ] Configure service mesh security (optional Istio)
- [ ] Set up TLS encryption for all service communication
- [ ] Implement network segmentation and micro-segmentation
- [ ] Configure network monitoring and intrusion detection

#### 7.3 Secrets Management
- [ ] Migrate all secrets to Azure Key Vault
- [ ] Configure Azure Key Vault CSI driver
- [ ] Implement secret rotation policies
- [ ] Set up secret monitoring and access logging
- [ ] Configure secret encryption at rest and in transit

#### 7.4 Container Security
- [ ] Implement container image scanning
- [ ] Configure vulnerability management and patching
- [ ] Set up container runtime security monitoring
- [ ] Implement container compliance scanning
- [ ] Configure container security policies and admission controllers

#### 7.5 Compliance and Governance
- [ ] Implement Azure Policy for governance
- [ ] Configure compliance scanning and reporting
- [ ] Set up audit logging and compliance monitoring
- [ ] Implement data protection and privacy controls
- [ ] Configure regulatory compliance frameworks (GDPR, SOC2, etc.)

### Deliverables
- ✅ Pod Security Standards enforced across cluster
- ✅ Network policies implemented and working
- ✅ Secrets managed through Azure Key Vault
- ✅ Container security scanning configured
- ✅ Compliance policies implemented and monitored

### Success Criteria
- Security policies are enforced and violations are blocked
- Network traffic is properly segmented and controlled
- Secrets are securely managed and rotated
- Container vulnerabilities are identified and patched
- Compliance requirements are met and monitored

---

## Phase 8: Testing & Optimization (Week 8-9)

### Objectives
- Conduct comprehensive testing of the AKS deployment
- Optimize performance and resource utilization
- Validate disaster recovery and business continuity

### Detailed Tasks

#### 8.1 Performance Testing
- [ ] Conduct load testing of all services
- [ ] Test horizontal and vertical scaling capabilities
- [ ] Validate database performance under load
- [ ] Test API response times and throughput
- [ ] Measure resource utilization and optimization opportunities

#### 8.2 Security Testing
- [ ] Conduct penetration testing and vulnerability assessment
- [ ] Test security policies and network controls
- [ ] Validate secrets management and access controls
- [ ] Test incident response and security monitoring
- [ ] Conduct compliance validation and audit

#### 8.3 Disaster Recovery Testing
- [ ] Test database backup and restore procedures
- [ ] Validate cluster failover and recovery scenarios
- [ ] Test application recovery and data consistency
- [ ] Conduct disaster recovery drills and procedures
- [ ] Validate business continuity and RTO/RPO objectives

#### 8.4 End-to-End Testing
- [ ] Test complete user workflows and business processes
- [ ] Validate integration between all services
- [ ] Test real-time features and WebSocket connections
- [ ] Validate background task processing and scheduling
- [ ] Test monitoring and alerting end-to-end

#### 8.5 Optimization and Tuning
- [ ] Optimize resource allocation and requests/limits
- [ ] Tune database performance and query optimization
- [ ] Optimize application performance and caching
- [ ] Configure auto-scaling policies and thresholds
- [ ] Implement cost optimization and resource efficiency

### Deliverables
- ✅ Performance testing completed with results documented
- ✅ Security testing passed with vulnerabilities addressed
- ✅ Disaster recovery procedures tested and validated
- ✅ End-to-end testing completed successfully
- ✅ System optimized for production performance

### Success Criteria
- Performance meets or exceeds requirements
- Security testing passes with no critical vulnerabilities
- Disaster recovery procedures work correctly
- All business processes function correctly
- System is optimized for cost and performance

---

## Phase 9: CI/CD & GitOps (Week 9-10)

### Objectives
- Implement automated deployment pipelines
- Set up GitOps workflows for continuous deployment
- Configure automated testing and quality gates

### Detailed Tasks

#### 9.1 CI/CD Pipeline Setup
- [ ] Set up Azure DevOps or GitHub Actions pipelines
- [ ] Configure automated builds and image creation
- [ ] Implement automated testing in CI/CD
- [ ] Set up automated security scanning in pipelines
- [ ] Configure automated deployment to staging and production

#### 9.2 GitOps Implementation
- [ ] Set up ArgoCD or Flux for GitOps
- [ ] Configure Git repository structure for GitOps
- [ ] Implement automated synchronization and deployment
- [ ] Set up GitOps monitoring and alerting
- [ ] Configure rollback and recovery procedures

#### 9.3 Automated Testing Integration
- [ ] Integrate unit tests in CI/CD pipeline
- [ ] Set up integration tests in staging environment
- [ ] Configure automated end-to-end testing
- [ ] Implement automated performance testing
- [ ] Set up automated security testing and scanning

#### 9.4 Quality Gates and Approval Processes
- [ ] Configure quality gates for code promotion
- [ ] Set up automated approval processes
- [ ] Implement change management and approval workflows
- [ ] Configure deployment validation and rollback triggers
- [ ] Set up compliance and governance checks

#### 9.5 Monitoring and Observability Integration
- [ ] Integrate deployment monitoring with CI/CD
- [ ] Set up automated rollback on failure detection
- [ ] Configure deployment success/failure notifications
- [ ] Implement deployment metrics and reporting
- [ ] Set up automated health checks post-deployment

### Deliverables
- ✅ CI/CD pipelines configured and working
- ✅ GitOps workflows implemented
- ✅ Automated testing integrated
- ✅ Quality gates and approval processes configured
- ✅ Deployment monitoring and rollback procedures working

### Success Criteria
- Code changes are automatically built and tested
- Deployments are automated and consistent
- Quality gates prevent bad deployments
- Rollback procedures work correctly
- Deployment monitoring provides visibility

---

## Phase 10: Production Deployment (Week 10-12)

### Objectives
- Execute final production deployment
- Conduct go-live activities and validation
- Establish production support and maintenance procedures

### Detailed Tasks

#### 10.1 Pre-Production Validation
- [ ] Conduct final pre-production testing
- [ ] Validate all configurations and settings
- [ ] Test disaster recovery and backup procedures
- [ ] Conduct security validation and compliance check
- [ ] Prepare production deployment runbook

#### 10.2 Production Deployment Execution
- [ ] Execute production deployment during maintenance window
- [ ] Monitor deployment progress and health
- [ ] Validate all services are running correctly
- [ ] Test critical business functions and workflows
- [ ] Confirm monitoring and alerting are working

#### 10.3 Go-Live Activities
- [ ] Switch traffic from old system to AKS deployment
- [ ] Monitor system performance and stability
- [ ] Validate user access and functionality
- [ ] Test real-time features and integrations
- [ ] Confirm all business processes are working

#### 10.4 Post-Deployment Validation
- [ ] Conduct comprehensive system validation
- [ ] Monitor performance metrics and KPIs
- [ ] Validate security and compliance requirements
- [ ] Test disaster recovery and backup procedures
- [ ] Document any issues and resolution procedures

#### 10.5 Production Support Setup
- [ ] Establish production support procedures
- [ ] Set up on-call rotation and escalation procedures
- [ ] Configure production monitoring and alerting
- [ ] Document troubleshooting and maintenance procedures
- [ ] Train support team on AKS deployment

### Deliverables
- ✅ Production deployment completed successfully
- ✅ All services running correctly in production
- ✅ Go-live activities completed without issues
- ✅ Production support procedures established
- ✅ Team trained on production AKS deployment

### Success Criteria
- Production deployment is stable and performing well
- All business functions are working correctly
- Monitoring and alerting are providing visibility
- Support team is trained and ready
- Disaster recovery procedures are validated

---

## Resource Requirements and Costs

### Team Requirements
- **DevOps Engineer** (Lead) - Full-time for 10-12 weeks
- **Backend Developer** - Full-time for 8-10 weeks
- **Database Administrator** - Part-time for 4-6 weeks
- **Security Engineer** - Part-time for 2-4 weeks

### Infrastructure Costs (Monthly)
- **AKS Cluster**: $300-500 (3+ nodes, Standard_D4s_v3)
- **Azure Container Registry**: $50-100
- **Storage (Premium SSD)**: $200-400
- **Load Balancer**: $100-200
- **Monitoring & Logging**: $100-200
- **Total Estimated**: $750-1,400/month

### Additional Costs
- **Azure Key Vault**: $50-100/month
- **Azure Monitor**: $100-200/month
- **SSL Certificates**: $50-100/year
- **Domain and DNS**: $50-100/year

---

## Risk Management

### High-Risk Areas
1. **Database Migration**: Risk of data loss or corruption
2. **Service Dependencies**: Complex inter-service dependencies
3. **Performance**: Potential performance degradation
4. **Security**: Security vulnerabilities during migration
5. **Downtime**: Extended downtime during migration

### Mitigation Strategies
1. **Comprehensive Testing**: Extensive testing in staging environment
2. **Backup Procedures**: Multiple backup and recovery procedures
3. **Rollback Plans**: Detailed rollback procedures for each phase
4. **Security Scanning**: Continuous security scanning and validation
5. **Gradual Migration**: Phased migration with validation at each step

---

## Success Metrics

### Technical Metrics
- **Availability**: 99.9% uptime target
- **Performance**: API response time < 200ms
- **Scalability**: Auto-scaling working correctly
- **Security**: Zero critical vulnerabilities
- **Monitoring**: 100% service coverage

### Business Metrics
- **Deployment Time**: < 30 minutes for full deployment
- **Recovery Time**: < 15 minutes for service recovery
- **Cost Optimization**: 20-30% cost reduction vs. current infrastructure
- **Operational Efficiency**: 50% reduction in manual operations
- **Developer Productivity**: 40% faster deployment cycles

---

## Conclusion

This comprehensive work plan provides a structured approach to migrating the MS5.0 Floor Dashboard from Docker Compose to Azure Kubernetes Service. The phased approach ensures minimal risk while maximizing the benefits of cloud-native architecture.

The migration will provide:
- **Improved Scalability**: Auto-scaling and resource optimization
- **Enhanced Reliability**: Kubernetes self-healing and high availability
- **Better Security**: Azure-native security features and compliance
- **Operational Efficiency**: Automated deployments and monitoring
- **Cost Optimization**: Pay-per-use model and resource efficiency

The estimated timeline of 10-12 weeks with a dedicated team will ensure a successful migration with minimal business disruption.

---

*This work plan is based on the comprehensive analysis of the MS5.0 Floor Dashboard codebase and provides a detailed roadmap for AKS optimization and deployment.*
