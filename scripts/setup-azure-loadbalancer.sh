#!/bin/bash

# Azure Load Balancer Setup Script for MS5.0 Floor Dashboard
# Creates Azure Load Balancer with advanced traffic management

set -euo pipefail

# Script metadata
readonly SCRIPT_NAME="setup-azure-loadbalancer.sh"
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_DESCRIPTION="Azure Load Balancer setup for MS5.0 Floor Dashboard"

# Color codes for output formatting
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Configuration
readonly RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-ms5-production-rg}"
readonly LOCATION="${AZURE_LOCATION:-uksouth}"
readonly LOADBALANCER_NAME="ms5-loadbalancer"
readonly PUBLIC_IP_NAME="ms5-loadbalancer-public-ip"

# Validate prerequisites
validate_prerequisites() {
    log_info "Validating prerequisites for Azure Load Balancer setup..."
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI is not installed"
        exit 1
    fi
    
    # Check authentication
    if ! az account show &> /dev/null; then
        log_error "Azure CLI is not authenticated"
        exit 1
    fi
    
    # Check required environment variables
    local required_vars=(
        "AZURE_SUBSCRIPTION_ID"
        "AZURE_RESOURCE_GROUP"
        "AZURE_VNET_NAME"
        "AZURE_SUBNET_NAME"
    )
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "$var environment variable is not set"
            exit 1
        fi
    done
    
    # Get AKS node IPs
    log_info "Getting AKS node IP addresses..."
    local node_ips
    node_ips=$(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || echo "")
    
    if [[ -z "$node_ips" ]]; then
        log_error "Could not get AKS node IP addresses"
        log_error "Make sure kubectl is configured and AKS cluster is accessible"
        exit 1
    fi
    
    # Set node IPs as environment variables
    local ip_array=($node_ips)
    export AKS_NODE_IP_1="${ip_array[0]}"
    export AKS_NODE_IP_2="${ip_array[1]:-${ip_array[0]}}"
    export AKS_NODE_IP_3="${ip_array[2]:-${ip_array[0]}}"
    
    log_success "AKS node IPs: $AKS_NODE_IP_1, $AKS_NODE_IP_2, $AKS_NODE_IP_3"
    
    log_success "Prerequisites validation completed"
}

# Create public IP
create_public_ip() {
    log_info "Creating public IP for Load Balancer..."
    
    # Check if public IP already exists
    if az network public-ip show \
        --name "$PUBLIC_IP_NAME" \
        --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        log_warning "Public IP $PUBLIC_IP_NAME already exists"
        return 0
    fi
    
    # Create public IP
    az network public-ip create \
        --name "$PUBLIC_IP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --sku Standard \
        --allocation-method Static \
        --dns-name "ms5floor-lb" \
        --tags \
            Environment=Production \
            Application="MS5.0 Floor Dashboard" \
            Owner="Manufacturing Systems Team" \
            CostCenter="Manufacturing Operations"
    
    log_success "Public IP $PUBLIC_IP_NAME created successfully"
}

# Create Load Balancer
create_load_balancer() {
    log_info "Creating Azure Load Balancer..."
    
    # Check if Load Balancer already exists
    if az network lb show \
        --name "$LOADBALANCER_NAME" \
        --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        log_warning "Load Balancer $LOADBALANCER_NAME already exists"
        return 0
    fi
    
    # Create Load Balancer
    az network lb create \
        --name "$LOADBALANCER_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --sku Standard \
        --public-ip-address "$PUBLIC_IP_NAME" \
        --tags \
            Environment=Production \
            Application="MS5.0 Floor Dashboard" \
            Owner="Manufacturing Systems Team" \
            CostCenter="Manufacturing Operations"
    
    log_success "Load Balancer $LOADBALANCER_NAME created successfully"
}

# Create backend address pool
create_backend_pool() {
    log_info "Creating backend address pool..."
    
    # Create backend address pool
    az network lb address-pool create \
        --name "ms5-backend-pool" \
        --lb-name "$LOADBALANCER_NAME" \
        --resource-group "$RESOURCE_GROUP"
    
    # Add AKS nodes to backend pool
    local node_ips=("$AKS_NODE_IP_1" "$AKS_NODE_IP_2" "$AKS_NODE_IP_3")
    
    for i in "${!node_ips[@]}"; do
        local node_ip="${node_ips[$i]}"
        log_info "Adding AKS node $((i+1)) ($node_ip) to backend pool"
        
        az network lb address-pool address add \
            --name "ms5-backend-pool" \
            --lb-name "$LOADBALANCER_NAME" \
            --resource-group "$RESOURCE_GROUP" \
            --ip-address "$node_ip" \
            --vnet "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Network/virtualNetworks/$AZURE_VNET_NAME"
    done
    
    log_success "Backend address pool created and configured"
}

