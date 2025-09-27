#!/bin/bash

# MS5.0 Floor Dashboard - Staging Deployment Script
# This script handles staging deployment for testing and validation

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${LOG_DIR}/staging_deploy_${TIMESTAMP}.log"

# Environment variables
ENVIRONMENT="staging"
DEPLOY_TYPE=${DEPLOY_TYPE:-full}  # full, backend, frontend, database, monitoring
SKIP_TESTS=${SKIP_TESTS:-false}
ROLLBACK_ON_FAILURE=${ROLLBACK_ON_FAILURE:-true}
BACKUP_BEFORE_DEPLOY=${BACKUP_BEFORE_DEPLOY:-false}  # Usually false for staging
HEALTH_CHECK_TIMEOUT=${HEALTH_CHECK_TIMEOUT:-120}

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

log "Starting MS5.0 Staging Deployment - Environment: $ENVIRONMENT, Type: $DEPLOY_TYPE"

# Change to script directory
cd "$SCRIPT_DIR"

# Function to validate staging prerequisites
validate_staging_prerequisites() {
    log "Validating staging deployment prerequisites..."
    
    # Check if we're in staging environment
    if [ "$ENVIRONMENT" != "staging" ]; then
        log_error "This script is only for staging deployments"
        exit 1
    fi
    
    # Check required staging files
    local required_files=(
        "docker-compose.staging.yml"
        "Dockerfile.staging"
        "env.staging"
        "nginx.staging.conf"
        "prometheus.staging.yml"
    )
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            log_error "Required staging file not found: $file"
            exit 1
        fi
    done
    
    # Check environment variables file
    if [ ! -f "env.staging" ]; then
        log_error "Staging environment file not found: env.staging"
        exit 1
    fi
    
    # Load staging environment variables
    source env.staging
    
    # Validate critical staging variables
    local critical_vars=(
        "POSTGRES_PASSWORD_STAGING"
        "SECRET_KEY_STAGING"
        "REDIS_PASSWORD_STAGING"
    )
    
    for var in "${critical_vars[@]}"; do
        if [ -z "${!var}" ]; then
            log_error "Critical staging environment variable not set: $var"
            exit 1
        fi
    done
    
    log_success "Staging prerequisites validation completed"
}

# Function to create staging backup (optional)
create_staging_backup() {
    if [ "$BACKUP_BEFORE_DEPLOY" = "true" ]; then
        log "Creating staging backup..."
        
        if [ -f "./backup.sh" ]; then
            ./backup.sh -t full -e staging
            log_success "Staging backup completed"
        else
            log_warning "Backup script not found, skipping backup"
        fi
    fi
}

# Function to run staging tests
run_staging_tests() {
    if [ "$SKIP_TESTS" = "true" ]; then
        log "Skipping staging tests"
        return 0
    fi
    
    log "Running staging deployment tests..."
    
    # Run unit tests
    if [ -f "./test_unit.sh" ]; then
        ./test_unit.sh
    fi
    
    # Run integration tests
    if [ -f "./test_integration.sh" ]; then
        ./test_integration.sh
    fi
    
    # Run staging-specific tests
    if [ -f "./test_staging.sh" ]; then
        ./test_staging.sh
    fi
    
    log_success "Staging tests completed"
}

# Function to deploy database with test data
deploy_staging_database() {
    log "Deploying staging database with test data..."
    
    # Run database migrations
    if [ -f "./deploy_migrations.sh" ]; then
        ./deploy_migrations.sh -e staging
        log_success "Database migrations completed"
    else
        log_warning "Database migration script not found"
    fi
    
    # Load test data
    if [ -f "./load_test_data.sh" ]; then
        ./load_test_data.sh -e staging
        log_success "Test data loaded"
    else
        log_warning "Test data loading script not found"
    fi
    
    # Validate database
    if [ -f "./validate_database.sh" ]; then
        ./validate_database.sh -e staging
        log_success "Database validation completed"
    else
        log_warning "Database validation script not found"
    fi
}

# Function to deploy backend services
deploy_backend_staging() {
    log "Deploying staging backend services..."
    
    # Build backend image
    log "Building backend Docker image..."
    docker build -f Dockerfile.staging -t ms5-backend:staging .
    
    # Stop existing services
    log "Stopping existing backend services..."
    docker-compose -f docker-compose.staging.yml down backend || true
    
    # Start backend services
    log "Starting backend services..."
    docker-compose -f docker-compose.staging.yml up -d backend
    
    # Wait for services to be ready
    log "Waiting for backend services to be ready..."
    sleep 30
    
    # Health check
    log "Performing backend health check..."
    local health_check_count=0
    local max_health_checks=$((HEALTH_CHECK_TIMEOUT / 10))
    
    while [ $health_check_count -lt $max_health_checks ]; do
        if curl -f -s http://localhost:8000/api/health > /dev/null; then
            log_success "Backend deployment completed"
            return 0
        fi
        
        log_info "Health check attempt $((health_check_count + 1))/$max_health_checks"
        sleep 10
        ((health_check_count++))
    done
    
    log_error "Backend health check failed"
    return 1
}

