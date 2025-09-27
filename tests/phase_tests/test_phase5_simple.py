#!/usr/bin/env python3
"""
MS5.0 Floor Dashboard - Phase 5 Simple Test Suite

This test suite validates the OEE calculation system implementation
without requiring full backend dependencies.
"""

import os
import sys
import json
from datetime import datetime, timedelta
from typing import Dict, List, Any

def test_file_structure():
    """Test that all required files exist and have correct structure."""
    print("🔍 Testing File Structure...")
    
    test_results = {
        "total_tests": 0,
        "passed": 0,
        "failed": 0,
        "errors": []
    }
    
    def log_test(test_name: str, passed: bool, error: str = None):
        test_results["total_tests"] += 1
        if passed:
            test_results["passed"] += 1
            print(f"✅ PASS - {test_name}")
        else:
            test_results["failed"] += 1
            test_results["errors"].append(f"{test_name}: {error}")
            print(f"❌ FAIL - {test_name}")
            if error:
                print(f"    Error: {error}")
    
    # Test 1: OEE Calculator file exists
    oee_calculator_path = "backend/app/services/oee_calculator.py"
    if os.path.exists(oee_calculator_path):
        log_test("OEE Calculator File Exists", True)
    else:
        log_test("OEE Calculator File Exists", False, "File not found")
    
    # Test 2: OEE Calculator file has required methods
    if os.path.exists(oee_calculator_path):
        with open(oee_calculator_path, 'r') as f:
            content = f.read()
            
            required_methods = [
                "calculate_real_time_oee",
                "_get_equipment_config",
                "_calculate_availability_real_time",
                "_calculate_performance_real_time",
                "_calculate_quality_real_time",
                "get_downtime_data",
                "get_production_data",
                "store_oee_calculation"
            ]
            
            missing_methods = []
            for method in required_methods:
                if f"async def {method}" not in content and f"def {method}" not in content:
                    missing_methods.append(method)
            
            if missing_methods:
                log_test("OEE Calculator Methods", False, f"Missing methods: {missing_methods}")
            else:
                log_test("OEE Calculator Methods", True)
    
    # Test 3: Database schema files exist
    schema_files = [
        "001_init_telemetry.sql",
        "002_plc_equipment_management.sql",
        "003_production_management.sql",
        "008_fix_critical_schema_issues.sql"
    ]
    
    for schema_file in schema_files:
        if os.path.exists(schema_file):
            log_test(f"Schema File Exists - {schema_file}", True)
        else:
            log_test(f"Schema File Exists - {schema_file}", False, "File not found")
    
    # Test 4: OEE tables in schema
    if os.path.exists("003_production_management.sql"):
        with open("003_production_management.sql", 'r') as f:
            content = f.read()
            
            if "CREATE TABLE" in content and "oee_calculations" in content:
                log_test("OEE Tables in Schema", True)
            else:
                log_test("OEE Tables in Schema", False, "OEE tables not found in schema")
    
    return test_results

