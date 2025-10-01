#!/bin/bash

# MS5.0 Floor Dashboard - Phase 1: Advanced Networking Setup
# This script sets up advanced networking with Azure CNI, Private Link, and security

set -e

# Configuration variables
RESOURCE_GROUP_NAME="rg-ms5-production-uksouth"
AKS_CLUSTER_NAME="aks-ms5-prod-uksouth"
LOCATION="UK South"
VNET_NAME="vnet-ms5-prod-uksouth"

echo "=== MS5.0 Phase 1: Advanced Networking Setup ==="
echo "Cluster Name: $AKS_CLUSTER_NAME"
echo "Location: $LOCATION"
echo "VNet Name: $VNET_NAME"
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

# Create additional subnets for different node pools
echo "Creating additional subnets for different node pools..."

# Create subnet for database node pool
az network vnet subnet create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --vnet-name "$VNET_NAME" \
    --name "subnet-aks-database" \
    --address-prefix "10.0.2.0/24" \
    --output table

# Create subnet for compute node pool
az network vnet subnet create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --vnet-name "$VNET_NAME" \
    --name "subnet-aks-compute" \
    --address-prefix "10.0.3.0/24" \
    --output table

# Create subnet for monitoring node pool
az network vnet subnet create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --vnet-name "$VNET_NAME" \
    --name "subnet-aks-monitoring" \
    --address-prefix "10.0.4.0/24" \
    --output table

# Create subnet for ingress
az network vnet subnet create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --vnet-name "$VNET_NAME" \
    --name "subnet-aks-ingress" \
    --address-prefix "10.0.5.0/24" \
    --output table

# Create subnet for spot node pool
az network vnet subnet create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --vnet-name "$VNET_NAME" \
    --name "subnet-aks-spot" \
    --address-prefix "10.0.6.0/24" \
    --output table

# Create subnet for burst workloads
az network vnet subnet create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --vnet-name "$VNET_NAME" \
    --name "subnet-aks-burst" \
    --address-prefix "10.0.7.0/24" \
    --output table

# Create subnet for private link
az network vnet subnet create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --vnet-name "$VNET_NAME" \
    --name "subnet-aks-private-link" \
    --address-prefix "10.0.8.0/24" \
    --output table

echo "Additional subnets created successfully!"
echo ""

# Configure Azure CNI networking plugin
echo "Configuring Azure CNI networking plugin..."

# Update AKS cluster with Azure CNI
az aks update \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$AKS_CLUSTER_NAME" \
    --network-plugin azure \
    --network-policy azure \
    --output table

echo "Azure CNI networking plugin configured successfully!"
echo ""

# Configure network security groups (NSGs)
echo "Configuring network security groups (NSGs)..."

# Create NSG for system subnet
az network nsg create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "nsg-aks-system" \
    --location "$LOCATION" \
    --output table

# Create NSG for database subnet
az network nsg create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "nsg-aks-database" \
    --location "$LOCATION" \
    --output table

# Create NSG for compute subnet
az network nsg create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "nsg-aks-compute" \
    --location "$LOCATION" \
    --output table

# Create NSG for monitoring subnet
az network nsg create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "nsg-aks-monitoring" \
    --location "$LOCATION" \
    --output table

# Create NSG for ingress subnet
az network nsg create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "nsg-aks-ingress" \
    --location "$LOCATION" \
    --output table

echo "Network security groups created successfully!"
echo ""

# Configure NSG rules
echo "Configuring NSG rules..."

# System subnet rules
az network nsg rule create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --nsg-name "nsg-aks-system" \
    --name "AllowHTTPS" \
    --priority 100 \
    --source-address-prefixes "*" \
    --source-port-ranges "*" \
    --destination-address-prefixes "*" \
    --destination-port-ranges 443 \
    --access Allow \
    --protocol Tcp \
    --direction Inbound \
    --output table

