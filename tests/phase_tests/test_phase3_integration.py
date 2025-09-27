"""
MS5.0 Floor Dashboard - Phase 3 Real-time Integration Tests

This module provides comprehensive tests for Phase 3: Real-time Integration
including enhanced WebSocket functionality, production event broadcasting,
and real-time service integration.
"""

import asyncio
import json
import pytest
from unittest.mock import Mock, AsyncMock, patch
from datetime import datetime
from typing import Dict, Any

from app.services.enhanced_websocket_manager import EnhancedWebSocketManager
from app.services.real_time_integration_service import RealTimeIntegrationService
from app.api.enhanced_websocket import enhanced_manager


class TestEnhancedWebSocketManager:
    """Test cases for Enhanced WebSocket Manager."""
    
    def setup_method(self):
        """Set up test fixtures."""
        self.manager = EnhancedWebSocketManager()
        self.mock_websocket = Mock()
        self.mock_websocket.accept = AsyncMock()
        self.mock_websocket.send_text = AsyncMock()
    
    def test_initialization(self):
        """Test WebSocket manager initialization."""
        assert len(self.manager.active_connections) == 0
        assert len(self.manager.subscriptions) == 0
        assert len(self.manager.line_subscriptions) == 0
        assert len(self.manager.equipment_subscriptions) == 0
        assert len(self.manager.job_subscriptions) == 0
        assert len(self.manager.production_subscriptions) == 0
        assert len(self.manager.oee_subscriptions) == 0
        assert len(self.manager.downtime_subscriptions) == 0
        assert len(self.manager.andon_subscriptions) == 0
        assert len(self.manager.escalation_subscriptions) == 0
        assert len(self.manager.quality_subscriptions) == 0
        assert len(self.manager.changeover_subscriptions) == 0
    
    def test_production_events_defined(self):
        """Test that production events are properly defined."""
        expected_events = {
            "job_assigned", "job_started", "job_completed", "job_cancelled",
            "production_update", "oee_update", "downtime_event", "andon_event",
            "escalation_update", "quality_alert", "changeover_started", "changeover_completed"
        }
        
        assert set(self.manager.PRODUCTION_EVENTS.keys()) == expected_events
    
    @pytest.mark.asyncio
    async def test_connect(self):
        """Test WebSocket connection."""
        user_id = "test_user_123"
        connection_id = await self.manager.connect(self.mock_websocket, user_id)
        
        assert connection_id.startswith(user_id)
        assert connection_id in self.manager.active_connections
        assert connection_id in self.manager.subscriptions
        assert user_id in self.manager.user_connections
        assert connection_id in self.manager.user_connections[user_id]
    
    def test_disconnect(self):
        """Test WebSocket disconnection."""
        # Add a test connection
        connection_id = "test_user_123_0"
        self.manager.active_connections[connection_id] = self.mock_websocket
        self.manager.subscriptions[connection_id] = {"line:line1", "equipment:eq1"}
        self.manager.user_connections["test_user_123"] = {connection_id}
        
        # Add to various subscription lists
        self.manager.line_subscriptions["line1"] = {connection_id}
        self.manager.equipment_subscriptions["eq1"] = {connection_id}
        
        # Disconnect
        self.manager.disconnect(connection_id)
        
        # Verify cleanup
        assert connection_id not in self.manager.active_connections
        assert connection_id not in self.manager.subscriptions
        assert connection_id not in self.manager.user_connections["test_user_123"]
        assert connection_id not in self.manager.line_subscriptions["line1"]
        assert connection_id not in self.manager.equipment_subscriptions["eq1"]
    
    def test_subscribe_to_production_line(self):
        """Test production line subscription."""
        connection_id = "test_conn"
        line_id = "line_001"
        
        self.manager.subscriptions[connection_id] = set()
        self.manager.subscribe_to_production_line(connection_id, line_id)
        
        assert f"line:{line_id}" in self.manager.subscriptions[connection_id]
        assert connection_id in self.manager.line_subscriptions[line_id]
    
    def test_subscribe_to_equipment(self):
        """Test equipment subscription."""
        connection_id = "test_conn"
        equipment_code = "BP01.PACK.BAG1"
        
        self.manager.subscriptions[connection_id] = set()
        self.manager.subscribe_to_equipment(connection_id, equipment_code)
        
        assert f"equipment:{equipment_code}" in self.manager.subscriptions[connection_id]
        assert connection_id in self.manager.equipment_subscriptions[equipment_code]
    
    def test_subscribe_to_job(self):
        """Test job subscription."""
        connection_id = "test_conn"
        job_id = "job_123"
        
        self.manager.subscriptions[connection_id] = set()
        self.manager.subscribe_to_job(connection_id, job_id)
        
        assert f"job:{job_id}" in self.manager.subscriptions[connection_id]
        assert connection_id in self.manager.job_subscriptions[job_id]
    
    def test_subscribe_to_production_events(self):
        """Test production events subscription."""
        connection_id = "test_conn"
        line_id = "line_001"
        
        self.manager.subscriptions[connection_id] = set()
        self.manager.subscribe_to_production_events(connection_id, line_id)
        
        assert f"production:{line_id}" in self.manager.subscriptions[connection_id]
        assert connection_id in self.manager.production_subscriptions[line_id]
    
    def test_subscribe_to_oee_updates(self):
        """Test OEE updates subscription."""
        connection_id = "test_conn"
        line_id = "line_001"
        
        self.manager.subscriptions[connection_id] = set()
        self.manager.subscribe_to_oee_updates(connection_id, line_id)
        
        assert f"oee:{line_id}" in self.manager.subscriptions[connection_id]
        assert connection_id in self.manager.oee_subscriptions[line_id]
    
    def test_subscribe_to_downtime_events(self):
        """Test downtime events subscription."""
        connection_id = "test_conn"
        line_id = "line_001"
        equipment_code = "BP01.PACK.BAG1"
        
        self.manager.subscriptions[connection_id] = set()
        self.manager.subscribe_to_downtime_events(connection_id, line_id, equipment_code)
        
        assert f"downtime:{line_id}:{equipment_code}" in self.manager.subscriptions[connection_id]
        assert connection_id in self.manager.downtime_subscriptions[line_id]
        assert connection_id in self.manager.downtime_subscriptions[equipment_code]
    
    def test_subscribe_to_andon_events(self):
        """Test Andon events subscription."""
        connection_id = "test_conn"
        line_id = "line_001"
        
        self.manager.subscriptions[connection_id] = set()
        self.manager.subscribe_to_andon_events(connection_id, line_id)
        
        assert f"andon:{line_id}" in self.manager.subscriptions[connection_id]
        assert connection_id in self.manager.andon_subscriptions[line_id]
    
    def test_subscribe_to_escalation_events(self):
        """Test escalation events subscription."""
        connection_id = "test_conn"
        escalation_id = "esc_123"
        priority = "high"
        
        self.manager.subscriptions[connection_id] = set()
        self.manager.subscribe_to_escalation_events(connection_id, escalation_id, priority)
        
        assert f"escalation:{escalation_id}" in self.manager.subscriptions[connection_id]
        assert f"escalation_priority:{priority}" in self.manager.subscriptions[connection_id]
        assert connection_id in self.manager.escalation_subscriptions[escalation_id]
        assert connection_id in self.manager.escalation_subscriptions[priority]
    
    def test_subscribe_to_quality_alerts(self):
        """Test quality alerts subscription."""
        connection_id = "test_conn"
        line_id = "line_001"
        
        self.manager.subscriptions[connection_id] = set()
        self.manager.subscribe_to_quality_alerts(connection_id, line_id)
        
        assert f"quality:{line_id}" in self.manager.subscriptions[connection_id]
        assert connection_id in self.manager.quality_subscriptions[line_id]
    
    def test_subscribe_to_changeover_events(self):
        """Test changeover events subscription."""
        connection_id = "test_conn"
        line_id = "line_001"
        
        self.manager.subscriptions[connection_id] = set()
        self.manager.subscribe_to_changeover_events(connection_id, line_id)
        
        assert f"changeover:{line_id}" in self.manager.subscriptions[connection_id]
        assert connection_id in self.manager.changeover_subscriptions[line_id]
    
    def test_get_connection_stats(self):
        """Test connection statistics."""
        # Add some test data
        connection_id = "test_conn"
        self.manager.active_connections[connection_id] = self.mock_websocket
        self.manager.subscriptions[connection_id] = {"line:line1"}
        self.manager.user_connections["user1"] = {connection_id}
        self.manager.line_subscriptions["line1"] = {connection_id}
        
        stats = self.manager.get_connection_stats()
        
        assert stats["active_connections"] == 1
        assert stats["user_connections"] == 1
        assert stats["line_subscriptions"] == 1
        assert stats["equipment_subscriptions"] == 0
        assert stats["job_subscriptions"] == 0
        assert stats["production_subscriptions"] == 0
        assert stats["oee_subscriptions"] == 0
        assert stats["downtime_subscriptions"] == 0
        assert stats["andon_subscriptions"] == 0
        assert stats["escalation_subscriptions"] == 0
        assert stats["quality_subscriptions"] == 0
        assert stats["changeover_subscriptions"] == 0
    
    def test_get_subscription_details(self):
        """Test subscription details retrieval."""
        connection_id = "test_conn"
        self.manager.subscriptions[connection_id] = {"line:line1", "equipment:eq1"}
        self.manager.active_connections[connection_id] = self.mock_websocket
        
        details = self.manager.get_subscription_details(connection_id)
        
        assert details["connection_id"] == connection_id
        assert details["subscriptions"] == ["line:line1", "equipment:eq1"]
        assert details["is_active"] is True
    
    def test_get_subscription_details_nonexistent(self):
        """Test subscription details for non-existent connection."""
        details = self.manager.get_subscription_details("nonexistent")
        assert details == {}


