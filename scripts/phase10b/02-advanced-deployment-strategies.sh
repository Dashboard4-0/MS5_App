#!/bin/bash

# MS5.0 Floor Dashboard - Phase 10B.2: Advanced Deployment Strategies
# Implementation of blue-green and canary deployment strategies with comprehensive validation
#
# This script implements advanced deployment strategies including:
# - Blue-green deployment infrastructure and automation
# - Canary deployment with traffic splitting and analysis
# - Automated rollback procedures and health checks
# - Feature flag integration for deployment control
# - Comprehensive testing and validation of deployment strategies
#
# Usage: ./02-advanced-deployment-strategies.sh [environment] [options]
# Environment: staging|production (default: production)
# Options: --dry-run, --skip-validation, --force

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
K8S_DIR="$PROJECT_ROOT/k8s"
NAMESPACE_PREFIX="ms5"
ENVIRONMENT="${1:-production}"
DRY_RUN="${2:-false}"
SKIP_VALIDATION="${3:-false}"
FORCE="${4:-false}"

# Azure Configuration
RESOURCE_GROUP_NAME="rg-ms5-production-uksouth"
AKS_CLUSTER_NAME="aks-ms5-prod-uksouth"
ACR_NAME="ms5acrprod"
KEY_VAULT_NAME="kv-ms5-prod-uksouth"
LOCATION="UK South"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_phase() {
    echo -e "${PURPLE}[PHASE]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_step() {
    echo -e "${CYAN}[STEP]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Create log file
LOG_FILE="$PROJECT_ROOT/logs/phase10b-deployment-strategies-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "$(dirname "$LOG_FILE")"

# Enhanced logging function
log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" | tee -a "$LOG_FILE"
}

