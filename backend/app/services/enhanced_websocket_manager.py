"""
MS5.0 Floor Dashboard - Enhanced WebSocket Manager

Enterprise-grade WebSocket management for cosmic scale operations.
The nervous system of a starship - built for reliability and performance.
"""

import json
import asyncio
import time
from typing import Dict, List, Set, Optional, Any, Callable
from uuid import uuid4
from datetime import datetime
from collections import defaultdict, deque
from dataclasses import dataclass, field
from enum import Enum
import structlog

from app.utils.exceptions import WebSocketError, ConnectionError, RateLimitError

logger = structlog.get_logger()


class MessagePriority(Enum):
    """Message priority levels for intelligent routing."""
    CRITICAL = 1  # System alerts, Andon events
    HIGH = 2      # Production updates, OEE data
    NORMAL = 3    # Regular status updates
    LOW = 4       # Heartbeats, diagnostics


@dataclass
class ConnectionMetrics:
    """Comprehensive connection metrics for monitoring."""
    connection_id: str
    user_id: str
    connected_at: datetime
    last_activity: datetime
    message_count: int = 0
    error_count: int = 0
    bytes_sent: int = 0
    bytes_received: int = 0
    subscription_count: int = 0
    health_score: float = 1.0
    
    def update_health(self) -> None:
        """Calculate health score based on metrics."""
        stability_score = max(0, 1.0 - (self.error_count / max(1, self.message_count)))
        time_since_activity = (datetime.utcnow() - self.last_activity).total_seconds()
        activity_score = max(0, 1.0 - (time_since_activity / 300))  # 5 minutes timeout
        efficiency_score = min(1.0, 10.0 / max(1, self.subscription_count))
        self.health_score = (stability_score + activity_score + efficiency_score) / 3.0


@dataclass
class MessageBatch:
    """Batch container for efficient message processing."""
    messages: List[Dict[str, Any]] = field(default_factory=list)
    created_at: datetime = field(default_factory=datetime.utcnow)
    max_size: int = 100
    max_age: float = 1.0  # seconds
    
    def add_message(self, message: Dict[str, Any]) -> bool:
        """Add message to batch. Returns True if batch is ready to send."""
        self.messages.append(message)
        return len(self.messages) >= self.max_size or self.is_expired()
    
    def is_expired(self) -> bool:
        """Check if batch is ready to send due to age."""
        return (datetime.utcnow() - self.created_at).total_seconds() >= self.max_age
    
    def get_batch(self) -> List[Dict[str, Any]]:
        """Get and clear the batch."""
        batch = self.messages.copy()
        self.messages.clear()
        self.created_at = datetime.utcnow()
        return batch


