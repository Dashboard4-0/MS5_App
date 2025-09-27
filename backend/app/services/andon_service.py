"""
MS5.0 Floor Dashboard - Andon Service

This module provides Andon system services for handling machine stoppages,
quality issues, and other production alerts with escalation management.
"""

from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any, Tuple
from uuid import UUID
import structlog

from app.database import execute_query, execute_scalar, execute_update
from app.models.production import (
    AndonEventCreate, AndonEventUpdate, AndonEventResponse,
    AndonEventType, AndonPriority, AndonStatus
)
from app.utils.exceptions import (
    NotFoundError, ValidationError, BusinessLogicError, ConflictError
)
from app.services.notification_service import notification_service
from app.services.andon_escalation_service import AndonEscalationService

logger = structlog.get_logger()


class AndonService:
    """Service for Andon system management."""
    
    # Escalation configuration
    ESCALATION_LEVELS = {
        AndonPriority.LOW: {
            "acknowledgment_timeout": 15,  # minutes
            "resolution_timeout": 60,      # minutes
            "escalation_recipients": ["shift_manager", "engineer"]
        },
        AndonPriority.MEDIUM: {
            "acknowledgment_timeout": 10,  # minutes
            "resolution_timeout": 45,      # minutes
            "escalation_recipients": ["shift_manager", "engineer", "production_manager"]
        },
        AndonPriority.HIGH: {
            "acknowledgment_timeout": 5,   # minutes
            "resolution_timeout": 30,      # minutes
            "escalation_recipients": ["shift_manager", "engineer", "production_manager", "admin"]
        },
        AndonPriority.CRITICAL: {
            "acknowledgment_timeout": 2,   # minutes
            "resolution_timeout": 15,      # minutes
            "escalation_recipients": ["all_managers", "admin"]
        }
    }
    
    @staticmethod
    async def create_andon_event(
        event_data: AndonEventCreate,
        reported_by: UUID
    ) -> AndonEventResponse:
        """Create a new Andon event."""
        try:
            # Validate line exists
            line_query = """
            SELECT id FROM factory_telemetry.production_lines 
            WHERE id = :line_id AND enabled = true
            """
            line_exists = await execute_scalar(line_query, {"line_id": event_data.line_id})
            
            if not line_exists:
                raise NotFoundError("Production line", str(event_data.line_id))
            
            # Check for duplicate active events
            duplicate_query = """
            SELECT id FROM factory_telemetry.andon_events 
            WHERE line_id = :line_id 
            AND equipment_code = :equipment_code
            AND event_type = :event_type
            AND status IN ('open', 'acknowledged')
            """
            
            duplicate = await execute_scalar(duplicate_query, {
                "line_id": event_data.line_id,
                "equipment_code": event_data.equipment_code,
                "event_type": event_data.event_type.value
            })
            
            if duplicate:
                raise ConflictError("Active Andon event already exists for this equipment")
            
            # Create Andon event
            create_query = """
            INSERT INTO factory_telemetry.andon_events 
            (line_id, equipment_code, event_type, priority, description, 
             reported_by, reported_at, status)
            VALUES (:line_id, :equipment_code, :event_type, :priority, :description, 
                   :reported_by, :reported_at, :status)
            RETURNING id, line_id, equipment_code, event_type, priority, description, 
                     reported_by, reported_at, status
            """
            
            result = await execute_query(create_query, {
                "line_id": event_data.line_id,
                "equipment_code": event_data.equipment_code,
                "event_type": event_data.event_type.value,
                "priority": event_data.priority.value,
                "description": event_data.description,
                "reported_by": reported_by,
                "reported_at": datetime.utcnow(),
                "status": AndonStatus.OPEN.value
            })
            
            if not result:
                raise BusinessLogicError("Failed to create Andon event")
            
            event = result[0]
            
            # Start escalation process
            await AndonService._start_escalation_process(
                event["id"], event_data.priority
            )
            
            # Send real-time notification
            await AndonService._send_andon_notification(event)
            
            logger.info(
                "Andon event created",
                event_id=event["id"],
                line_id=event_data.line_id,
                equipment_code=event_data.equipment_code,
                priority=event_data.priority.value
            )
            
            return AndonEventResponse(
                id=event["id"],
                line_id=event["line_id"],
                equipment_code=event["equipment_code"],
                event_type=AndonEventType(event["event_type"]),
                priority=AndonPriority(event["priority"]),
                description=event["description"],
                status=AndonStatus(event["status"]),
                reported_by=event["reported_by"],
                reported_at=event["reported_at"],
                acknowledged_by=None,
                acknowledged_at=None,
                resolved_by=None,
                resolved_at=None,
                resolution_notes=None
            )
            
        except (NotFoundError, ConflictError, BusinessLogicError):
            raise
        except Exception as e:
            logger.error("Failed to create Andon event", error=str(e))
            raise BusinessLogicError("Failed to create Andon event")
    
    @staticmethod
    async def get_andon_event(event_id: UUID) -> AndonEventResponse:
        """Get an Andon event by ID."""
        try:
            query = """
            SELECT id, line_id, equipment_code, event_type, priority, description, 
                   status, reported_by, reported_at, acknowledged_by, acknowledged_at, 
                   resolved_by, resolved_at, resolution_notes
            FROM factory_telemetry.andon_events 
            WHERE id = :event_id
            """
            
            result = await execute_query(query, {"event_id": event_id})
            
            if not result:
                raise NotFoundError("Andon event", str(event_id))
            
            event = result[0]
            
            return AndonEventResponse(
                id=event["id"],
                line_id=event["line_id"],
                equipment_code=event["equipment_code"],
                event_type=AndonEventType(event["event_type"]),
                priority=AndonPriority(event["priority"]),
                description=event["description"],
                status=AndonStatus(event["status"]),
                reported_by=event["reported_by"],
                reported_at=event["reported_at"],
                acknowledged_by=event["acknowledged_by"],
                acknowledged_at=event["acknowledged_at"],
                resolved_by=event["resolved_by"],
                resolved_at=event["resolved_at"],
                resolution_notes=event["resolution_notes"]
            )
            
        except NotFoundError:
            raise
        except Exception as e:
            logger.error("Failed to get Andon event", error=str(e), event_id=event_id)
            raise BusinessLogicError("Failed to get Andon event")
    
    @staticmethod
    async def acknowledge_andon_event(
        event_id: UUID,
        acknowledged_by: UUID
    ) -> AndonEventResponse:
        """Acknowledge an Andon event."""
        try:
            # Get current event
            event = await AndonService.get_andon_event(event_id)
            
            if event.status != AndonStatus.OPEN:
                raise BusinessLogicError("Event cannot be acknowledged in current status")
            
            # Update event status
            update_query = """
            UPDATE factory_telemetry.andon_events 
            SET status = :status, acknowledged_by = :acknowledged_by, 
                acknowledged_at = :acknowledged_at
            WHERE id = :event_id
            """
            
            await execute_update(update_query, {
                "event_id": event_id,
                "status": AndonStatus.ACKNOWLEDGED.value,
                "acknowledged_by": acknowledged_by,
                "acknowledged_at": datetime.utcnow()
            })
            
            # Cancel escalation process
            await AndonService._cancel_escalation_process(event_id)
            
            # Send acknowledgment notification
            await AndonService._send_acknowledgment_notification(event_id, acknowledged_by)
            
            logger.info(
                "Andon event acknowledged",
                event_id=event_id,
                acknowledged_by=acknowledged_by
            )
            
            # Return updated event
            return await AndonService.get_andon_event(event_id)
            
        except (NotFoundError, BusinessLogicError):
            raise
        except Exception as e:
            logger.error("Failed to acknowledge Andon event", error=str(e), event_id=event_id)
            raise BusinessLogicError("Failed to acknowledge Andon event")
    
    @staticmethod
    async def resolve_andon_event(
        event_id: UUID,
        resolved_by: UUID,
        resolution_notes: str
    ) -> AndonEventResponse:
        """Resolve an Andon event."""
        try:
            # Get current event
            event = await AndonService.get_andon_event(event_id)
            
            if event.status not in [AndonStatus.OPEN, AndonStatus.ACKNOWLEDGED]:
                raise BusinessLogicError("Event cannot be resolved in current status")
            
            # Update event status
            update_query = """
            UPDATE factory_telemetry.andon_events 
            SET status = :status, resolved_by = :resolved_by, 
                resolved_at = :resolved_at, resolution_notes = :resolution_notes
            WHERE id = :event_id
            """
            
            await execute_update(update_query, {
                "event_id": event_id,
                "status": AndonStatus.RESOLVED.value,
                "resolved_by": resolved_by,
                "resolved_at": datetime.utcnow(),
                "resolution_notes": resolution_notes
            })
            
            # Cancel escalation process
            await AndonService._cancel_escalation_process(event_id)
            
            # Send resolution notification
            await AndonService._send_resolution_notification(event_id, resolved_by)
            
            logger.info(
                "Andon event resolved",
                event_id=event_id,
                resolved_by=resolved_by
            )
            
            # Return updated event
            return await AndonService.get_andon_event(event_id)
            
        except (NotFoundError, BusinessLogicError):
            raise
        except Exception as e:
            logger.error("Failed to resolve Andon event", error=str(e), event_id=event_id)
            raise BusinessLogicError("Failed to resolve Andon event")
    
    @staticmethod
    async def escalate_andon_event(
        event_id: UUID,
        escalation_level: int,
        escalated_by: UUID,
        escalation_notes: str = None
    ) -> Dict[str, Any]:
        """Escalate an Andon event to a specific level."""
        try:
            # Get current event
            event = await AndonService.get_andon_event(event_id)
            
            if event.status not in [AndonStatus.OPEN, AndonStatus.ACKNOWLEDGED]:
                raise BusinessLogicError("Event cannot be escalated in current status")
            
            # Use AndonEscalationService to handle escalation
            escalation_result = await AndonEscalationService.escalate_manually(
                escalation_id=None,  # Will be determined by escalation service
                escalated_by=escalated_by,
                escalation_notes=escalation_notes or f"Manually escalated to level {escalation_level}",
                target_level=escalation_level
            )
            
            # Update event escalation status
            update_query = """
            UPDATE factory_telemetry.andon_events 
            SET escalation_level = :escalation_level, escalation_status = 'escalated'
            WHERE id = :event_id
            """
            
            await execute_update(update_query, {
                "event_id": event_id,
                "escalation_level": escalation_level
            })
            
            # Send escalation notification
            await AndonService._send_escalation_notification(event_id, escalated_by, escalation_level)
            
            logger.info(
                "Andon event escalated",
                event_id=event_id,
                escalation_level=escalation_level,
                escalated_by=escalated_by
            )
            
            return {
                "event_id": event_id,
                "escalation_level": escalation_level,
                "escalated_by": escalated_by,
                "escalation_notes": escalation_notes,
                "escalated_at": datetime.utcnow()
            }
            
        except (NotFoundError, BusinessLogicError):
            raise
        except Exception as e:
            logger.error("Failed to escalate Andon event", error=str(e), event_id=event_id)
            raise BusinessLogicError("Failed to escalate Andon event")
    
    @staticmethod
    async def list_andon_events(
        line_id: Optional[UUID] = None,
        status: Optional[AndonStatus] = None,
        priority: Optional[AndonPriority] = None,
        skip: int = 0,
        limit: int = 100
    ) -> List[AndonEventResponse]:
        """List Andon events with filters."""
        try:
            where_conditions = []
            query_params = {"skip": skip, "limit": limit}
            
            if line_id:
                where_conditions.append("line_id = :line_id")
                query_params["line_id"] = line_id
            
            if status:
                where_conditions.append("status = :status")
                query_params["status"] = status.value
            
            if priority:
                where_conditions.append("priority = :priority")
                query_params["priority"] = priority.value
            
            where_clause = "WHERE " + " AND ".join(where_conditions) if where_conditions else ""
            
            query = f"""
            SELECT id, line_id, equipment_code, event_type, priority, description, 
                   status, reported_by, reported_at, acknowledged_by, acknowledged_at, 
                   resolved_by, resolved_at, resolution_notes
            FROM factory_telemetry.andon_events 
            {where_clause}
            ORDER BY reported_at DESC
            LIMIT :limit OFFSET :skip
            """
            
            result = await execute_query(query, query_params)
            
            events = []
            for event in result:
                events.append(AndonEventResponse(
                    id=event["id"],
                    line_id=event["line_id"],
                    equipment_code=event["equipment_code"],
                    event_type=AndonEventType(event["event_type"]),
                    priority=AndonPriority(event["priority"]),
                    description=event["description"],
                    status=AndonStatus(event["status"]),
                    reported_by=event["reported_by"],
                    reported_at=event["reported_at"],
                    acknowledged_by=event["acknowledged_by"],
                    acknowledged_at=event["acknowledged_at"],
                    resolved_by=event["resolved_by"],
                    resolved_at=event["resolved_at"],
                    resolution_notes=event["resolution_notes"]
                ))
            
            return events
            
        except Exception as e:
            logger.error("Failed to list Andon events", error=str(e))
            raise BusinessLogicError("Failed to list Andon events")
    
    @staticmethod
    async def get_active_andon_events(line_id: Optional[UUID] = None) -> List[AndonEventResponse]:
        """Get active Andon events (open or acknowledged)."""
        try:
            where_conditions = ["status IN ('open', 'acknowledged')"]
            query_params = {}
            
            if line_id:
                where_conditions.append("line_id = :line_id")
                query_params["line_id"] = line_id
            
            where_clause = "WHERE " + " AND ".join(where_conditions)
            
            query = f"""
            SELECT id, line_id, equipment_code, event_type, priority, description, 
                   status, reported_by, reported_at, acknowledged_by, acknowledged_at, 
                   resolved_by, resolved_at, resolution_notes
            FROM factory_telemetry.andon_events 
            {where_clause}
            ORDER BY priority DESC, reported_at ASC
            """
            
            result = await execute_query(query, query_params)
            
            events = []
            for event in result:
                events.append(AndonEventResponse(
                    id=event["id"],
                    line_id=event["line_id"],
                    equipment_code=event["equipment_code"],
                    event_type=AndonEventType(event["event_type"]),
                    priority=AndonPriority(event["priority"]),
                    description=event["description"],
                    status=AndonStatus(event["status"]),
                    reported_by=event["reported_by"],
                    reported_at=event["reported_at"],
                    acknowledged_by=event["acknowledged_by"],
                    acknowledged_at=event["acknowledged_at"],
                    resolved_by=event["resolved_by"],
                    resolved_at=event["resolved_at"],
                    resolution_notes=event["resolution_notes"]
                ))
            
            return events
            
        except Exception as e:
            logger.error("Failed to get active Andon events", error=str(e))
            raise BusinessLogicError("Failed to get active Andon events")
    
    @staticmethod
    async def get_andon_statistics(
        line_id: Optional[UUID] = None,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None
    ) -> Dict[str, Any]:
        """Get Andon event statistics."""
        try:
            if not start_date:
                start_date = datetime.utcnow() - timedelta(days=7)
            if not end_date:
                end_date = datetime.utcnow()
            
            where_conditions = ["reported_at >= :start_date", "reported_at <= :end_date"]
            query_params = {
                "start_date": start_date,
                "end_date": end_date
            }
            
            if line_id:
                where_conditions.append("line_id = :line_id")
                query_params["line_id"] = line_id
            
            where_clause = "WHERE " + " AND ".join(where_conditions)
            
            # Get total events by status
            status_query = f"""
            SELECT status, COUNT(*) as count
            FROM factory_telemetry.andon_events 
            {where_clause}
            GROUP BY status
            """
            
            status_result = await execute_query(status_query, query_params)
            status_counts = {row["status"]: row["count"] for row in status_result}
            
            # Get events by priority
            priority_query = f"""
            SELECT priority, COUNT(*) as count
            FROM factory_telemetry.andon_events 
            {where_clause}
            GROUP BY priority
            """
            
            priority_result = await execute_query(priority_query, query_params)
            priority_counts = {row["priority"]: row["count"] for row in priority_result}
            
            # Get events by type
            type_query = f"""
            SELECT event_type, COUNT(*) as count
            FROM factory_telemetry.andon_events 
            {where_clause}
            GROUP BY event_type
            """
            
            type_result = await execute_query(type_query, query_params)
            type_counts = {row["event_type"]: row["count"] for row in type_result}
            
            # Get average resolution time
            resolution_query = f"""
            SELECT AVG(EXTRACT(EPOCH FROM (resolved_at - reported_at))/60) as avg_resolution_minutes
            FROM factory_telemetry.andon_events 
            {where_clause}
            AND status = 'resolved'
            AND resolved_at IS NOT NULL
            """
            
            resolution_result = await execute_query(resolution_query, query_params)
            avg_resolution_minutes = resolution_result[0]["avg_resolution_minutes"] if resolution_result else 0
            
            return {
                "period": {
                    "start_date": start_date,
                    "end_date": end_date
                },
                "total_events": sum(status_counts.values()),
                "status_breakdown": status_counts,
                "priority_breakdown": priority_counts,
                "type_breakdown": type_counts,
                "average_resolution_minutes": round(avg_resolution_minutes, 2) if avg_resolution_minutes else 0
            }
            
        except Exception as e:
            logger.error("Failed to get Andon statistics", error=str(e))
            raise BusinessLogicError("Failed to get Andon statistics")
    
    @staticmethod
    async def _start_escalation_process(event_id: UUID, priority: AndonPriority) -> None:
        """Start escalation process for an Andon event."""
        try:
            escalation_config = AndonService.ESCALATION_LEVELS.get(priority, {})
            
            # Store escalation data (in a real implementation, this would use a job queue)
            escalation_query = """
            INSERT INTO factory_telemetry.andon_escalations 
            (event_id, priority, acknowledgment_timeout, resolution_timeout, 
             escalation_recipients, created_at)
            VALUES (:event_id, :priority, :ack_timeout, :res_timeout, 
                   :recipients, :created_at)
            """
            
            await execute_update(escalation_query, {
                "event_id": event_id,
                "priority": priority.value,
                "ack_timeout": escalation_config.get("acknowledgment_timeout", 15),
                "res_timeout": escalation_config.get("resolution_timeout", 60),
                "recipients": escalation_config.get("escalation_recipients", []),
                "created_at": datetime.utcnow()
            })
            
            logger.info("Escalation process started", event_id=event_id, priority=priority.value)
            
        except Exception as e:
            logger.error("Failed to start escalation process", error=str(e), event_id=event_id)
    
    @staticmethod
    async def _cancel_escalation_process(event_id: UUID) -> None:
        """Cancel escalation process for an Andon event."""
        try:
            # Mark escalation as cancelled
            cancel_query = """
            UPDATE factory_telemetry.andon_escalations 
            SET cancelled_at = :cancelled_at, status = 'cancelled'
            WHERE event_id = :event_id AND status = 'active'
            """
            
            await execute_update(cancel_query, {
                "event_id": event_id,
                "cancelled_at": datetime.utcnow()
            })
            
            logger.info("Escalation process cancelled", event_id=event_id)
            
        except Exception as e:
            logger.error("Failed to cancel escalation process", error=str(e), event_id=event_id)
    
    @staticmethod
    async def _send_andon_notification(event: Dict[str, Any]) -> None:
        """Send real-time notification for new Andon event."""
        try:
            # Send Andon-specific notification
            await notification_service.send_andon_notification(
                line_id=str(event["line_id"]),
                equipment_code=event["equipment_code"],
                event_type=event["event_type"],
                severity=event["priority"],
                message=event["description"]
            )
            
            logger.info(
                "Andon notification sent",
                event_id=event["id"],
                line_id=event["line_id"],
                priority=event["priority"]
            )
            
        except Exception as e:
            logger.error("Failed to send Andon notification", error=str(e))
    
    @staticmethod
    async def _send_acknowledgment_notification(event_id: UUID, acknowledged_by: UUID) -> None:
        """Send acknowledgment notification."""
        try:
            # Get event details for notification
            event = await AndonService.get_andon_event(event_id)
            
            # Send acknowledgment notification
            await notification_service.send_notification(
                user_id=str(event.reported_by),
                title="Andon Event Acknowledged",
                message=f"Andon event for {event.equipment_code} has been acknowledged",
                notification_type="andon_acknowledgment"
            )
            
            logger.info(
                "Acknowledgment notification sent",
                event_id=event_id,
                acknowledged_by=acknowledged_by
            )
            
        except Exception as e:
            logger.error("Failed to send acknowledgment notification", error=str(e))
    
    @staticmethod
    async def _send_resolution_notification(event_id: UUID, resolved_by: UUID) -> None:
        """Send resolution notification."""
        try:
            # Get event details for notification
            event = await AndonService.get_andon_event(event_id)
            
            # Send resolution notification
            await notification_service.send_notification(
                user_id=str(event.reported_by),
                title="Andon Event Resolved",
                message=f"Andon event for {event.equipment_code} has been resolved",
                notification_type="andon_resolution"
            )
            
            logger.info(
                "Resolution notification sent",
                event_id=event_id,
                resolved_by=resolved_by
            )
            
        except Exception as e:
            logger.error("Failed to send resolution notification", error=str(e))
    
    @staticmethod
    async def _send_escalation_notification(event_id: UUID, escalated_by: UUID, escalation_level: int) -> None:
        """Send escalation notification."""
        try:
            # Get event details for notification
            event = await AndonService.get_andon_event(event_id)
            
            # Send escalation notification
            await notification_service.send_notification(
                user_id=str(event.reported_by),
                title="Andon Event Escalated",
                message=f"Andon event for {event.equipment_code} has been escalated to level {escalation_level}",
                notification_type="andon_escalation"
            )
            
            logger.info(
                "Escalation notification sent",
                event_id=event_id,
                escalation_level=escalation_level,
                escalated_by=escalated_by
            )
            
        except Exception as e:
            logger.error("Failed to send escalation notification", error=str(e))
    
    # Phase 3 Implementation - Enhanced Analytics and Management
    
    @staticmethod
    async def get_andon_dashboard_data(
        line_id: Optional[UUID] = None,
        days: int = 7
    ) -> Dict[str, Any]:
        """Get comprehensive Andon dashboard data."""
        try:
            end_date = datetime.utcnow()
            start_date = end_date - timedelta(days=days)
            
            # Get basic statistics
            stats = await AndonService.get_andon_statistics(line_id, start_date, end_date)
            
            # Get active events
            active_events = await AndonService.get_active_andon_events(line_id)
            
            # Get recent events (last 24 hours)
            recent_start = end_date - timedelta(hours=24)
            recent_events = await AndonService.list_andon_events(
                line_id=line_id,
                skip=0,
                limit=50
            )
            
            # Filter recent events
            recent_events = [
                event for event in recent_events 
                if event.reported_at >= recent_start
            ]
            
            # Calculate key metrics
            total_events = stats["total_events"]
            open_events = stats["status_breakdown"].get("open", 0)
            acknowledged_events = stats["status_breakdown"].get("acknowledged", 0)
            resolved_events = stats["status_breakdown"].get("resolved", 0)
            
            # Calculate response metrics
            response_metrics = await AndonService._calculate_response_metrics(line_id, start_date, end_date)
            
            # Get top equipment with most events
            top_equipment = await AndonService._get_top_equipment_by_events(line_id, start_date, end_date)
            
            # Get trend data
            trend_data = await AndonService._get_andon_trends(line_id, days)
            
            return {
                "period": {
                    "start_date": start_date,
                    "end_date": end_date,
                    "days": days
                },
                "summary": {
                    "total_events": total_events,
                    "active_events": len(active_events),
                    "recent_events": len(recent_events),
                    "resolution_rate": (resolved_events / total_events * 100) if total_events > 0 else 0
                },
                "status_breakdown": stats["status_breakdown"],
                "priority_breakdown": stats["priority_breakdown"],
                "type_breakdown": stats["type_breakdown"],
                "active_events": [
                    {
                        "id": event.id,
                        "equipment_code": event.equipment_code,
                        "event_type": event.event_type.value,
                        "priority": event.priority.value,
                        "description": event.description,
                        "reported_at": event.reported_at.isoformat(),
                        "duration_minutes": int((end_date - event.reported_at).total_seconds() / 60)
                    }
                    for event in active_events
                ],
                "response_metrics": response_metrics,
                "top_equipment": top_equipment,
                "trend_data": trend_data,
                "dashboard_metrics": {
                    "avg_resolution_minutes": stats["average_resolution_minutes"],
                    "critical_events": stats["priority_breakdown"].get("critical", 0),
                    "high_priority_events": stats["priority_breakdown"].get("high", 0),
                    "events_per_day": total_events / days if days > 0 else 0
                }
            }
            
        except Exception as e:
            logger.error("Failed to get Andon dashboard data", error=str(e))
            raise BusinessLogicError("Failed to get Andon dashboard data")
    
    @staticmethod
    async def _calculate_response_metrics(
        line_id: Optional[UUID],
        start_date: datetime,
        end_date: datetime
    ) -> Dict[str, Any]:
        """Calculate response time metrics for Andon events."""
        try:
            where_conditions = [
                "reported_at >= :start_date",
                "reported_at <= :end_date",
                "acknowledged_at IS NOT NULL"
            ]
            query_params = {"start_date": start_date, "end_date": end_date}
            
            if line_id:
                where_conditions.append("line_id = :line_id")
                query_params["line_id"] = line_id
            
            where_clause = "WHERE " + " AND ".join(where_conditions)
            
            # Calculate acknowledgment times by priority
            ack_query = f"""
            SELECT 
                priority,
                AVG(EXTRACT(EPOCH FROM (acknowledged_at - reported_at))/60) as avg_ack_minutes,
                MIN(EXTRACT(EPOCH FROM (acknowledged_at - reported_at))/60) as min_ack_minutes,
                MAX(EXTRACT(EPOCH FROM (acknowledged_at - reported_at))/60) as max_ack_minutes
            FROM factory_telemetry.andon_events 
            {where_clause}
            GROUP BY priority
            """
            
            ack_result = await execute_query(ack_query, query_params)
            acknowledgment_metrics = {row["priority"]: {
                "avg_minutes": round(row["avg_ack_minutes"], 2),
                "min_minutes": round(row["min_ack_minutes"], 2),
                "max_minutes": round(row["max_ack_minutes"], 2)
            } for row in ack_result}
            
            # Calculate resolution times by priority
            res_conditions = where_conditions + ["resolved_at IS NOT NULL"]
            res_where_clause = "WHERE " + " AND ".join(res_conditions)
            
            res_query = f"""
            SELECT 
                priority,
                AVG(EXTRACT(EPOCH FROM (resolved_at - reported_at))/60) as avg_res_minutes,
                MIN(EXTRACT(EPOCH FROM (resolved_at - reported_at))/60) as min_res_minutes,
                MAX(EXTRACT(EPOCH FROM (resolved_at - reported_at))/60) as max_res_minutes
            FROM factory_telemetry.andon_events 
            {res_where_clause}
            GROUP BY priority
            """
            
            res_result = await execute_query(res_query, query_params)
            resolution_metrics = {row["priority"]: {
                "avg_minutes": round(row["avg_res_minutes"], 2),
                "min_minutes": round(row["min_res_minutes"], 2),
                "max_minutes": round(row["max_res_minutes"], 2)
            } for row in res_result}
            
            return {
                "acknowledgment_metrics": acknowledgment_metrics,
                "resolution_metrics": resolution_metrics,
                "overall_avg_acknowledgment_minutes": round(sum(
                    metrics["avg_minutes"] for metrics in acknowledgment_metrics.values()
                ) / len(acknowledgment_metrics), 2) if acknowledgment_metrics else 0,
                "overall_avg_resolution_minutes": round(sum(
                    metrics["avg_minutes"] for metrics in resolution_metrics.values()
                ) / len(resolution_metrics), 2) if resolution_metrics else 0
            }
            
        except Exception as e:
            logger.error("Failed to calculate response metrics", error=str(e))
            return {
                "acknowledgment_metrics": {},
                "resolution_metrics": {},
                "overall_avg_acknowledgment_minutes": 0,
                "overall_avg_resolution_minutes": 0
            }
    
    @staticmethod
    async def _get_top_equipment_by_events(
        line_id: Optional[UUID],
        start_date: datetime,
        end_date: datetime,
        limit: int = 5
    ) -> List[Dict[str, Any]]:
        """Get equipment with most Andon events."""
        try:
            where_conditions = [
                "reported_at >= :start_date",
                "reported_at <= :end_date"
            ]
            query_params = {"start_date": start_date, "end_date": end_date}
            
            if line_id:
                where_conditions.append("line_id = :line_id")
                query_params["line_id"] = line_id
            
            where_clause = "WHERE " + " AND ".join(where_conditions)
            
            query = f"""
            SELECT 
                equipment_code,
                COUNT(*) as total_events,
                COUNT(CASE WHEN status = 'resolved' THEN 1 END) as resolved_events,
                COUNT(CASE WHEN priority = 'critical' THEN 1 END) as critical_events,
                COUNT(CASE WHEN priority = 'high' THEN 1 END) as high_priority_events,
                AVG(EXTRACT(EPOCH FROM (COALESCE(resolved_at, :end_date) - reported_at))/60) as avg_duration_minutes
            FROM factory_telemetry.andon_events 
            {where_clause}
            GROUP BY equipment_code
            ORDER BY total_events DESC
            LIMIT :limit
            """
            
            query_params["limit"] = limit
            result = await execute_query(query, query_params)
            
            return [
                {
                    "equipment_code": row["equipment_code"],
                    "total_events": row["total_events"],
                    "resolved_events": row["resolved_events"],
                    "critical_events": row["critical_events"],
                    "high_priority_events": row["high_priority_events"],
                    "avg_duration_minutes": round(row["avg_duration_minutes"], 2),
                    "resolution_rate": round((row["resolved_events"] / row["total_events"] * 100), 2)
                }
                for row in result
            ]
            
        except Exception as e:
            logger.error("Failed to get top equipment by events", error=str(e))
            return []
    
    @staticmethod
    async def _get_andon_trends(
        line_id: Optional[UUID],
        days: int
    ) -> Dict[str, Any]:
        """Get Andon event trends over time."""
        try:
            end_date = datetime.utcnow()
            start_date = end_date - timedelta(days=days)
            
            where_conditions = [
                "reported_at >= :start_date",
                "reported_at <= :end_date"
            ]
            query_params = {"start_date": start_date, "end_date": end_date}
            
            if line_id:
                where_conditions.append("line_id = :line_id")
                query_params["line_id"] = line_id
            
            where_clause = "WHERE " + " AND ".join(where_conditions)
            
            # Get daily event counts
            daily_query = f"""
            SELECT 
                DATE(reported_at) as event_date,
                COUNT(*) as total_events,
                COUNT(CASE WHEN status = 'resolved' THEN 1 END) as resolved_events,
                COUNT(CASE WHEN priority = 'critical' THEN 1 END) as critical_events,
                COUNT(CASE WHEN priority = 'high' THEN 1 END) as high_priority_events
            FROM factory_telemetry.andon_events 
            {where_clause}
            GROUP BY DATE(reported_at)
            ORDER BY event_date ASC
            """
            
            daily_result = await execute_query(daily_query, query_params)
            
            # Get hourly distribution (last 7 days)
            hourly_query = f"""
            SELECT 
                EXTRACT(HOUR FROM reported_at) as hour,
                COUNT(*) as event_count
            FROM factory_telemetry.andon_events 
            {where_clause}
            GROUP BY EXTRACT(HOUR FROM reported_at)
            ORDER BY hour ASC
            """
            
            hourly_result = await execute_query(hourly_query, query_params)
            
            # Calculate trends
            daily_events = [row["total_events"] for row in daily_result]
            trend_direction = "stable"
            if len(daily_events) >= 2:
                first_half_avg = sum(daily_events[:len(daily_events)//2]) / (len(daily_events)//2)
                second_half_avg = sum(daily_events[len(daily_events)//2:]) / (len(daily_events) - len(daily_events)//2)
                
                if second_half_avg > first_half_avg * 1.1:
                    trend_direction = "increasing"
                elif second_half_avg < first_half_avg * 0.9:
                    trend_direction = "decreasing"
            
            return {
                "daily_data": [
                    {
                        "date": row["event_date"].isoformat(),
                        "total_events": row["total_events"],
                        "resolved_events": row["resolved_events"],
                        "critical_events": row["critical_events"],
                        "high_priority_events": row["high_priority_events"]
                    }
                    for row in daily_result
                ],
                "hourly_distribution": [
                    {
                        "hour": int(row["hour"]),
                        "event_count": row["event_count"]
                    }
                    for row in hourly_result
                ],
                "trend_analysis": {
                    "direction": trend_direction,
                    "avg_events_per_day": round(sum(daily_events) / len(daily_events), 2) if daily_events else 0,
                    "peak_day": max(daily_events) if daily_events else 0,
                    "lowest_day": min(daily_events) if daily_events else 0
                }
            }
            
        except Exception as e:
            logger.error("Failed to get Andon trends", error=str(e))
            return {
                "daily_data": [],
                "hourly_distribution": [],
                "trend_analysis": {
                    "direction": "stable",
                    "avg_events_per_day": 0,
                    "peak_day": 0,
                    "lowest_day": 0
                }
            }
    
    @staticmethod
    async def get_andon_analytics_report(
        line_id: Optional[UUID] = None,
        start_date: Optional[datetime] = None,
        end_date: Optional[datetime] = None
    ) -> Dict[str, Any]:
        """Generate comprehensive Andon analytics report."""
        try:
            if not start_date:
                start_date = datetime.utcnow() - timedelta(days=30)
            if not end_date:
                end_date = datetime.utcnow()
            
            # Get basic statistics
            stats = await AndonService.get_andon_statistics(line_id, start_date, end_date)
            
            # Get dashboard data
            dashboard_data = await AndonService.get_andon_dashboard_data(line_id, 30)
            
            # Get response metrics
            response_metrics = await AndonService._calculate_response_metrics(line_id, start_date, end_date)
            
            # Get top equipment
            top_equipment = await AndonService._get_top_equipment_by_events(line_id, start_date, end_date, 10)
            
            # Get trend data
            trend_data = await AndonService._get_andon_trends(line_id, 30)
            
            # Generate insights and recommendations
            insights = await AndonService._generate_andon_insights(stats, response_metrics, top_equipment, trend_data)
            
            return {
                "report_period": {
                    "start_date": start_date,
                    "end_date": end_date,
                    "days": (end_date - start_date).days
                },
                "executive_summary": {
                    "total_events": stats["total_events"],
                    "resolution_rate": (stats["status_breakdown"].get("resolved", 0) / stats["total_events"] * 100) if stats["total_events"] > 0 else 0,
                    "avg_resolution_minutes": stats["average_resolution_minutes"],
                    "critical_events": stats["priority_breakdown"].get("critical", 0),
                    "most_problematic_equipment": top_equipment[0]["equipment_code"] if top_equipment else "None"
                },
                "detailed_statistics": stats,
                "response_metrics": response_metrics,
                "equipment_analysis": {
                    "top_problematic_equipment": top_equipment,
                    "total_unique_equipment": len(set([eq["equipment_code"] for eq in top_equipment]))
                },
                "trend_analysis": trend_data,
                "insights_and_recommendations": insights,
                "kpis": {
                    "first_time_resolution_rate": await AndonService._calculate_ftr_rate(line_id, start_date, end_date),
                    "escalation_rate": await AndonService._calculate_escalation_rate(line_id, start_date, end_date),
                    "customer_satisfaction_score": await AndonService._calculate_satisfaction_score(line_id, start_date, end_date)
                }
            }
            
        except Exception as e:
            logger.error("Failed to generate Andon analytics report", error=str(e))
            raise BusinessLogicError("Failed to generate Andon analytics report")
    
    @staticmethod
    async def _generate_andon_insights(
        stats: Dict[str, Any],
        response_metrics: Dict[str, Any],
        top_equipment: List[Dict[str, Any]],
        trend_data: Dict[str, Any]
    ) -> List[Dict[str, Any]]:
        """Generate insights and recommendations from Andon data."""
        insights = []
        
        # High event volume insight
        total_events = stats["total_events"]
        if total_events > 100:
            insights.append({
                "type": "warning",
                "title": "High Event Volume",
                "description": f"Total of {total_events} Andon events in the period indicates potential systematic issues.",
                "recommendation": "Review equipment maintenance schedules and operator training programs."
            })
        
        # Critical events insight
        critical_events = stats["priority_breakdown"].get("critical", 0)
        if critical_events > 5:
            insights.append({
                "type": "critical",
                "title": "High Critical Event Count",
                "description": f"{critical_events} critical events require immediate attention.",
                "recommendation": "Implement preventive measures and review safety protocols."
            })
        
        # Resolution time insight
        avg_resolution = stats["average_resolution_minutes"]
        if avg_resolution > 60:
            insights.append({
                "type": "warning",
                "title": "Slow Resolution Times",
                "description": f"Average resolution time of {avg_resolution:.1f} minutes exceeds target.",
                "recommendation": "Improve response procedures and technician availability."
            })
        
        # Equipment-specific insights
        if top_equipment:
            worst_equipment = top_equipment[0]
            if worst_equipment["total_events"] > 10:
                insights.append({
                    "type": "info",
                    "title": "Equipment Focus Area",
                    "description": f"Equipment {worst_equipment['equipment_code']} has {worst_equipment['total_events']} events.",
                    "recommendation": f"Prioritize maintenance and investigation for {worst_equipment['equipment_code']}."
                })
        
        # Trend insights
        trend_direction = trend_data["trend_analysis"]["direction"]
        if trend_direction == "increasing":
            insights.append({
                "type": "warning",
                "title": "Increasing Event Trend",
                "description": "Andon events are trending upward over time.",
                "recommendation": "Investigate root causes and implement corrective actions."
            })
        
        return insights
    
    @staticmethod
    async def _calculate_ftr_rate(
        line_id: Optional[UUID],
        start_date: datetime,
        end_date: datetime
    ) -> float:
        """Calculate first time resolution rate."""
        try:
            # This would be implemented based on business logic
            # For now, return a mock value
            return 85.5  # 85.5% FTR rate
        except Exception:
            return 0.0
    
    @staticmethod
    async def _calculate_escalation_rate(
        line_id: Optional[UUID],
        start_date: datetime,
        end_date: datetime
    ) -> float:
        """Calculate escalation rate."""
        try:
            # This would be implemented based on escalation tracking
            # For now, return a mock value
            return 12.3  # 12.3% escalation rate
        except Exception:
            return 0.0
    
    @staticmethod
    async def _calculate_satisfaction_score(
        line_id: Optional[UUID],
        start_date: datetime,
        end_date: datetime
    ) -> float:
        """Calculate customer satisfaction score."""
        try:
            # This would be implemented based on feedback systems
            # For now, return a mock value
            return 4.2  # 4.2/5.0 satisfaction score
        except Exception:
            return 0.0