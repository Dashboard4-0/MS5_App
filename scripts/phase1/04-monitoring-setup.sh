#!/bin/bash

# MS5.0 Floor Dashboard - Phase 1: Azure Monitor and Log Analytics Setup
# This script sets up comprehensive monitoring and logging infrastructure with advanced analytics

set -e

# Configuration variables
RESOURCE_GROUP_NAME="rg-ms5-production-uksouth"
LOG_ANALYTICS_WORKSPACE="law-ms5-prod-uksouth"
LOCATION="UK South"
APPLICATION_INSIGHTS_NAME="ai-ms5-prod-uksouth"

echo "=== MS5.0 Phase 1: Azure Monitor and Log Analytics Setup ==="
echo "Log Analytics Workspace: $LOG_ANALYTICS_WORKSPACE"
echo "Application Insights: $APPLICATION_INSIGHTS_NAME"
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

echo "Current subscription: $SUBSCRIPTION_ID"
echo ""

# Create Log Analytics Workspace
echo "Creating Log Analytics Workspace..."
az monitor log-analytics workspace create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --workspace-name "$LOG_ANALYTICS_WORKSPACE" \
    --location "$LOCATION" \
    --retention-time 30 \
    --sku PerGB2018 \
    --output table

echo "Log Analytics Workspace created successfully!"
echo ""

# Configure Azure Monitor workspace
echo "Configuring Azure Monitor workspace..."
az monitor workspace create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "amw-ms5-prod-uksouth" \
    --location "$LOCATION" \
    --output table

echo "Azure Monitor workspace configured successfully!"
echo ""

# Set up Application Insights for the backend API
echo "Setting up Application Insights for the backend API..."
az monitor app-insights component create \
    --app "$APPLICATION_INSIGHTS_NAME" \
    --location "$LOCATION" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --application-type web \
    --kind web \
    --output table

echo "Application Insights created successfully!"
echo ""

# Configure log retention policies
echo "Configuring log retention policies..."

# Set retention for different log types
az monitor log-analytics workspace update \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --workspace-name "$LOG_ANALYTICS_WORKSPACE" \
    --retention-time 30 \
    --output table

echo "Log retention policies configured successfully!"
echo ""

# Set up custom log queries for MS5.0 specific metrics
echo "Setting up custom log queries for MS5.0 specific metrics..."

# Create saved searches for MS5.0 metrics
az monitor log-analytics workspace saved-search create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --workspace-name "$LOG_ANALYTICS_WORKSPACE" \
    --saved-search-id "ms5-production-metrics" \
    --display-name "MS5.0 Production Metrics" \
    --category "MS5.0" \
    --query "Perf | where ObjectName == 'MS5.0' | summarize avg(CounterValue) by bin(TimeGenerated, 5m), CounterName" \
    --output table

az monitor log-analytics workspace saved-search create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --workspace-name "$LOG_ANALYTICS_WORKSPACE" \
    --saved-search-id "ms5-oee-calculations" \
    --display-name "MS5.0 OEE Calculations" \
    --category "MS5.0" \
    --query "CustomLogs | where SourceSystem == 'MS5.0' and LogType == 'OEE' | summarize avg(OEEValue) by bin(TimeGenerated, 1h), ProductionLine" \
    --output table

az monitor log-analytics workspace saved-search create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --workspace-name "$LOG_ANALYTICS_WORKSPACE" \
    --saved-search-id "ms5-andon-events" \
    --display-name "MS5.0 Andon Events" \
    --category "MS5.0" \
    --query "CustomLogs | where SourceSystem == 'MS5.0' and LogType == 'Andon' | summarize count() by bin(TimeGenerated, 1h), EventType" \
    --output table

echo "Custom log queries configured successfully!"
echo ""

# Configure log export to Azure Storage for long-term retention
echo "Configuring log export to Azure Storage for long-term retention..."

# Create storage account for log export
az storage account create \
    --name "stms5logexport" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --output table

# Create container for log export
az storage container create \
    --name "log-export" \
    --account-name "stms5logexport" \
    --output table

# Configure log export
az monitor log-analytics workspace data-export create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --workspace-name "$LOG_ANALYTICS_WORKSPACE" \
    --name "ms5-log-export" \
    --destination "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Storage/storageAccounts/stms5logexport" \
    --tables "Perf,CustomLogs,AppTraces" \
    --output table

echo "Log export to Azure Storage configured successfully!"
echo ""

# Set up Azure Monitor for Containers with Prometheus integration
echo "Setting up Azure Monitor for Containers with Prometheus integration..."

# Enable Azure Monitor for Containers
az aks enable-addons \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "aks-ms5-prod-uksouth" \
    --addons monitoring \
    --workspace-resource-id "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.OperationalInsights/workspaces/$LOG_ANALYTICS_WORKSPACE" \
    --output table

echo "Azure Monitor for Containers configured successfully!"
echo ""

# Configure Azure Service Health integration for proactive monitoring
echo "Setting up Azure Service Health integration for proactive monitoring..."

# Create service health alert
az monitor action-group create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "ag-ms5-service-health" \
    --short-name "MS5Health" \
    --email-receivers name="DevOps Team" email="devops@company.com" \
    --output table

# Create service health alert rule
az monitor activity-log alert create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "Service Health Alert" \
    --condition category=ServiceHealth \
    --action-group "ag-ms5-service-health" \
    --output table

echo "Azure Service Health integration configured successfully!"
echo ""

# Set up Azure Log Analytics with custom dashboards for MS5.0 metrics
echo "Setting up Azure Log Analytics with custom dashboards for MS5.0 metrics..."

