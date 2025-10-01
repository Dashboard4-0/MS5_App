"""
MS5.0 Floor Dashboard - Real-time Event Broadcaster

This module provides real-time event broadcasting for production updates,
integrating with existing services to broadcast events via WebSocket.

Architected for cosmic scale operations - the nervous system of a starship.
"""

import asyncio
from typing import Dict, List, Optional, Any
from datetime import datetime
import structlog

from app.services.enhanced_websocket_manager import enhanced_websocket_manager, MessagePriority
from app.services.production_service import ProductionService
from app.services.oee_calculator import OEECalculator
from app.services.andon_service import AndonService
from app.services.equipment_service import EquipmentService

logger = structlog.get_logger()


class RealTimeEventBroadcaster:
    """
    Real-time event broadcaster that integrates with existing services
    to provide live updates via WebSocket connections.
    
    Features:
    - Production data broadcasting
    - OEE calculation updates
    - Andon event notifications
    - Equipment status monitoring
    - Quality alerts
    - Downtime tracking
    - Escalation management
    """
    
    def __init__(self):
        self.production_service = ProductionService()
        self.oee_calculator = OEECalculator()
        self.andon_service = AndonService()
        self.equipment_service = EquipmentService()
        
        # Event subscription tracking
        self.event_subscriptions: Dict[str, List[str]] = {}
        
        logger.info("Real-time Event Broadcaster initialized")
    
    # ============================================================================
    # PRODUCTION DATA BROADCASTING
    # ============================================================================
    
    async def broadcast_production_update(self, line_id: str, production_data: Dict[str, Any]) -> None:
        """Broadcast production update to all subscribers."""
        message = {
            "type": "production_update",
            "data": {
                "line_id": line_id,
                "production_data": production_data,
                "timestamp": datetime.utcnow().isoformat()
            },
            "timestamp": datetime.utcnow().isoformat()
        }
        
        await enhanced_websocket_manager.send_to_line(message, line_id)
        
        logger.debug("Production update broadcasted", 
                    line_id=line_id, 
                    production_data=production_data)
    
    async def broadcast_line_status_update(self, line_id: str, status_data: Dict[str, Any]) -> None:
        """Broadcast line status update to all subscribers."""
        message = {
            "type": "line_status_update",
            "data": {
                "line_id": line_id,
                "status": status_data,
                "timestamp": datetime.utcnow().isoformat()
            },
            "timestamp": datetime.utcnow().isoformat()
        }
        
        await enhanced_websocket_manager.send_to_line(message, line_id)
        
        logger.debug("Line status update broadcasted", 
                    line_id=line_id, 
                    status=status_data)
    
    async def broadcast_job_assignment(self, job_data: Dict[str, Any]) -> None:
        """Broadcast job assignment to relevant subscribers."""
        message = {
            "type": "job_assigned",
            "data": {
                "job": job_data,
                "timestamp": datetime.utcnow().isoformat()
            },
            "timestamp": datetime.utcnow().isoformat()
        }
        
        # Send to line subscribers
        line_id = job_data.get("line_id")
        if line_id:
            await enhanced_websocket_manager.send_to_line(message, line_id)
        
        # Send to user if they have an active connection
        user_id = job_data.get("user_id")
        if user_id:
            # Find connection for user
            for connection_id, metrics in enhanced_websocket_manager.connection_metrics.items():
                if metrics.user_id == user_id:
                    await enhanced_websocket_manager.send_personal_message(
                        message, connection_id, MessagePriority.HIGH
                    )
                    break
        
        logger.debug("Job assignment broadcasted", job_data=job_data)
    
    async def broadcast_job_started(self, job_data: Dict[str, Any]) -> None:
        """Broadcast job started event."""
        message = {
            "type": "job_started",
            "data": {
                "job": job_data,
                "timestamp": datetime.utcnow().isoformat()
            },
            "timestamp": datetime.utcnow().isoformat()
        }
        
        line_id = job_data.get("line_id")
        if line_id:
            await enhanced_websocket_manager.send_to_line(message, line_id)
        
        logger.debug("Job started broadcasted", job_data=job_data)
    
    async def broadcast_job_completed(self, job_data: Dict[str, Any]) -> None:
        """Broadcast job completed event."""
        message = {
            "type": "job_completed",
            "data": {
                "job": job_data,
                "timestamp": datetime.utcnow().isoformat()
            },
            "timestamp": datetime.utcnow().isoformat()
        }
        
        line_id = job_data.get("line_id")
        if line_id:
            await enhanced_websocket_manager.send_to_line(message, line_id)
        
        logger.debug("Job completed broadcasted", job_data=job_data)
    
    async def broadcast_job_cancelled(self, job_data: Dict[str, Any]) -> None:
        """Broadcast job cancelled event."""
        message = {
            "type": "job_cancelled",
            "data": {
                "job": job_data,
                "timestamp": datetime.utcnow().isoformat()
            },
            "timestamp": datetime.utcnow().isoformat()
        }
        
        line_id = job_data.get("line_id")
        if line_id:
            await enhanced_websocket_manager.send_to_line(message, line_id)
        
        logger.debug("Job cancelled broadcasted", job_data=job_data)
    
    # ============================================================================
    # OEE DATA BROADCASTING
    # ============================================================================
    
    async def broadcast_oee_update(self, line_id: str, oee_data: Dict[str, Any]) -> None:
        """Broadcast OEE update to all subscribers."""
        message = {
            "type": "oee_update",
            "data": {
                "line_id": line_id,
                "oee_data": oee_data,
                "timestamp": datetime.utcnow().isoformat()
            },
            "timestamp": datetime.utcnow().isoformat()
        }
        
        await enhanced_websocket_manager.send_to_line(message, line_id)
        
        logger.debug("OEE update broadcasted", 
                    line_id=line_id, 
                    oee_data=oee_data)
    
    async def broadcast_oee_calculation_completed(self, line_id: str, calculation_result: Dict[str, Any]) -> None:
        """Broadcast OEE calculation completion."""
        message = {
            "type": "oee_calculation_completed",
            "data": {
                "line_id": line_id,
                "calculation_result": calculation_result,
                "timestamp": datetime.utcnow().isoformat()
            },
            "timestamp": datetime.utcnow().isoformat()
        }
        
        await enhanced_websocket_manager.send_to_line(message, line_id)
        
        logger.debug("OEE calculation completed broadcasted", 
                    line_id=line_id, 
                    calculation_result=calculation_result)
    
    # ============================================================================
    # ANDON EVENT BROADCASTING
    # ============================================================================
    
    async def broadcast_andon_event(self, andon_event: Dict[str, Any]) -> None:
        """Broadcast Andon event to relevant subscribers."""
        message = {
            "type": "andon_event",
            "data": {
                "andon_event": andon_event,
                "timestamp": datetime.utcnow().isoformat()
            },
            "timestamp": datetime.utcnow().isoformat()
        }
        
        # Send to line subscribers
        line_id = andon_event.get("line_id")
        if line_id:
            await enhanced_websocket_manager.send_to_line(message, line_id)
        
        # Send to equipment subscribers
        equipment_code = andon_event.get("equipment_code")
        if equipment_code:
            await enhanced_websocket_manager.send_to_equipment(message, equipment_code)
        
        # Send to escalation subscribers if priority is high
        priority = andon_event.get("priority")
        if priority in ["high", "critical"]:
            await enhanced_websocket_manager.send_to_escalation_subscribers(
                message, priority=priority
            )
        
        logger.debug("Andon event broadcasted", andon_event=andon_event)
    
    async def broadcast_andon_escalation(self, escalation_data: Dict[str, Any]) -> None:
        """Broadcast Andon escalation to relevant subscribers."""
        message = {
            "type": "andon_escalation_triggered",
            "data": {
                "escalation": escalation_data,
                "timestamp": datetime.utcnow().isoformat()
            },
            "timestamp": datetime.utcnow().isoformat()
        }
        
        # Send to escalation subscribers
        escalation_id = escalation_data.get("escalation_id")
        priority = escalation_data.get("priority")
        
        await enhanced_websocket_manager.send_to_escalation_subscribers(
            message, escalation_id, priority
        )
        
        # Send to line subscribers for context
        line_id = escalation_data.get("line_id")
        if line_id:
            await enhanced_websocket_manager.send_to_line(message, line_id)
        
        logger.debug("Andon escalation broadcasted", escalation_data=escalation_data)
    
    # ============================================================================
    # EQUIPMENT STATUS BROADCASTING
    # ============================================================================
    
    async def broadcast_equipment_status_update(self, equipment_code: str, status_data: Dict[str, Any]) -> None:
        """Broadcast equipment status update to all subscribers."""
        message = {
            "type": "equipment_status_update",
            "data": {
                "equipment_code": equipment_code,
                "status": status_data,
                "timestamp": datetime.utcnow().isoformat()
            },
            "timestamp": datetime.utcnow().isoformat()
        }
        
        await enhanced_websocket_manager.send_to_equipment(message, equipment_code)
        
        logger.debug("Equipment status update broadcasted", 
                    equipment_code=equipment_code, 
                    status=status_data)
    
    async def broadcast_equipment_fault(self, fault_data: Dict[str, Any]) -> None:
        """Broadcast equipment fault to relevant subscribers."""
        message = {
            "type": "equipment_fault_occurred",
            "data": {
                "fault": fault_data,
                "timestamp": datetime.utcnow().isoformat()
            },
            "timestamp": datetime.utcnow().isoformat()
        }
        
        # Send to equipment subscribers
        equipment_code = fault_data.get("equipment_code")
        if equipment_code:
            await enhanced_websocket_manager.send_to_equipment(message, equipment_code)
        
        # Send to line subscribers if line_id is available
        line_id = fault_data.get("line_id")
        if line_id:
            await enhanced_websocket_manager.send_to_line(message, line_id)
        
        # Send to escalation subscribers if severity is high
        severity = fault_data.get("severity")
        if severity in ["high", "critical"]:
            await enhanced_websocket_manager.send_to_escalation_subscribers(
                message, priority=severity
            )
        
        logger.debug("Equipment fault broadcasted", fault_data=fault_data)
    
    async def broadcast_equipment_fault_resolved(self, fault_data: Dict[str, Any]) -> None:
        """Broadcast equipment fault resolution."""
        message = {
            "type": "equipment_fault_resolved",
            "data": {
                "fault": fault_data,
                "timestamp": datetime.utcnow().isoformat()
            },
            "timestamp": datetime.utcnow().isoformat()
        }
        
        # Send to equipment subscribers
        equipment_code = fault_data.get("equipment_code")
        if equipment_code:
            await enhanced_websocket_manager.send_to_equipment(message, equipment_code)
        
        # Send to line subscribers if line_id is available
        line_id = fault_data.get("line_id")
        if line_id:
            await enhanced_websocket_manager.send_to_line(message, line_id)
        
        logger.debug("Equipment fault resolved broadcasted", fault_data=fault_data)
    
    # ============================================================================
    # QUALITY ALERT BROADCASTING
    # ============================================================================
    
    async def broadcast_quality_alert(self, quality_data: Dict[str, Any]) -> None:
        """Broadcast quality alert to relevant subscribers."""
        message = {
            "type": "quality_alert",
            "data": {
                "quality_alert": quality_data,
                "timestamp": datetime.utcnow().isoformat()
            },
            "timestamp": datetime.utcnow().isoformat()
        }
        
        # Send to line subscribers
        line_id = quality_data.get("line_id")
        if line_id:
            await enhanced_websocket_manager.send_to_line(message, line_id)
        
        # Send to escalation subscribers if severity is high
        severity = quality_data.get("severity")
        if severity in ["high", "critical"]:
            await enhanced_websocket_manager.send_to_escalation_subscribers(
                message, priority=severity
            )
        
        logger.debug("Quality alert broadcasted", quality_data=quality_data)
    
    async def broadcast_quality_check_completed(self, check_data: Dict[str, Any]) -> None:
        """Broadcast quality check completion."""
        message = {
            "type": "quality_check_completed",
            "data": {
                "quality_check": check_data,
                "timestamp": datetime.utcnow().isoformat()
            },
            "timestamp": datetime.utcnow().isoformat()
        }
        
        # Send to line subscribers
        line_id = check_data.get("line_id")
        if line_id:
            await enhanced_websocket_manager.send_to_line(message, line_id)
        
        logger.debug("Quality check completed broadcasted", check_data=check_data)
    
    # ============================================================================
    # DOWNTIME EVENT BROADCASTING
    # ============================================================================
    
    async def broadcast_downtime_event(self, downtime_data: Dict[str, Any]) -> None:
        """Broadcast downtime event to relevant subscribers."""
        message = {
            "type": "downtime_event",
            "data": {
                "downtime": downtime_data,
                "timestamp": datetime.utcnow().isoformat()
            },
            "timestamp": datetime.utcnow().isoformat()
        }
        
        # Send to downtime subscribers
        line_id = downtime_data.get("line_id")
        equipment_code = downtime_data.get("equipment_code")
        
        await enhanced_websocket_manager.send_to_downtime_subscribers(
            message, line_id, equipment_code
        )
        
        # Also send to general line and equipment subscribers
        if line_id:
            await enhanced_websocket_manager.send_to_line(message, line_id)
        
        if equipment_code:
            await enhanced_websocket_manager.send_to_equipment(message, equipment_code)
        
        logger.debug("Downtime event broadcasted", downtime_data=downtime_data)
    
    async def broadcast_downtime_statistics_update(self, stats_data: Dict[str, Any]) -> None:
        """Broadcast downtime statistics update."""
        message = {
            "type": "downtime_statistics_update",
            "data": {
                "statistics": stats_data,
                "timestamp": datetime.utcnow().isoformat()
            },
            "timestamp": datetime.utcnow().isoformat()
        }
        
        # Send to downtime subscribers
        line_id = stats_data.get("line_id")
        equipment_code = stats_data.get("equipment_code")
        
        await enhanced_websocket_manager.send_to_downtime_subscribers(
            message, line_id, equipment_code
        )
        
        logger.debug("Downtime statistics update broadcasted", stats_data=stats_data)
    
    # ============================================================================
    # ESCALATION EVENT BROADCASTING
    # ============================================================================
    
    async def broadcast_escalation_event(self, escalation_data: Dict[str, Any]) -> None:
        """Broadcast escalation event to relevant subscribers."""
        message = {
            "type": "escalation_event",
            "data": {
                "escalation": escalation_data,
                "timestamp": datetime.utcnow().isoformat()
            },
            "timestamp": datetime.utcnow().isoformat()
        }
        
        # Send to escalation subscribers
        escalation_id = escalation_data.get("escalation_id")
        priority = escalation_data.get("priority")
        
        await enhanced_websocket_manager.send_to_escalation_subscribers(
            message, escalation_id, priority
        )
        
        # Send to line subscribers for context
        line_id = escalation_data.get("line_id")
        if line_id:
            await enhanced_websocket_manager.send_to_line(message, line_id)
        
        logger.debug("Escalation event broadcasted", escalation_data=escalation_data)
    
    async def broadcast_escalation_status_update(self, escalation_id: str, status_data: Dict[str, Any]) -> None:
        """Broadcast escalation status update."""
        message = {
            "type": "escalation_status_update",
            "data": {
                "escalation_id": escalation_id,
                "status": status_data,
                "timestamp": datetime.utcnow().isoformat()
            },
            "timestamp": datetime.utcnow().isoformat()
        }
        
        await enhanced_websocket_manager.send_to_escalation_subscribers(
            message, escalation_id
        )
        
        logger.debug("Escalation status update broadcasted", 
                    escalation_id=escalation_id, 
                    status=status_data)
    
    async def broadcast_escalation_reminder(self, reminder_data: Dict[str, Any]) -> None:
        """Broadcast escalation reminder."""
        message = {
            "type": "escalation_reminder",
            "data": {
                "reminder": reminder_data,
                "timestamp": datetime.utcnow().isoformat()
            },
            "timestamp": datetime.utcnow().isoformat()
        }
        
        # Send to escalation subscribers
        escalation_id = reminder_data.get("escalation_id")
        priority = reminder_data.get("priority")
        
        await enhanced_websocket_manager.send_to_escalation_subscribers(
            message, escalation_id, priority
        )
        
        # Send to line subscribers for context
        line_id = reminder_data.get("line_id")
        if line_id:
            await enhanced_websocket_manager.send_to_line(message, line_id)
        
        logger.debug("Escalation reminder broadcasted", reminder_data=reminder_data)
    
    # ============================================================================
    # SYSTEM ALERT BROADCASTING
    # ============================================================================
    
    async def broadcast_system_alert(self, alert_data: Dict[str, Any]) -> None:
        """Broadcast system-wide alert to all connections."""
        message = {
            "type": "system_alert",
            "data": {
                "alert": alert_data,
                "timestamp": datetime.utcnow().isoformat()
            },
            "timestamp": datetime.utcnow().isoformat()
        }
        
        # Broadcast to all active connections
        for connection_id in enhanced_websocket_manager.active_connections.keys():
            await enhanced_websocket_manager.send_personal_message(
                message, connection_id, MessagePriority.CRITICAL
            )
        
        logger.debug("System alert broadcasted", alert_data=alert_data)
    
    # ============================================================================
    # INTEGRATION HELPERS
    # ============================================================================
    
    async def trigger_production_data_sync(self, line_id: str) -> None:
        """Trigger real-time production data synchronization for a line."""
        try:
            # Get latest production data
            production_data = await self.production_service.get_line_production_data(line_id)
            
            # Broadcast production update
            await self.broadcast_production_update(line_id, production_data)
            
            # Get and broadcast OEE data
            oee_data = await self.oee_calculator.calculate_oee(line_id)
            await self.broadcast_oee_update(line_id, oee_data)
            
            logger.debug("Production data sync triggered", line_id=line_id)
            
        except Exception as e:
            logger.error("Error triggering production data sync", 
                        line_id=line_id, error=str(e))
    
    async def trigger_equipment_status_sync(self, equipment_code: str) -> None:
        """Trigger real-time equipment status synchronization."""
        try:
            # Get latest equipment status
            status_data = await self.equipment_service.get_equipment_status(equipment_code)
            
            # Broadcast equipment status update
            await self.broadcast_equipment_status_update(equipment_code, status_data)
            
            logger.debug("Equipment status sync triggered", equipment_code=equipment_code)
            
        except Exception as e:
            logger.error("Error triggering equipment status sync", 
                        equipment_code=equipment_code, error=str(e))
    
    async def trigger_andon_events_sync(self, line_id: str) -> None:
        """Trigger real-time Andon events synchronization for a line."""
        try:
            # Get active Andon events
            active_events = await self.andon_service.get_active_events(line_id)
            
            # Broadcast each active event
            for event in active_events:
                await self.broadcast_andon_event(event)
            
            logger.debug("Andon events sync triggered", line_id=line_id)
            
        except Exception as e:
            logger.error("Error triggering Andon events sync", 
                        line_id=line_id, error=str(e))


# Global real-time event broadcaster instance
realtime_broadcaster = RealTimeEventBroadcaster()
