"""
MS5.0 Floor Dashboard - Error Tracking Middleware

This middleware provides automatic error tracking for FastAPI applications:
- Automatic error capture and categorization
- Request context preservation
- Error correlation with user sessions
- Performance impact tracking
- Zero redundancy architecture
"""

import asyncio
import time
import traceback
from typing import Any, Dict, Optional, Union
from uuid import uuid4

import structlog
from fastapi import Request, Response
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware

from app.services.error_rate_monitoring_service import (
    ErrorType, ErrorSeverity, record_error, get_error_rate_report
)
from app.utils.exceptions import BusinessLogicError

logger = structlog.get_logger()


class ErrorTrackingMiddleware(BaseHTTPMiddleware):
    """Middleware for automatic error tracking and monitoring."""
    
    def __init__(self, app, enable_error_tracking: bool = True):
        super().__init__(app)
        self.enable_error_tracking = enable_error_tracking
        self.error_tracking_enabled = True
        
        # Error tracking configuration
        self.track_all_errors = True
        self.track_4xx_errors = True
        self.track_5xx_errors = True
        self.track_timeout_errors = True
        self.track_validation_errors = True
        
        # Performance tracking
        self.track_performance_impact = True
        self.slow_request_threshold = 5.0  # seconds
        
        # Context preservation
        self.preserve_request_context = True
        self.preserve_user_context = True
        self.preserve_session_context = True
    
    async def dispatch(self, request: Request, call_next):
        """Process request and track errors."""
        if not self.enable_error_tracking or not self.error_tracking_enabled:
            return await call_next(request)
        
        # Generate request ID for correlation
        request_id = str(uuid4())
        request.state.request_id = request_id
        
        # Extract request context
        request_context = await self.extract_request_context(request)
        
        # Track request start time
        start_time = time.time()
        
        try:
            # Process request
            response = await call_next(request)
            
            # Calculate request duration
            duration = time.time() - start_time
            
            # Track performance impact
            if self.track_performance_impact and duration > self.slow_request_threshold:
                await self.track_slow_request(request, response, duration, request_context)
            
            # Track error responses
            if response.status_code >= 400:
                await self.track_error_response(request, response, duration, request_context)
            
            return response
            
        except Exception as e:
            # Calculate request duration
            duration = time.time() - start_time
            
            # Track exception
            await self.track_exception(request, e, duration, request_context)
            
            # Re-raise exception for proper error handling
            raise
    
    async def extract_request_context(self, request: Request) -> Dict[str, Any]:
        """Extract request context for error tracking."""
        try:
            context = {
                'request_id': getattr(request.state, 'request_id', None),
                'method': request.method,
                'url': str(request.url),
                'path': request.url.path,
                'query_params': dict(request.query_params),
                'headers': dict(request.headers),
                'client_ip': request.client.host if request.client else None,
                'user_agent': request.headers.get('user-agent'),
                'referer': request.headers.get('referer'),
                'content_type': request.headers.get('content-type'),
                'content_length': request.headers.get('content-length'),
            }
            
            # Extract user context if available
            if self.preserve_user_context:
                user_id = getattr(request.state, 'user_id', None)
                if user_id:
                    context['user_id'] = user_id
                
                session_id = getattr(request.state, 'session_id', None)
                if session_id:
                    context['session_id'] = session_id
            
            # Extract additional context
            if hasattr(request.state, 'additional_context'):
                context.update(request.state.additional_context)
            
            return context
            
        except Exception as e:
            logger.error("Failed to extract request context", error=str(e))
            return {}
    
    async def track_error_response(
        self,
        request: Request,
        response: Response,
        duration: float,
        request_context: Dict[str, Any]
    ):
        """Track error responses."""
        try:
            # Determine error type and severity
            error_type, severity = self.classify_error_response(response.status_code)
            
            # Extract error message from response
            error_message = await self.extract_error_message(response)
            
            # Record error
            await record_error(
                error_type=error_type,
                severity=severity,
                message=error_message,
                context=request_context,
                user_id=request_context.get('user_id'),
                session_id=request_context.get('session_id'),
                request_id=request_context.get('request_id'),
                endpoint=request_context.get('path'),
                method=request_context.get('method'),
                status_code=response.status_code
            )
            
            logger.warning(
                "Error response tracked",
                status_code=response.status_code,
                error_type=error_type.value,
                severity=severity.value,
                endpoint=request_context.get('path'),
                duration=duration
            )
            
        except Exception as e:
            logger.error("Failed to track error response", error=str(e))
    
    async def track_exception(
        self,
        request: Request,
        exception: Exception,
        duration: float,
        request_context: Dict[str, Any]
    ):
        """Track exceptions."""
        try:
            # Determine error type and severity
            error_type, severity = self.classify_exception(exception)
            
            # Extract error message and stack trace
            error_message = str(exception)
            stack_trace = traceback.format_exc()
            
            # Record error
            await record_error(
                error_type=error_type,
                severity=severity,
                message=error_message,
                stack_trace=stack_trace,
                context=request_context,
                user_id=request_context.get('user_id'),
                session_id=request_context.get('session_id'),
                request_id=request_context.get('request_id'),
                endpoint=request_context.get('path'),
                method=request_context.get('method'),
                status_code=500
            )
            
            logger.error(
                "Exception tracked",
                error_type=error_type.value,
                severity=severity.value,
                endpoint=request_context.get('path'),
                duration=duration,
                exception=str(exception)
            )
            
        except Exception as e:
            logger.error("Failed to track exception", error=str(e))
    
    async def track_slow_request(
        self,
        request: Request,
        response: Response,
        duration: float,
        request_context: Dict[str, Any]
    ):
        """Track slow requests."""
        try:
            # Record slow request as a performance issue
            await record_error(
                error_type=ErrorType.SYSTEM,
                severity=ErrorSeverity.MEDIUM,
                message=f"Slow request detected: {duration:.2f}s",
                context={
                    **request_context,
                    'performance_issue': True,
                    'duration': duration,
                    'threshold': self.slow_request_threshold
                },
                user_id=request_context.get('user_id'),
                session_id=request_context.get('session_id'),
                request_id=request_context.get('request_id'),
                endpoint=request_context.get('path'),
                method=request_context.get('method'),
                status_code=response.status_code
            )
            
            logger.warning(
                "Slow request tracked",
                endpoint=request_context.get('path'),
                duration=duration,
                threshold=self.slow_request_threshold
            )
            
        except Exception as e:
            logger.error("Failed to track slow request", error=str(e))
    
    def classify_error_response(self, status_code: int) -> tuple[ErrorType, ErrorSeverity]:
        """Classify error response by status code."""
        if status_code >= 500:
            return ErrorType.SYSTEM, ErrorSeverity.CRITICAL
        elif status_code == 401:
            return ErrorType.AUTHENTICATION, ErrorSeverity.HIGH
        elif status_code == 403:
            return ErrorType.AUTHORIZATION, ErrorSeverity.HIGH
        elif status_code == 404:
            return ErrorType.APPLICATION, ErrorSeverity.MEDIUM
        elif status_code == 422:
            return ErrorType.VALIDATION, ErrorSeverity.MEDIUM
        elif status_code == 429:
            return ErrorType.RATE_LIMIT, ErrorSeverity.MEDIUM
        elif status_code >= 400:
            return ErrorType.APPLICATION, ErrorSeverity.MEDIUM
        else:
            return ErrorType.UNKNOWN, ErrorSeverity.LOW
    
    def classify_exception(self, exception: Exception) -> tuple[ErrorType, ErrorSeverity]:
        """Classify exception by type."""
        exception_type = type(exception).__name__
        
        if isinstance(exception, BusinessLogicError):
            return ErrorType.APPLICATION, ErrorSeverity.MEDIUM
        elif exception_type in ['TimeoutError', 'asyncio.TimeoutError']:
            return ErrorType.TIMEOUT, ErrorSeverity.HIGH
        elif exception_type in ['ConnectionError', 'NetworkError']:
            return ErrorType.NETWORK, ErrorSeverity.HIGH
        elif exception_type in ['ValidationError', 'ValueError', 'TypeError']:
            return ErrorType.VALIDATION, ErrorSeverity.MEDIUM
        elif exception_type in ['PermissionError', 'AccessDeniedError']:
            return ErrorType.AUTHORIZATION, ErrorSeverity.HIGH
        elif exception_type in ['AuthenticationError', 'UnauthorizedError']:
            return ErrorType.AUTHENTICATION, ErrorSeverity.HIGH
        elif exception_type in ['DatabaseError', 'SQLAlchemyError']:
            return ErrorType.DATABASE, ErrorSeverity.CRITICAL
        else:
            return ErrorType.SYSTEM, ErrorSeverity.HIGH
    
    async def extract_error_message(self, response: Response) -> str:
        """Extract error message from response."""
        try:
            # Try to extract error message from response body
            if hasattr(response, 'body'):
                body = response.body
                if isinstance(body, bytes):
                    body = body.decode('utf-8')
                
                # Try to parse JSON error message
                try:
                    import json
                    error_data = json.loads(body)
                    if isinstance(error_data, dict):
                        return error_data.get('detail', error_data.get('message', str(error_data)))
                except (json.JSONDecodeError, TypeError):
                    pass
                
                # Return raw body if JSON parsing fails
                return body[:500]  # Limit message length
            
            return f"HTTP {response.status_code} Error"
            
        except Exception as e:
            logger.error("Failed to extract error message", error=str(e))
            return f"HTTP {response.status_code} Error"
    
    def configure_error_tracking(
        self,
        track_all_errors: Optional[bool] = None,
        track_4xx_errors: Optional[bool] = None,
        track_5xx_errors: Optional[bool] = None,
        track_timeout_errors: Optional[bool] = None,
        track_validation_errors: Optional[bool] = None,
        track_performance_impact: Optional[bool] = None,
        slow_request_threshold: Optional[float] = None
    ):
        """Configure error tracking settings."""
        if track_all_errors is not None:
            self.track_all_errors = track_all_errors
        if track_4xx_errors is not None:
            self.track_4xx_errors = track_4xx_errors
        if track_5xx_errors is not None:
            self.track_5xx_errors = track_5xx_errors
        if track_timeout_errors is not None:
            self.track_timeout_errors = track_timeout_errors
        if track_validation_errors is not None:
            self.track_validation_errors = track_validation_errors
        if track_performance_impact is not None:
            self.track_performance_impact = track_performance_impact
        if slow_request_threshold is not None:
            self.slow_request_threshold = slow_request_threshold
        
        logger.info("Error tracking configuration updated", configuration={
            'track_all_errors': self.track_all_errors,
            'track_4xx_errors': self.track_4xx_errors,
            'track_5xx_errors': self.track_5xx_errors,
            'track_timeout_errors': self.track_timeout_errors,
            'track_validation_errors': self.track_validation_errors,
            'track_performance_impact': self.track_performance_impact,
            'slow_request_threshold': self.slow_request_threshold
        })
    
    def enable_error_tracking(self):
        """Enable error tracking."""
        self.error_tracking_enabled = True
        logger.info("Error tracking enabled")
    
    def disable_error_tracking(self):
        """Disable error tracking."""
        self.error_tracking_enabled = False
        logger.info("Error tracking disabled")
    
    def get_error_tracking_status(self) -> Dict[str, Any]:
        """Get error tracking status and configuration."""
        return {
            'enabled': self.error_tracking_enabled,
            'configuration': {
                'track_all_errors': self.track_all_errors,
                'track_4xx_errors': self.track_4xx_errors,
                'track_5xx_errors': self.track_5xx_errors,
                'track_timeout_errors': self.track_timeout_errors,
                'track_validation_errors': self.track_validation_errors,
                'track_performance_impact': self.track_performance_impact,
                'slow_request_threshold': self.slow_request_threshold
            }
        }


