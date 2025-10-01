"""
MS5.0 Floor Dashboard - Enhanced Database Service

This module provides optimized database operations with intelligent caching,
query analysis, and performance monitoring. Architected for cosmic-scale
performance with zero redundancy.
"""

import asyncio
import time
from typing import Any, Dict, List, Optional, Union
from uuid import UUID

import structlog
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import execute_query as base_execute_query, execute_scalar as base_execute_scalar
from app.services.database_optimizer import analyze_query_performance, get_database_performance_report
from app.services.query_cache_manager import (
    CacheStrategy, get_cached_query, set_cached_query, invalidate_cache_by_table
)
from app.utils.exceptions import BusinessLogicError

logger = structlog.get_logger()


class OptimizedDatabaseService:
    """Enhanced database service with optimization and caching."""
    
    def __init__(self):
        self.query_cache_enabled = True
        self.performance_monitoring_enabled = True
        self.slow_query_threshold = 1.0  # seconds
        self.cache_ttl_default = 300  # 5 minutes
        self.cache_ttl_long = 1800  # 30 minutes
        self.cache_ttl_short = 60  # 1 minute
        
    async def execute_optimized_query(
        self,
        query: str,
        params: Optional[Dict] = None,
        cache_strategy: CacheStrategy = CacheStrategy.CACHE_FIRST,
        cache_ttl: Optional[int] = None,
        analyze_performance: bool = True
    ) -> List[Dict[str, Any]]:
        """Execute query with optimization and caching."""
        start_time = time.time()
        
        try:
            # Try cache first if strategy allows
            if cache_strategy in [CacheStrategy.CACHE_FIRST, CacheStrategy.CACHE_ONLY]:
                cached_result = await get_cached_query(
                    query, params, cache_strategy, cache_ttl or self.cache_ttl_default
                )
                if cached_result is not None:
                    execution_time = time.time() - start_time
                    logger.debug(
                        "Query executed from cache",
                        query=query[:100],
                        execution_time=execution_time,
                        rows_returned=len(cached_result)
                    )
                    return cached_result
            
            # Execute query against database
            if cache_strategy != CacheStrategy.CACHE_ONLY:
                result = await base_execute_query(query, params)
                execution_time = time.time() - start_time
                
                # Cache result if strategy allows
                if cache_strategy in [CacheStrategy.CACHE_FIRST, CacheStrategy.DATABASE_FIRST]:
                    await set_cached_query(
                        query, result, params, cache_ttl or self.cache_ttl_default
                    )
                
                # Analyze performance if enabled
                if analyze_performance and self.performance_monitoring_enabled:
                    try:
                        await analyze_query_performance(query, params)
                    except Exception as e:
                        logger.warning("Performance analysis failed", error=str(e))
                
                # Log slow queries
                if execution_time > self.slow_query_threshold:
                    logger.warning(
                        "Slow query detected",
                        query=query[:200],
                        execution_time=execution_time,
                        rows_returned=len(result)
                    )
                
                logger.debug(
                    "Query executed successfully",
                    query=query[:100],
                    execution_time=execution_time,
                    rows_returned=len(result)
                )
                
                return result
            else:
                raise BusinessLogicError("Cache-only strategy but no cached result found")
                
        except Exception as e:
            execution_time = time.time() - start_time
            logger.error(
                "Query execution failed",
                query=query[:100],
                execution_time=execution_time,
                error=str(e)
            )
            raise
    
    async def execute_optimized_scalar(
        self,
        query: str,
        params: Optional[Dict] = None,
        cache_strategy: CacheStrategy = CacheStrategy.CACHE_FIRST,
        cache_ttl: Optional[int] = None
    ) -> Any:
        """Execute scalar query with optimization and caching."""
        start_time = time.time()
        
        try:
            # Try cache first if strategy allows
            if cache_strategy in [CacheStrategy.CACHE_FIRST, CacheStrategy.CACHE_ONLY]:
                cached_result = await get_cached_query(
                    query, params, cache_strategy, cache_ttl or self.cache_ttl_default
                )
                if cached_result is not None:
                    execution_time = time.time() - start_time
                    logger.debug(
                        "Scalar query executed from cache",
                        query=query[:100],
                        execution_time=execution_time
                    )
                    return cached_result
            
            # Execute query against database
            if cache_strategy != CacheStrategy.CACHE_ONLY:
                result = await base_execute_scalar(query, params)
                execution_time = time.time() - start_time
                
                # Cache result if strategy allows
                if cache_strategy in [CacheStrategy.CACHE_FIRST, CacheStrategy.DATABASE_FIRST]:
                    await set_cached_query(
                        query, result, params, cache_ttl or self.cache_ttl_default
                    )
                
                logger.debug(
                    "Scalar query executed successfully",
                    query=query[:100],
                    execution_time=execution_time
                )
                
                return result
            else:
                raise BusinessLogicError("Cache-only strategy but no cached result found")
                
        except Exception as e:
            execution_time = time.time() - start_time
            logger.error(
                "Scalar query execution failed",
                query=query[:100],
                execution_time=execution_time,
                error=str(e)
            )
            raise
    
    async def execute_batch_queries(
        self,
        queries: List[Tuple[str, Optional[Dict]]],
        cache_strategy: CacheStrategy = CacheStrategy.CACHE_FIRST,
        cache_ttl: Optional[int] = None
    ) -> List[List[Dict[str, Any]]]:
        """Execute multiple queries in batch with optimization."""
        start_time = time.time()
        results = []
        
        try:
            # Execute queries concurrently
            tasks = []
            for query, params in queries:
                task = self.execute_optimized_query(
                    query, params, cache_strategy, cache_ttl
                )
                tasks.append(task)
            
            results = await asyncio.gather(*tasks, return_exceptions=True)
            
            # Handle exceptions
            processed_results = []
            for i, result in enumerate(results):
                if isinstance(result, Exception):
                    logger.error(
                        "Batch query failed",
                        query_index=i,
                        query=queries[i][0][:100],
                        error=str(result)
                    )
                    processed_results.append([])
                else:
                    processed_results.append(result)
            
            execution_time = time.time() - start_time
            logger.debug(
                "Batch queries executed",
                query_count=len(queries),
                execution_time=execution_time
            )
            
            return processed_results
            
        except Exception as e:
            execution_time = time.time() - start_time
            logger.error(
                "Batch query execution failed",
                query_count=len(queries),
                execution_time=execution_time,
                error=str(e)
            )
            raise BusinessLogicError("Batch query execution failed")
    
    async def get_optimized_oee_history(
        self,
        line_id: UUID,
        equipment_code: str,
        start_date: str,
        end_date: str,
        limit: int = 100
    ) -> List[Dict[str, Any]]:
        """Get OEE history with optimization."""
        query = """
        SELECT id, line_id, equipment_code, calculation_time, availability, 
               performance, quality, oee, planned_production_time, 
               actual_production_time, ideal_cycle_time, actual_cycle_time, 
               good_parts, total_parts
        FROM factory_telemetry.oee_calculations 
        WHERE line_id = :line_id 
        AND equipment_code = :equipment_code
        AND calculation_time >= :start_date
        AND calculation_time <= :end_date
        ORDER BY calculation_time DESC
        LIMIT :limit
        """
        
        params = {
            "line_id": line_id,
            "equipment_code": equipment_code,
            "start_date": start_date,
            "end_date": end_date,
            "limit": limit
        }
        
        return await self.execute_optimized_query(
            query, params, CacheStrategy.CACHE_FIRST, self.cache_ttl_long
        )
    
    async def get_optimized_production_context(
        self,
        equipment_code: str
    ) -> Optional[Dict[str, Any]]:
        """Get production context with optimization."""
        query = """
        SELECT 
            c.current_job_id,
            c.production_schedule_id,
            c.production_line_id,
            c.target_speed,
            c.current_product_type_id,
            c.shift_id,
            c.target_quantity,
            c.actual_quantity,
            c.production_efficiency,
            c.quality_rate,
            c.changeover_status,
            c.current_operator,
            c.current_shift
        FROM factory_telemetry.context c
        WHERE c.equipment_code = :equipment_code
        """
        
        params = {"equipment_code": equipment_code}
        
        result = await self.execute_optimized_query(
            query, params, CacheStrategy.CACHE_FIRST, self.cache_ttl_short
        )
        
        return result[0] if result else None
    
    async def get_optimized_line_status(
        self,
        line_id: Optional[UUID] = None
    ) -> List[Dict[str, Any]]:
        """Get production line status with optimization."""
        if line_id:
            query = """
            SELECT 
                pl.id, pl.line_code, pl.name, pl.status, pl.current_job_id,
                pl.target_speed, pl.actual_speed, pl.efficiency,
                pl.last_updated, pl.current_operator,
                j.job_code, j.product_type, j.target_quantity, j.actual_quantity,
                j.start_time, j.end_time, j.status as job_status
            FROM factory_telemetry.production_lines pl
            LEFT JOIN factory_telemetry.production_jobs j ON pl.current_job_id = j.id
            WHERE pl.id = :line_id
            """
            params = {"line_id": line_id}
        else:
            query = """
            SELECT 
                pl.id, pl.line_code, pl.name, pl.status, pl.current_job_id,
                pl.target_speed, pl.actual_speed, pl.efficiency,
                pl.last_updated, pl.current_operator,
                j.job_code, j.product_type, j.target_quantity, j.actual_quantity,
                j.start_time, j.end_time, j.status as job_status
            FROM factory_telemetry.production_lines pl
            LEFT JOIN factory_telemetry.production_jobs j ON pl.current_job_id = j.id
            ORDER BY pl.line_code
            """
            params = {}
        
        return await self.execute_optimized_query(
            query, params, CacheStrategy.CACHE_FIRST, self.cache_ttl_short
        )
    
    async def get_optimized_andon_events(
        self,
        line_id: Optional[UUID] = None,
        status: Optional[str] = None,
        priority: Optional[str] = None,
        limit: int = 100
    ) -> List[Dict[str, Any]]:
        """Get Andon events with optimization."""
        where_conditions = []
        params = {"limit": limit}
        
        if line_id:
            where_conditions.append("ae.line_id = :line_id")
            params["line_id"] = line_id
        
        if status:
            where_conditions.append("ae.status = :status")
            params["status"] = status
        
        if priority:
            where_conditions.append("ae.priority = :priority")
            params["priority"] = priority
        
        where_clause = " AND ".join(where_conditions) if where_conditions else ""
        if where_clause:
            where_clause = f"WHERE {where_clause}"
        
        query = f"""
        SELECT 
            ae.id, ae.line_id, ae.equipment_code, ae.event_type, ae.description,
            ae.priority, ae.status, ae.reported_at, ae.reported_by,
            ae.acknowledged_at, ae.acknowledged_by, ae.resolved_at, ae.resolved_by,
            pl.line_code, pl.name as line_name,
            u1.username as reported_by_username,
            u2.username as acknowledged_by_username,
            u3.username as resolved_by_username
        FROM factory_telemetry.andon_events ae
        JOIN factory_telemetry.production_lines pl ON ae.line_id = pl.id
        LEFT JOIN factory_telemetry.users u1 ON ae.reported_by = u1.id
        LEFT JOIN factory_telemetry.users u2 ON ae.acknowledged_by = u2.id
        LEFT JOIN factory_telemetry.users u3 ON ae.resolved_by = u3.id
        {where_clause}
        ORDER BY ae.reported_at DESC
        LIMIT :limit
        """
        
        return await self.execute_optimized_query(
            query, params, CacheStrategy.CACHE_FIRST, self.cache_ttl_short
        )
    
    async def invalidate_cache_for_table(self, table_name: str) -> int:
        """Invalidate cache for a specific table."""
        return await invalidate_cache_by_table(table_name)
    
    async def get_performance_report(self) -> Dict[str, Any]:
        """Get comprehensive performance report."""
        try:
            db_report = await get_database_performance_report()
            
            return {
                'database_performance': db_report,
                'cache_configuration': {
                    'cache_enabled': self.query_cache_enabled,
                    'performance_monitoring_enabled': self.performance_monitoring_enabled,
                    'slow_query_threshold': self.slow_query_threshold,
                    'default_cache_ttl': self.cache_ttl_default,
                    'long_cache_ttl': self.cache_ttl_long,
                    'short_cache_ttl': self.cache_ttl_short
                }
            }
            
        except Exception as e:
            logger.error("Failed to get performance report", error=str(e))
            raise BusinessLogicError("Failed to get performance report")
    
    def configure_cache_settings(
        self,
        cache_enabled: bool = True,
        performance_monitoring_enabled: bool = True,
        slow_query_threshold: float = 1.0,
        default_cache_ttl: int = 300,
        long_cache_ttl: int = 1800,
        short_cache_ttl: int = 60
    ):
        """Configure cache and performance settings."""
        self.query_cache_enabled = cache_enabled
        self.performance_monitoring_enabled = performance_monitoring_enabled
        self.slow_query_threshold = slow_query_threshold
        self.cache_ttl_default = default_cache_ttl
        self.cache_ttl_long = long_cache_ttl
        self.cache_ttl_short = short_cache_ttl
        
        logger.info(
            "Database service configuration updated",
            cache_enabled=cache_enabled,
            performance_monitoring_enabled=performance_monitoring_enabled,
            slow_query_threshold=slow_query_threshold
        )


# Global optimized database service instance
_optimized_db_service = OptimizedDatabaseService()


async def get_optimized_db_service() -> OptimizedDatabaseService:
    """Get the global optimized database service instance."""
    return _optimized_db_service


async def execute_optimized_query(
    query: str,
    params: Optional[Dict] = None,
    cache_strategy: CacheStrategy = CacheStrategy.CACHE_FIRST,
    cache_ttl: Optional[int] = None
) -> List[Dict[str, Any]]:
    """Execute optimized query using the global service."""
    return await _optimized_db_service.execute_optimized_query(
        query, params, cache_strategy, cache_ttl
    )


async def execute_optimized_scalar(
    query: str,
    params: Optional[Dict] = None,
    cache_strategy: CacheStrategy = CacheStrategy.CACHE_FIRST,
    cache_ttl: Optional[int] = None
) -> Any:
    """Execute optimized scalar query using the global service."""
    return await _optimized_db_service.execute_optimized_scalar(
        query, params, cache_strategy, cache_ttl
    )


async def get_database_performance_report() -> Dict[str, Any]:
    """Get database performance report using the global service."""
    return await _optimized_db_service.get_performance_report()
