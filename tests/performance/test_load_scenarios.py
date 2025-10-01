"""
MS5.0 Floor Dashboard - Load Testing Performance Tests

Performance tests for various load scenarios.
Tests system performance under different user loads and traffic patterns.

Load Scenarios:
1. Normal load (100 concurrent users)
2. High load (500 concurrent users)
3. Peak load (1000 concurrent users)
4. Stress load (2000+ concurrent users)
5. Endurance load (sustained load over time)
"""

import pytest
import pytest_asyncio
import asyncio
import aiohttp
import time
from typing import List, Dict, Any, Tuple
from datetime import datetime, timezone, timedelta
from dataclasses import dataclass, field
from concurrent.futures import ThreadPoolExecutor
import statistics
import json


@dataclass
class LoadTestResult:
    """Result of a load test execution."""
    scenario_name: str
    concurrent_users: int
    duration_seconds: float
    total_requests: int
    successful_requests: int
    failed_requests: int
    average_response_time_ms: float
    min_response_time_ms: float
    max_response_time_ms: float
    p50_response_time_ms: float
    p95_response_time_ms: float
    p99_response_time_ms: float
    requests_per_second: float
    error_rate_percentage: float
    resource_usage: Dict[str, float] = field(default_factory=dict)


class LoadTestRunner:
    """Runs load tests with configurable scenarios."""
    
    def __init__(self, base_url: str):
        self.base_url = base_url
        self.results: List[LoadTestResult] = []
    
    async def run_load_test(
        self,
        scenario_name: str,
        concurrent_users: int,
        duration_seconds: int,
        endpoint: str,
        method: str = "GET",
        headers: Dict[str, str] = None,
        data: Dict[str, Any] = None
    ) -> LoadTestResult:
        """Run a load test scenario."""
        
        print(f"Starting load test: {scenario_name}")
        print(f"Concurrent users: {concurrent_users}")
        print(f"Duration: {duration_seconds} seconds")
        print(f"Endpoint: {method} {endpoint}")
        
        # Initialize metrics
        response_times = []
        successful_requests = 0
        failed_requests = 0
        start_time = time.time()
        
        # Create semaphore to limit concurrent requests
        semaphore = asyncio.Semaphore(concurrent_users)
        
        async def make_request(session: aiohttp.ClientSession, request_id: int):
            """Make a single request and record metrics."""
            async with semaphore:
                request_start = time.time()
                try:
                    if method.upper() == "GET":
                        async with session.get(f"{self.base_url}{endpoint}", headers=headers) as response:
                            await response.text()
                            if response.status < 400:
                                successful_requests += 1
                            else:
                                failed_requests += 1
                    elif method.upper() == "POST":
                        async with session.post(f"{self.base_url}{endpoint}", headers=headers, json=data) as response:
                            await response.text()
                            if response.status < 400:
                                successful_requests += 1
                            else:
                                failed_requests += 1
                    elif method.upper() == "PUT":
                        async with session.put(f"{self.base_url}{endpoint}", headers=headers, json=data) as response:
                            await response.text()
                            if response.status < 400:
                                successful_requests += 1
                            else:
                                failed_requests += 1
                    elif method.upper() == "DELETE":
                        async with session.delete(f"{self.base_url}{endpoint}", headers=headers) as response:
                            await response.text()
                            if response.status < 400:
                                successful_requests += 1
                            else:
                                failed_requests += 1
                    
                    request_end = time.time()
                    response_time_ms = (request_end - request_start) * 1000
                    response_times.append(response_time_ms)
                    
                except Exception as e:
                    failed_requests += 1
                    print(f"Request {request_id} failed: {e}")
        
        # Create HTTP session
        timeout = aiohttp.ClientTimeout(total=30)
        async with aiohttp.ClientSession(timeout=timeout) as session:
            # Start load test
            tasks = []
            request_id = 0
            
            while time.time() - start_time < duration_seconds:
                # Create tasks for concurrent requests
                for _ in range(concurrent_users):
                    if time.time() - start_time < duration_seconds:
                        task = asyncio.create_task(make_request(session, request_id))
                        tasks.append(task)
                        request_id += 1
                
                # Wait a bit before creating more requests
                await asyncio.sleep(0.1)
            
            # Wait for all tasks to complete
            await asyncio.gather(*tasks, return_exceptions=True)
        
        end_time = time.time()
        actual_duration = end_time - start_time
        total_requests = successful_requests + failed_requests
        
        # Calculate statistics
        if response_times:
            avg_response_time = statistics.mean(response_times)
            min_response_time = min(response_times)
            max_response_time = max(response_times)
            p50_response_time = statistics.median(response_times)
            p95_response_time = sorted(response_times)[int(len(response_times) * 0.95)]
            p99_response_time = sorted(response_times)[int(len(response_times) * 0.99)]
        else:
            avg_response_time = min_response_time = max_response_time = 0
            p50_response_time = p95_response_time = p99_response_time = 0
        
        requests_per_second = total_requests / actual_duration if actual_duration > 0 else 0
        error_rate = (failed_requests / total_requests * 100) if total_requests > 0 else 0
        
        # Create result
        result = LoadTestResult(
            scenario_name=scenario_name,
            concurrent_users=concurrent_users,
            duration_seconds=actual_duration,
            total_requests=total_requests,
            successful_requests=successful_requests,
            failed_requests=failed_requests,
            average_response_time_ms=avg_response_time,
            min_response_time_ms=min_response_time,
            max_response_time_ms=max_response_time,
            p50_response_time_ms=p50_response_time,
            p95_response_time_ms=p95_response_time,
            p99_response_time_ms=p99_response_time,
            requests_per_second=requests_per_second,
            error_rate_percentage=error_rate
        )
        
        self.results.append(result)
        
        # Print results
        print(f"\nLoad Test Results for {scenario_name}:")
        print(f"Duration: {actual_duration:.2f} seconds")
        print(f"Total Requests: {total_requests}")
        print(f"Successful: {successful_requests}")
        print(f"Failed: {failed_requests}")
        print(f"Error Rate: {error_rate:.2f}%")
        print(f"Requests/sec: {requests_per_second:.2f}")
        print(f"Average Response Time: {avg_response_time:.2f}ms")
        print(f"P95 Response Time: {p95_response_time:.2f}ms")
        print(f"P99 Response Time: {p99_response_time:.2f}ms")
        
        return result


