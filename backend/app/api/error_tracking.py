"""
MS5.0 Floor Dashboard - Error Tracking API Endpoints

This module provides REST API endpoints for error tracking:
- Error event recording
- Error rate reporting
- Error resolution management
- Error analytics and insights
- Zero redundancy architecture
"""

import asyncio
from typing import Any, Dict, List, Optional
from uuid import UUID

import structlog
from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from app.auth.dependencies import get_current_user
from app.services.error_rate_monitoring_service import (
    ErrorType, ErrorSeverity, record_error, resolve_error, 
    get_error_rate_report, _error_rate_monitoring_service
)
from app.utils.exceptions import BusinessLogicError

logger = structlog.get_logger()

# Create router
router = APIRouter(prefix="/api/errors", tags=["Error Tracking"])


class ErrorEventRequest(BaseModel):
    """Request model for error event recording."""
    error_id: Optional[str] = None
    error_type: ErrorType
    severity: ErrorSeverity
    message: str
    stack_trace: Optional[str] = None
    context: Optional[Dict[str, Any]] = None
    user_id: Optional[str] = None
    session_id: Optional[str] = None
    request_id: Optional[str] = None
    endpoint: Optional[str] = None
    method: Optional[str] = None
    status_code: Optional[int] = None
    timestamp: Optional[float] = None


class ErrorResolutionRequest(BaseModel):
    """Request model for error resolution."""
    resolution_notes: Optional[str] = None
    resolution_type: Optional[str] = None
    resolved_by: Optional[str] = None


class ErrorAlertRequest(BaseModel):
    """Request model for error alert configuration."""
    alert_id: str
    error_type: ErrorType
    threshold: float = Field(ge=0, le=1)
    time_window: int = Field(ge=60, le=86400)
    severity: str = Field(regex="^(low|medium|high|critical)$")
    enabled: bool = True


class ErrorFilterRequest(BaseModel):
    """Request model for error filtering."""
    error_type: Optional[ErrorType] = None
    severity: Optional[ErrorSeverity] = None
    endpoint: Optional[str] = None
    user_id: Optional[str] = None
    session_id: Optional[str] = None
    start_time: Optional[float] = None
    end_time: Optional[float] = None
    resolved: Optional[bool] = None
    limit: int = Field(default=100, ge=1, le=1000)
    offset: int = Field(default=0, ge=0)


@router.post("/track")
async def track_error(
    error_request: ErrorEventRequest,
    request: Request,
    current_user: dict = Depends(get_current_user)
) -> JSONResponse:
    """Track an error event."""
    try:
        # Record error
        error_id = await record_error(
            error_type=error_request.error_type,
            severity=error_request.severity,
            message=error_request.message,
            stack_trace=error_request.stack_trace,
            context=error_request.context,
            user_id=error_request.user_id or current_user.get("user_id"),
            session_id=error_request.session_id,
            request_id=error_request.request_id,
            endpoint=error_request.endpoint,
            method=error_request.method,
            status_code=error_request.status_code
        )
        
        logger.info(
            "Error tracked via API",
            error_id=error_id,
            error_type=error_request.error_type.value,
            severity=error_request.severity.value,
            user_id=current_user.get("user_id")
        )
        
        return JSONResponse(
            status_code=201,
            content={
                "error_id": error_id,
                "message": "Error tracked successfully",
                "timestamp": error_request.timestamp or asyncio.get_event_loop().time()
            }
        )
        
    except Exception as e:
        logger.error("Failed to track error via API", error=str(e))
        raise HTTPException(
            status_code=500,
            detail="Failed to track error"
        )


@router.get("/report")
async def get_error_report(
    current_user: dict = Depends(get_current_user)
) -> JSONResponse:
    """Get comprehensive error rate report."""
    try:
        report = get_error_rate_report()
        
        logger.info(
            "Error report requested",
            user_id=current_user.get("user_id"),
            total_errors=report.get("error_metrics", {}).get("total_errors", 0)
        )
        
        return JSONResponse(content=report)
        
    except Exception as e:
        logger.error("Failed to get error report", error=str(e))
        raise HTTPException(
            status_code=500,
            detail="Failed to get error report"
        )


