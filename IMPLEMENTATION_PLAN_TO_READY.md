# MS5.0 Implementation Plan to Reach Production Ready State

## Document Control
- **Version:** 1.0
- **Date:** October 1, 2025
- **Status:** Draft for Review
- **Owner:** Development Team
- **Related Docs:** CODE_REVIEW_REPORT.md, MS5.0_System.md

---

## Executive Summary

This document provides a detailed, actionable plan to bring the MS5.0 codebase to full production readiness against the specifications in `MS5.0_System.md`. Based on the comprehensive code review, this plan outlines three deployment options with varying scope and timelines.

**Current Readiness:** 45/100  
**Target Readiness:** 95/100 (Full spec compliance)

---

## Option 1: Minimal Viable Deployment (4-6 Weeks)

**Goal:** Deploy current system to production with minimal changes, accepting architectural gaps

### Scope
- Deploy existing Python/FastAPI monolith
- Allen-Bradley PLC support only
- Basic production monitoring, OEE, Andon
- Tablet PWA deployment
- Essential security hardening

### Deliverables

#### Week 1-2: Security & Configuration Hardening

**Task 1.1: Production Environment Setup**
- [ ] Create production `.env` file with secure credentials
- [ ] Generate strong `SECRET_KEY` (32+ character random string)
- [ ] Configure database connection pooling for production load
- [ ] Set up Redis with password authentication
- [ ] Configure CORS for production frontend URL only
- [ ] Enable rate limiting on all endpoints
- [ ] Disable DEBUG mode

**Files to modify:**
- `backend/.env.production`
- `backend/app/config.py` (add production validators)
- `backend/app/main.py` (add rate limiting middleware)

**Task 1.2: SSL/TLS Configuration**
```bash
# Generate self-signed cert (or use Let's Encrypt)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/ms5-key.pem \
  -out /etc/ssl/certs/ms5-cert.pem

# Update nginx config
# backend/nginx.production.conf
```