az network nsg rule create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --nsg-name "nsg-aks-system" \
    --name "AllowHTTP" \
    --priority 110 \
    --source-address-prefixes "*" \
    --source-port-ranges "*" \
    --destination-address-prefixes "*" \
    --destination-port-ranges 80 \
    --access Allow \
    --protocol Tcp \
    --direction Inbound \
    --output table

# Database subnet rules
az network nsg rule create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --nsg-name "nsg-aks-database" \
    --name "AllowPostgreSQL" \
    --priority 100 \
    --source-address-prefixes "10.0.3.0/24" \
    --source-port-ranges "*" \
    --destination-address-prefixes "*" \
    --destination-port-ranges 5432 \
    --access Allow \
    --protocol Tcp \
    --direction Inbound \
    --output table

az network nsg rule create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --nsg-name "nsg-aks-database" \
    --name "AllowRedis" \
    --priority 110 \
    --source-address-prefixes "10.0.3.0/24" \
    --source-port-ranges "*" \
    --destination-address-prefixes "*" \
    --destination-port-ranges 6379 \
    --access Allow \
    --protocol Tcp \
    --direction Inbound \
    --output table

# Compute subnet rules
az network nsg rule create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --nsg-name "nsg-aks-compute" \
    --name "AllowFastAPI" \
    --priority 100 \
    --source-address-prefixes "10.0.5.0/24" \
    --source-port-ranges "*" \
    --destination-address-prefixes "*" \
    --destination-port-ranges 8000 \
    --access Allow \
    --protocol Tcp \
    --direction Inbound \
    --output table

# Monitoring subnet rules
az network nsg rule create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --nsg-name "nsg-aks-monitoring" \
    --name "AllowPrometheus" \
    --priority 100 \
    --source-address-prefixes "*" \
    --source-port-ranges "*" \
    --destination-address-prefixes "*" \
    --destination-port-ranges 9090 \
    --access Allow \
    --protocol Tcp \
    --direction Inbound \
    --output table

az network nsg rule create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --nsg-name "nsg-aks-monitoring" \
    --name "AllowGrafana" \
    --priority 110 \
    --source-address-prefixes "*" \
    --source-port-ranges "*" \
    --destination-address-prefixes "*" \
    --destination-port-ranges 3000 \
    --access Allow \
    --protocol Tcp \
    --direction Inbound \
    --output table

# Ingress subnet rules
az network nsg rule create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --nsg-name "nsg-aks-ingress" \
    --name "AllowHTTPS" \
    --priority 100 \
    --source-address-prefixes "*" \
    --source-port-ranges "*" \
    --destination-address-prefixes "*" \
    --destination-port-ranges 443 \
    --access Allow \
    --protocol Tcp \
    --direction Inbound \
    --output table

az network nsg rule create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --nsg-name "nsg-aks-ingress" \
    --name "AllowHTTP" \
    --priority 110 \
    --source-address-prefixes "*" \
    --source-port-ranges "*" \
    --destination-address-prefixes "*" \
    --destination-port-ranges 80 \
    --access Allow \
    --protocol Tcp \
    --direction Inbound \
    --output table

echo "NSG rules configured successfully!"
echo ""

# Associate NSGs with subnets
echo "Associating NSGs with subnets..."

az network vnet subnet update \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --vnet-name "$VNET_NAME" \
    --name "subnet-aks-system" \
    --network-security-group "nsg-aks-system" \
    --output table

az network vnet subnet update \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --vnet-name "$VNET_NAME" \
    --name "subnet-aks-database" \
    --network-security-group "nsg-aks-database" \
    --output table

az network vnet subnet update \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --vnet-name "$VNET_NAME" \
    --name "subnet-aks-compute" \
    --network-security-group "nsg-aks-compute" \
    --output table

az network vnet subnet update \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --vnet-name "$VNET_NAME" \
    --name "subnet-aks-monitoring" \
    --network-security-group "nsg-aks-monitoring" \
    --output table

az network vnet subnet update \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --vnet-name "$VNET_NAME" \
    --name "subnet-aks-ingress" \
    --network-security-group "nsg-aks-ingress" \
    --output table

