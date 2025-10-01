"""
MS5.0 Floor Dashboard - Integration Test Configuration

Configuration for integration tests that test the complete API stack.
Provides test client, database setup, and authentication fixtures.
"""

import pytest
import pytest_asyncio
from typing import AsyncGenerator, Generator
from fastapi.testclient import TestClient
from httpx import AsyncClient
from unittest.mock import AsyncMock, Mock, patch
import asyncio
import os
import sys

# Add project root to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))

from backend.app.main import app
from backend.app.database import get_db_session
from backend.app.auth.permissions import UserContext


@pytest.fixture(scope="session")
def event_loop() -> Generator:
    """Create an instance of the default event loop for the test session."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()


@pytest.fixture
def test_client() -> TestClient:
    """Create a test client for synchronous API testing."""
    return TestClient(app)


@pytest.fixture
async def async_client() -> AsyncGenerator[AsyncClient, None]:
    """Create an async test client for asynchronous API testing."""
    async with AsyncClient(app=app, base_url="http://test") as client:
        yield client


@pytest.fixture
def mock_db_session():
    """Create a mock database session for testing."""
    session = AsyncMock()
    session.execute = AsyncMock()
    session.commit = AsyncMock()
    session.rollback = AsyncMock()
    session.close = AsyncMock()
    return session


@pytest.fixture
def override_get_db_session(mock_db_session):
    """Override the database session dependency."""
    def _override_get_db_session():
        return mock_db_session
    
    app.dependency_overrides[get_db_session] = _override_get_db_session
    yield mock_db_session
    app.dependency_overrides.clear()


@pytest.fixture
def test_user_token():
    """Provide a test user authentication token."""
    return "test_user_token_12345"


@pytest.fixture
def test_admin_token():
    """Provide a test admin authentication token."""
    return "test_admin_token_67890"


@pytest.fixture
def auth_headers(test_user_token):
    """Provide authentication headers for test requests."""
    return {"Authorization": f"Bearer {test_user_token}"}


@pytest.fixture
def admin_auth_headers(test_admin_token):
    """Provide admin authentication headers for test requests."""
    return {"Authorization": f"Bearer {test_admin_token}"}


@pytest.fixture
def mock_current_user():
    """Mock the current user for authentication."""
    return UserContext(
        user_id="test-user-id",
        username="test_user",
        email="test@example.com",
        role="operator",
        permissions={
            "production:read", "production:write", "equipment:read",
            "andon:read", "andon:write", "reports:read", "dashboard:read"
        }
    )


@pytest.fixture
def mock_admin_user():
    """Mock the admin user for authentication."""
    return UserContext(
        user_id="admin-user-id",
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
def override_get_current_user(mock_current_user):
    """Override the current user dependency."""
    def _override_get_current_user():
        return mock_current_user
    
    app.dependency_overrides[get_current_user] = _override_get_current_user
    yield mock_current_user
    app.dependency_overrides.clear()


@pytest.fixture
def override_get_admin_user(mock_admin_user):
    """Override the admin user dependency."""
    def _override_get_admin_user():
        return mock_admin_user
    
    app.dependency_overrides[get_current_user] = _override_get_admin_user
    yield mock_admin_user
    app.dependency_overrides.clear()


@pytest.fixture(autouse=True)
def setup_test_environment():
    """Set up test environment variables."""
    os.environ["ENVIRONMENT"] = "test"
    os.environ["DATABASE_URL"] = "sqlite:///:memory:"
    os.environ["REDIS_URL"] = "redis://localhost:6379/1"
    os.environ["JWT_SECRET_KEY"] = "test-secret-key"
    os.environ["JWT_ALGORITHM"] = "HS256"
    os.environ["JWT_ACCESS_TOKEN_EXPIRE_MINUTES"] = "30"


# Test data factories for integration tests
class IntegrationTestDataFactory:
    """Factory for creating test data for integration tests."""
    
    @staticmethod
    def create_production_line_data():
        """Create production line test data."""
        return {
            "line_code": "INT_TEST_LINE_001",
            "line_name": "Integration Test Line",
            "line_type": "assembly",
            "status": "active"
        }
    
    @staticmethod
    def create_equipment_data():
        """Create equipment test data."""
        return {
            "equipment_code": "INT_TEST_EQ_001",
            "equipment_name": "Integration Test Equipment",
            "equipment_type": "conveyor",
            "status": "running"
        }
    
    @staticmethod
    def create_job_assignment_data():
        """Create job assignment test data."""
        return {
            "job_code": "INT_TEST_JOB_001",
            "job_name": "Integration Test Job",
            "priority": "normal",
            "status": "assigned"
        }
    
    @staticmethod
    def create_andon_event_data():
        """Create Andon event test data."""
        return {
            "equipment_code": "INT_TEST_EQ_001",
            "event_type": "fault",
            "priority": "high",
            "description": "Integration test fault event"
        }
    
    @staticmethod
    def create_downtime_event_data():
        """Create downtime event test data."""
        return {
            "equipment_code": "INT_TEST_EQ_001",
            "category": "planned",
            "reason_code": "MAINTENANCE",
            "description": "Integration test maintenance event"
        }


@pytest.fixture
def test_data_factory():
    """Provide access to the integration test data factory."""
    return IntegrationTestDataFactory()


# API endpoint coverage tracking
class APICoverageTracker:
    """Track API endpoint coverage for integration tests."""
    
    def __init__(self):
        self.covered_endpoints = set()
        self.total_endpoints = set()
    
    def register_endpoint(self, method: str, path: str):
        """Register an API endpoint for coverage tracking."""
        endpoint = f"{method.upper()} {path}"
        self.total_endpoints.add(endpoint)
    
    def mark_covered(self, method: str, path: str):
        """Mark an API endpoint as covered."""
        endpoint = f"{method.upper()} {path}"
        self.covered_endpoints.add(endpoint)
    
    def get_coverage_percentage(self) -> float:
        """Get the API coverage percentage."""
        if not self.total_endpoints:
            return 0.0
        return (len(self.covered_endpoints) / len(self.total_endpoints)) * 100
    
    def get_uncovered_endpoints(self) -> set:
        """Get the set of uncovered endpoints."""
        return self.total_endpoints - self.covered_endpoints


@pytest.fixture
def api_coverage_tracker():
    """Provide access to the API coverage tracker."""
    return APICoverageTracker()


# Performance testing utilities
class PerformanceTestHelper:
    """Helper utilities for performance testing."""
    
    @staticmethod
    def measure_response_time(client, method: str, url: str, **kwargs) -> float:
        """Measure the response time for an API request."""
        import time
        
        start_time = time.time()
        if method.upper() == "GET":
            response = client.get(url, **kwargs)
        elif method.upper() == "POST":
            response = client.post(url, **kwargs)
        elif method.upper() == "PUT":
            response = client.put(url, **kwargs)
        elif method.upper() == "DELETE":
            response = client.delete(url, **kwargs)
        else:
            raise ValueError(f"Unsupported HTTP method: {method}")
        
        end_time = time.time()
        response_time_ms = (end_time - start_time) * 1000
        
        return response_time_ms
    
    @staticmethod
    def assert_response_time_acceptable(response_time_ms: float, max_acceptable_ms: float = 200.0):
        """Assert that response time is within acceptable limits."""
        assert response_time_ms <= max_acceptable_ms, \
            f"Response time {response_time_ms:.2f}ms exceeds acceptable limit of {max_acceptable_ms}ms"


@pytest.fixture
def performance_helper():
    """Provide access to the performance test helper."""
    return PerformanceTestHelper()
