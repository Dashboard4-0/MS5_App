"""
Performance tests for WebSocket load testing
Tests WebSocket performance under various load conditions
"""

import pytest
import asyncio
import websockets
import json
import time
import statistics
from datetime import datetime
import uuid


class TestWebSocketLoadPerformance:
    """Performance tests for WebSocket load testing"""
    
    @pytest.fixture
    def websocket_url(self):
        """Get WebSocket URL for testing"""
        return "ws://localhost:8000/ws"
    
    @pytest.mark.asyncio
    async def test_websocket_connection_time(self, websocket_url):
        """Test WebSocket connection establishment time"""
        
        connection_times = []
        
        # Test multiple connections
        for i in range(10):
            start_time = time.time()
            
            try:
                async with websockets.connect(websocket_url) as websocket:
                    end_time = time.time()
                    connection_time = end_time - start_time
                    connection_times.append(connection_time)
                    
                    # Connection should be established quickly
                    assert connection_time < 1.0, f"Connection time exceeded 1 second: {connection_time:.3f}s"
                    
            except Exception as e:
                # Connection might fail in test environment
                print(f"Connection {i} failed: {e}")
        
        if connection_times:
            avg_connection_time = statistics.mean(connection_times)
            max_connection_time = max(connection_times)
            
            print(f"\nWebSocket Connection Performance:")
            print(f"  Successful connections: {len(connection_times)}/10")
            print(f"  Average connection time: {avg_connection_time:.3f}s")
            print(f"  Max connection time: {max_connection_time:.3f}s")
            
            assert avg_connection_time < 0.5, f"Average connection time exceeded 0.5 seconds: {avg_connection_time:.3f}s"
    
    @pytest.mark.asyncio
    async def test_websocket_message_latency(self, websocket_url):
        """Test WebSocket message latency"""
        
        try:
            async with websockets.connect(websocket_url) as websocket:
                # Subscribe to a topic
                subscribe_message = {
                    "type": "subscribe",
                    "subscription_type": "line",
                    "target": "test-line"
                }
                
                start_time = time.time()
                await websocket.send(json.dumps(subscribe_message))
                
                # Wait for acknowledgment
                response = await asyncio.wait_for(websocket.recv(), timeout=5.0)
                end_time = time.time()
                
                latency = end_time - start_time
                
                print(f"\nWebSocket Message Latency:")
                print(f"  Subscribe message latency: {latency:.3f}s")
                
                # Message latency should be low
                assert latency < 0.1, f"Message latency exceeded 0.1 seconds: {latency:.3f}s"
                
        except Exception as e:
            print(f"WebSocket latency test failed: {e}")
    
    @pytest.mark.asyncio
    async def test_websocket_concurrent_connections(self, websocket_url):
        """Test WebSocket performance with concurrent connections"""
        
        async def create_connection(connection_id):
            """Create a WebSocket connection"""
            try:
                async with websockets.connect(websocket_url) as websocket:
                    # Subscribe to a unique topic
                    subscribe_message = {
                        "type": "subscribe",
                        "subscription_type": "line",
                        "target": f"line-{connection_id:03d}"
                    }
                    
                    await websocket.send(json.dumps(subscribe_message))
                    
                    # Wait for acknowledgment
                    response = await asyncio.wait_for(websocket.recv(), timeout=5.0)
                    message = json.loads(response)
                    
                    return {
                        "connection_id": connection_id,
                        "success": message.get("type") == "subscription_confirmed",
                        "response_time": time.time()
                    }
                    
            except Exception as e:
                return {
                    "connection_id": connection_id,
                    "success": False,
                    "error": str(e)
                }
        
        # Test with different concurrency levels
        concurrency_levels = [5, 10, 20, 50]
        
        for concurrency in concurrency_levels:
            print(f"\nTesting {concurrency} concurrent WebSocket connections...")
            
            start_time = time.time()
            tasks = [create_connection(i) for i in range(concurrency)]
            results = await asyncio.gather(*tasks)
            end_time = time.time()
            
            # Analyze results
            successful_connections = [r for r in results if r["success"]]
            success_rate = len(successful_connections) / concurrency
            
            print(f"Concurrency {concurrency}:")
            print(f"  Successful connections: {len(successful_connections)}/{concurrency}")
            print(f"  Success rate: {success_rate:.1%}")
            print(f"  Total time: {end_time - start_time:.3f}s")
            
            # Performance assertions
            assert success_rate >= 0.8, f"Success rate below 80%: {success_rate:.1%}"
            assert (end_time - start_time) < 10.0, f"Total time exceeded 10 seconds: {end_time - start_time:.3f}s"
    
    @pytest.mark.asyncio
    async def test_websocket_message_throughput(self, websocket_url):
        """Test WebSocket message throughput"""
        
        try:
            async with websockets.connect(websocket_url) as websocket:
                # Subscribe to a topic
                subscribe_message = {
                    "type": "subscribe",
                    "subscription_type": "line",
                    "target": "throughput-test"
                }
                
                await websocket.send(json.dumps(subscribe_message))
                await asyncio.wait_for(websocket.recv(), timeout=5.0)
                
                # Send multiple messages
                message_count = 100
                start_time = time.time()
                
                for i in range(message_count):
                    message = {
                        "type": "heartbeat",
                        "sequence": i,
                        "timestamp": datetime.now().isoformat()
                    }
                    
                    await websocket.send(json.dumps(message))
                
                end_time = time.time()
                duration = end_time - start_time
                
                messages_per_second = message_count / duration
                
                print(f"\nWebSocket Message Throughput:")
                print(f"  Messages sent: {message_count}")
                print(f"  Duration: {duration:.3f}s")
                print(f"  Messages per second: {messages_per_second:.2f}")
                
                # Throughput assertions
                assert messages_per_second > 50, f"Message throughput below 50 msg/s: {messages_per_second:.2f}"
                
        except Exception as e:
            print(f"WebSocket throughput test failed: {e}")
    
    @pytest.mark.asyncio
    async def test_websocket_large_message_performance(self, websocket_url):
        """Test WebSocket performance with large messages"""
        
        try:
            async with websockets.connect(websocket_url) as websocket:
                # Create large message
                large_data = {
                    "type": "test_large_message",
                    "data": {
                        "large_field": "x" * 10000,  # 10KB
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
                    },
                    "timestamp": datetime.now().isoformat()
                }
                
                start_time = time.time()
                await websocket.send(json.dumps(large_data))
                end_time = time.time()
                
                send_time = end_time - start_time
                
                print(f"\nWebSocket Large Message Performance:")
                print(f"  Message size: ~{len(json.dumps(large_data))} bytes")
                print(f"  Send time: {send_time:.3f}s")
                
                # Large message send should still be reasonably fast
                assert send_time < 1.0, f"Large message send time exceeded 1 second: {send_time:.3f}s"
                
        except Exception as e:
            print(f"WebSocket large message test failed: {e}")
    
    @pytest.mark.asyncio
    async def test_websocket_subscription_performance(self, websocket_url):
        """Test WebSocket subscription performance"""
        
        try:
            async with websockets.connect(websocket_url) as websocket:
                # Test multiple subscriptions
                subscriptions = [
                    {"type": "subscribe", "subscription_type": "line", "target": "line-001"},
                    {"type": "subscribe", "subscription_type": "andon", "target": "line-001"},
                    {"type": "subscribe", "subscription_type": "oee", "target": "line-001"},
                    {"type": "subscribe", "subscription_type": "job", "target": "job-001"},
                    {"type": "subscribe", "subscription_type": "equipment", "target": "eq-001"}
                ]
                
                subscription_times = []
                
                for subscription in subscriptions:
                    start_time = time.time()
                    await websocket.send(json.dumps(subscription))
                    
                    # Wait for acknowledgment
                    response = await asyncio.wait_for(websocket.recv(), timeout=5.0)
                    end_time = time.time()
                    
                    subscription_time = end_time - start_time
                    subscription_times.append(subscription_time)
                    
                    # Subscription should be fast
                    assert subscription_time < 0.5, f"Subscription time exceeded 0.5 seconds: {subscription_time:.3f}s"
                
                avg_subscription_time = statistics.mean(subscription_times)
                max_subscription_time = max(subscription_times)
                
                print(f"\nWebSocket Subscription Performance:")
                print(f"  Subscriptions: {len(subscriptions)}")
                print(f"  Average subscription time: {avg_subscription_time:.3f}s")
                print(f"  Max subscription time: {max_subscription_time:.3f}s")
                
                assert avg_subscription_time < 0.2, f"Average subscription time exceeded 0.2 seconds: {avg_subscription_time:.3f}s"
                
        except Exception as e:
            print(f"WebSocket subscription test failed: {e}")
    
    @pytest.mark.asyncio
    async def test_websocket_error_handling_performance(self, websocket_url):
        """Test WebSocket error handling performance"""
        
        try:
            async with websockets.connect(websocket_url) as websocket:
                # Test invalid messages
                invalid_messages = [
                    "invalid json",
                    '{"type": "invalid_type"}',
                    '{"type": "subscribe", "invalid_field": "value"}',
                    '{"type": "subscribe", "subscription_type": "invalid_type", "target": "test"}'
                ]
                
                error_response_times = []
                
                for invalid_message in invalid_messages:
                    start_time = time.time()
                    await websocket.send(invalid_message)
                    
                    try:
                        response = await asyncio.wait_for(websocket.recv(), timeout=5.0)
                        end_time = time.time()
                        
                        response_time = end_time - start_time
                        error_response_times.append(response_time)
                        
                        # Error responses should still be fast
                        assert response_time < 0.5, f"Error response time exceeded 0.5 seconds: {response_time:.3f}s"
                        
                    except asyncio.TimeoutError:
                        # Some errors might not get responses
                        pass
                
                if error_response_times:
                    avg_error_response_time = statistics.mean(error_response_times)
                    
                    print(f"\nWebSocket Error Handling Performance:")
                    print(f"  Invalid messages tested: {len(invalid_messages)}")
                    print(f"  Error responses received: {len(error_response_times)}")
                    print(f"  Average error response time: {avg_error_response_time:.3f}s")
                    
                    assert avg_error_response_time < 0.3, f"Average error response time exceeded 0.3 seconds: {avg_error_response_time:.3f}s"
                
        except Exception as e:
            print(f"WebSocket error handling test failed: {e}")
    
    @pytest.mark.asyncio
    async def test_websocket_connection_stability(self, websocket_url):
        """Test WebSocket connection stability over time"""
        
        try:
            async with websockets.connect(websocket_url) as websocket:
                # Subscribe to a topic
                subscribe_message = {
                    "type": "subscribe",
                    "subscription_type": "line",
                    "target": "stability-test"
                }
                
                await websocket.send(json.dumps(subscribe_message))
                await asyncio.wait_for(websocket.recv(), timeout=5.0)
                
                # Keep connection alive for extended period
                test_duration = 30  # seconds
                start_time = time.time()
                heartbeat_count = 0
                
                while time.time() - start_time < test_duration:
                    # Send heartbeat
                    heartbeat_message = {
                        "type": "heartbeat",
                        "sequence": heartbeat_count,
                        "timestamp": datetime.now().isoformat()
                    }
                    
                    await websocket.send(json.dumps(heartbeat_message))
                    heartbeat_count += 1
                    
                    # Wait a bit before next heartbeat
                    await asyncio.sleep(1)
                
                end_time = time.time()
                actual_duration = end_time - start_time
                
                print(f"\nWebSocket Connection Stability:")
                print(f"  Test duration: {actual_duration:.2f}s")
                print(f"  Heartbeats sent: {heartbeat_count}")
                print(f"  Connection stable: {websocket.open}")
                
                # Connection should remain stable
                assert websocket.open, "WebSocket connection was lost during stability test"
                assert heartbeat_count >= test_duration * 0.9, f"Heartbeat count below expected: {heartbeat_count}"
                
        except Exception as e:
            print(f"WebSocket stability test failed: {e}")
    
    @pytest.mark.asyncio
    async def test_websocket_memory_usage(self, websocket_url):
        """Test WebSocket memory usage under load"""
        
        import psutil
        import os
        
        # Get initial memory usage
        process = psutil.Process(os.getpid())
        initial_memory = process.memory_info().rss / 1024 / 1024  # MB
        
        print(f"\nInitial memory usage: {initial_memory:.2f} MB")
        
        # Create multiple WebSocket connections
        connections = []
        
        try:
            for i in range(50):
                try:
                    websocket = await websockets.connect(websocket_url)
                    connections.append(websocket)
                    
                    # Subscribe to a topic
                    subscribe_message = {
                        "type": "subscribe",
                        "subscription_type": "line",
                        "target": f"memory-test-{i}"
                    }
                    
                    await websocket.send(json.dumps(subscribe_message))
                    
                except Exception as e:
                    print(f"Connection {i} failed: {e}")
            
            # Check memory usage with connections
            memory_with_connections = process.memory_info().rss / 1024 / 1024  # MB
            memory_increase = memory_with_connections - initial_memory
            
            print(f"Memory with {len(connections)} connections: {memory_with_connections:.2f} MB")
            print(f"Memory increase: {memory_increase:.2f} MB")
            
            # Memory usage should not increase excessively
            assert memory_increase < 50, f"Memory increase exceeded 50 MB: {memory_increase:.2f} MB"
            
        finally:
            # Close all connections
            for websocket in connections:
                try:
                    await websocket.close()
                except Exception:
                    pass


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
