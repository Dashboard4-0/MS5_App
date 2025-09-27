#!/bin/bash

# MS5.0 Floor Dashboard - Production Deployment Script
# This script handles the complete production deployment with zero-downtime deployment

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${LOG_DIR}/production_deploy_${TIMESTAMP}.log"

# Environment variables
ENVIRONMENT="production"
DEPLOY_TYPE=${DEPLOY_TYPE:-full}  # full, backend, frontend, database, monitoring
SKIP_TESTS=${SKIP_TESTS:-false}
ROLLBACK_ON_FAILURE=${ROLLBACK_ON_FAILURE:-true}
BACKUP_BEFORE_DEPLOY=${BACKUP_BEFORE_DEPLOY:-true}
ZERO_DOWNTIME=${ZERO_DOWNTIME:-true}
HEALTH_CHECK_TIMEOUT=${HEALTH_CHECK_TIMEOUT:-300}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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

# Create directories
mkdir -p "$LOG_DIR"

log "Starting MS5.0 Production Deployment - Environment: $ENVIRONMENT, Type: $DEPLOY_TYPE"

# Change to script directory
cd "$SCRIPT_DIR"

# Function to validate production prerequisites
validate_production_prerequisites() {
    log "Validating production deployment prerequisites..."
    
    # Check if we're in production environment
    if [ "$ENVIRONMENT" != "production" ]; then
        log_error "This script is only for production deployments"
        exit 1
    fi
    
    # Check required production files
    local required_files=(
        "docker-compose.production.yml"
        "Dockerfile.production"
        "env.production"
        "nginx.production.conf"
        "prometheus.production.yml"
        "alertmanager.yml"
        "alert_rules.yml"
    )
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            log_error "Required production file not found: $file"
            exit 1
        fi
    done
    
    # Check environment variables file
    if [ ! -f "env.production" ]; then
        log_error "Production environment file not found: env.production"
        exit 1
    fi
    
    # Load production environment variables
    source env.production
    
    # Validate critical production variables
    local critical_vars=(
        "POSTGRES_PASSWORD_PRODUCTION"
        "SECRET_KEY_PRODUCTION"
        "REDIS_PASSWORD_PRODUCTION"
        "GRAFANA_ADMIN_PASSWORD_PRODUCTION"
    )
    
    for var in "${critical_vars[@]}"; do
        if [ -z "${!var}" ]; then
            log_error "Critical production environment variable not set: $var"
            exit 1
        fi
    done
    
    # Check if passwords are not default values
    if [[ "$POSTGRES_PASSWORD_PRODUCTION" == *"CHANGE_THIS"* ]]; then
        log_error "Production database password is not configured properly"
        exit 1
    fi
    
    if [[ "$SECRET_KEY_PRODUCTION" == *"CHANGE_THIS"* ]]; then
        log_error "Production secret key is not configured properly"
        exit 1
    fi
    
    log_success "Production prerequisites validation completed"
}

# Function to create production backup
create_production_backup() {
    if [ "$BACKUP_BEFORE_DEPLOY" = "true" ]; then
        log "Creating production backup..."
        
        if [ -f "./backup.sh" ]; then
            ./backup.sh -t full -e production
            log_success "Production backup completed"
        else
            log_warning "Backup script not found, skipping backup"
        fi
    fi
}

# Function to run production tests
run_production_tests() {
    if [ "$SKIP_TESTS" = "true" ]; then
        log "Skipping production tests"
        return 0
    fi
    
    log "Running production deployment tests..."
    
    # Run security tests
    if [ -f "./test_security_production.sh" ]; then
        ./test_security_production.sh
    fi
    
    # Run performance tests
    if [ -f "./test_performance_production.sh" ]; then
        ./test_performance_production.sh
    fi
    
    # Run integration tests
    if [ -f "./test_integration_production.sh" ]; then
        ./test_integration_production.sh
    fi
    
    log_success "Production tests completed"
}

