"""
MS5.0 Floor Dashboard - Input Validation Module

Comprehensive input validation system designed for production-grade security.
Validates all incoming data with precision and provides detailed error reporting.

Architecture: Starship-grade validation engine that treats every input as potentially hostile.
"""

import re
import html
import json
from typing import Any, Dict, List, Optional, Union, Type, Callable
from datetime import datetime, date
from decimal import Decimal
from uuid import UUID
from enum import Enum
import structlog

from pydantic import BaseModel, ValidationError as PydanticValidationError
from fastapi import HTTPException, status

logger = structlog.get_logger()


class ValidationError(Exception):
    """Custom validation error with detailed context."""
    
    def __init__(self, message: str, field: str = None, value: Any = None, 
                 error_code: str = "VALIDATION_ERROR"):
        self.message = message
        self.field = field
        self.value = value
        self.error_code = error_code
        super().__init__(message)


class SecurityValidationError(ValidationError):
    """Security-specific validation error."""
    
    def __init__(self, message: str, field: str = None, value: Any = None,
                 threat_type: str = "UNKNOWN_THREAT"):
        self.threat_type = threat_type
        super().__init__(message, field, value, "SECURITY_VALIDATION_ERROR")


class InputValidator:
    """
    Comprehensive input validation system.
    
    Provides validation for all data types with security-focused checks.
    Designed to prevent injection attacks, XSS, and other security threats.
    """
    
    # Security patterns for threat detection
    SQL_INJECTION_PATTERNS = [
        r"(\b(SELECT|INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|EXEC|UNION|SCRIPT)\b)",
        r"(--|\#|\/\*|\*\/)",
        r"(\b(OR|AND)\s+\d+\s*=\s*\d+)",
        r"(\b(OR|AND)\s+['\"]?\w+['\"]?\s*=\s*['\"]?\w+['\"]?)",
        r"(\bUNION\s+SELECT\b)",
        r"(\bDROP\s+TABLE\b)",
        r"(\bINSERT\s+INTO\b)",
        r"(\bUPDATE\s+\w+\s+SET\b)",
        r"(\bDELETE\s+FROM\b)",
    ]
    
    XSS_PATTERNS = [
        r"<script[^>]*>.*?</script>",
        r"javascript:",
        r"vbscript:",
        r"onload\s*=",
        r"onerror\s*=",
        r"onclick\s*=",
        r"onmouseover\s*=",
        r"<iframe[^>]*>",
        r"<object[^>]*>",
        r"<embed[^>]*>",
        r"<link[^>]*>",
        r"<meta[^>]*>",
        r"<style[^>]*>",
    ]
    
    COMMAND_INJECTION_PATTERNS = [
        r"[;&|`$]",
        r"\b(cat|ls|pwd|whoami|id|uname|ps|netstat|ifconfig)\b",
        r"(\$\{.*\})",
        r"(\$\(.*\))",
        r"(\`.*\`)",
    ]
    
    # Field-specific validation rules
    VALIDATION_RULES = {
        "username": {
            "min_length": 3,
            "max_length": 50,
            "pattern": r"^[a-zA-Z0-9_-]+$",
            "forbidden_patterns": SQL_INJECTION_PATTERNS + XSS_PATTERNS
        },
        "email": {
            "pattern": r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$",
            "max_length": 254,
            "forbidden_patterns": XSS_PATTERNS
        },
        "password": {
            "min_length": 8,
            "max_length": 128,
            "require_uppercase": True,
            "require_lowercase": True,
            "require_digits": True,
            "require_special": True,
            "forbidden_patterns": SQL_INJECTION_PATTERNS + XSS_PATTERNS
        },
        "employee_id": {
            "pattern": r"^[A-Z0-9-]+$",
            "min_length": 3,
            "max_length": 20,
            "forbidden_patterns": SQL_INJECTION_PATTERNS + XSS_PATTERNS
        },
        "equipment_code": {
            "pattern": r"^[A-Z0-9_-]+$",
            "min_length": 2,
            "max_length": 20,
            "forbidden_patterns": SQL_INJECTION_PATTERNS + XSS_PATTERNS
        },
        "production_line_id": {
            "pattern": r"^[A-Z0-9_-]+$",
            "min_length": 2,
            "max_length": 20,
            "forbidden_patterns": SQL_INJECTION_PATTERNS + XSS_PATTERNS
        }
    }
    
    def __init__(self):
        """Initialize the input validator."""
        self.compiled_patterns = {
            "sql_injection": [re.compile(pattern, re.IGNORECASE) for pattern in self.SQL_INJECTION_PATTERNS],
            "xss": [re.compile(pattern, re.IGNORECASE) for pattern in self.XSS_PATTERNS],
            "command_injection": [re.compile(pattern, re.IGNORECASE) for pattern in self.COMMAND_INJECTION_PATTERNS]
        }
    
    def validate_string(self, value: Any, field_name: str = None, 
                       min_length: int = None, max_length: int = None,
                       pattern: str = None, required: bool = True) -> str:
        """
        Validate string input with comprehensive security checks.
        
        Args:
            value: Input value to validate
            field_name: Name of the field for error reporting
            min_length: Minimum string length
            max_length: Maximum string length
            pattern: Regex pattern for validation
            required: Whether the field is required
            
        Returns:
            Validated string
            
        Raises:
            ValidationError: If validation fails
        """
        if value is None:
            if required:
                raise ValidationError(f"Field '{field_name}' is required", field_name)
            return ""
        
        # Convert to string
        if not isinstance(value, str):
            value = str(value)
        
        # Check for security threats
        self._check_security_threats(value, field_name)
        
        # Length validation
        if min_length is not None and len(value) < min_length:
            raise ValidationError(
                f"Field '{field_name}' must be at least {min_length} characters long",
                field_name, value
            )
        
        if max_length is not None and len(value) > max_length:
            raise ValidationError(
                f"Field '{field_name}' exceeds maximum length of {max_length} characters",
                field_name, value
            )
        
        # Pattern validation
        if pattern:
            if not re.match(pattern, value):
                raise ValidationError(
                    f"Field '{field_name}' does not match required pattern",
                    field_name, value
                )
        
        return value.strip()
    
    def validate_email(self, value: Any, field_name: str = "email") -> str:
        """Validate email address with security checks."""
        email = self.validate_string(
            value, field_name,
            max_length=254,
            pattern=r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
        )
        
        # Additional email security checks
        if email:
            # Check for suspicious patterns
            suspicious_patterns = [
                r"\.{2,}",  # Multiple consecutive dots
                r"@.*@",    # Multiple @ symbols
                r"\.@",     # Dot before @
                r"@\.",     # @ before dot
            ]
            
            for pattern in suspicious_patterns:
                if re.search(pattern, email):
                    raise SecurityValidationError(
                        f"Invalid email format detected in '{field_name}'",
                        field_name, email, "SUSPICIOUS_EMAIL_FORMAT"
                    )
        
        return email.lower()
    
    def validate_password(self, value: Any, field_name: str = "password") -> str:
        """Validate password with comprehensive security requirements."""
        password = self.validate_string(
            value, field_name,
            min_length=8,
            max_length=128,
            required=True
        )
        
        # Password strength validation
        if password:
            # Check for uppercase letters
            if not re.search(r"[A-Z]", password):
                raise ValidationError(
                    f"Password must contain at least one uppercase letter",
                    field_name
                )
            
            # Check for lowercase letters
            if not re.search(r"[a-z]", password):
                raise ValidationError(
                    f"Password must contain at least one lowercase letter",
                    field_name
                )
            
            # Check for digits
            if not re.search(r"\d", password):
                raise ValidationError(
                    f"Password must contain at least one digit",
                    field_name
                )
            
            # Check for special characters
            if not re.search(r"[!@#$%^&*()_+\-=\[\]{};':\"\\|,.<>\/?]", password):
                raise ValidationError(
                    f"Password must contain at least one special character",
                    field_name
                )
            
            # Check for common weak passwords
            weak_passwords = [
                "password", "123456", "qwerty", "abc123", "password123",
                "admin", "letmein", "welcome", "monkey", "dragon"
            ]
            
            if password.lower() in weak_passwords:
                raise SecurityValidationError(
                    f"Password is too common and easily guessable",
                    field_name, "WEAK_PASSWORD"
                )
        
        return password
    
    def validate_integer(self, value: Any, field_name: str = None,
                        min_value: int = None, max_value: int = None,
                        required: bool = True) -> int:
        """Validate integer input."""
        if value is None:
            if required:
                raise ValidationError(f"Field '{field_name}' is required", field_name)
            return 0
        
        try:
            int_value = int(value)
        except (ValueError, TypeError):
            raise ValidationError(
                f"Field '{field_name}' must be a valid integer",
                field_name, value
            )
        
        if min_value is not None and int_value < min_value:
            raise ValidationError(
                f"Field '{field_name}' must be at least {min_value}",
                field_name, value
            )
        
        if max_value is not None and int_value > max_value:
            raise ValidationError(
                f"Field '{field_name}' must be at most {max_value}",
                field_name, value
            )
        
        return int_value
    
    def validate_float(self, value: Any, field_name: str = None,
                      min_value: float = None, max_value: float = None,
                      required: bool = True) -> float:
        """Validate float input."""
        if value is None:
            if required:
                raise ValidationError(f"Field '{field_name}' is required", field_name)
            return 0.0
        
        try:
            float_value = float(value)
        except (ValueError, TypeError):
            raise ValidationError(
                f"Field '{field_name}' must be a valid number",
                field_name, value
            )
        
        if min_value is not None and float_value < min_value:
            raise ValidationError(
                f"Field '{field_name}' must be at least {min_value}",
                field_name, value
            )
        
        if max_value is not None and float_value > max_value:
            raise ValidationError(
                f"Field '{field_name}' must be at most {max_value}",
                field_name, value
            )
        
        return float_value
    
    def validate_uuid(self, value: Any, field_name: str = None, required: bool = True) -> str:
        """Validate UUID input."""
        if value is None:
            if required:
                raise ValidationError(f"Field '{field_name}' is required", field_name)
            return None
        
        try:
            uuid_str = str(value)
            UUID(uuid_str)  # This will raise ValueError if invalid
            return uuid_str
        except (ValueError, TypeError):
            raise ValidationError(
                f"Field '{field_name}' must be a valid UUID",
                field_name, value
            )
    
    def validate_datetime(self, value: Any, field_name: str = None, 
                         required: bool = True) -> datetime:
        """Validate datetime input."""
        if value is None:
            if required:
                raise ValidationError(f"Field '{field_name}' is required", field_name)
            return None
        
        if isinstance(value, datetime):
            return value
        
        if isinstance(value, str):
            try:
                # Try parsing ISO format
                return datetime.fromisoformat(value.replace('Z', '+00:00'))
            except ValueError:
                try:
                    # Try parsing common formats
                    for fmt in ['%Y-%m-%d %H:%M:%S', '%Y-%m-%d', '%d/%m/%Y']:
                        try:
                            return datetime.strptime(value, fmt)
                        except ValueError:
                            continue
                except ValueError:
                    pass
        
        raise ValidationError(
            f"Field '{field_name}' must be a valid datetime",
            field_name, value
        )
    
    def validate_json(self, value: Any, field_name: str = None, 
                     schema: Dict = None, required: bool = True) -> Dict:
        """Validate JSON input."""
        if value is None:
            if required:
                raise ValidationError(f"Field '{field_name}' is required", field_name)
            return {}
        
        if isinstance(value, dict):
            json_data = value
        elif isinstance(value, str):
            try:
                json_data = json.loads(value)
            except json.JSONDecodeError:
                raise ValidationError(
                    f"Field '{field_name}' must be valid JSON",
                    field_name, value
                )
        else:
            raise ValidationError(
                f"Field '{field_name}' must be JSON data",
                field_name, value
            )
        
        # Additional validation if schema provided
        if schema:
            self._validate_json_schema(json_data, schema, field_name)
        
        return json_data
    
    def validate_field_by_type(self, value: Any, field_name: str, 
                              field_type: str, **kwargs) -> Any:
        """Validate field based on its type."""
        validation_methods = {
            "string": self.validate_string,
            "email": self.validate_email,
            "password": self.validate_password,
            "integer": self.validate_integer,
            "float": self.validate_float,
            "uuid": self.validate_uuid,
            "datetime": self.validate_datetime,
            "json": self.validate_json,
        }
        
        if field_type not in validation_methods:
            raise ValidationError(f"Unknown field type: {field_type}")
        
        return validation_methods[field_type](value, field_name, **kwargs)
    
    def validate_model(self, data: Dict[str, Any], model_class: Type[BaseModel]) -> BaseModel:
        """Validate data against a Pydantic model."""
        try:
            return model_class(**data)
        except PydanticValidationError as e:
            # Convert Pydantic errors to our validation errors
            errors = []
            for error in e.errors():
                field = ".".join(str(x) for x in error["loc"])
                message = error["msg"]
                errors.append(f"{field}: {message}")
            
            raise ValidationError(
                f"Model validation failed: {'; '.join(errors)}",
                error_code="MODEL_VALIDATION_ERROR"
            )
    
    def _check_security_threats(self, value: str, field_name: str = None):
        """Check for security threats in input value."""
        if not isinstance(value, str):
            return
        
        # Check for SQL injection patterns
        for pattern in self.compiled_patterns["sql_injection"]:
            if pattern.search(value):
                raise SecurityValidationError(
                    f"Potential SQL injection detected in '{field_name}'",
                    field_name, value, "SQL_INJECTION"
                )
        
        # Check for XSS patterns
        for pattern in self.compiled_patterns["xss"]:
            if pattern.search(value):
                raise SecurityValidationError(
                    f"Potential XSS attack detected in '{field_name}'",
                    field_name, value, "XSS_ATTACK"
                )
        
        # Check for command injection patterns
        for pattern in self.compiled_patterns["command_injection"]:
            if pattern.search(value):
                raise SecurityValidationError(
                    f"Potential command injection detected in '{field_name}'",
                    field_name, value, "COMMAND_INJECTION"
                )
    
    def _validate_json_schema(self, data: Dict, schema: Dict, field_name: str):
        """Validate JSON data against a schema."""
        # Basic schema validation - can be extended with JSON Schema library
        for key, expected_type in schema.items():
            if key not in data:
                continue
            
            value = data[key]
            if not isinstance(value, expected_type):
                raise ValidationError(
                    f"Field '{key}' in '{field_name}' must be of type {expected_type.__name__}",
                    f"{field_name}.{key}", value
                )


# Global validator instance
validator = InputValidator()


def validate_input(value: Any, field_name: str, field_type: str, **kwargs) -> Any:
    """
    Convenience function for input validation.
    
    Args:
        value: Value to validate
        field_name: Name of the field
        field_type: Type of validation to perform
        **kwargs: Additional validation parameters
        
    Returns:
        Validated value
        
    Raises:
        ValidationError: If validation fails
    """
    return validator.validate_field_by_type(value, field_name, field_type, **kwargs)


def validate_request_data(data: Dict[str, Any], 
                         validation_rules: Dict[str, Dict[str, Any]]) -> Dict[str, Any]:
    """
    Validate request data against validation rules.
    
    Args:
        data: Request data to validate
        validation_rules: Rules for each field
        
    Returns:
        Validated data
        
    Raises:
        ValidationError: If validation fails
    """
    validated_data = {}
    
    for field_name, rules in validation_rules.items():
        value = data.get(field_name)
        field_type = rules.get("type", "string")
        
        # Remove type from rules for validation method
        validation_params = {k: v for k, v in rules.items() if k != "type"}
        
        validated_data[field_name] = validator.validate_field_by_type(
            value, field_name, field_type, **validation_params
        )
    
    return validated_data