class TestRealTimeIntegrationService:
    """Test cases for Real-time Integration Service."""
    
    def setup_method(self):
        """Set up test fixtures."""
        self.mock_websocket_manager = Mock(spec=EnhancedWebSocketManager)
        self.service = RealTimeIntegrationService(self.mock_websocket_manager)
    
    def test_initialization(self):
        """Test service initialization."""
        assert self.service.websocket_manager == self.mock_websocket_manager
        assert self.service.production_service is None
        assert self.service.andon_service is None
        assert self.service.notification_service is None
        assert self.service.equipment_job_mapper is None
        assert self.service.oee_calculator is None
        assert self.service.downtime_tracker is None
        assert self.service.andon_service_plc is None
        assert self.service.enhanced_poller is None
        assert self.service.is_running is False
        assert self.service.background_tasks == []
    
    @pytest.mark.asyncio
    async def test_initialize(self):
        """Test service initialization."""
        with patch('app.services.real_time_integration_service.ProductionService') as mock_prod, \
             patch('app.services.real_time_integration_service.AndonService') as mock_andon, \
             patch('app.services.real_time_integration_service.NotificationService') as mock_notif, \
             patch('app.services.real_time_integration_service.EquipmentJobMapper') as mock_job_mapper, \
             patch('app.services.real_time_integration_service.PLCIntegratedOEECalculator') as mock_oee, \
             patch('app.services.real_time_integration_service.PLCIntegratedDowntimeTracker') as mock_downtime, \
             patch('app.services.real_time_integration_service.PLCIntegratedAndonService') as mock_andon_plc, \
             patch('app.services.real_time_integration_service.EnhancedTelemetryPoller') as mock_poller:
            
            mock_poller_instance = Mock()
            mock_poller_instance.initialize = AsyncMock()
            mock_poller.return_value = mock_poller_instance
            
            await self.service.initialize()
            
            assert self.service.production_service is not None
            assert self.service.andon_service is not None
            assert self.service.notification_service is not None
            assert self.service.equipment_job_mapper is not None
            assert self.service.oee_calculator is not None
            assert self.service.downtime_tracker is not None
            assert self.service.andon_service_plc is not None
            assert self.service.enhanced_poller is not None
    
    @pytest.mark.asyncio
    async def test_start_stop(self):
        """Test service start and stop."""
        # Mock the service components
        self.service.production_service = Mock()
        self.service.andon_service = Mock()
        self.service.notification_service = Mock()
        self.service.equipment_job_mapper = Mock()
        self.service.oee_calculator = Mock()
        self.service.downtime_tracker = Mock()
        self.service.andon_service_plc = Mock()
        self.service.enhanced_poller = Mock()
        
        # Mock background task methods
        self.service.enhanced_poller.get_production_updates = AsyncMock(return_value=[])
        self.service.oee_calculator.get_latest_oee_updates = AsyncMock(return_value=[])
        self.service.downtime_tracker.get_latest_downtime_events = AsyncMock(return_value=[])
        self.service.andon_service_plc.get_latest_andon_events = AsyncMock(return_value=[])
        self.service.equipment_job_mapper.get_job_progress_updates = AsyncMock(return_value=[])
        self.service.production_service.get_quality_alerts = AsyncMock(return_value=[])
        self.service.production_service.get_changeover_events = AsyncMock(return_value=[])
        
        # Start the service
        await self.service.start()
        assert self.service.is_running is True
        assert len(self.service.background_tasks) > 0
        
        # Wait a bit for tasks to start
        await asyncio.sleep(0.1)
        
        # Stop the service
        await self.service.stop()
        assert self.service.is_running is False
        assert len(self.service.background_tasks) == 0
    
    def test_get_status(self):
        """Test status retrieval."""
        # Mock some services
        self.service.production_service = Mock()
        self.service.andon_service = Mock()
        self.service.is_running = True
        self.service.background_tasks = [Mock(), Mock()]
        
        self.mock_websocket_manager.get_connection_stats.return_value = {"active_connections": 5}
        
        status = self.service.get_status()
        
        assert status["is_running"] is True
        assert status["background_tasks"] == 2
        assert status["active_connections"] == 5
        assert status["services_initialized"]["production_service"] is True
        assert status["services_initialized"]["andon_service"] is True
        assert status["services_initialized"]["notification_service"] is False
    
    @pytest.mark.asyncio
    async def test_broadcast_production_metrics(self):
        """Test production metrics broadcasting."""
        line_id = "line_001"
        metrics = {"efficiency": 85.5, "speed": 120}
        
        await self.service.broadcast_production_metrics(line_id, metrics)
        
        self.mock_websocket_manager.broadcast_production_update.assert_called_once_with(line_id, metrics)
    
    @pytest.mark.asyncio
    async def test_broadcast_job_event(self):
        """Test job event broadcasting."""
        job_data = {"job_id": "job_123", "line_id": "line_001", "user_id": "user_123"}
        
        # Test job assigned
        await self.service.broadcast_job_event("job_assigned", job_data)
        self.mock_websocket_manager.broadcast_job_assigned.assert_called_once_with(job_data)
        
        # Test job started
        await self.service.broadcast_job_event("job_started", job_data)
        self.mock_websocket_manager.broadcast_job_started.assert_called_once_with(job_data)
        
        # Test job completed
        await self.service.broadcast_job_event("job_completed", job_data)
        self.mock_websocket_manager.broadcast_job_completed.assert_called_once_with(job_data)
        
        # Test job cancelled
        await self.service.broadcast_job_event("job_cancelled", job_data)
        self.mock_websocket_manager.broadcast_job_cancelled.assert_called_once_with(job_data)
    
    @pytest.mark.asyncio
    async def test_broadcast_oee_metrics(self):
        """Test OEE metrics broadcasting."""
        line_id = "line_001"
        oee_data = {"oee": 75.5, "availability": 90.0, "performance": 85.0, "quality": 98.0}
        
        await self.service.broadcast_oee_metrics(line_id, oee_data)
        
        self.mock_websocket_manager.broadcast_oee_update.assert_called_once_with(line_id, oee_data)
    
    @pytest.mark.asyncio
    async def test_broadcast_downtime_event(self):
        """Test downtime event broadcasting."""
        downtime_data = {"line_id": "line_001", "equipment_code": "BP01.PACK.BAG1", "reason": "Fault"}
        
        await self.service.broadcast_downtime_event(downtime_data)
        
        self.mock_websocket_manager.broadcast_downtime_event.assert_called_once_with(downtime_data)
    
    @pytest.mark.asyncio
    async def test_broadcast_andon_event(self):
        """Test Andon event broadcasting."""
        andon_data = {"line_id": "line_001", "equipment_code": "BP01.PACK.BAG1", "priority": "high"}
        
        await self.service.broadcast_andon_event(andon_data)
        
        self.mock_websocket_manager.broadcast_andon_event.assert_called_once_with(andon_data)
    
    @pytest.mark.asyncio
    async def test_broadcast_escalation_update(self):
        """Test escalation update broadcasting."""
        escalation_data = {"escalation_id": "esc_123", "line_id": "line_001", "priority": "high"}
        
        await self.service.broadcast_escalation_update(escalation_data)
        
        self.mock_websocket_manager.broadcast_escalation_update.assert_called_once_with(escalation_data)
    
    @pytest.mark.asyncio
    async def test_broadcast_quality_alert(self):
        """Test quality alert broadcasting."""
        quality_data = {"line_id": "line_001", "alert_type": "defect_rate_high", "value": 5.2}
        
        await self.service.broadcast_quality_alert(quality_data)
        
        self.mock_websocket_manager.broadcast_quality_alert.assert_called_once_with(quality_data)
    
    @pytest.mark.asyncio
    async def test_broadcast_changeover_event(self):
        """Test changeover event broadcasting."""
        changeover_data = {"line_id": "line_001", "from_product": "Product A", "to_product": "Product B"}
        
        # Test changeover started
        await self.service.broadcast_changeover_event("changeover_started", changeover_data)
        self.mock_websocket_manager.broadcast_changeover_started.assert_called_once_with(changeover_data)
        
        # Test changeover completed
        await self.service.broadcast_changeover_event("changeover_completed", changeover_data)
        self.mock_websocket_manager.broadcast_changeover_completed.assert_called_once_with(changeover_data)