- [ ] Generate SSL certificates
- [ ] Configure nginx with TLS 1.3
- [ ] Enable HSTS headers
- [ ] Set up certificate auto-renewal (if using Let's Encrypt)

**Task 1.3: Authentication Improvements**
- [ ] Force password change on first login for default users
- [ ] Implement password complexity requirements
- [ ] Add account lockout after failed login attempts (5 attempts)
- [ ] Enable session timeout (30 minutes inactivity)
- [ ] Add password expiration policy (90 days)

**Files to create/modify:**
- `backend/app/auth/password_policy.py`
- `backend/app/auth/jwt_handler.py` (add session management)
- `backend/app/api/v1/auth.py` (add lockout logic)

**Task 1.4: Input Validation & Sanitization**
- [ ] Add Pydantic validators on all API endpoints
- [ ] Implement SQL injection prevention (verify parameterized queries)
- [ ] Add XSS protection headers
- [ ] Enable CSRF protection on state-changing endpoints
- [ ] Validate file uploads (type, size, content)

**Files to review:**
- All files in `backend/app/api/v1/`
- `backend/app/security/` (ensure all middleware active)

#### Week 2-3: Database & PLC Configuration

**Task 2.1: Production Database Setup**
```sql
-- Create production database
CREATE DATABASE factory_telemetry_prod;

-- Create dedicated database user
CREATE USER ms5_prod WITH PASSWORD 'SECURE_PASSWORD_HERE';
GRANT ALL PRIVILEGES ON DATABASE factory_telemetry_prod TO ms5_prod;

-- Enable TimescaleDB extension
\c factory_telemetry_prod
CREATE EXTENSION IF NOT EXISTS timescaledb;
```

- [ ] Provision production PostgreSQL instance (or cloud managed)
- [ ] Run all migration scripts in order:
  ```bash
  psql -d factory_telemetry_prod -f 001_init_telemetry.sql
  psql -d factory_telemetry_prod -f 002_plc_equipment_management.sql
  psql -d factory_telemetry_prod -f 003_production_management.sql
  psql -d factory_telemetry_prod -f 004_advanced_production_features.sql
  psql -d factory_telemetry_prod -f 005_andon_escalation_system.sql
  psql -d factory_telemetry_prod -f 006_report_system.sql
  psql -d factory_telemetry_prod -f 007_plc_integration_phase1.sql
  psql -d factory_telemetry_prod -f 008_fix_critical_schema_issues.sql
  psql -d factory_telemetry_prod -f 009_database_optimization.sql
  ```
- [ ] Verify hypertables created
- [ ] Configure TimescaleDB compression policies
- [ ] Set up retention policies
- [ ] Create read-only user for reporting

**Task 2.2: PLC Integration Configuration**
- [ ] Document all PLCs on factory floor:
  - IP addresses
  - PLC type (Logix or SLC)
  - Equipment codes
  - Tag lists
- [ ] Insert PLC configurations into database:
  ```sql
  INSERT INTO factory_telemetry.plc_config (name, ip_address, plc_type, poll_interval_s)
  VALUES ('Line 1 PLC', '192.168.1.10', 'LOGIX', 1.0);
  ```
- [ ] Insert equipment configurations
- [ ] Map all critical tags (metric definitions and bindings)
- [ ] Test PLC connectivity from server
- [ ] Configure alarms for PLC connection failures

**Files to create:**
- `deployment/plc_config.sql` (PLC-specific INSERT statements)
- `deployment/metric_definitions.csv` (import script)

**Task 2.3: Backup Strategy**
- [ ] Set up automated PostgreSQL backups (pg_dump daily)
- [ ] Configure backup retention (30 days)
- [ ] Test restore procedure
- [ ] Document backup/restore steps
- [ ] Set up Redis persistence (AOF + RDB)

**Scripts to create:**
- `scripts/backup/daily-backup.sh`
- `scripts/backup/restore-backup.sh`

#### Week 3-4: Deployment & Testing

**Task 3.1: Ubuntu Edge Server Deployment**

**Prerequisites:**
- Ubuntu 22.04 LTS server (4 CPU, 8GB RAM, 100GB SSD minimum)
- Static IP address configured
- Network access to PLCs (same VLAN or routed)
- Firewall rules configured

**Deployment Steps:**
```bash
# 1. System preparation
sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io docker-compose git

# 2. Create application user
sudo adduser ms5app
sudo usermod -aG docker ms5app

# 3. Clone repository
su - ms5app
git clone <repo-url> /home/ms5app/ms5
cd /home/ms5app/ms5

# 4. Configure environment
cd backend
cp env.production .env
nano .env  # Edit all production values

# 5. Start services
docker-compose -f docker-compose.production.yml up -d

# 6. Verify
docker-compose ps
curl http://localhost:8000/health
```

- [ ] Execute deployment steps
- [ ] Verify all containers running
- [ ] Check logs for errors (`docker-compose logs -f`)
- [ ] Verify database connectivity
- [ ] Verify Redis connectivity
- [ ] Test PLC polling (check metric_latest table for new data)

**Task 3.2: Frontend Tablet Deployment**

**Option A: PWA Deployment**
```bash
cd frontend
npm install
npm run build
# Copy build/ folder to nginx static directory
sudo cp -r build/* /var/www/ms5-frontend/
```

- [ ] Build React Native web bundle
- [ ] Deploy to nginx
- [ ] Test PWA installation on tablet browser
- [ ] Test offline mode
- [ ] Test WebSocket connection to backend

**Option B: Native Android App**
```bash
cd frontend
npm install
cd android
./gradlew assembleRelease
# APK: android/app/build/outputs/apk/release/app-release.apk
```

- [ ] Build signed APK
- [ ] Transfer to tablets
- [ ] Install on test devices
- [ ] Test camera/barcode permissions
- [ ] Test background sync
- [ ] Configure API endpoint in app settings

**Task 3.3: User Acceptance Testing**
- [ ] Create test plan with scenarios:
  - Login/logout
  - View production dashboard
  - Trigger Andon
  - Complete pre-start checklist
  - View OEE metrics
  - Check offline mode
  - Verify data sync after reconnect
- [ ] Execute test plan with 2-3 operators
- [ ] Document issues/bugs
- [ ] Fix critical bugs
- [ ] Re-test

#### Week 4-5: Monitoring & Documentation

**Task 4.1: Grafana Dashboard Setup**
- [ ] Access Grafana (http://server-ip:3000)
- [ ] Verify datasource connections (Prometheus, PostgreSQL)
- [ ] Import dashboards from `backend/grafana/provisioning/dashboards/`
- [ ] Verify metrics populating:
  - System overview
  - Production metrics
  - OEE by line
  - Andon events
  - TimescaleDB performance
- [ ] Create custom dashboard for factory floor (TV display)
- [ ] Set up Grafana alerts:
  - PLC connection loss
  - Database connection issues
  - High CPU/memory usage
  - Disk space < 20%

**Task 4.2: Alerting Configuration**
- [ ] Configure AlertManager recipients
- [ ] Set up email notifications
- [ ] Test alert routing
- [ ] Create on-call schedule
- [ ] Document escalation procedures

**Task 4.3: User Documentation**
```markdown
Create deployment/USER_GUIDE_PRODUCTION.md with:
- Tablet login instructions
- Dashboard navigation
- How to trigger Andon
- How to complete checklists
- Offline mode explanation
- Who to contact for support
```

- [ ] Create operator quick reference guide (1-page PDF)
- [ ] Create admin guide for user management
- [ ] Create troubleshooting guide
- [ ] Create video walkthroughs (5-10 minutes each)

**Task 4.4: Training**
- [ ] Schedule training sessions:
  - Session 1: Operators (2 hours)
  - Session 2: Engineers (2 hours)
  - Session 3: Managers (1 hour)
  - Session 4: IT/Admins (3 hours)
- [ ] Conduct training
- [ ] Gather feedback
- [ ] Update documentation based on feedback

#### Week 5-6: Go-Live & Support

**Task 5.1: Soft Launch**
- [ ] Deploy to production (1 line only for pilot)
- [ ] Run in parallel with existing systems
- [ ] Monitor for 1 week
- [ ] Gather user feedback
- [ ] Fix critical issues
- [ ] Optimize based on real usage

**Task 5.2: Full Rollout**
- [ ] Deploy to remaining production lines
- [ ] Decommission old systems (if applicable)
- [ ] 24/7 monitoring for first week
- [ ] Daily standup with users
- [ ] Bug triage and rapid fixes

**Task 5.3: Post-Deployment**
- [ ] Create runbook for common operations
- [ ] Document known issues and workarounds
- [ ] Schedule weekly review meetings (first month)
- [ ] Plan Phase 2 features based on feedback

### Success Criteria
- [ ] System uptime > 99% during pilot week
- [ ] < 5 critical bugs in first week
- [ ] Operator satisfaction score > 7/10
- [ ] PLC data collected successfully (>95% uptime)
- [ ] All tablets operational
- [ ] Backup/restore tested successfully

### Estimated Effort
- **Backend Engineer:** 2 people × 4 weeks = 320 hours
- **Frontend Engineer:** 1 person × 2 weeks = 80 hours
- **DevOps Engineer:** 1 person × 2 weeks = 80 hours
- **QA Engineer:** 1 person × 2 weeks = 80 hours
- **Total:** ~560 hours (~14 person-weeks)

### Budget Estimate
- **Personnel:** $70K - $100K (depends on rates)
- **Infrastructure:** $2K - $5K (hardware, cloud, licenses)
- **Contingency (20%):** $14K - $20K
- **Total:** $86K - $125K

---

## Option 2: Enhanced Deployment with Critical Gaps Filled (3-6 Months)

**Goal:** Fill critical architectural gaps before production deployment

### Phase 1: Event Infrastructure (Months 1-2)

**Objective:** Implement event-driven backbone with Kafka

**Tasks:**

**1.1 Kafka Cluster Deployment**
```yaml
# Deploy 3-node Kafka cluster
# Using Confluent Platform or Apache Kafka
# Include Zookeeper/KRaft, Schema Registry, Connect
```

**Deliverables:**
- [ ] Deploy Kafka cluster (3 brokers minimum for production)
- [ ] Deploy Zookeeper ensemble (or KRaft mode for Kafka 3.x)
- [ ] Deploy Confluent Schema Registry
- [ ] Configure broker replication (min 3 replicas)
- [ ] Set up retention policies (7 days default, 90 days for critical)
- [ ] Configure authentication (SASL/SCRAM)
- [ ] Configure TLS encryption
- [ ] Deploy Kafka Connect for database CDC

**Infrastructure:**
```bash
# Using Docker Compose or Kubernetes
# Minimum resources:
# - 3 brokers: 4 CPU, 16GB RAM, 500GB SSD each
# - Schema Registry: 2 CPU, 4GB RAM
# - Zookeeper (if used): 2 CPU, 4GB RAM each (3 nodes)
```

**1.2 Event Schema Definition**

**Create schema files:**
```bash
mkdir -p backend/event-schemas
```

**schemas/production.stop.unplanned.v1.avsc:**
```json
{
  "type": "record",
  "name": "UnplannedStop",
  "namespace": "com.ms5.production",
  "fields": [
    {"name": "event_id", "type": "string"},
    {"name": "occurred_at", "type": "string"},
    {"name": "site_id", "type": "string"},
    {"name": "line_id", "type": "string"},
    {"name": "equipment_id", "type": "string"},
    {"name": "shift_id", "type": "string"},
    {"name": "duration_ms", "type": "long"},
    {"name": "code", "type": "string"},
    {"name": "classification", "type": "string"},
    {"name": "detected_by", "type": "string"},
    {"name": "ack_user_id", "type": ["null", "string"]},
    {"name": "root_cause_id", "type": ["null", "string"]},
    {"name": "attachments", "type": {"type": "array", "items": "string"}}
  ]
}
```

**Implement event producers:**
```python
# backend/app/events/producers/production_events.py
from confluent_kafka import Producer
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroSerializer

class ProductionEventProducer:
    def __init__(self, kafka_config, schema_registry_url):
        self.producer = Producer(kafka_config)
        self.schema_registry = SchemaRegistryClient({'url': schema_registry_url})
        # Load schemas and create serializers
        
    async def publish_unplanned_stop(self, event_data):
        # Serialize with Avro schema
        # Publish to 'production.stop.unplanned.v1' topic
        pass
```

**Deliverables:**
- [ ] Define all event schemas from MS5.0_System.md Section 4.2:
  - `production.stop.unplanned.v1`
  - `production.stop.planned.v1`
  - `process.centerline.changed.v1`
  - `maintenance.cil.completed.v1`
  - `quality.defect.created.v1`
  - `andon.triggered.v1`
  - `andon.resolved.v1`
- [ ] Register schemas in Schema Registry
- [ ] Create Python event producer library
- [ ] Create Python event consumer framework
- [ ] Set up schema evolution policies (backward compatible)

**1.3 Migrate PLC Integration to Events**

**Create event-based PLC service:**
```python
# backend/app/services/plc_event_publisher.py
class PLCEventPublisher:
    def __init__(self, event_producer):
        self.producer = event_producer
        
    async def poll_and_publish(self, plc_config):
        # Read PLC tags
        # Detect state changes
        # Publish events to Kafka
        # Store latest state in database
        pass
```

**Deliverables:**
- [ ] Create PLC event publisher service
- [ ] Implement dual-write (Kafka + Database) temporarily
- [ ] Add metric published counters (Prometheus)
- [ ] Test event publishing end-to-end
- [ ] Create event consumers for database writes
- [ ] Gradually cutover from direct DB writes to event-driven
- [ ] Remove dual-write once validated

**1.4 Event Consumer Services**

**Create modular consumers:**
```python
# backend/app/events/consumers/database_sink.py
class DatabaseSinkConsumer:
    """Consumes events and writes to TimescaleDB"""
    def __init__(self, kafka_config, db):
        self.consumer = Consumer(kafka_config)
        self.db = db
        
    async def consume_production_events(self):
        self.consumer.subscribe(['production.*'])
        while True:
            msg = self.consumer.poll(1.0)
            if msg:
                await self.process_message(msg)
                self.consumer.commit(msg)
```

**Deliverables:**
- [ ] Create database sink consumer (events → TimescaleDB)
- [ ] Create WebSocket broadcaster consumer (events → connected clients)
- [ ] Create email notification consumer (critical events → email)
- [ ] Add consumer lag monitoring
- [ ] Implement consumer group coordination
- [ ] Add error handling and dead-letter queues
- [ ] Test consumer failover

**Effort:** 2-3 engineers, 2 months

### Phase 2: OPC UA Edge Adapter (Months 2-3)

**Objective:** Support vendor-neutral PLC connectivity

**2.1 Go-Based OPC UA Adapter**

**Why Go:**
- High performance for I/O-bound operations
- Small binary size for edge deployment
- Good OPC UA library support (gopcua)

**Architecture:**
```
edge-opcua-adapter/
├── cmd/
│   └── adapter/
│       └── main.go
├── internal/
│   ├── opcua/
│   │   ├── client.go
│   │   └── subscription.go
│   ├── kafka/
│   │   └── producer.go
│   ├── storage/
│   │   └── storeforward.go  # RocksDB queue
│   └── config/
│       └── config.go
├── go.mod
└── Dockerfile
```

**Core files:**

**cmd/adapter/main.go:**
```go
package main

import (
    "context"
    "log"
    "os"
    "os/signal"
    "syscall"
    
    "github.com/ms5/edge-opcua-adapter/internal/config"
    "github.com/ms5/edge-opcua-adapter/internal/opcua"
    "github.com/ms5/edge-opcua-adapter/internal/kafka"
    "github.com/ms5/edge-opcua-adapter/internal/storage"
)

func main() {
    cfg := config.Load()
    
    // Initialize OPC UA client
    opcuaClient, err := opcua.NewClient(cfg.OPCUAConfig)
    if err != nil {
        log.Fatal(err)
    }
    
    // Initialize Kafka producer
    kafkaProducer, err := kafka.NewProducer(cfg.KafkaConfig)
    if err != nil {
        log.Fatal(err)
    }
    
    // Initialize store-and-forward
    storage, err := storage.NewRocksDBQueue(cfg.StoragePath)
    if err != nil {
        log.Fatal(err)
    }
    
    // Start subscription loop
    ctx, cancel := context.WithCancel(context.Background())
    defer cancel()
    
    go opcuaClient.Subscribe(ctx, kafkaProducer, storage)
    
    // Wait for shutdown signal
    sigCh := make(chan os.Signal, 1)
    signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
    <-sigCh
    
    log.Println("Shutting down...")
}
```

**internal/opcua/client.go:**
```go
package opcua

import (
    "context"
    "log"
    "time"
    
    "github.com/gopcua/opcua"
    "github.com/gopcua/opcua/ua"
)

type Client struct {
    endpoint string
    client   *opcua.Client
    nodes    []string
}

func NewClient(cfg Config) (*Client, error) {
    client := opcua.NewClient(cfg.Endpoint, opcua.SecurityMode(ua.MessageSecurityModeNone))
    if err := client.Connect(context.Background()); err != nil {
        return nil, err
    }
    
    return &Client{
        endpoint: cfg.Endpoint,
        client:   client,
        nodes:    cfg.Nodes,
    }, nil
}

func (c *Client) Subscribe(ctx context.Context, producer Producer, storage Storage) {
    sub, err := c.client.Subscribe(&opcua.SubscribeRequest{
        Interval: 1000 * time.Millisecond,
    })
    if err != nil {
        log.Fatal(err)
    }
    
    for _, nodeID := range c.nodes {
        if err := sub.AddMonitoredItems(nodeID); err != nil {
            log.Printf("Failed to monitor %s: %v", nodeID, err)
        }
    }
    
    for {
        select {
        case <-ctx.Done():
            return
        case msg := <-sub.Notifications():
            // Process data change
            event := c.convertToEvent(msg)
            
            // Try to send to Kafka
            if err := producer.Send(event); err != nil {
                // Store locally for later retry
                storage.Enqueue(event)
            }
        }
    }
}

func (c *Client) convertToEvent(msg *ua.DataChangeNotification) []byte {
    // Convert OPC UA data to Avro/Protobuf event
    // Serialize and return
    return nil
}
```

**Deliverables:**
- [ ] Create Go module for OPC UA adapter
- [ ] Implement OPC UA client with subscriptions
- [ ] Implement Kafka producer with Avro serialization
- [ ] Implement RocksDB-based store-and-forward queue
- [ ] Add retry logic with exponential backoff
- [ ] Create Docker image
- [ ] Test with real OPC UA server
- [ ] Add Prometheus metrics export
- [ ] Create K8s deployment manifests
- [ ] Document configuration

**2.2 MQTT Bridge (Optional, if sensors exist)**

Similar architecture in Go:
```
edge-mqtt-bridge/
├── cmd/bridge/main.go
├── internal/
│   ├── mqtt/client.go
│   ├── kafka/producer.go
│   └── storage/queue.go
```

**Deliverables:**
- [ ] Create MQTT client (supporting v3.1.1 and v5)
- [ ] Subscribe to sensor topics
- [ ] Convert MQTT messages to events
- [ ] Publish to Kafka
- [ ] Add QoS handling
- [ ] Test with MQTT broker

**Effort:** 1-2 engineers, 1.5 months

### Phase 3: Workflow Orchestration with Temporal (Months 3-4)

**Objective:** Enable IWS methodology with workflow automation

**3.1 Temporal Cluster Deployment**

**Using Docker Compose:**
```yaml
# docker-compose.temporal.yml
version: '3.8'
services:
  postgresql:
    image: postgres:13
    environment:
      POSTGRES_PASSWORD: temporal
      POSTGRES_USER: temporal
      
  temporal:
    image: temporalio/auto-setup:latest
    depends_on:
      - postgresql
    environment:
      - DB=postgresql
      - DB_PORT=5432
      - POSTGRES_USER=temporal
      - POSTGRES_PWD=temporal
      - POSTGRES_SEEDS=postgresql
      
  temporal-ui:
    image: temporalio/ui:latest
    depends_on:
      - temporal
    ports:
      - 8080:8080
```

**Deliverables:**
- [ ] Deploy Temporal server
- [ ] Deploy Temporal Web UI
- [ ] Configure persistence (PostgreSQL)
- [ ] Set up namespaces (production, staging)
- [ ] Configure archival (S3/MinIO)
- [ ] Set up metrics export (Prometheus)

**3.2 TypeScript Workflow SDK**

**Why TypeScript:**
- Specification calls for TypeScript
- Temporal has excellent TS SDK
- Easier to attract talent vs. Go

**Create workflow service:**
```
backend-workflows/  # New TypeScript service
├── src/
│   ├── workflows/
│   │   ├── dds-session.workflow.ts
│   │   ├── cil.workflow.ts
│   │   ├── changeover.workflow.ts
│   │   └── dmaic.workflow.ts
│   ├── activities/
│   │   ├── data-fetch.activity.ts
│   │   ├── notification.activity.ts
│   │   └── esign.activity.ts
│   ├── worker.ts
│   └── client.ts
├── package.json
├── tsconfig.json
└── Dockerfile
```

**workflows/dds-session.workflow.ts:**
```typescript
import { proxyActivities, sleep } from '@temporalio/workflow';
import type { Activities } from '../activities';

const activities = proxyActivities<Activities>({
  startToCloseTimeout: '1 minute',
});

export async function ddsSessionWorkflow(lineId: string, shiftId: string): Promise<DDSResult> {
  // 1. Initialize agenda (safety → quality → throughput → service → staffing)
  const agenda = await activities.initializeDDSAgenda(lineId, shiftId);
  
  // 2. Fetch KPIs (OEE, unplanned stops, defects)
  const kpis = await activities.fetchKPIs(lineId, shiftId);
  
  // 3. Generate action queue
  const actions = await activities.generateActionQueue(lineId, kpis);
  
  // 4. Assign owners and set escalation triggers
  for (const action of actions) {
    await activities.assignActionOwner(action);
    await activities.setEscalationTrigger(action);
  }
  
  // 5. Wait for completion or timeout (30 minutes)
  const completed = await Promise.race([
    activities.waitForCompletion(agenda.id),
    sleep('30 minutes'),
  ]);
  
  // 6. Record decisions and e-sign
  const signatures = await activities.collectESignatures(agenda.id);
  
  // 7. Publish event
  await activities.publishEvent('dds.session.completed.v1', {
    lineId,
    shiftId,
    kpis,
    actions,
    signatures,
  });
  
  return { success: true, agendaId: agenda.id };
}
```

**Deliverables:**
- [ ] Set up TypeScript project
- [ ] Implement DDS workflow
- [ ] Implement CIL workflow (8-step AM progression)
- [ ] Implement SMED changeover workflow
- [ ] Implement DMAIC workflow template
- [ ] Create activity implementations (fetch data, send notifications, etc.)
- [ ] Create Temporal worker
- [ ] Create API endpoints to trigger workflows
- [ ] Add workflow monitoring dashboard
- [ ] Test workflow execution end-to-end
- [ ] Document workflow patterns

**3.3 Integration with FastAPI Backend**

**Add Temporal client to Python backend:**
```python
# backend/app/workflows/temporal_client.py
from temporalio.client import Client

class TemporalClientService:
    def __init__(self, temporal_address: str):
        self.client = None
        self.address = temporal_address
        
    async def connect(self):
        self.client = await Client.connect(self.address)
        
    async def start_dds_session(self, line_id: str, shift_id: str):
        handle = await self.client.start_workflow(
            "ddsSessionWorkflow",
            args=[line_id, shift_id],
            id=f"dds-{line_id}-{shift_id}",
            task_queue="dds-queue",
        )
        return await handle.result()
```

**Create FastAPI endpoints:**
```python
# backend/app/api/v1/workflows.py
from fastapi import APIRouter
from app.workflows.temporal_client import TemporalClientService

router = APIRouter()
temporal_client = TemporalClientService("localhost:7233")

@router.post("/dds/sessions/start")
async def start_dds_session(line_id: str, shift_id: str):
    result = await temporal_client.start_dds_session(line_id, shift_id)
    return {"workflow_id": result.workflow_id, "status": "started"}
```

**Deliverables:**
- [ ] Add Temporal Python SDK to requirements.txt
- [ ] Create Temporal client service
- [ ] Add workflow trigger endpoints
- [ ] Add workflow status query endpoints
- [ ] Update frontend to trigger workflows
- [ ] Test integration

**Effort:** 2 engineers, 1.5 months

### Phase 4: Identity & Access with Keycloak (Months 4-5)

**Objective:** Enterprise-grade authentication and authorization

**4.1 Keycloak Deployment**

```yaml
# docker-compose.keycloak.yml
services:
  postgres-keycloak:
    image: postgres:13
    environment:
      POSTGRES_DB: keycloak
      POSTGRES_USER: keycloak
      POSTGRES_PASSWORD: keycloak
      
  keycloak:
    image: quay.io/keycloak/keycloak:latest
    command: start-dev
    environment:
      KC_DB: postgres
      KC_DB_URL: jdbc:postgresql://postgres-keycloak:5432/keycloak
      KC_DB_USERNAME: keycloak
      KC_DB_PASSWORD: keycloak
      KEYCLOAK_ADMIN: admin
      KEYCLOAK_ADMIN_PASSWORD: admin
    ports:
      - 8090:8080
```

**Deliverables:**
- [ ] Deploy Keycloak server
- [ ] Create MS5 realm
- [ ] Configure OIDC client for backend API
- [ ] Configure OIDC client for frontend
- [ ] Set up user federation (LDAP if applicable)
- [ ] Configure password policies
- [ ] Set up MFA (optional)
- [ ] Configure session timeouts
- [ ] Create default roles (admin, engineer, operator, viewer)

**4.2 Backend Integration**

**Replace JWT auth with OIDC:**
```python
# backend/app/auth/oidc.py
from jose import jwt
import httpx

class OIDCAuthHandler:
    def __init__(self, keycloak_url, realm, client_id):
        self.keycloak_url = keycloak_url
        self.realm = realm
        self.client_id = client_id
        self.public_key = None
        
    async def initialize(self):
        # Fetch realm public key
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                f"{self.keycloak_url}/realms/{self.realm}"
            )
            realm_info = resp.json()
            self.public_key = realm_info["public_key"]
            
    async def verify_token(self, token: str):
        # Verify JWT signature with Keycloak public key
        payload = jwt.decode(
            token,
            self.public_key,
            algorithms=["RS256"],
            audience=self.client_id,
        )
        return payload
```

**Update FastAPI dependencies:**
```python
# backend/app/api/dependencies.py
from fastapi import Depends, HTTPException
from fastapi.security import OAuth2PasswordBearer
from app.auth.oidc import OIDCAuthHandler

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")
oidc_handler = OIDCAuthHandler(...)

async def get_current_user(token: str = Depends(oauth2_scheme)):
    try:
        payload = await oidc_handler.verify_token(token)
        return payload
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid token")
```

**Deliverables:**
- [ ] Add Keycloak Python client library
- [ ] Implement OIDC token verification
- [ ] Update all protected endpoints to use OIDC
- [ ] Migrate existing users to Keycloak
- [ ] Test SSO flow
- [ ] Update frontend to use Keycloak login

**4.3 OPA Policy Engine (Optional, for ABAC)**

**Deploy OPA:**
```yaml
services:
  opa:
    image: openpolicyagent/opa:latest
    command:
      - "run"
      - "--server"
      - "--log-level=debug"
    ports:
      - 8181:8181
```

**Define policies in Rego:**
```rego
# policies/floor_access.rego
package ms5.authorization

import data.roles
import data.assignments

default allow = false

# Operators can edit CIL on their owned equipment
allow {
  input.action == "edit_cil"
  input.user.role == "operator"
  equipment := data.assignments[input.user.id]
  input.equipment_id == equipment
  input.shift == input.user.current_shift
}

# Engineers can view all equipment
allow {
  input.action == "view_equipment"
  input.user.role == "engineer"
}
```

**Integrate with FastAPI:**
```python
# backend/app/auth/opa.py
import httpx

class OPAClient:
    def __init__(self, opa_url):
        self.opa_url = opa_url
        
    async def authorize(self, user, action, resource):
        async with httpx.AsyncClient() as client:
            resp = await client.post(
                f"{self.opa_url}/v1/data/ms5/authorization/allow",
                json={
                    "input": {
                        "user": user,
                        "action": action,
                        "resource": resource,
                    }
                },
            )
            result = resp.json()
            return result.get("result", False)
```

**Deliverables:**
- [ ] Deploy OPA server
- [ ] Define authorization policies in Rego
- [ ] Integrate OPA client in backend
- [ ] Add policy checks to sensitive endpoints
- [ ] Test policy enforcement
- [ ] Document policy model

**Effort:** 1-2 engineers, 1.5 months

### Phase 5: Floor Services Implementation (Months 5-6)

**Objective:** Implement DDS/DMS boards and centerline monitoring

**5.1 DDS/DMS Services (TypeScript Microservice)**

```typescript
// services/floor-dds/src/index.ts
import express from 'express';
import { Client as TemporalClient } from '@temporalio/client';
import { Pool } from 'pg';
import { Kafka } from 'kafkajs';

const app = express();
const db = new Pool({ connectionString: process.env.DATABASE_URL });
const kafka = new Kafka({ brokers: [process.env.KAFKA_BROKER] });
const temporal = await TemporalClient.connect({ address: process.env.TEMPORAL_ADDRESS });

// Start DDS session
app.post('/api/v1/dds/sessions', async (req, res) => {
  const { lineId, shiftId } = req.body;
  
  // Trigger Temporal workflow
  const handle = await temporal.workflow.start('ddsSessionWorkflow', {
    args: [lineId, shiftId],
    taskQueue: 'dds-queue',
    workflowId: `dds-${lineId}-${shiftId}-${Date.now()}`,
  });
  
  res.json({ workflowId: handle.workflowId });
});

// Get DDS board data
app.get('/api/v1/dds/boards/:lineId', async (req, res) => {
  const { lineId } = req.params;
  
  // Fetch last 24h data
  const yesterday = await db.query(`
    SELECT * FROM dds_sessions
    WHERE line_id = $1 AND created_at > NOW() - INTERVAL '24 hours'
    ORDER BY created_at DESC
    LIMIT 1
  `, [lineId]);
  
  // Fetch next 24h risks
  const risks = await db.query(`
    SELECT * FROM predicted_risks
    WHERE line_id = $1 AND predicted_at > NOW()
    ORDER BY severity DESC
  `, [lineId]);
  
  // Fetch actions
  const actions = await db.query(`
    SELECT * FROM dds_actions
    WHERE line_id = $1 AND status != 'completed'
    ORDER BY priority DESC, due_date ASC
  `, [lineId]);
  
  res.json({
    yesterday: yesterday.rows[0],
    risks: risks.rows,
    actions: actions.rows,
  });
});

app.listen(3001);
```

**Database schema additions:**
```sql
-- DDS sessions
CREATE TABLE factory_telemetry.dds_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  line_id TEXT NOT NULL,
  shift_id TEXT NOT NULL,
  scheduled_start TIMESTAMPTZ NOT NULL,
  actual_start TIMESTAMPTZ,
  duration_minutes INTEGER,
  agenda_items JSONB NOT NULL,
  kpis JSONB,
  decisions JSONB,
  signatures JSONB,
  status TEXT DEFAULT 'scheduled',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- DDS actions
CREATE TABLE factory_telemetry.dds_actions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID REFERENCES factory_telemetry.dds_sessions(id),
  description TEXT NOT NULL,
  assigned_to UUID REFERENCES factory_telemetry.users(id),
  priority TEXT CHECK (priority IN ('low', 'medium', 'high', 'critical')),
  due_date TIMESTAMPTZ,
  status TEXT DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'completed', 'cancelled')),
  escalation_level INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);

-- Predicted risks (from ML models later)
CREATE TABLE factory_telemetry.predicted_risks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  line_id TEXT NOT NULL,
  equipment_id TEXT,
  risk_type TEXT,
  description TEXT,
  severity TEXT CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  probability REAL,
  predicted_at TIMESTAMPTZ,
  mitigation_actions TEXT[],
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Frontend components:**
```typescript
// frontend/src/screens/floor/DDSBoardScreen.tsx
import React, { useEffect, useState } from 'react';
import { View, Text } from 'react-native';
import { api } from '../../services/api';

export const DDSBoardScreen = ({ lineId }) => {
  const [boardData, setBoardData] = useState(null);
  
  useEffect(() => {
    const fetchBoard = async () => {
      const data = await api.get(`/dds/boards/${lineId}`);
      setBoardData(data);
    };
    fetchBoard();
    const interval = setInterval(fetchBoard, 30000); // Refresh every 30s
    return () => clearInterval(interval);
  }, [lineId]);
  
  if (!boardData) return <LoadingSpinner />;
  
  return (
    <View style={styles.container}>
      <View style={styles.section}>
        <Text style={styles.header}>Yesterday's Performance</Text>
        {/* OEE, unplanned stops, etc. */}
      </View>
      
      <View style={styles.section}>
        <Text style={styles.header}>Today's Focus</Text>
        {/* Top 3 priorities */}
      </View>
      
      <View style={styles.section}>
        <Text style={styles.header}>Tomorrow's Risks</Text>
        {boardData.risks.map(risk => (
          <RiskCard key={risk.id} risk={risk} />
        ))}
      </View>
      
      <View style={styles.section}>
        <Text style={styles.header}>Actions</Text>
        {boardData.actions.map(action => (
          <ActionCard key={action.id} action={action} />
        ))}
      </View>
    </View>
  );
};
```

**Deliverables:**
- [ ] Create floor-dds microservice (TypeScript)
- [ ] Implement DDS board API endpoints
- [ ] Create database schema for DDS
- [ ] Build DDS board UI components
- [ ] Integrate with Temporal workflows
- [ ] Test DDS session flow end-to-end
- [ ] Add real-time updates via WebSocket

**5.2 Centerlines Service**

```sql
-- Centerline definitions
CREATE TABLE factory_telemetry.centerline_definitions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  equipment_id TEXT NOT NULL,
  parameter_name TEXT NOT NULL,
  spec_low REAL NOT NULL,
  spec_high REAL NOT NULL,
  target REAL,
  unit TEXT,
  control_plan JSONB,
  sampling_frequency TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (equipment_id, parameter_name)
);

-- Centerline history
CREATE TABLE factory_telemetry.centerline_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  centerline_id UUID REFERENCES factory_telemetry.centerline_definitions(id),
  changed_from REAL,
  changed_to REAL,
  reason TEXT,
  approved_by UUID REFERENCES factory_telemetry.users(id),
  work_instruction_id TEXT,
  changed_at TIMESTAMPTZ DEFAULT NOW()
);