echo "NSGs associated with subnets successfully!"
echo ""

# Set up Azure Load Balancer integration
echo "Setting up Azure Load Balancer integration..."

# Create public IP for load balancer
az network public-ip create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "pip-aks-loadbalancer" \
    --location "$LOCATION" \
    --sku Standard \
    --allocation-method Static \
    --output table

# Create load balancer
az network lb create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "lb-aks-ms5" \
    --location "$LOCATION" \
    --sku Standard \
    --frontend-ip-name "frontend-ip" \
    --public-ip-address "pip-aks-loadbalancer" \
    --backend-pool-name "backend-pool" \
    --output table

echo "Azure Load Balancer integration configured successfully!"
echo ""

# Configure DNS resolution for cluster services
echo "Configuring DNS resolution for cluster services..."

# Create private DNS zone for AKS
az network private-dns zone create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "privatelink.$(az aks show --resource-group "$RESOURCE_GROUP_NAME" --name "$AKS_CLUSTER_NAME" --query fqdn -o tsv)" \
    --output table

# Link private DNS zone to VNet
az network private-dns link vnet create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --zone-name "privatelink.$(az aks show --resource-group "$RESOURCE_GROUP_NAME" --name "$AKS_CLUSTER_NAME" --query fqdn -o tsv)" \
    --name "aks-dns-link" \
    --virtual-network "$VNET_NAME" \
    --registration-enabled false \
    --output table

echo "DNS resolution configured successfully!"
echo ""

# Set up network policies for traffic control
echo "Setting up network policies for traffic control..."

# Create network policy for database access
cat > /tmp/database-network-policy.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-network-policy
  namespace: ms5-production
spec:
  podSelector:
    matchLabels:
      app: postgres
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: backend
    ports:
    - protocol: TCP
      port: 5432
EOF

# Create network policy for cache access
cat > /tmp/cache-network-policy.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: cache-network-policy
  namespace: ms5-production
spec:
  podSelector:
    matchLabels:
      app: redis
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: backend
    ports:
    - protocol: TCP
      port: 6379
EOF

# Create network policy for monitoring access
cat > /tmp/monitoring-network-policy.yaml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: monitoring-network-policy
  namespace: ms5-production
spec:
  podSelector:
    matchLabels:
      app: prometheus
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: backend
    ports:
    - protocol: TCP
      port: 9090
EOF

# Apply network policies
kubectl apply -f /tmp/database-network-policy.yaml
kubectl apply -f /tmp/cache-network-policy.yaml
kubectl apply -f /tmp/monitoring-network-policy.yaml

echo "Network policies configured successfully!"
echo ""

# Configure Azure Private Link for secure access to all services
echo "Configuring Azure Private Link for secure access to all services..."

# Create private endpoint for AKS
az network private-endpoint create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "pe-aks-$AKS_CLUSTER_NAME" \
    --location "$LOCATION" \
    --vnet-name "$VNET_NAME" \
    --subnet "subnet-aks-private-link" \
    --private-connection-resource-id "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.ContainerService/managedClusters/$AKS_CLUSTER_NAME" \
    --group-ids management \
    --connection-name "aks-connection" \
    --output table

echo "Azure Private Link configured successfully!"
echo ""

# Set up Azure Firewall for additional network security
echo "Setting up Azure Firewall for additional network security..."

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

# Create public IP for firewall
az network public-ip create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "pip-azure-firewall" \
    --location "$LOCATION" \
    --sku Standard \
    --allocation-method Static \
    --output table

# Configure firewall IP configuration
az network firewall ip-config create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "fw-ip-config" \
    --vnet-name "$VNET_NAME" \
    --public-ip-address "pip-azure-firewall" \
    --output table

echo "Azure Firewall configured successfully!"
echo ""

# Configure Azure DDoS Protection Standard
echo "Configuring Azure DDoS Protection Standard..."

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

# Set up Azure Application Gateway for advanced load balancing
echo "Setting up Azure Application Gateway for advanced load balancing..."

