"""
Unit tests for Production Service
Tests all production service methods and functionality
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

from app.services.production_service import ProductionService, ProductionScheduleService, JobAssignmentService


class TestProductionService:
    """Test cases for ProductionService"""
    
    @pytest.fixture
    def mock_db(self):
        """Mock database connection"""
        mock_db = AsyncMock()
        return mock_db
    
    @pytest.fixture
    def production_service(self, mock_db):
        """Create ProductionService instance with mocked database"""
        with patch('app.services.production_service.get_database', return_value=mock_db):
            service = ProductionService()
            return service
    
    @pytest.mark.asyncio
    async def test_get_production_lines(self, production_service, mock_db):
        """Test getting production lines"""
        # Mock database response
        mock_db.fetch_all.return_value = [
            {
                'id': str(uuid.uuid4()),
                'name': 'Line 1',
                'status': 'active',
                'created_at': datetime.now()
            }
        ]
        
        result = await production_service.get_production_lines()
        
        assert result is not None
        assert len(result) == 1
        assert result[0]['name'] == 'Line 1'
        mock_db.fetch_all.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_create_production_line(self, production_service, mock_db):
        """Test creating a production line"""
        line_data = {
            'name': 'Test Line',
            'description': 'Test Description',
            'status': 'active'
        }
        
        mock_db.fetch_one.return_value = {
            'id': str(uuid.uuid4()),
            **line_data,
            'created_at': datetime.now()
        }
        
        result = await production_service.create_production_line(line_data)
        
        assert result is not None
        assert result['name'] == 'Test Line'
        mock_db.fetch_one.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_update_production_line(self, production_service, mock_db):
        """Test updating a production line"""
        line_id = str(uuid.uuid4())
        update_data = {'name': 'Updated Line'}
        
        mock_db.fetch_one.return_value = {
            'id': line_id,
            'name': 'Updated Line',
            'updated_at': datetime.now()
        }
        
        result = await production_service.update_production_line(line_id, update_data)
        
        assert result is not None
        assert result['name'] == 'Updated Line'
        mock_db.fetch_one.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_delete_production_line(self, production_service, mock_db):
        """Test deleting a production line"""
        line_id = str(uuid.uuid4())
        
        mock_db.execute.return_value = True
        
        result = await production_service.delete_production_line(line_id)
        
        assert result is True
        mock_db.execute.assert_called_once()


class TestProductionScheduleService:
    """Test cases for ProductionScheduleService"""
    
    @pytest.fixture
    def mock_db(self):
        """Mock database connection"""
        mock_db = AsyncMock()
        return mock_db
    
    @pytest.fixture
    def schedule_service(self, mock_db):
        """Create ProductionScheduleService instance with mocked database"""
        with patch('app.services.production_service.get_database', return_value=mock_db):
            service = ProductionScheduleService()
            return service
    
    @pytest.mark.asyncio
    async def test_get_schedules(self, schedule_service, mock_db):
        """Test getting production schedules"""
        mock_db.fetch_all.return_value = [
            {
                'id': str(uuid.uuid4()),
                'line_id': str(uuid.uuid4()),
                'start_time': datetime.now(),
                'end_time': datetime.now() + timedelta(hours=8),
                'status': 'scheduled'
            }
        ]
        
        result = await schedule_service.get_schedules()
        
        assert result is not None
        assert len(result) == 1
        mock_db.fetch_all.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_create_schedule(self, schedule_service, mock_db):
        """Test creating a production schedule"""
        schedule_data = {
            'line_id': str(uuid.uuid4()),
            'start_time': datetime.now(),
            'end_time': datetime.now() + timedelta(hours=8),
            'product_type_id': str(uuid.uuid4())
        }
        
        mock_db.fetch_one.return_value = {
            'id': str(uuid.uuid4()),
            **schedule_data,
            'status': 'scheduled',
            'created_at': datetime.now()
        }
        
        result = await schedule_service.create_schedule(schedule_data)
        
        assert result is not None
        assert result['status'] == 'scheduled'
        mock_db.fetch_one.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_update_schedule(self, schedule_service, mock_db):
        """Test updating a production schedule"""
        schedule_id = str(uuid.uuid4())
        update_data = {'status': 'in_progress'}
        
        mock_db.fetch_one.return_value = {
            'id': schedule_id,
            'status': 'in_progress',
            'updated_at': datetime.now()
        }
        
        result = await schedule_service.update_schedule(schedule_id, update_data)
        
        assert result is not None
        assert result['status'] == 'in_progress'
        mock_db.fetch_one.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_delete_schedule(self, schedule_service, mock_db):
        """Test deleting a production schedule"""
        schedule_id = str(uuid.uuid4())
        
        mock_db.execute.return_value = True
        
        result = await schedule_service.delete_schedule(schedule_id)
        
        assert result is True
        mock_db.execute.assert_called_once()


class TestJobAssignmentService:
    """Test cases for JobAssignmentService"""
    
    @pytest.fixture
    def mock_db(self):
        """Mock database connection"""
        mock_db = AsyncMock()
        return mock_db
    
    @pytest.fixture
    def job_service(self, mock_db):
        """Create JobAssignmentService instance with mocked database"""
        with patch('app.services.production_service.get_database', return_value=mock_db):
            service = JobAssignmentService()
            return service
    
    @pytest.mark.asyncio
    async def test_get_job_assignments(self, job_service, mock_db):
        """Test getting job assignments"""
        mock_db.fetch_all.return_value = [
            {
                'id': str(uuid.uuid4()),
                'user_id': str(uuid.uuid4()),
                'job_type': 'production',
                'status': 'assigned',
                'assigned_at': datetime.now()
            }
        ]
        
        result = await job_service.get_job_assignments()
        
        assert result is not None
        assert len(result) == 1
        assert result[0]['job_type'] == 'production'
        mock_db.fetch_all.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_create_job_assignment(self, job_service, mock_db):
        """Test creating a job assignment"""
        job_data = {
            'user_id': str(uuid.uuid4()),
            'job_type': 'maintenance',
            'equipment_id': str(uuid.uuid4()),
            'priority': 'high'
        }
        
        mock_db.fetch_one.return_value = {
            'id': str(uuid.uuid4()),
            **job_data,
            'status': 'assigned',
            'assigned_at': datetime.now()
        }
        
        result = await job_service.create_job_assignment(job_data)
        
        assert result is not None
        assert result['status'] == 'assigned'
        mock_db.fetch_one.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_accept_job(self, job_service, mock_db):
        """Test accepting a job"""
        job_id = str(uuid.uuid4())
        user_id = str(uuid.uuid4())
        
        mock_db.fetch_one.return_value = {
            'id': job_id,
            'user_id': user_id,
            'status': 'accepted',
            'accepted_at': datetime.now()
        }
        
        result = await job_service.accept_job(job_id, user_id)
        
        assert result is not None
        assert result['status'] == 'accepted'
        mock_db.fetch_one.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_start_job(self, job_service, mock_db):
        """Test starting a job"""
        job_id = str(uuid.uuid4())
        user_id = str(uuid.uuid4())
        
        mock_db.fetch_one.return_value = {
            'id': job_id,
            'user_id': user_id,
            'status': 'in_progress',
            'started_at': datetime.now()
        }
        
        result = await job_service.start_job(job_id, user_id)
        
        assert result is not None
        assert result['status'] == 'in_progress'
        mock_db.fetch_one.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_complete_job(self, job_service, mock_db):
        """Test completing a job"""
        job_id = str(uuid.uuid4())
        user_id = str(uuid.uuid4())
        completion_data = {'notes': 'Job completed successfully'}
        
        mock_db.fetch_one.return_value = {
            'id': job_id,
            'user_id': user_id,
            'status': 'completed',
            'completed_at': datetime.now(),
            'completion_notes': 'Job completed successfully'
        }
        
        result = await job_service.complete_job(job_id, user_id, completion_data)
        
        assert result is not None
        assert result['status'] == 'completed'
        mock_db.fetch_one.assert_called_once()


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
