# MS5.0 Floor Dashboard - Azure Container Registry Configuration
# This file contains the ACR setup and configuration for multi-environment support

# Azure Container Registry Configuration
# Production ACR
AZURE_CONTAINER_REGISTRY_PROD="ms5acrprod.azurecr.io"
AZURE_CONTAINER_REGISTRY_PROD_RESOURCE_GROUP="ms5-rg"
AZURE_CONTAINER_REGISTRY_PROD_LOCATION="uksouth"

# Staging ACR
AZURE_CONTAINER_REGISTRY_STAGING="ms5acrstaging.azurecr.io"
AZURE_CONTAINER_REGISTRY_STAGING_RESOURCE_GROUP="ms5-rg-staging"
AZURE_CONTAINER_REGISTRY_STAGING_LOCATION="uksouth"

# Development ACR (optional)
AZURE_CONTAINER_REGISTRY_DEV="ms5acrdev.azurecr.io"
AZURE_CONTAINER_REGISTRY_DEV_RESOURCE_GROUP="ms5-rg-dev"
AZURE_CONTAINER_REGISTRY_DEV_LOCATION="uksouth"

# ACR Configuration
ACR_SKU="Premium"  # Premium for geo-replication
ACR_ADMIN_ENABLED="true"
ACR_RETENTION_DAYS="30"
ACR_CLEANUP_ENABLED="true"

# Image Configuration
BACKEND_IMAGE_NAME="ms5-backend"
FRONTEND_IMAGE_NAME="ms5-frontend"
NGINX_IMAGE_NAME="ms5-nginx"
MONITORING_IMAGE_NAME="ms5-monitoring"

# Tagging Strategy
# Format: {environment}-{version}-{timestamp}
# Examples:
# - production-v1.2.3-20231201
# - staging-v1.2.3-20231201
# - develop-abc123-20231201

# Security Configuration
ACR_VULNERABILITY_SCANNING="true"
ACR_IMAGE_SIGNING="true"
ACR_CONTENT_TRUST="true"

# Replication Configuration
ACR_GEO_REPLICATION_LOCATIONS="ukwest,eastus,westeurope"

# Access Control
ACR_ACCESS_LEVEL="admin"
ACR_PULL_ACCESS="aks-cluster"
ACR_PUSH_ACCESS="github-actions"

# Webhook Configuration
ACR_WEBHOOK_ENABLED="true"
ACR_WEBHOOK_ACTIONS="push"
ACR_WEBHOOK_SCOPE="ms5-backend:*,ms5-frontend:*"

# Retention Policies
ACR_RETENTION_POLICY="30d"
ACR_CLEANUP_POLICY="untagged,30d"
ACR_CLEANUP_SCHEDULE="0 2 * * *"  # Daily at 2 AM

# Monitoring Configuration
ACR_METRICS_ENABLED="true"
ACR_LOGS_ENABLED="true"
ACR_ALERTS_ENABLED="true"

# Cost Optimization
ACR_RESERVED_CAPACITY="true"
ACR_AUTO_SCALING="true"
ACR_COST_ALERTS="true"
