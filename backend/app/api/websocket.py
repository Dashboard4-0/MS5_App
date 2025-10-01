"""
MS5.0 Floor Dashboard - WebSocket Handler

Enterprise-grade WebSocket endpoints for cosmic scale operations.
The nervous system of a starship - built for reliability and performance.

This module provides comprehensive WebSocket endpoints for real-time updates
including production status, OEE data, Andon events, and equipment monitoring.
"""

import json
import asyncio
from typing import Dict, List, Set, Optional, Any
from uuid import UUID
from datetime import datetime, timezone

from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends, Query, HTTPException, status
from fastapi.websockets import WebSocketState
from fastapi.responses import JSONResponse
import structlog

from app.auth.jwt_handler import verify_access_token, JWTError
from app.utils.exceptions import AuthenticationError, WebSocketError, ValidationError
from app.services.enhanced_websocket_manager import enhanced_websocket_manager
from app.services.websocket_manager import websocket_manager

logger = structlog.get_logger()

router = APIRouter()

# WebSocket event types for production operations
class WebSocketEventType:
    """Production WebSocket event types for real-time operations."""
    
    # Production events
    PRODUCTION_UPDATE = "production_update"
    PRODUCTION_LINE_UPDATED = "production_line_updated"
    PRODUCTION_SCHEDULE_UPDATED = "production_schedule_updated"
    PRODUCTION_METRICS_UPDATED = "production_metrics_updated"
    
    # Equipment events
    EQUIPMENT_STATUS_UPDATE = "equipment_status_update"
    EQUIPMENT_STATUS_CHANGE = "equipment_status_change"
    EQUIPMENT_FAULT_OCCURRED = "equipment_fault_occurred"
    EQUIPMENT_FAULT_RESOLVED = "equipment_fault_resolved"
    MAINTENANCE_SCHEDULE_UPDATED = "maintenance_schedule_updated"
    
    # Job events
    JOB_ASSIGNMENT_UPDATED = "job_assignment_updated"
    JOB_STARTED = "job_started"
    JOB_COMPLETED = "job_completed"
    JOB_CANCELLED = "job_cancelled"
    
    # OEE events
    OEE_UPDATE = "oee_update"
    OEE_DATA_UPDATED = "oee_data_updated"
    
    # Downtime events
    DOWNTIME_EVENT = "downtime_event"
    DOWNTIME_STATISTICS_UPDATE = "downtime_statistics_update"
    
    # Andon events
    ANDON_EVENT = "andon_event"
    ANDON_ALERT = "andon_alert"
    ANDON_EVENT_CREATED = "andon_event_created"
    ANDON_EVENT_UPDATED = "andon_event_updated"
    ANDON_EVENT_RESOLVED = "andon_event_resolved"
    ANDON_ESCALATION_TRIGGERED = "andon_escalation_triggered"
    
    # Escalation events
    ESCALATION_EVENT = "escalation_event"
    ESCALATION_STATUS_UPDATE = "escalation_status_update"
    ESCALATION_REMINDER = "escalation_reminder"
    
    # Quality events
    QUALITY_UPDATE = "quality_update"
    QUALITY_CHECK_COMPLETED = "quality_check_completed"
    QUALITY_INSPECTION_COMPLETED = "quality_inspection_completed"
    QUALITY_DEFECT_REPORTED = "quality_defect_reported"
    QUALITY_ALERT_TRIGGERED = "quality_alert_triggered"
    
    # Changeover events
    CHANGEOVER_UPDATE = "changeover_update"
    CHANGEOVER_STARTED = "changeover_started"
    CHANGEOVER_COMPLETED = "changeover_completed"
    
    # Dashboard events
    DASHBOARD_DATA_UPDATED = "dashboard_data_updated"
    REAL_TIME_METRICS_UPDATED = "real_time_metrics_updated"
    
    # System events
    SYSTEM_ALERT = "system_alert"
    HEARTBEAT = "heartbeat"
    PONG = "pong"
    ERROR = "error"
    SUBSCRIPTION_CONFIRMED = "subscription_confirmed"
    UNSUBSCRIPTION_CONFIRMED = "unsubscription_confirmed"

# Global connection manager - using enhanced version for production operations


