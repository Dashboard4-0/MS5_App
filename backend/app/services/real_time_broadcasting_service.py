"""
MS5.0 Floor Dashboard - Real-Time Broadcasting Service

Enterprise-grade real-time broadcasting for cosmic scale operations.
The nervous system of a starship - built for reliability and performance.

This service provides comprehensive real-time data broadcasting including:
- Live production data updates
- Real-time Andon notifications
- Equipment status monitoring
- OEE calculation updates
- Quality alerts and inspections
- Job assignment and progress tracking
- Downtime event broadcasting
- Escalation management
"""

import asyncio
import json
from typing import Dict, List, Optional, Any, Callable
from datetime import datetime, timezone
from dataclasses import dataclass, field
from enum import Enum
import structlog

from app.services.enhanced_websocket_manager import enhanced_websocket_manager
from app.services.websocket_manager import websocket_manager
from app.api.websocket import WebSocketEventType
from app.utils.exceptions import BroadcastingError, ServiceError

logger = structlog.get_logger()


class BroadcastPriority(Enum):
    """Broadcast priority levels for intelligent message routing."""
    CRITICAL = 1  # System alerts, Andon events, equipment faults
    HIGH = 2      # Production updates, OEE data, job assignments
    NORMAL = 3    # Regular status updates, quality checks
    LOW = 4       # Heartbeats, diagnostics, maintenance updates


@dataclass
class BroadcastEvent:
    """Real-time broadcast event with comprehensive metadata."""
    event_type: str
    data: Dict[str, Any]
    priority: BroadcastPriority
    target_filters: Dict[str, Any] = field(default_factory=dict)
    timestamp: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    retry_count: int = 0
    max_retries: int = 3
    metadata: Dict[str, Any] = field(default_factory=dict)


@dataclass
class BroadcastingMetrics:
    """Comprehensive broadcasting metrics for monitoring."""
    total_events_sent: int = 0
    events_by_priority: Dict[BroadcastPriority, int] = field(default_factory=dict)
    events_by_type: Dict[str, int] = field(default_factory=dict)
    failed_broadcasts: int = 0
    retry_attempts: int = 0
    average_latency: float = 0.0
    last_broadcast_time: Optional[datetime] = None
    active_subscriptions: int = 0


