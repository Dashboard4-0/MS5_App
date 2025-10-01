"""
MS5.0 Floor Dashboard - OEE API Integration Tests

Integration tests for all OEE-related API endpoints.
Tests complete OEE calculation and analytics workflows.

Coverage Requirements:
- 100% OEE endpoint coverage
- All calculation methods tested
- Real-time OEE functionality verified
- Performance benchmarks validated
"""

import pytest
import pytest_asyncio
from unittest.mock import AsyncMock, Mock, patch
from datetime import datetime, timezone, timedelta, date
from uuid import uuid4
from fastapi import status
from httpx import AsyncClient


class TestOEEAPI:
    """Integration tests for OEE API endpoints."""
    
    @pytest.mark.asyncio
    async def test_calculate_oee_success(
        self, 
        async_client: AsyncClient, 
        override_get_db_session, 
        override_get_current_user
    ):
        """Test successful OEE calculation via API."""
        # Arrange
        line_id = str(uuid4())
        equipment_code = "EQ_001"
        calc_date = date.today()
        
        # Mock OEE calculation result
        oee_result = {
            "line_id": line_id,
            "equipment_code": equipment_code,
            "calculation_date": calc_date.isoformat(),
            "availability": 93.75,
            "performance": 93.33,
            "quality": 95.24,
            "oee": 83.33,
            "planned_production_time": 480.0,
            "actual_production_time": 450.0,
            "ideal_cycle_time": 1.0,
            "total_units": 420,
            "good_units": 400
        }
        
        # Mock successful OEE calculation
        with patch('backend.app.services.oee_calculator.OEECalculator.calculate_comprehensive_oee', return_value=oee_result):
            # Act
            response = await async_client.get(
                f"/api/v1/oee/calculate",
                params={
                    "line_id": line_id,
                    "equipment_code": equipment_code,
                    "date": calc_date.isoformat()
                }
            )
            
            # Assert
            assert response.status_code == status.HTTP_200_OK
            response_data = response.json()
            assert response_data["line_id"] == line_id
            assert response_data["equipment_code"] == equipment_code
            assert response_data["availability"] == 93.75
            assert response_data["performance"] == 93.33
            assert response_data["quality"] == 95.24
            assert response_data["oee"] == 83.33
    
    @pytest.mark.asyncio
    async def test_calculate_oee_no_data(
        self, 
        async_client: AsyncClient, 
        override_get_db_session, 
        override_get_current_user
    ):
        """Test OEE calculation when no data is available."""
        # Arrange
        line_id = str(uuid4())
        equipment_code = "EQ_001"
        calc_date = date.today()
        
        # Mock no data found
        with patch('backend.app.services.oee_calculator.OEECalculator.calculate_comprehensive_oee', 
                   side_effect=Exception("No production data found")):
            # Act
            response = await async_client.get(
                f"/api/v1/oee/calculate",
                params={
                    "line_id": line_id,
                    "equipment_code": equipment_code,
                    "date": calc_date.isoformat()
                }
            )
            
            # Assert
            assert response.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY
            assert "No production data found" in response.json()["detail"]
    
    @pytest.mark.asyncio
    async def test_calculate_real_time_oee_success(
        self, 
        async_client: AsyncClient, 
        override_get_db_session, 
        override_get_current_user
    ):
        """Test successful real-time OEE calculation via API."""
        # Arrange
        line_id = str(uuid4())
        equipment_code = "EQ_001"
        current_status = {
            "status": "running",
            "speed": 100.0,
            "temperature": 25.5,
            "good_units": 95,
            "total_units": 100,
            "uptime_minutes": 450,
            "planned_time_minutes": 480
        }
        
        # Mock real-time OEE calculation result
        real_time_oee_result = {
            "line_id": line_id,
            "equipment_code": equipment_code,
            "oee": 87.5,
            "availability": 93.75,
            "performance": 95.0,
            "quality": 95.0,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "current_status": current_status
        }
        
        # Mock successful real-time OEE calculation
        with patch('backend.app.services.oee_calculator.OEECalculator.calculate_real_time_oee', 
                   return_value=real_time_oee_result):
            # Act
            response = await async_client.post(
                f"/api/v1/oee/real-time",
                params={
                    "line_id": line_id,
                    "equipment_code": equipment_code
                },
                json=current_status
            )
            
            # Assert
            assert response.status_code == status.HTTP_200_OK
            response_data = response.json()
            assert response_data["line_id"] == line_id
            assert response_data["equipment_code"] == equipment_code
            assert response_data["oee"] == 87.5
            assert response_data["availability"] == 93.75
            assert response_data["performance"] == 95.0
            assert response_data["quality"] == 95.0
            assert "timestamp" in response_data
    
    @pytest.mark.asyncio
    async def test_get_oee_analytics_success(
        self, 
        async_client: AsyncClient, 
        override_get_db_session, 
        override_get_current_user
    ):
        """Test successful OEE analytics retrieval via API."""
        # Arrange
        line_id = str(uuid4())
        equipment_code = "EQ_001"
        start_date = date.today() - timedelta(days=30)
        end_date = date.today()
        
        # Mock OEE analytics data
        analytics_data = {
            "line_id": line_id,
            "equipment_code": equipment_code,
            "date_range": {
                "start_date": start_date.isoformat(),
                "end_date": end_date.isoformat()
            },
            "average_oee": 85.5,
            "average_availability": 92.0,
            "average_performance": 88.5,
            "average_quality": 95.0,
            "oee_trend": "improving",
            "daily_oee_data": [
                {"date": (start_date + timedelta(days=i)).isoformat(), "oee": 80 + i}
                for i in range(30)
            ],
            "top_losses": [
                {"category": "availability", "loss_percentage": 8.0},
                {"category": "performance", "loss_percentage": 11.5},
                {"category": "quality", "loss_percentage": 5.0}
            ]
        }
        
        # Mock successful analytics calculation
        with patch('backend.app.services.oee_calculator.OEECalculator.get_oee_analytics', 
                   return_value=analytics_data):
            # Act
            response = await async_client.get(
                f"/api/v1/oee/analysis",
                params={
                    "line_id": line_id,
                    "equipment_code": equipment_code,
                    "start_date": start_date.isoformat(),
                    "end_date": end_date.isoformat()
                }
            )
            
            # Assert
            assert response.status_code == status.HTTP_200_OK
            response_data = response.json()
            assert response_data["line_id"] == line_id
            assert response_data["equipment_code"] == equipment_code
            assert response_data["average_oee"] == 85.5
            assert response_data["oee_trend"] == "improving"
            assert len(response_data["daily_oee_data"]) == 30
            assert len(response_data["top_losses"]) == 3
    
    @pytest.mark.asyncio
    async def test_recalculate_oee_success(
        self, 
        async_client: AsyncClient, 
        override_get_db_session, 
        override_get_current_user
    ):
        """Test successful OEE recalculation via API."""
        # Arrange
        line_id = str(uuid4())
        equipment_code = "EQ_001"
        start_date = date.today() - timedelta(days=7)
        end_date = date.today()
        
        # Mock recalculation result
        recalculation_result = {
            "line_id": line_id,
            "equipment_code": equipment_code,
            "date_range": {
                "start_date": start_date.isoformat(),
                "end_date": end_date.isoformat()
            },
            "recalculation_status": "completed",
            "records_processed": 168,  # 7 days * 24 hours
            "errors_found": 0,
            "oee_corrections": 5,
            "processing_time_seconds": 12.5
        }
        
        # Mock successful recalculation
        with patch('backend.app.services.oee_calculator.OEECalculator.recalculate_oee_period', 
                   return_value=recalculation_result):
            # Act
            response = await async_client.post(
                f"/api/v1/oee/recalculate",
                params={
                    "line_id": line_id,
                    "equipment_code": equipment_code,
                    "start_date": start_date.isoformat(),
                    "end_date": end_date.isoformat()
                }
            )
            
            # Assert
            assert response.status_code == status.HTTP_200_OK
            response_data = response.json()
            assert response_data["line_id"] == line_id
            assert response_data["equipment_code"] == equipment_code
            assert response_data["recalculation_status"] == "completed"
            assert response_data["records_processed"] == 168
            assert response_data["errors_found"] == 0


