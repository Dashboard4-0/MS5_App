#!/usr/bin/env node

/**
 * MS5.0 Floor Dashboard - AKS Optimization Script
 * 
 * This script performs final optimizations for AKS deployment by:
 * - Validating all configurations
 * - Optimizing for Kubernetes environment
 * - Setting up health checks and monitoring
 * - Preparing for container deployment
 */

const fs = require('fs');
const path = require('path');

// AKS optimization configuration
const aksConfig = {
  // Kubernetes-specific settings
  kubernetes: {
    namespace: 'ms5-floor-dashboard',
    labels: {
      app: 'ms5-frontend',
      version: process.env.npm_package_version || '1.0.0',
      component: 'frontend',
      environment: 'production'
    },
    annotations: {
      'deployment.kubernetes.io/revision': '1',
      'kubernetes.io/description': 'MS5.0 Floor Dashboard Frontend'
    }
  },
  
  // Health check configuration
  healthChecks: {
    liveness: {
      path: '/health',
      initialDelaySeconds: 30,
      periodSeconds: 10,
      timeoutSeconds: 5,
      failureThreshold: 3,
      successThreshold: 1
    },
    readiness: {
      path: '/ready',
      initialDelaySeconds: 5,
      periodSeconds: 5,
      timeoutSeconds: 3,
      failureThreshold: 3,
      successThreshold: 1
    },
    startup: {
      path: '/live',
      initialDelaySeconds: 10,
      periodSeconds: 5,
      timeoutSeconds: 3,
      failureThreshold: 30,
      successThreshold: 1
    }
  },
  
  // Resource configuration
  resources: {
    requests: {
      cpu: '100m',
      memory: '128Mi'
    },
    limits: {
      cpu: '500m',
      memory: '512Mi'
    }
  },
  
  // Scaling configuration
  scaling: {
    minReplicas: 2,
    maxReplicas: 10,
    targetCPUUtilizationPercentage: 70,
    targetMemoryUtilizationPercentage: 80
  },
  
  // Security configuration
  security: {
    runAsNonRoot: true,
    runAsUser: 1000,
    allowPrivilegeEscalation: false,
    readOnlyRootFilesystem: true,
    capabilities: {
      drop: ['ALL']
    }
  }
};

/**
 * Generate health check endpoints
 */