async def authenticate_websocket(websocket: WebSocket, token: str) -> Optional[str]:
    """
    Authenticate WebSocket connection using JWT token.
    
    This function provides enterprise-grade authentication for WebSocket connections
    with comprehensive error handling and security validation.
    
    Args:
        websocket: The WebSocket connection to authenticate
        token: JWT authentication token
        
    Returns:
        user_id if authentication successful, None otherwise
        
    Raises:
        WebSocketError: For authentication failures
    """
    try:
        # Verify the JWT token
        payload = verify_access_token(token)
        user_id = payload.get("user_id")
        
        if not user_id:
            logger.warning("WebSocket authentication failed: missing user_id in token")
            await websocket.close(code=1008, reason="Invalid token: missing user_id")
            return None
        
        # Validate user permissions for WebSocket access
        user_role = payload.get("role", "viewer")
        if user_role not in ["admin", "production_manager", "shift_manager", "engineer", "operator", "maintenance", "quality", "viewer"]:
            logger.warning("WebSocket authentication failed: invalid user role", user_role=user_role)
            await websocket.close(code=1008, reason="Invalid token: insufficient permissions")
            return None
        
        logger.info("WebSocket authentication successful", user_id=user_id, role=user_role)
        return user_id
        
    except JWTError as e:
        logger.warning("WebSocket authentication failed: JWT error", error=str(e))
        await websocket.close(code=1008, reason="Invalid token")
        return None
    except Exception as e:
        logger.error("WebSocket authentication failed: unexpected error", error=str(e))
        await websocket.close(code=1011, reason="Authentication error")
        return None


@router.websocket("/")
async def websocket_endpoint(
    websocket: WebSocket,
    token: str = Query(..., description="JWT authentication token")
):
    """
    Main WebSocket endpoint for real-time production updates.
    
    This endpoint provides comprehensive real-time communication for:
    - Production line status updates
    - Equipment monitoring and alerts
    - OEE calculations and metrics
    - Andon events and escalations
    - Quality alerts and inspections
    - Job assignments and progress
    
    The connection uses enhanced WebSocket management with:
    - Automatic reconnection handling
    - Message queuing and batching
    - Connection health monitoring
    - Performance metrics tracking
    
    Args:
        websocket: The WebSocket connection
        token: JWT authentication token for user validation
        
    Raises:
        WebSocketDisconnect: When connection is closed
        WebSocketError: For connection or message handling errors
    """
    # Accept the WebSocket connection
    await websocket.accept()
    
    # Authenticate the user
    user_id = await authenticate_websocket(websocket, token)
    if not user_id:
        return
    
    # Add connection to enhanced manager
    connection_id = await enhanced_websocket_manager.add_connection(websocket, user_id)
    
    try:
        logger.info("WebSocket connection established", 
                   connection_id=connection_id, 
                   user_id=user_id)
        
        # Send initial connection confirmation
        await enhanced_websocket_manager.send_personal_message({
            "type": WebSocketEventType.SYSTEM_ALERT,
            "data": {
                "message": "WebSocket connection established",
                "connection_id": connection_id,
                "timestamp": datetime.now(timezone.utc).isoformat()
            },
            "timestamp": datetime.now(timezone.utc).isoformat()
        }, connection_id)
        
        # Main message handling loop
        while True:
            try:
                # Wait for messages from client with timeout
                data = await asyncio.wait_for(websocket.receive_text(), timeout=300.0)
                
                try:
                    message = json.loads(data)
                    await handle_websocket_message(connection_id, message)
                except json.JSONDecodeError as e:
                    logger.warning("Invalid JSON message received", 
                                 connection_id=connection_id, 
                                 error=str(e))
                    await enhanced_websocket_manager.send_personal_message({
                        "type": WebSocketEventType.ERROR,
                        "data": {
                            "message": "Invalid JSON message format",
                            "error": str(e)
                        },
                        "timestamp": datetime.now(timezone.utc).isoformat()
                    }, connection_id)
                except ValidationError as e:
                    logger.warning("Message validation failed", 
                                 connection_id=connection_id, 
                                 error=str(e))
                    await enhanced_websocket_manager.send_personal_message({
                        "type": WebSocketEventType.ERROR,
                        "data": {
                            "message": "Message validation failed",
                            "error": str(e)
                        },
                        "timestamp": datetime.now(timezone.utc).isoformat()
                    }, connection_id)
                except Exception as e:
                    logger.error("Error handling WebSocket message", 
                               error=str(e), 
                               connection_id=connection_id)
                    await enhanced_websocket_manager.send_personal_message({
                        "type": WebSocketEventType.ERROR,
                        "data": {
                            "message": "Error processing message",
                            "error": str(e)
                        },
                        "timestamp": datetime.now(timezone.utc).isoformat()
                    }, connection_id)
                    
            except asyncio.TimeoutError:
                # Send heartbeat to check connection health
                await enhanced_websocket_manager.send_personal_message({
                    "type": WebSocketEventType.HEARTBEAT,
                    "data": {
                        "timestamp": datetime.now(timezone.utc).isoformat(),
                        "connection_id": connection_id
                    },
                    "timestamp": datetime.now(timezone.utc).isoformat()
                }, connection_id)
                
    except WebSocketDisconnect:
        logger.info("WebSocket connection closed by client", connection_id=connection_id)
        enhanced_websocket_manager.remove_connection(connection_id)
    except Exception as e:
        logger.error("WebSocket connection error", 
                   error=str(e), 
                   connection_id=connection_id)
        enhanced_websocket_manager.remove_connection(connection_id)


