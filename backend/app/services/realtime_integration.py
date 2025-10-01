"""
MS5.0 Floor Dashboard - Real-time Integration Service

This module provides integration hooks for existing services to automatically
broadcast real-time events via WebSocket when data changes occur.

Architected for cosmic scale operations - the nervous system of a starship.
"""

import asyncio
from typing import Dict, Any, Optional, Callable
from datetime import datetime
import structlog

from app.services.realtime_event_broadcaster import realtime_broadcaster

logger = structlog.get_logger()


class RealTimeIntegrationService:
    """
    Real-time integration service that provides hooks and decorators
    for existing services to automatically broadcast events.
    
    Features:
    - Automatic event broadcasting on data changes
    - Integration decorators for service methods
    - Event subscription management
    - Performance monitoring and optimization
    """
    
    def __init__(self):
        self.integration_hooks: Dict[str, List[Callable]] = {}
        self.broadcast_enabled = True
        
        logger.info("Real-time Integration Service initialized")
    
    def enable_broadcasting(self) -> None:
        """Enable real-time event broadcasting."""
        self.broadcast_enabled = True
        logger.info("Real-time broadcasting enabled")
    
    def disable_broadcasting(self) -> None:
        """Disable real-time event broadcasting."""
        self.broadcast_enabled = False
        logger.info("Real-time broadcasting disabled")
    
    def add_integration_hook(self, event_type: str, callback: Callable) -> None:
        """Add integration hook for specific event type."""
        if event_type not in self.integration_hooks:
            self.integration_hooks[event_type] = []
        
        self.integration_hooks[event_type].append(callback)
        logger.debug("Integration hook added", event_type=event_type)
    
    def remove_integration_hook(self, event_type: str, callback: Callable) -> None:
        """Remove integration hook for specific event type."""
        if event_type in self.integration_hooks:
            self.integration_hooks[event_type].remove(callback)
            
            if not self.integration_hooks[event_type]:
                del self.integration_hooks[event_type]
        
        logger.debug("Integration hook removed", event_type=event_type)
    
    async def trigger_integration_hooks(self, event_type: str, data: Dict[str, Any]) -> None:
        """Trigger all integration hooks for specific event type."""
        if not self.broadcast_enabled:
            return
        
        hooks = self.integration_hooks.get(event_type, [])
        
        for hook in hooks:
            try:
                if asyncio.iscoroutinefunction(hook):
                    await hook(data)
                else:
                    hook(data)
            except Exception as e:
                logger.error("Error in integration hook", 
                           event_type=event_type, error=str(e))
    
    # ============================================================================
    # PRODUCTION SERVICE INTEGRATION
    # ============================================================================
    
    async def on_production_data_updated(self, line_id: str, production_data: Dict[str, Any]) -> None:
        """Handle production data update."""
        await self.trigger_integration_hooks("production_data_updated", {
            "line_id": line_id,
            "production_data": production_data
        })
        
        if self.broadcast_enabled:
            await realtime_broadcaster.broadcast_production_update(line_id, production_data)
    
    async def on_line_status_changed(self, line_id: str, old_status: str, new_status: str) -> None:
        """Handle line status change."""
        await self.trigger_integration_hooks("line_status_changed", {
            "line_id": line_id,
            "old_status": old_status,
            "new_status": new_status
        })
        
        if self.broadcast_enabled:
            await realtime_broadcaster.broadcast_line_status_update(line_id, {
                "old_status": old_status,
                "new_status": new_status,
                "changed_at": datetime.utcnow().isoformat()
            })
    
    async def on_job_assigned(self, job_data: Dict[str, Any]) -> None:
        """Handle job assignment."""
        await self.trigger_integration_hooks("job_assigned", job_data)
        
        if self.broadcast_enabled:
            await realtime_broadcaster.broadcast_job_assignment(job_data)
    
    async def on_job_started(self, job_data: Dict[str, Any]) -> None:
        """Handle job started."""
        await self.trigger_integration_hooks("job_started", job_data)
        
        if self.broadcast_enabled:
            await realtime_broadcaster.broadcast_job_started(job_data)
    
    async def on_job_completed(self, job_data: Dict[str, Any]) -> None:
        """Handle job completed."""
        await self.trigger_integration_hooks("job_completed", job_data)
        
        if self.broadcast_enabled:
            await realtime_broadcaster.broadcast_job_completed(job_data)
    
    async def on_job_cancelled(self, job_data: Dict[str, Any]) -> None:
        """Handle job cancelled."""
        await self.trigger_integration_hooks("job_cancelled", job_data)
        
        if self.broadcast_enabled:
            await realtime_broadcaster.broadcast_job_cancelled(job_data)
    
    # ============================================================================
    # OEE SERVICE INTEGRATION
    # ============================================================================
    
    async def on_oee_calculated(self, line_id: str, oee_data: Dict[str, Any]) -> None:
        """Handle OEE calculation completion."""
        await self.trigger_integration_hooks("oee_calculated", {
            "line_id": line_id,
            "oee_data": oee_data
        })
        
        if self.broadcast_enabled:
            await realtime_broadcaster.broadcast_oee_update(line_id, oee_data)
            await realtime_broadcaster.broadcast_oee_calculation_completed(line_id, oee_data)
    
    async def on_oee_threshold_exceeded(self, line_id: str, threshold_data: Dict[str, Any]) -> None:
        """Handle OEE threshold exceeded."""
        await self.trigger_integration_hooks("oee_threshold_exceeded", {
            "line_id": line_id,
            "threshold_data": threshold_data
        })
        
        if self.broadcast_enabled:
            # Broadcast as quality alert
            await realtime_broadcaster.broadcast_quality_alert({
                "line_id": line_id,
                "type": "oee_threshold_exceeded",
                "severity": "high",
                "threshold_data": threshold_data
            })
    
    # ============================================================================
    # ANDON SERVICE INTEGRATION
    # ============================================================================
    
    async def on_andon_event_created(self, andon_event: Dict[str, Any]) -> None:
        """Handle Andon event creation."""
        await self.trigger_integration_hooks("andon_event_created", andon_event)
        
        if self.broadcast_enabled:
            await realtime_broadcaster.broadcast_andon_event(andon_event)
    
    async def on_andon_event_updated(self, andon_event: Dict[str, Any]) -> None:
        """Handle Andon event update."""
        await self.trigger_integration_hooks("andon_event_updated", andon_event)
        
        if self.broadcast_enabled:
            await realtime_broadcaster.broadcast_andon_event(andon_event)
    
    async def on_andon_event_resolved(self, andon_event: Dict[str, Any]) -> None:
        """Handle Andon event resolution."""
        await self.trigger_integration_hooks("andon_event_resolved", andon_event)
        
        if self.broadcast_enabled:
            await realtime_broadcaster.broadcast_andon_event(andon_event)
    
    async def on_andon_escalation_triggered(self, escalation_data: Dict[str, Any]) -> None:
        """Handle Andon escalation."""
        await self.trigger_integration_hooks("andon_escalation_triggered", escalation_data)
        
        if self.broadcast_enabled:
            await realtime_broadcaster.broadcast_andon_escalation(escalation_data)
    
    # ============================================================================
    # EQUIPMENT SERVICE INTEGRATION
    # ============================================================================
    
    async def on_equipment_status_changed(self, equipment_code: str, old_status: str, new_status: str) -> None:
        """Handle equipment status change."""
        await self.trigger_integration_hooks("equipment_status_changed", {
            "equipment_code": equipment_code,
            "old_status": old_status,
            "new_status": new_status
        })
        
        if self.broadcast_enabled:
            await realtime_broadcaster.broadcast_equipment_status_update(equipment_code, {
                "old_status": old_status,
                "new_status": new_status,
                "changed_at": datetime.utcnow().isoformat()
            })
    
    async def on_equipment_fault_occurred(self, fault_data: Dict[str, Any]) -> None:
        """Handle equipment fault occurrence."""
        await self.trigger_integration_hooks("equipment_fault_occurred", fault_data)
        
        if self.broadcast_enabled:
            await realtime_broadcaster.broadcast_equipment_fault(fault_data)
    
    async def on_equipment_fault_resolved(self, fault_data: Dict[str, Any]) -> None:
        """Handle equipment fault resolution."""
        await self.trigger_integration_hooks("equipment_fault_resolved", fault_data)
        
        if self.broadcast_enabled:
            await realtime_broadcaster.broadcast_equipment_fault_resolved(fault_data)
    
    async def on_equipment_maintenance_scheduled(self, maintenance_data: Dict[str, Any]) -> None:
        """Handle equipment maintenance scheduling."""
        await self.trigger_integration_hooks("equipment_maintenance_scheduled", maintenance_data)
        
        if self.broadcast_enabled:
            await realtime_broadcaster.broadcast_equipment_status_update(
                maintenance_data.get("equipment_code"), 
                {"maintenance_scheduled": maintenance_data}
            )
    
    # ============================================================================
    # QUALITY SERVICE INTEGRATION
    # ============================================================================
    
    async def on_quality_check_completed(self, check_data: Dict[str, Any]) -> None:
        """Handle quality check completion."""
        await self.trigger_integration_hooks("quality_check_completed", check_data)
        
        if self.broadcast_enabled:
            await realtime_broadcaster.broadcast_quality_check_completed(check_data)
    
    async def on_quality_alert_triggered(self, alert_data: Dict[str, Any]) -> None:
        """Handle quality alert."""
        await self.trigger_integration_hooks("quality_alert_triggered", alert_data)
        
        if self.broadcast_enabled:
            await realtime_broadcaster.broadcast_quality_alert(alert_data)
    
    async def on_quality_threshold_exceeded(self, threshold_data: Dict[str, Any]) -> None:
        """Handle quality threshold exceeded."""
        await self.trigger_integration_hooks("quality_threshold_exceeded", threshold_data)
        
        if self.broadcast_enabled:
            await realtime_broadcaster.broadcast_quality_alert(threshold_data)
    
    # ============================================================================
    # DOWNTIME SERVICE INTEGRATION
    # ============================================================================
    
    async def on_downtime_started(self, downtime_data: Dict[str, Any]) -> None:
        """Handle downtime start."""
        await self.trigger_integration_hooks("downtime_started", downtime_data)
        
        if self.broadcast_enabled:
            await realtime_broadcaster.broadcast_downtime_event(downtime_data)
    
    async def on_downtime_ended(self, downtime_data: Dict[str, Any]) -> None:
        """Handle downtime end."""
        await self.trigger_integration_hooks("downtime_ended", downtime_data)
        
        if self.broadcast_enabled:
            await realtime_broadcaster.broadcast_downtime_event(downtime_data)
    
    async def on_downtime_statistics_updated(self, stats_data: Dict[str, Any]) -> None:
        """Handle downtime statistics update."""
        await self.trigger_integration_hooks("downtime_statistics_updated", stats_data)
        
        if self.broadcast_enabled:
            await realtime_broadcaster.broadcast_downtime_statistics_update(stats_data)
    
    # ============================================================================
    # ESCALATION SERVICE INTEGRATION
    # ============================================================================
    
    async def on_escalation_created(self, escalation_data: Dict[str, Any]) -> None:
        """Handle escalation creation."""
        await self.trigger_integration_hooks("escalation_created", escalation_data)
        
        if self.broadcast_enabled:
            await realtime_broadcaster.broadcast_escalation_event(escalation_data)
    
    async def on_escalation_status_updated(self, escalation_id: str, status_data: Dict[str, Any]) -> None:
        """Handle escalation status update."""
        await self.trigger_integration_hooks("escalation_status_updated", {
            "escalation_id": escalation_id,
            "status_data": status_data
        })
        
        if self.broadcast_enabled:
            await realtime_broadcaster.broadcast_escalation_status_update(escalation_id, status_data)
    
    async def on_escalation_reminder_sent(self, reminder_data: Dict[str, Any]) -> None:
        """Handle escalation reminder."""
        await self.trigger_integration_hooks("escalation_reminder_sent", reminder_data)
        
        if self.broadcast_enabled:
            await realtime_broadcaster.broadcast_escalation_reminder(reminder_data)
    
    # ============================================================================
    # SYSTEM ALERT INTEGRATION
    # ============================================================================
    
    async def on_system_alert_triggered(self, alert_data: Dict[str, Any]) -> None:
        """Handle system alert."""
        await self.trigger_integration_hooks("system_alert_triggered", alert_data)
        
        if self.broadcast_enabled:
            await realtime_broadcaster.broadcast_system_alert(alert_data)
    
    async def on_system_health_check(self, health_data: Dict[str, Any]) -> None:
        """Handle system health check."""
        await self.trigger_integration_hooks("system_health_check", health_data)
        
        if self.broadcast_enabled:
            # Broadcast as diagnostic information
            await realtime_broadcaster.broadcast_system_alert({
                "type": "system_health_check",
                "severity": "info",
                "health_data": health_data
            })


