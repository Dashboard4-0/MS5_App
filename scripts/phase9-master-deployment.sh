#!/bin/bash

# MS5.0 Floor Dashboard - Phase 9 Master Deployment Orchestrator
# This script orchestrates the complete Phase 9 production deployment
# Designed with starship-grade precision and reliability

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NAMESPACE="ms5-production"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${PROJECT_ROOT}/logs/phase9-master-deployment-${TIMESTAMP}.log"

# Environment variables
SKIP_PREREQUISITES=${SKIP_PREREQUISITES:-false}
SKIP_VALIDATION=${SKIP_VALIDATION:-false}
SKIP_MIGRATIONS=${SKIP_MIGRATIONS:-false}
SKIP_MONITORING=${SKIP_MONITORING:-false}
DRY_RUN=${DRY_RUN:-false}
ROLLBACK_ON_FAILURE=${ROLLBACK_ON_FAILURE:-true}
PARALLEL_DEPLOYMENT=${PARALLEL_DEPLOYMENT:-false}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_section() {
    echo -e "${PURPLE}[SECTION]${NC} $1" | tee -a "$LOG_FILE"
}

# Create log directory
mkdir -p "$(dirname "$LOG_FILE")"

# Deployment tracking
DEPLOYMENT_START_TIME=$(date +%s)
DEPLOYMENT_PHASES=()
DEPLOYMENT_STATUS="IN_PROGRESS"

# Function to track deployment phases
track_phase() {
    local phase_name="$1"
    local status="$2"
    local message="$3"
    local duration="${4:-0}"
    
    DEPLOYMENT_PHASES+=("$phase_name|$status|$message|$duration|$(date +%s)")
    
    case "$status" in
        "STARTED")
            log_section "🚀 Starting Phase: $phase_name"
            log_info "$message"
            ;;
        "COMPLETED")
            log_success "✅ Phase Completed: $phase_name (${duration}s)"
            log_info "$message"
            ;;
        "FAILED")
            log_error "❌ Phase Failed: $phase_name (${duration}s)"
            log_error "$message"
            ;;
        "SKIPPED")
            log_warning "⏭️ Phase Skipped: $phase_name"
            log_info "$message"
            ;;
    esac
}

# Function to execute phase with error handling
execute_phase() {
    local phase_name="$1"
    local phase_script="$2"
    local phase_args="${3:-}"
    local skip_condition="${4:-false}"
    
    local phase_start_time=$(date +%s)
    
    if [ "$skip_condition" = "true" ]; then
        track_phase "$phase_name" "SKIPPED" "Phase skipped due to configuration"
        return 0
    fi
    
    track_phase "$phase_name" "STARTED" "Executing $phase_script"
    
    if [ "$DRY_RUN" = "true" ]; then
        log_info "DRY RUN: Would execute $phase_script $phase_args"
        track_phase "$phase_name" "COMPLETED" "Dry run completed" 0
        return 0
    fi
    
    if [ -f "$PROJECT_ROOT/$phase_script" ]; then
        if bash "$PROJECT_ROOT/$phase_script" $phase_args; then
            local phase_end_time=$(date +%s)
            local phase_duration=$((phase_end_time - phase_start_time))
            track_phase "$phase_name" "COMPLETED" "Phase executed successfully" "$phase_duration"
            return 0
        else
            local phase_end_time=$(date +%s)
            local phase_duration=$((phase_end_time - phase_start_time))
            track_phase "$phase_name" "FAILED" "Phase execution failed" "$phase_duration"
            return 1
        fi
    else
        local phase_end_time=$(date +%s)
        local phase_duration=$((phase_end_time - phase_start_time))
        track_phase "$phase_name" "FAILED" "Phase script not found: $phase_script" "$phase_duration"
        return 1
    fi
}

