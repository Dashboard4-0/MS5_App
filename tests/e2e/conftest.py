"""
MS5.0 Floor Dashboard - End-to-End Test Configuration

Configuration for end-to-end tests that validate complete user journeys.
Provides browser automation, test data, and user flow validation.
"""

import pytest
import pytest_asyncio
from typing import AsyncGenerator, Generator
from playwright.async_api import async_playwright, Browser, BrowserContext, Page
import asyncio
import os
import sys
from datetime import datetime, timezone, timedelta
from uuid import uuid4

# Add project root to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))


@pytest.fixture(scope="session")
def event_loop() -> Generator:
    """Create an instance of the default event loop for the test session."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()


@pytest.fixture(scope="session")
async def browser() -> AsyncGenerator[Browser, None]:
    """Create a browser instance for testing."""
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        yield browser
        await browser.close()


@pytest.fixture
async def browser_context(browser: Browser) -> AsyncGenerator[BrowserContext, None]:
    """Create a browser context for testing."""
    context = await browser.new_context(
        viewport={"width": 1920, "height": 1080},
        user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
    )
    yield context
    await context.close()


@pytest.fixture
async def page(browser_context: BrowserContext) -> AsyncGenerator[Page, None]:
    """Create a page for testing."""
    page = await browser_context.new_page()
    yield page
    await page.close()


@pytest.fixture
def test_app_url():
    """Provide the test application URL."""
    return os.getenv("TEST_APP_URL", "http://localhost:3000")


@pytest.fixture
def test_api_url():
    """Provide the test API URL."""
    return os.getenv("TEST_API_URL", "http://localhost:8000")


# Test user data
@pytest.fixture
def test_user_data():
    """Provide test user data for authentication."""
    return {
        "username": "test_operator",
        "password": "test_password_123",
        "role": "operator",
        "email": "test_operator@example.com",
        "permissions": [
            "production:read", "production:write", "equipment:read",
            "andon:read", "andon:write", "dashboard:read"
        ]
    }


@pytest.fixture
def test_admin_data():
    """Provide test admin user data for authentication."""
    return {
        "username": "test_admin",
        "password": "admin_password_123",
        "role": "admin",
        "email": "test_admin@example.com",
        "permissions": [
            "production:read", "production:write", "equipment:read", "equipment:write",
            "andon:read", "andon:write", "reports:read", "reports:write",
            "dashboard:read", "dashboard:write", "users:read", "users:write"
        ]
    }


@pytest.fixture
def test_production_data():
    """Provide test production data for E2E tests."""
    return {
        "production_line": {
            "line_code": f"E2E_LINE_{uuid4().hex[:8]}",
            "line_name": "E2E Test Production Line",
            "line_type": "assembly",
            "status": "active"
        },
        "equipment": {
            "equipment_code": f"E2E_EQ_{uuid4().hex[:8]}",
            "equipment_name": "E2E Test Equipment",
            "equipment_type": "conveyor",
            "status": "running"
        },
        "job": {
            "job_code": f"E2E_JOB_{uuid4().hex[:8]}",
            "job_name": "E2E Test Job",
            "priority": "normal",
            "status": "assigned"
        }
    }


@pytest.fixture
def test_andon_data():
    """Provide test Andon data for E2E tests."""
    return {
        "andon_event": {
            "equipment_code": f"E2E_EQ_{uuid4().hex[:8]}",
            "event_type": "fault",
            "priority": "high",
            "description": "E2E test fault event"
        }
    }


# Page object models for E2E tests
class LoginPage:
    """Page object model for the login page."""
    
    def __init__(self, page: Page):
        self.page = page
        self.username_input = page.locator("#username")
        self.password_input = page.locator("#password")
        self.login_button = page.locator("#login-button")
        self.error_message = page.locator("#error-message")
    
    async def login(self, username: str, password: str):
        """Perform login with provided credentials."""
        await self.username_input.fill(username)
        await self.password_input.fill(password)
        await self.login_button.click()
    
    async def get_error_message(self) -> str:
        """Get the error message if login fails."""
        await self.error_message.wait_for()
        return await self.error_message.text_content()


class DashboardPage:
    """Page object model for the dashboard page."""
    
    def __init__(self, page: Page):
        self.page = page
        self.production_overview = page.locator("#production-overview")
        self.oee_metrics = page.locator("#oee-metrics")
        self.andon_alerts = page.locator("#andon-alerts")
        self.equipment_status = page.locator("#equipment-status")
        self.navigation_menu = page.locator("#navigation-menu")
    
    async def wait_for_dashboard_load(self):
        """Wait for the dashboard to fully load."""
        await self.production_overview.wait_for()
        await self.oee_metrics.wait_for()
    
    async def navigate_to_section(self, section_name: str):
        """Navigate to a specific dashboard section."""
        section_link = self.navigation_menu.locator(f"a[href*='{section_name}']")
        await section_link.click()
    
    async def get_oee_value(self) -> float:
        """Get the current OEE value from the dashboard."""
        oee_element = self.oee_metrics.locator(".oee-value")
        await oee_element.wait_for()
        oee_text = await oee_element.text_content()
        return float(oee_text.replace('%', ''))
    
    async def get_active_andon_count(self) -> int:
        """Get the count of active Andon alerts."""
        andon_count_element = self.andon_alerts.locator(".andon-count")
        await andon_count_element.wait_for()
        count_text = await andon_count_element.text_content()
        return int(count_text)


class ProductionPage:
    """Page object model for the production management page."""
    
    def __init__(self, page: Page):
        self.page = page
        self.create_line_button = page.locator("#create-production-line")
        self.line_list = page.locator("#production-lines-list")
        self.line_form = page.locator("#production-line-form")
        self.save_button = page.locator("#save-line-button")
        self.cancel_button = page.locator("#cancel-line-button")
    
    async def create_production_line(self, line_data: dict):
        """Create a new production line."""
        await self.create_line_button.click()
        await self.line_form.wait_for()
        
        # Fill form fields
        await self.page.locator("#line-code").fill(line_data["line_code"])
        await self.page.locator("#line-name").fill(line_data["line_name"])
        await self.page.locator("#line-type").select_option(line_data["line_type"])
        await self.page.locator("#line-status").select_option(line_data["status"])
        
        # Save the line
        await self.save_button.click()
        await self.line_list.wait_for()
    
    async def get_line_count(self) -> int:
        """Get the number of production lines in the list."""
        line_items = self.line_list.locator(".line-item")
        return await line_items.count()
    
    async def get_line_by_code(self, line_code: str):
        """Get a production line by its code."""
        line_item = self.line_list.locator(f".line-item[data-line-code='{line_code}']")
        await line_item.wait_for()
        return line_item


class AndonPage:
    """Page object model for the Andon management page."""
    
    def __init__(self, page: Page):
        self.page = page
        self.create_andon_button = page.locator("#create-andon-event")
        self.andon_list = page.locator("#andon-events-list")
        self.andon_form = page.locator("#andon-event-form")
        self.acknowledge_button = page.locator("#acknowledge-button")
        self.resolve_button = page.locator("#resolve-button")
    
    async def create_andon_event(self, andon_data: dict):
        """Create a new Andon event."""
        await self.create_andon_button.click()
        await self.andon_form.wait_for()
        
        # Fill form fields
        await self.page.locator("#equipment-code").fill(andon_data["equipment_code"])
        await self.page.locator("#event-type").select_option(andon_data["event_type"])
        await self.page.locator("#priority").select_option(andon_data["priority"])
        await self.page.locator("#description").fill(andon_data["description"])
        
        # Save the event
        await self.page.locator("#save-andon-button").click()
        await self.andon_list.wait_for()
    
    async def acknowledge_event(self, event_id: str):
        """Acknowledge an Andon event."""
        event_item = self.andon_list.locator(f".andon-event[data-event-id='{event_id}']")
        await event_item.wait_for()
        
        acknowledge_btn = event_item.locator(".acknowledge-btn")
        await acknowledge_btn.click()
        
        # Confirm acknowledgment
        await self.page.locator("#confirm-acknowledge").click()
    
    async def resolve_event(self, event_id: str, resolution_notes: str):
        """Resolve an Andon event."""
        event_item = self.andon_list.locator(f".andon-event[data-event-id='{event_id}']")
        await event_item.wait_for()
        
        resolve_btn = event_item.locator(".resolve-btn")
        await resolve_btn.click()
        
        # Fill resolution notes
        await self.page.locator("#resolution-notes").fill(resolution_notes)
        await self.page.locator("#confirm-resolve").click()
    
    async def get_active_event_count(self) -> int:
        """Get the count of active Andon events."""
        active_events = self.andon_list.locator(".andon-event[data-status='open']")
        return await active_events.count()


class EquipmentPage:
    """Page object model for the equipment management page."""
    
    def __init__(self, page: Page):
        self.page = page
        self.equipment_list = page.locator("#equipment-list")
        self.status_filters = page.locator("#status-filters")
        self.equipment_details = page.locator("#equipment-details")
    
    async def filter_by_status(self, status: str):
        """Filter equipment by status."""
        status_filter = self.status_filters.locator(f"button[data-status='{status}']")
        await status_filter.click()
        await self.equipment_list.wait_for()
    
    async def get_equipment_count_by_status(self, status: str) -> int:
        """Get the count of equipment with a specific status."""
        equipment_items = self.equipment_list.locator(f".equipment-item[data-status='{status}']")
        return await equipment_items.count()
    
    async def click_equipment_item(self, equipment_code: str):
        """Click on an equipment item to view details."""
        equipment_item = self.equipment_list.locator(f".equipment-item[data-equipment-code='{equipment_code}']")
        await equipment_item.click()
        await self.equipment_details.wait_for()


# Test utilities for E2E tests
class E2ETestHelper:
    """Helper utilities for end-to-end testing."""
    
    @staticmethod
    async def wait_for_api_response(page: Page, api_url: str, timeout: int = 10000):
        """Wait for an API response to complete."""
        response = await page.wait_for_response(
            lambda response: api_url in response.url,
            timeout=timeout
        )
        return response
    
    @staticmethod
    async def wait_for_websocket_message(page: Page, message_type: str, timeout: int = 5000):
        """Wait for a specific WebSocket message."""
        # This would be implemented based on the WebSocket implementation
        await page.wait_for_timeout(timeout)
    
    @staticmethod
    async def take_screenshot(page: Page, name: str):
        """Take a screenshot for debugging purposes."""
        screenshot_path = f"/tmp/e2e_screenshot_{name}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.png"
        await page.screenshot(path=screenshot_path)
        return screenshot_path
    
    @staticmethod
    async def measure_page_load_time(page: Page, url: str) -> float:
        """Measure the page load time."""
        start_time = datetime.now()
        await page.goto(url)
        await page.wait_for_load_state("networkidle")
        end_time = datetime.now()
        return (end_time - start_time).total_seconds() * 1000  # Convert to milliseconds


@pytest.fixture
def e2e_helper():
    """Provide access to the E2E test helper."""
    return E2ETestHelper()


# Performance benchmarks for E2E tests
class E2EPerformanceBenchmarks:
    """Performance benchmarks for end-to-end tests."""
    
    def __init__(self):
        self.benchmarks = {
            "page_load_time_ms": 2000.0,
            "api_response_time_ms": 500.0,
            "websocket_latency_ms": 100.0,
            "form_submission_time_ms": 1000.0,
            "navigation_time_ms": 500.0
        }
    
    def assert_page_load_time(self, actual_time_ms: float, page_name: str):
        """Assert that page load time meets benchmark."""
        max_time = self.benchmarks["page_load_time_ms"]
        assert actual_time_ms <= max_time, \
            f"{page_name} load time {actual_time_ms:.2f}ms exceeds benchmark of {max_time}ms"
    
    def assert_api_response_time(self, actual_time_ms: float, api_name: str):
        """Assert that API response time meets benchmark."""
        max_time = self.benchmarks["api_response_time_ms"]
        assert actual_time_ms <= max_time, \
            f"{api_name} response time {actual_time_ms:.2f}ms exceeds benchmark of {max_time}ms"
    
    def assert_form_submission_time(self, actual_time_ms: float, form_name: str):
        """Assert that form submission time meets benchmark."""
        max_time = self.benchmarks["form_submission_time_ms"]
        assert actual_time_ms <= max_time, \
            f"{form_name} submission time {actual_time_ms:.2f}ms exceeds benchmark of {max_time}ms"


@pytest.fixture
def e2e_benchmarks():
    """Provide access to E2E performance benchmarks."""
    return E2EPerformanceBenchmarks()
