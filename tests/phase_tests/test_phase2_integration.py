"""
MS5.0 Floor Dashboard - Phase 2 Integration Test Suite

This module provides comprehensive tests for Phase 2: Service Integration
of the PLC Integration Plan, testing the enhanced services and their
integration with the existing PLC telemetry system.
"""

import pytest
import asyncio
from datetime import datetime, timedelta
from typing import Dict, Any
from uuid import UUID, uuid4
from unittest.mock import Mock, patch, AsyncMock

# Import the enhanced services
from backend.app.services.enhanced_metric_transformer import EnhancedMetricTransformer
from backend.app.services.enhanced_telemetry_poller import EnhancedTelemetryPoller, ProductionContextManager
from backend.app.services.equipment_job_mapper import EquipmentJobMapper
from backend.app.services.plc_integrated_oee_calculator import PLCIntegratedOEECalculator
from backend.app.services.plc_integrated_downtime_tracker import PLCIntegratedDowntimeTracker
from backend.app.services.plc_integrated_andon_service import PLCIntegratedAndonService


class TestEnhancedMetricTransformer:
    """Test suite for EnhancedMetricTransformer."""
    
    @pytest.fixture
    def transformer(self):
        """Create EnhancedMetricTransformer instance."""
        fault_catalog = {
            0: {"name": "Emergency Stop", "description": "Emergency stop activated", "marker": "INTERNAL", "severity": "critical"},
            1: {"name": "Safety Gate Open", "description": "Safety gate is open", "marker": "INTERNAL", "severity": "high"}
        }
        return EnhancedMetricTransformer(fault_catalog=fault_catalog)
    
    def test_enhanced_transformer_initialization(self, transformer):
        """Test enhanced transformer initialization."""
        assert transformer is not None
        assert transformer.fault_catalog is not None
        assert transformer.oee_calculator is not None
        assert transformer.downtime_tracker is not None
    
    def test_transform_bagger_metrics_enhanced(self, transformer):
        """Test enhanced bagger metrics transformation."""
        raw_data = {
            "processed": {
                "speed_real": 5.0,
                "product_count": 100,
                "current_product": 1,
                "fault_bits": [False] * 64,
                "has_active_faults": False
            }
        }
        
        context_data = {
            "equipment_code": "BP01.PACK.BAG1",
            "current_operator": "test_operator",
            "current_shift": "Day",
            "planned_stop": False
        }
        
        metrics = transformer.transform_bagger_metrics(raw_data, context_data)
        
        # Check basic metrics
        assert "speed_real" in metrics
        assert "product_count" in metrics
        assert "running_status" in metrics
        
        # Check enhanced metrics
        assert "production_line_id" in metrics
        assert "current_job_id" in metrics
        assert "production_efficiency" in metrics
        assert "quality_rate" in metrics
        assert "changeover_status" in metrics
    
    def test_calculate_production_efficiency(self, transformer):
        """Test production efficiency calculation."""
        processed = {"speed_real": 8.0}
        context_data = {"target_speed": 10.0}
        
        efficiency = transformer._calculate_production_efficiency(processed, context_data)
        
        assert efficiency == 80.0  # 8.0/10.0 * 100
    
    def test_calculate_quality_rate(self, transformer):
        """Test quality rate calculation."""
        processed = {"product_count": 100}
        context_data = {}
        
        quality_rate = transformer._calculate_quality_rate(processed, context_data)
        
        assert quality_rate == 95.0  # Default quality rate
    
    def test_detect_changeover_status(self, transformer):
        """Test changeover status detection."""
        # Test running status
        processed = {"speed_real": 5.0, "running_status": True}
        context_data = {"planned_stop": False}
        
        status = transformer._detect_changeover_status(processed, context_data)
        assert status == "completed"
        
        # Test planned stop
        processed = {"speed_real": 0.0, "running_status": False}
        context_data = {"planned_stop": True}
        
        status = transformer._detect_changeover_status(processed, context_data)
        assert status == "in_progress"


