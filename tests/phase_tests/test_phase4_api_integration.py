"""
MS5.0 Floor Dashboard - Phase 4 API Integration Test Suite

This module provides comprehensive tests for Phase 4: API Integration,
including enhanced production management endpoints, OEE analytics,
WebSocket functionality, and PLC integration.
"""

import asyncio
import json
import pytest
import uuid
from datetime import datetime, date, timedelta
from typing import Dict, Any, List
from unittest.mock import AsyncMock, MagicMock, patch

from fastapi.testclient import TestClient
from fastapi import WebSocket
import structlog

# Import the FastAPI app
from backend.app.main import app
from backend.app.services.equipment_job_mapper import EquipmentJobMapper
from backend.app.services.plc_integrated_oee_calculator import PLCIntegratedOEECalculator
from backend.app.services.plc_integrated_downtime_tracker import PLCIntegratedDowntimeTracker
from backend.app.services.plc_integrated_andon_service import PLCIntegratedAndonService
from backend.app.services.enhanced_websocket_manager import EnhancedWebSocketManager

logger = structlog.get_logger()

# Test client
client = TestClient(app)

# Test data
TEST_LINE_ID = str(uuid.uuid4())
TEST_EQUIPMENT_CODE = "BP01.PACK.BAG1"
TEST_USER_ID = str(uuid.uuid4())
TEST_JOB_ID = str(uuid.uuid4())


