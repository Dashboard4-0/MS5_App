"""
MS5.0 Floor Dashboard - Performance Monitoring Middleware

This module provides FastAPI middleware for:
- Request/response monitoring
- Automatic tracing
- Performance metrics collection
- Error tracking
- Zero redundancy architecture
"""

import time
from typing import Callable, Optional
from uuid import uuid4

import structlog
from fastapi import Request, Response
from fastapi.middleware.base import BaseHTTPMiddleware
from starlette.middleware.base import RequestResponseEndpoint

from app.services.application_performance_monitor import (
    start_trace, finish_trace, record_metric, increment_counter,
    TraceStatus, AlertSeverity
)

logger = structlog.get_logger()


class PerformanceMonitoringMiddleware(BaseHTTPMiddleware):
    """FastAPI middleware for performance monitoring."""
    
    def __init__(self, app, enable_tracing: bool = True, enable_metrics: bool = True):
        super().__init__(app)
        self.enable_tracing = enable_tracing
        self.enable_metrics = enable_metrics
        self.request_count = 0
        self.error_count = 0
    
    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        """Process request with performance monitoring."""
        # Generate unique request ID
        request_id = str(uuid4())
        
        # Start timing
        start_time = time.time()
        
        # Start trace if enabled
        span = None
        if self.enable_tracing:
            span = start_trace(
                operation_name=f"{request.method} {request.url.path}",
                trace_id=request_id
            )
            span.tags.update({
                'method': request.method,
                'path': request.url.path,
                'query_params': str(request.query_params),
                'user_agent': request.headers.get('user-agent', ''),
                'client_ip': request.client.host if request.client else '',
            })
        
        # Increment request counter
        if self.enable_metrics:
            self.request_count += 1
            increment_counter('requests_total', {
                'method': request.method,
                'endpoint': request.url.path,
                'status_code': 'pending'
            })
        
        # Process request
        try:
            response = await call_next(request)
            
            # Calculate processing time
            processing_time = time.time() - start_time
            
            # Update metrics
            if self.enable_metrics:
                record_metric('api_response_time', processing_time, {
                    'endpoint': request.url.path,
                    'method': request.method,
                    'status_code': str(response.status_code)
                })
                
                # Update request counter with actual status code
                increment_counter('requests_total', {
                    'method': request.method,
                    'endpoint': request.url.path,
                    'status_code': str(response.status_code)
                })
            
            # Finish trace
            if span:
                finish_trace(span, TraceStatus.SUCCESS)
                span.tags.update({
                    'status_code': response.status_code,
                    'response_size': response.headers.get('content-length', '0'),
                    'processing_time': processing_time,
                })
            
            # Add performance headers
            response.headers['X-Request-ID'] = request_id
            response.headers['X-Processing-Time'] = f"{processing_time:.3f}s"
            response.headers['X-Trace-ID'] = request_id
            
            # Log successful request
            logger.info(
                "Request processed",
                request_id=request_id,
                method=request.method,
                path=request.url.path,
                status_code=response.status_code,
                processing_time=processing_time,
                client_ip=request.client.host if request.client else '',
            )
            
            return response
            
        except Exception as e:
            # Calculate processing time for failed requests
            processing_time = time.time() - start_time
            
            # Update error metrics
            if self.enable_metrics:
                self.error_count += 1
                increment_counter('requests_total', {
                    'method': request.method,
                    'endpoint': request.url.path,
                    'status_code': '500'
                })
                
                record_metric('api_response_time', processing_time, {
                    'endpoint': request.url.path,
                    'method': request.method,
                    'status_code': '500'
                })
            
            # Finish trace with error
            if span:
                finish_trace(span, TraceStatus.ERROR, str(e))
                span.tags.update({
                    'error': str(e),
                    'error_type': type(e).__name__,
                    'processing_time': processing_time,
                })
            
            # Log error
            logger.error(
                "Request failed",
                request_id=request_id,
                method=request.method,
                path=request.url.path,
                error=str(e),
                error_type=type(e).__name__,
                processing_time=processing_time,
                client_ip=request.client.host if request.client else '',
            )
            
            # Re-raise the exception
            raise


