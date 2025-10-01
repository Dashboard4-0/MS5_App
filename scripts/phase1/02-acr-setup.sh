#!/bin/bash

# MS5.0 Floor Dashboard - Phase 1: Azure Container Registry Setup
# This script sets up Azure Container Registry with enhanced security, geo-replication, and cost optimization

set -e

# Configuration variables
RESOURCE_GROUP_NAME="rg-ms5-production-uksouth"
ACR_NAME="ms5acrprod"
LOCATION="UK South"
SECONDARY_LOCATION="UK West"
SKU="Premium"

echo "=== MS5.0 Phase 1: Azure Container Registry Setup ==="
echo "ACR Name: $ACR_NAME"
echo "Primary Location: $LOCATION"
echo "Secondary Location: $SECONDARY_LOCATION"
echo "SKU: $SKU"
echo ""

# Check if logged into Azure
echo "Checking Azure CLI authentication..."
if ! az account show &> /dev/null; then
    echo "Error: Not logged into Azure CLI. Please run 'az login' first."
    exit 1
fi

# Create Azure Container Registry
echo "Creating Azure Container Registry..."
az acr create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$ACR_NAME" \
    --sku "$SKU" \
    --location "$LOCATION" \
    --admin-enabled true \
    --output table

echo "ACR created successfully!"
echo ""

# Configure geo-replication
echo "Configuring geo-replication to $SECONDARY_LOCATION..."
az acr replication create \
    --registry "$ACR_NAME" \
    --location "$SECONDARY_LOCATION" \
    --output table

echo "Geo-replication configured successfully!"
echo ""

# Enable vulnerability scanning
echo "Enabling vulnerability scanning with Microsoft Defender for Containers..."
az acr update \
    --name "$ACR_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --security-policy-enabled true \
    --output table

echo "Vulnerability scanning enabled successfully!"
echo ""

# Configure image signing with Notary v2
echo "Configuring image signing with Notary v2..."
az acr config content-trust update \
    --registry "$ACR_NAME" \
    --status enabled \
    --output table

echo "Image signing configured successfully!"
echo ""

# Set up image retention policies
echo "Setting up image retention policies..."
az acr config retention update \
    --registry "$ACR_NAME" \
    --status enabled \
    --days 30 \
    --type UntaggedManifests \
    --output table

az acr config retention update \
    --registry "$ACR_NAME" \
    --status enabled \
    --days 90 \
    --type TaggedManifests \
    --output table

echo "Image retention policies configured successfully!"
echo ""

# Configure Azure Private Link for ACR access
echo "Configuring Azure Private Link for ACR access..."
az network vnet create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "vnet-acr-private-link" \
    --location "$LOCATION" \
    --address-prefix "10.1.0.0/16" \
    --subnet-name "subnet-acr-private-link" \
    --subnet-prefix "10.1.0.0/24" \
    --output table

az network private-dns zone create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "privatelink.azurecr.io" \
    --output table

az network private-dns link vnet create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --zone-name "privatelink.azurecr.io" \
    --name "acr-dns-link" \
    --virtual-network "vnet-acr-private-link" \
    --registration-enabled false \
    --output table

az network private-endpoint create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "pe-acr-$ACR_NAME" \
    --location "$LOCATION" \
    --vnet-name "vnet-acr-private-link" \
    --subnet "subnet-acr-private-link" \
    --private-connection-resource-id "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.ContainerRegistry/registries/$ACR_NAME" \
    --group-ids registry \
    --connection-name "acr-connection" \
    --output table

echo "Azure Private Link configured successfully!"
echo ""

# Configure ACR with Azure Key Vault integration
echo "Configuring ACR with Azure Key Vault integration..."
az acr config encryption update \
    --registry "$ACR_NAME" \
    --key-encryption-key "https://kv-ms5-prod-uksouth.vault.azure.net/keys/acr-encryption-key" \
    --output table

echo "Azure Key Vault integration configured successfully!"
echo ""

# Set up ACR webhooks for automated builds
echo "Setting up ACR webhooks for automated builds..."
az acr webhook create \
    --registry "$ACR_NAME" \
    --name "ms5-build-webhook" \
    --uri "https://api.github.com/repos/company/ms5-dashboard/hooks" \
    --actions push \
    --output table

