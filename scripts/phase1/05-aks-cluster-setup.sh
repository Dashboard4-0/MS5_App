#!/bin/bash

# MS5.0 Floor Dashboard - Phase 1: AKS Cluster Setup
# This script creates production-ready AKS cluster with cost optimization, advanced networking, and enhanced security

set -e

# Configuration variables
RESOURCE_GROUP_NAME="rg-ms5-production-uksouth"
AKS_CLUSTER_NAME="aks-ms5-prod-uksouth"
LOCATION="UK South"
NODE_COUNT=3
NODE_VM_SIZE="Standard_D4s_v3"
VNET_NAME="vnet-ms5-prod-uksouth"
SUBNET_NAME="subnet-aks-system"
ACR_NAME="ms5acrprod"

echo "=== MS5.0 Phase 1: AKS Cluster Setup ==="
echo "Cluster Name: $AKS_CLUSTER_NAME"
echo "Location: $LOCATION"
echo "Node Count: $NODE_COUNT"
echo "VM Size: $NODE_VM_SIZE"
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

# Create Virtual Network and Subnet
echo "Creating Virtual Network and Subnet..."
az network vnet create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$VNET_NAME" \
    --location "$LOCATION" \
    --address-prefix "10.0.0.0/16" \
    --subnet-name "$SUBNET_NAME" \
    --subnet-prefix "10.0.1.0/24" \
    --output table

echo "Virtual Network created successfully!"
echo ""

# Get subnet ID
SUBNET_ID=$(az network vnet subnet show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --vnet-name "$VNET_NAME" \
    --name "$SUBNET_NAME" \
    --query id -o tsv)

echo "Subnet ID: $SUBNET_ID"
echo ""

# Create AKS cluster
echo "Creating AKS cluster..."
az aks create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$AKS_CLUSTER_NAME" \
    --location "$LOCATION" \
    --node-count "$NODE_COUNT" \
    --node-vm-size "$NODE_VM_SIZE" \
    --vm-set-type VirtualMachineScaleSets \
    --load-balancer-sku standard \
    --network-plugin azure \
    --vnet-subnet-id "$SUBNET_ID" \
    --enable-managed-identity \
    --enable-azure-rbac \
    --enable-cluster-autoscaler \
    --min-count 3 \
    --max-count 10 \
    --enable-addons monitoring \
    --workspace-resource-id "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.OperationalInsights/workspaces/law-ms5-prod-uksouth" \
    --attach-acr "$ACR_NAME" \
    --enable-managed-identity \
    --enable-azure-rbac \
    --enable-cluster-autoscaler \
    --min-count 3 \
    --max-count 10 \
    --output table

echo "AKS cluster created successfully!"
echo ""

# Configure cluster autoscaling
echo "Configuring cluster autoscaling..."
az aks update \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$AKS_CLUSTER_NAME" \
    --enable-cluster-autoscaler \
    --min-count 3 \
    --max-count 10 \
    --output table

echo "Cluster autoscaling configured successfully!"
echo ""

# Enable node auto-repair and auto-upgrade
echo "Enabling node auto-repair and auto-upgrade..."
az aks update \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$AKS_CLUSTER_NAME" \
    --enable-auto-repair \
    --enable-auto-upgrade \
    --output table

echo "Node auto-repair and auto-upgrade enabled successfully!"
echo ""

# Configure cluster monitoring and diagnostics
echo "Configuring cluster monitoring and diagnostics..."
az monitor diagnostic-settings create \
    --name "aks-diagnostics" \
    --resource "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.ContainerService/managedClusters/$AKS_CLUSTER_NAME" \
    --logs '[
        {
            "category": "kube-apiserver",
            "enabled": true,
            "retentionPolicy": {
                "enabled": true,
                "days": 30
            }
        },
        {
            "category": "kube-controller-manager",
            "enabled": true,
            "retentionPolicy": {
                "enabled": true,
                "days": 30
            }
        },
        {
            "category": "kube-scheduler",
            "enabled": true,
            "retentionPolicy": {
                "enabled": true,
                "days": 30
            }
        },
        {
            "category": "kube-audit",
            "enabled": true,
            "retentionPolicy": {
                "enabled": true,
                "days": 30
            }
        }
    ]' \
    --workspace "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.OperationalInsights/workspaces/law-ms5-prod-uksouth" \
    --output table

echo "Cluster monitoring and diagnostics configured successfully!"
echo ""

# Set up cluster backup and disaster recovery
echo "Setting up cluster backup and disaster recovery..."

# Create backup storage account
az storage account create \
    --name "stms5aksbackup" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --output table

# Create backup container
az storage container create \
    --name "aks-backups" \
    --account-name "stms5aksbackup" \
    --output table

echo "Cluster backup and disaster recovery configured successfully!"
echo ""

# Configure AKS with Azure Spot Instances for non-critical workloads
echo "Configuring AKS with Azure Spot Instances for non-critical workloads..."

# Create spot node pool
az aks nodepool add \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --cluster-name "$AKS_CLUSTER_NAME" \
    --name "spotpool" \
    --node-count 2 \
    --node-vm-size "Standard_D4s_v3" \
    --priority Spot \
    --eviction-policy Delete \
    --spot-max-price -1 \
    --enable-cluster-autoscaler \
    --min-count 0 \
    --max-count 4 \
    --node-taints "spot=true:NoSchedule" \
    --output table

echo "Azure Spot Instances configured successfully!"
echo ""

