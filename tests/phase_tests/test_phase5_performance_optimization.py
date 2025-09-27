"""
MS5.0 Floor Dashboard - Phase 5 Performance Optimization Suite

This module provides comprehensive performance optimization testing and validation
for the MS5.0 Floor Dashboard system, including database query optimization,
API response time optimization, WebSocket performance tuning, and memory usage optimization.
"""

import asyncio
import json
import time
import statistics
import psutil
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional
import uuid

from fastapi.testclient import TestClient
import structlog

from backend.app.main import app

logger = structlog.get_logger()

# Test client
client = TestClient(app)

# Performance optimization targets
OPTIMIZATION_TARGETS = {
    "api_response_time_ms": 200,
    "database_query_time_ms": 50,
    "websocket_message_latency_ms": 30,
    "memory_usage_mb": 400,
    "cpu_usage_percent": 70,
    "cache_hit_rate_percent": 90,
    "connection_pool_utilization_percent": 80
}

# Performance monitoring thresholds
MONITORING_THRESHOLDS = {
    "memory_growth_rate_mb_per_minute": 10,
    "cpu_spike_duration_seconds": 5,
    "response_time_degradation_percent": 20,
    "error_rate_increase_percent": 5
}


class PerformanceMonitor:
    """System performance monitoring class."""
    
    def __init__(self):
        self.monitoring_active = False
        self.monitoring_thread = None
        self.metrics = []
        self.start_time = None
    
    def start_monitoring(self, duration_seconds: int = 60):
        """Start performance monitoring."""
        self.monitoring_active = True
        self.start_time = datetime.now()
        self.metrics = []
        
        self.monitoring_thread = threading.Thread(
            target=self._monitor_loop,
            args=(duration_seconds,)
        )
        self.monitoring_thread.start()
        
        logger.info(f"Started performance monitoring for {duration_seconds} seconds")
    
    def stop_monitoring(self) -> List[Dict[str, Any]]:
        """Stop performance monitoring and return metrics."""
        self.monitoring_active = False
        
        if self.monitoring_thread:
            self.monitoring_thread.join()
        
        logger.info(f"Stopped performance monitoring. Collected {len(self.metrics)} data points")
        return self.metrics
    
    def _monitor_loop(self, duration_seconds: int):
        """Main monitoring loop."""
        end_time = time.time() + duration_seconds
        
        while self.monitoring_active and time.time() < end_time:
            try:
                # Get system metrics
                cpu_percent = psutil.cpu_percent(interval=1)
                memory = psutil.virtual_memory()
                
                # Get process-specific metrics (if possible)
                process_metrics = {}
                try:
                    current_process = psutil.Process()
                    process_metrics = {
                        "process_memory_mb": current_process.memory_info().rss / 1024 / 1024,
                        "process_cpu_percent": current_process.cpu_percent()
                    }
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    pass
                
                metric = {
                    "timestamp": datetime.now(),
                    "system_cpu_percent": cpu_percent,
                    "system_memory_percent": memory.percent,
                    "system_memory_available_mb": memory.available / 1024 / 1024,
                    "system_memory_used_mb": memory.used / 1024 / 1024,
                    **process_metrics
                }
                
                self.metrics.append(metric)
                
                # Sleep for monitoring interval
                time.sleep(1)
                
            except Exception as e:
                logger.error(f"Error in monitoring loop: {e}")
                time.sleep(1)
    
    def get_performance_summary(self) -> Dict[str, Any]:
        """Get performance summary from collected metrics."""
        if not self.metrics:
            return {}
        
        cpu_values = [m["system_cpu_percent"] for m in self.metrics]
        memory_values = [m["system_memory_percent"] for m in self.metrics]
        
        # Get process metrics if available
        process_memory_values = [m.get("process_memory_mb", 0) for m in self.metrics if m.get("process_memory_mb")]
        process_cpu_values = [m.get("process_cpu_percent", 0) for m in self.metrics if m.get("process_cpu_percent")]
        
        summary = {
            "monitoring_duration_seconds": (self.metrics[-1]["timestamp"] - self.metrics[0]["timestamp"]).total_seconds(),
            "data_points": len(self.metrics),
            "system_cpu": {
                "avg_percent": statistics.mean(cpu_values),
                "max_percent": max(cpu_values),
                "min_percent": min(cpu_values),
                "p95_percent": sorted(cpu_values)[int(0.95 * len(cpu_values))] if cpu_values else 0
            },
            "system_memory": {
                "avg_percent": statistics.mean(memory_values),
                "max_percent": max(memory_values),
                "min_percent": min(memory_values),
                "avg_used_mb": statistics.mean([m["system_memory_used_mb"] for m in self.metrics])
            }
        }
        
        if process_memory_values:
            summary["process_memory"] = {
                "avg_mb": statistics.mean(process_memory_values),
                "max_mb": max(process_memory_values),
                "min_mb": min(process_memory_values),
                "growth_rate_mb_per_minute": self._calculate_growth_rate(process_memory_values)
            }
        
        if process_cpu_values:
            summary["process_cpu"] = {
                "avg_percent": statistics.mean(process_cpu_values),
                "max_percent": max(process_cpu_values),
                "min_percent": min(process_cpu_values)
            }
        
        return summary
    
    def _calculate_growth_rate(self, values: List[float]) -> float:
        """Calculate growth rate over time."""
        if len(values) < 2:
            return 0.0
        
        # Linear regression to find growth rate
        n = len(values)
        x_values = list(range(n))
        
        sum_x = sum(x_values)
        sum_y = sum(values)
        sum_xy = sum(x * y for x, y in zip(x_values, values))
        sum_x2 = sum(x * x for x in x_values)
        
        slope = (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x * sum_x)
        
        # Convert to per-minute rate (assuming 1-second intervals)
        return slope * 60


