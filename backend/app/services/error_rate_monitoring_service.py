"""
MS5.0 Floor Dashboard - Comprehensive Error Rate Monitoring Service

This module provides enterprise-grade error monitoring with:
- Real-time error tracking
- Error categorization and analysis
- Alerting and notifications
- Error rate calculations
- Performance impact analysis
- Zero redundancy architecture
"""

import asyncio
import json
import time
from collections import defaultdict, deque
from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Dict, List, Optional, Set, Tuple, Union
from uuid import UUID, uuid4

import structlog
from prometheus_client import Counter, Histogram, Gauge

from app.config import settings
from app.services.application_performance_monitor import record_metric, increment_counter, AlertSeverity
from app.utils.exceptions import BusinessLogicError

logger = structlog.get_logger()


class ErrorType(Enum):
    """Error type classifications."""
    APPLICATION = "application"
    DATABASE = "database"
    NETWORK = "network"
    VALIDATION = "validation"
    AUTHENTICATION = "authentication"
    AUTHORIZATION = "authorization"
    TIMEOUT = "timeout"
    RATE_LIMIT = "rate_limit"
    DEPENDENCY = "dependency"
    SYSTEM = "system"
    UNKNOWN = "unknown"


class ErrorSeverity(Enum):
    """Error severity levels."""
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


class ErrorStatus(Enum):
    """Error status types."""
    NEW = "new"
    ACKNOWLEDGED = "acknowledged"
    INVESTIGATING = "investigating"
    RESOLVED = "resolved"
    IGNORED = "ignored"


@dataclass
class ErrorEvent:
    """Error event data structure."""
    error_id: str
    error_type: ErrorType
    severity: ErrorSeverity
    message: str
    stack_trace: Optional[str]
    context: Dict[str, Any] = field(default_factory=dict)
    user_id: Optional[str] = None
    session_id: Optional[str] = None
    request_id: Optional[str] = None
    endpoint: Optional[str] = None
    method: Optional[str] = None
    status_code: Optional[int] = None
    timestamp: float = field(default_factory=time.time)
    resolved: bool = False
    resolution_notes: Optional[str] = None


@dataclass
class ErrorRateMetrics:
    """Error rate metrics."""
    total_errors: int = 0
    errors_by_type: Dict[str, int] = field(default_factory=dict)
    errors_by_severity: Dict[str, int] = field(default_factory=dict)
    errors_by_endpoint: Dict[str, int] = field(default_factory=dict)
    error_rate_per_minute: float = 0.0
    error_rate_per_hour: float = 0.0
    error_rate_percentage: float = 0.0
    total_requests: int = 0
    critical_errors: int = 0
    resolved_errors: int = 0
    unresolved_errors: int = 0


@dataclass
class ErrorAlert:
    """Error alert configuration."""
    alert_id: str
    error_type: ErrorType
    threshold: float
    time_window: int  # seconds
    severity: AlertSeverity
    enabled: bool = True
    last_triggered: Optional[float] = None
    trigger_count: int = 0


