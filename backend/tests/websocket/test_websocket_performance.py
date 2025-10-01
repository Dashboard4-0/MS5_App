"""
MS5.0 Floor Dashboard - WebSocket Performance Benchmarks

Comprehensive performance benchmarks for WebSocket system to ensure
cosmic scale operations and production readiness.

Architected for cosmic scale operations - the nervous system of a starship.
"""

import pytest
import asyncio
import json
import time
import statistics
from typing import Dict, Any, List, Tuple
from datetime import datetime, timedelta
from unittest.mock import Mock, AsyncMock

from app.services.enhanced_websocket_manager import enhanced_websocket_manager, MessagePriority
from app.services.realtime_event_broadcaster import realtime_broadcaster
from app.services.websocket_health_monitor import websocket_health_monitor


class WebSocketPerformanceBenchmark:
    """
    Comprehensive performance benchmark suite for WebSocket system.
    
    Benchmarks:
    - Message throughput and latency
    - Connection scaling
    - Memory usage
    - CPU utilization
    - Error rates under load
    """
    
    def __init__(self):
        self.benchmark_results: Dict[str, Any] = {}
        self.test_connections: List[str] = []
    
    async def setup_benchmark_environment(self):
        """Set up benchmark environment."""
        # Clear existing connections
        enhanced_websocket_manager.active_connections.clear()
        enhanced_websocket_manager.user_connections.clear()
        enhanced_websocket_manager.subscriptions.clear()
        
        # Reset health monitor
        websocket_health_monitor.health_scores.clear()
        websocket_health_monitor.metrics.clear()
    
    async def cleanup_benchmark_environment(self):
        """Clean up benchmark environment."""
        for connection_id in self.test_connections:
            enhanced_websocket_manager.remove_connection(connection_id)
        self.test_connections.clear()
        
        enhanced_websocket_manager.active_connections.clear()
        enhanced_websocket_manager.user_connections.clear()
        enhanced_websocket_manager.subscriptions.clear()
    
    async def create_benchmark_connections(self, count: int) -> List[str]:
        """Create benchmark connections."""
        connections = []
        for i in range(count):
            mock_websocket = Mock()
            mock_websocket.send_text = AsyncMock()
            mock_websocket.close = AsyncMock()
            
            connection_id = await enhanced_websocket_manager.add_connection(mock_websocket, f"benchmark_user_{i}")
            connections.append(connection_id)
            self.test_connections.append(connection_id)
        
        return connections
    
    async def benchmark_message_throughput(self, connection_count: int = 10, message_count: int = 1000) -> Dict[str, Any]:
        """Benchmark message throughput under various loads."""
        print(f"📊 Benchmarking Message Throughput ({connection_count} connections, {message_count} messages)...")
        
        try:
            # Create connections
            connections = await self.create_benchmark_connections(connection_count)
            
            # Set up subscriptions
            for conn_id in connections:
                enhanced_websocket_manager.subscribe_to_line(conn_id, "LINE_001")
            
            # Benchmark message sending
            start_time = time.time()
            messages_sent = 0
            
            for i in range(message_count):
                conn_id = connections[i % len(connections)]
                
                await enhanced_websocket_manager.send_personal_message(
                    {
                        "type": "benchmark_message",
                        "data": f"message_{i}",
                        "timestamp": datetime.utcnow().isoformat()
                    },
                    conn_id,
                    MessagePriority.NORMAL
                )
                messages_sent += 1
            
            end_time = time.time()
            duration = end_time - start_time
            
            # Calculate metrics
            throughput = messages_sent / duration
            avg_latency = duration / messages_sent * 1000  # ms
            
            # Memory usage
            memory_usage = websocket_health_monitor._estimate_memory_usage()
            
            results = {
                "messages_sent": messages_sent,
                "duration": duration,
                "throughput": throughput,
                "avg_latency_ms": avg_latency,
                "memory_usage_mb": memory_usage,
                "connection_count": connection_count
            }
            
            print(f"  ✅ Throughput: {throughput:.1f} msg/s, Latency: {avg_latency:.2f} ms")
            
            return results
            
        except Exception as e:
            print(f"  ❌ Message throughput benchmark failed: {e}")
            return {"error": str(e)}
    
    async def benchmark_connection_scaling(self, max_connections: int = 100) -> Dict[str, Any]:
        """Benchmark connection scaling performance."""
        print(f"📊 Benchmarking Connection Scaling (up to {max_connections} connections)...")
        
        try:
            scaling_results = []
            connection_counts = [10, 25, 50, 75, max_connections]
            
            for count in connection_counts:
                print(f"  Testing {count} connections...")
                
                # Create connections
                connections = await self.create_benchmark_connections(count)
                
                # Measure connection setup time
                setup_start = time.time()
                for conn_id in connections:
                    enhanced_websocket_manager.subscribe_to_line(conn_id, "LINE_001")
                setup_end = time.time()
                
                setup_time = setup_end - setup_start
                
                # Measure message sending with all connections
                message_start = time.time()
                for i, conn_id in enumerate(connections):
                    await enhanced_websocket_manager.send_personal_message(
                        {"type": "scaling_test", "data": f"message_{i}"},
                        conn_id,
                        MessagePriority.NORMAL
                    )
                message_end = time.time()
                
                message_time = message_end - message_start
                
                # Get system stats
                stats = enhanced_websocket_manager.get_connection_stats()
                memory_usage = websocket_health_monitor._estimate_memory_usage()
                
                scaling_results.append({
                    "connection_count": count,
                    "setup_time": setup_time,
                    "message_time": message_time,
                    "total_connections": stats["total_connections"],
                    "memory_usage_mb": memory_usage,
                    "avg_setup_time_per_connection": setup_time / count,
                    "avg_message_time_per_connection": message_time / count
                })
            
            # Calculate scaling efficiency
            efficiency_scores = []
            for i in range(1, len(scaling_results)):
                prev = scaling_results[i-1]
                curr = scaling_results[i]
                
                # Calculate efficiency based on setup time per connection
                efficiency = prev["avg_setup_time_per_connection"] / curr["avg_setup_time_per_connection"]
                efficiency_scores.append(efficiency)
            
            avg_efficiency = statistics.mean(efficiency_scores) if efficiency_scores else 1.0
            
            results = {
                "scaling_results": scaling_results,
                "avg_efficiency": avg_efficiency,
                "max_connections_tested": max_connections,
                "scaling_performance": "good" if avg_efficiency >= 0.8 else "poor"
            }
            
            print(f"  ✅ Connection scaling efficiency: {avg_efficiency:.2f}")
            
            return results
            
        except Exception as e:
            print(f"  ❌ Connection scaling benchmark failed: {e}")
            return {"error": str(e)}
    
    async def benchmark_memory_usage(self) -> Dict[str, Any]:
        """Benchmark memory usage under various scenarios."""
        print("📊 Benchmarking Memory Usage...")
        
        try:
            memory_results = []
            
            # Test scenarios
            scenarios = [
                {"connections": 10, "messages": 100, "subscriptions": 50},
                {"connections": 50, "messages": 500, "subscriptions": 250},
                {"connections": 100, "messages": 1000, "subscriptions": 500},
            ]
            
            for scenario in scenarios:
                print(f"  Testing scenario: {scenario}")
                
                # Create connections
                connections = await self.create_benchmark_connections(scenario["connections"])
                
                # Set up subscriptions
                subscription_count = 0
                for i, conn_id in enumerate(connections):
                    # Multiple subscriptions per connection
                    subscriptions_per_conn = scenario["subscriptions"] // scenario["connections"]
                    for j in range(subscriptions_per_conn):
                        if j % 4 == 0:
                            enhanced_websocket_manager.subscribe_to_line(conn_id, f"LINE_{j:03d}")
                        elif j % 4 == 1:
                            enhanced_websocket_manager.subscribe_to_equipment(conn_id, f"EQ_{j:03d}")
                        elif j % 4 == 2:
                            enhanced_websocket_manager.subscribe_to_downtime(conn_id, line_id=f"LINE_{j:03d}")
                        else:
                            enhanced_websocket_manager.subscribe_to_andon(conn_id, line_id=f"LINE_{j:03d}")
                        subscription_count += 1
                
                # Send messages
                for i in range(scenario["messages"]):
                    conn_id = connections[i % len(connections)]
                    await enhanced_websocket_manager.send_personal_message(
                        {"type": "memory_test", "data": f"message_{i}"},
                        conn_id,
                        MessagePriority.NORMAL
                    )
                
                # Measure memory usage
                memory_usage = websocket_health_monitor._estimate_memory_usage()
                
                memory_results.append({
                    "connections": scenario["connections"],
                    "subscriptions": subscription_count,
                    "messages_sent": scenario["messages"],
                    "memory_usage_mb": memory_usage,
                    "memory_per_connection_mb": memory_usage / scenario["connections"],
                    "memory_per_subscription_kb": (memory_usage * 1024) / subscription_count if subscription_count > 0 else 0
                })
            
            # Calculate memory efficiency
            memory_efficiency = []
            for result in memory_results:
                # Good memory efficiency: < 1MB per connection, < 10KB per subscription
                efficiency = 1.0
                if result["memory_per_connection_mb"] > 1.0:
                    efficiency -= 0.3
                if result["memory_per_subscription_kb"] > 10.0:
                    efficiency -= 0.3
                memory_efficiency.append(max(0.0, efficiency))
            
            avg_memory_efficiency = statistics.mean(memory_efficiency)
            
            results = {
                "memory_results": memory_results,
                "avg_memory_efficiency": avg_memory_efficiency,
                "memory_performance": "good" if avg_memory_efficiency >= 0.7 else "poor"
            }
            
            print(f"  ✅ Memory efficiency: {avg_memory_efficiency:.2f}")
            
            return results
            
        except Exception as e:
            print(f"  ❌ Memory usage benchmark failed: {e}")
            return {"error": str(e)}
    
    async def benchmark_error_rates_under_load(self, connection_count: int = 50, message_count: int = 2000) -> Dict[str, Any]:
        """Benchmark error rates under high load."""
        print(f"📊 Benchmarking Error Rates Under Load ({connection_count} connections, {message_count} messages)...")
        
        try:
            # Create connections
            connections = await self.create_benchmark_connections(connection_count)
            
            # Set up subscriptions
            for conn_id in connections:
                enhanced_websocket_manager.subscribe_to_line(conn_id, "LINE_001")
            
            # Send messages rapidly to create load
            start_time = time.time()
            messages_sent = 0
            errors = 0
            
            for i in range(message_count):
                try:
                    conn_id = connections[i % len(connections)]
                    
                    # Occasionally send to non-existent connection to test error handling
                    if i % 100 == 0:
                        await enhanced_websocket_manager.send_personal_message(
                            {"type": "error_test", "data": f"message_{i}"},
                            "non_existent_connection",
                            MessagePriority.NORMAL
                        )
                    else:
                        await enhanced_websocket_manager.send_personal_message(
                            {"type": "load_test", "data": f"message_{i}"},
                            conn_id,
                            MessagePriority.NORMAL
                        )
                    
                    messages_sent += 1
                    
                except Exception:
                    errors += 1
            
            end_time = time.time()
            duration = end_time - start_time
            
            # Calculate error rate
            error_rate = errors / message_count if message_count > 0 else 0
            throughput = messages_sent / duration
            
            # Get system health
            health_metrics = await websocket_health_monitor.get_system_health()
            
            results = {
                "messages_sent": messages_sent,
                "errors": errors,
                "error_rate": error_rate,
                "duration": duration,
                "throughput": throughput,
                "system_health": health_metrics.system_status.value,
                "connection_count": connection_count,
                "error_performance": "good" if error_rate < 0.01 else "poor"  # < 1% error rate
            }
            
            print(f"  ✅ Error rate: {error_rate:.2%}, Throughput: {throughput:.1f} msg/s")
            
            return results
            
        except Exception as e:
            print(f"  ❌ Error rates benchmark failed: {e}")
            return {"error": str(e)}
    
    async def benchmark_priority_message_handling(self) -> Dict[str, Any]:
        """Benchmark priority-based message handling."""
        print("📊 Benchmarking Priority Message Handling...")
        
        try:
            # Create connections
            connections = await self.create_benchmark_connections(10)
            
            # Set up subscriptions
            for conn_id in connections:
                enhanced_websocket_manager.subscribe_to_line(conn_id, "LINE_001")
            
            # Test different priorities
            priorities = [
                (MessagePriority.CRITICAL, 100),
                (MessagePriority.HIGH, 200),
                (MessagePriority.NORMAL, 300),
                (MessagePriority.LOW, 400)
            ]
            
            priority_results = {}
            
            for priority, message_count in priorities:
                print(f"  Testing {priority.name} priority ({message_count} messages)...")
                
                start_time = time.time()
                
                for i in range(message_count):
                    conn_id = connections[i % len(connections)]
                    await enhanced_websocket_manager.send_personal_message(
                        {
                            "type": f"{priority.name.lower()}_message",
                            "data": f"message_{i}",
                            "priority": priority.value
                        },
                        conn_id,
                        priority
                    )
                
                end_time = time.time()
                duration = end_time - start_time
                
                throughput = message_count / duration
                
                priority_results[priority.name.lower()] = {
                    "message_count": message_count,
                    "duration": duration,
                    "throughput": throughput,
                    "avg_latency_ms": duration / message_count * 1000
                }
            
            # Calculate priority efficiency
            # Critical messages should have highest throughput
            critical_throughput = priority_results["critical"]["throughput"]
            normal_throughput = priority_results["normal"]["throughput"]
            
            priority_efficiency = critical_throughput / normal_throughput if normal_throughput > 0 else 1.0
            
            results = {
                "priority_results": priority_results,
                "priority_efficiency": priority_efficiency,
                "priority_performance": "good" if priority_efficiency >= 1.0 else "poor"
            }
            
            print(f"  ✅ Priority efficiency: {priority_efficiency:.2f}")
            
            return results
            
        except Exception as e:
            print(f"  ❌ Priority message handling benchmark failed: {e}")
            return {"error": str(e)}
    
    async def run_complete_benchmark_suite(self) -> Dict[str, Any]:
        """Run complete performance benchmark suite."""
        print("🚀 Starting WebSocket Performance Benchmark Suite")
        print("=" * 60)
        
        await self.setup_benchmark_environment()
        
        benchmark_results = {}
        
        try:
            # Run all benchmarks
            benchmark_results["message_throughput"] = await self.benchmark_message_throughput()
            benchmark_results["connection_scaling"] = await self.benchmark_connection_scaling()
            benchmark_results["memory_usage"] = await self.benchmark_memory_usage()
            benchmark_results["error_rates"] = await self.benchmark_error_rates_under_load()
            benchmark_results["priority_handling"] = await self.benchmark_priority_message_handling()
            
        finally:
            await self.cleanup_benchmark_environment()
        
        # Generate performance report
        return self.generate_performance_report(benchmark_results)
    
    def generate_performance_report(self, results: Dict[str, Any]) -> Dict[str, Any]:
        """Generate comprehensive performance report."""
        print("\n📊 Performance Benchmark Report")
        print("=" * 60)
        
        # Analyze results
        performance_scores = {}
        recommendations = []
        
        # Message throughput analysis
        if "message_throughput" in results and "error" not in results["message_throughput"]:
            throughput = results["message_throughput"]["throughput"]
            if throughput >= 1000:
                performance_scores["throughput"] = "excellent"
            elif throughput >= 500:
                performance_scores["throughput"] = "good"
            elif throughput >= 100:
                performance_scores["throughput"] = "fair"
            else:
                performance_scores["throughput"] = "poor"
                recommendations.append("Optimize message throughput - consider batching or async processing")
        
        # Connection scaling analysis
        if "connection_scaling" in results and "error" not in results["connection_scaling"]:
            efficiency = results["connection_scaling"]["avg_efficiency"]
            if efficiency >= 0.9:
                performance_scores["scaling"] = "excellent"
            elif efficiency >= 0.8:
                performance_scores["scaling"] = "good"
            elif efficiency >= 0.7:
                performance_scores["scaling"] = "fair"
            else:
                performance_scores["scaling"] = "poor"
                recommendations.append("Improve connection scaling efficiency - optimize connection management")
        
        # Memory usage analysis
        if "memory_usage" in results and "error" not in results["memory_usage"]:
            efficiency = results["memory_usage"]["avg_memory_efficiency"]
            if efficiency >= 0.8:
                performance_scores["memory"] = "excellent"
            elif efficiency >= 0.7:
                performance_scores["memory"] = "good"
            elif efficiency >= 0.6:
                performance_scores["memory"] = "fair"
            else:
                performance_scores["memory"] = "poor"
                recommendations.append("Optimize memory usage - review connection and subscription management")
        
        # Error rates analysis
        if "error_rates" in results and "error" not in results["error_rates"]:
            error_rate = results["error_rates"]["error_rate"]
            if error_rate < 0.001:  # < 0.1%
                performance_scores["reliability"] = "excellent"
            elif error_rate < 0.01:  # < 1%
                performance_scores["reliability"] = "good"
            elif error_rate < 0.05:  # < 5%
                performance_scores["reliability"] = "fair"
            else:
                performance_scores["reliability"] = "poor"
                recommendations.append("Reduce error rates - improve error handling and connection stability")
        
        # Priority handling analysis
        if "priority_handling" in results and "error" not in results["priority_handling"]:
            efficiency = results["priority_handling"]["priority_efficiency"]
            if efficiency >= 1.2:
                performance_scores["priority"] = "excellent"
            elif efficiency >= 1.0:
                performance_scores["priority"] = "good"
            elif efficiency >= 0.8:
                performance_scores["priority"] = "fair"
            else:
                performance_scores["priority"] = "poor"
                recommendations.append("Improve priority message handling - optimize message queuing")
        
        # Calculate overall performance score
        score_values = {"excellent": 4, "good": 3, "fair": 2, "poor": 1}
        overall_score = statistics.mean([score_values.get(score, 0) for score in performance_scores.values()])
        
        if overall_score >= 3.5:
            overall_rating = "EXCELLENT"
        elif overall_score >= 3.0:
            overall_rating = "GOOD"
        elif overall_score >= 2.5:
            overall_rating = "FAIR"
        else:
            overall_rating = "POOR"
        
        # Print report
        print(f"\nPerformance Scores:")
        for category, score in performance_scores.items():
            print(f"  {category.title()}: {score.upper()}")
        
        print(f"\nOverall Performance Rating: {overall_rating}")
        
        if recommendations:
            print(f"\nRecommendations:")
            for rec in recommendations:
                print(f"  • {rec}")
        
        return {
            "overall_rating": overall_rating,
            "overall_score": overall_score,
            "performance_scores": performance_scores,
            "benchmark_results": results,
            "recommendations": recommendations,
            "timestamp": datetime.utcnow().isoformat()
        }


# Pytest integration
@pytest.mark.asyncio
async def test_websocket_performance_benchmarks():
    """Pytest test for WebSocket performance benchmarks."""
    benchmark = WebSocketPerformanceBenchmark()
    results = await benchmark.run_complete_benchmark_suite()
    
    # Assert performance meets requirements
    assert results["overall_score"] >= 2.5, f"Performance score too low: {results['overall_score']}"
    
    # Assert critical performance metrics
    assert "throughput" in results["performance_scores"], "Throughput benchmark missing"
    assert "scaling" in results["performance_scores"], "Scaling benchmark missing"
    assert "memory" in results["performance_scores"], "Memory benchmark missing"
    assert "reliability" in results["performance_scores"], "Reliability benchmark missing"


if __name__ == "__main__":
    # Run benchmarks when executed directly
    async def main():
        benchmark = WebSocketPerformanceBenchmark()
        await benchmark.run_complete_benchmark_suite()
    
    asyncio.run(main())