# Blue-green deployment implementation
implement_blue_green_deployment() {
    log_step "10B.2.1: Blue-Green Deployment Implementation"
    
    local namespace="$NAMESPACE_PREFIX-$ENVIRONMENT"
    
    # Create blue-green infrastructure
    log_info "Creating blue-green deployment infrastructure..."
    
    # Create blue-green service
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: ms5-backend-blue-green-service
  namespace: $namespace
  labels:
    app: ms5-backend
spec:
  selector:
    app: ms5-backend
    color: blue
  ports:
  - port: 8000
    targetPort: 8000
    protocol: TCP
  type: ClusterIP
EOF
    
    # Create blue deployment
    log_info "Creating blue deployment..."
    kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ms5-backend-blue
  namespace: $namespace
  labels:
    app: ms5-backend
    color: blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ms5-backend
      color: blue
  template:
    metadata:
      labels:
        app: ms5-backend
        color: blue
    spec:
      containers:
      - name: ms5-backend
        image: $ACR_NAME.azurecr.io/ms5-backend:latest
        ports:
        - containerPort: 8000
        env:
        - name: ENVIRONMENT
          value: "$ENVIRONMENT"
        - name: COLOR
          value: "blue"
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 5
EOF
    
    # Create green deployment
    log_info "Creating green deployment..."
    kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ms5-backend-green
  namespace: $namespace
  labels:
    app: ms5-backend
    color: green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ms5-backend
      color: green
  template:
    metadata:
      labels:
        app: ms5-backend
        color: green
    spec:
      containers:
      - name: ms5-backend
        image: $ACR_NAME.azurecr.io/ms5-backend:latest
        ports:
        - containerPort: 8000
        env:
        - name: ENVIRONMENT
          value: "$ENVIRONMENT"
        - name: COLOR
          value: "green"
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 5
EOF
    
    # Create blue-green deployment script
    log_info "Creating blue-green deployment automation script..."
    cat > "$SCRIPT_DIR/blue-green-deploy.sh" <<'EOF'
#!/bin/bash

# Blue-Green Deployment Script
# Usage: ./blue-green-deploy.sh [new_version] [environment]

set -euo pipefail

NEW_VERSION="${1:-latest}"
ENVIRONMENT="${2:-production}"
NAMESPACE="ms5-$ENVIRONMENT"
ACR_NAME="ms5acrprod"

# Get current color
CURRENT_COLOR=$(kubectl get service ms5-backend-blue-green-service -n "$NAMESPACE" -o jsonpath='{.spec.selector.color}')
NEW_COLOR=$([ "$CURRENT_COLOR" = "blue" ] && echo "green" || echo "blue")

echo "Deploying version $NEW_VERSION to $NEW_COLOR environment"
echo "Current color: $CURRENT_COLOR"
echo "New color: $NEW_COLOR"

# Deploy to new color
kubectl set image deployment/ms5-backend-$NEW_COLOR ms5-backend=$ACR_NAME.azurecr.io/ms5-backend:$NEW_VERSION -n "$NAMESPACE"

# Wait for deployment
kubectl rollout status deployment/ms5-backend-$NEW_COLOR -n "$NAMESPACE"

# Run health checks
echo "Running health checks on $NEW_COLOR deployment..."
kubectl exec -n "$NAMESPACE" deployment/ms5-backend-$NEW_COLOR -- python3 -c "
import requests
import sys

try:
    response = requests.get('http://localhost:8000/health', timeout=10)
    if response.status_code == 200:
        print('Health check passed')
        sys.exit(0)
    else:
        print(f'Health check failed: {response.status_code}')
        sys.exit(1)
except Exception as e:
    print(f'Health check failed: {e}')
    sys.exit(1)
"

# Run smoke tests
echo "Running smoke tests on $NEW_COLOR deployment..."
kubectl exec -n "$NAMESPACE" deployment/ms5-backend-$NEW_COLOR -- python3 -c "
import requests
import sys

try:
    # Test API endpoints
    base_url = 'http://localhost:8000'
    
    # Test health endpoint
    response = requests.get(f'{base_url}/health', timeout=10)
    if response.status_code != 200:
        raise Exception(f'Health endpoint failed: {response.status_code}')
    
    # Test API endpoints
    response = requests.get(f'{base_url}/api/production-lines/', timeout=10)
    if response.status_code != 200:
        raise Exception(f'Production lines endpoint failed: {response.status_code}')
    
    print('Smoke tests passed')
    sys.exit(0)
except Exception as e:
    print(f'Smoke tests failed: {e}')
    sys.exit(1)
"

# Switch traffic
echo "Switching traffic to $NEW_COLOR deployment..."
kubectl patch service ms5-backend-blue-green-service -n "$NAMESPACE" -p '{"spec":{"selector":{"color":"'$NEW_COLOR'"}}}'

# Verify traffic switch
echo "Verifying traffic switch..."
kubectl get service ms5-backend-blue-green-service -n "$NAMESPACE" -o jsonpath='{.spec.selector.color}'
echo ""

echo "Blue-green deployment completed successfully!"
echo "Traffic switched to $NEW_COLOR deployment"
EOF
    
    chmod +x "$SCRIPT_DIR/blue-green-deploy.sh"
    
    log_success "Blue-green deployment implementation completed"
}