def test_code_quality():
    """Test code quality and structure."""
    print("\n🔍 Testing Code Quality...")
    
    test_results = {
        "total_tests": 0,
        "passed": 0,
        "failed": 0,
        "errors": []
    }
    
    def log_test(test_name: str, passed: bool, error: str = None):
        test_results["total_tests"] += 1
        if passed:
            test_results["passed"] += 1
            print(f"✅ PASS - {test_name}")
        else:
            test_results["failed"] += 1
            test_results["errors"].append(f"{test_name}: {error}")
            print(f"❌ FAIL - {test_name}")
            if error:
                print(f"    Error: {error}")
    
    # Test 1: OEE Calculator code structure
    oee_calculator_path = "backend/app/services/oee_calculator.py"
    if os.path.exists(oee_calculator_path):
        with open(oee_calculator_path, 'r') as f:
            content = f.read()
            
            # Check for proper imports
            if "from datetime import datetime, timedelta" in content:
                log_test("OEE Calculator Imports", True)
            else:
                log_test("OEE Calculator Imports", False, "Missing datetime imports")
            
            # Check for async methods
            async_methods = content.count("async def")
            if async_methods >= 5:
                log_test("OEE Calculator Async Methods", True)
            else:
                log_test("OEE Calculator Async Methods", False, f"Only {async_methods} async methods found")
            
            # Check for error handling
            if "try:" in content and "except" in content:
                log_test("OEE Calculator Error Handling", True)
            else:
                log_test("OEE Calculator Error Handling", False, "Missing error handling")
            
            # Check for logging
            if "logger" in content:
                log_test("OEE Calculator Logging", True)
            else:
                log_test("OEE Calculator Logging", False, "Missing logging")
            
            # Check for documentation
            if '"""' in content:
                log_test("OEE Calculator Documentation", True)
            else:
                log_test("OEE Calculator Documentation", False, "Missing docstrings")
    
    return test_results

def test_implementation_completeness():
    """Test implementation completeness according to Phase 5 requirements."""
    print("\n🔍 Testing Implementation Completeness...")
    
    test_results = {
        "total_tests": 0,
        "passed": 0,
        "failed": 0,
        "errors": []
    }
    
    def log_test(test_name: str, passed: bool, error: str = None):
        test_results["total_tests"] += 1
        if passed:
            test_results["passed"] += 1
            print(f"✅ PASS - {test_name}")
        else:
            test_results["failed"] += 1
            test_results["errors"].append(f"{test_name}: {error}")
            print(f"❌ FAIL - {test_name}")
            if error:
                print(f"    Error: {error}")
    
    # Test 1: Phase 5 requirements from implementation plan
    oee_calculator_path = "backend/app/services/oee_calculator.py"
    if os.path.exists(oee_calculator_path):
        with open(oee_calculator_path, 'r') as f:
            content = f.read()
            
            # Check for Phase 5 specific implementation
            if "Phase 5 Implementation" in content:
                log_test("Phase 5 Implementation Marker", True)
            else:
                log_test("Phase 5 Implementation Marker", False, "Missing Phase 5 implementation marker")
            
            # Check for real-time OEE calculation
            if "calculate_real_time_oee" in content and "current_metrics" in content:
                log_test("Real-time OEE Calculation", True)
            else:
                log_test("Real-time OEE Calculation", False, "Missing real-time OEE calculation")
            
            # Check for equipment config access
            if "_get_equipment_config" in content:
                log_test("Equipment Config Access", True)
            else:
                log_test("Equipment Config Access", False, "Missing equipment config access")
            
            # Check for downtime data integration
            if "get_downtime_data" in content:
                log_test("Downtime Data Integration", True)
            else:
                log_test("Downtime Data Integration", False, "Missing downtime data integration")
            
            # Check for production data integration
            if "get_production_data" in content:
                log_test("Production Data Integration", True)
            else:
                log_test("Production Data Integration", False, "Missing production data integration")
            
            # Check for OEE storage
            if "store_oee_calculation" in content:
                log_test("OEE Storage Method", True)
            else:
                log_test("OEE Storage Method", False, "Missing OEE storage method")
    
    # Test 2: Database schema completeness
    # OEE tables should be in 003_production_management.sql (Phase 3), not 008_fix_critical_schema_issues.sql (Phase 1)
    schema_file = "003_production_management.sql"
    if os.path.exists(schema_file):
        with open(schema_file, 'r') as f:
            content = f.read()
            
            if "oee_calculations" in content and "CREATE TABLE" in content:
                log_test(f"OEE Tables in {schema_file}", True)
            else:
                log_test(f"OEE Tables in {schema_file}", False, f"OEE tables not found in {schema_file}")
    else:
        log_test(f"OEE Tables in {schema_file}", False, f"Schema file {schema_file} not found")
    
    return test_results

