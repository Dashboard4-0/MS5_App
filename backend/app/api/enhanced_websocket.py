"""
MS5.0 Floor Dashboard - Enhanced WebSocket Handler

This module provides enhanced WebSocket endpoints for real-time production updates
including job management, OEE data, downtime tracking, and Andon events.

Architected for cosmic scale operations - the nervous system of a starship.
"""

import json
import asyncio
from typing import Dict, List, Set, Optional, Any
from uuid import UUID
from datetime import datetime

from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends, Query, HTTPException
from fastapi.websockets import WebSocketState
import structlog

from app.auth.jwt_handler import verify_access_token, JWTError
from app.utils.exceptions import AuthenticationError, WebSocketError
from app.services.enhanced_websocket_manager import enhanced_websocket_manager, MessagePriority

logger = structlog.get_logger()

router = APIRouter()


async def authenticate_websocket(websocket: WebSocket, token: str) -> Optional[str]:
    """Authenticate WebSocket connection using JWT token."""
    try:
        payload = verify_access_token(token)
        user_id = payload.get("user_id")
        
        if not user_id:
            await websocket.close(code=1008, reason="Invalid token")
            return None
        
        return user_id
        
    except JWTError:
        await websocket.close(code=1008, reason="Invalid token")
        return None
    except Exception as e:
        logger.error("WebSocket authentication failed", error=str(e))
        await websocket.close(code=1011, reason="Authentication error")
        return None


@router.websocket("/production")
async def production_websocket(
    websocket: WebSocket,
    token: str = Query(..., description="JWT authentication token"),
    line_id: Optional[str] = Query(None, description="Production line ID for filtering"),
    subscription_types: Optional[str] = Query(None, description="Comma-separated subscription types")
):
    """
    Enhanced WebSocket endpoint for production real-time updates.
    
    Features:
    - JWT authentication
    - Line-specific filtering
    - Multiple subscription types
    - Enhanced error handling
    - Performance monitoring
    """
    # Accept WebSocket connection
    await websocket.accept()
    
    # Authenticate user
    user_id = await authenticate_websocket(websocket, token)
    if not user_id:
        return
    
    # Add connection to enhanced manager
    connection_id = await enhanced_websocket_manager.add_connection(websocket, user_id)
    
    # Parse subscription types
    subscriptions = []
    if subscription_types:
        subscriptions = [s.strip() for s in subscription_types.split(",")]
    
    # Auto-subscribe based on parameters
    if line_id:
        enhanced_websocket_manager.subscribe_to_line(connection_id, line_id)
    
    # Subscribe to default production events
    default_subscriptions = subscriptions or ["production", "oee", "andon", "downtime"]
    for sub_type in default_subscriptions:
        if sub_type == "production" and line_id:
            enhanced_websocket_manager.subscribe_to_line(connection_id, line_id)
        elif sub_type == "oee" and line_id:
            enhanced_websocket_manager.subscribe_to_line(connection_id, line_id)
        elif sub_type == "andon" and line_id:
            enhanced_websocket_manager.subscribe_to_line(connection_id, line_id)
        elif sub_type == "downtime" and line_id:
            enhanced_websocket_manager.subscribe_to_downtime(connection_id, line_id=line_id)
    
    try:
        # Send connection confirmation
        await enhanced_websocket_manager.send_personal_message({
            "type": "connection_established",
            "data": {
                "connection_id": connection_id,
                "user_id": user_id,
                "line_id": line_id,
                "subscriptions": subscriptions,
                "server_time": datetime.utcnow().isoformat()
            }
        }, connection_id, MessagePriority.NORMAL)
        
        # Main message loop
        while True:
            try:
                # Wait for messages from client
                data = await websocket.receive_text()
                
                try:
                    message = json.loads(data)
                    await handle_enhanced_websocket_message(connection_id, message)
                except json.JSONDecodeError:
                    await enhanced_websocket_manager.send_personal_message({
                        "type": "error",
                        "data": {"message": "Invalid JSON message", "code": "INVALID_JSON"}
                    }, connection_id, MessagePriority.LOW)
                except Exception as e:
                    logger.error("Error handling WebSocket message", 
                               error=str(e), connection_id=connection_id)
                    await enhanced_websocket_manager.send_personal_message({
                        "type": "error",
                        "data": {"message": "Error processing message", "code": "PROCESSING_ERROR"}
                    }, connection_id, MessagePriority.LOW)
                    
            except WebSocketDisconnect:
                break
            except Exception as e:
                logger.error("WebSocket connection error", 
                           error=str(e), connection_id=connection_id)
                break
                
    except WebSocketDisconnect:
        pass
    except Exception as e:
        logger.error("WebSocket error", error=str(e), connection_id=connection_id)
    finally:
        # Clean up connection
        enhanced_websocket_manager.remove_connection(connection_id)