class TestPLCIntegratedOEEAPI:
    """Integration tests for PLC-integrated OEE API endpoints."""
    
    @pytest.mark.asyncio
    async def test_get_plc_integrated_oee_success(
        self, 
        async_client: AsyncClient, 
        override_get_db_session, 
        override_get_current_user
    ):
        """Test successful PLC-integrated OEE retrieval via API."""
        # Arrange
        line_id = str(uuid4())
        equipment_code = "EQ_001"
        
        # Mock PLC-integrated OEE data
        plc_oee_data = {
            "line_id": line_id,
            "equipment_code": equipment_code,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "oee": 89.2,
            "availability": 94.5,
            "performance": 92.1,
            "quality": 96.8,
            "plc_data": {
                "equipment_status": "running",
                "speed": 98.5,
                "temperature": 24.8,
                "pressure": 1.15,
                "vibration": 0.08,
                "quality_metrics": {
                    "good_parts": 97,
                    "total_parts": 100,
                    "reject_rate": 3.0
                }
            },
            "equipment_efficiency": {
                "speed_efficiency": 98.5,
                "quality_efficiency": 97.0,
                "overall_efficiency": 95.75
            }
        }
        
        # Mock successful PLC-integrated OEE calculation
        with patch('backend.app.services.plc_integrated_oee_calculator.PLCIntegratedOEECalculator.get_plc_integrated_oee', 
                   return_value=plc_oee_data):
            # Act
            response = await async_client.get(
                f"/api/v1/oee/plc-integrated/{line_id}/{equipment_code}"
            )
            
            # Assert
            assert response.status_code == status.HTTP_200_OK
            response_data = response.json()
            assert response_data["line_id"] == line_id
            assert response_data["equipment_code"] == equipment_code
            assert response_data["oee"] == 89.2
            assert "plc_data" in response_data
            assert "equipment_efficiency" in response_data
            assert response_data["plc_data"]["equipment_status"] == "running"
    
    @pytest.mark.asyncio
    async def test_get_real_time_oee_analytics_success(
        self, 
        async_client: AsyncClient, 
        override_get_db_session, 
        override_get_current_user
    ):
        """Test successful real-time OEE analytics retrieval via API."""
        # Arrange
        line_id = str(uuid4())
        
        # Mock real-time OEE analytics data
        real_time_analytics = {
            "line_id": line_id,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "equipment_count": 5,
            "average_oee": 87.3,
            "equipment_oee_data": [
                {
                    "equipment_code": "EQ_001",
                    "oee": 89.2,
                    "availability": 94.5,
                    "performance": 92.1,
                    "quality": 96.8,
                    "status": "running"
                },
                {
                    "equipment_code": "EQ_002",
                    "oee": 85.1,
                    "availability": 91.2,
                    "performance": 89.8,
                    "quality": 94.5,
                    "status": "running"
                }
            ],
            "oee_distribution": {
                "excellent": 1,  # > 90%
                "good": 2,       # 80-90%
                "average": 2,    # 70-80%
                "poor": 0        # < 70%
            },
            "performance_alerts": [
                {
                    "equipment_code": "EQ_003",
                    "alert_type": "performance_degradation",
                    "message": "Performance below target threshold",
                    "severity": "warning"
                }
            ]
        }
        
        # Mock successful real-time analytics calculation
        with patch('backend.app.services.plc_integrated_oee_calculator.PLCIntegratedOEECalculator.get_real_time_oee_analytics', 
                   return_value=real_time_analytics):
            # Act
            response = await async_client.get(
                f"/api/v1/oee/real-time-analytics/{line_id}"
            )
            
            # Assert
            assert response.status_code == status.HTTP_200_OK
            response_data = response.json()
            assert response_data["line_id"] == line_id
            assert response_data["equipment_count"] == 5
            assert response_data["average_oee"] == 87.3
            assert len(response_data["equipment_oee_data"]) == 2
            assert "oee_distribution" in response_data
            assert "performance_alerts" in response_data