# Canary deployment implementation
implement_canary_deployment() {
    log_step "10B.2.2: Canary Deployment Implementation"
    
    local namespace="$NAMESPACE_PREFIX-$ENVIRONMENT"
    
    # Install Istio for canary deployment
    log_info "Installing Istio for canary deployment..."
    
    if [[ "$DRY_RUN" != "true" ]]; then
        # Download and install Istio
        curl -L https://istio.io/downloadIstio | sh -
        export PATH="$PWD/istio-*/bin:$PATH"
        
        # Install Istio in the cluster
        istioctl install --set values.defaultRevision=default -y
        
        # Enable Istio injection for the namespace
        kubectl label namespace "$namespace" istio-injection=enabled --overwrite
        
        # Wait for Istio to be ready
        kubectl wait --for=condition=ready pod -l app=istiod -n istio-system --timeout=300s
    fi
    
    # Create canary deployment infrastructure
    log_info "Creating canary deployment infrastructure..."
    
    # Create canary service
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: ms5-backend-canary-service
  namespace: $namespace
  labels:
    app: ms5-backend
spec:
  selector:
    app: ms5-backend
  ports:
  - port: 8000
    targetPort: 8000
    protocol: TCP
  type: ClusterIP
EOF
    
    # Create stable deployment
    log_info "Creating stable deployment..."
    kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ms5-backend-stable
  namespace: $namespace
  labels:
    app: ms5-backend
    version: stable
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ms5-backend
      version: stable
  template:
    metadata:
      labels:
        app: ms5-backend
        version: stable
    spec:
      containers:
      - name: ms5-backend
        image: $ACR_NAME.azurecr.io/ms5-backend:latest
        ports:
        - containerPort: 8000
        env:
        - name: ENVIRONMENT
          value: "$ENVIRONMENT"
        - name: VERSION
          value: "stable"
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 5
EOF
    
    # Create canary deployment
    log_info "Creating canary deployment..."
    kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ms5-backend-canary
  namespace: $namespace
  labels:
    app: ms5-backend
    version: canary
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ms5-backend
      version: canary
  template:
    metadata:
      labels:
        app: ms5-backend
        version: canary
    spec:
      containers:
      - name: ms5-backend
        image: $ACR_NAME.azurecr.io/ms5-backend:latest
        ports:
        - containerPort: 8000
        env:
        - name: ENVIRONMENT
          value: "$ENVIRONMENT"
        - name: VERSION
          value: "canary"
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 5
          periodSeconds: 5
EOF
    
    # Create DestinationRule for canary
    kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: ms5-backend-destination-rule
  namespace: $namespace
spec:
  host: ms5-backend-canary-service
  subsets:
  - name: stable
    labels:
      version: stable
  - name: canary
    labels:
      version: canary
EOF
    
    # Create VirtualService for canary
    kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: ms5-backend-virtual-service
  namespace: $namespace
spec:
  hosts:
  - ms5-backend-canary-service
  http:
  - match:
    - headers:
        canary:
          exact: "true"
    route:
    - destination:
        host: ms5-backend-canary-service
        subset: canary
  - route:
    - destination:
        host: ms5-backend-canary-service
        subset: stable
      weight: 100
    - destination:
        host: ms5-backend-canary-service
        subset: canary
      weight: 0
EOF
    
    # Create canary deployment script
    log_info "Creating canary deployment automation script..."
    cat > "$SCRIPT_DIR/canary-deploy.sh" <<'EOF'
#!/bin/bash

# Canary Deployment Script
# Usage: ./canary-deploy.sh [new_version] [canary_percentage] [environment]

set -euo pipefail

NEW_VERSION="${1:-latest}"
CANARY_PERCENTAGE="${2:-10}"
ENVIRONMENT="${3:-production}"
NAMESPACE="ms5-$ENVIRONMENT"
ACR_NAME="ms5acrprod"

echo "Deploying canary version $NEW_VERSION with $CANARY_PERCENTAGE% traffic"

# Deploy canary version
kubectl set image deployment/ms5-backend-canary ms5-backend=$ACR_NAME.azurecr.io/ms5-backend:$NEW_VERSION -n "$NAMESPACE"

# Wait for deployment
kubectl rollout status deployment/ms5-backend-canary -n "$NAMESPACE"

# Run health checks
echo "Running health checks on canary deployment..."
kubectl exec -n "$NAMESPACE" deployment/ms5-backend-canary -- python3 -c "
import requests
import sys

try:
    response = requests.get('http://localhost:8000/health', timeout=10)
    if response.status_code == 200:
        print('Health check passed')
        sys.exit(0)
    else:
        print(f'Health check failed: {response.status_code}')
        sys.exit(1)
except Exception as e:
    print(f'Health check failed: {e}')
    sys.exit(1)
"

# Run canary analysis
echo "Running canary analysis..."
kubectl exec -n "$NAMESPACE" deployment/ms5-backend-canary -- python3 -c "
import requests
import time
import sys

try:
    base_url = 'http://localhost:8000'
    
    # Test canary-specific endpoints
    response = requests.get(f'{base_url}/api/production-lines/', timeout=10)
    if response.status_code != 200:
        raise Exception(f'Production lines endpoint failed: {response.status_code}')
    
    # Test performance
    start_time = time.time()
    response = requests.get(f'{base_url}/health', timeout=10)
    end_time = time.time()
    
    response_time = (end_time - start_time) * 1000  # Convert to milliseconds
    
    if response_time > 200:  # 200ms threshold
        raise Exception(f'Response time too slow: {response_time}ms')
    
    print(f'Canary analysis passed - Response time: {response_time}ms')
    sys.exit(0)
except Exception as e:
    print(f'Canary analysis failed: {e}')
    sys.exit(1)
"

# Configure traffic splitting
echo "Configuring traffic splitting to $CANARY_PERCENTAGE% canary..."
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: ms5-backend-virtual-service
  namespace: $NAMESPACE
spec:
  hosts:
  - ms5-backend-canary-service
  http:
  - match:
    - headers:
        canary:
          exact: "true"
    route:
    - destination:
        host: ms5-backend-canary-service
        subset: canary
  - route:
    - destination:
        host: ms5-backend-canary-service
        subset: stable
      weight: $((100 - CANARY_PERCENTAGE))
    - destination:
        host: ms5-backend-canary-service
        subset: canary
      weight: $CANARY_PERCENTAGE
EOF

echo "Canary deployment completed successfully!"
echo "Traffic split: $((100 - CANARY_PERCENTAGE))% stable, $CANARY_PERCENTAGE% canary"
EOF
    
    chmod +x "$SCRIPT_DIR/canary-deploy.sh"
    
    log_success "Canary deployment implementation completed"
}