# Global real-time integration service instance
realtime_integration = RealTimeIntegrationService()


# ============================================================================
# INTEGRATION DECORATORS
# ============================================================================

def broadcast_on_success(event_type: str):
    """
    Decorator to automatically broadcast real-time events on method success.
    
    Usage:
        @broadcast_on_success("production_data_updated")
        async def update_production_data(self, line_id: str, data: Dict):
            # Method implementation
            return result
    """
    def decorator(func):
        async def wrapper(*args, **kwargs):
            result = await func(*args, **kwargs)
            
            # Trigger real-time broadcast
            if event_type == "production_data_updated":
                line_id = args[1] if len(args) > 1 else kwargs.get("line_id")
                await realtime_integration.on_production_data_updated(line_id, result)
            elif event_type == "oee_calculated":
                line_id = args[1] if len(args) > 1 else kwargs.get("line_id")
                await realtime_integration.on_oee_calculated(line_id, result)
            elif event_type == "andon_event_created":
                await realtime_integration.on_andon_event_created(result)
            elif event_type == "equipment_status_changed":
                equipment_code = args[1] if len(args) > 1 else kwargs.get("equipment_code")
                old_status = kwargs.get("old_status", "unknown")
                new_status = result.get("status", "unknown")
                await realtime_integration.on_equipment_status_changed(equipment_code, old_status, new_status)
            
            return result
        return wrapper
    return decorator


def broadcast_on_change(event_type: str, field_name: str):
    """
    Decorator to automatically broadcast real-time events when specific field changes.
    
    Usage:
        @broadcast_on_change("line_status_changed", "status")
        async def update_line_status(self, line_id: str, new_status: str):
            # Method implementation
            return result
    """
    def decorator(func):
        async def wrapper(*args, **kwargs):
            # Get old value if available
            old_value = kwargs.get(f"old_{field_name}")
            
            result = await func(*args, **kwargs)
            
            # Check if value changed
            new_value = result.get(field_name) if isinstance(result, dict) else result
            
            if old_value != new_value:
                # Trigger real-time broadcast
                if event_type == "line_status_changed":
                    line_id = args[1] if len(args) > 1 else kwargs.get("line_id")
                    await realtime_integration.on_line_status_changed(line_id, old_value, new_value)
                elif event_type == "equipment_status_changed":
                    equipment_code = args[1] if len(args) > 1 else kwargs.get("equipment_code")
                    await realtime_integration.on_equipment_status_changed(equipment_code, old_value, new_value)
            
            return result
        return wrapper
    return decorator
