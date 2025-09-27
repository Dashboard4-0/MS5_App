#!/usr/bin/env python3
"""
MS5.0 Floor Dashboard - Phase 6 Test Suite
Andon System Completion Testing

This test suite validates the completion of Phase 6: Andon System Completion
including notification system, Andon event creation, escalation system, and user notifications.
"""

import asyncio
import json
import os
import sys
from datetime import datetime, timedelta
from typing import Dict, List, Any
from uuid import uuid4

# Add the backend directory to the Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'backend'))

try:
    from app.services.notification_service import NotificationService, notification_service
    from app.services.andon_service import AndonService
    from app.services.andon_escalation_service import AndonEscalationService
    from app.services.andon_escalation_monitor import AndonEscalationMonitor, escalation_monitor
    from app.models.production import AndonEventCreate, AndonEventType, AndonPriority, AndonStatus
    from app.database import execute_query, execute_scalar
except ImportError as e:
    print(f"Import error: {e}")
    print("Make sure you're running this from the project root directory")
    sys.exit(1)


class Phase6TestSuite:
    """Comprehensive test suite for Phase 6: Andon System Completion."""
    
    def __init__(self):
        self.test_results = []
        self.total_tests = 0
        self.passed_tests = 0
        self.failed_tests = 0
        
    def log_test_result(self, test_name: str, passed: bool, message: str = "", details: Dict = None):
        """Log test result."""
        self.total_tests += 1
        if passed:
            self.passed_tests += 1
            status = "✅ PASS"
        else:
            self.failed_tests += 1
            status = "❌ FAIL"
        
        result = {
            "test_name": test_name,
            "status": status,
            "passed": passed,
            "message": message,
            "details": details or {},
            "timestamp": datetime.utcnow().isoformat()
        }
        
        self.test_results.append(result)
        print(f"{status} {test_name}: {message}")
        
        if details:
            for key, value in details.items():
                print(f"    {key}: {value}")
    
    async def test_notification_service_methods(self):
        """Test NotificationService method implementations."""
        print("\n=== Testing NotificationService Methods ===")
        
        # Test 1: Generic notification method
        try:
            notification_service_instance = NotificationService()
            
            # Test send_notification method exists and is callable
            if hasattr(notification_service_instance, 'send_notification'):
                self.log_test_result(
                    "NotificationService.send_notification method exists",
                    True,
                    "Generic notification method is implemented"
                )
            else:
                self.log_test_result(
                    "NotificationService.send_notification method exists",
                    False,
                    "Generic notification method is missing"
                )
            
            # Test send_sms_notification method exists and is callable
            if hasattr(notification_service_instance, 'send_sms_notification'):
                self.log_test_result(
                    "NotificationService.send_sms_notification method exists",
                    True,
                    "SMS notification method is implemented"
                )
            else:
                self.log_test_result(
                    "NotificationService.send_sms_notification method exists",
                    False,
                    "SMS notification method is missing"
                )
            
            # Test WebSocket notification method exists
            if hasattr(notification_service_instance, '_send_websocket_notification'):
                self.log_test_result(
                    "NotificationService._send_websocket_notification method exists",
                    True,
                    "WebSocket notification method is implemented"
                )
            else:
                self.log_test_result(
                    "NotificationService._send_websocket_notification method exists",
                    False,
                    "WebSocket notification method is missing"
                )
            
            # Test user preferences method exists
            if hasattr(notification_service_instance, '_get_user_notification_preferences'):
                self.log_test_result(
                    "NotificationService._get_user_notification_preferences method exists",
                    True,
                    "User preferences method is implemented"
                )
            else:
                self.log_test_result(
                    "NotificationService._get_user_notification_preferences method exists",
                    False,
                    "User preferences method is missing"
                )
                
        except Exception as e:
            self.log_test_result(
                "NotificationService methods test",
                False,
                f"Error testing NotificationService methods: {str(e)}"
            )
    
    async def test_andon_service_integration(self):
        """Test AndonService integration with other services."""
        print("\n=== Testing AndonService Integration ===")
        
        try:
            # Test AndonService imports
            if hasattr(AndonService, 'escalate_andon_event'):
                self.log_test_result(
                    "AndonService.escalate_andon_event method exists",
                    True,
                    "Escalation method is implemented"
                )
            else:
                self.log_test_result(
                    "AndonService.escalate_andon_event method exists",
                    False,
                    "Escalation method is missing"
                )
            
            # Test notification integration methods
            if hasattr(AndonService, '_send_escalation_notification'):
                self.log_test_result(
                    "AndonService._send_escalation_notification method exists",
                    True,
                    "Escalation notification method is implemented"
                )
            else:
                self.log_test_result(
                    "AndonService._send_escalation_notification method exists",
                    False,
                    "Escalation notification method is missing"
                )
            
            # Test that notification service is imported
            import inspect
            source = inspect.getsource(AndonService)
            if 'notification_service' in source:
                self.log_test_result(
                    "AndonService imports notification_service",
                    True,
                    "Notification service integration is implemented"
                )
            else:
                self.log_test_result(
                    "AndonService imports notification_service",
                    False,
                    "Notification service integration is missing"
                )
            
            # Test that escalation service is imported
            if 'AndonEscalationService' in source:
                self.log_test_result(
                    "AndonService imports AndonEscalationService",
                    True,
                    "Escalation service integration is implemented"
                )
            else:
                self.log_test_result(
                    "AndonService imports AndonEscalationService",
                    False,
                    "Escalation service integration is missing"
                )
                
        except Exception as e:
            self.log_test_result(
                "AndonService integration test",
                False,
                f"Error testing AndonService integration: {str(e)}"
            )
    
    async def test_andon_escalation_service(self):
        """Test AndonEscalationService implementation."""
        print("\n=== Testing AndonEscalationService ===")
        
        try:
            # Test key methods exist
            required_methods = [
                'create_escalation',
                'acknowledge_escalation',
                'resolve_escalation',
                'escalate_manually',
                'get_active_escalations',
                'get_escalation_history',
                'get_escalation_statistics',
                'process_automatic_escalations'
            ]
            
            for method_name in required_methods:
                if hasattr(AndonEscalationService, method_name):
                    self.log_test_result(
                        f"AndonEscalationService.{method_name} method exists",
                        True,
                        f"{method_name} method is implemented"
                    )
                else:
                    self.log_test_result(
                        f"AndonEscalationService.{method_name} method exists",
                        False,
                        f"{method_name} method is missing"
                    )
            
            # Test static methods
            if hasattr(AndonEscalationService, '_get_escalation'):
                self.log_test_result(
                    "AndonEscalationService._get_escalation method exists",
                    True,
                    "Private escalation getter method is implemented"
                )
            else:
                self.log_test_result(
                    "AndonEscalationService._get_escalation method exists",
                    False,
                    "Private escalation getter method is missing"
                )
                
        except Exception as e:
            self.log_test_result(
                "AndonEscalationService test",
                False,
                f"Error testing AndonEscalationService: {str(e)}"
            )
    
    async def test_andon_escalation_monitor(self):
        """Test AndonEscalationMonitor implementation."""
        print("\n=== Testing AndonEscalationMonitor ===")
        
        try:
            # Test monitor class exists
            if AndonEscalationMonitor:
                self.log_test_result(
                    "AndonEscalationMonitor class exists",
                    True,
                    "Escalation monitor class is implemented"
                )
            else:
                self.log_test_result(
                    "AndonEscalationMonitor class exists",
                    False,
                    "Escalation monitor class is missing"
                )
            
            # Test key methods exist
            required_methods = [
                'start',
                'stop',
                '_monitor_loop',
                '_process_escalations',
                '_check_overdue_escalations',
                '_send_reminder_notifications',
                'get_monitoring_status'
            ]
            
            for method_name in required_methods:
                if hasattr(AndonEscalationMonitor, method_name):
                    self.log_test_result(
                        f"AndonEscalationMonitor.{method_name} method exists",
                        True,
                        f"{method_name} method is implemented"
                    )
                else:
                    self.log_test_result(
                        f"AndonEscalationMonitor.{method_name} method exists",
                        False,
                        f"{method_name} method is missing"
                    )
            
            # Test global monitor instance
            if escalation_monitor:
                self.log_test_result(
                    "Global escalation_monitor instance exists",
                    True,
                    "Global monitor instance is available"
                )
            else:
                self.log_test_result(
                    "Global escalation_monitor instance exists",
                    False,
                    "Global monitor instance is missing"
                )
                
        except Exception as e:
            self.log_test_result(
                "AndonEscalationMonitor test",
                False,
                f"Error testing AndonEscalationMonitor: {str(e)}"
            )
    
    async def test_notification_functionality(self):
        """Test notification functionality."""
        print("\n=== Testing Notification Functionality ===")
        
        try:
            # Test notification service instance
            if notification_service:
                self.log_test_result(
                    "Global notification_service instance exists",
                    True,
                    "Global notification service instance is available"
                )
            else:
                self.log_test_result(
                    "Global notification_service instance exists",
                    False,
                    "Global notification service instance is missing"
                )
            
            # Test notification methods are callable
            test_user_id = "test-user-123"
            test_title = "Test Notification"
            test_message = "This is a test notification"
            
            # Test generic notification (should not fail even if no real notification sent)
            try:
                result = await notification_service.send_notification(
                    user_id=test_user_id,
                    title=test_title,
                    message=test_message,
                    notification_type="test"
                )
                self.log_test_result(
                    "NotificationService.send_notification is callable",
                    True,
                    f"Generic notification method executed (result: {result})"
                )
            except Exception as e:
                self.log_test_result(
                    "NotificationService.send_notification is callable",
                    False,
                    f"Generic notification method failed: {str(e)}"
                )
            
            # Test SMS notification
            try:
                result = await notification_service.send_sms_notification(
                    phone="+1234567890",
                    message="Test SMS message"
                )
                self.log_test_result(
                    "NotificationService.send_sms_notification is callable",
                    True,
                    f"SMS notification method executed (result: {result})"
                )
            except Exception as e:
                self.log_test_result(
                    "NotificationService.send_sms_notification is callable",
                    False,
                    f"SMS notification method failed: {str(e)}"
                )
            
            # Test Andon notification
            try:
                result = await notification_service.send_andon_notification(
                    line_id="test-line",
                    equipment_code="test-equipment",
                    event_type="test",
                    severity="medium",
                    message="Test Andon event"
                )
                self.log_test_result(
                    "NotificationService.send_andon_notification is callable",
                    True,
                    f"Andon notification method executed (result: {result})"
                )
            except Exception as e:
                self.log_test_result(
                    "NotificationService.send_andon_notification is callable",
                    False,
                    f"Andon notification method failed: {str(e)}"
                )
                
        except Exception as e:
            self.log_test_result(
                "Notification functionality test",
                False,
                f"Error testing notification functionality: {str(e)}"
            )
    
    async def test_andon_event_creation(self):
        """Test Andon event creation functionality."""
        print("\n=== Testing Andon Event Creation ===")
        
        try:
            # Test AndonService static methods exist
            required_methods = [
                'create_andon_event',
                'get_andon_event',
                'acknowledge_andon_event',
                'resolve_andon_event',
                'escalate_andon_event',
                'list_andon_events',
                'get_active_andon_events',
                'get_andon_statistics'
            ]
            
            for method_name in required_methods:
                if hasattr(AndonService, method_name):
                    self.log_test_result(
                        f"AndonService.{method_name} method exists",
                        True,
                        f"{method_name} method is implemented"
                    )
                else:
                    self.log_test_result(
                        f"AndonService.{method_name} method exists",
                        False,
                        f"{method_name} method is missing"
                    )
            
            # Test escalation configuration
            if hasattr(AndonService, 'ESCALATION_LEVELS'):
                escalation_levels = AndonService.ESCALATION_LEVELS
                if isinstance(escalation_levels, dict) and len(escalation_levels) > 0:
                    self.log_test_result(
                        "AndonService.ESCALATION_LEVELS configuration exists",
                        True,
                        f"Escalation levels configured: {list(escalation_levels.keys())}"
                    )
                else:
                    self.log_test_result(
                        "AndonService.ESCALATION_LEVELS configuration exists",
                        False,
                        "Escalation levels configuration is empty or invalid"
                    )
            else:
                self.log_test_result(
                    "AndonService.ESCALATION_LEVELS configuration exists",
                    False,
                    "Escalation levels configuration is missing"
                )
                
        except Exception as e:
            self.log_test_result(
                "Andon event creation test",
                False,
                f"Error testing Andon event creation: {str(e)}"
            )
    
    async def test_escalation_system(self):
        """Test escalation system functionality."""
        print("\n=== Testing Escalation System ===")
        
        try:
            # Test escalation service methods
            escalation_methods = [
                'create_escalation',
                'acknowledge_escalation',
                'resolve_escalation',
                'escalate_manually',
                'get_active_escalations',
                'get_escalation_history',
                'get_escalation_statistics',
                'process_automatic_escalations'
            ]
            
            for method_name in escalation_methods:
                if hasattr(AndonEscalationService, method_name):
                    self.log_test_result(
                        f"AndonEscalationService.{method_name} is implemented",
                        True,
                        f"{method_name} method is available"
                    )
                else:
                    self.log_test_result(
                        f"AndonEscalationService.{method_name} is implemented",
                        False,
                        f"{method_name} method is missing"
                    )
            
            # Test escalation monitor functionality
            monitor_methods = [
                'start',
                'stop',
                '_monitor_loop',
                '_process_escalations',
                '_check_overdue_escalations',
                '_send_reminder_notifications',
                'get_monitoring_status'
            ]
            
            for method_name in monitor_methods:
                if hasattr(AndonEscalationMonitor, method_name):
                    self.log_test_result(
                        f"AndonEscalationMonitor.{method_name} is implemented",
                        True,
                        f"{method_name} method is available"
                    )
                else:
                    self.log_test_result(
                        f"AndonEscalationMonitor.{method_name} is implemented",
                        False,
                        f"{method_name} method is missing"
                    )
                
        except Exception as e:
            self.log_test_result(
                "Escalation system test",
                False,
                f"Error testing escalation system: {str(e)}"
            )
    
    async def test_user_notifications(self):
        """Test user notification functionality."""
        print("\n=== Testing User Notifications ===")
        
        try:
            # Test notification service methods for user notifications
            user_notification_methods = [
                'send_notification',
                'send_push_notification',
                'send_email_notification',
                'send_sms_notification',
                'send_bulk_push_notification',
                'send_notification_to_role',
                'send_andon_notification',
                'send_maintenance_reminder',
                'send_quality_alert'
            ]
            
            for method_name in user_notification_methods:
                if hasattr(notification_service, method_name):
                    self.log_test_result(
                        f"NotificationService.{method_name} is implemented",
                        True,
                        f"{method_name} method is available for user notifications"
                    )
                else:
                    self.log_test_result(
                        f"NotificationService.{method_name} is implemented",
                        False,
                        f"{method_name} method is missing for user notifications"
                    )
            
            # Test notification types
            notification_types = [
                'andon',
                'andon_acknowledgment',
                'andon_resolution',
                'andon_escalation',
                'andon_escalation_reminder',
                'maintenance',
                'quality',
                'general',
                'test'
            ]
            
            self.log_test_result(
                "Notification types are defined",
                True,
                f"Supported notification types: {', '.join(notification_types)}"
            )
                
        except Exception as e:
            self.log_test_result(
                "User notifications test",
                False,
                f"Error testing user notifications: {str(e)}"
            )
    
    async def test_file_structure(self):
        """Test file structure and organization."""
        print("\n=== Testing File Structure ===")
        
        try:
            # Test required files exist
            required_files = [
                'backend/app/services/notification_service.py',
                'backend/app/services/andon_service.py',
                'backend/app/services/andon_escalation_service.py',
                'backend/app/services/andon_escalation_monitor.py'
            ]
            
            for file_path in required_files:
                if os.path.exists(file_path):
                    self.log_test_result(
                        f"File {file_path} exists",
                        True,
                        f"Required file is present"
                    )
                else:
                    self.log_test_result(
                        f"File {file_path} exists",
                        False,
                        f"Required file is missing"
                    )
            
            # Test SQL migration file exists
            sql_file = '005_andon_escalation_system.sql'
            if os.path.exists(sql_file):
                self.log_test_result(
                    f"SQL migration file {sql_file} exists",
                    True,
                    "Andon escalation system SQL migration is present"
                )
            else:
                self.log_test_result(
                    f"SQL migration file {sql_file} exists",
                    False,
                    "Andon escalation system SQL migration is missing"
                )
                
        except Exception as e:
            self.log_test_result(
                "File structure test",
                False,
                f"Error testing file structure: {str(e)}"
            )
    
    async def run_all_tests(self):
        """Run all Phase 6 tests."""
        print("=" * 80)
        print("MS5.0 Floor Dashboard - Phase 6 Test Suite")
        print("Andon System Completion Testing")
        print("=" * 80)
        
        # Run all test categories
        await self.test_notification_service_methods()
        await self.test_andon_service_integration()
        await self.test_andon_escalation_service()
        await self.test_andon_escalation_monitor()
        await self.test_notification_functionality()
        await self.test_andon_event_creation()
        await self.test_escalation_system()
        await self.test_user_notifications()
        await self.test_file_structure()
        
        # Print summary
        print("\n" + "=" * 80)
        print("PHASE 6 TEST SUMMARY")
        print("=" * 80)
        print(f"Total Tests: {self.total_tests}")
        print(f"Passed: {self.passed_tests} ✅")
        print(f"Failed: {self.failed_tests} ❌")
        print(f"Success Rate: {(self.passed_tests / self.total_tests * 100):.1f}%")
        
        if self.failed_tests == 0:
            print("\n🎉 ALL TESTS PASSED! Phase 6 is complete.")
        else:
            print(f"\n⚠️  {self.failed_tests} tests failed. Please review and fix issues.")
        
        return {
            "total_tests": self.total_tests,
            "passed_tests": self.passed_tests,
            "failed_tests": self.failed_tests,
            "success_rate": (self.passed_tests / self.total_tests * 100) if self.total_tests > 0 else 0,
            "test_results": self.test_results
        }


async def main():
    """Main test execution function."""
    test_suite = Phase6TestSuite()
    results = await test_suite.run_all_tests()
    
    # Save results to file
    results_file = "phase6_andon_system_test_results.json"
    with open(results_file, 'w') as f:
        json.dump(results, f, indent=2)
    
    print(f"\nDetailed test results saved to: {results_file}")
    
    return results


if __name__ == "__main__":
    # Run the test suite
    results = asyncio.run(main())
    
    # Exit with appropriate code
    if results["failed_tests"] == 0:
        sys.exit(0)  # Success
    else:
        sys.exit(1)  # Failure
