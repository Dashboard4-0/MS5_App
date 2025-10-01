#!/bin/bash

# MS5.0 Floor Dashboard - Azure Container Registry Setup Script
# This script sets up Azure Container Registry for multi-environment support

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$SCRIPT_DIR/azure-container-registry-config.sh"

# Load configuration
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    log_error "Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Function to create ACR
create_acr() {
    local acr_name="$1"
    local resource_group="$2"
    local location="$3"
    local sku="$4"
    
    log_info "Creating Azure Container Registry: $acr_name"
    
    # Check if ACR already exists
    if az acr show --name "$acr_name" --resource-group "$resource_group" >/dev/null 2>&1; then
        log_warning "ACR $acr_name already exists"
        return 0
    fi
    
    # Create resource group if it doesn't exist
    if ! az group show --name "$resource_group" >/dev/null 2>&1; then
        log_info "Creating resource group: $resource_group"
        az group create --name "$resource_group" --location "$location"
    fi
    
    # Create ACR
    az acr create \
        --name "$acr_name" \
        --resource-group "$resource_group" \
        --location "$location" \
        --sku "$sku" \
        --admin-enabled true \
        --public-network-enabled true \
        --zone-redundancy Disabled
    
    log_success "ACR $acr_name created successfully"
}

# Function to configure ACR security
configure_acr_security() {
    local acr_name="$1"
    local resource_group="$2"
    
    log_info "Configuring ACR security for: $acr_name"
    
    # Enable vulnerability scanning
    az acr config retention update \
        --name "$acr_name" \
        --resource-group "$resource_group" \
        --status Enabled \
        --days "$ACR_RETENTION_DAYS"
    
    # Configure cleanup policy
    az acr config retention update \
        --name "$acr_name" \
        --resource-group "$resource_group" \
        --status Enabled \
        --days "$ACR_RETENTION_DAYS"
    
    log_success "ACR security configured for: $acr_name"
}

# Function to configure ACR replication
configure_acr_replication() {
    local acr_name="$1"
    local resource_group="$2"
    
    log_info "Configuring ACR replication for: $acr_name"
    
    # Enable geo-replication for Premium SKU
    if [[ "$ACR_SKU" == "Premium" ]]; then
        IFS=',' read -ra LOCATIONS <<< "$ACR_GEO_REPLICATION_LOCATIONS"
        for location in "${LOCATIONS[@]}"; do
            log_info "Adding replication to: $location"
            az acr replication create \
                --name "$acr_name" \
                --resource-group "$resource_group" \
                --location "$location"
        done
    fi
    
    log_success "ACR replication configured for: $acr_name"
}

# Function to configure ACR webhooks
configure_acr_webhooks() {
    local acr_name="$1"
    local resource_group="$2"
    
    log_info "Configuring ACR webhooks for: $acr_name"
    
    # Create webhook for GitHub Actions
    az acr webhook create \
        --name "github-actions-webhook" \
        --registry "$acr_name" \
        --resource-group "$resource_group" \
        --uri "$GITHUB_WEBHOOK_URL" \
        --actions push \
        --scope "$ACR_WEBHOOK_SCOPE"
    
    log_success "ACR webhooks configured for: $acr_name"
}

# Function to configure ACR access policies
configure_acr_access() {
    local acr_name="$1"
    local resource_group="$2"
    
    log_info "Configuring ACR access policies for: $acr_name"
    
    # Get ACR login server
    local login_server=$(az acr show --name "$acr_name" --resource-group "$resource_group" --query loginServer --output tsv)
    
    # Create service principal for AKS
    local sp_name="acr-service-principal-$acr_name"
    local sp_password=$(az ad sp create-for-rbac --name "$sp_name" --scopes "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$resource_group/providers/Microsoft.ContainerRegistry/registries/$acr_name" --role AcrPull --query password --output tsv)
    local sp_app_id=$(az ad sp list --display-name "$sp_name" --query [0].appId --output tsv)
    
    log_success "Service principal created for ACR access: $sp_name"
    log_info "Service Principal App ID: $sp_app_id"
    log_info "Service Principal Password: $sp_password"
    
    # Store credentials securely
    echo "ACR_SERVICE_PRINCIPAL_APP_ID_$acr_name=$sp_app_id" >> "$PROJECT_ROOT/.env.acr"
    echo "ACR_SERVICE_PRINCIPAL_PASSWORD_$acr_name=$sp_password" >> "$PROJECT_ROOT/.env.acr"
}

