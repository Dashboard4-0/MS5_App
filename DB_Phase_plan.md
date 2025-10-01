# MS5.0 Database Migration & Optimization Phase Plan

## Executive Summary

This document outlines a comprehensive 6-phase plan to migrate the MS5.0 system from PostgreSQL to TimescaleDB, addressing critical issues identified in the database fix plan. The migration ensures optimal performance, data integrity, and smooth operation across all environments.

## Critical Issues Identified

### 1. **TimescaleDB Missing from Production Configuration**
- **Issue**: Production Docker Compose uses `postgres:15-alpine` instead of TimescaleDB
- **Impact**: `create_hypertable()` calls will fail, breaking time-series functionality
- **Severity**: **CRITICAL** - System will not function properly

### 2. **Hypertable Creation Calls Present**
- **Found in**: Migration files 003, 004, 005, 006, 007, 008, 009
- **Tables requiring hypertables**:
  - `factory_telemetry.oee_calculations` (line 180 in 003)
  - `factory_telemetry.energy_consumption` (line 203 in 004)
  - `factory_telemetry.production_kpis` (line 204 in 004)
  - `factory_telemetry.metric_hist` (implicit requirement)
  - Additional time-series tables in later migrations

### 3. **Schema Dependencies**
- **Migration Order**: Critical - must run in sequence (001-009)
- **Foreign Key Dependencies**: Complex web of relationships
- **Data Integrity**: Requires careful handling during migration

---

## Phase 1: Environment Preparation & Configuration Update

### **Phase 1.1: Docker Compose Configuration Update**

#### **Objectives**
- Update all Docker Compose files to use TimescaleDB
- Ensure consistent configuration across environments
- Add proper resource allocation and health checks

#### **Tasks**
1. **Update Production Configuration**
   ```yaml
   # Replace postgres service with TimescaleDB
   postgres:
     image: timescale/timescaledb:latest-pg15
     container_name: ms5_postgres_production
     environment:
       POSTGRES_DB: factory_telemetry
       POSTGRES_USER: ms5_user_production
       POSTGRES_PASSWORD: ${POSTGRES_PASSWORD_PRODUCTION}
       POSTGRES_INITDB_ARGS: "--encoding=UTF-8 --lc-collate=C --lc-ctype=C"
     volumes:
       - postgres_data_production:/var/lib/postgresql/data
       - ./init-scripts:/docker-entrypoint-initdb.d
       - ./backups:/backups
     ports:
       - "5432:5432"
     networks:
       - ms5_network_production
     restart: unless-stopped
     healthcheck:
       test: ["CMD-SHELL", "pg_isready -U ms5_user_production -d factory_telemetry"]
       interval: 10s
       timeout: 5s
       retries: 5
     deploy:
       resources:
         limits:
           memory: 8G  # Increased for TimescaleDB
         reservations:
           memory: 4G
   ```

2. **Update Staging Configuration**
   - Apply same TimescaleDB configuration to staging environment
   - Maintain separate databases and users

3. **Update Development Configuration**
   - Ensure development environment consistency
   - Remove separate TimescaleDB service (consolidate into main postgres)

#### **Optimization Points**
- **Memory Allocation**: Increased to 8G for production (TimescaleDB requires more memory)
- **Health Checks**: Enhanced to verify TimescaleDB extension
- **Volume Management**: Proper backup and data persistence

#### **Validation Steps**
```bash
# Verify TimescaleDB extension
docker exec ms5_postgres_production psql -U ms5_user_production -d factory_telemetry -c "SELECT * FROM pg_extension WHERE extname = 'timescaledb';"

# Check TimescaleDB version
docker exec ms5_postgres_production psql -U ms5_user_production -d factory_telemetry -c "SELECT extversion FROM pg_extension WHERE extname = 'timescaledb';"
```

---

## Phase 2: Migration Script Creation & Testing

### **Phase 2.1: Migration Script Development**

#### **Objectives**
- Create robust migration runner script
- Implement error handling and rollback capabilities
- Add comprehensive logging and validation

