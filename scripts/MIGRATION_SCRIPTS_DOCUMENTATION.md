# MS5.0 Database Migration Scripts Documentation

## Overview

This document provides comprehensive documentation for the MS5.0 database migration scripts, designed for migrating from PostgreSQL to TimescaleDB with production-grade reliability and comprehensive error handling.

## Architecture

The migration system follows a starship-grade architecture with the following principles:
- **Inevitable Functions**: Every function feels like physics - deterministic and reliable
- **Zero Redundancy**: Clean, elegant connections between modules
- **Production-Ready by Default**: No placeholders, no TODOs - final form code
- **Self-Documenting**: Code that explains itself with NASA-level precision

## Scripts Overview

### Core Migration Scripts

1. **`migration-runner.sh`** - Main migration execution engine
2. **`pre-migration-validation.sh`** - Pre-migration environment validation
3. **`post-migration-validation.sh`** - Post-migration verification
4. **`backup-rollback-manager.sh`** - Backup and rollback management
5. **`test-migration-scripts.sh`** - Comprehensive test suite

## Detailed Script Documentation

### 1. Migration Runner (`migration-runner.sh`)

The migration runner is the core execution engine that orchestrates the entire migration process.

#### Features
- **Sequential Execution**: Runs 9 migration files in correct order
- **Idempotent Operations**: Safe to re-run migrations
- **Comprehensive Error Handling**: Detailed error reporting and recovery
- **Environment Support**: Production, staging, and development environments
- **Dry Run Mode**: Preview migrations without execution
- **Migration Logging**: Tracks all migration attempts and results

#### Usage

```bash
# Basic usage
./migration-runner.sh

# With specific environment
./migration-runner.sh --environment=staging

# Dry run mode
./migration-runner.sh --dry-run --verbose

# Force re-execution
./migration-runner.sh --force
```

#### Command Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `--environment=ENV` | Target environment (production\|staging\|development) | production |
| `--dry-run` | Show what would be executed without making changes | false |
| `--verbose` | Enable detailed debug logging | false |
| `--force` | Force re-execution of already applied migrations | false |
| `--help` | Show help message | - |

#### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `DB_HOST` | Database host | localhost |
| `DB_PORT` | Database port | 5432 |
| `DB_NAME` | Database name | factory_telemetry |
| `DB_USER` | Database user | ms5_user_production |
| `POSTGRES_PASSWORD_PRODUCTION` | Production database password | - |

#### Migration Files Processed

The script processes these migration files in order:
1. `001_init_telemetry.sql` - Initialize telemetry tables
2. `002_plc_equipment_management.sql` - PLC equipment management
3. `003_production_management.sql` - Production management
4. `004_advanced_production_features.sql` - Advanced production features
5. `005_andon_escalation_system.sql` - Andon escalation system
6. `006_report_system.sql` - Report system
7. `007_plc_integration_phase1.sql` - PLC integration phase 1
8. `008_fix_critical_schema_issues.sql` - Fix critical schema issues
9. `009_database_optimization.sql` - Database optimization

#### Error Handling

The migration runner implements comprehensive error handling:

- **Connection Validation**: Tests database connectivity before starting
- **TimescaleDB Verification**: Ensures TimescaleDB extension is available
- **Migration Tracking**: Records all migration attempts in `migration_log` table
- **Rollback Support**: Stops execution on first failure (unless `--force` is used)
- **Detailed Logging**: All operations logged with timestamps and error details

#### Example Output

```
[2024-01-15 10:30:00] [INFO] Starting MS5.0 database migration process
[2024-01-15 10:30:00] [INFO] Environment: production
[2024-01-15 10:30:00] [INFO] Dry run: false
[2024-01-15 10:30:00] [SUCCESS] Database connection successful
[2024-01-15 10:30:01] [SUCCESS] TimescaleDB extension verified (version: 2.11.0)
[2024-01-15 10:30:01] [SUCCESS] Migration log table created/verified
[2024-01-15 10:30:02] [SUCCESS] ✅ Migration 001 - Initialize Telemetry completed successfully (1250ms)
[2024-01-15 10:30:05] [SUCCESS] ✅ Migration 002 - PLC Equipment Management completed successfully (2100ms)
...
[2024-01-15 10:35:00] [SUCCESS] 🎉 All migrations completed successfully!
```

### 2. Pre-Migration Validation (`pre-migration-validation.sh`)

Validates the environment before migration execution to ensure all requirements are met.

#### Features
- **System Resource Validation**: Disk space, memory, CPU checks
- **Database Connectivity**: Connection and permission validation
- **TimescaleDB Verification**: Extension installation and functionality tests
- **Migration File Validation**: File existence and integrity checks
- **Docker Environment Support**: Container-specific validations

#### Usage

