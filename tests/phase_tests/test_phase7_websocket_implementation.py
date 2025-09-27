#!/usr/bin/env python3
"""
MS5.0 Floor Dashboard - Phase 7 WebSocket Implementation Test Suite

This test suite validates the Phase 7 WebSocket implementation including:
- WebSocket manager functionality
- Event broadcasting methods
- Authentication and connection management
- Real-time updates and message handling
"""

import os
import sys
import json
import asyncio
import inspect
from pathlib import Path
from typing import Dict, List, Any, Optional

# Add the backend directory to the Python path
backend_path = Path(__file__).parent / "backend"
sys.path.insert(0, str(backend_path))

def test_websocket_manager_file_structure():
    """Test that the WebSocket manager file exists and has correct structure."""
    print("Testing WebSocket manager file structure...")
    
    websocket_manager_path = backend_path / "app" / "services" / "websocket_manager.py"
    assert websocket_manager_path.exists(), f"WebSocket manager file not found at {websocket_manager_path}"
    
    with open(websocket_manager_path, 'r') as f:
        content = f.read()
    
    # Check for required class
    assert "class WebSocketManager:" in content, "WebSocketManager class not found"
    
    # Check for required methods as specified in Phase 7
    required_methods = [
        "add_connection",
        "remove_connection", 
        "subscribe_to_line",
        "subscribe_to_equipment",
        "subscribe_to_job",
        "subscribe_to_production_events",
        "subscribe_to_oee_updates",
        "subscribe_to_downtime_events",
        "subscribe_to_andon_events",
        "subscribe_to_escalation_events",
        "subscribe_to_quality_alerts",
        "subscribe_to_changeover_events",
        "broadcast_line_status_update",
        "broadcast_production_update",
        "broadcast_andon_event",
        "broadcast_oee_update",
        "broadcast_downtime_event",
        "broadcast_job_assigned",
        "broadcast_job_started",
        "broadcast_job_completed",
        "broadcast_job_cancelled",
        "broadcast_escalation_update",
        "broadcast_quality_alert",
        "broadcast_changeover_started",
        "broadcast_changeover_completed",
        "get_connection_stats",
        "get_subscription_details"
    ]
    
    for method in required_methods:
        assert f"def {method}" in content, f"Required method {method} not found in WebSocketManager"
    
    print("✅ WebSocket manager file structure test passed")
    return True


def test_websocket_endpoint_structure():
    """Test that the WebSocket endpoint file has correct structure."""
    print("Testing WebSocket endpoint file structure...")
    
    websocket_endpoint_path = backend_path / "app" / "api" / "websocket.py"
    assert websocket_endpoint_path.exists(), f"WebSocket endpoint file not found at {websocket_endpoint_path}"
    
    with open(websocket_endpoint_path, 'r') as f:
        content = f.read()
    
    # Check for required imports
    assert "from app.services.websocket_manager import websocket_manager" in content, "WebSocket manager import not found"
    
    # Check for required functions
    required_functions = [
        "authenticate_websocket",
        "websocket_endpoint",
        "handle_websocket_message",
        "handle_subscribe_message",
        "handle_unsubscribe_message",
        "handle_ping_message",
        "broadcast_line_status_update",
        "broadcast_production_update",
        "broadcast_andon_event",
        "broadcast_oee_update",
        "broadcast_downtime_event",
        "broadcast_job_assigned",
        "broadcast_job_started",
        "broadcast_job_completed",
        "broadcast_job_cancelled",
        "broadcast_escalation_update",
        "broadcast_quality_alert",
        "broadcast_changeover_started",
        "broadcast_changeover_completed",
        "websocket_health"
    ]
    
    for function in required_functions:
        assert f"async def {function}" in content or f"def {function}" in content, f"Required function {function} not found"
    
    print("✅ WebSocket endpoint file structure test passed")
    return True


def test_websocket_manager_import():
    """Test that the WebSocket manager can be imported successfully."""
    print("Testing WebSocket manager import...")
    
    try:
        from app.services.websocket_manager import WebSocketManager, websocket_manager
        assert WebSocketManager is not None, "WebSocketManager class not imported"
        assert websocket_manager is not None, "websocket_manager instance not imported"
        print("✅ WebSocket manager import test passed")
        return True
    except ImportError as e:
        print(f"❌ WebSocket manager import failed: {e}")
        return False
    except Exception as e:
        print(f"❌ WebSocket manager import error: {e}")
        return False