class TestEnhancedWebSocketIntegration:
    """Integration tests for enhanced WebSocket functionality."""
    
    @pytest.mark.asyncio
    async def test_production_event_flow(self):
        """Test complete production event flow."""
        manager = EnhancedWebSocketManager()
        
        # Mock WebSocket
        mock_websocket = Mock()
        mock_websocket.accept = AsyncMock()
        mock_websocket.send_text = AsyncMock()
        
        # Connect
        connection_id = await manager.connect(mock_websocket, "test_user")
        
        # Subscribe to production events
        manager.subscribe_to_production_events(connection_id, "line_001")
        
        # Broadcast production update
        production_data = {"efficiency": 85.5, "speed": 120, "quantity": 150}
        await manager.broadcast_production_update("line_001", production_data)
        
        # Verify message was sent
        mock_websocket.send_text.assert_called()
        sent_message = json.loads(mock_websocket.send_text.call_args[0][0])
        
        assert sent_message["type"] == "production_update"
        assert sent_message["line_id"] == "line_001"
        assert sent_message["data"] == production_data
        assert "timestamp" in sent_message
    
    @pytest.mark.asyncio
    async def test_job_event_flow(self):
        """Test complete job event flow."""
        manager = EnhancedWebSocketManager()
        
        # Mock WebSocket
        mock_websocket = Mock()
        mock_websocket.accept = AsyncMock()
        mock_websocket.send_text = AsyncMock()
        
        # Connect
        connection_id = await manager.connect(mock_websocket, "test_user")
        
        # Subscribe to job events
        manager.subscribe_to_job(connection_id, "job_123")
        
        # Broadcast job assigned
        job_data = {"job_id": "job_123", "line_id": "line_001", "user_id": "user_123"}
        await manager.broadcast_job_assigned(job_data)
        
        # Verify message was sent
        mock_websocket.send_text.assert_called()
        sent_message = json.loads(mock_websocket.send_text.call_args[0][0])
        
        assert sent_message["type"] == "job_assigned"
        assert sent_message["data"] == job_data
        assert "timestamp" in sent_message
    
    @pytest.mark.asyncio
    async def test_oee_update_flow(self):
        """Test complete OEE update flow."""
        manager = EnhancedWebSocketManager()
        
        # Mock WebSocket
        mock_websocket = Mock()
        mock_websocket.accept = AsyncMock()
        mock_websocket.send_text = AsyncMock()
        
        # Connect
        connection_id = await manager.connect(mock_websocket, "test_user")
        
        # Subscribe to OEE updates
        manager.subscribe_to_oee_updates(connection_id, "line_001")
        
        # Broadcast OEE update
        oee_data = {"oee": 75.5, "availability": 90.0, "performance": 85.0, "quality": 98.0}
        await manager.broadcast_oee_update("line_001", oee_data)
        
        # Verify message was sent
        mock_websocket.send_text.assert_called()
        sent_message = json.loads(mock_websocket.send_text.call_args[0][0])
        
        assert sent_message["type"] == "oee_update"
        assert sent_message["line_id"] == "line_001"
        assert sent_message["data"] == oee_data
        assert "timestamp" in sent_message
    
    @pytest.mark.asyncio
    async def test_downtime_event_flow(self):
        """Test complete downtime event flow."""
        manager = EnhancedWebSocketManager()
        
        # Mock WebSocket
        mock_websocket = Mock()
        mock_websocket.accept = AsyncMock()
        mock_websocket.send_text = AsyncMock()
        
        # Connect
        connection_id = await manager.connect(mock_websocket, "test_user")
        
        # Subscribe to downtime events
        manager.subscribe_to_downtime_events(connection_id, "line_001", "BP01.PACK.BAG1")
        
        # Broadcast downtime event
        downtime_data = {"line_id": "line_001", "equipment_code": "BP01.PACK.BAG1", "reason": "Fault"}
        await manager.broadcast_downtime_event(downtime_data)
        
        # Verify message was sent
        mock_websocket.send_text.assert_called()
        sent_message = json.loads(mock_websocket.send_text.call_args[0][0])
        
        assert sent_message["type"] == "downtime_event"
        assert sent_message["data"] == downtime_data
        assert "timestamp" in sent_message
    
    @pytest.mark.asyncio
    async def test_andon_event_flow(self):
        """Test complete Andon event flow."""
        manager = EnhancedWebSocketManager()
        
        # Mock WebSocket
        mock_websocket = Mock()
        mock_websocket.accept = AsyncMock()
        mock_websocket.send_text = AsyncMock()
        
        # Connect
        connection_id = await manager.connect(mock_websocket, "test_user")
        
        # Subscribe to Andon events
        manager.subscribe_to_andon_events(connection_id, "line_001")
        
        # Broadcast Andon event
        andon_data = {"line_id": "line_001", "equipment_code": "BP01.PACK.BAG1", "priority": "high"}
        await manager.broadcast_andon_event(andon_data)
        
        # Verify message was sent
        mock_websocket.send_text.assert_called()
        sent_message = json.loads(mock_websocket.send_text.call_args[0][0])
        
        assert sent_message["type"] == "andon_event"
        assert sent_message["data"] == andon_data
        assert "timestamp" in sent_message


