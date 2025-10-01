# MS5.0 Phase 3: Database Migration Execution Guide

## Overview

This guide provides comprehensive instructions for executing Phase 3 of the MS5.0 database migration from PostgreSQL to TimescaleDB. The migration system implements cosmic-scale reliability with comprehensive backup, validation, and rollback capabilities.

## Architecture

The Phase 3 migration system consists of six core components:

1. **Backup System** (`backup-pre-migration.sh`) - Comprehensive backup creation
2. **Migration Runner** (`migration-runner.sh`) - Atomic migration execution
3. **Pre-Migration Validation** (`pre-migration-validation.sh`) - System readiness verification
4. **Post-Migration Validation** (`post-migration-validation.sh`) - Migration success verification
5. **Main Execution Script** (`execute-phase3-migration.sh`) - Orchestrated execution
6. **Testing Framework** (`test-phase3-migration.sh`) - Comprehensive testing suite

## Prerequisites

### System Requirements
- **Memory**: Minimum 4GB RAM (8GB recommended)
- **Disk Space**: Minimum 20GB free space
- **CPU**: Minimum 2 cores (4 cores recommended)
- **Docker**: Version 20.10.0 or higher
- **Docker Compose**: Latest version

### Environment Setup
```bash
# Required environment variables
export POSTGRES_PASSWORD_PRODUCTION="your_secure_password"
export DB_HOST="localhost"
export DB_PORT="5432"
export DB_NAME="factory_telemetry"
export DB_USER="ms5_user_production"
```

### Container Status
Ensure the PostgreSQL container is running:
```bash
docker compose -f docker-compose.production.yml up -d postgres
docker ps | grep ms5_postgres_production
```

## Quick Start

### Option 1: Automated Execution (Recommended)
```bash
# Execute complete Phase 3 migration
./execute-phase3-migration.sh
```

### Option 2: Manual Step-by-Step Execution
```bash
# Step 1: Pre-migration validation
./pre-migration-validation.sh

# Step 2: Create comprehensive backup
./backup-pre-migration.sh

# Step 3: Execute migrations
./migration-runner.sh

# Step 4: Post-migration validation
./post-migration-validation.sh
```

### Option 3: Testing Only
```bash
# Run comprehensive testing suite
./test-phase3-migration.sh
```

## Detailed Component Documentation

### 1. Backup System (`backup-pre-migration.sh`)

**Purpose**: Creates comprehensive backups before migration execution.

**Features**:
- Full database backup (complete dump)
- Schema-only backup (structure without data)
- Data-only backup (data without schema)
- Docker volume backup (complete filesystem state)
- Configuration backup (environment and config files)
- Backup integrity verification
- Automatic cleanup of old backups (7-day retention)

**Usage**:
```bash
./backup-pre-migration.sh
```

**Output**:
- Backup location: `/opt/ms5-backend/backups/pre-migration-YYYYMMDD-HHMMSS/`
- Backup manifest: `BACKUP_MANIFEST.txt`
- Execution log: Console output and log file

**Backup Structure**:
```
pre-migration-YYYYMMDD-HHMMSS/
├── database/
│   ├── full_backup.sql
│   ├── schema_only.sql
│   └── data_only.sql
├── volumes/
│   └── postgres_data.tar.gz
├── config/
│   ├── *.yml files
│   ├── *.env files
│   └── environment_dump.txt
├── logs/
└── BACKUP_MANIFEST.txt
```

### 2. Migration Runner (`migration-runner.sh`)

**Purpose**: Executes database migrations in a controlled, atomic manner.

**Features**:
- Idempotent migrations (safe to re-run)
- Transactional execution with rollback capability
- Comprehensive logging and audit trail
- Progress tracking and status reporting
- Dependency validation and integrity checks
- TimescaleDB extension verification
- Migration log table creation and management

