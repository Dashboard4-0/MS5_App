"""
MS5.0 Floor Dashboard - Monitoring & Health Check API

This module provides comprehensive monitoring endpoints for system health,
database performance, and TimescaleDB-specific metrics.

Endpoints:
- /health - Overall system health
- /health/database - Database health and connection pool status
- /health/timescaledb - TimescaleDB-specific health and statistics
- /metrics/hypertables - Hypertable statistics and chunk information
- /metrics/compression - Compression statistics and effectiveness
"""

from typing import Dict, Any, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status, Query
from fastapi.responses import JSONResponse
import structlog

from app.auth.permissions import get_current_user, UserContext, require_permission, Permission
from app.database import (
    check_database_health,
    get_connection_pool_status,
    get_timescaledb_health,
    get_hypertable_stats,
    get_compression_stats,
    get_chunk_details,
    check_timescaledb_extension,
    get_timescaledb_version
)
from app.config import settings

logger = structlog.get_logger()

router = APIRouter()


@router.get("/health", status_code=status.HTTP_200_OK)
async def get_system_health(
    current_user: UserContext = Depends(get_current_user)
) -> Dict[str, Any]:
    """
    Get overall system health status.
    
    Returns comprehensive health information including:
    - Application status
    - Database connectivity
    - TimescaleDB status
    - Configuration summary
    """
    try:
        # Check database health
        db_health = await check_database_health()
        
        # Check TimescaleDB health (non-blocking)
        timescaledb_health = {"status": "unknown"}
        try:
            timescaledb_health = await get_timescaledb_health()
        except Exception as e:
            logger.warning("TimescaleDB health check failed", error=str(e))
            timescaledb_health = {"status": "unavailable", "error": str(e)}
        
        # Determine overall status
        overall_status = "healthy"
        if db_health.get("status") != "healthy":
            overall_status = "degraded"
        if timescaledb_health.get("status") not in ["healthy", "degraded"]:
            overall_status = "degraded"
        
        health_response = {
            "status": overall_status,
            "application": {
                "name": settings.APP_NAME,
                "version": settings.VERSION,
                "environment": settings.ENVIRONMENT
            },
            "database": db_health,
            "timescaledb": {
                "status": timescaledb_health.get("status"),
                "extension_installed": timescaledb_health.get("extension_installed", False),
                "version": timescaledb_health.get("version")
            },
            "configuration": {
                "compression_enabled": settings.TIMESCALEDB_COMPRESSION_ENABLED,
                "retention_policy": settings.TIMESCALEDB_RETENTION_POLICY,
                "chunk_interval": settings.TIMESCALEDB_CHUNK_TIME_INTERVAL
            }
        }
        
        logger.info(
            "System health check completed",
            status=overall_status,
            user_id=current_user.user_id
        )
        
        return health_response
        
    except Exception as e:
        logger.error("System health check failed", error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Health check failed"
        )


@router.get("/health/database", status_code=status.HTTP_200_OK)
async def get_database_health(
    include_pool_stats: bool = Query(True, description="Include connection pool statistics"),
    current_user: UserContext = Depends(require_permission(Permission.ADMIN))
) -> Dict[str, Any]:
    """
    Get detailed database health and performance metrics.
    
    Requires admin permissions.
    
    Returns:
    - Database size and connectivity
    - Active connections and long-running queries
    - Connection pool statistics
    - Performance indicators
    """
    try:
        # Get database health
        db_health = await check_database_health()
        
        response = {
            "timestamp": "current",
            "health": db_health
        }
        
        # Add connection pool stats if requested
        if include_pool_stats:
            pool_stats = await get_connection_pool_status()
            response["connection_pool"] = pool_stats
        
        logger.info(
            "Database health check completed",
            status=db_health.get("status"),
            user_id=current_user.user_id
        )
        
        return response
        
    except Exception as e:
        logger.error("Database health check failed", error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Database health check failed"
        )


@router.get("/health/timescaledb", status_code=status.HTTP_200_OK)
async def get_timescaledb_health_detailed(
    current_user: UserContext = Depends(require_permission(Permission.ADMIN))
) -> Dict[str, Any]:
    """
    Get comprehensive TimescaleDB health and statistics.
    
    Requires admin permissions.
    
    Returns:
    - Extension version and status
    - Hypertable count and statistics
    - Compression effectiveness
    - Background worker status
    - Policy configuration
    """
    try:
        health = await get_timescaledb_health()
        
        # Enhance with configuration details
        health["configuration"] = {
            "compression_enabled": settings.TIMESCALEDB_COMPRESSION_ENABLED,
            "compression_after": settings.TIMESCALEDB_COMPRESSION_AFTER,
            "retention_policy": settings.TIMESCALEDB_RETENTION_POLICY,
            "retention_policy_metric_hist": settings.TIMESCALEDB_RETENTION_POLICY_METRIC_HIST,
            "retention_policy_oee": settings.TIMESCALEDB_RETENTION_POLICY_OEE,
            "chunk_interval": settings.TIMESCALEDB_CHUNK_TIME_INTERVAL,
            "chunk_interval_metric_hist": settings.TIMESCALEDB_CHUNK_TIME_INTERVAL_METRIC_HIST,
            "chunk_interval_oee": settings.TIMESCALEDB_CHUNK_TIME_INTERVAL_OEE,
            "max_background_workers": settings.TIMESCALEDB_MAX_BACKGROUND_WORKERS
        }
        
        logger.info(
            "TimescaleDB health check completed",
            status=health.get("status"),
            version=health.get("version"),
            user_id=current_user.user_id
        )
        
        return health
        
    except Exception as e:
        logger.error("TimescaleDB health check failed", error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="TimescaleDB health check failed"
        )