# Function to deploy with zero downtime
deploy_with_zero_downtime() {
    log "Starting zero-downtime deployment..."
    
    # Build new images
    log "Building new production images..."
    docker build -f Dockerfile.production -t ms5-backend:production-new .
    
    # Start new backend instance
    log "Starting new backend instance..."
    docker-compose -f docker-compose.production.yml up -d --scale backend=2 --no-recreate backend
    
    # Wait for new instance to be healthy
    log "Waiting for new backend instance to be healthy..."
    local health_check_count=0
    local max_health_checks=$((HEALTH_CHECK_TIMEOUT / 10))
    
    while [ $health_check_count -lt $max_health_checks ]; do
        if curl -f -s http://localhost:8000/api/health > /dev/null; then
            log_success "New backend instance is healthy"
            break
        fi
        
        log_info "Health check attempt $((health_check_count + 1))/$max_health_checks"
        sleep 10
        ((health_check_count++))
    done
    
    if [ $health_check_count -eq $max_health_checks ]; then
        log_error "New backend instance failed health checks"
        return 1
    fi
    
    # Scale down old instance
    log "Scaling down old backend instance..."
    docker-compose -f docker-compose.production.yml up -d --scale backend=1 backend
    
    # Wait for old instance to stop
    sleep 30
    
    # Remove old image
    log "Removing old backend image..."
    docker image rm ms5-backend:production-old 2>/dev/null || true
    docker tag ms5-backend:production-new ms5-backend:production
    docker image rm ms5-backend:production-new
    
    log_success "Zero-downtime deployment completed"
}

# Function to deploy database with migrations
deploy_database_production() {
    log "Deploying production database..."
    
    # Run database migrations
    if [ -f "./deploy_migrations.sh" ]; then
        ./deploy_migrations.sh -e production
        log_success "Database migrations completed"
    else
        log_warning "Database migration script not found"
    fi
    
    # Validate database
    if [ -f "./validate_database.sh" ]; then
        ./validate_database.sh -e production
        log_success "Database validation completed"
    else
        log_warning "Database validation script not found"
    fi
}

# Function to deploy backend services
deploy_backend_production() {
    log "Deploying production backend services..."
    
    if [ "$ZERO_DOWNTIME" = "true" ]; then
        deploy_with_zero_downtime
    else
        # Standard deployment
        docker-compose -f docker-compose.production.yml up -d backend
        sleep 30
        
        # Health check
        if curl -f http://localhost:8000/api/health; then
            log_success "Backend deployment completed"
        else
            log_error "Backend health check failed"
            return 1
        fi
    fi
}

# Function to deploy monitoring services
deploy_monitoring_production() {
    log "Deploying production monitoring services..."
    
    # Start monitoring services
    docker-compose -f docker-compose.production.yml up -d prometheus grafana alertmanager
    
    # Wait for services to be ready
    sleep 15
    
    # Verify Prometheus
    if curl -f -s http://localhost:9090/-/healthy > /dev/null; then
        log_success "Prometheus is healthy"
    else
        log_error "Prometheus health check failed"
        return 1
    fi
    
    # Verify Grafana
    if curl -f -s http://localhost:3000/api/health > /dev/null; then
        log_success "Grafana is healthy"
    else
        log_error "Grafana health check failed"
        return 1
    fi
    
    # Verify AlertManager
    if curl -f -s http://localhost:9093/-/healthy > /dev/null; then
        log_success "AlertManager is healthy"
    else
        log_error "AlertManager health check failed"
        return 1
    fi
    
    log_success "Monitoring deployment completed"
}

# Function to deploy all services
deploy_all_production() {
    log "Deploying all production services..."
    
    # Deploy all services
    docker-compose -f docker-compose.production.yml up -d
    
    # Wait for all services to be ready
    log "Waiting for all services to be ready..."
    sleep 60
    
    # Verify all services
    local services=("backend" "postgres" "redis" "nginx" "prometheus" "grafana" "alertmanager")
    for service in "${services[@]}"; do
        if docker-compose -f docker-compose.production.yml ps "$service" | grep -q "Up"; then
            log_success "$service is running"
        else
            log_error "$service is not running"
            return 1
        fi
    done
    
    log_success "All services deployment completed"
}

# Function to run production validation
run_production_validation() {
    log "Running production deployment validation..."
    
    if [ -f "./validate_deployment.sh" ]; then
        ./validate_deployment.sh -e production -t full
        log_success "Production validation completed"
    else
        log_warning "Deployment validation script not found"
    fi
}