class TestNormalLoadScenarios:
    """Tests for normal load scenarios (100 concurrent users)."""
    
    @pytest.fixture
    def test_base_url(self):
        """Provide the test API base URL."""
        return "http://localhost:8000"
    
    @pytest.fixture
    def load_test_runner(self, test_base_url):
        """Provide a load test runner instance."""
        return LoadTestRunner(test_base_url)
    
    @pytest.fixture
    def auth_headers(self):
        """Provide authentication headers for load tests."""
        return {
            "Authorization": "Bearer test_token",
            "Content-Type": "application/json"
        }
    
    @pytest.mark.asyncio
    async def test_dashboard_load_normal_load(
        self, 
        load_test_runner: LoadTestRunner, 
        auth_headers: Dict[str, str]
    ):
        """Test dashboard endpoint under normal load."""
        result = await load_test_runner.run_load_test(
            scenario_name="Dashboard Normal Load",
            concurrent_users=100,
            duration_seconds=60,
            endpoint="/api/v1/dashboard/lines",
            method="GET",
            headers=auth_headers
        )
        
        # Assert performance requirements
        assert result.average_response_time_ms <= 200.0, f"Average response time {result.average_response_time_ms}ms exceeds 200ms limit"
        assert result.p95_response_time_ms <= 500.0, f"P95 response time {result.p95_response_time_ms}ms exceeds 500ms limit"
        assert result.error_rate_percentage <= 1.0, f"Error rate {result.error_rate_percentage}% exceeds 1% limit"
        assert result.requests_per_second >= 50.0, f"Requests per second {result.requests_per_second} below 50 RPS requirement"
    
    @pytest.mark.asyncio
    async def test_production_api_normal_load(
        self, 
        load_test_runner: LoadTestRunner, 
        auth_headers: Dict[str, str]
    ):
        """Test production API endpoints under normal load."""
        result = await load_test_runner.run_load_test(
            scenario_name="Production API Normal Load",
            concurrent_users=100,
            duration_seconds=60,
            endpoint="/api/v1/production/lines",
            method="GET",
            headers=auth_headers
        )
        
        # Assert performance requirements
        assert result.average_response_time_ms <= 300.0, f"Average response time {result.average_response_time_ms}ms exceeds 300ms limit"
        assert result.p95_response_time_ms <= 800.0, f"P95 response time {result.p95_response_time_ms}ms exceeds 800ms limit"
        assert result.error_rate_percentage <= 1.0, f"Error rate {result.error_rate_percentage}% exceeds 1% limit"
    
    @pytest.mark.asyncio
    async def test_oee_calculation_normal_load(
        self, 
        load_test_runner: LoadTestRunner, 
        auth_headers: Dict[str, str]
    ):
        """Test OEE calculation endpoints under normal load."""
        result = await load_test_runner.run_load_test(
            scenario_name="OEE Calculation Normal Load",
            concurrent_users=100,
            duration_seconds=60,
            endpoint="/api/v1/oee/calculate",
            method="GET",
            headers=auth_headers
        )
        
        # Assert performance requirements (OEE calculations are more intensive)
        assert result.average_response_time_ms <= 500.0, f"Average response time {result.average_response_time_ms}ms exceeds 500ms limit"
        assert result.p95_response_time_ms <= 1000.0, f"P95 response time {result.p95_response_time_ms}ms exceeds 1000ms limit"
        assert result.error_rate_percentage <= 2.0, f"Error rate {result.error_rate_percentage}% exceeds 2% limit"
    
    @pytest.mark.asyncio
    async def test_andon_api_normal_load(
        self, 
        load_test_runner: LoadTestRunner, 
        auth_headers: Dict[str, str]
    ):
        """Test Andon API endpoints under normal load."""
        result = await load_test_runner.run_load_test(
            scenario_name="Andon API Normal Load",
            concurrent_users=100,
            duration_seconds=60,
            endpoint="/api/v1/andon/events",
            method="GET",
            headers=auth_headers
        )
        
        # Assert performance requirements
        assert result.average_response_time_ms <= 200.0, f"Average response time {result.average_response_time_ms}ms exceeds 200ms limit"
        assert result.p95_response_time_ms <= 500.0, f"P95 response time {result.p95_response_time_ms}ms exceeds 500ms limit"
        assert result.error_rate_percentage <= 1.0, f"Error rate {result.error_rate_percentage}% exceeds 1% limit"


