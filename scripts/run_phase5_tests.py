#!/usr/bin/env python3
"""
MS5.0 Floor Dashboard - Phase 5 Test Runner

Enterprise-grade test runner for cosmic scale operations.
The nervous system of a starship - built for reliability and performance.

This script provides comprehensive testing capabilities for Phase 5:
- WebSocket connection testing
- Real-time data update testing
- Connection recovery testing
- Performance load testing
- Error handling testing
- Integration testing
"""

import asyncio
import json
import sys
import argparse
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Any, Optional
import structlog

# Add the project root to the Python path
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

from tests.phase_tests.test_phase5_validation import (
    phase5_validation_framework,
    run_phase5_validation,
    get_validation_framework
)

logger = structlog.get_logger()


class Phase5TestRunner:
    """
    Enterprise-grade test runner for Phase 5 WebSocket and real-time features.
    
    This runner provides comprehensive testing capabilities including:
    - Automated test execution
    - Performance monitoring
    - Result reporting
    - CI/CD integration
    - Detailed logging
    """
    
    def __init__(self, config: Optional[Dict[str, Any]] = None):
        self.config = config or {}
        self.results: Optional[Dict[str, Any]] = None
        self.start_time: Optional[datetime] = None
        self.end_time: Optional[datetime] = None
        
        # Setup logging
        self._setup_logging()
        
        logger.info("Phase 5 test runner initialized")
    
    def _setup_logging(self):
        """Setup structured logging for the test runner."""
        structlog.configure(
            processors=[
                structlog.stdlib.filter_by_level,
                structlog.stdlib.add_logger_name,
                structlog.stdlib.add_log_level,
                structlog.stdlib.PositionalArgumentsFormatter(),
                structlog.processors.TimeStamper(fmt="iso"),
                structlog.processors.StackInfoRenderer(),
                structlog.processors.format_exc_info,
                structlog.processors.UnicodeDecoder(),
                structlog.processors.JSONRenderer()
            ],
            context_class=dict,
            logger_factory=structlog.stdlib.LoggerFactory(),
            wrapper_class=structlog.stdlib.BoundLogger,
            cache_logger_on_first_use=True,
        )
    
    async def run_tests(self, test_suite: str = "all") -> Dict[str, Any]:
        """
        Run Phase 5 tests.
        
        Args:
            test_suite: Test suite to run ("all", "websocket", "realtime", "performance", "integration")
        
        Returns:
            Test results
        """
        self.start_time = datetime.now(timezone.utc)
        logger.info("Starting Phase 5 test execution", test_suite=test_suite)
        
        try:
            if test_suite == "all":
                self.results = await run_phase5_validation()
            else:
                # Run specific test suite
                framework = get_validation_framework()
                if test_suite == "websocket":
                    self.results = await framework._run_websocket_connection_tests()
                elif test_suite == "realtime":
                    self.results = await framework._run_real_time_data_tests()
                elif test_suite == "performance":
                    self.results = await framework._run_performance_load_tests()
                elif test_suite == "integration":
                    self.results = await framework._run_integration_tests()
                else:
                    raise ValueError(f"Unknown test suite: {test_suite}")
            
            self.end_time = datetime.now(timezone.utc)
            
            # Log results
            self._log_results()
            
            # Generate report
            self._generate_report()
            
            logger.info("Phase 5 test execution completed", 
                       duration=(self.end_time - self.start_time).total_seconds())
            
            return self.results
            
        except Exception as e:
            logger.error("Error in Phase 5 test execution", error=str(e))
            self.end_time = datetime.now(timezone.utc)
            raise
    
    def _log_results(self):
        """Log test results."""
        if not self.results:
            return
        
        if isinstance(self.results, dict) and "overall_status" in self.results:
            # Comprehensive validation results
            logger.info("Test execution completed",
                       overall_status=self.results["overall_status"],
                       total_tests=self.results.get("total_tests", 0),
                       passed_tests=self.results.get("passed_tests", 0),
                       failed_tests=self.results.get("failed_tests", 0),
                       duration=self.results.get("total_duration", 0))
        else:
            # Single test suite results
            logger.info("Test suite completed",
                       suite_name=getattr(self.results, "suite_name", "unknown"),
                       passed_tests=getattr(self.results, "passed_tests", 0),
                       failed_tests=getattr(self.results, "failed_tests", 0),
                       duration=getattr(self.results, "total_duration", 0))
    
    def _generate_report(self):
        """Generate test report."""
        if not self.results:
            return
        
        report = {
            "test_run": {
                "start_time": self.start_time.isoformat() if self.start_time else None,
                "end_time": self.end_time.isoformat() if self.end_time else None,
                "duration": (self.end_time - self.start_time).total_seconds() if self.start_time and self.end_time else 0
            },
            "results": self.results,
            "summary": self._generate_summary()
        }
        
        # Save report to file
        report_file = Path("test_reports") / f"phase5_test_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        report_file.parent.mkdir(exist_ok=True)
        
        with open(report_file, "w") as f:
            json.dump(report, f, indent=2, default=str)
        
        logger.info("Test report generated", report_file=str(report_file))
    
    def _generate_summary(self) -> Dict[str, Any]:
        """Generate test summary."""
        if not self.results:
            return {}
        
        if isinstance(self.results, dict) and "overall_status" in self.results:
            # Comprehensive validation results
            return {
                "status": self.results["overall_status"],
                "total_tests": self.results.get("total_tests", 0),
                "passed_tests": self.results.get("passed_tests", 0),
                "failed_tests": self.results.get("failed_tests", 0),
                "success_rate": (
                    self.results.get("passed_tests", 0) / self.results.get("total_tests", 1)
                    if self.results.get("total_tests", 0) > 0 else 0
                ),
                "performance_summary": self.results.get("performance_summary", {}),
                "recommendations": self.results.get("recommendations", [])
            }
        else:
            # Single test suite results
            return {
                "suite_name": getattr(self.results, "suite_name", "unknown"),
                "passed_tests": getattr(self.results, "passed_tests", 0),
                "failed_tests": getattr(self.results, "failed_tests", 0),
                "total_tests": getattr(self.results, "passed_tests", 0) + getattr(self.results, "failed_tests", 0),
                "success_rate": (
                    getattr(self.results, "passed_tests", 0) / 
                    (getattr(self.results, "passed_tests", 0) + getattr(self.results, "failed_tests", 1))
                    if (getattr(self.results, "passed_tests", 0) + getattr(self.results, "failed_tests", 0)) > 0 else 0
                )
            }


