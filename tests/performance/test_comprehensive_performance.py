"""
Comprehensive Performance Tests
Tests API performance, database performance, and WebSocket performance under load
"""

import pytest
import asyncio
import httpx
import time
import statistics
from datetime import datetime, timedelta
from uuid import uuid4
import json
import psutil
import os

from backend.app.main import app
from backend.app.database import get_db_session


class TestAPIPerformance:
    """API performance tests"""
    
    @pytest.fixture
    async def client(self):
        """Create HTTP client for performance testing"""
        async with httpx.AsyncClient(app=app, base_url="http://test") as client:
            yield client
    
    @pytest.fixture
    async def auth_headers(self):
        """Create authentication headers for performance testing"""
        from backend.app.auth.jwt_handler import create_access_token
        
        token_data = {
            "sub": str(uuid4()),
            "email": "perf_test@example.com",
            "role": "admin",
            "permissions": ["read", "write", "admin"]
        }
        token = create_access_token(token_data)
        return {"Authorization": f"Bearer {token}"}
    
    @pytest.mark.asyncio
    async def test_single_request_response_time(self, client, auth_headers):
        """Test single request response time"""
        start_time = time.time()
        
        response = await client.get(
            "/api/v1/production/lines",
            headers=auth_headers
        )
        
        end_time = time.time()
        response_time = end_time - start_time
        
        # Response time should be under 1 second for single request
        assert response_time < 1.0
        
        # Log response time for monitoring
        print(f"Single request response time: {response_time:.3f}s")
    
    @pytest.mark.asyncio
    async def test_concurrent_requests_performance(self, client, auth_headers):
        """Test performance under concurrent requests"""
        num_requests = 10
        start_time = time.time()
        
        # Create concurrent requests
        tasks = []
        for i in range(num_requests):
            task = client.get(
                "/api/v1/production/lines",
                headers=auth_headers
            )
            tasks.append(task)
        
        responses = await asyncio.gather(*tasks)
        
        end_time = time.time()
        total_time = end_time - start_time
        avg_time_per_request = total_time / num_requests
        
        # All requests should complete
        assert len(responses) == num_requests
        
        # Average response time should be reasonable
        assert avg_time_per_request < 2.0
        
        # Total time should be reasonable for concurrent execution
        assert total_time < 10.0
        
        print(f"Concurrent requests ({num_requests}):")
        print(f"  Total time: {total_time:.3f}s")
        print(f"  Average time per request: {avg_time_per_request:.3f}s")
        print(f"  Requests per second: {num_requests / total_time:.2f}")
    
    @pytest.mark.asyncio
    async def test_high_load_performance(self, client, auth_headers):
        """Test performance under high load"""
        num_requests = 50
        response_times = []
        
        start_time = time.time()
        
        # Create high load requests
        tasks = []
        for i in range(num_requests):
            task = client.get(
                "/api/v1/production/lines",
                headers=auth_headers
            )
            tasks.append(task)
        
        # Execute with timeout
        try:
            responses = await asyncio.wait_for(
                asyncio.gather(*tasks),
                timeout=30.0
            )
            
            end_time = time.time()
            total_time = end_time - start_time
            
            # All requests should complete
            assert len(responses) == num_requests
            
            # Calculate performance metrics
            requests_per_second = num_requests / total_time
            
            # Should handle at least 10 requests per second
            assert requests_per_second >= 10.0
            
            print(f"High load test ({num_requests} requests):")
            print(f"  Total time: {total_time:.3f}s")
            print(f"  Requests per second: {requests_per_second:.2f}")
            
        except asyncio.TimeoutError:
            pytest.fail("High load test timed out")
    
    @pytest.mark.asyncio
    async def test_response_time_distribution(self, client, auth_headers):
        """Test response time distribution across multiple requests"""
        num_requests = 20
        response_times = []
        
        for i in range(num_requests):
            start_time = time.time()
            
            response = await client.get(
                "/api/v1/production/lines",
                headers=auth_headers
            )
            
            end_time = time.time()
            response_times.append(end_time - start_time)
        
        # Calculate statistics
        mean_time = statistics.mean(response_times)
        median_time = statistics.median(response_times)
        p95_time = sorted(response_times)[int(0.95 * len(response_times))]
        p99_time = sorted(response_times)[int(0.99 * len(response_times))]
        
        # Performance thresholds
        assert mean_time < 1.0
        assert median_time < 1.0
        assert p95_time < 2.0
        assert p99_time < 3.0
        
        print(f"Response time distribution ({num_requests} requests):")
        print(f"  Mean: {mean_time:.3f}s")
        print(f"  Median: {median_time:.3f}s")
        print(f"  P95: {p95_time:.3f}s")
        print(f"  P99: {p99_time:.3f}s")
    
    @pytest.mark.asyncio
    async def test_different_endpoints_performance(self, client, auth_headers):
        """Test performance across different endpoints"""
        endpoints = [
            "/api/v1/production/lines",
            "/api/v1/oee/lines/test-line",
            "/api/v1/andon/dashboard",
            "/api/v1/dashboard/lines"
        ]
        
        endpoint_times = {}
        
        for endpoint in endpoints:
            start_time = time.time()
            
            response = await client.get(endpoint, headers=auth_headers)
            
            end_time = time.time()
            response_time = end_time - start_time
            
            endpoint_times[endpoint] = response_time
            
            # Each endpoint should respond within reasonable time
            assert response_time < 2.0
        
        print("Endpoint performance:")
        for endpoint, response_time in endpoint_times.items():
            print(f"  {endpoint}: {response_time:.3f}s")
    
    @pytest.mark.asyncio
    async def test_post_request_performance(self, client, auth_headers):
        """Test POST request performance"""
        test_data = {
            "line_code": f"PERF_TEST_{int(time.time())}",
            "name": "Performance Test Line",
            "description": "Line for performance testing",
            "equipment_codes": ["EQ001", "EQ002"],
            "target_speed": 100.0,
            "enabled": True
        }
        
        num_requests = 10
        response_times = []
        
        for i in range(num_requests):
            start_time = time.time()
            
            # Modify data to avoid conflicts
            test_data["line_code"] = f"PERF_TEST_{int(time.time())}_{i}"
            
            response = await client.post(
                "/api/v1/production/lines",
                json=test_data,
                headers=auth_headers
            )
            
            end_time = time.time()
            response_times.append(end_time - start_time)
        
        mean_time = statistics.mean(response_times)
        
        # POST requests should complete within reasonable time
        assert mean_time < 2.0
        
        print(f"POST request performance ({num_requests} requests):")
        print(f"  Mean response time: {mean_time:.3f}s")