class TestHighLoadScenarios:
    """Tests for high load scenarios (500 concurrent users)."""
    
    @pytest.fixture
    def test_base_url(self):
        """Provide the test API base URL."""
        return "http://localhost:8000"
    
    @pytest.fixture
    def load_test_runner(self, test_base_url):
        """Provide a load test runner instance."""
        return LoadTestRunner(test_base_url)
    
    @pytest.fixture
    def auth_headers(self):
        """Provide authentication headers for load tests."""
        return {
            "Authorization": "Bearer test_token",
            "Content-Type": "application/json"
        }
    
    @pytest.mark.asyncio
    async def test_dashboard_high_load(
        self, 
        load_test_runner: LoadTestRunner, 
        auth_headers: Dict[str, str]
    ):
        """Test dashboard endpoint under high load."""
        result = await load_test_runner.run_load_test(
            scenario_name="Dashboard High Load",
            concurrent_users=500,
            duration_seconds=120,
            endpoint="/api/v1/dashboard/lines",
            method="GET",
            headers=auth_headers
        )
        
        # Assert performance requirements (relaxed for high load)
        assert result.average_response_time_ms <= 400.0, f"Average response time {result.average_response_time_ms}ms exceeds 400ms limit"
        assert result.p95_response_time_ms <= 1000.0, f"P95 response time {result.p95_response_time_ms}ms exceeds 1000ms limit"
        assert result.error_rate_percentage <= 5.0, f"Error rate {result.error_rate_percentage}% exceeds 5% limit"
        assert result.requests_per_second >= 200.0, f"Requests per second {result.requests_per_second} below 200 RPS requirement"
    
    @pytest.mark.asyncio
    async def test_mixed_api_high_load(
        self, 
        load_test_runner: LoadTestRunner, 
        auth_headers: Dict[str, str]
    ):
        """Test mixed API endpoints under high load."""
        endpoints = [
            "/api/v1/dashboard/lines",
            "/api/v1/production/lines",
            "/api/v1/equipment/status",
            "/api/v1/andon/events"
        ]
        
        results = []
        for endpoint in endpoints:
            result = await load_test_runner.run_load_test(
                scenario_name=f"Mixed API High Load - {endpoint}",
                concurrent_users=125,  # 500 / 4 endpoints
                duration_seconds=60,
                endpoint=endpoint,
                method="GET",
                headers=auth_headers
            )
            results.append(result)
        
        # Assert overall performance
        total_requests = sum(r.total_requests for r in results)
        total_errors = sum(r.failed_requests for r in results)
        overall_error_rate = (total_errors / total_requests * 100) if total_requests > 0 else 0
        
        assert overall_error_rate <= 5.0, f"Overall error rate {overall_error_rate}% exceeds 5% limit"
        
        # Assert individual endpoint performance
        for result in results:
            assert result.average_response_time_ms <= 500.0, f"{result.scenario_name}: Average response time {result.average_response_time_ms}ms exceeds 500ms limit"