async def main():
    """Main entry point for the test runner."""
    parser = argparse.ArgumentParser(description="Phase 5 Test Runner")
    parser.add_argument("--suite", choices=["all", "websocket", "realtime", "performance", "integration"], 
                       default="all", help="Test suite to run")
    parser.add_argument("--config", help="Path to test configuration file")
    parser.add_argument("--verbose", "-v", action="store_true", help="Enable verbose logging")
    parser.add_argument("--output", help="Output file for test results")
    
    args = parser.parse_args()
    
    # Load configuration if provided
    config = {}
    if args.config:
        with open(args.config, "r") as f:
            config = json.load(f)
    
    # Create test runner
    runner = Phase5TestRunner(config)
    
    try:
        # Run tests
        results = await runner.run_tests(args.suite)
        
        # Print summary
        summary = runner._generate_summary()
        print("\n" + "="*80)
        print("PHASE 5 TEST EXECUTION SUMMARY")
        print("="*80)
        print(f"Status: {summary.get('status', 'unknown')}")
        print(f"Total Tests: {summary.get('total_tests', 0)}")
        print(f"Passed: {summary.get('passed_tests', 0)}")
        print(f"Failed: {summary.get('failed_tests', 0)}")
        print(f"Success Rate: {summary.get('success_rate', 0):.2%}")
        
        if "performance_summary" in summary:
            perf = summary["performance_summary"]
            print(f"\nPerformance Metrics:")
            print(f"  Average Connection Time: {perf.get('average_connection_time', 0):.3f}s")
            print(f"  Average Message Latency: {perf.get('average_message_latency', 0):.3f}s")
            print(f"  Error Rate: {perf.get('error_rate', 0):.2%}")
        
        if "recommendations" in summary and summary["recommendations"]:
            print(f"\nRecommendations:")
            for rec in summary["recommendations"]:
                print(f"  - {rec}")
        
        print("="*80)
        
        # Exit with appropriate code
        if summary.get("failed_tests", 0) > 0:
            sys.exit(1)
        else:
            sys.exit(0)
            
    except Exception as e:
        logger.error("Test execution failed", error=str(e))
        print(f"Test execution failed: {e}")
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