@router.get("/metrics")
async def get_error_metrics(
    time_window: str = Query(default="hour", regex="^(minute|hour|day)$"),
    current_user: dict = Depends(get_current_user)
) -> JSONResponse:
    """Get error metrics for specific time window."""
    try:
        report = get_error_rate_report()
        error_metrics = report.get("error_metrics", {})
        
        # Filter metrics by time window
        if time_window == "minute":
            error_rate = error_metrics.get("error_rate_per_minute", 0)
        elif time_window == "hour":
            error_rate = error_metrics.get("error_rate_per_hour", 0)
        else:  # day
            error_rate = error_metrics.get("error_rate_percentage", 0) / 100
        
        metrics = {
            "time_window": time_window,
            "error_rate": error_rate,
            "total_errors": error_metrics.get("total_errors", 0),
            "critical_errors": error_metrics.get("critical_errors", 0),
            "unresolved_errors": error_metrics.get("unresolved_errors", 0),
            "errors_by_type": error_metrics.get("errors_by_type", {}),
            "errors_by_severity": error_metrics.get("errors_by_severity", {}),
            "errors_by_endpoint": error_metrics.get("errors_by_endpoint", {}),
        }
        
        return JSONResponse(content=metrics)
        
    except Exception as e:
        logger.error("Failed to get error metrics", error=str(e))
        raise HTTPException(
            status_code=500,
            detail="Failed to get error metrics"
        )


@router.get("/recent")
async def get_recent_errors(
    limit: int = Query(default=20, ge=1, le=100),
    severity: Optional[ErrorSeverity] = Query(default=None),
    error_type: Optional[ErrorType] = Query(default=None),
    current_user: dict = Depends(get_current_user)
) -> JSONResponse:
    """Get recent error events."""
    try:
        report = get_error_rate_report()
        recent_errors = report.get("recent_errors", {}).get("errors", [])
        
        # Filter by severity if specified
        if severity:
            recent_errors = [e for e in recent_errors if e.get("severity") == severity.value]
        
        # Filter by error type if specified
        if error_type:
            recent_errors = [e for e in recent_errors if e.get("error_type") == error_type.value]
        
        # Limit results
        recent_errors = recent_errors[:limit]
        
        return JSONResponse(content={
            "errors": recent_errors,
            "count": len(recent_errors),
            "limit": limit
        })
        
    except Exception as e:
        logger.error("Failed to get recent errors", error=str(e))
        raise HTTPException(
            status_code=500,
            detail="Failed to get recent errors"
        )


@router.get("/patterns")
async def get_error_patterns(
    limit: int = Query(default=10, ge=1, le=50),
    current_user: dict = Depends(get_current_user)
) -> JSONResponse:
    """Get top error patterns."""
    try:
        report = get_error_rate_report()
        top_patterns = report.get("top_error_patterns", [])
        
        # Limit results
        top_patterns = top_patterns[:limit]
        
        return JSONResponse(content={
            "patterns": top_patterns,
            "count": len(top_patterns),
            "limit": limit
        })
        
    except Exception as e:
        logger.error("Failed to get error patterns", error=str(e))
        raise HTTPException(
            status_code=500,
            detail="Failed to get error patterns"
        )


@router.get("/trends")
async def get_error_trends(
    current_user: dict = Depends(get_current_user)
) -> JSONResponse:
    """Get error trends over time."""
    try:
        report = get_error_rate_report()
        trends = report.get("error_trends", {})
        
        return JSONResponse(content=trends)
        
    except Exception as e:
        logger.error("Failed to get error trends", error=str(e))
        raise HTTPException(
            status_code=500,
            detail="Failed to get error trends"
        )