class DatabasePerformanceOptimizer:
    """Database performance optimization testing."""
    
    def __init__(self):
        self.test_results = {}
    
    def test_query_performance(self) -> Dict[str, Any]:
        """Test database query performance."""
        logger.info("Testing database query performance")
        
        # Test different types of queries that would be used in the application
        test_queries = [
            {
                "name": "equipment_status_query",
                "endpoint": "/api/v1/enhanced/equipment/BP01.PACK.BAG1/production-status",
                "description": "Equipment production status query"
            },
            {
                "name": "oee_analytics_query",
                "endpoint": f"/api/v1/enhanced/oee/lines/{str(uuid.uuid4())}/real-time-oee-analytics",
                "description": "OEE analytics query"
            },
            {
                "name": "production_metrics_query",
                "endpoint": f"/api/v1/enhanced/lines/{str(uuid.uuid4())}/production-metrics",
                "description": "Production metrics query"
            },
            {
                "name": "job_progress_query",
                "endpoint": "/api/v1/enhanced/equipment/BP01.PACK.BAG1/job-progress",
                "description": "Job progress query"
            }
        ]
        
        query_results = {}
        
        for query in test_queries:
            response_times = []
            
            # Run each query multiple times to get average performance
            for _ in range(10):
                start_time = time.time()
                response = client.get(query["endpoint"])
                end_time = time.time()
                
                response_time = (end_time - start_time) * 1000
                response_times.append(response_time)
            
            # Calculate statistics
            avg_time = statistics.mean(response_times)
            min_time = min(response_times)
            max_time = max(response_times)
            p95_time = sorted(response_times)[int(0.95 * len(response_times))]
            
            query_results[query["name"]] = {
                "description": query["description"],
                "avg_response_time_ms": avg_time,
                "min_response_time_ms": min_time,
                "max_response_time_ms": max_time,
                "p95_response_time_ms": p95_time,
                "meets_target": avg_time < OPTIMIZATION_TARGETS["database_query_time_ms"]
            }
        
        self.test_results["database_queries"] = query_results
        
        logger.info("Completed database query performance testing")
        return query_results
    
    def test_concurrent_query_performance(self) -> Dict[str, Any]:
        """Test concurrent database query performance."""
        logger.info("Testing concurrent database query performance")
        
        endpoint = "/api/v1/enhanced/equipment/BP01.PACK.BAG1/production-status"
        concurrent_requests = 20
        
        def make_request():
            start_time = time.time()
            response = client.get(endpoint)
            end_time = time.time()
            return (end_time - start_time) * 1000, response.status_code
        
        response_times = []
        status_codes = []
        
        with ThreadPoolExecutor(max_workers=concurrent_requests) as executor:
            futures = [executor.submit(make_request) for _ in range(concurrent_requests)]
            
            for future in as_completed(futures):
                response_time, status_code = future.result()
                response_times.append(response_time)
                status_codes.append(status_code)
        
        # Calculate statistics
        avg_time = statistics.mean(response_times)
        max_time = max(response_times)
        min_time = min(response_times)
        success_rate = sum(1 for code in status_codes if code == 200) / len(status_codes)
        
        concurrent_results = {
            "concurrent_requests": concurrent_requests,
            "avg_response_time_ms": avg_time,
            "max_response_time_ms": max_time,
            "min_response_time_ms": min_time,
            "success_rate": success_rate,
            "meets_target": avg_time < OPTIMIZATION_TARGETS["database_query_time_ms"] * 2
        }
        
        self.test_results["concurrent_queries"] = concurrent_results
        
        logger.info("Completed concurrent database query performance testing")
        return concurrent_results