class DatabaseQueryMonitoringMiddleware:
    """Middleware for monitoring database queries."""
    
    def __init__(self, enable_query_tracing: bool = True):
        self.enable_query_tracing = enable_query_tracing
        self.query_count = 0
        self.slow_query_count = 0
        self.slow_query_threshold = 1.0  # seconds
    
    async def monitor_query(self, query: str, params: Optional[dict] = None, execution_time: float = 0.0):
        """Monitor database query execution."""
        try:
            self.query_count += 1
            
            # Extract query type and table
            query_type = self.extract_query_type(query)
            table_name = self.extract_table_name(query)
            
            # Record query metrics
            record_metric('database_query_duration', execution_time, {
                'query_type': query_type,
                'table': table_name,
            })
            
            # Check for slow queries
            if execution_time > self.slow_query_threshold:
                self.slow_query_count += 1
                logger.warning(
                    "Slow query detected",
                    query=query[:100],
                    execution_time=execution_time,
                    query_type=query_type,
                    table=table_name
                )
            
            # Log query execution
            logger.debug(
                "Database query executed",
                query_type=query_type,
                table=table_name,
                execution_time=execution_time,
                params=params
            )
            
        except Exception as e:
            logger.error("Query monitoring failed", error=str(e))
    
    def extract_query_type(self, query: str) -> str:
        """Extract query type from SQL."""
        query_upper = query.strip().upper()
        if query_upper.startswith('SELECT'):
            return 'SELECT'
        elif query_upper.startswith('INSERT'):
            return 'INSERT'
        elif query_upper.startswith('UPDATE'):
            return 'UPDATE'
        elif query_upper.startswith('DELETE'):
            return 'DELETE'
        else:
            return 'OTHER'
    
    def extract_table_name(self, query: str) -> str:
        """Extract table name from SQL."""
        import re
        
        # Look for FROM clause
        from_match = re.search(r'FROM\s+factory_telemetry\.(\w+)', query, re.IGNORECASE)
        if from_match:
            return from_match.group(1)
        
        # Look for INTO clause
        into_match = re.search(r'INTO\s+factory_telemetry\.(\w+)', query, re.IGNORECASE)
        if into_match:
            return into_match.group(1)
        
        # Look for UPDATE clause
        update_match = re.search(r'UPDATE\s+factory_telemetry\.(\w+)', query, re.IGNORECASE)
        if update_match:
            return update_match.group(1)
        
        return 'unknown'


class CacheMonitoringMiddleware:
    """Middleware for monitoring cache operations."""
    
    def __init__(self, enable_cache_tracing: bool = True):
        self.enable_cache_tracing = enable_cache_tracing
        self.cache_hits = 0
        self.cache_misses = 0
        self.cache_operations = 0
    
    async def monitor_cache_operation(
        self,
        operation: str,
        key: str,
        hit: bool = False,
        execution_time: float = 0.0,
        cache_layer: str = 'unknown'
    ):
        """Monitor cache operation."""
        try:
            self.cache_operations += 1
            
            if hit:
                self.cache_hits += 1
            else:
                self.cache_misses += 1
            
            # Record cache metrics
            record_metric('cache_hit_ratio', self.cache_hits / self.cache_operations, {
                'cache_layer': cache_layer
            })
            
            # Log cache operation
            logger.debug(
                "Cache operation",
                operation=operation,
                key=key,
                hit=hit,
                execution_time=execution_time,
                cache_layer=cache_layer
            )
            
        except Exception as e:
            logger.error("Cache monitoring failed", error=str(e))