class TestEnhancedProductionAPI:
    """Test suite for enhanced production API endpoints."""
    
    def setup_method(self):
        """Setup test data and mocks."""
        self.test_line_id = TEST_LINE_ID
        self.test_equipment_code = TEST_EQUIPMENT_CODE
        self.test_user_id = TEST_USER_ID
        self.test_job_id = TEST_JOB_ID
    
    @patch('backend.app.api.v1.enhanced_production.equipment_job_mapper')
    @patch('backend.app.api.v1.enhanced_production._get_current_plc_metrics')
    @patch('backend.app.api.v1.enhanced_production.plc_oee_calculator')
    @patch('backend.app.api.v1.enhanced_production.plc_downtime_tracker')
    def test_get_equipment_production_status(
        self,
        mock_downtime_tracker,
        mock_oee_calculator,
        mock_plc_metrics,
        mock_job_mapper
    ):
        """Test equipment production status endpoint with PLC integration."""
        # Setup mocks
        mock_job_mapper.get_current_job.return_value = {
            "id": self.test_job_id,
            "line_id": self.test_line_id,
            "target_quantity": 1000,
            "status": "running"
        }
        
        mock_job_mapper.get_equipment_production_context.return_value = {
            "equipment_code": self.test_equipment_code,
            "production_line_id": self.test_line_id,
            "current_operator": "test_operator"
        }
        
        mock_plc_metrics.return_value = {
            "equipment_code": self.test_equipment_code,
            "running_status": True,
            "product_count": 500,
            "speed": 100.0,
            "has_faults": False
        }
        
        mock_oee_calculator.calculate_real_time_oee.return_value = {
            "oee": 0.85,
            "availability": 0.90,
            "performance": 0.95,
            "quality": 0.95
        }
        
        mock_downtime_tracker.get_current_downtime_status.return_value = {
            "status": "running",
            "downtime_hours": 0.0
        }
        
        # Make API request
        response = client.get(
            f"/api/v1/enhanced/equipment/{self.test_equipment_code}/production-status",
            params={
                "include_plc_data": True,
                "include_oee": True,
                "include_downtime": True
            }
        )
        
        # Assertions
        assert response.status_code == 200
        data = response.json()
        
        assert data["equipment_code"] == self.test_equipment_code
        assert "production_status" in data
        assert "plc_data" in data
        assert "oee" in data
        assert "downtime" in data
        
        # Verify mock calls
        mock_job_mapper.get_current_job.assert_called_once_with(self.test_equipment_code)
        mock_job_mapper.get_equipment_production_context.assert_called_once_with(self.test_equipment_code)
        mock_plc_metrics.assert_called_once_with(self.test_equipment_code)
        mock_oee_calculator.calculate_real_time_oee.assert_called_once()
        mock_downtime_tracker.get_current_downtime_status.assert_called_once_with(self.test_equipment_code)
    
    @patch('backend.app.api.v1.enhanced_production._get_line_equipment')
    @patch('backend.app.api.v1.enhanced_production._get_current_plc_metrics')
    @patch('backend.app.api.v1.enhanced_production.plc_oee_calculator')
    def test_get_real_time_oee(
        self,
        mock_oee_calculator,
        mock_plc_metrics,
        mock_get_line_equipment
    ):
        """Test real-time OEE endpoint with PLC integration."""
        # Setup mocks
        mock_get_line_equipment.return_value = [self.test_equipment_code]
        
        mock_plc_metrics.return_value = {
            "equipment_code": self.test_equipment_code,
            "running_status": True,
            "product_count": 500
        }
        
        mock_oee_calculator.calculate_real_time_oee.return_value = {
            "oee": 0.85,
            "availability": 0.90,
            "performance": 0.95,
            "quality": 0.95
        }
        
        mock_oee_calculator.get_oee_trends_from_plc.return_value = {
            "trend": "stable",
            "average_oee": 0.85
        }
        
        # Make API request
        response = client.get(
            f"/api/v1/enhanced/lines/{self.test_line_id}/real-time-oee",
            params={
                "include_trends": True
            }
        )
        
        # Assertions
        assert response.status_code == 200
        data = response.json()
        
        assert data["line_id"] == self.test_line_id
        assert "equipment_oee" in data
        assert "line_oee" in data
        assert "trends" in data
        
        # Verify mock calls
        mock_get_line_equipment.assert_called_once()
        mock_plc_metrics.assert_called_once_with(self.test_equipment_code)
        mock_oee_calculator.calculate_real_time_oee.assert_called_once()
    
    @patch('backend.app.api.v1.enhanced_production.equipment_job_mapper')
    @patch('backend.app.api.v1.enhanced_production._get_current_plc_metrics')
    def test_get_job_progress(
        self,
        mock_plc_metrics,
        mock_job_mapper
    ):
        """Test job progress endpoint with PLC integration."""
        # Setup mocks
        mock_job_mapper.get_current_job.return_value = {
            "id": self.test_job_id,
            "line_id": self.test_line_id,
            "target_quantity": 1000,
            "status": "running"
        }
        
        mock_job_mapper.get_job_progress.return_value = {
            "job_id": self.test_job_id,
            "progress_percentage": 50.0,
            "actual_quantity": 500,
            "target_quantity": 1000
        }
        
        mock_plc_metrics.return_value = {
            "equipment_code": self.test_equipment_code,
            "product_count": 500,
            "running_status": True
        }
        
        # Make API request
        response = client.get(
            f"/api/v1/enhanced/equipment/{self.test_equipment_code}/job-progress",
            params={
                "include_plc_metrics": True
            }
        )
        
        # Assertions
        assert response.status_code == 200
        data = response.json()
        
        assert "job_id" in data
        assert "progress_percentage" in data
        assert "plc_metrics" in data
        
        # Verify mock calls
        mock_job_mapper.get_current_job.assert_called_once_with(self.test_equipment_code)
        mock_job_mapper.get_job_progress.assert_called_once()
        mock_plc_metrics.assert_called_once_with(self.test_equipment_code)
    
    @patch('backend.app.api.v1.enhanced_production.equipment_job_mapper')
    def test_assign_job_to_equipment(self, mock_job_mapper):
        """Test job assignment endpoint."""
        # Setup mocks
        mock_job_mapper.assign_job_to_equipment.return_value = {
            "assignment_id": str(uuid.uuid4()),
            "equipment_code": self.test_equipment_code,
            "job_id": self.test_job_id,
            "assigned_at": datetime.utcnow().isoformat()
        }
        
        # Make API request
        response = client.post(
            f"/api/v1/enhanced/equipment/{self.test_equipment_code}/job-assignment",
            params={
                "job_id": self.test_job_id,
                "assign_reason": "Production schedule update"
            }
        )
        
        # Assertions
        assert response.status_code == 201
        data = response.json()
        
        assert data["message"] == "Job assigned successfully"
        assert "assignment" in data
        
        # Verify mock calls
        mock_job_mapper.assign_job_to_equipment.assert_called_once()
    
    @patch('backend.app.api.v1.enhanced_production.equipment_job_mapper')
    @patch('backend.app.api.v1.enhanced_production._get_current_plc_metrics')
    def test_complete_job_on_equipment(
        self,
        mock_plc_metrics,
        mock_job_mapper
    ):
        """Test job completion endpoint."""
        # Setup mocks
        mock_job_mapper.get_current_job.return_value = {
            "id": self.test_job_id,
            "line_id": self.test_line_id,
            "status": "running"
        }
        
        mock_job_mapper.complete_job_on_equipment.return_value = {
            "completion_id": str(uuid.uuid4()),
            "job_id": self.test_job_id,
            "completed_at": datetime.utcnow().isoformat()
        }
        
        mock_plc_metrics.return_value = {
            "equipment_code": self.test_equipment_code,
            "product_count": 1000,
            "running_status": True
        }
        
        # Make API request
        response = client.post(
            f"/api/v1/enhanced/equipment/{self.test_equipment_code}/job-completion",
            params={
                "completion_notes": "Job completed successfully"
            }
        )
        
        # Assertions
        assert response.status_code == 200
        data = response.json()
        
        assert data["message"] == "Job completed successfully"
        assert "completion" in data
        assert "final_metrics" in data
        
        # Verify mock calls
        mock_job_mapper.get_current_job.assert_called_once_with(self.test_equipment_code)
        mock_job_mapper.complete_job_on_equipment.assert_called_once()
        mock_plc_metrics.assert_called_once_with(self.test_equipment_code)