class TestEnhancedTelemetryPoller:
    """Test suite for EnhancedTelemetryPoller."""
    
    @pytest.fixture
    def poller(self):
        """Create EnhancedTelemetryPoller instance."""
        return EnhancedTelemetryPoller()
    
    @pytest.mark.asyncio
    async def test_poller_initialization(self, poller):
        """Test enhanced poller initialization."""
        with patch.object(poller, 'initialize') as mock_init:
            mock_init.return_value = None
            await poller.initialize()
            mock_init.assert_called_once()
    
    def test_performance_stats(self, poller):
        """Test performance statistics tracking."""
        # Simulate some cycle times
        poller.poll_cycle_times = [0.5, 0.6, 0.7, 0.8, 0.9]
        
        stats = poller.get_performance_stats()
        
        assert "total_cycles" in stats
        assert "avg_cycle_time" in stats
        assert "min_cycle_time" in stats
        assert "max_cycle_time" in stats
        assert stats["total_cycles"] == 5
        assert stats["avg_cycle_time"] == 0.7


class TestProductionContextManager:
    """Test suite for ProductionContextManager."""
    
    @pytest.fixture
    def context_manager(self):
        """Create ProductionContextManager instance."""
        production_service = Mock()
        return ProductionContextManager(production_service)
    
    @pytest.mark.asyncio
    async def test_get_production_context(self, context_manager):
        """Test getting production context."""
        with patch('backend.app.services.enhanced_telemetry_poller.execute_query') as mock_query:
            mock_query.return_value = [{
                "current_job_id": str(uuid4()),
                "production_line_id": str(uuid4()),
                "target_quantity": 1000,
                "actual_quantity": 500
            }]
            
            context = await context_manager.get_production_context("BP01.PACK.BAG1")
            
            assert context is not None
            assert "current_job_id" in context
            assert "production_line_id" in context


class TestEquipmentJobMapper:
    """Test suite for EquipmentJobMapper."""
    
    @pytest.fixture
    def job_mapper(self):
        """Create EquipmentJobMapper instance."""
        production_service = Mock()
        return EquipmentJobMapper(production_service)
    
    @pytest.mark.asyncio
    async def test_get_current_job(self, job_mapper):
        """Test getting current job for equipment."""
        with patch('backend.app.services.equipment_job_mapper.execute_query') as mock_query:
            job_id = uuid4()
            mock_query.return_value = [{
                "current_job_id": job_id,
                "production_schedule_id": str(uuid4()),
                "production_line_id": str(uuid4()),
                "target_quantity": 1000,
                "actual_quantity": 500,
                "target_speed": 10.0
            }]
            
            with patch.object(job_mapper, '_get_job_details') as mock_job_details:
                mock_job_details.return_value = {"id": job_id, "status": "in_progress"}
                
                job = await job_mapper.get_current_job("BP01.PACK.BAG1")
                
                assert job is not None
                assert job["job_id"] == job_id
                assert job["target_quantity"] == 1000
                assert job["actual_quantity"] == 500
    
    def test_calculate_progress_percentage(self, job_mapper):
        """Test progress percentage calculation."""
        percentage = job_mapper._calculate_progress_percentage(500, 1000)
        assert percentage == 50.0
        
        percentage = job_mapper._calculate_progress_percentage(0, 0)
        assert percentage == 0.0
    
    def test_estimate_completion_time(self, job_mapper):
        """Test completion time estimation."""
        completion_time = job_mapper._estimate_completion_time(500, 1000, 10.0)
        assert completion_time is not None
        assert isinstance(completion_time, datetime)
        
        # Test with completed job
        completion_time = job_mapper._estimate_completion_time(1000, 1000, 10.0)
        assert completion_time is None


