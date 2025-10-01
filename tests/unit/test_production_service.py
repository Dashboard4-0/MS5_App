"""
MS5.0 Floor Dashboard - Production Service Unit Tests

Tests the production service with the precision of cosmic navigation.
Every method is tested for success paths, error conditions, and edge cases.

Coverage Requirements:
- 100% method coverage
- 100% branch coverage
- All exception paths tested
- All validation scenarios covered
"""

import pytest
import pytest_asyncio
from unittest.mock import AsyncMock, Mock, patch
from datetime import datetime, timezone, timedelta
from uuid import uuid4
import structlog

from backend.app.services.production_service import ProductionLineService, ProductionScheduleService
from backend.app.models.production import (
    ProductionLineCreate, ProductionLineUpdate, ProductionLineResponse,
    ProductionScheduleCreate, ProductionScheduleUpdate, ProductionScheduleResponse,
    ScheduleStatus, ProductionLineStatus
)
from backend.app.utils.exceptions import (
    NotFoundError, ValidationError, ConflictError, BusinessLogicError
)


class TestProductionLineService:
    """Comprehensive tests for ProductionLineService."""
    
    @pytest.fixture
    def service(self):
        """Create a ProductionLineService instance for testing."""
        return ProductionLineService()
    
    @pytest.fixture
    def mock_db_session(self):
        """Create a mock database session."""
        session = AsyncMock()
        session.execute = AsyncMock()
        session.commit = AsyncMock()
        session.rollback = AsyncMock()
        return session
    
    @pytest.fixture
    def sample_production_line_data(self):
        """Provide sample production line data."""
        return {
            "id": str(uuid4()),
            "line_code": "LINE_001",
            "line_name": "Test Production Line",
            "line_type": "assembly",
            "status": ProductionLineStatus.ACTIVE,
            "created_at": datetime.now(timezone.utc),
            "updated_at": datetime.now(timezone.utc)
        }
    
    @pytest.mark.asyncio
    async def test_create_production_line_success(self, service, mock_db_session, sample_production_line_data):
        """Test successful production line creation."""
        # Arrange
        create_data = ProductionLineCreate(
            line_code="LINE_001",
            line_name="Test Production Line",
            line_type="assembly"
        )
        
        mock_result = Mock()
        mock_result.scalar_one_or_none.return_value = None  # No existing line
        mock_db_session.execute.return_value = mock_result
        
        with patch('backend.app.database.execute_scalar', return_value=sample_production_line_data["id"]):
            # Act
            result = await service.create_production_line(create_data, mock_db_session)
            
            # Assert
            assert result is not None
            assert result.line_code == create_data.line_code
            assert result.line_name == create_data.line_name
            assert result.line_type == create_data.line_type
            assert result.status == ProductionLineStatus.ACTIVE
            mock_db_session.execute.assert_called_once()
            mock_db_session.commit.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_create_production_line_duplicate_code(self, service, mock_db_session):
        """Test production line creation with duplicate code."""
        # Arrange
        create_data = ProductionLineCreate(
            line_code="LINE_001",
            line_name="Test Production Line",
            line_type="assembly"
        )
        
        mock_result = Mock()
        mock_result.scalar_one_or_none.return_value = {"id": str(uuid4())}  # Existing line
        mock_db_session.execute.return_value = mock_result
        
        # Act & Assert
        with pytest.raises(ConflictError, match="Production line with code LINE_001 already exists"):
            await service.create_production_line(create_data, mock_db_session)
        
        mock_db_session.rollback.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_get_production_line_success(self, service, mock_db_session, sample_production_line_data):
        """Test successful production line retrieval."""
        # Arrange
        line_id = sample_production_line_data["id"]
        
        mock_result = Mock()
        mock_result.scalar_one_or_none.return_value = sample_production_line_data
        mock_db_session.execute.return_value = mock_result
        
        # Act
        result = await service.get_production_line(line_id, mock_db_session)
        
        # Assert
        assert result is not None
        assert result.id == line_id
        assert result.line_code == sample_production_line_data["line_code"]
        assert result.line_name == sample_production_line_data["line_name"]
        mock_db_session.execute.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_get_production_line_not_found(self, service, mock_db_session):
        """Test production line retrieval when line doesn't exist."""
        # Arrange
        line_id = str(uuid4())
        
        mock_result = Mock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db_session.execute.return_value = mock_result
        
        # Act & Assert
        with pytest.raises(NotFoundError, match=f"Production line {line_id} not found"):
            await service.get_production_line(line_id, mock_db_session)
    
    @pytest.mark.asyncio
    async def test_update_production_line_success(self, service, mock_db_session, sample_production_line_data):
        """Test successful production line update."""
        # Arrange
        line_id = sample_production_line_data["id"]
        update_data = ProductionLineUpdate(
            line_name="Updated Production Line",
            status=ProductionLineStatus.MAINTENANCE
        )
        
        # Mock existing line check
        mock_existing = Mock()
        mock_existing.scalar_one_or_none.return_value = sample_production_line_data
        mock_db_session.execute.return_value = mock_existing
        
        # Mock update result
        updated_data = sample_production_line_data.copy()
        updated_data.update({
            "line_name": update_data.line_name,
            "status": update_data.status,
            "updated_at": datetime.now(timezone.utc)
        })
        
        mock_update_result = Mock()
        mock_update_result.scalar_one_or_none.return_value = updated_data
        
        with patch('backend.app.database.execute_update') as mock_update:
            mock_update.return_value = updated_data
            
            # Act
            result = await service.update_production_line(line_id, update_data, mock_db_session)
            
            # Assert
            assert result is not None
            assert result.line_name == update_data.line_name
            assert result.status == update_data.status
            mock_db_session.commit.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_delete_production_line_success(self, service, mock_db_session, sample_production_line_data):
        """Test successful production line deletion."""
        # Arrange
        line_id = sample_production_line_data["id"]
        
        # Mock existing line check
        mock_existing = Mock()
        mock_existing.scalar_one_or_none.return_value = sample_production_line_data
        mock_db_session.execute.return_value = mock_existing
        
        with patch('backend.app.database.execute_update') as mock_update:
            mock_update.return_value = True
            
            # Act
            result = await service.delete_production_line(line_id, mock_db_session)
            
            # Assert
            assert result is True
            mock_db_session.commit.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_list_production_lines_success(self, service, mock_db_session):
        """Test successful production lines listing."""
        # Arrange
        sample_lines = [
            {
                "id": str(uuid4()),
                "line_code": "LINE_001",
                "line_name": "Line 1",
                "status": ProductionLineStatus.ACTIVE
            },
            {
                "id": str(uuid4()),
                "line_code": "LINE_002", 
                "line_name": "Line 2",
                "status": ProductionLineStatus.ACTIVE
            }
        ]
        
        mock_result = Mock()
        mock_result.scalars.return_value.all.return_value = sample_lines
        mock_db_session.execute.return_value = mock_result
        
        # Act
        result = await service.list_production_lines(mock_db_session)
        
        # Assert
        assert len(result) == 2
        assert result[0].line_code == "LINE_001"
        assert result[1].line_code == "LINE_002"
    
    @pytest.mark.asyncio
    async def test_get_production_line_by_code_success(self, service, mock_db_session, sample_production_line_data):
        """Test successful production line retrieval by code."""
        # Arrange
        line_code = sample_production_line_data["line_code"]
        
        mock_result = Mock()
        mock_result.scalar_one_or_none.return_value = sample_production_line_data
        mock_db_session.execute.return_value = mock_result
        
        # Act
        result = await service.get_production_line_by_code(line_code, mock_db_session)
        
        # Assert
        assert result is not None
        assert result.line_code == line_code
    
    @pytest.mark.asyncio
    async def test_validate_production_line_data_valid(self, service):
        """Test production line data validation with valid data."""
        # Arrange
        valid_data = ProductionLineCreate(
            line_code="LINE_001",
            line_name="Valid Line",
            line_type="assembly"
        )
        
        # Act
        result = service._validate_production_line_data(valid_data)
        
        # Assert
        assert result is True
    
    @pytest.mark.asyncio
    async def test_validate_production_line_data_invalid_code(self, service):
        """Test production line data validation with invalid code."""
        # Arrange
        invalid_data = ProductionLineCreate(
            line_code="",  # Empty code
            line_name="Valid Line",
            line_type="assembly"
        )
        
        # Act & Assert
        with pytest.raises(ValidationError, match="Line code cannot be empty"):
            service._validate_production_line_data(invalid_data)
    
    @pytest.mark.asyncio
    async def test_validate_production_line_data_invalid_type(self, service):
        """Test production line data validation with invalid type."""
        # Arrange
        invalid_data = ProductionLineCreate(
            line_code="LINE_001",
            line_name="Valid Line",
            line_type="invalid_type"
        )
        
        # Act & Assert
        with pytest.raises(ValidationError, match="Invalid line type"):
            service._validate_production_line_data(invalid_data)
    
    @pytest.mark.asyncio
    async def test_production_line_service_error_handling(self, service, mock_db_session):
        """Test production line service error handling."""
        # Arrange
        create_data = ProductionLineCreate(
            line_code="LINE_001",
            line_name="Test Line",
            line_type="assembly"
        )
        
        # Mock database error
        mock_db_session.execute.side_effect = Exception("Database connection error")
        
        # Act & Assert
        with pytest.raises(Exception, match="Database connection error"):
            await service.create_production_line(create_data, mock_db_session)
        
        mock_db_session.rollback.assert_called_once()