class ErrorRateMonitoringService:
    """Comprehensive error rate monitoring service."""
    
    def __init__(self):
        self.error_events: deque = deque(maxlen=10000)
        self.error_patterns: Dict[str, List[ErrorEvent]] = defaultdict(list)
        self.error_metrics = ErrorRateMetrics()
        self.error_alerts: Dict[str, ErrorAlert] = {}
        self.is_monitoring = False
        
        # Prometheus metrics
        self.error_counter = Counter(
            'ms5_errors_total',
            'Total number of errors',
            ['error_type', 'severity', 'endpoint', 'status_code']
        )
        
        self.error_rate_gauge = Gauge(
            'ms5_error_rate_percentage',
            'Error rate percentage',
            ['time_window']
        )
        
        self.error_duration = Histogram(
            'ms5_error_resolution_duration_seconds',
            'Time to resolve errors',
            ['error_type', 'severity'],
            buckets=[60, 300, 900, 3600, 14400, 86400]  # 1min to 1day
        )
        
        # Background tasks
        self.monitoring_tasks: List[asyncio.Task] = []
        
        # Error rate thresholds
        self.error_rate_thresholds = {
            ErrorSeverity.CRITICAL: 0.01,  # 1%
            ErrorSeverity.HIGH: 0.05,      # 5%
            ErrorSeverity.MEDIUM: 0.10,    # 10%
            ErrorSeverity.LOW: 0.20,       # 20%
        }
        
        # Time windows for error rate calculation
        self.time_windows = {
            'minute': 60,
            'hour': 3600,
            'day': 86400,
        }
    
    async def initialize(self):
        """Initialize error rate monitoring."""
        try:
            # Setup default alerts
            await self.setup_default_alerts()
            
            # Start monitoring tasks
            await self.start_monitoring_tasks()
            
            self.is_monitoring = True
            logger.info("Error rate monitoring initialized")
            
        except Exception as e:
            logger.error("Failed to initialize error rate monitoring", error=str(e))
            raise BusinessLogicError("Error rate monitoring initialization failed")
    
    async def setup_default_alerts(self):
        """Setup default error rate alerts."""
        try:
            # Critical error rate alert
            critical_alert = ErrorAlert(
                alert_id="critical_error_rate",
                error_type=ErrorType.APPLICATION,
                threshold=0.01,  # 1%
                time_window=300,  # 5 minutes
                severity=AlertSeverity.CRITICAL
            )
            self.error_alerts["critical_error_rate"] = critical_alert
            
            # High error rate alert
            high_alert = ErrorAlert(
                alert_id="high_error_rate",
                error_type=ErrorType.APPLICATION,
                threshold=0.05,  # 5%
                time_window=600,  # 10 minutes
                severity=AlertSeverity.WARNING
            )
            self.error_alerts["high_error_rate"] = high_alert
            
            # Database error alert
            db_alert = ErrorAlert(
                alert_id="database_error_rate",
                error_type=ErrorType.DATABASE,
                threshold=0.02,  # 2%
                time_window=300,  # 5 minutes
                severity=AlertSeverity.CRITICAL
            )
            self.error_alerts["database_error_rate"] = db_alert
            
            # Network error alert
            network_alert = ErrorAlert(
                alert_id="network_error_rate",
                error_type=ErrorType.NETWORK,
                threshold=0.10,  # 10%
                time_window=600,  # 10 minutes
                severity=AlertSeverity.WARNING
            )
            self.error_alerts["network_error_rate"] = network_alert
            
            logger.info("Default error alerts configured", alert_count=len(self.error_alerts))
            
        except Exception as e:
            logger.error("Failed to setup default alerts", error=str(e))
            raise
    
    async def start_monitoring_tasks(self):
        """Start background monitoring tasks."""
        # Error rate calculation
        rate_task = asyncio.create_task(self.calculate_error_rates())
        self.monitoring_tasks.append(rate_task)
        
        # Error pattern analysis
        pattern_task = asyncio.create_task(self.analyze_error_patterns())
        self.monitoring_tasks.append(pattern_task)
        
        # Alert monitoring
        alert_task = asyncio.create_task(self.monitor_error_alerts())
        self.monitoring_tasks.append(alert_task)
        
        # Error cleanup
        cleanup_task = asyncio.create_task(self.cleanup_old_errors())
        self.monitoring_tasks.append(cleanup_task)
        
        # Metrics aggregation
        metrics_task = asyncio.create_task(self.aggregate_error_metrics())
        self.monitoring_tasks.append(metrics_task)
        
        logger.info("Error monitoring tasks started", task_count=len(self.monitoring_tasks))
    
    async def record_error(
        self,
        error_type: ErrorType,
        severity: ErrorSeverity,
        message: str,
        stack_trace: Optional[str] = None,
        context: Optional[Dict[str, Any]] = None,
        user_id: Optional[str] = None,
        session_id: Optional[str] = None,
        request_id: Optional[str] = None,
        endpoint: Optional[str] = None,
        method: Optional[str] = None,
        status_code: Optional[int] = None
    ) -> str:
        """Record an error event."""
        try:
            error_id = str(uuid4())
            
            error_event = ErrorEvent(
                error_id=error_id,
                error_type=error_type,
                severity=severity,
                message=message,
                stack_trace=stack_trace,
                context=context or {},
                user_id=user_id,
                session_id=session_id,
                request_id=request_id,
                endpoint=endpoint,
                method=method,
                status_code=status_code
            )
            
            # Store error event
            self.error_events.append(error_event)
            
            # Update error patterns
            pattern_key = self.generate_error_pattern_key(error_event)
            self.error_patterns[pattern_key].append(error_event)
            
            # Update metrics
            self.update_error_metrics(error_event)
            
            # Update Prometheus metrics
            self.error_counter.labels(
                error_type=error_type.value,
                severity=severity.value,
                endpoint=endpoint or 'unknown',
                status_code=str(status_code) if status_code else 'unknown'
            ).inc()
            
            # Log error
            logger.error(
                "Error recorded",
                error_id=error_id,
                error_type=error_type.value,
                severity=severity.value,
                message=message,
                endpoint=endpoint,
                user_id=user_id
            )
            
            return error_id
            
        except Exception as e:
            logger.error("Failed to record error", error=str(e))
            raise BusinessLogicError("Failed to record error")
    
    def generate_error_pattern_key(self, error_event: ErrorEvent) -> str:
        """Generate a pattern key for error grouping."""
        # Group errors by type, severity, and endpoint
        key_parts = [
            error_event.error_type.value,
            error_event.severity.value,
            error_event.endpoint or 'unknown',
            error_event.status_code or 'unknown'
        ]
        return ':'.join(str(part) for part in key_parts)
    
    def update_error_metrics(self, error_event: ErrorEvent):
        """Update error metrics."""
        self.error_metrics.total_errors += 1
        
        # Update by type
        error_type_key = error_event.error_type.value
        self.error_metrics.errors_by_type[error_type_key] = (
            self.error_metrics.errors_by_type.get(error_type_key, 0) + 1
        )
        
        # Update by severity
        severity_key = error_event.severity.value
        self.error_metrics.errors_by_severity[severity_key] = (
            self.error_metrics.errors_by_severity.get(severity_key, 0) + 1
        )
        
        # Update by endpoint
        if error_event.endpoint:
            endpoint_key = error_event.endpoint
            self.error_metrics.errors_by_endpoint[endpoint_key] = (
                self.error_metrics.errors_by_endpoint.get(endpoint_key, 0) + 1
            )
        
        # Update critical errors
        if error_event.severity == ErrorSeverity.CRITICAL:
            self.error_metrics.critical_errors += 1
        
        # Update resolved/unresolved counts
        if error_event.resolved:
            self.error_metrics.resolved_errors += 1
        else:
            self.error_metrics.unresolved_errors += 1
    
    async def calculate_error_rates(self):
        """Calculate error rates for different time windows."""
        while self.is_monitoring:
            try:
                current_time = time.time()
                
                # Calculate error rates for different time windows
                for window_name, window_seconds in self.time_windows.items():
                    cutoff_time = current_time - window_seconds
                    
                    # Count errors in time window
                    errors_in_window = sum(
                        1 for error in self.error_events
                        if error.timestamp >= cutoff_time
                    )
                    
                    # Count total requests in time window (would be tracked separately)
                    total_requests = self.error_metrics.total_requests  # Placeholder
                    
                    # Calculate error rate
                    error_rate = errors_in_window / total_requests if total_requests > 0 else 0.0
                    
                    # Update metrics
                    if window_name == 'minute':
                        self.error_metrics.error_rate_per_minute = error_rate
                    elif window_name == 'hour':
                        self.error_metrics.error_rate_per_hour = error_rate
                    
                    # Update Prometheus metrics
                    self.error_rate_gauge.labels(time_window=window_name).set(error_rate)
                    
                    # Record metric
                    record_metric('error_rate_percentage', error_rate * 100, {
                        'time_window': window_name
                    })
                
                # Sleep for 60 seconds
                await asyncio.sleep(60)
                
            except Exception as e:
                logger.error("Error rate calculation failed", error=str(e))
                await asyncio.sleep(60)
    
    async def analyze_error_patterns(self):
        """Analyze error patterns for insights."""
        while self.is_monitoring:
            try:
                # Analyze error patterns
                pattern_analysis = {}
                
                for pattern_key, errors in self.error_patterns.items():
                    if len(errors) >= 3:  # Only analyze patterns with 3+ errors
                        pattern_analysis[pattern_key] = {
                            'error_count': len(errors),
                            'first_occurrence': min(error.timestamp for error in errors),
                            'last_occurrence': max(error.timestamp for error in errors),
                            'frequency': len(errors) / (max(error.timestamp for error in errors) - min(error.timestamp for error in errors) + 1),
                            'affected_users': len(set(error.user_id for error in errors if error.user_id)),
                            'affected_endpoints': len(set(error.endpoint for error in errors if error.endpoint)),
                        }
                
                # Log significant patterns
                for pattern_key, analysis in pattern_analysis.items():
                    if analysis['error_count'] >= 10:  # Significant pattern
                        logger.warning(
                            "Significant error pattern detected",
                            pattern=pattern_key,
                            error_count=analysis['error_count'],
                            frequency=analysis['frequency'],
                            affected_users=analysis['affected_users']
                        )
                
                # Sleep for 5 minutes
                await asyncio.sleep(300)
                
            except Exception as e:
                logger.error("Error pattern analysis failed", error=str(e))
                await asyncio.sleep(300)
    
    async def monitor_error_alerts(self):
        """Monitor error rate alerts."""
        while self.is_monitoring:
            try:
                current_time = time.time()
                
                for alert_id, alert in self.error_alerts.items():
                    if not alert.enabled:
                        continue
                    
                    # Calculate error rate for alert time window
                    cutoff_time = current_time - alert.time_window
                    errors_in_window = sum(
                        1 for error in self.error_events
                        if error.timestamp >= cutoff_time and error.error_type == alert.error_type
                    )
                    
                    # Calculate error rate
                    total_requests = self.error_metrics.total_requests  # Placeholder
                    error_rate = errors_in_window / total_requests if total_requests > 0 else 0.0
                    
                    # Check if threshold is exceeded
                    if error_rate > alert.threshold:
                        # Check if alert was recently triggered
                        if not alert.last_triggered or (current_time - alert.last_triggered) > alert.time_window:
                            await self.trigger_error_alert(alert, error_rate, errors_in_window)
                            alert.last_triggered = current_time
                            alert.trigger_count += 1
                
                # Sleep for 30 seconds
                await asyncio.sleep(30)
                
            except Exception as e:
                logger.error("Error alert monitoring failed", error=str(e))
                await asyncio.sleep(30)
    
    async def trigger_error_alert(self, alert: ErrorAlert, error_rate: float, error_count: int):
        """Trigger an error rate alert."""
        try:
            alert_message = (
                f"Error rate alert triggered: {alert.error_type.value} errors "
                f"exceeded threshold of {alert.threshold:.2%} "
                f"(current rate: {error_rate:.2%}, count: {error_count})"
            )
            
            logger.critical(
                "Error rate alert triggered",
                alert_id=alert.alert_id,
                error_type=alert.error_type.value,
                threshold=alert.threshold,
                current_rate=error_rate,
                error_count=error_count,
                severity=alert.severity.value
            )
            
            # Record alert metric
            increment_counter('error_rate_alerts_total', {
                'alert_id': alert.alert_id,
                'error_type': alert.error_type.value,
                'severity': alert.severity.value
            })
            
            # Send alert notification (would integrate with actual notification system)
            await self.send_alert_notification(alert, alert_message, error_rate, error_count)
            
        except Exception as e:
            logger.error("Failed to trigger error alert", error=str(e))
    
    async def send_alert_notification(self, alert: ErrorAlert, message: str, error_rate: float, error_count: int):
        """Send alert notification."""
        try:
            # This would integrate with actual notification systems (email, Slack, PagerDuty, etc.)
            notification_data = {
                'alert_id': alert.alert_id,
                'error_type': alert.error_type.value,
                'severity': alert.severity.value,
                'threshold': alert.threshold,
                'current_rate': error_rate,
                'error_count': error_count,
                'message': message,
                'timestamp': time.time()
            }
            
            logger.info("Alert notification sent", notification_data=notification_data)
            
        except Exception as e:
            logger.error("Failed to send alert notification", error=str(e))
    
    async def cleanup_old_errors(self):
        """Cleanup old error events to prevent memory leaks."""
        while self.is_monitoring:
            try:
                current_time = time.time()
                cleanup_threshold = 86400  # 24 hours
                
                # Clean up old error events
                old_errors = [
                    error for error in self.error_events
                    if current_time - error.timestamp > cleanup_threshold
                ]
                
                for error in old_errors:
                    self.error_events.remove(error)
                
                # Clean up old error patterns
                for pattern_key, errors in list(self.error_patterns.items()):
                    errors[:] = [
                        error for error in errors
                        if current_time - error.timestamp <= cleanup_threshold
                    ]
                    if not errors:
                        del self.error_patterns[pattern_key]
                
                if old_errors:
                    logger.debug("Old errors cleaned up", count=len(old_errors))
                
                # Sleep for 1 hour
                await asyncio.sleep(3600)
                
            except Exception as e:
                logger.error("Error cleanup failed", error=str(e))
                await asyncio.sleep(3600)
    
    async def aggregate_error_metrics(self):
        """Aggregate error metrics for reporting."""
        while self.is_monitoring:
            try:
                # Calculate overall error rate percentage
                total_requests = self.error_metrics.total_requests
                total_errors = self.error_metrics.total_errors
                
                if total_requests > 0:
                    self.error_metrics.error_rate_percentage = (total_errors / total_requests) * 100
                
                # Record aggregated metrics
                record_metric('total_errors', total_errors)
                record_metric('error_rate_percentage', self.error_metrics.error_rate_percentage)
                record_metric('critical_errors', self.error_metrics.critical_errors)
                record_metric('unresolved_errors', self.error_metrics.unresolved_errors)
                
                # Sleep for 60 seconds
                await asyncio.sleep(60)
                
            except Exception as e:
                logger.error("Error metrics aggregation failed", error=str(e))
                await asyncio.sleep(60)
    
    async def resolve_error(self, error_id: str, resolution_notes: Optional[str] = None) -> bool:
        """Mark an error as resolved."""
        try:
            # Find error event
            error_event = None
            for error in self.error_events:
                if error.error_id == error_id:
                    error_event = error
                    break
            
            if not error_event:
                logger.warning("Error not found for resolution", error_id=error_id)
                return False
            
            # Mark as resolved
            error_event.resolved = True
            error_event.resolution_notes = resolution_notes
            
            # Update metrics
            self.error_metrics.resolved_errors += 1
            self.error_metrics.unresolved_errors = max(0, self.error_metrics.unresolved_errors - 1)
            
            # Record resolution duration
            resolution_duration = time.time() - error_event.timestamp
            self.error_duration.labels(
                error_type=error_event.error_type.value,
                severity=error_event.severity.value
            ).observe(resolution_duration)
            
            logger.info(
                "Error resolved",
                error_id=error_id,
                resolution_duration=resolution_duration,
                resolution_notes=resolution_notes
            )
            
            return True
            
        except Exception as e:
            logger.error("Failed to resolve error", error=str(e))
            return False
    
    def get_error_rate_report(self) -> Dict[str, Any]:
        """Get comprehensive error rate report."""
        try:
            # Calculate recent error rates
            current_time = time.time()
            recent_errors = [
                error for error in self.error_events
                if current_time - error.timestamp <= 3600  # Last hour
            ]
            
            # Top error patterns
            top_patterns = sorted(
                self.error_patterns.items(),
                key=lambda x: len(x[1]),
                reverse=True
            )[:10]
            
            # Error trends
            error_trends = self.calculate_error_trends()
            
            # Active alerts
            active_alerts = [
                {
                    'alert_id': alert.alert_id,
                    'error_type': alert.error_type.value,
                    'threshold': alert.threshold,
                    'time_window': alert.time_window,
                    'severity': alert.severity.value,
                    'enabled': alert.enabled,
                    'last_triggered': alert.last_triggered,
                    'trigger_count': alert.trigger_count
                }
                for alert in self.error_alerts.values()
            ]
            
            return {
                'error_metrics': {
                    'total_errors': self.error_metrics.total_errors,
                    'errors_by_type': self.error_metrics.errors_by_type,
                    'errors_by_severity': self.error_metrics.errors_by_severity,
                    'errors_by_endpoint': self.error_metrics.errors_by_endpoint,
                    'error_rate_per_minute': self.error_metrics.error_rate_per_minute,
                    'error_rate_per_hour': self.error_metrics.error_rate_per_hour,
                    'error_rate_percentage': self.error_metrics.error_rate_percentage,
                    'critical_errors': self.error_metrics.critical_errors,
                    'resolved_errors': self.error_metrics.resolved_errors,
                    'unresolved_errors': self.error_metrics.unresolved_errors,
                },
                'recent_errors': {
                    'count': len(recent_errors),
                    'errors': [
                        {
                            'error_id': error.error_id,
                            'error_type': error.error_type.value,
                            'severity': error.severity.value,
                            'message': error.message,
                            'endpoint': error.endpoint,
                            'timestamp': error.timestamp,
                            'resolved': error.resolved
                        }
                        for error in recent_errors[-20:]  # Last 20 errors
                    ]
                },
                'top_error_patterns': [
                    {
                        'pattern': pattern_key,
                        'error_count': len(errors),
                        'error_type': errors[0].error_type.value if errors else 'unknown',
                        'severity': errors[0].severity.value if errors else 'unknown',
                        'first_occurrence': min(error.timestamp for error in errors) if errors else 0,
                        'last_occurrence': max(error.timestamp for error in errors) if errors else 0,
                    }
                    for pattern_key, errors in top_patterns
                ],
                'error_trends': error_trends,
                'active_alerts': active_alerts,
                'monitoring_status': {
                    'is_monitoring': self.is_monitoring,
                    'monitoring_tasks': len(self.monitoring_tasks),
                    'total_patterns': len(self.error_patterns),
                }
            }
            
        except Exception as e:
            logger.error("Failed to generate error rate report", error=str(e))
            raise BusinessLogicError("Failed to generate error rate report")
    
    def calculate_error_trends(self) -> Dict[str, Any]:
        """Calculate error trends over time."""
        try:
            current_time = time.time()
            trends = {}
            
            # Calculate trends for different time windows
            for window_name, window_seconds in self.time_windows.items():
                cutoff_time = current_time - window_seconds
                
                # Count errors in current window
                current_errors = sum(
                    1 for error in self.error_events
                    if error.timestamp >= cutoff_time
                )
                
                # Count errors in previous window
                previous_cutoff = cutoff_time - window_seconds
                previous_errors = sum(
                    1 for error in self.error_events
                    if previous_cutoff <= error.timestamp < cutoff_time
                )
                
                # Calculate trend
                if previous_errors > 0:
                    trend_percentage = ((current_errors - previous_errors) / previous_errors) * 100
                else:
                    trend_percentage = 100 if current_errors > 0 else 0
                
                trends[window_name] = {
                    'current_errors': current_errors,
                    'previous_errors': previous_errors,
                    'trend_percentage': trend_percentage,
                    'trend_direction': 'increasing' if trend_percentage > 0 else 'decreasing' if trend_percentage < 0 else 'stable'
                }
            
            return trends
            
        except Exception as e:
            logger.error("Failed to calculate error trends", error=str(e))
            return {}
    
    async def stop_monitoring(self):
        """Stop error rate monitoring."""
        try:
            self.is_monitoring = False
            
            # Cancel monitoring tasks
            for task in self.monitoring_tasks:
                task.cancel()
            
            # Wait for tasks to complete
            await asyncio.gather(*self.monitoring_tasks, return_exceptions=True)
            
            self.monitoring_tasks.clear()
            
            logger.info("Error rate monitoring stopped")
            
        except Exception as e:
            logger.error("Failed to stop monitoring", error=str(e))


