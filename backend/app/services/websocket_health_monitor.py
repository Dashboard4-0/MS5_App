"""
MS5.0 Floor Dashboard - WebSocket Health Monitor

This module provides comprehensive health monitoring for WebSocket connections,
including performance metrics, connection quality assessment, and automated
recovery mechanisms.

Architected for cosmic scale operations - the nervous system of a starship.
"""

import asyncio
import time
from typing import Dict, List, Optional, Any, Tuple
from datetime import datetime, timedelta
from dataclasses import dataclass
from enum import Enum
import structlog

from app.services.enhanced_websocket_manager import enhanced_websocket_manager, ConnectionMetrics

logger = structlog.get_logger()


class HealthStatus(Enum):
    """Health status levels for WebSocket connections."""
    EXCELLENT = "excellent"
    GOOD = "good"
    FAIR = "fair"
    POOR = "poor"
    CRITICAL = "critical"


@dataclass
class HealthMetrics:
    """Comprehensive health metrics for WebSocket monitoring."""
    connection_id: str
    user_id: str
    health_score: float
    status: HealthStatus
    response_time_avg: float
    message_success_rate: float
    error_rate: float
    uptime_seconds: float
    last_activity_seconds_ago: float
    subscription_count: int
    bytes_per_second: float
    connection_stability: float
    network_quality: float
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        return {
            "connection_id": self.connection_id,
            "user_id": self.user_id,
            "health_score": self.health_score,
            "status": self.status.value,
            "response_time_avg": self.response_time_avg,
            "message_success_rate": self.message_success_rate,
            "error_rate": self.error_rate,
            "uptime_seconds": self.uptime_seconds,
            "last_activity_seconds_ago": self.last_activity_seconds_ago,
            "subscription_count": self.subscription_count,
            "bytes_per_second": self.bytes_per_second,
            "connection_stability": self.connection_stability,
            "network_quality": self.network_quality
        }