class TestEnhancedOEEAnalyticsAPI:
    """Test suite for enhanced OEE analytics API endpoints."""
    
    def setup_method(self):
        """Setup test data and mocks."""
        self.test_line_id = TEST_LINE_ID
        self.test_equipment_code = TEST_EQUIPMENT_CODE
        self.test_user_id = TEST_USER_ID
    
    @patch('backend.app.api.v1.enhanced_oee_analytics._get_line_equipment')
    @patch('backend.app.api.v1.enhanced_oee_analytics._get_current_plc_metrics')
    @patch('backend.app.api.v1.enhanced_oee_analytics.plc_oee_calculator')
    @patch('backend.app.api.v1.enhanced_oee_analytics.plc_downtime_tracker')
    def test_get_real_time_oee_analytics(
        self,
        mock_downtime_tracker,
        mock_oee_calculator,
        mock_plc_metrics,
        mock_get_line_equipment
    ):
        """Test real-time OEE analytics endpoint."""
        # Setup mocks
        mock_get_line_equipment.return_value = [self.test_equipment_code]
        
        mock_plc_metrics.return_value = {
            "equipment_code": self.test_equipment_code,
            "running_status": True,
            "product_count": 500
        }
        
        mock_oee_calculator.calculate_real_time_oee.return_value = {
            "oee": 0.85,
            "availability": 0.90,
            "performance": 0.95,
            "quality": 0.95
        }
        
        mock_oee_calculator.get_oee_trends_from_plc.return_value = {
            "trend": "stable",
            "average_oee": 0.85
        }
        
        mock_downtime_tracker.get_downtime_analysis.return_value = {
            "total_downtime_hours": 2.0,
            "downtime_events": 3
        }
        
        mock_downtime_tracker.get_line_downtime_analysis.return_value = {
            "line_downtime_hours": 4.0,
            "line_downtime_events": 5
        }
        
        # Make API request
        response = client.get(
            f"/api/v1/enhanced/oee/lines/{self.test_line_id}/real-time-oee-analytics",
            params={
                "include_breakdown": True,
                "include_downtime_analysis": True,
                "include_trends": True
            }
        )
        
        # Assertions
        assert response.status_code == 200
        data = response.json()
        
        assert data["line_id"] == self.test_line_id
        assert "equipment_analytics" in data
        assert "line_analytics" in data
        assert "downtime_analysis" in data
        assert "trends" in data
        assert "insights" in data
        assert "recommendations" in data
        
        # Verify mock calls
        mock_get_line_equipment.assert_called_once()
        mock_plc_metrics.assert_called_once_with(self.test_equipment_code)
        mock_oee_calculator.calculate_real_time_oee.assert_called_once()
    
    @patch('backend.app.api.v1.enhanced_oee_analytics._get_equipment_line_id')
    @patch('backend.app.api.v1.enhanced_oee_analytics.plc_oee_calculator')
    @patch('backend.app.api.v1.enhanced_oee_analytics.plc_downtime_tracker')
    def test_get_equipment_oee_performance_report(
        self,
        mock_downtime_tracker,
        mock_oee_calculator,
        mock_get_line_id
    ):
        """Test equipment OEE performance report endpoint."""
        # Setup mocks
        mock_get_line_id.return_value = uuid.UUID(self.test_line_id)
        
        mock_oee_calculator.calculate_plc_based_oee.return_value = {
            "oee": 0.85,
            "availability": 0.90,
            "performance": 0.95,
            "quality": 0.95,
            "production_hours": 168.0,
            "planned_production_hours": 168.0,
            "actual_production": 1000,
            "target_production": 1200,
            "quality_issues": 5
        }
        
        mock_downtime_tracker.get_period_downtime_analysis.return_value = {
            "total_downtime_hours": 10.0,
            "downtime_events": 8
        }
        
        # Test data
        start_date = date.today() - timedelta(days=7)
        end_date = date.today()
        
        # Make API request
        response = client.get(
            f"/api/v1/enhanced/oee/equipment/{self.test_equipment_code}/oee-performance-report",
            params={
                "start_date": start_date,
                "end_date": end_date,
                "report_type": "detailed",
                "include_plc_data": True,
                "include_downtime_breakdown": True,
                "include_benchmarks": True
            }
        )
        
        # Assertions
        assert response.status_code == 200
        data = response.json()
        
        assert data["equipment_code"] == self.test_equipment_code
        assert data["line_id"] == self.test_line_id
        assert "report_period" in data
        assert "oee_summary" in data
        assert "performance_metrics" in data
        assert "downtime_analysis" in data
        assert "plc_data_analysis" in data
        assert "benchmarks" in data
        assert "insights" in data
        assert "recommendations" in data
        
        # Verify mock calls
        mock_get_line_id.assert_called_once_with(self.test_equipment_code)
        mock_oee_calculator.calculate_plc_based_oee.assert_called_once()
    
    @patch('backend.app.api.v1.enhanced_oee_analytics._get_line_equipment')
    @patch('backend.app.api.v1.enhanced_oee_analytics.plc_oee_calculator')
    def test_get_oee_comparative_analysis(
        self,
        mock_oee_calculator,
        mock_get_line_equipment
    ):
        """Test OEE comparative analysis endpoint."""
        # Setup mocks
        mock_get_line_equipment.return_value = [self.test_equipment_code]
        
        mock_oee_calculator.get_current_line_oee.return_value = {
            "oee": 0.85,
            "availability": 0.90,
            "performance": 0.95,
            "quality": 0.95
        }
        
        mock_oee_calculator.get_oee_trends_from_plc.return_value = {
            "trend": "stable",
            "average_oee": 0.85
        }
        
        # Make API request
        response = client.get(
            f"/api/v1/enhanced/oee/lines/{self.test_line_id}/oee-comparative-analysis",
            params={
                "comparison_period_days": 30,
                "include_equipment_comparison": True,
                "include_historical_comparison": True,
                "include_benchmark_comparison": True
            }
        )
        
        # Assertions
        assert response.status_code == 200
        data = response.json()
        
        assert data["line_id"] == self.test_line_id
        assert "current_performance" in data
        assert "historical_comparison" in data
        assert "equipment_comparison" in data
        assert "benchmark_comparison" in data
        assert "trend_analysis" in data
        assert "insights" in data
        assert "recommendations" in data
        
        # Verify mock calls
        mock_get_line_equipment.assert_called_once()
        mock_oee_calculator.get_current_line_oee.assert_called_once()
    
    @patch('backend.app.api.v1.enhanced_oee_analytics._get_line_equipment')
    @patch('backend.app.api.v1.enhanced_oee_analytics.plc_oee_calculator')
    def test_get_oee_alert_analysis(
        self,
        mock_oee_calculator,
        mock_get_line_equipment
    ):
        """Test OEE alert analysis endpoint."""
        # Setup mocks
        mock_get_line_equipment.return_value = [self.test_equipment_code]
        
        mock_oee_calculator.get_current_line_oee.return_value = {
            "oee": 0.65,  # Below threshold
            "availability": 0.90,
            "performance": 0.95,
            "quality": 0.95
        }
        
        # Make API request
        response = client.get(
            f"/api/v1/enhanced/oee/lines/{self.test_line_id}/oee-alert-analysis",
            params={
                "alert_threshold": 0.70,
                "time_period_hours": 24,
                "include_equipment_alerts": True,
                "include_trend_alerts": True
            }
        )
        
        # Assertions
        assert response.status_code == 200
        data = response.json()
        
        assert data["line_id"] == self.test_line_id
        assert "line_alerts" in data
        assert "equipment_alerts" in data
        assert "trend_alerts" in data
        assert "alert_summary" in data
        assert "recommendations" in data
        
        # Verify alert was triggered (OEE below threshold)
        assert len(data["line_alerts"]) > 0
        assert data["alert_summary"]["total_alerts"] > 0
        
        # Verify mock calls
        mock_get_line_equipment.assert_called_once()
        mock_oee_calculator.get_current_line_oee.assert_called_once()


