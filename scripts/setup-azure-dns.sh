#!/bin/bash

# Azure DNS Setup Script for MS5.0 Floor Dashboard
# Creates DNS zone and configures all required DNS records

set -euo pipefail

# Script metadata
readonly SCRIPT_NAME="setup-azure-dns.sh"
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_DESCRIPTION="Azure DNS zone setup for MS5.0 Floor Dashboard"

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
readonly DOMAIN_NAME="ms5floor.com"
readonly RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-ms5-production-rg}"
readonly DNS_ZONE_NAME="${DOMAIN_NAME}"

# Validate prerequisites
validate_prerequisites() {
    log_info "Validating prerequisites for Azure DNS setup..."
    
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
    if [[ -z "${AZURE_SUBSCRIPTION_ID:-}" ]]; then
        log_error "AZURE_SUBSCRIPTION_ID environment variable is not set"
        exit 1
    fi
    
    if [[ -z "${AZURE_RESOURCE_GROUP:-}" ]]; then
        log_error "AZURE_RESOURCE_GROUP environment variable is not set"
        exit 1
    fi
    
    # Get NGINX Ingress Controller external IP
    log_info "Getting NGINX Ingress Controller external IP..."
    local external_ip
    external_ip=$(kubectl get service ingress-nginx-controller \
        -n ingress-nginx \
        -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    
    if [[ -z "$external_ip" ]]; then
        log_error "Could not get NGINX Ingress Controller external IP"
        log_error "Make sure Phase 5B NGINX Ingress Controller is deployed"
        exit 1
    fi
    
    export NGINX_EXTERNAL_IP="$external_ip"
    log_success "NGINX Ingress Controller external IP: $external_ip"
    
    log_success "Prerequisites validation completed"
}

# Create Azure DNS zone
create_dns_zone() {
    log_info "Creating Azure DNS zone for $DOMAIN_NAME..."
    
    # Check if DNS zone already exists
    if az network dns zone show \
        --name "$DNS_ZONE_NAME" \
        --resource-group "$RESOURCE_GROUP" &> /dev/null; then
        log_warning "DNS zone $DNS_ZONE_NAME already exists"
        return 0
    fi
    
    # Create DNS zone
    az network dns zone create \
        --name "$DNS_ZONE_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --zone-type Public \
        --tags \
            Environment=Production \
            Application="MS5.0 Floor Dashboard" \
            Owner="Manufacturing Systems Team" \
            CostCenter="Manufacturing Operations"
    
    log_success "DNS zone $DNS_ZONE_NAME created successfully"
}

# Create DNS records
create_dns_records() {
    log_info "Creating DNS records for $DOMAIN_NAME..."
    
    local external_ip="$NGINX_EXTERNAL_IP"
    
    # A Records
    local a_records=(
        "@:$external_ip"
        "www:$external_ip"
        "api:$external_ip"
        "backend:$external_ip"
        "ws:$external_ip"
        "wss:$external_ip"
        "monitoring:$external_ip"
        "grafana:$external_ip"
        "prometheus:$external_ip"
        "alerts:$external_ip"
        "status:$external_ip"
        "health:$external_ip"
    )
    
    for record in "${a_records[@]}"; do
        local name="${record%%:*}"
        local ip="${record##*:}"
        
        log_info "Creating A record: $name -> $ip"
        
        az network dns record-set a create \
            --name "$name" \
            --resource-group "$RESOURCE_GROUP" \
            --zone-name "$DNS_ZONE_NAME" \
            --ttl 300
        
        az network dns record-set a add-record \
            --name "$name" \
            --resource-group "$RESOURCE_GROUP" \
            --zone-name "$DNS_ZONE_NAME" \
            --ipv4-address "$ip"
    done
    
    # MX Record
    log_info "Creating MX record for email"
    az network dns record-set mx create \
        --name "@" \
        --resource-group "$RESOURCE_GROUP" \
        --zone-name "$DNS_ZONE_NAME" \
        --ttl 3600
    
    az network dns record-set mx add-record \
        --name "@" \
        --resource-group "$RESOURCE_GROUP" \
        --zone-name "$DNS_ZONE_NAME" \
        --exchange "mail.ms5floor.com" \
        --preference 10
    
    # TXT Records
    log_info "Creating TXT records for email authentication"
    
    # SPF Record
    az network dns record-set txt create \
        --name "@" \
        --resource-group "$RESOURCE_GROUP" \
        --zone-name "$DNS_ZONE_NAME" \
        --ttl 3600
    
    az network dns record-set txt add-record \
        --name "@" \
        --resource-group "$RESOURCE_GROUP" \
        --zone-name "$DNS_ZONE_NAME" \
        --value "v=spf1 include:_spf.google.com ~all"
    
    # DMARC Record
    az network dns record-set txt create \
        --name "_dmarc" \
        --resource-group "$RESOURCE_GROUP" \
        --zone-name "$DNS_ZONE_NAME" \
        --ttl 3600
    
    az network dns record-set txt add-record \
        --name "_dmarc" \
        --resource-group "$RESOURCE_GROUP" \
        --zone-name "$DNS_ZONE_NAME" \
        --value "v=DMARC1; p=quarantine; rua=mailto:dmarc@ms5floor.com"
    
    log_success "DNS records created successfully"
}

# Verify DNS configuration
verify_dns_configuration() {
    log_info "Verifying DNS configuration..."
    
    local domains=(
        "ms5floor.com"
        "www.ms5floor.com"
        "api.ms5floor.com"
        "ws.ms5floor.com"
        "monitoring.ms5floor.com"
        "grafana.ms5floor.com"
        "prometheus.ms5floor.com"
        "status.ms5floor.com"
    )
    
    local failed_domains=()
    
    for domain in "${domains[@]}"; do
        log_info "Verifying DNS resolution for $domain..."
        
        # Wait for DNS propagation (up to 5 minutes)
        local max_attempts=30
        local attempt=1
        local resolved=false
        
        while [[ $attempt -le $max_attempts && "$resolved" == "false" ]]; do
            if dig +short "$domain" A | grep -q .; then
                resolved=true
                log_success "DNS resolution successful for $domain"
            else
                log_info "Attempt $attempt/$max_attempts: Waiting for DNS propagation..."
                sleep 10
                ((attempt++))
            fi
        done
        
        if [[ "$resolved" == "false" ]]; then
            log_warning "DNS resolution failed for $domain"
            failed_domains+=("$domain")
        fi
    done
    
    if [[ ${#failed_domains[@]} -gt 0 ]]; then
        log_warning "DNS resolution failed for: ${failed_domains[*]}"
        log_warning "This may be due to DNS propagation delays. Please check again later."
    else
        log_success "All DNS records verified successfully"
    fi
}

# Create DNS monitoring
create_dns_monitoring() {
    log_info "Creating DNS monitoring configuration..."
    
    # Apply DNS monitoring ConfigMap
    kubectl apply -f k8s/azure-dns/01-dns-zone-setup.yaml
    
    # Create DNS health check CronJob
    cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: dns-health-check
  namespace: ms5-production
  labels:
    app: ms5-dashboard
    component: dns-monitoring
spec:
  schedule: "*/5 * * * *"  # Every 5 minutes
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: dns-health-check
            image: alpine:latest
            command:
            - /bin/sh
            - -c
            - |
              apk add --no-cache curl bind-tools openssl
              cat /etc/dns-health-check/health-check-script.sh | sh
            volumeMounts:
            - name: dns-health-check-script
              mountPath: /etc/dns-health-check
          volumes:
          - name: dns-health-check-script
            configMap:
              name: dns-health-check-config
              defaultMode: 0755
          restartPolicy: OnFailure
EOF
    
    log_success "DNS monitoring configuration created"
}

# Generate DNS report
generate_dns_report() {
    log_info "Generating DNS configuration report..."
    
    local report_file="dns-setup-report-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$report_file" << EOF
# MS5.0 Floor Dashboard - DNS Configuration Report
# Generated: $(date)
# Script: $SCRIPT_NAME v$SCRIPT_VERSION

## DNS Zone Information
- Zone Name: $DNS_ZONE_NAME
- Resource Group: $RESOURCE_GROUP
- External IP: $NGINX_EXTERNAL_IP

## DNS Records Created
### A Records
- ms5floor.com -> $NGINX_EXTERNAL_IP
- www.ms5floor.com -> $NGINX_EXTERNAL_IP
- api.ms5floor.com -> $NGINX_EXTERNAL_IP
- backend.ms5floor.com -> $NGINX_EXTERNAL_IP
- ws.ms5floor.com -> $NGINX_EXTERNAL_IP
- wss.ms5floor.com -> $NGINX_EXTERNAL_IP
- monitoring.ms5floor.com -> $NGINX_EXTERNAL_IP
- grafana.ms5floor.com -> $NGINX_EXTERNAL_IP
- prometheus.ms5floor.com -> $NGINX_EXTERNAL_IP
- alerts.ms5floor.com -> $NGINX_EXTERNAL_IP
- status.ms5floor.com -> $NGINX_EXTERNAL_IP
- health.ms5floor.com -> $NGINX_EXTERNAL_IP

### MX Records
- @ -> mail.ms5floor.com (priority 10)

### TXT Records
- @ -> v=spf1 include:_spf.google.com ~all (SPF)
- _dmarc -> v=DMARC1; p=quarantine; rua=mailto:dmarc@ms5floor.com (DMARC)

## Next Steps
1. Update your domain registrar to use Azure DNS nameservers
2. Wait for DNS propagation (up to 48 hours)
3. Verify SSL certificate issuance
4. Test all endpoints

## Nameservers
$(az network dns zone show --name "$DNS_ZONE_NAME" --resource-group "$RESOURCE_GROUP" --query "nameServers" -o table)

## Support Information
- Contact: team@ms5floor.com
- Documentation: Available in k8s/azure-dns/ directory

EOF
    
    log_success "DNS configuration report generated: $report_file"
    
    # Display nameservers
    log_info "Azure DNS nameservers for $DOMAIN_NAME:"
    az network dns zone show \
        --name "$DNS_ZONE_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query "nameServers" -o table
}

# Main function
main() {
    echo -e "${WHITE}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                    Azure DNS Setup for MS5.0 Floor Dashboard               ║"
    echo "║                                                                              ║"
    echo "║  Creating DNS zone and configuring all required DNS records for             ║"
    echo "║  enterprise-grade domain management with automated monitoring.              ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    log_info "Starting Azure DNS setup: $SCRIPT_DESCRIPTION"
    log_info "Script version: $SCRIPT_VERSION"
    log_info "Domain: $DOMAIN_NAME"
    log_info "Resource Group: $RESOURCE_GROUP"
    
    validate_prerequisites
    create_dns_zone
    create_dns_records
    verify_dns_configuration
    create_dns_monitoring
    generate_dns_report
    
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                         DNS SETUP COMPLETE                                   ║"
    echo "║                                                                              ║"
    echo "║  ✅ Azure DNS zone created for $DOMAIN_NAME                                ║"
    echo "║  ✅ All DNS records configured with external IP                            ║"
    echo "║  ✅ Email authentication records (SPF, DMARC) configured                   ║"
    echo "║  ✅ DNS monitoring and health checks enabled                               ║"
    echo "║  ✅ Configuration report generated                                          ║"
    echo "║                                                                              ║"
    echo "║  Next: Update your domain registrar to use Azure DNS nameservers           ║"
    echo "║  Wait for DNS propagation and verify SSL certificate issuance               ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    log_success "Azure DNS setup completed successfully!"
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
