"""
MS5.0 Manufacturing System - TimescaleDB Management Module

This module provides comprehensive management, monitoring, and optimization
capabilities for TimescaleDB hypertables, compression, retention, and
continuous aggregates.

Features:
- Hypertable health monitoring
- Compression policy management
- Retention policy management
- Continuous aggregate refresh control
- Performance analytics and reporting
- Automated maintenance tasks

Author: MS5.0 System
Version: 1.0.0
License: Proprietary
"""

import asyncio
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass, asdict
from enum import Enum

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
import structlog

from app.database import get_db_session


logger = structlog.get_logger(__name__)


# ============================================================================
# Data Classes and Enums
# ============================================================================

class HypertableStatus(str, Enum):
    """Hypertable health status enumeration."""
    HEALTHY = "healthy"
    WARNING = "warning"
    CRITICAL = "critical"
    UNKNOWN = "unknown"


class CompressionStatus(str, Enum):
    """Compression job status enumeration."""
    ACTIVE = "active"
    FAILED = "failed"
    PENDING = "pending"
    DISABLED = "disabled"


@dataclass
class HypertableInfo:
    """Hypertable metadata and statistics."""
    name: str
    schema: str
    num_chunks: int
    num_dimensions: int
    total_size_bytes: int
    total_size_human: str
    avg_chunk_size_bytes: int
    compression_enabled: bool
    compressed_chunks: int
    compression_percentage: float
    oldest_chunk: Optional[datetime]
    newest_chunk: Optional[datetime]
    status: HypertableStatus


@dataclass
class CompressionPolicyInfo:
    """Compression policy metadata and statistics."""
    hypertable_name: str
    job_id: int
    schedule_interval: str
    compress_after_interval: str
    last_run_status: Optional[str]
    last_successful_finish: Optional[datetime]
    total_runs: int
    total_successes: int
    total_failures: int
    status: CompressionStatus


@dataclass
class RetentionPolicyInfo:
    """Retention policy metadata and statistics."""
    hypertable_name: str
    job_id: int
    retention_interval: str
    schedule_interval: str
    chunks_eligible_for_deletion: int
    data_volume_to_delete: str
    last_run_status: Optional[str]
    last_successful_finish: Optional[datetime]


@dataclass
class ContinuousAggregateInfo:
    """Continuous aggregate metadata and statistics."""
    view_name: str
    materialized_only: bool
    compression_enabled: bool
    aggregate_size: str
    has_refresh_policy: bool
    refresh_interval: Optional[str]


@dataclass
class PerformanceMetrics:
    """Database performance metrics."""
    total_hypertables: int
    total_chunks: int
    total_size_bytes: int
    total_size_human: str
    compressed_chunks: int
    compression_ratio_percent: float
    space_saved_bytes: int
    space_saved_human: str
    avg_query_time_ms: float
    cache_hit_ratio: float


# ============================================================================
# TimescaleDB Manager Class
# ============================================================================

