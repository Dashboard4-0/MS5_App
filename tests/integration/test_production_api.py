"""
MS5.0 Floor Dashboard - Production API Integration Tests

Integration tests for all production-related API endpoints.
Tests complete request-response cycles with authentication and database integration.

Coverage Requirements:
- 100% endpoint coverage
- All HTTP methods tested
- Authentication and authorization verified
- Error handling validated
- Performance benchmarks met
"""

import pytest
import pytest_asyncio
from unittest.mock import AsyncMock, Mock, patch
from datetime import datetime, timezone, timedelta
from uuid import uuid4
from fastapi import status
from httpx import AsyncClient


class TestProductionLinesAPI:
    """Integration tests for production lines API endpoints."""
    
    @pytest.mark.asyncio
    async def test_create_production_line_success(
        self, 
        async_client: AsyncClient, 
        override_get_db_session, 
        override_get_current_user,
        test_data_factory
    ):
        """Test successful production line creation via API."""
        # Arrange
        production_line_data = test_data_factory.create_production_line_data()
        
        # Mock successful database operation
        with patch('backend.app.database.execute_scalar', return_value=str(uuid4())):
            # Act
            response = await async_client.post(
                "/api/v1/production/lines",
                json=production_line_data
            )
            
            # Assert
            assert response.status_code == status.HTTP_201_CREATED
            response_data = response.json()
            assert response_data["line_code"] == production_line_data["line_code"]
            assert response_data["line_name"] == production_line_data["line_name"]
            assert response_data["line_type"] == production_line_data["line_type"]
            assert response_data["status"] == production_line_data["status"]
    
    @pytest.mark.asyncio
    async def test_create_production_line_duplicate_code(
        self, 
        async_client: AsyncClient, 
        override_get_db_session, 
        override_get_current_user,
        test_data_factory
    ):
        """Test production line creation with duplicate code."""
        # Arrange
        production_line_data = test_data_factory.create_production_line_data()
        
        # Mock duplicate code error
        with patch('backend.app.database.execute_scalar', side_effect=Exception("Duplicate key")):
            # Act
            response = await async_client.post(
                "/api/v1/production/lines",
                json=production_line_data
            )
            
            # Assert
            assert response.status_code == status.HTTP_409_CONFLICT
            assert "already exists" in response.json()["detail"]
    
    @pytest.mark.asyncio
    async def test_get_production_line_success(
        self, 
        async_client: AsyncClient, 
        override_get_db_session, 
        override_get_current_user,
        test_data_factory
    ):
        """Test successful production line retrieval via API."""
        # Arrange
        line_id = str(uuid4())
        production_line_data = test_data_factory.create_production_line_data()
        production_line_data["id"] = line_id
        
        # Mock successful database query
        with patch('backend.app.database.execute_scalar', return_value=production_line_data):
            # Act
            response = await async_client.get(f"/api/v1/production/lines/{line_id}")
            
            # Assert
            assert response.status_code == status.HTTP_200_OK
            response_data = response.json()
            assert response_data["id"] == line_id
            assert response_data["line_code"] == production_line_data["line_code"]
    
    @pytest.mark.asyncio
    async def test_get_production_line_not_found(
        self, 
        async_client: AsyncClient, 
        override_get_db_session, 
        override_get_current_user
    ):
        """Test production line retrieval when line doesn't exist."""
        # Arrange
        line_id = str(uuid4())
        
        # Mock not found
        with patch('backend.app.database.execute_scalar', return_value=None):
            # Act
            response = await async_client.get(f"/api/v1/production/lines/{line_id}")
            
            # Assert
            assert response.status_code == status.HTTP_404_NOT_FOUND
            assert "not found" in response.json()["detail"]
    
    @pytest.mark.asyncio
    async def test_list_production_lines_success(
        self, 
        async_client: AsyncClient, 
        override_get_db_session, 
        override_get_current_user,
        test_data_factory
    ):
        """Test successful production lines listing via API."""
        # Arrange
        lines_data = [
            test_data_factory.create_production_line_data(),
            test_data_factory.create_production_line_data()
        ]
        
        # Mock successful database query
        with patch('backend.app.database.execute_query', return_value=lines_data):
            # Act
            response = await async_client.get("/api/v1/production/lines")
            
            # Assert
            assert response.status_code == status.HTTP_200_OK
            response_data = response.json()
            assert len(response_data) == 2
            assert all("line_code" in line for line in response_data)
    
    @pytest.mark.asyncio
    async def test_update_production_line_success(
        self, 
        async_client: AsyncClient, 
        override_get_db_session, 
        override_get_current_user,
        test_data_factory
    ):
        """Test successful production line update via API."""
        # Arrange
        line_id = str(uuid4())
        update_data = {
            "line_name": "Updated Production Line",
            "status": "maintenance"
        }
        
        # Mock successful database operations
        with patch('backend.app.database.execute_scalar', return_value={"id": line_id}):
            with patch('backend.app.database.execute_update', return_value=True):
                # Act
                response = await async_client.put(
                    f"/api/v1/production/lines/{line_id}",
                    json=update_data
                )
                
                # Assert
                assert response.status_code == status.HTTP_200_OK
                response_data = response.json()
                assert response_data["line_name"] == update_data["line_name"]
                assert response_data["status"] == update_data["status"]
    
    @pytest.mark.asyncio
    async def test_delete_production_line_success(
        self, 
        async_client: AsyncClient, 
        override_get_db_session, 
        override_get_current_user
    ):
        """Test successful production line deletion via API."""
        # Arrange
        line_id = str(uuid4())
        
        # Mock successful database operations
        with patch('backend.app.database.execute_scalar', return_value={"id": line_id}):
            with patch('backend.app.database.execute_update', return_value=True):
                # Act
                response = await async_client.delete(f"/api/v1/production/lines/{line_id}")
                
                # Assert
                assert response.status_code == status.HTTP_204_NO_CONTENT
    
    @pytest.mark.asyncio
    async def test_production_line_api_unauthorized(
        self, 
        async_client: AsyncClient, 
        override_get_db_session,
        test_data_factory
    ):
        """Test production line API without authentication."""
        # Arrange
        production_line_data = test_data_factory.create_production_line_data()
        
        # Act
        response = await async_client.post(
            "/api/v1/production/lines",
            json=production_line_data
        )
        
        # Assert
        assert response.status_code == status.HTTP_401_UNAUTHORIZED
    
    @pytest.mark.asyncio
    async def test_production_line_api_insufficient_permissions(
        self, 
        async_client: AsyncClient, 
        override_get_db_session,
        test_data_factory
    ):
        """Test production line API with insufficient permissions."""
        # Arrange
        production_line_data = test_data_factory.create_production_line_data()
        
        # Mock user without production write permissions
        restricted_user = Mock()
        restricted_user.has_permission.return_value = False
        
        with patch('backend.app.auth.permissions.get_current_user', return_value=restricted_user):
            # Act
            response = await async_client.post(
                "/api/v1/production/lines",
                json=production_line_data
            )
            
            # Assert
            assert response.status_code == status.HTTP_403_FORBIDDEN


