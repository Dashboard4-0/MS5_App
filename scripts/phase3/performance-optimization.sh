#!/bin/bash

# Phase 3.5: Performance Optimization Script
# This script implements database performance tuning and SLI/SLO monitoring

set -euo pipefail

# Configuration
NAMESPACE="ms5-production"
DATABASE_NAME="factory_telemetry"
PRIMARY_SERVICE="postgres-primary.ms5-production.svc.cluster.local"
REPLICA_SERVICE="postgres-replica.ms5-production.svc.cluster.local"
MONITORING_NAMESPACE="ms5-production"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if psql is available
    if ! command -v psql &> /dev/null; then
        log_error "psql is not installed or not in PATH"
        exit 1
    fi
    
    # Check if AKS cluster is accessible
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot access AKS cluster"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Optimize PostgreSQL configuration
optimize_postgresql_config() {
    log "Optimizing PostgreSQL configuration..."
    
    # Get database connection details
    local db_host="$PRIMARY_SERVICE"
    local db_port="5432"
    local db_user="ms5_user"
    local db_password="ms5_password"
    
    # Execute performance optimization queries
    PGPASSWORD="$db_password" psql \
        -h "$db_host" \
        -p "$db_port" \
        -U "$db_user" \
        -d "$DATABASE_NAME" \
        -c "
        -- Optimize PostgreSQL configuration for TimescaleDB
        ALTER SYSTEM SET shared_buffers = '256MB';
        ALTER SYSTEM SET effective_cache_size = '1GB';
        ALTER SYSTEM SET maintenance_work_mem = '64MB';
        ALTER SYSTEM SET checkpoint_completion_target = 0.9;
        ALTER SYSTEM SET wal_buffers = '16MB';
        ALTER SYSTEM SET default_statistics_target = 100;
        ALTER SYSTEM SET random_page_cost = 1.1;
        ALTER SYSTEM SET effective_io_concurrency = 200;
        
        -- TimescaleDB specific optimizations
        ALTER SYSTEM SET timescaledb.max_background_workers = 8;
        ALTER SYSTEM SET timescaledb.license_key = 'timescale';
        
        -- Connection and session settings
        ALTER SYSTEM SET max_connections = 200;
        ALTER SYSTEM SET shared_preload_libraries = 'timescaledb';
        
        -- Logging optimizations
        ALTER SYSTEM SET log_min_duration_statement = 1000;
        ALTER SYSTEM SET log_checkpoints = on;
        ALTER SYSTEM SET log_connections = on;
        ALTER SYSTEM SET log_disconnections = on;
        ALTER SYSTEM SET log_lock_waits = on;
        
        -- Autovacuum optimizations
        ALTER SYSTEM SET autovacuum = on;
        ALTER SYSTEM SET autovacuum_max_workers = 3;
        ALTER SYSTEM SET autovacuum_naptime = '1min';
        ALTER SYSTEM SET autovacuum_vacuum_threshold = 50;
        ALTER SYSTEM SET autovacuum_analyze_threshold = 50;
        ALTER SYSTEM SET autovacuum_vacuum_scale_factor = 0.1;
        ALTER SYSTEM SET autovacuum_analyze_scale_factor = 0.05;
        
        -- Background writer optimizations
        ALTER SYSTEM SET bgwriter_delay = '200ms';
        ALTER SYSTEM SET bgwriter_lru_maxpages = 100;
        ALTER SYSTEM SET bgwriter_lru_multiplier = 2.0;
        
        -- Lock management
        ALTER SYSTEM SET deadlock_timeout = '1s';
        ALTER SYSTEM SET lock_timeout = 0;
        
        -- Reload configuration
        SELECT pg_reload_conf();
        "
    
    if [ $? -eq 0 ]; then
        log_success "PostgreSQL configuration optimized"
    else
        log_error "Failed to optimize PostgreSQL configuration"
        exit 1
    fi
}