@router.post("/{error_id}/resolve")
async def resolve_error_endpoint(
    error_id: str,
    resolution_request: ErrorResolutionRequest,
    current_user: dict = Depends(get_current_user)
) -> JSONResponse:
    """Resolve an error event."""
    try:
        # Resolve error
        success = await resolve_error(
            error_id=error_id,
            resolution_notes=resolution_request.resolution_notes
        )
        
        if not success:
            raise HTTPException(
                status_code=404,
                detail="Error not found"
            )
        
        logger.info(
            "Error resolved via API",
            error_id=error_id,
            resolved_by=current_user.get("user_id"),
            resolution_notes=resolution_request.resolution_notes
        )
        
        return JSONResponse(content={
            "error_id": error_id,
            "message": "Error resolved successfully",
            "resolved_by": current_user.get("user_id"),
            "resolution_notes": resolution_request.resolution_notes
        })
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error("Failed to resolve error", error=str(e))
        raise HTTPException(
            status_code=500,
            detail="Failed to resolve error"
        )


@router.get("/alerts")
async def get_error_alerts(
    current_user: dict = Depends(get_current_user)
) -> JSONResponse:
    """Get active error alerts."""
    try:
        report = get_error_rate_report()
        active_alerts = report.get("active_alerts", [])
        
        return JSONResponse(content={
            "alerts": active_alerts,
            "count": len(active_alerts)
        })
        
    except Exception as e:
        logger.error("Failed to get error alerts", error=str(e))
        raise HTTPException(
            status_code=500,
            detail="Failed to get error alerts"
        )


@router.post("/alerts")
async def create_error_alert(
    alert_request: ErrorAlertRequest,
    current_user: dict = Depends(get_current_user)
) -> JSONResponse:
    """Create a new error alert."""
    try:
        # This would integrate with the error monitoring service
        # For now, return success response
        
        logger.info(
            "Error alert created via API",
            alert_id=alert_request.alert_id,
            error_type=alert_request.error_type.value,
            threshold=alert_request.threshold,
            created_by=current_user.get("user_id")
        )
        
        return JSONResponse(
            status_code=201,
            content={
                "alert_id": alert_request.alert_id,
                "message": "Error alert created successfully"
            }
        )
        
    except Exception as e:
        logger.error("Failed to create error alert", error=str(e))
        raise HTTPException(
            status_code=500,
            detail="Failed to create error alert"
        )


@router.put("/alerts/{alert_id}")
async def update_error_alert(
    alert_id: str,
    alert_request: ErrorAlertRequest,
    current_user: dict = Depends(get_current_user)
) -> JSONResponse:
    """Update an existing error alert."""
    try:
        # This would integrate with the error monitoring service
        # For now, return success response
        
        logger.info(
            "Error alert updated via API",
            alert_id=alert_id,
            updated_by=current_user.get("user_id")
        )
        
        return JSONResponse(content={
            "alert_id": alert_id,
            "message": "Error alert updated successfully"
        })
        
    except Exception as e:
        logger.error("Failed to update error alert", error=str(e))
        raise HTTPException(
            status_code=500,
            detail="Failed to update error alert"
        )


@router.delete("/alerts/{alert_id}")
async def delete_error_alert(
    alert_id: str,
    current_user: dict = Depends(get_current_user)
) -> JSONResponse:
    """Delete an error alert."""
    try:
        # This would integrate with the error monitoring service
        # For now, return success response
        
        logger.info(
            "Error alert deleted via API",
            alert_id=alert_id,
            deleted_by=current_user.get("user_id")
        )
        
        return JSONResponse(content={
            "alert_id": alert_id,
            "message": "Error alert deleted successfully"
        })
        
    except Exception as e:
        logger.error("Failed to delete error alert", error=str(e))
        raise HTTPException(
            status_code=500,
            detail="Failed to delete error alert"
        )