class TestJobAssignmentsAPI:
    """Integration tests for job assignments API endpoints."""
    
    @pytest.mark.asyncio
    async def test_create_job_assignment_success(
        self, 
        async_client: AsyncClient, 
        override_get_db_session, 
        override_get_current_user,
        test_data_factory
    ):
        """Test successful job assignment creation via API."""
        # Arrange
        job_data = test_data_factory.create_job_assignment_data()
        job_data["line_id"] = str(uuid4())
        job_data["operator_id"] = str(uuid4())
        
        # Mock successful database operation
        with patch('backend.app.database.execute_scalar', return_value=str(uuid4())):
            # Act
            response = await async_client.post(
                "/api/v1/production/jobs",
                json=job_data
            )
            
            # Assert
            assert response.status_code == status.HTTP_201_CREATED
            response_data = response.json()
            assert response_data["job_code"] == job_data["job_code"]
            assert response_data["job_name"] == job_data["job_name"]
            assert response_data["status"] == job_data["status"]
    
    @pytest.mark.asyncio
    async def test_get_job_assignment_success(
        self, 
        async_client: AsyncClient, 
        override_get_db_session, 
        override_get_current_user,
        test_data_factory
    ):
        """Test successful job assignment retrieval via API."""
        # Arrange
        job_id = str(uuid4())
        job_data = test_data_factory.create_job_assignment_data()
        job_data["id"] = job_id
        
        # Mock successful database query
        with patch('backend.app.database.execute_scalar', return_value=job_data):
            # Act
            response = await async_client.get(f"/api/v1/production/jobs/{job_id}")
            
            # Assert
            assert response.status_code == status.HTTP_200_OK
            response_data = response.json()
            assert response_data["id"] == job_id
            assert response_data["job_code"] == job_data["job_code"]
    
    @pytest.mark.asyncio
    async def test_list_job_assignments_success(
        self, 
        async_client: AsyncClient, 
        override_get_db_session, 
        override_get_current_user,
        test_data_factory
    ):
        """Test successful job assignments listing via API."""
        # Arrange
        jobs_data = [
            test_data_factory.create_job_assignment_data(),
            test_data_factory.create_job_assignment_data()
        ]
        
        # Mock successful database query
        with patch('backend.app.database.execute_query', return_value=jobs_data):
            # Act
            response = await async_client.get("/api/v1/production/jobs")
            
            # Assert
            assert response.status_code == status.HTTP_200_OK
            response_data = response.json()
            assert len(response_data) == 2
            assert all("job_code" in job for job in response_data)
    
    @pytest.mark.asyncio
    async def test_update_job_assignment_status_success(
        self, 
        async_client: AsyncClient, 
        override_get_db_session, 
        override_get_current_user
    ):
        """Test successful job assignment status update via API."""
        # Arrange
        job_id = str(uuid4())
        status_update = {"status": "in_progress"}
        
        # Mock successful database operations
        with patch('backend.app.database.execute_scalar', return_value={"id": job_id}):
            with patch('backend.app.database.execute_update', return_value=True):
                # Act
                response = await async_client.patch(
                    f"/api/v1/production/jobs/{job_id}/status",
                    json=status_update
                )
                
                # Assert
                assert response.status_code == status.HTTP_200_OK
                response_data = response.json()
                assert response_data["status"] == status_update["status"]