async def handle_websocket_message(connection_id: str, message: dict):
    """
    Handle incoming WebSocket messages with comprehensive production event support.
    
    This function processes various message types including:
    - Subscription/unsubscription requests
    - Heartbeat/ping messages
    - Production data requests
    - Equipment status queries
    - Andon event acknowledgments
    
    Args:
        connection_id: Unique identifier for the WebSocket connection
        message: The incoming message dictionary
        
    Raises:
        ValidationError: For invalid message format or content
        WebSocketError: For message processing errors
    """
    message_type = message.get("type")
    
    if not message_type:
        raise ValidationError("Message type is required")
    
    logger.debug("Processing WebSocket message", 
                connection_id=connection_id, 
                message_type=message_type)
    
    try:
        if message_type == "subscribe":
            await handle_subscribe_message(connection_id, message)
        elif message_type == "unsubscribe":
            await handle_unsubscribe_message(connection_id, message)
        elif message_type == "ping":
            await handle_ping_message(connection_id)
        elif message_type == "heartbeat":
            await handle_heartbeat_message(connection_id, message)
        elif message_type == "request_data":
            await handle_data_request_message(connection_id, message)
        elif message_type == "acknowledge":
            await handle_acknowledge_message(connection_id, message)
        else:
            logger.warning("Unknown message type received", 
                          connection_id=connection_id, 
                          message_type=message_type)
            await enhanced_websocket_manager.send_personal_message({
                "type": WebSocketEventType.ERROR,
                "data": {
                    "message": f"Unknown message type: {message_type}",
                    "supported_types": [
                        "subscribe", "unsubscribe", "ping", "heartbeat", 
                        "request_data", "acknowledge"
                    ]
                },
                "timestamp": datetime.now(timezone.utc).isoformat()
            }, connection_id)
            
    except Exception as e:
        logger.error("Error processing WebSocket message", 
                   connection_id=connection_id, 
                   message_type=message_type, 
                   error=str(e))
        await enhanced_websocket_manager.send_personal_message({
            "type": WebSocketEventType.ERROR,
            "data": {
                "message": "Error processing message",
                "error": str(e)
            },
            "timestamp": datetime.now(timezone.utc).isoformat()
        }, connection_id)


