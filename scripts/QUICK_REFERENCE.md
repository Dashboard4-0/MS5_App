# MS5.0 Migration Scripts - Quick Reference Guide

## 🚀 Quick Start

### 1. Pre-Migration Validation
```bash
./pre-migration-validation.sh --environment=production
```

### 2. Create Backup
```bash
./backup-rollback-manager.sh backup pre_migration full
```

### 3. Run Migration
```bash
./migration-runner.sh --environment=production
```

### 4. Post-Migration Validation
```bash
./post-migration-validation.sh --performance-test
```

## 📋 Script Overview

| Script | Purpose | Key Features |
|--------|---------|--------------|
| `migration-runner.sh` | Execute migrations | Sequential execution, error handling, dry-run |
| `pre-migration-validation.sh` | Validate environment | Resource checks, TimescaleDB verification |
| `post-migration-validation.sh` | Verify migration success | Hypertable validation, performance tests |
| `backup-rollback-manager.sh` | Backup & rollback | Multiple backup types, integrity verification |
| `test-migration-scripts.sh` | Test all scripts | Automated testing, HTML reports |

## 🔧 Common Commands

### Migration Runner
```bash
# Dry run
./migration-runner.sh --dry-run --verbose

# Force re-execution
./migration-runner.sh --force

# Specific environment
./migration-runner.sh --environment=staging
```

### Backup Management
```bash
# List backups
./backup-rollback-manager.sh list

# Verify backup
./backup-rollback-manager.sh verify <backup_name>

# Restore backup
./backup-rollback-manager.sh restore <backup_name> --force

# Clean old backups
./backup-rollback-manager.sh clean 30
```

### Validation
```bash
# Quick validation
./pre-migration-validation.sh --quick

# Full validation with performance tests
./post-migration-validation.sh --performance-test --verbose
```

## 🚨 Emergency Procedures

### Migration Failed
```bash
# 1. Stop services
docker compose -f docker-compose.production.yml down

# 2. Execute rollback
./rollback/migration_failure_*/rollback.sh --force

# 3. Verify rollback
./post-migration-validation.sh --no-data-integrity

# 4. Restart services
docker compose -f docker-compose.production.yml up -d
```

### Database Connection Issues
```bash
# Check database status
docker ps | grep postgres

# Check logs
docker logs ms5_postgres_production

# Restart database
docker compose -f docker-compose.production.yml restart postgres
```

### TimescaleDB Issues
```bash
# Check extension
docker exec ms5_postgres_production psql -U ms5_user_production -d factory_telemetry -c "SELECT * FROM pg_extension WHERE extname = 'timescaledb';"

# Install extension
docker exec ms5_postgres_production psql -U ms5_user_production -d factory_telemetry -c "CREATE EXTENSION IF NOT EXISTS timescaledb;"
```

## 📊 Environment Variables

| Variable | Production | Staging | Development |
|----------|------------|---------|-------------|
| `DB_HOST` | localhost | localhost | localhost |
| `DB_PORT` | 5432 | 5433 | 5434 |
| `DB_NAME` | factory_telemetry | factory_telemetry_staging | factory_telemetry_dev |
| `DB_USER` | ms5_user_production | ms5_user_staging | ms5_user_dev |
| `POSTGRES_PASSWORD_*` | Set in environment | Set in environment | Set in environment |

## 📁 Directory Structure

```
scripts/
├── migration-runner.sh              # Main migration executor
├── pre-migration-validation.sh      # Pre-migration checks
├── post-migration-validation.sh     # Post-migration verification
├── backup-rollback-manager.sh      # Backup & rollback management
├── test-migration-scripts.sh       # Test suite
├── MIGRATION_SCRIPTS_DOCUMENTATION.md  # Full documentation
└── QUICK_REFERENCE.md              # This file

logs/
├── migrations/                      # Migration execution logs
├── validation/                     # Validation logs
├── backup/                         # Backup operation logs
└── tests/                          # Test execution logs

backups/
├── pre_migration_*/                # Pre-migration backups
├── post_migration_*/               # Post-migration backups
└── rollback_points/                # Rollback scripts

rollback/
└── migration_failure_*/            # Automated rollback scripts
```

## 🎯 Success Criteria

### Migration Success
- ✅ All 9 migration files executed successfully
- ✅ TimescaleDB hypertables created
- ✅ No failed migrations in migration_log
- ✅ Post-migration validation passes
- ✅ Performance benchmarks met

### Performance Benchmarks
- **Data Insertion**: >1000 records/second
- **Query Performance**: <100ms for dashboard queries
- **Compression Ratio**: >70% for historical data
- **Storage Efficiency**: <1GB per month

## 🔍 Troubleshooting

### Check Migration Status
```bash
PGPASSWORD="${POSTGRES_PASSWORD_PRODUCTION}" psql -h localhost -p 5432 -U ms5_user_production -d factory_telemetry -c "SELECT migration_name, success, applied_at FROM migration_log ORDER BY applied_at DESC;"
```

### Check Hypertables
```bash
docker exec ms5_postgres_production psql -U ms5_user_production -d factory_telemetry -c "SELECT hypertable_name, num_chunks FROM timescaledb_information.hypertables;"
```

### Check Database Size
```bash
docker exec ms5_postgres_production psql -U ms5_user_production -d factory_telemetry -c "SELECT pg_size_pretty(pg_database_size('factory_telemetry'));"
```

## 📞 Support

For issues or questions:
1. Check the full documentation: `MIGRATION_SCRIPTS_DOCUMENTATION.md`
2. Review logs in the `logs/` directory
3. Run the test suite: `./test-migration-scripts.sh`
4. Check system resources and database connectivity

## 🏆 Best Practices

1. **Always validate before migration**
2. **Create backups before any changes**
3. **Test in staging environment first**
4. **Monitor logs during execution**
5. **Verify results after completion**
6. **Keep backups for rollback scenarios**
7. **Regular cleanup of old backups**
8. **Document any custom configurations**