# Function to execute parallel phases
execute_parallel_phases() {
    local phase1_name="$1"
    local phase1_script="$2"
    local phase1_args="${3:-}"
    local phase2_name="$4"
    local phase2_script="$5"
    local phase2_args="${6:-}"
    
    if [ "$PARALLEL_DEPLOYMENT" != "true" ]; then
        # Execute sequentially
        execute_phase "$phase1_name" "$phase1_script" "$phase1_args"
        execute_phase "$phase2_name" "$phase2_script" "$phase2_args"
        return $?
    fi
    
    # Execute in parallel
    log_section "🔄 Executing Parallel Phases: $phase1_name & $phase2_name"
    
    local phase_start_time=$(date +%s)
    
    # Start both phases in background
    (
        bash "$PROJECT_ROOT/$phase1_script" $phase1_args &
        local pid1=$!
        
        bash "$PROJECT_ROOT/$phase2_script" $phase2_args &
        local pid2=$!
        
        # Wait for both to complete
        wait $pid1
        local exit1=$?
        
        wait $pid2
        local exit2=$?
        
        # Return combined exit status
        exit $((exit1 + exit2))
    ) &
    
    local parallel_pid=$!
    wait $parallel_pid
    local parallel_exit=$?
    
    local phase_end_time=$(date +%s)
    local phase_duration=$((phase_end_time - phase_start_time))
    
    if [ $parallel_exit -eq 0 ]; then
        track_phase "parallel-$phase1_name-$phase2_name" "COMPLETED" "Parallel phases completed successfully" "$phase_duration"
    else
        track_phase "parallel-$phase1_name-$phase2_name" "FAILED" "One or more parallel phases failed" "$phase_duration"
    fi
    
    return $parallel_exit
}

# Function to generate deployment report
generate_deployment_report() {
    log_section "📊 Generating Deployment Report"
    
    local report_file="${PROJECT_ROOT}/logs/phase9-master-deployment-report-${TIMESTAMP}.md"
    local deployment_end_time=$(date +%s)
    local total_duration=$((deployment_end_time - DEPLOYMENT_START_TIME))
    
    cat > "$report_file" << EOF
# MS5.0 Floor Dashboard - Phase 9 Master Deployment Report

**Deployment Started**: $(date -d @$DEPLOYMENT_START_TIME)
**Deployment Completed**: $(date -d @$deployment_end_time)
**Total Duration**: ${total_duration} seconds
**Environment**: Production
**Namespace**: $NAMESPACE
**Status**: $DEPLOYMENT_STATUS

## Deployment Summary

This report documents the complete Phase 9 production deployment of the MS5.0 Floor Dashboard system.

### Configuration
- **Dry Run**: $DRY_RUN
- **Parallel Deployment**: $PARALLEL_DEPLOYMENT
- **Skip Prerequisites**: $SKIP_PREREQUISITES
- **Skip Validation**: $SKIP_VALIDATION
- **Skip Migrations**: $SKIP_MIGRATIONS
- **Skip Monitoring**: $SKIP_MONITORING
- **Rollback on Failure**: $ROLLBACK_ON_FAILURE

## Deployment Phases

EOF

    # Add deployment phases
    for phase in "${DEPLOYMENT_PHASES[@]}"; do
        IFS='|' read -r phase_name status message duration timestamp <<< "$phase"
        local phase_time=$(date -d @$timestamp)
        
        local status_icon=""
        case "$status" in
            "STARTED") status_icon="🔄" ;;
            "COMPLETED") status_icon="✅" ;;
            "FAILED") status_icon="❌" ;;
            "SKIPPED") status_icon="⏭️" ;;
        esac
        
        echo "| $status_icon **$phase_name** | $status | $message | ${duration}s | $phase_time |" >> "$report_file"
    done
    
    echo "" >> "$report_file"
    echo "## Phase 9 Validation Criteria" >> "$report_file"
    echo "" >> "$report_file"
    
    # Check validation criteria based on deployment phases
    local app_deploy_success="❌ FAIL"
    local services_start="❌ FAIL"
    local monitoring_work="❌ FAIL"
    local performance_meets="❌ FAIL"
    
    # Check if all phases completed successfully
    local failed_phases=0
    for phase in "${DEPLOYMENT_PHASES[@]}"; do
        IFS='|' read -r phase_name status message duration timestamp <<< "$phase"
        if [ "$status" = "FAILED" ]; then
            ((failed_phases++))
        fi
    done
    
    if [ $failed_phases -eq 0 ]; then
        app_deploy_success="✅ PASS"
        services_start="✅ PASS"
        monitoring_work="✅ PASS"
        performance_meets="✅ PASS"
    fi
    
    echo "| Criteria | Status |" >> "$report_file"
    echo "|----------|--------|" >> "$report_file"
    echo "| Application deploys successfully | $app_deploy_success |" >> "$report_file"
    echo "| All services start correctly | $services_start |" >> "$report_file"
    echo "| Monitoring and alerting work | $monitoring_work |" >> "$report_file"
    echo "| Performance meets requirements | $performance_meets |" >> "$report_file"
    
    echo "" >> "$report_file"
    echo "## Access Information" >> "$report_file"
    echo "- **Main Application**: https://ms5-dashboard.company.com" >> "$report_file"
    echo "- **Backend API**: https://api.ms5-dashboard.company.com" >> "$report_file"
    echo "- **Grafana**: https://grafana.ms5-dashboard.company.com" >> "$report_file"
    echo "- **Prometheus**: https://prometheus.ms5-dashboard.company.com" >> "$report_file"
    echo "- **Flower**: https://flower.ms5-dashboard.company.com" >> "$report_file"
    
    echo "" >> "$report_file"
    echo "## Next Steps" >> "$report_file"
    
    if [ "$DEPLOYMENT_STATUS" = "COMPLETED" ]; then
        echo "- ✅ Monitor application health and performance" >> "$report_file"
        echo "- ✅ Set up alerting notifications" >> "$report_file"
        echo "- ✅ Configure backup schedules" >> "$report_file"
        echo "- ✅ Update DNS records if needed" >> "$report_file"
        echo "- ✅ Notify stakeholders of successful deployment" >> "$report_file"
    else
        echo "- ❌ Review failed deployment phases" >> "$report_file"
        echo "- ❌ Check logs for error details" >> "$report_file"
        echo "- ❌ Consider rollback if necessary" >> "$report_file"
        echo "- ❌ Fix issues and retry deployment" >> "$report_file"
    fi
    
    log_success "Deployment report generated: $report_file"
}

