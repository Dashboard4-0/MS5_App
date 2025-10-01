"""
MS5.0 Floor Dashboard - Database Layer

This module handles database connections, ORM setup, and database operations
for the MS5.0 Floor Dashboard API. It uses SQLAlchemy with async support
and integrates with the existing factory telemetry database schema.
"""

import asyncio
from typing import AsyncGenerator, Optional
from contextlib import asynccontextmanager

from sqlalchemy import create_engine, MetaData, text
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase, sessionmaker
from sqlalchemy.pool import NullPool, QueuePool
import structlog

from app.config import settings

logger = structlog.get_logger()


class Base(DeclarativeBase):
    """Base class for all database models."""
    pass


# Database engines
sync_engine = None
async_engine = None
async_session_factory = None


async def init_db() -> None:
    """Initialize database connections and create tables."""
    global sync_engine, async_engine, async_session_factory
    
    try:
        # Create sync engine for migrations and admin operations
        sync_engine = create_engine(
            settings.DATABASE_URL.replace("postgresql+asyncpg://", "postgresql://"),
            poolclass=QueuePool,
            pool_size=settings.DATABASE_POOL_SIZE,
            max_overflow=settings.DATABASE_MAX_OVERFLOW,
            echo=settings.DATABASE_ECHO,
            future=True
        )
        
        # Create async engine for application operations
        async_engine = create_async_engine(
            settings.DATABASE_URL,
            poolclass=QueuePool,
            pool_size=settings.DATABASE_POOL_SIZE,
            max_overflow=settings.DATABASE_MAX_OVERFLOW,
            echo=settings.DATABASE_ECHO,
            future=True
        )
        
        # Create async session factory
        async_session_factory = async_sessionmaker(
            async_engine,
            class_=AsyncSession,
            expire_on_commit=False
        )
        
        # Test database connectivity
        await test_database_connection()
        
        logger.info("Database initialized successfully")
        
    except Exception as e:
        logger.error("Failed to initialize database", error=str(e))
        raise


async def close_db() -> None:
    """Close database connections."""
    global sync_engine, async_engine, async_session_factory
    
    try:
        if async_engine:
            await async_engine.dispose()
            logger.info("Async database engine disposed")
        
        if sync_engine:
            sync_engine.dispose()
            logger.info("Sync database engine disposed")
            
        async_session_factory = None
        
    except Exception as e:
        logger.error("Error closing database connections", error=str(e))


async def test_database_connection() -> None:
    """Test database connectivity."""
    try:
        async with async_engine.begin() as conn:
            result = await conn.execute(text("SELECT 1"))
            result.fetchone()
        logger.info("Database connection test successful")
    except Exception as e:
        logger.error("Database connection test failed", error=str(e))
        raise


@asynccontextmanager
async def get_db_session() -> AsyncGenerator[AsyncSession, None]:
    """Get database session with automatic cleanup."""
    if not async_session_factory:
        raise RuntimeError("Database not initialized. Call init_db() first.")
    
    async with async_session_factory() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """Dependency for getting database session in FastAPI endpoints."""
    async with get_db_session() as session:
        yield session


# Database utility functions
async def execute_query(query: str, params: Optional[dict] = None) -> list:
    """Execute a raw SQL query and return results."""
    try:
        async with get_db_session() as session:
            result = await session.execute(text(query), params or {})
            return result.fetchall()
    except Exception as e:
        logger.error("Database query execution failed", 
                    query=query[:100], params=params, error=str(e))
        raise


async def execute_scalar(query: str, params: Optional[dict] = None):
    """Execute a raw SQL query and return a single scalar result."""
    try:
        async with get_db_session() as session:
            result = await session.execute(text(query), params or {})
            return result.scalar()
    except Exception as e:
        logger.error("Database scalar execution failed", 
                    query=query[:100], params=params, error=str(e))
        raise


