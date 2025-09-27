# MS5.0 Floor Dashboard - Troubleshooting Guide

## Table of Contents
1. [Overview](#overview)
2. [Common Issues](#common-issues)
3. [Authentication Problems](#authentication-problems)
4. [Database Issues](#database-issues)
5. [API Problems](#api-problems)
6. [Frontend Issues](#frontend-issues)
7. [WebSocket Issues](#websocket-issues)
8. [Performance Issues](#performance-issues)
9. [Network Issues](#network-issues)
10. [System Monitoring](#system-monitoring)
11. [Emergency Procedures](#emergency-procedures)
12. [Support Resources](#support-resources)

## Overview

This troubleshooting guide provides comprehensive solutions for common issues encountered with the MS5.0 Floor Dashboard system. The guide is organized by component and includes step-by-step solutions, diagnostic commands, and preventive measures.

### Diagnostic Tools
- **System Health Check**: `./scripts/health_check.sh`
- **Database Test**: `./scripts/test_database.py`
- **API Test**: `./scripts/test_api_endpoints.sh`
- **Performance Monitor**: `./scripts/performance_monitor.py`
- **Log Analyzer**: `./scripts/log_analyzer.py`

## Common Issues

### Application Won't Start

#### Symptoms
- Docker containers fail to start
- Application returns 502/503 errors
- System appears unresponsive

#### Diagnosis
```bash
# Check Docker status
docker-compose -f docker-compose.production.yml ps

# Check container logs
docker-compose -f docker-compose.production.yml logs backend
docker-compose -f docker-compose.production.yml logs postgres
docker-compose -f docker-compose.production.yml logs redis

# Check system resources
htop
df -h
free -h

# Check port availability
netstat -tulpn | grep :8000
netstat -tulpn | grep :5432
netstat -tulpn | grep :6379
```

#### Solutions

**Insufficient Resources**
```bash
# Check memory usage
free -h
# If memory is low, restart services or add more RAM

# Check disk space
df -h
# If disk is full, clean up logs or expand storage
```

**Port Conflicts**
```bash
# Find process using port
sudo lsof -i :8000
sudo lsof -i :5432
sudo lsof -i :6379

# Kill conflicting process
sudo kill -9 <PID>
```

**Configuration Issues**
```bash
# Validate environment variables
docker-compose -f docker-compose.production.yml config

# Check database connectivity
docker-compose -f docker-compose.production.yml exec backend python scripts/test_database.py

# Restart services
docker-compose -f docker-compose.production.yml restart
```

### Database Connection Failed

#### Symptoms
- "Database connection failed" errors
- API returns 500 errors
- Application logs show database errors

#### Diagnosis
```bash
# Check PostgreSQL status
sudo systemctl status postgresql

# Test database connection
docker-compose -f docker-compose.production.yml exec backend python scripts/test_database.py

# Check database logs
sudo tail -f /var/log/postgresql/postgresql-13-main.log

# Check connection limits
docker-compose -f docker-compose.production.yml exec postgres psql -U ms5_user -d factory_telemetry -c "SELECT count(*) FROM pg_stat_activity;"
```

#### Solutions

**PostgreSQL Service Down**
```bash
# Start PostgreSQL service
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Check service status
sudo systemctl status postgresql
```

**Connection Limit Exceeded**
```bash
# Check active connections
docker-compose -f docker-compose.production.yml exec postgres psql -U ms5_user -d factory_telemetry -c "SELECT count(*) FROM pg_stat_activity;"

# Kill idle connections
docker-compose -f docker-compose.production.yml exec postgres psql -U ms5_user -d factory_telemetry -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE state = 'idle' AND state_change < now() - interval '5 minutes';"
```

**Database Corrupted**
```bash
# Check database integrity
docker-compose -f docker-compose.production.yml exec postgres psql -U ms5_user -d factory_telemetry -c "SELECT pg_database.datname, pg_size_pretty(pg_database_size(pg_database.datname)) AS size FROM pg_database;"

# Restore from backup if needed
./scripts/restore.sh backup_file.sql
```

### Redis Connection Failed

#### Symptoms
- Cache operations fail
- Session management issues
- "Redis connection refused" errors

#### Diagnosis
```bash
# Check Redis status
sudo systemctl status redis

# Test Redis connection
docker-compose -f docker-compose.production.yml exec backend python scripts/test_redis.py

# Check Redis logs
sudo tail -f /var/log/redis/redis-server.log

# Test Redis operations
redis-cli ping
redis-cli info memory
```

#### Solutions

**Redis Service Down**
```bash
# Start Redis service
sudo systemctl start redis
sudo systemctl enable redis

# Check Redis configuration
sudo vim /etc/redis/redis.conf
```

**Memory Issues**
```bash
# Check Redis memory usage
redis-cli info memory

# Clear Redis cache if needed
redis-cli FLUSHALL

# Adjust memory limits
sudo vim /etc/redis/redis.conf
# maxmemory 512mb
# maxmemory-policy allkeys-lru
```

## Authentication Problems

### Login Issues

#### Symptoms
- "Invalid credentials" errors
- Users cannot log in
- Authentication timeout errors

#### Diagnosis
```bash
# Check authentication logs
docker-compose -f docker-compose.production.yml logs backend | grep -i auth

# Test authentication endpoint
curl -X POST https://api.company.com/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"test"}'

# Check user accounts
docker-compose -f docker-compose.production.yml exec backend python scripts/check_users.py
```

#### Solutions

**Invalid Credentials**
```bash
# Reset user password
docker-compose -f docker-compose.production.yml exec backend python scripts/reset_password.py --username <username> --new-password <new_password>

# Check user account status
docker-compose -f docker-compose.production.yml exec postgres psql -U ms5_user -d factory_telemetry -c "SELECT username, email, is_active FROM factory_telemetry.users WHERE username = '<username>';"
```

**Token Issues**
```bash
# Check token configuration
grep -r "SECRET_KEY\|ALGORITHM" backend/.env

# Clear expired tokens
docker-compose -f docker-compose.production.yml exec backend python scripts/cleanup_tokens.py
```

### Permission Issues

#### Symptoms
- "Access denied" errors
- Users cannot access certain features
- Role-based restrictions not working

#### Diagnosis
```bash
# Check user roles and permissions
docker-compose -f docker-compose.production.yml exec postgres psql -U ms5_user -d factory_telemetry -c "SELECT u.username, u.role, p.permission FROM factory_telemetry.users u LEFT JOIN factory_telemetry.user_permissions p ON u.id = p.user_id WHERE u.username = '<username>';"

# Check permission configuration
docker-compose -f docker-compose.production.yml exec backend python scripts/check_permissions.py
```

#### Solutions

**Update User Permissions**
```bash
# Grant additional permissions
docker-compose -f docker-compose.production.yml exec postgres psql -U ms5_user -d factory_telemetry -c "INSERT INTO factory_telemetry.user_permissions (user_id, permission) VALUES ('<user_id>', '<permission>');"

# Update user role
docker-compose -f docker-compose.production.yml exec postgres psql -U ms5_user -d factory_telemetry -c "UPDATE factory_telemetry.users SET role = '<new_role>' WHERE id = '<user_id>';"
```

## Database Issues

### Slow Queries

#### Symptoms
- API responses are slow
- Database CPU usage is high
- Query timeouts

#### Diagnosis
```bash
# Check slow queries
docker-compose -f docker-compose.production.yml exec postgres psql -U ms5_user -d factory_telemetry -c "SELECT query, calls, total_time, mean_time FROM pg_stat_statements ORDER BY mean_time DESC LIMIT 10;"

# Check database locks
docker-compose -f docker-compose.production.yml exec postgres psql -U ms5_user -d factory_telemetry -c "SELECT pid, state, query FROM pg_stat_activity WHERE state = 'active';"

# Check table sizes
docker-compose -f docker-compose.production.yml exec postgres psql -U ms5_user -d factory_telemetry -c "SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size FROM pg_tables WHERE schemaname = 'factory_telemetry' ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;"
```

#### Solutions

**Optimize Queries**
```bash
# Run query optimization
docker-compose -f docker-compose.production.yml exec backend python scripts/optimize_queries.py

# Update table statistics
docker-compose -f docker-compose.production.yml exec postgres psql -U ms5_user -d factory_telemetry -c "ANALYZE;"

# Rebuild indexes
docker-compose -f docker-compose.production.yml exec postgres psql -U ms5_user -d factory_telemetry -c "REINDEX DATABASE factory_telemetry;"
```

**Database Maintenance**
```bash
# Vacuum database
docker-compose -f docker-compose.production.yml exec postgres psql -U ms5_user -d factory_telemetry -c "VACUUM ANALYZE;"

# Check for dead tuples
docker-compose -f docker-compose.production.yml exec postgres psql -U ms5_user -d factory_telemetry -c "SELECT schemaname, tablename, n_dead_tup, n_live_tup FROM pg_stat_user_tables WHERE n_dead_tup > 1000;"
```

### Database Corruption

#### Symptoms
- Data inconsistency errors
- Query failures
- Database crashes

#### Diagnosis
```bash
# Check database integrity
docker-compose -f docker-compose.production.yml exec postgres psql -U ms5_user -d factory_telemetry -c "SELECT pg_database.datname, pg_database_size(pg_database.datname) FROM pg_database;"

# Check for corrupted tables
docker-compose -f docker-compose.production.yml exec postgres psql -U ms5_user -d factory_telemetry -c "SELECT relname, pg_relation_size(oid) FROM pg_class WHERE relkind = 'r' ORDER BY pg_relation_size(oid) DESC;"
```

#### Solutions

**Restore from Backup**
```bash
# Stop application services
docker-compose -f docker-compose.production.yml stop backend

# Restore database
docker-compose -f docker-compose.production.yml exec postgres psql -U ms5_user -d factory_telemetry < backup_file.sql

# Restart services
docker-compose -f docker-compose.production.yml start backend
```

## API Problems

### High Response Times

#### Symptoms
- API requests take > 5 seconds
- Timeout errors
- User complaints about slow performance

#### Diagnosis
```bash
# Check API response times
curl -w "@curl-format.txt" -o /dev/null -s "https://api.company.com/api/v1/health"

# Monitor API logs
docker-compose -f docker-compose.production.yml logs backend | grep -i "slow\|timeout\|error"

# Check system resources
htop
iostat 1
```

#### Solutions

**Optimize Database Queries**
```bash
# Run database optimization
docker-compose -f docker-compose.production.yml exec backend python scripts/optimize_database.py

# Enable query caching
docker-compose -f docker-compose.production.yml exec backend python scripts/enable_caching.py
```

**Scale Application**
```bash
# Increase backend instances
docker-compose -f docker-compose.production.yml up -d --scale backend=3

# Configure load balancing
# Update nginx configuration for multiple backend instances
```

### API Errors

#### Symptoms
- 500 Internal Server Error
- 400 Bad Request errors
- API endpoint failures

#### Diagnosis
```bash
# Check API logs
docker-compose -f docker-compose.production.yml logs backend | tail -100

# Test specific endpoints
curl -v https://api.company.com/api/v1/production/lines
curl -v https://api.company.com/api/v1/auth/profile

# Check error patterns
docker-compose -f docker-compose.production.yml logs backend | grep -i "error\|exception\|traceback"
```

#### Solutions

**Code Issues**
```bash
# Check application logs for specific errors
docker-compose -f docker-compose.production.yml logs backend | grep -A 10 -B 10 "ERROR"

# Restart application with fresh logs
docker-compose -f docker-compose.production.yml restart backend
```

**Configuration Issues**
```bash
# Validate environment configuration
docker-compose -f docker-compose.production.yml config

# Check configuration files
cat backend/.env | grep -v "^#" | grep -v "^$"
```

## Frontend Issues

### Application Won't Load

#### Symptoms
- Blank screen
- "Loading..." indefinitely
- JavaScript errors

#### Diagnosis
```bash
# Check frontend files
ls -la /var/www/html/

# Check Nginx configuration
sudo nginx -t

# Check browser console for errors
# Open browser developer tools and check console tab
```

#### Solutions

**Missing Files**
```bash
# Rebuild and deploy frontend
cd frontend
npm run build:production
sudo cp -r build/* /var/www/html/
sudo chown -R www-data:www-data /var/www/html/
```

**Nginx Configuration**
```bash
# Test Nginx configuration
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx

# Check Nginx logs
sudo tail -f /var/log/nginx/error.log
```

### Performance Issues

#### Symptoms
- Slow page loading
- Unresponsive interface
- High memory usage

#### Diagnosis
```bash
# Check frontend bundle size
ls -lh /var/www/html/static/js/
ls -lh /var/www/html/static/css/

# Monitor browser performance
# Use browser developer tools Performance tab
```

#### Solutions

**Optimize Assets**
```bash
# Enable gzip compression in Nginx
sudo vim /etc/nginx/sites-available/ms5-dashboard

# Add to server block:
gzip on;
gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
```

**Cache Optimization**
```bash
# Update Nginx cache headers
sudo vim /etc/nginx/sites-available/ms5-dashboard

# Add cache headers for static assets
location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

## WebSocket Issues

### Connection Failures

#### Symptoms
- Real-time updates not working
- WebSocket connection errors
- Reconnection loops

#### Diagnosis
```bash
# Test WebSocket connection
wscat -c wss://api.company.com/ws

# Check WebSocket logs
docker-compose -f docker-compose.production.yml logs backend | grep -i websocket

# Monitor WebSocket connections
docker-compose -f docker-compose.production.yml exec backend python scripts/monitor_websockets.py
```

#### Solutions

**Nginx Configuration**
```bash
# Check WebSocket proxy configuration
grep -A 10 "location /ws" /etc/nginx/sites-available/ms5-dashboard

# Ensure proper WebSocket headers are set
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
```

**Application Issues**
```bash
# Restart backend service
docker-compose -f docker-compose.production.yml restart backend

# Check WebSocket manager status
docker-compose -f docker-compose.production.yml exec backend python scripts/check_websockets.py
```

### Message Delivery Issues

#### Symptoms
- Messages not received
- Delayed message delivery
- Message ordering issues

#### Diagnosis
```bash
# Check WebSocket message queue
docker-compose -f docker-compose.production.yml exec backend python scripts/check_message_queue.py

# Monitor message delivery
docker-compose -f docker-compose.production.yml logs backend | grep -i "message\|broadcast"
```

#### Solutions

**Queue Management**
```bash
# Clear message queue
docker-compose -f docker-compose.production.yml exec backend python scripts/clear_message_queue.py

# Restart WebSocket manager
docker-compose -f docker-compose.production.yml exec backend python scripts/restart_websocket_manager.py
```

## Performance Issues

### High CPU Usage

#### Symptoms
- System becomes unresponsive
- High CPU utilization
- Slow response times

#### Diagnosis
```bash
# Check CPU usage
htop
top -p $(pgrep -d',' -f "python\|postgres\|redis\|nginx")

# Check process details
ps aux --sort=-%cpu | head -10

# Monitor system load
uptime
cat /proc/loadavg
```

#### Solutions

**Optimize Application**
```bash
# Check for infinite loops or inefficient code
docker-compose -f docker-compose.production.yml logs backend | grep -i "cpu\|loop\|infinite"

# Restart services
docker-compose -f docker-compose.production.yml restart
```

**Scale Resources**
```bash
# Increase CPU limits in Docker
# Update docker-compose.production.yml
# Add resource limits:
# deploy:
#   resources:
#     limits:
#       cpus: '2.0'
#       memory: 4G
```

### High Memory Usage

#### Symptoms
- System runs out of memory
- Swap usage increases
- Out of memory errors

#### Diagnosis
```bash
# Check memory usage
free -h
cat /proc/meminfo

# Check process memory usage
ps aux --sort=-%mem | head -10

# Check for memory leaks
docker stats
```

#### Solutions

**Memory Optimization**
```bash
# Restart services to clear memory
docker-compose -f docker-compose.production.yml restart

# Check for memory leaks
docker-compose -f docker-compose.production.yml exec backend python scripts/check_memory_leaks.py

# Increase memory limits
# Update docker-compose.production.yml with higher memory limits
```

### Disk Space Issues

#### Symptoms
- "No space left on device" errors
- Log rotation failures
- Database write failures

#### Diagnosis
```bash
# Check disk usage
df -h
du -sh /opt/ms5-dashboard/*
du -sh /var/log/*

# Find large files
find /opt/ms5-dashboard -type f -size +100M
find /var/log -type f -size +100M
```

#### Solutions

**Clean Up Space**
```bash
# Clean Docker images and containers
docker system prune -a

# Clean application logs
find /opt/ms5-dashboard/logs -name "*.log" -mtime +30 -delete

# Clean system logs
sudo journalctl --vacuum-time=30d

# Clean old backups
find /opt/ms5-dashboard/backups -name "*.sql" -mtime +30 -delete
```

## Network Issues

### Connectivity Problems

#### Symptoms
- API requests fail
- Database connection timeouts
- External service failures

#### Diagnosis
```bash
# Test network connectivity
ping google.com
ping api.company.com

# Check DNS resolution
nslookup api.company.com
dig api.company.com

# Test specific ports
telnet api.company.com 443
telnet database.company.com 5432
```

#### Solutions

**DNS Issues**
```bash
# Check DNS configuration
cat /etc/resolv.conf

# Update DNS servers
sudo vim /etc/resolv.conf
# nameserver 8.8.8.8
# nameserver 8.8.4.4
```

**Firewall Issues**
```bash
# Check firewall status
sudo ufw status
sudo firewall-cmd --list-all

# Allow required ports
sudo ufw allow 443/tcp
sudo ufw allow 80/tcp
```

### SSL/TLS Issues

#### Symptoms
- SSL certificate errors
- HTTPS connection failures
- Mixed content warnings

#### Diagnosis
```bash
# Check SSL certificate
openssl x509 -in /opt/ms5-dashboard/ssl/cert.pem -text -noout

# Test SSL connection
openssl s_client -connect api.company.com:443 -servername api.company.com

# Check certificate expiration
echo | openssl s_client -connect api.company.com:443 2>/dev/null | openssl x509 -noout -dates
```

#### Solutions

**Certificate Issues**
```bash
# Renew Let's Encrypt certificate
sudo certbot renew

# Update certificate files
sudo cp /etc/letsencrypt/live/api.company.com/fullchain.pem /opt/ms5-dashboard/ssl/cert.pem
sudo cp /etc/letsencrypt/live/api.company.com/privkey.pem /opt/ms5-dashboard/ssl/key.pem

# Restart Nginx
sudo systemctl restart nginx
```

## System Monitoring

### Health Checks

#### Automated Health Monitoring
```bash
# Run comprehensive health check
./scripts/health_check.sh

# Check specific components
./scripts/test_database.py
./scripts/test_redis.py
./scripts/test_api_endpoints.sh
./scripts/test_websockets.py
```

#### Manual Health Checks
```bash
# Check service status
docker-compose -f docker-compose.production.yml ps

# Check system resources
htop
df -h
free -h

# Check application logs
docker-compose -f docker-compose.production.yml logs --tail=100 backend
```

### Monitoring Tools

#### Prometheus Metrics
```bash
# Check Prometheus status
curl http://localhost:9090/api/v1/query?query=up

# View metrics in Grafana
# Access http://dashboard.company.com:3000
```

#### Log Analysis
```bash
# Analyze error logs
docker-compose -f docker-compose.production.yml logs backend | grep -i error | tail -50

# Check access logs
sudo tail -f /var/log/nginx/access.log

# Monitor system logs
sudo journalctl -f -u nginx
sudo journalctl -f -u postgresql
```

## Emergency Procedures

### System Recovery

#### Complete System Failure
```bash
# 1. Assess damage
./scripts/health_check.sh

# 2. Stop all services
docker-compose -f docker-compose.production.yml down

# 3. Restore from backup
./scripts/restore.sh latest_backup.sql

# 4. Restart services
docker-compose -f docker-compose.production.yml up -d

# 5. Verify recovery
./scripts/health_check.sh
```

#### Database Recovery
```bash
# 1. Stop application services
docker-compose -f docker-compose.production.yml stop backend

# 2. Restore database
docker-compose -f docker-compose.production.yml exec postgres psql -U ms5_user -d factory_telemetry < backup_file.sql

# 3. Restart services
docker-compose -f docker-compose.production.yml start backend

# 4. Verify data integrity
docker-compose -f docker-compose.production.yml exec backend python scripts/verify_data_integrity.py
```

#### Application Recovery
```bash
# 1. Rollback to previous version
git checkout previous_stable_tag

# 2. Rebuild and redeploy
docker-compose -f docker-compose.production.yml down
docker-compose -f docker-compose.production.yml build
docker-compose -f docker-compose.production.yml up -d

# 3. Verify deployment
./scripts/health_check.sh
```

### Data Recovery

#### Backup Restoration
```bash
# List available backups
ls -la /opt/ms5-dashboard/backups/

# Restore specific backup
./scripts/restore.sh backup_2024_01_15.sql

# Verify restoration
docker-compose -f docker-compose.production.yml exec backend python scripts/verify_data_integrity.py
```

#### Partial Data Recovery
```bash
# Restore specific table
docker-compose -f docker-compose.production.yml exec postgres psql -U ms5_user -d factory_telemetry -c "\\copy factory_telemetry.production_lines FROM '/opt/ms5-dashboard/backups/production_lines_backup.csv' CSV HEADER;"

# Verify table data
docker-compose -f docker-compose.production.yml exec postgres psql -U ms5_user -d factory_telemetry -c "SELECT COUNT(*) FROM factory_telemetry.production_lines;"
```

## Support Resources

### Internal Support

#### Escalation Procedures
1. **Level 1**: Operator/User issues
   - Check user guide and FAQ
   - Contact local supervisor
   - Submit support ticket

2. **Level 2**: System issues
   - Contact system administrator
   - Check system logs
   - Run diagnostic scripts

3. **Level 3**: Critical issues
   - Contact development team
   - Implement emergency procedures
   - Coordinate with vendor support

#### Contact Information
- **Help Desk**: support@company.com
- **System Administrator**: admin@company.com
- **Database Administrator**: dba@company.com
- **Emergency Contact**: +1-555-0123

### External Support

#### Vendor Support
- **Application Vendor**: vendor@company.com
- **Database Vendor**: postgresql-support@company.com
- **Infrastructure Vendor**: infrastructure@company.com

#### Documentation Resources
- **User Guide**: `/docs/USER_GUIDE.md`
- **API Documentation**: `/docs/API_DOCUMENTATION.md`
- **Deployment Guide**: `/docs/DEPLOYMENT_GUIDE.md`
- **System Architecture**: `/docs/ARCHITECTURE.md`

### Training and Knowledge Base

#### Training Materials
- **User Training Videos**: Available in application
- **System Administration Guide**: Internal wiki
- **Troubleshooting Procedures**: This document
- **Emergency Response Plan**: Internal procedures

#### Knowledge Base
- **Common Issues**: Internal wiki
- **Solutions Database**: Internal knowledge base
- **Best Practices**: Internal documentation
- **Lessons Learned**: Post-incident reports

---

*This troubleshooting guide is updated regularly. For the latest version, please check the project repository.*
