"""
Comprehensive unit tests for OEE Calculator Service
Tests all calculation methods, edge cases, and business logic
"""

import pytest
import asyncio
from unittest.mock import AsyncMock, MagicMock, patch
from datetime import datetime, timedelta
from uuid import uuid4, UUID
import json

from backend.app.services.oee_calculator import (
    OEECalculator, PLCIntegratedOEECalculator
)
from backend.app.utils.exceptions import (
    ValidationError, CalculationError, DataError
)


class TestOEECalculator:
    """Test cases for OEECalculator"""
    
    @pytest.fixture
    def oee_calculator(self):
        """Create OEECalculator instance"""
        return OEECalculator()
    
    @pytest.fixture
    def sample_production_data(self):
        """Sample production data for testing"""
        return {
            'planned_production_time': 480,  # 8 hours in minutes
            'actual_production_time': 420,   # 7 hours in minutes
            'target_output': 1000,
            'actual_output': 850,
            'total_parts': 900,
            'good_parts': 850,
            'ideal_cycle_time': 0.5,  # minutes per part
            'actual_cycle_time': 0.6  # minutes per part
        }
    
    def test_calculate_availability_normal_case(self, oee_calculator, sample_production_data):
        """Test availability calculation with normal data"""
        availability = oee_calculator.calculate_availability(sample_production_data)
        
        # Expected: 420 / 480 = 0.875
        expected = 420 / 480
        assert availability == pytest.approx(expected, rel=1e-6)
        assert 0 <= availability <= 1
    
    def test_calculate_availability_zero_planned_time(self, oee_calculator):
        """Test availability calculation with zero planned time"""
        data = {
            'planned_production_time': 0,
            'actual_production_time': 100
        }
        
        availability = oee_calculator.calculate_availability(data)
        assert availability == 0.0
    
    def test_calculate_availability_exceeds_planned_time(self, oee_calculator):
        """Test availability calculation when actual time exceeds planned time"""
        data = {
            'planned_production_time': 400,
            'actual_production_time': 500
        }
        
        availability = oee_calculator.calculate_availability(data)
        # Should be capped at 1.0
        assert availability == 1.0
    
    def test_calculate_performance_normal_case(self, oee_calculator, sample_production_data):
        """Test performance calculation with normal data"""
        performance = oee_calculator.calculate_performance(sample_production_data)
        
        # Expected: 850 / 1000 = 0.85
        expected = 850 / 1000
        assert performance == pytest.approx(expected, rel=1e-6)
        assert 0 <= performance <= 1
    
    def test_calculate_performance_zero_target_output(self, oee_calculator):
        """Test performance calculation with zero target output"""
        data = {
            'target_output': 0,
            'actual_output': 100
        }
        
        performance = oee_calculator.calculate_performance(data)
        assert performance == 0.0
    
    def test_calculate_performance_exceeds_target(self, oee_calculator):
        """Test performance calculation when actual output exceeds target"""
        data = {
            'target_output': 800,
            'actual_output': 1000
        }
        
        performance = oee_calculator.calculate_performance(data)
        # Should be capped at 1.0
        assert performance == 1.0
    
    def test_calculate_quality_normal_case(self, oee_calculator, sample_production_data):
        """Test quality calculation with normal data"""
        quality = oee_calculator.calculate_quality(sample_production_data)
        
        # Expected: 850 / 900 = 0.9444...
        expected = 850 / 900
        assert quality == pytest.approx(expected, rel=1e-6)
        assert 0 <= quality <= 1
    
    def test_calculate_quality_zero_total_parts(self, oee_calculator):
        """Test quality calculation with zero total parts"""
        data = {
            'total_parts': 0,
            'good_parts': 100
        }
        
        quality = oee_calculator.calculate_quality(data)
        assert quality == 0.0
    
    def test_calculate_quality_all_good_parts(self, oee_calculator):
        """Test quality calculation when all parts are good"""
        data = {
            'total_parts': 1000,
            'good_parts': 1000
        }
        
        quality = oee_calculator.calculate_quality(data)
        assert quality == 1.0
    
    def test_calculate_oee_complete_calculation(self, oee_calculator, sample_production_data):
        """Test complete OEE calculation"""
        oee_result = oee_calculator.calculate_oee(sample_production_data)
        
        # Calculate expected values
        expected_availability = 420 / 480
        expected_performance = 850 / 1000
        expected_quality = 850 / 900
        expected_oee = expected_availability * expected_performance * expected_quality
        
        assert isinstance(oee_result, dict)
        assert 'oee' in oee_result
        assert 'availability' in oee_result
        assert 'performance' in oee_result
        assert 'quality' in oee_result
        assert 'calculated_at' in oee_result
        
        assert oee_result['availability'] == pytest.approx(expected_availability, rel=1e-6)
        assert oee_result['performance'] == pytest.approx(expected_performance, rel=1e-6)
        assert oee_result['quality'] == pytest.approx(expected_quality, rel=1e-6)
        assert oee_result['oee'] == pytest.approx(expected_oee, rel=1e-6)
        
        assert 0 <= oee_result['oee'] <= 1
        assert isinstance(oee_result['calculated_at'], datetime)
    
    def test_calculate_oee_missing_data(self, oee_calculator):
        """Test OEE calculation with missing data"""
        incomplete_data = {
            'planned_production_time': 480,
            'actual_production_time': 420
            # Missing other required fields
        }
        
        with pytest.raises(ValidationError, match="Missing required data for OEE calculation"):
            oee_calculator.calculate_oee(incomplete_data)
    
    def test_calculate_oee_negative_values(self, oee_calculator):
        """Test OEE calculation with negative values"""
        negative_data = {
            'planned_production_time': -100,
            'actual_production_time': 420,
            'target_output': 1000,
            'actual_output': 850,
            'total_parts': 900,
            'good_parts': 850
        }
        
        with pytest.raises(ValidationError, match="Negative values not allowed"):
            oee_calculator.calculate_oee(negative_data)
    
    def test_calculate_oee_perfect_scores(self, oee_calculator):
        """Test OEE calculation with perfect scores"""
        perfect_data = {
            'planned_production_time': 480,
            'actual_production_time': 480,
            'target_output': 1000,
            'actual_output': 1000,
            'total_parts': 1000,
            'good_parts': 1000
        }
        
        oee_result = oee_calculator.calculate_oee(perfect_data)
        
        assert oee_result['availability'] == 1.0
        assert oee_result['performance'] == 1.0
        assert oee_result['quality'] == 1.0
        assert oee_result['oee'] == 1.0
    
    def test_calculate_oee_zero_scores(self, oee_calculator):
        """Test OEE calculation with zero scores"""
        zero_data = {
            'planned_production_time': 480,
            'actual_production_time': 0,
            'target_output': 1000,
            'actual_output': 0,
            'total_parts': 100,
            'good_parts': 0
        }
        
        oee_result = oee_calculator.calculate_oee(zero_data)
        
        assert oee_result['availability'] == 0.0
        assert oee_result['performance'] == 0.0
        assert oee_result['quality'] == 0.0
        assert oee_result['oee'] == 0.0
    
    @pytest.mark.asyncio
    async def test_calculate_equipment_oee_with_analytics(self, oee_calculator):
        """Test equipment OEE calculation with analytics"""
        equipment_code = "TEST_EQ_001"
        time_period = timedelta(hours=8)
        
        # Mock the database query for historical data
        with patch.object(oee_calculator, 'get_oee_historical_data') as mock_historical:
            mock_historical.return_value = [
                {
                    'timestamp': datetime.now() - timedelta(hours=7),
                    'availability': 0.92,
                    'performance': 0.88,
                    'quality': 0.95,
                    'oee': 0.77
                },
                {
                    'timestamp': datetime.now() - timedelta(hours=6),
                    'availability': 0.94,
                    'performance': 0.90,
                    'quality': 0.96,
                    'oee': 0.81
                },
                {
                    'timestamp': datetime.now() - timedelta(hours=5),
                    'availability': 0.91,
                    'performance': 0.89,
                    'quality': 0.94,
                    'oee': 0.76
                }
            ]
            
            result = await oee_calculator.calculate_equipment_oee_with_analytics(
                equipment_code, time_period
            )
            
            assert isinstance(result, dict)
            assert 'current_oee' in result
            assert 'trend_analysis' in result
            assert 'benchmark_comparison' in result
            assert 'recommendations' in result
            assert 'historical_data' in result
            
            # Verify trend analysis
            trend = result['trend_analysis']
            assert 'direction' in trend
            assert 'percentage_change' in trend
            assert 'consistency' in trend
            
            # Verify benchmark comparison
            benchmark = result['benchmark_comparison']
            assert 'industry_benchmark' in benchmark
            assert 'performance_level' in benchmark
            assert 'gap_analysis' in benchmark
            
            # Verify recommendations
            recommendations = result['recommendations']
            assert isinstance(recommendations, list)
            assert len(recommendations) > 0
    
    @pytest.mark.asyncio
    async def test_get_oee_dashboard_data(self, oee_calculator):
        """Test OEE dashboard data aggregation"""
        line_id = uuid4()
        
        # Mock database queries
        with patch.object(oee_calculator, 'get_line_equipment') as mock_equipment, \
             patch.object(oee_calculator, 'get_current_oee_data') as mock_current, \
             patch.object(oee_calculator, 'get_oee_trends') as mock_trends:
            
            mock_equipment.return_value = [
                {'equipment_code': 'EQ001', 'name': 'Equipment 1'},
                {'equipment_code': 'EQ002', 'name': 'Equipment 2'}
            ]
            
            mock_current.return_value = {
                'EQ001': {'oee': 0.85, 'availability': 0.92, 'performance': 0.95, 'quality': 0.97},
                'EQ002': {'oee': 0.78, 'availability': 0.89, 'performance': 0.88, 'quality': 0.99}
            }
            
            mock_trends.return_value = [
                {'timestamp': datetime.now() - timedelta(hours=i), 'oee': 0.8 + (i * 0.01)}
                for i in range(24)
            ]
            
            result = await oee_calculator.get_oee_dashboard_data(line_id)
            
            assert isinstance(result, dict)
            assert 'line_id' in result
            assert 'equipment_oee' in result
            assert 'line_average_oee' in result
            assert 'trends' in result
            assert 'performance_summary' in result
            
            # Verify equipment OEE data
            equipment_oee = result['equipment_oee']
            assert len(equipment_oee) == 2
            assert 'EQ001' in equipment_oee
            assert 'EQ002' in equipment_oee
            
            # Verify line average calculation
            expected_average = (0.85 + 0.78) / 2
            assert result['line_average_oee'] == pytest.approx(expected_average, rel=1e-6)
            
            # Verify trends data
            trends = result['trends']
            assert isinstance(trends, list)
            assert len(trends) == 24