@router.get("/metrics/hypertables", status_code=status.HTTP_200_OK)
async def get_hypertables_metrics(
    current_user: UserContext = Depends(require_permission(Permission.ADMIN))
) -> Dict[str, Any]:
    """
    Get detailed hypertable statistics.
    
    Requires admin permissions.
    
    Returns:
    - Hypertable count
    - Table-specific statistics
    - Chunk counts and sizes
    - Storage efficiency metrics
    """
    try:
        stats = await get_hypertable_stats()
        
        logger.info(
            "Hypertable metrics retrieved",
            hypertable_count=stats.get("hypertable_count"),
            user_id=current_user.user_id
        )
        
        return stats
        
    except Exception as e:
        logger.error("Failed to get hypertable metrics", error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve hypertable metrics"
        )


@router.get("/metrics/compression", status_code=status.HTTP_200_OK)
async def get_compression_metrics(
    current_user: UserContext = Depends(require_permission(Permission.ADMIN))
) -> Dict[str, Any]:
    """
    Get compression statistics and effectiveness metrics.
    
    Requires admin permissions.
    
    Returns:
    - Compression ratios per table
    - Storage savings
    - Compressed vs uncompressed chunk counts
    - Compression policy status
    """
    try:
        stats = await get_compression_stats()
        
        # Calculate total savings if data available
        total_savings = None
        if stats.get("compressed_table_count", 0) > 0:
            total_compression = sum(
                table.get("compression_ratio_percent", 0)
                for table in stats.get("tables", [])
            )
            avg_compression = total_compression / len(stats.get("tables", []))
            
            stats["summary"] = {
                "average_compression_ratio_percent": round(avg_compression, 2),
                "total_compressed_tables": stats.get("compressed_table_count")
            }
        
        logger.info(
            "Compression metrics retrieved",
            compressed_tables=stats.get("compressed_table_count"),
            user_id=current_user.user_id
        )
        
        return stats
        
    except Exception as e:
        logger.error("Failed to get compression metrics", error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve compression metrics"
        )


@router.get("/metrics/chunks", status_code=status.HTTP_200_OK)
async def get_chunk_metrics(
    table_name: Optional[str] = Query(None, description="Filter by specific table name"),
    current_user: UserContext = Depends(require_permission(Permission.ADMIN))
) -> Dict[str, Any]:
    """
    Get detailed chunk information for hypertables.
    
    Requires admin permissions.
    
    Args:
        table_name: Optional table name to filter results
    
    Returns:
    - Chunk details including ranges, sizes, compression status
    - Limited to most recent 100 chunks for performance
    """
    try:
        details = await get_chunk_details(table_name)
        
        logger.info(
            "Chunk metrics retrieved",
            table_filter=table_name or "all",
            chunk_count=details.get("chunk_count"),
            user_id=current_user.user_id
        )
        
        return details
        
    except Exception as e:
        logger.error("Failed to get chunk metrics", error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve chunk metrics"
        )


@router.get("/status/timescaledb", status_code=status.HTTP_200_OK)
async def get_timescaledb_status(
    current_user: UserContext = Depends(get_current_user)
) -> Dict[str, Any]:
    """
    Get basic TimescaleDB status (lightweight check).
    
    Available to all authenticated users.
    
    Returns:
    - Extension installation status
    - Version information
    - Basic availability status
    """
    try:
        is_installed = await check_timescaledb_extension()
        version = None
        
        if is_installed:
            version = await get_timescaledb_version()
        
        status_response = {
            "installed": is_installed,
            "version": version,
            "status": "available" if is_installed else "unavailable"
        }
        
        logger.debug(
            "TimescaleDB status check",
            installed=is_installed,
            version=version,
            user_id=current_user.user_id
        )
        
        return status_response
        
    except Exception as e:
        logger.error("TimescaleDB status check failed", error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Status check failed"
        )


@router.get("/configuration", status_code=status.HTTP_200_OK)
async def get_monitoring_configuration(
    current_user: UserContext = Depends(require_permission(Permission.ADMIN))
) -> Dict[str, Any]:
    """
    Get current monitoring and TimescaleDB configuration.
    
    Requires admin permissions.
    
    Returns:
    - TimescaleDB policy settings
    - Compression configuration
    - Retention policies
    - Chunk intervals
    """
    try:
        config = {
            "timescaledb": {
                "compression": {
                    "enabled": settings.TIMESCALEDB_COMPRESSION_ENABLED,
                    "compress_after": settings.TIMESCALEDB_COMPRESSION_AFTER
                },
                "retention": {
                    "default_policy": settings.TIMESCALEDB_RETENTION_POLICY,
                    "metric_hist_policy": settings.TIMESCALEDB_RETENTION_POLICY_METRIC_HIST,
                    "oee_policy": settings.TIMESCALEDB_RETENTION_POLICY_OEE
                },
                "chunk_intervals": {
                    "default": settings.TIMESCALEDB_CHUNK_TIME_INTERVAL,
                    "metric_hist": settings.TIMESCALEDB_CHUNK_TIME_INTERVAL_METRIC_HIST,
                    "oee_calculations": settings.TIMESCALEDB_CHUNK_TIME_INTERVAL_OEE
                },
                "workers": {
                    "max_background_workers": settings.TIMESCALEDB_MAX_BACKGROUND_WORKERS
                }
            },
            "database": {
                "pool_size": settings.DATABASE_POOL_SIZE,
                "max_overflow": settings.DATABASE_MAX_OVERFLOW,
                "echo": settings.DATABASE_ECHO
            },
            "environment": settings.ENVIRONMENT
        }
        
        logger.info(
            "Monitoring configuration retrieved",
            user_id=current_user.user_id
        )
        
        return config
        
    except Exception as e:
        logger.error("Failed to get monitoring configuration", error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve configuration"
        )

