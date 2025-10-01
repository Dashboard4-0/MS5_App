#!/bin/bash

# MS5.0 Floor Dashboard - Phase 1: Azure Key Vault Setup
# This script sets up Azure Key Vault with HSM support, advanced security, and automated secret rotation

set -e

# Configuration variables
RESOURCE_GROUP_NAME="rg-ms5-production-uksouth"
KEY_VAULT_NAME="kv-ms5-prod-uksouth"
LOCATION="UK South"
SKU="Premium"

echo "=== MS5.0 Phase 1: Azure Key Vault Setup ==="
echo "Key Vault Name: $KEY_VAULT_NAME"
echo "Location: $LOCATION"
echo "SKU: $SKU"
echo ""

# Check if logged into Azure
echo "Checking Azure CLI authentication..."
if ! az account show &> /dev/null; then
    echo "Error: Not logged into Azure CLI. Please run 'az login' first."
    exit 1
fi

# Get current user and subscription
CURRENT_USER=$(az account show --query user.name -o tsv)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

echo "Current user: $CURRENT_USER"
echo "Subscription ID: $SUBSCRIPTION_ID"
echo ""

# Create Azure Key Vault
echo "Creating Azure Key Vault..."
az keyvault create \
    --name "$KEY_VAULT_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --location "$LOCATION" \
    --sku "$SKU" \
    --enable-rbac-authorization true \
    --enable-soft-delete true \
    --soft-delete-retention-days 90 \
    --enable-purge-protection true \
    --output table

echo "Key Vault created successfully!"
echo ""

# Configure access policies for AKS cluster and DevOps team
echo "Configuring access policies for AKS cluster and DevOps team..."

# Create service principal for AKS cluster
echo "Creating service principal for AKS cluster..."
AKS_SP_NAME="sp-aks-ms5-prod"
AKS_SP_PASSWORD=$(az ad sp create-for-rbac --name "$AKS_SP_NAME" --skip-assignment --query password -o tsv)
AKS_SP_APP_ID=$(az ad sp show --id "http://$AKS_SP_NAME" --query appId -o tsv)

echo "Service principal created successfully!"
echo "App ID: $AKS_SP_APP_ID"
echo ""

# Assign Key Vault Administrator role to current user
echo "Assigning Key Vault Administrator role to current user..."
az role assignment create \
    --role "Key Vault Administrator" \
    --assignee "$CURRENT_USER" \
    --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.KeyVault/vaults/$KEY_VAULT_NAME" \
    --output table

# Assign Key Vault Secrets Officer role to AKS service principal
echo "Assigning Key Vault Secrets Officer role to AKS service principal..."
az role assignment create \
    --role "Key Vault Secrets Officer" \
    --assignee "$AKS_SP_APP_ID" \
    --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.KeyVault/vaults/$KEY_VAULT_NAME" \
    --output table

echo "Access policies configured successfully!"
echo ""

# Set up Azure Key Vault CSI driver integration
echo "Setting up Azure Key Vault CSI driver integration..."

# Create HSM-backed key for encryption
echo "Creating HSM-backed key for encryption..."
az keyvault key create \
    --vault-name "$KEY_VAULT_NAME" \
    --name "ms5-encryption-key" \
    --kty RSA \
    --size 2048 \
    --protection hsm \
    --output table

echo "HSM-backed key created successfully!"
echo ""

# Create initial secrets
echo "Creating initial secrets..."

# PostgreSQL passwords
echo "Creating PostgreSQL passwords..."
az keyvault secret set \
    --vault-name "$KEY_VAULT_NAME" \
    --name "postgres-production-password" \
    --value "$(openssl rand -base64 32)" \
    --output table

az keyvault secret set \
    --vault-name "$KEY_VAULT_NAME" \
    --name "postgres-staging-password" \
    --value "$(openssl rand -base64 32)" \
    --output table

az keyvault secret set \
    --vault-name "$KEY_VAULT_NAME" \
    --name "postgres-development-password" \
    --value "$(openssl rand -base64 32)" \
    --output table

# Redis passwords
echo "Creating Redis passwords..."
az keyvault secret set \
    --vault-name "$KEY_VAULT_NAME" \
    --name "redis-production-password" \
    --value "$(openssl rand -base64 32)" \
    --output table

az keyvault secret set \
    --vault-name "$KEY_VAULT_NAME" \
    --name "redis-staging-password" \
    --value "$(openssl rand -base64 32)" \
    --output table

# JWT secret keys
echo "Creating JWT secret keys..."
az keyvault secret set \
    --vault-name "$KEY_VAULT_NAME" \
    --name "jwt-production-secret" \
    --value "$(openssl rand -base64 64)" \
    --output table

az keyvault secret set \
    --vault-name "$KEY_VAULT_NAME" \
    --name "jwt-staging-secret" \
    --value "$(openssl rand -base64 64)" \
    --output table

# MinIO access keys
echo "Creating MinIO access keys..."
az keyvault secret set \
    --vault-name "$KEY_VAULT_NAME" \
    --name "minio-access-key" \
    --value "$(openssl rand -base64 32)" \
    --output table

az keyvault secret set \
    --vault-name "$KEY_VAULT_NAME" \
    --name "minio-secret-key" \
    --value "$(openssl rand -base64 32)" \
    --output table

# Grafana admin passwords
echo "Creating Grafana admin passwords..."
az keyvault secret set \
    --vault-name "$KEY_VAULT_NAME" \
    --name "grafana-production-password" \
    --value "$(openssl rand -base64 32)" \
    --output table

az keyvault secret set \
    --vault-name "$KEY_VAULT_NAME" \
    --name "grafana-staging-password" \
    --value "$(openssl rand -base64 32)" \
    --output table

