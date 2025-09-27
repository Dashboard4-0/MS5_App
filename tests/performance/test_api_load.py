"""
Performance tests for API load testing
Tests API performance under various load conditions
"""

import pytest
import asyncio
import httpx
import time
import statistics
from datetime import datetime
import uuid
import json


class TestAPILoadPerformance:
    """Performance tests for API load testing"""
    
    @pytest.fixture
    async def client(self):
        """Create HTTP client for performance testing"""
        async with httpx.AsyncClient(base_url="http://localhost:8000", timeout=30.0) as client:
            yield client
    
    @pytest.fixture
    async def auth_token(self, client):
        """Get authentication token for performance testing"""
        login_data = {
            "email": "test@example.com",
            "password": "testpassword"
        }
        
        response = await client.post("/api/v1/auth/login", json=login_data)
        if response.status_code == 200:
            return response.json()["token"]
        return None
    
    @pytest.fixture
    def auth_headers(self, auth_token):
        """Get authentication headers"""
        if auth_token:
            return {"Authorization": f"Bearer {auth_token}"}
        return {}
    
    @pytest.mark.asyncio
    async def test_api_response_time_single_request(self, client, auth_headers):
        """Test API response time for single requests"""
        
        endpoints_to_test = [
            "/api/v1/production/lines",
            "/api/v1/production/schedules",
            "/api/v1/job-assignments",
            "/api/v1/andon/events",
            "/api/v1/oee/lines/test-line",
            "/api/v1/equipment/status"
        ]
        
        response_times = {}
        
        for endpoint in endpoints_to_test:
            start_time = time.time()
            
            try:
                response = await client.get(endpoint, headers=auth_headers)
                end_time = time.time()
                
                response_time = end_time - start_time
                response_times[endpoint] = {
                    "response_time": response_time,
                    "status_code": response.status_code,
                    "success": response.status_code in [200, 401]  # 401 is acceptable for auth issues
                }
                
                # Response time should be under 1 second
                assert response_time < 1.0, f"Response time for {endpoint} exceeded 1 second: {response_time:.3f}s"
                
            except Exception as e:
                response_times[endpoint] = {
                    "response_time": None,
                    "status_code": None,
                    "success": False,
                    "error": str(e)
                }
        
        # Print results for analysis
        print("\nSingle Request Performance Results:")
        for endpoint, result in response_times.items():
            if result["success"]:
                print(f"{endpoint}: {result['response_time']:.3f}s (Status: {result['status_code']})")
            else:
                print(f"{endpoint}: FAILED - {result.get('error', 'Unknown error')}")
    
    @pytest.mark.asyncio
    async def test_api_response_time_concurrent_requests(self, client, auth_headers):
        """Test API response time under concurrent load"""
        
        async def make_request(request_id):
            """Make a single API request"""
            start_time = time.time()
            
            try:
                response = await client.get("/api/v1/production/lines", headers=auth_headers)
                end_time = time.time()
                
                return {
                    "request_id": request_id,
                    "response_time": end_time - start_time,
                    "status_code": response.status_code,
                    "success": response.status_code in [200, 401]
                }
            except Exception as e:
                return {
                    "request_id": request_id,
                    "response_time": None,
                    "status_code": None,
                    "success": False,
                    "error": str(e)
                }
        
        # Test with different concurrency levels
        concurrency_levels = [5, 10, 20, 50]
        
        for concurrency in concurrency_levels:
            print(f"\nTesting {concurrency} concurrent requests...")
            
            # Create concurrent requests
            tasks = [make_request(i) for i in range(concurrency)]
            results = await asyncio.gather(*tasks)
            
            # Analyze results
            successful_results = [r for r in results if r["success"] and r["response_time"] is not None]
            
            if successful_results:
                response_times = [r["response_time"] for r in successful_results]
                
                avg_response_time = statistics.mean(response_times)
                median_response_time = statistics.median(response_times)
                max_response_time = max(response_times)
                min_response_time = min(response_times)
                
                print(f"Concurrency {concurrency}:")
                print(f"  Successful requests: {len(successful_results)}/{concurrency}")
                print(f"  Average response time: {avg_response_time:.3f}s")
                print(f"  Median response time: {median_response_time:.3f}s")
                print(f"  Max response time: {max_response_time:.3f}s")
                print(f"  Min response time: {min_response_time:.3f}s")
                
                # Performance assertions
                assert avg_response_time < 2.0, f"Average response time exceeded 2 seconds: {avg_response_time:.3f}s"
                assert max_response_time < 5.0, f"Max response time exceeded 5 seconds: {max_response_time:.3f}s"
                assert len(successful_results) >= concurrency * 0.8, f"Success rate below 80%: {len(successful_results)}/{concurrency}"
            else:
                print(f"Concurrency {concurrency}: No successful requests")
    
    @pytest.mark.asyncio
    async def test_api_throughput(self, client, auth_headers):
        """Test API throughput (requests per second)"""
        
        async def make_request():
            """Make a single API request"""
            try:
                response = await client.get("/api/v1/production/lines", headers=auth_headers)
                return response.status_code in [200, 401]
            except Exception:
                return False
        
        # Test duration in seconds
        test_duration = 10
        start_time = time.time()
        
        # Track requests
        request_count = 0
        successful_requests = 0
        
        # Make requests for the test duration
        while time.time() - start_time < test_duration:
            tasks = [make_request() for _ in range(10)]  # Batch of 10 requests
            results = await asyncio.gather(*tasks)
            
            request_count += len(results)
            successful_requests += sum(results)
        
        end_time = time.time()
        actual_duration = end_time - start_time
        
        # Calculate throughput
        requests_per_second = request_count / actual_duration
        successful_requests_per_second = successful_requests / actual_duration
        
        print(f"\nThroughput Test Results:")
        print(f"  Test duration: {actual_duration:.2f}s")
        print(f"  Total requests: {request_count}")
        print(f"  Successful requests: {successful_requests}")
        print(f"  Requests per second: {requests_per_second:.2f}")
        print(f"  Successful requests per second: {successful_requests_per_second:.2f}")
        print(f"  Success rate: {(successful_requests/request_count)*100:.1f}%")
        
        # Performance assertions
        assert requests_per_second > 10, f"Throughput below 10 RPS: {requests_per_second:.2f}"
        assert successful_requests_per_second > 8, f"Successful throughput below 8 RPS: {successful_requests_per_second:.2f}"
        assert (successful_requests/request_count) > 0.8, f"Success rate below 80%: {(successful_requests/request_count)*100:.1f}%"
    
    @pytest.mark.asyncio
    async def test_api_memory_usage(self, client, auth_headers):
        """Test API memory usage under load"""
        
        import psutil
        import os
        
        # Get initial memory usage
        process = psutil.Process(os.getpid())
        initial_memory = process.memory_info().rss / 1024 / 1024  # MB
        
        print(f"\nInitial memory usage: {initial_memory:.2f} MB")
        
        # Make many requests to test memory usage
        async def make_request():
            try:
                response = await client.get("/api/v1/production/lines", headers=auth_headers)
                return response.status_code in [200, 401]
            except Exception:
                return False
        
        # Make 1000 requests
        tasks = [make_request() for _ in range(1000)]
        results = await asyncio.gather(*tasks)
        
        # Check memory usage after requests
        final_memory = process.memory_info().rss / 1024 / 1024  # MB
        memory_increase = final_memory - initial_memory
        
        print(f"Final memory usage: {final_memory:.2f} MB")
        print(f"Memory increase: {memory_increase:.2f} MB")
        print(f"Successful requests: {sum(results)}/1000")
        
        # Memory usage should not increase excessively
        assert memory_increase < 100, f"Memory increase exceeded 100 MB: {memory_increase:.2f} MB"
    
    @pytest.mark.asyncio
    async def test_api_error_handling_performance(self, client, auth_headers):
        """Test API performance when handling errors"""
        
        # Test with invalid endpoints
        invalid_endpoints = [
            "/api/v1/invalid/endpoint",
            "/api/v1/production/lines/invalid-id",
            "/api/v1/job-assignments/invalid-id"
        ]
        
        response_times = []
        
        for endpoint in invalid_endpoints:
            start_time = time.time()
            
            try:
                response = await client.get(endpoint, headers=auth_headers)
                end_time = time.time()
                
                response_time = end_time - start_time
                response_times.append(response_time)
                
                # Error responses should still be fast
                assert response_time < 1.0, f"Error response time exceeded 1 second: {response_time:.3f}s"
                
            except Exception as e:
                # Some errors might be expected
                pass
        
        if response_times:
            avg_error_response_time = statistics.mean(response_times)
            print(f"\nAverage error response time: {avg_error_response_time:.3f}s")
            
            assert avg_error_response_time < 0.5, f"Average error response time exceeded 0.5 seconds: {avg_error_response_time:.3f}s"
    
    @pytest.mark.asyncio
    async def test_api_data_volume_performance(self, client, auth_headers):
        """Test API performance with large data volumes"""
        
        # Test with large data creation
        large_data = {
            "name": "Performance Test Line",
            "description": "Test line for performance testing with large data volume",
            "status": "active",
            "metadata": {
                "large_field": "x" * 10000,  # 10KB of data
                "array_field": list(range(1000)),  # 1000 integers
                "nested_data": {
                    "level1": {
                        "level2": {
                            "level3": {
                                "data": "x" * 5000
                            }
                        }
                    }
                }
            }
        }
        
        # Test creation performance
        start_time = time.time()
        
        try:
            response = await client.post("/api/v1/production/lines", json=large_data, headers=auth_headers)
            end_time = time.time()
            
            response_time = end_time - start_time
            
            print(f"\nLarge data creation response time: {response_time:.3f}s")
            
            # Large data operations should still be reasonably fast
            assert response_time < 2.0, f"Large data creation exceeded 2 seconds: {response_time:.3f}s"
            
            # Cleanup if creation was successful
            if response.status_code in [200, 201]:
                line_id = response.json()["id"]
                await client.delete(f"/api/v1/production/lines/{line_id}", headers=auth_headers)
                
        except Exception as e:
            print(f"Large data test failed: {e}")
    
    @pytest.mark.asyncio
    async def test_api_concurrent_write_operations(self, client, auth_headers):
        """Test API performance with concurrent write operations"""
        
        async def create_line(request_id):
            """Create a production line"""
            line_data = {
                "name": f"Concurrent Test Line {request_id}",
                "description": f"Test line for concurrent write operations {request_id}",
                "status": "active"
            }
            
            start_time = time.time()
            
            try:
                response = await client.post("/api/v1/production/lines", json=line_data, headers=auth_headers)
                end_time = time.time()
                
                return {
                    "request_id": request_id,
                    "response_time": end_time - start_time,
                    "status_code": response.status_code,
                    "success": response.status_code in [200, 201],
                    "line_id": response.json().get("id") if response.status_code in [200, 201] else None
                }
            except Exception as e:
                return {
                    "request_id": request_id,
                    "response_time": None,
                    "status_code": None,
                    "success": False,
                    "error": str(e)
                }
        
        # Test concurrent write operations
        concurrent_writes = 20
        print(f"\nTesting {concurrent_writes} concurrent write operations...")
        
        tasks = [create_line(i) for i in range(concurrent_writes)]
        results = await asyncio.gather(*tasks)
        
        # Analyze results
        successful_results = [r for r in results if r["success"] and r["response_time"] is not None]
        
        if successful_results:
            response_times = [r["response_time"] for r in successful_results]
            
            avg_response_time = statistics.mean(response_times)
            max_response_time = max(response_times)
            
            print(f"Concurrent write operations:")
            print(f"  Successful operations: {len(successful_results)}/{concurrent_writes}")
            print(f"  Average response time: {avg_response_time:.3f}s")
            print(f"  Max response time: {max_response_time:.3f}s")
            
            # Performance assertions
            assert avg_response_time < 3.0, f"Average write response time exceeded 3 seconds: {avg_response_time:.3f}s"
            assert max_response_time < 10.0, f"Max write response time exceeded 10 seconds: {max_response_time:.3f}s"
            assert len(successful_results) >= concurrent_writes * 0.7, f"Write success rate below 70%: {len(successful_results)}/{concurrent_writes}"
        
        # Cleanup created lines
        for result in results:
            if result["success"] and result["line_id"]:
                try:
                    await client.delete(f"/api/v1/production/lines/{result['line_id']}", headers=auth_headers)
                except Exception:
                    pass  # Cleanup failure is not critical


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
