# MS5.0 Floor Dashboard - Deployment Guide

## Table of Contents
1. [Overview](#overview)
2. [System Requirements](#system-requirements)
3. [Pre-deployment Checklist](#pre-deployment-checklist)
4. [Environment Setup](#environment-setup)
5. [Database Setup](#database-setup)
6. [Backend Deployment](#backend-deployment)
7. [Frontend Deployment](#frontend-deployment)
8. [Configuration](#configuration)
9. [SSL/TLS Setup](#ssltls-setup)
10. [Monitoring Setup](#monitoring-setup)
11. [Testing](#testing)
12. [Go-Live](#go-live)
13. [Post-deployment](#post-deployment)
14. [Troubleshooting](#troubleshooting)

## Overview

This guide provides comprehensive instructions for deploying the MS5.0 Floor Dashboard system to production, staging, and development environments. The deployment process includes database setup, backend API deployment, frontend application deployment, monitoring configuration, and system validation.

### Deployment Architecture
- **Load Balancer**: Nginx for SSL termination and load balancing
- **Application Server**: FastAPI backend with Gunicorn
- **Database**: PostgreSQL with TimescaleDB extension
- **Cache**: Redis for session storage and caching
- **Monitoring**: Prometheus, Grafana, and Alertmanager
- **Container Platform**: Docker and Docker Compose

## System Requirements

### Hardware Requirements

#### Production Environment
- **CPU**: 8+ cores (Intel Xeon or AMD EPYC recommended)
- **RAM**: 32GB minimum, 64GB recommended
- **Storage**: 500GB+ SSD storage
- **Network**: Gigabit Ethernet connection
- **Backup**: Automated backup system

#### Staging Environment
- **CPU**: 4+ cores
- **RAM**: 16GB minimum
- **Storage**: 250GB+ SSD storage
- **Network**: Gigabit Ethernet connection

#### Development Environment
- **CPU**: 2+ cores
- **RAM**: 8GB minimum
- **Storage**: 100GB+ storage
- **Network**: Standard Ethernet connection

### Software Requirements

#### Operating System
- **Production**: Ubuntu 20.04 LTS or CentOS 8+
- **Staging**: Ubuntu 20.04 LTS or CentOS 8+
- **Development**: Ubuntu 20.04 LTS, macOS 10.15+, or Windows 10+

#### Required Software
- **Docker**: 20.10+
- **Docker Compose**: 2.0+
- **Git**: 2.25+
- **Node.js**: 16+ (for frontend builds)
- **Python**: 3.9+ (for backend)

#### Database Requirements
- **PostgreSQL**: 13+
- **TimescaleDB**: 2.7+
- **Redis**: 6.0+

## Pre-deployment Checklist

### Environment Preparation
- [ ] Server hardware provisioned and configured
- [ ] Operating system installed and updated
- [ ] Required software packages installed
- [ ] Network connectivity verified
- [ ] Firewall rules configured
- [ ] SSL certificates obtained
- [ ] Domain names configured
- [ ] DNS records updated

### Security Preparation
- [ ] SSH keys configured for deployment access
- [ ] User accounts created with appropriate permissions
- [ ] Firewall configured with required ports
- [ ] SSL certificates installed
- [ ] Security scanning completed
- [ ] Backup procedures tested

### Application Preparation
- [ ] Application code reviewed and tested
- [ ] Database migrations prepared
- [ ] Configuration files updated
- [ ] Environment variables defined
- [ ] Secrets management configured
- [ ] Monitoring configuration prepared

## Environment Setup

### Server Setup

#### 1. Update System Packages
```bash
# Ubuntu/Debian
sudo apt update && sudo apt upgrade -y

# CentOS/RHEL
sudo yum update -y
```

#### 2. Install Required Packages
```bash
# Ubuntu/Debian
sudo apt install -y curl wget git vim htop unzip

# CentOS/RHEL
sudo yum install -y curl wget git vim htop unzip
```

#### 3. Install Docker
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.12.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

#### 4. Configure Firewall
```bash
# Ubuntu/Debian (UFW)
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 5432/tcp  # PostgreSQL (if external access needed)
sudo ufw allow 6379/tcp  # Redis (if external access needed)
sudo ufw enable

# CentOS/RHEL (firewalld)
sudo firewall-cmd --permanent --add-port=22/tcp
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --permanent --add-port=5432/tcp
sudo firewall-cmd --permanent --add-port=6379/tcp
sudo firewall-cmd --reload
```

### Directory Structure
Create the application directory structure:

```bash
sudo mkdir -p /opt/ms5-dashboard
sudo chown $USER:$USER /opt/ms5-dashboard
cd /opt/ms5-dashboard

# Create subdirectories
mkdir -p {data,logs,backups,ssl,config}
mkdir -p data/{postgres,redis,grafana,prometheus}
mkdir -p logs/{nginx,backend,frontend}
```

## Database Setup

### PostgreSQL Installation

#### 1. Install PostgreSQL
```bash
# Ubuntu/Debian
sudo apt install -y postgresql postgresql-contrib

# CentOS/RHEL
sudo yum install -y postgresql-server postgresql-contrib
sudo postgresql-setup initdb
```

#### 2. Install TimescaleDB Extension
```bash
# Ubuntu/Debian
sudo apt install -y timescaledb-postgresql-13

# CentOS/RHEL
sudo yum install -y timescaledb-postgresql13
```

#### 3. Configure PostgreSQL
```bash
# Edit postgresql.conf
sudo vim /etc/postgresql/13/main/postgresql.conf

# Add/modify these settings:
shared_preload_libraries = 'timescaledb'
max_connections = 200
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100

# Edit pg_hba.conf
sudo vim /etc/postgresql/13/main/pg_hba.conf

# Add this line for local connections:
local   all             all                                     md5
host    all             all             127.0.0.1/32            md5
host    all             all             ::1/128                 md5
```

#### 4. Start PostgreSQL Service
```bash
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

#### 5. Create Database and User
```bash
# Switch to postgres user
sudo -u postgres psql

-- Create database
CREATE DATABASE factory_telemetry;

-- Create user
CREATE USER ms5_user WITH PASSWORD 'secure_password_here';

-- Grant permissions
GRANT ALL PRIVILEGES ON DATABASE factory_telemetry TO ms5_user;

-- Connect to database and create schema
\c factory_telemetry;
CREATE SCHEMA IF NOT EXISTS factory_telemetry;

-- Grant schema permissions
GRANT ALL ON SCHEMA factory_telemetry TO ms5_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA factory_telemetry TO ms5_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA factory_telemetry TO ms5_user;

-- Enable TimescaleDB extension
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Exit psql
\q
```

### Redis Installation

#### 1. Install Redis
```bash
# Ubuntu/Debian
sudo apt install -y redis-server

# CentOS/RHEL
sudo yum install -y redis
```

#### 2. Configure Redis
```bash
# Edit redis.conf
sudo vim /etc/redis/redis.conf

# Modify these settings:
bind 127.0.0.1
port 6379
timeout 300
maxmemory 256mb
maxmemory-policy allkeys-lru
save 900 1
save 300 10
save 60 10000
```

#### 3. Start Redis Service
```bash
sudo systemctl start redis
sudo systemctl enable redis
```

## Backend Deployment

### 1. Clone Application Code
```bash
cd /opt/ms5-dashboard
git clone https://github.com/company/ms5-dashboard.git .
```

### 2. Configure Environment Variables
```bash
# Copy environment template
cp backend/env.example backend/.env

# Edit environment file
vim backend/.env
```

#### Production Environment Variables
```bash
# Database Configuration
DATABASE_URL=postgresql://ms5_user:secure_password_here@localhost:5432/factory_telemetry
REDIS_URL=redis://localhost:6379/0

# Application Configuration
APP_NAME=MS5.0 Floor Dashboard
APP_VERSION=1.0.0
ENVIRONMENT=production
DEBUG=false
SECRET_KEY=your_super_secret_key_here
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_DAYS=7

# API Configuration
API_HOST=0.0.0.0
API_PORT=8000
CORS_ORIGINS=["https://dashboard.company.com"]

# Monitoring Configuration
PROMETHEUS_ENABLED=true
GRAFANA_ENABLED=true
LOG_LEVEL=INFO

# Email Configuration
SMTP_HOST=smtp.company.com
SMTP_PORT=587
SMTP_USERNAME=alerts@company.com
SMTP_PASSWORD=email_password_here
SMTP_TLS=true

# File Storage
UPLOAD_PATH=/opt/ms5-dashboard/uploads
MAX_FILE_SIZE=10485760
```

### 3. Build Docker Images
```bash
cd backend

# Build production image
docker build -f Dockerfile.production -t ms5-backend:latest .

# Build staging image (if needed)
docker build -f Dockerfile.staging -t ms5-backend:staging .
```

### 4. Deploy with Docker Compose
```bash
# Deploy production environment
docker-compose -f docker-compose.production.yml up -d

# Deploy staging environment
docker-compose -f docker-compose.staging.yml up -d
```

### 5. Run Database Migrations
```bash
# Run migrations
docker-compose -f docker-compose.production.yml exec backend python -m alembic upgrade head

# Verify database setup
docker-compose -f docker-compose.production.yml exec backend python scripts/validate_database.py
```

### 6. Initialize Application Data
```bash
# Create default users and roles
docker-compose -f docker-compose.production.yml exec backend python scripts/init_data.py

# Load sample data (if needed)
docker-compose -f docker-compose.production.yml exec backend python scripts/load_sample_data.py
```

## Frontend Deployment

### 1. Install Node.js and Dependencies
```bash
# Install Node.js 16+
curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install frontend dependencies
cd frontend
npm install
```

### 2. Configure Frontend Environment
```bash
# Copy environment template
cp .env.example .env.production

# Edit environment file
vim .env.production
```

#### Frontend Environment Variables
```bash
# API Configuration
REACT_APP_API_BASE_URL=https://api.company.com/api/v1
REACT_APP_WS_BASE_URL=wss://api.company.com/ws

# Application Configuration
REACT_APP_NAME=MS5.0 Floor Dashboard
REACT_APP_VERSION=1.0.0
REACT_APP_ENVIRONMENT=production

# Feature Flags
REACT_APP_ENABLE_ANALYTICS=true
REACT_APP_ENABLE_ERROR_REPORTING=true
REACT_APP_ENABLE_OFFLINE_MODE=true

# Push Notifications
REACT_APP_FCM_SERVER_KEY=your_fcm_server_key_here
```

### 3. Build Frontend Application
```bash
# Build production version
npm run build:production

# Build staging version (if needed)
npm run build:staging
```

### 4. Deploy Frontend Files
```bash
# Copy build files to web server directory
sudo cp -r build/* /var/www/html/

# Set proper permissions
sudo chown -R www-data:www-data /var/www/html/
sudo chmod -R 755 /var/www/html/
```

## Configuration

### Nginx Configuration

#### 1. Install Nginx
```bash
# Ubuntu/Debian
sudo apt install -y nginx

# CentOS/RHEL
sudo yum install -y nginx
```

#### 2. Configure Nginx for Production
```bash
# Copy production configuration
sudo cp nginx.production.conf /etc/nginx/sites-available/ms5-dashboard
sudo ln -s /etc/nginx/sites-available/ms5-dashboard /etc/nginx/sites-enabled/

# Remove default site
sudo rm /etc/nginx/sites-enabled/default

# Test configuration
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx
sudo systemctl enable nginx
```

#### Production Nginx Configuration
```nginx
# Upstream backend servers
upstream backend {
    server 127.0.0.1:8000;
    server 127.0.0.1:8001;
}

# Rate limiting
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=login:10m rate=1r/s;

# Main server block
server {
    listen 80;
    server_name dashboard.company.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name dashboard.company.com;

    # SSL Configuration
    ssl_certificate /opt/ms5-dashboard/ssl/cert.pem;
    ssl_certificate_key /opt/ms5-dashboard/ssl/key.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security Headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains";

    # Frontend
    location / {
        root /var/www/html;
        index index.html;
        try_files $uri $uri/ /index.html;
        
        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }

    # API Backend
    location /api/ {
        limit_req zone=api burst=20 nodelay;
        
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }

    # WebSocket
    location /ws {
        proxy_pass http://backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket timeouts
        proxy_connect_timeout 7d;
        proxy_send_timeout 7d;
        proxy_read_timeout 7d;
    }

    # Authentication endpoints with stricter rate limiting
    location /api/v1/auth/login {
        limit_req zone=login burst=5 nodelay;
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Monitoring endpoints
    location /metrics {
        allow 127.0.0.1;
        allow 10.0.0.0/8;
        deny all;
        
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### Application Configuration

#### 1. Configure Logging
```bash
# Create log directories
sudo mkdir -p /var/log/ms5-dashboard
sudo chown -R $USER:$USER /var/log/ms5-dashboard

# Configure log rotation
sudo vim /etc/logrotate.d/ms5-dashboard
```

#### Log Rotation Configuration
```
/var/log/ms5-dashboard/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 $USER $USER
    postrotate
        docker-compose -f /opt/ms5-dashboard/docker-compose.production.yml restart backend
    endscript
}
```

#### 2. Configure System Services
```bash
# Create systemd service file
sudo vim /etc/systemd/system/ms5-dashboard.service
```

#### Systemd Service Configuration
```ini
[Unit]
Description=MS5.0 Floor Dashboard
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/ms5-dashboard
ExecStart=/usr/local/bin/docker-compose -f docker-compose.production.yml up -d
ExecStop=/usr/local/bin/docker-compose -f docker-compose.production.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
```

```bash
# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable ms5-dashboard
sudo systemctl start ms5-dashboard
```

## SSL/TLS Setup

### 1. Obtain SSL Certificates

#### Using Let's Encrypt (Recommended for Production)
```bash
# Install Certbot
sudo apt install -y certbot python3-certbot-nginx

# Obtain certificate
sudo certbot --nginx -d dashboard.company.com -d api.company.com

# Test automatic renewal
sudo certbot renew --dry-run
```

#### Using Commercial Certificate
```bash
# Copy certificate files
sudo cp your-certificate.pem /opt/ms5-dashboard/ssl/cert.pem
sudo cp your-private-key.pem /opt/ms5-dashboard/ssl/key.pem

# Set proper permissions
sudo chmod 600 /opt/ms5-dashboard/ssl/key.pem
sudo chmod 644 /opt/ms5-dashboard/ssl/cert.pem
sudo chown root:root /opt/ms5-dashboard/ssl/*
```

### 2. Configure SSL Security
```bash
# Generate DH parameters
sudo openssl dhparam -out /opt/ms5-dashboard/ssl/dhparam.pem 2048

# Update Nginx configuration to include DH parameters
sudo vim /etc/nginx/sites-available/ms5-dashboard
```

Add to Nginx SSL configuration:
```nginx
ssl_dhparam /opt/ms5-dashboard/ssl/dhparam.pem;
```

## Monitoring Setup

### 1. Configure Prometheus
```bash
# Copy Prometheus configuration
sudo cp prometheus.production.yml /opt/ms5-dashboard/config/prometheus.yml

# Create Prometheus data directory
sudo mkdir -p /opt/ms5-dashboard/data/prometheus
sudo chown -R 65534:65534 /opt/ms5-dashboard/data/prometheus
```

### 2. Configure Grafana
```bash
# Create Grafana data directory
sudo mkdir -p /opt/ms5-dashboard/data/grafana
sudo chown -R 472:472 /opt/ms5-dashboard/data/grafana

# Copy Grafana configuration
sudo cp -r grafana/* /opt/ms5-dashboard/config/grafana/
```

### 3. Start Monitoring Services
```bash
# Start monitoring stack
docker-compose -f docker-compose.production.yml up -d prometheus grafana alertmanager

# Verify services are running
docker-compose -f docker-compose.production.yml ps
```

### 4. Configure Alertmanager
```bash
# Copy alert configuration
sudo cp alertmanager.yml /opt/ms5-dashboard/config/alertmanager.yml
sudo cp alert_rules.yml /opt/ms5-dashboard/config/alert_rules.yml

# Restart Alertmanager
docker-compose -f docker-compose.production.yml restart alertmanager
```

## Testing

### 1. System Health Checks
```bash
# Run comprehensive health check
./scripts/health_check.sh

# Check database connectivity
docker-compose -f docker-compose.production.yml exec backend python scripts/test_database.py

# Check Redis connectivity
docker-compose -f docker-compose.production.yml exec backend python scripts/test_redis.py

# Check API endpoints
./scripts/test_api_endpoints.sh
```

### 2. Load Testing
```bash
# Install load testing tools
pip install locust

# Run load tests
locust -f tests/load_test.py --host=https://api.company.com
```

### 3. Security Testing
```bash
# Run security scan
docker run --rm -v $(pwd):/src securecodewarrior/docker-security-scan

# Check SSL configuration
sslscan dashboard.company.com

# Test for common vulnerabilities
nikto -h https://dashboard.company.com
```

### 4. Performance Testing
```bash
# Run performance tests
./scripts/performance_test.sh

# Check response times
curl -w "@curl-format.txt" -o /dev/null -s "https://api.company.com/api/v1/health"
```

## Go-Live

### 1. Final Pre-deployment Checks
```bash
# Verify all services are running
docker-compose -f docker-compose.production.yml ps

# Check system resources
htop
df -h
free -h

# Verify SSL certificates
openssl s_client -connect dashboard.company.com:443 -servername dashboard.company.com

# Test database backups
./scripts/test_backup.sh
```

### 2. DNS Cutover
```bash
# Update DNS records to point to production server
# A record: dashboard.company.com -> <production_ip>
# A record: api.company.com -> <production_ip>

# Verify DNS propagation
dig dashboard.company.com
dig api.company.com
```

### 3. Final Validation
```bash
# Test frontend access
curl -I https://dashboard.company.com

# Test API access
curl -I https://api.company.com/api/v1/health

# Test WebSocket connection
wscat -c wss://api.company.com/ws

# Run smoke tests
./scripts/smoke_tests.sh
```

### 4. User Acceptance Testing
- [ ] Production manager can access dashboard
- [ ] Operators can view assigned jobs
- [ ] Quality inspectors can perform checks
- [ ] Maintenance personnel can create work orders
- [ ] Real-time updates are working
- [ ] Mobile responsiveness is correct
- [ ] All user roles have appropriate access

## Post-deployment

### 1. Monitor System Performance
```bash
# Check application logs
docker-compose -f docker-compose.production.yml logs -f backend

# Monitor system resources
htop
iostat 1
netstat -tulpn

# Check database performance
docker-compose -f docker-compose.production.yml exec postgres psql -U ms5_user -d factory_telemetry -c "SELECT * FROM pg_stat_activity;"
```

### 2. Set Up Automated Backups
```bash
# Configure daily backups
crontab -e

# Add backup schedule
0 2 * * * /opt/ms5-dashboard/scripts/backup.sh
0 3 * * * /opt/ms5-dashboard/scripts/cleanup_old_backups.sh
```

### 3. Configure Monitoring Alerts
- [ ] Set up email notifications
- [ ] Configure Slack alerts
- [ ] Test alert delivery
- [ ] Set up escalation procedures

### 4. User Training and Support
- [ ] Conduct user training sessions
- [ ] Create user documentation
- [ ] Set up help desk procedures
- [ ] Establish support escalation

### 5. Performance Optimization
```bash
# Monitor and optimize database queries
docker-compose -f docker-compose.production.yml exec backend python scripts/optimize_database.py

# Review and optimize application performance
docker-compose -f docker-compose.production.yml exec backend python scripts/performance_analysis.py

# Update monitoring dashboards
# Access Grafana at https://dashboard.company.com:3000
```

## Troubleshooting

### Common Issues

#### Application Won't Start
```bash
# Check Docker containers
docker-compose -f docker-compose.production.yml ps

# Check container logs
docker-compose -f docker-compose.production.yml logs backend

# Check system resources
free -h
df -h
```

#### Database Connection Issues
```bash
# Test database connectivity
docker-compose -f docker-compose.production.yml exec backend python scripts/test_database.py

# Check PostgreSQL status
sudo systemctl status postgresql

# Check database logs
sudo tail -f /var/log/postgresql/postgresql-13-main.log
```

#### SSL Certificate Issues
```bash
# Check certificate validity
openssl x509 -in /opt/ms5-dashboard/ssl/cert.pem -text -noout

# Test SSL configuration
sslscan dashboard.company.com

# Check Nginx SSL configuration
sudo nginx -t
```

#### Performance Issues
```bash
# Check system load
htop
iostat 1

# Check database performance
docker-compose -f docker-compose.production.yml exec postgres psql -U ms5_user -d factory_telemetry -c "SELECT * FROM pg_stat_activity;"

# Check application logs for errors
docker-compose -f docker-compose.production.yml logs backend | grep ERROR
```

### Emergency Procedures

#### System Recovery
```bash
# Restore from backup
./scripts/restore.sh backup_file.sql

# Restart all services
sudo systemctl restart ms5-dashboard

# Verify system health
./scripts/health_check.sh
```

#### Database Recovery
```bash
# Stop application services
docker-compose -f docker-compose.production.yml stop backend

# Restore database
docker-compose -f docker-compose.production.yml exec postgres psql -U ms5_user -d factory_telemetry < backup_file.sql

# Restart services
docker-compose -f docker-compose.production.yml start backend
```

#### Rollback Procedures
```bash
# Rollback to previous version
git checkout previous_version_tag
docker-compose -f docker-compose.production.yml down
docker-compose -f docker-compose.production.yml up -d

# Verify rollback
./scripts/health_check.sh
```

### Support Contacts
- **System Administrator**: admin@company.com
- **Database Administrator**: dba@company.com
- **Network Administrator**: network@company.com
- **Emergency Contact**: +1-555-0123

### Maintenance Windows
- **Weekly Maintenance**: Sundays 2:00 AM - 4:00 AM EST
- **Monthly Maintenance**: First Sunday 1:00 AM - 6:00 AM EST
- **Emergency Maintenance**: As needed with 4-hour notice

---

*This deployment guide is updated regularly. For the latest version, please check the project repository.*