function generateHealthChecks() {
  const healthCheckHTML = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Health Check - MS5.0 Floor Dashboard</title>
    <style>
        body {
            font-family: 'Roboto', sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
            color: #333;
        }
        .health-container {
            max-width: 800px;
            margin: 20px auto;
            padding: 20px;
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .health-header {
            text-align: center;
            margin-bottom: 30px;
        }
        .health-status {
            display: flex;
            justify-content: space-around;
            margin-bottom: 30px;
        }
        .status-item {
            text-align: center;
            padding: 20px;
            border-radius: 8px;
            flex: 1;
            margin: 0 10px;
        }
        .status-healthy {
            background-color: #e8f5e8;
            color: #2e7d32;
        }
        .status-warning {
            background-color: #fff3e0;
            color: #f57c00;
        }
        .status-error {
            background-color: #ffebee;
            color: #c62828;
        }
        .status-icon {
            font-size: 48px;
            margin-bottom: 10px;
        }
        .status-title {
            font-size: 18px;
            font-weight: 500;
            margin-bottom: 5px;
        }
        .status-description {
            font-size: 14px;
            opacity: 0.8;
        }
        .health-details {
            margin-top: 30px;
        }
        .detail-section {
            margin-bottom: 20px;
        }
        .detail-title {
            font-size: 16px;
            font-weight: 500;
            margin-bottom: 10px;
            color: #1976d2;
        }
        .detail-content {
            background-color: #f8f9fa;
            padding: 15px;
            border-radius: 4px;
            font-family: monospace;
            font-size: 14px;
            overflow-x: auto;
        }
    </style>
</head>
<body>
    <div class="health-container">
        <div class="health-header">
            <h1>MS5.0 Floor Dashboard - Health Status</h1>
            <p>System health monitoring for AKS deployment</p>
        </div>
        
        <div class="health-status">
            <div class="status-item status-healthy" id="liveness-status">
                <div class="status-icon">💚</div>
                <div class="status-title">Liveness</div>
                <div class="status-description">Container is alive</div>
            </div>
            <div class="status-item status-healthy" id="readiness-status">
                <div class="status-icon">✅</div>
                <div class="status-title">Readiness</div>
                <div class="status-description">Ready to serve traffic</div>
            </div>
            <div class="status-item status-healthy" id="startup-status">
                <div class="status-icon">🚀</div>
                <div class="status-title">Startup</div>
                <div class="status-description">Application started</div>
            </div>
        </div>
        
        <div class="health-details">
            <div class="detail-section">
                <div class="detail-title">System Information</div>
                <div class="detail-content" id="system-info">
                    Loading system information...
                </div>
            </div>
            
            <div class="detail-section">
                <div class="detail-title">Application Status</div>
                <div class="detail-content" id="app-status">
                    Loading application status...
                </div>
            </div>
            
            <div class="detail-section">
                <div class="detail-title">Performance Metrics</div>
                <div class="detail-content" id="performance-metrics">
                    Loading performance metrics...
                </div>
            </div>
        </div>
    </div>

    <script>
        // Health check data
        const healthData = {
            timestamp: new Date().toISOString(),
            version: '${process.env.npm_package_version || '1.0.0'}',
            environment: 'production',
            platform: 'AKS',
            uptime: process.uptime ? process.uptime() : 'N/A',
            memory: process.memoryUsage ? process.memoryUsage() : {},
            cpu: process.cpuUsage ? process.cpuUsage() : {}
        };

        // Update system information
        document.getElementById('system-info').textContent = JSON.stringify({
            version: healthData.version,
            environment: healthData.environment,
            platform: healthData.platform,
            timestamp: healthData.timestamp,
            uptime: healthData.uptime
        }, null, 2);

        // Update application status
        document.getElementById('app-status').textContent = JSON.stringify({
            status: 'healthy',
            services: {
                api: 'connected',
                websocket: 'connected',
                cache: 'available',
                storage: 'available'
            },
            features: {
                offline: 'enabled',
                pwa: 'enabled',
                realtime: 'enabled'
            }
        }, null, 2);

        // Update performance metrics
        document.getElementById('performance-metrics').textContent = JSON.stringify({
            memory: healthData.memory,
            cpu: healthData.cpu,
            loadTime: performance.timing ? performance.timing.loadEventEnd - performance.timing.navigationStart : 'N/A',
            domContentLoaded: performance.timing ? performance.timing.domContentLoadedEventEnd - performance.timing.navigationStart : 'N/A'
        }, null, 2);

        // Health check endpoints
        function healthCheck() {
            return {
                status: 'healthy',
                timestamp: new Date().toISOString(),
                version: healthData.version,
                uptime: healthData.uptime,
                memory: healthData.memory,
                services: {
                    api: 'healthy',
                    websocket: 'healthy',
                    cache: 'healthy',
                    storage: 'healthy'
                }
            };
        }

        function readinessCheck() {
            return {
                ready: true,
                timestamp: new Date().toISOString(),
                dependencies: {
                    api: 'ready',
                    websocket: 'ready',
                    cache: 'ready',
                    storage: 'ready'
                }
            };
        }

        function startupCheck() {
            return {
                started: true,
                timestamp: new Date().toISOString(),
                initialization: 'complete',
                services: 'running'
            };
        }

        // Expose health check functions globally for Kubernetes probes
        window.healthCheck = healthCheck;
        window.readinessCheck = readinessCheck;
        window.startupCheck = startupCheck;
    </script>
</body>
</html>`;

  // Create health check endpoints
  const healthEndpoints = [
    { path: '/health', content: '{"status":"healthy","timestamp":"' + new Date().toISOString() + '","version":"' + (process.env.npm_package_version || '1.0.0') + '"}' },
    { path: '/ready', content: '{"ready":true,"timestamp":"' + new Date().toISOString() + '"}' },
    { path: '/live', content: '{"alive":true,"timestamp":"' + new Date().toISOString() + '"}' },
    { path: '/health-detail', content: healthCheckHTML }
  ];

  healthEndpoints.forEach(endpoint => {
    const outputPath = path.join(__dirname, '../build', endpoint.path === '/health-detail' ? 'health-detail.html' : endpoint.path.slice(1) + '.json');
    
    try {
      fs.writeFileSync(outputPath, endpoint.content);
      console.log(`✅ Generated health check: ${endpoint.path}`);
    } catch (error) {
      console.error(`❌ Error generating health check ${endpoint.path}:`, error);
    }
  });
}

/**
 * Generate AKS-specific configuration file
 */
function generateAKSConfig() {
  const config = {
    aks: {
      enabled: true,
      kubernetes: aksConfig.kubernetes,
      healthChecks: aksConfig.healthChecks,
      resources: aksConfig.resources,
      scaling: aksConfig.scaling,
      security: aksConfig.security
    },
    build: {
      timestamp: new Date().toISOString(),
      version: process.env.npm_package_version || '1.0.0',
      environment: 'aks-optimized',
      platform: 'kubernetes'
    }
  };
  
  const outputPath = path.join(__dirname, '../build/aks-config.json');
  
  try {
    fs.writeFileSync(outputPath, JSON.stringify(config, null, 2));
    console.log('✅ Generated AKS configuration');
  } catch (error) {
    console.error('❌ Error generating AKS config:', error);
  }
}

/**
 * Generate Kubernetes labels and annotations
 */
function generateKubernetesMetadata() {
  const metadata = {
    labels: aksConfig.kubernetes.labels,
    annotations: aksConfig.kubernetes.annotations
  };
  
  const outputPath = path.join(__dirname, '../build/kubernetes-metadata.json');
  
  try {
    fs.writeFileSync(outputPath, JSON.stringify(metadata, null, 2));
    console.log('✅ Generated Kubernetes metadata');
  } catch (error) {
    console.error('❌ Error generating Kubernetes metadata:', error);
  }
}

/**
 * Optimize for container deployment
 */
function optimizeForContainer() {
  // Add container-specific optimizations to HTML
  const htmlPath = path.join(__dirname, '../build/index.html');
  
  if (!fs.existsSync(htmlPath)) {
    console.log('⚠️  HTML file not found, skipping container optimization');
    return;
  }
  
  let html = fs.readFileSync(htmlPath, 'utf8');
  
  // Add container-specific meta tags and scripts
  const containerOptimizations = `
  <!-- Container-specific optimizations -->
  <meta name="container-platform" content="kubernetes" />
  <meta name="deployment-environment" content="aks" />
  <meta name="health-check-enabled" content="true" />
  
  <!-- Container configuration -->
  <script>
    window.CONTAINER_CONFIG = {
      platform: 'kubernetes',
      environment: 'aks',
      namespace: '${aksConfig.kubernetes.namespace}',
      version: '${process.env.npm_package_version || '1.0.0'}',
      healthChecks: ${JSON.stringify(aksConfig.healthChecks)},
      resources: ${JSON.stringify(aksConfig.resources)},
      scaling: ${JSON.stringify(aksConfig.scaling)}
    };
    
    // Container health monitoring
    if (window.CONTAINER_CONFIG.healthChecks) {
      setInterval(() => {
        // Simulate health check
        fetch('/health')
          .then(response => response.json())
          .then(data => {
            console.log('Health check:', data);
          })
          .catch(error => {
            console.error('Health check failed:', error);
          });
      }, 30000); // Every 30 seconds
    }
  </script>
`;
  
  // Insert container optimizations before closing head tag
  html = html.replace('</head>', `${containerOptimizations}\n</head>`);
  
  fs.writeFileSync(htmlPath, html);
  console.log('✅ Optimized HTML for container deployment');
}

/**
 * Generate deployment validation script
 */
function generateDeploymentValidation() {
  const validationScript = `#!/bin/bash

# MS5.0 Floor Dashboard - AKS Deployment Validation Script
# This script validates the deployment configuration for AKS

set -e

echo "🚀 Starting AKS deployment validation..."

# Check required files
REQUIRED_FILES=(
  "index.html"
  "manifest.json"
  "sw.js"
  "health.json"
  "ready.json"
  "live.json"
  "aks-config.json"
  "kubernetes-metadata.json"
)

echo "📋 Checking required files..."
for file in "${REQUIRED_FILES[@]}"; do
  if [ ! -f "build/$file" ]; then
    echo "❌ Missing required file: $file"
    exit 1
  fi
  echo "✅ Found: $file"
done

# Validate HTML
echo "🔍 Validating HTML..."
if ! grep -q "MS5.0 Floor Dashboard" build/index.html; then
  echo "❌ HTML validation failed: Title not found"
  exit 1
fi
echo "✅ HTML validation passed"

# Validate manifest
echo "🔍 Validating PWA manifest..."
if ! jq -e '.name' build/manifest.json > /dev/null; then
  echo "❌ Manifest validation failed: Invalid JSON"
  exit 1
fi
echo "✅ Manifest validation passed"

# Validate service worker
echo "🔍 Validating service worker..."
if ! grep -q "workbox" build/sw.js; then
  echo "❌ Service worker validation failed: Workbox not found"
  exit 1
fi
echo "✅ Service worker validation passed"

# Validate health checks
echo "🔍 Validating health checks..."
if ! jq -e '.status' build/health.json > /dev/null; then
  echo "❌ Health check validation failed: Invalid JSON"
  exit 1
fi
echo "✅ Health checks validation passed"

# Validate AKS configuration
echo "🔍 Validating AKS configuration..."
if ! jq -e '.aks' build/aks-config.json > /dev/null; then
  echo "❌ AKS configuration validation failed: Invalid JSON"
  exit 1
fi
echo "✅ AKS configuration validation passed"

# Check file sizes
echo "📊 Checking file sizes..."
MAX_SIZE=5242880  # 5MB
LARGE_FILES=$(find build -type f -size +${MAX_SIZE}c)

if [ -n "$LARGE_FILES" ]; then
  echo "⚠️  Large files detected:"
  echo "$LARGE_FILES"
  echo "Consider optimizing these files for better performance"
fi

# Check for security headers
echo "🔒 Checking security headers..."
if ! grep -q "Content-Security-Policy" build/index.html; then
  echo "⚠️  Security warning: Content Security Policy not found"
fi

echo "✅ AKS deployment validation completed successfully!"
echo "🎉 Ready for deployment to AKS!"
`;

  const outputPath = path.join(__dirname, '../build/validate-deployment.sh');
  
  try {
    fs.writeFileSync(outputPath, validationScript);
    // Make executable
    fs.chmodSync(outputPath, '755');
    console.log('✅ Generated deployment validation script');
  } catch (error) {
    console.error('❌ Error generating deployment validation script:', error);
  }
}

/**
 * Validate AKS optimization
 */
function validateAKSOptimization() {
  const buildPath = path.join(__dirname, '../build');
  
  if (!fs.existsSync(buildPath)) {
    console.error('❌ Build directory not found');
    return false;
  }
  
  const requiredFiles = [
    'index.html',
    'manifest.json',
    'sw.js',
    'health.json',
    'ready.json',
    'live.json',
    'aks-config.json',
    'kubernetes-metadata.json',
    'validate-deployment.sh'
  ];
  
  const missingFiles = requiredFiles.filter(file => 
    !fs.existsSync(path.join(buildPath, file))
  );
  
  if (missingFiles.length > 0) {
    console.error('❌ Missing required files:', missingFiles);
    return false;
  }
  
  // Validate JSON files
  const jsonFiles = [
    'manifest.json',
    'health.json',
    'ready.json',
    'live.json',
    'aks-config.json',
    'kubernetes-metadata.json'
  ];
  
  for (const file of jsonFiles) {
    try {
      const content = fs.readFileSync(path.join(buildPath, file), 'utf8');
      JSON.parse(content);
    } catch (error) {
      console.error(`❌ Invalid JSON in ${file}:`, error.message);
      return false;
    }
  }
  
  console.log('✅ AKS optimization validation passed');
  return true;
}

/**
 * Main optimization function
 */
function optimizeForAKS() {
  console.log('☸️  Starting AKS optimization...');
  
  try {
    generateHealthChecks();
    generateAKSConfig();
    generateKubernetesMetadata();
    optimizeForContainer();
    generateDeploymentValidation();
    
    if (validateAKSOptimization()) {
      console.log('✨ AKS optimization completed successfully!');
      console.log('🚀 Ready for deployment to Azure Kubernetes Service!');
    } else {
      console.error('❌ AKS optimization validation failed');
      process.exit(1);
    }
  } catch (error) {
    console.error('❌ AKS optimization failed:', error);
    process.exit(1);
  }
}

// Main execution
if (require.main === module) {
  optimizeForAKS();
}

module.exports = {
  optimizeForAKS,
  aksConfig
};