class TestProductionScheduleService:
    """Comprehensive tests for ProductionScheduleService."""
    
    @pytest.fixture
    def service(self):
        """Create a ProductionScheduleService instance for testing."""
        return ProductionScheduleService()
    
    @pytest.fixture
    def mock_db_session(self):
        """Create a mock database session."""
        session = AsyncMock()
        session.execute = AsyncMock()
        session.commit = AsyncMock()
        session.rollback = AsyncMock()
        return session
    
    @pytest.fixture
    def sample_schedule_data(self):
        """Provide sample production schedule data."""
        return {
            "id": str(uuid4()),
            "line_id": str(uuid4()),
            "schedule_name": "Test Schedule",
            "start_time": datetime.now(timezone.utc),
            "end_time": datetime.now(timezone.utc) + timedelta(hours=8),
            "status": ScheduleStatus.SCHEDULED,
            "created_at": datetime.now(timezone.utc)
        }
    
    @pytest.mark.asyncio
    async def test_create_schedule_success(self, service, mock_db_session, sample_schedule_data):
        """Test successful schedule creation."""
        # Arrange
        create_data = ProductionScheduleCreate(
            line_id=sample_schedule_data["line_id"],
            schedule_name="Test Schedule",
            start_time=sample_schedule_data["start_time"],
            end_time=sample_schedule_data["end_time"]
        )
        
        # Mock line existence check
        mock_line_check = Mock()
        mock_line_check.scalar_one_or_none.return_value = {"id": sample_schedule_data["line_id"]}
        mock_db_session.execute.return_value = mock_line_check
        
        with patch('backend.app.database.execute_scalar', return_value=sample_schedule_data["id"]):
            # Act
            result = await service.create_schedule(create_data, mock_db_session)
            
            # Assert
            assert result is not None
            assert result.line_id == create_data.line_id
            assert result.schedule_name == create_data.schedule_name
            assert result.status == ScheduleStatus.SCHEDULED
    
    @pytest.mark.asyncio
    async def test_create_schedule_invalid_times(self, service, mock_db_session):
        """Test schedule creation with invalid time range."""
        # Arrange
        create_data = ProductionScheduleCreate(
            line_id=str(uuid4()),
            schedule_name="Test Schedule",
            start_time=datetime.now(timezone.utc) + timedelta(hours=8),
            end_time=datetime.now(timezone.utc)  # End before start
        )
        
        # Act & Assert
        with pytest.raises(ValidationError, match="End time must be after start time"):
            await service.create_schedule(create_data, mock_db_session)
    
    @pytest.mark.asyncio
    async def test_update_schedule_status_success(self, service, mock_db_session, sample_schedule_data):
        """Test successful schedule status update."""
        # Arrange
        schedule_id = sample_schedule_data["id"]
        new_status = ScheduleStatus.IN_PROGRESS
        
        # Mock existing schedule check
        mock_existing = Mock()
        mock_existing.scalar_one_or_none.return_value = sample_schedule_data
        mock_db_session.execute.return_value = mock_existing
        
        with patch('backend.app.database.execute_update', return_value=True):
            # Act
            result = await service.update_schedule_status(schedule_id, new_status, mock_db_session)
            
            # Assert
            assert result is True
            mock_db_session.commit.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_get_schedules_by_line_success(self, service, mock_db_session):
        """Test successful schedule retrieval by line."""
        # Arrange
        line_id = str(uuid4())
        sample_schedules = [
            {
                "id": str(uuid4()),
                "line_id": line_id,
                "schedule_name": "Schedule 1",
                "status": ScheduleStatus.SCHEDULED
            },
            {
                "id": str(uuid4()),
                "line_id": line_id,
                "schedule_name": "Schedule 2", 
                "status": ScheduleStatus.IN_PROGRESS
            }
        ]
        
        mock_result = Mock()
        mock_result.scalars.return_value.all.return_value = sample_schedules
        mock_db_session.execute.return_value = mock_result
        
        # Act
        result = await service.get_schedules_by_line(line_id, mock_db_session)
        
        # Assert
        assert len(result) == 2
        assert all(schedule.line_id == line_id for schedule in result)
    
    @pytest.mark.asyncio
    async def test_validate_schedule_conflicts_success(self, service, mock_db_session):
        """Test schedule conflict validation with no conflicts."""
        # Arrange
        line_id = str(uuid4())
        start_time = datetime.now(timezone.utc)
        end_time = start_time + timedelta(hours=8)
        
        # Mock no conflicting schedules
        mock_result = Mock()
        mock_result.scalars.return_value.all.return_value = []
        mock_db_session.execute.return_value = mock_result
        
        # Act
        result = await service._validate_schedule_conflicts(
            line_id, start_time, end_time, mock_db_session
        )
        
        # Assert
        assert result is True
    
    @pytest.mark.asyncio
    async def test_validate_schedule_conflicts_conflict_detected(self, service, mock_db_session):
        """Test schedule conflict validation with conflicts detected."""
        # Arrange
        line_id = str(uuid4())
        start_time = datetime.now(timezone.utc)
        end_time = start_time + timedelta(hours=8)
        
        # Mock conflicting schedule
        conflicting_schedule = {
            "id": str(uuid4()),
            "line_id": line_id,
            "start_time": start_time + timedelta(hours=2),
            "end_time": end_time + timedelta(hours=2)
        }
        
        mock_result = Mock()
        mock_result.scalars.return_value.all.return_value = [conflicting_schedule]
        mock_db_session.execute.return_value = mock_result
        
        # Act & Assert
        with pytest.raises(BusinessLogicError, match="Schedule conflicts with existing schedule"):
            await service._validate_schedule_conflicts(
                line_id, start_time, end_time, mock_db_session
            )