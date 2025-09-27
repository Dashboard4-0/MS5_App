"""
Comprehensive unit tests for Production Service
Tests all methods with edge cases, error conditions, and business logic
"""

import pytest
import asyncio
from unittest.mock import AsyncMock, MagicMock, patch
from datetime import datetime, timedelta
from uuid import uuid4, UUID
import json

from backend.app.services.production_service import (
    ProductionLineService, ProductionScheduleService, JobAssignmentService,
    ProductionStatisticsService
)
from backend.app.models.production import (
    ProductionLineCreate, ProductionLineUpdate, ProductionLineResponse,
    ProductionScheduleCreate, ProductionScheduleUpdate, ProductionScheduleResponse,
    JobAssignmentCreate, JobAssignmentUpdate, JobAssignmentResponse,
    ScheduleStatus, JobStatus, ProductionLineStatus
)
from backend.app.utils.exceptions import (
    NotFoundError, ValidationError, ConflictError, BusinessLogicError
)


class TestProductionLineService:
    """Test cases for ProductionLineService"""
    
    @pytest.fixture
    def mock_db_execute_query(self):
        """Mock database execute_query function"""
        with patch('backend.app.services.production_service.execute_query') as mock:
            yield mock
    
    @pytest.fixture
    def mock_db_execute_scalar(self):
        """Mock database execute_scalar function"""
        with patch('backend.app.services.production_service.execute_scalar') as mock:
            yield mock
    
    @pytest.fixture
    def mock_db_execute_update(self):
        """Mock database execute_update function"""
        with patch('backend.app.services.production_service.execute_update') as mock:
            yield mock
    
    @pytest.fixture
    def sample_line_data(self):
        """Sample production line data"""
        return ProductionLineCreate(
            line_code="TEST_LINE_001",
            name="Test Production Line",
            description="Test line for unit testing",
            equipment_codes=["EQ001", "EQ002"],
            target_speed=100.0,
            enabled=True
        )
    
    @pytest.fixture
    def sample_line_response(self):
        """Sample production line response"""
        line_id = uuid4()
        return ProductionLineResponse(
            id=line_id,
            line_code="TEST_LINE_001",
            name="Test Production Line",
            description="Test line for unit testing",
            equipment_codes=["EQ001", "EQ002"],
            target_speed=100.0,
            enabled=True,
            created_at=datetime.now(),
            updated_at=datetime.now()
        )
    
    @pytest.mark.asyncio
    async def test_create_production_line_success(self, mock_db_execute_scalar, 
                                                 mock_db_execute_update, sample_line_data):
        """Test successful production line creation"""
        # Setup mocks
        mock_db_execute_scalar.return_value = None  # No existing line
        mock_db_execute_update.return_value = {
            'id': str(uuid4()),
            'line_code': 'TEST_LINE_001',
            'name': 'Test Production Line',
            'description': 'Test line for unit testing',
            'equipment_codes': ['EQ001', 'EQ002'],
            'target_speed': 100.0,
            'enabled': True,
            'created_at': datetime.now(),
            'updated_at': datetime.now()
        }
        
        # Execute
        result = await ProductionLineService.create_production_line(sample_line_data)
        
        # Verify
        assert isinstance(result, ProductionLineResponse)
        assert result.line_code == sample_line_data.line_code
        assert result.name == sample_line_data.name
        mock_db_execute_scalar.assert_called_once()
        mock_db_execute_update.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_create_production_line_conflict(self, mock_db_execute_scalar, sample_line_data):
        """Test production line creation with existing code"""
        # Setup mocks
        mock_db_execute_scalar.return_value = str(uuid4())  # Existing line found
        
        # Execute and verify
        with pytest.raises(ConflictError, match="Production line with this code already exists"):
            await ProductionLineService.create_production_line(sample_line_data)
        
        mock_db_execute_scalar.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_get_production_line_success(self, mock_db_execute_query, sample_line_response):
        """Test successful production line retrieval"""
        # Setup mocks
        mock_db_execute_query.return_value = [{
            'id': str(sample_line_response.id),
            'line_code': sample_line_response.line_code,
            'name': sample_line_response.name,
            'description': sample_line_response.description,
            'equipment_codes': sample_line_response.equipment_codes,
            'target_speed': sample_line_response.target_speed,
            'enabled': sample_line_response.enabled,
            'created_at': sample_line_response.created_at,
            'updated_at': sample_line_response.updated_at
        }]
        
        # Execute
        result = await ProductionLineService.get_production_line(sample_line_response.id)
        
        # Verify
        assert isinstance(result, ProductionLineResponse)
        assert result.id == sample_line_response.id
        assert result.line_code == sample_line_response.line_code
        mock_db_execute_query.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_get_production_line_not_found(self, mock_db_execute_query):
        """Test production line retrieval when not found"""
        # Setup mocks
        mock_db_execute_query.return_value = []
        
        # Execute and verify
        with pytest.raises(NotFoundError, match="Production line not found"):
            await ProductionLineService.get_production_line(uuid4())
        
        mock_db_execute_query.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_update_production_line_success(self, mock_db_execute_query, 
                                                 mock_db_execute_update, sample_line_response):
        """Test successful production line update"""
        # Setup mocks
        mock_db_execute_query.return_value = [{
            'id': str(sample_line_response.id),
            'line_code': sample_line_response.line_code,
            'name': sample_line_response.name,
            'description': sample_line_response.description,
            'equipment_codes': sample_line_response.equipment_codes,
            'target_speed': sample_line_response.target_speed,
            'enabled': sample_line_response.enabled,
            'created_at': sample_line_response.created_at,
            'updated_at': sample_line_response.updated_at
        }]
        
        mock_db_execute_update.return_value = {
            'id': str(sample_line_response.id),
            'line_code': sample_line_response.line_code,
            'name': 'Updated Test Line',
            'description': sample_line_response.description,
            'equipment_codes': sample_line_response.equipment_codes,
            'target_speed': 120.0,
            'enabled': sample_line_response.enabled,
            'created_at': sample_line_response.created_at,
            'updated_at': datetime.now()
        }
        
        update_data = ProductionLineUpdate(
            name="Updated Test Line",
            target_speed=120.0
        )
        
        # Execute
        result = await ProductionLineService.update_production_line(sample_line_response.id, update_data)
        
        # Verify
        assert isinstance(result, ProductionLineResponse)
        assert result.name == "Updated Test Line"
        assert result.target_speed == 120.0
        mock_db_execute_query.assert_called_once()
        mock_db_execute_update.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_delete_production_line_success(self, mock_db_execute_query, 
                                                 mock_db_execute_update, sample_line_response):
        """Test successful production line deletion"""
        # Setup mocks
        mock_db_execute_query.return_value = [{
            'id': str(sample_line_response.id),
            'line_code': sample_line_response.line_code,
            'name': sample_line_response.name,
            'description': sample_line_response.description,
            'equipment_codes': sample_line_response.equipment_codes,
            'target_speed': sample_line_response.target_speed,
            'enabled': sample_line_response.enabled,
            'created_at': sample_line_response.created_at,
            'updated_at': sample_line_response.updated_at
        }]
        
        mock_db_execute_update.return_value = {'deleted': True}
        
        # Execute
        result = await ProductionLineService.delete_production_line(sample_line_response.id)
        
        # Verify
        assert result is True
        mock_db_execute_query.assert_called_once()
        mock_db_execute_update.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_list_production_lines_success(self, mock_db_execute_query, sample_line_response):
        """Test successful production lines listing"""
        # Setup mocks
        mock_db_execute_query.return_value = [
            {
                'id': str(sample_line_response.id),
                'line_code': sample_line_response.line_code,
                'name': sample_line_response.name,
                'description': sample_line_response.description,
                'equipment_codes': sample_line_response.equipment_codes,
                'target_speed': sample_line_response.target_speed,
                'enabled': sample_line_response.enabled,
                'created_at': sample_line_response.created_at,
                'updated_at': sample_line_response.updated_at
            },
            {
                'id': str(uuid4()),
                'line_code': 'TEST_LINE_002',
                'name': 'Second Test Line',
                'description': 'Another test line',
                'equipment_codes': ['EQ003'],
                'target_speed': 80.0,
                'enabled': True,
                'created_at': datetime.now(),
                'updated_at': datetime.now()
            }
        ]
        
        # Execute
        result = await ProductionLineService.list_production_lines()
        
        # Verify
        assert isinstance(result, list)
        assert len(result) == 2
        assert all(isinstance(line, ProductionLineResponse) for line in result)
        mock_db_execute_query.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_list_production_lines_empty(self, mock_db_execute_query):
        """Test production lines listing when no lines exist"""
        # Setup mocks
        mock_db_execute_query.return_value = []
        
        # Execute
        result = await ProductionLineService.list_production_lines()
        
        # Verify
        assert isinstance(result, list)
        assert len(result) == 0
        mock_db_execute_query.assert_called_once()


