#!/bin/bash

# Phase 3.6: Security and Compliance Script
# This script implements zero-trust networking and compliance monitoring

set -euo pipefail

# Configuration
NAMESPACE="ms5-production"
DATABASE_NAME="factory_telemetry"
PRIMARY_SERVICE="postgres-primary.ms5-production.svc.cluster.local"
REPLICA_SERVICE="postgres-replica.ms5-production.svc.cluster.local"

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

# Implement zero-trust networking
implement_zero_trust_networking() {
    log "Implementing zero-trust networking..."
    
    # Create network policies for database isolation
    cat > /tmp/database-network-policies.yaml << EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-isolation
  namespace: $NAMESPACE
  labels:
    app: ms5-dashboard
    component: database
spec:
  podSelector:
    matchLabels:
      component: database
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: $NAMESPACE
    - podSelector:
        matchLabels:
          app: ms5-dashboard
          component: backend
    ports:
    - protocol: TCP
      port: 5432
  egress:
  - to:
    - podSelector:
        matchLabels:
          component: database
    ports:
    - protocol: TCP
      port: 5432
  - to: []
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53

---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-replica-isolation
  namespace: $NAMESPACE
  labels:
    app: ms5-dashboard
    component: database
spec:
  podSelector:
    matchLabels:
      component: database
      role: replica
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          component: database
          role: primary
    ports:
    - protocol: TCP
      port: 5432
  - from:
    - podSelector:
        matchLabels:
          app: ms5-dashboard
          component: backend
    ports:
    - protocol: TCP
      port: 5432
  egress:
  - to:
    - podSelector:
        matchLabels:
          component: database
          role: primary
    ports:
    - protocol: TCP
      port: 5432
  - to: []
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53

---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-monitoring-access
  namespace: $NAMESPACE
  labels:
    app: ms5-dashboard
    component: database
spec:
  podSelector:
    matchLabels:
      component: database
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: ms5-dashboard
          component: monitoring
    ports:
    - protocol: TCP
      port: 5432
    - protocol: TCP
      port: 9187
EOF

    # Apply network policies
    kubectl apply -f /tmp/database-network-policies.yaml
    
    log_success "Zero-trust networking implemented"
}

# Configure database security
configure_database_security() {
    log "Configuring database security..."
    
    # Get database connection details
    local db_host="$PRIMARY_SERVICE"
    local db_port="5432"
    local db_user="ms5_user"
    local db_password="ms5_password"
    
    # Execute security configuration queries
    PGPASSWORD="$db_password" psql \
        -h "$db_host" \
        -p "$db_port" \
        -U "$db_user" \
        -d "$DATABASE_NAME" \
        -c "
        -- Enable SSL/TLS
        ALTER SYSTEM SET ssl = on;
        ALTER SYSTEM SET ssl_cert_file = 'server.crt';
        ALTER SYSTEM SET ssl_key_file = 'server.key';
        ALTER SYSTEM SET ssl_ca_file = 'ca.crt';
        
        -- Configure authentication
        ALTER SYSTEM SET password_encryption = 'scram-sha-256';
        ALTER SYSTEM SET log_connections = on;
        ALTER SYSTEM SET log_disconnections = on;
        ALTER SYSTEM SET log_hostname = on;
        
        -- Configure access control
        ALTER SYSTEM SET row_security = on;
        ALTER SYSTEM SET shared_preload_libraries = 'timescaledb,pg_stat_statements';
        
        -- Configure audit logging
        ALTER SYSTEM SET log_statement = 'all';
        ALTER SYSTEM SET log_min_duration_statement = 1000;
        ALTER SYSTEM SET log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h ';
        
        -- Configure session security
        ALTER SYSTEM SET session_preload_libraries = 'timescaledb';
        ALTER SYSTEM SET default_transaction_isolation = 'read committed';
        ALTER SYSTEM SET default_transaction_read_only = off;
        
        -- Configure connection security
        ALTER SYSTEM SET tcp_keepalives_idle = 600;
        ALTER SYSTEM SET tcp_keepalives_interval = 30;
        ALTER SYSTEM SET tcp_keepalives_count = 3;
        
        -- Reload configuration
        SELECT pg_reload_conf();
        "
    
    if [ $? -eq 0 ]; then
        log_success "Database security configured"
    else
        log_error "Failed to configure database security"
        exit 1
    fi
}