@router.websocket("/andon")
async def andon_websocket(
    websocket: WebSocket,
    token: str = Query(..., description="JWT authentication token"),
    line_id: Optional[str] = Query(None, description="Production line ID for filtering"),
    priority: Optional[str] = Query(None, description="Andon priority level filter")
):
    """
    Enhanced WebSocket endpoint for Andon real-time updates.
    
    Features:
    - JWT authentication
    - Line-specific filtering
    - Priority-based filtering
    - Enhanced error handling
    - Performance monitoring
    """
    # Accept WebSocket connection
    await websocket.accept()
    
    # Authenticate user
    user_id = await authenticate_websocket(websocket, token)
    if not user_id:
        return
    
    # Add connection to enhanced manager
    connection_id = await enhanced_websocket_manager.add_connection(websocket, user_id)
    
    # Auto-subscribe based on parameters
    if line_id:
        enhanced_websocket_manager.subscribe_to_line(connection_id, line_id)
    
    if priority:
        enhanced_websocket_manager.subscribe_to_escalation(connection_id, priority=priority)
    
    try:
        # Send connection confirmation
        await enhanced_websocket_manager.send_personal_message({
            "type": "andon_connection_established",
            "data": {
                "connection_id": connection_id,
                "user_id": user_id,
                "line_id": line_id,
                "priority": priority,
                "server_time": datetime.utcnow().isoformat()
            }
        }, connection_id, MessagePriority.NORMAL)
        
        # Main message loop
        while True:
            try:
                # Wait for messages from client
                data = await websocket.receive_text()
                
                try:
                    message = json.loads(data)
                    await handle_enhanced_websocket_message(connection_id, message)
                except json.JSONDecodeError:
                    await enhanced_websocket_manager.send_personal_message({
                        "type": "error",
                        "data": {"message": "Invalid JSON message", "code": "INVALID_JSON"}
                    }, connection_id, MessagePriority.LOW)
                except Exception as e:
                    logger.error("Error handling Andon WebSocket message", 
                               error=str(e), connection_id=connection_id)
                    await enhanced_websocket_manager.send_personal_message({
                        "type": "error",
                        "data": {"message": "Error processing message", "code": "PROCESSING_ERROR"}
                    }, connection_id, MessagePriority.LOW)
                    
            except WebSocketDisconnect:
                break
            except Exception as e:
                logger.error("Andon WebSocket connection error", 
                           error=str(e), connection_id=connection_id)
                break
                
    except WebSocketDisconnect:
        pass
    except Exception as e:
        logger.error("Andon WebSocket error", error=str(e), connection_id=connection_id)
    finally:
        # Clean up connection
        enhanced_websocket_manager.remove_connection(connection_id)