class WebSocketMonitoringMiddleware:
    """Middleware for monitoring WebSocket connections."""
    
    def __init__(self, enable_ws_tracing: bool = True):
        self.enable_ws_tracing = enable_ws_tracing
        self.active_connections = 0
        self.total_connections = 0
        self.message_count = 0
    
    async def monitor_connection(self, connection_id: str, event: str, data: Optional[dict] = None):
        """Monitor WebSocket connection event."""
        try:
            if event == 'connect':
                self.active_connections += 1
                self.total_connections += 1
                record_metric('websocket_connections', self.active_connections)
                
            elif event == 'disconnect':
                self.active_connections = max(0, self.active_connections - 1)
                record_metric('websocket_connections', self.active_connections)
                
            elif event == 'message':
                self.message_count += 1
                increment_counter('websocket_messages_total', {
                    'connection_id': connection_id
                })
            
            # Log WebSocket event
            logger.debug(
                "WebSocket event",
                connection_id=connection_id,
                event=event,
                active_connections=self.active_connections,
                data=data
            )
            
        except Exception as e:
            logger.error("WebSocket monitoring failed", error=str(e))


# Global middleware instances
_performance_middleware: Optional[PerformanceMonitoringMiddleware] = None
_database_monitoring: Optional[DatabaseQueryMonitoringMiddleware] = None
_cache_monitoring: Optional[CacheMonitoringMiddleware] = None
_websocket_monitoring: Optional[WebSocketMonitoringMiddleware] = None


def initialize_performance_middleware(app, enable_tracing: bool = True, enable_metrics: bool = True):
    """Initialize performance monitoring middleware."""
    global _performance_middleware, _database_monitoring, _cache_monitoring, _websocket_monitoring
    
    _performance_middleware = PerformanceMonitoringMiddleware(app, enable_tracing, enable_metrics)
    _database_monitoring = DatabaseQueryMonitoringMiddleware(enable_tracing)
    _cache_monitoring = CacheMonitoringMiddleware(enable_tracing)
    _websocket_monitoring = WebSocketMonitoringMiddleware(enable_tracing)
    
    # Add middleware to app
    app.add_middleware(PerformanceMonitoringMiddleware, enable_tracing=enable_tracing, enable_metrics=enable_metrics)
    
    logger.info("Performance monitoring middleware initialized")


async def monitor_database_query(query: str, params: Optional[dict] = None, execution_time: float = 0.0):
    """Monitor database query using global middleware."""
    if _database_monitoring:
        await _database_monitoring.monitor_query(query, params, execution_time)


async def monitor_cache_operation(
    operation: str,
    key: str,
    hit: bool = False,
    execution_time: float = 0.0,
    cache_layer: str = 'unknown'
):
    """Monitor cache operation using global middleware."""
    if _cache_monitoring:
        await _cache_monitoring.monitor_cache_operation(operation, key, hit, execution_time, cache_layer)


async def monitor_websocket_event(connection_id: str, event: str, data: Optional[dict] = None):
    """Monitor WebSocket event using global middleware."""
    if _websocket_monitoring:
        await _websocket_monitoring.monitor_connection(connection_id, event, data)


def get_middleware_stats() -> dict:
    """Get middleware statistics."""
    stats = {}
    
    if _performance_middleware:
        stats['performance'] = {
            'request_count': _performance_middleware.request_count,
            'error_count': _performance_middleware.error_count,
        }
    
    if _database_monitoring:
        stats['database'] = {
            'query_count': _database_monitoring.query_count,
            'slow_query_count': _database_monitoring.slow_query_count,
            'slow_query_threshold': _database_monitoring.slow_query_threshold,
        }
    
    if _cache_monitoring:
        stats['cache'] = {
            'cache_hits': _cache_monitoring.cache_hits,
            'cache_misses': _cache_monitoring.cache_misses,
            'cache_operations': _cache_monitoring.cache_operations,
            'hit_ratio': _cache_monitoring.cache_hits / _cache_monitoring.cache_operations if _cache_monitoring.cache_operations > 0 else 0,
        }
    
    if _websocket_monitoring:
        stats['websocket'] = {
            'active_connections': _websocket_monitoring.active_connections,
            'total_connections': _websocket_monitoring.total_connections,
            'message_count': _websocket_monitoring.message_count,
        }
    
    return stats