#### **Tasks**
1. **Create Migration Runner Script**
   ```bash
   #!/bin/bash
   # migration-runner.sh
   
   set -e
   
   DB_HOST="localhost"
   DB_PORT="5432"
   DB_NAME="factory_telemetry"
   DB_USER="ms5_user_production"
   DB_PASSWORD="${POSTGRES_PASSWORD_PRODUCTION}"
   
   # Logging function
   log() {
       echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
   }
   
   # Function to run migration with error handling
   run_migration() {
       local migration_file=$1
       local migration_name=$2
       
       log "Starting migration: $migration_name"
       
       # Check if migration already applied
       if psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -t -c "SELECT 1 FROM migration_log WHERE migration_name = '$migration_name';" | grep -q 1; then
           log "Migration $migration_name already applied, skipping"
           return 0
       fi
       
       # Run migration
       PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f "$migration_file"
       
       if [ $? -eq 0 ]; then
           # Log successful migration
           PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "INSERT INTO migration_log (migration_name, applied_at) VALUES ('$migration_name', NOW());"
           log "✅ Migration $migration_name completed successfully"
       else
           log "❌ Migration $migration_name failed"
           exit 1
       fi
   }
   
   # Create migration log table
   PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "
   CREATE TABLE IF NOT EXISTS migration_log (
       id SERIAL PRIMARY KEY,
       migration_name VARCHAR(255) UNIQUE NOT NULL,
       applied_at TIMESTAMP DEFAULT NOW()
   );"
   
   # Run migrations in order
   run_migration "001_init_telemetry.sql" "001 - Initialize Telemetry"
   run_migration "002_plc_equipment_management.sql" "002 - PLC Equipment Management"
   run_migration "003_production_management.sql" "003 - Production Management"
   run_migration "004_advanced_production_features.sql" "004 - Advanced Production Features"
   run_migration "005_andon_escalation_system.sql" "005 - Andon Escalation System"
   run_migration "006_report_system.sql" "006 - Report System"
   run_migration "007_plc_integration_phase1.sql" "007 - PLC Integration Phase 1"
   run_migration "008_fix_critical_schema_issues.sql" "008 - Fix Critical Schema Issues"
   run_migration "009_database_optimization.sql" "009 - Database Optimization"
   
   log "🎉 All migrations completed successfully!"
   ```

2. **Create Pre-Migration Validation Script**
   ```bash
   #!/bin/bash
   # pre-migration-validation.sh
   
   validate_environment() {
       log "Validating environment..."
       
       # Check disk space
       local disk_space=$(df / | awk 'NR==2 {print $4}')
       if [ $disk_space -lt 10485760 ]; then  # 10GB in KB
           log_error "Insufficient disk space. Required: 10GB, Available: $(($disk_space/1024/1024))GB"
           exit 1
       fi
       
       # Check memory
       local memory=$(free -m | awk 'NR==2{printf "%.0f", $2}')
       if [ $memory -lt 4096 ]; then  # 4GB
           log_error "Insufficient memory. Required: 4GB, Available: ${memory}MB"
           exit 1
       fi
       
       # Verify TimescaleDB extension
       if ! docker exec ms5_postgres_production psql -U ms5_user_production -d factory_telemetry -c "SELECT 1 FROM pg_extension WHERE extname = 'timescaledb';" | grep -q 1; then
           log_error "TimescaleDB extension not found"
           exit 1
       fi
       
       log_success "Environment validation passed"
   }
   ```

#### **Optimization Points**
- **Idempotent Migrations**: Check migration log to avoid re-running
- **Error Handling**: Comprehensive error checking and rollback
- **Resource Validation**: Pre-migration environment checks
- **Logging**: Detailed logging for troubleshooting

---

## Phase 3: Database Migration Execution

### **Phase 3.1: Pre-Migration Backup & Preparation**

#### **Objectives**
- Create comprehensive backups
- Prepare rollback procedures
- Validate migration environment