class TestPeakLoadScenarios:
    """Tests for peak load scenarios (1000 concurrent users)."""
    
    @pytest.fixture
    def test_base_url(self):
        """Provide the test API base URL."""
        return "http://localhost:8000"
    
    @pytest.fixture
    def load_test_runner(self, test_base_url):
        """Provide a load test runner instance."""
        return LoadTestRunner(test_base_url)
    
    @pytest.fixture
    def auth_headers(self):
        """Provide authentication headers for load tests."""
        return {
            "Authorization": "Bearer test_token",
            "Content-Type": "application/json"
        }
    
    @pytest.mark.asyncio
    async def test_dashboard_peak_load(
        self, 
        load_test_runner: LoadTestRunner, 
        auth_headers: Dict[str, str]
    ):
        """Test dashboard endpoint under peak load."""
        result = await load_test_runner.run_load_test(
            scenario_name="Dashboard Peak Load",
            concurrent_users=1000,
            duration_seconds=180,
            endpoint="/api/v1/dashboard/lines",
            method="GET",
            headers=auth_headers
        )
        
        # Assert performance requirements (further relaxed for peak load)
        assert result.average_response_time_ms <= 800.0, f"Average response time {result.average_response_time_ms}ms exceeds 800ms limit"
        assert result.p95_response_time_ms <= 2000.0, f"P95 response time {result.p95_response_time_ms}ms exceeds 2000ms limit"
        assert result.error_rate_percentage <= 10.0, f"Error rate {result.error_rate_percentage}% exceeds 10% limit"
        assert result.requests_per_second >= 300.0, f"Requests per second {result.requests_per_second} below 300 RPS requirement"
    
    @pytest.mark.asyncio
    async def test_write_operations_peak_load(
        self, 
        load_test_runner: LoadTestRunner, 
        auth_headers: Dict[str, str]
    ):
        """Test write operations under peak load."""
        test_data = {
            "line_code": "LOAD_TEST_LINE",
            "line_name": "Load Test Line",
            "line_type": "assembly",
            "status": "active"
        }
        
        result = await load_test_runner.run_load_test(
            scenario_name="Write Operations Peak Load",
            concurrent_users=1000,
            duration_seconds=120,
            endpoint="/api/v1/production/lines",
            method="POST",
            headers=auth_headers,
            data=test_data
        )
        
        # Assert performance requirements for write operations
        assert result.average_response_time_ms <= 1000.0, f"Average response time {result.average_response_time_ms}ms exceeds 1000ms limit"
        assert result.p95_response_time_ms <= 3000.0, f"P95 response time {result.p95_response_time_ms}ms exceeds 3000ms limit"
        assert result.error_rate_percentage <= 15.0, f"Error rate {result.error_rate_percentage}% exceeds 15% limit"


class TestStressLoadScenarios:
    """Tests for stress load scenarios (2000+ concurrent users)."""
    
    @pytest.fixture
    def test_base_url(self):
        """Provide the test API base URL."""
        return "http://localhost:8000"
    
    @pytest.fixture
    def load_test_runner(self, test_base_url):
        """Provide a load test runner instance."""
        return LoadTestRunner(test_base_url)
    
    @pytest.fixture
    def auth_headers(self):
        """Provide authentication headers for load tests."""
        return {
            "Authorization": "Bearer test_token",
            "Content-Type": "application/json"
        }
    
    @pytest.mark.asyncio
    async def test_system_breaking_point(
        self, 
        load_test_runner: LoadTestRunner, 
        auth_headers: Dict[str, str]
    ):
        """Test system breaking point under extreme stress."""
        result = await load_test_runner.run_load_test(
            scenario_name="System Breaking Point",
            concurrent_users=2000,
            duration_seconds=300,
            endpoint="/api/v1/dashboard/lines",
            method="GET",
            headers=auth_headers
        )
        
        # Document breaking point (no assertions, just measurement)
        print(f"\nSystem Breaking Point Results:")
        print(f"Concurrent Users: {result.concurrent_users}")
        print(f"Total Requests: {result.total_requests}")
        print(f"Error Rate: {result.error_rate_percentage}%")
        print(f"Average Response Time: {result.average_response_time_ms}ms")
        print(f"P95 Response Time: {result.p95_response_time_ms}ms")
        print(f"Requests per Second: {result.requests_per_second}")
        
        # System should still be functional (not completely broken)
        assert result.error_rate_percentage < 50.0, "System completely broken (>50% error rate)"
    
    @pytest.mark.asyncio
    async def test_recovery_after_stress(
        self, 
        load_test_runner: LoadTestRunner, 
        auth_headers: Dict[str, str]
    ):
        """Test system recovery after stress load."""
        # First, apply stress load
        await load_test_runner.run_load_test(
            scenario_name="Pre-Recovery Stress",
            concurrent_users=2000,
            duration_seconds=60,
            endpoint="/api/v1/dashboard/lines",
            method="GET",
            headers=auth_headers
        )
        
        # Wait for system to stabilize
        await asyncio.sleep(30)
        
        # Test normal load after stress
        result = await load_test_runner.run_load_test(
            scenario_name="Post-Stress Recovery",
            concurrent_users=100,
            duration_seconds=60,
            endpoint="/api/v1/dashboard/lines",
            method="GET",
            headers=auth_headers
        )
        
        # Assert system has recovered
        assert result.average_response_time_ms <= 300.0, f"System has not recovered: Average response time {result.average_response_time_ms}ms exceeds 300ms limit"
        assert result.error_rate_percentage <= 2.0, f"System has not recovered: Error rate {result.error_rate_percentage}% exceeds 2% limit"