# Set up compliance monitoring
setup_compliance_monitoring() {
    log "Setting up compliance monitoring..."
    
    # Create compliance monitoring configuration
    cat > /tmp/compliance-monitoring.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ms5-compliance-monitoring
  namespace: $NAMESPACE
  labels:
    app: ms5-dashboard
    component: monitoring
data:
  gdpr-compliance.yaml: |
    # GDPR Compliance Monitoring
    gdpr_rules:
      data_retention:
        description: "Data retention compliance"
        query: |
          SELECT 
            schemaname,
            tablename,
            n_tup_ins as total_rows,
            n_tup_upd as updated_rows,
            n_tup_del as deleted_rows
          FROM pg_stat_user_tables
          WHERE schemaname = 'factory_telemetry'
        alert_threshold: 1000000
        retention_period: "90 days"
      
      data_encryption:
        description: "Data encryption compliance"
        query: |
          SELECT 
            datname,
            ssl,
            client_addr,
            state
          FROM pg_stat_ssl
          JOIN pg_stat_activity ON pg_stat_ssl.pid = pg_stat_activity.pid
        alert_threshold: 0
        requirement: "All connections must use SSL"
      
      access_control:
        description: "Access control compliance"
        query: |
          SELECT 
            usename,
            usesuper,
            usecreatedb,
            usebypassrls
          FROM pg_user
          WHERE usename NOT IN ('postgres', 'ms5_user', 'ms5_monitoring_user')
        alert_threshold: 0
        requirement: "No unauthorized users"

  soc2-compliance.yaml: |
    # SOC2 Compliance Monitoring
    soc2_rules:
      availability:
        description: "System availability compliance"
        query: |
          SELECT 
            COUNT(*) as total_checks,
            SUM(CASE WHEN pg_isready THEN 1 ELSE 0 END) as successful_checks
          FROM (
            SELECT pg_isready() as pg_isready
            FROM generate_series(1, 100)
          ) checks
        target: 99.9
        window: "30 days"
      
      security:
        description: "Security compliance"
        query: |
          SELECT 
            COUNT(*) as total_connections,
            SUM(CASE WHEN ssl THEN 1 ELSE 0 END) as ssl_connections
          FROM pg_stat_ssl
        target: 100
        requirement: "All connections must use SSL"
      
      confidentiality:
        description: "Data confidentiality compliance"
        query: |
          SELECT 
            COUNT(*) as total_tables,
            SUM(CASE WHEN row_security THEN 1 ELSE 0 END) as protected_tables
          FROM pg_tables
          WHERE schemaname = 'factory_telemetry'
        target: 100
        requirement: "All tables must have row security enabled"

  fda-compliance.yaml: |
    # FDA 21 CFR Part 11 Compliance Monitoring
    fda_rules:
      audit_trail:
        description: "Audit trail compliance"
        query: |
          SELECT 
            COUNT(*) as total_audit_entries,
            MIN(created_at) as earliest_entry,
            MAX(created_at) as latest_entry
          FROM factory_telemetry.audit_log
        requirement: "Complete audit trail must be maintained"
      
      electronic_signatures:
        description: "Electronic signature compliance"
        query: |
          SELECT 
            COUNT(*) as total_signatures,
            SUM(CASE WHEN signature_valid THEN 1 ELSE 0 END) as valid_signatures
          FROM factory_telemetry.electronic_signatures
        target: 100
        requirement: "All signatures must be valid"
      
      data_integrity:
        description: "Data integrity compliance"
        query: |
          SELECT 
            COUNT(*) as total_records,
            SUM(CASE WHEN checksum_valid THEN 1 ELSE 0 END) as valid_records
          FROM factory_telemetry.data_integrity_checks
        target: 100
        requirement: "All records must have valid checksums"

  compliance-alerts.yaml: |
    # Compliance Alert Rules
    groups:
    - name: ms5-compliance
      rules:
      - alert: GDPRDataRetentionViolation
        expr: factory_telemetry_data_retention_violation > 0
        for: 1m
        labels:
          severity: critical
          compliance: gdpr
        annotations:
          summary: "GDPR data retention violation detected"
          description: "Data retention policy violation: {{ \$value }} records"
      
      - alert: SOC2AvailabilityViolation
        expr: factory_telemetry_availability < 99.9
        for: 5m
        labels:
          severity: critical
          compliance: soc2
        annotations:
          summary: "SOC2 availability requirement violated"
          description: "System availability is {{ \$value }}%"
      
      - alert: FDAAuditTrailViolation
        expr: factory_telemetry_audit_trail_gap > 0
        for: 1m
        labels:
          severity: critical
          compliance: fda
        annotations:
          summary: "FDA audit trail violation detected"
          description: "Audit trail gap: {{ \$value }} minutes"
      
      - alert: SecurityComplianceViolation
        expr: factory_telemetry_security_violation > 0
        for: 1m
        labels:
          severity: critical
          compliance: security
        annotations:
          summary: "Security compliance violation detected"
          description: "Security violation: {{ \$value }} incidents"
EOF

    # Apply compliance monitoring configuration
    kubectl apply -f /tmp/compliance-monitoring.yaml
    
    log_success "Compliance monitoring configured"
}