class APIResponseOptimizer:
    """API response time optimization testing."""
    
    def __init__(self):
        self.test_results = {}
    
    def test_api_response_times(self) -> Dict[str, Any]:
        """Test API response time optimization."""
        logger.info("Testing API response time optimization")
        
        # Test all major API endpoints
        endpoints = [
            {
                "name": "equipment_production_status",
                "url": "/api/v1/enhanced/equipment/BP01.PACK.BAG1/production-status",
                "method": "GET"
            },
            {
                "name": "real_time_oee",
                "url": f"/api/v1/enhanced/lines/{str(uuid.uuid4())}/real-time-oee",
                "method": "GET"
            },
            {
                "name": "job_progress",
                "url": "/api/v1/enhanced/equipment/BP01.PACK.BAG1/job-progress",
                "method": "GET"
            },
            {
                "name": "production_metrics",
                "url": f"/api/v1/enhanced/lines/{str(uuid.uuid4())}/production-metrics",
                "method": "GET"
            },
            {
                "name": "downtime_status",
                "url": "/api/v1/enhanced/equipment/BP01.PACK.BAG1/downtime-status",
                "method": "GET"
            },
            {
                "name": "andon_status",
                "url": f"/api/v1/enhanced/lines/{str(uuid.uuid4())}/andon-status",
                "method": "GET"
            }
        ]
        
        endpoint_results = {}
        
        for endpoint in endpoints:
            response_times = []
            
            # Test each endpoint multiple times
            for _ in range(15):
                start_time = time.time()
                
                if endpoint["method"] == "GET":
                    response = client.get(endpoint["url"])
                else:
                    response = client.post(endpoint["url"])
                
                end_time = time.time()
                response_time = (end_time - start_time) * 1000
                response_times.append(response_time)
            
            # Calculate statistics
            avg_time = statistics.mean(response_times)
            min_time = min(response_times)
            max_time = max(response_times)
            p95_time = sorted(response_times)[int(0.95 * len(response_times))]
            p99_time = sorted(response_times)[int(0.99 * len(response_times))]
            
            endpoint_results[endpoint["name"]] = {
                "endpoint": endpoint["url"],
                "avg_response_time_ms": avg_time,
                "min_response_time_ms": min_time,
                "max_response_time_ms": max_time,
                "p95_response_time_ms": p95_time,
                "p99_response_time_ms": p99_time,
                "meets_target": avg_time < OPTIMIZATION_TARGETS["api_response_time_ms"]
            }
        
        self.test_results["api_endpoints"] = endpoint_results
        
        logger.info("Completed API response time optimization testing")
        return endpoint_results
    
    def test_api_caching_effectiveness(self) -> Dict[str, Any]:
        """Test API caching effectiveness."""
        logger.info("Testing API caching effectiveness")
        
        endpoint = "/api/v1/enhanced/equipment/BP01.PACK.BAG1/production-status"
        
        # First request (cache miss)
        start_time = time.time()
        response1 = client.get(endpoint)
        first_request_time = (time.time() - start_time) * 1000
        
        # Second request (potential cache hit)
        start_time = time.time()
        response2 = client.get(endpoint)
        second_request_time = (time.time() - start_time) * 1000
        
        # Third request (potential cache hit)
        start_time = time.time()
        response3 = client.get(endpoint)
        third_request_time = (time.time() - start_time) * 1000
        
        # Calculate caching effectiveness
        avg_subsequent_time = (second_request_time + third_request_time) / 2
        cache_improvement_percent = ((first_request_time - avg_subsequent_time) / first_request_time) * 100
        
        caching_results = {
            "first_request_time_ms": first_request_time,
            "second_request_time_ms": second_request_time,
            "third_request_time_ms": third_request_time,
            "avg_subsequent_time_ms": avg_subsequent_time,
            "cache_improvement_percent": cache_improvement_percent,
            "effective_caching": cache_improvement_percent > 10  # 10% improvement threshold
        }
        
        self.test_results["api_caching"] = caching_results
        
        logger.info("Completed API caching effectiveness testing")
        return caching_results


