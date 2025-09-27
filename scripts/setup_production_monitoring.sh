#!/bin/bash

# MS5.0 Floor Dashboard - Production Monitoring Setup Script
# This script sets up comprehensive monitoring and alerting for production deployment

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${LOG_DIR}/monitoring_setup_${TIMESTAMP}.log"

# Environment variables
ENVIRONMENT=${ENVIRONMENT:-production}
MONITORING_TYPE=${MONITORING_TYPE:-full}  # full, prometheus, grafana, alerts, dashboards
GRAFANA_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:-admin123}
PROMETHEUS_RETENTION_DAYS=${PROMETHEUS_RETENTION_DAYS:-30}
ALERT_EMAIL_RECIPIENTS=${ALERT_EMAIL_RECIPIENTS:-admin@ms5dashboard.com}
ALERT_SLACK_WEBHOOK=${ALERT_SLACK_WEBHOOK:-}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${PURPLE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_monitoring() {
    echo -e "${CYAN}[MONITORING]${NC} $1" | tee -a "$LOG_FILE"
}

# Create directories
mkdir -p "$LOG_DIR"

log "Starting MS5.0 Production Monitoring Setup - Environment: $ENVIRONMENT, Type: $MONITORING_TYPE"

# Change to script directory
cd "$SCRIPT_DIR"

# Function to setup Prometheus configuration
setup_prometheus() {
    log_monitoring "Setting up Prometheus configuration..."
    
    # Create Prometheus configuration
    cat > prometheus.production.yml << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'ms5-production'
    environment: 'production'

rule_files:
  - "alert_rules.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

scrape_configs:
  # Prometheus itself
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # MS5.0 Backend API
  - job_name: 'ms5-backend'
    static_configs:
      - targets: ['backend:8000']
    metrics_path: '/metrics'
    scrape_interval: 5s
    scrape_timeout: 5s

  # PostgreSQL Database
  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres_exporter:9187']

  # Redis Cache
  - job_name: 'redis'
    static_configs:
      - targets: ['redis_exporter:9121']

  # Node Exporter (System metrics)
  - job_name: 'node'
    static_configs:
      - targets: ['node_exporter:9100']

  # Nginx
  - job_name: 'nginx'
    static_configs:
      - targets: ['nginx:9113']

  # Grafana
  - job_name: 'grafana'
    static_configs:
      - targets: ['grafana:3000']

  # Celery Workers
  - job_name: 'celery'
    static_configs:
      - targets: ['flower:5555']
    metrics_path: '/metrics'
    scrape_interval: 10s

  # AlertManager
  - job_name: 'alertmanager'
    static_configs:
      - targets: ['alertmanager:9093']

  # MinIO
  - job_name: 'minio'
    static_configs:
      - targets: ['minio:9000']
    metrics_path: '/minio/v2/metrics/cluster'

# Recording rules for performance optimization
recording_rules:
  - name: "ms5.rules"
    rules:
      - record: "ms5:api_request_rate"
        expr: "rate(http_requests_total[5m])"
      
      - record: "ms5:api_response_time_p95"
        expr: "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))"
      
      - record: "ms5:database_connections_active"
        expr: "pg_stat_activity_count"
      
      - record: "ms5:redis_memory_usage_percent"
        expr: "(redis_memory_used_bytes / redis_memory_max_bytes) * 100"
      
      - record: "ms5:system_cpu_usage_percent"
        expr: "100 - (avg by(instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)"
      
      - record: "ms5:system_memory_usage_percent"
        expr: "(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100"
      
      - record: "ms5:disk_usage_percent"
        expr: "(1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) * 100"

# Remote write configuration for long-term storage (optional)
# remote_write:
#   - url: "https://your-remote-storage.com/api/v1/write"
#     basic_auth:
#       username: "your-username"
#       password: "your-password"
EOF

    log_success "Prometheus configuration created"
}

# Function to setup alert rules
setup_alert_rules() {
    log_monitoring "Setting up alert rules..."
    
    # Create comprehensive alert rules
    cat > alert_rules.yml << EOF
groups:
  - name: ms5.system
    rules:
      - alert: HighCPUUsage
        expr: ms5:system_cpu_usage_percent > 80
        for: 5m
        labels:
          severity: warning
          service: system
        annotations:
          summary: "High CPU usage detected"
          description: "CPU usage is above 80% for more than 5 minutes"
          runbook_url: "https://docs.ms5dashboard.com/runbooks/high-cpu-usage"

      - alert: HighMemoryUsage
        expr: ms5:system_memory_usage_percent > 85
        for: 5m
        labels:
          severity: warning
          service: system
        annotations:
          summary: "High memory usage detected"
          description: "Memory usage is above 85% for more than 5 minutes"
          runbook_url: "https://docs.ms5dashboard.com/runbooks/high-memory-usage"

      - alert: HighDiskUsage
        expr: ms5:disk_usage_percent > 90
        for: 5m
        labels:
          severity: critical
          service: system
        annotations:
          summary: "High disk usage detected"
          description: "Disk usage is above 90% for more than 5 minutes"
          runbook_url: "https://docs.ms5dashboard.com/runbooks/high-disk-usage"

      - alert: SystemDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
          service: system
        annotations:
          summary: "System is down"
          description: "{{ \$labels.instance }} is down"
          runbook_url: "https://docs.ms5dashboard.com/runbooks/system-down"

  - name: ms5.api
    rules:
      - alert: HighAPIErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) > 0.05
        for: 5m
        labels:
          severity: warning
          service: api
        annotations:
          summary: "High API error rate"
          description: "API error rate is above 5% for more than 5 minutes"
          runbook_url: "https://docs.ms5dashboard.com/runbooks/high-api-error-rate"

      - alert: SlowAPIResponse
        expr: ms5:api_response_time_p95 > 2
        for: 5m
        labels:
          severity: warning
          service: api
        annotations:
          summary: "Slow API response times"
          description: "95th percentile response time is above 2 seconds"
          runbook_url: "https://docs.ms5dashboard.com/runbooks/slow-api-response"

      - alert: APIUnavailable
        expr: up{job="ms5-backend"} == 0
        for: 1m
        labels:
          severity: critical
          service: api
        annotations:
          summary: "API is unavailable"
          description: "MS5.0 Backend API is not responding"
          runbook_url: "https://docs.ms5dashboard.com/runbooks/api-unavailable"

  - name: ms5.database
    rules:
      - alert: DatabaseConnectionsHigh
        expr: ms5:database_connections_active > 80
        for: 5m
        labels:
          severity: warning
          service: database
        annotations:
          summary: "High database connection count"
          description: "Database has more than 80 active connections"
          runbook_url: "https://docs.ms5dashboard.com/runbooks/high-db-connections"

      - alert: DatabaseDown
        expr: up{job="postgres"} == 0
        for: 1m
        labels:
          severity: critical
          service: database
        annotations:
          summary: "Database is down"
          description: "PostgreSQL database is not responding"
          runbook_url: "https://docs.ms5dashboard.com/runbooks/database-down"

      - alert: SlowDatabaseQueries
        expr: rate(pg_stat_activity_max_tx_duration[5m]) > 10
        for: 5m
        labels:
          severity: warning
          service: database
        annotations:
          summary: "Slow database queries detected"
          description: "Database queries are taking longer than 10 seconds"
          runbook_url: "https://docs.ms5dashboard.com/runbooks/slow-db-queries"

  - name: ms5.redis
    rules:
      - alert: RedisMemoryUsageHigh
        expr: ms5:redis_memory_usage_percent > 80
        for: 5m
        labels:
          severity: warning
          service: redis
        annotations:
          summary: "High Redis memory usage"
          description: "Redis memory usage is above 80%"
          runbook_url: "https://docs.ms5dashboard.com/runbooks/high-redis-memory"

      - alert: RedisDown
        expr: up{job="redis"} == 0
        for: 1m
        labels:
          severity: critical
          service: redis
        annotations:
          summary: "Redis is down"
          description: "Redis cache is not responding"
          runbook_url: "https://docs.ms5dashboard.com/runbooks/redis-down"

  - name: ms5.business
    rules:
      - alert: ProductionLineDown
        expr: increase(andon_events_total{event_type="stop"}[10m]) > 5
        for: 5m
        labels:
          severity: warning
          service: production
        annotations:
          summary: "Multiple production line stops"
          description: "More than 5 production line stops in the last 10 minutes"
          runbook_url: "https://docs.ms5dashboard.com/runbooks/production-line-down"

      - alert: LowOEE
        expr: oee_value < 0.7
        for: 30m
        labels:
          severity: warning
          service: production
        annotations:
          summary: "Low OEE detected"
          description: "OEE is below 70% for more than 30 minutes"
          runbook_url: "https://docs.ms5dashboard.com/runbooks/low-oee"

      - alert: HighDowntimeRate
        expr: rate(downtime_events_total[1h]) > 0.1
        for: 15m
        labels:
          severity: warning
          service: production
        annotations:
          summary: "High downtime rate"
          description: "Downtime rate is above 0.1 events per minute"
          runbook_url: "https://docs.ms5dashboard.com/runbooks/high-downtime-rate"

      - alert: AndonEscalationFailed
        expr: increase(andon_escalation_failures_total[5m]) > 0
        for: 1m
        labels:
          severity: critical
          service: andon
        annotations:
          summary: "Andon escalation failed"
          description: "Andon escalation system is failing"
          runbook_url: "https://docs.ms5dashboard.com/runbooks/andon-escalation-failed"

  - name: ms5.security
    rules:
      - alert: HighFailedLoginAttempts
        expr: rate(auth_failed_attempts_total[5m]) > 10
        for: 5m
        labels:
          severity: warning
          service: security
        annotations:
          summary: "High failed login attempts"
          description: "More than 10 failed login attempts per minute"
          runbook_url: "https://docs.ms5dashboard.com/runbooks/high-failed-logins"

      - alert: SuspiciousActivity
        expr: rate(security_events_total{type="suspicious"}[5m]) > 5
        for: 5m
        labels:
          severity: critical
          service: security
        annotations:
          summary: "Suspicious activity detected"
          description: "Multiple suspicious security events detected"
          runbook_url: "https://docs.ms5dashboard.com/runbooks/suspicious-activity"

  - name: ms5.monitoring
    rules:
      - alert: PrometheusDown
        expr: up{job="prometheus"} == 0
        for: 1m
        labels:
          severity: critical
          service: monitoring
        annotations:
          summary: "Prometheus is down"
          description: "Prometheus monitoring system is not responding"
          runbook_url: "https://docs.ms5dashboard.com/runbooks/prometheus-down"

      - alert: GrafanaDown
        expr: up{job="grafana"} == 0
        for: 1m
        labels:
          severity: warning
          service: monitoring
        annotations:
          summary: "Grafana is down"
          description: "Grafana dashboard is not responding"
          runbook_url: "https://docs.ms5dashboard.com/runbooks/grafana-down"

      - alert: AlertManagerDown
        expr: up{job="alertmanager"} == 0
        for: 1m
        labels:
          severity: critical
          service: monitoring
        annotations:
          summary: "AlertManager is down"
          description: "AlertManager is not responding"
          runbook_url: "https://docs.ms5dashboard.com/runbooks/alertmanager-down"
EOF

    log_success "Alert rules created"
}