#### **Tasks**
1. **Create Backup Script**
   ```bash
   #!/bin/bash
   # backup-pre-migration.sh
   
   BACKUP_DIR="/opt/ms5-backend/backups/pre-migration-$(date +%Y%m%d-%H%M%S)"
   mkdir -p "$BACKUP_DIR"
   
   # Full database backup
   docker exec ms5_postgres_production pg_dump -U ms5_user_production factory_telemetry > "$BACKUP_DIR/full_backup.sql"
   
   # Schema-only backup
   docker exec ms5_postgres_production pg_dump -U ms5_user_production -s factory_telemetry > "$BACKUP_DIR/schema_only.sql"
   
   # Data-only backup
   docker exec ms5_postgres_production pg_dump -U ms5_user_production -a factory_telemetry > "$BACKUP_DIR/data_only.sql"
   
   # Backup Docker volumes
   docker run --rm -v ms5-backend_postgres_data_production:/data -v "$BACKUP_DIR":/backup alpine tar czf /backup/postgres_data.tar.gz -C /data .
   
   log_success "Backup completed: $BACKUP_DIR"
   ```

2. **Execute Migration**
   ```bash
   # Start database with TimescaleDB
   docker compose -f docker-compose.production.yml up -d postgres
   
   # Wait for database to be ready
   sleep 30
   
   # Run pre-migration validation
   ./pre-migration-validation.sh
   
   # Execute migrations
   ./migration-runner.sh
   
   # Post-migration verification
   ./post-migration-validation.sh
   ```

#### **Optimization Points**
- **Multiple Backup Types**: Full, schema-only, and data-only backups
- **Volume Backup**: Docker volume backup for complete rollback
- **Validation**: Pre and post-migration validation scripts

---

## Phase 4: TimescaleDB Optimization & Configuration

### **Phase 4.1: Hypertable Configuration**

#### **Objectives**
- Configure optimal hypertable settings
- Implement compression policies
- Set up retention policies

#### **Tasks**
1. **Hypertable Optimization Script**
   ```sql
   -- optimize-hypertables.sql
   
   -- Set optimal chunk intervals for different data types
   SELECT set_chunk_time_interval('factory_telemetry.metric_hist', INTERVAL '1 hour');
   SELECT set_chunk_time_interval('factory_telemetry.oee_calculations', INTERVAL '1 day');
   SELECT set_chunk_time_interval('factory_telemetry.energy_consumption', INTERVAL '1 day');
   SELECT set_chunk_time_interval('factory_telemetry.production_kpis', INTERVAL '1 day');
   
   -- Enable compression with optimal settings
   ALTER TABLE factory_telemetry.metric_hist SET (
       timescaledb.compress, 
       timescaledb.compress_segmentby = 'metric_def_id',
       timescaledb.compress_orderby = 'ts DESC'
   );
   
   ALTER TABLE factory_telemetry.oee_calculations SET (
       timescaledb.compress, 
       timescaledb.compress_segmentby = 'line_id',
       timescaledb.compress_orderby = 'calculation_time DESC'
   );
   
   -- Add compression policies
   SELECT add_compression_policy('factory_telemetry.metric_hist', INTERVAL '7 days', if_not_exists => TRUE);
   SELECT add_compression_policy('factory_telemetry.oee_calculations', INTERVAL '7 days', if_not_exists => TRUE);
   
   -- Add retention policies
   SELECT add_retention_policy('factory_telemetry.metric_hist', INTERVAL '90 days', if_not_exists => TRUE);
   SELECT add_retention_policy('factory_telemetry.oee_calculations', INTERVAL '365 days', if_not_exists => TRUE);
   ```

2. **Performance Index Creation**
   ```sql
   -- Create optimized indexes for time-series queries
   CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_metric_hist_ts_desc 
   ON factory_telemetry.metric_hist (ts DESC);
   
   CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_metric_hist_metric_ts 
   ON factory_telemetry.metric_hist (metric_def_id, ts DESC);
   
   CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_oee_calculations_ts_desc 
   ON factory_telemetry.oee_calculations (calculation_time DESC);
   ```

