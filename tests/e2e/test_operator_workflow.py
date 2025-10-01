"""
MS5.0 Floor Dashboard - Operator Workflow End-to-End Tests

End-to-end tests for the complete operator workflow.
Tests the operator's journey from login to task completion.

Critical User Flows:
1. Operator login and dashboard access
2. Job assignment acceptance and execution
3. Checklist completion workflow
4. Andon event reporting and escalation
5. Equipment status monitoring
"""

import pytest
import pytest_asyncio
from playwright.async_api import Page, expect
from datetime import datetime, timezone, timedelta
import asyncio


class TestOperatorLoginWorkflow:
    """End-to-end tests for operator login workflow."""
    
    @pytest.mark.asyncio
    async def test_operator_login_success(
        self, 
        page: Page, 
        test_app_url: str, 
        test_user_data: dict,
        e2e_helper,
        e2e_benchmarks
    ):
        """Test successful operator login and dashboard access."""
        # Measure page load time
        load_start = datetime.now()
        
        # Navigate to login page
        await page.goto(f"{test_app_url}/login")
        await page.wait_for_load_state("networkidle")
        
        # Verify login page elements
        await expect(page.locator("#username")).to_be_visible()
        await expect(page.locator("#password")).to_be_visible()
        await expect(page.locator("#login-button")).to_be_visible()
        
        # Perform login
        login_start = datetime.now()
        
        from tests.e2e.conftest import LoginPage
        login_page = LoginPage(page)
        await login_page.login(test_user_data["username"], test_user_data["password"])
        
        # Wait for redirect to dashboard
        await page.wait_for_url(f"{test_app_url}/dashboard")
        await page.wait_for_load_state("networkidle")
        
        login_end = datetime.now()
        login_time_ms = (login_end - login_start).total_seconds() * 1000
        
        # Verify dashboard elements
        await expect(page.locator("#production-overview")).to_be_visible()
        await expect(page.locator("#oee-metrics")).to_be_visible()
        await expect(page.locator("#andon-alerts")).to_be_visible()
        await expect(page.locator("#equipment-status")).to_be_visible()
        
        # Verify user role and permissions
        user_menu = page.locator("#user-menu")
        await expect(user_menu).to_be_visible()
        await user_menu.click()
        
        user_role = page.locator("#user-role")
        await expect(user_role).to_contain_text("operator")
        
        # Assert performance benchmarks
        e2e_benchmarks.assert_form_submission_time(login_time_ms, "Login")
    
    @pytest.mark.asyncio
    async def test_operator_login_invalid_credentials(
        self, 
        page: Page, 
        test_app_url: str,
        e2e_helper
    ):
        """Test operator login with invalid credentials."""
        # Navigate to login page
        await page.goto(f"{test_app_url}/login")
        await page.wait_for_load_state("networkidle")
        
        # Perform login with invalid credentials
        from tests.e2e.conftest import LoginPage
        login_page = LoginPage(page)
        await login_page.login("invalid_user", "invalid_password")
        
        # Verify error message
        error_message = await login_page.get_error_message()
        assert "Invalid credentials" in error_message
        
        # Verify still on login page
        await expect(page).to_have_url(f"{test_app_url}/login")
    
    @pytest.mark.asyncio
    async def test_operator_login_insufficient_permissions(
        self, 
        page: Page, 
        test_app_url: str,
        e2e_helper
    ):
        """Test operator login with insufficient permissions."""
        # Navigate to login page
        await page.goto(f"{test_app_url}/login")
        await page.wait_for_load_state("networkidle")
        
        # Perform login with restricted user
        from tests.e2e.conftest import LoginPage
        login_page = LoginPage(page)
        await login_page.login("restricted_user", "restricted_password")
        
        # Verify access denied message
        error_message = await login_page.get_error_message()
        assert "Insufficient permissions" in error_message