# Function to setup AlertManager configuration
setup_alertmanager() {
    log_monitoring "Setting up AlertManager configuration..."
    
    # Create AlertManager configuration
    cat > alertmanager.yml << EOF
global:
  smtp_smarthost: 'localhost:587'
  smtp_from: 'alerts@ms5dashboard.com'
  smtp_auth_username: 'alerts@ms5dashboard.com'
  smtp_auth_password: 'your-smtp-password'

route:
  group_by: ['alertname', 'service']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'default-receiver'
  routes:
    - match:
        severity: critical
      receiver: 'critical-alerts'
      group_wait: 5s
      repeat_interval: 30m
    - match:
        severity: warning
      receiver: 'warning-alerts'
      group_wait: 10s
      repeat_interval: 2h
    - match:
        service: security
      receiver: 'security-alerts'
      group_wait: 5s
      repeat_interval: 15m

receivers:
  - name: 'default-receiver'
    email_configs:
      - to: '$ALERT_EMAIL_RECIPIENTS'
        subject: '[MS5.0] Alert: {{ .GroupLabels.alertname }}'
        body: |
          {{ range .Alerts }}
          Alert: {{ .Annotations.summary }}
          Description: {{ .Annotations.description }}
          Severity: {{ .Labels.severity }}
          Service: {{ .Labels.service }}
          Instance: {{ .Labels.instance }}
          Time: {{ .StartsAt }}
          {{ if .Annotations.runbook_url }}
          Runbook: {{ .Annotations.runbook_url }}
          {{ end }}
          {{ end }}

  - name: 'critical-alerts'
    email_configs:
      - to: '$ALERT_EMAIL_RECIPIENTS'
        subject: '[CRITICAL] MS5.0 Alert: {{ .GroupLabels.alertname }}'
        body: |
          🚨 CRITICAL ALERT 🚨
          
          {{ range .Alerts }}
          Alert: {{ .Annotations.summary }}
          Description: {{ .Annotations.description }}
          Severity: {{ .Labels.severity }}
          Service: {{ .Labels.service }}
          Instance: {{ .Labels.instance }}
          Time: {{ .StartsAt }}
          {{ if .Annotations.runbook_url }}
          Runbook: {{ .Annotations.runbook_url }}
          {{ end }}
          {{ end }}
    
    # Slack integration (if webhook is configured)
    $(if [ -n "$ALERT_SLACK_WEBHOOK" ]; then cat << 'SLACK_EOF'
    slack_configs:
      - api_url: '$ALERT_SLACK_WEBHOOK'
        channel: '#alerts-critical'
        title: 'Critical Alert: {{ .GroupLabels.alertname }}'
        text: |
          🚨 *CRITICAL ALERT* 🚨
          
          {{ range .Alerts }}
          *Alert:* {{ .Annotations.summary }}
          *Description:* {{ .Annotations.description }}
          *Severity:* {{ .Labels.severity }}
          *Service:* {{ .Labels.service }}
          *Instance:* {{ .Labels.instance }}
          *Time:* {{ .StartsAt }}
          {{ if .Annotations.runbook_url }}
          *Runbook:* {{ .Annotations.runbook_url }}
          {{ end }}
          {{ end }}
SLACK_EOF
    fi)

  - name: 'warning-alerts'
    email_configs:
      - to: '$ALERT_EMAIL_RECIPIENTS'
        subject: '[WARNING] MS5.0 Alert: {{ .GroupLabels.alertname }}'
        body: |
          ⚠️ WARNING ALERT ⚠️
          
          {{ range .Alerts }}
          Alert: {{ .Annotations.summary }}
          Description: {{ .Annotations.description }}
          Severity: {{ .Labels.severity }}
          Service: {{ .Labels.service }}
          Instance: {{ .Labels.instance }}
          Time: {{ .StartsAt }}
          {{ if .Annotations.runbook_url }}
          Runbook: {{ .Annotations.runbook_url }}
          {{ end }}
          {{ end }}

  - name: 'security-alerts'
    email_configs:
      - to: 'security@ms5dashboard.com'
        subject: '[SECURITY] MS5.0 Alert: {{ .GroupLabels.alertname }}'
        body: |
          🔒 SECURITY ALERT 🔒
          
          {{ range .Alerts }}
          Alert: {{ .Annotations.summary }}
          Description: {{ .Annotations.description }}
          Severity: {{ .Labels.severity }}
          Service: {{ .Labels.service }}
          Instance: {{ .Labels.instance }}
          Time: {{ .StartsAt }}
          {{ if .Annotations.runbook_url }}
          Runbook: {{ .Annotations.runbook_url }}
          {{ end }}
          {{ end }}

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'instance']
EOF

    log_success "AlertManager configuration created"
}