async def handle_subscribe_message(connection_id: str, message: dict):
    """
    Handle subscription requests with comprehensive production event support.
    
    Supports subscription to:
    - Production lines and equipment
    - OEE calculations and metrics
    - Downtime events and statistics
    - Andon events and escalations
    - Quality alerts and inspections
    - Job assignments and progress
    
    Args:
        connection_id: Unique identifier for the WebSocket connection
        message: The subscription request message
        
    Raises:
        ValidationError: For invalid subscription parameters
    """
    subscription_type = message.get("subscription_type")
    target_id = message.get("target_id")
    filters = message.get("filters", {})
    
    if not subscription_type:
        raise ValidationError("subscription_type is required")
    
    logger.info("Processing subscription request", 
               connection_id=connection_id, 
               subscription_type=subscription_type, 
               target_id=target_id)
    
    try:
        # Production line subscriptions
        if subscription_type == "line":
            if not target_id:
                raise ValidationError("target_id is required for line subscriptions")
            enhanced_websocket_manager.subscribe_to_line(connection_id, target_id)
            await enhanced_websocket_manager.send_personal_message({
                "type": WebSocketEventType.SUBSCRIPTION_CONFIRMED,
                "data": {
                    "subscription_type": "line",
                    "target_id": target_id,
                    "filters": filters
                },
                "timestamp": datetime.now(timezone.utc).isoformat()
            }, connection_id)
        
        # Equipment subscriptions
        elif subscription_type == "equipment":
            if not target_id:
                raise ValidationError("target_id is required for equipment subscriptions")
            enhanced_websocket_manager.subscribe_to_equipment(connection_id, target_id)
            await enhanced_websocket_manager.send_personal_message({
                "type": WebSocketEventType.SUBSCRIPTION_CONFIRMED,
                "data": {
                    "subscription_type": "equipment",
                    "target_id": target_id,
                    "filters": filters
                },
                "timestamp": datetime.now(timezone.utc).isoformat()
            }, connection_id)
        
        # Job subscriptions
        elif subscription_type == "job":
            if not target_id:
                raise ValidationError("target_id is required for job subscriptions")
            enhanced_websocket_manager.subscribe_to_job(connection_id, target_id)
            await enhanced_websocket_manager.send_personal_message({
                "type": WebSocketEventType.SUBSCRIPTION_CONFIRMED,
                "data": {
                    "subscription_type": "job",
                    "target_id": target_id,
                    "filters": filters
                },
                "timestamp": datetime.now(timezone.utc).isoformat()
            }, connection_id)
        
        # Production subscriptions
        elif subscription_type == "production":
            enhanced_websocket_manager.subscribe_to_production(connection_id, target_id)
            await enhanced_websocket_manager.send_personal_message({
                "type": WebSocketEventType.SUBSCRIPTION_CONFIRMED,
                "data": {
                    "subscription_type": "production",
                    "target_id": target_id,
                    "filters": filters
                },
                "timestamp": datetime.now(timezone.utc).isoformat()
            }, connection_id)
        
        # OEE subscriptions
        elif subscription_type == "oee":
            enhanced_websocket_manager.subscribe_to_oee(connection_id, target_id)
            await enhanced_websocket_manager.send_personal_message({
                "type": WebSocketEventType.SUBSCRIPTION_CONFIRMED,
                "data": {
                    "subscription_type": "oee",
                    "target_id": target_id,
                    "filters": filters
                },
                "timestamp": datetime.now(timezone.utc).isoformat()
            }, connection_id)
        
        # Downtime subscriptions
        elif subscription_type == "downtime":
            if target_id == "all":
                enhanced_websocket_manager.subscribe_to_downtime(connection_id)
            elif target_id and target_id.startswith("line:"):
                line_id = target_id[5:]  # Remove "line:" prefix
                enhanced_websocket_manager.subscribe_to_downtime(connection_id, line_id=line_id)
            elif target_id and target_id.startswith("equipment:"):
                equipment_code = target_id[10:]  # Remove "equipment:" prefix
                enhanced_websocket_manager.subscribe_to_downtime(connection_id, equipment_code=equipment_code)
            else:
                # Assume it's a line_id if no prefix
                enhanced_websocket_manager.subscribe_to_downtime(connection_id, line_id=target_id)
            
            await enhanced_websocket_manager.send_personal_message({
                "type": WebSocketEventType.SUBSCRIPTION_CONFIRMED,
                "data": {
                    "subscription_type": "downtime",
                    "target_id": target_id,
                    "filters": filters
                },
                "timestamp": datetime.now(timezone.utc).isoformat()
            }, connection_id)
        
        # Andon subscriptions
        elif subscription_type == "andon":
            enhanced_websocket_manager.subscribe_to_andon(connection_id, target_id)
            await enhanced_websocket_manager.send_personal_message({
                "type": WebSocketEventType.SUBSCRIPTION_CONFIRMED,
                "data": {
                    "subscription_type": "andon",
                    "target_id": target_id,
                    "filters": filters
                },
                "timestamp": datetime.now(timezone.utc).isoformat()
            }, connection_id)
        
        # Escalation subscriptions
        elif subscription_type == "escalation":
            if target_id == "all":
                enhanced_websocket_manager.subscribe_to_escalation(connection_id)
            elif target_id and target_id.startswith("escalation:"):
                escalation_id = target_id[11:]  # Remove "escalation:" prefix
                enhanced_websocket_manager.subscribe_to_escalation(connection_id, escalation_id=escalation_id)
            elif target_id and target_id.startswith("priority:"):
                priority = target_id[9:]  # Remove "priority:" prefix
                enhanced_websocket_manager.subscribe_to_escalation(connection_id, priority=priority)
            else:
                # Assume it's a priority if no prefix
                enhanced_websocket_manager.subscribe_to_escalation(connection_id, priority=target_id)
            
            await enhanced_websocket_manager.send_personal_message({
                "type": WebSocketEventType.SUBSCRIPTION_CONFIRMED,
                "data": {
                    "subscription_type": "escalation",
                    "target_id": target_id,
                    "filters": filters
                },
                "timestamp": datetime.now(timezone.utc).isoformat()
            }, connection_id)
        
        # Quality subscriptions
        elif subscription_type == "quality":
            enhanced_websocket_manager.subscribe_to_quality(connection_id, target_id)
            await enhanced_websocket_manager.send_personal_message({
                "type": WebSocketEventType.SUBSCRIPTION_CONFIRMED,
                "data": {
                    "subscription_type": "quality",
                    "target_id": target_id,
                    "filters": filters
                },
                "timestamp": datetime.now(timezone.utc).isoformat()
            }, connection_id)
        
        # Changeover subscriptions
        elif subscription_type == "changeover":
            enhanced_websocket_manager.subscribe_to_changeover(connection_id, target_id)
            await enhanced_websocket_manager.send_personal_message({
                "type": WebSocketEventType.SUBSCRIPTION_CONFIRMED,
                "data": {
                    "subscription_type": "changeover",
                    "target_id": target_id,
                    "filters": filters
                },
                "timestamp": datetime.now(timezone.utc).isoformat()
            }, connection_id)
        
        else:
            raise ValidationError(f"Unknown subscription type: {subscription_type}")
            
    except ValidationError as e:
        logger.warning("Subscription validation failed", 
                      connection_id=connection_id, 
                      subscription_type=subscription_type, 
                      error=str(e))
        await enhanced_websocket_manager.send_personal_message({
            "type": WebSocketEventType.ERROR,
            "data": {
                "message": f"Subscription validation failed: {str(e)}",
                "subscription_type": subscription_type,
                "target_id": target_id
            },
            "timestamp": datetime.now(timezone.utc).isoformat()
        }, connection_id)