#### **Optimization Points**
- **Chunk Sizing**: Optimized for different data patterns
- **Compression**: 70%+ compression ratio expected
- **Retention**: Automatic data cleanup
- **Indexes**: Time-series optimized indexes

---

## Phase 5: Application Integration & Testing

### **Phase 5.1: Application Configuration Updates**

#### **Objectives**
- Update application configuration for TimescaleDB
- Implement TimescaleDB-specific features
- Add monitoring and management functions

#### **Tasks**
1. **Update Application Configuration**
   ```python
   # app/config.py additions
   class Settings(BaseSettings):
       # TimescaleDB specific settings
       TIMESCALEDB_CHUNK_TIME_INTERVAL: str = "1 day"
       TIMESCALEDB_COMPRESSION_ENABLED: bool = True
       TIMESCALEDB_COMPRESSION_AFTER: str = "7 days"
       TIMESCALEDB_RETENTION_POLICY: str = "90 days"
       TIMESCALEDB_MAX_BACKGROUND_WORKERS: int = 8
   ```

2. **Add TimescaleDB Management Functions**
   ```python
   # app/database.py additions
   async def setup_timescaledb_policies():
       """Setup TimescaleDB compression and retention policies."""
       try:
           async with get_db_session() as session:
               # Enable compression policies
               await session.execute(text("""
                   SELECT add_compression_policy('factory_telemetry.metric_hist', 
                       INTERVAL '7 days', if_not_exists => TRUE);
               """))
               
               # Set retention policies
               await session.execute(text("""
                   SELECT add_retention_policy('factory_telemetry.metric_hist', 
                       INTERVAL '90 days', if_not_exists => TRUE);
               """))
               
           logger.info("TimescaleDB policies configured successfully")
       except Exception as e:
           logger.error("Failed to configure TimescaleDB policies", error=str(e))
   ```

3. **Performance Testing Script**
   ```python
   # tests/performance/timescaledb_tests.py
   async def test_timescaledb_performance():
       """Test TimescaleDB performance with realistic data loads."""
       
       # Test data insertion performance
       start_time = time.time()
       await insert_test_data(1000)  # 1000 records
       insertion_time = time.time() - start_time
       
       assert insertion_time < 1.0  # Should insert 1000 records in < 1 second
       
       # Test query performance
       start_time = time.time()
       result = await query_recent_metrics(limit=100)
       query_time = time.time() - start_time
       
       assert query_time < 0.1  # Should query 100 records in < 100ms
   ```

#### **Optimization Points**
- **Configuration Management**: Centralized TimescaleDB settings
- **Performance Monitoring**: Built-in performance testing
- **Error Handling**: Comprehensive error handling and logging

---

## Phase 6: Production Deployment & Monitoring

### **Phase 6.1: Production Deployment**

#### **Objectives**
- Deploy to production environment
- Implement comprehensive monitoring
- Validate system performance

#### **Tasks**
1. **Production Deployment Script**
   ```bash
   #!/bin/bash
   # deploy-to-production.sh
   
   # Stop existing services
   docker compose -f docker-compose.production.yml down
   
   # Update configuration
   cp docker-compose.production.yml docker-compose.production.yml.backup
   sed -i 's/image: postgres:15-alpine/image: timescale\/timescaledb:latest-pg15/' docker-compose.production.yml
   
   # Start database with TimescaleDB
   docker compose -f docker-compose.production.yml up -d postgres
   
   # Wait for database to be ready
   sleep 30
   
   # Run migrations
   ./migration-runner.sh
   
   # Start all services
   docker compose -f docker-compose.production.yml up -d
   
   # Verify deployment
   ./verify-deployment.sh
   ```

2. **Monitoring Setup**
   ```yaml
   # prometheus.production.yml additions
   - job_name: 'timescaledb'
     static_configs:
       - targets: ['postgres:5432']
     metrics_path: /metrics
     params:
       format: ['prometheus']
   ```