# Function to setup Grafana dashboards
setup_grafana_dashboards() {
    log_monitoring "Setting up Grafana dashboards..."
    
    # Create dashboard directory
    mkdir -p grafana/provisioning/dashboards
    
    # Create dashboard configuration
    cat > grafana/provisioning/dashboards/dashboard.yml << EOF
apiVersion: 1

providers:
  - name: 'ms5-dashboards'
    orgId: 1
    folder: 'MS5.0 Floor Dashboard'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOF

    # Create MS5.0 System Overview Dashboard
    cat > grafana/provisioning/dashboards/ms5-system-overview.json << EOF
{
  "dashboard": {
    "id": null,
    "title": "MS5.0 System Overview",
    "tags": ["ms5", "system", "overview"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "System Health",
        "type": "stat",
        "targets": [
          {
            "expr": "up{job=\"ms5-backend\"}",
            "legendFormat": "Backend API"
          },
          {
            "expr": "up{job=\"postgres\"}",
            "legendFormat": "Database"
          },
          {
            "expr": "up{job=\"redis\"}",
            "legendFormat": "Redis"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "color": {
              "mode": "thresholds"
            },
            "thresholds": {
              "steps": [
                {"color": "red", "value": 0},
                {"color": "green", "value": 1}
              ]
            }
          }
        },
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "API Request Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(http_requests_total[5m])",
            "legendFormat": "{{method}} {{endpoint}}"
          }
        ],
        "yAxes": [
          {
            "label": "Requests/sec"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
      },
      {
        "id": 3,
        "title": "Response Time",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))",
            "legendFormat": "95th percentile"
          },
          {
            "expr": "histogram_quantile(0.50, rate(http_request_duration_seconds_bucket[5m]))",
            "legendFormat": "50th percentile"
          }
        ],
        "yAxes": [
          {
            "label": "Seconds"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8}
      },
      {
        "id": 4,
        "title": "Error Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(http_requests_total{status=~\"5..\"}[5m]) / rate(http_requests_total[5m])",
            "legendFormat": "5xx Error Rate"
          },
          {
            "expr": "rate(http_requests_total{status=~\"4..\"}[5m]) / rate(http_requests_total[5m])",
            "legendFormat": "4xx Error Rate"
          }
        ],
        "yAxes": [
          {
            "label": "Error Rate"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8}
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "refresh": "30s"
  }
}
EOF

    # Create MS5.0 Production Dashboard
    cat > grafana/provisioning/dashboards/ms5-production-dashboard.json << EOF
{
  "dashboard": {
    "id": null,
    "title": "MS5.0 Production Dashboard",
    "tags": ["ms5", "production", "oee"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "OEE Overview",
        "type": "stat",
        "targets": [
          {
            "expr": "oee_value",
            "legendFormat": "Overall OEE"
          }
        ],
        "fieldConfig": {
          "defaults": {
            "unit": "percent",
            "color": {
              "mode": "thresholds"
            },
            "thresholds": {
              "steps": [
                {"color": "red", "value": 0},
                {"color": "yellow", "value": 70},
                {"color": "green", "value": 85}
              ]
            }
          }
        },
        "gridPos": {"h": 8, "w": 6, "x": 0, "y": 0}
      },
      {
        "id": 2,
        "title": "Production Lines Status",
        "type": "table",
        "targets": [
          {
            "expr": "production_line_status",
            "legendFormat": "{{line_id}}"
          }
        ],
        "gridPos": {"h": 8, "w": 6, "x": 6, "y": 0}
      },
      {
        "id": 3,
        "title": "Downtime Events",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(downtime_events_total[5m])",
            "legendFormat": "Downtime Rate"
          }
        ],
        "yAxes": [
          {
            "label": "Events/min"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8}
      },
      {
        "id": 4,
        "title": "Andon Events",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(andon_events_total[5m])",
            "legendFormat": "Andon Events"
          }
        ],
        "yAxes": [
          {
            "label": "Events/min"
          }
        ],
        "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8}
      }
    ],
    "time": {
      "from": "now-24h",
      "to": "now"
    },
    "refresh": "30s"
  }
}
EOF

    log_success "Grafana dashboards created"
}

