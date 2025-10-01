# MS5.0 Database Schema Assessment & Migration Plan

## Executive Summary

After conducting a comprehensive analysis of the database schema and TimescaleDB requirements, I've identified several critical issues that need to be addressed for successful Ubuntu deployment. The system **requires TimescaleDB** for optimal performance with time-series data, but the current production configuration is missing this critical component.

---

## 🔍 **Critical Issues Identified**

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

### 3. **PostgreSQL Version Requirements**
- **Current**: PostgreSQL 15 (correct)
- **TimescaleDB Compatibility**: ✅ Compatible with TimescaleDB 2.11+
- **Recommendation**: Use `timescale/timescaledb:latest-pg15` image

### 4. **Schema Dependencies**
- **Migration Order**: Critical - must run in sequence (001-009)
- **Foreign Key Dependencies**: Complex web of relationships
- **Data Integrity**: Requires careful handling during migration

---

## 📊 **Database Schema Analysis**

### **Time-Series Tables Requiring Hypertables**
```sql
-- Primary time-series tables
factory_telemetry.metric_hist          -- PLC telemetry data (1-second intervals)
factory_telemetry.oee_calculations     -- OEE calculations (1-minute intervals)
factory_telemetry.energy_consumption   -- Energy monitoring (1-minute intervals)
factory_telemetry.production_kpis      -- Daily KPI summaries
factory_telemetry.fault_event          -- Fault events (irregular intervals)
factory_telemetry.downtime_events      -- Downtime tracking (irregular intervals)
```

### **Schema Complexity**
- **Total Tables**: 25+ tables across 9 migration files
- **Relationships**: Complex foreign key dependencies
- **Indexes**: 50+ performance indexes
- **Views**: 10+ analytical views
- **Functions**: Custom SQL functions for calculations

### **Data Volume Estimates**
- **PLC Telemetry**: ~86,400 records/day per equipment (1-second intervals)
- **OEE Calculations**: ~1,440 records/day per line (1-minute intervals)
- **Fault Events**: Variable, estimated 100-1000/day
- **Total Daily Volume**: ~100,000+ records/day for typical setup

---

## 🛠️ **Detailed Migration Plan**

### **Phase 1: Environment Preparation**

#### **1.1 Update Production Docker Compose**
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
        memory: 4G
      reservations:
        memory: 2G
```

#### **1.2 Create Migration Script**
```bash
#!/bin/bash
# migration-runner.sh

set -e

DB_HOST="localhost"
DB_PORT="5432"
DB_NAME="factory_telemetry"
DB_USER="ms5_user_production"
DB_PASSWORD="${POSTGRES_PASSWORD_PRODUCTION}"

# Function to run migration
run_migration() {
    local migration_file=$1
    local migration_name=$2
    
    echo "Running migration: $migration_name"
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f "$migration_file"
    
    if [ $? -eq 0 ]; then
        echo "✅ Migration $migration_name completed successfully"
    else
        echo "❌ Migration $migration_name failed"
        exit 1
    fi
}

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

echo "🎉 All migrations completed successfully!"
```

### **Phase 2: Database Migration Execution**

#### **2.1 Pre-Migration Checklist**
```bash
# 1. Backup existing data (if any)
docker exec ms5_postgres_production pg_dump -U ms5_user_production factory_telemetry > backup_before_migration.sql

# 2. Verify TimescaleDB extension
docker exec ms5_postgres_production psql -U ms5_user_production -d factory_telemetry -c "SELECT * FROM pg_extension WHERE extname = 'timescaledb';"

# 3. Check available disk space
df -h

# 4. Verify database connectivity
docker exec ms5_postgres_production psql -U ms5_user_production -d factory_telemetry -c "SELECT version();"
```

#### **2.2 Migration Execution Steps**
```bash
# Step 1: Start database service
docker compose -f docker-compose.production.yml up -d postgres

# Step 2: Wait for database to be ready
sleep 30

# Step 3: Run migrations
chmod +x migration-runner.sh
./migration-runner.sh

# Step 4: Verify hypertables were created
docker exec ms5_postgres_production psql -U ms5_user_production -d factory_telemetry -c "
SELECT schemaname, tablename, hypertable_name 
FROM timescaledb_information.hypertables;"
```

#### **2.3 Post-Migration Verification**
```bash
# Verify all tables exist
docker exec ms5_postgres_production psql -U ms5_user_production -d factory_telemetry -c "
SELECT schemaname, tablename 
FROM pg_tables 
WHERE schemaname = 'factory_telemetry' 
ORDER BY tablename;"

# Verify hypertables
docker exec ms5_postgres_production psql -U ms5_user_production -d factory_telemetry -c "
SELECT hypertable_name, num_dimensions, num_chunks 
FROM timescaledb_information.hypertables;"

# Verify indexes
docker exec ms5_postgres_production psql -U ms5_user_production -d factory_telemetry -c "
SELECT schemaname, tablename, indexname 
FROM pg_indexes 
WHERE schemaname = 'factory_telemetry' 
ORDER BY tablename, indexname;"