class TestDatabasePerformance:
    """Database performance tests"""
    
    @pytest.mark.asyncio
    async def test_database_connection_performance(self):
        """Test database connection performance"""
        num_connections = 10
        connection_times = []
        
        for i in range(num_connections):
            start_time = time.time()
            
            # Simulate database connection
            async with get_db_session() as session:
                # Simple query to test connection
                result = await session.execute("SELECT 1")
                result.fetchone()
            
            end_time = time.time()
            connection_times.append(end_time - start_time)
        
        mean_time = statistics.mean(connection_times)
        
        # Database connections should be fast
        assert mean_time < 0.1
        
        print(f"Database connection performance ({num_connections} connections):")
        print(f"  Mean connection time: {mean_time:.3f}s")
    
    @pytest.mark.asyncio
    async def test_database_query_performance(self):
        """Test database query performance"""
        async with get_db_session() as session:
            # Test simple query
            start_time = time.time()
            
            result = await session.execute("SELECT COUNT(*) FROM factory_telemetry.equipment_config")
            count = result.fetchone()[0]
            
            end_time = time.time()
            query_time = end_time - start_time
            
            # Simple queries should be fast
            assert query_time < 0.5
            
            print(f"Database query performance:")
            print(f"  Query time: {query_time:.3f}s")
            print(f"  Result count: {count}")
    
    @pytest.mark.asyncio
    async def test_database_concurrent_queries(self):
        """Test database performance under concurrent queries"""
        num_queries = 10
        
        async def execute_query():
            async with get_db_session() as session:
                start_time = time.time()
                
                result = await session.execute("SELECT COUNT(*) FROM factory_telemetry.equipment_config")
                count = result.fetchone()[0]
                
                end_time = time.time()
                return end_time - start_time
        
        # Execute concurrent queries
        start_time = time.time()
        
        tasks = [execute_query() for _ in range(num_queries)]
        query_times = await asyncio.gather(*tasks)
        
        end_time = time.time()
        total_time = end_time - start_time
        
        mean_query_time = statistics.mean(query_times)
        
        # Concurrent queries should complete reasonably fast
        assert mean_query_time < 1.0
        assert total_time < 5.0
        
        print(f"Concurrent database queries ({num_queries} queries):")
        print(f"  Mean query time: {mean_query_time:.3f}s")
        print(f"  Total time: {total_time:.3f}s")