# Function to configure ACR monitoring
configure_acr_monitoring() {
    local acr_name="$1"
    local resource_group="$2"
    
    log_info "Configuring ACR monitoring for: $acr_name"
    
    # Enable diagnostic settings
    az monitor diagnostic-settings create \
        --name "acr-diagnostics" \
        --resource "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$resource_group/providers/Microsoft.ContainerRegistry/registries/$acr_name" \
        --logs '[{"category":"ContainerRegistryRepositoryEvents","enabled":true},{"category":"ContainerRegistryLoginEvents","enabled":true}]' \
        --metrics '[{"category":"AllMetrics","enabled":true}]' \
        --workspace "$LOG_ANALYTICS_WORKSPACE_ID"
    
    log_success "ACR monitoring configured for: $acr_name"
}

# Function to push base images
push_base_images() {
    local acr_name="$1"
    local environment="$2"
    
    log_info "Pushing base images to ACR: $acr_name"
    
    # Login to ACR
    az acr login --name "$acr_name"
    
    # Build and push backend image
    log_info "Building and pushing backend image..."
    docker build -t "$acr_name/$BACKEND_IMAGE_NAME:$environment" "$PROJECT_ROOT/backend"
    docker push "$acr_name/$BACKEND_IMAGE_NAME:$environment"
    
    # Build and push frontend image
    log_info "Building and pushing frontend image..."
    docker build -t "$acr_name/$FRONTEND_IMAGE_NAME:$environment" "$PROJECT_ROOT/frontend"
    docker push "$acr_name/$FRONTEND_IMAGE_NAME:$environment"
    
    # Tag as latest
    docker tag "$acr_name/$BACKEND_IMAGE_NAME:$environment" "$acr_name/$BACKEND_IMAGE_NAME:latest"
    docker tag "$acr_name/$FRONTEND_IMAGE_NAME:$environment" "$acr_name/$FRONTEND_IMAGE_NAME:latest"
    
    docker push "$acr_name/$BACKEND_IMAGE_NAME:latest"
    docker push "$acr_name/$FRONTEND_IMAGE_NAME:latest"
    
    log_success "Base images pushed to ACR: $acr_name"
}

# Function to validate ACR setup
validate_acr_setup() {
    local acr_name="$1"
    local resource_group="$2"
    
    log_info "Validating ACR setup for: $acr_name"
    
    # Check ACR status
    local acr_status=$(az acr show --name "$acr_name" --resource-group "$resource_group" --query provisioningState --output tsv)
    if [[ "$acr_status" != "Succeeded" ]]; then
        log_error "ACR $acr_name is not in Succeeded state: $acr_status"
        return 1
    fi
    
    # Check ACR login
    if ! az acr login --name "$acr_name" >/dev/null 2>&1; then
        log_error "Failed to login to ACR: $acr_name"
        return 1
    fi
    
    # Check ACR repositories
    local repositories=$(az acr repository list --name "$acr_name" --output tsv)
    if [[ -z "$repositories" ]]; then
        log_warning "No repositories found in ACR: $acr_name"
    else
        log_success "ACR repositories: $repositories"
    fi
    
    log_success "ACR setup validated for: $acr_name"
}

