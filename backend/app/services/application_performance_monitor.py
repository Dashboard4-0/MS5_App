"""
MS5.0 Floor Dashboard - Comprehensive Application Performance Monitoring

This module provides enterprise-grade APM with:
- Distributed tracing
- Real-time metrics collection
- Performance profiling
- Resource monitoring
- Alerting and notifications
- Zero redundancy architecture
"""

import asyncio
import json
import psutil
import time
from collections import defaultdict, deque
from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Dict, List, Optional, Set, Tuple, Union
from uuid import UUID, uuid4

import structlog
from prometheus_client import Counter, Histogram, Gauge, Summary, CollectorRegistry, generate_latest

from app.config import settings
from app.utils.exceptions import BusinessLogicError

logger = structlog.get_logger()


class MetricType(Enum):
    """Metric types."""
    COUNTER = "counter"
    GAUGE = "gauge"
    HISTOGRAM = "histogram"
    SUMMARY = "summary"


class AlertSeverity(Enum):
    """Alert severity levels."""
    INFO = "info"
    WARNING = "warning"
    CRITICAL = "critical"
    EMERGENCY = "emergency"


class TraceStatus(Enum):
    """Trace status types."""
    SUCCESS = "success"
    ERROR = "error"
    TIMEOUT = "timeout"
    CANCELLED = "cancelled"


@dataclass
class MetricData:
    """Metric data structure."""
    name: str
    value: float
    labels: Dict[str, str] = field(default_factory=dict)
    timestamp: float = field(default_factory=time.time)
    metric_type: MetricType = MetricType.GAUGE


@dataclass
class TraceSpan:
    """Distributed trace span."""
    trace_id: str
    span_id: str
    parent_span_id: Optional[str]
    operation_name: str
    start_time: float
    end_time: Optional[float] = None
    duration: Optional[float] = None
    status: TraceStatus = TraceStatus.SUCCESS
    tags: Dict[str, Any] = field(default_factory=dict)
    logs: List[Dict[str, Any]] = field(default_factory=list)
    error_message: Optional[str] = None


@dataclass
class PerformanceAlert:
    """Performance alert."""
    alert_id: str
    metric_name: str
    threshold: float
    current_value: float
    severity: AlertSeverity
    message: str
    timestamp: float = field(default_factory=time.time)
    resolved: bool = False


@dataclass
class SystemMetrics:
    """System performance metrics."""
    cpu_percent: float
    memory_percent: float
    memory_used: int
    memory_total: int
    disk_usage_percent: float
    disk_used: int
    disk_total: int
    network_sent: int
    network_recv: int
    load_average: Tuple[float, float, float]
    process_count: int
    timestamp: float = field(default_factory=time.time)