# Set up automated security scanning
setup_security_scanning() {
    log "Setting up automated security scanning..."
    
    # Create security scanning configuration
    cat > /tmp/security-scanning.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ms5-security-scanning
  namespace: $NAMESPACE
  labels:
    app: ms5-dashboard
    component: security
data:
  security-scan.sh: |
    #!/bin/bash
    # Automated security scanning script
    
    set -euo pipefail
    
    # Database security checks
    check_database_security() {
        echo "Checking database security..."
        
        # Check SSL configuration
        psql -h $PRIMARY_SERVICE -U ms5_user -d $DATABASE_NAME -c "
            SELECT 
                datname,
                ssl,
                client_addr,
                state
            FROM pg_stat_ssl
            JOIN pg_stat_activity ON pg_stat_ssl.pid = pg_stat_activity.pid;
        "
        
        # Check user permissions
        psql -h $PRIMARY_SERVICE -U ms5_user -d $DATABASE_NAME -c "
            SELECT 
                usename,
                usesuper,
                usecreatedb,
                usebypassrls
            FROM pg_user
            WHERE usename NOT IN ('postgres', 'ms5_user', 'ms5_monitoring_user');
        "
        
        # Check table permissions
        psql -h $PRIMARY_SERVICE -U ms5_user -d $DATABASE_NAME -c "
            SELECT 
                schemaname,
                tablename,
                tableowner,
                rowsecurity
            FROM pg_tables
            WHERE schemaname = 'factory_telemetry';
        "
    }
    
    # Network security checks
    check_network_security() {
        echo "Checking network security..."
        
        # Check network policies
        kubectl get networkpolicies -n $NAMESPACE
        
        # Check pod security policies
        kubectl get podsecuritypolicies
        
        # Check service accounts
        kubectl get serviceaccounts -n $NAMESPACE
    }
    
    # Container security checks
    check_container_security() {
        echo "Checking container security..."
        
        # Check container images
        kubectl get pods -n $NAMESPACE -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}' | sort | uniq
        
        # Check security contexts
        kubectl get pods -n $NAMESPACE -o jsonpath='{range .items[*]}{.spec.securityContext}{"\n"}{end}'
    }
    
    # Run all security checks
    check_database_security
    check_network_security
    check_container_security
    
    echo "Security scan completed"

  vulnerability-scan.yaml: |
    # Vulnerability scanning configuration
    vulnerability_scans:
      database:
        image: postgres:15-alpine
        scanner: trivy
        schedule: "0 2 * * *"  # Daily at 2 AM
        severity_threshold: "HIGH"
      
      application:
        image: ms5-backend:latest
        scanner: trivy
        schedule: "0 3 * * *"  # Daily at 3 AM
        severity_threshold: "HIGH"
      
      monitoring:
        image: prometheus:latest
        scanner: trivy
        schedule: "0 4 * * *"  # Daily at 4 AM
        severity_threshold: "HIGH"

  security-policies.yaml: |
    # Security policies
    security_policies:
      pod_security_standards:
        level: "restricted"
        rules:
          - runAsNonRoot: true
          - runAsUser: 999
          - runAsGroup: 999
          - fsGroup: 999
          - seccompProfile:
              type: RuntimeDefault
          - capabilities:
              drop:
              - ALL
      
      network_policies:
        default_deny: true
        allowed_ingress:
          - from:
            - namespaceSelector:
                matchLabels:
                  name: $NAMESPACE
            ports:
            - protocol: TCP
              port: 5432
      
      rbac_policies:
        default_deny: true
        allowed_roles:
          - ms5-database-sa
          - ms5-monitoring-sa
EOF

    # Apply security scanning configuration
    kubectl apply -f /tmp/security-scanning.yaml
    
    # Create security scanning CronJob
    cat > /tmp/security-scan-cronjob.yaml << EOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: ms5-security-scan
  namespace: $NAMESPACE
  labels:
    app: ms5-dashboard
    component: security
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: ms5-security-sa
          containers:
          - name: security-scanner
            image: trivy:latest
            command:
            - /bin/bash
            - /scripts/security-scan.sh
            volumeMounts:
            - name: security-scripts
              mountPath: /scripts
          volumes:
          - name: security-scripts
            configMap:
              name: ms5-security-scanning
          restartPolicy: OnFailure