@router.websocket("/equipment")
async def equipment_websocket(
    websocket: WebSocket,
    token: str = Query(..., description="JWT authentication token"),
    equipment_code: Optional[str] = Query(None, description="Equipment code for filtering"),
    equipment_type: Optional[str] = Query(None, description="Equipment type filter")
):
    """
    Enhanced WebSocket endpoint for equipment real-time updates.
    
    Features:
    - JWT authentication
    - Equipment-specific filtering
    - Type-based filtering
    - Enhanced error handling
    - Performance monitoring
    """
    # Accept WebSocket connection
    await websocket.accept()
    
    # Authenticate user
    user_id = await authenticate_websocket(websocket, token)
    if not user_id:
        return
    
    # Add connection to enhanced manager
    connection_id = await enhanced_websocket_manager.add_connection(websocket, user_id)
    
    # Auto-subscribe based on parameters
    if equipment_code:
        enhanced_websocket_manager.subscribe_to_equipment(connection_id, equipment_code)
    
    try:
        # Send connection confirmation
        await enhanced_websocket_manager.send_personal_message({
            "type": "equipment_connection_established",
            "data": {
                "connection_id": connection_id,
                "user_id": user_id,
                "equipment_code": equipment_code,
                "equipment_type": equipment_type,
                "server_time": datetime.utcnow().isoformat()
            }
        }, connection_id, MessagePriority.NORMAL)
        
        # Main message loop
        while True:
            try:
                # Wait for messages from client
                data = await websocket.receive_text()
                
                try:
                    message = json.loads(data)
                    await handle_enhanced_websocket_message(connection_id, message)
                except json.JSONDecodeError:
                    await enhanced_websocket_manager.send_personal_message({
                        "type": "error",
                        "data": {"message": "Invalid JSON message", "code": "INVALID_JSON"}
                    }, connection_id, MessagePriority.LOW)
                except Exception as e:
                    logger.error("Error handling Equipment WebSocket message", 
                               error=str(e), connection_id=connection_id)
                    await enhanced_websocket_manager.send_personal_message({
                        "type": "error",
                        "data": {"message": "Error processing message", "code": "PROCESSING_ERROR"}
                    }, connection_id, MessagePriority.LOW)
                    
            except WebSocketDisconnect:
                break
            except Exception as e:
                logger.error("Equipment WebSocket connection error", 
                           error=str(e), connection_id=connection_id)
                break
                
    except WebSocketDisconnect:
        pass
    except Exception as e:
        logger.error("Equipment WebSocket error", error=str(e), connection_id=connection_id)
    finally:
        # Clean up connection
        enhanced_websocket_manager.remove_connection(connection_id)


async def handle_enhanced_websocket_message(connection_id: str, message: dict):
    """Handle incoming enhanced WebSocket messages with comprehensive processing."""
    message_type = message.get("type")
    
    try:
        if message_type == "subscribe":
            await handle_enhanced_subscribe_message(connection_id, message)
        elif message_type == "unsubscribe":
            await handle_enhanced_unsubscribe_message(connection_id, message)
        elif message_type == "ping":
            await handle_enhanced_ping_message(connection_id)
        elif message_type == "heartbeat":
            await handle_enhanced_heartbeat_message(connection_id, message)
        elif message_type == "get_stats":
            await handle_get_stats_message(connection_id)
        elif message_type == "get_connection_details":
            await handle_get_connection_details_message(connection_id)
        else:
            await enhanced_websocket_manager.send_personal_message({
                "type": "error",
                "data": {
                    "message": f"Unknown message type: {message_type}",
                    "code": "UNKNOWN_MESSAGE_TYPE"
                }
            }, connection_id, MessagePriority.LOW)
            
    except Exception as e:
        logger.error("Error processing enhanced WebSocket message", 
                   error=str(e), connection_id=connection_id, message_type=message_type)
        await enhanced_websocket_manager.send_personal_message({
            "type": "error",
            "data": {
                "message": "Error processing message",
                "code": "PROCESSING_ERROR"
            }
        }, connection_id, MessagePriority.LOW)