async def handle_unsubscribe_message(connection_id: str, message: dict):
    """Handle unsubscription requests."""
    subscription_type = message.get("subscription_type")
    target_id = message.get("target_id")
    
    if not subscription_type or not target_id:
        await websocket_manager.send_personal_message({
            "type": "error",
            "message": "Missing subscription_type or target_id"
        }, connection_id)
        return
    
    if subscription_type == "line":
        websocket_manager.unsubscribe_from_line(connection_id, target_id)
        await websocket_manager.send_personal_message({
            "type": "unsubscription_confirmed",
            "subscription_type": "line",
            "target_id": target_id
        }, connection_id)
    
    elif subscription_type == "equipment":
        websocket_manager.unsubscribe_from_equipment(connection_id, target_id)
        await websocket_manager.send_personal_message({
            "type": "unsubscription_confirmed",
            "subscription_type": "equipment",
            "target_id": target_id
        }, connection_id)
    
    elif subscription_type == "downtime":
        # For downtime unsubscriptions, target_id can be "all", line_id, or equipment_code
        if target_id == "all":
            websocket_manager.unsubscribe_from_downtime(connection_id)
        elif target_id.startswith("line:"):
            line_id = target_id[5:]  # Remove "line:" prefix
            websocket_manager.unsubscribe_from_downtime(connection_id, line_id=line_id)
        elif target_id.startswith("equipment:"):
            equipment_code = target_id[10:]  # Remove "equipment:" prefix
            websocket_manager.unsubscribe_from_downtime(connection_id, equipment_code=equipment_code)
        else:
            # Assume it's a line_id if no prefix
            websocket_manager.unsubscribe_from_downtime(connection_id, line_id=target_id)
        
        await websocket_manager.send_personal_message({
            "type": "unsubscription_confirmed",
            "subscription_type": "downtime",
            "target_id": target_id
        }, connection_id)
    
    elif subscription_type == "escalation":
        # For escalation unsubscriptions, target_id can be "all", escalation_id, or priority
        if target_id == "all":
            websocket_manager.unsubscribe_from_escalation(connection_id)
        elif target_id.startswith("escalation:"):
            escalation_id = target_id[11:]  # Remove "escalation:" prefix
            websocket_manager.unsubscribe_from_escalation(connection_id, escalation_id=escalation_id)
        elif target_id.startswith("priority:"):
            priority = target_id[9:]  # Remove "priority:" prefix
            websocket_manager.unsubscribe_from_escalation(connection_id, priority=priority)
        else:
            # Assume it's a priority if no prefix
            websocket_manager.unsubscribe_from_escalation(connection_id, priority=target_id)
        
        await websocket_manager.send_personal_message({
            "type": "unsubscription_confirmed",
            "subscription_type": "escalation",
            "target_id": target_id
        }, connection_id)
    
    else:
        await websocket_manager.send_personal_message({
            "type": "error",
            "message": f"Unknown subscription type: {subscription_type}"
        }, connection_id)


async def handle_ping_message(connection_id: str):
    """Handle ping messages for connection health checks."""
    await websocket_manager.send_personal_message({
        "type": "pong",
        "timestamp": "2025-01-20T10:00:00Z"
    }, connection_id)


# Event broadcasting functions
async def broadcast_line_status_update(line_id: str, status_data: dict):
    """Broadcast line status update to all subscribers."""
    message = {
        "type": "line_status_update",
        "line_id": line_id,
        "data": status_data,
        "timestamp": "2025-01-20T10:00:00Z"
    }
    await websocket_manager.send_to_line(message, line_id)


async def broadcast_equipment_status_update(equipment_code: str, status_data: dict):
    """Broadcast equipment status update to all subscribers."""
    message = {
        "type": "equipment_status_update",
        "equipment_code": equipment_code,
        "data": status_data,
        "timestamp": "2025-01-20T10:00:00Z"
    }
    await websocket_manager.send_to_equipment(message, equipment_code)


async def broadcast_andon_event(andon_event: dict):
    """Broadcast Andon event to relevant subscribers."""
    message = {
        "type": "andon_event",
        "data": andon_event,
        "timestamp": "2025-01-20T10:00:00Z"
    }
    
    # Send to line subscribers
    line_id = andon_event.get("line_id")
    if line_id:
        await websocket_manager.send_to_line(message, line_id)
    
    # Send to equipment subscribers
    equipment_code = andon_event.get("equipment_code")
    if equipment_code:
        await websocket_manager.send_to_equipment(message, equipment_code)


