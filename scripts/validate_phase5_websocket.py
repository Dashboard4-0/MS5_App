#!/usr/bin/env python3
"""
MS5.0 Floor Dashboard - Phase 5 WebSocket Validation Script

Comprehensive validation script for Phase 5 WebSocket implementation.
This script validates all requirements and ensures production readiness.

Architected for cosmic scale operations - the nervous system of a starship.

Usage:
    python scripts/validate_phase5_websocket.py [--verbose] [--performance] [--integration]
"""

import asyncio
import sys
import os
import argparse
import json
from datetime import datetime
from typing import Dict, Any, List

# Add backend to path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'backend'))

from tests.websocket.test_websocket_validation import WebSocketValidationSuite
from tests.websocket.test_websocket_integration import WebSocketIntegrationTestSuite
from tests.websocket.test_websocket_performance import WebSocketPerformanceBenchmark


class Phase5WebSocketValidator:
    """
    Comprehensive Phase 5 WebSocket validation orchestrator.
    
    Coordinates all validation tests and provides a unified report
    on the readiness of the WebSocket implementation.
    """
    
    def __init__(self, verbose: bool = False):
        self.verbose = verbose
        self.validation_results = {}
        self.start_time = None
        self.end_time = None
    
    def log(self, message: str, level: str = "INFO"):
        """Log message with timestamp and level."""
        if self.verbose or level in ["ERROR", "CRITICAL"]:
            timestamp = datetime.now().strftime("%H:%M:%S")
            print(f"[{timestamp}] {level}: {message}")
    
    async def run_validation_suite(self) -> Dict[str, Any]:
        """Run the comprehensive validation suite."""
        self.start_time = datetime.now()
        self.log("Starting Phase 5 WebSocket Validation Suite", "INFO")
        self.log("=" * 60, "INFO")
        
        try:
            # Run validation tests
            self.log("Running WebSocket validation tests...", "INFO")
            validator = WebSocketValidationSuite()
            validation_results = await validator.run_all_validations()
            self.validation_results["validation"] = validation_results
            
            self.log(f"Validation tests completed: {validation_results['overall_score']:.1f}%", "INFO")
            
        except Exception as e:
            self.log(f"Validation tests failed: {e}", "ERROR")
            self.validation_results["validation"] = {"error": str(e), "overall_score": 0}
        
        return self.validation_results.get("validation", {})
    
    async def run_integration_suite(self) -> Dict[str, Any]:
        """Run the integration test suite."""
        self.log("Running WebSocket integration tests...", "INFO")
        
        try:
            integration_suite = WebSocketIntegrationTestSuite()
            integration_results = await integration_suite.run_complete_integration_test()
            self.validation_results["integration"] = integration_results
            
            self.log(f"Integration tests completed: {integration_results['success_rate']:.1f}%", "INFO")
            
        except Exception as e:
            self.log(f"Integration tests failed: {e}", "ERROR")
            self.validation_results["integration"] = {"error": str(e), "success_rate": 0}
        
        return self.validation_results.get("integration", {})
    
    async def run_performance_benchmarks(self) -> Dict[str, Any]:
        """Run the performance benchmark suite."""
        self.log("Running WebSocket performance benchmarks...", "INFO")
        
        try:
            benchmark = WebSocketPerformanceBenchmark()
            performance_results = await benchmark.run_complete_benchmark_suite()
            self.validation_results["performance"] = performance_results
            
            self.log(f"Performance benchmarks completed: {performance_results['overall_rating']}", "INFO")
            
        except Exception as e:
            self.log(f"Performance benchmarks failed: {e}", "ERROR")
            self.validation_results["performance"] = {"error": str(e), "overall_rating": "FAILED"}
        
        return self.validation_results.get("performance", {})
    
    async def run_complete_validation(self, include_performance: bool = False, include_integration: bool = True) -> Dict[str, Any]:
        """Run complete validation suite."""
        self.log("🚀 Starting Complete Phase 5 WebSocket Validation", "INFO")
        self.log("=" * 60, "INFO")
        
        # Always run validation tests
        await self.run_validation_suite()
        
        # Conditionally run integration tests
        if include_integration:
            await self.run_integration_suite()
        
        # Conditionally run performance benchmarks
        if include_performance:
            await self.run_performance_benchmarks()
        
        self.end_time = datetime.now()
        
        # Generate final report
        return self.generate_final_report()
    
    def generate_final_report(self) -> Dict[str, Any]:
        """Generate comprehensive final validation report."""
        self.log("\n📊 Phase 5 WebSocket Validation - Final Report", "INFO")
        self.log("=" * 60, "INFO")
        
        # Calculate overall metrics
        total_duration = (self.end_time - self.start_time).total_seconds()
        
        # Validation test results
        validation_score = 0
        validation_status = "FAILED"
        if "validation" in self.validation_results and "error" not in self.validation_results["validation"]:
            validation_score = self.validation_results["validation"].get("overall_score", 0)
            validation_status = "PASS" if validation_score >= 80 else "FAIL"
        
        # Integration test results
        integration_score = 0
        integration_status = "FAILED"
        if "integration" in self.validation_results and "error" not in self.validation_results["integration"]:
            integration_score = self.validation_results["integration"].get("success_rate", 0)
            integration_status = "PASS" if integration_score >= 80 else "FAIL"
        
        # Performance benchmark results
        performance_rating = "FAILED"
        performance_status = "FAILED"
        if "performance" in self.validation_results and "error" not in self.validation_results["performance"]:
            performance_rating = self.validation_results["performance"].get("overall_rating", "FAILED")
            performance_status = "PASS" if performance_rating in ["EXCELLENT", "GOOD"] else "FAIL"
        
        # Calculate overall readiness score
        scores = []
        if validation_score > 0:
            scores.append(validation_score)
        if integration_score > 0:
            scores.append(integration_score)
        if performance_rating in ["EXCELLENT", "GOOD"]:
            scores.append(90 if performance_rating == "EXCELLENT" else 80)
        elif performance_rating == "FAIR":
            scores.append(70)
        elif performance_rating != "FAILED":
            scores.append(60)
        
        overall_readiness = statistics.mean(scores) if scores else 0
        
        # Determine readiness status
        if overall_readiness >= 90:
            readiness_status = "✅ PRODUCTION READY"
            readiness_color = "GREEN"
        elif overall_readiness >= 80:
            readiness_status = "✅ READY WITH MINOR ISSUES"
            readiness_color = "YELLOW"
        elif overall_readiness >= 70:
            readiness_status = "⚠️ NEEDS ATTENTION"
            readiness_color = "ORANGE"
        elif overall_readiness >= 60:
            readiness_status = "⚠️ SIGNIFICANT ISSUES"
            readiness_color = "RED"
        else:
            readiness_status = "❌ NOT READY FOR PRODUCTION"
            readiness_color = "RED"
        
        # Print summary
        self.log(f"\nValidation Test Results:", "INFO")
        self.log(f"  Score: {validation_score:.1f}% - Status: {validation_status}", "INFO")
        
        if "integration" in self.validation_results:
            self.log(f"\nIntegration Test Results:", "INFO")
            self.log(f"  Score: {integration_score:.1f}% - Status: {integration_status}", "INFO")
        
        if "performance" in self.validation_results:
            self.log(f"\nPerformance Benchmark Results:", "INFO")
            self.log(f"  Rating: {performance_rating} - Status: {performance_status}", "INFO")
        
        self.log(f"\nOverall Readiness Score: {overall_readiness:.1f}%", "INFO")
        self.log(f"Phase 5 Status: {readiness_status}", readiness_color)
        self.log(f"Total Validation Time: {total_duration:.1f} seconds", "INFO")
        
        # Generate recommendations
        recommendations = self.generate_recommendations()
        if recommendations:
            self.log(f"\nRecommendations:", "INFO")
            for i, rec in enumerate(recommendations, 1):
                self.log(f"  {i}. {rec}", "INFO")
        
        # Create final report
        final_report = {
            "phase": "Phase 5 - WebSocket & Real-time Features",
            "validation_timestamp": datetime.utcnow().isoformat(),
            "total_duration_seconds": total_duration,
            "overall_readiness_score": overall_readiness,
            "readiness_status": readiness_status,
            "validation_results": {
                "validation_tests": {
                    "score": validation_score,
                    "status": validation_status,
                    "details": self.validation_results.get("validation", {})
                },
                "integration_tests": {
                    "score": integration_score,
                    "status": integration_status,
                    "details": self.validation_results.get("integration", {})
                },
                "performance_benchmarks": {
                    "rating": performance_rating,
                    "status": performance_status,
                    "details": self.validation_results.get("performance", {})
                }
            },
            "recommendations": recommendations,
            "phase5_requirements_met": overall_readiness >= 80
        }
        
        return final_report
    
    def generate_recommendations(self) -> List[str]:
        """Generate recommendations based on validation results."""
        recommendations = []
        
        # Validation test recommendations
        if "validation" in self.validation_results:
            validation_details = self.validation_results["validation"]
            if "error" not in validation_details:
                if validation_details.get("overall_score", 0) < 80:
                    recommendations.append("Address validation test failures - review WebSocket implementation")
                
                # Check specific test categories
                test_results = validation_details.get("test_results", {})
                for category, tests in test_results.items():
                    failed_tests = [name for name, result in tests.items() if not result]
                    if failed_tests:
                        if category == "connection_tests":
                            recommendations.append("Fix WebSocket connection establishment and authentication issues")
                        elif category == "realtime_tests":
                            recommendations.append("Resolve real-time event broadcasting problems")
                        elif category == "recovery_tests":
                            recommendations.append("Improve connection recovery and error handling")
                        elif category == "performance_tests":
                            recommendations.append("Optimize performance under load conditions")
                        elif category == "production_tests":
                            recommendations.append("Enhance production feature integration")
        
        # Integration test recommendations
        if "integration" in self.validation_results:
            integration_details = self.validation_results["integration"]
            if "error" not in integration_details:
                if integration_details.get("success_rate", 0) < 80:
                    recommendations.append("Fix integration test failures - ensure all components work together")
        
        # Performance benchmark recommendations
        if "performance" in self.validation_results:
            performance_details = self.validation_results["performance"]
            if "error" not in performance_details:
                performance_recs = performance_details.get("recommendations", [])
                recommendations.extend(performance_recs)
        
        # General recommendations
        if not recommendations:
            recommendations.append("Phase 5 implementation appears ready for production deployment")
            recommendations.append("Consider implementing continuous monitoring and alerting")
            recommendations.append("Add automated testing to CI/CD pipeline")
        
        return recommendations
    
    def save_report(self, report: Dict[str, Any], filename: str = None):
        """Save validation report to file."""
        if filename is None:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"phase5_websocket_validation_report_{timestamp}.json"
        
        filepath = os.path.join(os.path.dirname(__file__), '..', 'documentation', 'reports', filename)
        
        # Ensure directory exists
        os.makedirs(os.path.dirname(filepath), exist_ok=True)
        
        with open(filepath, 'w') as f:
            json.dump(report, f, indent=2)
        
        self.log(f"Validation report saved to: {filepath}", "INFO")
        return filepath


