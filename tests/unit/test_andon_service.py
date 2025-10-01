"""
MS5.0 Floor Dashboard - Andon Service Unit Tests

Tests the Andon service with the precision of emergency response systems.
Every event is handled with the reliability of a starship's alert system.

Coverage Requirements:
- 100% method coverage
- 100% event handling coverage
- All escalation scenarios tested
- All notification paths verified
"""

import pytest
import pytest_asyncio
from unittest.mock import AsyncMock, Mock, patch
from datetime import datetime, timezone, timedelta
from uuid import uuid4
import structlog

from backend.app.services.andon_service import AndonService
from backend.app.services.plc_integrated_andon_service import PLCIntegratedAndonService
from backend.app.models.production import (
    AndonEventCreate, AndonEventUpdate, AndonEventResponse,
    AndonPriority, AndonStatus, AndonEventType
)
from backend.app.utils.exceptions import (
    NotFoundError, ValidationError, ConflictError, BusinessLogicError
)


class TestAndonService:
    """Comprehensive tests for AndonService."""
    
    @pytest.fixture
    def service(self):
        """Create an AndonService instance for testing."""
        return AndonService()
    
    @pytest.fixture
    def mock_db_session(self):
        """Create a mock database session."""
        session = AsyncMock()
        session.execute = AsyncMock()
        session.commit = AsyncMock()
        session.rollback = AsyncMock()
        return session
    
    @pytest.fixture
    def sample_andon_event(self):
        """Provide sample Andon event data."""
        return {
            "id": str(uuid4()),
            "equipment_code": "EQ_001",
            "event_type": AndonEventType.FAULT,
            "priority": AndonPriority.HIGH,
            "description": "Test fault event",
            "status": AndonStatus.OPEN,
            "created_at": datetime.now(timezone.utc),
            "acknowledged_at": None,
            "resolved_at": None,
            "acknowledged_by": None,
            "resolved_by": None
        }
    
    @pytest.mark.asyncio
    async def test_create_andon_event_success(self, service, mock_db_session, sample_andon_event):
        """Test successful Andon event creation."""
        # Arrange
        create_data = AndonEventCreate(
            equipment_code="EQ_001",
            event_type=AndonEventType.FAULT,
            priority=AndonPriority.HIGH,
            description="Test fault event"
        )
        
        # Mock equipment existence check
        mock_equipment_check = Mock()
        mock_equipment_check.scalar_one_or_none.return_value = {"equipment_code": "EQ_001"}
        mock_db_session.execute.return_value = mock_equipment_check
        
        with patch('backend.app.database.execute_scalar', return_value=sample_andon_event["id"]):
            # Act
            result = await service.create_andon_event(create_data, mock_db_session)
            
            # Assert
            assert result is not None
            assert result.equipment_code == create_data.equipment_code
            assert result.event_type == create_data.event_type
            assert result.priority == create_data.priority
            assert result.description == create_data.description
            assert result.status == AndonStatus.OPEN
            mock_db_session.commit.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_create_andon_event_equipment_not_found(self, service, mock_db_session):
        """Test Andon event creation with non-existent equipment."""
        # Arrange
        create_data = AndonEventCreate(
            equipment_code="NONEXISTENT",
            event_type=AndonEventType.FAULT,
            priority=AndonPriority.HIGH,
            description="Test fault event"
        )
        
        # Mock equipment not found
        mock_equipment_check = Mock()
        mock_equipment_check.scalar_one_or_none.return_value = None
        mock_db_session.execute.return_value = mock_equipment_check
        
        # Act & Assert
        with pytest.raises(NotFoundError, match="Equipment NONEXISTENT not found"):
            await service.create_andon_event(create_data, mock_db_session)
        
        mock_db_session.rollback.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_get_andon_event_success(self, service, mock_db_session, sample_andon_event):
        """Test successful Andon event retrieval."""
        # Arrange
        event_id = sample_andon_event["id"]
        
        mock_result = Mock()
        mock_result.scalar_one_or_none.return_value = sample_andon_event
        mock_db_session.execute.return_value = mock_result
        
        # Act
        result = await service.get_andon_event(event_id, mock_db_session)
        
        # Assert
        assert result is not None
        assert result.id == event_id
        assert result.equipment_code == sample_andon_event["equipment_code"]
        assert result.event_type == sample_andon_event["event_type"]
        assert result.status == sample_andon_event["status"]
    
    @pytest.mark.asyncio
    async def test_get_andon_event_not_found(self, service, mock_db_session):
        """Test Andon event retrieval when event doesn't exist."""
        # Arrange
        event_id = str(uuid4())
        
        mock_result = Mock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db_session.execute.return_value = mock_result
        
        # Act & Assert
        with pytest.raises(NotFoundError, match=f"Andon event {event_id} not found"):
            await service.get_andon_event(event_id, mock_db_session)
    
    @pytest.mark.asyncio
    async def test_acknowledge_andon_event_success(self, service, mock_db_session, sample_andon_event):
        """Test successful Andon event acknowledgment."""
        # Arrange
        event_id = sample_andon_event["id"]
        user_id = str(uuid4())
        
        # Mock existing event check
        mock_existing = Mock()
        mock_existing.scalar_one_or_none.return_value = sample_andon_event
        mock_db_session.execute.return_value = mock_existing
        
        with patch('backend.app.database.execute_update', return_value=True):
            # Act
            result = await service.acknowledge_andon_event(event_id, user_id, mock_db_session)
            
            # Assert
            assert result is True
            mock_db_session.commit.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_acknowledge_andon_event_already_acknowledged(self, service, mock_db_session):
        """Test Andon event acknowledgment when already acknowledged."""
        # Arrange
        event_id = str(uuid4())
        user_id = str(uuid4())
        
        already_acknowledged_event = {
            "id": event_id,
            "status": AndonStatus.ACKNOWLEDGED,
            "acknowledged_at": datetime.now(timezone.utc),
            "acknowledged_by": str(uuid4())
        }
        
        mock_existing = Mock()
        mock_existing.scalar_one_or_none.return_value = already_acknowledged_event
        mock_db_session.execute.return_value = mock_existing
        
        # Act & Assert
        with pytest.raises(BusinessLogicError, match="Event is already acknowledged"):
            await service.acknowledge_andon_event(event_id, user_id, mock_db_session)
    
    @pytest.mark.asyncio
    async def test_resolve_andon_event_success(self, service, mock_db_session, sample_andon_event):
        """Test successful Andon event resolution."""
        # Arrange
        event_id = sample_andon_event["id"]
        user_id = str(uuid4())
        resolution_notes = "Issue resolved by replacing faulty component"
        
        # Mock existing event check
        mock_existing = Mock()
        mock_existing.scalar_one_or_none.return_value = sample_andon_event
        mock_db_session.execute.return_value = mock_existing
        
        with patch('backend.app.database.execute_update', return_value=True):
            # Act
            result = await service.resolve_andon_event(event_id, user_id, resolution_notes, mock_db_session)
            
            # Assert
            assert result is True
            mock_db_session.commit.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_resolve_andon_event_not_acknowledged(self, service, mock_db_session):
        """Test Andon event resolution when not acknowledged."""
        # Arrange
        event_id = str(uuid4())
        user_id = str(uuid4())
        resolution_notes = "Issue resolved"
        
        unacknowledged_event = {
            "id": event_id,
            "status": AndonStatus.OPEN,
            "acknowledged_at": None,
            "acknowledged_by": None
        }
        
        mock_existing = Mock()
        mock_existing.scalar_one_or_none.return_value = unacknowledged_event
        mock_db_session.execute.return_value = mock_existing
        
        # Act & Assert
        with pytest.raises(BusinessLogicError, match="Event must be acknowledged before resolution"):
            await service.resolve_andon_event(event_id, user_id, resolution_notes, mock_db_session)
    
    @pytest.mark.asyncio
    async def test_escalate_andon_event_success(self, service, mock_db_session, sample_andon_event):
        """Test successful Andon event escalation."""
        # Arrange
        event_id = sample_andon_event["id"]
        escalation_reason = "No response within timeout period"
        
        # Mock existing event check
        mock_existing = Mock()
        mock_existing.scalar_one_or_none.return_value = sample_andon_event
        mock_db_session.execute.return_value = mock_existing
        
        with patch('backend.app.database.execute_update', return_value=True):
            # Act
            result = await service.escalate_andon_event(event_id, escalation_reason, mock_db_session)
            
            # Assert
            assert result is True
            mock_db_session.commit.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_get_active_andon_events_success(self, service, mock_db_session):
        """Test successful retrieval of active Andon events."""
        # Arrange
        active_events = [
            {
                "id": str(uuid4()),
                "equipment_code": "EQ_001",
                "event_type": AndonEventType.FAULT,
                "priority": AndonPriority.HIGH,
                "status": AndonStatus.OPEN
            },
            {
                "id": str(uuid4()),
                "equipment_code": "EQ_002",
                "event_type": AndonEventType.QUALITY,
                "priority": AndonPriority.MEDIUM,
                "status": AndonStatus.ACKNOWLEDGED
            }
        ]
        
        mock_result = Mock()
        mock_result.scalars.return_value.all.return_value = active_events
        mock_db_session.execute.return_value = mock_result
        
        # Act
        result = await service.get_active_andon_events(mock_db_session)
        
        # Assert
        assert len(result) == 2
        assert all(event.status in [AndonStatus.OPEN, AndonStatus.ACKNOWLEDGED] for event in result)
    
    @pytest.mark.asyncio
    async def test_get_andon_events_by_equipment_success(self, service, mock_db_session):
        """Test successful retrieval of Andon events by equipment."""
        # Arrange
        equipment_code = "EQ_001"
        equipment_events = [
            {
                "id": str(uuid4()),
                "equipment_code": equipment_code,
                "event_type": AndonEventType.FAULT,
                "status": AndonStatus.RESOLVED
            }
        ]
        
        mock_result = Mock()
        mock_result.scalars.return_value.all.return_value = equipment_events
        mock_db_session.execute.return_value = mock_result
        
        # Act
        result = await service.get_andon_events_by_equipment(equipment_code, mock_db_session)
        
        # Assert
        assert len(result) == 1
        assert result[0].equipment_code == equipment_code
    
    @pytest.mark.asyncio
    async def test_get_andon_events_by_priority_success(self, service, mock_db_session):
        """Test successful retrieval of Andon events by priority."""
        # Arrange
        priority = AndonPriority.HIGH
        high_priority_events = [
            {
                "id": str(uuid4()),
                "equipment_code": "EQ_001",
                "priority": priority,
                "status": AndonStatus.OPEN
            }
        ]
        
        mock_result = Mock()
        mock_result.scalars.return_value.all.return_value = high_priority_events
        mock_db_session.execute.return_value = mock_result
        
        # Act
        result = await service.get_andon_events_by_priority(priority, mock_db_session)
        
        # Assert
        assert len(result) == 1
        assert result[0].priority == priority
    
    def test_validate_andon_event_data_valid(self, service):
        """Test Andon event data validation with valid data."""
        # Arrange
        valid_data = AndonEventCreate(
            equipment_code="EQ_001",
            event_type=AndonEventType.FAULT,
            priority=AndonPriority.HIGH,
            description="Valid fault description"
        )
        
        # Act
        result = service._validate_andon_event_data(valid_data)
        
        # Assert
        assert result is True
    
    def test_validate_andon_event_data_invalid(self, service):
        """Test Andon event data validation with invalid data."""
        # Test cases for invalid data
        invalid_cases = [
            # Empty equipment code
            AndonEventCreate(equipment_code="", event_type=AndonEventType.FAULT, priority=AndonPriority.HIGH, description="Test"),
            # Empty description
            AndonEventCreate(equipment_code="EQ_001", event_type=AndonEventType.FAULT, priority=AndonPriority.HIGH, description=""),
            # Invalid event type
            AndonEventCreate(equipment_code="EQ_001", event_type="INVALID", priority=AndonPriority.HIGH, description="Test"),
            # Invalid priority
            AndonEventCreate(equipment_code="EQ_001", event_type=AndonEventType.FAULT, priority="INVALID", description="Test"),
        ]
        
        for invalid_data in invalid_cases:
            with pytest.raises(ValidationError):
                service._validate_andon_event_data(invalid_data)
    
    @pytest.mark.asyncio
    async def test_calculate_andon_statistics_success(self, service, mock_db_session):
        """Test Andon statistics calculation."""
        # Arrange
        equipment_code = "EQ_001"
        start_date = datetime.now(timezone.utc) - timedelta(days=30)
        end_date = datetime.now(timezone.utc)
        
        # Mock statistics data
        stats_data = {
            "total_events": 15,
            "resolved_events": 12,
            "avg_resolution_time": 45.5,
            "events_by_type": {"FAULT": 8, "QUALITY": 4, "MAINTENANCE": 3},
            "events_by_priority": {"HIGH": 5, "MEDIUM": 7, "LOW": 3}
        }
        
        mock_result = Mock()
        mock_result.scalar_one_or_none.return_value = stats_data
        mock_db_session.execute.return_value = mock_result
        
        # Act
        result = await service.calculate_andon_statistics(
            equipment_code, start_date, end_date, mock_db_session
        )
        
        # Assert
        assert result is not None
        assert result["total_events"] == 15
        assert result["resolved_events"] == 12
        assert result["avg_resolution_time"] == 45.5
        assert "events_by_type" in result
        assert "events_by_priority" in result


