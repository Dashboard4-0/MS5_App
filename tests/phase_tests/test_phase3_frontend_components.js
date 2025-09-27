/**
 * MS5.0 Floor Dashboard - Phase 3 Frontend Components Test
 * 
 * Comprehensive test suite for Phase 3 frontend component implementation
 * covering all new components and their functionality.
 */

const fs = require('fs');
const path = require('path');

// Test configuration
const TEST_CONFIG = {
  phase: 'Phase 3 - Frontend Implementation',
  timestamp: new Date().toISOString(),
  components: [
    // Common Components
    'LoadingSpinner',
    'Input', 
    'Modal',
    'StatusIndicator',
    
    // Dashboard Components
    'OEEGauge',
    'DowntimeChart', 
    'EquipmentStatus',
    
    // Job Components
    'JobCard',
    'JobList',
    'JobDetails',
    'JobStatusFilter',
    
    // Checklist Components
    'ChecklistItem',
    'ChecklistForm',
    'SignaturePad',
    
    // Andon Components
    'AndonButton',
    'AndonModal',
    'EscalationTree'
  ]
};

// Test results storage
const testResults = {
  phase: TEST_CONFIG.phase,
  timestamp: TEST_CONFIG.timestamp,
  totalTests: 0,
  passedTests: 0,
  failedTests: 0,
  testDetails: [],
  summary: {}
};

// Utility functions
function logTest(testName, status, details = '') {
  testResults.totalTests++;
  if (status === 'PASS') {
    testResults.passedTests++;
  } else {
    testResults.failedTests++;
  }
  
  testResults.testDetails.push({
    test: testName,
    status,
    details,
    timestamp: new Date().toISOString()
  });
  
  console.log(`[${status}] ${testName}${details ? ` - ${details}` : ''}`);
}

function checkFileExists(filePath) {
  try {
    return fs.existsSync(filePath);
  } catch (error) {
    return false;
  }
}

function checkFileContent(filePath, requiredContent) {
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    return requiredContent.every(item => content.includes(item));
  } catch (error) {
    return false;
  }
}

function checkComponentStructure(filePath, componentName) {
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    
    // Check for React component structure
    const hasReactImport = content.includes('import React');
    const hasComponentExport = content.includes(`export default ${componentName}`) || 
                              content.includes(`export { ${componentName} }`);
    const hasTypeScript = content.includes('interface ') || content.includes('type ');
    const hasPropsInterface = content.includes('Props');
    const hasStyles = content.includes('StyleSheet.create');
    
    return {
      hasReactImport,
      hasComponentExport,
      hasTypeScript,
      hasPropsInterface,
      hasStyles,
      allPresent: hasReactImport && hasComponentExport && hasTypeScript && hasPropsInterface && hasStyles
    };
  } catch (error) {
    return { allPresent: false };
  }
}

// Test functions
function testCommonComponents() {
  console.log('\n=== Testing Common Components ===');
  
  const commonComponents = [
    'LoadingSpinner',
    'Input',
    'Modal', 
    'StatusIndicator'
  ];
  
  commonComponents.forEach(component => {
    const filePath = `frontend/src/components/common/${component}.tsx`;
    
    // Test file existence
    if (checkFileExists(filePath)) {
      logTest(`Common Component: ${component} - File Exists`, 'PASS');
      
      // Test component structure
      const structure = checkComponentStructure(filePath, component);
      if (structure.allPresent) {
        logTest(`Common Component: ${component} - Structure`, 'PASS');
      } else {
        logTest(`Common Component: ${component} - Structure`, 'FAIL', 
          `Missing: ${Object.entries(structure).filter(([k,v]) => k !== 'allPresent' && !v).map(([k]) => k).join(', ')}`);
      }
      
      // Test specific functionality
      testComponentFunctionality(filePath, component);
      
    } else {
      logTest(`Common Component: ${component} - File Exists`, 'FAIL', 'File not found');
    }
  });
}

