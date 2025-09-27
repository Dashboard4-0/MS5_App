"""
Unit tests for WebSocket Manager Service
Tests all WebSocket manager methods and functionality
"""

import pytest
import asyncio
from unittest.mock import Mock, AsyncMock, patch
from datetime import datetime
import uuid
import json

# Import the service to test
import sys
import os
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'backend'))

from app.services.websocket_manager import WebSocketManager


class TestWebSocketManager:
    """Test cases for WebSocketManager"""
    
    @pytest.fixture
    def websocket_manager(self):
        """Create WebSocketManager instance"""
        return WebSocketManager()
    
    @pytest.fixture
    def mock_websocket(self):
        """Mock WebSocket connection"""
        mock_ws = AsyncMock()
        mock_ws.send_text = AsyncMock()
        mock_ws.close = AsyncMock()
        return mock_ws
    
    def test_initialization(self, websocket_manager):
        """Test WebSocketManager initialization"""
        assert websocket_manager.connections == {}
        assert websocket_manager.subscriptions == {}
        assert websocket_manager.user_connections == {}
    
    @pytest.mark.asyncio
    async def test_add_connection(self, websocket_manager, mock_websocket):
        """Test adding a WebSocket connection"""
        user_id = str(uuid.uuid4())
        
        await websocket_manager.add_connection(mock_websocket, user_id)
        
        assert len(websocket_manager.connections) == 1
        assert user_id in websocket_manager.user_connections
        assert mock_websocket in websocket_manager.connections
    
    @pytest.mark.asyncio
    async def test_remove_connection(self, websocket_manager, mock_websocket):
        """Test removing a WebSocket connection"""
        user_id = str(uuid.uuid4())
        
        # Add connection first
        await websocket_manager.add_connection(mock_websocket, user_id)
        assert len(websocket_manager.connections) == 1
        
        # Remove connection
        await websocket_manager.remove_connection(mock_websocket)
        
        assert len(websocket_manager.connections) == 0
        assert user_id not in websocket_manager.user_connections
    
    @pytest.mark.asyncio
    async def test_subscribe(self, websocket_manager, mock_websocket):
        """Test subscribing to a topic"""
        user_id = str(uuid.uuid4())
        subscription_type = "line"
        target = "line-001"
        
        # Add connection first
        await websocket_manager.add_connection(mock_websocket, user_id)
        
        # Subscribe
        await websocket_manager.subscribe(mock_websocket, subscription_type, target)
        
        subscription_key = f"{subscription_type}:{target}"
        assert subscription_key in websocket_manager.subscriptions
        assert mock_websocket in websocket_manager.subscriptions[subscription_key]
    
    @pytest.mark.asyncio
    async def test_unsubscribe(self, websocket_manager, mock_websocket):
        """Test unsubscribing from a topic"""
        user_id = str(uuid.uuid4())
        subscription_type = "line"
        target = "line-001"
        
        # Add connection and subscribe
        await websocket_manager.add_connection(mock_websocket, user_id)
        await websocket_manager.subscribe(mock_websocket, subscription_type, target)
        
        subscription_key = f"{subscription_type}:{target}"
        assert subscription_key in websocket_manager.subscriptions
        
        # Unsubscribe
        await websocket_manager.unsubscribe(mock_websocket, subscription_type, target)
        
        assert subscription_key not in websocket_manager.subscriptions
    
    @pytest.mark.asyncio
    async def test_broadcast_line_status_update(self, websocket_manager, mock_websocket):
        """Test broadcasting line status update"""
        user_id = str(uuid.uuid4())
        line_id = "line-001"
        
        # Add connection and subscribe
        await websocket_manager.add_connection(mock_websocket, user_id)
        await websocket_manager.subscribe(mock_websocket, "line", line_id)
        
        data = {
            'status': 'running',
            'speed': 95.0,
            'efficiency': 0.95
        }
        
        await websocket_manager.broadcast_line_status_update(line_id, data)
        
        # Verify message was sent
        mock_websocket.send_text.assert_called_once()
        sent_message = mock_websocket.send_text.call_args[0][0]
        message_data = json.loads(sent_message)
        
        assert message_data['type'] == 'line_status_update'
        assert message_data['line_id'] == line_id
        assert message_data['data'] == data
    
    @pytest.mark.asyncio
    async def test_broadcast_production_update(self, websocket_manager, mock_websocket):
        """Test broadcasting production update"""
        user_id = str(uuid.uuid4())
        line_id = "line-001"
        
        # Add connection and subscribe
        await websocket_manager.add_connection(mock_websocket, user_id)
        await websocket_manager.subscribe(mock_websocket, "production", line_id)
        
        data = {
            'units_produced': 100,
            'target_units': 120,
            'efficiency': 0.83
        }
        
        await websocket_manager.broadcast_production_update(line_id, data)
        
        # Verify message was sent
        mock_websocket.send_text.assert_called_once()
        sent_message = mock_websocket.send_text.call_args[0][0]
        message_data = json.loads(sent_message)
        
        assert message_data['type'] == 'production_update'
        assert message_data['line_id'] == line_id
        assert message_data['data'] == data
    
    @pytest.mark.asyncio
    async def test_broadcast_andon_event(self, websocket_manager, mock_websocket):
        """Test broadcasting Andon event"""
        user_id = str(uuid.uuid4())
        line_id = "line-001"
        
        # Add connection and subscribe
        await websocket_manager.add_connection(mock_websocket, user_id)
        await websocket_manager.subscribe(mock_websocket, "andon", line_id)
        
        event = {
            'id': str(uuid.uuid4()),
            'equipment_code': 'EQ-001',
            'event_type': 'fault',
            'priority': 'high',
            'status': 'active'
        }
        
        await websocket_manager.broadcast_andon_event(event)
        
        # Verify message was sent
        mock_websocket.send_text.assert_called_once()
        sent_message = mock_websocket.send_text.call_args[0][0]
        message_data = json.loads(sent_message)
        
        assert message_data['type'] == 'andon_event'
        assert message_data['data'] == event
    
    @pytest.mark.asyncio
    async def test_broadcast_oee_update(self, websocket_manager, mock_websocket):
        """Test broadcasting OEE update"""
        user_id = str(uuid.uuid4())
        line_id = "line-001"
        
        # Add connection and subscribe
        await websocket_manager.add_connection(mock_websocket, user_id)
        await websocket_manager.subscribe(mock_websocket, "oee", line_id)
        
        oee_data = {
            'oee': 0.85,
            'availability': 0.9,
            'performance': 0.95,
            'quality': 0.95
        }
        
        await websocket_manager.broadcast_oee_update(line_id, oee_data)
        
        # Verify message was sent
        mock_websocket.send_text.assert_called_once()
        sent_message = mock_websocket.send_text.call_args[0][0]
        message_data = json.loads(sent_message)
        
        assert message_data['type'] == 'oee_update'
        assert message_data['line_id'] == line_id
        assert message_data['data'] == oee_data
    
    @pytest.mark.asyncio
    async def test_broadcast_downtime_event(self, websocket_manager, mock_websocket):
        """Test broadcasting downtime event"""
        user_id = str(uuid.uuid4())
        line_id = "line-001"
        
        # Add connection and subscribe
        await websocket_manager.add_connection(mock_websocket, user_id)
        await websocket_manager.subscribe(mock_websocket, "downtime", line_id)
        
        event = {
            'id': str(uuid.uuid4()),
            'equipment_code': 'EQ-001',
            'start_time': datetime.now().isoformat(),
            'duration_minutes': 30,
            'category': 'unplanned'
        }
        
        await websocket_manager.broadcast_downtime_event(event)
        
        # Verify message was sent
        mock_websocket.send_text.assert_called_once()
        sent_message = mock_websocket.send_text.call_args[0][0]
        message_data = json.loads(sent_message)
        
        assert message_data['type'] == 'downtime_event'
        assert message_data['data'] == event
    
    @pytest.mark.asyncio
    async def test_broadcast_job_update(self, websocket_manager, mock_websocket):
        """Test broadcasting job update"""
        user_id = str(uuid.uuid4())
        job_id = str(uuid.uuid4())
        
        # Add connection and subscribe
        await websocket_manager.add_connection(mock_websocket, user_id)
        await websocket_manager.subscribe(mock_websocket, "job", job_id)
        
        job_data = {
            'id': job_id,
            'status': 'in_progress',
            'progress': 50,
            'assigned_to': user_id
        }
        
        await websocket_manager.broadcast_job_update(job_id, job_data)
        
        # Verify message was sent
        mock_websocket.send_text.assert_called_once()
        sent_message = mock_websocket.send_text.call_args[0][0]
        message_data = json.loads(sent_message)
        
        assert message_data['type'] == 'job_update'
        assert message_data['job_id'] == job_id
        assert message_data['data'] == job_data
    
    @pytest.mark.asyncio
    async def test_broadcast_escalation_update(self, websocket_manager, mock_websocket):
        """Test broadcasting escalation update"""
        user_id = str(uuid.uuid4())
        escalation_id = str(uuid.uuid4())
        
        # Add connection and subscribe
        await websocket_manager.add_connection(mock_websocket, user_id)
        await websocket_manager.subscribe(mock_websocket, "escalation", escalation_id)
        
        escalation_data = {
            'id': escalation_id,
            'event_id': str(uuid.uuid4()),
            'escalation_level': 2,
            'status': 'escalated'
        }
        
        await websocket_manager.broadcast_escalation_update(escalation_id, escalation_data)
        
        # Verify message was sent
        mock_websocket.send_text.assert_called_once()
        sent_message = mock_websocket.send_text.call_args[0][0]
        message_data = json.loads(sent_message)
        
        assert message_data['type'] == 'escalation_update'
        assert message_data['escalation_id'] == escalation_id
        assert message_data['data'] == escalation_data
    
    @pytest.mark.asyncio
    async def test_broadcast_quality_alert(self, websocket_manager, mock_websocket):
        """Test broadcasting quality alert"""
        user_id = str(uuid.uuid4())
        line_id = "line-001"
        
        # Add connection and subscribe
        await websocket_manager.add_connection(mock_websocket, user_id)
        await websocket_manager.subscribe(mock_websocket, "quality", line_id)
        
        alert_data = {
            'parameter': 'temperature',
            'value': 85.5,
            'threshold': 80.0,
            'severity': 'warning'
        }
        
        await websocket_manager.broadcast_quality_alert(line_id, alert_data)
        
        # Verify message was sent
        mock_websocket.send_text.assert_called_once()
        sent_message = mock_websocket.send_text.call_args[0][0]
        message_data = json.loads(sent_message)
        
        assert message_data['type'] == 'quality_alert'
        assert message_data['line_id'] == line_id
        assert message_data['data'] == alert_data
    
    @pytest.mark.asyncio
    async def test_broadcast_changeover_event(self, websocket_manager, mock_websocket):
        """Test broadcasting changeover event"""
        user_id = str(uuid.uuid4())
        line_id = "line-001"
        
        # Add connection and subscribe
        await websocket_manager.add_connection(mock_websocket, user_id)
        await websocket_manager.subscribe(mock_websocket, "changeover", line_id)
        
        changeover_data = {
            'id': str(uuid.uuid4()),
            'line_id': line_id,
            'status': 'started',
            'estimated_duration_minutes': 30
        }
        
        await websocket_manager.broadcast_changeover_event(changeover_data)
        
        # Verify message was sent
        mock_websocket.send_text.assert_called_once()
        sent_message = mock_websocket.send_text.call_args[0][0]
        message_data = json.loads(sent_message)
        
        assert message_data['type'] == 'changeover_event'
        assert message_data['data'] == changeover_data
    
    def test_get_connection_stats(self, websocket_manager):
        """Test getting connection statistics"""
        stats = websocket_manager.get_connection_stats()
        
        assert 'total_connections' in stats
        assert 'total_subscriptions' in stats
        assert 'subscription_types' in stats
        assert stats['total_connections'] == 0
        assert stats['total_subscriptions'] == 0
    
    @pytest.mark.asyncio
    async def test_cleanup_disconnected_connections(self, websocket_manager, mock_websocket):
        """Test cleaning up disconnected connections"""
        user_id = str(uuid.uuid4())
        
        # Add connection
        await websocket_manager.add_connection(mock_websocket, user_id)
        assert len(websocket_manager.connections) == 1
        
        # Simulate connection error
        mock_websocket.send_text.side_effect = Exception("Connection closed")
        
        # Try to send message (should trigger cleanup)
        try:
            await websocket_manager.broadcast_line_status_update("line-001", {})
        except Exception:
            pass
        
        # Cleanup should have removed the connection
        assert len(websocket_manager.connections) == 0


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