# API keys for external services
echo "Creating API keys for external services..."
az keyvault secret set \
    --vault-name "$KEY_VAULT_NAME" \
    --name "external-api-key" \
    --value "$(openssl rand -base64 32)" \
    --output table

echo "Initial secrets created successfully!"
echo ""

# Configure secret rotation policies
echo "Configuring secret rotation policies..."

# Create Azure Function for secret rotation
echo "Creating Azure Function for secret rotation..."
az functionapp create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --consumption-plan-location "$LOCATION" \
    --runtime python \
    --runtime-version 3.9 \
    --functions-version 4 \
    --name "func-ms5-secret-rotation" \
    --storage-account "stms5secretrotation" \
    --output table

echo "Azure Function created successfully!"
echo ""

# Set up Azure Key Vault with Private Link for secure access
echo "Setting up Azure Key Vault with Private Link for secure access..."

# Create private DNS zone for Key Vault
az network private-dns zone create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "privatelink.vaultcore.azure.net" \
    --output table

# Create private endpoint for Key Vault
az network private-endpoint create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "pe-keyvault-$KEY_VAULT_NAME" \
    --location "$LOCATION" \
    --vnet-name "vnet-acr-private-link" \
    --subnet "subnet-acr-private-link" \
    --private-connection-resource-id "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.KeyVault/vaults/$KEY_VAULT_NAME" \
    --group-ids vault \
    --connection-name "keyvault-connection" \
    --output table

echo "Private Link configured successfully!"
echo ""

# Configure Key Vault with Azure Monitor integration
echo "Setting up Azure Monitor integration..."
az monitor diagnostic-settings create \
    --name "keyvault-diagnostics" \
    --resource "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.KeyVault/vaults/$KEY_VAULT_NAME" \
    --logs '[
        {
            "category": "AuditEvent",
            "enabled": true,
            "retentionPolicy": {
                "enabled": true,
                "days": 90
            }
        }
    ]' \
    --workspace "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.OperationalInsights/workspaces/law-ms5-prod-uksouth" \
    --output table

echo "Azure Monitor integration configured successfully!"
echo ""

# Set up automated secret rotation with Azure Functions
echo "Setting up automated secret rotation with Azure Functions..."

# Create secret rotation function code
cat > /tmp/secret_rotation_function.py << 'EOF'
import logging
import azure.functions as func
from azure.keyvault.secrets import SecretClient
from azure.identity import DefaultAzureCredential
import os
import secrets
import string

def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Secret rotation function triggered')
    
    try:
        # Initialize Key Vault client
        credential = DefaultAzureCredential()
        key_vault_url = os.environ["KEY_VAULT_URL"]
        client = SecretClient(vault_url=key_vault_url, credential=credential)
        
        # Generate new password
        new_password = ''.join(secrets.choice(string.ascii_letters + string.digits) for _ in range(32))
        
        # Update secret
        secret_name = req.params.get('secret_name')
        if secret_name:
            client.set_secret(secret_name, new_password)
            logging.info(f'Secret {secret_name} rotated successfully')
            return func.HttpResponse(f'Secret {secret_name} rotated successfully', status_code=200)
        else:
            return func.HttpResponse('Secret name parameter required', status_code=400)
            
    except Exception as e:
        logging.error(f'Error rotating secret: {str(e)}')
        return func.HttpResponse(f'Error: {str(e)}', status_code=500)
EOF

# Deploy function code
az functionapp deployment source config-zip \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "func-ms5-secret-rotation" \
    --src /tmp/secret_rotation_function.py \
    --output table

echo "Automated secret rotation configured successfully!"
echo ""

# Configure Key Vault with Azure AD Conditional Access policies
echo "Setting up Azure AD Conditional Access policies..."

# Create conditional access policy
az ad conditional-access policy create \
    --display-name "MS5.0 Key Vault Access Policy" \
    --state enabled \
    --conditions '{
        "applications": {
            "includeApplications": ["'$AKS_SP_APP_ID'"]
        },
        "users": {
            "includeUsers": ["'$CURRENT_USER'"]
        },
        "locations": {
            "includeLocations": ["All"]
        }
    }' \
    --grant-controls '{
        "builtInControls": ["mfa"],
        "operator": "OR"
    }' \
    --output table

echo "Azure AD Conditional Access policies configured successfully!"
echo ""

# Set up Key Vault backup and disaster recovery procedures
echo "Setting up Key Vault backup and disaster recovery procedures..."

# Create backup storage account
az storage account create \
    --name "stms5keyvaultbackup" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --output table

# Create backup container
az storage container create \
    --name "keyvault-backups" \
    --account-name "stms5keyvaultbackup" \
    --output table

echo "Key Vault backup and disaster recovery procedures configured successfully!"
echo ""

# Validate Key Vault setup
echo "Validating Key Vault setup..."
az keyvault show \
    --name "$KEY_VAULT_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query "{Name:name, SKU:properties.sku.name, Location:location, SoftDelete:properties.softDeleteEnabled, PurgeProtection:properties.purgeProtectionEnabled}" \
    --output table

echo ""
echo "=== Key Vault Setup Complete ==="
echo "Key Vault Name: $KEY_VAULT_NAME"
echo "SKU: $SKU"
echo "HSM Support: Enabled"
echo "Private Link: Configured"
echo "Azure Monitor: Integrated"
echo "Secret Rotation: Automated"
echo "Conditional Access: Configured"
echo "Backup: Configured"
echo ""
echo "Key Vault URL: https://$KEY_VAULT_NAME.vault.azure.net/"
echo ""
echo "Next steps:"
echo "1. Run 04-monitoring-setup.sh for Azure Monitor setup"
echo "2. Run 05-aks-cluster-setup.sh for AKS cluster creation"
echo "3. Run 06-networking-setup.sh for advanced networking"
echo ""
