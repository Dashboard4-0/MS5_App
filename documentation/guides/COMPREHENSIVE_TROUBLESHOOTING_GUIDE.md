# MS5.0 Floor Dashboard - Comprehensive Troubleshooting Guide

## Table of Contents
1. [Quick Reference](#quick-reference)
2. [System Health Diagnostics](#system-health-diagnostics)
3. [Authentication Issues](#authentication-issues)
4. [Database Problems](#database-problems)
5. [API Performance Issues](#api-performance-issues)
6. [Frontend Troubleshooting](#frontend-troubleshooting)
7. [WebSocket Connection Issues](#websocket-connection-issues)
8. [PLC Integration Problems](#plc-integration-problems)
9. [Security Issues](#security-issues)
10. [Performance Optimization](#performance-optimization)
11. [Network Connectivity](#network-connectivity)
12. [Emergency Procedures](#emergency-procedures)
13. [Preventive Maintenance](#preventive-maintenance)

## Quick Reference

### Emergency Contacts
- **Critical Issues**: +1-800-MS5-EMRG
- **Technical Support**: support@ms5.company.com
- **System Administrator**: admin@ms5.company.com
- **On-Call Engineer**: +1-800-MS5-ONCALL

### Service Status
- **System Status Page**: https://status.ms5.company.com
- **Maintenance Schedule**: https://status.ms5.company.com/maintenance
- **Known Issues**: https://status.ms5.company.com/issues

### Log Locations
- **Application Logs**: `/var/log/ms5-dashboard/`
- **System Logs**: `/var/log/syslog`
- **Database Logs**: `/var/log/postgresql/`
- **Web Server Logs**: `/var/log/nginx/`
- **Docker Logs**: `docker-compose logs`

### Diagnostic Commands
```bash
# System health check
./scripts/health_check.sh

# Database connectivity test
psql -U ms5_user -d factory_telemetry -c "SELECT version();"

# API health check
curl -s http://localhost:8000/health | jq .

# Service status
docker-compose -f docker-compose.production.yml ps

# Resource usage
htop && df -h && free -h
```

## System Health Diagnostics

### Comprehensive Health Check
```bash
#!/bin/bash
# comprehensive_health_check.sh

echo "=== MS5.0 System Health Check ==="
echo "Date: $(date)"
echo

# System Resources
echo "=== System Resources ==="
echo "CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
echo "Memory Usage: $(free | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100.0}')"
echo "Disk Usage: $(df -h / | awk 'NR==2{printf "%s", $5}')"
echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
echo

# Service Status
echo "=== Service Status ==="
docker-compose -f docker-compose.production.yml ps
echo

# Database Health
echo "=== Database Health ==="
if psql -U ms5_user -d factory_telemetry -c "SELECT version();" >/dev/null 2>&1; then
    echo "✓ Database connection successful"
    echo "Database size: $(psql -U ms5_user -d factory_telemetry -c "SELECT pg_size_pretty(pg_database_size('factory_telemetry'));" -t)"
    echo "Active connections: $(psql -U ms5_user -d factory_telemetry -c "SELECT count(*) FROM pg_stat_activity;" -t)"
else
    echo "✗ Database connection failed"
fi
echo

# API Health
echo "=== API Health ==="
if curl -s http://localhost:8000/health >/dev/null 2>&1; then
    echo "✓ API responding"
    echo "Response time: $(curl -w "%{time_total}" -o /dev/null -s http://localhost:8000/health)s"
else
    echo "✗ API not responding"
fi
echo

# Redis Health
echo "=== Redis Health ==="
if redis-cli ping >/dev/null 2>&1; then
    echo "✓ Redis responding"
    echo "Memory usage: $(redis-cli info memory | grep used_memory_human | cut -d: -f2)"
else
    echo "✗ Redis not responding"
fi
echo

# Network Connectivity
echo "=== Network Connectivity ==="
echo "Internet connectivity: $(ping -c 1 8.8.8.8 >/dev/null 2>&1 && echo "✓" || echo "✗")"
echo "DNS resolution: $(nslookup google.com >/dev/null 2>&1 && echo "✓" || echo "✗")"
echo

# Security Status
echo "=== Security Status ==="
echo "Firewall status: $(ufw status | head -1)"
echo "SSL certificate: $(openssl x509 -in /etc/ssl/certs/ms5.company.com.crt -noout -dates 2>/dev/null | grep notAfter | cut -d= -f2 || echo "Not found")"
echo

echo "Health check completed"
```

### Performance Monitoring
```bash
#!/bin/bash
# performance_monitor.sh

echo "=== Performance Monitoring ==="
echo "Date: $(date)"
echo

# Top processes by CPU
echo "=== Top CPU Processes ==="
ps aux --sort=-%cpu | head -10
echo

# Top processes by memory
echo "=== Top Memory Processes ==="
ps aux --sort=-%mem | head -10
echo

# Disk I/O
echo "=== Disk I/O ==="
iostat -x 1 1
echo

# Network I/O
echo "=== Network I/O ==="
iftop -t -s 5
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
    n_live_tup as live_tuples
FROM pg_stat_user_tables 
ORDER BY n_live_tup DESC 
LIMIT 10;"
echo

# Application metrics
echo "=== Application Metrics ==="
curl -s http://localhost:8000/metrics | grep -E "(http_requests_total|http_request_duration_seconds)" | head -20
echo
```

## Authentication Issues

### Login Problems

#### Symptoms
- "Invalid credentials" error
- "Account locked" message
- "Session expired" error
- Two-factor authentication failures

#### Diagnosis
```bash
# Check authentication logs
grep "Failed password" /var/log/auth.log | tail -20
grep "Invalid user" /var/log/auth.log | tail -20

# Check application logs
docker-compose -f docker-compose.production.yml logs backend | grep -i "auth\|login" | tail -20

# Check user account status
psql -U ms5_user -d factory_telemetry -c "
SELECT username, email, role, is_active, last_login, failed_login_attempts 
FROM users 
WHERE username = 'problematic_user';"
```

#### Solutions
1. **Invalid Credentials**
   ```bash
   # Reset user password
   curl -X POST "https://api.ms5.company.com/api/v1/admin/users/reset-password" \
     -H "Authorization: Bearer $ADMIN_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"username": "problematic_user", "new_password": "secure_password"}'
   ```

2. **Account Locked**
   ```bash
   # Unlock user account
   curl -X PUT "https://api.ms5.company.com/api/v1/admin/users/unlock" \
     -H "Authorization: Bearer $ADMIN_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"username": "locked_user"}'
   ```

3. **Session Issues**
   ```bash
   # Clear user sessions
   curl -X DELETE "https://api.ms5.company.com/api/v1/admin/users/sessions" \
     -H "Authorization: Bearer $ADMIN_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"username": "problematic_user"}'
   ```

### Permission Issues

#### Symptoms
- "Access denied" errors
- Missing features/buttons
- Cannot perform specific actions
- Role-based restrictions

#### Diagnosis
```bash
# Check user permissions
psql -U ms5_user -d factory_telemetry -c "
SELECT u.username, u.role, p.permission_name 
FROM users u 
JOIN user_permissions up ON u.id = up.user_id 
JOIN permissions p ON up.permission_id = p.id 
WHERE u.username = 'problematic_user';"

# Check role permissions
psql -U ms5_user -d factory_telemetry -c "
SELECT r.role_name, p.permission_name 
FROM roles r 
JOIN role_permissions rp ON r.id = rp.role_id 
JOIN permissions p ON rp.permission_id = p.id 
WHERE r.role_name = 'operator';"
```

#### Solutions
1. **Grant Missing Permissions**
   ```bash
   # Add permission to user
   curl -X POST "https://api.ms5.company.com/api/v1/admin/users/permissions" \
     -H "Authorization: Bearer $ADMIN_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"username": "user", "permission": "production:write"}'
   ```

2. **Update User Role**
   ```bash
   # Change user role
   curl -X PUT "https://api.ms5.company.com/api/v1/admin/users/role" \
     -H "Authorization: Bearer $ADMIN_TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"username": "user", "role": "production_manager"}'
   ```

## Database Problems

### Connection Issues

#### Symptoms
- "Database connection failed" errors
- Connection timeouts
- Connection pool exhaustion
- Database locks

#### Diagnosis
```bash
# Check PostgreSQL status
sudo systemctl status postgresql

# Check database connections
psql -U ms5_user -d factory_telemetry -c "SELECT * FROM pg_stat_activity;"

# Check connection limits
psql -U ms5_user -d factory_telemetry -c "SHOW max_connections;"

# Check database locks
psql -U ms5_user -d factory_telemetry -c "SELECT * FROM pg_locks WHERE NOT granted;"

# Check slow queries
psql -U ms5_user -d factory_telemetry -c "
SELECT query, mean_time, calls 
FROM pg_stat_statements 
ORDER BY mean_time DESC 
LIMIT 10;"
```

#### Solutions
1. **Connection Pool Exhaustion**
   ```python
   # Increase connection pool size
   # backend/app/database.py
   engine = create_engine(
       DATABASE_URL,
       pool_size=30,
       max_overflow=50,
       pool_pre_ping=True,
       pool_recycle=3600
   )
   ```

2. **Slow Queries**
   ```sql
   -- Create missing indexes
   CREATE INDEX CONCURRENTLY idx_production_lines_status ON production_lines(status);
   CREATE INDEX CONCURRENTLY idx_andon_events_created_at ON andon_events(created_at);
   CREATE INDEX CONCURRENTLY idx_oee_calculations_line_id_time ON oee_calculations(line_id, calculation_time);
   
   -- Update statistics
   ANALYZE;
   ```

3. **Database Locks**
   ```sql
   -- Kill blocking queries
   SELECT pg_terminate_backend(pid) 
   FROM pg_stat_activity 
   WHERE state = 'active' 
   AND query_start < NOW() - INTERVAL '5 minutes';
   ```

### Data Integrity Issues

#### Symptoms
- Data inconsistencies
- Missing records
- Duplicate entries
- Foreign key violations

#### Diagnosis
```bash
# Check database integrity
psql -U ms5_user -d factory_telemetry -c "SELECT * FROM pg_stat_database WHERE datname = 'factory_telemetry';"

# Check for orphaned records
psql -U ms5_user -d factory_telemetry -c "
SELECT COUNT(*) as orphaned_jobs 
FROM job_assignments ja 
LEFT JOIN production_schedules ps ON ja.schedule_id = ps.id 
WHERE ps.id IS NULL;"

# Check foreign key violations
psql -U ms5_user -d factory_telemetry -c "
SELECT conname, conrelid::regclass, confrelid::regclass 
FROM pg_constraint 
WHERE contype = 'f' AND NOT convalidated;"
```

#### Solutions
1. **Data Cleanup**
   ```sql
   -- Remove orphaned records
   DELETE FROM job_assignments 
   WHERE schedule_id NOT IN (SELECT id FROM production_schedules);
   
   -- Fix duplicate entries
   DELETE FROM production_lines 
   WHERE id NOT IN (
       SELECT MIN(id) 
       FROM production_lines 
       GROUP BY line_code
   );
   ```

2. **Data Validation**
   ```python
   # Implement data validation
   # backend/app/services/data_validation.py
   class DataValidator:
       @staticmethod
       def validate_production_line(data):
           required_fields = ['name', 'line_code']
           for field in required_fields:
               if field not in data or not data[field]:
                   raise ValidationError(f"Missing required field: {field}")
   ```

## API Performance Issues

### Response Time Problems

#### Symptoms
- Slow API responses (>2 seconds)
- Timeout errors
- High error rates
- Memory usage spikes

#### Diagnosis
```bash
# Check API response times
curl -w "@curl-format.txt" -o /dev/null -s http://localhost:8000/api/v1/health

# Check API metrics
curl -s http://localhost:8000/metrics | grep http_request

# Check backend logs
docker-compose -f docker-compose.production.yml logs backend | tail -100

# Check resource usage
docker stats --no-stream

# Check slow endpoints
curl -s http://localhost:8000/metrics | grep http_request_duration_seconds
```

#### Solutions
1. **Enable Caching**
   ```python
   # backend/app/services/cache_service.py
   @cache_result(ttl=300)
   def get_production_lines():
       # Implementation
   ```

2. **Database Query Optimization**
   ```python
   # Use database indexes
   # Optimize queries
   # Use connection pooling
   # Implement query caching
   ```

3. **Memory Management**
   ```bash
   # Monitor memory usage
   docker stats --no-stream
   
   # Restart services if memory usage is high
   docker-compose -f docker-compose.production.yml restart backend
   ```

### Error Rate Issues

#### Symptoms
- High 5xx error rates
- Frequent timeouts
- Service unavailability
- User complaints

#### Diagnosis
```bash
# Check error rates
curl -s http://localhost:8000/metrics | grep http_requests_total

# Check application logs
docker-compose -f docker-compose.production.yml logs backend | grep -i "error\|exception" | tail -20

# Check system resources
htop
free -h
df -h

# Check database performance
psql -U ms5_user -d factory_telemetry -c "SELECT * FROM pg_stat_activity;"
```

#### Solutions
1. **Error Handling**
   ```python
   # Implement proper error handling
   # backend/app/middleware/error_handler.py
   @app.exception_handler(Exception)
   async def global_exception_handler(request: Request, exc: Exception):
       logger.error(f"Unhandled exception: {exc}")
       return JSONResponse(
           status_code=500,
           content={"detail": "Internal server error"}
       )
   ```

2. **Resource Management**
   ```bash
   # Increase system resources
   # Optimize application configuration
   # Implement load balancing
   ```

## Frontend Troubleshooting

### Loading Issues

#### Symptoms
- Page won't load
- Blank screen
- JavaScript errors
- Styling issues

#### Diagnosis
```bash
# Check frontend container
docker-compose -f docker-compose.production.yml logs frontend

# Check frontend build
docker-compose -f docker-compose.production.yml exec frontend npm run build

# Check browser console
# Open browser developer tools (F12)
# Check Console tab for errors

# Check network requests
# Open browser developer tools (F12)
# Check Network tab for failed requests
```

#### Solutions
1. **Build Issues**
   ```bash
   # Rebuild frontend
   docker-compose -f docker-compose.production.yml build frontend
   
   # Clear npm cache
   docker-compose -f docker-compose.production.yml exec frontend npm cache clean --force
   
   # Reinstall dependencies
   docker-compose -f docker-compose.production.yml exec frontend npm install
   ```

2. **JavaScript Errors**
   ```javascript
   // Check for common issues:
   // - Missing dependencies
   // - Incorrect API calls
   // - State management issues
   // - Component lifecycle problems
   ```

### Performance Issues

#### Symptoms
- Slow page rendering
- High memory usage
- Browser crashes
- Poor user experience

#### Diagnosis
```bash
# Check frontend performance
# Use browser developer tools
# Check Performance tab
# Check Memory tab
# Check Network tab

# Check bundle size
docker-compose -f docker-compose.production.yml exec frontend npm run analyze
```

#### Solutions
1. **Code Splitting**
   ```javascript
   // Implement code splitting
   const LazyComponent = React.lazy(() => import('./LazyComponent'));
   ```

2. **Memory Management**
   ```javascript
   // Clean up event listeners
   // Remove unused components
   // Optimize state management
   ```

## WebSocket Connection Issues

### Connection Problems

#### Symptoms
- Real-time updates not working
- Connection drops frequently
- WebSocket handshake failures
- Data not syncing

#### Diagnosis
```bash
# Check WebSocket endpoint
curl -i -N -H "Connection: Upgrade" -H "Upgrade: websocket" -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: x3JJHMbDL1EzLkh9GBhXDw==" http://localhost:8000/ws/

# Check WebSocket logs
docker-compose -f docker-compose.production.yml logs backend | grep websocket

# Check network connectivity
ping localhost
telnet localhost 8000

# Check firewall rules
sudo ufw status
sudo iptables -L
```

#### Solutions
1. **Connection Drops**
   ```python
   # Implement reconnection logic
   # backend/app/services/websocket_manager.py
   class WebSocketManager:
       def __init__(self):
           self.reconnect_interval = 5
           self.max_reconnect_attempts = 10
   ```

2. **Handshake Failures**
   ```bash
   # Check CORS settings
   # backend/app/config.py
   CORS_ORIGINS = ["http://localhost:3000", "https://yourdomain.com"]
   ```

## PLC Integration Problems

### Connectivity Issues

#### Symptoms
- PLC data not updating
- Connection timeouts to PLC
- Data format errors
- Communication failures

#### Diagnosis
```bash
# Check PLC connectivity
./scripts/plc_connectivity_test.py

# Check PLC driver logs
docker-compose -f docker-compose.production.yml logs backend | grep plc

# Check network connectivity to PLC
ping <PLC_IP_ADDRESS>
telnet <PLC_IP_ADDRESS> <PLC_PORT>

# Check PLC driver status
curl -s http://localhost:8000/api/v1/plc/status | jq .
```

#### Solutions
1. **Network Connectivity**
   ```bash
   # Check network configuration
   ip route show
   ip addr show
   
   # Test PLC connection
   nc -zv <PLC_IP_ADDRESS> <PLC_PORT>
   ```

2. **Driver Issues**
   ```python
   # Check PLC driver configuration
   # backend/app/services/plc_drivers/
   # Verify driver parameters
   # Check data format compatibility
   ```

## Security Issues

### Authentication Attacks

#### Symptoms
- Unauthorized access attempts
- Security alerts
- Failed authentication
- Suspicious activity

#### Diagnosis
```bash
# Check authentication logs
grep "Failed password" /var/log/auth.log
grep "Invalid user" /var/log/auth.log

# Check application logs
docker-compose -f docker-compose.production.yml logs backend | grep -i "auth\|security\|error"

# Check system logs
grep -i "error\|warning\|critical" /var/log/syslog | tail -20

# Run security scan
./scripts/security_scanner.sh
```

#### Solutions
1. **Brute Force Attacks**
   ```bash
   # Block suspicious IPs
   sudo ufw deny from <SUSPICIOUS_IP>
   
   # Enable fail2ban
   sudo apt install fail2ban
   sudo systemctl enable fail2ban
   sudo systemctl start fail2ban
   ```

2. **Security Vulnerabilities**
   ```bash
   # Update system packages
   sudo apt update && sudo apt upgrade
   
   # Update application dependencies
   docker-compose -f docker-compose.production.yml build --no-cache
   ```

## Performance Optimization

### System Optimization

#### Symptoms
- Slow system response
- High CPU usage
- Memory consumption issues
- Disk I/O bottlenecks

#### Diagnosis
```bash
# Check system performance
htop
iotop
nethogs

# Check application performance
docker stats --no-stream

# Check database performance
psql -U ms5_user -d factory_telemetry -c "SELECT * FROM pg_stat_activity;"
```

#### Solutions
1. **Database Optimization**
   ```sql
   -- Create indexes
   CREATE INDEX CONCURRENTLY idx_production_lines_status ON production_lines(status);
   
   -- Optimize queries
   EXPLAIN ANALYZE SELECT * FROM production_lines WHERE status = 'running';
   
   -- Update statistics
   ANALYZE;
   ```

2. **System Optimization**
   ```bash
   # Optimize system parameters
   echo 'vm.swappiness=10' >> /etc/sysctl.conf
   echo 'vm.dirty_ratio=15' >> /etc/sysctl.conf
   sysctl -p
   ```

## Network Connectivity

### Connection Issues

#### Symptoms
- Cannot connect to external services
- DNS resolution failures
- Network timeouts
- Intermittent connectivity

#### Diagnosis
```bash
# Check network connectivity
ping -c 4 8.8.8.8
ping -c 4 google.com

# Check DNS resolution
nslookup google.com
dig google.com

# Check network interfaces
ip addr show
ip route show

# Check network statistics
netstat -i
ss -tuln
```

#### Solutions
1. **DNS Issues**
   ```bash
   # Check DNS configuration
   cat /etc/resolv.conf
   
   # Test different DNS servers
   nslookup google.com 8.8.8.8
   ```

2. **Network Configuration**
   ```bash
   # Check network configuration
   ip route show
   ip addr show
   
   # Restart network services
   sudo systemctl restart networking
   ```

## Emergency Procedures

### Critical System Failure

#### Immediate Actions
1. **Assess Impact**
   - Determine affected systems
   - Identify affected users
   - Estimate downtime

2. **Activate Emergency Response**
   - Contact emergency support
   - Notify stakeholders
   - Document incident

3. **Implement Workarounds**
   - Use backup systems
   - Implement manual processes
   - Provide alternative access

#### Recovery Procedures
```bash
#!/bin/bash
# emergency_recovery.sh

echo "=== Emergency Recovery - $(date) ==="

# 1. Stop all services
docker-compose -f docker-compose.production.yml stop

# 2. Check system health
./health_check.sh

# 3. Restore from backup
./restore_database.sh /backups/database/latest_backup.dump
./restore_application.sh /backups/application/latest_backup.tar.gz

# 4. Restart services
docker-compose -f docker-compose.production.yml up -d

# 5. Verify recovery
./health_check.sh

echo "Emergency recovery completed"
```

### Data Loss Prevention

#### Backup Verification
```bash
#!/bin/bash
# verify_backups.sh

echo "=== Backup Verification - $(date) ==="

# Check backup files
ls -la /backups/database/
ls -la /backups/application/

# Verify backup integrity
for backup in /backups/database/*.dump; do
    if pg_restore --list "$backup" > /dev/null 2>&1; then
        echo "✓ $backup is valid"
    else
        echo "✗ $backup is corrupted"
    fi
done

echo "Backup verification completed"
```

## Preventive Maintenance

### Daily Tasks
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

### Weekly Tasks
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

### Monthly Tasks
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

---

*This troubleshooting guide is updated regularly. For the latest version, please check the system documentation portal.*