class TestProductionScheduleService:
    """Test cases for ProductionScheduleService"""
    
    @pytest.fixture
    def mock_db_execute_query(self):
        """Mock database execute_query function"""
        with patch('backend.app.services.production_service.execute_query') as mock:
            yield mock
    
    @pytest.fixture
    def mock_db_execute_scalar(self):
        """Mock database execute_scalar function"""
        with patch('backend.app.services.production_service.execute_scalar') as mock:
            yield mock
    
    @pytest.fixture
    def mock_db_execute_update(self):
        """Mock database execute_update function"""
        with patch('backend.app.services.production_service.execute_update') as mock:
            yield mock
    
    @pytest.fixture
    def sample_schedule_data(self):
        """Sample production schedule data"""
        return ProductionScheduleCreate(
            line_id=uuid4(),
            product_type_id=uuid4(),
            scheduled_start=datetime.now() + timedelta(hours=1),
            scheduled_end=datetime.now() + timedelta(hours=9),
            target_quantity=1000,
            priority=1
        )
    
    @pytest.mark.asyncio
    async def test_create_production_schedule_success(self, mock_db_execute_scalar, 
                                                     mock_db_execute_update, sample_schedule_data):
        """Test successful production schedule creation"""
        # Setup mocks
        mock_db_execute_scalar.return_value = None  # No existing schedule conflict
        mock_db_execute_update.return_value = {
            'id': str(uuid4()),
            'line_id': str(sample_schedule_data.line_id),
            'product_type_id': str(sample_schedule_data.product_type_id),
            'scheduled_start': sample_schedule_data.scheduled_start,
            'scheduled_end': sample_schedule_data.scheduled_end,
            'target_quantity': sample_schedule_data.target_quantity,
            'priority': sample_schedule_data.priority,
            'status': 'scheduled',
            'created_at': datetime.now(),
            'updated_at': datetime.now()
        }
        
        # Execute
        result = await ProductionScheduleService.create_production_schedule(sample_schedule_data)
        
        # Verify
        assert isinstance(result, ProductionScheduleResponse)
        assert result.line_id == sample_schedule_data.line_id
        assert result.target_quantity == sample_schedule_data.target_quantity
        mock_db_execute_scalar.assert_called_once()
        mock_db_execute_update.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_create_production_schedule_invalid_dates(self, sample_schedule_data):
        """Test production schedule creation with invalid dates"""
        # Modify schedule data to have invalid dates
        sample_schedule_data.scheduled_end = sample_schedule_data.scheduled_start - timedelta(hours=1)
        
        # Execute and verify
        with pytest.raises(ValidationError, match="End time must be after start time"):
            await ProductionScheduleService.create_production_schedule(sample_schedule_data)
    
    @pytest.mark.asyncio
    async def test_update_production_schedule_status_transition(self, mock_db_execute_query, 
                                                               mock_db_execute_update):
        """Test production schedule status transitions"""
        schedule_id = uuid4()
        
        # Setup mocks for getting existing schedule
        mock_db_execute_query.return_value = [{
            'id': str(schedule_id),
            'line_id': str(uuid4()),
            'product_type_id': str(uuid4()),
            'scheduled_start': datetime.now(),
            'scheduled_end': datetime.now() + timedelta(hours=8),
            'target_quantity': 1000,
            'priority': 1,
            'status': 'scheduled',
            'created_at': datetime.now(),
            'updated_at': datetime.now()
        }]
        
        mock_db_execute_update.return_value = {
            'id': str(schedule_id),
            'line_id': str(uuid4()),
            'product_type_id': str(uuid4()),
            'scheduled_start': datetime.now(),
            'scheduled_end': datetime.now() + timedelta(hours=8),
            'target_quantity': 1000,
            'priority': 1,
            'status': 'in_progress',
            'created_at': datetime.now(),
            'updated_at': datetime.now()
        }
        
        update_data = ProductionScheduleUpdate(status=ScheduleStatus.IN_PROGRESS)
        
        # Execute
        result = await ProductionScheduleService.update_production_schedule(schedule_id, update_data)
        
        # Verify
        assert isinstance(result, ProductionScheduleResponse)
        assert result.status == ScheduleStatus.IN_PROGRESS
        mock_db_execute_query.assert_called_once()
        mock_db_execute_update.assert_called_once()


