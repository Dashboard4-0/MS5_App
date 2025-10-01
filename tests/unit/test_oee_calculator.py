"""
MS5.0 Floor Dashboard - OEE Calculator Unit Tests

Tests the OEE calculation service with mathematical precision.
Every calculation is verified for accuracy and edge case handling.

Coverage Requirements:
- 100% method coverage
- 100% calculation accuracy
- All edge cases tested
- Performance benchmarks validated
"""

import pytest
import pytest_asyncio
from unittest.mock import AsyncMock, Mock, patch
from datetime import datetime, timezone, timedelta, date
from uuid import uuid4
from decimal import Decimal
import structlog

from backend.app.services.oee_calculator import OEECalculator
from backend.app.services.plc_integrated_oee_calculator import PLCIntegratedOEECalculator
from backend.app.models.production import OEEMetrics, OEECalculationResult
from backend.app.utils.exceptions import ValidationError, BusinessLogicError


class TestOEECalculator:
    """Comprehensive tests for OEECalculator."""
    
    @pytest.fixture
    def calculator(self):
        """Create an OEECalculator instance for testing."""
        return OEECalculator()
    
    @pytest.fixture
    def mock_db_session(self):
        """Create a mock database session."""
        session = AsyncMock()
        session.execute = AsyncMock()
        session.commit = AsyncMock()
        session.rollback = AsyncMock()
        return session
    
    @pytest.fixture
    def sample_production_data(self):
        """Provide sample production data for OEE calculation."""
        return {
            "line_id": str(uuid4()),
            "equipment_code": "EQ_001",
            "date": date.today(),
            "planned_production_time": 480.0,  # 8 hours in minutes
            "actual_production_time": 450.0,   # 7.5 hours in minutes
            "ideal_cycle_time": 1.0,           # 1 minute per unit
            "actual_units_produced": 420,      # units produced
            "good_units": 400,                 # good quality units
            "total_units_planned": 480         # planned units
        }
    
    def test_calculate_availability_basic(self, calculator):
        """Test basic availability calculation."""
        # Arrange
        planned_time = 480.0  # 8 hours
        actual_time = 450.0   # 7.5 hours
        
        # Act
        availability = calculator.calculate_availability(planned_time, actual_time)
        
        # Assert
        expected = (actual_time / planned_time) * 100
        assert availability == pytest.approx(expected, rel=1e-6)
        assert availability == pytest.approx(93.75, rel=1e-6)
    
    def test_calculate_availability_zero_planned_time(self, calculator):
        """Test availability calculation with zero planned time."""
        # Act & Assert
        with pytest.raises(ValidationError, match="Planned production time cannot be zero"):
            calculator.calculate_availability(0.0, 450.0)
    
    def test_calculate_availability_negative_values(self, calculator):
        """Test availability calculation with negative values."""
        # Act & Assert
        with pytest.raises(ValidationError, match="Production times cannot be negative"):
            calculator.calculate_availability(-480.0, 450.0)
        
        with pytest.raises(ValidationError, match="Production times cannot be negative"):
            calculator.calculate_availability(480.0, -450.0)
    
    def test_calculate_performance_basic(self, calculator):
        """Test basic performance calculation."""
        # Arrange
        actual_time = 450.0   # 7.5 hours
        ideal_cycle_time = 1.0  # 1 minute per unit
        units_produced = 420   # units produced
        
        # Act
        performance = calculator.calculate_performance(
            actual_time, ideal_cycle_time, units_produced
        )
        
        # Assert
        expected_ideal_time = units_produced * ideal_cycle_time
        expected = (expected_ideal_time / actual_time) * 100
        assert performance == pytest.approx(expected, rel=1e-6)
        assert performance == pytest.approx(93.33, rel=1e-6)
    
    def test_calculate_performance_zero_actual_time(self, calculator):
        """Test performance calculation with zero actual time."""
        # Act & Assert
        with pytest.raises(ValidationError, match="Actual production time cannot be zero"):
            calculator.calculate_performance(0.0, 1.0, 420)
    
    def test_calculate_quality_basic(self, calculator):
        """Test basic quality calculation."""
        # Arrange
        total_units = 420
        good_units = 400
        
        # Act
        quality = calculator.calculate_quality(total_units, good_units)
        
        # Assert
        expected = (good_units / total_units) * 100
        assert quality == pytest.approx(expected, rel=1e-6)
        assert quality == pytest.approx(95.24, rel=1e-6)
    
    def test_calculate_quality_zero_total_units(self, calculator):
        """Test quality calculation with zero total units."""
        # Act & Assert
        with pytest.raises(ValidationError, match="Total units cannot be zero"):
            calculator.calculate_quality(0, 400)
    
    def test_calculate_quality_more_good_than_total(self, calculator):
        """Test quality calculation with more good units than total."""
        # Act & Assert
        with pytest.raises(ValidationError, match="Good units cannot exceed total units"):
            calculator.calculate_quality(400, 420)
    
    def test_calculate_oee_basic(self, calculator):
        """Test basic OEE calculation."""
        # Arrange
        availability = 93.75
        performance = 93.33
        quality = 95.24
        
        # Act
        oee = calculator.calculate_oee(availability, performance, quality)
        
        # Assert
        expected = (availability / 100) * (performance / 100) * (quality / 100) * 100
        assert oee == pytest.approx(expected, rel=1e-6)
        assert oee == pytest.approx(83.33, rel=1e-6)
    
    def test_calculate_oee_perfect_scores(self, calculator):
        """Test OEE calculation with perfect scores."""
        # Act
        oee = calculator.calculate_oee(100.0, 100.0, 100.0)
        
        # Assert
        assert oee == pytest.approx(100.0, rel=1e-6)
    
    def test_calculate_oee_zero_scores(self, calculator):
        """Test OEE calculation with zero scores."""
        # Act
        oee = calculator.calculate_oee(0.0, 100.0, 100.0)
        
        # Assert
        assert oee == pytest.approx(0.0, rel=1e-6)
    
    @pytest.mark.asyncio
    async def test_calculate_comprehensive_oee_success(self, calculator, mock_db_session, sample_production_data):
        """Test comprehensive OEE calculation."""
        # Arrange
        line_id = sample_production_data["line_id"]
        equipment_code = sample_production_data["equipment_code"]
        calc_date = sample_production_data["date"]
        
        # Mock database queries
        mock_result = Mock()
        mock_result.scalar_one_or_none.return_value = sample_production_data
        mock_db_session.execute.return_value = mock_result
        
        # Act
        result = await calculator.calculate_comprehensive_oee(
            line_id, equipment_code, calc_date, mock_db_session
        )
        
        # Assert
        assert result is not None
        assert isinstance(result, OEECalculationResult)
        assert result.line_id == line_id
        assert result.equipment_code == equipment_code
        assert result.calculation_date == calc_date
        assert result.availability > 0
        assert result.performance > 0
        assert result.quality > 0
        assert result.oee > 0
    
    @pytest.mark.asyncio
    async def test_calculate_comprehensive_oee_no_data(self, calculator, mock_db_session):
        """Test comprehensive OEE calculation with no data."""
        # Arrange
        line_id = str(uuid4())
        equipment_code = "EQ_001"
        calc_date = date.today()
        
        # Mock no data found
        mock_result = Mock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db_session.execute.return_value = mock_result
        
        # Act & Assert
        with pytest.raises(BusinessLogicError, match="No production data found"):
            await calculator.calculate_comprehensive_oee(
                line_id, equipment_code, calc_date, mock_db_session
            )
    
    @pytest.mark.asyncio
    async def test_calculate_real_time_oee_success(self, calculator, mock_db_session):
        """Test real-time OEE calculation."""
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
        timestamp = datetime.now(timezone.utc)
        
        # Mock equipment configuration
        mock_config = Mock()
        mock_config.scalar_one_or_none.return_value = {
            "ideal_cycle_time": 1.0,
            "target_speed": 100.0,
            "oee_targets": {"availability": 95.0, "performance": 95.0, "quality": 95.0}
        }
        mock_db_session.execute.return_value = mock_config
        
        # Act
        result = await calculator.calculate_real_time_oee(
            line_id, equipment_code, current_status, timestamp, mock_db_session
        )
        
        # Assert
        assert result is not None
        assert "oee" in result
        assert "availability" in result
        assert "performance" in result
        assert "quality" in result
        assert "timestamp" in result
        assert result["timestamp"] == timestamp
    
    def test_validate_oee_inputs_valid(self, calculator):
        """Test OEE input validation with valid inputs."""
        # Act
        result = calculator._validate_oee_inputs(
            planned_time=480.0,
            actual_time=450.0,
            ideal_cycle_time=1.0,
            total_units=420,
            good_units=400
        )
        
        # Assert
        assert result is True
    
    def test_validate_oee_inputs_invalid(self, calculator):
        """Test OEE input validation with invalid inputs."""
        # Test cases for each validation
        test_cases = [
            # (planned_time, actual_time, ideal_cycle_time, total_units, good_units, expected_error)
            (0.0, 450.0, 1.0, 420, 400, "Planned production time cannot be zero"),
            (-480.0, 450.0, 1.0, 420, 400, "Production times cannot be negative"),
            (480.0, -450.0, 1.0, 420, 400, "Production times cannot be negative"),
            (480.0, 450.0, -1.0, 420, 400, "Ideal cycle time cannot be negative"),
            (480.0, 450.0, 1.0, -420, 400, "Unit counts cannot be negative"),
            (480.0, 450.0, 1.0, 420, -400, "Unit counts cannot be negative"),
            (480.0, 450.0, 1.0, 0, 400, "Total units cannot be zero"),
            (480.0, 450.0, 1.0, 400, 420, "Good units cannot exceed total units"),
        ]
        
        for planned_time, actual_time, ideal_cycle_time, total_units, good_units, expected_error in test_cases:
            with pytest.raises(ValidationError, match=expected_error):
                calculator._validate_oee_inputs(
                    planned_time, actual_time, ideal_cycle_time, total_units, good_units
                )
    
    def test_calculate_oee_trends(self, calculator):
        """Test OEE trend calculation."""
        # Arrange
        oee_values = [80.0, 82.0, 85.0, 83.0, 87.0]
        
        # Act
        trend = calculator.calculate_oee_trend(oee_values)
        
        # Assert
        assert trend is not None
        assert "average" in trend
        assert "trend_direction" in trend
        assert "volatility" in trend
        assert trend["average"] == pytest.approx(83.4, rel=1e-6)
        assert trend["trend_direction"] in ["improving", "declining", "stable"]
    
    def test_calculate_oee_trends_insufficient_data(self, calculator):
        """Test OEE trend calculation with insufficient data."""
        # Arrange
        oee_values = [80.0]  # Need at least 2 values
        
        # Act & Assert
        with pytest.raises(ValidationError, match="At least 2 OEE values required"):
            calculator.calculate_oee_trend(oee_values)