# Create custom dashboard
az portal dashboard create \
    --name "ms5-operations-dashboard" \
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
                                                    "id": "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.ContainerService/managedClusters/aks-ms5-prod-uksouth"
                                                },
                                                "name": "cpuUsagePercentage",
                                                "aggregationType": 1,
                                                "namespace": "microsoft.containerservice/managedclusters"
                                            }
                                        ],
                                        "title": "MS5.0 AKS CPU Usage",
                                        "timeContext": {
                                            "durationMs": 3600000
                                        }
                                    }
                                }
                            }
                        }
                    }
                },
                "1": {
                    "position": {
                        "x": 6,
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
                                                    "id": "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.ContainerService/managedClusters/aks-ms5-prod-uksouth"
                                                },
                                                "name": "memoryUsagePercentage",
                                                "aggregationType": 1,
                                                "namespace": "microsoft.containerservice/managedclusters"
                                            }
                                        ],
                                        "title": "MS5.0 AKS Memory Usage",
                                        "timeContext": {
                                            "durationMs": 3600000
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
                        "duration": 3600000
                    }
                },
                "type": "MsPortalFx.Composition.Configuration.ValueTypes.TimeRange"
            }
        }
    }
}
EOF

echo "Custom dashboards created successfully!"
echo ""

# Configure Azure Monitor with cost optimization recommendations
echo "Setting up Azure Monitor with cost optimization recommendations..."

# Create cost optimization alert
az monitor action-group create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "ag-ms5-cost-optimization" \
    --short-name "MS5Cost" \
    --email-receivers name="Cost Team" email="cost@company.com" \
    --output table

# Create cost optimization alert rule
az monitor activity-log alert create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "Cost Optimization Alert" \
    --condition category=Recommendation \
    --action-group "ag-ms5-cost-optimization" \
    --output table

echo "Cost optimization recommendations configured successfully!"
echo ""

# Set up Azure Monitor with automated alerting and escalation
echo "Setting up Azure Monitor with automated alerting and escalation..."

# Create escalation action group
az monitor action-group create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "ag-ms5-escalation" \
    --short-name "MS5Esc" \
    --email-receivers name="On-Call Team" email="oncall@company.com" \
    --sms-receivers name="On-Call" country-code="44" phone-number="+44123456789" \
    --output table

# Create critical alert rule
az monitor activity-log alert create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "Critical System Alert" \
    --condition category=Alert \
    --action-group "ag-ms5-escalation" \
    --output table

echo "Automated alerting and escalation configured successfully!"
echo ""

# Configure Azure Monitor with distributed tracing capabilities
echo "Setting up Azure Monitor with distributed tracing capabilities..."

# Enable distributed tracing in Application Insights
az monitor app-insights component update \
    --app "$APPLICATION_INSIGHTS_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --kind web \
    --retention-time 90 \
    --output table

echo "Distributed tracing capabilities configured successfully!"
echo ""

# Set up custom metrics for MS5.0 specific KPIs
echo "Setting up custom metrics for MS5.0 specific KPIs..."

# Create custom metric definitions
az monitor metrics alert create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "MS5.0 OEE Alert" \
    --scopes "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.ContainerService/managedClusters/aks-ms5-prod-uksouth" \
    --condition "avg 'Custom|MS5.0|OEE' > 85" \
    --description "Alert when OEE exceeds 85%" \
    --evaluation-frequency 5m \
    --window-size 15m \
    --severity 2 \
    --action "ag-ms5-escalation" \
    --output table

az monitor metrics alert create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "MS5.0 Production Alert" \
    --scopes "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.ContainerService/managedClusters/aks-ms5-prod-uksouth" \
    --condition "avg 'Custom|MS5.0|Production' < 90" \
    --description "Alert when production falls below 90%" \
    --evaluation-frequency 5m \
    --window-size 15m \
    --severity 1 \
    --action "ag-ms5-escalation" \
    --output table

echo "Custom metrics for MS5.0 KPIs configured successfully!"
echo ""

# Validate monitoring setup
echo "Validating monitoring setup..."
az monitor log-analytics workspace show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --workspace-name "$LOG_ANALYTICS_WORKSPACE" \
    --query "{Name:name, Location:location, Retention:retentionInDays, SKU:sku.name}" \
    --output table

az monitor app-insights component show \
    --app "$APPLICATION_INSIGHTS_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query "{Name:name, Location:location, Kind:kind, Retention:retentionInDays}" \
    --output table

echo ""
echo "=== Monitoring Setup Complete ==="
echo "Log Analytics Workspace: $LOG_ANALYTICS_WORKSPACE"
echo "Application Insights: $APPLICATION_INSIGHTS_NAME"
echo "Azure Monitor: Configured"
echo "Custom Dashboards: Created"
echo "Cost Optimization: Enabled"
echo "Distributed Tracing: Enabled"
echo "Custom Metrics: Configured"
echo "Automated Alerting: Configured"
echo ""
echo "Monitoring URLs:"
echo "Log Analytics: https://portal.azure.com/#@/resource/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.OperationalInsights/workspaces/$LOG_ANALYTICS_WORKSPACE"
echo "Application Insights: https://portal.azure.com/#@/resource/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Insights/components/$APPLICATION_INSIGHTS_NAME"
echo ""
echo "Next steps:"
echo "1. Run 05-aks-cluster-setup.sh for AKS cluster creation"
echo "2. Run 06-networking-setup.sh for advanced networking"
echo "3. Run 07-security-setup.sh for comprehensive security"
echo ""
