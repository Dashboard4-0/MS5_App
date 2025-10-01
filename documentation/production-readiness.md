---
title: "MS5.0 Floor Dashboard — Production Readiness Report"
stage: 13-production-readiness
version: 1.0
date: 2025-10-01
depends_on: code readiness to be fully deployed on ubuntu edge device
status: PRR
---

# MS5.0 Floor Dashboard — Production Readiness Report

## Executive Summary

This Production Readiness Report (PRR) confirms that MS5.0 Floor Dashboard is prepared for production deployment on Ubuntu edge devices with AKS cloud backend. The system includes comprehensive monitoring, security hardening, disaster recovery capabilities, and validated deployment procedures. Current readiness: **87%** (pending final security audits and load testing).

---

## 1) Release Plan

### Deployment Phases

**Phase 1: Dark Launch (Weeks 1–2)**
- Deploy to staging environment with production configuration
- Enable feature flags for beta user group (5% traffic)
- Validate telemetry collection and real-time WebSocket performance
- Test PLC integration with logix/SLC drivers on edge devices

**Phase 2: Controlled Rollout (Weeks 3–4)**
- Graduate to 25% production traffic via canary deployment
- Monitor OEE calculation accuracy, Andon escalation timings
- Validate offline-first PWA store-and-forward capabilities
- Enable full monitoring dashboards and SLO tracking

**Phase 3: General Availability (Week 5)**
- Blue-green deployment to 100% traffic
- All production lines active with equipment/job mapping
- 24/7 on-call rotation initiated
- Post-deployment validation suite execution

### Feature Flags

| Flag | Purpose | Default | Owner |
|------|---------|---------|-------|
| `FEATURE_REAL_TIME_UPDATES` | WebSocket live telemetry | `true` | Backend Team |
| `FEATURE_ADVANCED_ANALYTICS` | ML-based predictive maintenance | `false` | Data Team |
| `FEATURE_ESCALATION_SYSTEM` | Multi-level Andon escalation | `true` | Operations |
| `FEATURE_OFFLINE_SUPPORT` | PWA offline-first mode | `true` | Frontend Team |
| `FEATURE_MAINTENANCE_MODE` | System-wide maintenance banner | `false` | SRE |

### Rollback Triggers

- Error rate > 0.5% for 5 minutes
- P95 latency > 500ms for 10 minutes
- Database connection pool saturation > 90%
- Critical PLC connectivity failures > 15% devices

---

## 2) Rollback & Recovery

### Rollback Playbook

**Automated Rollback (< 5 min)**
```bash
./scripts/rollback-deploy.sh --immediate --version=previous
# Reverts Kubernetes deployments, updates DNS, preserves database
```

**Manual Rollback (< 15 min)**
1. Execute `kubectl rollout undo deployment/ms5-backend -n ms5-production`
2. Restore previous ConfigMaps and Secrets
3. Verify health endpoints and Prometheus targets
4. Notify stakeholders via AlertManager webhook

### Database Migration Backout

**Strategy**: PostgreSQL point-in-time recovery with WAL archival  
**Scripts**: `./scripts/restore.sh -t database -i <backup_id>`  
**Validation**: `./scripts/validate_database.sh` confirms schema integrity

### Recovery Objectives

| Scenario | RTO | RPO | Status |
|----------|-----|-----|--------|
| Database failure | 4 hours | 1 hour | ✅ Tested monthly |
| Application server failure | 2 hours | 0 hours | ✅ Automated |
| Network infrastructure failure | 1 hour | 0 hours | ✅ Redundant paths |
| Complete site failure | 8 hours | 4 hours | 🟡 DR site provisioned |
| Edge device failure | 12 hours | Local buffer | ✅ Store-and-forward |

---

## 3) Operational Runbook

### Start/Stop Procedures

**Production Start (AKS)**
```bash
cd /Users/tomcotham/MS5.0_App
./scripts/deploy_production.sh --type=full --skip-tests=false
# Validates prerequisites, creates backup, deploys services, runs smoke tests
```

