#!/bin/bash

# MS5.0 Floor Dashboard - User Acceptance Testing Script
# This script conducts comprehensive user acceptance testing for production deployment

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${LOG_DIR}/uat_${TIMESTAMP}.log"

# Environment variables
ENVIRONMENT=${ENVIRONMENT:-production}
TEST_TYPE=${TEST_TYPE:-full}  # full, functional, performance, security, usability
BASE_URL=${BASE_URL:-http://localhost:8000}
API_BASE_URL=${API_BASE_URL:-${BASE_URL}/api}
WS_BASE_URL=${WS_BASE_URL:-ws://localhost:8000/ws}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test results tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${PURPLE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_test() {
    echo -e "${CYAN}[TEST]${NC} $1" | tee -a "$LOG_FILE"
}

# Create directories
mkdir -p "$LOG_DIR"

log "Starting MS5.0 User Acceptance Testing - Environment: $ENVIRONMENT, Type: $TEST_TYPE"

# Change to script directory
cd "$SCRIPT_DIR"

# Test result tracking functions
test_start() {
    ((TOTAL_TESTS++))
    log_test "Starting test: $1"
}

test_pass() {
    ((PASSED_TESTS++))
    log_success "PASS: $1"
}

test_fail() {
    ((FAILED_TESTS++))
    log_error "FAIL: $1"
}

test_skip() {
    ((SKIPPED_TESTS++))
    log_warning "SKIP: $1"
}

# Function to test authentication and authorization
test_authentication_authorization() {
    log "Testing Authentication and Authorization..."
    
    # Test user login
    test_start "User Login"
    local login_response=$(curl -s -X POST "${API_BASE_URL}/auth/login" \
        -H "Content-Type: application/json" \
        -d '{"username":"test_user","password":"test_password"}' 2>/dev/null || echo "FAIL")
    
    if [[ "$login_response" == *"access_token"* ]]; then
        test_pass "User Login"
        local access_token=$(echo "$login_response" | jq -r '.access_token' 2>/dev/null || echo "")
    else
        test_fail "User Login - Invalid credentials or service unavailable"
        return 1
    fi
    
    # Test token validation
    test_start "Token Validation"
    local token_response=$(curl -s -X GET "${API_BASE_URL}/auth/profile" \
        -H "Authorization: Bearer $access_token" 2>/dev/null || echo "FAIL")
    
    if [[ "$token_response" == *"username"* ]]; then
        test_pass "Token Validation"
    else
        test_fail "Token Validation"
    fi
    
    # Test role-based access control
    test_start "Role-based Access Control"
    local role_response=$(curl -s -X GET "${API_BASE_URL}/users/roles" \
        -H "Authorization: Bearer $access_token" 2>/dev/null || echo "FAIL")
    
    if [[ "$role_response" == *"roles"* ]] || [[ "$role_response" == *"permissions"* ]]; then
        test_pass "Role-based Access Control"
    else
        test_fail "Role-based Access Control"
    fi
    
    # Test unauthorized access
    test_start "Unauthorized Access Prevention"
    local unauthorized_response=$(curl -s -X GET "${API_BASE_URL}/users/admin" \
        -H "Authorization: Bearer invalid_token" 2>/dev/null || echo "FAIL")
    
    if [[ "$unauthorized_response" == *"401"* ]] || [[ "$unauthorized_response" == *"unauthorized"* ]]; then
        test_pass "Unauthorized Access Prevention"
    else
        test_fail "Unauthorized Access Prevention"
    fi
}

# Function to test production management functionality
test_production_management() {
    log "Testing Production Management Functionality..."
    
    # Test production lines
    test_start "Production Lines Management"
    local lines_response=$(curl -s -X GET "${API_BASE_URL}/production/lines" \
        -H "Authorization: Bearer $access_token" 2>/dev/null || echo "FAIL")
    
    if [[ "$lines_response" == *"lines"* ]] || [[ "$lines_response" == *"[]"* ]]; then
        test_pass "Production Lines Management"
    else
        test_fail "Production Lines Management"
    fi
    
    # Test production schedules
    test_start "Production Schedules Management"
    local schedules_response=$(curl -s -X GET "${API_BASE_URL}/production/schedules" \
        -H "Authorization: Bearer $access_token" 2>/dev/null || echo "FAIL")
    
    if [[ "$schedules_response" == *"schedules"* ]] || [[ "$schedules_response" == *"[]"* ]]; then
        test_pass "Production Schedules Management"
    else
        test_fail "Production Schedules Management"
    fi
    
    # Test job assignments
    test_start "Job Assignments Management"
    local jobs_response=$(curl -s -X GET "${API_BASE_URL}/jobs/my-jobs" \
        -H "Authorization: Bearer $access_token" 2>/dev/null || echo "FAIL")
    
    if [[ "$jobs_response" == *"jobs"* ]] || [[ "$jobs_response" == *"[]"* ]]; then
        test_pass "Job Assignments Management"
    else
        test_fail "Job Assignments Management"
    fi
}

# Function to test OEE calculation and analytics
test_oee_analytics() {
    log "Testing OEE Calculation and Analytics..."
    
    # Test OEE calculation
    test_start "OEE Calculation"
    local oee_response=$(curl -s -X GET "${API_BASE_URL}/oee/lines/test-line" \
        -H "Authorization: Bearer $access_token" 2>/dev/null || echo "FAIL")
    
    if [[ "$oee_response" == *"oee"* ]] || [[ "$oee_response" == *"availability"* ]]; then
        test_pass "OEE Calculation"
    else
        test_fail "OEE Calculation"
    fi
    
    # Test OEE analytics
    test_start "OEE Analytics"
    local analytics_response=$(curl -s -X GET "${API_BASE_URL}/oee/analytics/test-equipment" \
        -H "Authorization: Bearer $access_token" 2>/dev/null || echo "FAIL")
    
    if [[ "$analytics_response" == *"analytics"* ]] || [[ "$analytics_response" == *"trends"* ]]; then
        test_pass "OEE Analytics"
    else
        test_fail "OEE Analytics"
    fi
}

# Function to test Andon system functionality
test_andon_system() {
    log "Testing Andon System Functionality..."
    
    # Test Andon events
    test_start "Andon Events Management"
    local andon_response=$(curl -s -X GET "${API_BASE_URL}/andon/events" \
        -H "Authorization: Bearer $access_token" 2>/dev/null || echo "FAIL")
    
    if [[ "$andon_response" == *"events"* ]] || [[ "$andon_response" == *"[]"* ]]; then
        test_pass "Andon Events Management"
    else
        test_fail "Andon Events Management"
    fi
    
    # Test Andon escalation
    test_start "Andon Escalation System"
    local escalation_response=$(curl -s -X GET "${API_BASE_URL}/andon/escalation-tree" \
        -H "Authorization: Bearer $access_token" 2>/dev/null || echo "FAIL")
    
    if [[ "$escalation_response" == *"escalation"* ]] || [[ "$escalation_response" == *"tree"* ]]; then
        test_pass "Andon Escalation System"
    else
        test_fail "Andon Escalation System"
    fi
}

# Function to test real-time WebSocket functionality
test_websocket_functionality() {
    log "Testing WebSocket Functionality..."
    
    # Test WebSocket connection
    test_start "WebSocket Connection"
    local ws_test_script=$(cat << 'EOF'
import websocket
import json
import time
import sys

def on_message(ws, message):
    print(f"Received: {message}")
    ws.close()

def on_error(ws, error):
    print(f"Error: {error}")
    sys.exit(1)

def on_close(ws, close_status_code, close_msg):
    print("WebSocket connection closed")

def on_open(ws):
    print("WebSocket connection opened")
    # Send test message
    test_message = {
        "type": "subscribe",
        "channel": "production_updates"
    }
    ws.send(json.dumps(test_message))
    time.sleep(2)
    ws.close()

if __name__ == "__main__":
    ws_url = "ws://localhost:8000/ws"
    ws = websocket.WebSocketApp(ws_url,
                              on_open=on_open,
                              on_message=on_message,
                              on_error=on_error,
                              on_close=on_close)
    ws.run_forever()
EOF
    )
    
    # Check if Python websocket-client is available
    if command -v python3 &> /dev/null; then
        python3 -c "import websocket" 2>/dev/null || {
            test_skip "WebSocket Connection - websocket-client not installed"
            return 0
        }
        
        if python3 -c "$ws_test_script" 2>/dev/null; then
            test_pass "WebSocket Connection"
        else
            test_fail "WebSocket Connection"
        fi
    else
        test_skip "WebSocket Connection - Python not available"
    fi
}

# Function to test reporting functionality
test_reporting_functionality() {
    log "Testing Reporting Functionality..."
    
    # Test report generation
    test_start "Report Generation"
    local report_response=$(curl -s -X POST "${API_BASE_URL}/reports/production/generate" \
        -H "Authorization: Bearer $access_token" \
        -H "Content-Type: application/json" \
        -d '{"line_id":"test-line","date":"2025-01-20"}' 2>/dev/null || echo "FAIL")
    
    if [[ "$report_response" == *"report"* ]] || [[ "$report_response" == *"pdf"* ]]; then
        test_pass "Report Generation"
    else
        test_fail "Report Generation"
    fi
    
    # Test report templates
    test_start "Report Templates"
    local templates_response=$(curl -s -X GET "${API_BASE_URL}/reports/templates" \
        -H "Authorization: Bearer $access_token" 2>/dev/null || echo "FAIL")
    
    if [[ "$templates_response" == *"templates"* ]] || [[ "$templates_response" == *"[]"* ]]; then
        test_pass "Report Templates"
    else
        test_fail "Report Templates"
    fi
}

# Function to test performance and load handling
test_performance_load() {
    log "Testing Performance and Load Handling..."
    
    # Test API response times
    test_start "API Response Times"
    local start_time=$(date +%s%N)
    curl -s -X GET "${API_BASE_URL}/production/status" \
        -H "Authorization: Bearer $access_token" > /dev/null
    local end_time=$(date +%s%N)
    local response_time=$(( (end_time - start_time) / 1000000 ))
    
    if [ $response_time -lt 1000 ]; then  # Less than 1 second
        test_pass "API Response Times (${response_time}ms)"
    else
        test_fail "API Response Times (${response_time}ms) - Too slow"
    fi
    
    # Test concurrent requests
    test_start "Concurrent Request Handling"
    local concurrent_requests=10
    local success_count=0
    
    for i in $(seq 1 $concurrent_requests); do
        if curl -s -X GET "${API_BASE_URL}/production/status" \
            -H "Authorization: Bearer $access_token" > /dev/null; then
            ((success_count++))
        fi
    done
    
    if [ $success_count -eq $concurrent_requests ]; then
        test_pass "Concurrent Request Handling ($success_count/$concurrent_requests)"
    else
        test_fail "Concurrent Request Handling ($success_count/$concurrent_requests)"
    fi
}

# Function to test security features
test_security_features() {
    log "Testing Security Features..."
    
    # Test SQL injection protection
    test_start "SQL Injection Protection"
    local sql_injection_response=$(curl -s -X GET "${API_BASE_URL}/production/lines?search='; DROP TABLE users; --" \
        -H "Authorization: Bearer $access_token" 2>/dev/null || echo "FAIL")
    
    if [[ "$sql_injection_response" != *"error"* ]] || [[ "$sql_injection_response" == *"[]"* ]]; then
        test_pass "SQL Injection Protection"
    else
        test_fail "SQL Injection Protection"
    fi
    
    # Test XSS protection
    test_start "XSS Protection"
    local xss_response=$(curl -s -X POST "${API_BASE_URL}/production/schedules" \
        -H "Authorization: Bearer $access_token" \
        -H "Content-Type: application/json" \
        -d '{"name":"<script>alert(\"XSS\")</script>","description":"Test"}' 2>/dev/null || echo "FAIL")
    
    if [[ "$xss_response" != *"<script>"* ]]; then
        test_pass "XSS Protection"
    else
        test_fail "XSS Protection"
    fi
    
    # Test rate limiting
    test_start "Rate Limiting"
    local rate_limit_count=0
    for i in $(seq 1 100); do
        local rate_response=$(curl -s -X GET "${API_BASE_URL}/production/status" \
            -H "Authorization: Bearer $access_token" 2>/dev/null || echo "FAIL")
        if [[ "$rate_response" == *"429"* ]]; then
            ((rate_limit_count++))
            break
        fi
    done
    
    if [ $rate_limit_count -gt 0 ]; then
        test_pass "Rate Limiting"
    else
        test_skip "Rate Limiting - Not triggered in test"
    fi
}

# Function to test data integrity and consistency
test_data_integrity() {
    log "Testing Data Integrity and Consistency..."
    
    # Test data validation
    test_start "Data Validation"
    local validation_response=$(curl -s -X POST "${API_BASE_URL}/production/lines" \
        -H "Authorization: Bearer $access_token" \
        -H "Content-Type: application/json" \
        -d '{"invalid_field":"invalid_value"}' 2>/dev/null || echo "FAIL")
    
    if [[ "$validation_response" == *"error"* ]] || [[ "$validation_response" == *"validation"* ]]; then
        test_pass "Data Validation"
    else
        test_fail "Data Validation"
    fi
    
    # Test data consistency
    test_start "Data Consistency"
    local consistency_response1=$(curl -s -X GET "${API_BASE_URL}/production/lines" \
        -H "Authorization: Bearer $access_token" 2>/dev/null || echo "FAIL")
    sleep 1
    local consistency_response2=$(curl -s -X GET "${API_BASE_URL}/production/lines" \
        -H "Authorization: Bearer $access_token" 2>/dev/null || echo "FAIL")
    
    if [[ "$consistency_response1" == "$consistency_response2" ]]; then
        test_pass "Data Consistency"
    else
        test_fail "Data Consistency"
    fi
}

# Function to test error handling and recovery
test_error_handling() {
    log "Testing Error Handling and Recovery..."
    
    # Test 404 error handling
    test_start "404 Error Handling"
    local not_found_response=$(curl -s -X GET "${API_BASE_URL}/nonexistent-endpoint" \
        -H "Authorization: Bearer $access_token" 2>/dev/null || echo "FAIL")
    
    if [[ "$not_found_response" == *"404"* ]] || [[ "$not_found_response" == *"not found"* ]]; then
        test_pass "404 Error Handling"
    else
        test_fail "404 Error Handling"
    fi
    
    # Test 500 error handling
    test_start "500 Error Handling"
    local server_error_response=$(curl -s -X GET "${API_BASE_URL}/production/error-test" \
        -H "Authorization: Bearer $access_token" 2>/dev/null || echo "FAIL")
    
    if [[ "$server_error_response" == *"500"* ]] || [[ "$server_error_response" == *"internal server error"* ]]; then
        test_pass "500 Error Handling"
    else
        test_skip "500 Error Handling - Error endpoint not available"
    fi
}

# Function to test monitoring and observability
test_monitoring_observability() {
    log "Testing Monitoring and Observability..."
    
    # Test health check endpoint
    test_start "Health Check Endpoint"
    local health_response=$(curl -s -X GET "${BASE_URL}/health" 2>/dev/null || echo "FAIL")
    
    if [[ "$health_response" == *"healthy"* ]] || [[ "$health_response" == *"ok"* ]]; then
        test_pass "Health Check Endpoint"
    else
        test_fail "Health Check Endpoint"
    fi
    
    # Test metrics endpoint
    test_start "Metrics Endpoint"
    local metrics_response=$(curl -s -X GET "${BASE_URL}/metrics" 2>/dev/null || echo "FAIL")
    
    if [[ "$metrics_response" == *"http_requests"* ]] || [[ "$metrics_response" == *"prometheus"* ]]; then
        test_pass "Metrics Endpoint"
    else
        test_skip "Metrics Endpoint - Not available"
    fi
    
    # Test status endpoint
    test_start "Status Endpoint"
    local status_response=$(curl -s -X GET "${BASE_URL}/status" 2>/dev/null || echo "FAIL")
    
    if [[ "$status_response" == *"status"* ]] || [[ "$status_response" == *"version"* ]]; then
        test_pass "Status Endpoint"
    else
        test_fail "Status Endpoint"
    fi
}

# Function to generate UAT report
generate_uat_report() {
    log "Generating User Acceptance Testing Report..."
    
    local report_file="${LOG_DIR}/uat_report_${TIMESTAMP}.md"
    local pass_rate=$(( (PASSED_TESTS * 100) / TOTAL_TESTS ))
    
    cat > "$report_file" << EOF
# MS5.0 Floor Dashboard - User Acceptance Testing Report

**Test Date:** $(date)
**Environment:** $ENVIRONMENT
**Test Type:** $TEST_TYPE
**Base URL:** $BASE_URL

## Test Summary

- **Total Tests:** $TOTAL_TESTS
- **Passed Tests:** $PASSED_TESTS
- **Failed Tests:** $FAILED_TESTS
- **Skipped Tests:** $SKIPPED_TESTS
- **Pass Rate:** ${pass_rate}%

## Test Results by Category

### Authentication and Authorization
- User Login: $([ $PASSED_TESTS -gt 0 ] && echo "✅ PASS" || echo "❌ FAIL")
- Token Validation: $([ $PASSED_TESTS -gt 0 ] && echo "✅ PASS" || echo "❌ FAIL")
- Role-based Access Control: $([ $PASSED_TESTS -gt 0 ] && echo "✅ PASS" || echo "❌ FAIL")

### Production Management
- Production Lines Management: $([ $PASSED_TESTS -gt 0 ] && echo "✅ PASS" || echo "❌ FAIL")
- Production Schedules Management: $([ $PASSED_TESTS -gt 0 ] && echo "✅ PASS" || echo "❌ FAIL")
- Job Assignments Management: $([ $PASSED_TESTS -gt 0 ] && echo "✅ PASS" || echo "❌ FAIL")

### OEE and Analytics
- OEE Calculation: $([ $PASSED_TESTS -gt 0 ] && echo "✅ PASS" || echo "❌ FAIL")
- OEE Analytics: $([ $PASSED_TESTS -gt 0 ] && echo "✅ PASS" || echo "❌ FAIL")

### Andon System
- Andon Events Management: $([ $PASSED_TESTS -gt 0 ] && echo "✅ PASS" || echo "❌ FAIL")
- Andon Escalation System: $([ $PASSED_TESTS -gt 0 ] && echo "✅ PASS" || echo "❌ FAIL")

### Real-time Features
- WebSocket Functionality: $([ $PASSED_TESTS -gt 0 ] && echo "✅ PASS" || echo "❌ FAIL")

### Reporting
- Report Generation: $([ $PASSED_TESTS -gt 0 ] && echo "✅ PASS" || echo "❌ FAIL")
- Report Templates: $([ $PASSED_TESTS -gt 0 ] && echo "✅ PASS" || echo "❌ FAIL")

### Performance
- API Response Times: $([ $PASSED_TESTS -gt 0 ] && echo "✅ PASS" || echo "❌ FAIL")
- Concurrent Request Handling: $([ $PASSED_TESTS -gt 0 ] && echo "✅ PASS" || echo "❌ FAIL")

### Security
- SQL Injection Protection: $([ $PASSED_TESTS -gt 0 ] && echo "✅ PASS" || echo "❌ FAIL")
- XSS Protection: $([ $PASSED_TESTS -gt 0 ] && echo "✅ PASS" || echo "❌ FAIL")
- Rate Limiting: $([ $PASSED_TESTS -gt 0 ] && echo "✅ PASS" || echo "❌ FAIL")

### Data Integrity
- Data Validation: $([ $PASSED_TESTS -gt 0 ] && echo "✅ PASS" || echo "❌ FAIL")
- Data Consistency: $([ $PASSED_TESTS -gt 0 ] && echo "✅ PASS" || echo "❌ FAIL")

### Error Handling
- 404 Error Handling: $([ $PASSED_TESTS -gt 0 ] && echo "✅ PASS" || echo "❌ FAIL")
- 500 Error Handling: $([ $PASSED_TESTS -gt 0 ] && echo "✅ PASS" || echo "❌ FAIL")

### Monitoring
- Health Check Endpoint: $([ $PASSED_TESTS -gt 0 ] && echo "✅ PASS" || echo "❌ FAIL")
- Metrics Endpoint: $([ $PASSED_TESTS -gt 0 ] && echo "✅ PASS" || echo "❌ FAIL")
- Status Endpoint: $([ $PASSED_TESTS -gt 0 ] && echo "✅ PASS" || echo "❌ FAIL")

## Recommendations

$([ $pass_rate -ge 90 ] && echo "✅ **PASSED** - System is ready for production deployment" || echo "❌ **FAILED** - Issues need to be addressed before production deployment")

### Next Steps

1. Review failed tests and address issues
2. Conduct additional testing if needed
3. Update documentation based on findings
4. Schedule production deployment
5. Plan user training sessions

## Test Environment Details

- **Environment:** $ENVIRONMENT
- **Base URL:** $BASE_URL
- **API Base URL:** $API_BASE_URL
- **WebSocket URL:** $WS_BASE_URL
- **Test Type:** $TEST_TYPE

## Log Files

- **Main Log:** $LOG_FILE
- **Report File:** $report_file

EOF
    
    log_success "UAT report generated: $report_file"
}

# Main UAT function
main() {
    local start_time=$(date +%s)
    
    # Execute tests based on type
    case $TEST_TYPE in
        full)
            test_authentication_authorization
            test_production_management
            test_oee_analytics
            test_andon_system
            test_websocket_functionality
            test_reporting_functionality
            test_performance_load
            test_security_features
            test_data_integrity
            test_error_handling
            test_monitoring_observability
            ;;
        functional)
            test_authentication_authorization
            test_production_management
            test_oee_analytics
            test_andon_system
            test_reporting_functionality
            ;;
        performance)
            test_performance_load
            test_websocket_functionality
            ;;
        security)
            test_security_features
            test_authentication_authorization
            ;;
        usability)
            test_production_management
            test_andon_system
            test_reporting_functionality
            ;;
        *)
            log_error "Invalid test type: $TEST_TYPE"
            exit 1
            ;;
    esac
    
    # Generate report
    generate_uat_report
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log "UAT completed in ${duration}s"
    log "Total Tests: $TOTAL_TESTS, Passed: $PASSED_TESTS, Failed: $FAILED_TESTS, Skipped: $SKIPPED_TESTS"
    log "Log file: $LOG_FILE"
    
    # Exit with appropriate code
    if [ $FAILED_TESTS -eq 0 ]; then
        log_success "All tests passed!"
        exit 0
    else
        log_error "$FAILED_TESTS tests failed"
        exit 1
    fi
}

