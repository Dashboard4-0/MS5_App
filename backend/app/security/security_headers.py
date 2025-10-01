"""
MS5.0 Floor Dashboard - Security Headers Middleware

Comprehensive security headers implementation for production-grade protection.
Implements all modern security headers with proper configuration for different environments.

Architecture: Starship-grade security headers system that provides multiple layers
of protection against various attack vectors.
"""

from typing import Dict, List, Optional
from fastapi import Request, Response
from fastapi.middleware.base import BaseHTTPMiddleware
from starlette.middleware.base import RequestResponseEndpoint
import structlog

from app.config import settings

logger = structlog.get_logger()


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    """
    Comprehensive security headers middleware.
    
    Implements all modern security headers including CSP, HSTS, X-Frame-Options,
    and many others for maximum security.
    """
    
    def __init__(self, app, security_level: str = "high"):
        """
        Initialize security headers middleware.
        
        Args:
            app: FastAPI application
            security_level: Security level ("low", "medium", "high", "maximum")
        """
        super().__init__(app)
        self.security_level = security_level
        self.headers_config = self._configure_headers()
    
    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        """Add security headers to response."""
        response = await call_next(request)
        
        # Add security headers
        for header_name, header_value in self.headers_config.items():
            if header_value:
                response.headers[header_name] = header_value
        
        # Log security headers for audit
        logger.debug(
            "Security headers applied",
            path=request.url.path,
            method=request.method,
            headers_applied=list(self.headers_config.keys())
        )
        
        return response
    
    def _configure_headers(self) -> Dict[str, str]:
        """Configure security headers based on security level and environment."""
        headers = {}
        
        # Content Security Policy (CSP)
        headers["Content-Security-Policy"] = self._get_csp_header()
        
        # HTTP Strict Transport Security (HSTS)
        headers["Strict-Transport-Security"] = self._get_hsts_header()
        
        # X-Frame-Options
        headers["X-Frame-Options"] = self._get_frame_options_header()
        
        # X-Content-Type-Options
        headers["X-Content-Type-Options"] = "nosniff"
        
        # X-XSS-Protection
        headers["X-XSS-Protection"] = "1; mode=block"
        
        # Referrer Policy
        headers["Referrer-Policy"] = self._get_referrer_policy_header()
        
        # Permissions Policy
        headers["Permissions-Policy"] = self._get_permissions_policy_header()
        
        # Cross-Origin Embedder Policy
        headers["Cross-Origin-Embedder-Policy"] = self._get_coep_header()
        
        # Cross-Origin Opener Policy
        headers["Cross-Origin-Opener-Policy"] = self._get_coop_header()
        
        # Cross-Origin Resource Policy
        headers["Cross-Origin-Resource-Policy"] = self._get_corp_header()
        
        # Cache Control for sensitive endpoints
        if settings.ENVIRONMENT == "production":
            headers["Cache-Control"] = self._get_cache_control_header()
        
        return headers
    
    def _get_csp_header(self) -> str:
        """Get Content Security Policy header."""
        if self.security_level == "maximum":
            # Maximum security - very restrictive CSP
            return (
                "default-src 'self'; "
                "script-src 'self'; "
                "style-src 'self' 'unsafe-inline'; "
                "img-src 'self' data:; "
                "font-src 'self'; "
                "connect-src 'self'; "
                "frame-ancestors 'none'; "
                "base-uri 'self'; "
                "form-action 'self'; "
                "object-src 'none'; "
                "media-src 'self'; "
                "worker-src 'self'; "
                "manifest-src 'self'"
            )
        elif self.security_level == "high":
            # High security - restrictive CSP
            return (
                "default-src 'self'; "
                "script-src 'self' 'unsafe-inline'; "
                "style-src 'self' 'unsafe-inline'; "
                "img-src 'self' data: https:; "
                "font-src 'self' https:; "
                "connect-src 'self' wss: ws:; "
                "frame-ancestors 'self'; "
                "base-uri 'self'; "
                "form-action 'self'; "
                "object-src 'none'; "
                "media-src 'self'; "
                "worker-src 'self'; "
                "manifest-src 'self'"
            )
        elif self.security_level == "medium":
            # Medium security - balanced CSP
            return (
                "default-src 'self'; "
                "script-src 'self' 'unsafe-inline' 'unsafe-eval'; "
                "style-src 'self' 'unsafe-inline'; "
                "img-src 'self' data: https:; "
                "font-src 'self' https:; "
                "connect-src 'self' wss: ws: https:; "
                "frame-ancestors 'self'; "
                "base-uri 'self'; "
                "form-action 'self'; "
                "object-src 'none'; "
                "media-src 'self'; "
                "worker-src 'self'; "
                "manifest-src 'self'"
            )
        else:  # low security
            # Low security - permissive CSP
            return (
                "default-src 'self' 'unsafe-inline' 'unsafe-eval' data: blob:; "
                "script-src 'self' 'unsafe-inline' 'unsafe-eval'; "
                "style-src 'self' 'unsafe-inline'; "
                "img-src 'self' data: https: blob:; "
                "font-src 'self' https: data:; "
                "connect-src 'self' wss: ws: https:; "
                "frame-ancestors 'self'; "
                "base-uri 'self'; "
                "form-action 'self'; "
                "object-src 'self'; "
                "media-src 'self'; "
                "worker-src 'self'; "
                "manifest-src 'self'"
            )
    
    def _get_hsts_header(self) -> str:
        """Get HTTP Strict Transport Security header."""
        if settings.ENVIRONMENT == "production":
            if self.security_level in ["high", "maximum"]:
                return "max-age=31536000; includeSubDomains; preload"
            else:
                return "max-age=31536000; includeSubDomains"
        else:
            # Shorter max-age for development
            return "max-age=86400"
    
    def _get_frame_options_header(self) -> str:
        """Get X-Frame-Options header."""
        if self.security_level in ["high", "maximum"]:
            return "DENY"
        else:
            return "SAMEORIGIN"
    
    def _get_referrer_policy_header(self) -> str:
        """Get Referrer Policy header."""
        policies = {
            "maximum": "no-referrer",
            "high": "strict-origin-when-cross-origin",
            "medium": "strict-origin-when-cross-origin",
            "low": "strict-origin-when-cross-origin"
        }
        return policies.get(self.security_level, "strict-origin-when-cross-origin")
    
    def _get_permissions_policy_header(self) -> str:
        """Get Permissions Policy header."""
        if self.security_level == "maximum":
            # Maximum security - deny most features
            return (
                "accelerometer=(), "
                "ambient-light-sensor=(), "
                "autoplay=(), "
                "battery=(), "
                "camera=(), "
                "display-capture=(), "
                "document-domain=(), "
                "encrypted-media=(), "
                "execution-while-not-rendered=(), "
                "execution-while-out-of-viewport=(), "
                "fullscreen=(), "
                "geolocation=(), "
                "gyroscope=(), "
                "magnetometer=(), "
                "microphone=(), "
                "midi=(), "
                "navigation-override=(), "
                "payment=(), "
                "picture-in-picture=(), "
                "publickey-credentials-get=(), "
                "screen-wake-lock=(), "
                "sync-xhr=(), "
                "usb=(), "
                "web-share=(), "
                "xr-spatial-tracking=()"
            )
        elif self.security_level == "high":
            # High security - allow minimal features
            return (
                "accelerometer=(), "
                "ambient-light-sensor=(), "
                "autoplay=(), "
                "battery=(), "
                "camera=(), "
                "display-capture=(), "
                "document-domain=(), "
                "encrypted-media=(), "
                "execution-while-not-rendered=(), "
                "execution-while-out-of-viewport=(), "
                "fullscreen=(self), "
                "geolocation=(), "
                "gyroscope=(), "
                "magnetometer=(), "
                "microphone=(), "
                "midi=(), "
                "navigation-override=(), "
                "payment=(), "
                "picture-in-picture=(), "
                "publickey-credentials-get=(), "
                "screen-wake-lock=(), "
                "sync-xhr=(), "
                "usb=(), "
                "web-share=(), "
                "xr-spatial-tracking=()"
            )
        else:
            # Medium/Low security - allow more features
            return (
                "accelerometer=(self), "
                "ambient-light-sensor=(self), "
                "autoplay=(self), "
                "battery=(self), "
                "camera=(self), "
                "display-capture=(self), "
                "document-domain=(self), "
                "encrypted-media=(self), "
                "execution-while-not-rendered=(self), "
                "execution-while-out-of-viewport=(self), "
                "fullscreen=(self), "
                "geolocation=(self), "
                "gyroscope=(self), "
                "magnetometer=(self), "
                "microphone=(self), "
                "midi=(self), "
                "navigation-override=(self), "
                "payment=(self), "
                "picture-in-picture=(self), "
                "publickey-credentials-get=(self), "
                "screen-wake-lock=(self), "
                "sync-xhr=(self), "
                "usb=(self), "
                "web-share=(self), "
                "xr-spatial-tracking=(self)"
            )
    
    def _get_coep_header(self) -> str:
        """Get Cross-Origin Embedder Policy header."""
        if self.security_level in ["high", "maximum"]:
            return "require-corp"
        else:
            return "unsafe-none"
    
    def _get_coop_header(self) -> str:
        """Get Cross-Origin Opener Policy header."""
        if self.security_level in ["high", "maximum"]:
            return "same-origin"
        else:
            return "same-origin-allow-popups"
    
    def _get_corp_header(self) -> str:
        """Get Cross-Origin Resource Policy header."""
        if self.security_level in ["high", "maximum"]:
            return "same-origin"
        else:
            return "cross-origin"
    
    def _get_cache_control_header(self) -> str:
        """Get Cache Control header for sensitive endpoints."""
        return "no-store, no-cache, must-revalidate, proxy-revalidate"


def get_security_headers(security_level: str = "high") -> Dict[str, str]:
    """
    Get security headers configuration.
    
    Args:
        security_level: Security level for headers
        
    Returns:
        Dictionary of security headers
    """
    middleware = SecurityHeadersMiddleware(None, security_level)
    return middleware._configure_headers()


def apply_security_headers(response: Response, security_level: str = "high") -> Response:
    """
    Apply security headers to a response.
    
    Args:
        response: Response object
        security_level: Security level for headers
        
    Returns:
        Response with security headers applied
    """
    headers = get_security_headers(security_level)
    
    for header_name, header_value in headers.items():
        if header_value:
            response.headers[header_name] = header_value
    
    return response