def test_websocket_endpoint_import():
    """Test that the WebSocket endpoint can be imported successfully."""
    print("Testing WebSocket endpoint import...")
    
    try:
        from app.api.websocket import router, authenticate_websocket, websocket_endpoint
        assert router is not None, "WebSocket router not imported"
        assert authenticate_websocket is not None, "authenticate_websocket function not imported"
        assert websocket_endpoint is not None, "websocket_endpoint function not imported"
        print("✅ WebSocket endpoint import test passed")
        return True
    except ImportError as e:
        print(f"❌ WebSocket endpoint import failed: {e}")
        return False
    except Exception as e:
        print(f"❌ WebSocket endpoint import error: {e}")
        return False


def test_websocket_manager_methods():
    """Test that WebSocket manager has all required methods with correct signatures."""
    print("Testing WebSocket manager methods...")
    
    try:
        from app.services.websocket_manager import WebSocketManager
        
        # Create an instance
        manager = WebSocketManager()
        
        # Test required methods exist
        required_methods = [
            "add_connection",
            "remove_connection",
            "subscribe_to_line",
            "subscribe_to_equipment",
            "subscribe_to_job",
            "subscribe_to_production_events",
            "subscribe_to_oee_updates",
            "subscribe_to_downtime_events",
            "subscribe_to_andon_events",
            "subscribe_to_escalation_events",
            "subscribe_to_quality_alerts",
            "subscribe_to_changeover_events",
            "unsubscribe_from_line",
            "unsubscribe_from_equipment",
            "unsubscribe_from_job",
            "unsubscribe_from_production_events",
            "unsubscribe_from_oee_updates",
            "unsubscribe_from_downtime_events",
            "unsubscribe_from_andon_events",
            "unsubscribe_from_escalation_events",
            "unsubscribe_from_quality_alerts",
            "unsubscribe_from_changeover_events",
            "send_personal_message",
            "send_to_user",
            "send_to_line",
            "send_to_equipment",
            "send_to_job",
            "send_to_production_subscribers",
            "send_to_oee_subscribers",
            "send_to_downtime_subscribers",
            "send_to_andon_subscribers",
            "send_to_escalation_subscribers",
            "send_to_quality_subscribers",
            "send_to_changeover_subscribers",
            "broadcast",
            "broadcast_line_status_update",
            "broadcast_production_update",
            "broadcast_andon_event",
            "broadcast_oee_update",
            "broadcast_downtime_event",
            "broadcast_job_assigned",
            "broadcast_job_started",
            "broadcast_job_completed",
            "broadcast_job_cancelled",
            "broadcast_escalation_update",
            "broadcast_quality_alert",
            "broadcast_changeover_started",
            "broadcast_changeover_completed",
            "get_connection_stats",
            "get_subscription_details"
        ]
        
        for method_name in required_methods:
            assert hasattr(manager, method_name), f"Method {method_name} not found in WebSocketManager"
            method = getattr(manager, method_name)
            assert callable(method), f"Method {method_name} is not callable"
        
        print("✅ WebSocket manager methods test passed")
        return True
    except Exception as e:
        print(f"❌ WebSocket manager methods test failed: {e}")
        return False


def test_websocket_manager_production_events():
    """Test that WebSocket manager has production events defined."""
    print("Testing WebSocket manager production events...")
    
    try:
        from app.services.websocket_manager import WebSocketManager
        
        manager = WebSocketManager()
        
        # Check that PRODUCTION_EVENTS is defined
        assert hasattr(manager, 'PRODUCTION_EVENTS'), "PRODUCTION_EVENTS not found in WebSocketManager"
        
        production_events = manager.PRODUCTION_EVENTS
        assert isinstance(production_events, dict), "PRODUCTION_EVENTS should be a dictionary"
        
        # Check for required event types as specified in Phase 7
        required_events = [
            "line_status_update",
            "production_update", 
            "andon_event",
            "oee_update",
            "downtime_event",
            "job_assigned",
            "job_started",
            "job_completed",
            "job_cancelled",
            "escalation_update",
            "quality_alert",
            "changeover_started",
            "changeover_completed"
        ]
        
        for event_type in required_events:
            assert event_type in production_events, f"Required event type {event_type} not found in PRODUCTION_EVENTS"
        
        print("✅ WebSocket manager production events test passed")
        return True
    except Exception as e:
        print(f"❌ WebSocket manager production events test failed: {e}")
        return False


