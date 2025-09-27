"""
Unit tests for OEE Calculator Service
Tests all OEE calculation methods and functionality
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

from app.services.oee_calculator import OEECalculator


class TestOEECalculator:
    """Test cases for OEECalculator"""
    
    @pytest.fixture
    def mock_db(self):
        """Mock database connection"""
        mock_db = AsyncMock()
        return mock_db
    
    @pytest.fixture
    def oee_calculator(self, mock_db):
        """Create OEECalculator instance with mocked database"""
        with patch('app.services.oee_calculator.get_database', return_value=mock_db):
            calculator = OEECalculator()
            return calculator
    
    @pytest.mark.asyncio
    async def test_calculate_real_time_oee(self, oee_calculator, mock_db):
        """Test real-time OEE calculation"""
        line_id = str(uuid.uuid4())
        equipment_code = "EQ-001"
        current_metrics = {
            'running': True,
            'speed': 95.0,
            'target_speed': 100.0,
            'good_parts': 950,
            'total_parts': 1000,
            'cycle_time': 0.8,
            'ideal_cycle_time': 1.0
        }
        
        # Mock equipment config
        mock_db.fetch_one.return_value = {
            'equipment_code': equipment_code,
            'ideal_cycle_time': 1.0,
            'target_speed': 100.0,
            'oee_targets': {'availability': 0.9, 'performance': 0.9, 'quality': 0.95}
        }
        
        result = await oee_calculator.calculate_real_time_oee(line_id, equipment_code, current_metrics)
        
        assert result is not None
        assert 'oee' in result
        assert 'availability' in result
        assert 'performance' in result
        assert 'quality' in result
        assert result['equipment_code'] == equipment_code
        assert result['line_id'] == line_id
        assert isinstance(result['oee'], float)
        assert 0 <= result['oee'] <= 1
    
    @pytest.mark.asyncio
    async def test_get_equipment_config(self, oee_calculator, mock_db):
        """Test getting equipment configuration"""
        equipment_code = "EQ-001"
        
        mock_db.fetch_one.return_value = {
            'equipment_code': equipment_code,
            'ideal_cycle_time': 1.0,
            'target_speed': 100.0,
            'oee_targets': {'availability': 0.9, 'performance': 0.9, 'quality': 0.95}
        }
        
        result = await oee_calculator._get_equipment_config(equipment_code)
        
        assert result is not None
        assert result['equipment_code'] == equipment_code
        assert result['ideal_cycle_time'] == 1.0
        assert result['target_speed'] == 100.0
        mock_db.fetch_one.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_calculate_availability_real_time(self, oee_calculator, mock_db):
        """Test real-time availability calculation"""
        equipment_code = "EQ-001"
        metrics = {
            'running': True,
            'speed': 95.0,
            'target_speed': 100.0
        }
        config = {
            'target_speed': 100.0,
            'ideal_cycle_time': 1.0
        }
        
        result = await oee_calculator._calculate_availability_real_time(equipment_code, metrics, config)
        
        assert isinstance(result, float)
        assert 0 <= result <= 1
    
    @pytest.mark.asyncio
    async def test_calculate_performance_real_time(self, oee_calculator, mock_db):
        """Test real-time performance calculation"""
        equipment_code = "EQ-001"
        metrics = {
            'cycle_time': 0.8,
            'ideal_cycle_time': 1.0,
            'speed': 95.0,
            'target_speed': 100.0
        }
        config = {
            'ideal_cycle_time': 1.0,
            'target_speed': 100.0
        }
        
        result = await oee_calculator._calculate_performance_real_time(equipment_code, metrics, config)
        
        assert isinstance(result, float)
        assert 0 <= result <= 1
    
    @pytest.mark.asyncio
    async def test_calculate_quality_real_time(self, oee_calculator, mock_db):
        """Test real-time quality calculation"""
        equipment_code = "EQ-001"
        metrics = {
            'good_parts': 950,
            'total_parts': 1000
        }
        config = {}
        
        result = await oee_calculator._calculate_quality_real_time(equipment_code, metrics, config)
        
        assert isinstance(result, float)
        assert 0 <= result <= 1
        assert result == 0.95  # 950/1000
    
    @pytest.mark.asyncio
    async def test_get_downtime_data(self, oee_calculator, mock_db):
        """Test getting downtime data"""
        equipment_code = "EQ-001"
        time_period = timedelta(hours=24)
        
        mock_db.fetch_all.return_value = [
            {
                'id': str(uuid.uuid4()),
                'equipment_code': equipment_code,
                'start_time': datetime.now() - timedelta(hours=2),
                'end_time': datetime.now() - timedelta(hours=1),
                'duration_minutes': 60,
                'category': 'planned'
            }
        ]
        
        result = await oee_calculator.get_downtime_data(equipment_code, time_period)
        
        assert result is not None
        assert 'total_downtime_minutes' in result
        assert 'planned_downtime_minutes' in result
        assert 'unplanned_downtime_minutes' in result
        assert result['total_downtime_minutes'] == 60
        mock_db.fetch_all.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_get_production_data(self, oee_calculator, mock_db):
        """Test getting production data"""
        equipment_code = "EQ-001"
        time_period = timedelta(hours=24)
        
        mock_db.fetch_all.return_value = [
            {
                'id': str(uuid.uuid4()),
                'equipment_code': equipment_code,
                'good_parts': 950,
                'total_parts': 1000,
                'production_time_minutes': 480,
                'timestamp': datetime.now()
            }
        ]
        
        result = await oee_calculator.get_production_data(equipment_code, time_period)
        
        assert result is not None
        assert 'total_parts' in result
        assert 'good_parts' in result
        assert 'production_time_minutes' in result
        assert result['total_parts'] == 1000
        assert result['good_parts'] == 950
        mock_db.fetch_all.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_store_oee_calculation(self, oee_calculator, mock_db):
        """Test storing OEE calculation"""
        oee_data = {
            'equipment_code': 'EQ-001',
            'line_id': str(uuid.uuid4()),
            'oee': 0.85,
            'availability': 0.9,
            'performance': 0.95,
            'quality': 0.95,
            'timestamp': datetime.now()
        }
        
        mock_db.execute.return_value = True
        
        result = await oee_calculator.store_oee_calculation(oee_data)
        
        assert result is True
        mock_db.execute.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_calculate_historical_oee(self, oee_calculator, mock_db):
        """Test historical OEE calculation"""
        equipment_code = "EQ-001"
        start_time = datetime.now() - timedelta(days=1)
        end_time = datetime.now()
        
        # Mock downtime data
        mock_db.fetch_all.side_effect = [
            [{'duration_minutes': 60, 'category': 'planned'}],  # downtime data
            [{'total_parts': 1000, 'good_parts': 950, 'production_time_minutes': 480}]  # production data
        ]
        
        result = await oee_calculator.calculate_historical_oee(equipment_code, start_time, end_time)
        
        assert result is not None
        assert 'oee' in result
        assert 'availability' in result
        assert 'performance' in result
        assert 'quality' in result
        assert isinstance(result['oee'], float)
        assert 0 <= result['oee'] <= 1
    
    @pytest.mark.asyncio
    async def test_get_oee_trends(self, oee_calculator, mock_db):
        """Test getting OEE trends"""
        equipment_code = "EQ-001"
        days = 7
        
        mock_db.fetch_all.return_value = [
            {
                'date': datetime.now().date(),
                'oee': 0.85,
                'availability': 0.9,
                'performance': 0.95,
                'quality': 0.95
            }
        ]
        
        result = await oee_calculator.get_oee_trends(equipment_code, days)
        
        assert result is not None
        assert len(result) == 1
        assert 'oee' in result[0]
        assert 'availability' in result[0]
        assert 'performance' in result[0]
        assert 'quality' in result[0]
        mock_db.fetch_all.assert_called_once()


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
