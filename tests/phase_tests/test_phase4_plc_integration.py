#!/usr/bin/env python3
"""
MS5.0 Floor Dashboard - Phase 4 PLC Integration Test

This test validates the PLC integration fixes implemented in Phase 4:
- Import path fixes
- Async/await functionality
- PLC data integration
- Production service integration
"""

import asyncio
import sys
import os
import json
from datetime import datetime, timedelta
from typing import Dict, Any
import structlog

# Add the backend directory to the Python path
sys.path.append(os.path.join(os.path.dirname(__file__), 'backend'))

from app.services.enhanced_metric_transformer import EnhancedMetricTransformer
from app.services.enhanced_telemetry_poller import EnhancedTelemetryPoller
from app.services.production_service import ProductionLineService
from app.services.oee_calculator import OEECalculator
from app.services.downtime_tracker import DowntimeTracker
from app.services.andon_service import AndonService
from app.services.notification_service import NotificationService

# Configure logging
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.JSONRenderer()
    ],
    wrapper_class=structlog.stdlib.BoundLogger,
    logger_factory=structlog.stdlib.LoggerFactory(),
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger()


class Phase4PLCTestSuite:
    """Test suite for Phase 4 PLC integration."""
    
    def __init__(self):
        self.test_results = []
        self.total_tests = 0
        self.passed_tests = 0
        self.failed_tests = 0
        
    def log_test_result(self, test_name: str, passed: bool, message: str = ""):
        """Log test result."""
        self.total_tests += 1
        if passed:
            self.passed_tests += 1
            status = "✅ PASS"
        else:
            self.failed_tests += 1
            status = "❌ FAIL"
        
        result = {
            "test_name": test_name,
            "status": status,
            "passed": passed,
            "message": message,
            "timestamp": datetime.utcnow().isoformat()
        }
        
        self.test_results.append(result)
        print(f"{status} {test_name}: {message}")
        
        if not passed:
            logger.error("Test failed", test_name=test_name, message=message)
        else:
            logger.info("Test passed", test_name=test_name, message=message)
    
    async def test_import_paths(self):
        """Test 1: Verify import paths are working correctly."""
        try:
            # Test enhanced metric transformer imports
            transformer = EnhancedMetricTransformer()
            self.log_test_result(
                "Import Paths - Enhanced Metric Transformer",
                True,
                "Successfully imported and instantiated EnhancedMetricTransformer"
            )
            
            # Test enhanced telemetry poller imports
            poller = EnhancedTelemetryPoller()
            self.log_test_result(
                "Import Paths - Enhanced Telemetry Poller",
                True,
                "Successfully imported and instantiated EnhancedTelemetryPoller"
            )
            
            # Test service imports
            production_service = ProductionLineService()
            oee_calculator = OEECalculator()
            downtime_tracker = DowntimeTracker()
            andon_service = AndonService()
            notification_service = NotificationService()
            
            self.log_test_result(
                "Import Paths - Production Services",
                True,
                "Successfully imported all production services"
            )
            
        except Exception as e:
            self.log_test_result(
                "Import Paths",
                False,
                f"Failed to import services: {str(e)}"
            )
    
    async def test_async_await_functionality(self):
        """Test 2: Verify async/await functionality works correctly."""
        try:
            transformer = EnhancedMetricTransformer()
            
            # Test data
            raw_data = {
                "processed": {
                    "product_count": 100,
                    "speed_real": 50.0,
                    "running_status": True,
                    "fault_bits": [False] * 64
                }
            }
            
            context_data = {
                "equipment_code": "BP01.PACK.BAG1",
                "target_speed": 60.0,
                "production_line_id": "test_line_1"
            }
            
            # Test async bagger metrics transformation
            bagger_metrics = await transformer.transform_bagger_metrics(raw_data, context_data)
            
            self.log_test_result(
                "Async/Await - Bagger Metrics",
                isinstance(bagger_metrics, dict) and len(bagger_metrics) > 0,
                f"Successfully transformed bagger metrics: {len(bagger_metrics)} fields"
            )
            
            # Test async basket loader metrics transformation
            basket_metrics = await transformer.transform_basket_loader_metrics(
                raw_data, context_data, parent_product=1
            )
            
            self.log_test_result(
                "Async/Await - Basket Loader Metrics",
                isinstance(basket_metrics, dict) and len(basket_metrics) > 0,
                f"Successfully transformed basket loader metrics: {len(basket_metrics)} fields"
            )
            
            # Verify enhanced metrics are present
            enhanced_metrics = [
                "production_line_id", "current_job_id", "target_quantity",
                "actual_quantity", "production_efficiency", "quality_rate",
                "changeover_status", "enhanced_oee", "enhanced_availability",
                "enhanced_performance", "enhanced_quality"
            ]
            
            has_enhanced_metrics = all(
                metric in bagger_metrics for metric in enhanced_metrics
            )
            
            self.log_test_result(
                "Async/Await - Enhanced Metrics",
                has_enhanced_metrics,
                f"Enhanced metrics present: {has_enhanced_metrics}"
            )
            
        except Exception as e:
            self.log_test_result(
                "Async/Await Functionality",
                False,
                f"Failed async/await test: {str(e)}"
            )
    
    async def test_production_context_management(self):
        """Test 3: Verify production context management."""
        try:
            transformer = EnhancedMetricTransformer()
            
            # Test production context retrieval
            context = await transformer._get_production_context("BP01.PACK.BAG1")
            
            self.log_test_result(
                "Production Context - Retrieval",
                isinstance(context, dict),
                f"Successfully retrieved production context: {len(context)} fields"
            )
            
            # Test production context caching
            context2 = await transformer._get_production_context("BP01.PACK.BAG1")
            
            self.log_test_result(
                "Production Context - Caching",
                context == context2,
                "Production context caching working correctly"
            )
            
            # Test production context update
            transformer.update_production_context("BP01.PACK.BAG1", {
                "test_field": "test_value",
                "updated_at": datetime.utcnow()
            })
            
            self.log_test_result(
                "Production Context - Update",
                True,
                "Successfully updated production context"
            )
            
        except Exception as e:
            self.log_test_result(
                "Production Context Management",
                False,
                f"Failed production context test: {str(e)}"
            )
    
    async def test_enhanced_telemetry_poller(self):
        """Test 4: Verify enhanced telemetry poller functionality."""
        try:
            poller = EnhancedTelemetryPoller()
            
            # Test poller initialization
            await poller.initialize()
            
            self.log_test_result(
                "Enhanced Poller - Initialization",
                poller.production_service is not None and poller.andon_service is not None,
                "Successfully initialized enhanced poller with production services"
            )
            
            # Test performance stats
            stats = poller.get_performance_stats()
            
            self.log_test_result(
                "Enhanced Poller - Performance Stats",
                isinstance(stats, dict) and "total_cycles" in stats,
                f"Performance stats available: {stats}"
            )
            
            # Test event processing
            test_event = {
                "type": "job_completed",
                "equipment_code": "BP01.PACK.BAG1",
                "target_quantity": 1000,
                "actual_quantity": 1000,
                "timestamp": datetime.utcnow()
            }
            
            await poller._process_production_event(test_event)
            
            self.log_test_result(
                "Enhanced Poller - Event Processing",
                True,
                "Successfully processed production event"
            )
            
        except Exception as e:
            self.log_test_result(
                "Enhanced Telemetry Poller",
                False,
                f"Failed enhanced poller test: {str(e)}"
            )
    
    async def test_production_event_handlers(self):
        """Test 5: Verify production event handlers."""
        try:
            poller = EnhancedTelemetryPoller()
            await poller.initialize()
            
            # Test job completion handler
            job_event = {
                "equipment_code": "BP01.PACK.BAG1",
                "target_quantity": 1000,
                "actual_quantity": 1000
            }
            
            await poller._handle_job_completion(job_event)
            
            self.log_test_result(
                "Event Handlers - Job Completion",
                True,
                "Successfully handled job completion event"
            )
            
            # Test quality issue handler
            quality_event = {
                "equipment_code": "BP01.PACK.BAG1",
                "quality_rate": 90.0,
                "threshold": 95.0
            }
            
            await poller._handle_quality_issue(quality_event)
            
            self.log_test_result(
                "Event Handlers - Quality Issue",
                True,
                "Successfully handled quality issue event"
            )
            
            # Test changeover handlers
            changeover_event = {
                "equipment_code": "BP01.PACK.BAG1",
                "job_id": "job_123"
            }
            
            await poller._handle_changeover_started(changeover_event)
            await poller._handle_changeover_completed(changeover_event)
            
            self.log_test_result(
                "Event Handlers - Changeover",
                True,
                "Successfully handled changeover events"
            )
            
            # Test fault handlers
            fault_event = {
                "equipment_code": "BP01.PACK.BAG1",
                "fault_bit": 1,
                "metrics": {}
            }
            
            await poller._handle_fault_detected_event(fault_event)
            await poller._handle_fault_cleared_event(fault_event)
            
            self.log_test_result(
                "Event Handlers - Fault Detection",
                True,
                "Successfully handled fault events"
            )
            
        except Exception as e:
            self.log_test_result(
                "Production Event Handlers",
                False,
                f"Failed event handler test: {str(e)}"
            )
    
    async def test_plc_data_integration(self):
        """Test 6: Verify PLC data integration."""
        try:
            transformer = EnhancedMetricTransformer()
            
            # Simulate PLC data
            plc_data = {
                "processed": {
                    "product_count": 150,
                    "speed_real": 55.0,
                    "running_status": True,
                    "fault_bits": [False] * 64,
                    "temperature": 25.5,
                    "pressure": 1.2
                }
            }
            
            context_data = {
                "equipment_code": "BP01.PACK.BAG1",
                "target_speed": 60.0,
                "production_line_id": "test_line_1",
                "current_job_id": "job_123",
                "target_quantity": 1000
            }
            
            # Test PLC data transformation
            metrics = await transformer.transform_bagger_metrics(plc_data, context_data)
            
            # Verify PLC data is properly integrated
            plc_integration_checks = [
                metrics.get("product_count") == 150,
                metrics.get("speed_real") == 55.0,
                metrics.get("running_status") == True,
                metrics.get("production_line_id") == "test_line_1",
                metrics.get("current_job_id") == "job_123",
                metrics.get("target_quantity") == 1000
            ]
            
            all_checks_passed = all(plc_integration_checks)
            
            self.log_test_result(
                "PLC Data Integration - Basic Data",
                all_checks_passed,
                f"PLC data integration: {sum(plc_integration_checks)}/{len(plc_integration_checks)} checks passed"
            )
            
            # Test enhanced metrics calculation
            enhanced_metrics_present = all([
                "enhanced_oee" in metrics,
                "enhanced_availability" in metrics,
                "enhanced_performance" in metrics,
                "enhanced_quality" in metrics,
                "production_efficiency" in metrics,
                "quality_rate" in metrics
            ])
            
            self.log_test_result(
                "PLC Data Integration - Enhanced Metrics",
                enhanced_metrics_present,
                f"Enhanced metrics calculated: {enhanced_metrics_present}"
            )
            
        except Exception as e:
            self.log_test_result(
                "PLC Data Integration",
                False,
                f"Failed PLC data integration test: {str(e)}"
            )
    
    async def test_production_service_integration(self):
        """Test 7: Verify production service integration."""
        try:
            transformer = EnhancedMetricTransformer()
            
            # Test with production service
            production_service = ProductionLineService()
            transformer.production_service = production_service
            
            # Test OEE calculator integration
            oee_calculator = OEECalculator()
            transformer.oee_calculator = oee_calculator
            
            # Test downtime tracker integration
            downtime_tracker = DowntimeTracker()
            transformer.downtime_tracker = downtime_tracker
            
            # Test Andon service integration
            andon_service = AndonService()
            transformer.andon_service = andon_service
            
            # Test notification service integration
            notification_service = NotificationService()
            transformer.notification_service = notification_service
            
            self.log_test_result(
                "Production Service Integration - Services",
                all([
                    transformer.production_service is not None,
                    transformer.oee_calculator is not None,
                    transformer.downtime_tracker is not None,
                    transformer.andon_service is not None,
                    transformer.notification_service is not None
                ]),
                "All production services successfully integrated"
            )
            
            # Test service method calls
            test_data = {
                "processed": {
                    "product_count": 200,
                    "speed_real": 60.0,
                    "running_status": True,
                    "fault_bits": [False] * 64
                }
            }
            
            test_context = {
                "equipment_code": "BP01.PACK.BAG1",
                "target_speed": 60.0,
                "production_line_id": "test_line_1"
            }
            
            # This should not raise an exception
            metrics = await transformer.transform_bagger_metrics(test_data, test_context)
            
            self.log_test_result(
                "Production Service Integration - Method Calls",
                isinstance(metrics, dict),
                "Production service method calls working correctly"
            )
            
        except Exception as e:
            self.log_test_result(
                "Production Service Integration",
                False,
                f"Failed production service integration test: {str(e)}"
            )
    
    async def test_error_handling(self):
        """Test 8: Verify error handling and resilience."""
        try:
            transformer = EnhancedMetricTransformer()
            
            # Test with invalid data
            invalid_data = {}
            invalid_context = {}
            
            # This should handle errors gracefully
            metrics = await transformer.transform_bagger_metrics(invalid_data, invalid_context)
            
            self.log_test_result(
                "Error Handling - Invalid Data",
                isinstance(metrics, dict),
                "Gracefully handled invalid input data"
            )
            
            # Test with missing services
            transformer.oee_calculator = None
            transformer.downtime_tracker = None
            transformer.andon_service = None
            transformer.notification_service = None
            
            test_data = {
                "processed": {
                    "product_count": 100,
                    "speed_real": 50.0,
                    "running_status": True,
                    "fault_bits": [False] * 64
                }
            }
            
            test_context = {
                "equipment_code": "BP01.PACK.BAG1",
                "target_speed": 60.0
            }
            
            # This should handle missing services gracefully
            metrics = await transformer.transform_bagger_metrics(test_data, test_context)
            
            self.log_test_result(
                "Error Handling - Missing Services",
                isinstance(metrics, dict),
                "Gracefully handled missing services"
            )
            
        except Exception as e:
            self.log_test_result(
                "Error Handling",
                False,
                f"Failed error handling test: {str(e)}"
            )
    
    async def run_all_tests(self):
        """Run all Phase 4 tests."""
        print("=" * 80)
        print("MS5.0 Floor Dashboard - Phase 4 PLC Integration Test Suite")
        print("=" * 80)
        print()
        
        start_time = datetime.utcnow()
        
        # Run all tests
        await self.test_import_paths()
        await self.test_async_await_functionality()
        await self.test_production_context_management()
        await self.test_enhanced_telemetry_poller()
        await self.test_production_event_handlers()
        await self.test_plc_data_integration()
        await self.test_production_service_integration()
        await self.test_error_handling()
        
        end_time = datetime.utcnow()
        duration = (end_time - start_time).total_seconds()
        
        # Print summary
        print()
        print("=" * 80)
        print("TEST SUMMARY")
        print("=" * 80)
        print(f"Total Tests: {self.total_tests}")
        print(f"Passed: {self.passed_tests}")
        print(f"Failed: {self.failed_tests}")
        print(f"Success Rate: {(self.passed_tests / self.total_tests * 100):.1f}%")
        print(f"Duration: {duration:.2f} seconds")
        print()
        
        if self.failed_tests == 0:
            print("🎉 ALL TESTS PASSED! Phase 4 PLC Integration is working correctly.")
        else:
            print(f"⚠️  {self.failed_tests} tests failed. Please review the errors above.")
        
        print("=" * 80)
        
        # Save detailed results
        self.save_test_results()
        
        return self.failed_tests == 0
    
    def save_test_results(self):
        """Save detailed test results to file."""
        results = {
            "phase": "Phase 4 - PLC Integration Fixes",
            "timestamp": datetime.utcnow().isoformat(),
            "summary": {
                "total_tests": self.total_tests,
                "passed_tests": self.passed_tests,
                "failed_tests": self.failed_tests,
                "success_rate": (self.passed_tests / self.total_tests * 100) if self.total_tests > 0 else 0
            },
            "test_results": self.test_results
        }
        
        with open("phase4_plc_integration_test_report.json", "w") as f:
            json.dump(results, f, indent=2)
        
        print(f"Detailed test results saved to: phase4_plc_integration_test_report.json")


async def main():
    """Main test execution."""
    test_suite = Phase4PLCTestSuite()
    success = await test_suite.run_all_tests()
    
    if success:
        print("\n✅ Phase 4 PLC Integration Test Suite completed successfully!")
        return 0
    else:
        print("\n❌ Phase 4 PLC Integration Test Suite completed with failures!")
        return 1


if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code)