class TestWebSocketMessageHandling:
    """Test WebSocket message handling functionality."""
    
    @pytest.mark.asyncio
    async def test_subscribe_message_handling(self):
        """Test subscription message handling."""
        manager = EnhancedWebSocketManager()
        
        # Mock WebSocket
        mock_websocket = Mock()
        mock_websocket.accept = AsyncMock()
        mock_websocket.send_text = AsyncMock()
        
        # Connect
        connection_id = await manager.connect(mock_websocket, "test_user")
        
        # Test line subscription
        manager.subscribe_to_production_line(connection_id, "line_001")
        assert f"line:line_001" in manager.subscriptions[connection_id]
        assert connection_id in manager.line_subscriptions["line_001"]
        
        # Test equipment subscription
        manager.subscribe_to_equipment(connection_id, "BP01.PACK.BAG1")
        assert f"equipment:BP01.PACK.BAG1" in manager.subscriptions[connection_id]
        assert connection_id in manager.equipment_subscriptions["BP01.PACK.BAG1"]
        
        # Test job subscription
        manager.subscribe_to_job(connection_id, "job_123")
        assert f"job:job_123" in manager.subscriptions[connection_id]
        assert connection_id in manager.job_subscriptions["job_123"]
    
    @pytest.mark.asyncio
    async def test_unsubscribe_message_handling(self):
        """Test unsubscription message handling."""
        manager = EnhancedWebSocketManager()
        
        # Mock WebSocket
        mock_websocket = Mock()
        mock_websocket.accept = AsyncMock()
        mock_websocket.send_text = AsyncMock()
        
        # Connect
        connection_id = await manager.connect(mock_websocket, "test_user")
        
        # Subscribe first
        manager.subscribe_to_production_line(connection_id, "line_001")
        manager.subscribe_to_equipment(connection_id, "BP01.PACK.BAG1")
        manager.subscribe_to_job(connection_id, "job_123")
        
        # Unsubscribe
        manager.unsubscribe_from_production_line(connection_id, "line_001")
        manager.unsubscribe_from_equipment(connection_id, "BP01.PACK.BAG1")
        manager.unsubscribe_from_job(connection_id, "job_123")
        
        # Verify unsubscription
        assert f"line:line_001" not in manager.subscriptions[connection_id]
        assert f"equipment:BP01.PACK.BAG1" not in manager.subscriptions[connection_id]
        assert f"job:job_123" not in manager.subscriptions[connection_id]
        assert connection_id not in manager.line_subscriptions["line_001"]
        assert connection_id not in manager.equipment_subscriptions["BP01.PACK.BAG1"]
        assert connection_id not in manager.job_subscriptions["job_123"]


if __name__ == "__main__":
    # Run tests
    pytest.main([__file__, "-v"])