EOF

    # Apply security scanning CronJob
    kubectl apply -f /tmp/security-scan-cronjob.yaml
    
    log_success "Automated security scanning configured"
}

# Set up audit logging
setup_audit_logging() {
    log "Setting up audit logging..."
    
    # Create audit logging configuration
    cat > /tmp/audit-logging.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ms5-audit-logging
  namespace: $NAMESPACE
  labels:
    app: ms5-dashboard
    component: audit
data:
  audit-config.yaml: |
    # Audit logging configuration
    audit_logging:
      database_audit:
        enabled: true
        log_level: "all"
        log_statement: "all"
        log_min_duration_statement: 0
        log_connections: true
        log_disconnections: true
        log_hostname: true
        log_line_prefix: "%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h "
      
      application_audit:
        enabled: true
        log_level: "INFO"
        log_requests: true
        log_responses: true
        log_errors: true
        log_performance: true
      
      security_audit:
        enabled: true
        log_authentication: true
        log_authorization: true
        log_access_control: true
        log_security_events: true

  audit-queries.sql: |
    -- Audit logging queries
    CREATE TABLE IF NOT EXISTS factory_telemetry.audit_log (
        id BIGSERIAL PRIMARY KEY,
        timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        user_id UUID,
        action TEXT NOT NULL,
        table_name TEXT,
        record_id UUID,
        old_values JSONB,
        new_values JSONB,
        ip_address INET,
        user_agent TEXT,
        session_id TEXT
    );
    
    -- Create audit trigger function
    CREATE OR REPLACE FUNCTION audit_trigger_function()
    RETURNS TRIGGER AS \$\$
    BEGIN
        INSERT INTO factory_telemetry.audit_log (
            user_id,
            action,
            table_name,
            record_id,
            old_values,
            new_values,
            ip_address,
            user_agent,
            session_id
        ) VALUES (
            COALESCE(current_setting('app.current_user_id', true)::UUID, NULL),
            TG_OP,
            TG_TABLE_NAME,
            COALESCE(NEW.id, OLD.id),
            CASE WHEN TG_OP = 'DELETE' THEN to_jsonb(OLD) ELSE NULL END,
            CASE WHEN TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN to_jsonb(NEW) ELSE NULL END,
            inet_client_addr(),
            current_setting('app.user_agent', true),
            current_setting('app.session_id', true)
        );
        RETURN COALESCE(NEW, OLD);
    END;
    \$\$ LANGUAGE plpgsql;
    
    -- Create audit triggers for critical tables
    CREATE TRIGGER audit_trigger_users
        AFTER INSERT OR UPDATE OR DELETE ON factory_telemetry.users
        FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();
    
    CREATE TRIGGER audit_trigger_production_schedules
        AFTER INSERT OR UPDATE OR DELETE ON factory_telemetry.production_schedules
        FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();
    
    CREATE TRIGGER audit_trigger_downtime_events
        AFTER INSERT OR UPDATE OR DELETE ON factory_telemetry.downtime_events
        FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();
EOF

    # Apply audit logging configuration
    kubectl apply -f /tmp/audit-logging.yaml
    
    # Execute audit logging setup
    local db_host="$PRIMARY_SERVICE"
    local db_port="5432"
    local db_user="ms5_user"
    local db_password="ms5_password"
    
    PGPASSWORD="$db_password" psql \
        -h "$db_host" \
        -p "$db_port" \
        -U "$db_user" \
        -d "$DATABASE_NAME" \
        -f /tmp/audit-queries.sql
    
    log_success "Audit logging configured"
}

# Main function
main() {
    log "Starting Phase 3.6: Security and Compliance"
    
    # Step 1: Check prerequisites
    check_prerequisites
    
    # Step 2: Implement zero-trust networking
    implement_zero_trust_networking
    
    # Step 3: Configure database security
    configure_database_security
    
    # Step 4: Set up compliance monitoring
    setup_compliance_monitoring
    
    # Step 5: Set up automated security scanning
    setup_security_scanning
    
    # Step 6: Set up audit logging
    setup_audit_logging
    
    log_success "Phase 3.6: Security and Compliance completed successfully!"
    log "Security and compliance setup completed at $(date)"
}

# Run main function
main "$@"