class TestEnhancedProductionWebSocket:
    """Test suite for enhanced production WebSocket endpoints."""
    
    def setup_method(self):
        """Setup test data and mocks."""
        self.test_line_id = TEST_LINE_ID
        self.test_equipment_code = TEST_EQUIPMENT_CODE
        self.test_user_id = TEST_USER_ID
    
    @patch('backend.app.api.v1.enhanced_production_websocket.websocket_manager')
    def test_production_websocket_connection(self, mock_websocket_manager):
        """Test production WebSocket connection."""
        # Setup mocks
        mock_websocket_manager.register_connection.return_value = "test_connection_id"
        
        # This would require a more complex WebSocket test setup
        # For now, we'll test the endpoint exists
        with client.websocket_connect(
            f"/api/v1/ws/production?line_id={self.test_line_id}&user_id={self.test_user_id}"
        ) as websocket:
            # Test connection establishment
            data = websocket.receive_json()
            assert data["type"] == "connection_established"
            assert data["line_id"] == self.test_line_id
            
            # Test ping/pong
            websocket.send_json({"type": "ping"})
            data = websocket.receive_json()
            assert data["type"] == "pong"
    
    @patch('backend.app.api.v1.enhanced_production_websocket.websocket_manager')
    def test_line_production_websocket_connection(self, mock_websocket_manager):
        """Test line-specific production WebSocket connection."""
        # Setup mocks
        mock_websocket_manager.register_connection.return_value = "test_connection_id"
        
        with client.websocket_connect(
            f"/api/v1/ws/production/{self.test_line_id}?user_id={self.test_user_id}"
        ) as websocket:
            # Test connection establishment
            data = websocket.receive_json()
            assert data["type"] == "line_connection_established"
            assert data["line_id"] == self.test_line_id
            
            # Test subscription
            websocket.send_json({"type": "subscribe", "event_type": "production_update"})
            data = websocket.receive_json()
            assert data["type"] == "subscription_confirmed"
            assert data["event_type"] == "production_update"
    
    @patch('backend.app.api.v1.enhanced_production_websocket.websocket_manager')
    def test_equipment_production_websocket_connection(self, mock_websocket_manager):
        """Test equipment-specific production WebSocket connection."""
        # Setup mocks
        mock_websocket_manager.register_connection.return_value = "test_connection_id"
        
        with client.websocket_connect(
            f"/api/v1/ws/equipment/{self.test_equipment_code}?user_id={self.test_user_id}"
        ) as websocket:
            # Test connection establishment
            data = websocket.receive_json()
            assert data["type"] == "equipment_connection_established"
            assert data["equipment_code"] == self.test_equipment_code
    
    def test_get_production_event_types(self):
        """Test production event types endpoint."""
        response = client.get("/api/v1/ws/production/events/types")
        
        assert response.status_code == 200
        data = response.json()
        
        assert "event_types" in data
        assert "total_event_types" in data
        
        event_types = data["event_types"]
        assert "production_events" in event_types
        assert "oee_events" in event_types
        assert "downtime_events" in event_types
        assert "andon_events" in event_types
        assert "quality_events" in event_types
        assert "plc_events" in event_types
        assert "system_events" in event_types
    
    @patch('backend.app.api.v1.enhanced_production_websocket.websocket_manager')
    def test_get_production_subscriptions(self, mock_websocket_manager):
        """Test production subscriptions endpoint."""
        # Setup mocks
        mock_websocket_manager.get_subscriptions.return_value = [
            {
                "connection_id": "test_connection_id",
                "user_id": self.test_user_id,
                "line_id": self.test_line_id,
                "subscriptions": ["production_update", "oee_update"]
            }
        ]
        
        response = client.get("/api/v1/ws/production/subscriptions")
        
        assert response.status_code == 200
        data = response.json()
        
        assert "subscriptions" in data
        assert "total_connections" in data
        assert len(data["subscriptions"]) == 1
        
        # Verify mock calls
        mock_websocket_manager.get_subscriptions.assert_called_once()
    
    @patch('backend.app.api.v1.enhanced_production_websocket.websocket_manager')
    def test_get_production_websocket_stats(self, mock_websocket_manager):
        """Test production WebSocket stats endpoint."""
        # Setup mocks
        mock_websocket_manager.get_websocket_stats.return_value = {
            "total_connections": 10,
            "active_connections": 8,
            "total_subscriptions": 25,
            "connection_types": {
                "production": 5,
                "line_production": 3,
                "equipment_production": 2
            }
        }
        
        response = client.get("/api/v1/ws/production/stats")
        
        assert response.status_code == 200
        data = response.json()
        
        assert "websocket_stats" in data
        stats = data["websocket_stats"]
        assert "total_connections" in stats
        assert "active_connections" in stats
        assert "total_subscriptions" in stats
        assert "connection_types" in stats
        
        # Verify mock calls
        mock_websocket_manager.get_websocket_stats.assert_called_once()