# Test data insertion
docker exec ms5_postgres_production psql -U ms5_user_production -d factory_telemetry -c "
INSERT INTO factory_telemetry.metric_hist (metric_def_id, ts, value_real) 
VALUES (gen_random_uuid(), NOW(), 100.0);"
```

### **Phase 3: Application Integration**

#### **3.1 Update Application Configuration**
```python
# Update app/config.py to include TimescaleDB settings
class Settings(BaseSettings):
    # ... existing settings ...
    
    # TimescaleDB specific settings
    TIMESCALEDB_CHUNK_TIME_INTERVAL: str = "1 day"
    TIMESCALEDB_COMPRESSION_ENABLED: bool = True
    TIMESCALEDB_COMPRESSION_AFTER: str = "7 days"
    TIMESCALEDB_RETENTION_POLICY: str = "90 days"
```

#### **3.2 Add TimescaleDB Management Functions**
```python
# Add to app/database.py
async def setup_timescaledb_policies():
    """Setup TimescaleDB compression and retention policies."""
    try:
        async with get_db_session() as session:
            # Enable compression
            await session.execute(text("""
                SELECT add_compression_policy('factory_telemetry.metric_hist', 
                    INTERVAL '7 days', if_not_exists => TRUE);
            """))
            
            await session.execute(text("""
                SELECT add_compression_policy('factory_telemetry.oee_calculations', 
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

---

## ⚠️ **Common Gotchas & Solutions**

### **1. Hypertable Creation Failures**
**Problem**: `create_hypertable()` fails with "relation does not exist"
**Solution**: Ensure tables are created before hypertable conversion
```sql
-- Check if table exists before creating hypertable
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables 
               WHERE table_schema = 'factory_telemetry' 
               AND table_name = 'oee_calculations') THEN
        PERFORM create_hypertable('factory_telemetry.oee_calculations', 'calculation_time', if_not_exists => TRUE);
    END IF;
END $$;
```

### **2. TimescaleDB Extension Not Available**
**Problem**: `ERROR: extension "timescaledb" is not available`
**Solution**: Ensure TimescaleDB image is used
```bash
# Verify TimescaleDB extension
docker exec ms5_postgres_production psql -U ms5_user_production -d factory_telemetry -c "
CREATE EXTENSION IF NOT EXISTS timescaledb;"
```

### **3. Migration Order Dependencies**
**Problem**: Foreign key constraint violations
**Solution**: Run migrations in exact order, handle dependencies
```sql
-- Add dependency checks
DO $$
BEGIN
    -- Check if production_lines table exists before creating foreign keys
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables 
                   WHERE table_schema = 'factory_telemetry' 
                   AND table_name = 'production_lines') THEN
        RAISE EXCEPTION 'production_lines table must exist before running this migration';
    END IF;
END $$;
```

### **4. Memory Issues During Migration**
**Problem**: Out of memory during large table creation
**Solution**: Increase Docker memory limits and use CONCURRENTLY for indexes
```yaml
# In docker-compose.production.yml
deploy:
  resources:
    limits:
      memory: 8G  # Increase from 4G
    reservations:
      memory: 4G  # Increase from 2G
```

### **5. Disk Space Issues**
**Problem**: Insufficient disk space for time-series data
**Solution**: Monitor disk usage and implement data retention
```bash
# Monitor disk usage
docker exec ms5_postgres_production psql -U ms5_user_production -d factory_telemetry -c "
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
WHERE schemaname = 'factory_telemetry' 
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;"
```

---

## 🔧 **Updated Ubuntu Deployment Steps**

### **Step 1: Fix Docker Compose Configuration**
```bash
# On your Ubuntu server
cd /opt/ms5-backend

# Backup current configuration
cp docker-compose.production.yml docker-compose.production.yml.backup

# Update postgres service to use TimescaleDB
sed -i 's/image: postgres:15-alpine/image: timescale\/timescaledb:latest-pg15/' docker-compose.production.yml
```

### **Step 2: Create Migration Scripts**
```bash
# Create migration directory
mkdir -p migrations

# Copy migration files
cp ../001_init_telemetry.sql migrations/
cp ../002_plc_equipment_management.sql migrations/
cp ../003_production_management.sql migrations/
cp ../004_advanced_production_features.sql migrations/
cp ../005_andon_escalation_system.sql migrations/
cp ../006_report_system.sql migrations/
cp ../007_plc_integration_phase1.sql migrations/
cp ../008_fix_critical_schema_issues.sql migrations/
cp ../009_database_optimization.sql migrations/

# Create migration runner script
cat > migration-runner.sh << 'EOF'
#!/bin/bash
set -e

DB_HOST="localhost"
DB_PORT="5432"
DB_NAME="factory_telemetry"
DB_USER="ms5_user_production"
DB_PASSWORD="${POSTGRES_PASSWORD_PRODUCTION}"

run_migration() {
    local migration_file=$1
    local migration_name=$2
    
    echo "Running migration: $migration_name"
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f "$migration_file"
    
    if [ $? -eq 0 ]; then
        echo "✅ Migration $migration_name completed successfully"
    else
        echo "❌ Migration $migration_name failed"
        exit 1
    fi
}

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

echo "🎉 All migrations completed successfully!"
EOF

chmod +x migration-runner.sh
```

### **Step 3: Execute Migration**
```bash
# Start database with TimescaleDB
docker compose -f docker-compose.production.yml up -d postgres

# Wait for database to be ready
sleep 30

# Run migrations
./migration-runner.sh

# Verify TimescaleDB functionality
docker exec ms5_postgres_production psql -U ms5_user_production -d factory_telemetry -c "
SELECT hypertable_name, num_dimensions, num_chunks 
FROM timescaledb_information.hypertables;"
```

### **Step 4: Start Full Application**
```bash
# Start all services
docker compose -f docker-compose.production.yml up -d

# Verify all services are running
docker compose -f docker-compose.production.yml ps

# Check application health
curl -f https://yourdomain.com/health
```

---

## 📈 **Performance Optimization Recommendations**

### **1. TimescaleDB Configuration**
```sql
-- Optimize chunk size for different data types
SELECT set_chunk_time_interval('factory_telemetry.metric_hist', INTERVAL '1 hour');
SELECT set_chunk_time_interval('factory_telemetry.oee_calculations', INTERVAL '1 day');
SELECT set_chunk_time_interval('factory_telemetry.energy_consumption', INTERVAL '1 day');

-- Enable compression
ALTER TABLE factory_telemetry.metric_hist SET (timescaledb.compress, timescaledb.compress_segmentby = 'metric_def_id');
ALTER TABLE factory_telemetry.oee_calculations SET (timescaledb.compress, timescaledb.compress_segmentby = 'line_id');
```

### **2. Index Optimization**
```sql
-- Create time-based indexes for better query performance
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_metric_hist_ts_desc 
ON factory_telemetry.metric_hist (ts DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_oee_calculations_ts_desc 
ON factory_telemetry.oee_calculations (calculation_time DESC);
```

### **3. Data Retention Policies**
```sql
-- Implement automatic data retention
SELECT add_retention_policy('factory_telemetry.metric_hist', INTERVAL '90 days');
SELECT add_retention_policy('factory_telemetry.oee_calculations', INTERVAL '365 days');
SELECT add_retention_policy('factory_telemetry.energy_consumption', INTERVAL '365 days');
```

---

## 🎯 **Success Criteria**

### **Migration Success Indicators**
- ✅ All 9 migration files execute without errors
- ✅ TimescaleDB extension is installed and functional
- ✅ All hypertables are created successfully
- ✅ All indexes are created without conflicts
- ✅ Application can connect and perform basic operations
- ✅ Time-series data can be inserted and queried efficiently

### **Performance Benchmarks**
- **Data Insertion**: >1000 records/second for metric_hist table
- **Query Performance**: <100ms for typical dashboard queries
- **Compression Ratio**: >70% compression for historical data
- **Storage Efficiency**: <1GB per month for typical production data

---

## 🚨 **Risk Mitigation**

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

## 📋 **Final Checklist**

- [ ] Update Docker Compose to use TimescaleDB image
- [ ] Copy all migration files to server
- [ ] Create migration runner script
- [ ] Backup existing data (if any)
- [ ] Run migrations in correct order
- [ ] Verify hypertables are created
- [ ] Test data insertion and queries
- [ ] Configure compression and retention policies
- [ ] Start full application stack
- [ ] Verify application functionality
- [ ] Monitor performance and disk usage

---

## 🔍 **IMMEDIATE FIX REQUIRED**

### **Critical Issue Summary**
The system **REQUIRES TimescaleDB** for proper functionality. Without it, the hypertable creation calls will fail and the time-series features will not work correctly.

### **Quick Fix Commands**
```bash
# 1. Fix Docker Compose
cd /opt/ms5-backend
sed -i 's/image: postgres:15-alpine/image: timescale\/timescaledb:latest-pg15/' docker-compose.production.yml

# 2. Copy migration files
cp ../001_init_telemetry.sql .
cp ../002_plc_equipment_management.sql .
cp ../003_production_management.sql .
cp ../004_advanced_production_features.sql .
cp ../005_andon_escalation_system.sql .
cp ../006_report_system.sql .
cp ../007_plc_integration_phase1.sql .
cp ../008_fix_critical_schema_issues.sql .
cp ../009_database_optimization.sql .

# 3. Create migration script (use script from Phase 1.2 above)
# 4. Run migrations
docker compose -f docker-compose.production.yml up -d postgres
sleep 30
./migration-runner.sh
```

This comprehensive plan addresses all identified issues and provides a clear path to successful database migration on Ubuntu with TimescaleDB support.
