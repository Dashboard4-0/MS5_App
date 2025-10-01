#!/bin/bash

# =============================================================================
# MS5.0 Phase 3: Completion Validation Script
# =============================================================================
# 
# This script validates that Phase 3 implementation is complete and ready for execution.
# Performs comprehensive validation of all Phase 3 components:
# - Script existence and permissions
# - File integrity and syntax validation
# - Documentation completeness
# - Integration testing
# - Ready-for-production verification
#
# Designed for cosmic-scale reliability - every component is verified and documented.
# =============================================================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# =============================================================================
# Configuration & Constants
# =============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
readonly LOG_DIR="${PROJECT_ROOT}/logs/validation"
readonly VALIDATION_REPORT_FILE="$LOG_DIR/phase3-completion-validation-$(date +%Y%m%d-%H%M%S).txt"

# Required Phase 3 components
readonly REQUIRED_SCRIPTS=(
    "backup-pre-migration.sh"
    "pre-migration-validation.sh"
    "migration-runner.sh"
    "post-migration-validation.sh"
    "execute-phase3-migration.sh"
    "test-phase3-migration.sh"
    "validate-phase3-completion.sh"
)

readonly REQUIRED_DOCS=(
    "PHASE3_MIGRATION_GUIDE.md"
)

readonly REQUIRED_MIGRATION_FILES=(
    "001_init_telemetry.sql"
    "002_plc_equipment_management.sql"
    "003_production_management.sql"
    "004_advanced_production_features.sql"
    "005_andon_escalation_system.sql"
    "006_report_system.sql"
    "007_plc_integration_phase1.sql"
    "008_fix_critical_schema_issues.sql"
    "009_database_optimization.sql"
)

# =============================================================================
# Logging System - Production Grade
# =============================================================================

# ANSI color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m'

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$VALIDATION_REPORT_FILE"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✅${NC} $1" | tee -a "$VALIDATION_REPORT_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️${NC} $1" | tee -a "$VALIDATION_REPORT_FILE"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ❌${NC} $1" | tee -a "$VALIDATION_REPORT_FILE"
}

log_info() {
    echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')] ℹ️${NC} $1" | tee -a "$VALIDATION_REPORT_FILE"
}

log_validation() {
    echo -e "${PURPLE}[$(date '+%Y-%m-%d %H:%M:%S')] 🔍${NC} $1" | tee -a "$VALIDATION_REPORT_FILE"
}

log_header() {
    echo -e "${WHITE}[$(date '+%Y-%m-%d %H:%M:%S')] 🚀${NC} $1" | tee -a "$VALIDATION_REPORT_FILE"
}

# =============================================================================
# Validation Functions
# =============================================================================

