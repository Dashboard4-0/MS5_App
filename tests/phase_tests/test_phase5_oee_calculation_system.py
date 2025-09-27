#!/usr/bin/env python3
"""
MS5.0 Floor Dashboard - Phase 5 OEE Calculation System Test Suite

This test suite validates the OEE calculation system implementation
as specified in the Phase 5 requirements of the MS5.0 Implementation Plan.

Test Categories:
1. OEE Calculator Methods
2. Database Dependencies
3. Real-time Calculations
4. Historical Data Retrieval
5. Downtime Integration
6. Production Data Integration
7. Error Handling
8. Performance Testing
"""

import asyncio
import sys
import os
import json
from datetime import datetime, timedelta, date
from uuid import uuid4
from typing import Dict, List, Any

# Add the backend directory to the Python path
sys.path.append(os.path.join(os.path.dirname(__file__), 'backend'))

# Import the OEE calculator and related modules
try:
    from app.services.oee_calculator import OEECalculator
    from app.services.downtime_tracker import DowntimeTracker
    from app.database import execute_query, execute_update
    from app.utils.exceptions import BusinessLogicError, ValidationError
    print("✅ Successfully imported OEE calculator and dependencies")
except ImportError as e:
    print(f"❌ Failed to import required modules: {e}")
    sys.exit(1)