async def main():
    """Main validation function."""
    parser = argparse.ArgumentParser(description="Phase 5 WebSocket Validation Script")
    parser.add_argument("--verbose", "-v", action="store_true", help="Enable verbose logging")
    parser.add_argument("--performance", "-p", action="store_true", help="Include performance benchmarks")
    parser.add_argument("--integration", "-i", action="store_true", default=True, help="Include integration tests")
    parser.add_argument("--no-integration", dest="integration", action="store_false", help="Skip integration tests")
    parser.add_argument("--save-report", "-s", action="store_true", help="Save validation report to file")
    
    args = parser.parse_args()
    
    # Create validator
    validator = Phase5WebSocketValidator(verbose=args.verbose)
    
    try:
        # Run validation
        report = await validator.run_complete_validation(
            include_performance=args.performance,
            include_integration=args.integration
        )
        
        # Save report if requested
        if args.save_report:
            validator.save_report(report)
        
        # Exit with appropriate code
        if report["phase5_requirements_met"]:
            print(f"\n🎯 Phase 5 WebSocket implementation is ready for production!")
            sys.exit(0)
        else:
            print(f"\n⚠️ Phase 5 WebSocket implementation needs attention before production deployment.")
            sys.exit(1)
    
    except KeyboardInterrupt:
        print(f"\n⏹️ Validation interrupted by user.")
        sys.exit(130)
    except Exception as e:
        print(f"\n❌ Validation failed with error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    # Import statistics for mean calculation
    import statistics
    
    # Run validation
    asyncio.run(main())