# Function to setup monitoring services
start_monitoring_services() {
    log_monitoring "Starting monitoring services..."
    
    # Start monitoring stack
    docker-compose -f docker-compose.production.yml up -d prometheus grafana alertmanager
    
    # Wait for services to be ready
    log_info "Waiting for monitoring services to start..."
    sleep 30
    
    # Verify Prometheus
    if curl -f -s http://localhost:9090/-/healthy > /dev/null; then
        log_success "Prometheus is running"
    else
        log_error "Prometheus failed to start"
        return 1
    fi
    
    # Verify Grafana
    if curl -f -s http://localhost:3000/api/health > /dev/null; then
        log_success "Grafana is running"
    else
        log_error "Grafana failed to start"
        return 1
    fi
    
    # Verify AlertManager
    if curl -f -s http://localhost:9093/-/healthy > /dev/null; then
        log_success "AlertManager is running"
    else
        log_error "AlertManager failed to start"
        return 1
    fi
    
    log_success "All monitoring services are running"
}

# Function to configure Grafana
configure_grafana() {
    log_monitoring "Configuring Grafana..."
    
    # Wait for Grafana to be ready
    local retry_count=0
    local max_retries=30
    
    while [ $retry_count -lt $max_retries ]; do
        if curl -f -s http://localhost:3000/api/health > /dev/null; then
            break
        fi
        log_info "Waiting for Grafana to be ready... ($((retry_count + 1))/$max_retries)"
        sleep 10
        ((retry_count++))
    done
    
    if [ $retry_count -eq $max_retries ]; then
        log_error "Grafana is not ready after $max_retries attempts"
        return 1
    fi
    
    # Configure Prometheus data source
    log_info "Configuring Prometheus data source..."
    curl -X POST http://admin:${GRAFANA_ADMIN_PASSWORD}@localhost:3000/api/datasources \
        -H "Content-Type: application/json" \
        -d '{
            "name": "Prometheus",
            "type": "prometheus",
            "url": "http://prometheus:9090",
            "access": "proxy",
            "isDefault": true
        }' 2>/dev/null || log_warning "Prometheus data source configuration failed"
    
    # Configure alerting
    log_info "Configuring Grafana alerting..."
    curl -X POST http://admin:${GRAFANA_ADMIN_PASSWORD}@localhost:3000/api/alerting/provisioning/contact-points \
        -H "Content-Type: application/json" \
        -d '{
            "name": "email-alerts",
            "type": "email",
            "settings": {
                "addresses": "'${ALERT_EMAIL_RECIPIENTS}'",
                "subject": "[MS5.0] Alert: {{ .AlertName }}"
            }
        }' 2>/dev/null || log_warning "Grafana alerting configuration failed"
    
    log_success "Grafana configuration completed"
}

