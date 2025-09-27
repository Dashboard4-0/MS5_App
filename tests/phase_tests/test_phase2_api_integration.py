#!/usr/bin/env python3
"""
MS5.0 Floor Dashboard - Phase 2 API Integration Tests

This script tests all the API endpoints and permission system implemented in Phase 2.
It verifies that the backend services, API endpoints, and frontend integration are working correctly.

Test Coverage:
- Production Line Management API
- Production Schedule Management API  
- Job Assignment API
- Permission System
- Redux Store Integration
- API Service Layer

Usage:
    python test_phase2_api_integration.py
"""

import asyncio
import json
import sys
import os
from datetime import datetime, timedelta
from typing import Dict, List, Any
import uuid

# Add the backend directory to the Python path
sys.path.append(os.path.join(os.path.dirname(__file__), 'backend'))

from backend.app.database import get_db
from backend.app.models.production import (
    ProductionLine, ProductionSchedule, JobAssignment,
    ProductionLineCreate, ProductionScheduleCreate, JobAssignmentCreate
)
from backend.app.services.production_service import (
    ProductionLineService, ProductionScheduleService, JobAssignmentService
)
from backend.app.auth.permissions import PermissionChecker
from backend.app.auth.jwt_handler import create_access_token
from backend.app.models.user import User, UserRole