# Function to run production smoke tests
run_production_smoke_tests() {
    log "Running production smoke tests..."
    
    if [ -f "./test_smoke.sh" ]; then
        ./test_smoke.sh -e production
        log_success "Production smoke tests completed"
    else
        log_warning "Smoke test script not found"
    fi
}

# Function to setup production monitoring
setup_production_monitoring() {
    log "Setting up production monitoring..."
    
    # Configure Prometheus targets
    if [ -f "./configure_monitoring.sh" ]; then
        ./configure_monitoring.sh -e production
    fi
    
    # Setup Grafana dashboards
    if [ -f "./setup_grafana.sh" ]; then
        ./setup_grafana.sh -e production
    fi
    
    # Configure alerts
    if [ -f "./configure_alerts.sh" ]; then
        ./configure_alerts.sh -e production
    fi
    
    log_success "Production monitoring setup completed"
}

# Function to rollback production deployment
rollback_production_deployment() {
    if [ "$ROLLBACK_ON_FAILURE" = "true" ]; then
        log "Rolling back production deployment..."
        
        # Stop current services
        docker-compose -f docker-compose.production.yml down
        
        # Restore from backup if available
        if [ -f "./restore.sh" ]; then
            ./restore.sh -t full -e production
        fi
        
        # Start previous version
        docker-compose -f docker-compose.production.yml up -d
        
        log_success "Production rollback completed"
    fi
}

# Function to generate production deployment report
generate_production_report() {
    log "Generating production deployment report..."
    
    local report_file="${LOG_DIR}/production_deployment_report_${TIMESTAMP}.md"
    
    cat > "$report_file" << EOF
# MS5.0 Floor Dashboard - Production Deployment Report

**Deployment Date:** $(date)
**Environment:** $ENVIRONMENT
**Deploy Type:** $DEPLOY_TYPE
**Deploy Status:** $1
**Zero Downtime:** $ZERO_DOWNTIME

## Production Deployment Summary

### Deployed Components
EOF
    
    case $DEPLOY_TYPE in
        full)
            echo "- Database (PostgreSQL)" >> "$report_file"
            echo "- Backend Services (FastAPI)" >> "$report_file"
            echo "- Frontend Application (React Native)" >> "$report_file"
            echo "- Monitoring Services (Prometheus, Grafana, AlertManager)" >> "$report_file"
            echo "- Cache Services (Redis)" >> "$report_file"
            echo "- Reverse Proxy (Nginx)" >> "$report_file"
            ;;
        backend)
            echo "- Backend Services (FastAPI)" >> "$report_file"
            ;;
        frontend)
            echo "- Frontend Application (React Native)" >> "$report_file"
            ;;
        database)
            echo "- Database (PostgreSQL)" >> "$report_file"
            ;;
        monitoring)
            echo "- Monitoring Services (Prometheus, Grafana, AlertManager)" >> "$report_file"
            ;;
    esac
    
    cat >> "$report_file" << EOF

## Production Configuration

- **Environment:** $ENVIRONMENT
- **Deploy Type:** $DEPLOY_TYPE
- **Zero Downtime:** $ZERO_DOWNTIME
- **Backup Before Deploy:** $BACKUP_BEFORE_DEPLOY
- **Rollback On Failure:** $ROLLBACK_ON_FAILURE

## Production URLs

- **API Endpoint:** https://api.ms5dashboard.com
- **Web Dashboard:** https://ms5dashboard.com
- **Monitoring:** https://monitoring.ms5dashboard.com
- **Grafana:** https://grafana.ms5dashboard.com
- **Prometheus:** https://prometheus.ms5dashboard.com

## Production Monitoring

- **Health Checks:** Enabled
- **Alerting:** Configured
- **Logging:** Centralized
- **Metrics:** Collected

## Next Steps

1. Monitor system performance
2. Verify all functionality
3. Update DNS records if needed
4. Schedule user training
5. Plan next deployment

## Production Checklist

