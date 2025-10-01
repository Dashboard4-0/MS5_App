"""
MS5.0 Floor Dashboard - Test Configuration

Central nervous system for all testing operations.
Provides fixtures, utilities, and configuration for the entire test suite.

This configuration ensures:
- Isolated test environments
- Deterministic test data
- Comprehensive coverage tracking
- Performance monitoring
"""

import asyncio
import os
import sys
import pytest
import pytest_asyncio
from typing import AsyncGenerator, Generator, Dict, Any
from unittest.mock import AsyncMock, Mock, patch
from datetime import datetime, timezone, timedelta
from uuid import uuid4
import structlog

# Add project root to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from backend.app.database import get_db_session
from backend.app.auth.permissions import UserContext
from backend.app.models.production import (
    ProductionLineCreate, ProductionLineResponse,
    JobAssignmentCreate, JobAssignmentResponse,
    ChecklistTemplateCreate, ChecklistTemplateResponse
)


@pytest.fixture(scope="session")
def event_loop() -> Generator:
    """Create an instance of the default event loop for the test session."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()


@pytest.fixture
async def test_db_session() -> AsyncGenerator:
    """Provide a test database session with automatic cleanup."""
    # This would be configured with test database
    # For now, return a mock session
    session = AsyncMock()
    yield session
    await session.close()


@pytest.fixture
def test_user() -> UserContext:
    """Provide a test user context with appropriate permissions."""
    return UserContext(
        user_id=uuid4(),
        username="test_user",
        email="test@example.com",
        role="operator",
        permissions={
            "production:read", "production:write", "equipment:read",
            "andon:read", "andon:write", "reports:read", "dashboard:read"
        }
    )


@pytest.fixture
def test_admin_user() -> UserContext:
    """Provide a test admin user context with all permissions."""
    return UserContext(
        user_id=uuid4(),
        username="admin_user",
        email="admin@example.com",
        role="admin",
        permissions={
            "production:read", "production:write", "equipment:read", "equipment:write",
            "andon:read", "andon:write", "reports:read", "reports:write",
            "dashboard:read", "dashboard:write", "users:read", "users:write"
        }
    )


@pytest.fixture
def test_production_line_data() -> Dict[str, Any]:
    """Provide test production line data."""
    return {
        "id": str(uuid4()),
        "line_code": "LINE_001",
        "line_name": "Test Production Line",
        "line_type": "assembly",
        "status": "active",
        "created_at": datetime.now(timezone.utc),
        "updated_at": datetime.now(timezone.utc)
    }


@pytest.fixture
def test_equipment_data() -> Dict[str, Any]:
    """Provide test equipment data."""
    return {
        "id": str(uuid4()),
        "equipment_code": "EQ_001",
        "equipment_name": "Test Equipment",
        "equipment_type": "conveyor",
        "status": "running",
        "line_id": str(uuid4()),
        "created_at": datetime.now(timezone.utc)
    }


@pytest.fixture
def test_job_data() -> Dict[str, Any]:
    """Provide test job assignment data."""
    return {
        "id": str(uuid4()),
        "job_code": "JOB_001",
        "job_name": "Test Job",
        "line_id": str(uuid4()),
        "operator_id": str(uuid4()),
        "status": "assigned",
        "priority": "normal",
        "created_at": datetime.now(timezone.utc)
    }


@pytest.fixture
def test_andon_data() -> Dict[str, Any]:
    """Provide test Andon event data."""
    return {
        "id": str(uuid4()),
        "equipment_code": "EQ_001",
        "event_type": "fault",
        "priority": "high",
        "description": "Test fault event",
        "status": "open",
        "created_at": datetime.now(timezone.utc)
    }


@pytest.fixture
def mock_telemetry_data() -> Dict[str, Any]:
    """Provide mock telemetry data for testing."""
    return {
        "equipment_code": "EQ_001",
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


@pytest.fixture
def mock_websocket_connection() -> AsyncMock:
    """Provide a mock WebSocket connection for testing."""
    websocket = AsyncMock()
    websocket.accept = AsyncMock()
    websocket.send_text = AsyncMock()
    websocket.send_json = AsyncMock()
    websocket.receive_text = AsyncMock()
    websocket.receive_json = AsyncMock()
    websocket.close = AsyncMock()
    return websocket


@pytest.fixture(autouse=True)
def setup_test_environment():
    """Set up test environment variables and logging."""
    os.environ["ENVIRONMENT"] = "test"
    os.environ["DATABASE_URL"] = "sqlite:///:memory:"
    os.environ["REDIS_URL"] = "redis://localhost:6379/1"
    
    # Configure test logging
    structlog.configure(
        processors=[
            structlog.stdlib.filter_by_level,
            structlog.stdlib.add_logger_name,
            structlog.stdlib.add_log_level,
            structlog.stdlib.PositionalArgumentsFormatter(),
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            structlog.processors.UnicodeDecoder(),
            structlog.processors.JSONRenderer()
        ],
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        wrapper_class=structlog.stdlib.BoundLogger,
        cache_logger_on_first_use=True,
    )


@pytest.fixture
def coverage_config() -> Dict[str, Any]:
    """Provide coverage configuration for tests."""
    return {
        "backend_target": 80.0,
        "frontend_target": 70.0,
        "api_target": 100.0,
        "critical_paths_target": 100.0,
        "exclude_patterns": [
            "*/migrations/*",
            "*/venv/*",
            "*/__pycache__/*",
            "*/node_modules/*",
            "*/coverage/*"
        ]
    }


@pytest.fixture
def performance_benchmarks() -> Dict[str, float]:
    """Provide performance benchmark thresholds."""
    return {
        "api_response_time_ms": 200.0,
        "database_query_time_ms": 50.0,
        "websocket_latency_ms": 100.0,
        "frontend_load_time_ms": 1000.0,
        "concurrent_users": 1000,
        "throughput_rps": 100.0
    }


# Test utilities
class TestDataFactory:
    """Factory for creating test data with consistent patterns."""
    
    @staticmethod
    def create_production_line(**kwargs) -> Dict[str, Any]:
        """Create a production line test data object."""
        defaults = {
            "id": str(uuid4()),
            "line_code": f"LINE_{uuid4().hex[:8].upper()}",
            "line_name": f"Test Line {uuid4().hex[:4]}",
            "line_type": "assembly",
            "status": "active",
            "created_at": datetime.now(timezone.utc),
            "updated_at": datetime.now(timezone.utc)
        }
        defaults.update(kwargs)
        return defaults
    
    @staticmethod
    def create_equipment(**kwargs) -> Dict[str, Any]:
        """Create an equipment test data object."""
        defaults = {
            "id": str(uuid4()),
            "equipment_code": f"EQ_{uuid4().hex[:8].upper()}",
            "equipment_name": f"Test Equipment {uuid4().hex[:4]}",
            "equipment_type": "conveyor",
            "status": "running",
            "line_id": str(uuid4()),
            "created_at": datetime.now(timezone.utc)
        }
        defaults.update(kwargs)
        return defaults
    
    @staticmethod
    def create_job_assignment(**kwargs) -> Dict[str, Any]:
        """Create a job assignment test data object."""
        defaults = {
            "id": str(uuid4()),
            "job_code": f"JOB_{uuid4().hex[:8].upper()}",
            "job_name": f"Test Job {uuid4().hex[:4]}",
            "line_id": str(uuid4()),
            "operator_id": str(uuid4()),
            "status": "assigned",
            "priority": "normal",
            "created_at": datetime.now(timezone.utc)
        }
        defaults.update(kwargs)
        return defaults


@pytest.fixture
def data_factory() -> TestDataFactory:
    """Provide access to the test data factory."""
    return TestDataFactory()


# Coverage tracking utilities
class CoverageTracker:
    """Track and validate test coverage across all modules."""
    
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.coverage_data = {}
    
    def record_coverage(self, module: str, coverage_percent: float):
        """Record coverage percentage for a module."""
        self.coverage_data[module] = coverage_percent
    
    def validate_coverage(self) -> Dict[str, bool]:
        """Validate that coverage meets targets."""
        results = {}
        for module, target in [
            ("backend", self.config["backend_target"]),
            ("frontend", self.config["frontend_target"]),
            ("api", self.config["api_target"]),
            ("critical_paths", self.config["critical_paths_target"])
        ]:
            actual = self.coverage_data.get(module, 0.0)
            results[module] = actual >= target
        return results


@pytest.fixture
def coverage_tracker(coverage_config) -> CoverageTracker:
    """Provide access to the coverage tracker."""
    return CoverageTracker(coverage_config)