# Function to test monitoring setup
test_monitoring_setup() {
    log_monitoring "Testing monitoring setup..."
    
    # Test Prometheus targets
    local targets_response=$(curl -s http://localhost:9090/api/v1/targets)
    local active_targets=$(echo "$targets_response" | jq -r '.data.activeTargets | length' 2>/dev/null || echo "0")
    
    if [ "$active_targets" -gt 0 ]; then
        log_success "Prometheus has $active_targets active targets"
    else
        log_warning "No active targets found in Prometheus"
    fi
    
    # Test Grafana dashboards
    local dashboards_response=$(curl -s http://admin:${GRAFANA_ADMIN_PASSWORD}@localhost:3000/api/search?type=dash-db)
    local dashboard_count=$(echo "$dashboards_response" | jq -r 'length' 2>/dev/null || echo "0")
    
    if [ "$dashboard_count" -gt 0 ]; then
        log_success "Grafana has $dashboard_count dashboards"
    else
        log_warning "No dashboards found in Grafana"
    fi
    
    # Test AlertManager
    local alertmanager_response=$(curl -s http://localhost:9093/api/v1/status)
    if echo "$alertmanager_response" | jq -e '.data' > /dev/null 2>&1; then
        log_success "AlertManager is configured and running"
    else
        log_warning "AlertManager configuration test failed"
    fi
    
    log_success "Monitoring setup test completed"
}

# Function to generate monitoring report
generate_monitoring_report() {
    log_monitoring "Generating monitoring setup report..."
    
    local report_file="${LOG_DIR}/monitoring_setup_report_${TIMESTAMP}.md"
    
    cat > "$report_file" << EOF
# MS5.0 Floor Dashboard - Production Monitoring Setup Report

**Setup Date:** $(date)
**Environment:** $ENVIRONMENT
**Monitoring Type:** $MONITORING_TYPE

## Monitoring Components

### Prometheus
- **Status:** $(curl -s http://localhost:9090/-/healthy > /dev/null && echo "✅ Running" || echo "❌ Not Running")
- **URL:** http://localhost:9090
- **Targets:** $(curl -s http://localhost:9090/api/v1/targets | jq -r '.data.activeTargets | length' 2>/dev/null || echo "Unknown")
- **Retention:** ${PROMETHEUS_RETENTION_DAYS} days

### Grafana
- **Status:** $(curl -s http://localhost:3000/api/health > /dev/null && echo "✅ Running" || echo "❌ Not Running")
- **URL:** http://localhost:3000
- **Admin Password:** $GRAFANA_ADMIN_PASSWORD
- **Dashboards:** $(curl -s http://admin:${GRAFANA_ADMIN_PASSWORD}@localhost:3000/api/search?type=dash-db | jq -r 'length' 2>/dev/null || echo "Unknown")

### AlertManager
- **Status:** $(curl -s http://localhost:9093/-/healthy > /dev/null && echo "✅ Running" || echo "❌ Not Running")
- **URL:** http://localhost:9093
- **Email Recipients:** $ALERT_EMAIL_RECIPIENTS
- **Slack Integration:** $(if [ -n "$ALERT_SLACK_WEBHOOK" ]; then echo "✅ Configured"; else echo "❌ Not Configured"; fi)

## Alert Rules

### System Alerts
- High CPU Usage (>80%)
- High Memory Usage (>85%)
- High Disk Usage (>90%)
- System Down

### API Alerts
- High API Error Rate (>5%)
- Slow API Response (>2s)
- API Unavailable

### Database Alerts
- High Database Connections (>80)
- Database Down
- Slow Database Queries (>10s)

### Redis Alerts
- High Redis Memory Usage (>80%)
- Redis Down

### Business Alerts
- Production Line Down
- Low OEE (<70%)
- High Downtime Rate
- Andon Escalation Failed

### Security Alerts
- High Failed Login Attempts
- Suspicious Activity

### Monitoring Alerts
- Prometheus Down
- Grafana Down
- AlertManager Down

## Dashboards

### MS5.0 System Overview
- System Health Status
- API Request Rate
- Response Time Metrics
- Error Rate Tracking

### MS5.0 Production Dashboard
- OEE Overview
- Production Lines Status
- Downtime Events
- Andon Events

## Configuration Files

- **Prometheus Config:** prometheus.production.yml
- **Alert Rules:** alert_rules.yml
- **AlertManager Config:** alertmanager.yml
- **Grafana Dashboards:** grafana/provisioning/dashboards/

## Access URLs

- **Prometheus:** http://localhost:9090
- **Grafana:** http://localhost:3000 (admin/${GRAFANA_ADMIN_PASSWORD})
- **AlertManager:** http://localhost:9093

## Next Steps

1. Configure SSL certificates for production URLs
2. Set up external notification channels (Slack, PagerDuty, etc.)
3. Configure additional dashboards as needed
4. Set up log aggregation (ELK stack or similar)
5. Configure backup and retention policies
6. Train team on monitoring and alerting procedures

## Monitoring Best Practices

1. **Alert Fatigue Prevention:**
   - Use appropriate severity levels
   - Group related alerts
   - Set reasonable thresholds

2. **Dashboard Design:**
   - Keep dashboards focused and actionable
   - Use consistent color schemes
   - Include relevant context

3. **Alert Response:**
   - Document runbooks for each alert
   - Establish escalation procedures
   - Regular alert review and tuning

4. **Performance Monitoring:**
   - Monitor key business metrics
   - Track SLA/SLO compliance
   - Regular capacity planning

EOF
    
    log_success "Monitoring setup report generated: $report_file"
}

# Main monitoring setup function
main() {
    local start_time=$(date +%s)
    
    # Execute setup based on type
    case $MONITORING_TYPE in
        full)
            setup_prometheus
            setup_alert_rules
            setup_alertmanager
            setup_grafana_dashboards
            start_monitoring_services
            configure_grafana
            test_monitoring_setup
            ;;
        prometheus)
            setup_prometheus
            setup_alert_rules
            start_monitoring_services
            ;;
        grafana)
            setup_grafana_dashboards
            configure_grafana
            ;;
        alerts)
            setup_alert_rules
            setup_alertmanager
            ;;
        dashboards)
            setup_grafana_dashboards
            ;;
        *)
            log_error "Invalid monitoring type: $MONITORING_TYPE"
            exit 1
            ;;
    esac
    
    # Generate report
    generate_monitoring_report
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log "Monitoring setup completed in ${duration}s"
    log "Log file: $LOG_FILE"
}

# Help function
show_help() {
    echo "MS5.0 Floor Dashboard - Production Monitoring Setup Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -e, --environment ENV   Environment (staging|production) (default: production)"
    echo "  -t, --type TYPE         Monitoring type (full|prometheus|grafana|alerts|dashboards) (default: full)"
    echo "  -p, --password PASS     Grafana admin password (default: admin123)"
    echo ""
    echo "Environment Variables:"
    echo "  ENVIRONMENT            Environment (default: production)"
    echo "  MONITORING_TYPE        Monitoring type (default: full)"
    echo "  GRAFANA_ADMIN_PASSWORD Grafana admin password (default: admin123)"
    echo "  PROMETHEUS_RETENTION_DAYS Retention days (default: 30)"
    echo "  ALERT_EMAIL_RECIPIENTS Email recipients for alerts"
    echo "  ALERT_SLACK_WEBHOOK    Slack webhook URL for alerts"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Setup full monitoring stack"
    echo "  $0 -t prometheus                     # Setup only Prometheus"
    echo "  $0 -t grafana -p mypassword         # Setup Grafana with custom password"
    echo "  ALERT_EMAIL_RECIPIENTS=admin@example.com $0  # Setup with email alerts"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -t|--type)
            MONITORING_TYPE="$2"
            shift 2
            ;;
        -p|--password)
            GRAFANA_ADMIN_PASSWORD="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(staging|production)$ ]]; then
    log_error "Invalid environment: $ENVIRONMENT (must be 'staging' or 'production')"
    exit 1
fi

# Validate monitoring type
if [[ ! "$MONITORING_TYPE" =~ ^(full|prometheus|grafana|alerts|dashboards)$ ]]; then
    log_error "Invalid monitoring type: $MONITORING_TYPE (must be 'full', 'prometheus', 'grafana', 'alerts', or 'dashboards')"
    exit 1
fi

# Run main function
main
