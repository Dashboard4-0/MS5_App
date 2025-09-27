"""
MS5.0 Floor Dashboard - Phase 5 Load Testing Suite

This module provides comprehensive load testing for the MS5.0 Floor Dashboard
system, including stress testing, performance benchmarking, and scalability
validation under high-load conditions.
"""

import asyncio
import json
import time
import statistics
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timedelta
from typing import Dict, Any, List
import uuid

from fastapi.testclient import TestClient
import structlog

from backend.app.main import app

logger = structlog.get_logger()

# Test client
client = TestClient(app)

# Load testing configuration
LOAD_TEST_CONFIG = {
    "light_load": {
        "api_requests": 50,
        "websocket_connections": 20,
        "duration_seconds": 30,
        "max_workers": 10
    },
    "medium_load": {
        "api_requests": 200,
        "websocket_connections": 50,
        "duration_seconds": 60,
        "max_workers": 20
    },
    "heavy_load": {
        "api_requests": 500,
        "websocket_connections": 100,
        "duration_seconds": 120,
        "max_workers": 30
    },
    "stress_load": {
        "api_requests": 1000,
        "websocket_connections": 200,
        "duration_seconds": 180,
        "max_workers": 50
    }
}

# Performance thresholds
PERFORMANCE_THRESHOLDS = {
    "api_response_time_p95_ms": 500,
    "api_response_time_p99_ms": 1000,
    "websocket_connection_time_ms": 2000,
    "websocket_message_latency_ms": 100,
    "memory_usage_mb": 1000,
    "cpu_usage_percent": 90,
    "error_rate_percent": 5,
    "throughput_requests_per_second": 50
}