class WebSocketPerformanceOptimizer:
    """WebSocket performance optimization testing."""
    
    def __init__(self):
        self.test_results = {}
    
    def test_websocket_connection_performance(self) -> Dict[str, Any]:
        """Test WebSocket connection performance."""
        logger.info("Testing WebSocket connection performance")
        
        connection_times = []
        message_latencies = []
        
        # Test multiple WebSocket connections
        for i in range(10):
            start_time = time.time()
            
            try:
                with client.websocket_connect(
                    f"/api/v1/ws/production?line_id={str(uuid.uuid4())}&user_id=perf_test_{i}"
                ) as websocket:
                    connection_time = (time.time() - start_time) * 1000
                    connection_times.append(connection_time)
                    
                    # Test message latency
                    for _ in range(5):
                        msg_start = time.time()
                        websocket.send_json({"type": "ping"})
                        data = websocket.receive_json()
                        msg_time = (time.time() - msg_start) * 1000
                        message_latencies.append(msg_time)
                        
                        assert data.get("type") == "pong"
                        
            except Exception as e:
                logger.error(f"WebSocket connection error: {e}")
        
        # Calculate statistics
        avg_connection_time = statistics.mean(connection_times) if connection_times else 0
        avg_message_latency = statistics.mean(message_latencies) if message_latencies else 0
        
        connection_results = {
            "avg_connection_time_ms": avg_connection_time,
            "max_connection_time_ms": max(connection_times) if connection_times else 0,
            "min_connection_time_ms": min(connection_times) if connection_times else 0,
            "avg_message_latency_ms": avg_message_latency,
            "max_message_latency_ms": max(message_latencies) if message_latencies else 0,
            "min_message_latency_ms": min(message_latencies) if message_latencies else 0,
            "meets_connection_target": avg_connection_time < 1000,  # 1 second connection target
            "meets_latency_target": avg_message_latency < OPTIMIZATION_TARGETS["websocket_message_latency_ms"]
        }
        
        self.test_results["websocket_connection"] = connection_results
        
        logger.info("Completed WebSocket connection performance testing")
        return connection_results
    
    def test_websocket_concurrent_connections(self) -> Dict[str, Any]:
        """Test concurrent WebSocket connections."""
        logger.info("Testing concurrent WebSocket connections")
        
        concurrent_connections = 20
        connection_times = []
        successful_connections = 0
        
        def create_connection(connection_id):
            start_time = time.time()
            try:
                with client.websocket_connect(
                    f"/api/v1/ws/production?line_id={str(uuid.uuid4())}&user_id=concurrent_test_{connection_id}"
                ) as websocket:
                    connection_time = (time.time() - start_time) * 1000
                    
                    # Test a few messages
                    for _ in range(3):
                        websocket.send_json({"type": "ping"})
                        data = websocket.receive_json()
                        assert data.get("type") == "pong"
                    
                    return connection_time, True
                    
            except Exception as e:
                logger.error(f"Concurrent WebSocket connection error: {e}")
                return (time.time() - start_time) * 1000, False
        
        with ThreadPoolExecutor(max_workers=concurrent_connections) as executor:
            futures = [executor.submit(create_connection, i) for i in range(concurrent_connections)]
            
            for future in as_completed(futures):
                connection_time, success = future.result()
                connection_times.append(connection_time)
                if success:
                    successful_connections += 1
        
        # Calculate statistics
        avg_connection_time = statistics.mean(connection_times) if connection_times else 0
        success_rate = successful_connections / concurrent_connections
        
        concurrent_results = {
            "concurrent_connections": concurrent_connections,
            "successful_connections": successful_connections,
            "success_rate": success_rate,
            "avg_connection_time_ms": avg_connection_time,
            "max_connection_time_ms": max(connection_times) if connection_times else 0,
            "meets_target": success_rate >= 0.95 and avg_connection_time < 2000
        }
        
        self.test_results["websocket_concurrent"] = concurrent_results
        
        logger.info("Completed concurrent WebSocket connections testing")
        return concurrent_results