class TestPLCIntegratedOEECalculator:
    """Test suite for PLCIntegratedOEECalculator."""
    
    @pytest.fixture
    def oee_calculator(self):
        """Create PLCIntegratedOEECalculator instance."""
        return PLCIntegratedOEECalculator()
    
    @pytest.mark.asyncio
    async def test_calculate_real_time_oee(self, oee_calculator):
        """Test real-time OEE calculation from PLC data."""
        line_id = uuid4()
        equipment_code = "BP01.PACK.BAG1"
        
        current_metrics = {
            "running_status": True,
            "speed_real": 8.0,
            "internal_fault": False,
            "upstream_fault": False,
            "downstream_fault": False,
            "planned_stop": False
        }
        
        with patch.object(oee_calculator, '_get_production_context') as mock_context:
            mock_context.return_value = {
                "target_speed": 10.0,
                "quality_rate": 95.0
            }
            
            oee_result = await oee_calculator.calculate_real_time_oee(
                line_id, equipment_code, current_metrics
            )
            
            assert oee_result is not None
            assert "oee" in oee_result
            assert "availability" in oee_result
            assert "performance" in oee_result
            assert "quality" in oee_result
            assert oee_result["equipment_code"] == equipment_code
            assert oee_result["line_id"] == line_id
    
    def test_calculate_availability_from_plc(self, oee_calculator):
        """Test availability calculation from PLC data."""
        current_metrics = {
            "running_status": True,
            "internal_fault": False,
            "upstream_fault": False,
            "downstream_fault": False,
            "planned_stop": False
        }
        
        production_context = {"target_speed": 10.0}
        
        availability = asyncio.run(oee_calculator._calculate_availability_from_plc(
            current_metrics, production_context
        ))
        
        assert availability == 1.0  # Running with no faults
    
    def test_calculate_performance_from_plc(self, oee_calculator):
        """Test performance calculation from PLC data."""
        current_metrics = {"speed_real": 8.0}
        production_context = {"target_speed": 10.0}
        
        performance = asyncio.run(oee_calculator._calculate_performance_from_plc(
            current_metrics, production_context
        ))
        
        assert performance == 0.8  # 8.0/10.0


class TestPLCIntegratedDowntimeTracker:
    """Test suite for PLCIntegratedDowntimeTracker."""
    
    @pytest.fixture
    def downtime_tracker(self):
        """Create PLCIntegratedDowntimeTracker instance."""
        return PLCIntegratedDowntimeTracker()
    
    @pytest.mark.asyncio
    async def test_detect_downtime_event_from_plc(self, downtime_tracker):
        """Test downtime event detection from PLC data."""
        line_id = uuid4()
        equipment_code = "BP01.PACK.BAG1"
        
        plc_data = {
            "processed": {
                "running_status": False,
                "speed_real": 0.0,
                "has_active_faults": True,
                "fault_bits": [True] + [False] * 63,  # First fault bit active
                "active_alarms": ["Emergency Stop"]
            }
        }
        
        context_data = {"planned_stop": False}
        
        with patch.object(downtime_tracker, '_store_downtime_event') as mock_store:
            mock_store.return_value = uuid4()
            
            downtime_event = await downtime_tracker.detect_downtime_event_from_plc(
                line_id, equipment_code, plc_data, context_data
            )
            
            assert downtime_event is not None
            assert downtime_event["equipment_code"] == equipment_code
            assert downtime_event["line_id"] == line_id
            assert downtime_event["category"] == "unplanned"
    
    def test_analyze_plc_faults(self, downtime_tracker):
        """Test PLC fault analysis."""
        plc_data = {
            "processed": {
                "fault_bits": [True, False, True] + [False] * 61,
                "active_alarms": ["Emergency Stop", "Safety Gate Open"]
            }
        }
        
        fault_analysis = asyncio.run(downtime_tracker._analyze_plc_downtime_indicators(plc_data))
        
        assert fault_analysis is not None
        assert "is_downtime" in fault_analysis
        assert "fault_analysis" in fault_analysis
        assert "downtime_category" in fault_analysis
    
    def test_determine_downtime_reason(self, downtime_tracker):
        """Test downtime reason determination."""
        fault_analysis = {
            "critical_faults": [{"name": "Emergency Stop", "description": "Emergency stop activated"}],
            "internal_faults": [],
            "upstream_faults": [],
            "downstream_faults": []
        }
        
        reason_code, description = downtime_tracker._determine_downtime_reason(
            fault_analysis, "", False, False
        )
        
        assert reason_code is not None
        assert description is not None
        assert "Emergency stop activated" in description


