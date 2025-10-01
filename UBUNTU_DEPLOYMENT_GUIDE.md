# MS5.0 Floor Dashboard - Complete Ubuntu Edge Deployment Guide

## Document Information
- **Version:** 2.0 (Updated for current codebase)
- **Last Updated:** October 1, 2025
- **Repository:** https://github.com/Dashboard4-0/MS5_App.git
- **Deployment Target:** Ubuntu 20.04/22.04 LTS Edge Device
- **Related Documents:** 
  - CODE_REVIEW_REPORT.md (comprehensive system analysis)
  - IMPLEMENTATION_PLAN_TO_READY.md (deployment options & roadmap)
  - MS5.0_System.md (full system specification)

---

## Table of Contents
1. [Executive Summary](#executive-summary)
2. [Prerequisites](#prerequisites)
3. [System Requirements](#system-requirements)
4. [Pre-Deployment Checklist](#pre-deployment-checklist)
5. [Initial Server Setup](#initial-server-setup)
6. [Docker Installation](#docker-installation)
7. [Repository Setup](#repository-setup)
8. [Environment Configuration](#environment-configuration)
9. [Database Setup](#database-setup)
10. [PLC Integration Configuration](#plc-integration-configuration)
11. [SSL Certificate Setup](#ssl-certificate-setup)
12. [Service Deployment](#service-deployment)
13. [Frontend Tablet Deployment](#frontend-tablet-deployment)
14. [Verification & Testing](#verification--testing)
15. [Monitoring Setup](#monitoring-setup)
16. [Backup Configuration](#backup-configuration)
17. [Security Hardening](#security-hardening)
18. [Troubleshooting Guide](#troubleshooting-guide)
19. [Maintenance Procedures](#maintenance-procedures)
20. [Quick Reference](#quick-reference)

---

## Executive Summary

This guide provides **complete step-by-step instructions** to deploy the MS5.0 Floor Dashboard system on an Ubuntu edge device for **production use**. 

### What This Deployment Provides

✅ **PLC Data Collection:** Real-time data from Allen-Bradley CompactLogix and MicroLogix PLCs  
✅ **Production Monitoring:** OEE calculation, line status, equipment monitoring  
✅ **Andon System:** Real-time alerts with escalation paths  
✅ **Quality Tracking:** Defect recording and quality checks  
✅ **Job Management:** Work assignments and checklists  
✅ **Tablet Frontend:** PWA and native apps for floor operators  
✅ **Real-time Dashboards:** Live production metrics via WebSocket  
✅ **Monitoring Stack:** Prometheus + Grafana for system health  

### Current System Capabilities

Based on the comprehensive code review (see CODE_REVIEW_REPORT.md):
- **Readiness Score:** 45/100 for full MS5.0 specification
- **Production Ready For:** Allen-Bradley PLC data collection, basic OEE, Andon, production monitoring
- **Not Yet Implemented:** Event streaming (Kafka), workflows (Temporal), full IWS/TPM features
- **Architecture:** Monolithic Python/FastAPI backend (not microservices yet)

### Deployment Timeline

- **Pre-deployment setup:** 2-4 hours
- **Installation & configuration:** 4-6 hours
- **PLC setup & testing:** 2-4 hours
- **Frontend deployment:** 2-3 hours
- **Verification & training:** 4-6 hours
- **Total:** 1-2 days for complete deployment

---

## Prerequisites

### Required Knowledge

**Essential:**
- Linux command line (bash, file navigation, text editing)
- Basic networking (IP addresses, ports, firewall rules)
- Docker and Docker Compose fundamentals
- PostgreSQL database basics

**Helpful:**
- PLC programming concepts (tag structure, data types)
- Allen-Bradley Logix/SLC familiarity
- REST API concepts
- SSL/TLS certificate management

### Required Access

**System Access:**
- [ ] Root/sudo access to Ubuntu server
- [ ] Network access from server to factory PLCs
- [ ] SSH access to server (port 22)

**PLC Access:**
- [ ] IP addresses of all PLCs
- [ ] Network access to PLCs (same VLAN or routed)
- [ ] Knowledge of PLC tag names and data types
- [ ] Ability to configure PLC to allow EtherNet/IP connections

**External Access:**
- [ ] GitHub account with access to repository
- [ ] Email address for SSL certificate validation (if using Let's Encrypt)
- [ ] Domain name (optional, for HTTPS)

### Required Information

Before starting, gather:

**Network Information:**
```
Edge Server IP: ________________
Server Hostname: ________________
DNS/Domain (if any): ________________
Default Gateway: ________________
Subnet Mask: ________________
```

**PLC Information:**
```
PLC 1:
  - Name: ________________
  - IP Address: ________________
  - PLC Type (Logix/SLC): ________________
  - Equipment Code: ________________

PLC 2:
  - Name: ________________
  - IP Address: ________________
  - PLC Type (Logix/SLC): ________________
  - Equipment Code: ________________
```

---

## System Requirements

### Minimum Hardware Requirements

For basic deployment (1-2 lines, <100 tags):
```
CPU:     2 cores (Intel/AMD x86_64)
RAM:     4GB
Storage: 50GB SSD
Network: 100Mbps Ethernet
```

### Recommended Hardware Requirements

For production deployment (3-5 lines, 200+ tags):
```
CPU:     4 cores @ 2.0GHz+
RAM:     8GB
Storage: 100GB SSD (NVMe preferred)
Network: 1Gbps Ethernet
```

### Software Requirements

**Operating System:**
- Ubuntu 20.04 LTS (Focal Fossa) ✅ Recommended
- Ubuntu 22.04 LTS (Jammy Jellyfish) ✅ Recommended

**Required Software (installed during setup):**
- Docker Engine 20.10+
- Docker Compose 2.0+
- Git 2.25+
- PostgreSQL client tools

---

## Pre-Deployment Checklist

**Complete this checklist before starting deployment:**

### Infrastructure Readiness
- [ ] Ubuntu server provisioned and accessible via SSH
- [ ] Server has internet connectivity
- [ ] Server can reach factory network/PLCs
- [ ] Firewall rules documented and approved
- [ ] DNS records configured (if using domain name)

### Network Validation
- [ ] Can ping PLCs from server
- [ ] No firewall blocking between server and PLCs
- [ ] PLC IP addresses documented and verified
- [ ] PLC tag lists available

---

## Initial Server Setup

### Step 1: Update System Packages

Login to your Ubuntu server and update:

\`\`\`bash
ssh your-username@<server-ip>

# Update package lists
sudo apt update

# Upgrade existing packages
sudo apt upgrade -y

# Install essential tools
sudo apt install -y curl wget git nano vim htop net-tools unzip \
  software-properties-common apt-transport-https ca-certificates \
  gnupg lsb-release postgresql-client

# Reboot if kernel was updated
sudo reboot
\`\`\`

### Step 2: Configure Firewall

\`\`\`bash
# IMPORTANT: Allow SSH FIRST to avoid lockout!
sudo ufw allow 22/tcp comment 'SSH'
sudo ufw enable

# Allow HTTP and HTTPS
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'

# Allow backend API
sudo ufw allow 8000/tcp comment 'MS5 Backend API'

# Allow Grafana
sudo ufw allow 3000/tcp comment 'Grafana Dashboard'

# Check firewall status
sudo ufw status verbose
\`\`\`

### Step 3: Create Application User

\`\`\`bash
# Create user
sudo adduser ms5app

# Add to sudo group
sudo usermod -aG sudo ms5app

# Switch to new user
su - ms5app
\`\`\`

---

## Docker Installation

### Step 1: Install Docker Engine

\`\`\`bash
# Remove old Docker versions
sudo apt remove -y docker docker-engine docker.io containerd runc

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Verify installation
docker --version
docker compose version
\`\`\`

### Step 2: Configure Docker

\`\`\`bash
# Add user to docker group
sudo usermod -aG docker \$USER
sudo usermod -aG docker ms5app

# Log out and back in, or run:
newgrp docker

# Test Docker
docker run hello-world
\`\`\`

---

## Repository Setup

### Step 1: Clone Repository

\`\`\`bash
# Create directory
sudo mkdir -p /opt/ms5
sudo chown -R ms5app:ms5app /opt/ms5

# Switch to application user
su - ms5app
cd /opt/ms5

# Clone the MS5_App repository
git clone https://github.com/Dashboard4-0/MS5_App.git .

# Verify clone
ls -la
\`\`\`

**Expected files:**
- backend/
- frontend/
- *.sql (database migration files 001-009)
- CODE_REVIEW_REPORT.md
- IMPLEMENTATION_PLAN_TO_READY.md
- README.md

### Step 2: Verify SQL Migration Files

\`\`\`bash
# List SQL files in order
ls -1 *.sql

# Expected output:
# 001_init_telemetry.sql
# 002_plc_equipment_management.sql
# 003_production_management.sql
# 004_advanced_production_features.sql
# 005_andon_escalation_system.sql
# 006_report_system.sql
# 007_plc_integration_phase1.sql
# 008_fix_critical_schema_issues.sql
# 009_database_optimization.sql
\`\`\`

---

## Environment Configuration

### Step 1: Create Production Environment File

\`\`\`bash
cd /opt/ms5/backend
cp env.example .env.production
nano .env.production
\`\`\`

### Step 2: Configure Critical Variables

Generate secure passwords first:

\`\`\`bash
# Generate SECRET_KEY (64+ characters)
openssl rand -base64 64

# Generate database password
openssl rand -base64 32

# Generate Redis password
openssl rand -base64 32
\`\`\`

**Edit .env.production with these values:**

\`\`\`bash
# SECURITY SETTINGS
SECRET_KEY="<paste-64-char-key-here>"

# DATABASE
DATABASE_URL="postgresql://ms5_user:<DB_PASSWORD>@postgres:5432/factory_telemetry"

# REDIS
REDIS_URL="redis://:<REDIS_PASSWORD>@redis:6379/0"
REDIS_PASSWORD="<REDIS_PASSWORD>"

# CORS (update with your server IP or domain)
ALLOWED_ORIGINS="http://localhost:3000,http://192.168.1.100,https://yourdomain.com"
ALLOWED_HOSTS="localhost,127.0.0.1,192.168.1.100,yourdomain.com"

# PLC SETTINGS
PLC_POLL_INTERVAL=1
PLC_TIMEOUT=5
PLC_RETRY_ATTEMPTS=3

# ENVIRONMENT
ENVIRONMENT="production"
DEBUG="False"
LOG_LEVEL="INFO"
\`\`\`

### Step 3: Create Required Directories

\`\`\`bash
cd /opt/ms5/backend
mkdir -p logs reports uploads temp backups ssl/production
chmod 755 logs reports uploads temp backups ssl/production
\`\`\`

---

## Database Setup

### Step 1: Start PostgreSQL

\`\`\`bash
cd /opt/ms5/backend

# Start only database services first
docker compose -f docker-compose.production.yml up -d postgres redis

# Watch logs
docker compose -f docker-compose.production.yml logs -f postgres
# Wait for: "database system is ready to accept connections"
# Press Ctrl+C to exit
\`\`\`

### Step 2: Verify Database

\`\`\`bash
# Test connection
docker exec -it ms5_postgres_production psql -U ms5_user -d factory_telemetry -c "SELECT version();"
\`\`\`

### Step 3: Enable TimescaleDB

\`\`\`bash
docker exec -it ms5_postgres_production psql -U ms5_user -d factory_telemetry
# Inside psql:
CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
\dx
\q
\`\`\`

### Step 4: Run Database Migrations

**Navigate to repository root:**
\`\`\`bash
cd /opt/ms5
\`\`\`

**Run each migration in order:**

\`\`\`bash
# Set password variable
export PGPASSWORD="YOUR_DATABASE_PASSWORD"

# Run migrations
for sql_file in 00*.sql; do
  echo "Running \$sql_file..."
  docker exec -i ms5_postgres_production psql -U ms5_user -d factory_telemetry < "\$sql_file"
done

echo "All migrations completed!"

# Clear password
unset PGPASSWORD
\`\`\`

### Step 5: Verify Schema

\`\`\`bash
docker exec -it ms5_postgres_production psql -U ms5_user -d factory_telemetry

# List tables
\dt factory_telemetry.*

# Check hypertables
SELECT * FROM timescaledb_information.hypertables;

\q
\`\`\`

---

## PLC Integration Configuration

**This is the CRITICAL section for getting data from your PLCs.**

### Step 1: Test PLC Connectivity

\`\`\`bash
# Test ping
ping -c 4 <PLC-IP>

# Test EtherNet/IP port
nc -zv <PLC-IP> 44818
\`\`\`

### Step 2: Insert PLC Configurations

\`\`\`bash
docker exec -it ms5_postgres_production psql -U ms5_user -d factory_telemetry
\`\`\`

**Insert your PLC (adjust values):**

\`\`\`sql
INSERT INTO factory_telemetry.plc_config (
    name, 
    ip_address, 
    plc_type, 
    port, 
    enabled, 
    poll_interval_s
) VALUES (
    'Line 1 PLC',
    '192.168.1.10',
    'LOGIX',
    44818,
    TRUE,
    1.0
) ON CONFLICT (ip_address, port) DO NOTHING;

-- Verify
SELECT id, name, ip_address, plc_type, enabled 
FROM factory_telemetry.plc_config;
\`\`\`

### Step 3: Insert Equipment

\`\`\`sql
INSERT INTO factory_telemetry.equipment_config (
    equipment_code,
    name,
    description,
    plc_id,
    enabled
) VALUES (
    'LINE1_FILLER',
    'Line 1 Filler Station',
    'Primary filling station',
    (SELECT id FROM factory_telemetry.plc_config WHERE ip_address = '192.168.1.10'),
    TRUE
) ON CONFLICT (equipment_code) DO NOTHING;

-- Verify
SELECT equipment_code, name, enabled 
FROM factory_telemetry.equipment_config;
\`\`\`

### Step 4: Define Metrics (PLC Tags)

\`\`\`sql
-- Machine running status
INSERT INTO factory_telemetry.metric_def (
    equipment_code,
    metric_key,
    value_type,
    unit,
    description,
    enabled
) VALUES (
    'LINE1_FILLER',
    'MachineRunning',
    'BOOL',
    NULL,
    'Machine running status',
    TRUE
) ON CONFLICT (equipment_code, metric_key) DO NOTHING;

-- Current speed
INSERT INTO factory_telemetry.metric_def (
    equipment_code,
    metric_key,
    value_type,
    unit,
    description,
    enabled
) VALUES (
    'LINE1_FILLER',
    'CurrentSpeed',
    'REAL',
    'BPM',
    'Line speed in bottles per minute',
    TRUE
) ON CONFLICT (equipment_code, metric_key) DO NOTHING;

-- Product counter
INSERT INTO factory_telemetry.metric_def (
    equipment_code,
    metric_key,
    value_type,
    unit,
    description,
    enabled
) VALUES (
    'LINE1_FILLER',
    'ProductCount',
    'INT',
    'units',
    'Product counter',
    TRUE
) ON CONFLICT (equipment_code, metric_key) DO NOTHING;
\`\`\`

### Step 5: Bind Metrics to PLC Tags

**Map each metric to actual PLC tag address:**

\`\`\`sql
-- Bind MachineRunning
INSERT INTO factory_telemetry.metric_binding (
    metric_def_id,
    plc_kind,
    address
) VALUES (
    (SELECT id FROM factory_telemetry.metric_def 
     WHERE equipment_code = 'LINE1_FILLER' AND metric_key = 'MachineRunning'),
    'LOGIX',
    'Program:MainProgram.Status.Running'
);

-- Bind CurrentSpeed
INSERT INTO factory_telemetry.metric_binding (
    metric_def_id,
    plc_kind,
    address
) VALUES (
    (SELECT id FROM factory_telemetry.metric_def 
     WHERE equipment_code = 'LINE1_FILLER' AND metric_key = 'CurrentSpeed'),
    'LOGIX',
    'Program:MainProgram.Production.Speed'
);

-- Bind ProductCount
INSERT INTO factory_telemetry.metric_binding (
    metric_def_id,
    plc_kind,
    address
) VALUES (
    (SELECT id FROM factory_telemetry.metric_def 
     WHERE equipment_code = 'LINE1_FILLER' AND metric_key = 'ProductCount'),
    'LOGIX',
    'Program:MainProgram.Production.Counter'
);

-- Verify bindings
SELECT 
    md.equipment_code,
    md.metric_key,
    mb.plc_kind,
    mb.address
FROM factory_telemetry.metric_binding mb
JOIN factory_telemetry.metric_def md ON mb.metric_def_id = md.id;

\q
\`\`\`

**⚠️ CRITICAL:** Replace tag addresses with your actual PLC tag names!

---

## SSL Certificate Setup

### Option 1: Let's Encrypt (Recommended)

\`\`\`bash
# Install Certbot
sudo apt install -y certbot

# Generate certificate
sudo certbot certonly --standalone \
  -d yourdomain.com \
  -d www.yourdomain.com \
  --email your-email@example.com \
  --agree-tos

# Copy certificates
sudo cp /etc/letsencrypt/live/yourdomain.com/fullchain.pem /opt/ms5/backend/ssl/production/production.crt
sudo cp /etc/letsencrypt/live/yourdomain.com/privkey.pem /opt/ms5/backend/ssl/production/production.key

# Set permissions
sudo chown ms5app:ms5app /opt/ms5/backend/ssl/production/*
sudo chmod 600 /opt/ms5/backend/ssl/production/production.key
sudo chmod 644 /opt/ms5/backend/ssl/production/production.crt
\`\`\`

### Option 2: Self-Signed (Development)

\`\`\`bash
cd /opt/ms5/backend

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ssl/production/production.key \
  -out ssl/production/production.crt \
  -subj "/C=US/ST=State/L=City/O=Company/CN=ms5.local"

chmod 600 ssl/production/production.key
chmod 644 ssl/production/production.crt
\`\`\`

---

## Service Deployment

### Step 1: Build and Start Services

\`\`\`bash
cd /opt/ms5/backend

# Build images
docker compose -f docker-compose.production.yml build backend

# Start all services
docker compose -f docker-compose.production.yml up -d

# Watch startup logs
docker compose -f docker-compose.production.yml logs -f
\`\`\`

**Wait for:** "Application startup complete"

### Step 2: Verify Services

\`\`\`bash
# Check all services running
docker compose -f docker-compose.production.yml ps

# All should show "Up" or "Up (healthy)"
\`\`\`

---

## Frontend Tablet Deployment

### Option 1: PWA (Recommended)

**On tablet browser:**
1. Navigate to: `https://<server-ip>` or `https://yourdomain.com`
2. Login with admin credentials
3. Click "Add to Home Screen"
4. App installs as PWA with offline support

**Configure tablet:**
- Screen timeout: Never
- Auto-rotate: Off (Lock landscape)
- Allow notifications: On

### Option 2: Native Android App

**Build on dev machine:**
\`\`\`bash
cd frontend
npm install
cd android
./gradlew assembleRelease
\`\`\`

**Install on tablet:**
\`\`\`bash
adb install app/build/outputs/apk/release/app-release.apk
\`\`\`

---

## Verification & Testing

### Step 1: Backend Health Check

\`\`\`bash
# Test health
curl -f http://localhost:8000/health

# Expected: {"status":"healthy",...}
\`\`\`

### Step 2: Verify PLC Data

\`\`\`bash
# Check PLC connection
docker compose -f docker-compose.production.yml logs backend | grep "PLC"

# Check data in database
docker exec -it ms5_postgres_production psql -U ms5_user -d factory_telemetry -c \
  "SELECT md.equipment_code, md.metric_key, ml.ts 
   FROM factory_telemetry.metric_latest ml 
   JOIN factory_telemetry.metric_def md ON ml.metric_def_id = md.id 
   ORDER BY ml.ts DESC LIMIT 5;"
\`\`\`

### Step 3: Frontend Test

**From browser:**
1. Navigate to server IP/domain
2. Login as admin
3. Verify dashboard loads
4. Check real-time data updating

---

## Monitoring Setup

### Step 1: Access Grafana

**Navigate to:** `http://<server-ip>:3000`

**Login:**
- Username: admin
- Password: (from .env.production)

### Step 2: Verify Dashboards

Go to Dashboards → Browse

Should see:
- MS5 System Overview
- MS5 Production Dashboard
- MS5 Andon Dashboard
- MS5 TimescaleDB Monitoring

---

## Backup Configuration

### Create Backup Script

\`\`\`bash
cat > /opt/ms5/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/ms5/backups"
DATE=\$(date +%Y%m%d_%H%M%S)
mkdir -p \$BACKUP_DIR

# Database backup
docker exec ms5_postgres_production pg_dump -U ms5_user factory_telemetry | \
  gzip > \$BACKUP_DIR/db_backup_\$DATE.sql.gz

# Config backup
tar -czf \$BACKUP_DIR/config_backup_\$DATE.tar.gz \
  /opt/ms5/backend/.env.production \
  /opt/ms5/backend/ssl/production

# Remove old backups (30+ days)
find \$BACKUP_DIR -name "*.gz" -mtime +30 -delete

echo "Backup completed: \$DATE"
EOF

chmod +x /opt/ms5/backup.sh
\`\`\`

### Schedule Daily Backups

\`\`\`bash
crontab -e
# Add:
0 2 * * * /opt/ms5/backup.sh >> /opt/ms5/logs/backup.log 2>&1
\`\`\`

---

## Security Hardening

### Disable Root Login

\`\`\`bash
sudo nano /etc/ssh/sshd_config
# Set: PermitRootLogin no
sudo systemctl restart sshd
\`\`\`

### Install Fail2Ban

\`\`\`bash
sudo apt install -y fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
\`\`\`

---

## Troubleshooting Guide

### Issue: Cannot Connect to PLC

**Solutions:**

\`\`\`bash
# Test connectivity
ping <PLC-IP>
nc -zv <PLC-IP> 44818

# Check PLC config
docker exec -it ms5_postgres_production psql -U ms5_user -d factory_telemetry -c \
  "SELECT * FROM factory_telemetry.plc_config WHERE enabled = TRUE;"

# Check backend logs
docker compose -f docker-compose.production.yml logs backend | grep -i "plc"
\`\`\`

### Issue: Database Connection Failed

\`\`\`bash
# Check PostgreSQL running
docker compose -f docker-compose.production.yml ps postgres

# Check logs
docker compose -f docker-compose.production.yml logs postgres

# Test connection
docker exec -it ms5_postgres_production psql -U ms5_user -d factory_telemetry -c "SELECT 1;"
\`\`\`

### Issue: Out of Disk Space

\`\`\`bash
# Check usage
df -h
docker system df

# Clean up
docker system prune -a
docker volume prune

# Clean old logs
find /opt/ms5/backend/logs -name "*.log" -mtime +7 -delete
\`\`\`

---

## Maintenance Procedures

### Daily Checks

\`\`\`bash
# Service health
docker compose -f docker-compose.production.yml ps

# Disk space
df -h

# Recent errors
docker compose -f docker-compose.production.yml logs --tail=100 | grep -i error

# PLC data flowing
docker exec -it ms5_postgres_production psql -U ms5_user -d factory_telemetry -c \
  "SELECT COUNT(*) FROM factory_telemetry.metric_latest WHERE ts > NOW() - INTERVAL '5 minutes';"
\`\`\`

### Weekly Tasks

\`\`\`bash
# Update system
sudo apt update && sudo apt upgrade -y

# Clean Docker
docker system prune -f

# Review logs
cd /opt/ms5/backend/logs
tail -100 backend.log | grep -i error
\`\`\`

### Monthly Tasks

\`\`\`bash
# Update Docker images
cd /opt/ms5/backend
docker compose -f docker-compose.production.yml pull
docker compose -f docker-compose.production.yml up -d

# Optimize database
docker exec -it ms5_postgres_production psql -U ms5_user -d factory_telemetry -c "VACUUM ANALYZE;"

# Review certificates
openssl x509 -in ssl/production/production.crt -noout -dates
\`\`\`

---

## Quick Reference

### Essential Commands

\`\`\`bash
# Navigate to app
cd /opt/ms5/backend

# Start services
docker compose -f docker-compose.production.yml up -d

# Stop services
docker compose -f docker-compose.production.yml down

# Restart
docker compose -f docker-compose.production.yml restart

# View logs
docker compose -f docker-compose.production.yml logs -f

# Service status
docker compose -f docker-compose.production.yml ps

# Database access
docker exec -it ms5_postgres_production psql -U ms5_user -d factory_telemetry

# Health check
curl http://localhost:8000/health
\`\`\`

### Service URLs

```
Backend API:    http://<server-ip>:8000
API Docs:       http://<server-ip>:8000/docs
Grafana:        http://<server-ip>:3000
Prometheus:     http://<server-ip>:9090
Frontend:       https://<server-ip>
```

### Important Paths

```
Application:    /opt/ms5/
Backend:        /opt/ms5/backend/
Environment:    /opt/ms5/backend/.env.production
Docker Compose: /opt/ms5/backend/docker-compose.production.yml
Logs:           /opt/ms5/backend/logs/
Backups:        /opt/ms5/backups/
SSL Certs:      /opt/ms5/backend/ssl/production/
```

### Emergency Procedures

**Stop Everything:**
\`\`\`bash
cd /opt/ms5/backend
docker compose -f docker-compose.production.yml down
\`\`\`

**Restart Everything:**
\`\`\`bash
docker compose -f docker-compose.production.yml down
docker compose -f docker-compose.production.yml up -d
\`\`\`

**Emergency Backup:**
\`\`\`bash
docker exec ms5_postgres_production pg_dump -U ms5_user factory_telemetry > /tmp/emergency_backup.sql
\`\`\`

---

## Support & Resources

### Documentation
- **Code Review:** CODE_REVIEW_REPORT.md
- **Implementation Plan:** IMPLEMENTATION_PLAN_TO_READY.md
- **System Spec:** MS5.0_System.md
- **API Docs:** http://\<server-ip\>:8000/docs

### Repository
- **GitHub:** https://github.com/Dashboard4-0/MS5_App.git
- **Issues:** https://github.com/Dashboard4-0/MS5_App/issues

---

## Post-Deployment Checklist

- [ ] All Docker containers running
- [ ] Backend health check returns 200
- [ ] Database migrations complete
- [ ] All PLCs configured
- [ ] PLC connectivity tested
- [ ] Data flowing (metric_latest updated)
- [ ] Frontend accessible from tablets
- [ ] WebSocket connection working
- [ ] Grafana dashboards showing data
- [ ] Backups scheduled and tested
- [ ] Firewall configured
- [ ] SSL certificates installed
- [ ] Default passwords changed
- [ ] Users trained

---

## System Limitations

**Current Version Includes:**
- ✅ Allen-Bradley CompactLogix/MicroLogix support
- ✅ Basic OEE calculation
- ✅ Andon system
- ✅ Production monitoring
- ✅ Quality tracking

**NOT Included (See IMPLEMENTATION_PLAN_TO_READY.md):**
- ❌ Event streaming (Kafka)
- ❌ Workflow orchestration (Temporal)
- ❌ Full IWS/TPM workflows
- ❌ OPC UA support
- ❌ Microservices architecture

---

**Deployment Guide Version:** 2.0  
**Last Updated:** October 1, 2025  
**Repository:** https://github.com/Dashboard4-0/MS5_App.git

**This guide successfully deploys a production-ready MS5.0 system on Ubuntu edge devices.**