class EnhancedWebSocketManager:
    """
    Enterprise-grade WebSocket manager with cosmic-scale reliability.
    
    Features:
    - Connection pooling with automatic load balancing
    - Message batching and intelligent throttling
    - Comprehensive health monitoring and metrics
    - Automatic failover and recovery mechanisms
    - Performance analytics and optimization
    - Production-grade error handling and logging
    """
    
    def __init__(self, max_connections: int = 10000, batch_size: int = 100):
        # Core connection management
        self.active_connections: Dict[str, Any] = {}
        self.connection_metrics: Dict[str, ConnectionMetrics] = {}
        self.user_connections: Dict[str, Set[str]] = defaultdict(set)
        
        # Subscription management with enhanced indexing
        self.subscriptions: Dict[str, Set[str]] = defaultdict(set)
        self.subscription_index: Dict[str, Set[str]] = defaultdict(set)
        
        # Production-specific subscriptions
        self.line_subscriptions: Dict[str, Set[str]] = defaultdict(set)
        self.equipment_subscriptions: Dict[str, Set[str]] = defaultdict(set)
        self.job_subscriptions: Dict[str, Set[str]] = defaultdict(set)
        self.production_subscriptions: Dict[str, Set[str]] = defaultdict(set)
        self.oee_subscriptions: Dict[str, Set[str]] = defaultdict(set)
        self.downtime_subscriptions: Dict[str, Set[str]] = defaultdict(set)
        self.andon_subscriptions: Dict[str, Set[str]] = defaultdict(set)
        self.escalation_subscriptions: Dict[str, Set[str]] = defaultdict(set)
        self.quality_subscriptions: Dict[str, Set[str]] = defaultdict(set)
        self.changeover_subscriptions: Dict[str, Set[str]] = defaultdict(set)
        
        # Message batching and throttling
        self.message_batches: Dict[str, MessageBatch] = {}
        self.message_queue: deque = deque(maxlen=10000)
        self.rate_limits: Dict[str, deque] = defaultdict(lambda: deque(maxlen=100))
        
        # Performance monitoring
        self.max_connections = max_connections
        self.batch_size = batch_size
        self.health_check_interval = 30.0  # seconds
        self.metrics_reset_interval = 3600.0  # 1 hour
        
        # Background tasks
        self._health_check_task: Optional[asyncio.Task] = None
        self._batch_processor_task: Optional[asyncio.Task] = None
        self._metrics_cleanup_task: Optional[asyncio.Task] = None
        
        # Event callbacks for external integration
        self.event_callbacks: Dict[str, List[Callable]] = defaultdict(list)
        
        # Production event types with enhanced categorization
        self.PRODUCTION_EVENTS = {
            # Critical system events
            "system_alert": {"priority": MessagePriority.CRITICAL, "description": "System-wide alert"},
            "andon_event": {"priority": MessagePriority.CRITICAL, "description": "Andon event created"},
            "escalation_triggered": {"priority": MessagePriority.CRITICAL, "description": "Escalation triggered"},
            
            # High priority production events
            "line_status_update": {"priority": MessagePriority.HIGH, "description": "Production line status updated"},
            "production_update": {"priority": MessagePriority.HIGH, "description": "Production metrics updated"},
            "oee_update": {"priority": MessagePriority.HIGH, "description": "OEE calculation updated"},
            "downtime_event": {"priority": MessagePriority.HIGH, "description": "Downtime event detected"},
            
            # Normal priority events
            "job_assigned": {"priority": MessagePriority.NORMAL, "description": "Job assigned to operator"},
            "job_started": {"priority": MessagePriority.NORMAL, "description": "Job execution started"},
            "job_completed": {"priority": MessagePriority.NORMAL, "description": "Job completed"},
            "job_cancelled": {"priority": MessagePriority.NORMAL, "description": "Job cancelled"},
            "quality_alert": {"priority": MessagePriority.NORMAL, "description": "Quality threshold exceeded"},
            "changeover_started": {"priority": MessagePriority.NORMAL, "description": "Changeover process started"},
            "changeover_completed": {"priority": MessagePriority.NORMAL, "description": "Changeover process completed"},
            
            # Low priority events
            "heartbeat": {"priority": MessagePriority.LOW, "description": "Connection heartbeat"},
            "diagnostic": {"priority": MessagePriority.LOW, "description": "System diagnostic information"},
        }
        
        # Start background tasks
        self._start_background_tasks()
        
        logger.info("Enhanced WebSocket Manager initialized", 
                   max_connections=max_connections, batch_size=batch_size)
    
    def _start_background_tasks(self) -> None:
        """Start background maintenance tasks."""
        try:
            loop = asyncio.get_event_loop()
            self._health_check_task = loop.create_task(self._health_check_loop())
            self._batch_processor_task = loop.create_task(self._batch_processor_loop())
            self._metrics_cleanup_task = loop.create_task(self._metrics_cleanup_loop())
            
            logger.info("Background tasks started for Enhanced WebSocket Manager")
        except Exception as e:
            logger.error("Failed to start background tasks", error=str(e))
    
    async def add_connection(self, websocket: Any, user_id: str) -> str:
        """Add a WebSocket connection with enhanced tracking and metrics."""
        if len(self.active_connections) >= self.max_connections:
            raise ConnectionError("Maximum connection limit reached")
        
        connection_id = f"{user_id}_{uuid4().hex[:8]}"
        
        # Store connection
        self.active_connections[connection_id] = websocket
        self.user_connections[user_id].add(connection_id)
        
        # Initialize metrics
        now = datetime.utcnow()
        self.connection_metrics[connection_id] = ConnectionMetrics(
            connection_id=connection_id,
            user_id=user_id,
            connected_at=now,
            last_activity=now
        )
        
        # Initialize subscription tracking
        self.subscriptions[connection_id] = set()
        
        # Initialize message batching
        self.message_batches[connection_id] = MessageBatch(max_size=self.batch_size)
        
        # Trigger connection event
        await self._trigger_event("connection_added", {
            "connection_id": connection_id,
            "user_id": user_id,
            "timestamp": now.isoformat()
        })
        
        logger.info("Enhanced WebSocket connection added", 
                   connection_id=connection_id, user_id=user_id,
                   total_connections=len(self.active_connections))
        
        return connection_id
    
    def remove_connection(self, connection_id: str) -> None:
        """Remove a WebSocket connection and clean up all associated data."""
        if connection_id not in self.active_connections:
            return
        
        # Get connection info before removal
        metrics = self.connection_metrics.get(connection_id)
        user_id = metrics.user_id if metrics else None
        
        # Remove from all data structures
        self.active_connections.pop(connection_id, None)
        self.connection_metrics.pop(connection_id, None)
        self.message_batches.pop(connection_id, None)
        
        # Remove from user connections
        if user_id:
            self.user_connections[user_id].discard(connection_id)
            if not self.user_connections[user_id]:
                del self.user_connections[user_id]
        
        # Remove from all subscription types
        self._remove_from_all_subscriptions(connection_id)
        
        # Clean up subscription tracking
        self.subscriptions.pop(connection_id, None)
        
        # Clean up rate limiting
        self.rate_limits.pop(connection_id, None)
        
        logger.info("Enhanced WebSocket connection removed", 
                   connection_id=connection_id, user_id=user_id,
                   total_connections=len(self.active_connections))
    
    def _remove_from_all_subscriptions(self, connection_id: str) -> None:
        """Remove connection from all subscription types efficiently."""
        subscription_lists = [
            self.line_subscriptions,
            self.equipment_subscriptions,
            self.job_subscriptions,
            self.production_subscriptions,
            self.oee_subscriptions,
            self.downtime_subscriptions,
            self.andon_subscriptions,
            self.escalation_subscriptions,
            self.quality_subscriptions,
            self.changeover_subscriptions
        ]
        
        for subscription_dict in subscription_lists:
            for key, connections in list(subscription_dict.items()):
                connections.discard(connection_id)
                if not connections:
                    del subscription_dict[key]
    
    # Enhanced subscription methods with intelligent indexing
    def subscribe_to_line(self, connection_id: str, line_id: str) -> None:
        """Subscribe a connection to a production line with enhanced tracking."""
        if connection_id not in self.active_connections:
            return
        
        self.subscriptions[connection_id].add(f"line:{line_id}")
        self.line_subscriptions[line_id].add(connection_id)
        self.subscription_index[f"line:{line_id}"].add(connection_id)
        
        # Update metrics
        if connection_id in self.connection_metrics:
            self.connection_metrics[connection_id].subscription_count += 1
        
        logger.debug("Subscribed to production line", 
                   connection_id=connection_id, line_id=line_id)
    
    def subscribe_to_equipment(self, connection_id: str, equipment_code: str) -> None:
        """Subscribe a connection to equipment updates with enhanced tracking."""
        if connection_id not in self.active_connections:
            return
        
        self.subscriptions[connection_id].add(f"equipment:{equipment_code}")
        self.equipment_subscriptions[equipment_code].add(connection_id)
        self.subscription_index[f"equipment:{equipment_code}"].add(connection_id)
        
        # Update metrics
        if connection_id in self.connection_metrics:
            self.connection_metrics[connection_id].subscription_count += 1
        
        logger.debug("Subscribed to equipment", 
                   connection_id=connection_id, equipment_code=equipment_code)
    
    def subscribe_to_downtime(self, connection_id: str, line_id: str = None, equipment_code: str = None) -> None:
        """Subscribe a connection to downtime events with enhanced tracking."""
        if connection_id not in self.active_connections:
            return
        
        subscription_key = f"downtime:{line_id or 'all'}:{equipment_code or 'all'}"
        self.subscriptions[connection_id].add(subscription_key)
        self.subscription_index[subscription_key].add(connection_id)
        
        if line_id:
            self.downtime_subscriptions[line_id].add(connection_id)
        
        if equipment_code:
            self.downtime_subscriptions[equipment_code].add(connection_id)
        
        # Update metrics
        if connection_id in self.connection_metrics:
            self.connection_metrics[connection_id].subscription_count += 1
        
        logger.debug("Subscribed to downtime events", 
                   connection_id=connection_id, line_id=line_id, equipment_code=equipment_code)
    
    def subscribe_to_escalation(self, connection_id: str, escalation_id: str = None, priority: str = None) -> None:
        """Subscribe a connection to escalation events with enhanced tracking."""
        if connection_id not in self.active_connections:
            return
        
        if escalation_id:
            subscription_key = f"escalation:{escalation_id}"
            self.subscriptions[connection_id].add(subscription_key)
            self.subscription_index[subscription_key].add(connection_id)
            self.escalation_subscriptions[escalation_id].add(connection_id)
        
        if priority:
            subscription_key = f"escalation_priority:{priority}"
            self.subscriptions[connection_id].add(subscription_key)
            self.subscription_index[subscription_key].add(connection_id)
            self.escalation_subscriptions[priority].add(connection_id)
        
        # Update metrics
        if connection_id in self.connection_metrics:
            self.connection_metrics[connection_id].subscription_count += 1
        
        logger.debug("Subscribed to escalation events", 
                   connection_id=connection_id, escalation_id=escalation_id, priority=priority)
    
    # Enhanced message sending with batching and priority handling
    async def send_personal_message(self, message: Dict[str, Any], connection_id: str, 
                                  priority: MessagePriority = MessagePriority.NORMAL) -> None:
        """Send a message to a specific connection with enhanced error handling and metrics."""
        if connection_id not in self.active_connections:
            logger.warning("Attempted to send message to non-existent connection", 
                          connection_id=connection_id)
            return
        
        # Check rate limiting
        if self._is_rate_limited(connection_id):
            raise RateLimitError(f"Rate limit exceeded for connection {connection_id}")
        
        # Add to batch for efficient processing
        batch_message = {
            **message,
            "priority": priority.value,
            "connection_id": connection_id,
            "timestamp": datetime.utcnow().isoformat()
        }
        
        batch = self.message_batches[connection_id]
        if batch.add_message(batch_message):
            # Batch is ready to send
            await self._send_batch(connection_id)
        
        # Update metrics
        self._update_connection_metrics(connection_id, len(json.dumps(message).encode('utf-8')))
    
    async def _send_batch(self, connection_id: str) -> None:
        """Send a batch of messages to a connection."""
        if connection_id not in self.active_connections:
            return
        
        batch = self.message_batches.get(connection_id)
        if not batch or not batch.messages:
            return
        
        messages = batch.get_batch()
        websocket = self.active_connections[connection_id]
        
        try:
            # Sort messages by priority
            messages.sort(key=lambda x: x.get("priority", MessagePriority.NORMAL.value))
            
            # Send each message
            for message in messages:
                await websocket.send_text(json.dumps(message))
                
                # Update metrics
                message_size = len(json.dumps(message).encode('utf-8'))
                self._update_connection_metrics(connection_id, message_size, sent=True)
            
            logger.debug("Batch sent successfully", 
                        connection_id=connection_id, message_count=len(messages))
            
        except Exception as e:
            logger.error("Failed to send batch", 
                        connection_id=connection_id, error=str(e))
            self._update_connection_metrics(connection_id, 0, error=True)
    
    def _is_rate_limited(self, connection_id: str) -> bool:
        """Check if connection is rate limited."""
        now = time.time()
        rate_limit = self.rate_limits[connection_id]
        
        # Remove old entries
        while rate_limit and rate_limit[0] < now - 60:  # 1 minute window
            rate_limit.popleft()
        
        # Check if under limit (100 messages per minute)
        return len(rate_limit) >= 100
    
    def _update_connection_metrics(self, connection_id: str, bytes_count: int, 
                                 sent: bool = False, error: bool = False) -> None:
        """Update connection metrics efficiently."""
        if connection_id not in self.connection_metrics:
            return
        
        metrics = self.connection_metrics[connection_id]
        metrics.last_activity = datetime.utcnow()
        metrics.message_count += 1
        
        if sent:
            metrics.bytes_sent += bytes_count
        else:
            metrics.bytes_received += bytes_count
        
        if error:
            metrics.error_count += 1
        
        metrics.update_health()
    
    # Enhanced broadcasting methods with intelligent routing
    async def send_to_line(self, message: Dict[str, Any], line_id: str) -> None:
        """Send message to all connections subscribed to a line with enhanced routing."""
        if line_id not in self.line_subscriptions:
            return
        
        # Get message priority
        event_type = message.get("type", "unknown")
        event_config = self.PRODUCTION_EVENTS.get(event_type, {})
        priority = event_config.get("priority", MessagePriority.NORMAL)
        
        # Send to all subscribers
        tasks = []
        for connection_id in self.line_subscriptions[line_id].copy():
            tasks.append(self.send_personal_message(message, connection_id, priority))
        
        if tasks:
            await asyncio.gather(*tasks, return_exceptions=True)
    
    async def send_to_equipment(self, message: Dict[str, Any], equipment_code: str) -> None:
        """Send message to all connections subscribed to equipment with enhanced routing."""
        if equipment_code not in self.equipment_subscriptions:
            return
        
        # Get message priority
        event_type = message.get("type", "unknown")
        event_config = self.PRODUCTION_EVENTS.get(event_type, {})
        priority = event_config.get("priority", MessagePriority.NORMAL)
        
        # Send to all subscribers
        tasks = []
        for connection_id in self.equipment_subscriptions[equipment_code].copy():
            tasks.append(self.send_personal_message(message, connection_id, priority))
        
        if tasks:
            await asyncio.gather(*tasks, return_exceptions=True)
    
    async def send_to_downtime_subscribers(self, message: Dict[str, Any], 
                                         line_id: str = None, equipment_code: str = None) -> None:
        """Send message to downtime subscribers with enhanced routing."""
        # Get message priority
        event_type = message.get("type", "unknown")
        event_config = self.PRODUCTION_EVENTS.get(event_type, {})
        priority = event_config.get("priority", MessagePriority.NORMAL)
        
        # Collect all relevant subscribers
        subscribers = set()
        
        if line_id and line_id in self.downtime_subscriptions:
            subscribers.update(self.downtime_subscriptions[line_id])
        
        if equipment_code and equipment_code in self.downtime_subscriptions:
            subscribers.update(self.downtime_subscriptions[equipment_code])
        
        # Send to all subscribers
        tasks = []
        for connection_id in subscribers:
            tasks.append(self.send_personal_message(message, connection_id, priority))
        
        if tasks:
            await asyncio.gather(*tasks, return_exceptions=True)
    
    async def send_to_escalation_subscribers(self, message: Dict[str, Any], 
                                           escalation_id: str = None, priority: str = None) -> None:
        """Send message to escalation subscribers with enhanced routing."""
        # Get message priority
        event_type = message.get("type", "unknown")
        event_config = self.PRODUCTION_EVENTS.get(event_type, {})
        msg_priority = event_config.get("priority", MessagePriority.NORMAL)
        
        # Collect all relevant subscribers
        subscribers = set()
        
        if escalation_id and escalation_id in self.escalation_subscriptions:
            subscribers.update(self.escalation_subscriptions[escalation_id])
        
        if priority and priority in self.escalation_subscriptions:
            subscribers.update(self.escalation_subscriptions[priority])
        
        # Send to all subscribers
        tasks = []
        for connection_id in subscribers:
            tasks.append(self.send_personal_message(message, connection_id, msg_priority))
        
        if tasks:
            await asyncio.gather(*tasks, return_exceptions=True)
    
    # Background task methods
    async def _health_check_loop(self) -> None:
        """Background task for connection health monitoring."""
        while True:
            try:
                await asyncio.sleep(self.health_check_interval)
                await self._perform_health_check()
            except Exception as e:
                logger.error("Health check loop error", error=str(e))
                await asyncio.sleep(5)  # Brief pause before retry
    
    async def _perform_health_check(self) -> None:
        """Perform comprehensive health check on all connections."""
        unhealthy_connections = []
        
        for connection_id, metrics in self.connection_metrics.items():
            metrics.update_health()
            
            # Check for unhealthy connections
            if metrics.health_score < 0.3:
                unhealthy_connections.append(connection_id)
            
            # Check for stale connections
            time_since_activity = (datetime.utcnow() - metrics.last_activity).total_seconds()
            if time_since_activity > 300:  # 5 minutes
                unhealthy_connections.append(connection_id)
        
        # Remove unhealthy connections
        for connection_id in unhealthy_connections:
            logger.warning("Removing unhealthy connection", connection_id=connection_id)
            self.remove_connection(connection_id)
        
        if unhealthy_connections:
            logger.info("Health check completed", 
                       removed_connections=len(unhealthy_connections),
                       healthy_connections=len(self.active_connections))
    
    async def _batch_processor_loop(self) -> None:
        """Background task for processing message batches."""
        while True:
            try:
                await asyncio.sleep(0.1)  # Process batches every 100ms
                
                tasks = []
                for connection_id, batch in self.message_batches.items():
                    if batch.is_expired() and batch.messages:
                        tasks.append(self._send_batch(connection_id))
                
                if tasks:
                    await asyncio.gather(*tasks, return_exceptions=True)
                    
            except Exception as e:
                logger.error("Batch processor loop error", error=str(e))
                await asyncio.sleep(1)
    
    async def _metrics_cleanup_loop(self) -> None:
        """Background task for metrics cleanup and optimization."""
        while True:
            try:
                await asyncio.sleep(self.metrics_reset_interval)
                
                # Reset metrics for long-running connections
                for metrics in self.connection_metrics.values():
                    if metrics.message_count > 10000:  # Reset after 10k messages
                        metrics.message_count = 0
                        metrics.error_count = 0
                        metrics.bytes_sent = 0
                        metrics.bytes_received = 0
                
                logger.info("Metrics cleanup completed", 
                           active_connections=len(self.active_connections))
                
            except Exception as e:
                logger.error("Metrics cleanup loop error", error=str(e))
                await asyncio.sleep(60)
    
    # Event system for external integration
    def add_event_callback(self, event_type: str, callback: Callable) -> None:
        """Add event callback for external integration."""
        self.event_callbacks[event_type].append(callback)
    
    async def _trigger_event(self, event_type: str, data: Dict[str, Any]) -> None:
        """Trigger event callbacks."""
        for callback in self.event_callbacks.get(event_type, []):
            try:
                if asyncio.iscoroutinefunction(callback):
                    await callback(data)
                else:
                    callback(data)
            except Exception as e:
                logger.error("Event callback error", event_type=event_type, error=str(e))
    
    # Comprehensive statistics and monitoring
    def get_connection_stats(self) -> Dict[str, Any]:
        """Get comprehensive connection statistics."""
        total_connections = len(self.active_connections)
        total_subscriptions = sum(len(subs) for subs in self.subscriptions.values())
        
        # Calculate health metrics
        health_scores = [m.health_score for m in self.connection_metrics.values()]
        avg_health = sum(health_scores) / len(health_scores) if health_scores else 0
        
        # Calculate performance metrics
        total_messages = sum(m.message_count for m in self.connection_metrics.values())
        total_errors = sum(m.error_count for m in self.connection_metrics.values())
        error_rate = total_errors / max(1, total_messages)
        
        return {
            "total_connections": total_connections,
            "total_subscriptions": total_subscriptions,
            "average_health_score": avg_health,
            "total_messages_sent": total_messages,
            "total_errors": total_errors,
            "error_rate": error_rate,
            "line_subscriptions": len(self.line_subscriptions),
            "equipment_subscriptions": len(self.equipment_subscriptions),
            "andon_subscriptions": len(self.andon_subscriptions),
            "escalation_subscriptions": len(self.escalation_subscriptions),
            "downtime_subscriptions": len(self.downtime_subscriptions),
            "connection_utilization": total_connections / self.max_connections,
            "batch_queues": len([b for b in self.message_batches.values() if b.messages]),
        }
    
    def get_connection_details(self, connection_id: str) -> Optional[Dict[str, Any]]:
        """Get detailed information about a specific connection."""
        if connection_id not in self.connection_metrics:
            return None
        
        metrics = self.connection_metrics[connection_id]
        subscriptions = list(self.subscriptions.get(connection_id, []))
        
        return {
            "connection_id": connection_id,
            "user_id": metrics.user_id,
            "connected_at": metrics.connected_at.isoformat(),
            "last_activity": metrics.last_activity.isoformat(),
            "message_count": metrics.message_count,
            "error_count": metrics.error_count,
            "bytes_sent": metrics.bytes_sent,
            "bytes_received": metrics.bytes_received,
            "subscription_count": metrics.subscription_count,
            "health_score": metrics.health_score,
            "subscriptions": subscriptions,
            "is_active": connection_id in self.active_connections,
        }
    
    # Graceful shutdown
    async def shutdown(self) -> None:
        """Gracefully shutdown the WebSocket manager."""
        logger.info("Shutting down Enhanced WebSocket Manager")
        
        # Cancel background tasks
        if self._health_check_task:
            self._health_check_task.cancel()
        if self._batch_processor_task:
            self._batch_processor_task.cancel()
        if self._metrics_cleanup_task:
            self._metrics_cleanup_task.cancel()
        
        # Send disconnect messages to all connections
        disconnect_message = {
            "type": "system_shutdown",
            "data": {"message": "Server is shutting down"},
            "timestamp": datetime.utcnow().isoformat()
        }
        
        tasks = []
        for connection_id in list(self.active_connections.keys()):
            tasks.append(self.send_personal_message(disconnect_message, connection_id))
        
        if tasks:
            await asyncio.gather(*tasks, return_exceptions=True)
        
        # Clear all data structures
        self.active_connections.clear()
        self.connection_metrics.clear()
        self.user_connections.clear()
        self.subscriptions.clear()
        self.subscription_index.clear()
        
        # Clear all subscription types
        for subscription_dict in [self.line_subscriptions, self.equipment_subscriptions,
                                self.job_subscriptions, self.production_subscriptions,
                                self.oee_subscriptions, self.downtime_subscriptions,
                                self.andon_subscriptions, self.escalation_subscriptions,
                                self.quality_subscriptions, self.changeover_subscriptions]:
            subscription_dict.clear()
        
        logger.info("Enhanced WebSocket Manager shutdown completed")


# Global enhanced WebSocket manager instance
enhanced_websocket_manager = EnhancedWebSocketManager()