# Global error rate monitoring service instance
_error_rate_monitoring_service = ErrorRateMonitoringService()


async def initialize_error_rate_monitoring():
    """Initialize the global error rate monitoring service."""
    await _error_rate_monitoring_service.initialize()


async def record_error(
    error_type: ErrorType,
    severity: ErrorSeverity,
    message: str,
    stack_trace: Optional[str] = None,
    context: Optional[Dict[str, Any]] = None,
    user_id: Optional[str] = None,
    session_id: Optional[str] = None,
    request_id: Optional[str] = None,
    endpoint: Optional[str] = None,
    method: Optional[str] = None,
    status_code: Optional[int] = None
) -> str:
    """Record an error using the global service."""
    return await _error_rate_monitoring_service.record_error(
        error_type, severity, message, stack_trace, context,
        user_id, session_id, request_id, endpoint, method, status_code
    )


async def resolve_error(error_id: str, resolution_notes: Optional[str] = None) -> bool:
    """Resolve an error using the global service."""
    return await _error_rate_monitoring_service.resolve_error(error_id, resolution_notes)


def get_error_rate_report() -> Dict[str, Any]:
    """Get error rate report using the global service."""
    return _error_rate_monitoring_service.get_error_rate_report()


async def stop_error_rate_monitoring():
    """Stop the global error rate monitoring service."""
    await _error_rate_monitoring_service.stop_monitoring()