class TestOperatorJobWorkflow:
    """End-to-end tests for operator job assignment workflow."""
    
    @pytest.mark.asyncio
    async def test_job_assignment_acceptance_workflow(
        self, 
        page: Page, 
        test_app_url: str,
        test_user_data: dict,
        test_production_data: dict,
        e2e_helper,
        e2e_benchmarks
    ):
        """Test complete job assignment acceptance and execution workflow."""
        # Login as operator
        from tests.e2e.conftest import LoginPage, DashboardPage
        login_page = LoginPage(page)
        await login_page.login(test_user_data["username"], test_user_data["password"])
        
        # Navigate to jobs section
        dashboard_page = DashboardPage(page)
        await dashboard_page.wait_for_dashboard_load()
        await dashboard_page.navigate_to_section("jobs")
        
        # Verify jobs page loaded
        await expect(page.locator("#jobs-list")).to_be_visible()
        await expect(page.locator("#job-assignments")).to_be_visible()
        
        # Find and accept a job assignment
        job_item = page.locator(".job-item[data-status='assigned']").first()
        await expect(job_item).to_be_visible()
        
        # Click to view job details
        await job_item.click()
        await expect(page.locator("#job-details")).to_be_visible()
        
        # Accept the job
        accept_button = page.locator("#accept-job-button")
        await expect(accept_button).to_be_visible()
        
        accept_start = datetime.now()
        await accept_button.click()
        
        # Wait for job status update
        await expect(job_item.locator("[data-status='accepted']")).to_be_visible()
        
        accept_end = datetime.now()
        accept_time_ms = (accept_end - accept_start).total_seconds() * 1000
        
        # Verify job details updated
        await expect(page.locator("#job-status")).to_contain_text("accepted")
        await expect(page.locator("#job-accepted-by")).to_contain_text(test_user_data["username"])
        await expect(page.locator("#job-accepted-time")).to_be_visible()
        
        # Assert performance benchmarks
        e2e_benchmarks.assert_form_submission_time(accept_time_ms, "Job Acceptance")
    
    @pytest.mark.asyncio
    async def test_job_execution_and_completion_workflow(
        self, 
        page: Page, 
        test_app_url: str,
        test_user_data: dict,
        test_production_data: dict,
        e2e_helper
    ):
        """Test job execution and completion workflow."""
        # Login as operator
        from tests.e2e.conftest import LoginPage
        login_page = LoginPage(page)
        await login_page.login(test_user_data["username"], test_user_data["password"])
        
        # Navigate to accepted job
        await page.goto(f"{test_app_url}/jobs/accepted")
        await page.wait_for_load_state("networkidle")
        
        # Find an accepted job
        accepted_job = page.locator(".job-item[data-status='accepted']").first()
        await expect(accepted_job).to_be_visible()
        
        # Start job execution
        await accepted_job.click()
        await expect(page.locator("#job-details")).to_be_visible()
        
        start_execution_button = page.locator("#start-execution-button")
        await expect(start_execution_button).to_be_visible()
        await start_execution_button.click()
        
        # Verify job status changed to in_progress
        await expect(accepted_job.locator("[data-status='in_progress']")).to_be_visible()
        
        # Complete job execution
        complete_button = page.locator("#complete-job-button")
        await expect(complete_button).to_be_visible()
        await complete_button.click()
        
        # Fill completion form
        await page.locator("#completion-notes").fill("Job completed successfully")
        await page.locator("#quality-check-passed").check()
        await page.locator("#quantity-produced").fill("100")
        
        # Submit completion
        await page.locator("#submit-completion-button").click()
        
        # Verify job status changed to completed
        await expect(accepted_job.locator("[data-status='completed']")).to_be_visible()
        
        # Verify completion details
        await expect(page.locator("#completion-time")).to_be_visible()
        await expect(page.locator("#completion-notes")).to_contain_text("Job completed successfully")