@dataclass
class SystemHealthMetrics:
    """System-wide health metrics."""
    total_connections: int
    healthy_connections: int
    average_health_score: float
    system_status: HealthStatus
    total_messages_per_second: float
    total_errors_per_minute: float
    connection_utilization: float
    memory_usage_mb: float
    cpu_usage_percent: float
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON serialization."""
        return {
            "total_connections": self.total_connections,
            "healthy_connections": self.healthy_connections,
            "average_health_score": self.average_health_score,
            "system_status": self.system_status.value,
            "total_messages_per_second": self.total_messages_per_second,
            "total_errors_per_minute": self.total_errors_per_minute,
            "connection_utilization": self.connection_utilization,
            "memory_usage_mb": self.memory_usage_mb,
            "cpu_usage_percent": self.cpu_usage_percent
        }


class WebSocketHealthMonitor:
    """
    Comprehensive WebSocket health monitoring service.
    
    Features:
    - Individual connection health assessment
    - System-wide health monitoring
    - Performance metrics collection
    - Automated recovery mechanisms
    - Health trend analysis
    - Alert generation
    - Performance optimization recommendations
    """
    
    def __init__(self, check_interval: float = 30.0):
        self.check_interval = check_interval
        self.health_history: Dict[str, List[HealthMetrics]] = {}
        self.system_health_history: List[SystemHealthMetrics] = []
        self.alert_thresholds = {
            "health_score_critical": 0.3,
            "health_score_warning": 0.6,
            "error_rate_critical": 0.1,
            "error_rate_warning": 0.05,
            "response_time_critical": 5000.0,  # milliseconds
            "response_time_warning": 2000.0,
            "uptime_minimum": 300.0  # seconds
        }
        
        # Performance tracking
        self.performance_tracking = {
            "message_counts": [],
            "error_counts": [],
            "response_times": [],
            "connection_counts": []
        }
        
        # Background monitoring task
        self._monitoring_task: Optional[asyncio.Task] = None
        self._start_monitoring()
        
        logger.info("WebSocket Health Monitor initialized", check_interval=check_interval)
    
    def _start_monitoring(self) -> None:
        """Start background health monitoring."""
        try:
            loop = asyncio.get_event_loop()
            self._monitoring_task = loop.create_task(self._monitoring_loop())
            logger.info("WebSocket health monitoring started")
        except Exception as e:
            logger.error("Failed to start WebSocket health monitoring", error=str(e))
    
    async def _monitoring_loop(self) -> None:
        """Background monitoring loop."""
        while True:
            try:
                await asyncio.sleep(self.check_interval)
                await self.perform_health_check()
            except Exception as e:
                logger.error("Health monitoring loop error", error=str(e))
                await asyncio.sleep(5)  # Brief pause before retry
    
    async def perform_health_check(self) -> None:
        """Perform comprehensive health check on all connections."""
        try:
            # Check individual connections
            connection_health = await self.check_connection_health()
            
            # Check system health
            system_health = await self.check_system_health()
            
            # Store health history
            self._store_health_history(connection_health, system_health)
            
            # Check for alerts
            await self._check_alerts(connection_health, system_health)
            
            # Update performance tracking
            self._update_performance_tracking(system_health)
            
            logger.debug("Health check completed", 
                        connections_checked=len(connection_health),
                        system_status=system_health.system_status.value)
            
        except Exception as e:
            logger.error("Health check error", error=str(e))
    
    async def check_connection_health(self) -> Dict[str, HealthMetrics]:
        """Check health of all individual connections."""
        connection_health = {}
        current_time = time.time()
        
        for connection_id, metrics in enhanced_websocket_manager.connection_metrics.items():
            try:
                # Calculate health metrics
                health_score = self._calculate_health_score(metrics, current_time)
                status = self._determine_health_status(health_score)
                
                # Calculate performance metrics
                response_time_avg = self._calculate_response_time_avg(metrics)
                message_success_rate = self._calculate_success_rate(metrics)
                error_rate = self._calculate_error_rate(metrics)
                uptime_seconds = (current_time - metrics.connected_at.timestamp())
                last_activity_seconds_ago = (current_time - metrics.last_activity.timestamp())
                bytes_per_second = self._calculate_bytes_per_second(metrics, uptime_seconds)
                connection_stability = self._calculate_connection_stability(metrics, uptime_seconds)
                network_quality = self._calculate_network_quality(metrics, response_time_avg, error_rate)
                
                # Create health metrics
                health_metrics = HealthMetrics(
                    connection_id=connection_id,
                    user_id=metrics.user_id,
                    health_score=health_score,
                    status=status,
                    response_time_avg=response_time_avg,
                    message_success_rate=message_success_rate,
                    error_rate=error_rate,
                    uptime_seconds=uptime_seconds,
                    last_activity_seconds_ago=last_activity_seconds_ago,
                    subscription_count=metrics.subscription_count,
                    bytes_per_second=bytes_per_second,
                    connection_stability=connection_stability,
                    network_quality=network_quality
                )
                
                connection_health[connection_id] = health_metrics
                
                # Update connection metrics health score
                metrics.health_score = health_score
                
            except Exception as e:
                logger.error("Error checking connection health", 
                           connection_id=connection_id, error=str(e))
        
        return connection_health
    
    async def check_system_health(self) -> SystemHealthMetrics:
        """Check overall system health."""
        try:
            # Get basic stats
            stats = enhanced_websocket_manager.get_connection_stats()
            
            # Calculate system metrics
            total_connections = stats["total_connections"]
            healthy_connections = sum(1 for metrics in enhanced_websocket_manager.connection_metrics.values() 
                                    if metrics.health_score >= self.alert_thresholds["health_score_warning"])
            average_health_score = stats["average_health_score"]
            
            # Calculate performance metrics
            total_messages_per_second = self._calculate_system_messages_per_second()
            total_errors_per_minute = stats["total_errors"] / max(1, total_connections)
            connection_utilization = stats["connection_utilization"]
            
            # System resource metrics (simplified)
            memory_usage_mb = self._estimate_memory_usage()
            cpu_usage_percent = self._estimate_cpu_usage()
            
            # Determine system status
            system_status = self._determine_system_status(
                average_health_score, total_errors_per_minute, connection_utilization
            )
            
            return SystemHealthMetrics(
                total_connections=total_connections,
                healthy_connections=healthy_connections,
                average_health_score=average_health_score,
                system_status=system_status,
                total_messages_per_second=total_messages_per_second,
                total_errors_per_minute=total_errors_per_minute,
                connection_utilization=connection_utilization,
                memory_usage_mb=memory_usage_mb,
                cpu_usage_percent=cpu_usage_percent
            )
            
        except Exception as e:
            logger.error("Error checking system health", error=str(e))
            # Return minimal health metrics
            return SystemHealthMetrics(
                total_connections=0,
                healthy_connections=0,
                average_health_score=0.0,
                system_status=HealthStatus.CRITICAL,
                total_messages_per_second=0.0,
                total_errors_per_minute=0.0,
                connection_utilization=0.0,
                memory_usage_mb=0.0,
                cpu_usage_percent=0.0
            )
    
    def _calculate_health_score(self, metrics: ConnectionMetrics, current_time: float) -> float:
        """Calculate comprehensive health score for a connection."""
        try:
            # Base score from connection stability
            stability_score = max(0, 1.0 - (metrics.error_count / max(1, metrics.message_count)))
            
            # Activity score based on recent activity
            time_since_activity = current_time - metrics.last_activity.timestamp()
            activity_score = max(0, 1.0 - (time_since_activity / 300))  # 5 minutes timeout
            
            # Subscription efficiency score
            efficiency_score = min(1.0, 10.0 / max(1, metrics.subscription_count))
            
            # Network quality score (based on error rate)
            network_score = max(0, 1.0 - (metrics.error_count / max(1, metrics.message_count)))
            
            # Uptime score
            uptime_seconds = current_time - metrics.connected_at.timestamp()
            uptime_score = min(1.0, uptime_seconds / 3600)  # 1 hour for full score
            
            # Weighted average
            health_score = (
                stability_score * 0.3 +
                activity_score * 0.25 +
                efficiency_score * 0.15 +
                network_score * 0.2 +
                uptime_score * 0.1
            )
            
            return max(0, min(1, health_score))
            
        except Exception as e:
            logger.error("Error calculating health score", error=str(e))
            return 0.0
    
    def _determine_health_status(self, health_score: float) -> HealthStatus:
        """Determine health status based on health score."""
        if health_score >= 0.9:
            return HealthStatus.EXCELLENT
        elif health_score >= 0.8:
            return HealthStatus.GOOD
        elif health_score >= 0.6:
            return HealthStatus.FAIR
        elif health_score >= 0.3:
            return HealthStatus.POOR
        else:
            return HealthStatus.CRITICAL
    
    def _calculate_response_time_avg(self, metrics: ConnectionMetrics) -> float:
        """Calculate average response time for a connection."""
        # Simplified calculation - in real implementation, you'd track actual response times
        if metrics.message_count > 0:
            # Estimate based on message count and error rate
            base_time = 100.0  # Base response time in milliseconds
            error_penalty = metrics.error_count * 500.0  # Penalty for errors
            return base_time + (error_penalty / metrics.message_count)
        return 0.0
    
    def _calculate_success_rate(self, metrics: ConnectionMetrics) -> float:
        """Calculate message success rate."""
        if metrics.message_count > 0:
            return (metrics.message_count - metrics.error_count) / metrics.message_count
        return 1.0
    
    def _calculate_error_rate(self, metrics: ConnectionMetrics) -> float:
        """Calculate error rate."""
        if metrics.message_count > 0:
            return metrics.error_count / metrics.message_count
        return 0.0
    
    def _calculate_bytes_per_second(self, metrics: ConnectionMetrics, uptime_seconds: float) -> float:
        """Calculate bytes per second throughput."""
        if uptime_seconds > 0:
            total_bytes = metrics.bytes_sent + metrics.bytes_received
            return total_bytes / uptime_seconds
        return 0.0
    
    def _calculate_connection_stability(self, metrics: ConnectionMetrics, uptime_seconds: float) -> float:
        """Calculate connection stability score."""
        if uptime_seconds > 0:
            # Stability based on uptime and error rate
            uptime_factor = min(1.0, uptime_seconds / 3600)  # 1 hour for full score
            error_factor = max(0, 1.0 - (metrics.error_count / max(1, metrics.message_count)))
            return (uptime_factor + error_factor) / 2
        return 0.0
    
    def _calculate_network_quality(self, metrics: ConnectionMetrics, response_time_avg: float, error_rate: float) -> float:
        """Calculate network quality score."""
        # Network quality based on response time and error rate
        response_factor = max(0, 1.0 - (response_time_avg / 5000.0))  # 5 seconds max
        error_factor = max(0, 1.0 - error_rate)
        return (response_factor + error_factor) / 2
    
    def _determine_system_status(self, avg_health: float, errors_per_minute: float, utilization: float) -> HealthStatus:
        """Determine overall system status."""
        if avg_health >= 0.8 and errors_per_minute < 1.0 and utilization < 0.9:
            return HealthStatus.EXCELLENT
        elif avg_health >= 0.7 and errors_per_minute < 5.0 and utilization < 0.95:
            return HealthStatus.GOOD
        elif avg_health >= 0.5 and errors_per_minute < 10.0:
            return HealthStatus.FAIR
        elif avg_health >= 0.3 and errors_per_minute < 20.0:
            return HealthStatus.POOR
        else:
            return HealthStatus.CRITICAL
    
    def _calculate_system_messages_per_second(self) -> float:
        """Calculate total system messages per second."""
        total_messages = sum(m.message_count for m in enhanced_websocket_manager.connection_metrics.values())
        if total_messages > 0:
            # Estimate based on connection uptime
            avg_uptime = sum(
                time.time() - m.connected_at.timestamp() 
                for m in enhanced_websocket_manager.connection_metrics.values()
            ) / max(1, len(enhanced_websocket_manager.connection_metrics))
            
            if avg_uptime > 0:
                return total_messages / avg_uptime
        return 0.0
    
    def _estimate_memory_usage(self) -> float:
        """Estimate memory usage in MB."""
        # Simplified estimation based on connection count
        connection_count = len(enhanced_websocket_manager.connection_metrics)
        base_memory = 50.0  # Base memory in MB
        per_connection = 0.5  # MB per connection
        return base_memory + (connection_count * per_connection)
    
    def _estimate_cpu_usage(self) -> float:
        """Estimate CPU usage percentage."""
        # Simplified estimation based on activity
        total_messages = sum(m.message_count for m in enhanced_websocket_manager.connection_metrics.values())
        if total_messages > 0:
            # Estimate CPU usage based on message processing
            return min(100.0, (total_messages / 1000.0) * 10.0)  # 10% per 1000 messages
        return 0.0
    
    def _store_health_history(self, connection_health: Dict[str, HealthMetrics], system_health: SystemHealthMetrics) -> None:
        """Store health history for trend analysis."""
        # Store connection health history
        for connection_id, health_metrics in connection_health.items():
            if connection_id not in self.health_history:
                self.health_history[connection_id] = []
            
            self.health_history[connection_id].append(health_metrics)
            
            # Keep only last 100 entries per connection
            if len(self.health_history[connection_id]) > 100:
                self.health_history[connection_id] = self.health_history[connection_id][-100:]
        
        # Store system health history
        self.system_health_history.append(system_health)
        
        # Keep only last 100 system health entries
        if len(self.system_health_history) > 100:
            self.system_health_history = self.system_health_history[-100:]
    
    async def _check_alerts(self, connection_health: Dict[str, HealthMetrics], system_health: SystemHealthMetrics) -> None:
        """Check for health alerts and trigger notifications."""
        alerts = []
        
        # Check individual connection alerts
        for connection_id, health_metrics in connection_health.items():
            if health_metrics.health_score < self.alert_thresholds["health_score_critical"]:
                alerts.append({
                    "type": "connection_critical",
                    "connection_id": connection_id,
                    "user_id": health_metrics.user_id,
                    "health_score": health_metrics.health_score,
                    "message": f"Connection {connection_id} has critical health score: {health_metrics.health_score:.2f}"
                })
            elif health_metrics.health_score < self.alert_thresholds["health_score_warning"]:
                alerts.append({
                    "type": "connection_warning",
                    "connection_id": connection_id,
                    "user_id": health_metrics.user_id,
                    "health_score": health_metrics.health_score,
                    "message": f"Connection {connection_id} has warning health score: {health_metrics.health_score:.2f}"
                })
        
        # Check system alerts
        if system_health.system_status == HealthStatus.CRITICAL:
            alerts.append({
                "type": "system_critical",
                "system_status": system_health.system_status.value,
                "average_health": system_health.average_health_score,
                "message": f"System health is critical: {system_health.average_health_score:.2f}"
            })
        elif system_health.system_status == HealthStatus.POOR:
            alerts.append({
                "type": "system_warning",
                "system_status": system_health.system_status.value,
                "average_health": system_health.average_health_score,
                "message": f"System health is poor: {system_health.average_health_score:.2f}"
            })
        
        # Send alerts
        for alert in alerts:
            await self._send_health_alert(alert)
    
    async def _send_health_alert(self, alert: Dict[str, Any]) -> None:
        """Send health alert notification."""
        try:
            # Send system alert via WebSocket
            await enhanced_websocket_manager.broadcast({
                "type": "health_alert",
                "data": alert,
                "timestamp": datetime.utcnow().isoformat()
            })
            
            logger.warning("Health alert sent", alert=alert)
            
        except Exception as e:
            logger.error("Error sending health alert", alert=alert, error=str(e))
    
    def _update_performance_tracking(self, system_health: SystemHealthMetrics) -> None:
        """Update performance tracking data."""
        current_time = time.time()
        
        self.performance_tracking["message_counts"].append({
            "timestamp": current_time,
            "value": system_health.total_messages_per_second
        })
        
        self.performance_tracking["error_counts"].append({
            "timestamp": current_time,
            "value": system_health.total_errors_per_minute
        })
        
        self.performance_tracking["connection_counts"].append({
            "timestamp": current_time,
            "value": system_health.total_connections
        })
        
        # Keep only last 100 entries per metric
        for metric_name in self.performance_tracking:
            if len(self.performance_tracking[metric_name]) > 100:
                self.performance_tracking[metric_name] = self.performance_tracking[metric_name][-100:]
    
    # ============================================================================
    # PUBLIC API METHODS
    # ============================================================================
    
    async def get_connection_health(self, connection_id: str) -> Optional[HealthMetrics]:
        """Get health metrics for specific connection."""
        try:
            connection_health = await self.check_connection_health()
            return connection_health.get(connection_id)
        except Exception as e:
            logger.error("Error getting connection health", connection_id=connection_id, error=str(e))
            return None
    
    async def get_system_health(self) -> SystemHealthMetrics:
        """Get current system health metrics."""
        return await self.check_system_health()
    
    async def get_health_trends(self, connection_id: Optional[str] = None) -> Dict[str, Any]:
        """Get health trends for analysis."""
        try:
            if connection_id:
                # Get trends for specific connection
                history = self.health_history.get(connection_id, [])
                return {
                    "connection_id": connection_id,
                    "trends": {
                        "health_scores": [h.health_score for h in history],
                        "timestamps": [h.uptime_seconds for h in history],
                        "statuses": [h.status.value for h in history]
                    }
                }
            else:
                # Get system trends
                return {
                    "system_trends": {
                        "average_health_scores": [h.average_health_score for h in self.system_health_history],
                        "total_connections": [h.total_connections for h in self.system_health_history],
                        "system_statuses": [h.system_status.value for h in self.system_health_history]
                    }
                }
        except Exception as e:
            logger.error("Error getting health trends", connection_id=connection_id, error=str(e))
            return {}
    
    async def get_performance_metrics(self) -> Dict[str, Any]:
        """Get performance metrics for monitoring."""
        return {
            "performance_tracking": self.performance_tracking,
            "alert_thresholds": self.alert_thresholds,
            "monitoring_interval": self.check_interval
        }
    
    async def force_health_check(self) -> Dict[str, Any]:
        """Force immediate health check."""
        await self.perform_health_check()
        
        connection_health = await self.check_connection_health()
        system_health = await self.check_system_health()
        
        return {
            "connection_health": {k: v.to_dict() for k, v in connection_health.items()},
            "system_health": system_health.to_dict(),
            "check_timestamp": datetime.utcnow().isoformat()
        }
    
    async def shutdown(self) -> None:
        """Shutdown health monitor."""
        if self._monitoring_task:
            self._monitoring_task.cancel()
            try:
                await self._monitoring_task
            except asyncio.CancelledError:
                pass
        
        logger.info("WebSocket Health Monitor shutdown completed")


# Global WebSocket health monitor instance
websocket_health_monitor = WebSocketHealthMonitor()