function testDashboardComponents() {
  console.log('\n=== Testing Dashboard Components ===');
  
  const dashboardComponents = [
    'OEEGauge',
    'DowntimeChart',
    'EquipmentStatus'
  ];
  
  dashboardComponents.forEach(component => {
    const filePath = `frontend/src/components/dashboard/${component}.tsx`;
    
    if (checkFileExists(filePath)) {
      logTest(`Dashboard Component: ${component} - File Exists`, 'PASS');
      
      const structure = checkComponentStructure(filePath, component);
      if (structure.allPresent) {
        logTest(`Dashboard Component: ${component} - Structure`, 'PASS');
      } else {
        logTest(`Dashboard Component: ${component} - Structure`, 'FAIL',
          `Missing: ${Object.entries(structure).filter(([k,v]) => k !== 'allPresent' && !v).map(([k]) => k).join(', ')}`);
      }
      
      testComponentFunctionality(filePath, component);
      
    } else {
      logTest(`Dashboard Component: ${component} - File Exists`, 'FAIL', 'File not found');
    }
  });
}

function testJobComponents() {
  console.log('\n=== Testing Job Components ===');
  
  const jobComponents = [
    'JobCard',
    'JobList', 
    'JobDetails',
    'JobStatusFilter'
  ];
  
  jobComponents.forEach(component => {
    const filePath = `frontend/src/components/jobs/${component}.tsx`;
    
    if (checkFileExists(filePath)) {
      logTest(`Job Component: ${component} - File Exists`, 'PASS');
      
      const structure = checkComponentStructure(filePath, component);
      if (structure.allPresent) {
        logTest(`Job Component: ${component} - Structure`, 'PASS');
      } else {
        logTest(`Job Component: ${component} - Structure`, 'FAIL',
          `Missing: ${Object.entries(structure).filter(([k,v]) => k !== 'allPresent' && !v).map(([k]) => k).join(', ')}`);
      }
      
      testComponentFunctionality(filePath, component);
      
    } else {
      logTest(`Job Component: ${component} - File Exists`, 'FAIL', 'File not found');
    }
  });
}

function testChecklistComponents() {
  console.log('\n=== Testing Checklist Components ===');
  
  const checklistComponents = [
    'ChecklistItem',
    'ChecklistForm',
    'SignaturePad'
  ];
  
  checklistComponents.forEach(component => {
    const filePath = `frontend/src/components/checklist/${component}.tsx`;
    
    if (checkFileExists(filePath)) {
      logTest(`Checklist Component: ${component} - File Exists`, 'PASS');
      
      const structure = checkComponentStructure(filePath, component);
      if (structure.allPresent) {
        logTest(`Checklist Component: ${component} - Structure`, 'PASS');
      } else {
        logTest(`Checklist Component: ${component} - Structure`, 'FAIL',
          `Missing: ${Object.entries(structure).filter(([k,v]) => k !== 'allPresent' && !v).map(([k]) => k).join(', ')}`);
      }
      
      testComponentFunctionality(filePath, component);
      
    } else {
      logTest(`Checklist Component: ${component} - File Exists`, 'FAIL', 'File not found');
    }
  });
}

function testAndonComponents() {
  console.log('\n=== Testing Andon Components ===');
  
  const andonComponents = [
    'AndonButton',
    'AndonModal',
    'EscalationTree'
  ];
  
  andonComponents.forEach(component => {
    const filePath = `frontend/src/components/andon/${component}.tsx`;
    
    if (checkFileExists(filePath)) {
      logTest(`Andon Component: ${component} - File Exists`, 'PASS');
      
      const structure = checkComponentStructure(filePath, component);
      if (structure.allPresent) {
        logTest(`Andon Component: ${component} - Structure`, 'PASS');
      } else {
        logTest(`Andon Component: ${component} - Structure`, 'FAIL',
          `Missing: ${Object.entries(structure).filter(([k,v]) => k !== 'allPresent' && !v).map(([k]) => k).join(', ')}`);
      }
      
      testComponentFunctionality(filePath, component);
      
    } else {
      logTest(`Andon Component: ${component} - File Exists`, 'FAIL', 'File not found');
    }
  });
}

