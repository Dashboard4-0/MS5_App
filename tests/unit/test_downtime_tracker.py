"""
MS5.0 Floor Dashboard - Downtime Tracker Unit Tests

Tests the downtime tracking service with the precision of cosmic monitoring.
Every downtime event is tracked with the reliability of a starship's diagnostics.

Coverage Requirements:
- 100% method coverage
- 100% event detection coverage
- All categorization scenarios tested
- All integration paths verified
"""

import pytest
import pytest_asyncio
from unittest.mock import AsyncMock, Mock, patch
from datetime import datetime, timezone, timedelta, date
from uuid import uuid4
import structlog

from backend.app.services.downtime_tracker import DowntimeTracker, DowntimeReasonCode
from backend.app.services.plc_integrated_downtime_tracker import PLCIntegratedDowntimeTracker
from backend.app.models.production import (
    DowntimeEventCreate, DowntimeEventUpdate, DowntimeEventResponse,
    DowntimeCategory
)
from backend.app.utils.exceptions import (
    NotFoundError, ValidationError, ConflictError, BusinessLogicError
)


class TestDowntimeTracker:
    """Comprehensive tests for DowntimeTracker."""
    
    @pytest.fixture
    def tracker(self):
        """Create a DowntimeTracker instance for testing."""
        return DowntimeTracker()
    
    @pytest.fixture
    def mock_db_session(self):
        """Create a mock database session."""
        session = AsyncMock()
        session.execute = AsyncMock()
        session.commit = AsyncMock()
        session.rollback = AsyncMock()
        return session
    
    @pytest.fixture
    def sample_downtime_event(self):
        """Provide sample downtime event data."""
        return {
            "id": str(uuid4()),
            "equipment_code": "EQ_001",
            "line_id": str(uuid4()),
            "start_time": datetime.now(timezone.utc),
            "end_time": None,
            "duration_minutes": None,
            "category": DowntimeCategory.PLANNED,
            "reason_code": DowntimeReasonCode.MAINTENANCE,
            "description": "Scheduled maintenance",
            "status": "active",
            "created_at": datetime.now(timezone.utc)
        }
    
    @pytest.mark.asyncio
    async def test_create_downtime_event_success(self, tracker, mock_db_session, sample_downtime_event):
        """Test successful downtime event creation."""
        # Arrange
        create_data = DowntimeEventCreate(
            equipment_code="EQ_001",
            line_id=sample_downtime_event["line_id"],
            start_time=sample_downtime_event["start_time"],
            category=DowntimeCategory.PLANNED,
            reason_code=DowntimeReasonCode.MAINTENANCE,
            description="Scheduled maintenance"
        )
        
        # Mock equipment existence check
        mock_equipment_check = Mock()
        mock_equipment_check.scalar_one_or_none.return_value = {"equipment_code": "EQ_001"}
        mock_db_session.execute.return_value = mock_equipment_check
        
        with patch('backend.app.database.execute_scalar', return_value=sample_downtime_event["id"]):
            # Act
            result = await tracker.create_downtime_event(create_data, mock_db_session)
            
            # Assert
            assert result is not None
            assert result.equipment_code == create_data.equipment_code
            assert result.line_id == create_data.line_id
            assert result.category == create_data.category
            assert result.reason_code == create_data.reason_code
            assert result.status == "active"
            mock_db_session.commit.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_create_downtime_event_equipment_not_found(self, tracker, mock_db_session):
        """Test downtime event creation with non-existent equipment."""
        # Arrange
        create_data = DowntimeEventCreate(
            equipment_code="NONEXISTENT",
            line_id=str(uuid4()),
            start_time=datetime.now(timezone.utc),
            category=DowntimeCategory.PLANNED,
            reason_code=DowntimeReasonCode.MAINTENANCE,
            description="Test downtime"
        )
        
        # Mock equipment not found
        mock_equipment_check = Mock()
        mock_equipment_check.scalar_one_or_none.return_value = None
        mock_db_session.execute.return_value = mock_equipment_check
        
        # Act & Assert
        with pytest.raises(NotFoundError, match="Equipment NONEXISTENT not found"):
            await tracker.create_downtime_event(create_data, mock_db_session)
        
        mock_db_session.rollback.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_end_downtime_event_success(self, tracker, mock_db_session, sample_downtime_event):
        """Test successful downtime event ending."""
        # Arrange
        event_id = sample_downtime_event["id"]
        end_time = datetime.now(timezone.utc)
        
        # Mock existing event check
        mock_existing = Mock()
        mock_existing.scalar_one_or_none.return_value = sample_downtime_event
        mock_db_session.execute.return_value = mock_existing
        
        with patch('backend.app.database.execute_update', return_value=True):
            # Act
            result = await tracker.end_downtime_event(event_id, end_time, mock_db_session)
            
            # Assert
            assert result is True
            mock_db_session.commit.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_end_downtime_event_not_found(self, tracker, mock_db_session):
        """Test ending downtime event when event doesn't exist."""
        # Arrange
        event_id = str(uuid4())
        end_time = datetime.now(timezone.utc)
        
        # Mock event not found
        mock_existing = Mock()
        mock_existing.scalar_one_or_none.return_value = None
        mock_db_session.execute.return_value = mock_existing
        
        # Act & Assert
        with pytest.raises(NotFoundError, match=f"Downtime event {event_id} not found"):
            await tracker.end_downtime_event(event_id, end_time, mock_db_session)
    
    @pytest.mark.asyncio
    async def test_end_downtime_event_already_ended(self, tracker, mock_db_session):
        """Test ending downtime event when already ended."""
        # Arrange
        event_id = str(uuid4())
        end_time = datetime.now(timezone.utc)
        
        already_ended_event = {
            "id": event_id,
            "end_time": datetime.now(timezone.utc) - timedelta(hours=1),
            "status": "completed"
        }
        
        mock_existing = Mock()
        mock_existing.scalar_one_or_none.return_value = already_ended_event
        mock_db_session.execute.return_value = mock_existing
        
        # Act & Assert
        with pytest.raises(BusinessLogicError, match="Downtime event is already ended"):
            await tracker.end_downtime_event(event_id, end_time, mock_db_session)
    
    @pytest.mark.asyncio
    async def test_get_downtime_event_success(self, tracker, mock_db_session, sample_downtime_event):
        """Test successful downtime event retrieval."""
        # Arrange
        event_id = sample_downtime_event["id"]
        
        mock_result = Mock()
        mock_result.scalar_one_or_none.return_value = sample_downtime_event
        mock_db_session.execute.return_value = mock_result
        
        # Act
        result = await tracker.get_downtime_event(event_id, mock_db_session)
        
        # Assert
        assert result is not None
        assert result.id == event_id
        assert result.equipment_code == sample_downtime_event["equipment_code"]
        assert result.category == sample_downtime_event["category"]
    
    @pytest.mark.asyncio
    async def test_get_downtime_events_by_equipment_success(self, tracker, mock_db_session):
        """Test successful retrieval of downtime events by equipment."""
        # Arrange
        equipment_code = "EQ_001"
        equipment_events = [
            {
                "id": str(uuid4()),
                "equipment_code": equipment_code,
                "category": DowntimeCategory.PLANNED,
                "status": "completed"
            },
            {
                "id": str(uuid4()),
                "equipment_code": equipment_code,
                "category": DowntimeCategory.UNPLANNED,
                "status": "active"
            }
        ]
        
        mock_result = Mock()
        mock_result.scalars.return_value.all.return_value = equipment_events
        mock_db_session.execute.return_value = mock_result
        
        # Act
        result = await tracker.get_downtime_events_by_equipment(equipment_code, mock_db_session)
        
        # Assert
        assert len(result) == 2
        assert all(event.equipment_code == equipment_code for event in result)
    
    @pytest.mark.asyncio
    async def test_get_downtime_events_by_category_success(self, tracker, mock_db_session):
        """Test successful retrieval of downtime events by category."""
        # Arrange
        category = DowntimeCategory.UNPLANNED
        unplanned_events = [
            {
                "id": str(uuid4()),
                "equipment_code": "EQ_001",
                "category": category,
                "reason_code": DowntimeReasonCode.MECHANICAL_FAULT
            }
        ]
        
        mock_result = Mock()
        mock_result.scalars.return_value.all.return_value = unplanned_events
        mock_db_session.execute.return_value = mock_result
        
        # Act
        result = await tracker.get_downtime_events_by_category(category, mock_db_session)
        
        # Assert
        assert len(result) == 1
        assert result[0].category == category
    
    @pytest.mark.asyncio
    async def test_calculate_downtime_statistics_success(self, tracker, mock_db_session):
        """Test downtime statistics calculation."""
        # Arrange
        equipment_code = "EQ_001"
        start_date = datetime.now(timezone.utc) - timedelta(days=30)
        end_date = datetime.now(timezone.utc)
        
        # Mock statistics data
        stats_data = {
            "total_downtime_minutes": 1200,
            "planned_downtime_minutes": 800,
            "unplanned_downtime_minutes": 400,
            "total_events": 25,
            "avg_downtime_per_event": 48.0,
            "availability_percentage": 91.7
        }
        
        mock_result = Mock()
        mock_result.scalar_one_or_none.return_value = stats_data
        mock_db_session.execute.return_value = mock_result
        
        # Act
        result = await tracker.calculate_downtime_statistics(
            equipment_code, start_date, end_date, mock_db_session
        )
        
        # Assert
        assert result is not None
        assert result["total_downtime_minutes"] == 1200
        assert result["planned_downtime_minutes"] == 800
        assert result["unplanned_downtime_minutes"] == 400
        assert result["total_events"] == 25
        assert result["availability_percentage"] == 91.7
    
    def test_categorize_downtime_by_reason_code(self, tracker):
        """Test downtime categorization by reason code."""
        # Test cases for different reason codes
        test_cases = [
            (DowntimeReasonCode.MECHANICAL_FAULT, DowntimeCategory.UNPLANNED),
            (DowntimeReasonCode.ELECTRICAL_FAULT, DowntimeCategory.UNPLANNED),
            (DowntimeReasonCode.MAINTENANCE, DowntimeCategory.PLANNED),
            (DowntimeReasonCode.CHANGEOVER, DowntimeCategory.PLANNED),
            (DowntimeReasonCode.MATERIAL_SHORTAGE, DowntimeCategory.UNPLANNED),
            (DowntimeReasonCode.QUALITY_ISSUE, DowntimeCategory.UNPLANNED),
        ]
        
        for reason_code, expected_category in test_cases:
            result = tracker._categorize_downtime_by_reason_code(reason_code)
            assert result == expected_category
    
    def test_validate_downtime_event_data_valid(self, tracker):
        """Test downtime event data validation with valid data."""
        # Arrange
        valid_data = DowntimeEventCreate(
            equipment_code="EQ_001",
            line_id=str(uuid4()),
            start_time=datetime.now(timezone.utc),
            category=DowntimeCategory.PLANNED,
            reason_code=DowntimeReasonCode.MAINTENANCE,
            description="Valid downtime event"
        )
        
        # Act
        result = tracker._validate_downtime_event_data(valid_data)
        
        # Assert
        assert result is True
    
    def test_validate_downtime_event_data_invalid(self, tracker):
        """Test downtime event data validation with invalid data."""
        # Test cases for invalid data
        invalid_cases = [
            # Empty equipment code
            DowntimeEventCreate(
                equipment_code="", line_id=str(uuid4()), start_time=datetime.now(timezone.utc),
                category=DowntimeCategory.PLANNED, reason_code=DowntimeReasonCode.MAINTENANCE,
                description="Test"
            ),
            # Invalid category
            DowntimeEventCreate(
                equipment_code="EQ_001", line_id=str(uuid4()), start_time=datetime.now(timezone.utc),
                category="INVALID", reason_code=DowntimeReasonCode.MAINTENANCE,
                description="Test"
            ),
            # Invalid reason code
            DowntimeEventCreate(
                equipment_code="EQ_001", line_id=str(uuid4()), start_time=datetime.now(timezone.utc),
                category=DowntimeCategory.PLANNED, reason_code="INVALID",
                description="Test"
            ),
            # Empty description
            DowntimeEventCreate(
                equipment_code="EQ_001", line_id=str(uuid4()), start_time=datetime.now(timezone.utc),
                category=DowntimeCategory.PLANNED, reason_code=DowntimeReasonCode.MAINTENANCE,
                description=""
            ),
        ]
        
        for invalid_data in invalid_cases:
            with pytest.raises(ValidationError):
                tracker._validate_downtime_event_data(invalid_data)
    
    @pytest.mark.asyncio
    async def test_detect_automatic_downtime_success(self, tracker, mock_db_session):
        """Test automatic downtime detection."""
        # Arrange
        equipment_code = "EQ_001"
        status_change = {
            "equipment_code": equipment_code,
            "previous_status": "running",
            "current_status": "stopped",
            "timestamp": datetime.now(timezone.utc)
        }
        
        # Mock equipment configuration
        equipment_config = {
            "equipment_code": equipment_code,
            "auto_downtime_detection": True,
            "downtime_threshold_minutes": 5
        }
        
        mock_result = Mock()
        mock_result.scalar_one_or_none.return_value = equipment_config
        mock_db_session.execute.return_value = mock_result
        
        with patch.object(tracker, 'create_downtime_event', return_value=Mock(id=str(uuid4()))):
            # Act
            result = await tracker.detect_automatic_downtime(status_change, mock_db_session)
            
            # Assert
            assert result["detected"] is True
            assert "downtime_event_id" in result
    
    @pytest.mark.asyncio
    async def test_detect_automatic_downtime_disabled(self, tracker, mock_db_session):
        """Test automatic downtime detection when disabled."""
        # Arrange
        equipment_code = "EQ_001"
        status_change = {
            "equipment_code": equipment_code,
            "previous_status": "running",
            "current_status": "stopped",
            "timestamp": datetime.now(timezone.utc)
        }
        
        # Mock equipment configuration with auto-detection disabled
        equipment_config = {
            "equipment_code": equipment_code,
            "auto_downtime_detection": False
        }
        
        mock_result = Mock()
        mock_result.scalar_one_or_none.return_value = equipment_config
        mock_db_session.execute.return_value = mock_result
        
        # Act
        result = await tracker.detect_automatic_downtime(status_change, mock_db_session)
        
        # Assert
        assert result["detected"] is False
        assert result["reason"] == "Automatic downtime detection disabled"