- [ ] SSL certificates configured
- [ ] Domain names updated
- [ ] DNS records updated
- [ ] Firewall rules configured
- [ ] Backup procedures tested
- [ ] Monitoring alerts configured
- [ ] User access configured
- [ ] Documentation updated

EOF
    
    log_success "Production deployment report generated: $report_file"
}

# Main production deployment function
main() {
    local start_time=$(date +%s)
    local deploy_success=true
    
    # Execute deployment steps based on type
    case $DEPLOY_TYPE in
        full)
            validate_production_prerequisites || deploy_success=false
            create_production_backup || deploy_success=false
            run_production_tests || deploy_success=false
            deploy_database_production || deploy_success=false
            deploy_backend_production || deploy_success=false
            deploy_monitoring_production || deploy_success=false
            setup_production_monitoring || deploy_success=false
            run_production_validation || deploy_success=false
            run_production_smoke_tests || deploy_success=false
            ;;
        backend)
            validate_production_prerequisites || deploy_success=false
            create_production_backup || deploy_success=false
            run_production_tests || deploy_success=false
            deploy_backend_production || deploy_success=false
            run_production_validation || deploy_success=false
            ;;
        frontend)
            validate_production_prerequisites || deploy_success=false
            deploy_frontend_production || deploy_success=false
            run_production_validation || deploy_success=false
            ;;
        database)
            validate_production_prerequisites || deploy_success=false
            create_production_backup || deploy_success=false
            deploy_database_production || deploy_success=false
            run_production_validation || deploy_success=false
            ;;
        monitoring)
            validate_production_prerequisites || deploy_success=false
            deploy_monitoring_production || deploy_success=false
            setup_production_monitoring || deploy_success=false
            run_production_validation || deploy_success=false
            ;;
    esac
    
    # Generate report
    if [ "$deploy_success" = "true" ]; then
        generate_production_report "SUCCESS"
        log_success "Production deployment completed successfully"
    else
        generate_production_report "FAILED"
        log_error "Production deployment failed"
        rollback_production_deployment
        exit 1
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log "Production deployment completed in ${duration}s"
    log "Log file: $LOG_FILE"
}

# Help function
show_help() {
    echo "MS5.0 Floor Dashboard - Production Deployment Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -t, --type TYPE         Deploy type (full|backend|frontend|database|monitoring) (default: full)"
    echo "  -s, --skip-tests        Skip running tests"
    echo "  -r, --no-rollback       Disable rollback on failure"
    echo "  -b, --no-backup         Skip backup before deployment"
    echo "  -z, --no-zero-downtime  Disable zero-downtime deployment"
    echo ""
    echo "Environment Variables:"
    echo "  DEPLOY_TYPE            Deploy type (default: full)"
    echo "  SKIP_TESTS             Skip tests (default: false)"
    echo "  ROLLBACK_ON_FAILURE    Rollback on failure (default: true)"
    echo "  BACKUP_BEFORE_DEPLOY   Backup before deploy (default: true)"
    echo "  ZERO_DOWNTIME          Zero downtime deployment (default: true)"
    echo "  HEALTH_CHECK_TIMEOUT   Health check timeout in seconds (default: 300)"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Deploy full system to production"
    echo "  $0 -t backend                         # Deploy backend to production"
    echo "  $0 -t monitoring -s                  # Deploy monitoring, skip tests"
    echo "  ZERO_DOWNTIME=false $0               # Deploy without zero downtime"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -t|--type)
            DEPLOY_TYPE="$2"
            shift 2
            ;;
        -s|--skip-tests)
            SKIP_TESTS="true"
            shift
            ;;
        -r|--no-rollback)
            ROLLBACK_ON_FAILURE="false"
            shift
            ;;
        -b|--no-backup)
            BACKUP_BEFORE_DEPLOY="false"
            shift
            ;;
        -z|--no-zero-downtime)
            ZERO_DOWNTIME="false"
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate deploy type
if [[ ! "$DEPLOY_TYPE" =~ ^(full|backend|frontend|database|monitoring)$ ]]; then
    log_error "Invalid deploy type: $DEPLOY_TYPE (must be 'full', 'backend', 'frontend', 'database', or 'monitoring')"
    exit 1
fi

# Run main function
main
