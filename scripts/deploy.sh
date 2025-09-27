#!/bin/bash

# MS5.0 Floor Dashboard - Deployment Script
# This script automates the deployment of the MS5.0 system

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${LOG_DIR}/deploy_${TIMESTAMP}.log"

# Environment variables
ENVIRONMENT=${ENVIRONMENT:-staging}
DEPLOY_TYPE=${DEPLOY_TYPE:-full}  # full, backend, frontend, database
SKIP_TESTS=${SKIP_TESTS:-false}
ROLLBACK_ON_FAILURE=${ROLLBACK_ON_FAILURE:-true}
BACKUP_BEFORE_DEPLOY=${BACKUP_BEFORE_DEPLOY:-true}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Create directories
mkdir -p "$LOG_DIR"

log "Starting MS5.0 system deployment - Environment: $ENVIRONMENT, Type: $DEPLOY_TYPE"

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(staging|production)$ ]]; then
    log_error "Invalid environment: $ENVIRONMENT (must be 'staging' or 'production')"
    exit 1
fi

# Validate deploy type
if [[ ! "$DEPLOY_TYPE" =~ ^(full|backend|frontend|database)$ ]]; then
    log_error "Invalid deploy type: $DEPLOY_TYPE (must be 'full', 'backend', 'frontend', or 'database')"
    exit 1
fi

# Change to script directory
cd "$SCRIPT_DIR"

# Function to check prerequisites
check_prerequisites() {
    log "Checking deployment prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose is not installed or not in PATH"
        exit 1
    fi
    
    # Check required files
    local required_files=(
        "docker-compose.${ENVIRONMENT}.yml"
        "Dockerfile.${ENVIRONMENT}"
        "env.${ENVIRONMENT}"
        "nginx.${ENVIRONMENT}.conf"
        "prometheus.${ENVIRONMENT}.yml"
    )
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            log_error "Required file not found: $file"
            exit 1
        fi
    done
    
    # Check environment variables
    if [ ! -f "env.${ENVIRONMENT}" ]; then
        log_error "Environment file not found: env.${ENVIRONMENT}"
        exit 1
    fi
    
    log_success "Prerequisites check completed"
}

# Function to backup current deployment
backup_current_deployment() {
    if [ "$BACKUP_BEFORE_DEPLOY" = "true" ]; then
        log "Creating backup of current deployment..."
        
        if [ -f "./backup.sh" ]; then
            ./backup.sh -t full
            log_success "Backup completed"
        else
            log_warning "Backup script not found, skipping backup"
        fi
    fi
}

# Function to run pre-deployment tests
run_pre_deployment_tests() {
    if [ "$SKIP_TESTS" = "true" ]; then
        log "Skipping pre-deployment tests"
        return 0
    fi
    
    log "Running pre-deployment tests..."
    
    # Run unit tests
    if [ -f "./test_unit.sh" ]; then
        ./test_unit.sh
    fi
    
    # Run integration tests
    if [ -f "./test_integration.sh" ]; then
        ./test_integration.sh
    fi
    
    log_success "Pre-deployment tests completed"
}

# Function to deploy database
deploy_database() {
    log "Deploying database..."
    
    # Run database migrations
    if [ -f "./deploy_migrations.sh" ]; then
        ./deploy_migrations.sh
        log_success "Database migrations completed"
    else
        log_warning "Database migration script not found"
    fi
    
    # Validate database
    if [ -f "./validate_database.sh" ]; then
        ./validate_database.sh
        log_success "Database validation completed"
    else
        log_warning "Database validation script not found"
    fi
}

# Function to deploy backend
deploy_backend() {
    log "Deploying backend services..."
    
    # Build backend image
    log "Building backend Docker image..."
    docker build -f "Dockerfile.${ENVIRONMENT}" -t "ms5-backend:${ENVIRONMENT}" .
    
    # Stop existing services
    log "Stopping existing backend services..."
    docker-compose -f "docker-compose.${ENVIRONMENT}.yml" down backend || true
    
    # Start backend services
    log "Starting backend services..."
    docker-compose -f "docker-compose.${ENVIRONMENT}.yml" up -d backend
    
    # Wait for services to be ready
    log "Waiting for backend services to be ready..."
    sleep 30
    
    # Health check
    log "Performing backend health check..."
    if curl -f http://localhost:8000/api/health; then
        log_success "Backend deployment completed"
    else
        log_error "Backend health check failed"
        return 1
    fi
}

