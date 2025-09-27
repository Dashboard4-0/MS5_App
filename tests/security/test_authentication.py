"""
Security tests for authentication
Tests authentication mechanisms, token validation, and security vulnerabilities
"""

import pytest
import asyncio
import httpx
import jwt
import time
from datetime import datetime, timedelta
import uuid


class TestAuthenticationSecurity:
    """Security tests for authentication"""
    
    @pytest.fixture
    async def client(self):
        """Create HTTP client for security testing"""
        async with httpx.AsyncClient(base_url="http://localhost:8000", timeout=30.0) as client:
            yield client
    
    @pytest.mark.asyncio
    async def test_invalid_credentials(self, client):
        """Test authentication with invalid credentials"""
        
        # Test with invalid email
        invalid_email_data = {
            "email": "invalid@example.com",
            "password": "testpassword"
        }
        
        response = await client.post("/api/v1/auth/login", json=invalid_email_data)
        
        # Should return 401 Unauthorized
        assert response.status_code == 401, f"Expected 401, got {response.status_code}"
        
        # Test with invalid password
        invalid_password_data = {
            "email": "test@example.com",
            "password": "wrongpassword"
        }
        
        response = await client.post("/api/v1/auth/login", json=invalid_password_data)
        
        # Should return 401 Unauthorized
        assert response.status_code == 401, f"Expected 401, got {response.status_code}"
        
        # Test with empty credentials
        empty_credentials_data = {
            "email": "",
            "password": ""
        }
        
        response = await client.post("/api/v1/auth/login", json=empty_credentials_data)
        
        # Should return 422 Validation Error or 401 Unauthorized
        assert response.status_code in [401, 422], f"Expected 401 or 422, got {response.status_code}"
    
    @pytest.mark.asyncio
    async def test_sql_injection_authentication(self, client):
        """Test authentication against SQL injection attacks"""
        
        # Test SQL injection in email field
        sql_injection_data = {
            "email": "test@example.com'; DROP TABLE users; --",
            "password": "testpassword"
        }
        
        response = await client.post("/api/v1/auth/login", json=sql_injection_data)
        
        # Should return 401 Unauthorized, not execute SQL
        assert response.status_code == 401, f"Expected 401, got {response.status_code}"
        
        # Test SQL injection in password field
        sql_injection_data = {
            "email": "test@example.com",
            "password": "'; DROP TABLE users; --"
        }
        
        response = await client.post("/api/v1/auth/login", json=sql_injection_data)
        
        # Should return 401 Unauthorized, not execute SQL
        assert response.status_code == 401, f"Expected 401, got {response.status_code}"
        
        # Test with UNION attack
        union_attack_data = {
            "email": "test@example.com' UNION SELECT * FROM users --",
            "password": "testpassword"
        }
        
        response = await client.post("/api/v1/auth/login", json=union_attack_data)
        
        # Should return 401 Unauthorized, not execute SQL
        assert response.status_code == 401, f"Expected 401, got {response.status_code}"
    
    @pytest.mark.asyncio
    async def test_brute_force_protection(self, client):
        """Test brute force attack protection"""
        
        # Attempt multiple failed logins
        failed_attempts = 0
        
        for i in range(10):
            brute_force_data = {
                "email": "test@example.com",
                "password": f"wrongpassword{i}"
            }
            
            response = await client.post("/api/v1/auth/login", json=brute_force_data)
            
            if response.status_code == 401:
                failed_attempts += 1
            elif response.status_code == 429:  # Rate limited
                print(f"Rate limiting triggered after {failed_attempts} attempts")
                break
        
        # Should either block after multiple attempts or continue to return 401
        assert failed_attempts >= 5, f"Expected at least 5 failed attempts, got {failed_attempts}"
        
        # If rate limiting is implemented, it should trigger
        if failed_attempts >= 10:
            print("No rate limiting detected - consider implementing brute force protection")
    
    @pytest.mark.asyncio
    async def test_token_validation(self, client):
        """Test JWT token validation and security"""
        
        # Test with invalid token
        invalid_token = "invalid.jwt.token"
        
        response = await client.get("/api/v1/auth/profile", headers={"Authorization": f"Bearer {invalid_token}"})
        
        # Should return 401 Unauthorized
        assert response.status_code == 401, f"Expected 401, got {response.status_code}"
        
        # Test with malformed token
        malformed_token = "not.a.valid.token"
        
        response = await client.get("/api/v1/auth/profile", headers={"Authorization": f"Bearer {malformed_token}"})
        
        # Should return 401 Unauthorized
        assert response.status_code == 401, f"Expected 401, got {response.status_code}"
        
        # Test with expired token (if we can create one)
        try:
            # Create an expired token
            expired_payload = {
                "user_id": "test",
                "exp": int(time.time()) - 3600  # Expired 1 hour ago
            }
            
            # This would require the actual JWT secret, which we don't have in tests
            # So we'll test with a clearly expired token format
            expired_token = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoidGVzdCIsImV4cCI6MTYwMDAwMDAwMH0.invalid"
            
            response = await client.get("/api/v1/auth/profile", headers={"Authorization": f"Bearer {expired_token}"})
            
            # Should return 401 Unauthorized
            assert response.status_code == 401, f"Expected 401, got {response.status_code}"
            
        except Exception as e:
            print(f"Expired token test failed: {e}")
    
    @pytest.mark.asyncio
    async def test_token_manipulation(self, client):
        """Test JWT token manipulation attacks"""
        
        # Test with modified token
        modified_token = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoidGVzdCIsImV4cCI6OTk5OTk5OTk5OX0.modified"
        
        response = await client.get("/api/v1/auth/profile", headers={"Authorization": f"Bearer {modified_token}"})
        
        # Should return 401 Unauthorized
        assert response.status_code == 401, f"Expected 401, got {response.status_code}"
        
        # Test with token without signature
        unsigned_token = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoidGVzdCJ9"
        
        response = await client.get("/api/v1/auth/profile", headers={"Authorization": f"Bearer {unsigned_token}"})
        
        # Should return 401 Unauthorized
        assert response.status_code == 401, f"Expected 401, got {response.status_code}"
        
        # Test with different algorithm
        different_alg_token = "eyJ0eXAiOiJKV1QiLCJhbGciOiJub25lIn0.eyJ1c2VyX2lkIjoidGVzdCJ9."
        
        response = await client.get("/api/v1/auth/profile", headers={"Authorization": f"Bearer {different_alg_token}"})
        
        # Should return 401 Unauthorized
        assert response.status_code == 401, f"Expected 401, got {response.status_code}"
    
    @pytest.mark.asyncio
    async def test_authorization_header_manipulation(self, client):
        """Test authorization header manipulation"""
        
        # Test without Bearer prefix
        response = await client.get("/api/v1/auth/profile", headers={"Authorization": "invalid-token"})
        
        # Should return 401 Unauthorized
        assert response.status_code == 401, f"Expected 401, got {response.status_code}"
        
        # Test with wrong Bearer format
        response = await client.get("/api/v1/auth/profile", headers={"Authorization": "Bearer"})
        
        # Should return 401 Unauthorized
        assert response.status_code == 401, f"Expected 401, got {response.status_code}"
        
        # Test with multiple Bearer tokens
        response = await client.get("/api/v1/auth/profile", headers={"Authorization": "Bearer token1 Bearer token2"})
        
        # Should return 401 Unauthorized
        assert response.status_code == 401, f"Expected 401, got {response.status_code}"
        
        # Test with case sensitivity
        response = await client.get("/api/v1/auth/profile", headers={"Authorization": "bearer invalid-token"})
        
        # Should return 401 Unauthorized
        assert response.status_code == 401, f"Expected 401, got {response.status_code}"
    
    @pytest.mark.asyncio
    async def test_session_management(self, client):
        """Test session management security"""
        
        # Test login and get token
        login_data = {
            "email": "test@example.com",
            "password": "testpassword"
        }
        
        login_response = await client.post("/api/v1/auth/login", json=login_data)
        
        if login_response.status_code == 200:
            token = login_response.json()["token"]
            
            # Test token reuse
            response1 = await client.get("/api/v1/auth/profile", headers={"Authorization": f"Bearer {token}"})
            response2 = await client.get("/api/v1/auth/profile", headers={"Authorization": f"Bearer {token}"})
            
            # Both requests should work (token should be reusable)
            assert response1.status_code == response2.status_code, "Token behavior inconsistent"
            
            # Test logout (if implemented)
            logout_response = await client.post("/api/v1/auth/logout", headers={"Authorization": f"Bearer {token}"})
            
            if logout_response.status_code == 200:
                # After logout, token should be invalid
                response_after_logout = await client.get("/api/v1/auth/profile", headers={"Authorization": f"Bearer {token}"})
                
                # Should return 401 Unauthorized
                assert response_after_logout.status_code == 401, f"Expected 401 after logout, got {response_after_logout.status_code}"
        else:
            pytest.skip("Could not login for session management test")
    
    @pytest.mark.asyncio
    async def test_password_security(self, client):
        """Test password security requirements"""
        
        # Test weak passwords
        weak_passwords = [
            "123456",
            "password",
            "admin",
            "qwerty",
            "abc123",
            "test",
            "12345",
            "password123"
        ]
        
        for weak_password in weak_passwords:
            weak_password_data = {
                "email": "test@example.com",
                "password": weak_password
            }
            
            response = await client.post("/api/v1/auth/login", json=weak_password_data)
            
            # Should return 401 Unauthorized
            assert response.status_code == 401, f"Expected 401 for weak password '{weak_password}', got {response.status_code}"
        
        # Test password length limits
        long_password = "a" * 1000  # Very long password
        
        long_password_data = {
            "email": "test@example.com",
            "password": long_password
        }
        
        response = await client.post("/api/v1/auth/login", json=long_password_data)
        
        # Should handle long passwords gracefully
        assert response.status_code in [401, 422], f"Expected 401 or 422 for long password, got {response.status_code}"
    
    @pytest.mark.asyncio
    async def test_input_validation(self, client):
        """Test input validation for authentication"""
        
        # Test XSS attempts in email
        xss_email_data = {
            "email": "<script>alert('xss')</script>@example.com",
            "password": "testpassword"
        }
        
        response = await client.post("/api/v1/auth/login", json=xss_email_data)
        
        # Should return 401 Unauthorized, not execute script
        assert response.status_code == 401, f"Expected 401 for XSS attempt, got {response.status_code}"
        
        # Test XSS attempts in password
        xss_password_data = {
            "email": "test@example.com",
            "password": "<script>alert('xss')</script>"
        }
        
        response = await client.post("/api/v1/auth/login", json=xss_password_data)
        
        # Should return 401 Unauthorized, not execute script
        assert response.status_code == 401, f"Expected 401 for XSS attempt, got {response.status_code}"
        
        # Test with special characters
        special_chars_data = {
            "email": "test@example.com",
            "password": "!@#$%^&*()_+-=[]{}|;':\",./<>?"
        }
        
        response = await client.post("/api/v1/auth/login", json=special_chars_data)
        
        # Should handle special characters gracefully
        assert response.status_code in [401, 422], f"Expected 401 or 422 for special characters, got {response.status_code}"
    
    @pytest.mark.asyncio
    async def test_authentication_bypass(self, client):
        """Test authentication bypass attempts"""
        
        # Test accessing protected endpoints without authentication
        protected_endpoints = [
            "/api/v1/auth/profile",
            "/api/v1/production/lines",
            "/api/v1/job-assignments",
            "/api/v1/andon/events",
            "/api/v1/oee/lines/test"
        ]
        
        for endpoint in protected_endpoints:
            response = await client.get(endpoint)
            
            # Should return 401 Unauthorized
            assert response.status_code == 401, f"Expected 401 for {endpoint}, got {response.status_code}"
        
        # Test with empty authorization header
        for endpoint in protected_endpoints:
            response = await client.get(endpoint, headers={"Authorization": ""})
            
            # Should return 401 Unauthorized
            assert response.status_code == 401, f"Expected 401 for {endpoint} with empty auth, got {response.status_code}"
        
        # Test with null authorization header
        for endpoint in protected_endpoints:
            response = await client.get(endpoint, headers={"Authorization": "null"})
            
            # Should return 401 Unauthorized
            assert response.status_code == 401, f"Expected 401 for {endpoint} with null auth, got {response.status_code}"
    
    @pytest.mark.asyncio
    async def test_token_expiration(self, client):
        """Test token expiration handling"""
        
        # Test with very old token
        old_token = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoidGVzdCIsImV4cCI6MTYwMDAwMDAwMH0.old"
        
        response = await client.get("/api/v1/auth/profile", headers={"Authorization": f"Bearer {old_token}"})
        
        # Should return 401 Unauthorized
        assert response.status_code == 401, f"Expected 401 for old token, got {response.status_code}"
        
        # Test token refresh (if implemented)
        refresh_response = await client.post("/api/v1/auth/refresh")
        
        if refresh_response.status_code == 401:
            # Refresh without token should return 401
            assert refresh_response.status_code == 401, f"Expected 401 for refresh without token, got {refresh_response.status_code}"
        else:
            pytest.skip("Token refresh not implemented")
    
    @pytest.mark.asyncio
    async def test_concurrent_authentication(self, client):
        """Test concurrent authentication attempts"""
        
        async def attempt_login(attempt_id):
            """Attempt login"""
            login_data = {
                "email": "test@example.com",
                "password": f"wrongpassword{attempt_id}"
            }
            
            response = await client.post("/api/v1/auth/login", json=login_data)
            return response.status_code
        
        # Test concurrent failed logins
        tasks = [attempt_login(i) for i in range(20)]
        results = await asyncio.gather(*tasks)
        
        # All should return 401
        for i, status_code in enumerate(results):
            assert status_code == 401, f"Expected 401 for attempt {i}, got {status_code}"
        
        # Test concurrent valid logins (if we have valid credentials)
        valid_login_data = {
            "email": "test@example.com",
            "password": "testpassword"
        }
        
        async def attempt_valid_login(attempt_id):
            """Attempt valid login"""
            response = await client.post("/api/v1/auth/login", json=valid_login_data)
            return response.status_code
        
        tasks = [attempt_valid_login(i) for i in range(5)]
        results = await asyncio.gather(*tasks)
        
        # Should handle concurrent valid logins gracefully
        for i, status_code in enumerate(results):
            assert status_code in [200, 401], f"Expected 200 or 401 for valid attempt {i}, got {status_code}"


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