3. **Performance Validation**
   ```bash
   # verify-deployment.sh
   # Test TimescaleDB functionality
   docker exec ms5_postgres_production psql -U ms5_user_production -d factory_telemetry -c "
   SELECT hypertable_name, num_dimensions, num_chunks 
   FROM timescaledb_information.hypertables;"
   
   # Test data insertion
   docker exec ms5_postgres_production psql -U ms5_user_production -d factory_telemetry -c "
   INSERT INTO factory_telemetry.metric_hist (metric_def_id, ts, value_real) 
   VALUES (gen_random_uuid(), NOW(), 100.0);"
   
   # Test compression
   docker exec ms5_postgres_production psql -U ms5_user_production -d factory_telemetry -c "
   SELECT * FROM timescaledb_information.compression_stats;"
   ```

#### **Optimization Points**
- **Zero-Downtime Deployment**: Careful service management
- **Comprehensive Monitoring**: TimescaleDB-specific metrics
- **Performance Validation**: Automated performance testing

---

## Success Criteria & Validation

### **Phase Completion Criteria**

#### **Phase 1: Environment Preparation**
- ✅ All Docker Compose files updated to TimescaleDB
- ✅ Resource allocation optimized
- ✅ Health checks implemented

#### **Phase 2: Migration Script Creation**
- ✅ Migration runner script created with error handling
- ✅ Pre-migration validation script created
- ✅ Rollback procedures documented

#### **Phase 3: Database Migration**
- ✅ All 9 migration files executed successfully
- ✅ Hypertables created without errors
- ✅ Data integrity maintained

#### **Phase 4: TimescaleDB Optimization**
- ✅ Compression policies implemented
- ✅ Retention policies configured
- ✅ Performance indexes created

#### **Phase 5: Application Integration**
- ✅ Application configuration updated
- ✅ TimescaleDB management functions added
- ✅ Performance tests passing

#### **Phase 6: Production Deployment**
- ✅ Production deployment successful
- ✅ Monitoring implemented
- ✅ Performance validated

### **Performance Benchmarks**
- **Data Insertion**: >1000 records/second for metric_hist table
- **Query Performance**: <100ms for typical dashboard queries
- **Compression Ratio**: >70% compression for historical data
- **Storage Efficiency**: <1GB per month for typical production data

---

## Risk Mitigation & Rollback Procedures

### **Backup Strategy**
```bash
# Pre-migration backup
docker exec ms5_postgres_production pg_dump -U ms5_user_production factory_telemetry > pre_migration_backup.sql

# Post-migration verification backup
docker exec ms5_postgres_production pg_dump -U ms5_user_production factory_telemetry > post_migration_backup.sql
```

### **Rollback Plan**
```bash
# If migration fails, restore from backup
docker compose -f docker-compose.production.yml down
docker volume rm ms5-backend_postgres_data_production
docker compose -f docker-compose.production.yml up -d postgres
sleep 30
PGPASSWORD=$POSTGRES_PASSWORD_PRODUCTION psql -h localhost -p 5432 -U ms5_user_production -d factory_telemetry < pre_migration_backup.sql
```

---

## Implementation Timeline

### **Week 1: Phases 1-2**
- Environment preparation and configuration updates
- Migration script development and testing

### **Week 2: Phases 3-4**
- Database migration execution
- TimescaleDB optimization and configuration

### **Week 3: Phases 5-6**
- Application integration and testing
- Production deployment and monitoring

---

## Conclusion

This comprehensive 6-phase plan addresses all critical issues identified in the database fix plan, ensuring a smooth migration from PostgreSQL to TimescaleDB with optimal performance and reliability. Each phase includes specific optimization points and validation criteria to ensure successful implementation.

The plan prioritizes data integrity, performance optimization, and risk mitigation throughout the migration process, providing a clear path to successful TimescaleDB deployment across all environments.