class TestPLCIntegratedAndonService:
    """Test suite for PLCIntegratedAndonService."""
    
    @pytest.fixture
    def andon_service(self):
        """Create PLCIntegratedAndonService instance."""
        return PLCIntegratedAndonService()
    
    @pytest.mark.asyncio
    async def test_process_plc_faults(self, andon_service):
        """Test PLC fault processing for Andon events."""
        line_id = uuid4()
        equipment_code = "BP01.PACK.BAG1"
        
        fault_data = {
            "fault_bits": [True] + [False] * 63,
            "active_alarms": ["Emergency Stop"],
            "has_active_faults": True
        }
        
        context_data = {"planned_stop": False}
        
        with patch.object(andon_service, '_create_andon_from_plc_faults') as mock_create:
            mock_create.return_value = {
                "id": "mock-andon-id",
                "event_type": "maintenance",
                "priority": "critical"
            }
            
            events = await andon_service.process_plc_faults(
                line_id, equipment_code, fault_data, context_data
            )
            
            assert events is not None
            assert isinstance(events, list)
    
    def test_analyze_plc_faults(self, andon_service):
        """Test PLC fault analysis for Andon events."""
        fault_data = {
            "fault_bits": [True, False, True] + [False] * 61,
            "active_alarms": ["Emergency Stop", "Safety Gate Open"]
        }
        
        fault_analysis = andon_service._analyze_plc_faults(fault_data)
        
        assert fault_analysis is not None
        assert "critical" in fault_analysis
        assert "high_priority" in fault_analysis
        assert "medium_priority" in fault_analysis
        assert "low_priority" in fault_analysis
    
    def test_classify_fault_category_for_andon(self, andon_service):
        """Test fault category classification for Andon events."""
        faults = [
            {"name": "Emergency Stop", "severity": "critical"},
            {"name": "Safety Gate Open", "severity": "high"}
        ]
        
        event_type, priority = andon_service._classify_fault_category_for_andon("critical", faults)
        
        assert event_type == "maintenance"
        assert priority == "critical"


class TestIntegrationScenarios:
    """Integration test scenarios for Phase 2."""
    
    @pytest.mark.asyncio
    async def test_end_to_end_plc_integration(self):
        """Test end-to-end PLC integration scenario."""
        # Create enhanced transformer
        transformer = EnhancedMetricTransformer()
        
        # Create job mapper
        production_service = Mock()
        job_mapper = EquipmentJobMapper(production_service)
        
        # Create OEE calculator
        oee_calculator = PLCIntegratedOEECalculator()
        
        # Simulate PLC data
        raw_data = {
            "processed": {
                "speed_real": 8.0,
                "product_count": 150,
                "current_product": 1,
                "fault_bits": [False] * 64,
                "has_active_faults": False,
                "running_status": True
            }
        }
        
        context_data = {
            "equipment_code": "BP01.PACK.BAG1",
            "current_operator": "test_operator",
            "current_shift": "Day",
            "planned_stop": False,
            "target_speed": 10.0
        }
        
        # Transform metrics
        metrics = transformer.transform_bagger_metrics(raw_data, context_data)
        
        # Verify enhanced metrics are present
        assert "production_efficiency" in metrics
        assert "quality_rate" in metrics
        assert "changeover_status" in metrics
        
        # Test OEE calculation
        line_id = uuid4()
        oee_result = await oee_calculator.calculate_real_time_oee(
            line_id, "BP01.PACK.BAG1", metrics
        )
        
        assert oee_result is not None
        assert "oee" in oee_result
        assert "availability" in oee_result
        assert "performance" in oee_result
        assert "quality" in oee_result
    
    @pytest.mark.asyncio
    async def test_fault_detection_and_andon_integration(self):
        """Test fault detection and Andon integration."""
        # Create downtime tracker
        downtime_tracker = PLCIntegratedDowntimeTracker()
        
        # Create Andon service
        andon_service = PLCIntegratedAndonService()
        
        line_id = uuid4()
        equipment_code = "BP01.PACK.BAG1"
        
        # Simulate fault condition
        plc_data = {
            "processed": {
                "running_status": False,
                "speed_real": 0.0,
                "has_active_faults": True,
                "fault_bits": [True] + [False] * 63,
                "active_alarms": ["Emergency Stop"]
            }
        }
        
        context_data = {"planned_stop": False}
        
        # Detect downtime event
        with patch.object(downtime_tracker, '_store_downtime_event') as mock_store:
            mock_store.return_value = uuid4()
            
            downtime_event = await downtime_tracker.detect_downtime_event_from_plc(
                line_id, equipment_code, plc_data, context_data
            )
            
            assert downtime_event is not None
            assert downtime_event["category"] == "unplanned"
        
        # Process faults for Andon events
        with patch.object(andon_service, '_create_andon_from_plc_faults') as mock_create:
            mock_create.return_value = {
                "id": "mock-andon-id",
                "event_type": "maintenance",
                "priority": "critical"
            }
            
            andon_events = await andon_service.process_plc_faults(
                line_id, equipment_code, plc_data, context_data
            )
            
            assert andon_events is not None
            assert isinstance(andon_events, list)


if __name__ == "__main__":
    # Run the tests
    pytest.main([__file__, "-v"])