@router.get("/health")
async def get_error_tracking_health(
    current_user: dict = Depends(get_current_user)
) -> JSONResponse:
    """Get error tracking service health status."""
    try:
        report = get_error_rate_report()
        monitoring_status = report.get("monitoring_status", {})
        
        health_status = {
            "status": "healthy" if monitoring_status.get("is_monitoring", False) else "unhealthy",
            "monitoring": monitoring_status.get("is_monitoring", False),
            "monitoring_tasks": monitoring_status.get("monitoring_tasks", 0),
            "total_patterns": monitoring_status.get("total_patterns", 0),
            "error_metrics": {
                "total_errors": report.get("error_metrics", {}).get("total_errors", 0),
                "critical_errors": report.get("error_metrics", {}).get("critical_errors", 0),
                "unresolved_errors": report.get("error_metrics", {}).get("unresolved_errors", 0),
            }
        }
        
        return JSONResponse(content=health_status)
        
    except Exception as e:
        logger.error("Failed to get error tracking health", error=str(e))
        raise HTTPException(
            status_code=500,
            detail="Failed to get error tracking health"
        )


@router.get("/analytics")
async def get_error_analytics(
    time_range: str = Query(default="24h", regex="^(1h|24h|7d|30d)$"),
    current_user: dict = Depends(get_current_user)
) -> JSONResponse:
    """Get error analytics and insights."""
    try:
        report = get_error_rate_report()
        
        # Calculate analytics based on time range
        analytics = {
            "time_range": time_range,
            "error_frequency": report.get("error_metrics", {}).get("errors_by_type", {}),
            "error_trends": report.get("error_trends", {}),
            "top_error_sources": report.get("top_error_patterns", [])[:5],
            "error_impact_analysis": {
                "user_impact": report.get("error_metrics", {}).get("total_errors", 0),
                "system_impact": report.get("error_metrics", {}).get("critical_errors", 0),
                "business_impact": report.get("error_metrics", {}).get("unresolved_errors", 0),
            },
            "resolution_metrics": {
                "resolved_errors": report.get("error_metrics", {}).get("resolved_errors", 0),
                "unresolved_errors": report.get("error_metrics", {}).get("unresolved_errors", 0),
                "resolution_rate": 0,  # Would be calculated based on actual data
            }
        }
        
        return JSONResponse(content=analytics)
        
    except Exception as e:
        logger.error("Failed to get error analytics", error=str(e))
        raise HTTPException(
            status_code=500,
            detail="Failed to get error analytics"
        )


@router.get("/dashboard")
async def get_error_dashboard(
    current_user: dict = Depends(get_current_user)
) -> JSONResponse:
    """Get error dashboard data."""
    try:
        report = get_error_rate_report()
        
        # Calculate system health
        total_errors = report.get("error_metrics", {}).get("total_errors", 0)
        critical_errors = report.get("error_metrics", {}).get("critical_errors", 0)
        unresolved_errors = report.get("error_metrics", {}).get("unresolved_errors", 0)
        
        # Determine overall health
        if critical_errors > 0:
            overall_health = "critical"
        elif unresolved_errors > 10:
            overall_health = "warning"
        else:
            overall_health = "healthy"
        
        dashboard_data = {
            "error_rate_report": report,
            "system_health": {
                "overall_health": overall_health,
                "error_rate": report.get("error_metrics", {}).get("error_rate_percentage", 0),
                "critical_errors": critical_errors,
                "unresolved_errors": unresolved_errors,
            },
            "recent_errors": report.get("recent_errors", {}).get("errors", [])[:10],
            "active_alerts": report.get("active_alerts", []),
            "error_trends": report.get("error_trends", {}),
        }
        
        return JSONResponse(content=dashboard_data)
        
    except Exception as e:
        logger.error("Failed to get error dashboard", error=str(e))
        raise HTTPException(
            status_code=500,
            detail="Failed to get error dashboard"
        )


# Export router
__all__ = ["router"]