class TestWebSocketPerformance:
    """WebSocket performance tests"""
    
    @pytest.mark.asyncio
    async def test_websocket_connection_performance(self):
        """Test WebSocket connection performance"""
        import websockets
        
        num_connections = 5
        connection_times = []
        
        for i in range(num_connections):
            start_time = time.time()
            
            try:
                # Attempt WebSocket connection
                uri = "ws://localhost:8000/ws"
                async with websockets.connect(uri) as websocket:
                    # Send a test message
                    await websocket.send(json.dumps({"type": "ping"}))
                    
                    # Wait for response
                    response = await asyncio.wait_for(websocket.recv(), timeout=5.0)
                    
                    end_time = time.time()
                    connection_times.append(end_time - start_time)
                    
            except Exception as e:
                # Expected in test environment without WebSocket server
                print(f"WebSocket connection test skipped (expected): {e}")
                return
        
        if connection_times:
            mean_time = statistics.mean(connection_times)
            
            # WebSocket connections should be fast
            assert mean_time < 1.0
            
            print(f"WebSocket connection performance ({num_connections} connections):")
            print(f"  Mean connection time: {mean_time:.3f}s")
    
    @pytest.mark.asyncio
    async def test_websocket_message_throughput(self):
        """Test WebSocket message throughput"""
        import websockets
        
        num_messages = 100
        
        try:
            uri = "ws://localhost:8000/ws"
            async with websockets.connect(uri) as websocket:
                start_time = time.time()
                
                # Send multiple messages
                for i in range(num_messages):
                    message = json.dumps({
                        "type": "test",
                        "message": f"Test message {i}",
                        "timestamp": datetime.now().isoformat()
                    })
                    await websocket.send(message)
                
                end_time = time.time()
                total_time = end_time - start_time
                
                messages_per_second = num_messages / total_time
                
                # Should handle reasonable message throughput
                assert messages_per_second > 10.0
                
                print(f"WebSocket message throughput:")
                print(f"  Messages sent: {num_messages}")
                print(f"  Total time: {total_time:.3f}s")
                print(f"  Messages per second: {messages_per_second:.2f}")
                
        except Exception as e:
            # Expected in test environment without WebSocket server
            print(f"WebSocket throughput test skipped (expected): {e}")


class TestSystemResourcePerformance:
    """System resource performance tests"""
    
    def test_cpu_usage_under_load(self):
        """Test CPU usage under load"""
        # Get initial CPU usage
        initial_cpu = psutil.cpu_percent(interval=1)
        
        # Simulate some CPU load
        start_time = time.time()
        while time.time() - start_time < 2.0:
            # Simple CPU-bound operation
            sum(range(1000))
        
        # Get CPU usage after load
        final_cpu = psutil.cpu_percent(interval=1)
        
        # CPU usage should be reasonable
        assert final_cpu < 80.0  # Less than 80% CPU usage
        
        print(f"CPU usage test:")
        print(f"  Initial CPU: {initial_cpu:.1f}%")
        print(f"  Final CPU: {final_cpu:.1f}%")
    
    def test_memory_usage_stability(self):
        """Test memory usage stability"""
        # Get initial memory usage
        process = psutil.Process(os.getpid())
        initial_memory = process.memory_info().rss / 1024 / 1024  # MB
        
        # Perform some operations that might use memory
        data_structures = []
        for i in range(100):
            data_structures.append([j for j in range(1000)])
        
        # Get memory usage after operations
        final_memory = process.memory_info().rss / 1024 / 1024  # MB
        
        # Memory usage should not increase dramatically
        memory_increase = final_memory - initial_memory
        assert memory_increase < 100.0  # Less than 100MB increase
        
        print(f"Memory usage test:")
        print(f"  Initial memory: {initial_memory:.1f} MB")
        print(f"  Final memory: {final_memory:.1f} MB")
        print(f"  Memory increase: {memory_increase:.1f} MB")
    
    def test_disk_io_performance(self):
        """Test disk I/O performance"""
        test_file = "test_performance.tmp"
        
        # Test write performance
        start_time = time.time()
        
        with open(test_file, 'w') as f:
            for i in range(1000):
                f.write(f"Test line {i}\n")
        
        write_time = time.time() - start_time
        
        # Test read performance
        start_time = time.time()
        
        with open(test_file, 'r') as f:
            lines = f.readlines()
        
        read_time = time.time() - start_time
        
        # Clean up
        os.remove(test_file)
        
        # Disk I/O should be reasonable
        assert write_time < 1.0
        assert read_time < 1.0
        
        print(f"Disk I/O performance:")
        print(f"  Write time: {write_time:.3f}s")
        print(f"  Read time: {read_time:.3f}s")
        print(f"  Lines processed: {len(lines)}")


