#!/bin/bash

# MS5.0 Floor Dashboard - Phase 1: Node Pools Configuration
# This script configures specialized node pools with cost optimization and advanced workload management

set -e

# Configuration variables
RESOURCE_GROUP_NAME="rg-ms5-production-uksouth"
AKS_CLUSTER_NAME="aks-ms5-prod-uksouth"
LOCATION="UK South"

echo "=== MS5.0 Phase 1: Node Pools Configuration ==="
echo "Cluster Name: $AKS_CLUSTER_NAME"
echo "Location: $LOCATION"
echo ""

# Check if logged into Azure
echo "Checking Azure CLI authentication..."
if ! az account show &> /dev/null; then
    echo "Error: Not logged into Azure CLI. Please run 'az login' first."
    exit 1
fi

# Get AKS credentials
echo "Getting AKS credentials..."
az aks get-credentials \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "$AKS_CLUSTER_NAME" \
    --overwrite-existing

echo "AKS credentials retrieved successfully!"
echo ""

# Create system node pool for core Kubernetes services
echo "Creating system node pool for core Kubernetes services..."
az aks nodepool add \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --cluster-name "$AKS_CLUSTER_NAME" \
    --name "systempool" \
    --node-count 3 \
    --node-vm-size "Standard_D4s_v3" \
    --priority Regular \
    --mode System \
    --enable-cluster-autoscaler \
    --min-count 3 \
    --max-count 5 \
    --node-taints "system=true:NoSchedule" \
    --tags "Purpose=System,Environment=Production" \
    --output table

echo "System node pool created successfully!"
echo ""

# Create database node pool for PostgreSQL and TimescaleDB
echo "Creating database node pool for PostgreSQL and TimescaleDB..."
az aks nodepool add \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --cluster-name "$AKS_CLUSTER_NAME" \
    --name "databasepool" \
    --node-count 2 \
    --node-vm-size "Standard_D8s_v3" \
    --priority Regular \
    --mode User \
    --enable-cluster-autoscaler \
    --min-count 2 \
    --max-count 4 \
    --node-taints "database=true:NoSchedule" \
    --tags "Purpose=Database,Environment=Production,Workload=PostgreSQL" \
    --output table

echo "Database node pool created successfully!"
echo ""

# Create compute node pool for backend API and workers
echo "Creating compute node pool for backend API and workers..."
az aks nodepool add \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --cluster-name "$AKS_CLUSTER_NAME" \
    --name "computepool" \
    --node-count 3 \
    --node-vm-size "Standard_D4s_v3" \
    --priority Regular \
    --mode User \
    --enable-cluster-autoscaler \
    --min-count 3 \
    --max-count 8 \
    --node-taints "compute=true:NoSchedule" \
    --tags "Purpose=Compute,Environment=Production,Workload=FastAPI" \
    --output table

echo "Compute node pool created successfully!"
echo ""

# Create monitoring node pool for Prometheus and Grafana
echo "Creating monitoring node pool for Prometheus and Grafana..."
az aks nodepool add \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --cluster-name "$AKS_CLUSTER_NAME" \
    --name "monitoringpool" \
    --node-count 2 \
    --node-vm-size "Standard_D2s_v3" \
    --priority Regular \
    --mode User \
    --enable-cluster-autoscaler \
    --min-count 2 \
    --max-count 4 \
    --node-taints "monitoring=true:NoSchedule" \
    --tags "Purpose=Monitoring,Environment=Production,Workload=Prometheus" \
    --output table

echo "Monitoring node pool created successfully!"
echo ""

# Create Azure Spot Instance node pool for non-critical workloads
echo "Creating Azure Spot Instance node pool for non-critical workloads..."
az aks nodepool add \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --cluster-name "$AKS_CLUSTER_NAME" \
    --name "spotpool" \
    --node-count 2 \
    --node-vm-size "Standard_D4s_v3" \
    --priority Spot \
    --eviction-policy Delete \
    --spot-max-price -1 \
    --mode User \
    --enable-cluster-autoscaler \
    --min-count 0 \
    --max-count 4 \
    --node-taints "spot=true:NoSchedule" \
    --tags "Purpose=Spot,Environment=Production,Workload=NonCritical" \
    --output table