class TestIntegrationScenarios:
    """Test suite for end-to-end integration scenarios."""
    
    def setup_method(self):
        """Setup test data and mocks."""
        self.test_line_id = TEST_LINE_ID
        self.test_equipment_code = TEST_EQUIPMENT_CODE
        self.test_user_id = TEST_USER_ID
        self.test_job_id = TEST_JOB_ID
    
    @patch('backend.app.api.v1.enhanced_production.equipment_job_mapper')
    @patch('backend.app.api.v1.enhanced_production.plc_oee_calculator')
    @patch('backend.app.api.v1.enhanced_production.plc_downtime_tracker')
    @patch('backend.app.api.v1.enhanced_production.plc_andon_service')
    def test_complete_production_workflow(
        self,
        mock_andon_service,
        mock_downtime_tracker,
        mock_oee_calculator,
        mock_job_mapper
    ):
        """Test complete production workflow integration."""
        # Setup mocks for complete workflow
        mock_job_mapper.get_current_job.return_value = {
            "id": self.test_job_id,
            "line_id": self.test_line_id,
            "target_quantity": 1000,
            "status": "running"
        }
        
        mock_job_mapper.get_equipment_production_context.return_value = {
            "equipment_code": self.test_equipment_code,
            "production_line_id": self.test_line_id,
            "current_operator": "test_operator"
        }
        
        mock_oee_calculator.calculate_real_time_oee.return_value = {
            "oee": 0.85,
            "availability": 0.90,
            "performance": 0.95,
            "quality": 0.95
        }
        
        mock_downtime_tracker.get_current_downtime_status.return_value = {
            "status": "running",
            "downtime_hours": 0.0
        }
        
        mock_andon_service.get_active_andon_events.return_value = []
        
        # Test 1: Get equipment production status
        response1 = client.get(
            f"/api/v1/enhanced/equipment/{self.test_equipment_code}/production-status"
        )
        assert response1.status_code == 200
        
        # Test 2: Get real-time OEE
        response2 = client.get(
            f"/api/v1/enhanced/lines/{self.test_line_id}/real-time-oee"
        )
        assert response2.status_code == 200
        
        # Test 3: Get line production metrics
        response3 = client.get(
            f"/api/v1/enhanced/lines/{self.test_line_id}/production-metrics"
        )
        assert response3.status_code == 200
        
        # Test 4: Get downtime status
        response4 = client.get(
            f"/api/v1/enhanced/equipment/{self.test_equipment_code}/downtime-status"
        )
        assert response4.status_code == 200
        
        # Test 5: Get Andon status
        response5 = client.get(
            f"/api/v1/enhanced/lines/{self.test_line_id}/andon-status"
        )
        assert response5.status_code == 200
        
        # Verify all services were called
        assert mock_job_mapper.get_current_job.call_count >= 1
        assert mock_oee_calculator.calculate_real_time_oee.call_count >= 1
        assert mock_downtime_tracker.get_current_downtime_status.call_count >= 1
        assert mock_andon_service.get_active_andon_events.call_count >= 1
    
    @patch('backend.app.api.v1.enhanced_oee_analytics.plc_oee_calculator')
    @patch('backend.app.api.v1.enhanced_oee_analytics.plc_downtime_tracker')
    def test_complete_oee_analytics_workflow(
        self,
        mock_downtime_tracker,
        mock_oee_calculator
    ):
        """Test complete OEE analytics workflow integration."""
        # Setup mocks
        mock_oee_calculator.calculate_real_time_oee.return_value = {
            "oee": 0.85,
            "availability": 0.90,
            "performance": 0.95,
            "quality": 0.95
        }
        
        mock_oee_calculator.get_oee_trends_from_plc.return_value = {
            "trend": "stable",
            "average_oee": 0.85
        }
        
        mock_oee_calculator.calculate_plc_based_oee.return_value = {
            "oee": 0.85,
            "availability": 0.90,
            "performance": 0.95,
            "quality": 0.95
        }
        
        mock_downtime_tracker.get_downtime_analysis.return_value = {
            "total_downtime_hours": 2.0,
            "downtime_events": 3
        }
        
        # Test 1: Get real-time OEE analytics
        response1 = client.get(
            f"/api/v1/enhanced/oee/lines/{self.test_line_id}/real-time-oee-analytics"
        )
        assert response1.status_code == 200
        
        # Test 2: Get performance report
        start_date = date.today() - timedelta(days=7)
        end_date = date.today()
        response2 = client.get(
            f"/api/v1/enhanced/oee/equipment/{self.test_equipment_code}/oee-performance-report",
            params={"start_date": start_date, "end_date": end_date}
        )
        assert response2.status_code == 200
        
        # Test 3: Get comparative analysis
        response3 = client.get(
            f"/api/v1/enhanced/oee/lines/{self.test_line_id}/oee-comparative-analysis"
        )
        assert response3.status_code == 200
        
        # Test 4: Get alert analysis
        response4 = client.get(
            f"/api/v1/enhanced/oee/lines/{self.test_line_id}/oee-alert-analysis"
        )
        assert response4.status_code == 200
        
        # Test 5: Get optimization recommendations
        response5 = client.post(
            f"/api/v1/enhanced/oee/lines/{self.test_line_id}/oee-optimization-recommendations"
        )
        assert response5.status_code == 200
        
        # Verify services were called
        assert mock_oee_calculator.calculate_real_time_oee.call_count >= 1
        assert mock_oee_calculator.calculate_plc_based_oee.call_count >= 1
        assert mock_downtime_tracker.get_downtime_analysis.call_count >= 1


