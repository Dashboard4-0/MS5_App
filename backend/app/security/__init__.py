"""
MS5.0 Floor Dashboard - Security Module

This module provides comprehensive security features for the MS5.0 Floor Dashboard API,
including input validation, sanitization, security headers, CSRF protection, and audit logging.

Architecture: Starship-grade security system designed for cosmic-scale reliability.
Every component is production-ready, self-documenting, and testable by default.
"""

from .input_validation import InputValidator, ValidationError as SecurityValidationError
from .sanitization import ContentSanitizer, XSSProtection
from .security_headers import SecurityHeadersMiddleware
from .csrf_protection import CSRFProtection, CSRFMiddleware
from .audit_logging import AuditLogger, SecurityEventLogger
from .rate_limiting import RateLimiter, RateLimitMiddleware
from .sql_injection_prevention import SQLInjectionPrevention, QuerySanitizer
from .access_control import AccessControlValidator, SessionManager
from .gdpr_compliance import GDPRCompliance, DataSubjectRights
from .data_retention import DataRetentionManager, RetentionPolicy
from .security_testing import SecurityTestSuite, VulnerabilityScanner

__all__ = [
    # Input validation and sanitization
    "InputValidator",
    "SecurityValidationError", 
    "ContentSanitizer",
    "XSSProtection",
    
    # Security middleware
    "SecurityHeadersMiddleware",
    "CSRFProtection",
    "CSRFMiddleware",
    "RateLimiter",
    "RateLimitMiddleware",
    
    # Database security
    "SQLInjectionPrevention",
    "QuerySanitizer",
    
    # Access control and session management
    "AccessControlValidator",
    "SessionManager",
    
    # Audit and compliance
    "AuditLogger",
    "SecurityEventLogger",
    "GDPRCompliance",
    "DataSubjectRights",
    "DataRetentionManager",
    "RetentionPolicy",
    
    # Testing and validation
    "SecurityTestSuite",
    "VulnerabilityScanner",
]