def test_websocket_manager_subscription_types():
    """Test that WebSocket manager has all required subscription types."""
    print("Testing WebSocket manager subscription types...")
    
    try:
        from app.services.websocket_manager import WebSocketManager
        
        manager = WebSocketManager()
        
        # Check for required subscription dictionaries
        required_subscriptions = [
            "line_subscriptions",
            "equipment_subscriptions",
            "job_subscriptions",
            "production_subscriptions",
            "oee_subscriptions",
            "downtime_subscriptions",
            "andon_subscriptions",
            "escalation_subscriptions",
            "quality_subscriptions",
            "changeover_subscriptions"
        ]
        
        for subscription_type in required_subscriptions:
            assert hasattr(manager, subscription_type), f"Subscription type {subscription_type} not found"
            subscription_dict = getattr(manager, subscription_type)
            assert isinstance(subscription_dict, dict), f"Subscription type {subscription_type} should be a dictionary"
        
        print("✅ WebSocket manager subscription types test passed")
        return True
    except Exception as e:
        print(f"❌ WebSocket manager subscription types test failed: {e}")
        return False


def test_websocket_broadcasting_functions():
    """Test that all broadcasting functions exist and are callable."""
    print("Testing WebSocket broadcasting functions...")
    
    try:
        from app.api.websocket import (
            broadcast_line_status_update,
            broadcast_production_update,
            broadcast_andon_event,
            broadcast_oee_update,
            broadcast_downtime_event,
            broadcast_job_assigned,
            broadcast_job_started,
            broadcast_job_completed,
            broadcast_job_cancelled,
            broadcast_escalation_update,
            broadcast_quality_alert,
            broadcast_changeover_started,
            broadcast_changeover_completed
        )
        
        # Test that all functions are callable
        broadcasting_functions = [
            broadcast_line_status_update,
            broadcast_production_update,
            broadcast_andon_event,
            broadcast_oee_update,
            broadcast_downtime_event,
            broadcast_job_assigned,
            broadcast_job_started,
            broadcast_job_completed,
            broadcast_job_cancelled,
            broadcast_escalation_update,
            broadcast_quality_alert,
            broadcast_changeover_started,
            broadcast_changeover_completed
        ]
        
        for func in broadcasting_functions:
            assert callable(func), f"Broadcasting function {func.__name__} is not callable"
            # Check that it's an async function
            assert asyncio.iscoroutinefunction(func), f"Broadcasting function {func.__name__} should be async"
        
        print("✅ WebSocket broadcasting functions test passed")
        return True
    except ImportError as e:
        print(f"❌ WebSocket broadcasting functions import failed: {e}")
        return False
    except Exception as e:
        print(f"❌ WebSocket broadcasting functions test failed: {e}")
        return False


def test_websocket_authentication():
    """Test that WebSocket authentication function exists and has correct signature."""
    print("Testing WebSocket authentication...")
    
    try:
        from app.api.websocket import authenticate_websocket
        
        # Check function signature
        sig = inspect.signature(authenticate_websocket)
        params = list(sig.parameters.keys())
        
        # Should have websocket and token parameters
        assert "websocket" in params, "authenticate_websocket should have websocket parameter"
        assert "token" in params, "authenticate_websocket should have token parameter"
        
        # Should be async
        assert asyncio.iscoroutinefunction(authenticate_websocket), "authenticate_websocket should be async"
        
        print("✅ WebSocket authentication test passed")
        return True
    except ImportError as e:
        print(f"❌ WebSocket authentication import failed: {e}")
        return False
    except Exception as e:
        print(f"❌ WebSocket authentication test failed: {e}")
        return False