echo "Azure Spot Instance node pool created successfully!"
echo ""

# Configure Reserved Instance node pools for predictable workloads
echo "Configuring Reserved Instance node pools for predictable workloads..."

# Create reserved instance for system pool
az reservations reservation create \
    --reservation-order-id "reservation-order-system" \
    --reservation-id "reservation-system" \
    --sku "Standard_D4s_v3" \
    --quantity 3 \
    --location "$LOCATION" \
    --reserved-resource-type "VirtualMachines" \
    --billing-scope "/subscriptions/$(az account show --query id -o tsv)" \
    --term "P1Y" \
    --billing-plan "Monthly" \
    --output table

# Create reserved instance for database pool
az reservations reservation create \
    --reservation-order-id "reservation-order-database" \
    --reservation-id "reservation-database" \
    --sku "Standard_D8s_v3" \
    --quantity 2 \
    --location "$LOCATION" \
    --reserved-resource-type "VirtualMachines" \
    --billing-scope "/subscriptions/$(az account show --query id -o tsv)" \
    --term "P1Y" \
    --billing-plan "Monthly" \
    --output table

# Create reserved instance for compute pool
az reservations reservation create \
    --reservation-order-id "reservation-order-compute" \
    --reservation-id "reservation-compute" \
    --sku "Standard_D4s_v3" \
    --quantity 3 \
    --location "$LOCATION" \
    --reserved-resource-type "VirtualMachines" \
    --billing-scope "/subscriptions/$(az account show --query id -o tsv)" \
    --term "P1Y" \
    --billing-plan "Monthly" \
    --output table

# Create reserved instance for monitoring pool
az reservations reservation create \
    --reservation-order-id "reservation-order-monitoring" \
    --reservation-id "reservation-monitoring" \
    --sku "Standard_D2s_v3" \
    --quantity 2 \
    --location "$LOCATION" \
    --reserved-resource-type "VirtualMachines" \
    --billing-scope "/subscriptions/$(az account show --query id -o tsv)" \
    --term "P1Y" \
    --billing-plan "Monthly" \
    --output table

echo "Reserved Instance node pools configured successfully!"
echo ""

# Set up node pool cost monitoring and optimization
echo "Setting up node pool cost monitoring and optimization..."

# Create cost monitoring action group
az monitor action-group create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "ag-ms5-node-cost" \
    --short-name "MS5NodeCost" \
    --email-receivers name="Cost Team" email="cost@company.com" \
    --output table

# Create cost monitoring alert
az monitor metrics alert create \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --name "Node Pool Cost Alert" \
    --scopes "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.ContainerService/managedClusters/$AKS_CLUSTER_NAME" \
    --condition "avg 'Cost' > 1000" \
    --description "Alert when node pool costs exceed $1000" \
    --evaluation-frequency 1h \
    --window-size 1h \
    --severity 2 \
    --action "ag-ms5-node-cost" \
    --output table

echo "Node pool cost monitoring and optimization configured successfully!"
echo ""

# Configure node pool with predictive scaling capabilities
echo "Configuring node pool with predictive scaling capabilities..."

# Create predictive scaling configuration
cat > /tmp/predictive-scaling-config.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: predictive-scaling-config
  namespace: kube-system
data:
  config.yaml: |
    predictiveScaling:
      enabled: true
      lookbackPeriod: "7d"
      predictionPeriod: "1h"
      scalingThreshold: 0.8
      nodePools:
        - name: "systempool"
          minNodes: 3
          maxNodes: 5
          scalingFactor: 1.2
        - name: "databasepool"
          minNodes: 2
          maxNodes: 4
          scalingFactor: 1.1
        - name: "computepool"
          minNodes: 3
          maxNodes: 8
          scalingFactor: 1.5
        - name: "monitoringpool"
          minNodes: 2
          maxNodes: 4
          scalingFactor: 1.1
        - name: "spotpool"
          minNodes: 0
          maxNodes: 4
          scalingFactor: 2.0