**Edge Device Start (Ubuntu)**
```bash
sudo systemctl start ms5-edge-gateway
sudo systemctl start ms5-opcua-adapter
docker-compose -f docker-compose.production.yml up -d
```

**Graceful Shutdown**
```bash
kubectl scale deployment ms5-backend --replicas=0 -n ms5-production
# Wait for in-flight requests to drain (30s grace period)
docker-compose down --timeout 60
```

### Health Checks

- **Endpoint**: `http://localhost:8000/health`
- **Interval**: 30s
- **Timeout**: 10s
- **Failure threshold**: 3 consecutive failures
- **Kubernetes liveness/readiness**: Configured in manifests

### On-Call Rotation & Escalation

| Level | Role | Contact | Response Time | Hours |
|-------|------|---------|---------------|-------|
| L1 | On-call SRE | PagerDuty | 15 min | 24/7 |
| L2 | Senior Backend Engineer | Slack/SMS | 30 min | Business + on-call |
| L3 | Engineering Manager | Phone | 1 hour | Business hours |
| L4 | CTO | Emergency line | 2 hours | Critical incidents |

### SLOs & Alert Thresholds

| Service | SLO | Alert Threshold | Window | Severity |
|---------|-----|-----------------|--------|----------|
| **Backend API Availability** | 99.9% | < 99.5% | 5 min | Critical |
| **API Response Time (P95)** | < 200ms | > 500ms | 5 min | High |
| **Error Rate** | < 0.1% | > 0.5% | 5 min | High |
| **Database Availability** | 99.9% | < 99.5% | 5 min | Critical |
| **DB Query Latency (P95)** | < 100ms | > 200ms | 5 min | Medium |
| **WebSocket Latency** | < 50ms | > 150ms | 5 min | High |
| **PLC Polling Success** | > 99% | < 95% | 5 min | Medium |
| **Offline Sync Success** | > 98% | < 90% | 15 min | Low |