async def execute_update(query: str, params: Optional[dict] = None) -> int:
    """Execute an update/insert/delete query and return affected rows."""
    try:
        async with get_db_session() as session:
            result = await session.execute(text(query), params or {})
            await session.commit()
            return result.rowcount
    except Exception as e:
        logger.error("Database update execution failed", 
                    query=query[:100], params=params, error=str(e))
        raise


# Database health check
async def check_database_health() -> dict:
    """Check database health and return status information."""
    try:
        # Test basic connectivity
        await test_database_connection()
        
        # Check database size
        size_query = """
        SELECT pg_size_pretty(pg_database_size(current_database())) as size
        """
        db_size = await execute_scalar(size_query)
        
        # Check active connections
        connections_query = """
        SELECT count(*) as active_connections 
        FROM pg_stat_activity 
        WHERE state = 'active'
        """
        active_connections = await execute_scalar(connections_query)
        
        # Check for long-running queries
        long_queries_query = """
        SELECT count(*) as long_queries
        FROM pg_stat_activity 
        WHERE state = 'active' 
        AND query_start < NOW() - INTERVAL '5 minutes'
        """
        long_queries = await execute_scalar(long_queries_query)
        
        return {
            "status": "healthy",
            "database_size": db_size,
            "active_connections": active_connections,
            "long_queries": long_queries,
            "pool_size": settings.DATABASE_POOL_SIZE,
            "max_overflow": settings.DATABASE_MAX_OVERFLOW
        }
        
    except Exception as e:
        logger.error("Database health check failed", error=str(e))
        return {
            "status": "unhealthy",
            "error": str(e)
        }


# Transaction management
class DatabaseTransaction:
    """Context manager for database transactions."""
    
    def __init__(self):
        self.session: Optional[AsyncSession] = None
    
    async def __aenter__(self) -> AsyncSession:
        if not async_session_factory:
            raise RuntimeError("Database not initialized. Call init_db() first.")
        
        self.session = async_session_factory()
        return self.session
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self.session:
            if exc_type:
                await self.session.rollback()
            else:
                await self.session.commit()
            await self.session.close()


# Database migration utilities
async def run_migrations() -> None:
    """Run database migrations."""
    try:
        # This would typically use Alembic or similar migration tool
        # For now, we'll just log that migrations would run here
        logger.info("Database migrations would run here")
        
        # Example migration check
        migration_check_query = """
        SELECT EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'factory_telemetry' 
            AND table_name = 'production_lines'
        ) as table_exists
        """
        
        table_exists = await execute_scalar(migration_check_query)
        
        if not table_exists:
            logger.warning("Production tables not found. Run migrations first.")
        else:
            logger.info("Production tables found. Database schema is up to date.")
            
    except Exception as e:
        logger.error("Migration check failed", error=str(e))
        raise


# Connection pool monitoring
async def get_connection_pool_status() -> dict:
    """Get connection pool status information."""
    try:
        if not async_engine:
            return {"error": "Database not initialized"}
        
        pool = async_engine.pool
        
        return {
            "pool_size": pool.size(),
            "checked_in": pool.checkedin(),
            "checked_out": pool.checkedout(),
            "overflow": pool.overflow(),
            "invalid": pool.invalid()
        }
        
    except Exception as e:
        logger.error("Failed to get connection pool status", error=str(e))
        return {"error": str(e)}


# Database cleanup utilities
async def cleanup_old_data() -> None:
    """Clean up old data based on retention policies."""
    try:
        # Clean up old reports
        cleanup_reports_query = """
        DELETE FROM factory_telemetry.production_reports 
        WHERE generated_at < NOW() - INTERVAL '%s days'
        """ % settings.REPORT_RETENTION_DAYS
        
        deleted_reports = await execute_update(cleanup_reports_query)
        logger.info(f"Cleaned up {deleted_reports} old reports")
        
        # Clean up old OEE calculations (keep last 90 days)
        cleanup_oee_query = """
        DELETE FROM factory_telemetry.oee_calculations 
        WHERE calculation_time < NOW() - INTERVAL '90 days'
        """
        
        deleted_oee = await execute_update(cleanup_oee_query)
        logger.info(f"Cleaned up {deleted_oee} old OEE calculations")
        
    except Exception as e:
        logger.error("Data cleanup failed", error=str(e))
        raise