# Function to deploy frontend
deploy_frontend() {
    log "Deploying frontend..."
    
    # Change to frontend directory
    cd "../frontend"
    
    # Install dependencies
    log "Installing frontend dependencies..."
    npm install
    
    # Build frontend
    log "Building frontend..."
    if [ "$ENVIRONMENT" = "staging" ]; then
        npm run build:staging
    else
        npm run build:production
    fi
    
    # Deploy frontend (if deployment script exists)
    if [ -f "./deploy.sh" ]; then
        ./deploy.sh "$ENVIRONMENT"
    fi
    
    log_success "Frontend deployment completed"
    
    # Return to backend directory
    cd "../backend"
}

# Function to deploy monitoring
deploy_monitoring() {
    log "Deploying monitoring services..."
    
    # Start monitoring services
    docker-compose -f "docker-compose.${ENVIRONMENT}.yml" up -d prometheus grafana alertmanager
    
    # Wait for services to be ready
    sleep 15
    
    # Verify monitoring services
    if curl -f http://localhost:9090/-/healthy; then
        log_success "Prometheus is healthy"
    else
        log_error "Prometheus health check failed"
        return 1
    fi
    
    if curl -f http://localhost:3000/api/health; then
        log_success "Grafana is healthy"
    else
        log_error "Grafana health check failed"
        return 1
    fi
    
    log_success "Monitoring deployment completed"
}

# Function to run post-deployment tests
run_post_deployment_tests() {
    if [ "$SKIP_TESTS" = "true" ]; then
        log "Skipping post-deployment tests"
        return 0
    fi
    
    log "Running post-deployment tests..."
    
    # Run smoke tests
    if [ -f "./test_smoke.sh" ]; then
        ./test_smoke.sh
    fi
    
    # Run end-to-end tests
    if [ -f "./test_e2e.sh" ]; then
        ./test_e2e.sh
    fi
    
    log_success "Post-deployment tests completed"
}

# Function to rollback deployment
rollback_deployment() {
    if [ "$ROLLBACK_ON_FAILURE" = "true" ]; then
        log "Rolling back deployment..."
        
        # Stop current services
        docker-compose -f "docker-compose.${ENVIRONMENT}.yml" down
        
        # Restore from backup if available
        if [ -f "./restore.sh" ]; then
            ./restore.sh -t full
        fi
        
        # Start previous version
        docker-compose -f "docker-compose.${ENVIRONMENT}.yml" up -d
        
        log_success "Rollback completed"
    fi
}

# Function to validate deployment
validate_deployment() {
    log "Validating deployment..."
    
    # Check service health
    local services=("backend" "frontend" "database" "redis" "nginx")
    for service in "${services[@]}"; do
        if docker-compose -f "docker-compose.${ENVIRONMENT}.yml" ps "$service" | grep -q "Up"; then
            log_success "$service is running"
        else
            log_error "$service is not running"
            return 1
        fi
    done
    
    # Check API endpoints
    if curl -f http://localhost:8000/api/health; then
        log_success "API health check passed"
    else
        log_error "API health check failed"
        return 1
    fi
    
    # Check database connectivity
    if docker-compose -f "docker-compose.${ENVIRONMENT}.yml" exec -T backend psql "$DATABASE_URL" -c "SELECT 1;" > /dev/null 2>&1; then
        log_success "Database connectivity check passed"
    else
        log_error "Database connectivity check failed"
        return 1
    fi
    
    log_success "Deployment validation completed"
}

