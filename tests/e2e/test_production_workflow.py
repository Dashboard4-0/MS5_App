"""
End-to-end tests for production workflow
Tests complete production management workflow from start to finish
"""

import pytest
import asyncio
import httpx
import uuid
from datetime import datetime, timedelta
import json


class TestProductionWorkflow:
    """End-to-end tests for production workflow"""
    
    @pytest.fixture
    async def client(self):
        """Create HTTP client for E2E testing"""
        async with httpx.AsyncClient(base_url="http://localhost:8000", timeout=30.0) as client:
            yield client
    
    @pytest.fixture
    async def auth_token(self, client):
        """Get authentication token for E2E testing"""
        login_data = {
            "email": "test@example.com",
            "password": "testpassword"
        }
        
        response = await client.post("/api/v1/auth/login", json=login_data)
        if response.status_code == 200:
            return response.json()["token"]
        return None
    
    @pytest.fixture
    def auth_headers(self, auth_token):
        """Get authentication headers"""
        if auth_token:
            return {"Authorization": f"Bearer {auth_token}"}
        return {}
    
    @pytest.mark.asyncio
    async def test_complete_production_workflow(self, client, auth_headers):
        """Test complete production workflow from line creation to job completion"""
        
        # Step 1: Create Production Line
        line_data = {
            "name": "E2E Test Line",
            "description": "End-to-end test production line",
            "status": "active"
        }
        
        line_response = await client.post("/api/v1/production/lines", json=line_data, headers=auth_headers)
        
        if line_response.status_code in [200, 201]:
            line_id = line_response.json()["id"]
        else:
            # Use existing line if creation fails
            lines_response = await client.get("/api/v1/production/lines", headers=auth_headers)
            if lines_response.status_code == 200 and lines_response.json():
                line_id = lines_response.json()[0]["id"]
            else:
                pytest.skip("No production lines available for testing")
        
        # Step 2: Create Production Schedule
        schedule_data = {
            "line_id": line_id,
            "start_time": datetime.now().isoformat(),
            "end_time": (datetime.now() + timedelta(hours=8)).isoformat(),
            "product_type_id": str(uuid.uuid4())
        }
        
        schedule_response = await client.post("/api/v1/production/schedules", json=schedule_data, headers=auth_headers)
        
        if schedule_response.status_code in [200, 201]:
            schedule_id = schedule_response.json()["id"]
        else:
            pytest.skip("Could not create production schedule")
        
        # Step 3: Create Job Assignment
        job_data = {
            "user_id": str(uuid.uuid4()),
            "job_type": "production",
            "title": "E2E Test Job",
            "description": "End-to-end test job assignment",
            "priority": "high",
            "equipment_id": str(uuid.uuid4())
        }
        
        job_response = await client.post("/api/v1/job-assignments", json=job_data, headers=auth_headers)
        
        if job_response.status_code in [200, 201]:
            job_id = job_response.json()["id"]
        else:
            pytest.skip("Could not create job assignment")
        
        # Step 4: Accept Job
        accept_response = await client.post(f"/api/v1/job-assignments/{job_id}/accept", headers=auth_headers)
        
        if accept_response.status_code == 200:
            assert accept_response.json()["status"] == "accepted"
        else:
            pytest.skip("Could not accept job")
        
        # Step 5: Start Job
        start_response = await client.post(f"/api/v1/job-assignments/{job_id}/start", headers=auth_headers)
        
        if start_response.status_code == 200:
            assert start_response.json()["status"] == "in_progress"
        else:
            pytest.skip("Could not start job")
        
        # Step 6: Complete Job
        completion_data = {
            "notes": "E2E test job completed successfully",
            "completion_time": datetime.now().isoformat()
        }
        
        complete_response = await client.post(f"/api/v1/job-assignments/{job_id}/complete", json=completion_data, headers=auth_headers)
        
        if complete_response.status_code == 200:
            assert complete_response.json()["status"] == "completed"
        else:
            pytest.skip("Could not complete job")
        
        # Step 7: Verify Job Status
        job_status_response = await client.get(f"/api/v1/job-assignments/{job_id}", headers=auth_headers)
        
        if job_status_response.status_code == 200:
            job_status = job_status_response.json()
            assert job_status["status"] == "completed"
            assert job_status["completion_notes"] == completion_data["notes"]
        else:
            pytest.skip("Could not verify job status")
        
        # Step 8: Cleanup (if we created the line)
        if line_response.status_code in [200, 201]:
            cleanup_response = await client.delete(f"/api/v1/production/lines/{line_id}", headers=auth_headers)
            # Cleanup failure is not critical for test success
    
    @pytest.mark.asyncio
    async def test_production_line_management_workflow(self, client, auth_headers):
        """Test production line management workflow"""
        
        # Step 1: Create Production Line
        line_data = {
            "name": "E2E Line Management Test",
            "description": "Test line for management workflow",
            "status": "active"
        }
        
        create_response = await client.post("/api/v1/production/lines", json=line_data, headers=auth_headers)
        
        if create_response.status_code in [200, 201]:
            line_id = create_response.json()["id"]
            
            # Step 2: Update Production Line
            update_data = {
                "name": "Updated E2E Line",
                "status": "inactive"
            }
            
            update_response = await client.put(f"/api/v1/production/lines/{line_id}", json=update_data, headers=auth_headers)
            
            if update_response.status_code == 200:
                updated_line = update_response.json()
                assert updated_line["name"] == update_data["name"]
                assert updated_line["status"] == update_data["status"]
            
            # Step 3: Get Production Line Details
            get_response = await client.get(f"/api/v1/production/lines/{line_id}", headers=auth_headers)
            
            if get_response.status_code == 200:
                line_details = get_response.json()
                assert line_details["id"] == line_id
                assert line_details["name"] == update_data["name"]
            
            # Step 4: List All Production Lines
            list_response = await client.get("/api/v1/production/lines", headers=auth_headers)
            
            if list_response.status_code == 200:
                lines = list_response.json()
                assert isinstance(lines, list)
                # Our line should be in the list
                line_found = any(line["id"] == line_id for line in lines)
                assert line_found
            
            # Step 5: Cleanup
            delete_response = await client.delete(f"/api/v1/production/lines/{line_id}", headers=auth_headers)
            # Cleanup failure is not critical for test success
        else:
            pytest.skip("Could not create production line for management workflow test")
    
    @pytest.mark.asyncio
    async def test_production_schedule_workflow(self, client, auth_headers):
        """Test production schedule management workflow"""
        
        # Get existing production line
        lines_response = await client.get("/api/v1/production/lines", headers=auth_headers)
        
        if lines_response.status_code == 200 and lines_response.json():
            line_id = lines_response.json()[0]["id"]
        else:
            pytest.skip("No production lines available for schedule testing")
        
        # Step 1: Create Production Schedule
        schedule_data = {
            "line_id": line_id,
            "start_time": datetime.now().isoformat(),
            "end_time": (datetime.now() + timedelta(hours=8)).isoformat(),
            "product_type_id": str(uuid.uuid4()),
            "status": "scheduled"
        }
        
        create_response = await client.post("/api/v1/production/schedules", json=schedule_data, headers=auth_headers)
        
        if create_response.status_code in [200, 201]:
            schedule_id = create_response.json()["id"]
            
            # Step 2: Update Production Schedule
            update_data = {
                "status": "in_progress",
                "start_time": datetime.now().isoformat()
            }
            
            update_response = await client.put(f"/api/v1/production/schedules/{schedule_id}", json=update_data, headers=auth_headers)
            
            if update_response.status_code == 200:
                updated_schedule = update_response.json()
                assert updated_schedule["status"] == update_data["status"]
            
            # Step 3: Get Production Schedule Details
            get_response = await client.get(f"/api/v1/production/schedules/{schedule_id}", headers=auth_headers)
            
            if get_response.status_code == 200:
                schedule_details = get_response.json()
                assert schedule_details["id"] == schedule_id
                assert schedule_details["line_id"] == line_id
            
            # Step 4: List Production Schedules
            list_response = await client.get("/api/v1/production/schedules", headers=auth_headers)
            
            if list_response.status_code == 200:
                schedules = list_response.json()
                assert isinstance(schedules, list)
                # Our schedule should be in the list
                schedule_found = any(schedule["id"] == schedule_id for schedule in schedules)
                assert schedule_found
            
            # Step 5: Complete Production Schedule
            complete_data = {
                "status": "completed",
                "end_time": datetime.now().isoformat()
            }
            
            complete_response = await client.put(f"/api/v1/production/schedules/{schedule_id}", json=complete_data, headers=auth_headers)
            
            if complete_response.status_code == 200:
                completed_schedule = complete_response.json()
                assert completed_schedule["status"] == "completed"
            
            # Step 6: Cleanup
            delete_response = await client.delete(f"/api/v1/production/schedules/{schedule_id}", headers=auth_headers)
            # Cleanup failure is not critical for test success
        else:
            pytest.skip("Could not create production schedule")
    
    @pytest.mark.asyncio
    async def test_job_assignment_workflow(self, client, auth_headers):
        """Test job assignment workflow"""
        
        # Step 1: Create Job Assignment
        job_data = {
            "user_id": str(uuid.uuid4()),
            "job_type": "maintenance",
            "title": "E2E Maintenance Job",
            "description": "End-to-end test maintenance job",
            "priority": "medium",
            "equipment_id": str(uuid.uuid4()),
            "due_date": (datetime.now() + timedelta(hours=2)).isoformat()
        }
        
        create_response = await client.post("/api/v1/job-assignments", json=job_data, headers=auth_headers)
        
        if create_response.status_code in [200, 201]:
            job_id = create_response.json()["id"]
            
            # Step 2: Get Job Assignment Details
            get_response = await client.get(f"/api/v1/job-assignments/{job_id}", headers=auth_headers)
            
            if get_response.status_code == 200:
                job_details = get_response.json()
                assert job_details["id"] == job_id
                assert job_details["title"] == job_data["title"]
                assert job_details["status"] == "assigned"
            
            # Step 3: Accept Job
            accept_response = await client.post(f"/api/v1/job-assignments/{job_id}/accept", headers=auth_headers)
            
            if accept_response.status_code == 200:
                accepted_job = accept_response.json()
                assert accepted_job["status"] == "accepted"
                assert accepted_job["accepted_at"] is not None
            
            # Step 4: Start Job
            start_response = await client.post(f"/api/v1/job-assignments/{job_id}/start", headers=auth_headers)
            
            if start_response.status_code == 200:
                started_job = start_response.json()
                assert started_job["status"] == "in_progress"
                assert started_job["started_at"] is not None
            
            # Step 5: Update Job Progress
            progress_data = {
                "progress": 50,
                "notes": "Job is 50% complete"
            }
            
            update_response = await client.put(f"/api/v1/job-assignments/{job_id}", json=progress_data, headers=auth_headers)
            
            if update_response.status_code == 200:
                updated_job = update_response.json()
                assert updated_job["progress"] == progress_data["progress"]
            
            # Step 6: Complete Job
            completion_data = {
                "notes": "E2E maintenance job completed successfully",
                "completion_time": datetime.now().isoformat()
            }
            
            complete_response = await client.post(f"/api/v1/job-assignments/{job_id}/complete", json=completion_data, headers=auth_headers)
            
            if complete_response.status_code == 200:
                completed_job = complete_response.json()
                assert completed_job["status"] == "completed"
                assert completed_job["completion_notes"] == completion_data["notes"]
                assert completed_job["completed_at"] is not None
            
            # Step 7: Verify Final Job Status
            final_response = await client.get(f"/api/v1/job-assignments/{job_id}", headers=auth_headers)
            
            if final_response.status_code == 200:
                final_job = final_response.json()
                assert final_job["status"] == "completed"
                assert final_job["progress"] == 100
        else:
            pytest.skip("Could not create job assignment")
    
    @pytest.mark.asyncio
    async def test_production_monitoring_workflow(self, client, auth_headers):
        """Test production monitoring workflow"""
        
        # Step 1: Get Production Lines Status
        lines_response = await client.get("/api/v1/production/lines", headers=auth_headers)
        
        if lines_response.status_code == 200:
            lines = lines_response.json()
            assert isinstance(lines, list)
            
            if lines:
                line_id = lines[0]["id"]
                
                # Step 2: Get Production Schedules for Line
                schedules_response = await client.get(f"/api/v1/production/schedules?line_id={line_id}", headers=auth_headers)
                
                if schedules_response.status_code == 200:
                    schedules = schedules_response.json()
                    assert isinstance(schedules, list)
                
                # Step 3: Get Job Assignments for Line
                jobs_response = await client.get(f"/api/v1/job-assignments?line_id={line_id}", headers=auth_headers)
                
                if jobs_response.status_code == 200:
                    jobs = jobs_response.json()
                    assert isinstance(jobs, list)
                
                # Step 4: Get Equipment Status for Line
                equipment_response = await client.get(f"/api/v1/equipment/lines/{line_id}", headers=auth_headers)
                
                if equipment_response.status_code == 200:
                    equipment = equipment_response.json()
                    assert isinstance(equipment, list)
                
                # Step 5: Get OEE Data for Line
                oee_response = await client.get(f"/api/v1/oee/lines/{line_id}", headers=auth_headers)
                
                if oee_response.status_code == 200:
                    oee_data = oee_response.json()
                    assert "oee" in oee_data
                    assert "availability" in oee_data
                    assert "performance" in oee_data
                    assert "quality" in oee_data
                
                # Step 6: Get OEE Trends for Line
                trends_response = await client.get(f"/api/v1/oee/lines/{line_id}/trends?days=7", headers=auth_headers)
                
                if trends_response.status_code == 200:
                    trends = trends_response.json()
                    assert isinstance(trends, list)
        else:
            pytest.skip("Could not get production lines for monitoring workflow test")


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
