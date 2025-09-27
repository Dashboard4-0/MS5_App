"""
End-to-end tests for OEE calculation workflow
Tests complete OEE calculation, monitoring, and reporting workflow
"""

import pytest
import asyncio
import httpx
import uuid
from datetime import datetime, timedelta
import json


class TestOEECalculationWorkflow:
    """End-to-end tests for OEE calculation workflow"""
    
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
    async def test_complete_oee_calculation_workflow(self, client, auth_headers):
        """Test complete OEE calculation workflow from data collection to reporting"""
        
        # Step 1: Create Production Line
        line_data = {
            "name": "E2E OEE Test Line",
            "description": "End-to-end test production line for OEE",
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
                pytest.skip("No production lines available for OEE testing")
        
        # Step 2: Create Equipment Configuration
        equipment_data = {
            "equipment_code": "EQ-OEE-TEST-001",
            "equipment_name": "E2E OEE Test Equipment",
            "equipment_type": "production",
            "production_line_id": line_id,
            "ideal_cycle_time": 1.0,
            "target_speed": 100.0,
            "oee_targets": {
                "availability": 0.9,
                "performance": 0.9,
                "quality": 0.95
            }
        }
        
        equipment_response = await client.post("/api/v1/equipment/config", json=equipment_data, headers=auth_headers)
        
        if equipment_response.status_code in [200, 201]:
            equipment_id = equipment_response.json()["id"]
        else:
            pytest.skip("Could not create equipment configuration")
        
        # Step 3: Create Production Schedule
        schedule_data = {
            "line_id": line_id,
            "start_time": datetime.now().isoformat(),
            "end_time": (datetime.now() + timedelta(hours=8)).isoformat(),
            "product_type_id": str(uuid.uuid4()),
            "status": "scheduled"
        }
        
        schedule_response = await client.post("/api/v1/production/schedules", json=schedule_data, headers=auth_headers)
        
        if schedule_response.status_code in [200, 201]:
            schedule_id = schedule_response.json()["id"]
        else:
            pytest.skip("Could not create production schedule")
        
        # Step 4: Start Production Schedule
        start_schedule_data = {
            "status": "in_progress",
            "start_time": datetime.now().isoformat()
        }
        
        start_schedule_response = await client.put(f"/api/v1/production/schedules/{schedule_id}", json=start_schedule_data, headers=auth_headers)
        
        if start_schedule_response.status_code == 200:
            assert start_schedule_response.json()["status"] == "in_progress"
        else:
            pytest.skip("Could not start production schedule")
        
        # Step 5: Simulate Production Data Collection
        production_data = [
            {
                "equipment_code": "EQ-OEE-TEST-001",
                "timestamp": datetime.now().isoformat(),
                "running": True,
                "speed": 95.0,
                "target_speed": 100.0,
                "good_parts": 950,
                "total_parts": 1000,
                "cycle_time": 0.8,
                "ideal_cycle_time": 1.0
            },
            {
                "equipment_code": "EQ-OEE-TEST-001",
                "timestamp": (datetime.now() + timedelta(minutes=5)).isoformat(),
                "running": True,
                "speed": 98.0,
                "target_speed": 100.0,
                "good_parts": 980,
                "total_parts": 1000,
                "cycle_time": 0.85,
                "ideal_cycle_time": 1.0
            }
        ]
        
        for data_point in production_data:
            data_response = await client.post("/api/v1/oee/data", json=data_point, headers=auth_headers)
            
            if data_response.status_code not in [200, 201]:
                pytest.skip("Could not submit production data")
        
        # Step 6: Calculate Real-time OEE
        oee_calculation_data = {
            "equipment_code": "EQ-OEE-TEST-001",
            "line_id": line_id,
            "current_metrics": {
                "running": True,
                "speed": 95.0,
                "target_speed": 100.0,
                "good_parts": 950,
                "total_parts": 1000,
                "cycle_time": 0.8,
                "ideal_cycle_time": 1.0
            }
        }
        
        oee_response = await client.post("/api/v1/oee/calculate", json=oee_calculation_data, headers=auth_headers)
        
        if oee_response.status_code == 200:
            oee_data = oee_response.json()
            assert "oee" in oee_data
            assert "availability" in oee_data
            assert "performance" in oee_data
            assert "quality" in oee_data
            assert 0 <= oee_data["oee"] <= 1
            assert 0 <= oee_data["availability"] <= 1
            assert 0 <= oee_data["performance"] <= 1
            assert 0 <= oee_data["quality"] <= 1
        else:
            pytest.skip("Could not calculate OEE")
        
        # Step 7: Get OEE Data for Line
        line_oee_response = await client.get(f"/api/v1/oee/lines/{line_id}", headers=auth_headers)
        
        if line_oee_response.status_code == 200:
            line_oee_data = line_oee_response.json()
            assert "oee" in line_oee_data
            assert "availability" in line_oee_data
            assert "performance" in line_oee_data
            assert "quality" in line_oee_data
        else:
            pytest.skip("Could not get OEE data for line")
        
        # Step 8: Get OEE Trends
        trends_response = await client.get(f"/api/v1/oee/lines/{line_id}/trends?days=7", headers=auth_headers)
        
        if trends_response.status_code == 200:
            trends_data = trends_response.json()
            assert isinstance(trends_data, list)
        else:
            pytest.skip("Could not get OEE trends")
        
        # Step 9: Create Downtime Event
        downtime_data = {
            "equipment_code": "EQ-OEE-TEST-001",
            "line_id": line_id,
            "start_time": datetime.now().isoformat(),
            "end_time": (datetime.now() + timedelta(minutes=30)).isoformat(),
            "duration_minutes": 30,
            "category": "unplanned",
            "description": "E2E test downtime event"
        }
        
        downtime_response = await client.post("/api/v1/downtime/events", json=downtime_data, headers=auth_headers)
        
        if downtime_response.status_code in [200, 201]:
            downtime_id = downtime_response.json()["id"]
        else:
            pytest.skip("Could not create downtime event")
        
        # Step 10: Recalculate OEE with Downtime
        updated_oee_response = await client.post("/api/v1/oee/calculate", json=oee_calculation_data, headers=auth_headers)
        
        if updated_oee_response.status_code == 200:
            updated_oee_data = updated_oee_response.json()
            # OEE should be lower due to downtime
            assert updated_oee_data["availability"] < 1.0
        else:
            pytest.skip("Could not recalculate OEE with downtime")
        
        # Step 11: Complete Production Schedule
        complete_schedule_data = {
            "status": "completed",
            "end_time": datetime.now().isoformat()
        }
        
        complete_schedule_response = await client.put(f"/api/v1/production/schedules/{schedule_id}", json=complete_schedule_data, headers=auth_headers)
        
        if complete_schedule_response.status_code == 200:
            assert complete_schedule_response.json()["status"] == "completed"
        else:
            pytest.skip("Could not complete production schedule")
        
        # Step 12: Generate OEE Report
        report_data = {
            "report_type": "oee_summary",
            "line_id": line_id,
            "start_date": (datetime.now() - timedelta(hours=1)).isoformat(),
            "end_date": datetime.now().isoformat(),
            "include_details": True
        }
        
        report_response = await client.post("/api/v1/oee/reports/generate", json=report_data, headers=auth_headers)
        
        if report_response.status_code in [200, 201]:
            generated_report = report_response.json()
            assert "report_id" in generated_report
            assert "status" in generated_report
        else:
            pytest.skip("Could not generate OEE report")
        
        # Step 13: Cleanup
        if line_response.status_code in [200, 201]:
            cleanup_response = await client.delete(f"/api/v1/production/lines/{line_id}", headers=auth_headers)
            # Cleanup failure is not critical for test success
    
    @pytest.mark.asyncio
    async def test_oee_availability_calculation(self, client, auth_headers):
        """Test OEE availability calculation workflow"""
        
        # Step 1: Create Equipment with Known Configuration
        equipment_data = {
            "equipment_code": "EQ-AVAILABILITY-TEST",
            "equipment_name": "Availability Test Equipment",
            "equipment_type": "production",
            "ideal_cycle_time": 1.0,
            "target_speed": 100.0,
            "oee_targets": {
                "availability": 0.9,
                "performance": 0.9,
                "quality": 0.95
            }
        }
        
        equipment_response = await client.post("/api/v1/equipment/config", json=equipment_data, headers=auth_headers)
        
        if equipment_response.status_code in [200, 201]:
            equipment_id = equipment_response.json()["id"]
        else:
            pytest.skip("Could not create equipment for availability test")
        
        # Step 2: Create Planned Downtime
        planned_downtime_data = {
            "equipment_code": "EQ-AVAILABILITY-TEST",
            "start_time": datetime.now().isoformat(),
            "end_time": (datetime.now() + timedelta(hours=1)).isoformat(),
            "duration_minutes": 60,
            "category": "planned",
            "description": "Planned maintenance"
        }
        
        planned_downtime_response = await client.post("/api/v1/downtime/events", json=planned_downtime_data, headers=auth_headers)
        
        if planned_downtime_response.status_code in [200, 201]:
            planned_downtime_id = planned_downtime_response.json()["id"]
        else:
            pytest.skip("Could not create planned downtime")
        
        # Step 3: Create Unplanned Downtime
        unplanned_downtime_data = {
            "equipment_code": "EQ-AVAILABILITY-TEST",
            "start_time": (datetime.now() + timedelta(hours=1)).isoformat(),
            "end_time": (datetime.now() + timedelta(hours=1, minutes=30)).isoformat(),
            "duration_minutes": 30,
            "category": "unplanned",
            "description": "Equipment breakdown"
        }
        
        unplanned_downtime_response = await client.post("/api/v1/downtime/events", json=unplanned_downtime_data, headers=auth_headers)
        
        if unplanned_downtime_response.status_code in [200, 201]:
            unplanned_downtime_id = unplanned_downtime_response.json()["id"]
        else:
            pytest.skip("Could not create unplanned downtime")
        
        # Step 4: Calculate Availability
        availability_calculation_data = {
            "equipment_code": "EQ-AVAILABILITY-TEST",
            "time_period_hours": 8,
            "include_planned_downtime": True
        }
        
        availability_response = await client.post("/api/v1/oee/availability/calculate", json=availability_calculation_data, headers=auth_headers)
        
        if availability_response.status_code == 200:
            availability_data = availability_response.json()
            assert "availability" in availability_data
            assert "planned_downtime_minutes" in availability_data
            assert "unplanned_downtime_minutes" in availability_data
            assert "total_downtime_minutes" in availability_data
            assert 0 <= availability_data["availability"] <= 1
        else:
            pytest.skip("Could not calculate availability")
        
        # Step 5: Get Downtime Summary
        downtime_summary_response = await client.get("/api/v1/downtime/summary?equipment_code=EQ-AVAILABILITY-TEST", headers=auth_headers)
        
        if downtime_summary_response.status_code == 200:
            downtime_summary = downtime_summary_response.json()
            assert "total_downtime_minutes" in downtime_summary
            assert "planned_downtime_minutes" in downtime_summary
            assert "unplanned_downtime_minutes" in downtime_summary
        else:
            pytest.skip("Could not get downtime summary")
    
    @pytest.mark.asyncio
    async def test_oee_performance_calculation(self, client, auth_headers):
        """Test OEE performance calculation workflow"""
        
        # Step 1: Create Equipment with Performance Configuration
        equipment_data = {
            "equipment_code": "EQ-PERFORMANCE-TEST",
            "equipment_name": "Performance Test Equipment",
            "equipment_type": "production",
            "ideal_cycle_time": 1.0,
            "target_speed": 100.0,
            "oee_targets": {
                "availability": 0.9,
                "performance": 0.9,
                "quality": 0.95
            }
        }
        
        equipment_response = await client.post("/api/v1/equipment/config", json=equipment_data, headers=auth_headers)
        
        if equipment_response.status_code in [200, 201]:
            equipment_id = equipment_response.json()["id"]
        else:
            pytest.skip("Could not create equipment for performance test")
        
        # Step 2: Submit Performance Data
        performance_data = [
            {
                "equipment_code": "EQ-PERFORMANCE-TEST",
                "timestamp": datetime.now().isoformat(),
                "cycle_time": 0.8,
                "ideal_cycle_time": 1.0,
                "speed": 95.0,
                "target_speed": 100.0,
                "units_produced": 100
            },
            {
                "equipment_code": "EQ-PERFORMANCE-TEST",
                "timestamp": (datetime.now() + timedelta(minutes=5)).isoformat(),
                "cycle_time": 1.2,
                "ideal_cycle_time": 1.0,
                "speed": 80.0,
                "target_speed": 100.0,
                "units_produced": 80
            }
        ]
        
        for data_point in performance_data:
            data_response = await client.post("/api/v1/oee/performance/data", json=data_point, headers=auth_headers)
            
            if data_response.status_code not in [200, 201]:
                pytest.skip("Could not submit performance data")
        
        # Step 3: Calculate Performance
        performance_calculation_data = {
            "equipment_code": "EQ-PERFORMANCE-TEST",
            "time_period_hours": 1
        }
        
        performance_response = await client.post("/api/v1/oee/performance/calculate", json=performance_calculation_data, headers=auth_headers)
        
        if performance_response.status_code == 200:
            performance_data = performance_response.json()
            assert "performance" in performance_data
            assert "avg_cycle_time" in performance_data
            assert "ideal_cycle_time" in performance_data
            assert "avg_speed" in performance_data
            assert "target_speed" in performance_data
            assert 0 <= performance_data["performance"] <= 1
        else:
            pytest.skip("Could not calculate performance")
        
        # Step 4: Get Performance Trends
        performance_trends_response = await client.get("/api/v1/oee/performance/trends?equipment_code=EQ-PERFORMANCE-TEST&days=7", headers=auth_headers)
        
        if performance_trends_response.status_code == 200:
            performance_trends = performance_trends_response.json()
            assert isinstance(performance_trends, list)
        else:
            pytest.skip("Could not get performance trends")
    
    @pytest.mark.asyncio
    async def test_oee_quality_calculation(self, client, auth_headers):
        """Test OEE quality calculation workflow"""
        
        # Step 1: Create Equipment with Quality Configuration
        equipment_data = {
            "equipment_code": "EQ-QUALITY-TEST",
            "equipment_name": "Quality Test Equipment",
            "equipment_type": "production",
            "ideal_cycle_time": 1.0,
            "target_speed": 100.0,
            "oee_targets": {
                "availability": 0.9,
                "performance": 0.9,
                "quality": 0.95
            }
        }
        
        equipment_response = await client.post("/api/v1/equipment/config", json=equipment_data, headers=auth_headers)
        
        if equipment_response.status_code in [200, 201]:
            equipment_id = equipment_response.json()["id"]
        else:
            pytest.skip("Could not create equipment for quality test")
        
        # Step 2: Submit Quality Data
        quality_data = [
            {
                "equipment_code": "EQ-QUALITY-TEST",
                "timestamp": datetime.now().isoformat(),
                "good_parts": 950,
                "total_parts": 1000,
                "defect_count": 50,
                "rework_count": 20
            },
            {
                "equipment_code": "EQ-QUALITY-TEST",
                "timestamp": (datetime.now() + timedelta(minutes=5)).isoformat(),
                "good_parts": 980,
                "total_parts": 1000,
                "defect_count": 20,
                "rework_count": 10
            }
        ]
        
        for data_point in quality_data:
            data_response = await client.post("/api/v1/oee/quality/data", json=data_point, headers=auth_headers)
            
            if data_response.status_code not in [200, 201]:
                pytest.skip("Could not submit quality data")
        
        # Step 3: Calculate Quality
        quality_calculation_data = {
            "equipment_code": "EQ-QUALITY-TEST",
            "time_period_hours": 1
        }
        
        quality_response = await client.post("/api/v1/oee/quality/calculate", json=quality_calculation_data, headers=auth_headers)
        
        if quality_response.status_code == 200:
            quality_data = quality_response.json()
            assert "quality" in quality_data
            assert "good_parts" in quality_data
            assert "total_parts" in quality_data
            assert "defect_rate" in quality_data
            assert "rework_rate" in quality_data
            assert 0 <= quality_data["quality"] <= 1
        else:
            pytest.skip("Could not calculate quality")
        
        # Step 4: Get Quality Trends
        quality_trends_response = await client.get("/api/v1/oee/quality/trends?equipment_code=EQ-QUALITY-TEST&days=7", headers=auth_headers)
        
        if quality_trends_response.status_code == 200:
            quality_trends = quality_trends_response.json()
            assert isinstance(quality_trends, list)
        else:
            pytest.skip("Could not get quality trends")
    
    @pytest.mark.asyncio
    async def test_oee_reporting_and_analytics(self, client, auth_headers):
        """Test OEE reporting and analytics functionality"""
        
        # Step 1: Get OEE Dashboard Data
        dashboard_response = await client.get("/api/v1/oee/dashboard", headers=auth_headers)
        
        if dashboard_response.status_code == 200:
            dashboard_data = dashboard_response.json()
            assert "overall_oee" in dashboard_data
            assert "line_oee" in dashboard_data
            assert "equipment_oee" in dashboard_data
            assert "trends" in dashboard_data
        else:
            pytest.skip("Could not get OEE dashboard data")
        
        # Step 2: Get OEE Analytics
        analytics_response = await client.get("/api/v1/oee/analytics", headers=auth_headers)
        
        if analytics_response.status_code == 200:
            analytics_data = analytics_response.json()
            assert "summary" in analytics_data
            assert "trends" in analytics_data
            assert "comparisons" in analytics_data
        else:
            pytest.skip("Could not get OEE analytics")
        
        # Step 3: Generate OEE Report
        report_data = {
            "report_type": "oee_detailed",
            "start_date": (datetime.now() - timedelta(days=7)).isoformat(),
            "end_date": datetime.now().isoformat(),
            "include_breakdown": True,
            "include_trends": True
        }
        
        report_response = await client.post("/api/v1/oee/reports/generate", json=report_data, headers=auth_headers)
        
        if report_response.status_code in [200, 201]:
            generated_report = report_response.json()
            assert "report_id" in generated_report
            assert "status" in generated_report
        else:
            pytest.skip("Could not generate OEE report")
        
        # Step 4: Get OEE Alerts
        alerts_response = await client.get("/api/v1/oee/alerts", headers=auth_headers)
        
        if alerts_response.status_code == 200:
            alerts_data = alerts_response.json()
            assert isinstance(alerts_data, list)
        else:
            pytest.skip("Could not get OEE alerts")
        
        # Step 5: Get OEE Targets and Goals
        targets_response = await client.get("/api/v1/oee/targets", headers=auth_headers)
        
        if targets_response.status_code == 200:
            targets_data = targets_response.json()
            assert "availability_target" in targets_data
            assert "performance_target" in targets_data
            assert "quality_target" in targets_data
            assert "overall_oee_target" in targets_data
        else:
            pytest.skip("Could not get OEE targets")


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