# Function to deploy frontend
deploy_frontend_staging() {
    log "Deploying staging frontend..."
    
    # Change to frontend directory
    cd "../frontend"
    
    # Install dependencies
    log "Installing frontend dependencies..."
    npm install
    
    # Build frontend for staging
    log "Building frontend for staging..."
    npm run build:staging
    
    # Deploy frontend (if deployment script exists)
    if [ -f "./deploy.sh" ]; then
        ./deploy.sh staging
    fi
    
    log_success "Frontend deployment completed"
    
    # Return to backend directory
    cd "../backend"
}

# Function to deploy monitoring services
deploy_monitoring_staging() {
    log "Deploying staging monitoring services..."
    
    # Start monitoring services
    docker-compose -f docker-compose.staging.yml up -d prometheus grafana
    
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
    
    log_success "Monitoring deployment completed"
}

# Function to deploy all services
deploy_all_staging() {
    log "Deploying all staging services..."
    
    # Deploy all services
    docker-compose -f docker-compose.staging.yml up -d
    
    # Wait for all services to be ready
    log "Waiting for all services to be ready..."
    sleep 60
    
    # Verify all services
    local services=("backend" "postgres" "redis" "nginx" "prometheus" "grafana")
    for service in "${services[@]}"; do
        if docker-compose -f docker-compose.staging.yml ps "$service" | grep -q "Up"; then
            log_success "$service is running"
        else
            log_error "$service is not running"
            return 1
        fi
    done
    
    log_success "All services deployment completed"
}

# Function to run staging validation
run_staging_validation() {
    log "Running staging deployment validation..."
    
    if [ -f "./validate_deployment.sh" ]; then
        ./validate_deployment.sh -e staging -t full
        log_success "Staging validation completed"
    else
        log_warning "Deployment validation script not found"
    fi
}

# Function to run staging smoke tests
run_staging_smoke_tests() {
    log "Running staging smoke tests..."
    
    if [ -f "./test_smoke.sh" ]; then
        ./test_smoke.sh -e staging
        log_success "Staging smoke tests completed"
    else
        log_warning "Smoke test script not found"
    fi
}

# Function to run user acceptance testing
run_staging_uat() {
    log "Running staging user acceptance testing..."
    
    if [ -f "./user_acceptance_testing.sh" ]; then
        ./user_acceptance_testing.sh -e staging -t functional
        log_success "Staging UAT completed"
    else
        log_warning "UAT script not found"
    fi
}

# Function to setup staging monitoring
setup_staging_monitoring() {
    log "Setting up staging monitoring..."
    
    # Configure monitoring for staging
    if [ -f "./setup_production_monitoring.sh" ]; then
        ./setup_production_monitoring.sh -e staging -t full
        log_success "Staging monitoring setup completed"
    else
        log_warning "Monitoring setup script not found"
    fi
}

# Function to rollback staging deployment
rollback_staging_deployment() {
    if [ "$ROLLBACK_ON_FAILURE" = "true" ]; then
        log "Rolling back staging deployment..."
        
        # Stop current services
        docker-compose -f docker-compose.staging.yml down
        
        # Restore from backup if available
        if [ -f "./restore.sh" ] && [ "$BACKUP_BEFORE_DEPLOY" = "true" ]; then
            ./restore.sh -t full -e staging
        fi
        
        # Start previous version
        docker-compose -f docker-compose.staging.yml up -d
        
        log_success "Staging rollback completed"
    fi
}

# Function to generate staging deployment report
generate_staging_report() {
    log "Generating staging deployment report..."
    
    local report_file="${LOG_DIR}/staging_deployment_report_${TIMESTAMP}.md"
    
    cat > "$report_file" << EOF
# MS5.0 Floor Dashboard - Staging Deployment Report

**Deployment Date:** $(date)
**Environment:** $ENVIRONMENT
**Deploy Type:** $DEPLOY_TYPE
**Deploy Status:** $1

## Staging Deployment Summary

### Deployed Components
EOF
    
    case $DEPLOY_TYPE in
        full)
            echo "- Database (PostgreSQL with test data)" >> "$report_file"
            echo "- Backend Services (FastAPI)" >> "$report_file"
            echo "- Frontend Application (React Native)" >> "$report_file"
            echo "- Monitoring Services (Prometheus, Grafana)" >> "$report_file"
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
            echo "- Database (PostgreSQL with test data)" >> "$report_file"
            ;;
        monitoring)
            echo "- Monitoring Services (Prometheus, Grafana)" >> "$report_file"
            ;;
    esac
    
    cat >> "$report_file" << EOF

## Staging Configuration