class ErrorTrackingExceptionHandler:
    """Custom exception handler for error tracking."""
    
    def __init__(self, error_tracking_middleware: ErrorTrackingMiddleware):
        self.error_tracking_middleware = error_tracking_middleware
    
    async def handle_exception(self, request: Request, exc: Exception) -> JSONResponse:
        """Handle exceptions with error tracking."""
        try:
            # Extract request context
            request_context = await self.error_tracking_middleware.extract_request_context(request)
            
            # Track exception
            await self.error_tracking_middleware.track_exception(
                request, exc, 0.0, request_context
            )
            
            # Return appropriate error response
            if isinstance(exc, BusinessLogicError):
                return JSONResponse(
                    status_code=400,
                    content={
                        'error': 'Business Logic Error',
                        'message': str(exc),
                        'request_id': request_context.get('request_id')
                    }
                )
            else:
                return JSONResponse(
                    status_code=500,
                    content={
                        'error': 'Internal Server Error',
                        'message': 'An unexpected error occurred',
                        'request_id': request_context.get('request_id')
                    }
                )
                
        except Exception as e:
            logger.error("Failed to handle exception", error=str(e))
            return JSONResponse(
                status_code=500,
                content={
                    'error': 'Internal Server Error',
                    'message': 'An unexpected error occurred'
                }
            )


# Global error tracking middleware instance
_error_tracking_middleware = None


def get_error_tracking_middleware() -> Optional[ErrorTrackingMiddleware]:
    """Get the global error tracking middleware instance."""
    return _error_tracking_middleware


def set_error_tracking_middleware(middleware: ErrorTrackingMiddleware):
    """Set the global error tracking middleware instance."""
    global _error_tracking_middleware
    _error_tracking_middleware = middleware


def configure_error_tracking(**kwargs):
    """Configure error tracking settings."""
    if _error_tracking_middleware:
        _error_tracking_middleware.configure_error_tracking(**kwargs)


def get_error_tracking_status() -> Dict[str, Any]:
    """Get error tracking status."""
    if _error_tracking_middleware:
        return _error_tracking_middleware.get_error_tracking_status()
    return {'enabled': False, 'configuration': {}}


def get_error_rate_report() -> Dict[str, Any]:
    """Get error rate report."""
    return get_error_rate_report()