class Phase5OEETestSuite:
    """Comprehensive test suite for Phase 5 OEE Calculation System."""
    
    def __init__(self):
        self.test_results = {
            "total_tests": 0,
            "passed": 0,
            "failed": 0,
            "errors": [],
            "test_details": []
        }
        self.test_line_id = str(uuid4())
        self.test_equipment_code = "TEST_EQUIPMENT_001"
        self.test_metrics = {
            "running": True,
            "speed": 95.5,
            "cycle_time": 1.2,
            "good_parts": 450,
            "total_parts": 500,
            "fault_bits": [False] * 32
        }
    
    def log_test(self, test_name: str, passed: bool, error: str = None):
        """Log test result."""
        self.test_results["total_tests"] += 1
        if passed:
            self.test_results["passed"] += 1
            status = "✅ PASS"
        else:
            self.test_results["failed"] += 1
            status = "❌ FAIL"
            if error:
                self.test_results["errors"].append(f"{test_name}: {error}")
        
        self.test_results["test_details"].append({
            "test": test_name,
            "status": status,
            "error": error
        })
        
        print(f"{status} - {test_name}")
        if error:
            print(f"    Error: {error}")
    
    async def test_oee_calculator_methods(self):
        """Test OEE Calculator methods implementation."""
        print("\n🔍 Testing OEE Calculator Methods...")
        
        # Test 1: calculate_real_time_oee method exists and works
        try:
            result = await OEECalculator.calculate_real_time_oee(
                line_id=self.test_line_id,
                equipment_code=self.test_equipment_code,
                current_metrics=self.test_metrics
            )
            
            # Validate result structure
            required_fields = ["oee", "availability", "performance", "quality", "timestamp", "equipment_code", "line_id"]
            missing_fields = [field for field in required_fields if field not in result]
            
            if missing_fields:
                self.log_test("calculate_real_time_oee - Result Structure", False, f"Missing fields: {missing_fields}")
            else:
                self.log_test("calculate_real_time_oee - Result Structure", True)
            
            # Validate OEE calculation
            expected_oee = result["availability"] * result["performance"] * result["quality"]
            if abs(result["oee"] - expected_oee) < 0.001:
                self.log_test("calculate_real_time_oee - OEE Calculation", True)
            else:
                self.log_test("calculate_real_time_oee - OEE Calculation", False, f"Expected {expected_oee}, got {result['oee']}")
                
        except Exception as e:
            self.log_test("calculate_real_time_oee - Method Execution", False, str(e))
        
        # Test 2: _get_equipment_config method
        try:
            config = await OEECalculator._get_equipment_config(self.test_equipment_code)
            if isinstance(config, dict):
                self.log_test("_get_equipment_config - Return Type", True)
            else:
                self.log_test("_get_equipment_config - Return Type", False, f"Expected dict, got {type(config)}")
        except Exception as e:
            self.log_test("_get_equipment_config - Method Execution", False, str(e))
        
        # Test 3: _calculate_availability_real_time method
        try:
            availability = await OEECalculator._calculate_availability_real_time(
                self.test_equipment_code, self.test_metrics, {}
            )
            if 0 <= availability <= 1:
                self.log_test("_calculate_availability_real_time - Value Range", True)
            else:
                self.log_test("_calculate_availability_real_time - Value Range", False, f"Value {availability} out of range [0,1]")
        except Exception as e:
            self.log_test("_calculate_availability_real_time - Method Execution", False, str(e))
        
        # Test 4: _calculate_performance_real_time method
        try:
            performance = await OEECalculator._calculate_performance_real_time(
                self.test_equipment_code, self.test_metrics, {}
            )
            if 0 <= performance <= 1:
                self.log_test("_calculate_performance_real_time - Value Range", True)
            else:
                self.log_test("_calculate_performance_real_time - Value Range", False, f"Value {performance} out of range [0,1]")
        except Exception as e:
            self.log_test("_calculate_performance_real_time - Method Execution", False, str(e))
        
        # Test 5: _calculate_quality_real_time method
        try:
            quality = await OEECalculator._calculate_quality_real_time(
                self.test_equipment_code, self.test_metrics, {}
            )
            if 0 <= quality <= 1:
                self.log_test("_calculate_quality_real_time - Value Range", True)
            else:
                self.log_test("_calculate_quality_real_time - Value Range", False, f"Value {quality} out of range [0,1]")
        except Exception as e:
            self.log_test("_calculate_quality_real_time - Method Execution", False, str(e))
    
    async def test_database_dependencies(self):
        """Test database dependencies and table access."""
        print("\n🔍 Testing Database Dependencies...")
        
        # Test 1: equipment_config table access
        try:
            query = "SELECT COUNT(*) FROM factory_telemetry.equipment_config LIMIT 1"
            result = await execute_query(query, {})
            self.log_test("Database - equipment_config table access", True)
        except Exception as e:
            self.log_test("Database - equipment_config table access", False, str(e))
        
        # Test 2: oee_calculations table access
        try:
            query = "SELECT COUNT(*) FROM factory_telemetry.oee_calculations LIMIT 1"
            result = await execute_query(query, {})
            self.log_test("Database - oee_calculations table access", True)
        except Exception as e:
            self.log_test("Database - oee_calculations table access", False, str(e))
        
        # Test 3: downtime_events table access
        try:
            query = "SELECT COUNT(*) FROM factory_telemetry.downtime_events LIMIT 1"
            result = await execute_query(query, {})
            self.log_test("Database - downtime_events table access", True)
        except Exception as e:
            self.log_test("Database - downtime_events table access", False, str(e))
        
        # Test 4: production_lines table access
        try:
            query = "SELECT COUNT(*) FROM factory_telemetry.production_lines LIMIT 1"
            result = await execute_query(query, {})
            self.log_test("Database - production_lines table access", True)
        except Exception as e:
            self.log_test("Database - production_lines table access", False, str(e))
    
    async def test_real_time_calculations(self):
        """Test real-time OEE calculations."""
        print("\n🔍 Testing Real-time Calculations...")
        
        # Test 1: Real-time calculation with running equipment
        try:
            running_metrics = {
                "running": True,
                "speed": 100.0,
                "cycle_time": 1.0,
                "good_parts": 100,
                "total_parts": 100
            }
            
            result = await OEECalculator.calculate_real_time_oee(
                line_id=self.test_line_id,
                equipment_code=self.test_equipment_code,
                current_metrics=running_metrics
            )
            
            if result["availability"] > 0.9:  # Should be high for running equipment
                self.log_test("Real-time - Running Equipment Availability", True)
            else:
                self.log_test("Real-time - Running Equipment Availability", False, f"Low availability: {result['availability']}")
                
        except Exception as e:
            self.log_test("Real-time - Running Equipment Calculation", False, str(e))
        
        # Test 2: Real-time calculation with stopped equipment
        try:
            stopped_metrics = {
                "running": False,
                "speed": 0.0,
                "cycle_time": 0.0,
                "good_parts": 0,
                "total_parts": 0
            }
            
            result = await OEECalculator.calculate_real_time_oee(
                line_id=self.test_line_id,
                equipment_code=self.test_equipment_code,
                current_metrics=stopped_metrics
            )
            
            if result["availability"] == 0.0:  # Should be 0 for stopped equipment
                self.log_test("Real-time - Stopped Equipment Availability", True)
            else:
                self.log_test("Real-time - Stopped Equipment Availability", False, f"Non-zero availability: {result['availability']}")
                
        except Exception as e:
            self.log_test("Real-time - Stopped Equipment Calculation", False, str(e))
        
        # Test 3: Real-time calculation with quality issues
        try:
            quality_issue_metrics = {
                "running": True,
                "speed": 100.0,
                "cycle_time": 1.0,
                "good_parts": 80,
                "total_parts": 100
            }
            
            result = await OEECalculator.calculate_real_time_oee(
                line_id=self.test_line_id,
                equipment_code=self.test_equipment_code,
                current_metrics=quality_issue_metrics
            )
            
            if result["quality"] == 0.8:  # Should be 80% quality
                self.log_test("Real-time - Quality Calculation", True)
            else:
                self.log_test("Real-time - Quality Calculation", False, f"Expected 0.8, got {result['quality']}")
                
        except Exception as e:
            self.log_test("Real-time - Quality Calculation", False, str(e))
    
    async def test_historical_data_retrieval(self):
        """Test historical data retrieval methods."""
        print("\n🔍 Testing Historical Data Retrieval...")
        
        # Test 1: get_downtime_data method
        try:
            downtime_data = await OEECalculator.get_downtime_data(
                equipment_code=self.test_equipment_code,
                time_period=timedelta(hours=24)
            )
            
            required_fields = ["equipment_code", "period", "start_time", "end_time", "downtime_events", "total_events", "total_downtime_seconds"]
            missing_fields = [field for field in required_fields if field not in downtime_data]
            
            if missing_fields:
                self.log_test("get_downtime_data - Result Structure", False, f"Missing fields: {missing_fields}")
            else:
                self.log_test("get_downtime_data - Result Structure", True)
                
        except Exception as e:
            self.log_test("get_downtime_data - Method Execution", False, str(e))
        
        # Test 2: get_production_data method
        try:
            production_data = await OEECalculator.get_production_data(
                equipment_code=self.test_equipment_code,
                time_period=timedelta(hours=24)
            )
            
            required_fields = ["equipment_code", "period", "start_time", "end_time", "total_good_parts", "total_parts", "avg_cycle_time", "calculation_count"]
            missing_fields = [field for field in required_fields if field not in production_data]
            
            if missing_fields:
                self.log_test("get_production_data - Result Structure", False, f"Missing fields: {missing_fields}")
            else:
                self.log_test("get_production_data - Result Structure", True)
                
        except Exception as e:
            self.log_test("get_production_data - Method Execution", False, str(e))
        
        # Test 3: store_oee_calculation method
        try:
            oee_data = {
                "line_id": self.test_line_id,
                "equipment_code": self.test_equipment_code,
                "timestamp": datetime.utcnow(),
                "availability": 0.95,
                "performance": 0.90,
                "quality": 0.98,
                "oee": 0.8379,
                "planned_production_time": 86400,
                "actual_production_time": 82080,
                "ideal_cycle_time": 1.0,
                "actual_cycle_time": 1.1,
                "good_parts": 750,
                "total_parts": 765
            }
            
            await OEECalculator.store_oee_calculation(oee_data)
            self.log_test("store_oee_calculation - Method Execution", True)
            
        except Exception as e:
            self.log_test("store_oee_calculation - Method Execution", False, str(e))
    
    async def test_downtime_integration(self):
        """Test downtime tracker integration."""
        print("\n🔍 Testing Downtime Integration...")
        
        # Test 1: DowntimeTracker import and initialization
        try:
            downtime_tracker = DowntimeTracker()
            self.log_test("DowntimeTracker - Initialization", True)
        except Exception as e:
            self.log_test("DowntimeTracker - Initialization", False, str(e))
        
        # Test 2: Downtime integration in real-time OEE
        try:
            # Test with downtime metrics
            downtime_metrics = {
                "running": False,
                "speed": 0.0,
                "cycle_time": 0.0,
                "good_parts": 0,
                "total_parts": 0,
                "fault_bits": [True] + [False] * 31  # First fault bit active
            }
            
            result = await OEECalculator.calculate_real_time_oee(
                line_id=self.test_line_id,
                equipment_code=self.test_equipment_code,
                current_metrics=downtime_metrics
            )
            
            # Should have zero availability when equipment is down
            if result["availability"] == 0.0:
                self.log_test("Downtime Integration - Zero Availability", True)
            else:
                self.log_test("Downtime Integration - Zero Availability", False, f"Expected 0.0, got {result['availability']}")
                
        except Exception as e:
            self.log_test("Downtime Integration - Real-time Calculation", False, str(e))
    
    async def test_production_data_integration(self):
        """Test production data integration."""
        print("\n🔍 Testing Production Data Integration...")
        
        # Test 1: Production data with good performance
        try:
            good_performance_metrics = {
                "running": True,
                "speed": 105.0,  # Above target
                "cycle_time": 0.95,  # Below ideal (better performance)
                "good_parts": 1000,
                "total_parts": 1000
            }
            
            result = await OEECalculator.calculate_real_time_oee(
                line_id=self.test_line_id,
                equipment_code=self.test_equipment_code,
                current_metrics=good_performance_metrics
            )
            
            # Should have high performance due to better cycle time
            if result["performance"] > 0.9:
                self.log_test("Production Data - High Performance", True)
            else:
                self.log_test("Production Data - High Performance", False, f"Low performance: {result['performance']}")
                
        except Exception as e:
            self.log_test("Production Data - Performance Calculation", False, str(e))
        
        # Test 2: Production data with quality issues
        try:
            quality_issue_metrics = {
                "running": True,
                "speed": 100.0,
                "cycle_time": 1.0,
                "good_parts": 900,
                "total_parts": 1000
            }
            
            result = await OEECalculator.calculate_real_time_oee(
                line_id=self.test_line_id,
                equipment_code=self.test_equipment_code,
                current_metrics=quality_issue_metrics
            )
            
            # Should have 90% quality
            if abs(result["quality"] - 0.9) < 0.001:
                self.log_test("Production Data - Quality Calculation", True)
            else:
                self.log_test("Production Data - Quality Calculation", False, f"Expected 0.9, got {result['quality']}")
                
        except Exception as e:
            self.log_test("Production Data - Quality Calculation", False, str(e))
    
    async def test_error_handling(self):
        """Test error handling and edge cases."""
        print("\n🔍 Testing Error Handling...")
        
        # Test 1: Invalid equipment code
        try:
            result = await OEECalculator.calculate_real_time_oee(
                line_id=self.test_line_id,
                equipment_code="INVALID_EQUIPMENT",
                current_metrics=self.test_metrics
            )
            # Should still work with empty config
            self.log_test("Error Handling - Invalid Equipment Code", True)
        except Exception as e:
            self.log_test("Error Handling - Invalid Equipment Code", False, str(e))
        
        # Test 2: Empty metrics
        try:
            result = await OEECalculator.calculate_real_time_oee(
                line_id=self.test_line_id,
                equipment_code=self.test_equipment_code,
                current_metrics={}
            )
            # Should handle empty metrics gracefully
            self.log_test("Error Handling - Empty Metrics", True)
        except Exception as e:
            self.log_test("Error Handling - Empty Metrics", False, str(e))
        
        # Test 3: Zero division handling
        try:
            zero_metrics = {
                "running": False,
                "speed": 0,
                "cycle_time": 0,
                "good_parts": 0,
                "total_parts": 0
            }
            
            result = await OEECalculator.calculate_real_time_oee(
                line_id=self.test_line_id,
                equipment_code=self.test_equipment_code,
                current_metrics=zero_metrics
            )
            # Should handle zero values gracefully
            self.log_test("Error Handling - Zero Division", True)
        except Exception as e:
            self.log_test("Error Handling - Zero Division", False, str(e))
    
    async def test_performance(self):
        """Test performance and efficiency."""
        print("\n🔍 Testing Performance...")
        
        # Test 1: Multiple concurrent calculations
        try:
            start_time = datetime.utcnow()
            
            # Run 10 concurrent calculations
            tasks = []
            for i in range(10):
                task = OEECalculator.calculate_real_time_oee(
                    line_id=self.test_line_id,
                    equipment_code=f"{self.test_equipment_code}_{i}",
                    current_metrics=self.test_metrics
                )
                tasks.append(task)
            
            results = await asyncio.gather(*tasks)
            end_time = datetime.utcnow()
            
            duration = (end_time - start_time).total_seconds()
            if duration < 5.0:  # Should complete within 5 seconds
                self.log_test("Performance - Concurrent Calculations", True)
            else:
                self.log_test("Performance - Concurrent Calculations", False, f"Too slow: {duration}s")
                
        except Exception as e:
            self.log_test("Performance - Concurrent Calculations", False, str(e))
        
        # Test 2: Large time period queries
        try:
            start_time = datetime.utcnow()
            
            # Test with 7-day period
            downtime_data = await OEECalculator.get_downtime_data(
                equipment_code=self.test_equipment_code,
                time_period=timedelta(days=7)
            )
            
            end_time = datetime.utcnow()
            duration = (end_time - start_time).total_seconds()
            
            if duration < 2.0:  # Should complete within 2 seconds
                self.log_test("Performance - Large Time Period Query", True)
            else:
                self.log_test("Performance - Large Time Period Query", False, f"Too slow: {duration}s")
                
        except Exception as e:
            self.log_test("Performance - Large Time Period Query", False, str(e))
    
    async def run_all_tests(self):
        """Run all test categories."""
        print("🚀 Starting Phase 5 OEE Calculation System Test Suite")
        print("=" * 60)
        
        await self.test_oee_calculator_methods()
        await self.test_database_dependencies()
        await self.test_real_time_calculations()
        await self.test_historical_data_retrieval()
        await self.test_downtime_integration()
        await self.test_production_data_integration()
        await self.test_error_handling()
        await self.test_performance()
        
        # Print summary
        print("\n" + "=" * 60)
        print("📊 Phase 5 Test Results Summary")
        print("=" * 60)
        print(f"Total Tests: {self.test_results['total_tests']}")
        print(f"Passed: {self.test_results['passed']} ✅")
        print(f"Failed: {self.test_results['failed']} ❌")
        print(f"Success Rate: {(self.test_results['passed'] / self.test_results['total_tests'] * 100):.1f}%")
        
        if self.test_results['errors']:
            print(f"\n❌ Errors:")
            for error in self.test_results['errors']:
                print(f"  - {error}")
        
        return self.test_results


async def main():
    """Main test execution function."""
    test_suite = Phase5OEETestSuite()
    results = await test_suite.run_all_tests()
    
    # Save results to file
    with open('phase5_oee_test_results.json', 'w') as f:
        json.dump(results, f, indent=2, default=str)
    
    print(f"\n📄 Test results saved to: phase5_oee_test_results.json")
    
    # Exit with appropriate code
    if results['failed'] > 0:
        print(f"\n❌ Phase 5 tests failed. {results['failed']} tests failed.")
        sys.exit(1)
    else:
        print(f"\n✅ All Phase 5 tests passed successfully!")
        sys.exit(0)


if __name__ == "__main__":
    asyncio.run(main())