class RealTimeBroadcastingService:
    """
    Enterprise-grade real-time broadcasting service for production operations.
    
    This service provides comprehensive real-time data broadcasting with:
    - Intelligent message routing based on priority
    - Automatic retry mechanisms for failed broadcasts
    - Comprehensive metrics and monitoring
    - Factory-specific optimizations
    - Advanced filtering and targeting
    """
    
    def __init__(self):
        self.is_running = False
        self.metrics = BroadcastingMetrics()
        self.event_queue: asyncio.Queue = asyncio.Queue()
        self.broadcast_tasks: Dict[str, asyncio.Task] = {}
        self.subscription_callbacks: Dict[str, List[Callable]] = {}
        
        # Initialize metrics tracking
        for priority in BroadcastPriority:
            self.metrics.events_by_priority[priority] = 0
        
        logger.info("Real-time broadcasting service initialized")
    
    async def start(self):
        """Start the real-time broadcasting service."""
        if self.is_running:
            logger.warning("Broadcasting service is already running")
            return
        
        self.is_running = True
        
        # Start background tasks
        self.broadcast_tasks["event_processor"] = asyncio.create_task(self._event_processor_loop())
        self.broadcast_tasks["metrics_updater"] = asyncio.create_task(self._metrics_updater_loop())
        self.broadcast_tasks["health_monitor"] = asyncio.create_task(self._health_monitor_loop())
        
        logger.info("Real-time broadcasting service started")
    
    async def stop(self):
        """Stop the real-time broadcasting service."""
        if not self.is_running:
            return
        
        self.is_running = False
        
        # Cancel all background tasks
        for task_name, task in self.broadcast_tasks.items():
            if not task.done():
                task.cancel()
                try:
                    await task
                except asyncio.CancelledError:
                    logger.info(f"Broadcasting task {task_name} cancelled")
        
        self.broadcast_tasks.clear()
        
        logger.info("Real-time broadcasting service stopped")
    
    async def broadcast_production_update(self, line_id: str, production_data: Dict[str, Any]):
        """
        Broadcast live production data updates.
        
        Args:
            line_id: Production line identifier
            production_data: Production metrics and status data
        """
        event = BroadcastEvent(
            event_type=WebSocketEventType.PRODUCTION_UPDATE,
            data={
                "line_id": line_id,
                "production_data": production_data,
                "timestamp": datetime.now(timezone.utc).isoformat()
            },
            priority=BroadcastPriority.HIGH,
            target_filters={"line_id": line_id},
            metadata={
                "source": "production_service",
                "data_size": len(json.dumps(production_data))
            }
        )
        
        await self._queue_event(event)
        logger.debug("Production update queued for broadcasting", line_id=line_id)
    
    async def broadcast_oee_update(self, line_id: str, oee_data: Dict[str, Any]):
        """
        Broadcast real-time OEE calculation updates.
        
        Args:
            line_id: Production line identifier
            oee_data: OEE metrics and calculations
        """
        event = BroadcastEvent(
            event_type=WebSocketEventType.OEE_UPDATE,
            data={
                "line_id": line_id,
                "oee_data": oee_data,
                "timestamp": datetime.now(timezone.utc).isoformat()
            },
            priority=BroadcastPriority.HIGH,
            target_filters={"line_id": line_id},
            metadata={
                "source": "oee_calculator",
                "availability": oee_data.get("availability", 0),
                "performance": oee_data.get("performance", 0),
                "quality": oee_data.get("quality", 0),
                "oee": oee_data.get("oee", 0)
            }
        )
        
        await self._queue_event(event)
        logger.debug("OEE update queued for broadcasting", line_id=line_id, oee=oee_data.get("oee", 0))
    
    async def broadcast_andon_notification(self, andon_event: Dict[str, Any]):
        """
        Broadcast real-time Andon notifications with priority handling.
        
        Args:
            andon_event: Andon event data with priority and escalation info
        """
        priority_level = BroadcastPriority.CRITICAL
        if andon_event.get("priority") == "low":
            priority_level = BroadcastPriority.NORMAL
        elif andon_event.get("priority") == "medium":
            priority_level = BroadcastPriority.HIGH
        
        event = BroadcastEvent(
            event_type=WebSocketEventType.ANDON_EVENT,
            data={
                "andon_event": andon_event,
                "timestamp": datetime.now(timezone.utc).isoformat()
            },
            priority=priority_level,
            target_filters={
                "line_id": andon_event.get("line_id"),
                "priority": andon_event.get("priority")
            },
            metadata={
                "source": "andon_service",
                "event_id": andon_event.get("id"),
                "escalation_level": andon_event.get("escalation_level", 0)
            }
        )
        
        await self._queue_event(event)
        logger.info("Andon notification queued for broadcasting", 
                   event_id=andon_event.get("id"), 
                   priority=andon_event.get("priority"))
    
    async def broadcast_equipment_status(self, equipment_code: str, status_data: Dict[str, Any]):
        """
        Broadcast equipment status monitoring updates.
        
        Args:
            equipment_code: Equipment identifier
            status_data: Equipment status and sensor data
        """
        priority_level = BroadcastPriority.NORMAL
        if status_data.get("status") == "fault":
            priority_level = BroadcastPriority.CRITICAL
        elif status_data.get("status") == "warning":
            priority_level = BroadcastPriority.HIGH
        
        event = BroadcastEvent(
            event_type=WebSocketEventType.EQUIPMENT_STATUS_UPDATE,
            data={
                "equipment_code": equipment_code,
                "status_data": status_data,
                "timestamp": datetime.now(timezone.utc).isoformat()
            },
            priority=priority_level,
            target_filters={"equipment_code": equipment_code},
            metadata={
                "source": "equipment_monitor",
                "status": status_data.get("status"),
                "temperature": status_data.get("temperature"),
                "pressure": status_data.get("pressure"),
                "vibration": status_data.get("vibration")
            }
        )
        
        await self._queue_event(event)
        logger.debug("Equipment status update queued for broadcasting", 
                    equipment_code=equipment_code, 
                    status=status_data.get("status"))
    
    async def broadcast_job_update(self, job_data: Dict[str, Any]):
        """
        Broadcast job assignment and progress updates.
        
        Args:
            job_data: Job information and progress data
        """
        event = BroadcastEvent(
            event_type=WebSocketEventType.JOB_ASSIGNMENT_UPDATED,
            data={
                "job_data": job_data,
                "timestamp": datetime.now(timezone.utc).isoformat()
            },
            priority=BroadcastPriority.HIGH,
            target_filters={
                "line_id": job_data.get("line_id"),
                "user_id": job_data.get("assigned_user_id")
            },
            metadata={
                "source": "job_service",
                "job_id": job_data.get("id"),
                "status": job_data.get("status"),
                "progress": job_data.get("progress", 0)
            }
        )
        
        await self._queue_event(event)
        logger.debug("Job update queued for broadcasting", 
                    job_id=job_data.get("id"), 
                    status=job_data.get("status"))
    
    async def broadcast_downtime_event(self, downtime_data: Dict[str, Any]):
        """
        Broadcast downtime events and statistics.
        
        Args:
            downtime_data: Downtime event information
        """
        event = BroadcastEvent(
            event_type=WebSocketEventType.DOWNTIME_EVENT,
            data={
                "downtime_data": downtime_data,
                "timestamp": datetime.now(timezone.utc).isoformat()
            },
            priority=BroadcastPriority.HIGH,
            target_filters={
                "line_id": downtime_data.get("line_id"),
                "equipment_code": downtime_data.get("equipment_code")
            },
            metadata={
                "source": "downtime_tracker",
                "reason": downtime_data.get("reason"),
                "duration": downtime_data.get("duration", 0)
            }
        )
        
        await self._queue_event(event)
        logger.info("Downtime event queued for broadcasting", 
                   line_id=downtime_data.get("line_id"), 
                   reason=downtime_data.get("reason"))
    
    async def broadcast_quality_alert(self, quality_data: Dict[str, Any]):
        """
        Broadcast quality alerts and inspection results.
        
        Args:
            quality_data: Quality inspection and alert data
        """
        priority_level = BroadcastPriority.HIGH
        if quality_data.get("severity") == "critical":
            priority_level = BroadcastPriority.CRITICAL
        
        event = BroadcastEvent(
            event_type=WebSocketEventType.QUALITY_ALERT_TRIGGERED,
            data={
                "quality_data": quality_data,
                "timestamp": datetime.now(timezone.utc).isoformat()
            },
            priority=priority_level,
            target_filters={"line_id": quality_data.get("line_id")},
            metadata={
                "source": "quality_service",
                "inspection_id": quality_data.get("inspection_id"),
                "defect_count": quality_data.get("defect_count", 0),
                "severity": quality_data.get("severity")
            }
        )
        
        await self._queue_event(event)
        logger.info("Quality alert queued for broadcasting", 
                   line_id=quality_data.get("line_id"), 
                   severity=quality_data.get("severity"))
    
    async def broadcast_escalation_update(self, escalation_data: Dict[str, Any]):
        """
        Broadcast escalation updates and reminders.
        
        Args:
            escalation_data: Escalation information and status
        """
        event = BroadcastEvent(
            event_type=WebSocketEventType.ANDON_ESCALATION_TRIGGERED,
            data={
                "escalation_data": escalation_data,
                "timestamp": datetime.now(timezone.utc).isoformat()
            },
            priority=BroadcastPriority.CRITICAL,
            target_filters={
                "line_id": escalation_data.get("line_id"),
                "escalation_level": escalation_data.get("level")
            },
            metadata={
                "source": "escalation_service",
                "escalation_id": escalation_data.get("id"),
                "level": escalation_data.get("level"),
                "assigned_to": escalation_data.get("assigned_to")
            }
        )
        
        await self._queue_event(event)
        logger.warning("Escalation update queued for broadcasting", 
                      escalation_id=escalation_data.get("id"), 
                      level=escalation_data.get("level"))
    
    async def broadcast_system_alert(self, alert_data: Dict[str, Any]):
        """
        Broadcast system-wide alerts and notifications.
        
        Args:
            alert_data: System alert information
        """
        event = BroadcastEvent(
            event_type=WebSocketEventType.SYSTEM_ALERT,
            data={
                "alert_data": alert_data,
                "timestamp": datetime.now(timezone.utc).isoformat()
            },
            priority=BroadcastPriority.CRITICAL,
            target_filters={},  # System-wide broadcast
            metadata={
                "source": "system_monitor",
                "alert_type": alert_data.get("type"),
                "severity": alert_data.get("severity")
            }
        )
        
        await self._queue_event(event)
        logger.warning("System alert queued for broadcasting", 
                      alert_type=alert_data.get("type"), 
                      severity=alert_data.get("severity"))
    
    async def _queue_event(self, event: BroadcastEvent):
        """Queue an event for broadcasting."""
        try:
            await self.event_queue.put(event)
        except Exception as e:
            logger.error("Failed to queue broadcast event", error=str(e), event_type=event.event_type)
            raise BroadcastingError(f"Failed to queue event: {str(e)}")
    
    async def _event_processor_loop(self):
        """Main event processing loop for broadcasting."""
        while self.is_running:
            try:
                # Wait for events with timeout
                event = await asyncio.wait_for(self.event_queue.get(), timeout=1.0)
                
                # Process the event
                await self._process_broadcast_event(event)
                
                # Update metrics
                self.metrics.total_events_sent += 1
                self.metrics.events_by_priority[event.priority] += 1
                self.metrics.events_by_type[event.event_type] = self.metrics.events_by_type.get(event.event_type, 0) + 1
                self.metrics.last_broadcast_time = datetime.now(timezone.utc)
                
            except asyncio.TimeoutError:
                # No events to process, continue
                continue
            except Exception as e:
                logger.error("Error in event processor loop", error=str(e))
                await asyncio.sleep(1)  # Brief pause before retrying
    
    async def _process_broadcast_event(self, event: BroadcastEvent):
        """Process a single broadcast event."""
        try:
            # Create WebSocket message
            message = {
                "type": event.event_type,
                "data": event.data,
                "timestamp": event.timestamp.isoformat(),
                "priority": event.priority.value,
                "metadata": event.metadata
            }
            
            # Broadcast based on event type and filters
            if event.event_type == WebSocketEventType.PRODUCTION_UPDATE:
                await self._broadcast_to_line_subscribers(message, event.target_filters.get("line_id"))
            elif event.event_type == WebSocketEventType.OEE_UPDATE:
                await self._broadcast_to_line_subscribers(message, event.target_filters.get("line_id"))
            elif event.event_type == WebSocketEventType.ANDON_EVENT:
                await self._broadcast_andon_event(message, event.target_filters)
            elif event.event_type == WebSocketEventType.EQUIPMENT_STATUS_UPDATE:
                await self._broadcast_to_equipment_subscribers(message, event.target_filters.get("equipment_code"))
            elif event.event_type == WebSocketEventType.JOB_ASSIGNMENT_UPDATED:
                await self._broadcast_job_update(message, event.target_filters)
            elif event.event_type == WebSocketEventType.DOWNTIME_EVENT:
                await self._broadcast_downtime_event(message, event.target_filters)
            elif event.event_type == WebSocketEventType.QUALITY_ALERT_TRIGGERED:
                await self._broadcast_to_line_subscribers(message, event.target_filters.get("line_id"))
            elif event.event_type == WebSocketEventType.ANDON_ESCALATION_TRIGGERED:
                await self._broadcast_escalation_event(message, event.target_filters)
            elif event.event_type == WebSocketEventType.SYSTEM_ALERT:
                await self._broadcast_system_wide(message)
            else:
                # Default broadcast to all subscribers
                await enhanced_websocket_manager.broadcast(message)
            
            logger.debug("Event broadcasted successfully", 
                        event_type=event.event_type, 
                        priority=event.priority.name)
            
        except Exception as e:
            logger.error("Failed to process broadcast event", 
                        error=str(e), 
                        event_type=event.event_type)
            
            # Retry logic
            if event.retry_count < event.max_retries:
                event.retry_count += 1
                self.metrics.retry_attempts += 1
                await self._queue_event(event)
                logger.info("Event queued for retry", 
                           event_type=event.event_type, 
                           retry_count=event.retry_count)
            else:
                self.metrics.failed_broadcasts += 1
                logger.error("Event failed after max retries", 
                           event_type=event.event_type, 
                           max_retries=event.max_retries)
    
    async def _broadcast_to_line_subscribers(self, message: Dict[str, Any], line_id: Optional[str]):
        """Broadcast message to line-specific subscribers."""
        if line_id:
            await enhanced_websocket_manager.send_to_line(message, line_id)
        else:
            await enhanced_websocket_manager.broadcast(message)
    
    async def _broadcast_to_equipment_subscribers(self, message: Dict[str, Any], equipment_code: Optional[str]):
        """Broadcast message to equipment-specific subscribers."""
        if equipment_code:
            await enhanced_websocket_manager.send_to_equipment(message, equipment_code)
        else:
            await enhanced_websocket_manager.broadcast(message)
    
    async def _broadcast_andon_event(self, message: Dict[str, Any], filters: Dict[str, Any]):
        """Broadcast Andon event to relevant subscribers."""
        line_id = filters.get("line_id")
        priority = filters.get("priority")
        
        if line_id:
            await enhanced_websocket_manager.send_to_line(message, line_id)
        
        # Also broadcast to Andon-specific subscribers
        await enhanced_websocket_manager.send_to_andon_subscribers(message, line_id, priority)
    
    async def _broadcast_job_update(self, message: Dict[str, Any], filters: Dict[str, Any]):
        """Broadcast job update to relevant subscribers."""
        line_id = filters.get("line_id")
        user_id = filters.get("user_id")
        
        if line_id:
            await enhanced_websocket_manager.send_to_line(message, line_id)
        
        if user_id:
            # Send to specific user if they have an active connection
            await enhanced_websocket_manager.send_to_user(message, user_id)
    
    async def _broadcast_downtime_event(self, message: Dict[str, Any], filters: Dict[str, Any]):
        """Broadcast downtime event to relevant subscribers."""
        line_id = filters.get("line_id")
        equipment_code = filters.get("equipment_code")
        
        await enhanced_websocket_manager.send_to_downtime_subscribers(message, line_id, equipment_code)
    
    async def _broadcast_escalation_event(self, message: Dict[str, Any], filters: Dict[str, Any]):
        """Broadcast escalation event to relevant subscribers."""
        line_id = filters.get("line_id")
        escalation_level = filters.get("escalation_level")
        
        await enhanced_websocket_manager.send_to_escalation_subscribers(message, None, escalation_level)
        
        if line_id:
            await enhanced_websocket_manager.send_to_line(message, line_id)
    
    async def _broadcast_system_wide(self, message: Dict[str, Any]):
        """Broadcast system-wide message to all subscribers."""
        await enhanced_websocket_manager.broadcast(message)
    
    async def _metrics_updater_loop(self):
        """Background task to update broadcasting metrics."""
        while self.is_running:
            try:
                # Update active subscriptions count
                stats = enhanced_websocket_manager.get_connection_stats()
                self.metrics.active_subscriptions = stats.get("active_connections", 0)
                
                # Calculate average latency (simplified)
                if self.metrics.total_events_sent > 0:
                    self.metrics.average_latency = 50.0  # Placeholder calculation
                
                await asyncio.sleep(30)  # Update every 30 seconds
                
            except Exception as e:
                logger.error("Error in metrics updater loop", error=str(e))
                await asyncio.sleep(30)
    
    async def _health_monitor_loop(self):
        """Background task to monitor broadcasting service health."""
        while self.is_running:
            try:
                # Check service health
                if self.metrics.failed_broadcasts > self.metrics.total_events_sent * 0.1:  # More than 10% failure rate
                    logger.warning("High broadcast failure rate detected", 
                                 failure_rate=self.metrics.failed_broadcasts / max(self.metrics.total_events_sent, 1))
                
                # Check queue size
                queue_size = self.event_queue.qsize()
                if queue_size > 100:
                    logger.warning("Broadcast queue size is high", queue_size=queue_size)
                
                await asyncio.sleep(60)  # Check every minute
                
            except Exception as e:
                logger.error("Error in health monitor loop", error=str(e))
                await asyncio.sleep(60)
    
    def get_metrics(self) -> BroadcastingMetrics:
        """Get comprehensive broadcasting metrics."""
        return self.metrics
    
    def get_health_status(self) -> Dict[str, Any]:
        """Get broadcasting service health status."""
        return {
            "is_running": self.is_running,
            "queue_size": self.event_queue.qsize(),
            "active_tasks": len(self.broadcast_tasks),
            "total_events_sent": self.metrics.total_events_sent,
            "failed_broadcasts": self.metrics.failed_broadcasts,
            "failure_rate": self.metrics.failed_broadcasts / max(self.metrics.total_events_sent, 1),
            "last_broadcast_time": self.metrics.last_broadcast_time.isoformat() if self.metrics.last_broadcast_time else None,
            "active_subscriptions": self.metrics.active_subscriptions
        }