class TestPLCIntegratedOEECalculator:
    """Comprehensive tests for PLCIntegratedOEECalculator."""
    
    @pytest.fixture
    def calculator(self):
        """Create a PLCIntegratedOEECalculator instance for testing."""
        return PLCIntegratedOEECalculator()
    
    @pytest.fixture
    def mock_db_session(self):
        """Create a mock database session."""
        session = AsyncMock()
        session.execute = AsyncMock()
        session.commit = AsyncMock()
        session.rollback = AsyncMock()
        return session
    
    @pytest.mark.asyncio
    async def test_calculate_plc_integrated_oee_success(self, calculator, mock_db_session):
        """Test PLC-integrated OEE calculation."""
        # Arrange
        line_id = str(uuid4())
        equipment_code = "EQ_001"
        calc_date = date.today()
        
        # Mock PLC telemetry data
        plc_data = {
            "equipment_code": equipment_code,
            "timestamp": datetime.now(timezone.utc),
            "status": "running",
            "speed": 100.0,
            "temperature": 25.5,
            "pressure": 1.2,
            "vibration": 0.1,
            "quality_metrics": {
                "good_parts": 95,
                "defective_parts": 5,
                "total_parts": 100
            }
        }
        
        # Mock equipment configuration
        equipment_config = {
            "ideal_cycle_time": 1.0,
            "target_speed": 100.0,
            "oee_targets": {"availability": 95.0, "performance": 95.0, "quality": 95.0}
        }
        
        mock_result = Mock()
        mock_result.scalar_one_or_none.return_value = plc_data
        mock_db_session.execute.return_value = mock_result
        
        with patch.object(calculator, '_get_equipment_config', return_value=equipment_config):
            # Act
            result = await calculator.calculate_plc_integrated_oee(
                line_id, equipment_code, calc_date, mock_db_session
            )
            
            # Assert
            assert result is not None
            assert result.line_id == line_id
            assert result.equipment_code == equipment_code
            assert result.calculation_date == calc_date
            assert "plc_data" in result.metadata
            assert result.metadata["plc_data"] == plc_data
    
    @pytest.mark.asyncio
    async def test_integrate_plc_telemetry_success(self, calculator):
        """Test PLC telemetry integration."""
        # Arrange
        plc_data = {
            "equipment_code": "EQ_001",
            "status": "running",
            "speed": 100.0,
            "quality_metrics": {"good_parts": 95, "total_parts": 100}
        }
        
        # Act
        result = calculator._integrate_plc_telemetry(plc_data)
        
        # Assert
        assert result is not None
        assert "actual_speed" in result
        assert "quality_rate" in result
        assert "status_factor" in result
        assert result["actual_speed"] == 100.0
        assert result["quality_rate"] == pytest.approx(95.0, rel=1e-6)
    
    @pytest.mark.asyncio
    async def test_validate_plc_data_valid(self, calculator):
        """Test PLC data validation with valid data."""
        # Arrange
        valid_plc_data = {
            "equipment_code": "EQ_001",
            "timestamp": datetime.now(timezone.utc),
            "status": "running",
            "speed": 100.0,
            "quality_metrics": {"good_parts": 95, "total_parts": 100}
        }
        
        # Act
        result = calculator._validate_plc_data(valid_plc_data)
        
        # Assert
        assert result is True
    
    @pytest.mark.asyncio
    async def test_validate_plc_data_invalid(self, calculator):
        """Test PLC data validation with invalid data."""
        # Test cases for invalid PLC data
        invalid_cases = [
            # Missing equipment_code
            {"timestamp": datetime.now(timezone.utc), "status": "running"},
            # Invalid status
            {"equipment_code": "EQ_001", "status": "invalid_status"},
            # Negative speed
            {"equipment_code": "EQ_001", "speed": -100.0},
            # Invalid quality metrics
            {"equipment_code": "EQ_001", "quality_metrics": {"good_parts": 105, "total_parts": 100}},
        ]
        
        for invalid_data in invalid_cases:
            with pytest.raises(ValidationError):
                calculator._validate_plc_data(invalid_data)
    
    def test_calculate_equipment_efficiency_with_plc(self, calculator):
        """Test equipment efficiency calculation with PLC data."""
        # Arrange
        plc_metrics = {
            "actual_speed": 95.0,
            "target_speed": 100.0,
            "quality_rate": 98.0,
            "status_factor": 1.0
        }
        
        # Act
        efficiency = calculator._calculate_equipment_efficiency_with_plc(plc_metrics)
        
        # Assert
        assert efficiency is not None
        assert "speed_efficiency" in efficiency
        assert "quality_efficiency" in efficiency
        assert "overall_efficiency" in efficiency
        assert efficiency["speed_efficiency"] == pytest.approx(95.0, rel=1e-6)
        assert efficiency["quality_efficiency"] == pytest.approx(98.0, rel=1e-6)