async def broadcast_oee_update(line_id: str, oee_data: dict):
    """Broadcast OEE update to line subscribers."""
    message = {
        "type": "oee_update",
        "line_id": line_id,
        "data": oee_data,
        "timestamp": "2025-01-20T10:00:00Z"
    }
    await websocket_manager.send_to_line(message, line_id)


async def broadcast_downtime_event(downtime_event: dict):
    """Broadcast downtime event to relevant subscribers."""
    from datetime import datetime
    
    message = {
        "type": "downtime_event",
        "data": downtime_event,
        "timestamp": datetime.utcnow().isoformat() + "Z"
    }
    
    # Send to downtime-specific subscribers
    line_id = downtime_event.get("line_id")
    equipment_code = downtime_event.get("equipment_code")
    
    await websocket_manager.send_to_downtime_subscribers(message, line_id, equipment_code)
    
    # Also send to general line and equipment subscribers for backward compatibility
    if line_id:
        await websocket_manager.send_to_line(message, line_id)
    
    if equipment_code:
        await websocket_manager.send_to_equipment(message, equipment_code)


async def broadcast_downtime_statistics_update(statistics_data: dict, line_id: str = None, equipment_code: str = None):
    """Broadcast downtime statistics update to relevant subscribers."""
    from datetime import datetime
    
    message = {
        "type": "downtime_statistics_update",
        "data": statistics_data,
        "timestamp": datetime.utcnow().isoformat() + "Z"
    }
    
    # Send to downtime-specific subscribers
    await websocket_manager.send_to_downtime_subscribers(message, line_id, equipment_code)
    
    # Also send to general line and equipment subscribers for backward compatibility
    if line_id:
        await websocket_manager.send_to_line(message, line_id)
    
    if equipment_code:
        await websocket_manager.send_to_equipment(message, equipment_code)


async def broadcast_job_update(job_data: dict):
    """Broadcast job assignment update to relevant subscribers."""
    message = {
        "type": "job_update",
        "data": job_data,
        "timestamp": "2025-01-20T10:00:00Z"
    }
    
    # Send to line subscribers
    line_id = job_data.get("line_id")
    if line_id:
        await websocket_manager.send_to_line(message, line_id)
    
    # Send to user if they have an active connection
    user_id = job_data.get("user_id")
    if user_id:
        # Find connection for user
        for connection_id, websocket in websocket_manager.connections.items():
            if connection_id.startswith(user_id):
                await websocket_manager.send_personal_message(message, connection_id)
                break


async def broadcast_system_alert(alert_data: dict):
    """Broadcast system-wide alert to all connections."""
    message = {
        "type": "system_alert",
        "data": alert_data,
        "timestamp": "2025-01-20T10:00:00Z"
    }
    await websocket_manager.broadcast(message)


async def broadcast_escalation_event(escalation_data: dict):
    """Broadcast escalation event to relevant subscribers."""
    from datetime import datetime
    
    message = {
        "type": "escalation_event",
        "data": escalation_data,
        "timestamp": datetime.utcnow().isoformat() + "Z"
    }
    
    # Send to escalation-specific subscribers
    escalation_id = escalation_data.get("escalation_id")
    priority = escalation_data.get("priority")
    
    await websocket_manager.send_to_escalation_subscribers(message, escalation_id, priority)
    
    # Also send to line subscribers for context
    line_id = escalation_data.get("line_id")
    if line_id:
        await websocket_manager.send_to_line(message, line_id)


async def broadcast_escalation_status_update(escalation_id: str, status_data: dict):
    """Broadcast escalation status update to subscribers."""
    from datetime import datetime
    
    message = {
        "type": "escalation_status_update",
        "escalation_id": escalation_id,
        "data": status_data,
        "timestamp": datetime.utcnow().isoformat() + "Z"
    }
    
    await websocket_manager.send_to_escalation_subscribers(message, escalation_id)


async def broadcast_escalation_reminder(reminder_data: dict):
    """Broadcast escalation reminder to relevant subscribers."""
    from datetime import datetime
    
    message = {
        "type": "escalation_reminder",
        "data": reminder_data,
        "timestamp": datetime.utcnow().isoformat() + "Z"
    }
    
    # Send to escalation-specific subscribers
    escalation_id = reminder_data.get("escalation_id")
    priority = reminder_data.get("priority")
    
    await websocket_manager.send_to_escalation_subscribers(message, escalation_id, priority)
    
    # Also send to line subscribers for context
    line_id = reminder_data.get("line_id")
    if line_id:
        await websocket_manager.send_to_line(message, line_id)


# Additional broadcasting functions for enhanced real-time features
async def broadcast_equipment_status_change(equipment_code: str, status_data: dict):
    """Broadcast equipment status change to subscribers."""
    message = {
        "type": "equipment_status_change",
        "equipment_code": equipment_code,
        "data": status_data,
        "timestamp": "2025-01-20T10:00:00Z"
    }
    await websocket_manager.send_to_equipment(message, equipment_code)


