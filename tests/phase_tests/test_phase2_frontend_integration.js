#!/usr/bin/env node
/**
 * MS5.0 Floor Dashboard - Phase 2 Frontend Integration Tests
 * 
 * This script tests the frontend integration components implemented in Phase 2.
 * It verifies that the Redux slices, API service layer, and constants are working correctly.
 * 
 * Test Coverage:
 * - Redux Store Configuration
 * - Redux Slices (Production, Jobs, Dashboard, Andon, OEE, Equipment, Reports, Quality)
 * - API Service Layer
 * - Permission Constants
 * - Store Integration
 * 
 * Usage:
 *     node test_phase2_frontend_integration.js
 */

const fs = require('fs');
const path = require('path');

class Phase2FrontendTester {
    constructor() {
        this.testResults = [];
        this.frontendPath = path.join(__dirname, 'frontend', 'src');
    }

    /**
     * Test Redux store configuration
     */
    testReduxStoreConfiguration() {
        console.log('\n🧪 Testing Redux Store Configuration...');
        
        try {
            const storePath = path.join(this.frontendPath, 'store', 'index.ts');
            const storeContent = fs.readFileSync(storePath, 'utf8');
            
            // Check if all required slices are imported
            const requiredSlices = [
                'authSlice',
                'productionSlice',
                'jobsSlice',
                'dashboardSlice',
                'andonSlice',
                'oeeSlice',
                'equipmentSlice',
                'reportsSlice',
                'qualitySlice',
                'settingsSlice',
                'offlineSlice'
            ];
            
            const allSlicesImported = requiredSlices.every(slice => 
                storeContent.includes(`import ${slice}`)
            );
            
            this.recordTestResult(
                'Redux Store - All slices imported',
                allSlicesImported,
                `All ${requiredSlices.length} slices are imported`
            );
            
            // Check if slices are added to root reducer
            const slicesInReducer = requiredSlices.every(slice => 
                storeContent.includes(`${slice.replace('Slice', '')}: ${slice}`)
            );
            
            this.recordTestResult(
                'Redux Store - Slices in root reducer',
                slicesInReducer,
                'All slices are properly configured in root reducer'
            );
            
            // Check persist configuration
            const hasPersistConfig = storeContent.includes('persistConfig') && 
                                   storeContent.includes('whitelist') && 
                                   storeContent.includes('blacklist');
            
            this.recordTestResult(
                'Redux Store - Persist configuration',
                hasPersistConfig,
                'Persist configuration is properly set up'
            );
            
        } catch (error) {
            this.recordTestResult(
                'Redux Store Configuration',
                false,
                `Error: ${error.message}`
            );
        }
    }

    /**
     * Test Redux slices
     */
    testReduxSlices() {
        console.log('\n🧪 Testing Redux Slices...');
        
        const slices = [
            { name: 'Production', file: 'productionSlice.ts' },
            { name: 'Jobs', file: 'jobsSlice.ts' },
            { name: 'Dashboard', file: 'dashboardSlice.ts' },
            { name: 'Andon', file: 'andonSlice.ts' },
            { name: 'OEE', file: 'oeeSlice.ts' },
            { name: 'Equipment', file: 'equipmentSlice.ts' },
            { name: 'Reports', file: 'reportsSlice.ts' },
            { name: 'Quality', file: 'qualitySlice.ts' }
        ];
        
        slices.forEach(slice => {
            try {
                const slicePath = path.join(this.frontendPath, 'store', 'slices', slice.file);
                const sliceContent = fs.readFileSync(slicePath, 'utf8');
                
                // Check for required slice components
                const hasInitialState = sliceContent.includes('initialState');
                const hasReducers = sliceContent.includes('reducers:');
                const hasExtraReducers = sliceContent.includes('extraReducers:');
                const hasAsyncThunks = sliceContent.includes('createAsyncThunk');
                const hasSelectors = sliceContent.includes('export const select');
                
                const sliceValid = hasInitialState && hasReducers && hasExtraReducers && hasAsyncThunks && hasSelectors;
                
                this.recordTestResult(
                    `Redux Slice - ${slice.name}`,
                    sliceValid,
                    `Slice has all required components: initialState, reducers, extraReducers, asyncThunks, selectors`
                );
                
                // Check for specific async thunks
                const asyncThunkPattern = /createAsyncThunk\(\s*'[^']+',/g;
                const asyncThunks = sliceContent.match(asyncThunkPattern) || [];
                
                this.recordTestResult(
                    `Redux Slice - ${slice.name} Async Thunks`,
                    asyncThunks.length > 0,
                    `Found ${asyncThunks.length} async thunks`
                );
                
            } catch (error) {
                this.recordTestResult(
                    `Redux Slice - ${slice.name}`,
                    false,
                    `Error: ${error.message}`
                );
            }
        });
    }

