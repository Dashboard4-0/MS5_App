#!/bin/bash

# MS5.0 Floor Dashboard - Phase 1: Master Execution Script
# This script executes all Phase 1 setup scripts in the correct sequence

set -e

echo "=== MS5.0 Phase 1: Master Execution Script ==="
echo "This script will execute all Phase 1 setup scripts in sequence."
echo "Estimated execution time: 2-3 hours"
echo ""

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/ms5-phase1-execution.log"

# Function to log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to execute script with error handling
execute_script() {
    local script_name="$1"
    local script_path="$SCRIPT_DIR/$script_name"
    
    if [ ! -f "$script_path" ]; then
        log "❌ ERROR: Script $script_name not found at $script_path"
        exit 1
    fi
    
    log "🚀 Starting execution of $script_name..."
    
    if bash "$script_path" 2>&1 | tee -a "$LOG_FILE"; then
        log "✅ Successfully completed $script_name"
    else
        log "❌ ERROR: Failed to execute $script_name"
        log "Check the log file at $LOG_FILE for details"
        exit 1
    fi
    
    log "⏳ Waiting 30 seconds before next script..."
    sleep 30
}

# Check prerequisites
log "🔍 Checking prerequisites..."

# Check if logged into Azure
if ! az account show &> /dev/null; then
    log "❌ ERROR: Not logged into Azure CLI. Please run 'az login' first."
    exit 1
fi

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    log "❌ ERROR: kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Check if docker is available
if ! command -v docker &> /dev/null; then
    log "❌ ERROR: Docker is not installed. Please install Docker first."
    exit 1
fi

log "✅ Prerequisites check passed"
echo ""

# Create log file
log "📝 Creating execution log at $LOG_FILE"
echo "MS5.0 Phase 1 Execution Log - $(date)" > "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Execute Phase 1 scripts in sequence
log "🎯 Beginning Phase 1 execution..."

# 1. Resource Group Setup
execute_script "01-resource-group-setup.sh"

# 2. Azure Container Registry Setup
execute_script "02-acr-setup.sh"

# 3. Azure Key Vault Setup
execute_script "03-keyvault-setup.sh"

# 4. Azure Monitor and Log Analytics Setup
execute_script "04-monitoring-setup.sh"

# 5. AKS Cluster Setup
execute_script "05-aks-cluster-setup.sh"

# 6. Node Pools Configuration
execute_script "06-node-pools-setup.sh"

# 7. Advanced Networking Setup
execute_script "07-networking-setup.sh"

# 8. Comprehensive Security Setup
execute_script "08-security-setup.sh"

# 9. Container Registry Setup
execute_script "09-container-registry-setup.sh"

# 10. Comprehensive Validation and Testing
execute_script "10-validation-setup.sh"

# Phase 1 completion
log "🎉 Phase 1 execution completed successfully!"
log "📊 All components have been implemented and validated"
log "📋 Check the log file at $LOG_FILE for detailed execution logs"
echo ""

# Display summary
echo "=== Phase 1 Implementation Summary ==="
echo ""
echo "✅ Azure Resource Group: Created with cost management"
echo "✅ Azure Container Registry: Configured with enhanced security"
echo "✅ Azure Key Vault: Set up with HSM and advanced security"
echo "✅ Azure Monitor: Comprehensive monitoring and logging"
echo "✅ AKS Cluster: Production-ready with cost optimization"
echo "✅ Node Pools: Specialized pools with Spot/Reserved Instances"
echo "✅ Advanced Networking: Azure CNI, Private Link, security"
echo "✅ Comprehensive Security: Azure AD, Pod Security, network policies"
echo "✅ Container Registry: Images migrated and optimized"
echo "✅ Validation: All components tested and validated"
echo ""
echo "=== Next Steps ==="
echo "1. Review the execution log at $LOG_FILE"
echo "2. Begin Phase 2: Kubernetes Manifests Creation"
echo "3. Deploy applications to AKS cluster"
echo "4. Conduct end-to-end testing"
echo "5. Prepare for production deployment"
echo ""
echo "Phase 1 implementation completed successfully! 🚀"
echo ""