# Optimize TimescaleDB hypertables
optimize_timescaledb() {
    log "Optimizing TimescaleDB hypertables..."
    
    # Get database connection details
    local db_host="$PRIMARY_SERVICE"
    local db_port="5432"
    local db_user="ms5_user"
    local db_password="ms5_password"
    
    # Execute TimescaleDB optimization queries
    PGPASSWORD="$db_password" psql \
        -h "$db_host" \
        -p "$db_port" \
        -U "$db_user" \
        -d "$DATABASE_NAME" \
        -c "
        -- Optimize chunk intervals for better performance
        SELECT set_chunk_time_interval('factory_telemetry.metric_hist', INTERVAL '1 hour');
        SELECT set_chunk_time_interval('factory_telemetry.oee_calculations', INTERVAL '1 day');
        
        -- Enable compression for historical data
        ALTER TABLE factory_telemetry.metric_hist SET (timescaledb.compress, timescaledb.compress_segmentby = 'metric_def_id');
        ALTER TABLE factory_telemetry.oee_calculations SET (timescaledb.compress, timescaledb.compress_segmentby = 'equipment_code');
        
        -- Set up compression policies
        SELECT add_compression_policy('factory_telemetry.metric_hist', INTERVAL '7 days', if_not_exists => TRUE);
        SELECT add_compression_policy('factory_telemetry.oee_calculations', INTERVAL '30 days', if_not_exists => TRUE);
        
        -- Set up data retention policies
        SELECT add_retention_policy('factory_telemetry.metric_hist', INTERVAL '90 days', if_not_exists => TRUE);
        SELECT add_retention_policy('factory_telemetry.oee_calculations', INTERVAL '1 year', if_not_exists => TRUE);
        
        -- Create continuous aggregates for better query performance
        CREATE MATERIALIZED VIEW IF NOT EXISTS metric_hourly_aggregate
        WITH (timescaledb.continuous) AS
        SELECT 
            time_bucket('1 hour', ts) AS hour,
            metric_def_id,
            COUNT(*) as sample_count,
            AVG(CASE WHEN value_real IS NOT NULL THEN value_real END) as avg_real_value,
            MIN(CASE WHEN value_real IS NOT NULL THEN value_real END) as min_real_value,
            MAX(CASE WHEN value_real IS NOT NULL THEN value_real END) as max_real_value,
            AVG(CASE WHEN value_int IS NOT NULL THEN value_int END) as avg_int_value,
            MIN(CASE WHEN value_int IS NOT NULL THEN value_int END) as min_int_value,
            MAX(CASE WHEN value_int IS NOT NULL THEN value_int END) as max_int_value
        FROM factory_telemetry.metric_hist
        GROUP BY hour, metric_def_id;
        
        -- Create indexes for better performance
        CREATE INDEX IF NOT EXISTS idx_metric_hist_ts_metric_def_id 
        ON factory_telemetry.metric_hist (ts DESC, metric_def_id);
        
        CREATE INDEX IF NOT EXISTS idx_oee_calculations_calculation_time_equipment_code 
        ON factory_telemetry.oee_calculations (calculation_time DESC, equipment_code);
        
        CREATE INDEX IF NOT EXISTS idx_oee_calculations_line_id_calculation_time 
        ON factory_telemetry.oee_calculations (line_id, calculation_time DESC);
        
        -- Analyze tables for better query planning
        ANALYZE factory_telemetry.metric_hist;
        ANALYZE factory_telemetry.oee_calculations;
        ANALYZE factory_telemetry.metric_def;
        ANALYZE factory_telemetry.equipment_config;
        "
    
    if [ $? -eq 0 ]; then
        log_success "TimescaleDB hypertables optimized"
    else
        log_error "Failed to optimize TimescaleDB hypertables"
        exit 1
    fi
}

# Set up connection pooling
setup_connection_pooling() {
    log "Setting up connection pooling..."
    
    # Create PgBouncer configuration
    cat > /tmp/pgbouncer.ini << EOF
[databases]
factory_telemetry = host=postgres-primary.ms5-production.svc.cluster.local port=5432 dbname=factory_telemetry

[pgbouncer]
listen_port = 6432
listen_addr = 0.0.0.0
auth_type = md5
auth_file = /etc/pgbouncer/userlist.txt
admin_users = ms5_user
stats_users = ms5_monitoring_user
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 50
reserve_pool_size = 10
reserve_pool_timeout = 5
max_db_connections = 100
max_user_connections = 100
server_round_robin = 1
ignore_startup_parameters = extra_float_digits
application_name_add_host = 1
EOF

    # Create user list for PgBouncer
    cat > /tmp/userlist.txt << EOF
\"ms5_user\" \"md5$(echo -n 'ms5_passwordms5_user' | md5sum | cut -d' ' -f1)\"
\"ms5_monitoring_user\" \"md5$(echo -n 'ms5_monitoring_passwordms5_monitoring_user' | md5sum | cut -d' ' -f1)\"
EOF

    # Apply PgBouncer configuration
    kubectl create configmap pgbouncer-config -n "$NAMESPACE" \
        --from-file=pgbouncer.ini=/tmp/pgbouncer.ini \
        --from-file=userlist.txt=/tmp/userlist.txt \
        --dry-run=client -o yaml | kubectl apply -f -
    
    log_success "Connection pooling configured"
}

