"""
Comprehensive unit tests for Andon Service
Tests all methods, escalation logic, and business rules
"""

import pytest
import asyncio
from unittest.mock import AsyncMock, MagicMock, patch
from datetime import datetime, timedelta
from uuid import uuid4, UUID
import json

from backend.app.services.andon_service import (
    AndonService, PLCIntegratedAndonService
)
from backend.app.utils.exceptions import (
    ValidationError, BusinessLogicError, NotFoundError
)


class TestAndonService:
    """Test cases for AndonService"""
    
    @pytest.fixture
    def andon_service(self):
        """Create AndonService instance"""
        return AndonService()
    
    @pytest.fixture
    def sample_andon_event(self):
        """Sample Andon event data"""
        return {
            'line_id': str(uuid4()),
            'equipment_code': 'BP01.PACK.BAG1',
            'event_type': 'stop',
            'priority': 'high',
            'description': 'Machine stopped due to mechanical fault',
            'reported_by': str(uuid4())
        }
    
    @pytest.fixture
    def sample_escalation_tree(self):
        """Sample escalation tree configuration"""
        return {
            'critical': {
                1: {'delay_minutes': 5, 'recipients': ['supervisor', 'engineer']},
                2: {'delay_minutes': 15, 'recipients': ['manager', 'maintenance_lead']},
                3: {'delay_minutes': 30, 'recipients': ['plant_manager', 'director']}
            },
            'high': {
                1: {'delay_minutes': 10, 'recipients': ['supervisor']},
                2: {'delay_minutes': 30, 'recipients': ['manager', 'engineer']},
                3: {'delay_minutes': 60, 'recipients': ['plant_manager']}
            },
            'medium': {
                1: {'delay_minutes': 15, 'recipients': ['supervisor']},
                2: {'delay_minutes': 60, 'recipients': ['manager']}
            },
            'low': {
                1: {'delay_minutes': 30, 'recipients': ['supervisor']}
            }
        }
    
    @pytest.mark.asyncio
    async def test_create_andon_event_success(self, andon_service, sample_andon_event):
        """Test successful Andon event creation"""
        with patch.object(andon_service, 'store_andon_event') as mock_store, \
             patch.object(andon_service, 'start_escalation') as mock_escalation, \
             patch.object(andon_service, 'send_websocket_notification') as mock_ws:
            
            mock_store.return_value = str(uuid4())
            mock_escalation.return_value = None
            mock_ws.return_value = None
            
            result = await andon_service.create_andon_event(**sample_andon_event)
            
            assert isinstance(result, dict)
            assert 'id' in result
            assert result['line_id'] == sample_andon_event['line_id']
            assert result['equipment_code'] == sample_andon_event['equipment_code']
            assert result['event_type'] == sample_andon_event['event_type']
            assert result['priority'] == sample_andon_event['priority']
            assert result['status'] == 'open'
            assert 'created_at' in result
            
            mock_store.assert_called_once()
            mock_escalation.assert_called_once()
            mock_ws.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_create_andon_event_invalid_priority(self, andon_service, sample_andon_event):
        """Test Andon event creation with invalid priority"""
        sample_andon_event['priority'] = 'invalid_priority'
        
        with pytest.raises(ValidationError, match="Invalid priority level"):
            await andon_service.create_andon_event(**sample_andon_event)
    
    @pytest.mark.asyncio
    async def test_create_andon_event_invalid_event_type(self, andon_service, sample_andon_event):
        """Test Andon event creation with invalid event type"""
        sample_andon_event['event_type'] = 'invalid_type'
        
        with pytest.raises(ValidationError, match="Invalid event type"):
            await andon_service.create_andon_event(**sample_andon_event)
    
    @pytest.mark.asyncio
    async def test_acknowledge_andon_event_success(self, andon_service):
        """Test successful Andon event acknowledgment"""
        event_id = str(uuid4())
        user_id = str(uuid4())
        
        with patch.object(andon_service, 'get_andon_event') as mock_get, \
             patch.object(andon_service, 'update_andon_event') as mock_update:
            
            mock_get.return_value = {
                'id': event_id,
                'status': 'open',
                'line_id': str(uuid4()),
                'equipment_code': 'BP01.PACK.BAG1'
            }
            
            mock_update.return_value = {
                'id': event_id,
                'status': 'acknowledged',
                'acknowledged_by': user_id,
                'acknowledged_at': datetime.now()
            }
            
            result = await andon_service.acknowledge_andon_event(event_id, user_id)
            
            assert isinstance(result, dict)
            assert result['status'] == 'acknowledged'
            assert result['acknowledged_by'] == user_id
            assert 'acknowledged_at' in result
            
            mock_get.assert_called_once_with(event_id)
            mock_update.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_acknowledge_andon_event_already_acknowledged(self, andon_service):
        """Test acknowledging already acknowledged Andon event"""
        event_id = str(uuid4())
        user_id = str(uuid4())
        
        with patch.object(andon_service, 'get_andon_event') as mock_get:
            mock_get.return_value = {
                'id': event_id,
                'status': 'acknowledged',
                'acknowledged_by': str(uuid4())
            }
            
            with pytest.raises(BusinessLogicError, match="Event already acknowledged"):
                await andon_service.acknowledge_andon_event(event_id, user_id)
    
    @pytest.mark.asyncio
    async def test_resolve_andon_event_success(self, andon_service):
        """Test successful Andon event resolution"""
        event_id = str(uuid4())
        user_id = str(uuid4())
        resolution_notes = "Issue resolved by replacing faulty component"
        
        with patch.object(andon_service, 'get_andon_event') as mock_get, \
             patch.object(andon_service, 'update_andon_event') as mock_update, \
             patch.object(andon_service, 'stop_escalation') as mock_stop:
            
            mock_get.return_value = {
                'id': event_id,
                'status': 'acknowledged',
                'line_id': str(uuid4()),
                'equipment_code': 'BP01.PACK.BAG1'
            }
            
            mock_update.return_value = {
                'id': event_id,
                'status': 'resolved',
                'resolved_by': user_id,
                'resolved_at': datetime.now(),
                'resolution_notes': resolution_notes
            }
            
            mock_stop.return_value = None
            
            result = await andon_service.resolve_andon_event(event_id, user_id, resolution_notes)
            
            assert isinstance(result, dict)
            assert result['status'] == 'resolved'
            assert result['resolved_by'] == user_id
            assert result['resolution_notes'] == resolution_notes
            assert 'resolved_at' in result
            
            mock_get.assert_called_once_with(event_id)
            mock_update.assert_called_once()
            mock_stop.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_resolve_andon_event_not_acknowledged(self, andon_service):
        """Test resolving unacknowledged Andon event"""
        event_id = str(uuid4())
        user_id = str(uuid4())
        
        with patch.object(andon_service, 'get_andon_event') as mock_get:
            mock_get.return_value = {
                'id': event_id,
                'status': 'open'
            }
            
            with pytest.raises(BusinessLogicError, match="Event must be acknowledged before resolution"):
                await andon_service.resolve_andon_event(event_id, user_id, "Resolution notes")
    
    @pytest.mark.asyncio
    async def test_escalate_andon_event_success(self, andon_service):
        """Test successful Andon event escalation"""
        event_id = str(uuid4())
        user_id = str(uuid4())
        
        with patch.object(andon_service, 'get_andon_event') as mock_get, \
             patch.object(andon_service, 'update_andon_event') as mock_update, \
             patch.object(andon_service, 'send_escalation_notification') as mock_notify:
            
            mock_get.return_value = {
                'id': event_id,
                'status': 'open',
                'escalation_level': 1,
                'priority': 'high',
                'line_id': str(uuid4()),
                'equipment_code': 'BP01.PACK.BAG1'
            }
            
            mock_update.return_value = {
                'id': event_id,
                'status': 'escalated',
                'escalation_level': 2,
                'escalated_by': user_id,
                'escalated_at': datetime.now()
            }
            
            mock_notify.return_value = None
            
            result = await andon_service.escalate_andon_event(event_id, user_id)
            
            assert isinstance(result, dict)
            assert result['status'] == 'escalated'
            assert result['escalation_level'] == 2
            assert result['escalated_by'] == user_id
            assert 'escalated_at' in result
            
            mock_get.assert_called_once_with(event_id)
            mock_update.assert_called_once()
            mock_notify.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_get_active_andon_events(self, andon_service):
        """Test retrieval of active Andon events"""
        with patch.object(andon_service, 'query_andon_events') as mock_query:
            mock_query.return_value = [
                {
                    'id': str(uuid4()),
                    'line_id': str(uuid4()),
                    'equipment_code': 'BP01.PACK.BAG1',
                    'event_type': 'stop',
                    'priority': 'high',
                    'status': 'open',
                    'created_at': datetime.now()
                },
                {
                    'id': str(uuid4()),
                    'line_id': str(uuid4()),
                    'equipment_code': 'BP01.LOAD.BASKET1',
                    'event_type': 'quality',
                    'priority': 'medium',
                    'status': 'acknowledged',
                    'created_at': datetime.now()
                }
            ]
            
            result = await andon_service.get_active_andon_events()
            
            assert isinstance(result, list)
            assert len(result) == 2
            
            for event in result:
                assert 'id' in event
                assert 'line_id' in event
                assert 'equipment_code' in event
                assert 'event_type' in event
                assert 'priority' in event
                assert 'status' in event
                assert event['status'] in ['open', 'acknowledged', 'escalated']
            
            mock_query.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_get_andon_dashboard_data(self, andon_service):
        """Test Andon dashboard data aggregation"""
        with patch.object(andon_service, 'get_active_andon_events') as mock_active, \
             patch.object(andon_service, 'get_andon_statistics') as mock_stats, \
             patch.object(andon_service, 'get_andon_trends') as mock_trends:
            
            mock_active.return_value = [
                {'id': str(uuid4()), 'priority': 'critical', 'status': 'open'},
                {'id': str(uuid4()), 'priority': 'high', 'status': 'acknowledged'},
                {'id': str(uuid4()), 'priority': 'medium', 'status': 'open'}
            ]
            
            mock_stats.return_value = {
                'total_events_today': 15,
                'resolved_events_today': 12,
                'average_resolution_time': 25.5,
                'critical_events_pending': 2
            }
            
            mock_trends.return_value = [
                {'hour': i, 'event_count': 2 + (i % 3)}
                for i in range(24)
            ]
            
            result = await andon_service.get_andon_dashboard_data()
            
            assert isinstance(result, dict)
            assert 'active_events' in result
            assert 'statistics' in result
            assert 'trends' in result
            assert 'priority_summary' in result
            
            # Verify active events
            active_events = result['active_events']
            assert isinstance(active_events, list)
            assert len(active_events) == 3
            
            # Verify statistics
            stats = result['statistics']
            assert 'total_events_today' in stats
            assert 'resolved_events_today' in stats
            assert 'average_resolution_time' in stats
            
            # Verify priority summary
            priority_summary = result['priority_summary']
            assert 'critical' in priority_summary
            assert 'high' in priority_summary
            assert 'medium' in priority_summary
            assert 'low' in priority_summary
    
    @pytest.mark.asyncio
    async def test_get_andon_analytics_report(self, andon_service):
        """Test comprehensive Andon analytics report"""
        with patch.object(andon_service, 'get_andon_historical_data') as mock_historical, \
             patch.object(andon_service, 'calculate_response_metrics') as mock_response, \
             patch.object(andon_service, 'get_top_equipment_by_events') as mock_equipment, \
             patch.object(andon_service, 'get_andon_trends') as mock_trends, \
             patch.object(andon_service, 'generate_andon_insights') as mock_insights:
            
            mock_historical.return_value = [
                {'date': datetime.now().date() - timedelta(days=i), 'event_count': 10 + i}
                for i in range(30)
            ]
            
            mock_response.return_value = {
                'critical': {'average_response_time': 5.2, 'first_time_resolution': 0.85},
                'high': {'average_response_time': 12.5, 'first_time_resolution': 0.78},
                'medium': {'average_response_time': 25.3, 'first_time_resolution': 0.92},
                'low': {'average_response_time': 45.1, 'first_time_resolution': 0.95}
            }
            
            mock_equipment.return_value = [
                {'equipment_code': 'BP01.PACK.BAG1', 'event_count': 25, 'downtime_hours': 12.5},
                {'equipment_code': 'BP01.LOAD.BASKET1', 'event_count': 18, 'downtime_hours': 8.2}
            ]
            
            mock_trends.return_value = {
                'daily_patterns': [{'hour': i, 'average_events': 2 + (i % 4)} for i in range(24)],
                'weekly_patterns': [{'day': i, 'average_events': 15 + i} for i in range(7)]
            }
            
            mock_insights.return_value = [
                'Equipment BP01.PACK.BAG1 shows high fault frequency',
                'Critical events have good response times',
                'Consider preventive maintenance for top failing equipment'
            ]
            
            result = await andon_service.get_andon_analytics_report()
            
            assert isinstance(result, dict)
            assert 'historical_data' in result
            assert 'response_metrics' in result
            assert 'equipment_analysis' in result
            assert 'trend_analysis' in result
            assert 'insights' in result
            assert 'recommendations' in result
            
            # Verify response metrics structure
            response_metrics = result['response_metrics']
            assert 'critical' in response_metrics
            assert 'high' in response_metrics
            assert 'medium' in response_metrics
            assert 'low' in response_metrics
            
            # Verify equipment analysis
            equipment_analysis = result['equipment_analysis']
            assert isinstance(equipment_analysis, list)
            assert len(equipment_analysis) == 2
            
            # Verify insights
            insights = result['insights']
            assert isinstance(insights, list)
            assert len(insights) > 0


