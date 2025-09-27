#!/bin/bash

# MS5.0 Floor Dashboard - Frontend Deployment Script
# This script builds and deploys the React Native frontend application

set -e  # Exit on any error

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
LOG_DIR="${PROJECT_ROOT}/logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="${LOG_DIR}/deployment_${TIMESTAMP}.log"

# Environment variables
ENVIRONMENT=${ENVIRONMENT:-production}
PLATFORM=${PLATFORM:-all}  # all, android, ios
BUILD_TYPE=${BUILD_TYPE:-release}  # debug, staging, release
CLEAN_BUILD=${CLEAN_BUILD:-true}
RUN_TESTS=${RUN_TESTS:-true}
UPLOAD_TO_STORE=${UPLOAD_TO_STORE:-false}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Create log directory
mkdir -p "$LOG_DIR"

log "Starting frontend deployment for environment: $ENVIRONMENT, platform: $PLATFORM"

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check Node.js version
    if ! command -v node > /dev/null; then
        log_error "Node.js is not installed"
        exit 1
    fi
    
    local node_version=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$node_version" -lt 16 ]; then
        log_error "Node.js version 16 or higher is required (current: $(node --version))"
        exit 1
    fi
    log_success "Node.js version: $(node --version)"
    
    # Check npm version
    if ! command -v npm > /dev/null; then
        log_error "npm is not installed"
        exit 1
    fi
    log_success "npm version: $(npm --version)"
    
    # Check React Native CLI
    if ! command -v react-native > /dev/null; then
        log_warning "React Native CLI not found globally, using local version"
    fi
    
    # Check Android environment (if building for Android)
    if [[ "$PLATFORM" == "android" || "$PLATFORM" == "all" ]]; then
        if [ -z "$ANDROID_HOME" ]; then
            log_error "ANDROID_HOME environment variable is not set"
            exit 1
        fi
        
        if ! command -v adb > /dev/null; then
            log_error "Android Debug Bridge (adb) is not found"
            exit 1
        fi
        log_success "Android environment configured"
    fi
    
    # Check iOS environment (if building for iOS)
    if [[ "$PLATFORM" == "ios" || "$PLATFORM" == "all" ]]; then
        if ! command -v xcodebuild > /dev/null; then
            log_error "Xcode command line tools are not installed"
            exit 1
        fi
        
        if ! command -v pod > /dev/null; then
            log_error "CocoaPods is not installed"
            exit 1
        fi
        log_success "iOS environment configured"
    fi
}

# Install dependencies
install_dependencies() {
    log "Installing dependencies..."
    
    if [ "$CLEAN_BUILD" = "true" ]; then
        log "Cleaning node_modules and package-lock.json..."
        rm -rf node_modules package-lock.json
    fi
    
    if ! npm install >> "$LOG_FILE" 2>&1; then
        log_error "Failed to install dependencies"
        exit 1
    fi
    
    # Install iOS dependencies if building for iOS
    if [[ "$PLATFORM" == "ios" || "$PLATFORM" == "all" ]]; then
        log "Installing iOS dependencies..."
        cd ios
        if ! pod install >> "$LOG_FILE" 2>&1; then
            log_error "Failed to install iOS dependencies"
            exit 1
        fi
        cd ..
    fi
    
    log_success "Dependencies installed successfully"
}

# Run tests
run_tests() {
    if [ "$RUN_TESTS" = "false" ]; then
        log "Skipping tests as requested"
        return 0
    fi
    
    log "Running tests..."
    
    # Run unit tests
    log "Running unit tests..."
    if ! npm run test:unit >> "$LOG_FILE" 2>&1; then
        log_error "Unit tests failed"
        exit 1
    fi
    
    # Run integration tests
    log "Running integration tests..."
    if ! npm run test:integration >> "$LOG_FILE" 2>&1; then
        log_error "Integration tests failed"
        exit 1
    fi
    
    # Run type checking
    log "Running type checking..."
    if ! npm run type-check >> "$LOG_FILE" 2>&1; then
        log_error "Type checking failed"
        exit 1
    fi
    
    # Run linting
    log "Running linting..."
    if ! npm run lint >> "$LOG_FILE" 2>&1; then
        log_error "Linting failed"
        exit 1
    fi
    
    log_success "All tests passed"
}