```bash
# Basic validation
./pre-migration-validation.sh

# With specific environment
./pre-migration-validation.sh --environment=staging

# Quick validation (skip time-consuming checks)
./pre-migration-validation.sh --quick

# Verbose output
./pre-migration-validation.sh --verbose
```

#### Validation Checks

1. **System Resources**
   - Disk space: Minimum 10GB free
   - Memory: Minimum 4GB total, 2GB available
   - CPU: Core count and load average checks

2. **Database Connectivity**
   - Basic connection test
   - Permission validation (CREATE TABLE, CREATE SCHEMA)
   - Network connectivity

3. **TimescaleDB Verification**
   - Extension installation check
   - Version verification
   - License information
   - Hypertable creation test

4. **Migration Files**
   - File existence validation
   - Readability checks
   - Basic SQL syntax validation
   - Dependency analysis

#### Example Output

```
[2024-01-15 10:25:00] [INFO] Starting MS5.0 pre-migration validation
[2024-01-15 10:25:00] [INFO] Environment: production
[2024-01-15 10:25:00] [SUCCESS] Root filesystem space: 25GB available
[2024-01-15 10:25:01] [SUCCESS] Total memory: 8192MB, Available: 4096MB
[2024-01-15 10:25:01] [SUCCESS] CPU cores available: 8
[2024-01-15 10:25:02] [SUCCESS] Database connection successful
[2024-01-15 10:25:03] [SUCCESS] Database permissions validated
[2024-01-15 10:25:04] [SUCCESS] TimescaleDB extension verified (version: 2.11.0)
[2024-01-15 10:25:05] [SUCCESS] TimescaleDB functionality verified
[2024-01-15 10:25:06] [SUCCESS] All migration files validated
[2024-01-15 10:25:07] [SUCCESS] ✅ Pre-migration validation passed
```

### 3. Post-Migration Validation (`post-migration-validation.sh`)

Verifies the migration was successful and TimescaleDB is functioning correctly.

#### Features
- **Migration Completion Verification**: Checks migration log for success
- **Schema Validation**: Verifies all expected schemas and tables exist
- **Hypertable Validation**: Confirms TimescaleDB hypertables were created
- **Data Integrity Tests**: Tests data insertion and retrieval
- **Performance Validation**: Basic query performance checks
- **System Health Checks**: Database metrics and health indicators

#### Usage

```bash
# Basic validation
./post-migration-validation.sh

# With performance testing
./post-migration-validation.sh --performance-test

# Skip data integrity tests
./post-migration-validation.sh --no-data-integrity

# Verbose output
./post-migration-validation.sh --verbose
```

#### Validation Checks

1. **Migration Status**
   - Migration log table existence
   - Successful migration count
   - Failed migration identification

2. **Schema Validation**
   - Expected schemas (factory_telemetry, public)
   - Table existence verification
   - Table count validation

3. **TimescaleDB Validation**
   - Hypertable existence
   - Hypertable configuration
   - Compression policies
   - Background jobs

4. **Data Integrity**
   - Test data insertion
   - Data retrieval verification
   - TimescaleDB function tests

5. **Performance**
   - Query execution time
   - Compression statistics
   - Database health metrics

#### Expected Hypertables

The script validates these TimescaleDB hypertables:
- `factory_telemetry.metric_hist`
- `factory_telemetry.oee_calculations`
- `factory_telemetry.energy_consumption`
- `factory_telemetry.production_kpis`
- `factory_telemetry.production_context_history`

#### Example Output

```
[2024-01-15 10:40:00] [INFO] Starting MS5.0 post-migration validation
[2024-01-15 10:40:00] [INFO] Environment: production
[2024-01-15 10:40:01] [SUCCESS] Database connection successful
[2024-01-15 10:40:02] [SUCCESS] All migrations completed successfully
[2024-01-15 10:40:03] [SUCCESS] All expected schemas validated
[2024-01-15 10:40:04] [SUCCESS] Found 15 tables in factory_telemetry schema
[2024-01-15 10:40:05] [SUCCESS] Hypertable validated: factory_telemetry.metric_hist
[2024-01-15 10:40:06] [SUCCESS] Hypertable validated: factory_telemetry.oee_calculations
[2024-01-15 10:40:07] [SUCCESS] All expected hypertables validated
[2024-01-15 10:40:08] [SUCCESS] Data integrity test passed
[2024-01-15 10:40:09] [SUCCESS] TimescaleDB functions validated
[2024-01-15 10:40:10] [SUCCESS] ✅ Post-migration validation passed
```

### 4. Backup & Rollback Manager (`backup-rollback-manager.sh`)

Comprehensive backup and rollback management system with integrity verification.