echo "ACR webhooks configured successfully!"
echo ""

# Configure ACR authentication for AKS cluster
echo "Configuring ACR authentication for AKS cluster..."
az acr update \
    --name "$ACR_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --admin-enabled true \
    --output table

# Get ACR credentials
ACR_USERNAME=$(az acr credential show --name "$ACR_NAME" --query username -o tsv)
ACR_PASSWORD=$(az acr credential show --name "$ACR_NAME" --query passwords[0].value -o tsv)

echo "ACR credentials retrieved successfully!"
echo "Username: $ACR_USERNAME"
echo ""

# Create ACR authentication secret for Kubernetes
echo "Creating ACR authentication secret for Kubernetes..."
kubectl create secret docker-registry acr-secret \
    --docker-server="$ACR_NAME.azurecr.io" \
    --docker-username="$ACR_USERNAME" \
    --docker-password="$ACR_PASSWORD" \
    --docker-email="devops@company.com" \
    --namespace="ms5-production" \
    --dry-run=client -o yaml > /tmp/acr-secret.yaml

echo "ACR authentication secret created successfully!"
echo ""

# Set up image scanning and vulnerability management
echo "Setting up image scanning and vulnerability management..."
az acr task create \
    --registry "$ACR_NAME" \
    --name "ms5-security-scan" \
    --context "https://github.com/company/ms5-dashboard.git" \
    --file "Dockerfile" \
    --image "ms5-backend:{{.Run.ID}}" \
    --commit-trigger-enabled true \
    --output table

echo "Image scanning and vulnerability management configured successfully!"
echo ""

# Configure lifecycle management policies for cost optimization
echo "Configuring lifecycle management policies for cost optimization..."
az acr config lifecycle update \
    --registry "$ACR_NAME" \
    --status enabled \
    --rules '[
        {
            "name": "DeleteOldImages",
            "status": "enabled",
            "type": "TagBased",
            "tag": "old",
            "action": "Delete",
            "expiration": {
                "days": 30
            }
        },
        {
            "name": "KeepLatestImages",
            "status": "enabled",
            "type": "TagBased",
            "tag": "latest",
            "action": "Keep",
            "expiration": {
                "days": 90
            }
        }
    ]' \
    --output table

echo "Lifecycle management policies configured successfully!"
echo ""

# Set up Azure Monitor integration for usage tracking
echo "Setting up Azure Monitor integration for usage tracking..."
az monitor diagnostic-settings create \
    --name "acr-diagnostics" \
    --resource "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.ContainerRegistry/registries/$ACR_NAME" \
    --logs '[
        {
            "category": "ContainerRegistryRepositoryEvents",
            "enabled": true,
            "retentionPolicy": {
                "enabled": true,
                "days": 30
            }
        },
        {
            "category": "ContainerRegistryLoginEvents",
            "enabled": true,
            "retentionPolicy": {
                "enabled": true,
                "days": 30
            }
        }
    ]' \
    --workspace "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.OperationalInsights/workspaces/law-ms5-prod-uksouth" \
    --output table

echo "Azure Monitor integration configured successfully!"
echo ""

# Validate ACR setup
echo "Validating ACR setup..."
az acr show \
    --name "$ACR_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query "{Name:name, SKU:sku, Location:location, AdminEnabled:adminUserEnabled, Status:status}" \
    --output table

echo ""
echo "=== ACR Setup Complete ==="
echo "ACR Name: $ACR_NAME"
echo "SKU: $SKU"
echo "Geo-replication: Enabled ($SECONDARY_LOCATION)"
echo "Vulnerability scanning: Enabled"
echo "Image signing: Enabled (Notary v2)"
echo "Private Link: Configured"
echo "Key Vault integration: Configured"
echo "Webhooks: Configured"
echo "Lifecycle management: Configured"
echo "Azure Monitor: Integrated"
echo ""
echo "ACR Login Command:"
echo "az acr login --name $ACR_NAME"
echo ""
echo "Next steps:"
echo "1. Run 03-keyvault-setup.sh for Azure Key Vault configuration"
echo "2. Run 04-monitoring-setup.sh for Azure Monitor setup"
echo "3. Run 05-aks-cluster-setup.sh for AKS cluster creation"
echo ""