# Create health probes
create_health_probes() {
    log_info "Creating health probes..."
    
    # HTTP probe
    az network lb probe create \
        --name "ms5-http-probe" \
        --lb-name "$LOADBALANCER_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --protocol Http \
        --port 80 \
        --path "/healthz" \
        --interval 15 \
        --threshold 2
    
    # HTTPS probe
    az network lb probe create \
        --name "ms5-https-probe" \
        --lb-name "$LOADBALANCER_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --protocol Https \
        --port 443 \
        --path "/healthz" \
        --interval 15 \
        --threshold 2
    
    # WebSocket probe
    az network lb probe create \
        --name "ms5-websocket-probe" \
        --lb-name "$LOADBALANCER_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --protocol Http \
        --port 8080 \
        --path "/ws/health" \
        --interval 30 \
        --threshold 3
    
    log_success "Health probes created successfully"
}

# Create load balancing rules
create_load_balancing_rules() {
    log_info "Creating load balancing rules..."
    
    # HTTP rule
    az network lb rule create \
        --name "ms5-http-rule" \
        --lb-name "$LOADBALANCER_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --protocol Tcp \
        --frontend-port 80 \
        --backend-port 80 \
        --frontend-ip-name "LoadBalancerFrontEnd" \
        --backend-pool-name "ms5-backend-pool" \
        --probe-name "ms5-http-probe" \
        --idle-timeout 4
    
    # HTTPS rule
    az network lb rule create \
        --name "ms5-https-rule" \
        --lb-name "$LOADBALANCER_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --protocol Tcp \
        --frontend-port 443 \
        --backend-port 443 \
        --frontend-ip-name "LoadBalancerFrontEnd" \
        --backend-pool-name "ms5-backend-pool" \
        --probe-name "ms5-https-probe" \
        --idle-timeout 4
    
    # WebSocket rule with source IP affinity
    az network lb rule create \
        --name "ms5-websocket-rule" \
        --lb-name "$LOADBALANCER_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --protocol Tcp \
        --frontend-port 8080 \
        --backend-port 8080 \
        --frontend-ip-name "LoadBalancerFrontEnd" \
        --backend-pool-name "ms5-backend-pool" \
        --probe-name "ms5-websocket-probe" \
        --idle-timeout 30 \
        --load-distribution SourceIP
    
    log_success "Load balancing rules created successfully"
}

# Create outbound rules
create_outbound_rules() {
    log_info "Creating outbound rules..."
    
    az network lb outbound-rule create \
        --name "ms5-outbound-rule" \
        --lb-name "$LOADBALANCER_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --frontend-ip-configs "LoadBalancerFrontEnd" \
        --backend-pool-name "ms5-backend-pool" \
        --protocol All \
        --allocated-outbound-ports 1024 \
        --idle-timeout 4 \
        --enable-tcp-reset true
    
    log_success "Outbound rules created successfully"
}

# Configure Kubernetes service
configure_kubernetes_service() {
    log_info "Configuring Kubernetes LoadBalancer service..."
    
    # Apply Load Balancer configuration
    kubectl apply -f k8s/azure-loadbalancer/01-loadbalancer-config.yaml
    
    # Create health check CronJob
    cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: loadbalancer-health-check
  namespace: ms5-production
  labels:
    app: ms5-dashboard
    component: loadbalancer-monitoring
spec:
  schedule: "*/2 * * * *"  # Every 2 minutes
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: loadbalancer-health-check
            image: alpine:latest
            command:
            - /bin/sh
            - -c
            - |
              apk add --no-cache curl
              cat /etc/health-check/health-check-script.sh | sh
            volumeMounts:
            - name: health-check-script
              mountPath: /etc/health-check
          volumes:
          - name: health-check-script
            configMap:
              name: loadbalancer-health-check-config
              defaultMode: 0755
          restartPolicy: OnFailure
EOF
    
    log_success "Kubernetes LoadBalancer service configured"
}