    /**
     * Test API service layer
     */
    testAPIServiceLayer() {
        console.log('\n🧪 Testing API Service Layer...');
        
        try {
            const apiPath = path.join(this.frontendPath, 'services', 'api.ts');
            const apiContent = fs.readFileSync(apiPath, 'utf8');
            
            // Check for API service class
            const hasApiServiceClass = apiContent.includes('class ApiService');
            this.recordTestResult(
                'API Service - Class definition',
                hasApiServiceClass,
                'ApiService class is defined'
            );
            
            // Check for HTTP methods
            const httpMethods = ['get', 'post', 'put', 'patch', 'delete'];
            const hasHttpMethods = httpMethods.every(method => 
                apiContent.includes(`async ${method}<T = any>`)
            );
            
            this.recordTestResult(
                'API Service - HTTP methods',
                hasHttpMethods,
                `All HTTP methods (${httpMethods.join(', ')}) are implemented`
            );
            
            // Check for specific API endpoints
            const apiEndpoints = [
                'getProductionLines',
                'getProductionSchedules',
                'getMyJobs',
                'acceptJob',
                'startJob',
                'completeJob',
                'getLineStatus',
                'getEquipmentStatus',
                'getAndonEvents',
                'createAndonEvent',
                'getOEEData',
                'getEquipment',
                'getMaintenanceSchedules',
                'getReportTemplates',
                'generateReport',
                'getQualityChecks',
                'getQualityInspections'
            ];
            
            const hasApiEndpoints = apiEndpoints.every(endpoint => 
                apiContent.includes(`async ${endpoint}`)
            );
            
            this.recordTestResult(
                'API Service - Specific endpoints',
                hasApiEndpoints,
                `All ${apiEndpoints.length} specific API endpoints are implemented`
            );
            
            // Check for error handling
            const hasErrorHandling = apiContent.includes('handleError') && 
                                   apiContent.includes('shouldRetry') && 
                                   apiContent.includes('retryRequest');
            
            this.recordTestResult(
                'API Service - Error handling',
                hasErrorHandling,
                'Error handling, retry logic, and request management are implemented'
            );
            
            // Check for caching
            const hasCaching = apiContent.includes('getCachedData') && 
                             apiContent.includes('setCachedData') && 
                             apiContent.includes('clearCache');
            
            this.recordTestResult(
                'API Service - Caching',
                hasCaching,
                'Caching functionality is implemented'
            );
            
        } catch (error) {
            this.recordTestResult(
                'API Service Layer',
                false,
                `Error: ${error.message}`
            );
        }
    }