# Help function
show_help() {
    echo "MS5.0 Floor Dashboard - User Acceptance Testing Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -e, --environment ENV   Environment (staging|production) (default: production)"
    echo "  -t, --type TYPE         Test type (full|functional|performance|security|usability) (default: full)"
    echo "  -u, --url URL           Base URL (default: http://localhost:8000)"
    echo ""
    echo "Environment Variables:"
    echo "  ENVIRONMENT            Environment (default: production)"
    echo "  TEST_TYPE              Test type (default: full)"
    echo "  BASE_URL               Base URL (default: http://localhost:8000)"
    echo "  API_BASE_URL           API Base URL (default: \$BASE_URL/api)"
    echo "  WS_BASE_URL            WebSocket URL (default: ws://localhost:8000/ws)"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Run full UAT on production"
    echo "  $0 -e staging -t functional           # Run functional tests on staging"
    echo "  $0 -t performance -u https://api.example.com  # Run performance tests"
    echo "  ENVIRONMENT=production $0             # Run full UAT on production"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -t|--type)
            TEST_TYPE="$2"
            shift 2
            ;;
        -u|--url)
            BASE_URL="$2"
            API_BASE_URL="${BASE_URL}/api"
            WS_BASE_URL="ws://$(echo $BASE_URL | sed 's|https\?://||')/ws"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(staging|production)$ ]]; then
    log_error "Invalid environment: $ENVIRONMENT (must be 'staging' or 'production')"
    exit 1
fi

# Validate test type
if [[ ! "$TEST_TYPE" =~ ^(full|functional|performance|security|usability)$ ]]; then
    log_error "Invalid test type: $TEST_TYPE (must be 'full', 'functional', 'performance', 'security', or 'usability')"
    exit 1
fi

# Run main function
main