class TestPLCIntegratedAndonService:
    """Comprehensive tests for PLCIntegratedAndonService."""
    
    @pytest.fixture
    def service(self):
        """Create a PLCIntegratedAndonService instance for testing."""
        return PLCIntegratedAndonService()
    
    @pytest.fixture
    def mock_db_session(self):
        """Create a mock database session."""
        session = AsyncMock()
        session.execute = AsyncMock()
        session.commit = AsyncMock()
        session.rollback = AsyncMock()
        return session
    
    @pytest.mark.asyncio
    async def test_process_plc_andon_signal_success(self, service, mock_db_session):
        """Test PLC Andon signal processing."""
        # Arrange
        plc_signal = {
            "equipment_code": "EQ_001",
            "signal_type": "FAULT",
            "signal_value": 1,
            "timestamp": datetime.now(timezone.utc),
            "additional_data": {"fault_code": "F001", "description": "Motor overload"}
        }
        
        # Mock equipment configuration
        equipment_config = {
            "equipment_code": "EQ_001",
            "andon_settings": {
                "auto_andon_enabled": True,
                "fault_thresholds": {"F001": {"priority": "HIGH", "auto_escalate": True}}
            }
        }
        
        mock_result = Mock()
        mock_result.scalar_one_or_none.return_value = equipment_config
        mock_db_session.execute.return_value = mock_result
        
        with patch.object(service, 'create_andon_event', return_value=Mock(id=str(uuid4()))):
            # Act
            result = await service.process_plc_andon_signal(plc_signal, mock_db_session)
            
            # Assert
            assert result is not None
            assert result["processed"] is True
            assert "andon_event_id" in result
    
    @pytest.mark.asyncio
    async def test_process_plc_andon_signal_auto_andon_disabled(self, service, mock_db_session):
        """Test PLC Andon signal processing with auto-Andon disabled."""
        # Arrange
        plc_signal = {
            "equipment_code": "EQ_001",
            "signal_type": "FAULT",
            "signal_value": 1,
            "timestamp": datetime.now(timezone.utc)
        }
        
        # Mock equipment configuration with auto-Andon disabled
        equipment_config = {
            "equipment_code": "EQ_001",
            "andon_settings": {"auto_andon_enabled": False}
        }
        
        mock_result = Mock()
        mock_result.scalar_one_or_none.return_value = equipment_config
        mock_db_session.execute.return_value = mock_result
        
        # Act
        result = await service.process_plc_andon_signal(plc_signal, mock_db_session)
        
        # Assert
        assert result["processed"] is False
        assert result["reason"] == "Auto-Andon disabled for equipment"
    
    @pytest.mark.asyncio
    async def test_validate_plc_andon_signal_valid(self, service):
        """Test PLC Andon signal validation with valid signal."""
        # Arrange
        valid_signal = {
            "equipment_code": "EQ_001",
            "signal_type": "FAULT",
            "signal_value": 1,
            "timestamp": datetime.now(timezone.utc)
        }
        
        # Act
        result = service._validate_plc_andon_signal(valid_signal)
        
        # Assert
        assert result is True
    
    @pytest.mark.asyncio
    async def test_validate_plc_andon_signal_invalid(self, service):
        """Test PLC Andon signal validation with invalid signal."""
        # Test cases for invalid signals
        invalid_cases = [
            # Missing equipment_code
            {"signal_type": "FAULT", "signal_value": 1, "timestamp": datetime.now(timezone.utc)},
            # Invalid signal_type
            {"equipment_code": "EQ_001", "signal_type": "INVALID", "signal_value": 1, "timestamp": datetime.now(timezone.utc)},
            # Invalid signal_value
            {"equipment_code": "EQ_001", "signal_type": "FAULT", "signal_value": "invalid", "timestamp": datetime.now(timezone.utc)},
            # Missing timestamp
            {"equipment_code": "EQ_001", "signal_type": "FAULT", "signal_value": 1},
        ]
        
        for invalid_signal in invalid_cases:
            with pytest.raises(ValidationError):
                service._validate_plc_andon_signal(invalid_signal)
    
    @pytest.mark.asyncio
    async def test_map_plc_signal_to_andon_event_success(self, service):
        """Test mapping PLC signal to Andon event."""
        # Arrange
        plc_signal = {
            "equipment_code": "EQ_001",
            "signal_type": "FAULT",
            "signal_value": 1,
            "additional_data": {"fault_code": "F001", "description": "Motor overload"}
        }
        
        equipment_config = {
            "andon_settings": {
                "fault_thresholds": {
                    "F001": {
                        "priority": "HIGH",
                        "event_type": "FAULT",
                        "description_template": "Fault {fault_code}: {description}"
                    }
                }
            }
        }
        
        # Act
        result = service._map_plc_signal_to_andon_event(plc_signal, equipment_config)
        
        # Assert
        assert result is not None
        assert result["equipment_code"] == "EQ_001"
        assert result["event_type"] == "FAULT"
        assert result["priority"] == "HIGH"
        assert "F001" in result["description"]
        assert "Motor overload" in result["description"]
    
    @pytest.mark.asyncio
    async def test_check_andon_escalation_conditions_success(self, service, mock_db_session):
        """Test Andon escalation condition checking."""
        # Arrange
        event_id = str(uuid4())
        andon_event = {
            "id": event_id,
            "priority": AndonPriority.HIGH,
            "created_at": datetime.now(timezone.utc) - timedelta(minutes=30),
            "acknowledged_at": None,
            "escalation_settings": {"timeout_minutes": 15}
        }
        
        # Act
        result = await service._check_andon_escalation_conditions(andon_event, mock_db_session)
        
        # Assert
        assert result["should_escalate"] is True
        assert result["escalation_reason"] == "Timeout exceeded"
    
    @pytest.mark.asyncio
    async def test_check_andon_escalation_conditions_no_escalation(self, service, mock_db_session):
        """Test Andon escalation condition checking when no escalation needed."""
        # Arrange
        event_id = str(uuid4())
        andon_event = {
            "id": event_id,
            "priority": AndonPriority.LOW,
            "created_at": datetime.now(timezone.utc) - timedelta(minutes=5),
            "acknowledged_at": None,
            "escalation_settings": {"timeout_minutes": 15}
        }
        
        # Act
        result = await service._check_andon_escalation_conditions(andon_event, mock_db_session)
        
        # Assert
        assert result["should_escalate"] is False