class LoadTestResults:
    """Container for load test results."""
    
    def __init__(self):
        self.test_name = ""
        self.start_time = None
        self.end_time = None
        self.total_requests = 0
        self.successful_requests = 0
        self.failed_requests = 0
        self.response_times = []
        self.error_types = {}
        self.throughput = 0.0
        self.peak_memory_mb = 0.0
        self.peak_cpu_percent = 0.0
        
    def calculate_metrics(self):
        """Calculate performance metrics from collected data."""
        if not self.response_times:
            return
            
        self.successful_requests = len(self.response_times)
        self.failed_requests = self.total_requests - self.successful_requests
        
        if self.start_time and self.end_time:
            duration = (self.end_time - self.start_time).total_seconds()
            self.throughput = self.total_requests / duration if duration > 0 else 0
        
        # Calculate percentiles
        sorted_times = sorted(self.response_times)
        self.p50_response_time = sorted_times[int(0.5 * len(sorted_times))] if sorted_times else 0
        self.p95_response_time = sorted_times[int(0.95 * len(sorted_times))] if sorted_times else 0
        self.p99_response_time = sorted_times[int(0.99 * len(sorted_times))] if sorted_times else 0
        
        self.avg_response_time = statistics.mean(sorted_times) if sorted_times else 0
        self.min_response_time = min(sorted_times) if sorted_times else 0
        self.max_response_time = max(sorted_times) if sorted_times else 0
    
    def is_performance_acceptable(self) -> bool:
        """Check if performance meets thresholds."""
        return (
            self.p95_response_time < PERFORMANCE_THRESHOLDS["api_response_time_p95_ms"] and
            self.p99_response_time < PERFORMANCE_THRESHOLDS["api_response_time_p99_ms"] and
            self.get_error_rate() < PERFORMANCE_THRESHOLDS["error_rate_percent"] and
            self.throughput > PERFORMANCE_THRESHOLDS["throughput_requests_per_second"]
        )
    
    def get_error_rate(self) -> float:
        """Calculate error rate percentage."""
        if self.total_requests == 0:
            return 0.0
        return (self.failed_requests / self.total_requests) * 100.0
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert results to dictionary."""
        return {
            "test_name": self.test_name,
            "duration_seconds": (self.end_time - self.start_time).total_seconds() if self.start_time and self.end_time else 0,
            "total_requests": self.total_requests,
            "successful_requests": self.successful_requests,
            "failed_requests": self.failed_requests,
            "error_rate_percent": self.get_error_rate(),
            "throughput_rps": self.throughput,
            "avg_response_time_ms": self.avg_response_time,
            "p50_response_time_ms": self.p50_response_time,
            "p95_response_time_ms": self.p95_response_time,
            "p99_response_time_ms": self.p99_response_time,
            "min_response_time_ms": self.min_response_time,
            "max_response_time_ms": self.max_response_time,
            "peak_memory_mb": self.peak_memory_mb,
            "peak_cpu_percent": self.peak_cpu_percent,
            "error_types": self.error_types,
            "performance_acceptable": self.is_performance_acceptable()
        }


class APILoadTester:
    """API load testing class."""
    
    def __init__(self, test_config: Dict[str, Any]):
        self.config = test_config
        self.results = LoadTestResults()
        self.results.test_name = f"API Load Test - {test_config.get('name', 'Unknown')}"
    
    def run_load_test(self) -> LoadTestResults:
        """Run API load test."""
        logger.info(f"Starting API load test: {self.results.test_name}")
        
        self.results.start_time = datetime.now()
        
        # Test endpoints
        endpoints = [
            f"/api/v1/enhanced/equipment/BP01.PACK.BAG1/production-status",
            f"/api/v1/enhanced/lines/{str(uuid.uuid4())}/real-time-oee",
            f"/api/v1/enhanced/equipment/BP01.PACK.BAG1/job-progress",
            f"/api/v1/enhanced/lines/{str(uuid.uuid4())}/production-metrics",
            f"/api/v1/enhanced/equipment/BP01.PACK.BAG1/downtime-status"
        ]
        
        def make_request(endpoint):
            """Make a single API request."""
            start_time = time.time()
            try:
                response = client.get(endpoint)
                end_time = time.time()
                
                response_time = (end_time - start_time) * 1000
                
                if response.status_code == 200:
                    return response_time, "success"
                else:
                    error_type = f"http_{response.status_code}"
                    return response_time, error_type
                    
            except Exception as e:
                end_time = time.time()
                response_time = (end_time - start_time) * 1000
                error_type = f"exception_{type(e).__name__}"
                return response_time, error_type
        
        # Run concurrent requests
        with ThreadPoolExecutor(max_workers=self.config["max_workers"]) as executor:
            # Submit all requests
            futures = []
            for _ in range(self.config["api_requests"]):
                endpoint = endpoints[_ % len(endpoints)]
                futures.append(executor.submit(make_request, endpoint))
            
            # Collect results
            for future in as_completed(futures):
                response_time, result = future.result()
                
                self.results.total_requests += 1
                
                if result == "success":
                    self.results.response_times.append(response_time)
                else:
                    self.results.failed_requests += 1
                    if result in self.results.error_types:
                        self.results.error_types[result] += 1
                    else:
                        self.results.error_types[result] = 1
        
        self.results.end_time = datetime.now()
        self.results.calculate_metrics()
        
        logger.info(f"Completed API load test: {self.results.test_name}")
        logger.info(f"Results: {self.results.to_dict()}")
        
        return self.results


class WebSocketLoadTester:
    """WebSocket load testing class."""
    
    def __init__(self, test_config: Dict[str, Any]):
        self.config = test_config
        self.results = LoadTestResults()
        self.results.test_name = f"WebSocket Load Test - {test_config.get('name', 'Unknown')}"
    
    def run_load_test(self) -> LoadTestResults:
        """Run WebSocket load test."""
        logger.info(f"Starting WebSocket load test: {self.results.test_name}")
        
        self.results.start_time = datetime.now()
        
        def create_websocket_connection(connection_id):
            """Create a WebSocket connection and test messaging."""
            start_time = time.time()
            try:
                with client.websocket_connect(
                    f"/api/v1/ws/production?line_id={str(uuid.uuid4())}&user_id=load_test_{connection_id}"
                ) as websocket:
                    connection_time = (time.time() - start_time) * 1000
                    
                    # Test message exchange
                    message_times = []
                    for _ in range(5):  # Send 5 messages per connection
                        msg_start = time.time()
                        websocket.send_json({"type": "ping"})
                        data = websocket.receive_json()
                        msg_time = (time.time() - msg_start) * 1000
                        message_times.append(msg_time)
                        
                        if data.get("type") != "pong":
                            return connection_time, "invalid_response", message_times
                    
                    return connection_time, "success", message_times
                    
            except Exception as e:
                end_time = time.time()
                connection_time = (end_time - start_time) * 1000
                error_type = f"exception_{type(e).__name__}"
                return connection_time, error_type, []
        
        # Run concurrent WebSocket connections
        with ThreadPoolExecutor(max_workers=self.config["max_workers"]) as executor:
            futures = []
            for i in range(self.config["websocket_connections"]):
                futures.append(executor.submit(create_websocket_connection, i))
            
            connection_times = []
            message_times = []
            
            for future in as_completed(futures):
                connection_time, result, msg_times = future.result()
                
                self.results.total_requests += 1
                
                if result == "success":
                    connection_times.append(connection_time)
                    message_times.extend(msg_times)
                else:
                    self.results.failed_requests += 1
                    if result in self.results.error_types:
                        self.results.error_types[result] += 1
                    else:
                        self.results.error_types[result] = 1
            
            # Use connection times as response times for WebSocket
            self.results.response_times = connection_times
            self.results.websocket_message_times = message_times
        
        self.results.end_time = datetime.now()
        self.results.calculate_metrics()
        
        logger.info(f"Completed WebSocket load test: {self.results.test_name}")
        logger.info(f"Results: {self.results.to_dict()}")
        
        return self.results


class MixedWorkloadTester:
    """Mixed workload testing class."""
    
    def __init__(self, test_config: Dict[str, Any]):
        self.config = test_config
        self.results = LoadTestResults()
        self.results.test_name = f"Mixed Workload Test - {test_config.get('name', 'Unknown')}"
    
    def run_load_test(self) -> LoadTestResults:
        """Run mixed workload test."""
        logger.info(f"Starting mixed workload test: {self.results.test_name}")
        
        self.results.start_time = datetime.now()
        
        # API endpoints
        api_endpoints = [
            f"/api/v1/enhanced/equipment/BP01.PACK.BAG1/production-status",
            f"/api/v1/enhanced/lines/{str(uuid.uuid4())}/real-time-oee",
            f"/api/v1/enhanced/equipment/BP01.PACK.BAG1/job-progress"
        ]
        
        def make_api_request(endpoint):
            """Make API request."""
            start_time = time.time()
            try:
                response = client.get(endpoint)
                end_time = time.time()
                response_time = (end_time - start_time) * 1000
                
                if response.status_code == 200:
                    return response_time, "api_success"
                else:
                    return response_time, f"api_error_{response.status_code}"
                    
            except Exception as e:
                end_time = time.time()
                response_time = (end_time - start_time) * 1000
                return response_time, f"api_exception_{type(e).__name__}"
        
        def create_websocket_connection(connection_id):
            """Create WebSocket connection."""
            start_time = time.time()
            try:
                with client.websocket_connect(
                    f"/api/v1/ws/production?line_id={str(uuid.uuid4())}&user_id=mixed_test_{connection_id}"
                ) as websocket:
                    connection_time = (time.time() - start_time) * 1000
                    
                    # Send a few messages
                    for _ in range(3):
                        websocket.send_json({"type": "ping"})
                        data = websocket.receive_json()
                        if data.get("type") != "pong":
                            return connection_time, "ws_invalid_response"
                    
                    return connection_time, "ws_success"
                    
            except Exception as e:
                end_time = time.time()
                connection_time = (end_time - start_time) * 1000
                return connection_time, f"ws_exception_{type(e).__name__}"
        
        # Run mixed workload
        with ThreadPoolExecutor(max_workers=self.config["max_workers"]) as executor:
            futures = []
            
            # Submit API requests
            for _ in range(self.config["api_requests"]):
                endpoint = api_endpoints[_ % len(api_endpoints)]
                futures.append(executor.submit(make_api_request, endpoint))
            
            # Submit WebSocket connections
            for i in range(self.config["websocket_connections"]):
                futures.append(executor.submit(create_websocket_connection, i))
            
            # Collect results
            for future in as_completed(futures):
                response_time, result = future.result()
                
                self.results.total_requests += 1
                
                if result in ["api_success", "ws_success"]:
                    self.results.response_times.append(response_time)
                else:
                    self.results.failed_requests += 1
                    if result in self.results.error_types:
                        self.results.error_types[result] += 1
                    else:
                        self.results.error_types[result] = 1
        
        self.results.end_time = datetime.now()
        self.results.calculate_metrics()
        
        logger.info(f"Completed mixed workload test: {self.results.test_name}")
        logger.info(f"Results: {self.results.to_dict()}")
        
        return self.results


class StressTester:
    """Stress testing class for system limits."""
    
    def __init__(self):
        self.results = []
    
    def run_stress_test(self) -> List[LoadTestResults]:
        """Run comprehensive stress test."""
        logger.info("Starting comprehensive stress test")
        
        stress_configs = [
            {"name": "Light Load", **LOAD_TEST_CONFIG["light_load"]},
            {"name": "Medium Load", **LOAD_TEST_CONFIG["medium_load"]},
            {"name": "Heavy Load", **LOAD_TEST_CONFIG["heavy_load"]},
            {"name": "Stress Load", **LOAD_TEST_CONFIG["stress_load"]}
        ]
        
        for config in stress_configs:
            logger.info(f"Running stress test: {config['name']}")
            
            # API stress test
            api_tester = APILoadTester(config)
            api_results = api_tester.run_load_test()
            self.results.append(api_results)
            
            # WebSocket stress test
            ws_tester = WebSocketLoadTester(config)
            ws_results = ws_tester.run_load_test()
            self.results.append(ws_results)
            
            # Mixed workload stress test
            mixed_tester = MixedWorkloadTester(config)
            mixed_results = mixed_tester.run_load_test()
            self.results.append(mixed_results)
            
            # Wait between tests
            time.sleep(5)
        
        logger.info("Completed comprehensive stress test")
        return self.results
    
    def generate_stress_report(self) -> Dict[str, Any]:
        """Generate comprehensive stress test report."""
        report = {
            "test_summary": {
                "total_tests": len(self.results),
                "passed_tests": sum(1 for r in self.results if r.is_performance_acceptable()),
                "failed_tests": sum(1 for r in self.results if not r.is_performance_acceptable()),
                "overall_pass_rate": 0.0
            },
            "performance_summary": {
                "avg_response_time_ms": 0.0,
                "max_response_time_ms": 0.0,
                "avg_throughput_rps": 0.0,
                "max_throughput_rps": 0.0,
                "avg_error_rate_percent": 0.0,
                "max_error_rate_percent": 0.0
            },
            "test_results": [],
            "recommendations": []
        }
        
        if self.results:
            # Calculate summary metrics
            response_times = [r.avg_response_time for r in self.results]
            throughputs = [r.throughput for r in self.results]
            error_rates = [r.get_error_rate() for r in self.results]
            
            report["performance_summary"]["avg_response_time_ms"] = statistics.mean(response_times)
            report["performance_summary"]["max_response_time_ms"] = max(response_times)
            report["performance_summary"]["avg_throughput_rps"] = statistics.mean(throughputs)
            report["performance_summary"]["max_throughput_rps"] = max(throughputs)
            report["performance_summary"]["avg_error_rate_percent"] = statistics.mean(error_rates)
            report["performance_summary"]["max_error_rate_percent"] = max(error_rates)
            
            # Calculate pass rate
            passed = sum(1 for r in self.results if r.is_performance_acceptable())
            report["test_summary"]["overall_pass_rate"] = (passed / len(self.results)) * 100
            
            # Add individual test results
            for result in self.results:
                report["test_results"].append(result.to_dict())
            
            # Generate recommendations
            if report["performance_summary"]["avg_response_time_ms"] > PERFORMANCE_THRESHOLDS["api_response_time_p95_ms"]:
                report["recommendations"].append("Consider optimizing database queries and API response times")
            
            if report["performance_summary"]["avg_error_rate_percent"] > PERFORMANCE_THRESHOLDS["error_rate_percent"]:
                report["recommendations"].append("Investigate and fix error conditions causing high error rates")
            
            if report["performance_summary"]["avg_throughput_rps"] < PERFORMANCE_THRESHOLDS["throughput_requests_per_second"]:
                report["recommendations"].append("Consider scaling horizontally or optimizing system performance")
        
        return report


class LoadTestSuite:
    """Main load test suite."""
    
    def __init__(self):
        self.stress_tester = StressTester()
        self.results = []
    
    def run_all_tests(self) -> Dict[str, Any]:
        """Run all load tests."""
        logger.info("Starting comprehensive load test suite")
        
        # Run stress tests
        stress_results = self.stress_tester.run_stress_test()
        self.results.extend(stress_results)
        
        # Generate final report
        report = self.stress_tester.generate_stress_report()
        
        logger.info("Completed comprehensive load test suite")
        logger.info(f"Final report: {json.dumps(report, indent=2)}")
        
        return report
    
    def save_results(self, filename: str = "load_test_results.json"):
        """Save test results to file."""
        report = self.stress_tester.generate_stress_report()
        
        with open(filename, 'w') as f:
            json.dump(report, f, indent=2, default=str)
        
        logger.info(f"Load test results saved to {filename}")


def main():
    """Main function to run load tests."""
    logger.info("Starting MS5.0 Floor Dashboard Load Testing")
    
    # Create and run load test suite
    test_suite = LoadTestSuite()
    results = test_suite.run_all_tests()
    
    # Save results
    test_suite.save_results()
    
    # Print summary
    print("\n" + "="*80)
    print("LOAD TEST SUMMARY")
    print("="*80)
    print(f"Total Tests: {results['test_summary']['total_tests']}")
    print(f"Passed Tests: {results['test_summary']['passed_tests']}")
    print(f"Failed Tests: {results['test_summary']['failed_tests']}")
    print(f"Pass Rate: {results['test_summary']['overall_pass_rate']:.1f}%")
    print(f"Average Response Time: {results['performance_summary']['avg_response_time_ms']:.1f}ms")
    print(f"Average Throughput: {results['performance_summary']['avg_throughput_rps']:.1f} RPS")
    print(f"Average Error Rate: {results['performance_summary']['avg_error_rate_percent']:.1f}%")
    
    if results['recommendations']:
        print("\nRECOMMENDATIONS:")
        for i, rec in enumerate(results['recommendations'], 1):
            print(f"{i}. {rec}")
    
    print("="*80)
    
    # Return exit code based on pass rate
    if results['test_summary']['overall_pass_rate'] >= 80:
        return 0  # Success
    else:
        return 1  # Failure


if __name__ == "__main__":
    exit(main())