#### Features
- **Multiple Backup Types**: Full, schema, data, and hypertables
- **Integrity Verification**: SHA256 checksums for all backup files
- **Automated Restoration**: One-command database restoration
- **Rollback Points**: Automated rollback script generation
- **Backup Management**: Listing, verification, and cleanup
- **Metadata Tracking**: JSON metadata for all backups

#### Usage

```bash
# Create backup
./backup-rollback-manager.sh backup pre_migration full

# Restore from backup
./backup-rollback-manager.sh restore pre_migration

# List backups
./backup-rollback-manager.sh list

# Verify backup integrity
./backup-rollback-manager.sh verify pre_migration

# Clean old backups
./backup-rollback-manager.sh clean 7
```

#### Backup Types

1. **Full Backup** (`full`)
   - Complete database dump
   - Includes schema and data
   - Compressed by default
   - Metadata and checksums

2. **Schema Backup** (`schema`)
   - Schema definitions only
   - No data included
   - Faster creation and restoration

3. **Data Backup** (`data`)
   - Data only
   - No schema definitions
   - For data migration scenarios

4. **Hypertables Backup** (`hypertables`)
   - TimescaleDB-specific data
   - CSV format for hypertables
   - Optimized for time-series data

#### Backup Structure

```
backups/
├── pre_migration_20240115_103000/
│   ├── full_database.sql.gz
│   ├── metadata.json
│   └── checksums.sha256
├── post_migration_20240115_104500/
│   ├── schema.sql.gz
│   ├── data.sql.gz
│   └── metadata.json
└── rollback_points/
    ├── migration_failure_20240115/
    │   ├── rollback.sh
    │   └── backup_reference.txt
```

#### Metadata Format

```json
{
    "backup_name": "pre_migration_20240115_103000",
    "backup_type": "full",
    "environment": "production",
    "database": {
        "host": "localhost",
        "port": "5432",
        "name": "factory_telemetry",
        "user": "ms5_user_production"
    },
    "backup_info": {
        "created_at": "2024-01-15T10:30:00Z",
        "created_by": "admin",
        "database_size": "2.5GB",
        "table_count": "15",
        "hypertable_count": "5"
    },
    "files": [
        "full_database.sql.gz"
    ],
    "checksums": {
        "full_database.sql.gz": "sha256:abc123..."
    }
}
```

#### Rollback Procedures

The rollback manager creates automated rollback scripts:

```bash
#!/bin/bash
# MS5.0 Rollback Script
# Created: 2024-01-15T10:30:00Z
# Backup: pre_migration_20240115_103000

# Configuration
ENVIRONMENT="production"
DB_HOST="localhost"
DB_PORT="5432"
DB_NAME="factory_telemetry"
DB_USER="ms5_user_production"
DB_PASSWORD="***"
BACKUP_NAME="pre_migration_20240115_103000"

# Execute rollback
gunzip -c /path/to/backup/full_database.sql.gz | \
PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST}" -p "${DB_PORT}" \
-U "${DB_USER}" -d "${DB_NAME}"
```

### 5. Test Suite (`test-migration-scripts.sh`)

Comprehensive test suite for all migration scripts with automated reporting.

#### Features
- **Automated Test Execution**: Runs all test scenarios
- **Environment Setup**: Automated test database creation
- **Test Coverage**: Tests all script functionality
- **Performance Testing**: Execution time benchmarks
- **HTML Reporting**: Detailed test reports
- **Cleanup Management**: Automatic test resource cleanup

#### Usage

```bash
# Run all tests
./test-migration-scripts.sh

# With verbose output
./test-migration-scripts.sh --verbose

# Skip cleanup
./test-migration-scripts.sh --no-cleanup

# Run tests in parallel
./test-migration-scripts.sh --parallel
```

#### Test Categories

1. **Environment Tests**
   - Database connectivity
   - TimescaleDB extension
   - Test data creation

2. **Migration Runner Tests**
   - Help command
   - Dry run mode
   - Environment validation
   - Error handling

3. **Validation Script Tests**
   - Pre-migration validation
   - Post-migration validation
   - TimescaleDB verification

4. **Backup Manager Tests**
   - Backup creation
   - Backup verification
   - Backup restoration
   - Rollback procedures

5. **Integration Tests**
   - Full migration workflow
   - Rollback integration
   - Performance benchmarks

#### Test Report Example

The test suite generates HTML reports with:
- Test summary statistics
- Individual test results
- Performance metrics
- Execution times
- Pass/fail status

## Best Practices

### 1. Pre-Migration Checklist

Before running migrations:

1. **Environment Validation**
   ```bash
   ./pre-migration-validation.sh --environment=production
   ```

2. **Create Backup**
   ```bash
   ./backup-rollback-manager.sh backup pre_migration full
   ```

3. **Verify Backup**
   ```bash
   ./backup-rollback-manager.sh verify pre_migration
   ```

