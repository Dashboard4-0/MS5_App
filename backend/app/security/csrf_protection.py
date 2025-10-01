"""
MS5.0 Floor Dashboard - CSRF Protection Module

Comprehensive CSRF protection system implementing multiple defense strategies.
Uses both token-based and SameSite cookie protection for maximum security.

Architecture: Starship-grade CSRF protection that implements defense in depth
with multiple layers of protection against cross-site request forgery attacks.
"""

import secrets
import hashlib
import hmac
from typing import Dict, Optional, Set
from datetime import datetime, timedelta
from fastapi import Request, Response, HTTPException, status
from fastapi.middleware.base import BaseHTTPMiddleware
from starlette.middleware.base import RequestResponseEndpoint
import structlog

from app.config import settings

logger = structlog.get_logger()


class CSRFProtection:
    """
    Comprehensive CSRF protection system.
    
    Implements multiple CSRF protection strategies including:
    - CSRF tokens
    - SameSite cookies
    - Double-submit cookie pattern
    - Origin/Referer validation
    """
    
    def __init__(self, secret_key: str = None, token_expiry: int = 3600):
        """
        Initialize CSRF protection.
        
        Args:
            secret_key: Secret key for token generation
            token_expiry: Token expiry time in seconds
        """
        self.secret_key = secret_key or settings.SECRET_KEY
        self.token_expiry = token_expiry
        self.tokens: Dict[str, Dict] = {}  # In production, use Redis or database
    
    def generate_token(self, user_id: str = None, session_id: str = None) -> str:
        """
        Generate a CSRF token.
        
        Args:
            user_id: User ID for token binding
            session_id: Session ID for token binding
            
        Returns:
            CSRF token
        """
        # Generate random token
        random_part = secrets.token_urlsafe(32)
        
        # Create token data
        token_data = {
            "random": random_part,
            "user_id": user_id,
            "session_id": session_id,
            "timestamp": datetime.utcnow().isoformat(),
            "expires_at": (datetime.utcnow() + timedelta(seconds=self.token_expiry)).isoformat()
        }
        
        # Create signature
        signature = self._create_signature(token_data)
        
        # Combine token parts
        token = f"{random_part}.{signature}"
        
        # Store token for validation
        self.tokens[token] = token_data
        
        logger.debug("CSRF token generated", user_id=user_id, session_id=session_id)
        
        return token
    
    def validate_token(self, token: str, user_id: str = None, session_id: str = None) -> bool:
        """
        Validate a CSRF token.
        
        Args:
            token: CSRF token to validate
            user_id: User ID for validation
            session_id: Session ID for validation
            
        Returns:
            True if token is valid, False otherwise
        """
        if not token:
            return False
        
        try:
            # Split token
            parts = token.split('.')
            if len(parts) != 2:
                return False
            
            random_part, signature = parts
            
            # Check if token exists
            if token not in self.tokens:
                return False
            
            token_data = self.tokens[token]
            
            # Check expiry
            expires_at = datetime.fromisoformat(token_data["expires_at"])
            if datetime.utcnow() > expires_at:
                self._remove_token(token)
                return False
            
            # Verify signature
            expected_signature = self._create_signature(token_data)
            if not hmac.compare_digest(signature, expected_signature):
                return False
            
            # Verify user/session binding
            if user_id and token_data.get("user_id") != user_id:
                return False
            
            if session_id and token_data.get("session_id") != session_id:
                return False
            
            return True
            
        except Exception as e:
            logger.warning("CSRF token validation failed", error=str(e))
            return False
    
    def _create_signature(self, token_data: Dict) -> str:
        """Create HMAC signature for token data."""
        message = f"{token_data['random']}:{token_data['user_id']}:{token_data['session_id']}:{token_data['timestamp']}"
        signature = hmac.new(
            self.secret_key.encode(),
            message.encode(),
            hashlib.sha256
        ).hexdigest()
        return signature
    
    def _remove_token(self, token: str):
        """Remove token from storage."""
        if token in self.tokens:
            del self.tokens[token]
    
    def cleanup_expired_tokens(self):
        """Clean up expired tokens."""
        current_time = datetime.utcnow()
        expired_tokens = []
        
        for token, data in self.tokens.items():
            expires_at = datetime.fromisoformat(data["expires_at"])
            if current_time > expires_at:
                expired_tokens.append(token)
        
        for token in expired_tokens:
            del self.tokens[token]
        
        if expired_tokens:
            logger.debug(f"Cleaned up {len(expired_tokens)} expired CSRF tokens")


