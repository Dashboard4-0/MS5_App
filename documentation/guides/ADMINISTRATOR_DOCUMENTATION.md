# MS5.0 Floor Dashboard - Administrator Documentation

## Table of Contents
1. [System Architecture](#system-architecture)
2. [Installation and Configuration](#installation-and-configuration)
3. [User Management](#user-management)
4. [Security Configuration](#security-configuration)
5. [System Monitoring](#system-monitoring)
6. [Backup and Recovery](#backup-and-recovery)
7. [Performance Tuning](#performance-tuning)
8. [Troubleshooting](#troubleshooting)
9. [Maintenance Procedures](#maintenance-procedures)
10. [Disaster Recovery](#disaster-recovery)

## System Architecture

### Overview
The MS5.0 Floor Dashboard is built on a modern microservices architecture designed for high availability, scalability, and maintainability.

### Core Components

#### **Backend Services**
- **API Gateway**: FastAPI-based REST API with WebSocket support
- **Authentication Service**: JWT-based authentication with role management
- **Production Service**: Real-time production monitoring and control
- **OEE Calculator**: Advanced OEE calculation engine
- **Andon Service**: Event management and escalation system
- **Report Generator**: Dynamic report generation and export
- **WebSocket Manager**: Real-time data broadcasting
- **PLC Integration**: Direct PLC connectivity and data processing

#### **Frontend Application**
- **React Native**: Cross-platform mobile application
- **Redux Store**: Centralized state management
- **Offline Support**: Comprehensive offline capabilities
- **Real-time Updates**: WebSocket-based live data updates
- **Progressive Web App**: Web-based access for desktop users

#### **Database Layer**
- **PostgreSQL**: Primary relational database
- **TimescaleDB**: Time-series data extension
- **Redis**: Caching and session management
- **Connection Pooling**: Optimized database connections

#### **Infrastructure**
- **Kubernetes**: Container orchestration
- **Docker**: Application containerization
- **Nginx**: Reverse proxy and load balancing
- **Prometheus**: Metrics collection and monitoring
- **Grafana**: Visualization and alerting
- **AlertManager**: Alert routing and management

### Network Architecture

#### **Production Network**
- **DMZ**: Public-facing services and load balancers
- **Application Tier**: Backend services and APIs
- **Database Tier**: Database servers and caching
- **PLC Network**: Industrial control systems
- **Management Network**: Administrative and monitoring systems

#### **Security Zones**
- **Public Zone**: Internet-facing services
- **DMZ Zone**: Web servers and load balancers
- **Application Zone**: Business logic services
- **Data Zone**: Database and storage systems
- **Control Zone**: PLC and industrial systems

## Installation and Configuration

### Prerequisites

#### **Hardware Requirements**
- **Minimum**: 8 CPU cores, 32GB RAM, 500GB SSD
- **Recommended**: 16 CPU cores, 64GB RAM, 1TB SSD
- **Production**: 32 CPU cores, 128GB RAM, 2TB SSD
- **Network**: Gigabit Ethernet with redundancy

#### **Software Requirements**
- **Operating System**: Ubuntu 20.04 LTS or CentOS 8
- **Docker**: Version 20.10+
- **Kubernetes**: Version 1.21+
- **PostgreSQL**: Version 13+
- **Redis**: Version 6.0+
- **Node.js**: Version 16+

### Installation Process

#### **1. System Preparation**
```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y curl wget git vim htop

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Kubernetes
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

#### **2. Database Setup**
```bash
# Install PostgreSQL
sudo apt install -y postgresql postgresql-contrib

# Create database and user
sudo -u postgres psql
CREATE DATABASE factory_telemetry;
CREATE USER ms5_user WITH PASSWORD 'secure_password';
GRANT ALL PRIVILEGES ON DATABASE factory_telemetry TO ms5_user;
\q

# Install TimescaleDB extension
sudo -u postgres psql -d factory_telemetry -c "CREATE EXTENSION IF NOT EXISTS timescaledb;"
```

#### **3. Application Deployment**
```bash
# Clone repository
git clone https://github.com/company/ms5-dashboard.git
cd ms5-dashboard

# Configure environment
cp env.example .env
# Edit .env with your configuration

# Build and deploy
docker-compose -f docker-compose.production.yml up -d

# Verify deployment
docker-compose ps
```

### Configuration Management

#### **Environment Variables**
```bash
# Database Configuration
DATABASE_URL=postgresql://ms5_user:password@localhost:5432/factory_telemetry
REDIS_URL=redis://localhost:6379

# Security Configuration
JWT_SECRET_KEY=your-super-secret-jwt-key
JWT_ALGORITHM=HS256
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=30
JWT_REFRESH_TOKEN_EXPIRE_DAYS=7

# API Configuration
API_V1_STR=/api/v1
PROJECT_NAME=MS5.0 Floor Dashboard
CORS_ORIGINS=["http://localhost:3000", "https://yourdomain.com"]

# Monitoring Configuration
PROMETHEUS_ENABLED=true
GRAFANA_ENABLED=true
LOG_LEVEL=INFO
```

#### **Kubernetes Configuration**
```yaml
# namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ms5-dashboard
  labels:
    name: ms5-dashboard

---
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ms5-config
  namespace: ms5-dashboard
data:
  DATABASE_URL: "postgresql://ms5_user:password@postgres:5432/factory_telemetry"
  REDIS_URL: "redis://redis:6379"
  JWT_SECRET_KEY: "your-super-secret-jwt-key"
```

## User Management

### User Roles and Permissions

#### **Role Hierarchy**
1. **Admin**: Full system access
2. **Production Manager**: Production management and oversight
3. **Shift Manager**: Shift-level management
4. **Engineer**: Technical operations and maintenance
5. **Operator**: Production line operations
6. **Maintenance**: Equipment maintenance
7. **Quality**: Quality control operations
8. **Viewer**: Read-only access

#### **Permission Matrix**
| Permission | Admin | Prod Mgr | Shift Mgr | Engineer | Operator | Maintenance | Quality | Viewer |
|------------|-------|----------|-----------|----------|----------|-------------|---------|-------|
| User Management | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| System Config | ✓ | ✗ | ✗ | ✓ | ✗ | ✗ | ✗ | ✗ |
| Production Control | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ |
| Job Management | ✓ | ✓ | ✓ | ✗ | ✓ | ✗ | ✗ | ✗ |
| Quality Control | ✓ | ✓ | ✓ | ✗ | ✓ | ✗ | ✓ | ✗ |
| Maintenance | ✓ | ✓ | ✓ | ✓ | ✗ | ✓ | ✗ | ✗ |
| Reports | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Analytics | ✓ | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ | ✓ |

### User Administration

#### **Creating Users**
```bash
# Using admin interface
curl -X POST "https://api.ms5.company.com/api/v1/admin/users" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "john.doe",
    "email": "john.doe@company.com",
    "password": "secure_password",
    "role": "operator",
    "first_name": "John",
    "last_name": "Doe",
    "employee_id": "EMP001",
    "department": "Production",
    "shift": "Day"
  }'
```

#### **Managing Permissions**
```bash
# Assign specific permissions
curl -X PUT "https://api.ms5.company.com/api/v1/admin/users/john.doe/permissions" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "permissions": [
      "production:read",
      "production:write",
      "andon:read",
      "andon:write"
    ]
  }'
```

#### **User Groups**
```bash
# Create user group
curl -X POST "https://api.ms5.company.com/api/v1/admin/groups" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Production Team A",
    "description": "Day shift production team",
    "permissions": [
      "production:read",
      "production:write",
      "andon:read"
    ]
  }'
```

### Authentication Configuration

#### **JWT Configuration**
```python
# backend/app/config.py
class SecuritySettings:
    JWT_SECRET_KEY: str = "your-super-secret-jwt-key"
    JWT_ALGORITHM: str = "HS256"
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    JWT_REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    PASSWORD_HASH_ALGORITHM: str = "bcrypt"
    PASSWORD_MIN_LENGTH: int = 8
    PASSWORD_REQUIRE_UPPERCASE: bool = True
    PASSWORD_REQUIRE_LOWERCASE: bool = True
    PASSWORD_REQUIRE_NUMBERS: bool = True
    PASSWORD_REQUIRE_SPECIAL_CHARS: bool = True
```

#### **Two-Factor Authentication**
```python
# Enable 2FA for specific roles
TWO_FACTOR_REQUIRED_ROLES = ["admin", "production_manager", "engineer"]
TWO_FACTOR_ISSUER = "MS5.0 Floor Dashboard"
TWO_FACTOR_WINDOW = 1  # Allow 1 time step tolerance
```

## Security Configuration

### Network Security

#### **Firewall Configuration**
```bash
# UFW firewall rules
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 5432/tcp  # PostgreSQL
sudo ufw allow 6379/tcp  # Redis
sudo ufw enable
```

#### **SSL/TLS Configuration**
```nginx
# nginx.conf
server {
    listen 443 ssl http2;
    server_name api.ms5.company.com;
    
    ssl_certificate /etc/ssl/certs/ms5.company.com.crt;
    ssl_certificate_key /etc/ssl/private/ms5.company.com.key;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;
    ssl_prefer_server_ciphers off;
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains";
}
```

### Application Security

#### **Input Validation**
```python
# backend/app/security/input_validation.py
from pydantic import BaseModel, validator
import re

class UserInputValidator:
    @staticmethod
    def validate_username(username: str) -> bool:
        pattern = r'^[a-zA-Z0-9._-]{3,20}$'
        return bool(re.match(pattern, username))
    
    @staticmethod
    def validate_password(password: str) -> bool:
        if len(password) < 8:
            return False
        if not re.search(r'[A-Z]', password):
            return False
        if not re.search(r'[a-z]', password):
            return False
        if not re.search(r'\d', password):
            return False
        if not re.search(r'[!@#$%^&*(),.?":{}|<>]', password):
            return False
        return True
```

#### **SQL Injection Prevention**
```python
# backend/app/security/sql_injection_prevention.py
from sqlalchemy import text
import re

class SQLInjectionPrevention:
    @staticmethod
    def sanitize_input(input_string: str) -> str:
        # Remove potentially dangerous characters
        dangerous_chars = [';', '--', '/*', '*/', 'xp_', 'sp_']
        for char in dangerous_chars:
            input_string = input_string.replace(char, '')
        return input_string.strip()
    
    @staticmethod
    def validate_sql_query(query: str) -> bool:
        # Check for suspicious patterns
        suspicious_patterns = [
            r'union\s+select',
            r'drop\s+table',
            r'delete\s+from',
            r'insert\s+into',
            r'update\s+set'
        ]
        
        for pattern in suspicious_patterns:
            if re.search(pattern, query, re.IGNORECASE):
                return False
        return True
```

### Data Protection

#### **Encryption Configuration**
```python
# backend/app/security/encryption.py
from cryptography.fernet import Fernet
import base64
import os

class DataEncryption:
    def __init__(self):
        self.key = os.getenv('ENCRYPTION_KEY', Fernet.generate_key())
        self.cipher = Fernet(self.key)
    
    def encrypt_data(self, data: str) -> str:
        encrypted_data = self.cipher.encrypt(data.encode())
        return base64.b64encode(encrypted_data).decode()
    
    def decrypt_data(self, encrypted_data: str) -> str:
        decoded_data = base64.b64decode(encrypted_data.encode())
        decrypted_data = self.cipher.decrypt(decoded_data)
        return decrypted_data.decode()
```

#### **Audit Logging**
```python
# backend/app/security/audit_logging.py
import structlog
from datetime import datetime
from typing import Dict, Any

class AuditLogger:
    def __init__(self):
        self.logger = structlog.get_logger("audit")
    
    def log_user_action(self, user_id: str, action: str, details: Dict[str, Any]):
        self.logger.info(
            "User action logged",
            user_id=user_id,
            action=action,
            details=details,
            timestamp=datetime.utcnow().isoformat(),
            ip_address=self.get_client_ip(),
            user_agent=self.get_user_agent()
        )
    
    def log_system_event(self, event_type: str, details: Dict[str, Any]):
        self.logger.info(
            "System event logged",
            event_type=event_type,
            details=details,
            timestamp=datetime.utcnow().isoformat()
        )
```

## System Monitoring

### Monitoring Stack

#### **Prometheus Configuration**
```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "alert_rules.yml"

scrape_configs:
  - job_name: 'ms5-backend'
    static_configs:
      - targets: ['backend:8000']
    metrics_path: '/metrics'
    scrape_interval: 5s

  - job_name: 'ms5-database'
    static_configs:
      - targets: ['postgres:5432']
    scrape_interval: 30s

  - job_name: 'ms5-redis'
    static_configs:
      - targets: ['redis:6379']
    scrape_interval: 30s

  - job_name: 'ms5-frontend'
    static_configs:
      - targets: ['frontend:3000']
    scrape_interval: 30s
```

#### **Grafana Dashboards**
```json
{
  "dashboard": {
    "title": "MS5.0 System Overview",
    "panels": [
      {
        "title": "System Health",
        "type": "stat",
        "targets": [
          {
            "expr": "up{job=\"ms5-backend\"}",
            "legendFormat": "Backend Status"
          }
        ]
      },
      {
        "title": "Response Time",
        "type": "graph",
        "targets": [
          {
            "expr": "http_request_duration_seconds{job=\"ms5-backend\"}",
            "legendFormat": "API Response Time"
          }
        ]
      }
    ]
  }
}
```

### Alerting Configuration

#### **Alert Rules**
```yaml
# alert_rules.yml
groups:
  - name: ms5-system
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value }} errors per second"

      - alert: DatabaseConnectionFailure
        expr: up{job="ms5-database"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Database connection failed"
          description: "Database is not responding"

      - alert: HighMemoryUsage
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes > 0.9
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage"
          description: "Memory usage is {{ $value | humanizePercentage }}"
```

#### **AlertManager Configuration**
```yaml
# alertmanager.yml
global:
  smtp_smarthost: 'smtp.company.com:587'
  smtp_from: 'alerts@ms5.company.com'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'

receivers:
  - name: 'web.hook'
    webhook_configs:
      - url: 'http://webhook.company.com/alerts'
        send_resolved: true

  - name: 'email'
    email_configs:
      - to: 'admin@company.com'
        subject: 'MS5.0 Alert: {{ .GroupLabels.alertname }}'
        body: |
          {{ range .Alerts }}
          Alert: {{ .Annotations.summary }}
          Description: {{ .Annotations.description }}
          {{ end }}
```

### Performance Monitoring

#### **Key Metrics**
- **Response Time**: API endpoint response times
- **Throughput**: Requests per second
- **Error Rate**: Percentage of failed requests
- **Resource Usage**: CPU, memory, disk, network
- **Database Performance**: Query times, connection pool usage
- **Cache Hit Rate**: Redis cache effectiveness

#### **Custom Metrics**
```python
# backend/app/monitoring/metrics.py
from prometheus_client import Counter, Histogram, Gauge
import time

# Request metrics
REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP requests', ['method', 'endpoint', 'status'])
REQUEST_DURATION = Histogram('http_request_duration_seconds', 'HTTP request duration')

# Business metrics
PRODUCTION_COUNT = Counter('production_parts_total', 'Total parts produced', ['line_id'])
OEE_SCORE = Gauge('oee_score', 'Current OEE score', ['line_id'])
ANDON_EVENTS = Counter('andon_events_total', 'Total Andon events', ['priority', 'status'])

def track_request(func):
    def wrapper(*args, **kwargs):
        start_time = time.time()
        try:
            result = func(*args, **kwargs)
            REQUEST_COUNT.labels(method='GET', endpoint=func.__name__, status='200').inc()
            return result
        except Exception as e:
            REQUEST_COUNT.labels(method='GET', endpoint=func.__name__, status='500').inc()
            raise
        finally:
            REQUEST_DURATION.observe(time.time() - start_time)
    return wrapper
```

## Backup and Recovery

### Backup Strategy

#### **Database Backup**
```bash
#!/bin/bash
# backup_database.sh

BACKUP_DIR="/backups/database"
DATE=$(date +%Y%m%d_%H%M%S)
DB_NAME="factory_telemetry"

# Create backup directory
mkdir -p $BACKUP_DIR

# Full database backup
pg_dump -h localhost -U ms5_user -d $DB_NAME \
  --format=custom \
  --compress=9 \
  --file="$BACKUP_DIR/full_backup_$DATE.dump"

# Schema-only backup
pg_dump -h localhost -U ms5_user -d $DB_NAME \
  --schema-only \
  --format=custom \
  --file="$BACKUP_DIR/schema_backup_$DATE.dump"

# Data-only backup
pg_dump -h localhost -U ms5_user -d $DB_NAME \
  --data-only \
  --format=custom \
  --file="$BACKUP_DIR/data_backup_$DATE.dump"

# Cleanup old backups (keep last 30 days)
find $BACKUP_DIR -name "*.dump" -mtime +30 -delete

echo "Backup completed: $BACKUP_DIR/full_backup_$DATE.dump"
```

#### **Application Backup**
```bash
#!/bin/bash
# backup_application.sh

BACKUP_DIR="/backups/application"
DATE=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup configuration files
tar -czf "$BACKUP_DIR/config_backup_$DATE.tar.gz" \
  /etc/nginx/ \
  /etc/ssl/ \
  /opt/ms5-dashboard/.env \
  /opt/ms5-dashboard/docker-compose.yml

# Backup application data
tar -czf "$BACKUP_DIR/app_data_backup_$DATE.tar.gz" \
  /opt/ms5-dashboard/uploads/ \
  /opt/ms5-dashboard/logs/ \
  /opt/ms5-dashboard/reports/

# Cleanup old backups
find $BACKUP_DIR -name "*.tar.gz" -mtime +30 -delete

echo "Application backup completed: $BACKUP_DIR/config_backup_$DATE.tar.gz"
```

### Recovery Procedures

#### **Database Recovery**
```bash
#!/bin/bash
# restore_database.sh

BACKUP_FILE=$1
DB_NAME="factory_telemetry"

if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 <backup_file>"
    exit 1
fi

# Stop application services
docker-compose -f docker-compose.production.yml stop backend

# Drop existing database
dropdb -h localhost -U ms5_user $DB_NAME

# Create new database
createdb -h localhost -U ms5_user $DB_NAME

# Restore from backup
pg_restore -h localhost -U ms5_user -d $DB_NAME \
  --clean \
  --if-exists \
  --verbose \
  $BACKUP_FILE

# Restart application services
docker-compose -f docker-compose.production.yml start backend

echo "Database recovery completed"
```

#### **Application Recovery**
```bash
#!/bin/bash
# restore_application.sh

BACKUP_FILE=$1

if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 <backup_file>"
    exit 1
fi

# Stop application services
docker-compose -f docker-compose.production.yml stop

# Extract backup
tar -xzf $BACKUP_FILE -C /

# Restart application services
docker-compose -f docker-compose.production.yml up -d

echo "Application recovery completed"
```

### Automated Backup

#### **Cron Job Configuration**
```bash
# Add to crontab
# Database backup every 6 hours
0 */6 * * * /opt/ms5-dashboard/scripts/backup_database.sh

# Application backup daily at 2 AM
0 2 * * * /opt/ms5-dashboard/scripts/backup_application.sh

# Cleanup old backups weekly
0 3 * * 0 /opt/ms5-dashboard/scripts/cleanup_backups.sh
```

#### **Backup Verification**
```bash
#!/bin/bash
# verify_backup.sh

BACKUP_FILE=$1

if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 <backup_file>"
    exit 1
fi

# Verify backup file integrity
if pg_restore --list $BACKUP_FILE > /dev/null 2>&1; then
    echo "Backup file is valid"
    exit 0
else
    echo "Backup file is corrupted"
    exit 1
fi
```

## Performance Tuning

### Database Optimization

#### **PostgreSQL Configuration**
```sql
-- postgresql.conf optimizations
shared_buffers = 256MB
effective_cache_size = 1GB
work_mem = 4MB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200

-- Connection settings
max_connections = 100
shared_preload_libraries = 'timescaledb'
```

#### **Index Optimization**
```sql
-- Create indexes for frequently queried columns
CREATE INDEX CONCURRENTLY idx_production_lines_status 
ON production_lines(status);

CREATE INDEX CONCURRENTLY idx_andon_events_created_at 
ON andon_events(created_at);

CREATE INDEX CONCURRENTLY idx_oee_calculations_line_id_time 
ON oee_calculations(line_id, calculation_time);

-- TimescaleDB hypertables
SELECT create_hypertable('oee_calculations', 'calculation_time');
SELECT create_hypertable('production_data', 'timestamp');
```

### Application Optimization

#### **Connection Pooling**
```python
# backend/app/database.py
from sqlalchemy import create_engine
from sqlalchemy.pool import QueuePool

engine = create_engine(
    DATABASE_URL,
    poolclass=QueuePool,
    pool_size=20,
    max_overflow=30,
    pool_pre_ping=True,
    pool_recycle=3600
)
```

#### **Caching Strategy**
```python
# backend/app/services/cache_service.py
import redis
from functools import wraps
import json

class CacheService:
    def __init__(self):
        self.redis_client = redis.Redis(
            host='localhost',
            port=6379,
            db=0,
            decode_responses=True
        )
    
    def cache_result(self, ttl=300):
        def decorator(func):
            @wraps(func)
            def wrapper(*args, **kwargs):
                cache_key = f"{func.__name__}:{hash(str(args) + str(kwargs))}"
                
                # Try to get from cache
                cached_result = self.redis_client.get(cache_key)
                if cached_result:
                    return json.loads(cached_result)
                
                # Execute function and cache result
                result = func(*args, **kwargs)
                self.redis_client.setex(
                    cache_key, 
                    ttl, 
                    json.dumps(result, default=str)
                )
                return result
            return wrapper
        return decorator
```

### System Resource Optimization

#### **Memory Management**
```bash
# /etc/sysctl.conf optimizations
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.overcommit_memory = 1
```

#### **File System Optimization**
```bash
# Mount options for better performance
/dev/sda1 / ext4 defaults,noatime,nodiratime 0 1
/dev/sda2 /var ext4 defaults,noatime,nodiratime 0 2
```

## Troubleshooting

### Common Issues

#### **Database Connection Issues**
```bash
# Check PostgreSQL status
sudo systemctl status postgresql

# Check connection limits
psql -U ms5_user -d factory_telemetry -c "SELECT * FROM pg_stat_activity;"

# Check database size
psql -U ms5_user -d factory_telemetry -c "SELECT pg_size_pretty(pg_database_size('factory_telemetry'));"

# Check slow queries
psql -U ms5_user -d factory_telemetry -c "SELECT query, mean_time, calls FROM pg_stat_statements ORDER BY mean_time DESC LIMIT 10;"
```

#### **Application Performance Issues**
```bash
# Check application logs
docker-compose -f docker-compose.production.yml logs backend

# Check resource usage
docker stats

# Check network connectivity
curl -I http://localhost:8000/health

# Check API response times
curl -w "@curl-format.txt" -o /dev/null -s http://localhost:8000/api/v1/health
```

#### **WebSocket Connection Issues**
```bash
# Check WebSocket endpoint
curl -i -N -H "Connection: Upgrade" -H "Upgrade: websocket" -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==" http://localhost:8000/ws/

# Check WebSocket logs
docker-compose -f docker-compose.production.yml logs backend | grep websocket
```

### Diagnostic Tools

#### **System Health Check**
```bash
#!/bin/bash
# health_check.sh

echo "=== MS5.0 System Health Check ==="
echo "Date: $(date)"
echo

# Check system resources
echo "=== System Resources ==="
echo "CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
echo "Memory Usage: $(free | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100.0}')"
echo "Disk Usage: $(df -h / | awk 'NR==2{printf "%s", $5}')"
echo

# Check services
echo "=== Service Status ==="
docker-compose -f docker-compose.production.yml ps
echo

# Check database
echo "=== Database Status ==="
psql -U ms5_user -d factory_telemetry -c "SELECT version();" 2>/dev/null || echo "Database connection failed"
echo

# Check API
echo "=== API Status ==="
curl -s http://localhost:8000/health | jq . || echo "API health check failed"
echo

# Check Redis
echo "=== Redis Status ==="
redis-cli ping 2>/dev/null || echo "Redis connection failed"
echo
```

#### **Performance Analysis**
```bash
#!/bin/bash
# performance_analysis.sh

echo "=== Performance Analysis ==="
echo "Date: $(date)"
echo

# Database performance
echo "=== Database Performance ==="
psql -U ms5_user -d factory_telemetry -c "
SELECT 
    schemaname,
    tablename,
    n_tup_ins as inserts,
    n_tup_upd as updates,
    n_tup_del as deletes,
    n_live_tup as live_tuples,
    n_dead_tup as dead_tuples
FROM pg_stat_user_tables 
ORDER BY n_live_tup DESC 
LIMIT 10;"
echo

# Application metrics
echo "=== Application Metrics ==="
curl -s http://localhost:8000/metrics | grep -E "(http_requests_total|http_request_duration_seconds)" | head -20
echo

# System load
echo "=== System Load ==="
uptime
echo
```

## Maintenance Procedures

### Regular Maintenance Tasks

#### **Daily Tasks**
```bash
#!/bin/bash
# daily_maintenance.sh

echo "=== Daily Maintenance - $(date) ==="

# Check system health
./health_check.sh

# Clean up old logs
find /var/log -name "*.log" -mtime +7 -delete

# Clean up old backups
find /backups -name "*.dump" -mtime +30 -delete

# Update system packages
apt update && apt upgrade -y

# Restart services if needed
docker-compose -f docker-compose.production.yml restart

echo "Daily maintenance completed"
```

#### **Weekly Tasks**
```bash
#!/bin/bash
# weekly_maintenance.sh

echo "=== Weekly Maintenance - $(date) ==="

# Database maintenance
psql -U ms5_user -d factory_telemetry -c "VACUUM ANALYZE;"

# Clean up old data
psql -U ms5_user -d factory_telemetry -c "
DELETE FROM oee_calculations 
WHERE calculation_time < NOW() - INTERVAL '90 days';"

# Update statistics
psql -U ms5_user -d factory_telemetry -c "ANALYZE;"

# Check disk space
df -h

# Check for security updates
apt list --upgradable

echo "Weekly maintenance completed"
```

#### **Monthly Tasks**
```bash
#!/bin/bash
# monthly_maintenance.sh

echo "=== Monthly Maintenance - $(date) ==="

# Full system backup
./backup_database.sh
./backup_application.sh

# Security audit
./security_audit.sh

# Performance review
./performance_analysis.sh

# Update documentation
./update_documentation.sh

echo "Monthly maintenance completed"
```

### Security Maintenance

#### **Security Audit**
```bash
#!/bin/bash
# security_audit.sh

echo "=== Security Audit - $(date) ==="

# Check for security updates
apt list --upgradable | grep -i security

# Check failed login attempts
grep "Failed password" /var/log/auth.log | tail -20

# Check for suspicious activity
grep -i "error\|warning\|critical" /var/log/syslog | tail -20

# Check SSL certificates
openssl x509 -in /etc/ssl/certs/ms5.company.com.crt -text -noout | grep -E "Not Before|Not After"

# Check firewall status
ufw status

echo "Security audit completed"
```

#### **User Access Review**
```bash
#!/bin/bash
# user_access_review.sh

echo "=== User Access Review - $(date) ==="

# List all users
psql -U ms5_user -d factory_telemetry -c "
SELECT 
    username,
    email,
    role,
    is_active,
    last_login,
    created_at
FROM users 
ORDER BY last_login DESC;"

# Check inactive users
psql -U ms5_user -d factory_telemetry -c "
SELECT username, last_login 
FROM users 
WHERE last_login < NOW() - INTERVAL '90 days';"

# Check admin users
psql -U ms5_user -d factory_telemetry -c "
SELECT username, email, created_at 
FROM users 
WHERE role = 'admin';"

echo "User access review completed"
```

## Disaster Recovery

### Disaster Recovery Plan

#### **Recovery Time Objectives (RTO)**
- **Critical Systems**: 4 hours
- **Production Systems**: 8 hours
- **Support Systems**: 24 hours
- **Development Systems**: 48 hours

#### **Recovery Point Objectives (RPO)**
- **Database**: 15 minutes
- **Application Data**: 1 hour
- **Configuration**: 4 hours
- **Documentation**: 24 hours

### Recovery Procedures

#### **Full System Recovery**
```bash
#!/bin/bash
# full_system_recovery.sh

echo "=== Full System Recovery - $(date) ==="

# 1. Provision new infrastructure
echo "Provisioning new infrastructure..."
# (Infrastructure provisioning scripts)

# 2. Restore database
echo "Restoring database..."
./restore_database.sh /backups/database/latest_backup.dump

# 3. Restore application
echo "Restoring application..."
./restore_application.sh /backups/application/latest_backup.tar.gz

# 4. Configure services
echo "Configuring services..."
docker-compose -f docker-compose.production.yml up -d

# 5. Verify recovery
echo "Verifying recovery..."
./health_check.sh

echo "Full system recovery completed"
```

#### **Partial Recovery**
```bash
#!/bin/bash
# partial_recovery.sh

COMPONENT=$1

case $COMPONENT in
    "database")
        echo "Recovering database..."
        ./restore_database.sh /backups/database/latest_backup.dump
        ;;
    "application")
        echo "Recovering application..."
        ./restore_application.sh /backups/application/latest_backup.tar.gz
        ;;
    "configuration")
        echo "Recovering configuration..."
        cp /backups/config/latest_config.tar.gz /tmp/
        tar -xzf /tmp/latest_config.tar.gz -C /
        ;;
    *)
        echo "Usage: $0 {database|application|configuration}"
        exit 1
        ;;
esac

echo "Partial recovery completed"
```

### Business Continuity

#### **High Availability Setup**
```yaml
# kubernetes/high-availability.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ms5-backend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ms5-backend
  template:
    metadata:
      labels:
        app: ms5-backend
    spec:
      containers:
      - name: backend
        image: ms5-backend:latest
        ports:
        - containerPort: 8000
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 5
```

#### **Load Balancing Configuration**
```nginx
# nginx/load-balancer.conf
upstream backend {
    least_conn;
    server backend1:8000 weight=3;
    server backend2:8000 weight=3;
    server backend3:8000 weight=3;
}

server {
    listen 80;
    server_name api.ms5.company.com;
    
    location / {
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

---

## Maintenance Procedures & Schedules

### Preventive Maintenance

#### Daily Maintenance Tasks
- **System Health Check**: Verify all services are running
- **Database Performance**: Check database performance metrics
- **Log Analysis**: Review system logs for errors or warnings
- **Backup Verification**: Verify backup completion and integrity
- **Security Monitoring**: Check security logs and alerts
- **Resource Monitoring**: Monitor CPU, memory, and disk usage

#### Weekly Maintenance Tasks
- **Database Optimization**: Run database maintenance scripts
- **Log Rotation**: Rotate and archive old log files
- **Security Updates**: Check for and apply security updates
- **Performance Analysis**: Analyze system performance trends
- **Capacity Planning**: Review capacity utilization
- **Documentation Updates**: Update system documentation

#### Monthly Maintenance Tasks
- **Full System Backup**: Create complete system backup
- **Security Audit**: Conduct security audit and review
- **Performance Tuning**: Optimize system performance
- **Disaster Recovery Test**: Test disaster recovery procedures
- **User Account Review**: Review and audit user accounts
- **Compliance Check**: Verify compliance with regulations

#### Quarterly Maintenance Tasks
- **System Upgrade Planning**: Plan system upgrades and updates
- **Capacity Assessment**: Assess system capacity requirements
- **Security Penetration Testing**: Conduct security testing
- **Business Continuity Review**: Review business continuity plans
- **Training Updates**: Update training materials and procedures
- **Vendor Review**: Review vendor contracts and support

### Maintenance Schedules

#### Production Environment
- **Daily**: 6:00 AM - 7:00 AM (Low activity period)
- **Weekly**: Sunday 2:00 AM - 4:00 AM (Maintenance window)
- **Monthly**: First Sunday 1:00 AM - 6:00 AM (Extended maintenance)
- **Quarterly**: Scheduled during planned downtime

#### Staging Environment
- **Daily**: 8:00 PM - 9:00 PM (After business hours)
- **Weekly**: Saturday 10:00 PM - 12:00 AM (Weekend maintenance)
- **Monthly**: Third Saturday 8:00 PM - 2:00 AM (Extended maintenance)

#### Development Environment
- **Daily**: 9:00 PM - 10:00 PM (After development hours)
- **Weekly**: Friday 6:00 PM - 8:00 PM (End of week maintenance)
- **Monthly**: Last Friday 5:00 PM - 9:00 PM (Extended maintenance)

### Database Maintenance

#### Daily Database Tasks
```sql
-- Daily maintenance script
-- Check database health
SELECT 
    schemaname,
    tablename,
    n_tup_ins,
    n_tup_upd,
    n_tup_del,
    n_live_tup,
    n_dead_tup
FROM pg_stat_user_tables
WHERE n_dead_tup > 1000;

-- Update table statistics
ANALYZE;

-- Check for long-running queries
SELECT 
    pid,
    now() - pg_stat_activity.query_start AS duration,
    query,
    state
FROM pg_stat_activity
WHERE (now() - pg_stat_activity.query_start) > interval '5 minutes';
```

#### Weekly Database Tasks
```sql
-- Weekly maintenance script
-- Vacuum analyze all tables
VACUUM ANALYZE;

-- Check database size
SELECT 
    pg_database.datname,
    pg_size_pretty(pg_database_size(pg_database.datname)) AS size
FROM pg_database
ORDER BY pg_database_size(pg_database.datname) DESC;

-- Check index usage
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_tup_read DESC;
```

#### Monthly Database Tasks
```sql
-- Monthly maintenance script
-- Full vacuum (if needed)
VACUUM FULL;

-- Reindex all tables
REINDEX DATABASE ms5_floor_dashboard;

-- Update table statistics
ANALYZE;

-- Check for unused indexes
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
WHERE idx_tup_read = 0;
```

### Application Maintenance

#### Application Updates
```bash
#!/bin/bash
# application_update.sh

echo "Starting application update..."

# 1. Backup current application
echo "Creating backup..."
tar -czf /backups/app_$(date +%Y%m%d_%H%M%S).tar.gz /app

# 2. Stop application services
echo "Stopping services..."
docker-compose down

# 3. Pull latest code
echo "Pulling latest code..."
git pull origin main

# 4. Build new application
echo "Building application..."
docker-compose build

# 5. Run database migrations
echo "Running migrations..."
docker-compose run --rm backend alembic upgrade head

# 6. Start services
echo "Starting services..."
docker-compose up -d

# 7. Verify deployment
echo "Verifying deployment..."
./health_check.sh

echo "Application update completed"
```

#### Configuration Updates
```bash
#!/bin/bash
# config_update.sh

CONFIG_FILE=$1

if [ -z "$CONFIG_FILE" ]; then
    echo "Usage: $0 <config_file>"
    exit 1
fi

echo "Updating configuration..."

# 1. Backup current config
cp $CONFIG_FILE $CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)

# 2. Validate new config
echo "Validating configuration..."
python -c "import yaml; yaml.safe_load(open('$CONFIG_FILE'))"

# 3. Apply configuration
echo "Applying configuration..."
docker-compose down
docker-compose up -d

# 4. Verify configuration
echo "Verifying configuration..."
./health_check.sh

echo "Configuration update completed"
```

### System Maintenance

#### Operating System Updates
```bash
#!/bin/bash
# os_update.sh

echo "Starting OS update..."

# 1. Check for updates
echo "Checking for updates..."
apt update
apt list --upgradable

# 2. Backup system
echo "Creating system backup..."
tar -czf /backups/system_$(date +%Y%m%d_%H%M%S).tar.gz /etc /var/log

# 3. Apply security updates
echo "Applying security updates..."
apt upgrade -y

# 4. Clean up
echo "Cleaning up..."
apt autoremove -y
apt autoclean

# 5. Reboot if required
if [ -f /var/run/reboot-required ]; then
    echo "Reboot required. Scheduling reboot..."
    shutdown -r +5 "System update completed. Rebooting in 5 minutes."
fi

echo "OS update completed"
```

#### Security Updates
```bash
#!/bin/bash
# security_update.sh

echo "Starting security update..."

# 1. Check for security updates
echo "Checking for security updates..."
apt update
apt list --upgradable | grep -i security

# 2. Apply security updates
echo "Applying security updates..."
apt upgrade -y --only-upgrade-security

# 3. Update security tools
echo "Updating security tools..."
apt update && apt upgrade -y fail2ban ufw

# 4. Restart security services
echo "Restarting security services..."
systemctl restart fail2ban
systemctl restart ufw

echo "Security update completed"
```

### Monitoring Maintenance

#### Monitoring System Updates
```bash
#!/bin/bash
# monitoring_update.sh

echo "Starting monitoring system update..."

# 1. Backup monitoring configuration
echo "Backing up monitoring configuration..."
tar -czf /backups/monitoring_$(date +%Y%m%d_%H%M%S).tar.gz /etc/prometheus /etc/grafana

# 2. Update Prometheus
echo "Updating Prometheus..."
docker pull prom/prometheus:latest
docker-compose down prometheus
docker-compose up -d prometheus

# 3. Update Grafana
echo "Updating Grafana..."
docker pull grafana/grafana:latest
docker-compose down grafana
docker-compose up -d grafana

# 4. Update AlertManager
echo "Updating AlertManager..."
docker pull prom/alertmanager:latest
docker-compose down alertmanager
docker-compose up -d alertmanager

# 5. Verify monitoring
echo "Verifying monitoring..."
./monitoring_health_check.sh

echo "Monitoring update completed"
```

#### Log Management
```bash
#!/bin/bash
# log_management.sh

echo "Starting log management..."

# 1. Rotate application logs
echo "Rotating application logs..."
logrotate -f /etc/logrotate.d/ms5-app

# 2. Archive old logs
echo "Archiving old logs..."
find /var/log -name "*.log.*" -mtime +30 -exec gzip {} \;
find /var/log -name "*.log.*.gz" -mtime +90 -delete

# 3. Clean up temporary files
echo "Cleaning up temporary files..."
find /tmp -type f -mtime +7 -delete
find /var/tmp -type f -mtime +7 -delete

# 4. Update log retention policies
echo "Updating log retention policies..."
# Keep logs for 30 days, archive for 90 days, delete after 1 year

echo "Log management completed"
```

### Maintenance Documentation

#### Maintenance Checklist
- [ ] **Pre-Maintenance**
  - [ ] Notify users of maintenance window
  - [ ] Create system backup
  - [ ] Verify maintenance procedures
  - [ ] Prepare rollback plan

- [ ] **During Maintenance**
  - [ ] Follow maintenance procedures
  - [ ] Monitor system status
  - [ ] Document any issues
  - [ ] Test functionality

- [ ] **Post-Maintenance**
  - [ ] Verify system functionality
  - [ ] Update documentation
  - [ ] Notify users of completion
  - [ ] Schedule next maintenance

#### Maintenance Log Template
```
Maintenance Log Entry
====================
Date: [DATE]
Time: [START_TIME] - [END_TIME]
Type: [DAILY/WEEKLY/MONTHLY/QUARTERLY]
Performed By: [ADMINISTRATOR_NAME]

Tasks Completed:
- [TASK_1]
- [TASK_2]
- [TASK_3]

Issues Encountered:
- [ISSUE_1]: [RESOLUTION]
- [ISSUE_2]: [RESOLUTION]

System Status:
- Database: [STATUS]
- Application: [STATUS]
- Monitoring: [STATUS]
- Security: [STATUS]

Next Maintenance: [DATE]
Notes: [ADDITIONAL_NOTES]
```

---

*This administrator documentation is updated regularly. For the latest version, please check the system documentation portal.*