**Migration Order** (CRITICAL - Must maintain this sequence):
1. `001_init_telemetry.sql` - Initialize telemetry tables
2. `002_plc_equipment_management.sql` - PLC equipment management
3. `003_production_management.sql` - Production management
4. `004_advanced_production_features.sql` - Advanced production features
5. `005_andon_escalation_system.sql` - Andon escalation system
6. `006_report_system.sql` - Report system
7. `007_plc_integration_phase1.sql` - PLC integration phase 1
8. `008_fix_critical_schema_issues.sql` - Fix critical schema issues
9. `009_database_optimization.sql` - Database optimization

**Usage**:
```bash
./migration-runner.sh
```

**Migration Log Table**:
```sql
CREATE TABLE migration_log (
    id SERIAL PRIMARY KEY,
    migration_name VARCHAR(255) UNIQUE NOT NULL,
    migration_file VARCHAR(255) NOT NULL,
    applied_at TIMESTAMPTZ DEFAULT NOW(),
    applied_by VARCHAR(255) DEFAULT USER,
    execution_time_ms INTEGER,
    status VARCHAR(50) DEFAULT 'completed',
    error_message TEXT,
    checksum VARCHAR(64),
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 3. Pre-Migration Validation (`pre-migration-validation.sh`)

**Purpose**: Validates system readiness before migration execution.

**Validation Checks**:
- System resources (disk space, memory, CPU)
- Docker environment and version compatibility
- Container status and health
- Database connectivity and configuration
- Migration file integrity and accessibility
- Backup system verification
- Network connectivity

**Usage**:
```bash
./pre-migration-validation.sh
```

**Validation Report**: `logs/validation/pre-migration-validation-YYYYMMDD-HHMMSS.txt`

### 4. Post-Migration Validation (`post-migration-validation.sh`)

**Purpose**: Validates migration success and system readiness for production.

**Validation Checks**:
- Database health and connectivity
- Database schema completeness
- TimescaleDB hypertable verification
- Data integrity and consistency
- Performance benchmarks
- Application connectivity
- System health verification

**Expected Tables** (after successful migration):
- `factory_telemetry.metric_def`
- `factory_telemetry.metric_binding`
- `factory_telemetry.metric_latest`
- `factory_telemetry.metric_hist`
- `factory_telemetry.fault_catalog`
- `factory_telemetry.fault_active`
- `factory_telemetry.fault_event`
- `factory_telemetry.context`
- `factory_telemetry.production_lines`
- `factory_telemetry.product_types`
- `factory_telemetry.production_schedules`
- `factory_telemetry.job_assignments`
- `factory_telemetry.users`
- `factory_telemetry.shifts`
- `factory_telemetry.andon_events`
- `factory_telemetry.escalation_rules`
- `factory_telemetry.notifications`
- `factory_telemetry.reports`
- `factory_telemetry.report_templates`
- `factory_telemetry.plc_connections`
- `factory_telemetry.plc_tags`
- `factory_telemetry.migration_log`

**Expected Hypertables**:
- `factory_telemetry.metric_hist`
- `factory_telemetry.oee_calculations`
- `factory_telemetry.energy_consumption`
- `factory_telemetry.production_kpis`

**Usage**:
```bash
./post-migration-validation.sh
```

**Validation Report**: `logs/validation/post-migration-validation-YYYYMMDD-HHMMSS.txt`

### 5. Main Execution Script (`execute-phase3-migration.sh`)

**Purpose**: Orchestrates the complete Phase 3 migration process.

**Execution Flow**:
1. Environment verification and script dependency checks
2. Pre-migration validation
3. Comprehensive backup creation
4. Database migration execution
5. Post-migration validation
6. System verification
7. Report generation

**Features**:
- Atomic execution with rollback capability
- Comprehensive error handling and logging
- Progress tracking and status reporting
- Automatic rollback on failure
- Detailed execution reports

**Usage**:
```bash
./execute-phase3-migration.sh
```

**Execution Reports**:
- Execution log: `logs/phase3/phase3-execution-YYYYMMDD-HHMMSS.log`
- Execution report: `logs/phase3/phase3-execution-report-YYYYMMDD-HHMMSS.txt`

### 6. Testing Framework (`test-phase3-migration.sh`)

**Purpose**: Comprehensive testing suite for migration validation.

**Test Categories**:
1. **Script Validation** - Syntax and permissions
2. **Database Connectivity** - Connection and TimescaleDB extension
3. **Migration Simulation** - Test database migration
4. **Performance Benchmarks** - Query and insert performance
5. **Data Integrity** - Consistency and referential integrity
6. **TimescaleDB Functionality** - Hypertables and compression
7. **Rollback Testing** - Backup and rollback capabilities

**Performance Benchmarks**:
- Query performance: < 1000ms
- Insert performance: < 500ms
- Connection time: < 100ms

**Usage**:
```bash
./test-phase3-migration.sh
```

**Test Report**: `logs/testing/phase3-migration-test-YYYYMMDD-HHMMSS.txt`

## Error Handling and Rollback

### Automatic Rollback
The system automatically initiates rollback procedures when:
- Migration execution fails
- Post-migration validation fails
- System health checks fail

### Manual Rollback
If automatic rollback is not available:

```bash
# Stop services
docker compose -f docker-compose.production.yml down