# ============================================================================
# TimescaleDB Management Functions
# ============================================================================

async def check_timescaledb_extension() -> bool:
    """
    Verify that TimescaleDB extension is installed and available.
    
    Returns:
        bool: True if TimescaleDB is available, False otherwise
    """
    try:
        query = """
        SELECT EXISTS(
            SELECT 1 FROM pg_extension WHERE extname = 'timescaledb'
        ) as timescaledb_installed;
        """
        result = await execute_scalar(query)
        
        if result:
            logger.info("TimescaleDB extension verified")
            return True
        else:
            logger.warning("TimescaleDB extension not found")
            return False
            
    except Exception as e:
        logger.error("Failed to check TimescaleDB extension", error=str(e))
        return False


async def get_timescaledb_version() -> Optional[str]:
    """
    Get the installed TimescaleDB version.
    
    Returns:
        Optional[str]: Version string or None if not available
    """
    try:
        query = """
        SELECT extversion 
        FROM pg_extension 
        WHERE extname = 'timescaledb';
        """
        version = await execute_scalar(query)
        
        if version:
            logger.info(f"TimescaleDB version: {version}")
            return version
        else:
            logger.warning("TimescaleDB version not found")
            return None
            
    except Exception as e:
        logger.error("Failed to get TimescaleDB version", error=str(e))
        return None