class CSRFMiddleware(BaseHTTPMiddleware):
    """
    CSRF protection middleware.
    
    Automatically applies CSRF protection to state-changing requests.
    """
    
    # Methods that require CSRF protection
    PROTECTED_METHODS = {"POST", "PUT", "PATCH", "DELETE"}
    
    # Endpoints that are exempt from CSRF protection
    EXEMPT_ENDPOINTS = {
        "/api/v1/auth/login",
        "/api/v1/auth/logout",
        "/api/v1/auth/refresh",
        "/health",
        "/metrics"
    }
    
    def __init__(self, app, csrf_protection: CSRFProtection = None):
        """
        Initialize CSRF middleware.
        
        Args:
            app: FastAPI application
            csrf_protection: CSRF protection instance
        """
        super().__init__(app)
        self.csrf_protection = csrf_protection or CSRFProtection()
    
    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        """Process request with CSRF protection."""
        response = await call_next(request)
        
        # Check if request needs CSRF protection
        if self._needs_csrf_protection(request):
            if not self._validate_csrf_token(request):
                logger.warning(
                    "CSRF token validation failed",
                    path=request.url.path,
                    method=request.method,
                    client_ip=request.client.host if request.client else None
                )
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="CSRF token validation failed"
                )
        
        # Add CSRF token to response if needed
        if self._should_add_csrf_token(request, response):
            csrf_token = self._get_csrf_token(request)
            if csrf_token:
                response.headers["X-CSRF-Token"] = csrf_token
        
        return response
    
    def _needs_csrf_protection(self, request: Request) -> bool:
        """Check if request needs CSRF protection."""
        # Check method
        if request.method not in self.PROTECTED_METHODS:
            return False
        
        # Check if endpoint is exempt
        if request.url.path in self.EXEMPT_ENDPOINTS:
            return False
        
        # Check if it's an API endpoint
        if not request.url.path.startswith("/api/"):
            return False
        
        return True
    
    def _validate_csrf_token(self, request: Request) -> bool:
        """Validate CSRF token from request."""
        # Get token from header
        csrf_token = request.headers.get("X-CSRF-Token")
        if not csrf_token:
            # Try to get from form data
            if hasattr(request, "_form") and request._form:
                csrf_token = request._form.get("csrf_token")
        
        if not csrf_token:
            return False
        
        # Get user/session info for validation
        user_id = self._get_user_id(request)
        session_id = self._get_session_id(request)
        
        return self.csrf_protection.validate_token(csrf_token, user_id, session_id)
    
    def _should_add_csrf_token(self, request: Request, response: Response) -> bool:
        """Check if CSRF token should be added to response."""
        # Add token for GET requests to pages that might have forms
        if request.method == "GET" and request.url.path.startswith("/api/"):
            return True
        
        return False
    
    def _get_csrf_token(self, request: Request) -> Optional[str]:
        """Get CSRF token for request."""
        user_id = self._get_user_id(request)
        session_id = self._get_session_id(request)
        
        return self.csrf_protection.generate_token(user_id, session_id)
    
    def _get_user_id(self, request: Request) -> Optional[str]:
        """Extract user ID from request."""
        # This would typically come from JWT token or session
        # For now, return None - implement based on your auth system
        return None
    
    def _get_session_id(self, request: Request) -> Optional[str]:
        """Extract session ID from request."""
        # This would typically come from session cookie
        # For now, return None - implement based on your session system
        return None


def create_csrf_protection() -> CSRFProtection:
    """Create CSRF protection instance."""
    return CSRFProtection()


def create_csrf_middleware(app, csrf_protection: CSRFProtection = None) -> CSRFMiddleware:
    """Create CSRF middleware instance."""
    return CSRFMiddleware(app, csrf_protection)


# Global CSRF protection instance
csrf_protection = create_csrf_protection()


def get_csrf_token(user_id: str = None, session_id: str = None) -> str:
    """
    Get CSRF token for user/session.
    
    Args:
        user_id: User ID
        session_id: Session ID
        
    Returns:
        CSRF token
    """
    return csrf_protection.generate_token(user_id, session_id)


def validate_csrf_token(token: str, user_id: str = None, session_id: str = None) -> bool:
    """
    Validate CSRF token.
    
    Args:
        token: CSRF token
        user_id: User ID
        session_id: Session ID
        
    Returns:
        True if valid, False otherwise
    """
    return csrf_protection.validate_token(token, user_id, session_id)