# Remove existing volume
docker volume rm ms5-backend_postgres_data_production

# Start fresh database
docker compose -f docker-compose.production.yml up -d postgres

# Wait for database to be ready
sleep 30

# Restore from backup
PGPASSWORD=$POSTGRES_PASSWORD_PRODUCTION psql -h localhost -p 5432 -U ms5_user_production -d factory_telemetry < /opt/ms5-backend/backups/pre-migration-YYYYMMDD-HHMMSS/database/full_backup.sql
```

### Backup Verification
```bash
# Verify backup integrity
head -n 10 /opt/ms5-backend/backups/pre-migration-YYYYMMDD-HHMMSS/database/full_backup.sql

# Check backup manifest
cat /opt/ms5-backend/backups/pre-migration-YYYYMMDD-HHMMSS/BACKUP_MANIFEST.txt
```

## Monitoring and Logging

### Log Locations
- **Execution logs**: `backend/logs/phase3/`
- **Validation logs**: `backend/logs/validation/`
- **Testing logs**: `backend/logs/testing/`
- **Migration logs**: `backend/logs/migrations/`

### Key Log Files
- `phase3-execution-YYYYMMDD-HHMMSS.log` - Main execution log
- `migration-runner.log` - Migration execution details
- `pre-migration-validation-YYYYMMDD-HHMMSS.txt` - Pre-migration validation report
- `post-migration-validation-YYYYMMDD-HHMMSS.txt` - Post-migration validation report

### Monitoring Commands
```bash
# Check migration status
PGPASSWORD=$POSTGRES_PASSWORD_PRODUCTION psql -h localhost -p 5432 -U ms5_user_production -d factory_telemetry -c "
SELECT migration_name, status, applied_at, execution_time_ms 
FROM factory_telemetry.migration_log 
ORDER BY applied_at;"

# Check TimescaleDB hypertables
PGPASSWORD=$POSTGRES_PASSWORD_PRODUCTION psql -h localhost -p 5432 -U ms5_user_production -d factory_telemetry -c "
SELECT hypertable_name, num_dimensions, num_chunks 
FROM timescaledb_information.hypertables 
WHERE schema_name = 'factory_telemetry';"

# Check container health
docker inspect --format='{{.State.Health.Status}}' ms5_postgres_production
```

## Troubleshooting

### Common Issues

#### 1. TimescaleDB Extension Not Found
**Error**: `TimescaleDB extension is not installed`
**Solution**:
```bash
# Verify TimescaleDB in container
docker exec ms5_postgres_production psql -U ms5_user_production -d factory_telemetry -c "SELECT extversion FROM pg_extension WHERE extname = 'timescaledb';"

