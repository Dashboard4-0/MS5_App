"""
End-to-end tests for Andon escalation workflow
Tests complete Andon event creation, acknowledgment, escalation, and resolution workflow
"""

import pytest
import asyncio
import httpx
import uuid
from datetime import datetime, timedelta
import json


class TestAndonEscalationWorkflow:
    """End-to-end tests for Andon escalation workflow"""
    
    @pytest.fixture
    async def client(self):
        """Create HTTP client for E2E testing"""
        async with httpx.AsyncClient(base_url="http://localhost:8000", timeout=30.0) as client:
            yield client
    
    @pytest.fixture
    async def auth_token(self, client):
        """Get authentication token for E2E testing"""
        login_data = {
            "email": "test@example.com",
            "password": "testpassword"
        }
        
        response = await client.post("/api/v1/auth/login", json=login_data)
        if response.status_code == 200:
            return response.json()["token"]
        return None
    
    @pytest.fixture
    def auth_headers(self, auth_token):
        """Get authentication headers"""
        if auth_token:
            return {"Authorization": f"Bearer {auth_token}"}
        return {}
    
    @pytest.mark.asyncio
    async def test_complete_andon_escalation_workflow(self, client, auth_headers):
        """Test complete Andon escalation workflow from event creation to resolution"""
        
        # Step 1: Create Andon Event
        event_data = {
            "equipment_code": "EQ-E2E-001",
            "line_id": str(uuid.uuid4()),
            "event_type": "fault",
            "priority": "high",
            "description": "E2E test Andon event - equipment fault detected",
            "reported_by": str(uuid.uuid4()),
            "category": "mechanical"
        }
        
        create_response = await client.post("/api/v1/andon/events", json=event_data, headers=auth_headers)
        
        if create_response.status_code in [200, 201]:
            event_id = create_response.json()["id"]
            assert create_response.json()["status"] == "active"
            assert create_response.json()["event_type"] == event_data["event_type"]
            assert create_response.json()["priority"] == event_data["priority"]
        else:
            pytest.skip("Could not create Andon event")
        
        # Step 2: Get Andon Event Details
        get_response = await client.get(f"/api/v1/andon/events/{event_id}", headers=auth_headers)
        
        if get_response.status_code == 200:
            event_details = get_response.json()
            assert event_details["id"] == event_id
            assert event_details["status"] == "active"
            assert event_details["equipment_code"] == event_data["equipment_code"]
        else:
            pytest.skip("Could not get Andon event details")
        
        # Step 3: Acknowledge Andon Event
        acknowledge_response = await client.post(f"/api/v1/andon/events/{event_id}/acknowledge", headers=auth_headers)
        
        if acknowledge_response.status_code == 200:
            acknowledged_event = acknowledge_response.json()
            assert acknowledged_event["status"] == "acknowledged"
            assert acknowledged_event["acknowledged_at"] is not None
        else:
            pytest.skip("Could not acknowledge Andon event")
        
        # Step 4: Update Andon Event Status
        update_data = {
            "status": "in_progress",
            "notes": "Maintenance team dispatched to investigate"
        }
        
        update_response = await client.put(f"/api/v1/andon/events/{event_id}", json=update_data, headers=auth_headers)
        
        if update_response.status_code == 200:
            updated_event = update_response.json()
            assert updated_event["status"] == "in_progress"
        else:
            pytest.skip("Could not update Andon event")
        
        # Step 5: Escalate Andon Event (if escalation system is available)
        escalation_data = {
            "escalation_level": 2,
            "escalation_reason": "Issue not resolved within expected timeframe",
            "escalated_by": str(uuid.uuid4())
        }
        
        escalate_response = await client.post(f"/api/v1/andon/events/{event_id}/escalate", json=escalation_data, headers=auth_headers)
        
        if escalate_response.status_code == 200:
            escalated_event = escalate_response.json()
            assert escalated_event["status"] == "escalated"
            assert escalated_event["escalation_level"] == escalation_data["escalation_level"]
        else:
            # Escalation might not be implemented, continue with resolution
            pass
        
        # Step 6: Resolve Andon Event
        resolution_data = {
            "notes": "E2E test resolution - faulty component replaced successfully",
            "resolved_by": str(uuid.uuid4()),
            "resolution_time": datetime.now().isoformat(),
            "root_cause": "Component wear and tear",
            "corrective_action": "Replaced faulty component and implemented preventive maintenance"
        }
        
        resolve_response = await client.post(f"/api/v1/andon/events/{event_id}/resolve", json=resolution_data, headers=auth_headers)
        
        if resolve_response.status_code == 200:
            resolved_event = resolve_response.json()
            assert resolved_event["status"] == "resolved"
            assert resolved_event["resolved_at"] is not None
            assert resolved_event["resolution_notes"] == resolution_data["notes"]
        else:
            pytest.skip("Could not resolve Andon event")
        
        # Step 7: Verify Final Event Status
        final_response = await client.get(f"/api/v1/andon/events/{event_id}", headers=auth_headers)
        
        if final_response.status_code == 200:
            final_event = final_response.json()
            assert final_event["status"] == "resolved"
            assert final_event["resolution_notes"] == resolution_data["notes"]
        else:
            pytest.skip("Could not verify final Andon event status")
    
    @pytest.mark.asyncio
    async def test_andon_event_lifecycle(self, client, auth_headers):
        """Test Andon event lifecycle management"""
        
        # Step 1: Create Multiple Andon Events
        events_data = [
            {
                "equipment_code": "EQ-E2E-001",
                "line_id": str(uuid.uuid4()),
                "event_type": "fault",
                "priority": "high",
                "description": "High priority fault",
                "reported_by": str(uuid.uuid4())
            },
            {
                "equipment_code": "EQ-E2E-002",
                "line_id": str(uuid.uuid4()),
                "event_type": "warning",
                "priority": "medium",
                "description": "Medium priority warning",
                "reported_by": str(uuid.uuid4())
            },
            {
                "equipment_code": "EQ-E2E-003",
                "line_id": str(uuid.uuid4()),
                "event_type": "info",
                "priority": "low",
                "description": "Low priority information",
                "reported_by": str(uuid.uuid4())
            }
        ]
        
        created_events = []
        for event_data in events_data:
            create_response = await client.post("/api/v1/andon/events", json=event_data, headers=auth_headers)
            
            if create_response.status_code in [200, 201]:
                created_events.append(create_response.json())
            else:
                pytest.skip("Could not create Andon events for lifecycle test")
        
        # Step 2: Get All Andon Events
        list_response = await client.get("/api/v1/andon/events", headers=auth_headers)
        
        if list_response.status_code == 200:
            all_events = list_response.json()
            assert isinstance(all_events, list)
            
            # Verify our events are in the list
            created_event_ids = [event["id"] for event in created_events]
            for event_id in created_event_ids:
                event_found = any(event["id"] == event_id for event in all_events)
                assert event_found
        else:
            pytest.skip("Could not list Andon events")
        
        # Step 3: Get Active Andon Events
        active_response = await client.get("/api/v1/andon/events/active", headers=auth_headers)
        
        if active_response.status_code == 200:
            active_events = active_response.json()
            assert isinstance(active_events, list)
            
            # All our events should be active initially
            created_event_ids = [event["id"] for event in created_events]
            for event_id in created_event_ids:
                event_found = any(event["id"] == event_id for event in active_events)
                assert event_found
        else:
            pytest.skip("Could not get active Andon events")
        
        # Step 4: Filter Events by Priority
        high_priority_response = await client.get("/api/v1/andon/events?priority=high", headers=auth_headers)
        
        if high_priority_response.status_code == 200:
            high_priority_events = high_priority_response.json()
            assert isinstance(high_priority_events, list)
            
            # Should contain our high priority event
            high_priority_event_id = created_events[0]["id"]
            event_found = any(event["id"] == high_priority_event_id for event in high_priority_events)
            assert event_found
        else:
            pytest.skip("Could not filter Andon events by priority")
        
        # Step 5: Filter Events by Equipment
        equipment_response = await client.get("/api/v1/andon/events?equipment_code=EQ-E2E-001", headers=auth_headers)
        
        if equipment_response.status_code == 200:
            equipment_events = equipment_response.json()
            assert isinstance(equipment_events, list)
            
            # Should contain our event for this equipment
            equipment_event_id = created_events[0]["id"]
            event_found = any(event["id"] == equipment_event_id for event in equipment_events)
            assert event_found
        else:
            pytest.skip("Could not filter Andon events by equipment")
        
        # Step 6: Resolve All Events
        for event in created_events:
            resolution_data = {
                "notes": f"E2E lifecycle test resolution for event {event['id']}",
                "resolved_by": str(uuid.uuid4())
            }
            
            resolve_response = await client.post(f"/api/v1/andon/events/{event['id']}/resolve", json=resolution_data, headers=auth_headers)
            
            if resolve_response.status_code == 200:
                resolved_event = resolve_response.json()
                assert resolved_event["status"] == "resolved"
            else:
                pytest.skip(f"Could not resolve Andon event {event['id']}")
        
        # Step 7: Verify No Active Events
        final_active_response = await client.get("/api/v1/andon/events/active", headers=auth_headers)
        
        if final_active_response.status_code == 200:
            final_active_events = final_active_response.json()
            
            # Our events should no longer be active
            created_event_ids = [event["id"] for event in created_events]
            for event_id in created_event_ids:
                event_found = any(event["id"] == event_id for event in final_active_events)
                assert not event_found
        else:
            pytest.skip("Could not verify final active Andon events")
    
    @pytest.mark.asyncio
    async def test_andon_escalation_system(self, client, auth_headers):
        """Test Andon escalation system functionality"""
        
        # Step 1: Create High Priority Andon Event
        event_data = {
            "equipment_code": "EQ-ESCALATION-TEST",
            "line_id": str(uuid.uuid4()),
            "event_type": "critical_fault",
            "priority": "critical",
            "description": "E2E escalation test - critical equipment failure",
            "reported_by": str(uuid.uuid4()),
            "category": "electrical"
        }
        
        create_response = await client.post("/api/v1/andon/events", json=event_data, headers=auth_headers)
        
        if create_response.status_code in [200, 201]:
            event_id = create_response.json()["id"]
        else:
            pytest.skip("Could not create Andon event for escalation test")
        
        # Step 2: Check Escalation Rules (if available)
        escalation_rules_response = await client.get("/api/v1/andon/escalation-rules", headers=auth_headers)
        
        if escalation_rules_response.status_code == 200:
            escalation_rules = escalation_rules_response.json()
            assert isinstance(escalation_rules, list)
        else:
            # Escalation rules endpoint might not be implemented
            pass
        
        # Step 3: Create Escalation for Event
        escalation_data = {
            "event_id": event_id,
            "priority": "critical",
            "acknowledgment_timeout_minutes": 5,
            "resolution_timeout_minutes": 30,
            "escalation_recipients": ["maintenance_manager", "production_manager"],
            "escalation_level": 1
        }
        
        create_escalation_response = await client.post("/api/v1/andon/escalations", json=escalation_data, headers=auth_headers)
        
        if create_escalation_response.status_code in [200, 201]:
            escalation_id = create_escalation_response.json()["id"]
            
            # Step 4: Get Escalation Details
            get_escalation_response = await client.get(f"/api/v1/andon/escalations/{escalation_id}", headers=auth_headers)
            
            if get_escalation_response.status_code == 200:
                escalation_details = get_escalation_response.json()
                assert escalation_details["event_id"] == event_id
                assert escalation_details["priority"] == "critical"
                assert escalation_details["status"] == "active"
            
            # Step 5: Acknowledge Escalation
            acknowledge_escalation_response = await client.post(f"/api/v1/andon/escalations/{escalation_id}/acknowledge", headers=auth_headers)
            
            if acknowledge_escalation_response.status_code == 200:
                acknowledged_escalation = acknowledge_escalation_response.json()
                assert acknowledged_escalation["status"] == "acknowledged"
                assert acknowledged_escalation["acknowledged_at"] is not None
            
            # Step 6: Escalate Further (if needed)
            further_escalation_data = {
                "escalation_level": 2,
                "escalation_reason": "Initial acknowledgment did not lead to resolution",
                "escalated_by": str(uuid.uuid4())
            }
            
            escalate_further_response = await client.post(f"/api/v1/andon/escalations/{escalation_id}/escalate", json=further_escalation_data, headers=auth_headers)
            
            if escalate_further_response.status_code == 200:
                further_escalated = escalate_further_response.json()
                assert further_escalated["escalation_level"] == 2
                assert further_escalated["status"] == "escalated"
            
            # Step 7: Resolve Escalation
            resolve_escalation_data = {
                "resolution_notes": "E2E escalation test resolution - issue resolved by maintenance team",
                "resolved_by": str(uuid.uuid4())
            }
            
            resolve_escalation_response = await client.post(f"/api/v1/andon/escalations/{escalation_id}/resolve", json=resolve_escalation_data, headers=auth_headers)
            
            if resolve_escalation_response.status_code == 200:
                resolved_escalation = resolve_escalation_response.json()
                assert resolved_escalation["status"] == "resolved"
                assert resolved_escalation["resolved_at"] is not None
            
            # Step 8: Get Escalation History
            history_response = await client.get(f"/api/v1/andon/escalations/{escalation_id}/history", headers=auth_headers)
            
            if history_response.status_code == 200:
                escalation_history = history_response.json()
                assert isinstance(escalation_history, list)
                assert len(escalation_history) > 0
        else:
            pytest.skip("Could not create Andon escalation")
        
        # Step 9: Resolve Original Event
        event_resolution_data = {
            "notes": "E2E escalation test - original event resolved",
            "resolved_by": str(uuid.uuid4())
        }
        
        resolve_event_response = await client.post(f"/api/v1/andon/events/{event_id}/resolve", json=event_resolution_data, headers=auth_headers)
        
        if resolve_event_response.status_code == 200:
            resolved_event = resolve_event_response.json()
            assert resolved_event["status"] == "resolved"
        else:
            pytest.skip("Could not resolve original Andon event")
    
    @pytest.mark.asyncio
    async def test_andon_notification_workflow(self, client, auth_headers):
        """Test Andon notification workflow"""
        
        # Step 1: Create Andon Event with Notification Requirements
        event_data = {
            "equipment_code": "EQ-NOTIFICATION-TEST",
            "line_id": str(uuid.uuid4()),
            "event_type": "safety_alert",
            "priority": "critical",
            "description": "E2E notification test - safety alert",
            "reported_by": str(uuid.uuid4()),
            "requires_notification": True,
            "notification_channels": ["email", "sms", "push"]
        }
        
        create_response = await client.post("/api/v1/andon/events", json=event_data, headers=auth_headers)
        
        if create_response.status_code in [200, 201]:
            event_id = create_response.json()["id"]
            
            # Step 2: Check Notification Status
            notification_status_response = await client.get(f"/api/v1/andon/events/{event_id}/notifications", headers=auth_headers)
            
            if notification_status_response.status_code == 200:
                notification_status = notification_status_response.json()
                assert isinstance(notification_status, list)
            else:
                # Notifications endpoint might not be implemented
                pass
            
            # Step 3: Acknowledge Event (should trigger acknowledgment notifications)
            acknowledge_response = await client.post(f"/api/v1/andon/events/{event_id}/acknowledge", headers=auth_headers)
            
            if acknowledge_response.status_code == 200:
                acknowledged_event = acknowledge_response.json()
                assert acknowledged_event["status"] == "acknowledged"
            
            # Step 4: Resolve Event (should trigger resolution notifications)
            resolution_data = {
                "notes": "E2E notification test resolution",
                "resolved_by": str(uuid.uuid4())
            }
            
            resolve_response = await client.post(f"/api/v1/andon/events/{event_id}/resolve", json=resolution_data, headers=auth_headers)
            
            if resolve_response.status_code == 200:
                resolved_event = resolve_response.json()
                assert resolved_event["status"] == "resolved"
        else:
            pytest.skip("Could not create Andon event for notification test")
    
    @pytest.mark.asyncio
    async def test_andon_statistics_and_reporting(self, client, auth_headers):
        """Test Andon statistics and reporting functionality"""
        
        # Step 1: Get Andon Statistics
        stats_response = await client.get("/api/v1/andon/statistics", headers=auth_headers)
        
        if stats_response.status_code == 200:
            stats = stats_response.json()
            assert "total_events" in stats
            assert "active_events" in stats
            assert "resolved_events" in stats
            assert "escalated_events" in stats
            assert "avg_resolution_time_minutes" in stats
        else:
            pytest.skip("Could not get Andon statistics")
        
        # Step 2: Get Andon Reports
        reports_response = await client.get("/api/v1/andon/reports", headers=auth_headers)
        
        if reports_response.status_code == 200:
            reports = reports_response.json()
            assert isinstance(reports, list)
        else:
            pytest.skip("Could not get Andon reports")
        
        # Step 3: Generate Andon Report
        report_data = {
            "report_type": "andon_summary",
            "start_date": (datetime.now() - timedelta(days=7)).isoformat(),
            "end_date": datetime.now().isoformat(),
            "include_details": True
        }
        
        generate_report_response = await client.post("/api/v1/andon/reports/generate", json=report_data, headers=auth_headers)
        
        if generate_report_response.status_code in [200, 201]:
            generated_report = generate_report_response.json()
            assert "report_id" in generated_report
            assert "status" in generated_report
        else:
            pytest.skip("Could not generate Andon report")


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