class TestOperatorChecklistWorkflow:
    """End-to-end tests for operator checklist completion workflow."""
    
    @pytest.mark.asyncio
    async def test_checklist_completion_workflow(
        self, 
        page: Page, 
        test_app_url: str,
        test_user_data: dict,
        e2e_helper
    ):
        """Test complete checklist completion workflow."""
        # Login as operator
        from tests.e2e.conftest import LoginPage
        login_page = LoginPage(page)
        await login_page.login(test_user_data["username"], test_user_data["password"])
        
        # Navigate to checklists
        await page.goto(f"{test_app_url}/checklists")
        await page.wait_for_load_state("networkidle")
        
        # Verify checklists page loaded
        await expect(page.locator("#checklists-list")).to_be_visible()
        await expect(page.locator("#pending-checklists")).to_be_visible()
        
        # Find a pending checklist
        pending_checklist = page.locator(".checklist-item[data-status='pending']").first()
        await expect(pending_checklist).to_be_visible()
        
        # Open checklist
        await pending_checklist.click()
        await expect(page.locator("#checklist-details")).to_be_visible()
        
        # Complete checklist items
        checklist_items = page.locator(".checklist-item-input")
        item_count = await checklist_items.count()
        
        for i in range(item_count):
            item = checklist_items.nth(i)
            await item.check()
            
            # Add notes if required
            notes_field = page.locator(f".checklist-item-notes").nth(i)
            if await notes_field.is_visible():
                await notes_field.fill(f"Completed item {i+1}")
        
        # Submit checklist
        submit_button = page.locator("#submit-checklist-button")
        await expect(submit_button).to_be_visible()
        await submit_button.click()
        
        # Verify checklist completion
        await expect(pending_checklist.locator("[data-status='completed']")).to_be_visible()
        
        # Verify completion timestamp
        await expect(page.locator("#checklist-completion-time")).to_be_visible()
    
    @pytest.mark.asyncio
    async def test_checklist_with_issues_workflow(
        self, 
        page: Page, 
        test_app_url: str,
        test_user_data: dict,
        e2e_helper
    ):
        """Test checklist completion workflow with issues reported."""
        # Login as operator
        from tests.e2e.conftest import LoginPage
        login_page = LoginPage(page)
        await login_page.login(test_user_data["username"], test_user_data["password"])
        
        # Navigate to checklists
        await page.goto(f"{test_app_url}/checklists")
        await page.wait_for_load_state("networkidle")
        
        # Find a pending checklist
        pending_checklist = page.locator(".checklist-item[data-status='pending']").first()
        await expect(pending_checklist).to_be_visible()
        
        # Open checklist
        await pending_checklist.click()
        await expect(page.locator("#checklist-details")).to_be_visible()
        
        # Mark an item as failed
        first_item = page.locator(".checklist-item-input").first()
        await first_item.check()
        
        # Report an issue
        issue_button = page.locator(".report-issue-button").first()
        await issue_button.click()
        
        # Fill issue details
        await page.locator("#issue-description").fill("Equipment malfunction detected")
        await page.locator("#issue-severity").select_option("high")
        await page.locator("#issue-category").select_option("equipment")
        
        # Submit issue
        await page.locator("#submit-issue-button").click()
        
        # Verify issue reported
        await expect(page.locator("#issue-reported-notification")).to_be_visible()
        
        # Complete remaining checklist items
        remaining_items = page.locator(".checklist-item-input:not(:checked)")
        remaining_count = await remaining_items.count()
        
        for i in range(remaining_count):
            item = remaining_items.nth(i)
            await item.check()
        
        # Submit checklist with issues
        submit_button = page.locator("#submit-checklist-button")
        await submit_button.click()
        
        # Verify checklist completed with issues
        await expect(pending_checklist.locator("[data-status='completed_with_issues']")).to_be_visible()