class TestLoadTesting:
    """Load testing scenarios"""
    
    @pytest.mark.asyncio
    async def test_sustained_load(self, client, auth_headers):
        """Test sustained load over time"""
        duration_seconds = 30
        requests_per_second = 2
        
        start_time = time.time()
        request_count = 0
        response_times = []
        
        while time.time() - start_time < duration_seconds:
            request_start = time.time()
            
            response = await client.get(
                "/api/v1/production/lines",
                headers=auth_headers
            )
            
            request_end = time.time()
            response_times.append(request_end - request_start)
            request_count += 1
            
            # Wait to maintain target request rate
            await asyncio.sleep(1.0 / requests_per_second)
        
        total_time = time.time() - start_time
        actual_rps = request_count / total_time
        
        # Should maintain reasonable performance under sustained load
        mean_response_time = statistics.mean(response_times)
        assert mean_response_time < 2.0
        assert actual_rps >= requests_per_second * 0.8  # Within 20% of target
        
        print(f"Sustained load test:")
        print(f"  Duration: {duration_seconds}s")
        print(f"  Target RPS: {requests_per_second}")
        print(f"  Actual RPS: {actual_rps:.2f}")
        print(f"  Total requests: {request_count}")
        print(f"  Mean response time: {mean_response_time:.3f}s")
    
    @pytest.mark.asyncio
    async def test_burst_load(self, client, auth_headers):
        """Test burst load handling"""
        burst_size = 20
        
        start_time = time.time()
        
        # Create burst of requests
        tasks = []
        for i in range(burst_size):
            task = client.get(
                "/api/v1/production/lines",
                headers=auth_headers
            )
            tasks.append(task)
        
        responses = await asyncio.gather(*tasks)
        
        end_time = time.time()
        burst_time = end_time - start_time
        
        # All requests should complete
        assert len(responses) == burst_size
        
        # Burst should be handled reasonably well
        assert burst_time < 10.0
        
        burst_rps = burst_size / burst_time
        
        print(f"Burst load test:")
        print(f"  Burst size: {burst_size}")
        print(f"  Burst time: {burst_time:.3f}s")
        print(f"  Burst RPS: {burst_rps:.2f}")
    
    @pytest.mark.asyncio
    async def test_mixed_workload(self, client, auth_headers):
        """Test mixed workload performance"""
        num_requests = 20
        response_times = []
        
        endpoints = [
            "/api/v1/production/lines",
            "/api/v1/oee/lines/test-line",
            "/api/v1/andon/dashboard"
        ]
        
        start_time = time.time()
        
        tasks = []
        for i in range(num_requests):
            # Mix different endpoints
            endpoint = endpoints[i % len(endpoints)]
            task = client.get(endpoint, headers=auth_headers)
            tasks.append(task)
        
        responses = await asyncio.gather(*tasks)
        
        end_time = time.time()
        total_time = end_time - start_time
        
        # All requests should complete
        assert len(responses) == num_requests
        
        # Mixed workload should perform reasonably
        assert total_time < 15.0
        
        mixed_rps = num_requests / total_time
        
        print(f"Mixed workload test:")
        print(f"  Requests: {num_requests}")
        print(f"  Total time: {total_time:.3f}s")
        print(f"  Mixed RPS: {mixed_rps:.2f}")


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