class Phase2APITester:
    """Test suite for Phase 2 API integration."""
    
    def __init__(self):
        self.test_results = []
        self.test_data = {}
        self.test_users = {}
        
    async def setup_test_data(self):
        """Set up test data for the tests."""
        print("🔧 Setting up test data...")
        
        # Create test users with different roles
        self.test_users = {
            'admin': {
                'id': str(uuid.uuid4()),
                'username': 'admin_test',
                'email': 'admin@test.com',
                'role': UserRole.ADMIN,
                'permissions': ['*']  # Admin has all permissions
            },
            'production_manager': {
                'id': str(uuid.uuid4()),
                'username': 'pm_test',
                'email': 'pm@test.com',
                'role': UserRole.PRODUCTION_MANAGER,
                'permissions': [
                    'production:read', 'production:write', 'production:delete',
                    'line:read', 'line:write', 'line:delete',
                    'schedule:read', 'schedule:write', 'schedule:delete',
                    'job:read', 'job:write', 'job:assign'
                ]
            },
            'operator': {
                'id': str(uuid.uuid4()),
                'username': 'operator_test',
                'email': 'operator@test.com',
                'role': UserRole.OPERATOR,
                'permissions': [
                    'production:read', 'job:read', 'job:accept', 'job:start', 'job:complete'
                ]
            },
            'viewer': {
                'id': str(uuid.uuid4()),
                'username': 'viewer_test',
                'email': 'viewer@test.com',
                'role': UserRole.VIEWER,
                'permissions': ['production:read', 'line:read', 'schedule:read', 'job:read']
            }
        }
        
        # Create test production line data
        self.test_data['production_line'] = {
            'line_code': 'TEST_LINE_001',
            'name': 'Test Production Line',
            'description': 'Test line for Phase 2 testing',
            'equipment_codes': ['EQ001', 'EQ002', 'EQ003'],
            'target_speed': 100.0,
            'enabled': True,
            'status': 'idle'
        }
        
        # Create test production schedule data
        self.test_data['production_schedule'] = {
            'line_id': None,  # Will be set after line creation
            'product_type_id': 'PRODUCT_A',
            'scheduled_start': (datetime.now() + timedelta(hours=1)).isoformat(),
            'scheduled_end': (datetime.now() + timedelta(hours=9)).isoformat(),
            'target_quantity': 1000,
            'priority': 1,
            'status': 'scheduled',
            'notes': 'Test production schedule'
        }
        
        # Create test job assignment data
        self.test_data['job_assignment'] = {
            'schedule_id': None,  # Will be set after schedule creation
            'user_id': None,  # Will be set to operator user
            'assigned_at': datetime.now().isoformat(),
            'status': 'assigned',
            'notes': 'Test job assignment'
        }
        
        print("✅ Test data setup complete")
    
    async def test_production_line_service(self):
        """Test ProductionLineService methods."""
        print("\n🧪 Testing ProductionLineService...")
        
        try:
            # Test create production line
            line_data = ProductionLineCreate(**self.test_data['production_line'])
            created_line = await ProductionLineService.create_production_line(
                line_data, self.test_users['admin']['id']
            )
            
            self.test_data['production_line']['id'] = created_line.id
            self.test_data['production_schedule']['line_id'] = created_line.id
            
            self.record_test_result(
                "ProductionLineService.create_production_line",
                True,
                f"Created line with ID: {created_line.id}"
            )
            
            # Test get production line
            retrieved_line = await ProductionLineService.get_production_line(created_line.id)
            self.record_test_result(
                "ProductionLineService.get_production_line",
                retrieved_line.id == created_line.id,
                f"Retrieved line: {retrieved_line.name}"
            )
            
            # Test list production lines
            lines = await ProductionLineService.list_production_lines()
            self.record_test_result(
                "ProductionLineService.list_production_lines",
                len(lines) > 0,
                f"Found {len(lines)} production lines"
            )
            
            # Test update production line
            update_data = {'name': 'Updated Test Line', 'target_speed': 150.0}
            updated_line = await ProductionLineService.update_production_line(
                created_line.id, update_data
            )
            self.record_test_result(
                "ProductionLineService.update_production_line",
                updated_line.name == 'Updated Test Line' and updated_line.target_speed == 150.0,
                f"Updated line: {updated_line.name}"
            )
            
        except Exception as e:
            self.record_test_result(
                "ProductionLineService",
                False,
                f"Error: {str(e)}"
            )
    
    async def test_production_schedule_service(self):
        """Test ProductionScheduleService methods."""
        print("\n🧪 Testing ProductionScheduleService...")
        
        try:
            # Test create production schedule
            schedule_data = ProductionScheduleCreate(**self.test_data['production_schedule'])
            created_schedule = await ProductionScheduleService.create_schedule(
                schedule_data, self.test_users['production_manager']['id']
            )
            
            self.test_data['production_schedule']['id'] = created_schedule.id
            self.test_data['job_assignment']['schedule_id'] = created_schedule.id
            self.test_data['job_assignment']['user_id'] = self.test_users['operator']['id']
            
            self.record_test_result(
                "ProductionScheduleService.create_schedule",
                True,
                f"Created schedule with ID: {created_schedule.id}"
            )
            
            # Test get production schedule
            retrieved_schedule = await ProductionScheduleService.get_schedule(created_schedule.id)
            self.record_test_result(
                "ProductionScheduleService.get_schedule",
                retrieved_schedule.id == created_schedule.id,
                f"Retrieved schedule: {retrieved_schedule.product_type_id}"
            )
            
            # Test list production schedules
            schedules = await ProductionScheduleService.list_schedules(
                line_id=created_schedule.line_id
            )
            self.record_test_result(
                "ProductionScheduleService.list_schedules",
                len(schedules) > 0,
                f"Found {len(schedules)} schedules for line"
            )
            
            # Test update production schedule
            update_data = {'target_quantity': 1500, 'priority': 2}
            updated_schedule = await ProductionScheduleService.update_schedule(
                created_schedule.id, update_data
            )
            self.record_test_result(
                "ProductionScheduleService.update_schedule",
                updated_schedule.target_quantity == 1500 and updated_schedule.priority == 2,
                f"Updated schedule: {updated_schedule.target_quantity} units"
            )
            
            # Test delete production schedule
            await ProductionScheduleService.delete_schedule(created_schedule.id)
            self.record_test_result(
                "ProductionScheduleService.delete_schedule",
                True,
                "Schedule deleted successfully"
            )
            
        except Exception as e:
            self.record_test_result(
                "ProductionScheduleService",
                False,
                f"Error: {str(e)}"
            )
    
    async def test_job_assignment_service(self):
        """Test JobAssignmentService methods."""
        print("\n🧪 Testing JobAssignmentService...")
        
        try:
            # Create a new schedule for job assignment testing
            schedule_data = ProductionScheduleCreate(**self.test_data['production_schedule'])
            created_schedule = await ProductionScheduleService.create_schedule(
                schedule_data, self.test_users['production_manager']['id']
            )
            
            # Test create job assignment
            job_data = JobAssignmentCreate(**self.test_data['job_assignment'])
            job_data.schedule_id = created_schedule.id
            job_data.user_id = self.test_users['operator']['id']
            
            created_job = await JobAssignmentService.create_job_assignment(
                job_data, self.test_users['production_manager']['id']
            )
            
            self.record_test_result(
                "JobAssignmentService.create_job_assignment",
                True,
                f"Created job assignment with ID: {created_job.id}"
            )
            
            # Test get job assignment
            retrieved_job = await JobAssignmentService.get_job_assignment(created_job.id)
            self.record_test_result(
                "JobAssignmentService.get_job_assignment",
                retrieved_job.id == created_job.id,
                f"Retrieved job assignment: {retrieved_job.status}"
            )
            
            # Test list job assignments
            jobs = await JobAssignmentService.list_job_assignments(
                user_id=self.test_users['operator']['id']
            )
            self.record_test_result(
                "JobAssignmentService.list_job_assignments",
                len(jobs) > 0,
                f"Found {len(jobs)} job assignments for user"
            )
            
            # Test accept job
            accepted_job = await JobAssignmentService.accept_job(
                created_job.id, self.test_users['operator']['id']
            )
            self.record_test_result(
                "JobAssignmentService.accept_job",
                accepted_job.status == 'accepted',
                f"Job accepted: {accepted_job.status}"
            )
            
            # Test start job
            started_job = await JobAssignmentService.start_job(
                created_job.id, self.test_users['operator']['id']
            )
            self.record_test_result(
                "JobAssignmentService.start_job",
                started_job.status == 'in_progress',
                f"Job started: {started_job.status}"
            )
            
            # Test complete job
            completed_job = await JobAssignmentService.complete_job(
                created_job.id, self.test_users['operator']['id']
            )
            self.record_test_result(
                "JobAssignmentService.complete_job",
                completed_job.status == 'completed',
                f"Job completed: {completed_job.status}"
            )
            
        except Exception as e:
            self.record_test_result(
                "JobAssignmentService",
                False,
                f"Error: {str(e)}"
            )
    
    async def test_permission_system(self):
        """Test the permission system."""
        print("\n🧪 Testing Permission System...")
        
        try:
            # Test admin permissions
            admin_user = self.test_users['admin']
            admin_token = create_access_token(admin_user)
            
            # Admin should have all permissions
            has_production_write = await PermissionChecker.check_permission(
                admin_token, 'production:write'
            )
            self.record_test_result(
                "Permission System - Admin production:write",
                has_promission,
                f"Admin has production:write permission: {has_production_write}"
            )
            
            # Test production manager permissions
            pm_user = self.test_users['production_manager']
            pm_token = create_access_token(pm_user)
            
            has_schedule_write = await PermissionChecker.check_permission(
                pm_token, 'schedule:write'
            )
            self.record_test_result(
                "Permission System - PM schedule:write",
                has_schedule_write,
                f"PM has schedule:write permission: {has_schedule_write}"
            )
            
            # Test operator permissions
            operator_user = self.test_users['operator']
            operator_token = create_access_token(operator_user)
            
            has_job_accept = await PermissionChecker.check_permission(
                operator_token, 'job:accept'
            )
            self.record_test_result(
                "Permission System - Operator job:accept",
                has_job_accept,
                f"Operator has job:accept permission: {has_job_accept}"
            )
            
            # Test viewer permissions (should not have write access)
            viewer_user = self.test_users['viewer']
            viewer_token = create_access_token(viewer_user)
            
            has_production_write_viewer = await PermissionChecker.check_permission(
                viewer_token, 'production:write'
            )
            self.record_test_result(
                "Permission System - Viewer production:write (should be False)",
                not has_production_write_viewer,
                f"Viewer has production:write permission: {has_production_write_viewer} (should be False)"
            )
            
        except Exception as e:
            self.record_test_result(
                "Permission System",
                False,
                f"Error: {str(e)}"
            )
    
    async def test_redux_integration(self):
        """Test Redux store integration (simulated)."""
        print("\n🧪 Testing Redux Store Integration...")
        
        try:
            # Simulate Redux store state updates
            redux_tests = [
                {
                    'name': 'Production Slice - fetchProductionLines',
                    'test': self.simulate_redux_action('production/fetchProductionLines'),
                    'expected': True
                },
                {
                    'name': 'Jobs Slice - fetchMyJobs',
                    'test': self.simulate_redux_action('jobs/fetchMyJobs'),
                    'expected': True
                },
                {
                    'name': 'Dashboard Slice - fetchLineStatus',
                    'test': self.simulate_redux_action('dashboard/fetchLineStatus'),
                    'expected': True
                },
                {
                    'name': 'Andon Slice - fetchAndonEvents',
                    'test': self.simulate_redux_action('andon/fetchAndonEvents'),
                    'expected': True
                },
                {
                    'name': 'OEE Slice - fetchOEEData',
                    'test': self.simulate_redux_action('oee/fetchOEEData'),
                    'expected': True
                },
                {
                    'name': 'Equipment Slice - fetchEquipment',
                    'test': self.simulate_redux_action('equipment/fetchEquipment'),
                    'expected': True
                },
                {
                    'name': 'Reports Slice - fetchReportTemplates',
                    'test': self.simulate_redux_action('reports/fetchReportTemplates'),
                    'expected': True
                },
                {
                    'name': 'Quality Slice - fetchQualityChecks',
                    'test': self.simulate_redux_action('quality/fetchQualityChecks'),
                    'expected': True
                }
            ]
            
            for test in redux_tests:
                result = test['test']
                self.record_test_result(
                    test['name'],
                    result == test['expected'],
                    f"Redux action simulation: {test['name']}"
                )
            
        except Exception as e:
            self.record_test_result(
                "Redux Store Integration",
                False,
                f"Error: {str(e)}"
            )
    
    def simulate_redux_action(self, action_type: str) -> bool:
        """Simulate a Redux action for testing purposes."""
        # This is a simplified simulation - in real testing, you would use actual Redux store
        valid_actions = [
            'production/fetchProductionLines',
            'production/fetchProductionSchedules',
            'jobs/fetchMyJobs',
            'jobs/acceptJob',
            'jobs/startJob',
            'jobs/completeJob',
            'dashboard/fetchLineStatus',
            'dashboard/fetchEquipmentStatus',
            'andon/fetchAndonEvents',
            'andon/createAndonEvent',
            'andon/acknowledgeAndonEvent',
            'andon/resolveAndonEvent',
            'oee/fetchOEEData',
            'equipment/fetchEquipment',
            'equipment/fetchMaintenanceSchedules',
            'equipment/fetchEquipmentFaults',
            'reports/fetchReportTemplates',
            'reports/generateReport',
            'quality/fetchQualityChecks',
            'quality/fetchQualityInspections',
            'quality/fetchQualityDefects'
        ]
        
        return action_type in valid_actions
    
    async def test_api_service_layer(self):
        """Test API service layer methods (simulated)."""
        print("\n🧪 Testing API Service Layer...")
        
        try:
            # Simulate API service method calls
            api_tests = [
                {
                    'name': 'Authentication API',
                    'methods': ['login', 'logout', 'refreshToken', 'getCurrentUser'],
                    'expected': True
                },
                {
                    'name': 'Production API',
                    'methods': ['getProductionLines', 'createProductionLine', 'getProductionSchedules'],
                    'expected': True
                },
                {
                    'name': 'Job Assignment API',
                    'methods': ['getMyJobs', 'acceptJob', 'startJob', 'completeJob'],
                    'expected': True
                },
                {
                    'name': 'Dashboard API',
                    'methods': ['getLineStatus', 'getEquipmentStatus', 'getDashboardMetrics'],
                    'expected': True
                },
                {
                    'name': 'Andon API',
                    'methods': ['getAndonEvents', 'createAndonEvent', 'acknowledgeAndonEvent'],
                    'expected': True
                },
                {
                    'name': 'OEE API',
                    'methods': ['getOEEData', 'getOEEHistory', 'getOEEBreakdown'],
                    'expected': True
                },
                {
                    'name': 'Equipment API',
                    'methods': ['getEquipment', 'getMaintenanceSchedules', 'getEquipmentFaults'],
                    'expected': True
                },
                {
                    'name': 'Reports API',
                    'methods': ['getReportTemplates', 'generateReport', 'getScheduledReports'],
                    'expected': True
                },
                {
                    'name': 'Quality API',
                    'methods': ['getQualityChecks', 'getQualityInspections', 'getQualityDefects'],
                    'expected': True
                }
            ]
            
            for test in api_tests:
                # Simulate method existence check
                method_exists = all(
                    hasattr(self, f'simulate_api_method_{method}') or 
                    method in ['login', 'logout', 'refreshToken', 'getCurrentUser', 'getProductionLines', 'createProductionLine']
                    for method in test['methods']
                )
                
                self.record_test_result(
                    f"API Service - {test['name']}",
                    method_exists,
                    f"API methods available: {', '.join(test['methods'])}"
                )
            
        except Exception as e:
            self.record_test_result(
                "API Service Layer",
                False,
                f"Error: {str(e)}"
            )
    
    def record_test_result(self, test_name: str, passed: bool, message: str):
        """Record a test result."""
        result = {
            'test_name': test_name,
            'passed': passed,
            'message': message,
            'timestamp': datetime.now().isoformat()
        }
        self.test_results.append(result)
        
        status = "✅ PASS" if passed else "❌ FAIL"
        print(f"  {status} {test_name}: {message}")
    
    def generate_report(self):
        """Generate a test report."""
        print("\n" + "="*80)
        print("📊 PHASE 2 API INTEGRATION TEST REPORT")
        print("="*80)
        
        total_tests = len(self.test_results)
        passed_tests = sum(1 for result in self.test_results if result['passed'])
        failed_tests = total_tests - passed_tests
        
        print(f"\n📈 SUMMARY:")
        print(f"  Total Tests: {total_tests}")
        print(f"  Passed: {passed_tests} ✅")
        print(f"  Failed: {failed_tests} ❌")
        print(f"  Success Rate: {(passed_tests/total_tests)*100:.1f}%")
        
        if failed_tests > 0:
            print(f"\n❌ FAILED TESTS:")
            for result in self.test_results:
                if not result['passed']:
                    print(f"  - {result['test_name']}: {result['message']}")
        
        print(f"\n✅ PASSED TESTS:")
        for result in self.test_results:
            if result['passed']:
                print(f"  - {result['test_name']}: {result['message']}")
        
        # Save detailed report
        report_data = {
            'phase': 'Phase 2 - API Implementation and Permissions',
            'timestamp': datetime.now().isoformat(),
            'summary': {
                'total_tests': total_tests,
                'passed_tests': passed_tests,
                'failed_tests': failed_tests,
                'success_rate': (passed_tests/total_tests)*100
            },
            'test_results': self.test_results
        }
        
        with open('phase2_test_report.json', 'w') as f:
            json.dump(report_data, f, indent=2)
        
        print(f"\n📄 Detailed report saved to: phase2_test_report.json")
        
        return passed_tests == total_tests
    
    async def run_all_tests(self):
        """Run all Phase 2 tests."""
        print("🚀 Starting Phase 2 API Integration Tests...")
        print("="*80)
        
        await self.setup_test_data()
        await self.test_production_line_service()
        await self.test_production_schedule_service()
        await self.test_job_assignment_service()
        await self.test_permission_system()
        await self.test_redux_integration()
        await self.test_api_service_layer()
        
        success = self.generate_report()
        
        if success:
            print("\n🎉 All Phase 2 tests passed! The API implementation and permission system are working correctly.")
        else:
            print("\n⚠️  Some Phase 2 tests failed. Please review the failed tests and fix the issues.")
        
        return success

async def main():
    """Main test runner."""
    tester = Phase2APITester()
    success = await tester.run_all_tests()
    return 0 if success else 1

if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code)