class TestOperatorAndonWorkflow:
    """End-to-end tests for operator Andon event workflow."""
    
    @pytest.mark.asyncio
    async def test_andon_event_reporting_workflow(
        self, 
        page: Page, 
        test_app_url: str,
        test_user_data: dict,
        test_andon_data: dict,
        e2e_helper,
        e2e_benchmarks
    ):
        """Test complete Andon event reporting workflow."""
        # Login as operator
        from tests.e2e.conftest import LoginPage
        login_page = LoginPage(page)
        await login_page.login(test_user_data["username"], test_user_data["password"])
        
        # Navigate to Andon section
        await page.goto(f"{test_app_url}/andon")
        await page.wait_for_load_state("networkidle")
        
        # Verify Andon page loaded
        await expect(page.locator("#andon-dashboard")).to_be_visible()
        await expect(page.locator("#create-andon-button")).to_be_visible()
        
        # Create new Andon event
        create_button = page.locator("#create-andon-button")
        await create_button.click()
        
        # Fill Andon event form
        await page.locator("#equipment-code").fill(test_andon_data["andon_event"]["equipment_code"])
        await page.locator("#event-type").select_option(test_andon_data["andon_event"]["event_type"])
        await page.locator("#priority").select_option(test_andon_data["andon_event"]["priority"])
        await page.locator("#description").fill(test_andon_data["andon_event"]["description"])
        
        # Submit Andon event
        submit_start = datetime.now()
        
        submit_button = page.locator("#submit-andon-button")
        await submit_button.click()
        
        # Wait for event creation
        await expect(page.locator("#andon-created-notification")).to_be_visible()
        
        submit_end = datetime.now()
        submit_time_ms = (submit_end - submit_start).total_seconds() * 1000
        
        # Verify event appears in Andon list
        andon_list = page.locator("#andon-events-list")
        await expect(andon_list).to_be_visible()
        
        new_event = andon_list.locator(f"[data-equipment-code='{test_andon_data['andon_event']['equipment_code']}']")
        await expect(new_event).to_be_visible()
        await expect(new_event.locator("[data-priority='high']")).to_be_visible()
        await expect(new_event.locator("[data-status='open']")).to_be_visible()
        
        # Assert performance benchmarks
        e2e_benchmarks.assert_form_submission_time(submit_time_ms, "Andon Event Creation")
    
    @pytest.mark.asyncio
    async def test_andon_event_acknowledgment_workflow(
        self, 
        page: Page, 
        test_app_url: str,
        test_user_data: dict,
        e2e_helper
    ):
        """Test Andon event acknowledgment workflow."""
        # Login as operator
        from tests.e2e.conftest import LoginPage
        login_page = LoginPage(page)
        await login_page.login(test_user_data["username"], test_user_data["password"])
        
        # Navigate to Andon section
        await page.goto(f"{test_app_url}/andon")
        await page.wait_for_load_state("networkidle")
        
        # Find an open Andon event
        open_event = page.locator(".andon-event[data-status='open']").first()
        await expect(open_event).to_be_visible()
        
        # Acknowledge the event
        acknowledge_button = open_event.locator(".acknowledge-button")
        await expect(acknowledge_button).to_be_visible()
        await acknowledge_button.click()
        
        # Confirm acknowledgment
        await expect(page.locator("#confirm-acknowledge-dialog")).to_be_visible()
        await page.locator("#confirm-acknowledge-button").click()
        
        # Verify event status changed to acknowledged
        await expect(open_event.locator("[data-status='acknowledged']")).to_be_visible()
        await expect(open_event.locator(".acknowledged-by")).to_contain_text(test_user_data["username"])
        await expect(open_event.locator(".acknowledged-time")).to_be_visible()
    
    @pytest.mark.asyncio
    async def test_andon_event_escalation_workflow(
        self, 
        page: Page, 
        test_app_url: str,
        test_user_data: dict,
        e2e_helper
    ):
        """Test Andon event escalation workflow."""
        # Login as operator
        from tests.e2e.conftest import LoginPage
        login_page = LoginPage(page)
        await login_page.login(test_user_data["username"], test_user_data["password"])
        
        # Navigate to Andon section
        await page.goto(f"{test_app_url}/andon")
        await page.wait_for_load_state("networkidle")
        
        # Find an acknowledged Andon event
        acknowledged_event = page.locator(".andon-event[data-status='acknowledged']").first()
        await expect(acknowledged_event).to_be_visible()
        
        # Check if escalation is available (timeout exceeded)
        escalation_button = acknowledged_event.locator(".escalate-button")
        if await escalation_button.is_visible():
            await escalation_button.click()
            
            # Fill escalation details
            await page.locator("#escalation-reason").fill("No response within timeout period")
            await page.locator("#escalation-priority").select_option("urgent")
            
            # Submit escalation
            await page.locator("#submit-escalation-button").click()
            
            # Verify escalation notification
            await expect(page.locator("#escalation-notification")).to_be_visible()
            
            # Verify event status changed to escalated
            await expect(acknowledged_event.locator("[data-status='escalated']")).to_be_visible()