async def broadcast_andon_alert(andon_alert: dict):
    """Broadcast Andon alert to relevant subscribers."""
    message = {
        "type": "andon_alert",
        "data": andon_alert,
        "timestamp": "2025-01-20T10:00:00Z"
    }
    
    # Send to line subscribers
    line_id = andon_alert.get("line_id")
    if line_id:
        await websocket_manager.send_to_line(message, line_id)
    
    # Send to equipment subscribers
    equipment_code = andon_alert.get("equipment_code")
    if equipment_code:
        await websocket_manager.send_to_equipment(message, equipment_code)


async def broadcast_quality_update(quality_data: dict):
    """Broadcast quality update to relevant subscribers."""
    message = {
        "type": "quality_update",
        "data": quality_data,
        "timestamp": "2025-01-20T10:00:00Z"
    }
    
    # Send to line subscribers
    line_id = quality_data.get("line_id")
    if line_id:
        await websocket_manager.send_to_line(message, line_id)


async def broadcast_changeover_update(changeover_data: dict):
    """Broadcast changeover update to relevant subscribers."""
    message = {
        "type": "changeover_update",
        "data": changeover_data,
        "timestamp": "2025-01-20T10:00:00Z"
    }
    
    # Send to line subscribers
    line_id = changeover_data.get("line_id")
    if line_id:
        await websocket_manager.send_to_line(message, line_id)


async def handle_heartbeat_message(connection_id: str, message: dict):
    """
    Handle heartbeat messages for connection health monitoring.
    
    Args:
        connection_id: Unique identifier for the WebSocket connection
        message: The heartbeat message
    """
    logger.debug("Received heartbeat", connection_id=connection_id)
    
    await enhanced_websocket_manager.send_personal_message({
        "type": WebSocketEventType.PONG,
        "data": {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "connection_id": connection_id,
            "server_time": datetime.now(timezone.utc).isoformat()
        },
        "timestamp": datetime.now(timezone.utc).isoformat()
    }, connection_id)


async def handle_data_request_message(connection_id: str, message: dict):
    """
    Handle data request messages for on-demand data retrieval.
    
    Args:
        connection_id: Unique identifier for the WebSocket connection
        message: The data request message
    """
    data_type = message.get("data_type")
    filters = message.get("filters", {})
    
    if not data_type:
        await enhanced_websocket_manager.send_personal_message({
            "type": WebSocketEventType.ERROR,
            "data": {
                "message": "data_type is required for data requests"
            },
            "timestamp": datetime.now(timezone.utc).isoformat()
        }, connection_id)
        return
    
    logger.info("Processing data request", 
               connection_id=connection_id, 
               data_type=data_type, 
               filters=filters)
    
    # TODO: Implement data retrieval based on data_type and filters
    # This would integrate with the appropriate service layer
    await enhanced_websocket_manager.send_personal_message({
        "type": f"{data_type}_data",
        "data": {
            "message": f"Data request for {data_type} received",
            "filters": filters,
            "status": "processing"
        },
        "timestamp": datetime.now(timezone.utc).isoformat()
    }, connection_id)


async def handle_acknowledge_message(connection_id: str, message: dict):
    """
    Handle acknowledgment messages for event confirmation.
    
    Args:
        connection_id: Unique identifier for the WebSocket connection
        message: The acknowledgment message
    """
    event_id = message.get("event_id")
    event_type = message.get("event_type")
    
    logger.debug("Received acknowledgment", 
                connection_id=connection_id, 
                event_id=event_id, 
                event_type=event_type)
    
    # Update event status in the system
    # TODO: Implement event acknowledgment tracking


# Health check endpoint
@router.get("/health")
async def websocket_health():
    """
    WebSocket health check endpoint with comprehensive metrics.
    
    Returns:
        JSON response with WebSocket service health and statistics
    """
    try:
        # Get enhanced manager statistics
        enhanced_stats = enhanced_websocket_manager.get_connection_stats()
        
        # Get basic manager statistics for comparison
        basic_stats = websocket_manager.get_connection_stats()
        
        return JSONResponse({
            "status": "healthy",
            "service": "websocket",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "enhanced_manager": enhanced_stats,
            "basic_manager": basic_stats,
            "event_types": {
                "production": [
                    WebSocketEventType.PRODUCTION_UPDATE,
                    WebSocketEventType.PRODUCTION_LINE_UPDATED,
                    WebSocketEventType.PRODUCTION_SCHEDULE_UPDATED,
                    WebSocketEventType.PRODUCTION_METRICS_UPDATED
                ],
                "equipment": [
                    WebSocketEventType.EQUIPMENT_STATUS_UPDATE,
                    WebSocketEventType.EQUIPMENT_STATUS_CHANGE,
                    WebSocketEventType.EQUIPMENT_FAULT_OCCURRED,
                    WebSocketEventType.EQUIPMENT_FAULT_RESOLVED,
                    WebSocketEventType.MAINTENANCE_SCHEDULE_UPDATED
                ],
                "andon": [
                    WebSocketEventType.ANDON_EVENT,
                    WebSocketEventType.ANDON_ALERT,
                    WebSocketEventType.ANDON_EVENT_CREATED,
                    WebSocketEventType.ANDON_EVENT_UPDATED,
                    WebSocketEventType.ANDON_EVENT_RESOLVED,
                    WebSocketEventType.ANDON_ESCALATION_TRIGGERED
                ],
                "oee": [
                    WebSocketEventType.OEE_UPDATE,
                    WebSocketEventType.OEE_DATA_UPDATED
                ],
                "quality": [
                    WebSocketEventType.QUALITY_UPDATE,
                    WebSocketEventType.QUALITY_CHECK_COMPLETED,
                    WebSocketEventType.QUALITY_INSPECTION_COMPLETED,
                    WebSocketEventType.QUALITY_DEFECT_REPORTED,
                    WebSocketEventType.QUALITY_ALERT_TRIGGERED
                ]
            }
        })
        
    except Exception as e:
        logger.error("WebSocket health check failed", error=str(e))
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content={
                "status": "unhealthy",
                "service": "websocket",
                "error": str(e),
                "timestamp": datetime.now(timezone.utc).isoformat()
            }
        )