def test_websocket_endpoint_function():
    """Test that WebSocket endpoint function exists and has correct signature."""
    print("Testing WebSocket endpoint function...")
    
    try:
        from app.api.websocket import websocket_endpoint
        
        # Check function signature
        sig = inspect.signature(websocket_endpoint)
        params = list(sig.parameters.keys())
        
        # Should have websocket and token parameters
        assert "websocket" in params, "websocket_endpoint should have websocket parameter"
        assert "token" in params, "websocket_endpoint should have token parameter"
        
        # Should be async
        assert asyncio.iscoroutinefunction(websocket_endpoint), "websocket_endpoint should be async"
        
        print("✅ WebSocket endpoint function test passed")
        return True
    except ImportError as e:
        print(f"❌ WebSocket endpoint function import failed: {e}")
        return False
    except Exception as e:
        print(f"❌ WebSocket endpoint function test failed: {e}")
        return False


def test_websocket_message_handlers():
    """Test that WebSocket message handlers exist and are callable."""
    print("Testing WebSocket message handlers...")
    
    try:
        from app.api.websocket import (
            handle_websocket_message,
            handle_subscribe_message,
            handle_unsubscribe_message,
            handle_ping_message
        )
        
        handlers = [
            handle_websocket_message,
            handle_subscribe_message,
            handle_unsubscribe_message,
            handle_ping_message
        ]
        
        for handler in handlers:
            assert callable(handler), f"Message handler {handler.__name__} is not callable"
            assert asyncio.iscoroutinefunction(handler), f"Message handler {handler.__name__} should be async"
        
        print("✅ WebSocket message handlers test passed")
        return True
    except ImportError as e:
        print(f"❌ WebSocket message handlers import failed: {e}")
        return False
    except Exception as e:
        print(f"❌ WebSocket message handlers test failed: {e}")
        return False


def test_websocket_health_endpoint():
    """Test that WebSocket health endpoint exists and is callable."""
    print("Testing WebSocket health endpoint...")
    
    try:
        from app.api.websocket import websocket_health
        
        assert callable(websocket_health), "websocket_health should be callable"
        assert asyncio.iscoroutinefunction(websocket_health), "websocket_health should be async"
        
        print("✅ WebSocket health endpoint test passed")
        return True
    except ImportError as e:
        print(f"❌ WebSocket health endpoint import failed: {e}")
        return False
    except Exception as e:
        print(f"❌ WebSocket health endpoint test failed: {e}")
        return False


def test_websocket_manager_global_instance():
    """Test that global WebSocket manager instance exists and is accessible."""
    print("Testing WebSocket manager global instance...")
    
    try:
        from app.services.websocket_manager import websocket_manager
        from app.api.websocket import websocket_manager as endpoint_manager
        
        # Both should be the same instance
        assert websocket_manager is endpoint_manager, "WebSocket manager instances should be the same"
        
        # Check that it's a WebSocketManager instance
        from app.services.websocket_manager import WebSocketManager
        assert isinstance(websocket_manager, WebSocketManager), "websocket_manager should be a WebSocketManager instance"
        
        print("✅ WebSocket manager global instance test passed")
        return True
    except ImportError as e:
        print(f"❌ WebSocket manager global instance import failed: {e}")
        return False
    except Exception as e:
        print(f"❌ WebSocket manager global instance test failed: {e}")
        return False


def test_websocket_manager_initialization():
    """Test that WebSocket manager initializes correctly with all required attributes."""
    print("Testing WebSocket manager initialization...")
    
    try:
        from app.services.websocket_manager import WebSocketManager
        
        manager = WebSocketManager()
        
        # Check required attributes
        required_attributes = [
            "connections",
            "user_connections",
            "subscriptions",
            "line_subscriptions",
            "equipment_subscriptions",
            "job_subscriptions",
            "production_subscriptions",
            "oee_subscriptions",
            "downtime_subscriptions",
            "andon_subscriptions",
            "escalation_subscriptions",
            "quality_subscriptions",
            "changeover_subscriptions",
            "PRODUCTION_EVENTS"
        ]
        
        for attr in required_attributes:
            assert hasattr(manager, attr), f"Required attribute {attr} not found in WebSocketManager"
        
        # Check that subscription dictionaries are empty initially
        subscription_attrs = [
            "connections", "user_connections", "subscriptions",
            "line_subscriptions", "equipment_subscriptions", "job_subscriptions",
            "production_subscriptions", "oee_subscriptions", "downtime_subscriptions",
            "andon_subscriptions", "escalation_subscriptions", "quality_subscriptions",
            "changeover_subscriptions"
        ]
        
        for attr in subscription_attrs:
            value = getattr(manager, attr)
            if attr == "PRODUCTION_EVENTS":
                continue  # Skip PRODUCTION_EVENTS as it should have content
            assert isinstance(value, dict), f"Attribute {attr} should be a dictionary"
            assert len(value) == 0, f"Attribute {attr} should be empty initially"
        
        print("✅ WebSocket manager initialization test passed")
        return True
    except Exception as e:
        print(f"❌ WebSocket manager initialization test failed: {e}")
        return False


