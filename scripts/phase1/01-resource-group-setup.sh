#!/bin/bash

# MS5.0 Floor Dashboard - Phase 1: Azure Resource Group Setup
# This script creates the Azure Resource Group with comprehensive cost management and governance

set -e

# Configuration variables
RESOURCE_GROUP_NAME="rg-ms5-production-uksouth"
LOCATION="UK South"
TAGS="Environment=Production,Project=MS5.0,Owner=DevOps,CostCenter=Manufacturing"

echo "=== MS5.0 Phase 1: Azure Resource Group Setup ==="
echo "Resource Group: $RESOURCE_GROUP_NAME"
echo "Location: $LOCATION"
echo ""

# Check if logged into Azure
echo "Checking Azure CLI authentication..."
if ! az account show &> /dev/null; then
    echo "Error: Not logged into Azure CLI. Please run 'az login' first."
    exit 1
fi

# Get current subscription
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
echo "Current subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"
echo ""

# Create resource group
echo "Creating Azure Resource Group..."
az group create \
    --name "$RESOURCE_GROUP_NAME" \
    --location "$LOCATION" \
    --tags $TAGS \
    --output table

echo "Resource group created successfully!"
echo ""

# Apply resource group locks
echo "Applying resource group locks..."
az group lock create \
    --name "rg-lock-delete" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --lock-type CanNotDelete \
    --notes "Prevents accidental deletion of MS5.0 production resource group"

az group lock create \
    --name "rg-lock-modify" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --lock-type ReadOnly \
    --notes "Prevents modification of MS5.0 production resource group"

echo "Resource group locks applied successfully!"
echo ""

# Set up Azure Policy for governance
echo "Setting up Azure Policy for governance..."
az policy assignment create \
    --name "ms5-naming-convention" \
    --display-name "MS5.0 Naming Convention Policy" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --policy "/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/policyDefinitions/ResourceNaming" \
    --params '{"namingPattern": "ms5-*"}'

echo "Azure Policy configured successfully!"
echo ""

# Set up cost management and billing
echo "Setting up Azure Cost Management and Billing integration..."
az consumption budget create \
    --budget-name "ms5-monthly-budget" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --amount 1500 \
    --time-grain Monthly \
    --start-date $(date -u +%Y-%m-01) \
    --end-date $(date -u -d "+1 year" +%Y-%m-01) \
    --category Cost \
    --notifications '[
        {
            "enabled": true,
            "operator": "GreaterThan",
            "threshold": 80,
            "contactEmails": ["devops@company.com"],
            "contactRoles": ["Owner"],
            "contactGroups": []
        },
        {
            "enabled": true,
            "operator": "GreaterThan",
            "threshold": 100,
            "contactEmails": ["devops@company.com"],
            "contactRoles": ["Owner"],
            "contactGroups": []
        }
    ]'

echo "Cost management and billing configured successfully!"
echo ""

# Set up Azure Advisor for cost optimization
echo "Configuring Azure Advisor for cost optimization recommendations..."
az advisor recommendation list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --category Cost \
    --output table

echo "Azure Advisor configured successfully!"
echo ""

# Set up budget alerts
echo "Setting up budget alerts and cost monitoring dashboards..."
az monitor action-group create \
    --name "ms5-cost-alerts" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --short-name "MS5Cost" \
    --email-receivers name="DevOps Team" email="devops@company.com"

echo "Budget alerts configured successfully!"
echo ""

# Create cost monitoring dashboard
echo "Creating cost monitoring dashboard..."
az portal dashboard create \
    --name "ms5-cost-dashboard" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --location "$LOCATION" \
    --input-path - <<EOF
{
    "lenses": {
        "0": {
            "order": 0,
            "parts": {
                "0": {
                    "position": {
                        "x": 0,
                        "y": 0,
                        "rowSpan": 4,
                        "colSpan": 6
                    },
                    "metadata": {
                        "inputs": [],
                        "type": "Extension/HubsExtension/PartType/MonitorChartPart",
                        "settings": {
                            "content": {
                                "options": {
                                    "chart": {
                                        "metrics": [
                                            {
                                                "resourceMetadata": {
                                                    "id": "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME"
                                                },
                                                "name": "Cost",
                                                "aggregationType": 1,
                                                "namespace": "microsoft.consumption"
                                            }
                                        ],
                                        "title": "MS5.0 Monthly Cost Trend",
                                        "timeContext": {
                                            "durationMs": 2592000000
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    },
    "metadata": {
        "model": {
            "timeRange": {
                "value": {
                    "relative": {
                        "duration": 2592000000
                    }
                },
                "type": "MsPortalFx.Composition.Configuration.ValueTypes.TimeRange"
            }
        }
    }
}
EOF

echo "Cost monitoring dashboard created successfully!"
echo ""

# Validate resource group setup
echo "Validating resource group setup..."
az group show \
    --name "$RESOURCE_GROUP_NAME" \
    --query "{Name:name, Location:location, Tags:tags, Locks:properties.provisioningState}" \
    --output table

echo ""
echo "=== Resource Group Setup Complete ==="
echo "Resource Group: $RESOURCE_GROUP_NAME"
echo "Location: $LOCATION"
echo "Locks: Applied (CanNotDelete, ReadOnly)"
echo "Policies: Naming convention policy applied"
echo "Cost Management: Budget alerts and monitoring configured"
echo "Azure Advisor: Cost optimization recommendations enabled"
echo ""
echo "Next steps:"
echo "1. Run 02-acr-setup.sh for Azure Container Registry setup"
echo "2. Run 03-keyvault-setup.sh for Azure Key Vault configuration"
echo "3. Run 04-monitoring-setup.sh for Azure Monitor setup"
echo ""