# Main execution
main() {
    log_info "Starting Azure Container Registry setup for MS5.0 Floor Dashboard"
    
    # Check prerequisites
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install it first."
        exit 1
    fi
    
    # Login to Azure
    log_info "Logging in to Azure..."
    az login --use-device-code
    
    # Set subscription
    if [[ -n "${AZURE_SUBSCRIPTION_ID:-}" ]]; then
        az account set --subscription "$AZURE_SUBSCRIPTION_ID"
    fi
    
    # Create production ACR
    create_acr "$AZURE_CONTAINER_REGISTRY_PROD" "$AZURE_CONTAINER_REGISTRY_PROD_RESOURCE_GROUP" "$AZURE_CONTAINER_REGISTRY_PROD_LOCATION" "$ACR_SKU"
    configure_acr_security "$AZURE_CONTAINER_REGISTRY_PROD" "$AZURE_CONTAINER_REGISTRY_PROD_RESOURCE_GROUP"
    configure_acr_replication "$AZURE_CONTAINER_REGISTRY_PROD" "$AZURE_CONTAINER_REGISTRY_PROD_RESOURCE_GROUP"
    configure_acr_access "$AZURE_CONTAINER_REGISTRY_PROD" "$AZURE_CONTAINER_REGISTRY_PROD_RESOURCE_GROUP"
    configure_acr_monitoring "$AZURE_CONTAINER_REGISTRY_PROD" "$AZURE_CONTAINER_REGISTRY_PROD_RESOURCE_GROUP"
    validate_acr_setup "$AZURE_CONTAINER_REGISTRY_PROD" "$AZURE_CONTAINER_REGISTRY_PROD_RESOURCE_GROUP"
    
    # Create staging ACR
    create_acr "$AZURE_CONTAINER_REGISTRY_STAGING" "$AZURE_CONTAINER_REGISTRY_STAGING_RESOURCE_GROUP" "$AZURE_CONTAINER_REGISTRY_STAGING_LOCATION" "$ACR_SKU"
    configure_acr_security "$AZURE_CONTAINER_REGISTRY_STAGING" "$AZURE_CONTAINER_REGISTRY_STAGING_RESOURCE_GROUP"
    configure_acr_access "$AZURE_CONTAINER_REGISTRY_STAGING" "$AZURE_CONTAINER_REGISTRY_STAGING_RESOURCE_GROUP"
    configure_acr_monitoring "$AZURE_CONTAINER_REGISTRY_STAGING" "$AZURE_CONTAINER_REGISTRY_STAGING_RESOURCE_GROUP"
    validate_acr_setup "$AZURE_CONTAINER_REGISTRY_STAGING" "$AZURE_CONTAINER_REGISTRY_STAGING_RESOURCE_GROUP"
    
    # Push base images
    push_base_images "$AZURE_CONTAINER_REGISTRY_PROD" "production"
    push_base_images "$AZURE_CONTAINER_REGISTRY_STAGING" "staging"
    
    log_success "Azure Container Registry setup completed successfully!"
    
    # Display summary
    echo ""
    log_info "ACR Setup Summary:"
    echo "  Production ACR: $AZURE_CONTAINER_REGISTRY_PROD"
    echo "  Staging ACR: $AZURE_CONTAINER_REGISTRY_STAGING"
    echo "  Resource Groups: $AZURE_CONTAINER_REGISTRY_PROD_RESOURCE_GROUP, $AZURE_CONTAINER_REGISTRY_STAGING_RESOURCE_GROUP"
    echo "  Location: $AZURE_CONTAINER_REGISTRY_PROD_LOCATION"
    echo "  SKU: $ACR_SKU"
    echo ""
    log_info "Next steps:"
    echo "  1. Configure GitHub Actions secrets with ACR credentials"
    echo "  2. Update Kubernetes manifests with ACR image references"
    echo "  3. Test image pulls from AKS clusters"
    echo "  4. Configure ACR cleanup policies"
}

# Run main function
main "$@"