function testComponentFunctionality(filePath, componentName) {
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    
    // Test for proper TypeScript interfaces
    if (content.includes('interface ') && content.includes('Props')) {
      logTest(`${componentName} - TypeScript Interfaces`, 'PASS');
    } else {
      logTest(`${componentName} - TypeScript Interfaces`, 'FAIL', 'Missing Props interface');
    }
    
    // Test for proper styling
    if (content.includes('StyleSheet.create') && content.includes('styles.')) {
      logTest(`${componentName} - Styling`, 'PASS');
    } else {
      logTest(`${componentName} - Styling`, 'FAIL', 'Missing StyleSheet implementation');
    }
    
    // Test for accessibility
    if (content.includes('testID') || content.includes('accessibilityLabel')) {
      logTest(`${componentName} - Accessibility`, 'PASS');
    } else {
      logTest(`${componentName} - Accessibility`, 'FAIL', 'Missing accessibility features');
    }
    
    // Test for proper error handling
    if (content.includes('error') || content.includes('Error') || content.includes('disabled')) {
      logTest(`${componentName} - Error Handling`, 'PASS');
    } else {
      logTest(`${componentName} - Error Handling`, 'FAIL', 'Missing error handling');
    }
    
    // Test for proper documentation
    if (content.includes('/**') && content.includes('*/')) {
      logTest(`${componentName} - Documentation`, 'PASS');
    } else {
      logTest(`${componentName} - Documentation`, 'FAIL', 'Missing JSDoc comments');
    }
    
  } catch (error) {
    logTest(`${componentName} - Functionality Check`, 'FAIL', `Error reading file: ${error.message}`);
  }
}

function testReduxIntegration() {
  console.log('\n=== Testing Redux Integration ===');
  
  // Test store configuration
  const storePath = 'frontend/src/store/index.ts';
  if (checkFileExists(storePath)) {
    logTest('Redux Store - File Exists', 'PASS');
    
    const storeContent = fs.readFileSync(storePath, 'utf8');
    if (storeContent.includes('configureStore') && storeContent.includes('persistStore')) {
      logTest('Redux Store - Configuration', 'PASS');
    } else {
      logTest('Redux Store - Configuration', 'FAIL', 'Missing store configuration');
    }
    
    if (storeContent.includes('export type RootState') && storeContent.includes('export type AppDispatch')) {
      logTest('Redux Store - TypeScript Types', 'PASS');
    } else {
      logTest('Redux Store - TypeScript Types', 'FAIL', 'Missing TypeScript types');
    }
    
  } else {
    logTest('Redux Store - File Exists', 'FAIL', 'Store file not found');
  }
  
  // Test slices
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
  
  sliceFiles.forEach(sliceFile => {
    const slicePath = `frontend/src/store/slices/${sliceFile}`;
    if (checkFileExists(slicePath)) {
      logTest(`Redux Slice: ${sliceFile} - File Exists`, 'PASS');
    } else {
      logTest(`Redux Slice: ${sliceFile} - File Exists`, 'FAIL', 'Slice file not found');
    }
  });
}

function testAPIService() {
  console.log('\n=== Testing API Service ===');
  
  const apiPath = 'frontend/src/services/api.ts';
  if (checkFileExists(apiPath)) {
    logTest('API Service - File Exists', 'PASS');
    
    const apiContent = fs.readFileSync(apiPath, 'utf8');
    if (apiContent.includes('class ApiService') && apiContent.includes('axios')) {
      logTest('API Service - Structure', 'PASS');
    } else {
      logTest('API Service - Structure', 'FAIL', 'Missing ApiService class or axios');
    }
    
    if (apiContent.includes('async ') && apiContent.includes('await ')) {
      logTest('API Service - Async Methods', 'PASS');
    } else {
      logTest('API Service - Async Methods', 'FAIL', 'Missing async/await implementation');
    }
    
    if (apiContent.includes('error') && apiContent.includes('catch')) {
      logTest('API Service - Error Handling', 'PASS');
    } else {
      logTest('API Service - Error Handling', 'FAIL', 'Missing error handling');
    }
    
  } else {
    logTest('API Service - File Exists', 'FAIL', 'API service file not found');
  }
}