class TestErrorHandling:
    """Test suite for error handling in Phase 4 API endpoints."""
    
    def setup_method(self):
        """Setup test data."""
        self.test_line_id = TEST_LINE_ID
        self.test_equipment_code = TEST_EQUIPMENT_CODE
    
    @patch('backend.app.api.v1.enhanced_production.equipment_job_mapper')
    def test_equipment_not_found_error(self, mock_job_mapper):
        """Test error handling for equipment not found."""
        # Setup mock to raise exception
        mock_job_mapper.get_current_job.side_effect = Exception("Equipment not found")
        
        response = client.get(
            f"/api/v1/enhanced/equipment/{self.test_equipment_code}/production-status"
        )
        
        # Should return 500 error due to unhandled exception
        assert response.status_code == 500
    
    def test_invalid_line_id_format(self):
        """Test error handling for invalid line ID format."""
        response = client.get("/api/v1/enhanced/lines/invalid-uuid/real-time-oee")
        
        # Should return 422 validation error
        assert response.status_code == 422
    
    def test_invalid_date_range(self):
        """Test error handling for invalid date range."""
        start_date = date.today()
        end_date = date.today() - timedelta(days=1)  # End before start
        
        response = client.get(
            f"/api/v1/enhanced/oee/equipment/{self.test_equipment_code}/oee-performance-report",
            params={"start_date": start_date, "end_date": end_date}
        )
        
        # Should return 400 error
        assert response.status_code == 400
    
    def test_date_range_too_large(self):
        """Test error handling for date range too large."""
        start_date = date.today() - timedelta(days=100)  # Too large
        end_date = date.today()
        
        response = client.get(
            f"/api/v1/enhanced/oee/equipment/{self.test_equipment_code}/oee-performance-report",
            params={"start_date": start_date, "end_date": end_date}
        )
        
        # Should return 400 error
        assert response.status_code == 400
    
    def test_invalid_optimization_focus(self):
        """Test error handling for invalid optimization focus."""
        response = client.post(
            f"/api/v1/enhanced/oee/lines/{self.test_line_id}/oee-optimization-recommendations",
            params={"optimization_focus": "invalid_focus"}
        )
        
        # Should return 400 error
        assert response.status_code == 400
    
    def test_invalid_andon_event_type(self):
        """Test error handling for invalid Andon event type."""
        response = client.post(
            f"/api/v1/enhanced/equipment/{self.test_equipment_code}/trigger-andon",
            params={
                "event_type": "invalid_type",
                "priority": "high",
                "description": "Test event"
            }
        )
        
        # Should return 400 error
        assert response.status_code == 400
    
    def test_invalid_andon_priority(self):
        """Test error handling for invalid Andon priority."""
        response = client.post(
            f"/api/v1/enhanced/equipment/{self.test_equipment_code}/trigger-andon",
            params={
                "event_type": "maintenance",
                "priority": "invalid_priority",
                "description": "Test event"
            }
        )
        
        # Should return 400 error
        assert response.status_code == 400


# Test runner configuration
if __name__ == "__main__":
    # Configure test logging
    logging.basicConfig(level=logging.INFO)
    
    # Run tests
    pytest.main([
        __file__,
        "-v",
        "--tb=short",
        "--disable-warnings"
    ])