class TestEnduranceLoadScenarios:
    """Tests for endurance load scenarios (sustained load over time)."""
    
    @pytest.fixture
    def test_base_url(self):
        """Provide the test API base URL."""
        return "http://localhost:8000"
    
    @pytest.fixture
    def load_test_runner(self, test_base_url):
        """Provide a load test runner instance."""
        return LoadTestRunner(test_base_url)
    
    @pytest.fixture
    def auth_headers(self):
        """Provide authentication headers for load tests."""
        return {
            "Authorization": "Bearer test_token",
            "Content-Type": "application/json"
        }
    
    @pytest.mark.asyncio
    async def test_24_hour_endurance_load(
        self, 
        load_test_runner: LoadTestRunner, 
        auth_headers: Dict[str, str]
    ):
        """Test 24-hour endurance load (shortened for testing)."""
        # Note: In real testing, this would run for 24 hours
        # For CI/CD, we'll run for a shorter duration
        result = await load_test_runner.run_load_test(
            scenario_name="24-Hour Endurance Load (Shortened)",
            concurrent_users=500,
            duration_seconds=3600,  # 1 hour instead of 24 hours
            endpoint="/api/v1/dashboard/lines",
            method="GET",
            headers=auth_headers
        )
        
        # Assert endurance requirements
        assert result.error_rate_percentage <= 2.0, f"Endurance test error rate {result.error_rate_percentage}% exceeds 2% limit"
        assert result.requests_per_second >= 100.0, f"Endurance test RPS {result.requests_per_second} below 100 RPS requirement"
        
        # Check for memory leaks or performance degradation
        # (This would be monitored over the full 24-hour period)
        assert result.average_response_time_ms <= 500.0, f"Performance degradation detected: {result.average_response_time_ms}ms"
    
    @pytest.mark.asyncio
    async def test_memory_leak_detection(
        self, 
        load_test_runner: LoadTestRunner, 
        auth_headers: Dict[str, str]
    ):
        """Test for memory leaks under sustained load."""
        # Run multiple load test cycles to detect memory leaks
        results = []
        for cycle in range(5):
            result = await load_test_runner.run_load_test(
                scenario_name=f"Memory Leak Detection Cycle {cycle + 1}",
                concurrent_users=200,
                duration_seconds=300,  # 5 minutes per cycle
                endpoint="/api/v1/dashboard/lines",
                method="GET",
                headers=auth_headers
            )
            results.append(result)
            
            # Wait between cycles
            await asyncio.sleep(60)
        
        # Check for performance degradation over cycles
        first_cycle_avg = results[0].average_response_time_ms
        last_cycle_avg = results[-1].average_response_time_ms
        
        # Allow for 20% performance degradation maximum
        max_degradation = first_cycle_avg * 1.2
        
        assert last_cycle_avg <= max_degradation, \
            f"Memory leak detected: Response time increased from {first_cycle_avg}ms to {last_cycle_avg}ms (>{max_degradation}ms limit)"
        
        # Check for increasing error rates
        first_cycle_errors = results[0].error_rate_percentage
        last_cycle_errors = results[-1].error_rate_percentage
        
        assert last_cycle_errors <= first_cycle_errors * 2, \
            f"Error rate increasing over time: {first_cycle_errors}% -> {last_cycle_errors}%"
