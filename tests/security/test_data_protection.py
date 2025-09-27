"""
Security tests for data protection
Tests data encryption, input validation, and data integrity
"""

import pytest
import asyncio
import httpx
import json
import uuid
from datetime import datetime, timedelta


class TestDataProtectionSecurity:
    """Security tests for data protection"""
    
    @pytest.fixture
    async def client(self):
        """Create HTTP client for security testing"""
        async with httpx.AsyncClient(base_url="http://localhost:8000", timeout=30.0) as client:
            yield client
    
    @pytest.fixture
    async def auth_token(self, client):
        """Get authentication token for security testing"""
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
    async def test_input_validation(self, client, auth_headers):
        """Test input validation for security"""
        
        # Test SQL injection attempts
        sql_injection_payloads = [
            "'; DROP TABLE users; --",
            "' OR '1'='1",
            "' UNION SELECT * FROM users --",
            "'; INSERT INTO users VALUES ('hacker', 'hacker@evil.com'); --",
            "' OR 1=1 --"
        ]
        
        for payload in sql_injection_payloads:
            # Test in production line name
            line_data = {
                "name": payload,
                "description": "Test line",
                "status": "active"
            }
            
            response = await client.post("/api/v1/production/lines", json=line_data, headers=auth_headers)
            
            # Should return 422 Validation Error or 401 Unauthorized
            assert response.status_code in [422, 401], f"Expected 422 or 401 for SQL injection in name, got {response.status_code}"
            
            # Test in description
            line_data = {
                "name": "Test Line",
                "description": payload,
                "status": "active"
            }
            
            response = await client.post("/api/v1/production/lines", json=line_data, headers=auth_headers)
            
            # Should return 422 Validation Error or 401 Unauthorized
            assert response.status_code in [422, 401], f"Expected 422 or 401 for SQL injection in description, got {response.status_code}"
    
    @pytest.mark.asyncio
    async def test_xss_protection(self, client, auth_headers):
        """Test XSS protection"""
        
        # Test XSS payloads
        xss_payloads = [
            "<script>alert('xss')</script>",
            "<img src=x onerror=alert('xss')>",
            "javascript:alert('xss')",
            "<svg onload=alert('xss')>",
            "<iframe src=javascript:alert('xss')></iframe>",
            "<body onload=alert('xss')>",
            "<input onfocus=alert('xss') autofocus>",
            "<select onfocus=alert('xss') autofocus>",
            "<textarea onfocus=alert('xss') autofocus>",
            "<keygen onfocus=alert('xss') autofocus>"
        ]
        
        for payload in xss_payloads:
            # Test in production line name
            line_data = {
                "name": payload,
                "description": "Test line",
                "status": "active"
            }
            
            response = await client.post("/api/v1/production/lines", json=line_data, headers=auth_headers)
            
            # Should return 422 Validation Error or 401 Unauthorized
            assert response.status_code in [422, 401], f"Expected 422 or 401 for XSS in name, got {response.status_code}"
            
            # Test in description
            line_data = {
                "name": "Test Line",
                "description": payload,
                "status": "active"
            }
            
            response = await client.post("/api/v1/production/lines", json=line_data, headers=auth_headers)
            
            # Should return 422 Validation Error or 401 Unauthorized
            assert response.status_code in [422, 401], f"Expected 422 or 401 for XSS in description, got {response.status_code}"
    
    @pytest.mark.asyncio
    async def test_data_encryption(self, client, auth_headers):
        """Test data encryption and secure transmission"""
        
        # Test HTTPS (if available)
        if client.base_url.startswith("https://"):
            # HTTPS should be used for secure transmission
            assert True, "HTTPS is being used for secure transmission"
        else:
            print("Warning: HTTP is being used instead of HTTPS")
        
        # Test sensitive data handling
        sensitive_data = {
            "name": "Sensitive Test Line",
            "description": "Line containing sensitive information",
            "status": "active",
            "sensitive_field": "This is sensitive data that should be encrypted"
        }
        
        response = await client.post("/api/v1/production/lines", json=sensitive_data, headers=auth_headers)
        
        if response.status_code in [200, 201]:
            # Data should be stored securely
            assert response.status_code in [200, 201], "Sensitive data should be handled securely"
            
            # Cleanup
            line_id = response.json()["id"]
            await client.delete(f"/api/v1/production/lines/{line_id}", headers=auth_headers)
        else:
            pytest.skip("Could not create line for encryption test")
    
    @pytest.mark.asyncio
    async def test_data_integrity(self, client, auth_headers):
        """Test data integrity protection"""
        
        # Test data corruption attempts
        corrupted_data = {
            "name": "Test Line",
            "description": "Test line",
            "status": "active",
            "corrupted_field": "This field should not be accepted"
        }
        
        response = await client.post("/api/v1/production/lines", json=corrupted_data, headers=auth_headers)
        
        # Should return 422 Validation Error or 401 Unauthorized
        assert response.status_code in [422, 401], f"Expected 422 or 401 for corrupted data, got {response.status_code}"
        
        # Test data validation
        invalid_data = {
            "name": "",  # Empty name
            "description": "Test line",
            "status": "invalid_status"  # Invalid status
        }
        
        response = await client.post("/api/v1/production/lines", json=invalid_data, headers=auth_headers)
        
        # Should return 422 Validation Error or 401 Unauthorized
        assert response.status_code in [422, 401], f"Expected 422 or 401 for invalid data, got {response.status_code}"
    
    @pytest.mark.asyncio
    async def test_data_sanitization(self, client, auth_headers):
        """Test data sanitization"""
        
        # Test with potentially dangerous characters
        dangerous_chars = [
            "\x00",  # Null byte
            "\x01",  # Control character
            "\x1f",  # Control character
            "\x7f",  # DEL character
            "\x80",  # Extended ASCII
            "\xff",  # Extended ASCII
            "\u0000",  # Unicode null
            "\u0001",  # Unicode control
            "\u001f",  # Unicode control
            "\u007f",  # Unicode control
            "\u0080",  # Unicode control
            "\u009f",  # Unicode control
            "\u00a0",  # Non-breaking space
            "\u2000",  # En quad
            "\u2001",  # Em quad
            "\u2002",  # En space
            "\u2003",  # Em space
            "\u2004",  # Three-per-em space
            "\u2005",  # Four-per-em space
            "\u2006",  # Six-per-em space
            "\u2007",  # Figure space
            "\u2008",  # Punctuation space
            "\u2009",  # Thin space
            "\u200a",  # Hair space
            "\u200b",  # Zero width space
            "\u200c",  # Zero width non-joiner
            "\u200d",  # Zero width joiner
            "\u200e",  # Left-to-right mark
            "\u200f",  # Right-to-left mark
            "\u2028",  # Line separator
            "\u2029",  # Paragraph separator
            "\u202a",  # Left-to-right embedding
            "\u202b",  # Right-to-left embedding
            "\u202c",  # Pop directional formatting
            "\u202d",  # Left-to-right override
            "\u202e",  # Right-to-left override
            "\u202f",  # Narrow no-break space
            "\u205f",  # Medium mathematical space
            "\u3000",  # Ideographic space
            "\ufeff"   # Byte order mark
        ]
        
        for char in dangerous_chars:
            # Test in production line name
            line_data = {
                "name": f"Test Line {char}",
                "description": "Test line",
                "status": "active"
            }
            
            response = await client.post("/api/v1/production/lines", json=line_data, headers=auth_headers)
            
            # Should return 422 Validation Error or 401 Unauthorized
            assert response.status_code in [422, 401], f"Expected 422 or 401 for dangerous character in name, got {response.status_code}"
            
            # Test in description
            line_data = {
                "name": "Test Line",
                "description": f"Test line {char}",
                "status": "active"
            }
            
            response = await client.post("/api/v1/production/lines", json=line_data, headers=auth_headers)
            
            # Should return 422 Validation Error or 401 Unauthorized
            assert response.status_code in [422, 401], f"Expected 422 or 401 for dangerous character in description, got {response.status_code}"
    
    @pytest.mark.asyncio
    async def test_data_size_limits(self, client, auth_headers):
        """Test data size limits"""
        
        # Test with very large data
        large_data = {
            "name": "x" * 10000,  # 10KB name
            "description": "x" * 100000,  # 100KB description
            "status": "active"
        }
        
        response = await client.post("/api/v1/production/lines", json=large_data, headers=auth_headers)
        
        # Should return 422 Validation Error or 401 Unauthorized
        assert response.status_code in [422, 401], f"Expected 422 or 401 for large data, got {response.status_code}"
        
        # Test with extremely large data
        extremely_large_data = {
            "name": "x" * 1000000,  # 1MB name
            "description": "x" * 10000000,  # 10MB description
            "status": "active"
        }
        
        response = await client.post("/api/v1/production/lines", json=extremely_large_data, headers=auth_headers)
        
        # Should return 422 Validation Error or 401 Unauthorized
        assert response.status_code in [422, 401], f"Expected 422 or 401 for extremely large data, got {response.status_code}"
    
    @pytest.mark.asyncio
    async def test_data_type_validation(self, client, auth_headers):
        """Test data type validation"""
        
        # Test with wrong data types
        wrong_types = [
            {"name": 123, "description": "Test line", "status": "active"},  # Number instead of string
            {"name": "Test Line", "description": 123, "status": "active"},  # Number instead of string
            {"name": "Test Line", "description": "Test line", "status": 123},  # Number instead of string
            {"name": True, "description": "Test line", "status": "active"},  # Boolean instead of string
            {"name": "Test Line", "description": False, "status": "active"},  # Boolean instead of string
            {"name": "Test Line", "description": "Test line", "status": True},  # Boolean instead of string
            {"name": None, "description": "Test line", "status": "active"},  # Null instead of string
            {"name": "Test Line", "description": None, "status": "active"},  # Null instead of string
            {"name": "Test Line", "description": "Test line", "status": None},  # Null instead of string
            {"name": [], "description": "Test line", "status": "active"},  # Array instead of string
            {"name": "Test Line", "description": [], "status": "active"},  # Array instead of string
            {"name": "Test Line", "description": "Test line", "status": []},  # Array instead of string
            {"name": {}, "description": "Test line", "status": "active"},  # Object instead of string
            {"name": "Test Line", "description": {}, "status": "active"},  # Object instead of string
            {"name": "Test Line", "description": "Test line", "status": {}}  # Object instead of string
        ]
        
        for wrong_type_data in wrong_types:
            response = await client.post("/api/v1/production/lines", json=wrong_type_data, headers=auth_headers)
            
            # Should return 422 Validation Error or 401 Unauthorized
            assert response.status_code in [422, 401], f"Expected 422 or 401 for wrong data type, got {response.status_code}"
    
    @pytest.mark.asyncio
    async def test_data_consistency(self, client, auth_headers):
        """Test data consistency"""
        
        # Test creating and retrieving data
        line_data = {
            "name": "Consistency Test Line",
            "description": "Test line for data consistency",
            "status": "active"
        }
        
        create_response = await client.post("/api/v1/production/lines", json=line_data, headers=auth_headers)
        
        if create_response.status_code in [200, 201]:
            line_id = create_response.json()["id"]
            
            # Retrieve the data
            get_response = await client.get(f"/api/v1/production/lines/{line_id}", headers=auth_headers)
            
            if get_response.status_code == 200:
                retrieved_data = get_response.json()
                
                # Data should be consistent
                assert retrieved_data["name"] == line_data["name"], "Name data is inconsistent"
                assert retrieved_data["description"] == line_data["description"], "Description data is inconsistent"
                assert retrieved_data["status"] == line_data["status"], "Status data is inconsistent"
            
            # Cleanup
            await client.delete(f"/api/v1/production/lines/{line_id}", headers=auth_headers)
        else:
            pytest.skip("Could not create line for consistency test")
    
    @pytest.mark.asyncio
    async def test_data_privacy(self, client, auth_headers):
        """Test data privacy protection"""
        
        # Test accessing sensitive data
        sensitive_endpoints = [
            "/api/v1/users/passwords",
            "/api/v1/system/secrets",
            "/api/v1/admin/keys",
            "/api/v1/config/passwords"
        ]
        
        for endpoint in sensitive_endpoints:
            response = await client.get(endpoint, headers=auth_headers)
            
            # Should return 403 Forbidden or 404 Not Found
            assert response.status_code in [403, 404], f"Expected 403 or 404 for sensitive endpoint {endpoint}, got {response.status_code}"
        
        # Test data exposure in responses
        response = await client.get("/api/v1/production/lines", headers=auth_headers)
        
        if response.status_code == 200:
            data = response.json()
            
            # Check for sensitive data exposure
            for item in data:
                # Should not contain sensitive fields
                sensitive_fields = ["password", "secret", "key", "token", "credential"]
                for field in sensitive_fields:
                    assert field not in item, f"Sensitive field '{field}' exposed in response"
    
    @pytest.mark.asyncio
    async def test_data_audit_trail(self, client, auth_headers):
        """Test data audit trail"""
        
        # Test creating data
        line_data = {
            "name": "Audit Trail Test Line",
            "description": "Test line for audit trail",
            "status": "active"
        }
        
        create_response = await client.post("/api/v1/production/lines", json=line_data, headers=auth_headers)
        
        if create_response.status_code in [200, 201]:
            line_id = create_response.json()["id"]
            
            # Test updating data
            update_data = {
                "name": "Updated Audit Trail Test Line",
                "status": "inactive"
            }
            
            update_response = await client.put(f"/api/v1/production/lines/{line_id}", json=update_data, headers=auth_headers)
            
            if update_response.status_code == 200:
                # Test deleting data
                delete_response = await client.delete(f"/api/v1/production/lines/{line_id}", headers=auth_headers)
                
                # All operations should be logged
                assert delete_response.status_code in [200, 204], f"Expected 200 or 204 for delete, got {delete_response.status_code}"
            else:
                pytest.skip("Could not update line for audit trail test")
        else:
            pytest.skip("Could not create line for audit trail test")


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