class MemoryOptimizer:
    """Memory usage optimization testing."""
    
    def __init__(self):
        self.test_results = {}
    
    def test_memory_usage_under_load(self) -> Dict[str, Any]:
        """Test memory usage under load."""
        logger.info("Testing memory usage under load")
        
        # Start performance monitoring
        monitor = PerformanceMonitor()
        monitor.start_monitoring(duration_seconds=30)
        
        # Generate load
        endpoint = "/api/v1/enhanced/equipment/BP01.PACK.BAG1/production-status"
        request_count = 100
        
        def make_request():
            response = client.get(endpoint)
            return response.status_code
        
        # Run concurrent requests
        with ThreadPoolExecutor(max_workers=20) as executor:
            futures = [executor.submit(make_request) for _ in range(request_count)]
            [future.result() for future in as_completed(futures)]
        
        # Stop monitoring and get results
        metrics = monitor.stop_monitoring()
        summary = monitor.get_performance_summary()
        
        memory_results = {
            "test_duration_seconds": summary.get("monitoring_duration_seconds", 0),
            "total_requests": request_count,
            "system_memory": summary.get("system_memory", {}),
            "process_memory": summary.get("process_memory", {}),
            "meets_memory_target": False
        }
        
        # Check if memory usage meets targets
        if memory_results["process_memory"]:
            avg_memory = memory_results["process_memory"].get("avg_mb", 0)
            memory_results["meets_memory_target"] = avg_memory < OPTIMIZATION_TARGETS["memory_usage_mb"]
        
        self.test_results["memory_under_load"] = memory_results
        
        logger.info("Completed memory usage under load testing")
        return memory_results
    
    def test_memory_leak_detection(self) -> Dict[str, Any]:
        """Test for memory leaks."""
        logger.info("Testing for memory leaks")
        
        # Start monitoring
        monitor = PerformanceMonitor()
        monitor.start_monitoring(duration_seconds=60)
        
        # Generate sustained load
        endpoint = "/api/v1/enhanced/equipment/BP01.PACK.BAG1/production-status"
        
        def sustained_load():
            for _ in range(200):  # 200 requests over 60 seconds
                response = client.get(endpoint)
                time.sleep(0.3)  # 3 requests per second
        
        # Run sustained load
        load_thread = threading.Thread(target=sustained_load)
        load_thread.start()
        load_thread.join()
        
        # Stop monitoring
        metrics = monitor.stop_monitoring()
        summary = monitor.get_performance_summary()
        
        # Analyze memory growth
        leak_results = {
            "test_duration_seconds": summary.get("monitoring_duration_seconds", 0),
            "total_requests": 200,
            "process_memory": summary.get("process_memory", {}),
            "memory_growth_rate_mb_per_minute": 0,
            "potential_memory_leak": False
        }
        
        if leak_results["process_memory"]:
            growth_rate = leak_results["process_memory"].get("growth_rate_mb_per_minute", 0)
            leak_results["memory_growth_rate_mb_per_minute"] = growth_rate
            leak_results["potential_memory_leak"] = growth_rate > MONITORING_THRESHOLDS["memory_growth_rate_mb_per_minute"]
        
        self.test_results["memory_leak_detection"] = leak_results
        
        logger.info("Completed memory leak detection testing")
        return leak_results