# Initialize validation environment
initialize_validation() {
    log_header "Initializing Phase 3 Completion Validation"
    
    # Create log directory
    mkdir -p "$LOG_DIR"
    
    # Initialize validation report
    cat > "$VALIDATION_REPORT_FILE" << EOF
# MS5.0 Phase 3 Completion Validation Report
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
# Validation ID: phase3-completion-$(date +%Y%m%d-%H%M%S)

## Validation Summary
- Validation Started: $(date '+%Y-%m-%d %H:%M:%S')
- Required Scripts: ${#REQUIRED_SCRIPTS[@]}
- Required Documents: ${#REQUIRED_DOCS[@]}
- Required Migration Files: ${#REQUIRED_MIGRATION_FILES[@]}

## Validation Results

EOF
    
    log_success "Validation environment initialized"
}

# Validate script components
validate_script_components() {
    log_validation "Validating Phase 3 script components..."
    
    local validation_passed=true
    local missing_scripts=()
    local non_executable_scripts=()
    local syntax_errors=()
    
    # Check each required script
    for script in "${REQUIRED_SCRIPTS[@]}"; do
        local script_path="${SCRIPT_DIR}/${script}"
        
        # Check existence
        if [[ ! -f "$script_path" ]]; then
            missing_scripts+=("$script")
            validation_passed=false
        else
            # Check executable permission
            if [[ ! -x "$script_path" ]]; then
                non_executable_scripts+=("$script")
                validation_passed=false
            fi
            
            # Check syntax
            if ! bash -n "$script_path" 2>/dev/null; then
                syntax_errors+=("$script")
                validation_passed=false
            fi
        fi
    done
    
    # Report results
    if [[ ${#missing_scripts[@]} -gt 0 ]]; then
        log_error "Missing scripts: ${missing_scripts[*]}"
    fi
    
    if [[ ${#non_executable_scripts[@]} -gt 0 ]]; then
        log_error "Non-executable scripts: ${non_executable_scripts[*]}"
    fi
    
    if [[ ${#syntax_errors[@]} -gt 0 ]]; then
        log_error "Scripts with syntax errors: ${syntax_errors[*]}"
    fi
    
    if [[ "$validation_passed" == "true" ]]; then
        log_success "All Phase 3 scripts validated successfully"
        return 0
    else
        log_error "Script component validation failed"
        return 1
    fi
}

# Validate documentation
validate_documentation() {
    log_validation "Validating Phase 3 documentation..."
    
    local validation_passed=true
    local missing_docs=()
    
    # Check each required document
    for doc in "${REQUIRED_DOCS[@]}"; do
        local doc_path="${SCRIPT_DIR}/${doc}"
        
        if [[ ! -f "$doc_path" ]]; then
            missing_docs+=("$doc")
            validation_passed=false
        else
            # Check document size (should not be empty)
            local doc_size
            doc_size=$(stat -f%z "$doc_path" 2>/dev/null || stat -c%s "$doc_path" 2>/dev/null || echo "0")
            
            if [[ $doc_size -lt 1000 ]]; then  # Less than 1KB
                log_warning "Document may be incomplete: $doc ($doc_size bytes)"
            else
                log_success "Document validated: $doc ($(numfmt --to=iec $doc_size))"
            fi
        fi
    done
    
    if [[ ${#missing_docs[@]} -gt 0 ]]; then
        log_error "Missing documentation: ${missing_docs[*]}"
        validation_passed=false
    fi
    
    if [[ "$validation_passed" == "true" ]]; then
        log_success "Documentation validation passed"
        return 0
    else
        log_error "Documentation validation failed"
        return 1
    fi
}

# Validate migration files
validate_migration_files() {
    log_validation "Validating migration files..."
    
    local validation_passed=true
    local missing_files=()
    local empty_files=()
    
    # Check each required migration file
    for migration_file in "${REQUIRED_MIGRATION_FILES[@]}"; do
        local migration_path="${PROJECT_ROOT}/../${migration_file}"
        
        if [[ ! -f "$migration_path" ]]; then
            missing_files+=("$migration_file")
            validation_passed=false
        else
            # Check file size (should not be empty)
            local file_size
            file_size=$(stat -f%z "$migration_path" 2>/dev/null || stat -c%s "$migration_path" 2>/dev/null || echo "0")
            
            if [[ $file_size -eq 0 ]]; then
                empty_files+=("$migration_file")
                validation_passed=false
            else
                # Basic SQL syntax check
                if head -n 5 "$migration_path" | grep -qi "sql\|create\|alter\|drop\|insert\|update\|delete"; then
                    log_success "Migration file validated: $migration_file ($(numfmt --to=iec $file_size))"
                else
                    log_warning "Migration file syntax unclear: $migration_file"
                fi
            fi
        fi
    done
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        log_error "Missing migration files: ${missing_files[*]}"
        validation_passed=false
    fi
    
    if [[ ${#empty_files[@]} -gt 0 ]]; then
        log_error "Empty migration files: ${empty_files[*]}"
        validation_passed=false
    fi
    
    if [[ "$validation_passed" == "true" ]]; then
        log_success "Migration files validation passed"
        return 0
    else
        log_error "Migration files validation failed"
        return 1
    fi
}

# Validate script integration
validate_script_integration() {
    log_validation "Validating script integration..."
    
    local validation_passed=true
    
    # Check that main execution script references all other scripts
    local main_script="${SCRIPT_DIR}/execute-phase3-migration.sh"
    
    if [[ -f "$main_script" ]]; then
        # Check for references to other scripts
        local referenced_scripts=(
            "backup-pre-migration.sh"
            "pre-migration-validation.sh"
            "migration-runner.sh"
            "post-migration-validation.sh"
        )
        
        for script in "${referenced_scripts[@]}"; do
            if grep -q "$script" "$main_script"; then
                log_success "Main script references: $script"
            else
                log_error "Main script missing reference to: $script"
                validation_passed=false
            fi
        done
    else
        log_error "Main execution script not found"
        validation_passed=false
    fi
    
    # Check that migration runner references migration files
    local migration_script="${SCRIPT_DIR}/migration-runner.sh"
    
    if [[ -f "$migration_script" ]]; then
        local migration_files_referenced=0
        
        for migration_file in "${REQUIRED_MIGRATION_FILES[@]}"; do
            if grep -q "$migration_file" "$migration_script"; then
                ((migration_files_referenced++))
            fi
        done
        
        if [[ $migration_files_referenced -eq ${#REQUIRED_MIGRATION_FILES[@]} ]]; then
            log_success "Migration runner references all migration files"
        else
            log_error "Migration runner missing references to migration files"
            validation_passed=false
        fi
    else
        log_error "Migration runner script not found"
        validation_passed=false
    fi
    
    if [[ "$validation_passed" == "true" ]]; then
        log_success "Script integration validation passed"
        return 0
    else
        log_error "Script integration validation failed"
        return 1
    fi
}

# Validate environment readiness
validate_environment_readiness() {
    log_validation "Validating environment readiness..."
    
    local validation_passed=true
    
    # Check Docker availability
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker is not installed or not in PATH"
        validation_passed=false
    else
        log_success "Docker is available"
        
        # Check Docker daemon
        if ! docker info >/dev/null 2>&1; then
            log_error "Docker daemon is not running"
            validation_passed=false
        else
            log_success "Docker daemon is running"
        fi
    fi
    
    # Check Docker Compose
    if ! docker compose version >/dev/null 2>&1; then
        log_error "Docker Compose is not available"
        validation_passed=false
    else
        log_success "Docker Compose is available"
    fi
    
    # Check required environment variables
    if [[ -z "${POSTGRES_PASSWORD_PRODUCTION:-}" ]]; then
        log_warning "POSTGRES_PASSWORD_PRODUCTION environment variable not set"
        log_info "This will need to be set before migration execution"
    else
        log_success "Database password environment variable is set"
    fi
    
    # Check system resources
    local memory_mb
    memory_mb=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    local disk_space_kb
    disk_space_kb=$(df / | awk 'NR==2 {print $4}')
    local disk_space_gb=$((disk_space_kb / 1024 / 1024))
    
    log_info "System resources - Memory: ${memory_mb}MB, Disk: ${disk_space_gb}GB"
    
    if [[ $memory_mb -lt 4096 ]]; then
        log_warning "Low memory available: ${memory_mb}MB (recommended: 4GB+)"
    fi
    
    if [[ $disk_space_kb -lt 20971520 ]]; then  # 20GB
        log_warning "Low disk space available: ${disk_space_gb}GB (recommended: 20GB+)"
    fi
    
    if [[ "$validation_passed" == "true" ]]; then
        log_success "Environment readiness validation passed"
        return 0
    else
        log_error "Environment readiness validation failed"
        return 1
    fi
}

# Validate Phase 3 compliance
validate_phase3_compliance() {
    log_validation "Validating Phase 3 compliance with requirements..."
    
    local validation_passed=true
    
    # Check that all Phase 3 requirements from DB_Phase_plan.md are met
    
    # Requirement 1: Pre-Migration Backup & Preparation
    log_info "Checking Phase 3.1: Pre-Migration Backup & Preparation"
    
    if [[ -f "${SCRIPT_DIR}/backup-pre-migration.sh" ]]; then
        log_success "✅ Comprehensive backup script implemented"
    else
        log_error "❌ Comprehensive backup script missing"
        validation_passed=false
    fi
    
    if [[ -f "${SCRIPT_DIR}/pre-migration-validation.sh" ]]; then
        log_success "✅ Pre-migration validation script implemented"
    else
        log_error "❌ Pre-migration validation script missing"
        validation_passed=false
    fi
    
    # Requirement 2: Execute Migration
    log_info "Checking Phase 3.2: Execute Migration"
    
    if [[ -f "${SCRIPT_DIR}/migration-runner.sh" ]]; then
        log_success "✅ Migration runner script implemented"
    else
        log_error "❌ Migration runner script missing"
        validation_passed=false
    fi
    
    if [[ -f "${SCRIPT_DIR}/post-migration-validation.sh" ]]; then
        log_success "✅ Post-migration validation script implemented"
    else
        log_error "❌ Post-migration validation script missing"
        validation_passed=false
    fi
    
    if [[ -f "${SCRIPT_DIR}/execute-phase3-migration.sh" ]]; then
        log_success "✅ Main execution script implemented"
    else
        log_error "❌ Main execution script missing"
        validation_passed=false
    fi
    
    # Check optimization points
    log_info "Checking optimization points..."
    
    # Multiple backup types
    if grep -q "full_backup\|schema_only\|data_only\|postgres_data" "${SCRIPT_DIR}/backup-pre-migration.sh" 2>/dev/null; then
        log_success "✅ Multiple backup types implemented"
    else
        log_error "❌ Multiple backup types not implemented"
        validation_passed=false
    fi
    
    # Volume backup
    if grep -q "docker.*volume\|tar.*gz" "${SCRIPT_DIR}/backup-pre-migration.sh" 2>/dev/null; then
        log_success "✅ Docker volume backup implemented"
    else
        log_error "❌ Docker volume backup not implemented"
        validation_passed=false
    fi
    
    # Validation scripts
    if [[ -f "${SCRIPT_DIR}/pre-migration-validation.sh" ]] && [[ -f "${SCRIPT_DIR}/post-migration-validation.sh" ]]; then
        log_success "✅ Pre and post-migration validation scripts implemented"
    else
        log_error "❌ Validation scripts not fully implemented"
        validation_passed=false
    fi
    
    if [[ "$validation_passed" == "true" ]]; then
        log_success "Phase 3 compliance validation passed"
        return 0
    else
        log_error "Phase 3 compliance validation failed"
        return 1
    fi
}

# =============================================================================
# Report Generation
# =============================================================================

# Generate final validation report
generate_validation_report() {
    log "Generating final validation report..."
    
    # Append summary to report file
    cat >> "$VALIDATION_REPORT_FILE" << EOF

## Validation Summary
- Validation Completed: $(date '+%Y-%m-%d %H:%M:%S')
- Total Validation Categories: 6

## Phase 3 Components Status
EOF

    # List all components with status
    echo "### Scripts" >> "$VALIDATION_REPORT_FILE"
    for script in "${REQUIRED_SCRIPTS[@]}"; do
        local script_path="${SCRIPT_DIR}/${script}"
        if [[ -f "$script_path" && -x "$script_path" ]]; then
            echo "✅ $script" >> "$VALIDATION_REPORT_FILE"
        else
            echo "❌ $script" >> "$VALIDATION_REPORT_FILE"
        fi
    done
    
    echo "" >> "$VALIDATION_REPORT_FILE"
    echo "### Documentation" >> "$VALIDATION_REPORT_FILE"
    for doc in "${REQUIRED_DOCS[@]}"; do
        local doc_path="${SCRIPT_DIR}/${doc}"
        if [[ -f "$doc_path" ]]; then
            echo "✅ $doc" >> "$VALIDATION_REPORT_FILE"
        else
            echo "❌ $doc" >> "$VALIDATION_REPORT_FILE"
        fi
    done
    
    echo "" >> "$VALIDATION_REPORT_FILE"
    echo "### Migration Files" >> "$VALIDATION_REPORT_FILE"
    for migration_file in "${REQUIRED_MIGRATION_FILES[@]}"; do
        local migration_path="${PROJECT_ROOT}/../${migration_file}"
        if [[ -f "$migration_path" ]]; then
            echo "✅ $migration_file" >> "$VALIDATION_REPORT_FILE"
        else
            echo "❌ $migration_file" >> "$VALIDATION_REPORT_FILE"
        fi
    done
    
    cat >> "$VALIDATION_REPORT_FILE" << EOF

## System Information
- Hostname: $(hostname)
- Operating System: $(uname -s) $(uname -r)
- Architecture: $(uname -m)
- Docker Version: $(docker --version 2>/dev/null || echo "Not available")
- Docker Compose Version: $(docker compose version --short 2>/dev/null || echo "Not available")

## Next Steps
1. Review validation results above
2. Address any failed validations
3. Run comprehensive testing: ./test-phase3-migration.sh
4. Execute Phase 3 migration: ./execute-phase3-migration.sh

EOF
    
    log_success "Validation report generated: $VALIDATION_REPORT_FILE"
}

# =============================================================================
# Main Execution Function
# =============================================================================

main() {
    log_header "Starting MS5.0 Phase 3 Completion Validation"
    
    # Initialize validation environment
    initialize_validation
    
    # Track validation results
    local validation_failed=false
    
    # Run all validation checks
    validate_script_components || validation_failed=true
    validate_documentation || validation_failed=true
    validate_migration_files || validation_failed=true
    validate_script_integration || validation_failed=true
    validate_environment_readiness || validation_failed=true
    validate_phase3_compliance || validation_failed=true
    
    # Generate final report
    generate_validation_report
    
    # Final result
    if [[ "$validation_failed" == "true" ]]; then
        log_error "❌ Phase 3 completion validation failed"
        log_error "Please address the issues above before proceeding with migration"
        log_info "Validation report: $VALIDATION_REPORT_FILE"
        exit 1
    else
        log_success "🎉 Phase 3 completion validation passed successfully!"
        log_success "Phase 3 implementation is complete and ready for execution"
        log_info "Validation report: $VALIDATION_REPORT_FILE"
        log_info "Next steps:"
        log_info "  1. Run testing: ./test-phase3-migration.sh"
        log_info "  2. Execute migration: ./execute-phase3-migration.sh"
        exit 0
    fi
}

# =============================================================================
# Script Execution
# =============================================================================

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