function testConstantsAndConfig() {
  console.log('\n=== Testing Constants and Configuration ===');
  
  const constantsPath = 'frontend/src/config/constants.ts';
  if (checkFileExists(constantsPath)) {
    logTest('Constants - File Exists', 'PASS');
    
    const constantsContent = fs.readFileSync(constantsPath, 'utf8');
    if (constantsContent.includes('PERMISSIONS') && constantsContent.includes('USER_ROLES')) {
      logTest('Constants - Permission System', 'PASS');
    } else {
      logTest('Constants - Permission System', 'FAIL', 'Missing permission constants');
    }
    
    if (constantsContent.includes('COLORS') && constantsContent.includes('TYPOGRAPHY')) {
      logTest('Constants - Design System', 'PASS');
    } else {
      logTest('Constants - Design System', 'FAIL', 'Missing design system constants');
    }
    
  } else {
    logTest('Constants - File Exists', 'FAIL', 'Constants file not found');
  }
}

function generateSummary() {
  const successRate = ((testResults.passedTests / testResults.totalTests) * 100).toFixed(1);
  
  testResults.summary = {
    successRate: `${successRate}%`,
    totalTests: testResults.totalTests,
    passedTests: testResults.passedTests,
    failedTests: testResults.failedTests,
    status: successRate >= 90 ? 'PASS' : 'FAIL'
  };
  
  console.log('\n=== PHASE 3 TEST SUMMARY ===');
  console.log(`Phase: ${testResults.phase}`);
  console.log(`Timestamp: ${testResults.timestamp}`);
  console.log(`Total Tests: ${testResults.totalTests}`);
  console.log(`Passed: ${testResults.passedTests}`);
  console.log(`Failed: ${testResults.failedTests}`);
  console.log(`Success Rate: ${successRate}%`);
  console.log(`Overall Status: ${testResults.summary.status}`);
  
  if (testResults.failedTests > 0) {
    console.log('\n=== FAILED TESTS ===');
    testResults.testDetails
      .filter(test => test.status === 'FAIL')
      .forEach(test => {
        console.log(`- ${test.test}: ${test.details}`);
      });
  }
  
  return testResults;
}

// Main test execution
function runPhase3Tests() {
  console.log('🚀 Starting MS5.0 Phase 3 Frontend Components Test Suite');
  console.log(`📅 Test Date: ${new Date().toLocaleString()}`);
  console.log('=' * 60);
  
  try {
    testCommonComponents();
    testDashboardComponents();
    testJobComponents();
    testChecklistComponents();
    testAndonComponents();
    testReduxIntegration();
    testAPIService();
    testConstantsAndConfig();
    
    const results = generateSummary();
    
    // Save results to file
    fs.writeFileSync(
      'phase3_frontend_test_report.json',
      JSON.stringify(results, null, 2)
    );
    
    console.log('\n📊 Test report saved to: phase3_frontend_test_report.json');
    
    return results;
    
  } catch (error) {
    console.error('❌ Test execution failed:', error.message);
    return null;
  }
}

// Run tests if this file is executed directly
if (require.main === module) {
  runPhase3Tests();
}

module.exports = {
  runPhase3Tests,
  testCommonComponents,
  testDashboardComponents,
  testJobComponents,
  testChecklistComponents,
  testAndonComponents,
  testReduxIntegration,
  testAPIService,
  testConstantsAndConfig
};