class ApplicationPerformanceMonitor:
    """Comprehensive Application Performance Monitoring system."""
    
    def __init__(self):
        self.metrics_registry = CollectorRegistry()
        self.custom_metrics: Dict[str, Any] = {}
        self.traces: Dict[str, List[TraceSpan]] = defaultdict(list)
        self.active_spans: Dict[str, TraceSpan] = {}
        self.alerts: deque = deque(maxlen=1000)
        self.system_metrics_history: deque = deque(maxlen=1000)
        self.performance_thresholds: Dict[str, Dict[str, float]] = {}
        self.is_monitoring = False
        
        # Prometheus metrics
        self.request_counter = Counter(
            'ms5_requests_total',
            'Total number of requests',
            ['method', 'endpoint', 'status_code'],
            registry=self.metrics_registry
        )
        
        self.request_duration = Histogram(
            'ms5_request_duration_seconds',
            'Request duration in seconds',
            ['method', 'endpoint'],
            buckets=[0.1, 0.5, 1.0, 2.0, 5.0, 10.0],
            registry=self.metrics_registry
        )
        
        self.active_connections = Gauge(
            'ms5_active_connections',
            'Number of active connections',
            ['connection_type'],
            registry=self.metrics_registry
        )
        
        self.cache_hit_ratio = Gauge(
            'ms5_cache_hit_ratio',
            'Cache hit ratio',
            ['cache_layer'],
            registry=self.metrics_registry
        )
        
        self.database_query_duration = Summary(
            'ms5_database_query_duration_seconds',
            'Database query duration',
            ['query_type', 'table'],
            registry=self.metrics_registry
        )
        
        self.system_cpu = Gauge(
            'ms5_system_cpu_percent',
            'System CPU usage percentage',
            registry=self.metrics_registry
        )
        
        self.system_memory = Gauge(
            'ms5_system_memory_bytes',
            'System memory usage in bytes',
            registry=self.metrics_registry
        )
        
        # Performance thresholds
        self.setup_default_thresholds()
        
        # Background tasks
        self.monitoring_tasks: List[asyncio.Task] = []
    
    def setup_default_thresholds(self):
        """Setup default performance thresholds."""
        self.performance_thresholds = {
            'request_duration': {
                'warning': 2.0,
                'critical': 5.0,
            },
            'cpu_usage': {
                'warning': 80.0,
                'critical': 95.0,
            },
            'memory_usage': {
                'warning': 80.0,
                'critical': 95.0,
            },
            'cache_hit_ratio': {
                'warning': 0.7,
                'critical': 0.5,
            },
            'database_query_duration': {
                'warning': 1.0,
                'critical': 3.0,
            },
            'error_rate': {
                'warning': 0.05,
                'critical': 0.1,
            },
        }
    
    async def initialize(self):
        """Initialize APM system."""
        try:
            # Start monitoring tasks
            await self.start_monitoring_tasks()
            
            # Initialize custom metrics
            await self.initialize_custom_metrics()
            
            self.is_monitoring = True
            logger.info("Application Performance Monitoring initialized")
            
        except Exception as e:
            logger.error("Failed to initialize APM", error=str(e))
            raise BusinessLogicError("APM initialization failed")
    
    async def start_monitoring_tasks(self):
        """Start background monitoring tasks."""
        # System metrics collection
        system_task = asyncio.create_task(self.collect_system_metrics())
        self.monitoring_tasks.append(system_task)
        
        # Performance threshold monitoring
        threshold_task = asyncio.create_task(self.monitor_performance_thresholds())
        self.monitoring_tasks.append(threshold_task)
        
        # Trace cleanup
        cleanup_task = asyncio.create_task(self.cleanup_old_traces())
        self.monitoring_tasks.append(cleanup_task)
        
        # Metrics aggregation
        aggregation_task = asyncio.create_task(self.aggregate_metrics())
        self.monitoring_tasks.append(aggregation_task)
        
        logger.info("Monitoring tasks started", task_count=len(self.monitoring_tasks))
    
    async def initialize_custom_metrics(self):
        """Initialize custom application metrics."""
        try:
            # Business metrics
            self.custom_metrics['production_efficiency'] = Gauge(
                'ms5_production_efficiency_percent',
                'Production line efficiency percentage',
                ['line_id', 'equipment_code'],
                registry=self.metrics_registry
            )
            
            self.custom_metrics['oee_score'] = Gauge(
                'ms5_oee_score',
                'Overall Equipment Effectiveness score',
                ['line_id', 'equipment_code'],
                registry=self.metrics_registry
            )
            
            self.custom_metrics['andon_events'] = Counter(
                'ms5_andon_events_total',
                'Total number of Andon events',
                ['event_type', 'priority', 'line_id'],
                registry=self.metrics_registry
            )
            
            self.custom_metrics['downtime_minutes'] = Gauge(
                'ms5_downtime_minutes',
                'Downtime in minutes',
                ['line_id', 'downtime_type'],
                registry=self.metrics_registry
            )
            
            # Performance metrics
            self.custom_metrics['api_response_time'] = Histogram(
                'ms5_api_response_time_seconds',
                'API response time',
                ['endpoint', 'method'],
                buckets=[0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0],
                registry=self.metrics_registry
            )
            
            self.custom_metrics['websocket_connections'] = Gauge(
                'ms5_websocket_connections_active',
                'Active WebSocket connections',
                registry=self.metrics_registry
            )
            
            logger.info("Custom metrics initialized", metric_count=len(self.custom_metrics))
            
        except Exception as e:
            logger.error("Failed to initialize custom metrics", error=str(e))
            raise
    
    async def collect_system_metrics(self):
        """Collect system performance metrics."""
        while self.is_monitoring:
            try:
                # CPU metrics
                cpu_percent = psutil.cpu_percent(interval=1)
                self.system_cpu.set(cpu_percent)
                
                # Memory metrics
                memory = psutil.virtual_memory()
                self.system_memory.set(memory.used)
                
                # Disk metrics
                disk = psutil.disk_usage('/')
                
                # Network metrics
                network = psutil.net_io_counters()
                
                # Load average
                load_avg = psutil.getloadavg()
                
                # Process count
                process_count = len(psutil.pids())
                
                # Create system metrics object
                system_metrics = SystemMetrics(
                    cpu_percent=cpu_percent,
                    memory_percent=memory.percent,
                    memory_used=memory.used,
                    memory_total=memory.total,
                    disk_usage_percent=disk.percent,
                    disk_used=disk.used,
                    disk_total=disk.total,
                    network_sent=network.bytes_sent,
                    network_recv=network.bytes_recv,
                    load_average=load_avg,
                    process_count=process_count
                )
                
                self.system_metrics_history.append(system_metrics)
                
                logger.debug("System metrics collected", cpu=cpu_percent, memory=memory.percent)
                
                # Sleep for 30 seconds
                await asyncio.sleep(30)
                
            except Exception as e:
                logger.error("System metrics collection error", error=str(e))
                await asyncio.sleep(30)
    
    async def monitor_performance_thresholds(self):
        """Monitor performance thresholds and generate alerts."""
        while self.is_monitoring:
            try:
                # Check system metrics thresholds
                if self.system_metrics_history:
                    latest_metrics = self.system_metrics_history[-1]
                    
                    # CPU threshold check
                    if latest_metrics.cpu_percent > self.performance_thresholds['cpu_usage']['critical']:
                        await self.create_alert(
                            'cpu_usage',
                            latest_metrics.cpu_percent,
                            AlertSeverity.CRITICAL,
                            f"CPU usage critically high: {latest_metrics.cpu_percent:.1f}%"
                        )
                    elif latest_metrics.cpu_percent > self.performance_thresholds['cpu_usage']['warning']:
                        await self.create_alert(
                            'cpu_usage',
                            latest_metrics.cpu_percent,
                            AlertSeverity.WARNING,
                            f"CPU usage high: {latest_metrics.cpu_percent:.1f}%"
                        )
                    
                    # Memory threshold check
                    if latest_metrics.memory_percent > self.performance_thresholds['memory_usage']['critical']:
                        await self.create_alert(
                            'memory_usage',
                            latest_metrics.memory_percent,
                            AlertSeverity.CRITICAL,
                            f"Memory usage critically high: {latest_metrics.memory_percent:.1f}%"
                        )
                    elif latest_metrics.memory_percent > self.performance_thresholds['memory_usage']['warning']:
                        await self.create_alert(
                            'memory_usage',
                            latest_metrics.memory_percent,
                            AlertSeverity.WARNING,
                            f"Memory usage high: {latest_metrics.memory_percent:.1f}%"
                        )
                
                # Sleep for 60 seconds
                await asyncio.sleep(60)
                
            except Exception as e:
                logger.error("Performance threshold monitoring error", error=str(e))
                await asyncio.sleep(60)
    
    async def cleanup_old_traces(self):
        """Cleanup old traces to prevent memory leaks."""
        while self.is_monitoring:
            try:
                current_time = time.time()
                cleanup_threshold = 3600  # 1 hour
                
                # Clean up old traces
                for trace_id, spans in list(self.traces.items()):
                    spans[:] = [span for span in spans if current_time - span.start_time < cleanup_threshold]
                    if not spans:
                        del self.traces[trace_id]
                
                # Clean up old alerts
                while self.alerts and current_time - self.alerts[0].timestamp > cleanup_threshold:
                    self.alerts.popleft()
                
                logger.debug("Old traces and alerts cleaned up")
                
                # Sleep for 5 minutes
                await asyncio.sleep(300)
                
            except Exception as e:
                logger.error("Trace cleanup error", error=str(e))
                await asyncio.sleep(300)
    
    async def aggregate_metrics(self):
        """Aggregate metrics for reporting."""
        while self.is_monitoring:
            try:
                # Calculate aggregated metrics
                await self.calculate_aggregated_metrics()
                
                # Sleep for 60 seconds
                await asyncio.sleep(60)
                
            except Exception as e:
                logger.error("Metrics aggregation error", error=str(e))
                await asyncio.sleep(60)
    
    async def calculate_aggregated_metrics(self):
        """Calculate aggregated metrics."""
        try:
            # Calculate average response times
            if self.system_metrics_history:
                recent_metrics = list(self.system_metrics_history)[-10:]  # Last 10 samples
                avg_cpu = sum(m.cpu_percent for m in recent_metrics) / len(recent_metrics)
                avg_memory = sum(m.memory_percent for m in recent_metrics) / len(recent_metrics)
                
                logger.debug("Aggregated metrics calculated", avg_cpu=avg_cpu, avg_memory=avg_memory)
                
        except Exception as e:
            logger.error("Failed to calculate aggregated metrics", error=str(e))
    
    async def create_alert(
        self,
        metric_name: str,
        current_value: float,
        severity: AlertSeverity,
        message: str
    ):
        """Create a performance alert."""
        try:
            alert = PerformanceAlert(
                alert_id=str(uuid4()),
                metric_name=metric_name,
                threshold=self.performance_thresholds.get(metric_name, {}).get(severity.value, 0),
                current_value=current_value,
                severity=severity,
                message=message
            )
            
            self.alerts.append(alert)
            
            logger.warning(
                "Performance alert created",
                alert_id=alert.alert_id,
                metric=metric_name,
                value=current_value,
                severity=severity.value,
                message=message
            )
            
            # Send alert notification (would integrate with actual notification system)
            await self.send_alert_notification(alert)
            
        except Exception as e:
            logger.error("Failed to create alert", error=str(e))
    
    async def send_alert_notification(self, alert: PerformanceAlert):
        """Send alert notification."""
        try:
            # This would integrate with actual notification systems (email, Slack, PagerDuty, etc.)
            logger.info("Alert notification sent", alert_id=alert.alert_id, severity=alert.severity.value)
        except Exception as e:
            logger.error("Failed to send alert notification", error=str(e))
    
    def start_trace(self, operation_name: str, trace_id: Optional[str] = None) -> TraceSpan:
        """Start a new trace span."""
        try:
            if not trace_id:
                trace_id = str(uuid4())
            
            span_id = str(uuid4())
            
            span = TraceSpan(
                trace_id=trace_id,
                span_id=span_id,
                parent_span_id=None,
                operation_name=operation_name,
                start_time=time.time()
            )
            
            self.active_spans[span_id] = span
            self.traces[trace_id].append(span)
            
            logger.debug("Trace started", trace_id=trace_id, span_id=span_id, operation=operation_name)
            
            return span
            
        except Exception as e:
            logger.error("Failed to start trace", error=str(e))
            raise BusinessLogicError("Failed to start trace")
    
    def finish_trace(self, span: TraceSpan, status: TraceStatus = TraceStatus.SUCCESS, error_message: Optional[str] = None):
        """Finish a trace span."""
        try:
            span.end_time = time.time()
            span.duration = span.end_time - span.start_time
            span.status = status
            span.error_message = error_message
            
            # Remove from active spans
            if span.span_id in self.active_spans:
                del self.active_spans[span.span_id]
            
            # Update Prometheus metrics
            if span.operation_name.startswith('api_'):
                self.request_duration.labels(
                    method=span.tags.get('method', 'unknown'),
                    endpoint=span.operation_name
                ).observe(span.duration)
            
            logger.debug(
                "Trace finished",
                trace_id=span.trace_id,
                span_id=span.span_id,
                duration=span.duration,
                status=status.value
            )
            
        except Exception as e:
            logger.error("Failed to finish trace", error=str(e))
    
    def record_metric(self, name: str, value: float, labels: Optional[Dict[str, str]] = None):
        """Record a custom metric."""
        try:
            labels = labels or {}
            
            # Update Prometheus metrics
            if name in self.custom_metrics:
                metric = self.custom_metrics[name]
                if hasattr(metric, 'labels'):
                    metric.labels(**labels).set(value)
                else:
                    metric.set(value)
            
            logger.debug("Metric recorded", name=name, value=value, labels=labels)
            
        except Exception as e:
            logger.error("Failed to record metric", error=str(e))
    
    def increment_counter(self, name: str, labels: Optional[Dict[str, str]] = None):
        """Increment a counter metric."""
        try:
            labels = labels or {}
            
            if name == 'requests_total':
                self.request_counter.labels(**labels).inc()
            elif name in self.custom_metrics:
                metric = self.custom_metrics[name]
                if hasattr(metric, 'labels'):
                    metric.labels(**labels).inc()
                else:
                    metric.inc()
            
            logger.debug("Counter incremented", name=name, labels=labels)
            
        except Exception as e:
            logger.error("Failed to increment counter", error=str(e))
    
    def get_metrics_prometheus(self) -> str:
        """Get metrics in Prometheus format."""
        try:
            return generate_latest(self.metrics_registry).decode('utf-8')
        except Exception as e:
            logger.error("Failed to generate Prometheus metrics", error=str(e))
            return ""
    
    def get_performance_report(self) -> Dict[str, Any]:
        """Get comprehensive performance report."""
        try:
            # System metrics summary
            system_summary = {}
            if self.system_metrics_history:
                latest_metrics = self.system_metrics_history[-1]
                system_summary = {
                    'cpu_percent': latest_metrics.cpu_percent,
                    'memory_percent': latest_metrics.memory_percent,
                    'memory_used_mb': latest_metrics.memory_used // (1024 * 1024),
                    'memory_total_mb': latest_metrics.memory_total // (1024 * 1024),
                    'disk_usage_percent': latest_metrics.disk_usage_percent,
                    'load_average': latest_metrics.load_average,
                    'process_count': latest_metrics.process_count,
                }
            
            # Active alerts
            active_alerts = [
                {
                    'alert_id': alert.alert_id,
                    'metric_name': alert.metric_name,
                    'current_value': alert.current_value,
                    'threshold': alert.threshold,
                    'severity': alert.severity.value,
                    'message': alert.message,
                    'timestamp': alert.timestamp,
                }
                for alert in self.alerts
                if not alert.resolved
            ]
            
            # Trace statistics
            trace_stats = {
                'total_traces': len(self.traces),
                'active_spans': len(self.active_spans),
                'total_spans': sum(len(spans) for spans in self.traces.values()),
            }
            
            # Performance thresholds
            thresholds = self.performance_thresholds.copy()
            
            return {
                'system_metrics': system_summary,
                'active_alerts': active_alerts,
                'trace_statistics': trace_stats,
                'performance_thresholds': thresholds,
                'monitoring_status': {
                    'is_monitoring': self.is_monitoring,
                    'monitoring_tasks': len(self.monitoring_tasks),
                    'custom_metrics_count': len(self.custom_metrics),
                },
                'timestamp': time.time(),
            }
            
        except Exception as e:
            logger.error("Failed to generate performance report", error=str(e))
            raise BusinessLogicError("Failed to generate performance report")
    
    def get_trace_details(self, trace_id: str) -> Dict[str, Any]:
        """Get detailed trace information."""
        try:
            if trace_id not in self.traces:
                return {'error': f'Trace {trace_id} not found'}
            
            spans = self.traces[trace_id]
            
            return {
                'trace_id': trace_id,
                'span_count': len(spans),
                'spans': [
                    {
                        'span_id': span.span_id,
                        'parent_span_id': span.parent_span_id,
                        'operation_name': span.operation_name,
                        'start_time': span.start_time,
                        'end_time': span.end_time,
                        'duration': span.duration,
                        'status': span.status.value,
                        'tags': span.tags,
                        'error_message': span.error_message,
                    }
                    for span in spans
                ],
                'total_duration': max(span.duration or 0 for span in spans) if spans else 0,
            }
            
        except Exception as e:
            logger.error("Failed to get trace details", error=str(e))
            return {'error': str(e)}
    
    async def stop_monitoring(self):
        """Stop APM monitoring."""
        try:
            self.is_monitoring = False
            
            # Cancel monitoring tasks
            for task in self.monitoring_tasks:
                task.cancel()
            
            # Wait for tasks to complete
            await asyncio.gather(*self.monitoring_tasks, return_exceptions=True)
            
            self.monitoring_tasks.clear()
            
            logger.info("APM monitoring stopped")
            
        except Exception as e:
            logger.error("Failed to stop monitoring", error=str(e))