# Global broadcasting service instance
real_time_broadcasting_service = RealTimeBroadcastingService()


# Convenience functions for easy integration
async def broadcast_production_update(line_id: str, production_data: Dict[str, Any]):
    """Convenience function to broadcast production updates."""
    await real_time_broadcasting_service.broadcast_production_update(line_id, production_data)


async def broadcast_oee_update(line_id: str, oee_data: Dict[str, Any]):
    """Convenience function to broadcast OEE updates."""
    await real_time_broadcasting_service.broadcast_oee_update(line_id, oee_data)


async def broadcast_andon_notification(andon_event: Dict[str, Any]):
    """Convenience function to broadcast Andon notifications."""
    await real_time_broadcasting_service.broadcast_andon_notification(andon_event)


async def broadcast_equipment_status(equipment_code: str, status_data: Dict[str, Any]):
    """Convenience function to broadcast equipment status."""
    await real_time_broadcasting_service.broadcast_equipment_status(equipment_code, status_data)


async def broadcast_job_update(job_data: Dict[str, Any]):
    """Convenience function to broadcast job updates."""
    await real_time_broadcasting_service.broadcast_job_update(job_data)


async def broadcast_downtime_event(downtime_data: Dict[str, Any]):
    """Convenience function to broadcast downtime events."""
    await real_time_broadcasting_service.broadcast_downtime_event(downtime_data)


async def broadcast_quality_alert(quality_data: Dict[str, Any]):
    """Convenience function to broadcast quality alerts."""
    await real_time_broadcasting_service.broadcast_quality_alert(quality_data)


async def broadcast_escalation_update(escalation_data: Dict[str, Any]):
    """Convenience function to broadcast escalation updates."""
    await real_time_broadcasting_service.broadcast_escalation_update(escalation_data)


async def broadcast_system_alert(alert_data: Dict[str, Any]):
    """Convenience function to broadcast system alerts."""
    await real_time_broadcasting_service.broadcast_system_alert(alert_data)