async def setup_timescaledb_policies() -> None:
    """
    Configure TimescaleDB compression and retention policies for all hypertables.
    
    This function sets up:
    - Compression policies for efficient storage
    - Retention policies for automatic data cleanup
    - Chunk interval optimization for each hypertable
    
    Called during application startup to ensure policies are configured.
    """
    try:
        # Verify TimescaleDB is available
        if not await check_timescaledb_extension():
            logger.error("Cannot setup policies: TimescaleDB extension not available")
            return
        
        async with get_db_session() as session:
            # ================================================================
            # Configure metric_hist hypertable (high-frequency data)
            # ================================================================
            
            # Set chunk interval for metric_hist
            try:
                await session.execute(text(f"""
                    SELECT set_chunk_time_interval(
                        'factory_telemetry.metric_hist', 
                        INTERVAL '{settings.TIMESCALEDB_CHUNK_TIME_INTERVAL_METRIC_HIST}'
                    );
                """))
                logger.info(
                    "Chunk interval configured for metric_hist",
                    interval=settings.TIMESCALEDB_CHUNK_TIME_INTERVAL_METRIC_HIST
                )
            except Exception as e:
                # Hypertable might not exist yet or already configured
                logger.debug("Metric_hist chunk interval setup skipped", error=str(e))
            
            # Enable compression on metric_hist
            if settings.TIMESCALEDB_COMPRESSION_ENABLED:
                try:
                    await session.execute(text("""
                        ALTER TABLE factory_telemetry.metric_hist SET (
                            timescaledb.compress,
                            timescaledb.compress_segmentby = 'metric_def_id',
                            timescaledb.compress_orderby = 'ts DESC'
                        );
                    """))
                    logger.info("Compression enabled for metric_hist")
                except Exception as e:
                    logger.debug("Metric_hist compression setup skipped", error=str(e))
                
                # Add compression policy
                try:
                    await session.execute(text(f"""
                        SELECT add_compression_policy(
                            'factory_telemetry.metric_hist',
                            INTERVAL '{settings.TIMESCALEDB_COMPRESSION_AFTER}',
                            if_not_exists => TRUE
                        );
                    """))
                    logger.info(
                        "Compression policy added for metric_hist",
                        after=settings.TIMESCALEDB_COMPRESSION_AFTER
                    )
                except Exception as e:
                    logger.debug("Metric_hist compression policy skipped", error=str(e))
            
            # Add retention policy for metric_hist
            try:
                await session.execute(text(f"""
                    SELECT add_retention_policy(
                        'factory_telemetry.metric_hist',
                        INTERVAL '{settings.TIMESCALEDB_RETENTION_POLICY_METRIC_HIST}',
                        if_not_exists => TRUE
                    );
                """))
                logger.info(
                    "Retention policy added for metric_hist",
                    retention=settings.TIMESCALEDB_RETENTION_POLICY_METRIC_HIST
                )
            except Exception as e:
                logger.debug("Metric_hist retention policy skipped", error=str(e))
            
            # ================================================================
            # Configure oee_calculations hypertable
            # ================================================================
            
            # Set chunk interval for oee_calculations
            try:
                await session.execute(text(f"""
                    SELECT set_chunk_time_interval(
                        'factory_telemetry.oee_calculations',
                        INTERVAL '{settings.TIMESCALEDB_CHUNK_TIME_INTERVAL_OEE}'
                    );
                """))
                logger.info(
                    "Chunk interval configured for oee_calculations",
                    interval=settings.TIMESCALEDB_CHUNK_TIME_INTERVAL_OEE
                )
            except Exception as e:
                logger.debug("OEE chunk interval setup skipped", error=str(e))
            
            # Enable compression on oee_calculations
            if settings.TIMESCALEDB_COMPRESSION_ENABLED:
                try:
                    await session.execute(text("""
                        ALTER TABLE factory_telemetry.oee_calculations SET (
                            timescaledb.compress,
                            timescaledb.compress_segmentby = 'line_id',
                            timescaledb.compress_orderby = 'calculation_time DESC'
                        );
                    """))
                    logger.info("Compression enabled for oee_calculations")
                except Exception as e:
                    logger.debug("OEE compression setup skipped", error=str(e))
                
                # Add compression policy
                try:
                    await session.execute(text(f"""
                        SELECT add_compression_policy(
                            'factory_telemetry.oee_calculations',
                            INTERVAL '{settings.TIMESCALEDB_COMPRESSION_AFTER}',
                            if_not_exists => TRUE
                        );
                    """))
                    logger.info(
                        "Compression policy added for oee_calculations",
                        after=settings.TIMESCALEDB_COMPRESSION_AFTER
                    )
                except Exception as e:
                    logger.debug("OEE compression policy skipped", error=str(e))
            
            # Add retention policy for oee_calculations
            try:
                await session.execute(text(f"""
                    SELECT add_retention_policy(
                        'factory_telemetry.oee_calculations',
                        INTERVAL '{settings.TIMESCALEDB_RETENTION_POLICY_OEE}',
                        if_not_exists => TRUE
                    );
                """))
                logger.info(
                    "Retention policy added for oee_calculations",
                    retention=settings.TIMESCALEDB_RETENTION_POLICY_OEE
                )
            except Exception as e:
                logger.debug("OEE retention policy skipped", error=str(e))
            
            # ================================================================
            # Configure additional hypertables (energy_consumption, production_kpis)
            # ================================================================
            
            for table_name in ['energy_consumption', 'production_kpis']:
                try:
                    # Set chunk interval
                    await session.execute(text(f"""
                        SELECT set_chunk_time_interval(
                            'factory_telemetry.{table_name}',
                            INTERVAL '{settings.TIMESCALEDB_CHUNK_TIME_INTERVAL}'
                        );
                    """))
                    logger.info(f"Chunk interval configured for {table_name}")
                    
                    # Enable compression
                    if settings.TIMESCALEDB_COMPRESSION_ENABLED:
                        await session.execute(text(f"""
                            ALTER TABLE factory_telemetry.{table_name} SET (
                                timescaledb.compress,
                                timescaledb.compress_orderby = 'time DESC'
                            );
                        """))
                        
                        # Add compression policy
                        await session.execute(text(f"""
                            SELECT add_compression_policy(
                                'factory_telemetry.{table_name}',
                                INTERVAL '{settings.TIMESCALEDB_COMPRESSION_AFTER}',
                                if_not_exists => TRUE
                            );
                        """))
                        logger.info(f"Compression configured for {table_name}")
                    
                    # Add retention policy
                    await session.execute(text(f"""
                        SELECT add_retention_policy(
                            'factory_telemetry.{table_name}',
                            INTERVAL '{settings.TIMESCALEDB_RETENTION_POLICY}',
                            if_not_exists => TRUE
                        );
                    """))
                    logger.info(f"Retention policy configured for {table_name}")
                    
                except Exception as e:
                    logger.debug(f"{table_name} policy setup skipped", error=str(e))
            
            logger.info("✅ TimescaleDB policies configured successfully")
            
    except Exception as e:
        logger.error("Failed to configure TimescaleDB policies", error=str(e))
        # Don't raise - allow application to start even if policies fail
        # They can be configured manually later