# Global APM instance
_apm_instance = ApplicationPerformanceMonitor()


async def initialize_apm():
    """Initialize the global APM system."""
    await _apm_instance.initialize()


def start_trace(operation_name: str, trace_id: Optional[str] = None) -> TraceSpan:
    """Start a trace using the global APM."""
    return _apm_instance.start_trace(operation_name, trace_id)


def finish_trace(span: TraceSpan, status: TraceStatus = TraceStatus.SUCCESS, error_message: Optional[str] = None):
    """Finish a trace using the global APM."""
    _apm_instance.finish_trace(span, status, error_message)


def record_metric(name: str, value: float, labels: Optional[Dict[str, str]] = None):
    """Record a metric using the global APM."""
    _apm_instance.record_metric(name, value, labels)


def increment_counter(name: str, labels: Optional[Dict[str, str]] = None):
    """Increment a counter using the global APM."""
    _apm_instance.increment_counter(name, labels)


def get_metrics_prometheus() -> str:
    """Get Prometheus metrics using the global APM."""
    return _apm_instance.get_metrics_prometheus()


def get_performance_report() -> Dict[str, Any]:
    """Get performance report using the global APM."""
    return _apm_instance.get_performance_report()


def get_trace_details(trace_id: str) -> Dict[str, Any]:
    """Get trace details using the global APM."""
    return _apm_instance.get_trace_details(trace_id)


async def stop_apm():
    """Stop the global APM system."""
    await _apm_instance.stop_monitoring()