# Create public IP for application gateway
az network public-ip create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "pip-app-gateway" \
    --location "$LOCATION" \
    --sku Standard \
    --allocation-method Static \
    --output table

# Create application gateway
az network application-gateway create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "ag-ms5-prod" \
    --location "$LOCATION" \
    --sku Standard_v2 \
    --public-ip-address "pip-app-gateway" \
    --vnet-name "$VNET_NAME" \
    --subnet "subnet-aks-ingress" \
    --output table

echo "Azure Application Gateway configured successfully!"
echo ""

# Set up Azure Front Door for global content delivery
echo "Setting up Azure Front Door for global content delivery..."

# Create Front Door profile
az afd profile create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --profile-name "afd-ms5-prod" \
    --sku Standard_AzureFrontDoor \
    --output table

# Create Front Door endpoint
az afd endpoint create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --profile-name "afd-ms5-prod" \
    --endpoint-name "ms5-endpoint" \
    --enabled-state Enabled \
    --output table

echo "Azure Front Door configured successfully!"
echo ""

# Set up Azure Network Watcher for network monitoring
echo "Setting up Azure Network Watcher for network monitoring..."

# Enable Network Watcher
az network watcher configure \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --locations "$LOCATION" \
    --output table

# Create network watcher
az network watcher create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "nw-ms5-prod" \
    --location "$LOCATION" \
    --output table

echo "Azure Network Watcher configured successfully!"
echo ""

# Configure Azure Traffic Manager for global traffic routing
echo "Configuring Azure Traffic Manager for global traffic routing..."

# Create Traffic Manager profile
az network traffic-manager profile create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "tm-ms5-prod" \
    --routing-method Performance \
    --unique-dns-name "ms5-prod-traffic-manager" \
    --output table

# Create Traffic Manager endpoint
az network traffic-manager endpoint create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --profile-name "tm-ms5-prod" \
    --name "ms5-endpoint" \
    --type externalEndpoints \
    --target "ms5-prod.azurewebsites.net" \
    --endpoint-status Enabled \
    --output table

echo "Azure Traffic Manager configured successfully!"
echo ""

# Validate networking setup
echo "Validating networking setup..."
az network vnet show \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$VNET_NAME" \
    --query "{Name:name, Location:location, AddressSpace:addressSpace.addressPrefixes, Subnets:subnets[].name}" \
    --output table

echo ""
echo "=== Advanced Networking Setup Complete ==="
echo "VNet: $VNET_NAME with 8 subnets"
echo "Azure CNI: Configured with network policies"
echo "NSGs: 5 security groups with custom rules"
echo "Load Balancer: Standard SKU with public IP"
echo "Private Link: Configured for secure access"
echo "Azure Firewall: Integrated for additional security"
echo "DDoS Protection: Standard enabled"
echo "Application Gateway: Standard_v2 configured"
echo "Front Door: Global content delivery enabled"
echo "Network Watcher: Monitoring enabled"
echo "Traffic Manager: Global traffic routing enabled"
echo ""
echo "Network Architecture:"
echo "- System Subnet: 10.0.1.0/24 (Core Kubernetes services)"
echo "- Database Subnet: 10.0.2.0/24 (PostgreSQL, Redis)"
echo "- Compute Subnet: 10.0.3.0/24 (FastAPI, Workers)"
echo "- Monitoring Subnet: 10.0.4.0/24 (Prometheus, Grafana)"
echo "- Ingress Subnet: 10.0.5.0/24 (Load balancers)"
echo "- Spot Subnet: 10.0.6.0/24 (Spot instances)"
echo "- Burst Subnet: 10.0.7.0/24 (Burst workloads)"
echo "- Private Link Subnet: 10.0.8.0/24 (Private endpoints)"
echo ""
echo "Next steps:"
echo "1. Run 08-security-setup.sh for comprehensive security"
echo "2. Run 09-container-registry-setup.sh for container registry"
echo "3. Run 10-validation-setup.sh for comprehensive testing"
echo ""