# If not found, restart container
docker compose -f docker-compose.production.yml down
docker compose -f docker-compose.production.yml up -d postgres
```

#### 2. Migration File Not Found
**Error**: `Migration file not found: XXX.sql`
**Solution**:
```bash
# Verify migration files exist
ls -la /Users/tomcotham/MS5.0_App/*.sql

# Check file permissions
chmod +x /Users/tomcotham/MS5.0_App/backend/scripts/*.sh
```

#### 3. Database Connection Failed
**Error**: `Cannot connect to database`
**Solution**:
```bash
# Check container status
docker ps | grep ms5_postgres_production

# Check container logs
docker logs ms5_postgres_production

# Verify environment variables
echo $POSTGRES_PASSWORD_PRODUCTION
```

#### 4. Insufficient Resources
**Error**: `Insufficient disk space` or `Insufficient memory`
**Solution**:
```bash
# Check system resources
df -h /
free -h

# Clean up old backups
find /opt/ms5-backend/backups -type d -name "pre-migration-*" -mtime +7 -exec rm -rf {} \;
```

### Debug Mode
Enable verbose logging by setting environment variables:
```bash
export DEBUG=true
export LOG_LEVEL=DEBUG
./execute-phase3-migration.sh
```

## Performance Optimization

### TimescaleDB Configuration
The system automatically configures TimescaleDB for optimal performance:
- Chunk intervals optimized for different data types
- Compression policies for historical data
- Retention policies for automatic cleanup
- Performance indexes for time-series queries

### Expected Performance
- **Data Insertion**: >1000 records/second for metric_hist table
- **Query Performance**: <100ms for typical dashboard queries
- **Compression Ratio**: >70% compression for historical data
- **Storage Efficiency**: <1GB per month for typical production data

## Security Considerations

### Password Management
- Use strong, unique passwords for production
- Store passwords in environment variables, not scripts
- Rotate passwords regularly
- Use Docker secrets for production deployments

### Backup Security
- Encrypt backup files for sensitive data
- Store backups in secure, off-site locations
- Implement backup retention policies
- Regular backup integrity verification

### Access Control
- Limit database access to necessary users only
- Use principle of least privilege
- Monitor database access logs
- Implement network security controls

## Production Deployment Checklist

### Pre-Deployment
- [ ] System resources verified (memory, disk, CPU)
- [ ] Environment variables configured
- [ ] Container health verified
- [ ] Migration files validated
- [ ] Backup system tested
- [ ] Rollback procedures documented

### During Deployment
- [ ] Pre-migration validation passed
- [ ] Comprehensive backup created
- [ ] Migration execution completed
- [ ] Post-migration validation passed
- [ ] System verification completed

### Post-Deployment
- [ ] Application connectivity verified
- [ ] Performance benchmarks met
- [ ] Monitoring systems active
- [ ] Documentation updated
- [ ] Team notified of completion

## Support and Maintenance

### Regular Maintenance
- Monitor TimescaleDB performance metrics
- Review and optimize compression policies
- Clean up old backup files
- Update migration scripts as needed
- Test rollback procedures periodically

### Monitoring Integration
The system integrates with existing monitoring:
- Prometheus metrics collection
- Grafana dashboard visualization
- AlertManager notifications
- Log aggregation and analysis

### Documentation Updates
Keep this guide updated with:
- New migration files and procedures
- Performance optimization changes
- Security updates and best practices
- Troubleshooting solutions for new issues

---

## Conclusion

The MS5.0 Phase 3 migration system provides a robust, reliable, and comprehensive solution for migrating from PostgreSQL to TimescaleDB. With cosmic-scale reliability features including atomic execution, comprehensive validation, automatic rollback, and detailed logging, the system ensures successful migration with minimal risk.

For additional support or questions, refer to the execution logs and validation reports, or consult the MS5.0 system documentation.