class PerformanceOptimizationSuite:
    """Main performance optimization test suite."""
    
    def __init__(self):
        self.db_optimizer = DatabasePerformanceOptimizer()
        self.api_optimizer = APIResponseOptimizer()
        self.ws_optimizer = WebSocketPerformanceOptimizer()
        self.memory_optimizer = MemoryOptimizer()
        self.results = {}
    
    def run_all_optimization_tests(self) -> Dict[str, Any]:
        """Run all performance optimization tests."""
        logger.info("Starting comprehensive performance optimization testing")
        
        # Database performance tests
        logger.info("Running database performance optimization tests")
        self.results["database_performance"] = self.db_optimizer.test_query_performance()
        self.results["concurrent_queries"] = self.db_optimizer.test_concurrent_query_performance()
        
        # API performance tests
        logger.info("Running API performance optimization tests")
        self.results["api_response_times"] = self.api_optimizer.test_api_response_times()
        self.results["api_caching"] = self.api_optimizer.test_api_caching_effectiveness()
        
        # WebSocket performance tests
        logger.info("Running WebSocket performance optimization tests")
        self.results["websocket_connection"] = self.ws_optimizer.test_websocket_connection_performance()
        self.results["websocket_concurrent"] = self.ws_optimizer.test_websocket_concurrent_connections()
        
        # Memory optimization tests
        logger.info("Running memory optimization tests")
        self.results["memory_under_load"] = self.memory_optimizer.test_memory_usage_under_load()
        self.results["memory_leak_detection"] = self.memory_optimizer.test_memory_leak_detection()
        
        # Generate optimization report
        optimization_report = self.generate_optimization_report()
        
        logger.info("Completed comprehensive performance optimization testing")
        return optimization_report
    
    def generate_optimization_report(self) -> Dict[str, Any]:
        """Generate comprehensive optimization report."""
        report = {
            "optimization_summary": {
                "total_tests": 0,
                "passed_tests": 0,
                "failed_tests": 0,
                "pass_rate": 0.0
            },
            "performance_metrics": {},
            "optimization_recommendations": [],
            "detailed_results": self.results
        }
        
        # Count tests and results
        total_tests = 0
        passed_tests = 0
        
        # Database performance
        if "database_performance" in self.results:
            for query_name, query_result in self.results["database_performance"].items():
                total_tests += 1
                if query_result.get("meets_target", False):
                    passed_tests += 1
        
        if "concurrent_queries" in self.results:
            total_tests += 1
            if self.results["concurrent_queries"].get("meets_target", False):
                passed_tests += 1
        
        # API performance
        if "api_response_times" in self.results:
            for endpoint_name, endpoint_result in self.results["api_response_times"].items():
                total_tests += 1
                if endpoint_result.get("meets_target", False):
                    passed_tests += 1
        
        if "api_caching" in self.results:
            total_tests += 1
            if self.results["api_caching"].get("effective_caching", False):
                passed_tests += 1
        
        # WebSocket performance
        if "websocket_connection" in self.results:
            total_tests += 1
            if self.results["websocket_connection"].get("meets_latency_target", False):
                passed_tests += 1
        
        if "websocket_concurrent" in self.results:
            total_tests += 1
            if self.results["websocket_concurrent"].get("meets_target", False):
                passed_tests += 1
        
        # Memory optimization
        if "memory_under_load" in self.results:
            total_tests += 1
            if self.results["memory_under_load"].get("meets_memory_target", False):
                passed_tests += 1
        
        if "memory_leak_detection" in self.results:
            total_tests += 1
            if not self.results["memory_leak_detection"].get("potential_memory_leak", True):
                passed_tests += 1
        
        # Update summary
        report["optimization_summary"]["total_tests"] = total_tests
        report["optimization_summary"]["passed_tests"] = passed_tests
        report["optimization_summary"]["failed_tests"] = total_tests - passed_tests
        report["optimization_summary"]["pass_rate"] = (passed_tests / total_tests * 100) if total_tests > 0 else 0
        
        # Generate recommendations
        self._generate_recommendations(report)
        
        return report
    
    def _generate_recommendations(self, report: Dict[str, Any]):
        """Generate optimization recommendations."""
        recommendations = []
        
        # Database recommendations
        if "database_performance" in self.results:
            slow_queries = [
                name for name, result in self.results["database_performance"].items()
                if not result.get("meets_target", False)
            ]
            if slow_queries:
                recommendations.append(f"Optimize slow database queries: {', '.join(slow_queries)}")
        
        # API recommendations
        if "api_response_times" in self.results:
            slow_endpoints = [
                name for name, result in self.results["api_response_times"].items()
                if not result.get("meets_target", False)
            ]
            if slow_endpoints:
                recommendations.append(f"Optimize slow API endpoints: {', '.join(slow_endpoints)}")
        
        # WebSocket recommendations
        if "websocket_connection" in self.results:
            if not self.results["websocket_connection"].get("meets_latency_target", False):
                recommendations.append("Optimize WebSocket message latency")
        
        # Memory recommendations
        if "memory_leak_detection" in self.results:
            if self.results["memory_leak_detection"].get("potential_memory_leak", False):
                recommendations.append("Investigate potential memory leaks")
        
        if "memory_under_load" in self.results:
            if not self.results["memory_under_load"].get("meets_memory_target", False):
                recommendations.append("Optimize memory usage under load")
        
        report["optimization_recommendations"] = recommendations