async def get_hypertable_stats() -> dict:
    """
    Get statistics for all hypertables in the database.
    
    Returns:
        dict: Statistics including table names, chunk counts, sizes, compression ratios
    """
    try:
        query = """
        SELECT 
            hypertable_schema,
            hypertable_name,
            num_dimensions,
            num_chunks,
            pg_size_pretty(
                hypertable_size(format('%I.%I', hypertable_schema, hypertable_name)::regclass)
            ) as total_size,
            pg_size_pretty(
                hypertable_size(format('%I.%I', hypertable_schema, hypertable_name)::regclass) / 
                GREATEST(num_chunks, 1)
            ) as avg_chunk_size
        FROM timescaledb_information.hypertables
        WHERE hypertable_schema = 'factory_telemetry'
        ORDER BY hypertable_name;
        """
        
        result = await execute_query(query)
        
        hypertables = []
        for row in result:
            hypertables.append({
                "schema": row[0],
                "table": row[1],
                "dimensions": row[2],
                "chunk_count": row[3],
                "total_size": row[4],
                "avg_chunk_size": row[5]
            })
        
        logger.info(f"Retrieved stats for {len(hypertables)} hypertables")
        return {
            "hypertable_count": len(hypertables),
            "hypertables": hypertables
        }
        
    except Exception as e:
        logger.error("Failed to get hypertable stats", error=str(e))
        return {"error": str(e)}


async def get_compression_stats() -> dict:
    """
    Get compression statistics for all compressed hypertables.
    
    Returns:
        dict: Compression ratios, before/after sizes, chunk counts
    """
    try:
        query = """
        SELECT 
            hypertable_schema,
            hypertable_name,
            total_chunks,
            number_compressed_chunks,
            pg_size_pretty(before_compression_total_bytes) as before_compression,
            pg_size_pretty(after_compression_total_bytes) as after_compression,
            ROUND(
                100.0 * (before_compression_total_bytes - after_compression_total_bytes) / 
                NULLIF(before_compression_total_bytes, 0),
                2
            ) as compression_ratio_percent
        FROM timescaledb_information.compression_settings cs
        JOIN (
            SELECT 
                format('%I.%I', hypertable_schema, hypertable_name) as full_name,
                SUM(total_bytes) as before_compression_total_bytes,
                SUM(total_bytes) as after_compression_total_bytes,
                COUNT(*) as total_chunks,
                COUNT(*) FILTER (WHERE is_compressed) as number_compressed_chunks
            FROM timescaledb_information.chunks
            GROUP BY full_name
        ) chunk_stats ON format('%I.%I', cs.hypertable_schema, cs.hypertable_name) = chunk_stats.full_name
        WHERE hypertable_schema = 'factory_telemetry'
        ORDER BY hypertable_name;
        """
        
        result = await execute_query(query)
        
        compression_stats = []
        for row in result:
            compression_stats.append({
                "schema": row[0],
                "table": row[1],
                "total_chunks": row[2],
                "compressed_chunks": row[3],
                "before_compression": row[4],
                "after_compression": row[5],
                "compression_ratio_percent": float(row[6]) if row[6] else 0.0
            })
        
        logger.info(f"Retrieved compression stats for {len(compression_stats)} tables")
        return {
            "compressed_table_count": len(compression_stats),
            "tables": compression_stats
        }
        
    except Exception as e:
        logger.error("Failed to get compression stats", error=str(e))
        return {"error": str(e)}