def test_phase7_implementation_completeness():
    """Test that Phase 7 implementation is complete according to the plan."""
    print("Testing Phase 7 implementation completeness...")
    
    try:
        # Test that all Phase 7 requirements are met
        from app.services.websocket_manager import WebSocketManager
        from app.api.websocket import (
            authenticate_websocket, websocket_endpoint,
            broadcast_line_status_update, broadcast_production_update,
            broadcast_andon_event, broadcast_oee_update, broadcast_downtime_event
        )
        
        manager = WebSocketManager()
        
        # Test Phase 7.1: Complete WebSocket Event Types
        required_broadcast_methods = [
            "broadcast_line_status_update",
            "broadcast_production_update", 
            "broadcast_andon_event",
            "broadcast_oee_update",
            "broadcast_downtime_event"
        ]
        
        for method in required_broadcast_methods:
            assert hasattr(manager, method), f"Phase 7.1: Required broadcast method {method} not found"
        
        # Test Phase 7.2: WebSocket Authentication
        assert authenticate_websocket is not None, "Phase 7.2: WebSocket authentication not implemented"
        assert websocket_endpoint is not None, "Phase 7.2: WebSocket endpoint not implemented"
        
        # Test that all required broadcasting functions exist
        assert broadcast_line_status_update is not None, "broadcast_line_status_update not found"
        assert broadcast_production_update is not None, "broadcast_production_update not found"
        assert broadcast_andon_event is not None, "broadcast_andon_event not found"
        assert broadcast_oee_update is not None, "broadcast_oee_update not found"
        assert broadcast_downtime_event is not None, "broadcast_downtime_event not found"
        
        print("✅ Phase 7 implementation completeness test passed")
        return True
    except Exception as e:
        print(f"❌ Phase 7 implementation completeness test failed: {e}")
        return False


def run_all_tests():
    """Run all Phase 7 WebSocket implementation tests."""
    print("=" * 80)
    print("MS5.0 Floor Dashboard - Phase 7 WebSocket Implementation Test Suite")
    print("=" * 80)
    
    tests = [
        test_websocket_manager_file_structure,
        test_websocket_endpoint_structure,
        test_websocket_manager_import,
        test_websocket_endpoint_import,
        test_websocket_manager_methods,
        test_websocket_manager_production_events,
        test_websocket_manager_subscription_types,
        test_websocket_broadcasting_functions,
        test_websocket_authentication,
        test_websocket_endpoint_function,
        test_websocket_message_handlers,
        test_websocket_health_endpoint,
        test_websocket_manager_global_instance,
        test_websocket_manager_initialization,
        test_phase7_implementation_completeness
    ]
    
    passed = 0
    failed = 0
    
    for test in tests:
        try:
            if test():
                passed += 1
            else:
                failed += 1
        except Exception as e:
            print(f"❌ Test {test.__name__} failed with exception: {e}")
            failed += 1
        print()
    
    print("=" * 80)
    print(f"Test Results: {passed} passed, {failed} failed")
    print("=" * 80)
    
    if failed == 0:
        print("🎉 All Phase 7 WebSocket implementation tests passed!")
        return True
    else:
        print(f"❌ {failed} tests failed. Please review the implementation.")
        return False


if __name__ == "__main__":
    success = run_all_tests()
    sys.exit(0 if success else 1)
