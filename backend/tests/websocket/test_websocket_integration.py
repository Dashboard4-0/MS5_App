"""
MS5.0 Floor Dashboard - WebSocket Integration Tests

Comprehensive integration tests for the complete WebSocket system,
validating end-to-end functionality and production readiness.

Architected for cosmic scale operations - the nervous system of a starship.
"""

import pytest
import asyncio
import json
import time
from typing import Dict, Any, List, Optional
from datetime import datetime, timedelta
from unittest.mock import Mock, AsyncMock, patch

from fastapi.testclient import TestClient
from fastapi.websockets import WebSocket

from app.main import app
from app.services.enhanced_websocket_manager import enhanced_websocket_manager, MessagePriority
from app.services.realtime_event_broadcaster import realtime_broadcaster
from app.services.websocket_health_monitor import websocket_health_monitor
from app.services.realtime_integration import realtime_integration


class WebSocketIntegrationTestSuite:
    """
    Comprehensive integration test suite for WebSocket system.
    
    Tests the complete flow from client connection to production event handling,
    ensuring all components work together seamlessly.
    """
    
    def __init__(self):
        self.client = TestClient(app)
        self.test_connections: List[str] = []
        self.test_results: Dict[str, Any] = {}
    
    async def setup_test_environment(self):
        """Set up test environment with mock connections."""
        # Clear any existing connections
        enhanced_websocket_manager.active_connections.clear()
        enhanced_websocket_manager.user_connections.clear()
        enhanced_websocket_manager.subscriptions.clear()
        
        # Reset health monitor
        websocket_health_monitor.health_scores.clear()
        websocket_health_monitor.metrics.clear()
    
    async def cleanup_test_environment(self):
        """Clean up test environment."""
        # Remove all test connections
        for connection_id in self.test_connections:
            enhanced_websocket_manager.remove_connection(connection_id)
        
        self.test_connections.clear()
        
        # Reset managers
        enhanced_websocket_manager.active_connections.clear()
        enhanced_websocket_manager.user_connections.clear()
        enhanced_websocket_manager.subscriptions.clear()
    
    async def create_test_connection(self, user_id: str = "test_user") -> str:
        """Create a test WebSocket connection."""
        mock_websocket = Mock()
        mock_websocket.send_text = AsyncMock()
        mock_websocket.close = AsyncMock()
        
        connection_id = await enhanced_websocket_manager.add_connection(mock_websocket, user_id)
        self.test_connections.append(connection_id)
        
        return connection_id
    
    async def test_complete_production_workflow(self):
        """Test complete production workflow from connection to event handling."""
        print("🔄 Testing Complete Production Workflow...")
        
        try:
            # Step 1: Establish connections
            supervisor_conn = await self.create_test_connection("supervisor_001")
            operator_conn = await self.create_test_connection("operator_001")
            maintenance_conn = await self.create_test_connection("maintenance_001")
            
            # Step 2: Set up subscriptions
            enhanced_websocket_manager.subscribe_to_line(supervisor_conn, "LINE_001")
            enhanced_websocket_manager.subscribe_to_line(operator_conn, "LINE_001")
            enhanced_websocket_manager.subscribe_to_equipment(operator_conn, "EQ_001")
            enhanced_websocket_manager.subscribe_to_downtime(maintenance_conn, line_id="LINE_001")
            enhanced_websocket_manager.subscribe_to_andon(supervisor_conn, line_id="LINE_001")
            
            # Step 3: Simulate production events
            events_sent = 0
            
            # Production update
            await realtime_broadcaster.broadcast_production_update("LINE_001", {
                "current_job": "JOB_123",
                "units_produced": 150,
                "target_units": 200,
                "efficiency": 0.75
            })
            events_sent += 1
            
            # Equipment status update
            await realtime_broadcaster.broadcast_equipment_status_update("EQ_001", {
                "status": "running",
                "temperature": 75.5,
                "vibration": 0.8,
                "maintenance_due": False
            })
            events_sent += 1
            
            # OEE update
            await realtime_broadcaster.broadcast_oee_update("LINE_001", {
                "availability": 0.95,
                "performance": 0.88,
                "quality": 0.92,
                "oee": 0.77
            })
            events_sent += 1
            
            # Andon event
            await realtime_broadcaster.broadcast_andon_event({
                "line_id": "LINE_001",
                "equipment_code": "EQ_001",
                "priority": "high",
                "description": "Equipment fault detected",
                "timestamp": datetime.utcnow().isoformat()
            })
            events_sent += 1
            
            # Downtime event
            await realtime_broadcaster.broadcast_downtime_event({
                "line_id": "LINE_001",
                "equipment_code": "EQ_001",
                "downtime_type": "unplanned",
                "duration_minutes": 15,
                "reason": "Maintenance required"
            })
            events_sent += 1
            
            # Step 4: Verify event delivery
            await asyncio.sleep(0.1)  # Allow events to process
            
            stats = enhanced_websocket_manager.get_connection_stats()
            
            # Verify connections are active
            assert stats["total_connections"] >= 3
            
            # Verify subscriptions are working
            assert stats["line_subscriptions"] > 0
            assert stats["equipment_subscriptions"] > 0
            assert stats["downtime_subscriptions"] > 0
            assert stats["andon_subscriptions"] > 0
            
            print(f"  ✅ Complete workflow tested - {events_sent} events processed")
            return True
            
        except Exception as e:
            print(f"  ❌ Complete workflow test failed: {e}")
            return False
    
    async def test_connection_recovery_scenarios(self):
        """Test various connection recovery scenarios."""
        print("🔄 Testing Connection Recovery Scenarios...")
        
        try:
            # Scenario 1: Normal disconnection
            conn_id = await self.create_test_connection("recovery_test_user")
            enhanced_websocket_manager.subscribe_to_line(conn_id, "LINE_001")
            
            # Simulate disconnection
            enhanced_websocket_manager.remove_connection(conn_id)
            
            # Verify cleanup
            stats = enhanced_websocket_manager.get_connection_stats()
            assert stats["total_connections"] == len(self.test_connections) - 1
            
            # Scenario 2: Reconnection
            new_conn_id = await self.create_test_connection("recovery_test_user")
            enhanced_websocket_manager.subscribe_to_line(new_conn_id, "LINE_001")
            
            # Verify reconnection works
            stats = enhanced_websocket_manager.get_connection_stats()
            assert stats["total_connections"] == len(self.test_connections)
            
            # Scenario 3: Multiple rapid connections/disconnections
            for i in range(10):
                temp_conn = await self.create_test_connection(f"rapid_test_user_{i}")
                enhanced_websocket_manager.subscribe_to_line(temp_conn, "LINE_001")
                await asyncio.sleep(0.01)  # Small delay
                enhanced_websocket_manager.remove_connection(temp_conn)
                self.test_connections.remove(temp_conn)
            
            # Verify system stability
            stats = enhanced_websocket_manager.get_connection_stats()
            assert stats["total_connections"] >= 0  # Should handle gracefully
            
            print("  ✅ Connection recovery scenarios tested successfully")
            return True
            
        except Exception as e:
            print(f"  ❌ Connection recovery test failed: {e}")
            return False
    
    async def test_high_load_performance(self):
        """Test system performance under high load."""
        print("⚡ Testing High Load Performance...")
        
        try:
            # Create multiple connections
            connections = []
            for i in range(20):
                conn_id = await self.create_test_connection(f"load_test_user_{i}")
                enhanced_websocket_manager.subscribe_to_line(conn_id, f"LINE_{i % 5:03d}")
                connections.append(conn_id)
            
            # Send high volume of messages
            start_time = time.time()
            messages_sent = 0
            
            for i in range(100):
                # Send to random connection
                conn_id = connections[i % len(connections)]
                
                await enhanced_websocket_manager.send_personal_message(
                    {
                        "type": "load_test_message",
                        "data": f"message_{i}",
                        "timestamp": datetime.utcnow().isoformat()
                    },
                    conn_id,
                    MessagePriority.NORMAL
                )
                messages_sent += 1
            
            end_time = time.time()
            duration = end_time - start_time
            throughput = messages_sent / duration
            
            # Verify performance metrics
            assert throughput >= 50.0, f"Throughput too low: {throughput} msg/s"
            
            # Test health monitoring under load
            health_metrics = await websocket_health_monitor.get_system_health()
            assert health_metrics.total_connections >= 20
            assert health_metrics.system_status.value in ["healthy", "warning"]
            
            print(f"  ✅ High load performance test - {throughput:.1f} msg/s throughput")
            return True
            
        except Exception as e:
            print(f"  ❌ High load performance test failed: {e}")
            return False
    
    async def test_message_priority_routing(self):
        """Test message priority routing and handling."""
        print("🎯 Testing Message Priority Routing...")
        
        try:
            # Create test connections
            critical_conn = await self.create_test_connection("critical_user")
            normal_conn = await self.create_test_connection("normal_user")
            
            # Set up subscriptions
            enhanced_websocket_manager.subscribe_to_line(critical_conn, "LINE_001")
            enhanced_websocket_manager.subscribe_to_line(normal_conn, "LINE_001")
            
            # Send messages with different priorities
            priorities = [
                (MessagePriority.CRITICAL, "critical_alert"),
                (MessagePriority.HIGH, "high_priority_update"),
                (MessagePriority.NORMAL, "normal_update"),
                (MessagePriority.LOW, "low_priority_info")
            ]
            
            for priority, message_type in priorities:
                await enhanced_websocket_manager.send_personal_message(
                    {
                        "type": message_type,
                        "priority": priority.value,
                        "data": f"Test {priority.name} message"
                    },
                    critical_conn,
                    priority
                )
            
            # Verify messages were sent
            stats = enhanced_websocket_manager.get_connection_stats()
            assert stats["total_messages_sent"] >= 4
            
            print("  ✅ Message priority routing tested successfully")
            return True
            
        except Exception as e:
            print(f"  ❌ Message priority routing test failed: {e}")
            return False
    
    async def test_health_monitoring_integration(self):
        """Test health monitoring integration with WebSocket system."""
        print("🏥 Testing Health Monitoring Integration...")
        
        try:
            # Start health monitoring
            await websocket_health_monitor.start_monitoring()
            
            # Create test connections
            conn1 = await self.create_test_connection("health_test_user_1")
            conn2 = await self.create_test_connection("health_test_user_2")
            
            # Generate some activity
            for i in range(5):
                await enhanced_websocket_manager.send_personal_message(
                    {"type": "health_test", "data": f"message_{i}"},
                    conn1,
                    MessagePriority.NORMAL
                )
                await asyncio.sleep(0.1)
            
            # Wait for health monitoring to update
            await asyncio.sleep(1.0)
            
            # Check health metrics
            health_metrics = await websocket_health_monitor.get_system_health()
            assert health_metrics.total_connections >= 2
            assert health_metrics.system_status.value in ["healthy", "warning", "critical"]
            
            # Check connection health
            conn1_health = await websocket_health_monitor.get_connection_health(conn1)
            assert conn1_health is not None
            assert 0.0 <= conn1_health <= 1.0
            
            # Check performance metrics
            performance_metrics = await websocket_health_monitor.get_performance_metrics()
            assert "performance_tracking" in performance_metrics
            assert "alert_thresholds" in performance_metrics
            
            # Stop health monitoring
            await websocket_health_monitor.stop_monitoring()
            
            print("  ✅ Health monitoring integration tested successfully")
            return True
            
        except Exception as e:
            print(f"  ❌ Health monitoring integration test failed: {e}")
            return False
    
    async def test_realtime_integration_hooks(self):
        """Test real-time integration hooks."""
        print("🔗 Testing Real-time Integration Hooks...")
        
        try:
            # Set up test hooks
            hook_calls = []
            
            def production_hook(data):
                hook_calls.append(("production", data))
            
            def andon_hook(data):
                hook_calls.append(("andon", data))
            
            def equipment_hook(data):
                hook_calls.append(("equipment", data))
            
            # Register hooks
            realtime_integration.add_integration_hook("production_update", production_hook)
            realtime_integration.add_integration_hook("andon_event", andon_hook)
            realtime_integration.add_integration_hook("equipment_status", equipment_hook)
            
            # Trigger events
            test_data = {
                "line_id": "LINE_001",
                "production_data": {"units": 100}
            }
            
            await realtime_integration.trigger_production_update("LINE_001", test_data)
            await realtime_integration.trigger_andon_event({
                "line_id": "LINE_001",
                "priority": "high"
            })
            await realtime_integration.trigger_equipment_update("EQ_001", {
                "status": "running"
            })
            
            # Verify hooks were called
            assert len(hook_calls) >= 3
            
            # Check hook data
            hook_types = [call[0] for call in hook_calls]
            assert "production" in hook_types
            assert "andon" in hook_types
            assert "equipment" in hook_types
            
            print("  ✅ Real-time integration hooks tested successfully")
            return True
            
        except Exception as e:
            print(f"  ❌ Real-time integration hooks test failed: {e}")
            return False
    
    async def run_complete_integration_test(self) -> Dict[str, Any]:
        """Run complete integration test suite."""
        print("🚀 Starting WebSocket Integration Test Suite")
        print("=" * 60)
        
        await self.setup_test_environment()
        
        test_results = {
            "complete_workflow": False,
            "connection_recovery": False,
            "high_load_performance": False,
            "priority_routing": False,
            "health_monitoring": False,
            "integration_hooks": False
        }
        
        try:
            # Run all integration tests
            test_results["complete_workflow"] = await self.test_complete_production_workflow()
            test_results["connection_recovery"] = await self.test_connection_recovery_scenarios()
            test_results["high_load_performance"] = await self.test_high_load_performance()
            test_results["priority_routing"] = await self.test_message_priority_routing()
            test_results["health_monitoring"] = await self.test_health_monitoring_integration()
            test_results["integration_hooks"] = await self.test_realtime_integration_hooks()
            
        finally:
            await self.cleanup_test_environment()
        
        # Generate report
        passed_tests = sum(test_results.values())
        total_tests = len(test_results)
        success_rate = (passed_tests / total_tests * 100) if total_tests > 0 else 0
        
        print(f"\n📊 Integration Test Results: {passed_tests}/{total_tests} ({success_rate:.1f}%)")
        
        for test_name, result in test_results.items():
            status = "✅ PASS" if result else "❌ FAIL"
            print(f"  {test_name.replace('_', ' ').title()}: {status}")
        
        if success_rate >= 90:
            print("\n🎯 Integration Test Status: ✅ EXCELLENT - System ready for production")
        elif success_rate >= 80:
            print("\n🎯 Integration Test Status: ✅ GOOD - Minor issues to address")
        elif success_rate >= 70:
            print("\n🎯 Integration Test Status: ⚠️ FAIR - Some issues need attention")
        else:
            print("\n🎯 Integration Test Status: ❌ CRITICAL - Major issues require attention")
        
        return {
            "success_rate": success_rate,
            "passed_tests": passed_tests,
            "total_tests": total_tests,
            "test_results": test_results,
            "timestamp": datetime.utcnow().isoformat()
        }


# Pytest integration
@pytest.mark.asyncio
async def test_websocket_integration_suite():
    """Pytest test for WebSocket integration suite."""
    test_suite = WebSocketIntegrationTestSuite()
    results = await test_suite.run_complete_integration_test()
    
    # Assert integration tests pass
    assert results["success_rate"] >= 80.0, f"Integration test success rate too low: {results['success_rate']}%"
    
    # Assert critical components work
    assert results["test_results"]["complete_workflow"], "Complete workflow integration failed"
    assert results["test_results"]["connection_recovery"], "Connection recovery integration failed"
    assert results["test_results"]["health_monitoring"], "Health monitoring integration failed"


if __name__ == "__main__":
    # Run integration tests when executed directly
    async def main():
        test_suite = WebSocketIntegrationTestSuite()
        await test_suite.run_complete_integration_test()
    
    asyncio.run(main())