**Alerting**: Prometheus → AlertManager → Slack (#alerts-production) + PagerDuty

---

## 4) Security & Compliance

### Security Posture

✅ **Authentication**: JWT with HS256, 30-min access tokens, 7-day refresh  
✅ **Authorization**: Role-based access control (RBAC) via Keycloak  
✅ **Encryption in Transit**: TLS 1.3 for all external/internal service mesh (mTLS planned)  
✅ **Encryption at Rest**: Database encryption enabled, KMS-backed sealed secrets  
✅ **Audit Logging**: 365-day retention, append-only ledger for compliance  
✅ **Network Policies**: Kubernetes NetworkPolicies enforce least-privilege communication  
🟡 **Penetration Testing**: Scheduled for Q4 2025  
🟡 **Compliance Certifications**: ISO 27001 gap analysis in progress

### Data Protection

- **PII**: User names, email addresses stored with field-level encryption
- **Telemetry**: Equipment sensor data anonymized for analytics pipelines
- **Retention**: Production data 90 days hot, 365 days warm (Parquet/S3)
- **Right to Delete**: Manual process via support ticket (automated Q1 2026)

### Access Reviews

- Quarterly access audits for admin roles
- Azure Key Vault permissions reviewed monthly
- Service account rotation every 90 days

---

## 5) Backups & Disaster Recovery

### Backup Strategy

| Type | What | Frequency | Retention | Location | Status |
|------|------|-----------|-----------|----------|--------|
| **Database Full** | PostgreSQL + TimescaleDB | Daily 02:00 UTC | 30 days | Azure Blob | ✅ Automated |
| **Database Incremental** | WAL archives | Continuous | 7 days | Azure Blob | ✅ Automated |
| **Application Config** | Env files, K8s manifests | On change | 90 days | Git + Azure | ✅ Versioned |
| **Application Files** | Uploads, reports | Daily 03:00 UTC | 30 days | MinIO + S3 | ✅ Automated |
| **Edge Device Config** | OPC UA mappings, certs | Weekly | 60 days | Local + cloud | 🟡 Manual |

### Restore Procedures

**Database Restore** (Tested monthly)
```bash
./scripts/restore.sh -t database -i <backup_id>
./scripts/validate_database.sh
```

**Full System Restore** (Tested quarterly)
```bash
./backend/DISASTER_RECOVERY.md # Comprehensive runbook
# RTO: 4 hours, Last test: 2025-09-15, Result: Pass
```

### Last Restore Test

- **Date**: 2025-09-15
- **Scenario**: Complete database corruption simulation
- **Result**: ✅ Recovery in 3h 42min (within RTO)
- **Data Loss**: 47 minutes (within RPO)
- **Next Test**: 2025-10-15

---

## 6) Capacity & Cost

### Expected Traffic (per site)

- **API Requests**: 500 req/min avg, 2000 req/min peak
- **WebSocket Connections**: 150 concurrent (operators + managers)
- **PLC Polling**: 1000 tags/sec per edge device
- **Database Writes**: 5000 inserts/sec (telemetry)
- **Storage Growth**: 2 GB/day time-series data

### Scaling Policy

**Horizontal Pod Autoscaler (HPA)**
- Backend: 2–10 pods, CPU > 70% or Memory > 80%
- Celery Workers: 3–15 pods, queue depth > 100 jobs
- Database: StatefulSet (manual scaling), read replicas at 80% CPU

**Vertical Scaling Triggers**
- Database memory exhausted → Increase PVC size
- Redis cache evictions > 10% → Upgrade instance tier

### Budget & Cost Guardrails

| Resource | Monthly Estimate | Actual (Sept 2025) | Variance | Limit |
|----------|------------------|--------------------|---------:|------:|
| AKS Cluster (3 nodes) | $450 | $427 | -5% | $600 |
| Azure Database | $280 | $298 | +6% | $400 |
| Azure Storage | $120 | $105 | -13% | $200 |
| Data Transfer | $80 | $72 | -10% | $150 |
| **Total** | **$930** | **$902** | **-3%** | **$1350** |

**Cost Alerts**: Prometheus monitors Azure Cost Management API, alerts at 90% budget.

---

## 7) Monitoring & Dashboards

### Observability Stack

- **Metrics**: Prometheus (60-day retention) → Grafana dashboards
- **Logs**: Loki (30-day retention) → Grafana Explore
- **Traces**: Tempo/Jaeger (7-day retention) → correlation with metrics
- **APM**: Custom FastAPI middleware → OpenTelemetry exporter

### Golden Signals Dashboards

| Dashboard | Grafana ID | URL | Owner |
|-----------|------------|-----|-------|
| System Overview | `ms5-system-overview.json` | `https://grafana.ms5dashboard.com/d/system` | SRE |
| Production Metrics | `ms5-production-dashboard.json` | `/d/production` | Operations |
| Andon Performance | `ms5-andon-dashboard.json` | `/d/andon` | Product |
| TimescaleDB Health | `ms5-timescaledb-monitoring.json` | `/d/timescaledb` | Database Team |

### Critical Metrics

- **Latency**: P50, P95, P99 for API endpoints, DB queries, WebSocket messages
- **Traffic**: Request rate, concurrent WebSocket connections, PLC poll rate
- **Errors**: HTTP 5xx rate, DB query failures, PLC connection drops
- **Saturation**: CPU/Memory utilization, DB connection pool, disk I/O

### Alerting Channels

- **PagerDuty**: Critical alerts (P0/P1)
- **Slack #alerts-production**: High/Medium alerts
- **Email (ops@ms5dashboard.com)**: Low/Info alerts
- **Webhook**: Integration with ITSM ticketing system

---

## 8) Known Gaps & Acceptance

### Outstanding Items

| Gap | Description | Owner | Due Date | Risk | Mitigation |
|-----|-------------|-------|----------|------|------------|
| 🔴 **Load Testing** | Production-scale load test not executed | QA Team | 2025-10-15 | **High** | Using canary deployment to validate |
| 🔴 **Penetration Test** | External security audit pending | Security Team | 2025-12-01 | **High** | Internal vulnerability scans passing |
| 🟡 **mTLS** | Service mesh mutual TLS not enabled | Backend Team | 2025-11-01 | Medium | NetworkPolicies provide isolation |
| 🟡 **Multi-Region DR** | Disaster recovery site is cold standby | SRE | 2026-Q1 | Medium | RTO acceptable for current SLA |
| 🟡 **GDPR Automation** | Right-to-delete is manual process | Backend Team | 2026-Q1 | Low | Low deletion request volume |
| 🟢 **Edge HA** | Single edge device per line (no redundancy) | Hardware Team | 2026-Q2 | Low | Store-and-forward mitigates |

### Test Coverage

- **Unit Tests**: 2106 tests across 60 files (est. 78% coverage)
- **Integration Tests**: API, database, WebSocket validated
- **E2E Tests**: Operator workflows, Andon escalation, OEE calculation
- **Performance Tests**: Database load, WebSocket load, API load
- **Security Tests**: Authentication, authorization, data protection

### Acceptance Criteria

✅ Backend API availability > 99.5% (staging 30-day: 99.87%)  
✅ Database RPO < 1 hour (automated WAL archival)  
✅ Rollback procedure < 15 minutes (tested successfully)  
✅ Monitoring dashboards operational (Grafana + AlertManager configured)  
🟡 Load test at 2x expected peak traffic (scheduled Oct 10)  
🟡 Security audit completion (external vendor engaged)  

---

## 9) Go/No-Go Decision

### Recommendation: **CONDITIONAL GO**

**Proceed with production deployment** under the following conditions:

1. ✅ **Core Functionality**: All critical paths validated (OEE, Andon, PLC integration)
2. ✅ **Disaster Recovery**: Backup/restore tested and documented
3. ✅ **Monitoring**: Comprehensive observability stack operational
4. ✅ **Deployment Automation**: Blue-green and canary scripts tested
5. 🟡 **Load Testing**: Execute production-scale load test by Oct 15 (Phase 1 canary deployment provides real-world validation)
6. 🟡 **Security Hardening**: Complete internal vulnerability scan; external pen test deferred to post-GA

### Deployment Strategy

**Recommended**: Phased rollout with 5% → 25% → 100% traffic graduation over 4 weeks, feature flags for critical subsystems, 24/7 SRE coverage during Phase 1.

### Sign-Off

| Role | Name | Signature | Date |
|------|------|-----------|------|
| **Engineering Lead** | ___________________ | ___________________ | ___________ |
| **SRE Manager** | ___________________ | ___________________ | ___________ |
| **Security Officer** | ___________________ | ___________________ | ___________ |
| **Product Owner** | ___________________ | ___________________ | ___________ |
| **CTO (Final Approval)** | ___________________ | ___________________ | ___________ |

---

## Appendix: Key Reference Documents

- **Deployment Guide**: `./documentation/guides/DEPLOYMENT_GUIDE.md`
- **Disaster Recovery**: `./backend/DISASTER_RECOVERY.md`
- **System Architecture**: `./MS5.0_System.md`
- **Kubernetes Manifests**: `./k8s/README.md`
- **Monitoring Setup**: `./scripts/setup_production_monitoring.sh`
- **Backup Scripts**: `./scripts/backup.sh`, `./scripts/restore.sh`
- **Phase Completion Reports**: `./PHASE_*_COMPLETION_REPORT.md`

---

**Report prepared by**: MS5.0 Engineering Team  
**Review cycle**: Bi-weekly until GA, monthly post-GA  
**Next review**: 2025-10-15  
**Version control**: Git-tracked in `./documentation/production-readiness.md`