# Set up SLI/SLO monitoring
setup_sli_slo_monitoring() {
    log "Setting up SLI/SLO monitoring..."
    
    # Create SLI/SLO configuration
    cat > /tmp/sli-slo-config.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ms5-sli-slo-config
  namespace: $MONITORING_NAMESPACE
  labels:
    app: ms5-dashboard
    component: monitoring
data:
  sli-definitions.yaml: |
    # Service Level Indicators for MS5.0 Database
    sli_definitions:
      database_availability:
        description: "Database availability percentage"
        query: |
          (
            sum(rate(pg_up[5m])) / 
            sum(rate(pg_up[5m]) + rate(pg_down[5m]))
          ) * 100
        target: 99.9
        window: 30d
      
      database_query_latency:
        description: "Database query latency (95th percentile)"
        query: |
          histogram_quantile(0.95, 
            rate(pg_stat_database_tup_returned[5m])
          )
        target: 200
        window: 30d
        unit: "ms"
      
      database_connection_pool_utilization:
        description: "Database connection pool utilization"
        query: |
          (
            sum(pg_stat_activity_count) / 
            sum(pg_stat_activity_max_connections)
          ) * 100
        target: 80
        window: 30d
        unit: "%"
      
      timescaledb_compression_ratio:
        description: "TimescaleDB compression ratio"
        query: |
          sum(timescaledb_chunk_compressed_bytes) / 
          sum(timescaledb_chunk_uncompressed_bytes)
        target: 0.1
        window: 30d
      
      database_backup_success_rate:
        description: "Database backup success rate"
        query: |
          (
            sum(rate(backup_success_total[5m])) / 
            sum(rate(backup_total[5m]))
          ) * 100
        target: 99.5
        window: 30d
        unit: "%"

  slo-configuration.yaml: |
    # Service Level Objectives for MS5.0 Database
    slo_configurations:
      database_availability_slo:
        sli: database_availability
        target: 99.9
        window: 30d
        error_budget: 0.1
        alert_threshold: 99.5
        critical_threshold: 99.0
      
      database_performance_slo:
        sli: database_query_latency
        target: 200
        window: 30d
        error_budget: 20
        alert_threshold: 250
        critical_threshold: 500
        unit: "ms"
      
      database_capacity_slo:
        sli: database_connection_pool_utilization
        target: 80
        window: 30d
        error_budget: 20
        alert_threshold: 85
        critical_threshold: 90
        unit: "%"
      
      database_storage_slo:
        sli: timescaledb_compression_ratio
        target: 0.1
        window: 30d
        error_budget: 0.05
        alert_threshold: 0.15
        critical_threshold: 0.2
      
      database_reliability_slo:
        sli: database_backup_success_rate
        target: 99.5
        window: 30d
        error_budget: 0.5
        alert_threshold: 99.0
        critical_threshold: 95.0
        unit: "%"
EOF

    # Apply SLI/SLO configuration
    kubectl apply -f /tmp/sli-slo-config.yaml
    
    log_success "SLI/SLO monitoring configured"
}