# Build Android
build_android() {
    log "Building Android application..."
    
    # Set environment-specific build configuration
    case $ENVIRONMENT in
        staging)
            local build_command="build:android:staging"
            local build_type="Staging"
            ;;
        production)
            local build_command="build:android:production"
            local build_type="Production"
            ;;
        *)
            local build_command="build:android"
            local build_type="Debug"
            ;;
    esac
    
    log "Building Android $build_type version..."
    
    # Clean Android build
    if [ "$CLEAN_BUILD" = "true" ]; then
        log "Cleaning Android build..."
        cd android
        ./gradlew clean >> "$LOG_FILE" 2>&1
        cd ..
    fi
    
    # Build Android APK
    if ! npm run "$build_command" >> "$LOG_FILE" 2>&1; then
        log_error "Android build failed"
        exit 1
    fi
    
    # Find and copy APK to output directory
    local apk_dir="android/app/build/outputs/apk"
    local output_dir="${PROJECT_ROOT}/dist/android"
    
    mkdir -p "$output_dir"
    
    if [ -d "$apk_dir/release" ]; then
        cp "$apk_dir/release"/*.apk "$output_dir/"
        log_success "Android release APK copied to $output_dir"
    fi
    
    if [ -d "$apk_dir/staging" ]; then
        cp "$apk_dir/staging"/*.apk "$output_dir/"
        log_success "Android staging APK copied to $output_dir"
    fi
    
    log_success "Android build completed successfully"
}

# Build iOS
build_ios() {
    log "Building iOS application..."
    
    # Set environment-specific build configuration
    case $ENVIRONMENT in
        staging)
            local build_command="build:ios:staging"
            local scheme="MS5FloorDashboard-Staging"
            ;;
        production)
            local build_command="build:ios:production"
            local scheme="MS5FloorDashboard-Production"
            ;;
        *)
            local build_command="build:ios"
            local scheme="MS5FloorDashboard"
            ;;
    esac
    
    log "Building iOS $scheme..."
    
    # Clean iOS build
    if [ "$CLEAN_BUILD" = "true" ]; then
        log "Cleaning iOS build..."
        cd ios
        xcodebuild clean -workspace MS5FloorDashboard.xcworkspace -scheme "$scheme" >> "$LOG_FILE" 2>&1
        cd ..
    fi
    
    # Build iOS app
    if ! npm run "$build_command" >> "$LOG_FILE" 2>&1; then
        log_error "iOS build failed"
        exit 1
    fi
    
    # Find and copy IPA to output directory
    local archive_dir="ios/build"
    local output_dir="${PROJECT_ROOT}/dist/ios"
    
    mkdir -p "$output_dir"
    
    # Look for generated IPA files
    find ios -name "*.ipa" -exec cp {} "$output_dir/" \; 2>/dev/null || true
    
    if [ -d "$output_dir" ] && [ "$(ls -A "$output_dir" 2>/dev/null)" ]; then
        log_success "iOS IPA copied to $output_dir"
    else
        log_warning "No IPA file found in expected location"
    fi
    
    log_success "iOS build completed successfully"
}

# Upload to app stores (if enabled)
upload_to_stores() {
    if [ "$UPLOAD_TO_STORE" = "false" ]; then
        log "Skipping app store upload as requested"
        return 0
    fi
    
    log "Uploading to app stores..."
    
    # Android Play Store upload
    if [[ "$PLATFORM" == "android" || "$PLATFORM" == "all" ]]; then
        local android_output="${PROJECT_ROOT}/dist/android"
        if [ -d "$android_output" ] && [ "$(ls -A "$android_output" 2>/dev/null)" ]; then
            log "Uploading Android APK to Play Store..."
            # Add Play Store upload logic here
            # fastlane android deploy
            log_warning "Android Play Store upload not implemented in this version"
        fi
    fi
    
    # iOS App Store upload
    if [[ "$PLATFORM" == "ios" || "$PLATFORM" == "all" ]]; then
        local ios_output="${PROJECT_ROOT}/dist/ios"
        if [ -d "$ios_output" ] && [ "$(ls -A "$ios_output" 2>/dev/null)" ]; then
            log "Uploading iOS IPA to App Store..."
            # Add App Store upload logic here
            # fastlane ios deploy
            log_warning "iOS App Store upload not implemented in this version"
        fi
    fi
}

# Generate deployment report
generate_report() {
    log "Generating deployment report..."
    
    local report_file="${LOG_DIR}/deployment_report_${TIMESTAMP}.md"
    
    cat > "$report_file" << EOF
# MS5.0 Floor Dashboard - Deployment Report

**Deployment Date:** $(date)
**Environment:** $ENVIRONMENT
**Platform:** $PLATFORM
**Build Type:** $BUILD_TYPE

## Build Summary

- **Status:** $([ $? -eq 0 ] && echo "SUCCESS" || echo "FAILED")
- **Clean Build:** $CLEAN_BUILD
- **Tests Run:** $RUN_TESTS
- **Store Upload:** $UPLOAD_TO_STORE

## Build Outputs

### Android
EOF
    
    local android_output="${PROJECT_ROOT}/dist/android"
    if [ -d "$android_output" ] && [ "$(ls -A "$android_output" 2>/dev/null)" ]; then
        echo "- APK files:" >> "$report_file"
        ls -la "$android_output" >> "$report_file"
    else
        echo "- No Android build outputs found" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

### iOS
EOF
    
    local ios_output="${PROJECT_ROOT}/dist/ios"
    if [ -d "$ios_output" ] && [ "$(ls -A "$ios_output" 2>/dev/null)" ]; then
        echo "- IPA files:" >> "$report_file"
        ls -la "$ios_output" >> "$report_file"
    else
        echo "- No iOS build outputs found" >> "$report_file"
    fi
    
    cat >> "$report_file" << EOF

## Log Files

- **Main Log:** $LOG_FILE
- **Report:** $report_file

## Next Steps

1. Test the deployed application
2. Distribute to testers (staging environment)
3. Submit for app store review (production environment)
4. Monitor application performance and user feedback

EOF
    
    log_success "Deployment report generated: $report_file"
}

# Main deployment function
main() {
    log "Starting MS5.0 Floor Dashboard deployment process..."
    
    # Change to project root directory
    cd "$PROJECT_ROOT"
    
    # Run deployment steps
    check_prerequisites
    install_dependencies
    run_tests
    
    # Build applications
    if [[ "$PLATFORM" == "android" || "$PLATFORM" == "all" ]]; then
        build_android
    fi
    
    if [[ "$PLATFORM" == "ios" || "$PLATFORM" == "all" ]]; then
        build_ios
    fi
    
    # Upload to stores if enabled
    upload_to_stores
    
    # Generate report
    generate_report
    
    log_success "Deployment completed successfully!"
    log "Build outputs available in: ${PROJECT_ROOT}/dist/"
    log "Log file: $LOG_FILE"
}

# Help function
show_help() {
    echo "MS5.0 Floor Dashboard - Frontend Deployment Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help          Show this help message"
    echo "  -e, --environment   Set environment (staging, production) (default: production)"
    echo "  -p, --platform      Set platform (android, ios, all) (default: all)"
    echo "  -t, --build-type    Set build type (debug, staging, release) (default: release)"
    echo "  -c, --clean         Enable clean build (default: true)"
    echo "  --no-tests          Skip running tests"
    echo "  --upload            Upload to app stores (default: false)"
    echo ""
    echo "Environment Variables:"
    echo "  ENVIRONMENT         Environment name (default: production)"
    echo "  PLATFORM           Platform to build (default: all)"
    echo "  BUILD_TYPE         Build type (default: release)"
    echo "  CLEAN_BUILD        Enable clean build (default: true)"
    echo "  RUN_TESTS          Run tests (default: true)"
    echo "  UPLOAD_TO_STORE    Upload to stores (default: false)"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Deploy production build for all platforms"
    echo "  $0 -e staging -p android              # Deploy staging build for Android only"
    echo "  $0 -e production --upload             # Deploy production and upload to stores"
    echo "  $0 --no-tests -p ios                  # Deploy iOS without running tests"
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
        -p|--platform)
            PLATFORM="$2"
            shift 2
            ;;
        -t|--build-type)
            BUILD_TYPE="$2"
            shift 2
            ;;
        -c|--clean)
            CLEAN_BUILD="true"
            shift
            ;;
        --no-tests)
            RUN_TESTS="false"
            shift
            ;;
        --upload)
            UPLOAD_TO_STORE="true"
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(staging|production|development)$ ]]; then
    log_error "Invalid environment: $ENVIRONMENT (must be 'staging', 'production', or 'development')"
    exit 1
fi

# Validate platform
if [[ ! "$PLATFORM" =~ ^(android|ios|all)$ ]]; then
    log_error "Invalid platform: $PLATFORM (must be 'android', 'ios', or 'all')"
    exit 1
fi

# Validate build type
if [[ ! "$BUILD_TYPE" =~ ^(debug|staging|release)$ ]]; then
    log_error "Invalid build type: $BUILD_TYPE (must be 'debug', 'staging', or 'release')"
    exit 1
fi

# Run main function
main