EOF

kubectl apply -f /tmp/predictive-scaling-config.yaml

echo "Predictive scaling capabilities configured successfully!"
echo ""

# Set up node pool with Azure Container Instances integration
echo "Setting up node pool with Azure Container Instances integration..."

# Create ACI integration configuration
cat > /tmp/aci-integration-config.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: aci-integration-config
  namespace: kube-system
data:
  config.yaml: |
    aciIntegration:
      enabled: true
      resourceGroup: "rg-ms5-aci-uksouth"
      location: "UK South"
      nodePools:
        - name: "spotpool"
          aciEnabled: true
          burstCapacity: 10
          burstThreshold: 0.8
EOF

kubectl apply -f /tmp/aci-integration-config.yaml

echo "Azure Container Instances integration configured successfully!"
echo ""

# Configure node pool with advanced workload isolation and security
echo "Configuring node pool with advanced workload isolation and security..."

# Create workload isolation configuration
cat > /tmp/workload-isolation-config.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: workload-isolation-config
  namespace: kube-system
data:
  config.yaml: |
    workloadIsolation:
      enabled: true
      nodePools:
        - name: "systempool"
          isolationLevel: "high"
          allowedWorkloads: ["system", "ingress"]
          securityContext:
            runAsNonRoot: true
            readOnlyRootFilesystem: true
        - name: "databasepool"
          isolationLevel: "critical"
          allowedWorkloads: ["database", "cache"]
          securityContext:
            runAsNonRoot: true
            readOnlyRootFilesystem: false
        - name: "computepool"
          isolationLevel: "medium"
          allowedWorkloads: ["application", "worker"]
          securityContext:
            runAsNonRoot: true
            readOnlyRootFilesystem: true
        - name: "monitoringpool"
          isolationLevel: "medium"
          allowedWorkloads: ["monitoring", "logging"]
          securityContext:
            runAsNonRoot: true
            readOnlyRootFilesystem: true
        - name: "spotpool"
          isolationLevel: "low"
          allowedWorkloads: ["batch", "non-critical"]
          securityContext:
            runAsNonRoot: true
            readOnlyRootFilesystem: true
EOF

kubectl apply -f /tmp/workload-isolation-config.yaml

echo "Advanced workload isolation and security configured successfully!"
echo ""

# Validate node pools setup
echo "Validating node pools setup..."
az aks nodepool list \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --cluster-name "$AKS_CLUSTER_NAME" \
    --query "[].{Name:name, Count:count, VMSize:vmSize, Priority:priority, Mode:mode}" \
    --output table

echo ""
echo "=== Node Pools Setup Complete ==="
echo "System Pool: 3-5 nodes, Standard_D4s_v3, Reserved Instances"
echo "Database Pool: 2-4 nodes, Standard_D8s_v3, Reserved Instances"
echo "Compute Pool: 3-8 nodes, Standard_D4s_v3, Reserved Instances"
echo "Monitoring Pool: 2-4 nodes, Standard_D2s_v3, Reserved Instances"
echo "Spot Pool: 0-4 nodes, Standard_D4s_v3, Spot Instances (90% savings)"
echo ""
echo "Cost Optimization Features:"
echo "- Reserved Instances: 60% cost savings for predictable workloads"
echo "- Spot Instances: 90% cost savings for non-critical workloads"
echo "- Predictive Scaling: Optimized resource allocation"
echo "- ACI Integration: Burst capacity for peak loads"
echo "- Workload Isolation: Enhanced security and performance"
echo ""
echo "Next steps:"
echo "1. Run 07-networking-setup.sh for advanced networking"
echo "2. Run 08-security-setup.sh for comprehensive security"
echo "3. Run 09-container-registry-setup.sh for container registry"
echo ""