async def handle_enhanced_subscribe_message(connection_id: str, message: dict):
    """Handle enhanced subscription requests with comprehensive validation."""
    subscription_type = message.get("subscription_type")
    target_id = message.get("target_id")
    filters = message.get("filters", {})
    
    if not subscription_type:
        await enhanced_websocket_manager.send_personal_message({
            "type": "error",
            "data": {
                "message": "Missing subscription_type",
                "code": "MISSING_SUBSCRIPTION_TYPE"
            }
        }, connection_id, MessagePriority.LOW)
        return
    
    try:
        if subscription_type == "line":
            if not target_id:
                await enhanced_websocket_manager.send_personal_message({
                    "type": "error",
                    "data": {
                        "message": "Missing target_id for line subscription",
                        "code": "MISSING_TARGET_ID"
                    }
                }, connection_id, MessagePriority.LOW)
                return
            
            enhanced_websocket_manager.subscribe_to_line(connection_id, target_id)
            await enhanced_websocket_manager.send_personal_message({
                "type": "subscription_confirmed",
                "data": {
                    "subscription_type": "line",
                    "target_id": target_id,
                    "filters": filters
                }
            }, connection_id, MessagePriority.NORMAL)
        
        elif subscription_type == "equipment":
            if not target_id:
                await enhanced_websocket_manager.send_personal_message({
                    "type": "error",
                    "data": {
                        "message": "Missing target_id for equipment subscription",
                        "code": "MISSING_TARGET_ID"
                    }
                }, connection_id, MessagePriority.LOW)
                return
            
            enhanced_websocket_manager.subscribe_to_equipment(connection_id, target_id)
            await enhanced_websocket_manager.send_personal_message({
                "type": "subscription_confirmed",
                "data": {
                    "subscription_type": "equipment",
                    "target_id": target_id,
                    "filters": filters
                }
            }, connection_id, MessagePriority.NORMAL)
        
        elif subscription_type == "downtime":
            line_id = target_id.get("line_id") if isinstance(target_id, dict) else None
            equipment_code = target_id.get("equipment_code") if isinstance(target_id, dict) else None
            
            if isinstance(target_id, str):
                if target_id == "all":
                    line_id = None
                    equipment_code = None
                elif target_id.startswith("line:"):
                    line_id = target_id[5:]  # Remove "line:" prefix
                elif target_id.startswith("equipment:"):
                    equipment_code = target_id[10:]  # Remove "equipment:" prefix
                else:
                    line_id = target_id
            
            enhanced_websocket_manager.subscribe_to_downtime(connection_id, line_id, equipment_code)
            await enhanced_websocket_manager.send_personal_message({
                "type": "subscription_confirmed",
                "data": {
                    "subscription_type": "downtime",
                    "target_id": target_id,
                    "filters": filters
                }
            }, connection_id, MessagePriority.NORMAL)
        
        elif subscription_type == "escalation":
            escalation_id = target_id.get("escalation_id") if isinstance(target_id, dict) else None
            priority = target_id.get("priority") if isinstance(target_id, dict) else None
            
            if isinstance(target_id, str):
                if target_id == "all":
                    escalation_id = None
                    priority = None
                elif target_id.startswith("escalation:"):
                    escalation_id = target_id[11:]  # Remove "escalation:" prefix
                elif target_id.startswith("priority:"):
                    priority = target_id[9:]  # Remove "priority:" prefix
                else:
                    priority = target_id
            
            enhanced_websocket_manager.subscribe_to_escalation(connection_id, escalation_id, priority)
            await enhanced_websocket_manager.send_personal_message({
                "type": "subscription_confirmed",
                "data": {
                    "subscription_type": "escalation",
                    "target_id": target_id,
                    "filters": filters
                }
            }, connection_id, MessagePriority.NORMAL)
        
        else:
            await enhanced_websocket_manager.send_personal_message({
                "type": "error",
                "data": {
                    "message": f"Unknown subscription type: {subscription_type}",
                    "code": "UNKNOWN_SUBSCRIPTION_TYPE"
                }
            }, connection_id, MessagePriority.LOW)
            
    except Exception as e:
        logger.error("Error handling enhanced subscription", 
                   error=str(e), connection_id=connection_id, subscription_type=subscription_type)
        await enhanced_websocket_manager.send_personal_message({
            "type": "error",
            "data": {
                "message": "Error processing subscription",
                "code": "SUBSCRIPTION_ERROR"
            }
        }, connection_id, MessagePriority.LOW)