class TestJobAssignmentService:
    """Test cases for JobAssignmentService"""
    
    @pytest.fixture
    def mock_db_execute_query(self):
        """Mock database execute_query function"""
        with patch('backend.app.services.production_service.execute_query') as mock:
            yield mock
    
    @pytest.fixture
    def mock_db_execute_scalar(self):
        """Mock database execute_scalar function"""
        with patch('backend.app.services.production_service.execute_scalar') as mock:
            yield mock
    
    @pytest.fixture
    def mock_db_execute_update(self):
        """Mock database execute_update function"""
        with patch('backend.app.services.production_service.execute_update') as mock:
            yield mock
    
    @pytest.fixture
    def sample_job_data(self):
        """Sample job assignment data"""
        return JobAssignmentCreate(
            user_id=uuid4(),
            job_type="production",
            title="Test Job Assignment",
            description="Test job for unit testing",
            priority="high",
            equipment_id=uuid4(),
            due_date=datetime.now() + timedelta(hours=4)
        )
    
    @pytest.mark.asyncio
    async def test_create_job_assignment_success(self, mock_db_execute_update, sample_job_data):
        """Test successful job assignment creation"""
        # Setup mocks
        mock_db_execute_update.return_value = {
            'id': str(uuid4()),
            'user_id': str(sample_job_data.user_id),
            'job_type': sample_job_data.job_type,
            'title': sample_job_data.title,
            'description': sample_job_data.description,
            'priority': sample_job_data.priority,
            'equipment_id': str(sample_job_data.equipment_id),
            'due_date': sample_job_data.due_date,
            'status': 'assigned',
            'created_at': datetime.now(),
            'updated_at': datetime.now()
        }
        
        # Execute
        result = await JobAssignmentService.create_job_assignment(sample_job_data)
        
        # Verify
        assert isinstance(result, JobAssignmentResponse)
        assert result.user_id == sample_job_data.user_id
        assert result.title == sample_job_data.title
        assert result.status == JobStatus.ASSIGNED
        mock_db_execute_update.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_accept_job_assignment_success(self, mock_db_execute_query, mock_db_execute_update):
        """Test successful job assignment acceptance"""
        job_id = uuid4()
        user_id = uuid4()
        
        # Setup mocks for getting existing job
        mock_db_execute_query.return_value = [{
            'id': str(job_id),
            'user_id': str(user_id),
            'job_type': 'production',
            'title': 'Test Job',
            'description': 'Test job description',
            'priority': 'high',
            'equipment_id': str(uuid4()),
            'due_date': datetime.now() + timedelta(hours=4),
            'status': 'assigned',
            'created_at': datetime.now(),
            'updated_at': datetime.now()
        }]
        
        mock_db_execute_update.return_value = {
            'id': str(job_id),
            'user_id': str(user_id),
            'job_type': 'production',
            'title': 'Test Job',
            'description': 'Test job description',
            'priority': 'high',
            'equipment_id': str(uuid4()),
            'due_date': datetime.now() + timedelta(hours=4),
            'status': 'accepted',
            'accepted_at': datetime.now(),
            'created_at': datetime.now(),
            'updated_at': datetime.now()
        }
        
        # Execute
        result = await JobAssignmentService.accept_job_assignment(job_id, user_id)
        
        # Verify
        assert isinstance(result, JobAssignmentResponse)
        assert result.status == JobStatus.ACCEPTED
        assert result.accepted_at is not None
        mock_db_execute_query.assert_called_once()
        mock_db_execute_update.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_accept_job_assignment_wrong_user(self, mock_db_execute_query):
        """Test job assignment acceptance by wrong user"""
        job_id = uuid4()
        wrong_user_id = uuid4()
        
        # Setup mocks for getting existing job with different user
        mock_db_execute_query.return_value = [{
            'id': str(job_id),
            'user_id': str(uuid4()),  # Different user
            'job_type': 'production',
            'title': 'Test Job',
            'description': 'Test job description',
            'priority': 'high',
            'equipment_id': str(uuid4()),
            'due_date': datetime.now() + timedelta(hours=4),
            'status': 'assigned',
            'created_at': datetime.now(),
            'updated_at': datetime.now()
        }]
        
        # Execute and verify
        with pytest.raises(BusinessLogicError, match="User not authorized to accept this job"):
            await JobAssignmentService.accept_job_assignment(job_id, wrong_user_id)
        
        mock_db_execute_query.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_complete_job_assignment_success(self, mock_db_execute_query, mock_db_execute_update):
        """Test successful job assignment completion"""
        job_id = uuid4()
        user_id = uuid4()
        
        # Setup mocks for getting existing job
        mock_db_execute_query.return_value = [{
            'id': str(job_id),
            'user_id': str(user_id),
            'job_type': 'production',
            'title': 'Test Job',
            'description': 'Test job description',
            'priority': 'high',
            'equipment_id': str(uuid4()),
            'due_date': datetime.now() + timedelta(hours=4),
            'status': 'in_progress',
            'created_at': datetime.now(),
            'updated_at': datetime.now()
        }]
        
        mock_db_execute_update.return_value = {
            'id': str(job_id),
            'user_id': str(user_id),
            'job_type': 'production',
            'title': 'Test Job',
            'description': 'Test job description',
            'priority': 'high',
            'equipment_id': str(uuid4()),
            'due_date': datetime.now() + timedelta(hours=4),
            'status': 'completed',
            'completion_notes': 'Job completed successfully',
            'completed_at': datetime.now(),
            'created_at': datetime.now(),
            'updated_at': datetime.now()
        }
        
        completion_data = {
            'notes': 'Job completed successfully',
            'completion_time': datetime.now()
        }
        
        # Execute
        result = await JobAssignmentService.complete_job_assignment(job_id, user_id, completion_data)
        
        # Verify
        assert isinstance(result, JobAssignmentResponse)
        assert result.status == JobStatus.COMPLETED
        assert result.completion_notes == completion_data['notes']
        assert result.completed_at is not None
        mock_db_execute_query.assert_called_once()
        mock_db_execute_update.assert_called_once()