- **Environment:** $ENVIRONMENT
- **Deploy Type:** $DEPLOY_TYPE
- **Backup Before Deploy:** $BACKUP_BEFORE_DEPLOY
- **Rollback On Failure:** $ROLLBACK_ON_FAILURE

## Staging URLs

- **API Endpoint:** http://staging.ms5dashboard.com
- **Web Dashboard:** http://staging-app.ms5dashboard.com
- **Monitoring:** http://staging-monitoring.ms5dashboard.com
- **Grafana:** http://staging-grafana.ms5dashboard.com
- **Prometheus:** http://staging-prometheus.ms5dashboard.com

## Test Data

- **Test Users:** Available
- **Test Production Lines:** Available
- **Test Equipment:** Available
- **Test Schedules:** Available

## Staging Checklist

- [ ] All services deployed successfully
- [ ] Health checks passing
- [ ] Test data loaded
- [ ] Monitoring configured
- [ ] UAT tests passing
- [ ] Smoke tests passing
- [ ] Performance tests passing
- [ ] Security tests passing

## Next Steps

1. Run comprehensive testing
2. Validate all functionality
3. Performance testing
4. Security testing
5. User acceptance testing
6. Prepare for production deployment

## Testing URLs

- **API Health:** http://staging.ms5dashboard.com/api/health
- **API Status:** http://staging.ms5dashboard.com/api/status
- **API Version:** http://staging.ms5dashboard.com/api/version

## Test Credentials

- **Admin User:** admin@staging.com / admin123
- **Operator User:** operator@staging.com / operator123
- **Manager User:** manager@staging.com / manager123

EOF
    
    log_success "Staging deployment report generated: $report_file"
}

# Main staging deployment function
main() {
    local start_time=$(date +%s)
    local deploy_success=true
    
    # Execute deployment steps based on type
    case $DEPLOY_TYPE in
        full)
            validate_staging_prerequisites || deploy_success=false
            create_staging_backup || deploy_success=false
            run_staging_tests || deploy_success=false
            deploy_staging_database || deploy_success=false
            deploy_backend_staging || deploy_success=false
            deploy_frontend_staging || deploy_success=false
            deploy_monitoring_staging || deploy_success=false
            setup_staging_monitoring || deploy_success=false
            run_staging_validation || deploy_success=false
            run_staging_smoke_tests || deploy_success=false
            run_staging_uat || deploy_success=false
            ;;
        backend)
            validate_staging_prerequisites || deploy_success=false
            create_staging_backup || deploy_success=false
            run_staging_tests || deploy_success=false
            deploy_backend_staging || deploy_success=false
            run_staging_validation || deploy_success=false
            ;;
        frontend)
            validate_staging_prerequisites || deploy_success=false
            deploy_frontend_staging || deploy_success=false
            run_staging_validation || deploy_success=false
            ;;
        database)
            validate_staging_prerequisites || deploy_success=false
            create_staging_backup || deploy_success=false
            deploy_staging_database || deploy_success=false
            run_staging_validation || deploy_success=false
            ;;
        monitoring)
            validate_staging_prerequisites || deploy_success=false
            deploy_monitoring_staging || deploy_success=false
            setup_staging_monitoring || deploy_success=false
            run_staging_validation || deploy_success=false
            ;;
    esac
    
    # Generate report
    if [ "$deploy_success" = "true" ]; then
        generate_staging_report "SUCCESS"
        log_success "Staging deployment completed successfully"
    else
        generate_staging_report "FAILED"
        log_error "Staging deployment failed"
        rollback_staging_deployment
        exit 1
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log "Staging deployment completed in ${duration}s"
    log "Log file: $LOG_FILE"
}

# Help function
show_help() {
    echo "MS5.0 Floor Dashboard - Staging Deployment Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -t, --type TYPE         Deploy type (full|backend|frontend|database|monitoring) (default: full)"
    echo "  -s, --skip-tests        Skip running tests"
    echo "  -r, --no-rollback       Disable rollback on failure"
    echo "  -b, --backup            Enable backup before deployment"
    echo ""
    echo "Environment Variables:"
    echo "  DEPLOY_TYPE            Deploy type (default: full)"
    echo "  SKIP_TESTS             Skip tests (default: false)"
    echo "  ROLLBACK_ON_FAILURE    Rollback on failure (default: true)"
    echo "  BACKUP_BEFORE_DEPLOY   Backup before deploy (default: false)"
    echo "  HEALTH_CHECK_TIMEOUT   Health check timeout in seconds (default: 120)"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Deploy full system to staging"
    echo "  $0 -t backend                         # Deploy backend to staging"
    echo "  $0 -t monitoring -s                  # Deploy monitoring, skip tests"
    echo "  BACKUP_BEFORE_DEPLOY=true $0         # Deploy with backup"
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
        -b|--backup)
            BACKUP_BEFORE_DEPLOY="true"
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