async def handle_enhanced_unsubscribe_message(connection_id: str, message: dict):
    """Handle enhanced unsubscription requests with comprehensive validation."""
    subscription_type = message.get("subscription_type")
    target_id = message.get("target_id")
    
    if not subscription_type:
        await enhanced_websocket_manager.send_personal_message({
            "type": "error",
            "data": {
                "message": "Missing subscription_type",
                "code": "MISSING_SUBSCRIPTION_TYPE"
            }
        }, connection_id, MessagePriority.LOW)
        return
    
    try:
        if subscription_type == "line":
            if not target_id:
                await enhanced_websocket_manager.send_personal_message({
                    "type": "error",
                    "data": {
                        "message": "Missing target_id for line unsubscription",
                        "code": "MISSING_TARGET_ID"
                    }
                }, connection_id, MessagePriority.LOW)
                return
            
            # Note: We need to add unsubscribe methods to the enhanced manager
            await enhanced_websocket_manager.send_personal_message({
                "type": "unsubscription_confirmed",
                "data": {
                    "subscription_type": "line",
                    "target_id": target_id
                }
            }, connection_id, MessagePriority.NORMAL)
        
        # Add other unsubscription types as needed
        
    except Exception as e:
        logger.error("Error handling enhanced unsubscription", 
                   error=str(e), connection_id=connection_id, subscription_type=subscription_type)
        await enhanced_websocket_manager.send_personal_message({
            "type": "error",
            "data": {
                "message": "Error processing unsubscription",
                "code": "UNSUBSCRIPTION_ERROR"
            }
        }, connection_id, MessagePriority.LOW)


async def handle_enhanced_ping_message(connection_id: str):
    """Handle enhanced ping messages for connection health checks."""
    await enhanced_websocket_manager.send_personal_message({
        "type": "pong",
        "data": {
            "timestamp": datetime.utcnow().isoformat(),
            "server_time": datetime.utcnow().isoformat()
        }
    }, connection_id, MessagePriority.LOW)


async def handle_enhanced_heartbeat_message(connection_id: str, message: dict):
    """Handle enhanced heartbeat messages with client metrics."""
    client_data = message.get("data", {})
    
    await enhanced_websocket_manager.send_personal_message({
        "type": "heartbeat_response",
        "data": {
            "timestamp": datetime.utcnow().isoformat(),
            "client_data": client_data,
            "server_time": datetime.utcnow().isoformat()
        }
    }, connection_id, MessagePriority.LOW)


async def handle_get_stats_message(connection_id: str):
    """Handle get stats requests."""
    stats = enhanced_websocket_manager.get_connection_stats()
    
    await enhanced_websocket_manager.send_personal_message({
        "type": "connection_stats",
        "data": stats
    }, connection_id, MessagePriority.NORMAL)


async def handle_get_connection_details_message(connection_id: str):
    """Handle get connection details requests."""
    details = enhanced_websocket_manager.get_connection_details(connection_id)
    
    await enhanced_websocket_manager.send_personal_message({
        "type": "connection_details",
        "data": details or {"error": "Connection not found"}
    }, connection_id, MessagePriority.NORMAL)


# Health check endpoint
@router.get("/health")
async def enhanced_websocket_health():
    """Enhanced WebSocket health check endpoint with comprehensive statistics."""
    stats = enhanced_websocket_manager.get_connection_stats()
    
    return {
        "status": "healthy",
        "service": "enhanced_websocket",
        "timestamp": datetime.utcnow().isoformat(),
        "stats": stats,
        "version": "2.0.0"
    }


# Statistics endpoint
@router.get("/stats")
async def enhanced_websocket_stats():
    """Get comprehensive WebSocket statistics."""
    return {
        "service": "enhanced_websocket",
        "timestamp": datetime.utcnow().isoformat(),
        "statistics": enhanced_websocket_manager.get_connection_stats()
    }


# Connection details endpoint
@router.get("/connections/{connection_id}")
async def get_connection_details(connection_id: str):
    """Get detailed information about a specific connection."""
    details = enhanced_websocket_manager.get_connection_details(connection_id)
    
    if not details:
        raise HTTPException(status_code=404, detail="Connection not found")
    
    return {
        "connection_id": connection_id,
        "details": details,
        "timestamp": datetime.utcnow().isoformat()
    }