class TestPLCIntegratedDowntimeTracker:
    """Comprehensive tests for PLCIntegratedDowntimeTracker."""
    
    @pytest.fixture
    def tracker(self):
        """Create a PLCIntegratedDowntimeTracker instance for testing."""
        return PLCIntegratedDowntimeTracker()
    
    @pytest.fixture
    def mock_db_session(self):
        """Create a mock database session."""
        session = AsyncMock()
        session.execute = AsyncMock()
        session.commit = AsyncMock()
        session.rollback = AsyncMock()
        return session
    
    @pytest.mark.asyncio
    async def test_process_plc_downtime_signal_success(self, tracker, mock_db_session):
        """Test PLC downtime signal processing."""
        # Arrange
        plc_signal = {
            "equipment_code": "EQ_001",
            "signal_type": "STATUS_CHANGE",
            "previous_status": "running",
            "current_status": "stopped",
            "timestamp": datetime.now(timezone.utc),
            "additional_data": {"reason": "MECHANICAL_FAULT", "fault_code": "F001"}
        }
        
        # Mock equipment configuration
        equipment_config = {
            "equipment_code": "EQ_001",
            "auto_downtime_detection": True,
            "downtime_threshold_minutes": 5
        }
        
        mock_result = Mock()
        mock_result.scalar_one_or_none.return_value = equipment_config
        mock_db_session.execute.return_value = mock_result
        
        with patch.object(tracker, 'create_downtime_event', return_value=Mock(id=str(uuid4()))):
            # Act
            result = await tracker.process_plc_downtime_signal(plc_signal, mock_db_session)
            
            # Assert
            assert result["processed"] is True
            assert "downtime_event_id" in result
    
    @pytest.mark.asyncio
    async def test_process_plc_downtime_signal_auto_detection_disabled(self, tracker, mock_db_session):
        """Test PLC downtime signal processing with auto-detection disabled."""
        # Arrange
        plc_signal = {
            "equipment_code": "EQ_001",
            "signal_type": "STATUS_CHANGE",
            "previous_status": "running",
            "current_status": "stopped",
            "timestamp": datetime.now(timezone.utc)
        }
        
        # Mock equipment configuration with auto-detection disabled
        equipment_config = {
            "equipment_code": "EQ_001",
            "auto_downtime_detection": False
        }
        
        mock_result = Mock()
        mock_result.scalar_one_or_none.return_value = equipment_config
        mock_db_session.execute.return_value = mock_result
        
        # Act
        result = await tracker.process_plc_downtime_signal(plc_signal, mock_db_session)
        
        # Assert
        assert result["processed"] is False
        assert result["reason"] == "Automatic downtime detection disabled"
    
    @pytest.mark.asyncio
    async def test_validate_plc_downtime_signal_valid(self, tracker):
        """Test PLC downtime signal validation with valid signal."""
        # Arrange
        valid_signal = {
            "equipment_code": "EQ_001",
            "signal_type": "STATUS_CHANGE",
            "previous_status": "running",
            "current_status": "stopped",
            "timestamp": datetime.now(timezone.utc)
        }
        
        # Act
        result = tracker._validate_plc_downtime_signal(valid_signal)
        
        # Assert
        assert result is True
    
    @pytest.mark.asyncio
    async def test_validate_plc_downtime_signal_invalid(self, tracker):
        """Test PLC downtime signal validation with invalid signal."""
        # Test cases for invalid signals
        invalid_cases = [
            # Missing equipment_code
            {"signal_type": "STATUS_CHANGE", "previous_status": "running", "current_status": "stopped"},
            # Invalid signal_type
            {"equipment_code": "EQ_001", "signal_type": "INVALID", "previous_status": "running", "current_status": "stopped"},
            # Invalid status values
            {"equipment_code": "EQ_001", "signal_type": "STATUS_CHANGE", "previous_status": "invalid", "current_status": "stopped"},
            # Missing timestamp
            {"equipment_code": "EQ_001", "signal_type": "STATUS_CHANGE", "previous_status": "running", "current_status": "stopped"},
        ]
        
        for invalid_signal in invalid_cases:
            with pytest.raises(ValidationError):
                tracker._validate_plc_downtime_signal(invalid_signal)
    
    @pytest.mark.asyncio
    async def test_map_plc_signal_to_downtime_event_success(self, tracker):
        """Test mapping PLC signal to downtime event."""
        # Arrange
        plc_signal = {
            "equipment_code": "EQ_001",
            "signal_type": "STATUS_CHANGE",
            "previous_status": "running",
            "current_status": "stopped",
            "additional_data": {"reason": "MECHANICAL_FAULT", "fault_code": "F001"}
        }
        
        equipment_config = {
            "equipment_code": "EQ_001",
            "line_id": str(uuid4()),
            "downtime_mapping": {
                "MECHANICAL_FAULT": {
                    "category": "UNPLANNED",
                    "reason_code": "MECHANICAL_FAULT",
                    "description_template": "Mechanical fault: {fault_code}"
                }
            }
        }
        
        # Act
        result = tracker._map_plc_signal_to_downtime_event(plc_signal, equipment_config)
        
        # Assert
        assert result is not None
        assert result["equipment_code"] == "EQ_001"
        assert result["line_id"] == equipment_config["line_id"]
        assert result["category"] == "UNPLANNED"
        assert result["reason_code"] == "MECHANICAL_FAULT"
        assert "F001" in result["description"]
    
    @pytest.mark.asyncio
    async def test_calculate_downtime_impact_analysis_success(self, tracker, mock_db_session):
        """Test downtime impact analysis calculation."""
        # Arrange
        equipment_code = "EQ_001"
        downtime_event_id = str(uuid4())
        
        # Mock impact analysis data
        impact_data = {
            "production_loss_units": 150,
            "production_loss_value": 7500.0,
            "efficiency_impact_percentage": 12.5,
            "affected_operations": ["ASSEMBLY", "PACKAGING"],
            "escalation_level": "HIGH"
        }
        
        mock_result = Mock()
        mock_result.scalar_one_or_none.return_value = impact_data
        mock_db_session.execute.return_value = mock_result
        
        # Act
        result = await tracker.calculate_downtime_impact_analysis(
            equipment_code, downtime_event_id, mock_db_session
        )
        
        # Assert
        assert result is not None
        assert result["production_loss_units"] == 150
        assert result["production_loss_value"] == 7500.0
        assert result["efficiency_impact_percentage"] == 12.5
        assert "affected_operations" in result
        assert "escalation_level" in result