class TestOEEAPIPerformance:
    """Performance tests for OEE API endpoints."""
    
    @pytest.mark.asyncio
    async def test_oee_calculation_performance(
        self, 
        async_client: AsyncClient, 
        override_get_db_session, 
        override_get_current_user,
        performance_helper
    ):
        """Test OEE calculation API performance."""
        # Arrange
        line_id = str(uuid4())
        equipment_code = "EQ_001"
        calc_date = date.today()
        
        # Mock OEE calculation result
        oee_result = {
            "line_id": line_id,
            "equipment_code": equipment_code,
            "oee": 83.33,
            "availability": 93.75,
            "performance": 93.33,
            "quality": 95.24
        }
        
        # Mock successful OEE calculation
        with patch('backend.app.services.oee_calculator.OEECalculator.calculate_comprehensive_oee', 
                   return_value=oee_result):
            # Act
            response_time = performance_helper.measure_response_time(
                async_client, "GET", 
                f"/api/v1/oee/calculate?line_id={line_id}&equipment_code={equipment_code}&date={calc_date.isoformat()}"
            )
            
            # Assert
            performance_helper.assert_response_time_acceptable(response_time, max_acceptable_ms=500.0)
    
    @pytest.mark.asyncio
    async def test_real_time_oee_performance(
        self, 
        async_client: AsyncClient, 
        override_get_db_session, 
        override_get_current_user,
        performance_helper
    ):
        """Test real-time OEE API performance."""
        # Arrange
        line_id = str(uuid4())
        equipment_code = "EQ_001"
        current_status = {
            "status": "running",
            "speed": 100.0,
            "good_units": 95,
            "total_units": 100
        }
        
        # Mock real-time OEE calculation result
        real_time_result = {
            "oee": 87.5,
            "availability": 93.75,
            "performance": 95.0,
            "quality": 95.0
        }
        
        # Mock successful real-time OEE calculation
        with patch('backend.app.services.oee_calculator.OEECalculator.calculate_real_time_oee', 
                   return_value=real_time_result):
            # Act
            response_time = performance_helper.measure_response_time(
                async_client, "POST", 
                f"/api/v1/oee/real-time?line_id={line_id}&equipment_code={equipment_code}",
                json=current_status
            )
            
            # Assert
            performance_helper.assert_response_time_acceptable(response_time, max_acceptable_ms=300.0)
    
    @pytest.mark.asyncio
    async def test_oee_analytics_performance(
        self, 
        async_client: AsyncClient, 
        override_get_db_session, 
        override_get_current_user,
        performance_helper
    ):
        """Test OEE analytics API performance."""
        # Arrange
        line_id = str(uuid4())
        equipment_code = "EQ_001"
        start_date = date.today() - timedelta(days=30)
        end_date = date.today()
        
        # Mock analytics data
        analytics_data = {
            "average_oee": 85.5,
            "oee_trend": "improving",
            "daily_oee_data": [{"date": (start_date + timedelta(days=i)).isoformat(), "oee": 80 + i} for i in range(30)]
        }
        
        # Mock successful analytics calculation
        with patch('backend.app.services.oee_calculator.OEECalculator.get_oee_analytics', 
                   return_value=analytics_data):
            # Act
            response_time = performance_helper.measure_response_time(
                async_client, "GET", 
                f"/api/v1/oee/analysis?line_id={line_id}&equipment_code={equipment_code}&start_date={start_date.isoformat()}&end_date={end_date.isoformat()}"
            )
            
            # Assert
            performance_helper.assert_response_time_acceptable(response_time, max_acceptable_ms=1000.0)