async def get_chunk_details(table_name: str = None) -> dict:
    """
    Get detailed chunk information for hypertables.
    
    Args:
        table_name: Optional table name to filter results
        
    Returns:
        dict: Detailed chunk information including ranges, sizes, compression status
    """
    try:
        base_query = """
        SELECT 
            hypertable_name,
            chunk_name,
            range_start,
            range_end,
            pg_size_pretty(total_bytes) as chunk_size,
            is_compressed,
            chunk_schema
        FROM timescaledb_information.chunks
        WHERE hypertable_schema = 'factory_telemetry'
        """
        
        if table_name:
            query = base_query + f" AND hypertable_name = '{table_name}'"
        else:
            query = base_query
        
        query += " ORDER BY hypertable_name, range_start DESC LIMIT 100;"
        
        result = await execute_query(query)
        
        chunks = []
        for row in result:
            chunks.append({
                "table": row[0],
                "chunk_name": row[1],
                "range_start": str(row[2]) if row[2] else None,
                "range_end": str(row[3]) if row[3] else None,
                "size": row[4],
                "compressed": row[5],
                "schema": row[6]
            })
        
        logger.info(f"Retrieved details for {len(chunks)} chunks")
        return {
            "chunk_count": len(chunks),
            "chunks": chunks
        }
        
    except Exception as e:
        logger.error("Failed to get chunk details", error=str(e))
        return {"error": str(e)}


async def get_timescaledb_health() -> dict:
    """
    Comprehensive health check for TimescaleDB.
    
    Returns:
        dict: Health status including extension, policies, performance metrics
    """
    try:
        health_info = {
            "status": "healthy",
            "extension_installed": False,
            "version": None,
            "hypertables": {},
            "compression": {},
            "background_workers": {},
            "errors": []
        }
        
        # Check extension
        health_info["extension_installed"] = await check_timescaledb_extension()
        if not health_info["extension_installed"]:
            health_info["status"] = "degraded"
            health_info["errors"].append("TimescaleDB extension not installed")
            return health_info
        
        # Get version
        health_info["version"] = await get_timescaledb_version()
        
        # Get hypertable stats
        try:
            hypertable_stats = await get_hypertable_stats()
            health_info["hypertables"] = hypertable_stats
        except Exception as e:
            health_info["errors"].append(f"Failed to get hypertable stats: {str(e)}")
        
        # Get compression stats
        try:
            compression_stats = await get_compression_stats()
            health_info["compression"] = compression_stats
        except Exception as e:
            health_info["errors"].append(f"Failed to get compression stats: {str(e)}")
        
        # Check background workers
        try:
            worker_query = """
            SELECT 
                total_workers,
                free_workers,
                scheduled_jobs
            FROM timescaledb_information.jobs_stats
            LIMIT 1;
            """
            worker_result = await execute_query(worker_query)
            if worker_result:
                row = worker_result[0]
                health_info["background_workers"] = {
                    "total": row[0],
                    "free": row[1],
                    "scheduled_jobs": row[2]
                }
        except Exception as e:
            # Jobs stats might not be available in all versions
            logger.debug("Background worker stats not available", error=str(e))
        
        # Set status based on errors
        if len(health_info["errors"]) > 0:
            health_info["status"] = "degraded"
        
        logger.info("TimescaleDB health check completed", status=health_info["status"])
        return health_info
        
    except Exception as e:
        logger.error("TimescaleDB health check failed", error=str(e))
        return {
            "status": "unhealthy",
            "error": str(e)
        }