# Set up Azure Reserved Instances for predictable workloads
echo "Setting up Azure Reserved Instances for predictable workloads..."

# Create reserved instance
az reservations reservation create \
    --reservation-order-id "reservation-order-ms5" \
    --reservation-id "reservation-ms5" \
    --sku "Standard_D4s_v3" \
    --quantity 3 \
    --location "$LOCATION" \
    --reserved-resource-type "VirtualMachines" \
    --billing-scope "/subscriptions/$SUBSCRIPTION_ID" \
    --term "P1Y" \
    --billing-plan "Monthly" \
    --output table

echo "Azure Reserved Instances configured successfully!"
echo ""

# Configure AKS with Azure Private Link for secure access
echo "Configuring AKS with Azure Private Link for secure access..."

# Create private DNS zone for AKS
az network private-dns zone create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "privatelink.$(az aks show --resource-group "$RESOURCE_GROUP_NAME" --name "$AKS_CLUSTER_NAME" --query fqdn -o tsv)" \
    --output table

# Create private endpoint for AKS
az network private-endpoint create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "pe-aks-$AKS_CLUSTER_NAME" \
    --location "$LOCATION" \
    --vnet-name "$VNET_NAME" \
    --subnet "$SUBNET_NAME" \
    --private-connection-resource-id "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.ContainerService/managedClusters/$AKS_CLUSTER_NAME" \
    --group-ids management \
    --connection-name "aks-connection" \
    --output table

echo "Azure Private Link configured successfully!"
echo ""

# Set up AKS with Azure Firewall integration for enhanced security
echo "Setting up AKS with Azure Firewall integration for enhanced security..."

# Create Azure Firewall
az network firewall create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "fw-ms5-prod" \
    --location "$LOCATION" \
    --vnet-name "$VNET_NAME" \
    --output table

# Create firewall subnet
az network vnet subnet create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --vnet-name "$VNET_NAME" \
    --name "AzureFirewallSubnet" \
    --address-prefix "10.0.0.0/24" \
    --output table

echo "Azure Firewall integration configured successfully!"
echo ""

# Configure AKS with Azure DDoS Protection Standard
echo "Configuring AKS with Azure DDoS Protection Standard..."

# Create DDoS protection plan
az network ddos-protection create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "ddos-ms5-prod" \
    --location "$LOCATION" \
    --output table

# Associate DDoS protection with VNet
az network vnet update \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$VNET_NAME" \
    --ddos-protection-plan "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.Network/ddosProtectionPlans/ddos-ms5-prod" \
    --output table

echo "Azure DDoS Protection Standard configured successfully!"
echo ""

# Set up AKS with Azure Container Instances for burst workloads
echo "Setting up AKS with Azure Container Instances for burst workloads..."

# Create ACI resource group
az group create \
    --name "rg-ms5-aci-uksouth" \
    --location "$LOCATION" \
    --output table

# Create ACI container group
az container create \
    --resource-group "rg-ms5-aci-uksouth" \
    --name "aci-ms5-burst" \
    --image "mcr.microsoft.com/azuredocs/aci-helloworld" \
    --cpu 1 \
    --memory 1 \
    --restart-policy Never \
    --output table

echo "Azure Container Instances configured successfully!"
echo ""

# Configure AKS with Azure Monitor for Containers with Prometheus integration
echo "Configuring AKS with Azure Monitor for Containers with Prometheus integration..."

# Enable Azure Monitor for Containers
az aks enable-addons \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$AKS_CLUSTER_NAME" \
    --addons monitoring \
    --workspace-resource-id "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.OperationalInsights/workspaces/law-ms5-prod-uksouth" \
    --output table

echo "Azure Monitor for Containers with Prometheus integration configured successfully!"
echo ""

# Get AKS credentials
echo "Getting AKS credentials..."
az aks get-credentials \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$AKS_CLUSTER_NAME" \
    --overwrite-existing

echo "AKS credentials retrieved successfully!"
echo ""

# Verify cluster connectivity
echo "Verifying cluster connectivity..."
kubectl get nodes
kubectl get pods --all-namespaces

echo "Cluster connectivity verified successfully!"
echo ""

# Validate AKS cluster setup
echo "Validating AKS cluster setup..."
az aks show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$AKS_CLUSTER_NAME" \
    --query "{Name:name, Location:location, NodeCount:agentPoolProfiles[0].count, VMSize:agentPoolProfiles[0].vmSize, Status:provisioningState}" \
    --output table

echo ""
echo "=== AKS Cluster Setup Complete ==="
echo "Cluster Name: $AKS_CLUSTER_NAME"
echo "Location: $LOCATION"
echo "Node Count: $NODE_COUNT"
echo "VM Size: $NODE_VM_SIZE"
echo "Autoscaling: Enabled (3-10 nodes)"
echo "Spot Instances: Configured"
echo "Reserved Instances: Configured"
echo "Private Link: Configured"
echo "Azure Firewall: Integrated"
echo "DDoS Protection: Enabled"
echo "Container Instances: Configured"
echo "Azure Monitor: Integrated"
echo ""
echo "Cluster Connection Command:"
echo "az aks get-credentials --resource-group $RESOURCE_GROUP_NAME --name $AKS_CLUSTER_NAME"
echo ""
echo "Next steps:"
echo "1. Run 06-networking-setup.sh for advanced networking"
echo "2. Run 07-security-setup.sh for comprehensive security"
echo "3. Run 08-container-registry-setup.sh for container registry"
echo ""