class TestProductionStatisticsService:
    """Test cases for ProductionStatisticsService"""
    
    @pytest.fixture
    def mock_db_execute_query(self):
        """Mock database execute_query function"""
        with patch('backend.app.services.production_service.execute_query') as mock:
            yield mock
    
    @pytest.mark.asyncio
    async def test_get_production_statistics_success(self, mock_db_execute_query):
        """Test successful production statistics retrieval"""
        # Setup mocks
        mock_db_execute_query.return_value = [{
            'total_lines': 5,
            'active_lines': 4,
            'total_schedules': 25,
            'active_schedules': 8,
            'completed_schedules': 17,
            'total_jobs': 150,
            'pending_jobs': 12,
            'in_progress_jobs': 8,
            'completed_jobs': 130,
            'average_completion_time': 2.5,
            'oee_average': 0.85
        }]
        
        # Execute
        result = await ProductionStatisticsService.get_production_statistics()
        
        # Verify
        assert isinstance(result, dict)
        assert 'total_lines' in result
        assert 'active_lines' in result
        assert 'total_schedules' in result
        assert 'total_jobs' in result
        assert result['total_lines'] == 5
        assert result['oee_average'] == 0.85
        mock_db_execute_query.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_get_line_performance_metrics_success(self, mock_db_execute_query):
        """Test successful line performance metrics retrieval"""
        line_id = uuid4()
        
        # Setup mocks
        mock_db_execute_query.return_value = [{
            'line_id': str(line_id),
            'line_code': 'TEST_LINE_001',
            'oee_average': 0.85,
            'availability': 0.92,
            'performance': 0.95,
            'quality': 0.97,
            'total_production': 1000,
            'target_production': 1200,
            'efficiency': 0.83,
            'downtime_hours': 2.5,
            'planned_downtime_hours': 1.0,
            'unplanned_downtime_hours': 1.5
        }]
        
        # Execute
        result = await ProductionStatisticsService.get_line_performance_metrics(line_id)
        
        # Verify
        assert isinstance(result, dict)
        assert 'line_id' in result
        assert 'oee_average' in result
        assert 'efficiency' in result
        assert result['line_id'] == str(line_id)
        assert result['oee_average'] == 0.85
        mock_db_execute_query.assert_called_once()


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
