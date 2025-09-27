"""
Unit tests for Andon Service
Tests all Andon service methods and functionality
"""

import pytest
import asyncio
from unittest.mock import Mock, AsyncMock, patch
from datetime import datetime, timedelta
import uuid

# Import the service to test
import sys
import os
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'backend'))

from app.services.andon_service import AndonService


class TestAndonService:
    """Test cases for AndonService"""
    
    @pytest.fixture
    def mock_db(self):
        """Mock database connection"""
        mock_db = AsyncMock()
        return mock_db
    
    @pytest.fixture
    def mock_notification_service(self):
        """Mock notification service"""
        return AsyncMock()
    
    @pytest.fixture
    def mock_escalation_service(self):
        """Mock escalation service"""
        return AsyncMock()
    
    @pytest.fixture
    def andon_service(self, mock_db, mock_notification_service, mock_escalation_service):
        """Create AndonService instance with mocked dependencies"""
        with patch('app.services.andon_service.get_database', return_value=mock_db):
            with patch('app.services.andon_service.NotificationService', return_value=mock_notification_service):
                with patch('app.services.andon_service.AndonEscalationService', return_value=mock_escalation_service):
                    service = AndonService()
                    return service
    
    @pytest.mark.asyncio
    async def test_create_andon_event(self, andon_service, mock_db):
        """Test creating an Andon event"""
        event_data = {
            'equipment_code': 'EQ-001',
            'line_id': str(uuid.uuid4()),
            'event_type': 'fault',
            'priority': 'high',
            'description': 'Equipment fault detected',
            'reported_by': str(uuid.uuid4())
        }
        
        mock_db.fetch_one.return_value = {
            'id': str(uuid.uuid4()),
            **event_data,
            'status': 'active',
            'created_at': datetime.now()
        }
        
        result = await andon_service.create_andon_event(event_data)
        
        assert result is not None
        assert result['status'] == 'active'
        assert result['event_type'] == 'fault'
        assert result['priority'] == 'high'
        mock_db.fetch_one.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_get_andon_events(self, andon_service, mock_db):
        """Test getting Andon events"""
        mock_db.fetch_all.return_value = [
            {
                'id': str(uuid.uuid4()),
                'equipment_code': 'EQ-001',
                'event_type': 'fault',
                'priority': 'high',
                'status': 'active',
                'created_at': datetime.now()
            }
        ]
        
        result = await andon_service.get_andon_events()
        
        assert result is not None
        assert len(result) == 1
        assert result[0]['event_type'] == 'fault'
        mock_db.fetch_all.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_get_andon_event_by_id(self, andon_service, mock_db):
        """Test getting Andon event by ID"""
        event_id = str(uuid.uuid4())
        
        mock_db.fetch_one.return_value = {
            'id': event_id,
            'equipment_code': 'EQ-001',
            'event_type': 'fault',
            'priority': 'high',
            'status': 'active',
            'created_at': datetime.now()
        }
        
        result = await andon_service.get_andon_event_by_id(event_id)
        
        assert result is not None
        assert result['id'] == event_id
        mock_db.fetch_one.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_acknowledge_andon_event(self, andon_service, mock_db, mock_notification_service):
        """Test acknowledging an Andon event"""
        event_id = str(uuid.uuid4())
        user_id = str(uuid.uuid4())
        
        mock_db.fetch_one.return_value = {
            'id': event_id,
            'status': 'acknowledged',
            'acknowledged_by': user_id,
            'acknowledged_at': datetime.now()
        }
        
        result = await andon_service.acknowledge_andon_event(event_id, user_id)
        
        assert result is not None
        assert result['status'] == 'acknowledged'
        assert result['acknowledged_by'] == user_id
        mock_db.fetch_one.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_resolve_andon_event(self, andon_service, mock_db, mock_notification_service):
        """Test resolving an Andon event"""
        event_id = str(uuid.uuid4())
        user_id = str(uuid.uuid4())
        resolution_notes = "Issue resolved by replacing faulty component"
        
        mock_db.fetch_one.return_value = {
            'id': event_id,
            'status': 'resolved',
            'resolved_by': user_id,
            'resolved_at': datetime.now(),
            'resolution_notes': resolution_notes
        }
        
        result = await andon_service.resolve_andon_event(event_id, user_id, resolution_notes)
        
        assert result is not None
        assert result['status'] == 'resolved'
        assert result['resolved_by'] == user_id
        assert result['resolution_notes'] == resolution_notes
        mock_db.fetch_one.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_escalate_andon_event(self, andon_service, mock_db, mock_escalation_service):
        """Test escalating an Andon event"""
        event_id = str(uuid.uuid4())
        escalation_level = 2
        
        mock_db.fetch_one.return_value = {
            'id': event_id,
            'status': 'escalated',
            'escalation_level': escalation_level,
            'escalated_at': datetime.now()
        }
        
        result = await andon_service.escalate_andon_event(event_id, escalation_level)
        
        assert result is not None
        assert result['status'] == 'escalated'
        assert result['escalation_level'] == escalation_level
        mock_db.fetch_one.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_get_active_andon_events(self, andon_service, mock_db):
        """Test getting active Andon events"""
        mock_db.fetch_all.return_value = [
            {
                'id': str(uuid.uuid4()),
                'equipment_code': 'EQ-001',
                'event_type': 'fault',
                'priority': 'high',
                'status': 'active',
                'created_at': datetime.now()
            }
        ]
        
        result = await andon_service.get_active_andon_events()
        
        assert result is not None
        assert len(result) == 1
        assert result[0]['status'] == 'active'
        mock_db.fetch_all.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_get_andon_events_by_equipment(self, andon_service, mock_db):
        """Test getting Andon events by equipment"""
        equipment_code = 'EQ-001'
        
        mock_db.fetch_all.return_value = [
            {
                'id': str(uuid.uuid4()),
                'equipment_code': equipment_code,
                'event_type': 'fault',
                'priority': 'high',
                'status': 'active',
                'created_at': datetime.now()
            }
        ]
        
        result = await andon_service.get_andon_events_by_equipment(equipment_code)
        
        assert result is not None
        assert len(result) == 1
        assert result[0]['equipment_code'] == equipment_code
        mock_db.fetch_all.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_get_andon_events_by_priority(self, andon_service, mock_db):
        """Test getting Andon events by priority"""
        priority = 'high'
        
        mock_db.fetch_all.return_value = [
            {
                'id': str(uuid.uuid4()),
                'equipment_code': 'EQ-001',
                'event_type': 'fault',
                'priority': priority,
                'status': 'active',
                'created_at': datetime.now()
            }
        ]
        
        result = await andon_service.get_andon_events_by_priority(priority)
        
        assert result is not None
        assert len(result) == 1
        assert result[0]['priority'] == priority
        mock_db.fetch_all.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_get_andon_statistics(self, andon_service, mock_db):
        """Test getting Andon statistics"""
        mock_db.fetch_one.return_value = {
            'total_events': 100,
            'active_events': 5,
            'resolved_events': 90,
            'escalated_events': 5,
            'avg_resolution_time_minutes': 45.5
        }
        
        result = await andon_service.get_andon_statistics()
        
        assert result is not None
        assert 'total_events' in result
        assert 'active_events' in result
        assert 'resolved_events' in result
        assert 'escalated_events' in result
        assert 'avg_resolution_time_minutes' in result
        mock_db.fetch_one.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_update_andon_event(self, andon_service, mock_db):
        """Test updating an Andon event"""
        event_id = str(uuid.uuid4())
        update_data = {'priority': 'critical', 'description': 'Updated description'}
        
        mock_db.fetch_one.return_value = {
            'id': event_id,
            'priority': 'critical',
            'description': 'Updated description',
            'updated_at': datetime.now()
        }
        
        result = await andon_service.update_andon_event(event_id, update_data)
        
        assert result is not None
        assert result['priority'] == 'critical'
        assert result['description'] == 'Updated description'
        mock_db.fetch_one.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_delete_andon_event(self, andon_service, mock_db):
        """Test deleting an Andon event"""
        event_id = str(uuid.uuid4())
        
        mock_db.execute.return_value = True
        
        result = await andon_service.delete_andon_event(event_id)
        
        assert result is True
        mock_db.execute.assert_called_once()


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