class TimescaleDBManager:
    """
    Comprehensive TimescaleDB management and monitoring system.
    
    This class provides a unified interface for managing all aspects of
    TimescaleDB optimization including hypertables, compression, retention,
    and continuous aggregates.
    
    Example:
        ```python
        manager = TimescaleDBManager()
        
        # Get hypertable health
        health = await manager.get_hypertable_health()
        
        # Trigger manual compression
        await manager.compress_hypertable("metric_hist", older_than_days=7)
        
        # Refresh continuous aggregates
        await manager.refresh_all_continuous_aggregates()
        ```
    """
    
    def __init__(self):
        """Initialize TimescaleDB manager."""
        self.schema = "factory_telemetry"
        self.logger = logger.bind(component="timescaledb_manager")
    
    # ========================================================================
    # Hypertable Management
    # ========================================================================
    
    async def get_hypertable_info(
        self,
        hypertable_name: Optional[str] = None
    ) -> List[HypertableInfo]:
        """
        Retrieve detailed information about hypertables.
        
        Args:
            hypertable_name: Specific hypertable name, or None for all
            
        Returns:
            List of HypertableInfo objects with complete metadata
        """
        async with get_db_session() as session:
            query = text("""
                SELECT
                    h.hypertable_name AS name,
                    h.hypertable_schema AS schema,
                    h.num_chunks,
                    h.num_dimensions,
                    COALESCE(cs.total_size_bytes, 0) AS total_size_bytes,
                    pg_size_pretty(COALESCE(cs.total_size_bytes, 0)) AS total_size_human,
                    COALESCE(cs.total_size_bytes / NULLIF(h.num_chunks, 0), 0) AS avg_chunk_size_bytes,
                    h.compression_enabled,
                    COALESCE(cs.compressed_chunks, 0) AS compressed_chunks,
                    COALESCE(cs.compression_percentage, 0) AS compression_percentage,
                    (SELECT MIN(range_start) FROM timescaledb_information.chunks 
                     WHERE hypertable_name = h.hypertable_name) AS oldest_chunk,
                    (SELECT MAX(range_end) FROM timescaledb_information.chunks 
                     WHERE hypertable_name = h.hypertable_name) AS newest_chunk
                FROM timescaledb_information.hypertables h
                LEFT JOIN factory_telemetry.v_chunk_statistics cs 
                    ON h.hypertable_name = cs.hypertable_name
                WHERE h.hypertable_schema = :schema
                    AND (:name IS NULL OR h.hypertable_name = :name)
                ORDER BY cs.total_size_bytes DESC NULLS LAST
            """)
            
            result = await session.execute(
                query,
                {"schema": self.schema, "name": hypertable_name}
            )
            rows = result.mappings().all()
            
            hypertables = []
            for row in rows:
                # Determine health status
                status = self._determine_hypertable_status(
                    row["num_chunks"],
                    row["compression_percentage"],
                    row["compression_enabled"]
                )
                
                hypertables.append(HypertableInfo(
                    name=row["name"],
                    schema=row["schema"],
                    num_chunks=row["num_chunks"],
                    num_dimensions=row["num_dimensions"],
                    total_size_bytes=row["total_size_bytes"],
                    total_size_human=row["total_size_human"],
                    avg_chunk_size_bytes=row["avg_chunk_size_bytes"],
                    compression_enabled=row["compression_enabled"],
                    compressed_chunks=row["compressed_chunks"],
                    compression_percentage=row["compression_percentage"],
                    oldest_chunk=row["oldest_chunk"],
                    newest_chunk=row["newest_chunk"],
                    status=status
                ))
            
            self.logger.info(
                "Retrieved hypertable info",
                count=len(hypertables),
                specific=hypertable_name
            )
            
            return hypertables
    
    def _determine_hypertable_status(
        self,
        num_chunks: int,
        compression_percentage: float,
        compression_enabled: bool
    ) -> HypertableStatus:
        """
        Determine hypertable health status based on metrics.
        
        Health criteria:
        - Healthy: Compression enabled, >60% chunks compressed
        - Warning: Compression enabled but <60% compressed, or too many chunks
        - Critical: Compression disabled or failed, or excessive chunk count
        """
        if not compression_enabled:
            return HypertableStatus.CRITICAL
        
        if num_chunks > 1000:
            return HypertableStatus.WARNING
        
        if compression_percentage < 60:
            return HypertableStatus.WARNING
        
        if compression_percentage >= 60:
            return HypertableStatus.HEALTHY
        
        return HypertableStatus.UNKNOWN
    
    async def get_hypertable_health(self) -> Dict[str, Any]:
        """
        Get comprehensive health report for all hypertables.
        
        Returns:
            Dictionary with health summary and individual hypertable statuses
        """
        hypertables = await self.get_hypertable_info()
        
        health_summary = {
            "total_hypertables": len(hypertables),
            "healthy": sum(1 for h in hypertables if h.status == HypertableStatus.HEALTHY),
            "warning": sum(1 for h in hypertables if h.status == HypertableStatus.WARNING),
            "critical": sum(1 for h in hypertables if h.status == HypertableStatus.CRITICAL),
            "total_size_bytes": sum(h.total_size_bytes for h in hypertables),
            "avg_compression_percentage": (
                sum(h.compression_percentage for h in hypertables) / len(hypertables)
                if hypertables else 0
            ),
            "hypertables": [asdict(h) for h in hypertables]
        }
        
        self.logger.info("Generated hypertable health report", summary=health_summary)
        
        return health_summary
    
    # ========================================================================
    # Compression Management
    # ========================================================================
    
    async def get_compression_policies(self) -> List[CompressionPolicyInfo]:
        """
        Retrieve all compression policies and their status.
        
        Returns:
            List of CompressionPolicyInfo objects
        """
        async with get_db_session() as session:
            result = await session.execute(text("""
                SELECT * FROM factory_telemetry.v_compression_jobs
                ORDER BY hypertable_name
            """))
            rows = result.mappings().all()
            
            policies = []
            for row in rows:
                status = self._determine_compression_status(
                    row["last_run_status"],
                    row["total_failures"]
                )
                
                policies.append(CompressionPolicyInfo(
                    hypertable_name=row["hypertable_name"],
                    job_id=row["job_id"],
                    schedule_interval=str(row["schedule_interval"]),
                    compress_after_interval=row["compress_after_interval"],
                    last_run_status=row["last_run_status"],
                    last_successful_finish=row["last_successful_finish"],
                    total_runs=row["total_runs"] or 0,
                    total_successes=row["total_successes"] or 0,
                    total_failures=row["total_failures"] or 0,
                    status=status
                ))
            
            return policies
    
    def _determine_compression_status(
        self,
        last_run_status: Optional[str],
        total_failures: int
    ) -> CompressionStatus:
        """Determine compression policy status."""
        if last_run_status is None:
            return CompressionStatus.PENDING
        if last_run_status == "Failed" or total_failures > 3:
            return CompressionStatus.FAILED
        if last_run_status == "Success":
            return CompressionStatus.ACTIVE
        return CompressionStatus.DISABLED
    
    async def compress_hypertable(
        self,
        hypertable_name: str,
        older_than_days: int = 7
    ) -> Dict[str, Any]:
        """
        Manually compress eligible chunks for a hypertable.
        
        Args:
            hypertable_name: Name of the hypertable
            older_than_days: Only compress chunks older than this many days
            
        Returns:
            Dictionary with compression results
        """
        async with get_db_session() as session:
            query = text("""
                SELECT * FROM factory_telemetry.compress_all_eligible_chunks(
                    :table_name,
                    :older_than::INTERVAL
                )
            """)
            
            result = await session.execute(
                query,
                {
                    "table_name": hypertable_name,
                    "older_than": f"{older_than_days} days"
                }
            )
            chunks = result.fetchall()
            
            await session.commit()
            
            total_before = sum(c[2] for c in chunks)  # size_before
            total_after = sum(c[3] for c in chunks)   # size_after
            
            compression_result = {
                "hypertable": hypertable_name,
                "chunks_compressed": len(chunks),
                "size_before_bytes": total_before,
                "size_after_bytes": total_after,
                "space_saved_bytes": total_before - total_after,
                "compression_ratio_percent": (
                    round(100 * (1 - total_after / total_before), 2)
                    if total_before > 0 else 0
                ),
                "chunks": [
                    {
                        "name": c[0],
                        "compressed": c[1],
                        "size_before": c[2],
                        "size_after": c[3],
                        "ratio": c[4]
                    }
                    for c in chunks
                ]
            }
            
            self.logger.info(
                "Manual compression completed",
                hypertable=hypertable_name,
                chunks=len(chunks),
                ratio=compression_result["compression_ratio_percent"]
            )
            
            return compression_result
    
    # ========================================================================
    # Retention Policy Management
    # ========================================================================
    
    async def get_retention_policies(self) -> List[RetentionPolicyInfo]:
        """
        Retrieve all retention policies and their status.
        
        Returns:
            List of RetentionPolicyInfo objects
        """
        async with get_db_session() as session:
            result = await session.execute(text("""
                SELECT * FROM factory_telemetry.v_retention_policies
                ORDER BY hypertable_name
            """))
            rows = result.mappings().all()
            
            policies = []
            for row in rows:
                policies.append(RetentionPolicyInfo(
                    hypertable_name=row["hypertable_name"],
                    job_id=row["job_id"],
                    retention_interval=row["retention_interval"],
                    schedule_interval=str(row["schedule_interval"]),
                    chunks_eligible_for_deletion=row["chunks_eligible_for_deletion"] or 0,
                    data_volume_to_delete=row["data_volume_to_delete"] or "0 bytes",
                    last_run_status=row["last_run_status"],
                    last_successful_finish=row["last_successful_finish"]
                ))
            
            return policies
    
    async def modify_retention_policy(
        self,
        hypertable_name: str,
        new_interval_days: int
    ) -> bool:
        """
        Modify retention interval for a hypertable.
        
        Args:
            hypertable_name: Name of the hypertable
            new_interval_days: New retention period in days
            
        Returns:
            True if successful, False otherwise
        """
        async with get_db_session() as session:
            query = text("""
                SELECT factory_telemetry.modify_retention_policy(
                    :table_name,
                    :interval::INTERVAL
                )
            """)
            
            try:
                result = await session.execute(
                    query,
                    {
                        "table_name": hypertable_name,
                        "interval": f"{new_interval_days} days"
                    }
                )
                await session.commit()
                
                success = result.scalar()
                
                self.logger.info(
                    "Modified retention policy",
                    hypertable=hypertable_name,
                    new_interval_days=new_interval_days,
                    success=success
                )
                
                return success
            except Exception as e:
                self.logger.error(
                    "Failed to modify retention policy",
                    hypertable=hypertable_name,
                    error=str(e)
                )
                return False
    
    # ========================================================================
    # Continuous Aggregate Management
    # ========================================================================
    
    async def get_continuous_aggregates(self) -> List[ContinuousAggregateInfo]:
        """
        Retrieve all continuous aggregates and their status.
        
        Returns:
            List of ContinuousAggregateInfo objects
        """
        async with get_db_session() as session:
            result = await session.execute(text("""
                SELECT * FROM factory_telemetry.v_continuous_aggregate_status
                ORDER BY view_name
            """))
            rows = result.mappings().all()
            
            aggregates = []
            for row in rows:
                aggregates.append(ContinuousAggregateInfo(
                    view_name=row["view_name"],
                    materialized_only=row["materialized_only"],
                    compression_enabled=row["compression_enabled"],
                    aggregate_size=row["aggregate_size"],
                    has_refresh_policy=row["has_refresh_policy"] > 0,
                    refresh_interval=str(row["refresh_interval"]) if row["refresh_interval"] else None
                ))
            
            return aggregates
    
    async def refresh_continuous_aggregate(
        self,
        aggregate_name: str,
        start_time: Optional[datetime] = None,
        end_time: Optional[datetime] = None
    ) -> bool:
        """
        Manually refresh a continuous aggregate.
        
        Args:
            aggregate_name: Name of the continuous aggregate
            start_time: Start of refresh window (defaults to 7 days ago)
            end_time: End of refresh window (defaults to now)
            
        Returns:
            True if successful, False otherwise
        """
        async with get_db_session() as session:
            query = text("""
                SELECT factory_telemetry.refresh_continuous_aggregate(
                    :aggregate_name,
                    :start_time,
                    :end_time
                )
            """)
            
            try:
                result = await session.execute(
                    query,
                    {
                        "aggregate_name": aggregate_name,
                        "start_time": start_time or datetime.now() - timedelta(days=7),
                        "end_time": end_time or datetime.now()
                    }
                )
                await session.commit()
                
                success = result.scalar()
                
                self.logger.info(
                    "Refreshed continuous aggregate",
                    aggregate=aggregate_name,
                    success=success
                )
                
                return success
            except Exception as e:
                self.logger.error(
                    "Failed to refresh continuous aggregate",
                    aggregate=aggregate_name,
                    error=str(e)
                )
                return False
    
    async def refresh_all_continuous_aggregates(self) -> Dict[str, bool]:
        """
        Refresh all continuous aggregates.
        
        Returns:
            Dictionary mapping aggregate names to success status
        """
        aggregates = await self.get_continuous_aggregates()
        results = {}
        
        for agg in aggregates:
            success = await self.refresh_continuous_aggregate(agg.view_name)
            results[agg.view_name] = success
        
        self.logger.info(
            "Refreshed all continuous aggregates",
            total=len(aggregates),
            succeeded=sum(1 for v in results.values() if v)
        )
        
        return results
    
    # ========================================================================
    # Performance Metrics
    # ========================================================================
    
    async def get_performance_metrics(self) -> PerformanceMetrics:
        """
        Get comprehensive database performance metrics.
        
        Returns:
            PerformanceMetrics object with complete statistics
        """
        async with get_db_session() as session:
            # Get compression statistics
            result = await session.execute(text("""
                SELECT * FROM factory_telemetry.v_compression_statistics
            """))
            comp_stats = result.mappings().all()
            
            total_size = sum(
                int(row["total_uncompressed_size"].replace(" ", "").replace("bytes", "") or 0)
                for row in comp_stats
            )
            
            # Calculate cache hit ratio
            cache_result = await session.execute(text("""
                SELECT 
                    ROUND(
                        100.0 * sum(heap_blks_hit) / 
                        NULLIF(sum(heap_blks_hit) + sum(heap_blks_read), 0),
                        2
                    ) AS cache_hit_ratio
                FROM pg_statio_user_tables
                WHERE schemaname = 'factory_telemetry'
            """))
            cache_hit_ratio = cache_result.scalar() or 0.0
            
            # Get hypertable info
            hypertables = await self.get_hypertable_info()
            
            metrics = PerformanceMetrics(
                total_hypertables=len(hypertables),
                total_chunks=sum(h.num_chunks for h in hypertables),
                total_size_bytes=sum(h.total_size_bytes for h in hypertables),
                total_size_human=self._bytes_to_human(sum(h.total_size_bytes for h in hypertables)),
                compressed_chunks=sum(h.compressed_chunks for h in hypertables),
                compression_ratio_percent=(
                    sum(h.compression_percentage for h in hypertables) / len(hypertables)
                    if hypertables else 0
                ),
                space_saved_bytes=0,  # Would need more complex calculation
                space_saved_human="N/A",
                avg_query_time_ms=0.0,  # Would need query statistics
                cache_hit_ratio=float(cache_hit_ratio)
            )
            
            return metrics
    
    @staticmethod
    def _bytes_to_human(bytes_count: int) -> str:
        """Convert bytes to human-readable format."""
        for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
            if bytes_count < 1024.0:
                return f"{bytes_count:.2f} {unit}"
            bytes_count /= 1024.0
        return f"{bytes_count:.2f} PB"
    
    # ========================================================================
    # Maintenance Tasks
    # ========================================================================
    
    async def run_maintenance(self) -> Dict[str, Any]:
        """
        Run comprehensive maintenance tasks.
        
        This includes:
        - VACUUM ANALYZE on all hypertables
        - Compression of eligible chunks
        - Refresh of continuous aggregates
        - Health check
        
        Returns:
            Dictionary with maintenance results
        """
        self.logger.info("Starting TimescaleDB maintenance")
        
        results = {
            "timestamp": datetime.now().isoformat(),
            "tasks": {}
        }
        
        # Get hypertables
        hypertables = await self.get_hypertable_info()
        
        # Run VACUUM ANALYZE
        async with get_db_session() as session:
            for ht in hypertables:
                try:
                    await session.execute(text(
                        f"VACUUM ANALYZE {self.schema}.{ht.name}"
                    ))
                    results["tasks"][f"vacuum_{ht.name}"] = "success"
                except Exception as e:
                    self.logger.error(f"VACUUM failed for {ht.name}", error=str(e))
                    results["tasks"][f"vacuum_{ht.name}"] = f"failed: {str(e)}"
        
        # Refresh continuous aggregates
        refresh_results = await self.refresh_all_continuous_aggregates()
        results["tasks"]["continuous_aggregates"] = refresh_results
        
        # Get health summary
        health = await self.get_hypertable_health()
        results["health"] = health
        
        self.logger.info("TimescaleDB maintenance completed", results=results)
        
        return results


# ============================================================================
# Convenience Functions
# ============================================================================

async def get_timescaledb_manager() -> TimescaleDBManager:
    """Get singleton TimescaleDB manager instance."""
    return TimescaleDBManager()