4. **Test Migration (Dry Run)**
   ```bash
   ./migration-runner.sh --dry-run --verbose
   ```

### 2. Migration Execution

1. **Run Pre-Migration Validation**
   ```bash
   ./pre-migration-validation.sh
   ```

2. **Execute Migration**
   ```bash
   ./migration-runner.sh
   ```

3. **Run Post-Migration Validation**
   ```bash
   ./post-migration-validation.sh --performance-test
   ```

4. **Create Post-Migration Backup**
   ```bash
   ./backup-rollback-manager.sh backup post_migration full
   ```

### 3. Rollback Procedures

If migration fails:

1. **Stop Services**
   ```bash
   docker compose -f docker-compose.production.yml down
   ```

2. **Execute Rollback**
   ```bash
   ./rollback/migration_failure_*/rollback.sh --force
   ```

3. **Verify Rollback**
   ```bash
   ./post-migration-validation.sh --no-data-integrity
   ```

4. **Restart Services**
   ```bash
   docker compose -f docker-compose.production.yml up -d
   ```

### 4. Monitoring and Maintenance

1. **Regular Backup Cleanup**
   ```bash
   ./backup-rollback-manager.sh clean 30
   ```

2. **Backup Verification**
   ```bash
   ./backup-rollback-manager.sh list
   ./backup-rollback-manager.sh verify <backup_name>
   ```

3. **Performance Monitoring**
   ```bash
   ./post-migration-validation.sh --performance-test
   ```

## Troubleshooting

### Common Issues

1. **TimescaleDB Extension Not Found**
   ```bash
   # Check if TimescaleDB is installed
   docker exec ms5_postgres_production psql -U ms5_user_production -d factory_telemetry -c "SELECT * FROM pg_extension WHERE extname = 'timescaledb';"
   
   # Install TimescaleDB extension
   docker exec ms5_postgres_production psql -U ms5_user_production -d factory_telemetry -c "CREATE EXTENSION IF NOT EXISTS timescaledb;"
   ```

2. **Migration Already Applied**
   ```bash
   # Check migration status
   PGPASSWORD="${POSTGRES_PASSWORD_PRODUCTION}" psql -h localhost -p 5432 -U ms5_user_production -d factory_telemetry -c "SELECT * FROM migration_log ORDER BY applied_at DESC;"
   
   # Force re-execution
   ./migration-runner.sh --force
   ```

3. **Database Connection Failed**
   ```bash
   # Check database status
   docker ps | grep postgres
   
   # Check database logs
   docker logs ms5_postgres_production
   
   # Restart database
   docker compose -f docker-compose.production.yml restart postgres
   ```

4. **Backup Restoration Failed**
   ```bash
   # Verify backup integrity
   ./backup-rollback-manager.sh verify <backup_name>
   
   # Check disk space
   df -h
   
   # Check database permissions
   PGPASSWORD="${POSTGRES_PASSWORD_PRODUCTION}" psql -h localhost -p 5432 -U ms5_user_production -d factory_telemetry -c "SELECT current_user, session_user;"
   ```

### Log Analysis

All scripts generate detailed logs in the `logs/` directory:

- **Migration Logs**: `logs/migrations/migration_<environment>_<timestamp>.log`
- **Validation Logs**: `logs/validation/pre_migration_validation_<environment>_<timestamp>.log`
- **Backup Logs**: `logs/backup/backup_rollback_<environment>_<timestamp>.log`
- **Test Logs**: `logs/tests/migration_tests_<environment>_<timestamp>.log`

### Performance Optimization

1. **Database Configuration**
   - Increase `shared_buffers` for TimescaleDB
   - Optimize `work_mem` for large operations
   - Configure `maintenance_work_mem` for migrations

2. **Migration Optimization**
   - Use `--parallel` for independent operations
   - Monitor disk I/O during migrations
   - Schedule migrations during low-usage periods

3. **Backup Optimization**
   - Use compression for large backups
   - Implement incremental backups for frequent operations
   - Monitor backup storage usage

## Security Considerations

1. **Password Management**
   - Use environment variables for passwords
   - Never hardcode credentials in scripts
   - Rotate passwords regularly

2. **Access Control**
   - Limit database user permissions
   - Use separate users for different environments
   - Implement network-level access controls

3. **Backup Security**
   - Encrypt sensitive backup data
   - Secure backup storage locations
   - Implement backup access controls

## Conclusion

The MS5.0 database migration scripts provide a production-ready solution for migrating from PostgreSQL to TimescaleDB. With comprehensive error handling, validation, backup management, and testing capabilities, these scripts ensure reliable and safe database migrations in any environment.

The architecture follows starship-grade principles with inevitable functions, zero redundancy, and production-ready code that laughs at bugs. Every component is designed for reliability, maintainability, and operational excellence.