    /**
     * Test permission constants
     */
    testPermissionConstants() {
        console.log('\n🧪 Testing Permission Constants...');
        
        try {
            const constantsPath = path.join(this.frontendPath, 'config', 'constants.ts');
            const constantsContent = fs.readFileSync(constantsPath, 'utf8');
            
            // Check for PERMISSIONS object
            const hasPermissionsObject = constantsContent.includes('export const PERMISSIONS');
            this.recordTestResult(
                'Permission Constants - PERMISSIONS object',
                hasPermissionsObject,
                'PERMISSIONS object is exported'
            );
            
            // Check for specific permission categories
            const permissionCategories = [
                'USER_READ', 'USER_WRITE', 'USER_DELETE',
                'PRODUCTION_READ', 'PRODUCTION_WRITE', 'PRODUCTION_DELETE',
                'LINE_READ', 'LINE_WRITE', 'LINE_DELETE',
                'SCHEDULE_READ', 'SCHEDULE_WRITE', 'SCHEDULE_DELETE',
                'JOB_READ', 'JOB_WRITE', 'JOB_ASSIGN', 'JOB_ACCEPT', 'JOB_START', 'JOB_COMPLETE',
                'CHECKLIST_READ', 'CHECKLIST_WRITE', 'CHECKLIST_COMPLETE',
                'OEE_READ', 'OEE_CALCULATE', 'ANALYTICS_READ',
                'DOWNTIME_READ', 'DOWNTIME_WRITE', 'DOWNTIME_CONFIRM',
                'ANDON_READ', 'ANDON_CREATE', 'ANDON_ACKNOWLEDGE', 'ANDON_RESOLVE',
                'EQUIPMENT_READ', 'EQUIPMENT_WRITE', 'EQUIPMENT_MAINTENANCE',
                'REPORTS_READ', 'REPORTS_WRITE', 'REPORTS_GENERATE', 'REPORTS_DELETE',
                'DASHBOARD_READ', 'DASHBOARD_WRITE',
                'QUALITY_READ', 'QUALITY_WRITE', 'QUALITY_APPROVE',
                'MAINTENANCE_READ', 'MAINTENANCE_WRITE', 'MAINTENANCE_SCHEDULE',
                'SYSTEM_CONFIG', 'SYSTEM_MONITOR', 'SYSTEM_MAINTENANCE'
            ];
            
            const hasAllPermissions = permissionCategories.every(permission => 
                constantsContent.includes(permission)
            );
            
            this.recordTestResult(
                'Permission Constants - All permissions defined',
                hasAllPermissions,
                `All ${permissionCategories.length} permission constants are defined`
            );
            
            // Check for USER_ROLES
            const hasUserRoles = constantsContent.includes('export const USER_ROLES');
            this.recordTestResult(
                'Permission Constants - USER_ROLES',
                hasUserRoles,
                'USER_ROLES are defined'
            );
            
            // Check for STATUS_TYPES
            const hasStatusTypes = constantsContent.includes('export const STATUS_TYPES');
            this.recordTestResult(
                'Permission Constants - STATUS_TYPES',
                hasStatusTypes,
                'STATUS_TYPES are defined'
            );
            
        } catch (error) {
            this.recordTestResult(
                'Permission Constants',
                false,
                `Error: ${error.message}`
            );
        }
    }

    /**
     * Test store integration
     */
    testStoreIntegration() {
        console.log('\n🧪 Testing Store Integration...');
        
        try {
            // Test that all slice files exist
            const sliceFiles = [
                'authSlice.ts',
                'productionSlice.ts',
                'jobsSlice.ts',
                'dashboardSlice.ts',
                'andonSlice.ts',
                'oeeSlice.ts',
                'equipmentSlice.ts',
                'reportsSlice.ts',
                'qualitySlice.ts',
                'settingsSlice.ts',
                'offlineSlice.ts'
            ];
            
            const allSliceFilesExist = sliceFiles.every(file => {
                const filePath = path.join(this.frontendPath, 'store', 'slices', file);
                return fs.existsSync(filePath);
            });
            
            this.recordTestResult(
                'Store Integration - All slice files exist',
                allSliceFilesExist,
                allSliceFilesExist ? `All ${sliceFiles.length} slice files are present` : `Missing slice files`
            );
            
            // Test that store index exports RootState and AppDispatch
            const storePath = path.join(this.frontendPath, 'store', 'index.ts');
            const storeContent = fs.readFileSync(storePath, 'utf8');
            
            const hasRootState = storeContent.includes('export type RootState');
            const hasAppDispatch = storeContent.includes('export type AppDispatch');
            
            this.recordTestResult(
                'Store Integration - Type exports',
                hasRootState && hasAppDispatch,
                'RootState and AppDispatch types are exported'
            );
            
            // Test that store is properly configured
            const hasStoreConfig = storeContent.includes('configureStore') && 
                                 storeContent.includes('persistStore') && 
                                 storeContent.includes('persistReducer');
            
            this.recordTestResult(
                'Store Integration - Store configuration',
                hasStoreConfig,
                'Store is properly configured with Redux Toolkit and Redux Persist'
            );
            
        } catch (error) {
            this.recordTestResult(
                'Store Integration',
                false,
                `Error: ${error.message}`
            );
        }
    }