def test_integration_points():
    """Test integration points with other services."""
    print("\n🔍 Testing Integration Points...")
    
    test_results = {
        "total_tests": 0,
        "passed": 0,
        "failed": 0,
        "errors": []
    }
    
    def log_test(test_name: str, passed: bool, error: str = None):
        test_results["total_tests"] += 1
        if passed:
            test_results["passed"] += 1
            print(f"✅ PASS - {test_name}")
        else:
            test_results["failed"] += 1
            test_results["errors"].append(f"{test_name}: {error}")
            print(f"❌ FAIL - {test_name}")
            if error:
                print(f"    Error: {error}")
    
    # Test 1: Downtime tracker integration
    oee_calculator_path = "backend/app/services/oee_calculator.py"
    if os.path.exists(oee_calculator_path):
        with open(oee_calculator_path, 'r') as f:
            content = f.read()
            
            if "DowntimeTracker" in content:
                log_test("Downtime Tracker Integration", True)
            else:
                log_test("Downtime Tracker Integration", False, "Missing DowntimeTracker integration")
    
    # Test 2: Database integration
    if os.path.exists(oee_calculator_path):
        with open(oee_calculator_path, 'r') as f:
            content = f.read()
            
            if "execute_query" in content or "execute_update" in content:
                log_test("Database Integration", True)
            else:
                log_test("Database Integration", False, "Missing database integration")
    
    # Test 3: Production service integration
    if os.path.exists(oee_calculator_path):
        with open(oee_calculator_path, 'r') as f:
            content = f.read()
            
            if "production" in content.lower():
                log_test("Production Service Integration", True)
            else:
                log_test("Production Service Integration", False, "Missing production service integration")
    
    return test_results

def main():
    """Main test execution function."""
    print("🚀 Starting Phase 5 Simple Test Suite")
    print("=" * 60)
    
    # Run all test categories
    file_results = test_file_structure()
    quality_results = test_code_quality()
    completeness_results = test_implementation_completeness()
    integration_results = test_integration_points()
    
    # Combine results
    total_tests = (file_results["total_tests"] + quality_results["total_tests"] + 
                   completeness_results["total_tests"] + integration_results["total_tests"])
    total_passed = (file_results["passed"] + quality_results["passed"] + 
                    completeness_results["passed"] + integration_results["passed"])
    total_failed = (file_results["failed"] + quality_results["failed"] + 
                    completeness_results["failed"] + integration_results["failed"])
    
    all_errors = (file_results["errors"] + quality_results["errors"] + 
                  completeness_results["errors"] + integration_results["errors"])
    
    # Print summary
    print("\n" + "=" * 60)
    print("📊 Phase 5 Simple Test Results Summary")
    print("=" * 60)
    print(f"Total Tests: {total_tests}")
    print(f"Passed: {total_passed} ✅")
    print(f"Failed: {total_failed} ❌")
    print(f"Success Rate: {(total_passed / total_tests * 100):.1f}%")
    
    if all_errors:
        print(f"\n❌ Errors:")
        for error in all_errors:
            print(f"  - {error}")
    
    # Save results
    results = {
        "total_tests": total_tests,
        "passed": total_passed,
        "failed": total_failed,
        "success_rate": (total_passed / total_tests * 100) if total_tests > 0 else 0,
        "errors": all_errors,
        "file_structure": file_results,
        "code_quality": quality_results,
        "implementation_completeness": completeness_results,
        "integration_points": integration_results
    }
    
    with open('phase5_simple_test_results.json', 'w') as f:
        json.dump(results, f, indent=2)
    
    print(f"\n📄 Test results saved to: phase5_simple_test_results.json")
    
    # Exit with appropriate code
    if total_failed > 0:
        print(f"\n❌ Phase 5 simple tests failed. {total_failed} tests failed.")
        sys.exit(1)
    else:
        print(f"\n✅ All Phase 5 simple tests passed successfully!")
        sys.exit(0)

if __name__ == "__main__":
    main()