class TestPLCIntegratedAndonService:
    """Test cases for PLCIntegratedAndonService"""
    
    @pytest.fixture
    def plc_andon_service(self):
        """Create PLCIntegratedAndonService instance"""
        return PLCIntegratedAndonService()
    
    @pytest.fixture
    def sample_plc_fault_data(self):
        """Sample PLC fault data"""
        return {
            'equipment_code': 'BP01.PACK.BAG1',
            'fault_bits': [True, False, True, False] + [False] * 60,
            'fault_names': ['Motor Overload', 'Sensor Fault', 'Communication Error'],
            'alarm_levels': ['critical', 'high', 'medium'],
            'timestamp': datetime.now()
        }
    
    @pytest.mark.asyncio
    async def test_process_plc_faults_success(self, plc_andon_service, sample_plc_fault_data):
        """Test successful PLC fault processing"""
        with patch.object(plc_andon_service, 'analyze_plc_faults') as mock_analyze, \
             patch.object(plc_andon_service, 'create_andon_from_plc_faults') as mock_create, \
             patch.object(plc_andon_service, 'is_duplicate_andon_event') as mock_duplicate:
            
            mock_analyze.return_value = [
                {
                    'fault_name': 'Motor Overload',
                    'priority': 'critical',
                    'event_type': 'maintenance',
                    'description': 'Motor overload detected on BP01.PACK.BAG1'
                },
                {
                    'fault_name': 'Sensor Fault',
                    'priority': 'high',
                    'event_type': 'maintenance',
                    'description': 'Sensor fault detected on BP01.PACK.BAG1'
                }
            ]
            
            mock_duplicate.return_value = False
            
            mock_create.return_value = [
                {
                    'id': str(uuid4()),
                    'line_id': str(uuid4()),
                    'equipment_code': 'BP01.PACK.BAG1',
                    'event_type': 'maintenance',
                    'priority': 'critical',
                    'description': 'Motor overload detected on BP01.PACK.BAG1',
                    'status': 'open'
                },
                {
                    'id': str(uuid4()),
                    'line_id': str(uuid4()),
                    'equipment_code': 'BP01.PACK.BAG1',
                    'event_type': 'maintenance',
                    'priority': 'high',
                    'description': 'Sensor fault detected on BP01.PACK.BAG1',
                    'status': 'open'
                }
            ]
            
            result = await plc_andon_service.process_plc_faults(sample_plc_fault_data)
            
            assert isinstance(result, list)
            assert len(result) == 2
            
            for event in result:
                assert 'id' in event
                assert 'equipment_code' in event
                assert 'event_type' in event
                assert 'priority' in event
                assert 'status' in event
                assert event['equipment_code'] == 'BP01.PACK.BAG1'
            
            mock_analyze.assert_called_once()
            mock_create.assert_called_once()
            mock_duplicate.assert_called()
    
    @pytest.mark.asyncio
    async def test_process_plc_faults_duplicate_prevention(self, plc_andon_service, sample_plc_fault_data):
        """Test duplicate Andon event prevention"""
        with patch.object(plc_andon_service, 'analyze_plc_faults') as mock_analyze, \
             patch.object(plc_andon_service, 'is_duplicate_andon_event') as mock_duplicate:
            
            mock_analyze.return_value = [
                {
                    'fault_name': 'Motor Overload',
                    'priority': 'critical',
                    'event_type': 'maintenance',
                    'description': 'Motor overload detected on BP01.PACK.BAG1'
                }
            ]
            
            mock_duplicate.return_value = True  # Duplicate detected
            
            result = await plc_andon_service.process_plc_faults(sample_plc_fault_data)
            
            # Should return empty list due to duplicate prevention
            assert isinstance(result, list)
            assert len(result) == 0
            
            mock_analyze.assert_called_once()
            mock_duplicate.assert_called_once()
    
    def test_analyze_plc_faults_success(self, plc_andon_service, sample_plc_fault_data):
        """Test PLC fault analysis"""
        result = plc_andon_service._analyze_plc_faults(sample_plc_fault_data)
        
        assert isinstance(result, list)
        assert len(result) == 2  # Two active faults
        
        for fault in result:
            assert 'fault_name' in fault
            assert 'priority' in fault
            assert 'event_type' in fault
            assert 'description' in fault
            assert fault['priority'] in ['critical', 'high', 'medium', 'low']
            assert fault['event_type'] in ['stop', 'quality', 'maintenance', 'material']
    
    def test_categorize_fault_critical(self, plc_andon_service):
        """Test fault categorization for critical faults"""
        fault_name = "Motor Overload"
        equipment_code = "BP01.PACK.BAG1"
        
        result = plc_andon_service._categorize_fault(fault_name, equipment_code)
        
        assert result['priority'] == 'critical'
        assert result['event_type'] == 'maintenance'
        assert 'description' in result
        assert fault_name in result['description']
        assert equipment_code in result['description']
    
    def test_categorize_fault_high(self, plc_andon_service):
        """Test fault categorization for high priority faults"""
        fault_name = "Sensor Fault"
        equipment_code = "BP01.PACK.BAG1"
        
        result = plc_andon_service._categorize_fault(fault_name, equipment_code)
        
        assert result['priority'] == 'high'
        assert result['event_type'] == 'maintenance'
        assert 'description' in result
    
    def test_categorize_fault_unknown(self, plc_andon_service):
        """Test fault categorization for unknown faults"""
        fault_name = "Unknown Fault"
        equipment_code = "BP01.PACK.BAG1"
        
        result = plc_andon_service._categorize_fault(fault_name, equipment_code)
        
        # Should default to medium priority for unknown faults
        assert result['priority'] == 'medium'
        assert result['event_type'] == 'maintenance'
        assert 'description' in result
    
    @pytest.mark.asyncio
    async def test_create_andon_from_plc_faults_success(self, plc_andon_service):
        """Test Andon event creation from PLC faults"""
        analyzed_faults = [
            {
                'fault_name': 'Motor Overload',
                'priority': 'critical',
                'event_type': 'maintenance',
                'description': 'Motor overload detected'
            },
            {
                'fault_name': 'Sensor Fault',
                'priority': 'high',
                'event_type': 'maintenance',
                'description': 'Sensor fault detected'
            }
        ]
        
        equipment_code = 'BP01.PACK.BAG1'
        line_id = str(uuid4())
        
        with patch.object(plc_andon_service, 'create_andon_event') as mock_create:
            mock_create.side_effect = [
                {'id': str(uuid4()), 'status': 'open'},
                {'id': str(uuid4()), 'status': 'open'}
            ]
            
            result = await plc_andon_service._create_andon_from_plc_faults(
                analyzed_faults, equipment_code, line_id
            )
            
            assert isinstance(result, list)
            assert len(result) == 2
            
            for event in result:
                assert 'id' in event
                assert 'status' in event
                assert event['status'] == 'open'
            
            assert mock_create.call_count == 2
    
    def test_is_duplicate_andon_event_true(self, plc_andon_service):
        """Test duplicate Andon event detection (true case)"""
        equipment_code = 'BP01.PACK.BAG1'
        fault_name = 'Motor Overload'
        
        with patch.object(plc_andon_service, 'get_recent_andon_events') as mock_recent:
            mock_recent.return_value = [
                {
                    'equipment_code': equipment_code,
                    'description': 'Motor overload detected',
                    'created_at': datetime.now() - timedelta(minutes=5)
                }
            ]
            
            result = plc_andon_service._is_duplicate_andon_event(
                equipment_code, fault_name
            )
            
            assert result is True
            mock_recent.assert_called_once()
    
    def test_is_duplicate_andon_event_false(self, plc_andon_service):
        """Test duplicate Andon event detection (false case)"""
        equipment_code = 'BP01.PACK.BAG1'
        fault_name = 'Motor Overload'
        
        with patch.object(plc_andon_service, 'get_recent_andon_events') as mock_recent:
            mock_recent.return_value = []  # No recent events
            
            result = plc_andon_service._is_duplicate_andon_event(
                equipment_code, fault_name
            )
            
            assert result is False
            mock_recent.assert_called_once()
    
    def test_classify_fault_category_for_andon_critical(self, plc_andon_service):
        """Test fault category classification for critical events"""
        fault_info = {
            'name': 'Motor Overload',
            'severity': 'critical',
            'category': 'mechanical'
        }
        
        result = plc_andon_service._classify_fault_category_for_andon(fault_info)
        
        assert result['event_type'] == 'maintenance'
        assert result['priority'] == 'critical'
        assert 'description' in result
    
    def test_classify_fault_category_for_andon_quality(self, plc_andon_service):
        """Test fault category classification for quality events"""
        fault_info = {
            'name': 'Quality Check Failed',
            'severity': 'high',
            'category': 'quality'
        }
        
        result = plc_andon_service._classify_fault_category_for_andon(fault_info)
        
        assert result['event_type'] == 'quality'
        assert result['priority'] == 'high'
        assert 'description' in result


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