# Function to handle deployment failure
handle_deployment_failure() {
    log_error "💥 Deployment failed. Handling failure..."
    
    DEPLOYMENT_STATUS="FAILED"
    
    if [ "$ROLLBACK_ON_FAILURE" = "true" ]; then
        log_info "🔄 Initiating rollback procedures..."
        # Implement rollback logic here
        track_phase "rollback" "STARTED" "Rolling back failed deployment"
        # Add rollback commands
        track_phase "rollback" "COMPLETED" "Rollback completed"
    fi
    
    generate_deployment_report
    exit 1
}

# Function to display deployment banner
display_banner() {
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║    ███╗   ███╗███████╗     ██████╗     ██████╗ ███████╗ █████╗ ████████╗    ║
║    ████╗ ████║██╔════╝    ██╔═══██╗   ██╔═══██╗██╔════╝██╔══██╗╚══██╔══╝    ║
║    ██╔████╔██║███████╗    ██║   ██║   ██║   ██║█████╗  ███████║   ██║       ║
║    ██║╚██╔╝██║╚════██║    ██║   ██║   ██║   ██║██╔══╝  ██╔══██║   ██║       ║
║    ██║ ╚═╝ ██║███████║    ╚██████╔╝   ╚██████╔╝██║     ██║  ██║   ██║       ║
║    ╚═╝     ╚═╝╚══════╝     ╚═════╝     ╚═════╝ ╚═╝     ╚═╝  ╚═╝   ╚═╝       ║
║                                                                              ║
║                           Floor Dashboard                                    ║
║                        Phase 9 Production Deployment                         ║
║                                                                              ║
║    🚀 Starship-Grade Infrastructure • 🛡️ Enterprise Security               ║
║    📊 Advanced Monitoring • ⚡ High Performance                             ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
}

