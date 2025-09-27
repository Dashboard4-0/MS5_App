"""
Security tests for authorization
Tests role-based access control, permission validation, and authorization bypass attempts
"""

import pytest
import asyncio
import httpx
import uuid
from datetime import datetime, timedelta


class TestAuthorizationSecurity:
    """Security tests for authorization"""
    
    @pytest.fixture
    async def client(self):
        """Create HTTP client for security testing"""
        async with httpx.AsyncClient(base_url="http://localhost:8000", timeout=30.0) as client:
            yield client
    
    @pytest.fixture
    async def operator_token(self, client):
        """Get operator authentication token"""
        login_data = {
            "email": "operator@example.com",
            "password": "operatorpassword"
        }
        
        response = await client.post("/api/v1/auth/login", json=login_data)
        if response.status_code == 200:
            return response.json()["token"]
        return None
    
    @pytest.fixture
    async def manager_token(self, client):
        """Get manager authentication token"""
        login_data = {
            "email": "manager@example.com",
            "password": "managerpassword"
        }
        
        response = await client.post("/api/v1/auth/login", json=login_data)
        if response.status_code == 200:
            return response.json()["token"]
        return None
    
    @pytest.fixture
    async def admin_token(self, client):
        """Get admin authentication token"""
        login_data = {
            "email": "admin@example.com",
            "password": "adminpassword"
        }
        
        response = await client.post("/api/v1/auth/login", json=login_data)
        if response.status_code == 200:
            return response.json()["token"]
        return None
    
    @pytest.fixture
    def operator_headers(self, operator_token):
        """Get operator authentication headers"""
        if operator_token:
            return {"Authorization": f"Bearer {operator_token}"}
        return {}
    
    @pytest.fixture
    def manager_headers(self, manager_token):
        """Get manager authentication headers"""
        if manager_token:
            return {"Authorization": f"Bearer {manager_token}"}
        return {}
    
    @pytest.fixture
    def admin_headers(self, admin_token):
        """Get admin authentication headers"""
        if admin_token:
            return {"Authorization": f"Bearer {admin_token}"}
        return {}
    
    @pytest.mark.asyncio
    async def test_role_based_access_control(self, client, operator_headers, manager_headers, admin_headers):
        """Test role-based access control for different user roles"""
        
        # Test endpoints that should be accessible to all authenticated users
        common_endpoints = [
            "/api/v1/production/lines",
            "/api/v1/job-assignments",
            "/api/v1/andon/events"
        ]
        
        for endpoint in common_endpoints:
            # Test operator access
            if operator_headers:
                response = await client.get(endpoint, headers=operator_headers)
                assert response.status_code in [200, 401], f"Operator access to {endpoint} failed: {response.status_code}"
            
            # Test manager access
            if manager_headers:
                response = await client.get(endpoint, headers=manager_headers)
                assert response.status_code in [200, 401], f"Manager access to {endpoint} failed: {response.status_code}"
            
            # Test admin access
            if admin_headers:
                response = await client.get(endpoint, headers=admin_headers)
                assert response.status_code in [200, 401], f"Admin access to {endpoint} failed: {response.status_code}"
        
        # Test endpoints that should only be accessible to managers and admins
        manager_endpoints = [
            "/api/v1/production/schedules",
            "/api/v1/reports",
            "/api/v1/users"
        ]
        
        for endpoint in manager_endpoints:
            # Test operator access (should be denied)
            if operator_headers:
                response = await client.get(endpoint, headers=operator_headers)
                assert response.status_code in [403, 401], f"Operator should not access {endpoint}: {response.status_code}"
            
            # Test manager access
            if manager_headers:
                response = await client.get(endpoint, headers=manager_headers)
                assert response.status_code in [200, 401], f"Manager access to {endpoint} failed: {response.status_code}"
            
            # Test admin access
            if admin_headers:
                response = await client.get(endpoint, headers=admin_headers)
                assert response.status_code in [200, 401], f"Admin access to {endpoint} failed: {response.status_code}"
        
        # Test endpoints that should only be accessible to admins
        admin_endpoints = [
            "/api/v1/admin/users",
            "/api/v1/admin/system",
            "/api/v1/admin/logs"
        ]
        
        for endpoint in admin_endpoints:
            # Test operator access (should be denied)
            if operator_headers:
                response = await client.get(endpoint, headers=operator_headers)
                assert response.status_code in [403, 401], f"Operator should not access {endpoint}: {response.status_code}"
            
            # Test manager access (should be denied)
            if manager_headers:
                response = await client.get(endpoint, headers=manager_headers)
                assert response.status_code in [403, 401], f"Manager should not access {endpoint}: {response.status_code}"
            
            # Test admin access
            if admin_headers:
                response = await client.get(endpoint, headers=admin_headers)
                assert response.status_code in [200, 401], f"Admin access to {endpoint} failed: {response.status_code}"
    
    @pytest.mark.asyncio
    async def test_authorization_bypass_attempts(self, client, operator_headers):
        """Test authorization bypass attempts"""
        
        if not operator_headers:
            pytest.skip("No operator token available")
        
        # Test accessing admin endpoints with operator token
        admin_endpoints = [
            "/api/v1/admin/users",
            "/api/v1/admin/system",
            "/api/v1/admin/logs"
        ]
        
        for endpoint in admin_endpoints:
            response = await client.get(endpoint, headers=operator_headers)
            
            # Should return 403 Forbidden
            assert response.status_code == 403, f"Expected 403 for operator accessing {endpoint}, got {response.status_code}"
        
        # Test creating admin resources with operator token
        admin_create_data = {
            "username": "newadmin",
            "email": "newadmin@example.com",
            "role": "admin",
            "password": "adminpassword"
        }
        
        response = await client.post("/api/v1/admin/users", json=admin_create_data, headers=operator_headers)
        
        # Should return 403 Forbidden
        assert response.status_code == 403, f"Expected 403 for operator creating admin user, got {response.status_code}"
        
        # Test modifying system settings with operator token
        system_settings_data = {
            "setting": "test_setting",
            "value": "test_value"
        }
        
        response = await client.put("/api/v1/admin/system/settings", json=system_settings_data, headers=operator_headers)
        
        # Should return 403 Forbidden
        assert response.status_code == 403, f"Expected 403 for operator modifying system settings, got {response.status_code}"
    
    @pytest.mark.asyncio
    async def test_resource_access_control(self, client, operator_headers, manager_headers):
        """Test resource-level access control"""
        
        # Test accessing other users' data
        if operator_headers:
            # Try to access another user's profile
            response = await client.get("/api/v1/users/other-user-id", headers=operator_headers)
            
            # Should return 403 Forbidden or 404 Not Found
            assert response.status_code in [403, 404], f"Expected 403 or 404 for accessing other user's data, got {response.status_code}"
            
            # Try to modify another user's data
            user_data = {
                "first_name": "Modified",
                "last_name": "User"
            }
            
            response = await client.put("/api/v1/users/other-user-id", json=user_data, headers=operator_headers)
            
            # Should return 403 Forbidden or 404 Not Found
            assert response.status_code in [403, 404], f"Expected 403 or 404 for modifying other user's data, got {response.status_code}"
        
        # Test accessing other lines' data
        if operator_headers:
            # Try to access another line's data
            response = await client.get("/api/v1/production/lines/other-line-id", headers=operator_headers)
            
            # Should return 403 Forbidden or 404 Not Found
            assert response.status_code in [403, 404], f"Expected 403 or 404 for accessing other line's data, got {response.status_code}"
            
            # Try to modify another line's data
            line_data = {
                "name": "Modified Line",
                "status": "inactive"
            }
            
            response = await client.put("/api/v1/production/lines/other-line-id", json=line_data, headers=operator_headers)
            
            # Should return 403 Forbidden or 404 Not Found
            assert response.status_code in [403, 404], f"Expected 403 or 404 for modifying other line's data, got {response.status_code}"
    
    @pytest.mark.asyncio
    async def test_permission_validation(self, client, operator_headers, manager_headers):
        """Test permission validation for different operations"""
        
        # Test create permissions
        if operator_headers:
            # Try to create production line (should be denied for operators)
            line_data = {
                "name": "Test Line",
                "description": "Test line",
                "status": "active"
            }
            
            response = await client.post("/api/v1/production/lines", json=line_data, headers=operator_headers)
            
            # Should return 403 Forbidden
            assert response.status_code == 403, f"Expected 403 for operator creating line, got {response.status_code}"
        
        # Test update permissions
        if operator_headers:
            # Try to update production line (should be denied for operators)
            line_data = {
                "name": "Updated Line",
                "status": "inactive"
            }
            
            response = await client.put("/api/v1/production/lines/test-line-id", json=line_data, headers=operator_headers)
            
            # Should return 403 Forbidden
            assert response.status_code == 403, f"Expected 403 for operator updating line, got {response.status_code}"
        
        # Test delete permissions
        if operator_headers:
            # Try to delete production line (should be denied for operators)
            response = await client.delete("/api/v1/production/lines/test-line-id", headers=operator_headers)
            
            # Should return 403 Forbidden
            assert response.status_code == 403, f"Expected 403 for operator deleting line, got {response.status_code}"
        
        # Test manager permissions
        if manager_headers:
            # Managers should be able to create lines
            line_data = {
                "name": "Manager Test Line",
                "description": "Test line created by manager",
                "status": "active"
            }
            
            response = await client.post("/api/v1/production/lines", json=line_data, headers=manager_headers)
            
            # Should return 200 or 201
            assert response.status_code in [200, 201], f"Expected 200 or 201 for manager creating line, got {response.status_code}"
            
            # Cleanup if creation was successful
            if response.status_code in [200, 201]:
                line_id = response.json()["id"]
                await client.delete(f"/api/v1/production/lines/{line_id}", headers=manager_headers)
    
    @pytest.mark.asyncio
    async def test_authorization_header_manipulation(self, client):
        """Test authorization header manipulation"""
        
        # Test with invalid token
        invalid_token = "invalid.jwt.token"
        
        response = await client.get("/api/v1/production/lines", headers={"Authorization": f"Bearer {invalid_token}"})
        
        # Should return 401 Unauthorized
        assert response.status_code == 401, f"Expected 401 for invalid token, got {response.status_code}"
        
        # Test with expired token
        expired_token = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoidGVzdCIsImV4cCI6MTYwMDAwMDAwMH0.expired"
        
        response = await client.get("/api/v1/production/lines", headers={"Authorization": f"Bearer {expired_token}"})
        
        # Should return 401 Unauthorized
        assert response.status_code == 401, f"Expected 401 for expired token, got {response.status_code}"
        
        # Test with malformed token
        malformed_token = "not.a.valid.token"
        
        response = await client.get("/api/v1/production/lines", headers={"Authorization": f"Bearer {malformed_token}"})
        
        # Should return 401 Unauthorized
        assert response.status_code == 401, f"Expected 401 for malformed token, got {response.status_code}"
    
    @pytest.mark.asyncio
    async def test_privilege_escalation(self, client, operator_headers):
        """Test privilege escalation attempts"""
        
        if not operator_headers:
            pytest.skip("No operator token available")
        
        # Test trying to change own role
        role_change_data = {
            "role": "admin"
        }
        
        response = await client.put("/api/v1/users/me", json=role_change_data, headers=operator_headers)
        
        # Should return 403 Forbidden
        assert response.status_code == 403, f"Expected 403 for role change attempt, got {response.status_code}"
        
        # Test trying to access admin functions
        admin_functions = [
            "/api/v1/admin/users",
            "/api/v1/admin/system",
            "/api/v1/admin/logs"
        ]
        
        for endpoint in admin_functions:
            response = await client.get(endpoint, headers=operator_headers)
            
            # Should return 403 Forbidden
            assert response.status_code == 403, f"Expected 403 for accessing {endpoint}, got {response.status_code}"
        
        # Test trying to create admin users
        admin_user_data = {
            "username": "newadmin",
            "email": "newadmin@example.com",
            "role": "admin",
            "password": "adminpassword"
        }
        
        response = await client.post("/api/v1/admin/users", json=admin_user_data, headers=operator_headers)
        
        # Should return 403 Forbidden
        assert response.status_code == 403, f"Expected 403 for creating admin user, got {response.status_code}"
    
    @pytest.mark.asyncio
    async def test_data_access_control(self, client, operator_headers, manager_headers):
        """Test data access control"""
        
        # Test accessing sensitive data
        sensitive_endpoints = [
            "/api/v1/admin/logs",
            "/api/v1/admin/system",
            "/api/v1/users/passwords",
            "/api/v1/system/config"
        ]
        
        for endpoint in sensitive_endpoints:
            # Test operator access
            if operator_headers:
                response = await client.get(endpoint, headers=operator_headers)
                
                # Should return 403 Forbidden
                assert response.status_code == 403, f"Expected 403 for operator accessing {endpoint}, got {response.status_code}"
            
            # Test manager access
            if manager_headers:
                response = await client.get(endpoint, headers=manager_headers)
                
                # Should return 403 Forbidden (unless managers have access)
                assert response.status_code in [403, 401], f"Expected 403 or 401 for manager accessing {endpoint}, got {response.status_code}"
    
    @pytest.mark.asyncio
    async def test_concurrent_authorization(self, client, operator_headers):
        """Test concurrent authorization requests"""
        
        if not operator_headers:
            pytest.skip("No operator token available")
        
        async def make_request(endpoint):
            """Make a request to an endpoint"""
            response = await client.get(endpoint, headers=operator_headers)
            return response.status_code
        
        # Test concurrent requests to different endpoints
        endpoints = [
            "/api/v1/production/lines",
            "/api/v1/job-assignments",
            "/api/v1/andon/events",
            "/api/v1/oee/lines/test"
        ]
        
        tasks = [make_request(endpoint) for endpoint in endpoints]
        results = await asyncio.gather(*tasks)
        
        # All requests should return consistent status codes
        for i, status_code in enumerate(results):
            assert status_code in [200, 401, 403], f"Unexpected status code {status_code} for {endpoints[i]}"
    
    @pytest.mark.asyncio
    async def test_authorization_caching(self, client, operator_headers):
        """Test authorization caching and consistency"""
        
        if not operator_headers:
            pytest.skip("No operator token available")
        
        # Make multiple requests to the same endpoint
        endpoint = "/api/v1/production/lines"
        
        responses = []
        for i in range(10):
            response = await client.get(endpoint, headers=operator_headers)
            responses.append(response.status_code)
        
        # All responses should be consistent
        for i, status_code in enumerate(responses):
            assert status_code == responses[0], f"Inconsistent status code {status_code} for request {i}"
        
        # Test with different endpoints
        different_endpoints = [
            "/api/v1/production/lines",
            "/api/v1/job-assignments",
            "/api/v1/andon/events"
        ]
        
        for endpoint in different_endpoints:
            response1 = await client.get(endpoint, headers=operator_headers)
            response2 = await client.get(endpoint, headers=operator_headers)
            
            # Responses should be consistent
            assert response1.status_code == response2.status_code, f"Inconsistent responses for {endpoint}"


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