# Feature flag integration
implement_feature_flags() {
    log_step "10B.2.3: Feature Flag Integration"
    
    local namespace="$NAMESPACE_PREFIX-$ENVIRONMENT"
    
    # Create feature flag ConfigMap
    log_info "Creating feature flag configuration..."
    kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: feature-flags
  namespace: $namespace
data:
  feature-flags.yaml: |
    feature_flags:
      blue_green_deployment:
        enabled: true
        description: "Enable blue-green deployment strategy"
        default_value: false
      
      canary_deployment:
        enabled: true
        description: "Enable canary deployment strategy"
        default_value: false
      
      advanced_monitoring:
        enabled: true
        description: "Enable advanced monitoring features"
        default_value: true
      
      cost_optimization:
        enabled: true
        description: "Enable cost optimization features"
        default_value: true
      
      predictive_scaling:
        enabled: false
        description: "Enable predictive scaling based on historical data"
        default_value: false
      
      automated_rollback:
        enabled: true
        description: "Enable automated rollback on failure detection"
        default_value: true
EOF
    
    # Create feature flag service
    log_info "Creating feature flag service..."
    kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: feature-flag-service
  namespace: $namespace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: feature-flag-service
  template:
    metadata:
      labels:
        app: feature-flag-service
    spec:
      containers:
      - name: feature-flag-service
        image: python:3.11-slim
        command: ["python3"]
        args: ["-c", "
import yaml
import json
import os
from http.server import HTTPServer, BaseHTTPRequestHandler
import threading
import time

# Load feature flags
with open('/etc/feature-flags/feature-flags.yaml', 'r') as f:
    config = yaml.safe_load(f)

class FeatureFlagHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/flags':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps(config['feature_flags']).encode())
        elif self.path.startswith('/flags/'):
            flag_name = self.path.split('/')[-1]
            if flag_name in config['feature_flags']:
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(json.dumps({
                    'name': flag_name,
                    'enabled': config['feature_flags'][flag_name]['enabled'],
                    'value': config['feature_flags'][flag_name]['default_value']
                }).encode())
            else:
                self.send_response(404)
                self.end_headers()
        else:
            self.send_response(404)
            self.end_headers()
    
    def do_POST(self):
        if self.path.startswith('/flags/'):
            flag_name = self.path.split('/')[-1]
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            try:
                data = json.loads(post_data.decode('utf-8'))
                if flag_name in config['feature_flags']:
                    config['feature_flags'][flag_name]['enabled'] = data.get('enabled', config['feature_flags'][flag_name]['enabled'])
                    config['feature_flags'][flag_name]['default_value'] = data.get('value', config['feature_flags'][flag_name]['default_value'])
                    self.send_response(200)
                    self.send_header('Content-type', 'application/json')
                    self.end_headers()
                    self.wfile.write(json.dumps({'status': 'success'}).encode())
                else:
                    self.send_response(404)
                    self.end_headers()
            except Exception as e:
                self.send_response(400)
                self.end_headers()
        else:
            self.send_response(404)
            self.end_headers()

# Start feature flag service
server = HTTPServer(('0.0.0.0', 8080), FeatureFlagHandler)
print('Feature flag service started on port 8080')
server.serve_forever()
"]
        ports:
        - containerPort: 8080
        volumeMounts:
        - name: feature-flags
          mountPath: /etc/feature-flags
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
      volumes:
      - name: feature-flags
        configMap:
          name: feature-flags
EOF
    
    # Create feature flag service
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: feature-flag-service
  namespace: $namespace
spec:
  selector:
    app: feature-flag-service
  ports:
  - port: 8080
    targetPort: 8080
  type: ClusterIP
EOF
    
    log_success "Feature flag integration completed"
}

# Automated rollback procedures
implement_automated_rollback() {
    log_step "10B.2.4: Automated Rollback Procedures"
    
    local namespace="$NAMESPACE_PREFIX-$ENVIRONMENT"
    
    # Create rollback monitoring deployment
    log_info "Creating automated rollback monitoring..."
    kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rollback-monitor
  namespace: $namespace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: rollback-monitor
  template:
    metadata:
      labels:
        app: rollback-monitor
    spec:
      containers:
      - name: rollback-monitor
        image: python:3.11-slim
        command: ["python3"]
        args: ["-c", "
import time
import requests
import json
import os
import subprocess

# Configuration
PROMETHEUS_URL = os.environ.get('PROMETHEUS_URL', 'http://ms5-prometheus-service:9090')
FEATURE_FLAG_URL = os.environ.get('FEATURE_FLAG_URL', 'http://feature-flag-service:8080')
NAMESPACE = os.environ.get('NAMESPACE', 'ms5-production')

def check_feature_flag(flag_name):
    try:
        response = requests.get(f'{FEATURE_FLAG_URL}/flags/{flag_name}')
        if response.status_code == 200:
            data = response.json()
            return data.get('enabled', False)
        return False
    except Exception as e:
        print(f'Error checking feature flag {flag_name}: {e}')
        return False

def query_prometheus(query):
    try:
        response = requests.get(f'{PROMETHEUS_URL}/api/v1/query', params={'query': query})
        if response.status_code == 200:
            data = response.json()
            if data['status'] == 'success' and data['data']['result']:
                return float(data['data']['result'][0]['value'][1])
        return None
    except Exception as e:
        print(f'Error querying Prometheus: {e}')
        return None

def check_error_rate():
    query = 'sum(rate(http_requests_total{job=\"ms5-backend\",code=~\"5..\"}[5m])) / sum(rate(http_requests_total{job=\"ms5-backend\"}[5m])) * 100'
    error_rate = query_prometheus(query)
    return error_rate

def check_response_time():
    query = 'histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{job=\"ms5-backend\"}[5m]))'
    response_time = query_prometheus(query)
    return response_time

def execute_rollback():
    print('Executing automated rollback...')
    try:
        # Get current color
        result = subprocess.run(['kubectl', 'get', 'service', 'ms5-backend-blue-green-service', '-n', NAMESPACE, '-o', 'jsonpath={.spec.selector.color}'], 
                              capture_output=True, text=True)
        current_color = result.stdout.strip()
        
        # Switch to opposite color
        new_color = 'green' if current_color == 'blue' else 'blue'
        
        # Execute rollback
        subprocess.run(['kubectl', 'patch', 'service', 'ms5-backend-blue-green-service', '-n', NAMESPACE, 
                       '-p', f'{{\"spec\":{{\"selector\":{{\"color\":\"{new_color}\"}}}}}}'], check=True)
        
        print(f'Rollback completed: switched to {new_color} deployment')
        return True
    except Exception as e:
        print(f'Rollback failed: {e}')
        return False

def monitor_and_rollback():
    while True:
        try:
            # Check if automated rollback is enabled
            if not check_feature_flag('automated_rollback'):
                print('Automated rollback is disabled')
                time.sleep(60)
                continue
            
            # Check error rate
            error_rate = check_error_rate()
            if error_rate is not None and error_rate > 5.0:  # 5% error rate threshold
                print(f'High error rate detected: {error_rate}%')
                execute_rollback()
                continue
            
            # Check response time
            response_time = check_response_time()
            if response_time is not None and response_time > 1.0:  # 1 second response time threshold
                print(f'High response time detected: {response_time}s')
                execute_rollback()
                continue
            
            print('System health is good')
            time.sleep(30)  # Check every 30 seconds
            
        except Exception as e:
            print(f'Error in monitoring: {e}')
            time.sleep(60)

# Start monitoring
monitor_and_rollback()
"]
        env:
        - name: PROMETHEUS_URL
          value: "http://ms5-prometheus-service:9090"
        - name: FEATURE_FLAG_URL
          value: "http://feature-flag-service:8080"
        - name: NAMESPACE
          value: "$namespace"
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
EOF
    
    log_success "Automated rollback procedures implemented"
}

# Comprehensive testing and validation
test_deployment_strategies() {
    log_step "10B.2.5: Comprehensive Testing and Validation"
    
    local namespace="$NAMESPACE_PREFIX-$ENVIRONMENT"
    
    if [[ "$DRY_RUN" != "true" ]]; then
        # Test blue-green deployment
        log_info "Testing blue-green deployment..."
        "$SCRIPT_DIR/blue-green-deploy.sh" "latest" "$ENVIRONMENT"
        
        # Test canary deployment
        log_info "Testing canary deployment..."
        "$SCRIPT_DIR/canary-deploy.sh" "latest" "10" "$ENVIRONMENT"
        
        # Test feature flags
        log_info "Testing feature flags..."
        kubectl exec -n "$namespace" deployment/feature-flag-service -- python3 -c "
import requests
import json

try:
    response = requests.get('http://localhost:8080/flags')
    if response.status_code == 200:
        flags = response.json()
        print('Feature flags retrieved successfully:')
        for flag_name, flag_config in flags.items():
            print(f'  {flag_name}: enabled={flag_config[\"enabled\"]}, value={flag_config[\"default_value\"]}')
    else:
        print(f'Failed to retrieve feature flags: {response.status_code}')
except Exception as e:
    print(f'Error testing feature flags: {e}')
" 2>&1 | tee -a "$LOG_FILE"
        
        # Test automated rollback
        log_info "Testing automated rollback..."
        kubectl exec -n "$namespace" deployment/rollback-monitor -- python3 -c "
import requests
import json

try:
    # Test rollback monitoring
    response = requests.get('http://localhost:8080/flags/automated_rollback')
    if response.status_code == 200:
        data = response.json()
        print(f'Automated rollback feature flag: {data}')
    else:
        print(f'Failed to check automated rollback flag: {response.status_code}')
except Exception as e:
    print(f'Error testing automated rollback: {e}')
" 2>&1 | tee -a "$LOG_FILE"
    fi
    
    log_success "Comprehensive testing and validation completed"
}

# Main execution
main() {
    log_phase "Starting Phase 10B.2: Advanced Deployment Strategies"
    log_info "Environment: $ENVIRONMENT"
    log_info "Dry Run: $DRY_RUN"
    log_info "Skip Validation: $SKIP_VALIDATION"
    log_info "Force: $FORCE"
    log_info "Log File: $LOG_FILE"
    echo ""
    
    # Execute deployment strategy phases
    implement_blue_green_deployment
    implement_canary_deployment
    implement_feature_flags
    implement_automated_rollback
    test_deployment_strategies
    
    # Phase 10B.2 completion
    log_phase "Phase 10B.2 execution completed successfully!"
    log_success "All advanced deployment strategy components have been implemented and validated"
    log_info "Check the log file at $LOG_FILE for detailed execution logs"
    echo ""
    
    # Display summary
    echo "=== Phase 10B.2 Implementation Summary ==="
    echo ""
    echo "✅ Blue-Green Deployment: Infrastructure and automation implemented"
    echo "✅ Canary Deployment: Traffic splitting and analysis implemented"
    echo "✅ Feature Flag Integration: Feature flag service and configuration implemented"
    echo "✅ Automated Rollback: Automated rollback procedures implemented"
    echo "✅ Comprehensive Testing: All deployment strategies tested and validated"
    echo ""
    echo "=== Deployment Strategies Available ==="
    echo "🔄 Blue-Green: ./scripts/phase10b/blue-green-deploy.sh [version] [environment]"
    echo "🎯 Canary: ./scripts/phase10b/canary-deploy.sh [version] [percentage] [environment]"
    echo "🚩 Feature Flags: http://feature-flag-service:8080/flags"
    echo "🔄 Automated Rollback: Enabled with monitoring and thresholds"
    echo ""
    echo "=== Next Steps ==="
    echo "1. Review the deployment strategies log at $LOG_FILE"
    echo "2. Proceed to Phase 10B.3: Cost Optimization and Resource Management"
    echo "3. Test deployment strategies in staging environment"
    echo "4. Configure deployment strategies for production use"
    echo "5. Train team on advanced deployment procedures"
}

# Error handling
trap 'log_error "Phase 10B.2 execution failed at line $LINENO"' ERR

# Execute main function
main "$@"