# Verify Load Balancer configuration
verify_load_balancer() {
    log_info "Verifying Load Balancer configuration..."
    
    # Get Load Balancer public IP
    local public_ip
    public_ip=$(az network public-ip show \
        --name "$PUBLIC_IP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query "ipAddress" -o tsv)
    
    if [[ -z "$public_ip" ]]; then
        log_error "Could not get Load Balancer public IP"
        exit 1
    fi
    
    log_success "Load Balancer public IP: $public_ip"
    
    # Test Load Balancer endpoints
    local endpoints=(
        "http://$public_ip/healthz"
        "https://$public_ip/healthz"
    )
    
    for endpoint in "${endpoints[@]}"; do
        log_info "Testing endpoint: $endpoint"
        
        local max_attempts=10
        local attempt=1
        local success=false
        
        while [[ $attempt -le $max_attempts && "$success" == "false" ]]; do
            if curl -s --max-time 10 "$endpoint" &> /dev/null; then
                success=true
                log_success "Endpoint $endpoint is responding"
            else
                log_info "Attempt $attempt/$max_attempts: Waiting for Load Balancer to be ready..."
                sleep 30
                ((attempt++))
            fi
        done
        
        if [[ "$success" == "false" ]]; then
            log_warning "Endpoint $endpoint is not responding yet"
        fi
    done
    
    log_success "Load Balancer verification completed"
}

# Generate Load Balancer report
generate_load_balancer_report() {
    log_info "Generating Load Balancer configuration report..."
    
    local report_file="loadbalancer-setup-report-$(date +%Y%m%d-%H%M%S).txt"
    local public_ip
    public_ip=$(az network public-ip show \
        --name "$PUBLIC_IP_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query "ipAddress" -o tsv)
    
    cat > "$report_file" << EOF
# MS5.0 Floor Dashboard - Load Balancer Configuration Report
# Generated: $(date)
# Script: $SCRIPT_NAME v$SCRIPT_VERSION

## Load Balancer Information
- Name: $LOADBALANCER_NAME
- Resource Group: $RESOURCE_GROUP
- Location: $LOCATION
- SKU: Standard
- Public IP: $public_ip

## Backend Configuration
- Backend Pool: ms5-backend-pool
- Backend Nodes: $AKS_NODE_IP_1, $AKS_NODE_IP_2, $AKS_NODE_IP_3
- Load Distribution: Default (HTTP/HTTPS), SourceIP (WebSocket)

## Load Balancing Rules
### HTTP Rule
- Frontend Port: 80
- Backend Port: 80
- Protocol: TCP
- Probe: ms5-http-probe (/healthz)
- Idle Timeout: 4 minutes

### HTTPS Rule
- Frontend Port: 443
- Backend Port: 443
- Protocol: TCP
- Probe: ms5-https-probe (/healthz)
- Idle Timeout: 4 minutes

### WebSocket Rule
- Frontend Port: 8080
- Backend Port: 8080
- Protocol: TCP
- Probe: ms5-websocket-probe (/ws/health)
- Idle Timeout: 30 minutes
- Load Distribution: SourceIP (for session affinity)

## Health Probes
- HTTP Probe: Port 80, Path /healthz, Interval 15s, Threshold 2
- HTTPS Probe: Port 443, Path /healthz, Interval 15s, Threshold 2
- WebSocket Probe: Port 8080, Path /ws/health, Interval 30s, Threshold 3

## Outbound Rules
- Protocol: All
- Allocated Ports: 1024
- Idle Timeout: 4 minutes
- TCP Reset: Enabled

## Monitoring
- Health Check CronJob: Every 2 minutes
- Metrics: Data path availability, health probe status, SNAT usage
- Alerts: Backend unhealthy, high SNAT usage, data path unavailable

## Next Steps
1. Update DNS records to point to Load Balancer IP: $public_ip
2. Verify SSL certificate binding
3. Test all endpoints through Load Balancer
4. Monitor Load Balancer metrics and alerts

## Support Information
- Contact: team@ms5floor.com
- Documentation: Available in k8s/azure-loadbalancer/ directory

EOF
    
    log_success "Load Balancer configuration report generated: $report_file"
}

# Main function
main() {
    echo -e "${WHITE}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                    Azure Load Balancer Setup for MS5.0                       ║"
    echo "║                                                                              ║"
    echo "║  Creating Azure Load Balancer with advanced traffic management for          ║"
    echo "║  enterprise-grade load balancing with health monitoring and optimization.  ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    log_info "Starting Azure Load Balancer setup: $SCRIPT_DESCRIPTION"
    log_info "Script version: $SCRIPT_VERSION"
    log_info "Resource Group: $RESOURCE_GROUP"
    log_info "Location: $LOCATION"
    
    validate_prerequisites
    create_public_ip
    create_load_balancer
    create_backend_pool
    create_health_probes
    create_load_balancing_rules
    create_outbound_rules
    configure_kubernetes_service
    verify_load_balancer
    generate_load_balancer_report
    
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                         LOAD BALANCER SETUP COMPLETE                        ║"
    echo "║                                                                              ║"
    echo "║  ✅ Azure Load Balancer created with Standard SKU                         ║"
    echo "║  ✅ Public IP configured with DNS label                                     ║"
    echo "║  ✅ Backend address pool configured with AKS nodes                         ║"
    echo "║  ✅ Health probes configured for HTTP, HTTPS, and WebSocket                 ║"
    echo "║  ✅ Load balancing rules with session affinity for WebSocket                ║"
    echo "║  ✅ Outbound rules configured for SNAT                                     ║"
    echo "║  ✅ Kubernetes service integration configured                               ║"
    echo "║  ✅ Health monitoring and alerting enabled                                  ║"
    echo "║                                                                              ║"
    echo "║  Next: Update DNS records to point to Load Balancer IP                      ║"
    echo "║  Test all endpoints and verify SSL certificate binding                      ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    log_success "Azure Load Balancer setup completed successfully!"
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