class TestOperatorEquipmentMonitoring:
    """End-to-end tests for operator equipment monitoring workflow."""
    
    @pytest.mark.asyncio
    async def test_equipment_status_monitoring_workflow(
        self, 
        page: Page, 
        test_app_url: str,
        test_user_data: dict,
        e2e_helper
    ):
        """Test equipment status monitoring workflow."""
        # Login as operator
        from tests.e2e.conftest import LoginPage
        login_page = LoginPage(page)
        await login_page.login(test_user_data["username"], test_user_data["password"])
        
        # Navigate to equipment section
        await page.goto(f"{test_app_url}/equipment")
        await page.wait_for_load_state("networkidle")
        
        # Verify equipment page loaded
        await expect(page.locator("#equipment-dashboard")).to_be_visible()
        await expect(page.locator("#equipment-list")).to_be_visible()
        await expect(page.locator("#status-filters")).to_be_visible()
        
        # Filter equipment by status
        running_filter = page.locator("#status-filters button[data-status='running']")
        await running_filter.click()
        
        # Verify filtered results
        running_equipment = page.locator(".equipment-item[data-status='running']")
        await expect(running_equipment.first()).to_be_visible()
        
        # View equipment details
        first_equipment = running_equipment.first()
        await first_equipment.click()
        
        # Verify equipment details panel
        await expect(page.locator("#equipment-details")).to_be_visible()
        await expect(page.locator("#equipment-status")).to_be_visible()
        await expect(page.locator("#equipment-metrics")).to_be_visible()
        await expect(page.locator("#equipment-history")).to_be_visible()
        
        # Check real-time metrics
        metrics_section = page.locator("#equipment-metrics")
        await expect(metrics_section.locator(".speed-value")).to_be_visible()
        await expect(metrics_section.locator(".temperature-value")).to_be_visible()
        await expect(metrics_section.locator(".pressure-value")).to_be_visible()
    
    @pytest.mark.asyncio
    async def test_equipment_maintenance_workflow(
        self, 
        page: Page, 
        test_app_url: str,
        test_user_data: dict,
        e2e_helper
    ):
        """Test equipment maintenance workflow."""
        # Login as operator
        from tests.e2e.conftest import LoginPage
        login_page = LoginPage(page)
        await login_page.login(test_user_data["username"], test_user_data["password"])
        
        # Navigate to equipment section
        await page.goto(f"{test_app_url}/equipment")
        await page.wait_for_load_state("networkidle")
        
        # Find equipment requiring maintenance
        maintenance_equipment = page.locator(".equipment-item[data-status='maintenance_required']").first()
        if await maintenance_equipment.is_visible():
            await maintenance_equipment.click()
            
            # Verify maintenance details
            await expect(page.locator("#maintenance-details")).to_be_visible()
            await expect(page.locator("#maintenance-checklist")).to_be_visible()
            
            # Complete maintenance checklist
            checklist_items = page.locator(".maintenance-checklist-item input[type='checkbox']")
            item_count = await checklist_items.count()
            
            for i in range(item_count):
                item = checklist_items.nth(i)
                await item.check()
                
                # Add maintenance notes
                notes_field = page.locator(f".maintenance-notes").nth(i)
                if await notes_field.is_visible():
                    await notes_field.fill(f"Maintenance item {i+1} completed")
            
            # Submit maintenance completion
            submit_button = page.locator("#submit-maintenance-button")
            await submit_button.click()
            
            # Verify maintenance completion
            await expect(page.locator("#maintenance-completed-notification")).to_be_visible()
            
            # Verify equipment status updated
            await expect(maintenance_equipment.locator("[data-status='running']")).to_be_visible()