class TestProductionSchedulesAPI:
    """Integration tests for production schedules API endpoints."""
    
    @pytest.mark.asyncio
    async def test_create_production_schedule_success(
        self, 
        async_client: AsyncClient, 
        override_get_db_session, 
        override_get_current_user
    ):
        """Test successful production schedule creation via API."""
        # Arrange
        schedule_data = {
            "line_id": str(uuid4()),
            "schedule_name": "Test Schedule",
            "start_time": datetime.now(timezone.utc).isoformat(),
            "end_time": (datetime.now(timezone.utc) + timedelta(hours=8)).isoformat(),
            "job_assignments": [
                {
                    "job_code": "JOB_001",
                    "job_name": "Test Job",
                    "priority": "normal"
                }
            ]
        }
        
        # Mock successful database operation
        with patch('backend.app.database.execute_scalar', return_value=str(uuid4())):
            # Act
            response = await async_client.post(
                "/api/v1/production/schedules",
                json=schedule_data
            )
            
            # Assert
            assert response.status_code == status.HTTP_201_CREATED
            response_data = response.json()
            assert response_data["schedule_name"] == schedule_data["schedule_name"]
            assert response_data["status"] == "scheduled"
    
    @pytest.mark.asyncio
    async def test_get_production_schedule_success(
        self, 
        async_client: AsyncClient, 
        override_get_db_session, 
        override_get_current_user
    ):
        """Test successful production schedule retrieval via API."""
        # Arrange
        schedule_id = str(uuid4())
        schedule_data = {
            "id": schedule_id,
            "line_id": str(uuid4()),
            "schedule_name": "Test Schedule",
            "status": "scheduled",
            "start_time": datetime.now(timezone.utc),
            "end_time": datetime.now(timezone.utc) + timedelta(hours=8)
        }
        
        # Mock successful database query
        with patch('backend.app.database.execute_scalar', return_value=schedule_data):
            # Act
            response = await async_client.get(f"/api/v1/production/schedules/{schedule_id}")
            
            # Assert
            assert response.status_code == status.HTTP_200_OK
            response_data = response.json()
            assert response_data["id"] == schedule_id
            assert response_data["schedule_name"] == schedule_data["schedule_name"]
    
    @pytest.mark.asyncio
    async def test_update_schedule_status_success(
        self, 
        async_client: AsyncClient, 
        override_get_db_session, 
        override_get_current_user
    ):
        """Test successful schedule status update via API."""
        # Arrange
        schedule_id = str(uuid4())
        status_update = {"status": "in_progress"}
        
        # Mock successful database operations
        with patch('backend.app.database.execute_scalar', return_value={"id": schedule_id}):
            with patch('backend.app.database.execute_update', return_value=True):
                # Act
                response = await async_client.patch(
                    f"/api/v1/production/schedules/{schedule_id}/status",
                    json=status_update
                )
                
                # Assert
                assert response.status_code == status.HTTP_200_OK
                response_data = response.json()
                assert response_data["status"] == status_update["status"]


class TestProductionAPIPerformance:
    """Performance tests for production API endpoints."""
    
    @pytest.mark.asyncio
    async def test_production_line_list_performance(
        self, 
        async_client: AsyncClient, 
        override_get_db_session, 
        override_get_current_user,
        performance_helper
    ):
        """Test production line listing performance."""
        # Arrange
        lines_data = [{"line_code": f"LINE_{i}", "line_name": f"Line {i}"} for i in range(100)]
        
        # Mock successful database query
        with patch('backend.app.database.execute_query', return_value=lines_data):
            # Act
            response_time = performance_helper.measure_response_time(
                async_client, "GET", "/api/v1/production/lines"
            )
            
            # Assert
            performance_helper.assert_response_time_acceptable(response_time, max_acceptable_ms=200.0)
    
    @pytest.mark.asyncio
    async def test_job_assignment_create_performance(
        self, 
        async_client: AsyncClient, 
        override_get_db_session, 
        override_get_current_user,
        performance_helper,
        test_data_factory
    ):
        """Test job assignment creation performance."""
        # Arrange
        job_data = test_data_factory.create_job_assignment_data()
        job_data["line_id"] = str(uuid4())
        job_data["operator_id"] = str(uuid4())
        
        # Mock successful database operation
        with patch('backend.app.database.execute_scalar', return_value=str(uuid4())):
            # Act
            response_time = performance_helper.measure_response_time(
                async_client, "POST", "/api/v1/production/jobs", json=job_data
            )
            
            # Assert
            performance_helper.assert_response_time_acceptable(response_time, max_acceptable_ms=300.0)