# Set up performance monitoring
setup_performance_monitoring() {
    log "Setting up performance monitoring..."
    
    # Create performance monitoring configuration
    cat > /tmp/performance-monitoring.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ms5-performance-monitoring
  namespace: $MONITORING_NAMESPACE
  labels:
    app: ms5-dashboard
    component: monitoring
data:
  prometheus-rules.yaml: |
    groups:
    - name: ms5-database-performance
      rules:
      - alert: DatabaseHighLatency
        expr: histogram_quantile(0.95, rate(pg_stat_database_tup_returned[5m])) > 200
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Database query latency is high"
          description: "95th percentile query latency is {{ \$value }}ms"
      
      - alert: DatabaseConnectionPoolHigh
        expr: (sum(pg_stat_activity_count) / sum(pg_stat_activity_max_connections)) * 100 > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Database connection pool utilization is high"
          description: "Connection pool utilization is {{ \$value }}%"
      
      - alert: DatabaseSlowQueries
        expr: rate(pg_stat_database_slow_queries[5m]) > 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High number of slow queries detected"
          description: "Slow query rate is {{ \$value }} queries/second"
      
      - alert: TimescaleDBCompressionLow
        expr: sum(timescaledb_chunk_compressed_bytes) / sum(timescaledb_chunk_uncompressed_bytes) > 0.2
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "TimescaleDB compression ratio is low"
          description: "Compression ratio is {{ \$value }}"
      
      - alert: DatabaseBackupFailed
        expr: rate(backup_failure_total[5m]) > 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Database backup failed"
          description: "Backup failure rate is {{ \$value }} failures/second"

  grafana-dashboard.json: |
    {
      "dashboard": {
        "title": "MS5.0 Database Performance",
        "panels": [
          {
            "title": "Database Availability",
            "type": "stat",
            "targets": [
              {
                "expr": "(sum(rate(pg_up[5m])) / sum(rate(pg_up[5m]) + rate(pg_down[5m]))) * 100",
                "legendFormat": "Availability %"
              }
            ]
          },
          {
            "title": "Query Latency",
            "type": "graph",
            "targets": [
              {
                "expr": "histogram_quantile(0.95, rate(pg_stat_database_tup_returned[5m]))",
                "legendFormat": "95th percentile latency"
              },
              {
                "expr": "histogram_quantile(0.50, rate(pg_stat_database_tup_returned[5m]))",
                "legendFormat": "50th percentile latency"
              }
            ]
          },
          {
            "title": "Connection Pool Utilization",
            "type": "graph",
            "targets": [
              {
                "expr": "(sum(pg_stat_activity_count) / sum(pg_stat_activity_max_connections)) * 100",
                "legendFormat": "Pool utilization %"
              }
            ]
          },
          {
            "title": "TimescaleDB Compression",
            "type": "graph",
            "targets": [
              {
                "expr": "sum(timescaledb_chunk_compressed_bytes) / sum(timescaledb_chunk_uncompressed_bytes)",
                "legendFormat": "Compression ratio"
              }
            ]
          }
        ]
      }
    }
EOF

    # Apply performance monitoring configuration
    kubectl apply -f /tmp/performance-monitoring.yaml
    
    log_success "Performance monitoring configured"
}

# Run performance tests
run_performance_tests() {
    log "Running performance tests..."
    
    # Get database connection details
    local db_host="$PRIMARY_SERVICE"
    local db_port="5432"
    local db_user="ms5_user"
    local db_password="ms5_password"
    
    # Run performance test queries
    PGPASSWORD="$db_password" psql \
        -h "$db_host" \
        -p "$db_port" \
        -U "$db_user" \
        -d "$DATABASE_NAME" \
        -c "
        -- Test query performance
        EXPLAIN (ANALYZE, BUFFERS) 
        SELECT 
            time_bucket('1 hour', ts) AS hour,
            metric_def_id,
            AVG(value_real) as avg_value
        FROM factory_telemetry.metric_hist 
        WHERE ts >= NOW() - INTERVAL '24 hours'
        GROUP BY hour, metric_def_id
        ORDER BY hour DESC;
        
        -- Test OEE calculation performance
        EXPLAIN (ANALYZE, BUFFERS)
        SELECT 
            line_id,
            equipment_code,
            AVG(oee) as avg_oee,
            AVG(availability) as avg_availability,
            AVG(performance) as avg_performance,
            AVG(quality) as avg_quality
        FROM factory_telemetry.oee_calculations
        WHERE calculation_time >= NOW() - INTERVAL '7 days'
        GROUP BY line_id, equipment_code;
        
        -- Test index usage
        SELECT 
            schemaname,
            tablename,
            indexname,
            idx_scan,
            idx_tup_read,
            idx_tup_fetch
        FROM pg_stat_user_indexes
        WHERE schemaname = 'factory_telemetry'
        ORDER BY idx_scan DESC;
        "
    
    log_success "Performance tests completed"
}

# Main function
main() {
    log "Starting Phase 3.5: Performance Optimization"
    
    # Step 1: Check prerequisites
    check_prerequisites
    
    # Step 2: Optimize PostgreSQL configuration
    optimize_postgresql_config
    
    # Step 3: Optimize TimescaleDB hypertables
    optimize_timescaledb
    
    # Step 4: Set up connection pooling
    setup_connection_pooling
    
    # Step 5: Set up SLI/SLO monitoring
    setup_sli_slo_monitoring
    
    # Step 6: Set up performance monitoring
    setup_performance_monitoring
    
    # Step 7: Run performance tests
    run_performance_tests
    
    log_success "Phase 3.5: Performance Optimization completed successfully!"
    log "Performance optimization completed at $(date)"
}

# Run main function
main "$@"