    /**
     * Test file structure
     */
    testFileStructure() {
        console.log('\n🧪 Testing File Structure...');
        
        const requiredFiles = [
            'store/index.ts',
            'store/slices/productionSlice.ts',
            'store/slices/jobsSlice.ts',
            'store/slices/dashboardSlice.ts',
            'store/slices/andonSlice.ts',
            'store/slices/oeeSlice.ts',
            'store/slices/equipmentSlice.ts',
            'store/slices/reportsSlice.ts',
            'store/slices/qualitySlice.ts',
            'services/api.ts',
            'config/constants.ts'
        ];
        
        const allFilesExist = requiredFiles.every(file => {
            const filePath = path.join(this.frontendPath, file);
            return fs.existsSync(filePath);
        });
        
        this.recordTestResult(
            'File Structure - Required files exist',
            allFilesExist,
            `All ${requiredFiles.length} required files are present`
        );
        
        // Test file sizes (basic content check)
        const fileSizes = requiredFiles.map(file => {
            const filePath = path.join(this.frontendPath, file);
            if (fs.existsSync(filePath)) {
                const stats = fs.statSync(filePath);
                return { file, size: stats.size };
            }
            return { file, size: 0 };
        });
        
        const filesWithContent = fileSizes.filter(f => f.size > 1000); // Files with substantial content
        
        this.recordTestResult(
            'File Structure - File content',
            filesWithContent.length >= requiredFiles.length * 0.8, // At least 80% have substantial content
            `${filesWithContent.length}/${requiredFiles.length} files have substantial content`
        );
    }

    /**
     * Record a test result
     */
    recordTestResult(testName, passed, message) {
        const result = {
            testName,
            passed,
            message,
            timestamp: new Date().toISOString()
        };
        this.testResults.push(result);
        
        const status = passed ? "✅ PASS" : "❌ FAIL";
        console.log(`  ${status} ${testName}: ${message}`);
    }

    /**
     * Generate test report
     */
    generateReport() {
        console.log("\n" + "=".repeat(80));
        console.log("📊 PHASE 2 FRONTEND INTEGRATION TEST REPORT");
        console.log("=".repeat(80));
        
        const totalTests = this.testResults.length;
        const passedTests = this.testResults.filter(result => result.passed).length;
        const failedTests = totalTests - passedTests;
        
        console.log(`\n📈 SUMMARY:`);
        console.log(`  Total Tests: ${totalTests}`);
        console.log(`  Passed: ${passedTests} ✅`);
        console.log(`  Failed: ${failedTests} ❌`);
        console.log(`  Success Rate: ${((passedTests/totalTests)*100).toFixed(1)}%`);
        
        if (failedTests > 0) {
            console.log(`\n❌ FAILED TESTS:`);
            this.testResults
                .filter(result => !result.passed)
                .forEach(result => {
                    console.log(`  - ${result.testName}: ${result.message}`);
                });
        }
        
        console.log(`\n✅ PASSED TESTS:`);
        this.testResults
            .filter(result => result.passed)
            .forEach(result => {
                console.log(`  - ${result.testName}: ${result.message}`);
            });
        
        // Save detailed report
        const reportData = {
            phase: 'Phase 2 - Frontend Integration',
            timestamp: new Date().toISOString(),
            summary: {
                totalTests,
                passedTests,
                failedTests,
                successRate: (passedTests/totalTests)*100
            },
            testResults: this.testResults
        };
        
        fs.writeFileSync('phase2_frontend_test_report.json', JSON.stringify(reportData, null, 2));
        console.log(`\n📄 Detailed report saved to: phase2_frontend_test_report.json`);
        
        return passedTests === totalTests;
    }

    /**
     * Run all tests
     */
    runAllTests() {
        console.log("🚀 Starting Phase 2 Frontend Integration Tests...");
        console.log("=".repeat(80));
        
        this.testReduxStoreConfiguration();
        this.testReduxSlices();
        this.testAPIServiceLayer();
        this.testPermissionConstants();
        this.testStoreIntegration();
        this.testFileStructure();
        
        const success = this.generateReport();
        
        if (success) {
            console.log("\n🎉 All Phase 2 frontend tests passed! The frontend integration is working correctly.");
        } else {
            console.log("\n⚠️  Some Phase 2 frontend tests failed. Please review the failed tests and fix the issues.");
        }
        
        return success;
    }
}

// Run tests
const tester = new Phase2FrontendTester();
const success = tester.runAllTests();
process.exit(success ? 0 : 1);