def main():
    """Main function to run performance optimization tests."""
    logger.info("Starting MS5.0 Floor Dashboard Performance Optimization")
    
    # Create and run optimization suite
    optimization_suite = PerformanceOptimizationSuite()
    results = optimization_suite.run_all_optimization_tests()
    
    # Save results
    with open("performance_optimization_results.json", 'w') as f:
        json.dump(results, f, indent=2, default=str)
    
    # Print summary
    print("\n" + "="*80)
    print("PERFORMANCE OPTIMIZATION SUMMARY")
    print("="*80)
    
    summary = results["optimization_summary"]
    print(f"Total Tests: {summary['total_tests']}")
    print(f"Passed Tests: {summary['passed_tests']}")
    print(f"Failed Tests: {summary['failed_tests']}")
    print(f"Pass Rate: {summary['pass_rate']:.1f}%")
    
    if results["optimization_recommendations"]:
        print("\nOPTIMIZATION RECOMMENDATIONS:")
        for i, rec in enumerate(results["optimization_recommendations"], 1):
            print(f"{i}. {rec}")
    
    print("="*80)
    
    # Return exit code based on pass rate
    if summary["pass_rate"] >= 80:
        return 0  # Success
    else:
        return 1  # Failure


if __name__ == "__main__":
    exit(main())
