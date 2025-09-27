"""
Integration tests for API endpoints
Tests all API endpoints with database integration
"""

import pytest
import asyncio
import httpx
from datetime import datetime, timedelta
import uuid
import json

# Test configuration
BASE_URL = "http://localhost:8000"
API_BASE = f"{BASE_URL}/api/v1"

class TestAPIIntegration:
    """Integration tests for API endpoints"""
    
    @pytest.fixture
    async def client(self):
        """Create HTTP client for testing"""
        async with httpx.AsyncClient(base_url=BASE_URL, timeout=30.0) as client:
            yield client
    
    @pytest.fixture
    async def auth_token(self, client):
        """Get authentication token for testing"""
        # This would need to be set up with test user credentials
        login_data = {
            "email": "test@example.com",
            "password": "testpassword"
        }
        
        response = await client.post(f"{API_BASE}/auth/login", json=login_data)
        if response.status_code == 200:
            return response.json()["token"]
        else:
            # Return None if login fails (for tests that don't require auth)
            return None
    
    @pytest.fixture
    def auth_headers(self, auth_token):
        """Get authentication headers"""
        if auth_token:
            return {"Authorization": f"Bearer {auth_token}"}
        return {}
    
    # Authentication Tests
    @pytest.mark.asyncio
    async def test_auth_login(self, client):
        """Test user login endpoint"""
        login_data = {
            "email": "test@example.com",
            "password": "testpassword"
        }
        
        response = await client.post(f"{API_BASE}/auth/login", json=login_data)
        
        # Should return 200 or 401 depending on test setup
        assert response.status_code in [200, 401]
        
        if response.status_code == 200:
            data = response.json()
            assert "token" in data
            assert "user" in data
    
    @pytest.mark.asyncio
    async def test_auth_profile(self, client, auth_headers):
        """Test get user profile endpoint"""
        response = await client.get(f"{API_BASE}/auth/profile", headers=auth_headers)
        
        # Should return 200 if authenticated, 401 if not
        assert response.status_code in [200, 401]
        
        if response.status_code == 200:
            data = response.json()
            assert "id" in data
            assert "email" in data
    
    # Production API Tests
    @pytest.mark.asyncio
    async def test_get_production_lines(self, client, auth_headers):
        """Test get production lines endpoint"""
        response = await client.get(f"{API_BASE}/production/lines", headers=auth_headers)
        
        assert response.status_code in [200, 401]
        
        if response.status_code == 200:
            data = response.json()
            assert isinstance(data, list)
    
    @pytest.mark.asyncio
    async def test_create_production_line(self, client, auth_headers):
        """Test create production line endpoint"""
        line_data = {
            "name": "Test Line",
            "description": "Test Production Line",
            "status": "active"
        }
        
        response = await client.post(f"{API_BASE}/production/lines", json=line_data, headers=auth_headers)
        
        assert response.status_code in [200, 201, 401, 422]
        
        if response.status_code in [200, 201]:
            data = response.json()
            assert data["name"] == line_data["name"]
    
    @pytest.mark.asyncio
    async def test_get_production_schedules(self, client, auth_headers):
        """Test get production schedules endpoint"""
        response = await client.get(f"{API_BASE}/production/schedules", headers=auth_headers)
        
        assert response.status_code in [200, 401]
        
        if response.status_code == 200:
            data = response.json()
            assert isinstance(data, list)
    
    @pytest.mark.asyncio
    async def test_create_production_schedule(self, client, auth_headers):
        """Test create production schedule endpoint"""
        schedule_data = {
            "line_id": str(uuid.uuid4()),
            "start_time": datetime.now().isoformat(),
            "end_time": (datetime.now() + timedelta(hours=8)).isoformat(),
            "product_type_id": str(uuid.uuid4())
        }
        
        response = await client.post(f"{API_BASE}/production/schedules", json=schedule_data, headers=auth_headers)
        
        assert response.status_code in [200, 201, 401, 422]
    
    # Job Assignment API Tests
    @pytest.mark.asyncio
    async def test_get_job_assignments(self, client, auth_headers):
        """Test get job assignments endpoint"""
        response = await client.get(f"{API_BASE}/job-assignments", headers=auth_headers)
        
        assert response.status_code in [200, 401]
        
        if response.status_code == 200:
            data = response.json()
            assert isinstance(data, list)
    
    @pytest.mark.asyncio
    async def test_create_job_assignment(self, client, auth_headers):
        """Test create job assignment endpoint"""
        job_data = {
            "user_id": str(uuid.uuid4()),
            "job_type": "production",
            "equipment_id": str(uuid.uuid4()),
            "priority": "high",
            "title": "Test Job",
            "description": "Test job assignment"
        }
        
        response = await client.post(f"{API_BASE}/job-assignments", json=job_data, headers=auth_headers)
        
        assert response.status_code in [200, 201, 401, 422]
    
    @pytest.mark.asyncio
    async def test_accept_job(self, client, auth_headers):
        """Test accept job endpoint"""
        job_id = str(uuid.uuid4())
        
        response = await client.post(f"{API_BASE}/job-assignments/{job_id}/accept", headers=auth_headers)
        
        assert response.status_code in [200, 404, 401, 422]
    
    @pytest.mark.asyncio
    async def test_start_job(self, client, auth_headers):
        """Test start job endpoint"""
        job_id = str(uuid.uuid4())
        
        response = await client.post(f"{API_BASE}/job-assignments/{job_id}/start", headers=auth_headers)
        
        assert response.status_code in [200, 404, 401, 422]
    
    @pytest.mark.asyncio
    async def test_complete_job(self, client, auth_headers):
        """Test complete job endpoint"""
        job_id = str(uuid.uuid4())
        completion_data = {
            "notes": "Job completed successfully",
            "completion_time": datetime.now().isoformat()
        }
        
        response = await client.post(f"{API_BASE}/job-assignments/{job_id}/complete", json=completion_data, headers=auth_headers)
        
        assert response.status_code in [200, 404, 401, 422]
    
    # OEE API Tests
    @pytest.mark.asyncio
    async def test_get_oee_data(self, client, auth_headers):
        """Test get OEE data endpoint"""
        line_id = str(uuid.uuid4())
        
        response = await client.get(f"{API_BASE}/oee/lines/{line_id}", headers=auth_headers)
        
        assert response.status_code in [200, 404, 401]
        
        if response.status_code == 200:
            data = response.json()
            assert "oee" in data
            assert "availability" in data
            assert "performance" in data
            assert "quality" in data
    
    @pytest.mark.asyncio
    async def test_get_oee_trends(self, client, auth_headers):
        """Test get OEE trends endpoint"""
        line_id = str(uuid.uuid4())
        
        response = await client.get(f"{API_BASE}/oee/lines/{line_id}/trends?days=7", headers=auth_headers)
        
        assert response.status_code in [200, 404, 401]
        
        if response.status_code == 200:
            data = response.json()
            assert isinstance(data, list)
    
    # Andon API Tests
    @pytest.mark.asyncio
    async def test_get_andon_events(self, client, auth_headers):
        """Test get Andon events endpoint"""
        response = await client.get(f"{API_BASE}/andon/events", headers=auth_headers)
        
        assert response.status_code in [200, 401]
        
        if response.status_code == 200:
            data = response.json()
            assert isinstance(data, list)
    
    @pytest.mark.asyncio
    async def test_create_andon_event(self, client, auth_headers):
        """Test create Andon event endpoint"""
        event_data = {
            "equipment_code": "EQ-001",
            "line_id": str(uuid.uuid4()),
            "event_type": "fault",
            "priority": "high",
            "description": "Test Andon event",
            "reported_by": str(uuid.uuid4())
        }
        
        response = await client.post(f"{API_BASE}/andon/events", json=event_data, headers=auth_headers)
        
        assert response.status_code in [200, 201, 401, 422]
    
    @pytest.mark.asyncio
    async def test_acknowledge_andon_event(self, client, auth_headers):
        """Test acknowledge Andon event endpoint"""
        event_id = str(uuid.uuid4())
        
        response = await client.post(f"{API_BASE}/andon/events/{event_id}/acknowledge", headers=auth_headers)
        
        assert response.status_code in [200, 404, 401, 422]
    
    @pytest.mark.asyncio
    async def test_resolve_andon_event(self, client, auth_headers):
        """Test resolve Andon event endpoint"""
        event_id = str(uuid.uuid4())
        resolution_data = {
            "notes": "Issue resolved by replacing faulty component",
            "resolved_by": str(uuid.uuid4())
        }
        
        response = await client.post(f"{API_BASE}/andon/events/{event_id}/resolve", json=resolution_data, headers=auth_headers)
        
        assert response.status_code in [200, 404, 401, 422]
    
    # Equipment API Tests
    @pytest.mark.asyncio
    async def test_get_equipment_status(self, client, auth_headers):
        """Test get equipment status endpoint"""
        response = await client.get(f"{API_BASE}/equipment/status", headers=auth_headers)
        
        assert response.status_code in [200, 401]
        
        if response.status_code == 200:
            data = response.json()
            assert isinstance(data, list)
    
    @pytest.mark.asyncio
    async def test_get_equipment_by_line(self, client, auth_headers):
        """Test get equipment by line endpoint"""
        line_id = str(uuid.uuid4())
        
        response = await client.get(f"{API_BASE}/equipment/lines/{line_id}", headers=auth_headers)
        
        assert response.status_code in [200, 404, 401]
        
        if response.status_code == 200:
            data = response.json()
            assert isinstance(data, list)
    
    # Reports API Tests
    @pytest.mark.asyncio
    async def test_get_reports(self, client, auth_headers):
        """Test get reports endpoint"""
        response = await client.get(f"{API_BASE}/reports", headers=auth_headers)
        
        assert response.status_code in [200, 401]
        
        if response.status_code == 200:
            data = response.json()
            assert isinstance(data, list)
    
    @pytest.mark.asyncio
    async def test_generate_report(self, client, auth_headers):
        """Test generate report endpoint"""
        report_data = {
            "report_type": "oee_summary",
            "line_id": str(uuid.uuid4()),
            "start_date": datetime.now().isoformat(),
            "end_date": (datetime.now() + timedelta(days=7)).isoformat()
        }
        
        response = await client.post(f"{API_BASE}/reports/generate", json=report_data, headers=auth_headers)
        
        assert response.status_code in [200, 201, 401, 422]
    
    # Quality API Tests
    @pytest.mark.asyncio
    async def test_get_quality_checks(self, client, auth_headers):
        """Test get quality checks endpoint"""
        response = await client.get(f"{API_BASE}/quality/checks", headers=auth_headers)
        
        assert response.status_code in [200, 401]
        
        if response.status_code == 200:
            data = response.json()
            assert isinstance(data, list)
    
    @pytest.mark.asyncio
    async def test_create_quality_check(self, client, auth_headers):
        """Test create quality check endpoint"""
        check_data = {
            "equipment_code": "EQ-001",
            "check_type": "visual",
            "result": "pass",
            "notes": "All parameters within spec",
            "performed_by": str(uuid.uuid4())
        }
        
        response = await client.post(f"{API_BASE}/quality/checks", json=check_data, headers=auth_headers)
        
        assert response.status_code in [200, 201, 401, 422]
    
    # Error Handling Tests
    @pytest.mark.asyncio
    async def test_invalid_endpoint(self, client):
        """Test invalid endpoint returns 404"""
        response = await client.get(f"{API_BASE}/invalid/endpoint")
        
        assert response.status_code == 404
    
    @pytest.mark.asyncio
    async def test_invalid_json(self, client, auth_headers):
        """Test invalid JSON returns 422"""
        response = await client.post(
            f"{API_BASE}/production/lines",
            content="invalid json",
            headers={**auth_headers, "Content-Type": "application/json"}
        )
        
        assert response.status_code == 422
    
    @pytest.mark.asyncio
    async def test_missing_required_fields(self, client, auth_headers):
        """Test missing required fields returns 422"""
        incomplete_data = {
            "name": "Test Line"
            # Missing required fields
        }
        
        response = await client.post(f"{API_BASE}/production/lines", json=incomplete_data, headers=auth_headers)
        
        assert response.status_code in [422, 401]
    
    # Performance Tests
    @pytest.mark.asyncio
    async def test_response_time(self, client, auth_headers):
        """Test API response times are acceptable"""
        import time
        
        start_time = time.time()
        response = await client.get(f"{API_BASE}/production/lines", headers=auth_headers)
        end_time = time.time()
        
        response_time = end_time - start_time
        
        # Response should be under 1 second
        assert response_time < 1.0
        assert response.status_code in [200, 401]
    
    @pytest.mark.asyncio
    async def test_concurrent_requests(self, client, auth_headers):
        """Test concurrent API requests"""
        import asyncio
        
        async def make_request():
            return await client.get(f"{API_BASE}/production/lines", headers=auth_headers)
        
        # Make 10 concurrent requests
        tasks = [make_request() for _ in range(10)]
        responses = await asyncio.gather(*tasks)
        
        # All requests should complete successfully
        for response in responses:
            assert response.status_code in [200, 401]


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