@router.get("/events")
async def get_available_events():
    """
    Get available WebSocket event types and subscription options.
    
    Returns:
        JSON response with all available event types and subscription types
    """
    return JSONResponse({
        "event_types": {
            "production": [
                WebSocketEventType.PRODUCTION_UPDATE,
                WebSocketEventType.PRODUCTION_LINE_UPDATED,
                WebSocketEventType.PRODUCTION_SCHEDULE_UPDATED,
                WebSocketEventType.PRODUCTION_METRICS_UPDATED
            ],
            "equipment": [
                WebSocketEventType.EQUIPMENT_STATUS_UPDATE,
                WebSocketEventType.EQUIPMENT_STATUS_CHANGE,
                WebSocketEventType.EQUIPMENT_FAULT_OCCURRED,
                WebSocketEventType.EQUIPMENT_FAULT_RESOLVED,
                WebSocketEventType.MAINTENANCE_SCHEDULE_UPDATED
            ],
            "job": [
                WebSocketEventType.JOB_ASSIGNMENT_UPDATED,
                WebSocketEventType.JOB_STARTED,
                WebSocketEventType.JOB_COMPLETED,
                WebSocketEventType.JOB_CANCELLED
            ],
            "oee": [
                WebSocketEventType.OEE_UPDATE,
                WebSocketEventType.OEE_DATA_UPDATED
            ],
            "downtime": [
                WebSocketEventType.DOWNTIME_EVENT,
                WebSocketEventType.DOWNTIME_STATISTICS_UPDATE
            ],
            "andon": [
                WebSocketEventType.ANDON_EVENT,
                WebSocketEventType.ANDON_ALERT,
                WebSocketEventType.ANDON_EVENT_CREATED,
                WebSocketEventType.ANDON_EVENT_UPDATED,
                WebSocketEventType.ANDON_EVENT_RESOLVED,
                WebSocketEventType.ANDON_ESCALATION_TRIGGERED
            ],
            "escalation": [
                WebSocketEventType.ESCALATION_EVENT,
                WebSocketEventType.ESCALATION_STATUS_UPDATE,
                WebSocketEventType.ESCALATION_REMINDER
            ],
            "quality": [
                WebSocketEventType.QUALITY_UPDATE,
                WebSocketEventType.QUALITY_CHECK_COMPLETED,
                WebSocketEventType.QUALITY_INSPECTION_COMPLETED,
                WebSocketEventType.QUALITY_DEFECT_REPORTED,
                WebSocketEventType.QUALITY_ALERT_TRIGGERED
            ],
            "changeover": [
                WebSocketEventType.CHANGEOVER_UPDATE,
                WebSocketEventType.CHANGEOVER_STARTED,
                WebSocketEventType.CHANGEOVER_COMPLETED
            ],
            "dashboard": [
                WebSocketEventType.DASHBOARD_DATA_UPDATED,
                WebSocketEventType.REAL_TIME_METRICS_UPDATED
            ],
            "system": [
                WebSocketEventType.SYSTEM_ALERT,
                WebSocketEventType.HEARTBEAT,
                WebSocketEventType.PONG,
                WebSocketEventType.ERROR,
                WebSocketEventType.SUBSCRIPTION_CONFIRMED,
                WebSocketEventType.UNSUBSCRIPTION_CONFIRMED
            ]
        },
        "subscription_types": [
            "line", "equipment", "job", "production", "oee", 
            "downtime", "andon", "escalation", "quality", "changeover"
        ],
        "message_types": [
            "subscribe", "unsubscribe", "ping", "heartbeat", 
            "request_data", "acknowledge"
        ]
    })