# Function to generate deployment report
generate_deployment_report() {
    log "Generating deployment report..."
    
    local report_file="${LOG_DIR}/deployment_report_${TIMESTAMP}.md"
    
    cat > "$report_file" << EOF
# MS5.0 Floor Dashboard - Deployment Report

**Deployment Date:** $(date)
**Environment:** $ENVIRONMENT
**Deploy Type:** $DEPLOY_TYPE
**Deploy Status:** $1

## Deployment Summary

### Deployed Components
EOF
    
    case $DEPLOY_TYPE in
        full)
            echo "- Database" >> "$report_file"
            echo "- Backend Services" >> "$report_file"
            echo "- Frontend Application" >> "$report_file"
            echo "- Monitoring Services" >> "$report_file"
            ;;
        backend)
            echo "- Backend Services" >> "$report_file"
            ;;
        frontend)
            echo "- Frontend Application" >> "$report_file"
            ;;
        database)
            echo "- Database" >> "$report_file"
            ;;
    esac
    
    cat >> "$report_file" << EOF

## Deployment Details

- **Log File:** $LOG_FILE
- **Report File:** $report_file
- **Environment:** $ENVIRONMENT
- **Deploy Type:** $DEPLOY_TYPE

## Next Steps

1. Monitor system performance
2. Verify all functionality
3. Update documentation if needed
4. Schedule next deployment

EOF
    
    log_success "Deployment report generated: $report_file"
}

# Main deployment function
main() {
    local start_time=$(date +%s)
    local deploy_success=true
    
    # Execute deployment steps based on type
    case $DEPLOY_TYPE in
        full)
            check_prerequisites || deploy_success=false
            backup_current_deployment || deploy_success=false
            run_pre_deployment_tests || deploy_success=false
            deploy_database || deploy_success=false
            deploy_backend || deploy_success=false
            deploy_frontend || deploy_success=false
            deploy_monitoring || deploy_success=false
            run_post_deployment_tests || deploy_success=false
            validate_deployment || deploy_success=false
            ;;
        backend)
            check_prerequisites || deploy_success=false
            backup_current_deployment || deploy_success=false
            run_pre_deployment_tests || deploy_success=false
            deploy_backend || deploy_success=false
            run_post_deployment_tests || deploy_success=false
            validate_deployment || deploy_success=false
            ;;
        frontend)
            check_prerequisites || deploy_success=false
            deploy_frontend || deploy_success=false
            validate_deployment || deploy_success=false
            ;;
        database)
            check_prerequisites || deploy_success=false
            backup_current_deployment || deploy_success=false
            deploy_database || deploy_success=false
            validate_deployment || deploy_success=false
            ;;
    esac
    
    # Generate report
    if [ "$deploy_success" = "true" ]; then
        generate_deployment_report "SUCCESS"
        log_success "Deployment completed successfully"
    else
        generate_deployment_report "FAILED"
        log_error "Deployment failed"
        rollback_deployment
        exit 1
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log "Deployment completed in ${duration}s"
    log "Log file: $LOG_FILE"
}

# Help function
show_help() {
    echo "MS5.0 Floor Dashboard - Deployment Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -e, --environment ENV   Environment (staging|production) (default: staging)"
    echo "  -t, --type TYPE         Deploy type (full|backend|frontend|database) (default: full)"
    echo "  -s, --skip-tests        Skip running tests"
    echo "  -r, --no-rollback       Disable rollback on failure"
    echo "  -b, --no-backup         Skip backup before deployment"
    echo ""
    echo "Environment Variables:"
    echo "  ENVIRONMENT            Environment (default: staging)"
    echo "  DEPLOY_TYPE            Deploy type (default: full)"
    echo "  SKIP_TESTS             Skip tests (default: false)"
    echo "  ROLLBACK_ON_FAILURE    Rollback on failure (default: true)"
    echo "  BACKUP_BEFORE_DEPLOY   Backup before deploy (default: true)"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Deploy full system to staging"
    echo "  $0 -e production -t backend          # Deploy backend to production"
    echo "  $0 -e staging -t frontend -s         # Deploy frontend to staging, skip tests"
    echo "  ENVIRONMENT=production $0            # Deploy full system to production"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
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
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Run main function
main