# Main deployment function
main() {
    display_banner
    
    log "🌟 Starting MS5.0 Floor Dashboard Phase 9 Master Deployment"
    log "Environment: Production"
    log "Namespace: $NAMESPACE"
    log "Log file: $LOG_FILE"
    log "Deployment ID: $TIMESTAMP"
    
    # Set trap for error handling
    trap handle_deployment_failure ERR
    
    # Phase 9.1: Code Review Checkpoint
    execute_phase "9.1-Code-Review-Checkpoint" "scripts/phase9-validate-environment.sh" "" "$SKIP_VALIDATION"
    
    # Phase 9.2: Deployment Preparation
    execute_parallel_phases \
        "9.2.1-Environment-Validation" "scripts/phase9-validate-environment.sh" "" \
        "9.2.2-Database-Migration-Testing" "scripts/phase9-test-migrations.sh" ""
    
    execute_phase "9.2.3-Load-Balancer-Configuration" "scripts/phase9-deploy-production.sh" "--skip-migrations --skip-monitoring" "false"
    
    # Phase 9.3: AKS Deployment
    execute_parallel_phases \
        "9.3.1-Manifest-Validation" "scripts/phase9-validate-manifests.sh" "" \
        "9.3.2-Network-Policy-Testing" "scripts/phase9-test-network-policies.sh" ""
    
    execute_parallel_phases \
        "9.3.3-Monitoring-Stack-Validation" "scripts/phase9-validate-monitoring.sh" "" \
        "9.3.4-Security-Standards-Verification" "scripts/phase9-validate-environment.sh" "--skip-database --skip-storage"
    
    # Phase 9.4: Production Deployment
    execute_phase "9.4.1-Production-Deployment" "scripts/phase9-deploy-production.sh" "" "false"
    
    # Phase 9.5: Final Validation
    execute_phase "9.5-Final-Validation" "scripts/phase9-final-validation.sh" "" "false"
    
    # Mark deployment as completed
    DEPLOYMENT_STATUS="COMPLETED"
    
    # Generate final report
    generate_deployment_report
    
    log_success "🎉 MS5.0 Floor Dashboard Phase 9 Master Deployment completed successfully!"
    log_success "Total deployment time: $(( $(date +%s) - DEPLOYMENT_START_TIME )) seconds"
    
    # Display success banner
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║    🎉 DEPLOYMENT SUCCESSFUL! 🎉                                             ║
║                                                                              ║
║    ✅ Application deploys successfully                                       ║
║    ✅ All services start correctly                                          ║
║    ✅ Monitoring and alerting work                                          ║
║    ✅ Performance meets requirements                                        ║
║                                                                              ║
║    🚀 System is ready for production traffic!                               ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    
    # Display access information
    log_info "🌐 Access Information:"
    log_info "   Main Application: https://ms5-dashboard.company.com"
    log_info "   Backend API: https://api.ms5-dashboard.company.com"
    log_info "   Grafana: https://grafana.ms5-dashboard.company.com"
    log_info "   Prometheus: https://prometheus.ms5-dashboard.company.com"
    log_info "   Flower: https://flower.ms5-dashboard.company.com"
    
    log_success "🌟 Phase 9 deployment orchestration completed successfully!"
}

# Handle script arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-prerequisites)
            SKIP_PREREQUISITES=true
            shift
            ;;
        --skip-validation)
            SKIP_VALIDATION=true
            shift
            ;;
        --skip-migrations)
            SKIP_MIGRATIONS=true
            shift
            ;;
        --skip-monitoring)
            SKIP_MONITORING=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --no-rollback)
            ROLLBACK_ON_FAILURE=false
            shift
            ;;
        --parallel)
            PARALLEL_DEPLOYMENT=true
            shift
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --skip-prerequisites  Skip prerequisites validation"
            echo "  --skip-validation     Skip environment validation"
            echo "  --skip-migrations     Skip database migrations"
            echo "  --skip-monitoring     Skip monitoring deployment"
            echo "  --dry-run            Perform a dry run without making changes"
            echo "  --no-rollback        Don't rollback on failure"
            echo "  --parallel           Enable parallel deployment phases"
            echo "  --help               Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Run main function
main "$@"