class TestPLCIntegratedOEECalculator:
    """Test cases for PLCIntegratedOEECalculator"""
    
    @pytest.fixture
    def plc_oee_calculator(self):
        """Create PLCIntegratedOEECalculator instance"""
        return PLCIntegratedOEECalculator()
    
    @pytest.fixture
    def sample_plc_metrics(self):
        """Sample PLC metrics for testing"""
        return {
            'running_status': True,
            'speed': 95.0,  # RPM
            'target_speed': 100.0,
            'product_count': 850,
            'fault_bits': [False] * 64,
            'cycle_time': 0.6,
            'ideal_cycle_time': 0.5,
            'temperature': 65.5,
            'pressure': 2.5
        }
    
    @pytest.fixture
    def sample_production_context(self):
        """Sample production context for testing"""
        return {
            'line_id': str(uuid4()),
            'equipment_code': 'BP01.PACK.BAG1',
            'current_job_id': str(uuid4()),
            'target_quantity': 1000,
            'planned_production_time': 480,  # minutes
            'current_operator': 'operator_001',
            'current_shift': 'A'
        }
    
    def test_calculate_real_time_oee_success(self, plc_oee_calculator, sample_plc_metrics, sample_production_context):
        """Test real-time OEE calculation with PLC data"""
        result = plc_oee_calculator.calculate_real_time_oee(
            line_id=sample_production_context['line_id'],
            equipment_code=sample_production_context['equipment_code'],
            current_metrics=sample_plc_metrics,
            production_context=sample_production_context
        )
        
        assert isinstance(result, dict)
        assert 'oee' in result
        assert 'availability' in result
        assert 'performance' in result
        assert 'quality' in result
        assert 'timestamp' in result
        assert 'equipment_code' in result
        assert 'line_id' in result
        
        # Verify values are within valid range
        assert 0 <= result['oee'] <= 1
        assert 0 <= result['availability'] <= 1
        assert 0 <= result['performance'] <= 1
        assert 0 <= result['quality'] <= 1
        
        assert result['equipment_code'] == sample_production_context['equipment_code']
        assert result['line_id'] == sample_production_context['line_id']
    
    def test_calculate_availability_from_plc_running(self, plc_oee_calculator, sample_plc_metrics):
        """Test availability calculation when PLC shows running"""
        availability = plc_oee_calculator._calculate_availability_from_plc(sample_plc_metrics)
        
        # When running, availability should be calculated based on speed vs target
        expected = sample_plc_metrics['speed'] / sample_plc_metrics['target_speed']
        assert availability == pytest.approx(expected, rel=1e-6)
    
    def test_calculate_availability_from_plc_stopped(self, plc_oee_calculator, sample_plc_metrics):
        """Test availability calculation when PLC shows stopped"""
        stopped_metrics = sample_plc_metrics.copy()
        stopped_metrics['running_status'] = False
        stopped_metrics['speed'] = 0.0
        
        availability = plc_oee_calculator._calculate_availability_from_plc(stopped_metrics)
        assert availability == 0.0
    
    def test_calculate_performance_from_plc_normal(self, plc_oee_calculator, sample_plc_metrics, sample_production_context):
        """Test performance calculation from PLC data"""
        performance = plc_oee_calculator._calculate_performance_from_plc(
            sample_plc_metrics, sample_production_context
        )
        
        # Performance should be based on actual vs ideal cycle time
        expected = sample_plc_metrics['ideal_cycle_time'] / sample_plc_metrics['cycle_time']
        assert performance == pytest.approx(expected, rel=1e-6)
    
    def test_calculate_quality_from_production_normal(self, plc_oee_calculator, sample_plc_metrics, sample_production_context):
        """Test quality calculation from production data"""
        quality = plc_oee_calculator._calculate_quality_from_production(
            sample_plc_metrics, sample_production_context
        )
        
        # Quality should be based on product count vs target
        expected = sample_plc_metrics['product_count'] / sample_production_context['target_quantity']
        # Cap at 1.0
        expected = min(1.0, expected)
        assert quality == pytest.approx(expected, rel=1e-6)
    
    @pytest.mark.asyncio
    async def test_calculate_plc_based_oee_with_historical_data(self, plc_oee_calculator):
        """Test PLC-based OEE calculation with historical data"""
        line_id = str(uuid4())
        equipment_code = 'BP01.PACK.BAG1'
        time_period = timedelta(hours=8)
        
        # Mock historical PLC data
        with patch.object(plc_oee_calculator, 'get_plc_historical_data') as mock_historical:
            mock_historical.return_value = [
                {
                    'timestamp': datetime.now() - timedelta(hours=7),
                    'running_status': True,
                    'speed': 95.0,
                    'target_speed': 100.0,
                    'product_count': 100,
                    'cycle_time': 0.6,
                    'ideal_cycle_time': 0.5
                },
                {
                    'timestamp': datetime.now() - timedelta(hours=6),
                    'running_status': True,
                    'speed': 98.0,
                    'target_speed': 100.0,
                    'product_count': 105,
                    'cycle_time': 0.58,
                    'ideal_cycle_time': 0.5
                }
            ]
            
            result = await plc_oee_calculator.calculate_plc_based_oee(
                line_id, equipment_code, time_period
            )
            
            assert isinstance(result, dict)
            assert 'oee' in result
            assert 'availability' in result
            assert 'performance' in result
            assert 'quality' in result
            assert 'period' in result
            assert 'data_points' in result
            
            assert 0 <= result['oee'] <= 1
            assert result['data_points'] == 2
    
    @pytest.mark.asyncio
    async def test_get_oee_trends_from_plc(self, plc_oee_calculator):
        """Test OEE trends analysis from PLC data"""
        line_id = str(uuid4())
        equipment_code = 'BP01.PACK.BAG1'
        days = 7
        
        # Mock trends data
        with patch.object(plc_oee_calculator, 'get_plc_trends_data') as mock_trends:
            mock_trends.return_value = [
                {
                    'date': datetime.now().date() - timedelta(days=i),
                    'average_oee': 0.8 + (i * 0.01),
                    'availability': 0.9,
                    'performance': 0.85,
                    'quality': 0.95
                }
                for i in range(days)
            ]
            
            result = await plc_oee_calculator.get_oee_trends_from_plc(
                line_id, equipment_code, days
            )
            
            assert isinstance(result, dict)
            assert 'trends' in result
            assert 'summary' in result
            assert 'recommendations' in result
            
            trends = result['trends']
            assert isinstance(trends, list)
            assert len(trends) == days
            
            summary = result['summary']
            assert 'average_oee' in summary
            assert 'trend_direction' in summary
            assert 'volatility' in summary
    
    def test_calculate_oee_with_faults(self, plc_oee_calculator, sample_plc_metrics, sample_production_context):
        """Test OEE calculation when equipment has active faults"""
        fault_metrics = sample_plc_metrics.copy()
        fault_metrics['fault_bits'] = [True] + [False] * 63  # One active fault
        
        result = plc_oee_calculator.calculate_real_time_oee(
            line_id=sample_production_context['line_id'],
            equipment_code=sample_production_context['equipment_code'],
            current_metrics=fault_metrics,
            production_context=sample_production_context
        )
        
        # OEE should be significantly impacted by faults
        assert result['availability'] < 1.0
        assert result['oee'] < 1.0
        
        # Verify fault information is included
        assert 'active_faults' in result
        assert len(result['active_faults']) > 0
    
    def test_calculate_oee_missing_plc_data(self, plc_oee_calculator, sample_production_context):
        """Test OEE calculation with missing PLC data"""
        incomplete_metrics = {
            'running_status': True
            # Missing speed, product_count, etc.
        }
        
        with pytest.raises(ValidationError, match="Insufficient PLC data for OEE calculation"):
            plc_oee_calculator.calculate_real_time_oee(
                line_id=sample_production_context['line_id'],
                equipment_code=sample_production_context['equipment_code'],
                current_metrics=incomplete_metrics,
                production_context=sample_production_context
            )
    
    def test_calculate_oee_invalid_production_context(self, plc_oee_calculator, sample_plc_metrics):
        """Test OEE calculation with invalid production context"""
        invalid_context = {
            'line_id': str(uuid4()),
            'equipment_code': 'BP01.PACK.BAG1'
            # Missing required fields
        }
        
        with pytest.raises(ValidationError, match="Invalid production context"):
            plc_oee_calculator.calculate_real_time_oee(
                line_id=invalid_context['line_id'],
                equipment_code=invalid_context['equipment_code'],
                current_metrics=sample_plc_metrics,
                production_context=invalid_context
            )


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