-- Centerline violations
CREATE TABLE factory_telemetry.centerline_violations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  centerline_id UUID REFERENCES factory_telemetry.centerline_definitions(id),
  actual_value REAL,
  spec_low REAL,
  spec_high REAL,
  detected_at TIMESTAMPTZ DEFAULT NOW(),
  acknowledged_at TIMESTAMPTZ,
  acknowledged_by UUID REFERENCES factory_telemetry.users(id),
  corrective_action TEXT,
  resolved_at TIMESTAMPTZ
);
```

**Deliverables:**
- [ ] Create centerline database schema
- [ ] Create centerline monitoring service
- [ ] Add API endpoints for centerline CRUD
- [ ] Add violation detection logic
- [ ] Create "Restore to Standard" workflow
- [ ] Build centerline gauge UI components
- [ ] Add drift alerts
- [ ] Test centerline monitoring

**Effort:** 2-3 engineers, 1.5 months

### Total Effort for Option 2
- **Duration:** 6 months
- **Team:** 3-4 backend engineers, 1-2 frontend engineers, 1 DevOps
- **Person-Months:** ~30-40
- **Cost:** $400K - $600K (personnel + infrastructure)

---

## Option 3: Full Specification Compliance (18-24 Months)

This option implements the complete MS5.0_System.md specification with all 40+ microservices.

**See Section 12 of CODE_REVIEW_REPORT.md for detailed phased roadmap**

**Summary:**
- Phase 1-2: Event infrastructure + microservices foundation (Months 1-6)
- Phase 3: Identity & workflow (Months 6-9)
- Phase 4: Floor services (Months 9-15)
- Phase 5: People & skills (Months 15-18)
- Phase 6: Advanced features (Months 18-24)

**Total Effort:** 36-48 person-months  
**Total Cost:** $1.5M - $2.5M

---

## Recommendation Matrix

| Scenario | Recommended Option | Timeline | Cost |
|----------|-------------------|----------|------|
| **Need production system ASAP, accept gaps** | Option 1 | 4-6 weeks | $86K-$125K |
| **Want event-driven, workflows, OPC UA** | Option 2 | 3-6 months | $400K-$600K |
| **Full IWS/TPM implementation required** | Option 3 | 18-24 months | $1.5M-$2.5M |
| **Pilot project, prove value first** | Option 1 → Option 2 | 6-9 months total | $500K-$700K |
| **Enterprise rollout, 5+ factories** | Option 3 | 24 months | $2M-$3M |

---

## Success Metrics

### Option 1 Metrics (Minimal Deployment)
- System uptime > 99%
- PLC data collection uptime > 95%
- < 10 critical bugs in first month
- Operator satisfaction > 7/10
- Time to generate OEE report < 5 seconds

### Option 2 Metrics (Enhanced Deployment)
- All Option 1 metrics +
- Event throughput > 10,000 events/second
- Workflow completion rate > 98%
- OPC UA device support confirmed
- Zero data loss during network outages
- DDS session completion < 30 minutes

### Option 3 Metrics (Full Compliance)
- All Option 2 metrics +
- > 90% of MS5.0_System.md features implemented
- Support 5+ manufacturing sites
- Skills matrix completion > 95%
- LSW adherence > 90%
- AI model accuracy > 85% for predictive maintenance

---

## Appendix: Quick Reference Checklists

### Pre-Deployment Checklist (All Options)
- [ ] Ubuntu server provisioned (min 4 CPU, 8GB RAM)
- [ ] Network access to PLCs verified
- [ ] Firewall rules configured
- [ ] SSL certificates obtained
- [ ] Database backups tested
- [ ] Monitoring dashboards configured
- [ ] On-call rotation defined
- [ ] User training completed
- [ ] Rollback plan documented

### Post-Deployment Checklist
- [ ] Health checks passing
- [ ] PLC data flowing
- [ ] WebSocket connections stable
- [ ] Grafana dashboards populating
- [ ] Alerts routing correctly
- [ ] Users able to log in
- [ ] Tablets connecting
- [ ] Backup jobs running
- [ ] Performance within targets

### Weekly Operations Checklist
- [ ] Review error logs
- [ ] Check disk space usage
- [ ] Verify backup completion
- [ ] Review security alerts
- [ ] Check database performance
- [ ] Review user feedback
- [ ] Update documentation as needed

---

**Document Version:** 1.0  
**Last Updated:** October 1, 2025  
**Next Review:** After option selection

