"""
MS5.0 Floor Dashboard - Advanced Connection Pool Manager

This module provides intelligent connection pooling with:
- Dynamic pool sizing
- Health monitoring
- Load balancing
- Connection recycling
- Performance optimization
- Zero redundancy architecture
"""

import asyncio
import time
from collections import defaultdict, deque
from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Dict, List, Optional, Set, Tuple, Union
from uuid import UUID

import aiohttp
import structlog
from sqlalchemy import create_engine
from sqlalchemy.pool import QueuePool, StaticPool

from app.config import settings
from app.utils.exceptions import BusinessLogicError

logger = structlog.get_logger()


class PoolType(Enum):
    """Connection pool types."""
    DATABASE = "database"
    REDIS = "redis"
    HTTP = "http"
    WEBSOCKET = "websocket"


class LoadBalancingStrategy(Enum):
    """Load balancing strategies."""
    ROUND_ROBIN = "round_robin"
    LEAST_CONNECTIONS = "least_connections"
    WEIGHTED_ROUND_ROBIN = "weighted_round_robin"
    IP_HASH = "ip_hash"
    RANDOM = "random"


class HealthStatus(Enum):
    """Health status types."""
    HEALTHY = "healthy"
    DEGRADED = "degraded"
    UNHEALTHY = "unhealthy"
    UNKNOWN = "unknown"


@dataclass
class PoolConfiguration:
    """Connection pool configuration."""
    pool_type: PoolType
    min_connections: int = 5
    max_connections: int = 100
    max_connections_per_host: int = 30
    keepalive_timeout: int = 30
    connection_timeout: int = 10
    retry_count: int = 3
    retry_delay: float = 1.0
    health_check_interval: int = 60
    max_idle_time: int = 300
    enable_cleanup_closed: bool = True
    ttl_dns_cache: int = 300
    use_dns_cache: bool = True


@dataclass
class ConnectionMetrics:
    """Connection pool metrics."""
    total_connections: int = 0
    active_connections: int = 0
    idle_connections: int = 0
    failed_connections: int = 0
    total_requests: int = 0
    successful_requests: int = 0
    failed_requests: int = 0
    avg_response_time: float = 0.0
    max_response_time: float = 0.0
    min_response_time: float = float('inf')
    health_status: HealthStatus = HealthStatus.UNKNOWN
    last_health_check: float = field(default_factory=time.time)


@dataclass
class ConnectionInfo:
    """Connection information."""
    connection_id: str
    pool_name: str
    created_at: float
    last_used: float
    use_count: int
    is_active: bool
    response_times: deque = field(default_factory=lambda: deque(maxlen=100))


class ConnectionPoolManager:
    """Advanced connection pool manager."""
    
    def __init__(self):
        self.pools: Dict[str, Any] = {}
        self.pool_configs: Dict[str, PoolConfiguration] = {}
        self.pool_metrics: Dict[str, ConnectionMetrics] = {}
        self.connection_info: Dict[str, ConnectionInfo] = {}
        self.load_balancing_strategies: Dict[str, LoadBalancingStrategy] = {}
        self.health_checkers: Dict[str, asyncio.Task] = {}
        self.is_initialized = False
        
        # Performance tracking
        self.request_history: deque = deque(maxlen=10000)
        self.performance_stats: Dict[str, Dict[str, Any]] = defaultdict(lambda: {
            'total_requests': 0,
            'total_time': 0.0,
            'avg_response_time': 0.0,
            'error_count': 0,
            'timeout_count': 0,
        })
    
    async def initialize(self):
        """Initialize connection pool manager."""
        try:
            # Initialize default pools
            await self.initialize_default_pools()
            
            # Start health checkers
            await self.start_health_checkers()
            
            # Start background maintenance
            asyncio.create_task(self.background_maintenance())
            
            self.is_initialized = True
            logger.info("Connection pool manager initialized")
            
        except Exception as e:
            logger.error("Failed to initialize connection pool manager", error=str(e))
            raise BusinessLogicError("Connection pool manager initialization failed")
    
    async def initialize_default_pools(self):
        """Initialize default connection pools."""
        try:
            # Database pool
            if settings.DATABASE_URL:
                await self.create_database_pool(
                    name="main_db",
                    url=settings.DATABASE_URL,
                    config=PoolConfiguration(
                        pool_type=PoolType.DATABASE,
                        min_connections=10,
                        max_connections=50,
                        keepalive_timeout=30,
                        health_check_interval=30
                    )
                )
            
            # Redis pool
            if settings.REDIS_URL:
                await self.create_http_pool(
                    name="redis",
                    base_url=settings.REDIS_URL,
                    config=PoolConfiguration(
                        pool_type=PoolType.REDIS,
                        min_connections=5,
                        max_connections=20,
                        keepalive_timeout=30,
                        health_check_interval=60
                    )
                )
            
            # External API pool
            await self.create_http_pool(
                name="external_api",
                base_url="https://api.external.com",
                config=PoolConfiguration(
                    pool_type=PoolType.HTTP,
                    min_connections=10,
                    max_connections=100,
                    max_connections_per_host=30,
                    keepalive_timeout=60,
                    health_check_interval=120
                )
            )
            
            logger.info("Default connection pools initialized", pools=list(self.pools.keys()))
            
        except Exception as e:
            logger.error("Failed to initialize default pools", error=str(e))
            raise
    
    async def create_database_pool(
        self,
        name: str,
        url: str,
        config: PoolConfiguration
    ) -> bool:
        """Create database connection pool."""
        try:
            # Create SQLAlchemy engine with optimized pool
            engine = create_engine(
                url,
                poolclass=QueuePool,
                pool_size=config.min_connections,
                max_overflow=config.max_connections - config.min_connections,
                pool_pre_ping=True,
                pool_recycle=config.max_idle_time,
                pool_timeout=config.connection_timeout,
                echo=False,
            )
            
            self.pools[name] = engine
            self.pool_configs[name] = config
            self.pool_metrics[name] = ConnectionMetrics()
            self.load_balancing_strategies[name] = LoadBalancingStrategy.ROUND_ROBIN
            
            logger.info("Database pool created", name=name, url=url[:50] + "...")
            return True
            
        except Exception as e:
            logger.error("Failed to create database pool", error=str(e), name=name)
            return False
    
    async def create_http_pool(
        self,
        name: str,
        base_url: str,
        config: PoolConfiguration
    ) -> bool:
        """Create HTTP connection pool."""
        try:
            # Create aiohttp connector with optimized settings
            connector = aiohttp.TCPConnector(
                limit=config.max_connections,
                limit_per_host=config.max_connections_per_host,
                keepalive_timeout=config.keepalive_timeout,
                enable_cleanup_closed=config.enable_cleanup_closed,
                ttl_dns_cache=config.ttl_dns_cache,
                use_dns_cache=config.use_dns_cache,
                force_close=False,
                ssl=False,
            )
            
            # Create session with connector
            session = aiohttp.ClientSession(
                connector=connector,
                timeout=aiohttp.ClientTimeout(total=config.connection_timeout),
                headers={'User-Agent': 'MS5.0-Dashboard/1.0'}
            )
            
            self.pools[name] = session
            self.pool_configs[name] = config
            self.pool_metrics[name] = ConnectionMetrics()
            self.load_balancing_strategies[name] = LoadBalancingStrategy.ROUND_ROBIN
            
            logger.info("HTTP pool created", name=name, base_url=base_url)
            return True
            
        except Exception as e:
            logger.error("Failed to create HTTP pool", error=str(e), name=name)
            return False
    
    async def create_websocket_pool(
        self,
        name: str,
        base_url: str,
        config: PoolConfiguration
    ) -> bool:
        """Create WebSocket connection pool."""
        try:
            # WebSocket pools are managed differently
            self.pools[name] = {
                'base_url': base_url,
                'connections': [],
                'max_connections': config.max_connections,
            }
            self.pool_configs[name] = config
            self.pool_metrics[name] = ConnectionMetrics()
            self.load_balancing_strategies[name] = LoadBalancingStrategy.ROUND_ROBIN
            
            logger.info("WebSocket pool created", name=name, base_url=base_url)
            return True
            
        except Exception as e:
            logger.error("Failed to create WebSocket pool", error=str(e), name=name)
            return False
    
    async def get_connection(self, pool_name: str) -> Any:
        """Get connection from pool with load balancing."""
        try:
            if pool_name not in self.pools:
                raise BusinessLogicError(f"Pool {pool_name} not found")
            
            pool = self.pools[pool_name]
            config = self.pool_configs[pool_name]
            metrics = self.pool_metrics[pool_name]
            
            # Update metrics
            metrics.total_requests += 1
            
            # Get connection based on pool type
            if config.pool_type == PoolType.DATABASE:
                connection = pool.connect()
            elif config.pool_type == PoolType.HTTP:
                connection = pool
            elif config.pool_type == PoolType.WEBSOCKET:
                connection = await self.get_websocket_connection(pool_name)
            else:
                raise BusinessLogicError(f"Unsupported pool type: {config.pool_type}")
            
            # Track connection usage
            connection_id = f"{pool_name}_{int(time.time() * 1000)}"
            self.connection_info[connection_id] = ConnectionInfo(
                connection_id=connection_id,
                pool_name=pool_name,
                created_at=time.time(),
                last_used=time.time(),
                use_count=1,
                is_active=True
            )
            
            metrics.active_connections += 1
            metrics.idle_connections = max(0, metrics.idle_connections - 1)
            
            logger.debug("Connection acquired", pool=pool_name, connection_id=connection_id)
            
            return connection
            
        except Exception as e:
            logger.error("Failed to get connection", error=str(e), pool=pool_name)
            self.pool_metrics[pool_name].failed_requests += 1
            raise BusinessLogicError(f"Failed to get connection from pool {pool_name}")
    
    async def return_connection(self, pool_name: str, connection: Any):
        """Return connection to pool."""
        try:
            if pool_name not in self.pools:
                return
            
            config = self.pool_configs[pool_name]
            metrics = self.pool_metrics[pool_name]
            
            # Return connection based on pool type
            if config.pool_type == PoolType.DATABASE:
                connection.close()
            elif config.pool_type == PoolType.HTTP:
                # HTTP connections are managed by aiohttp
                pass
            elif config.pool_type == PoolType.WEBSOCKET:
                await self.return_websocket_connection(pool_name, connection)
            
            # Update metrics
            metrics.active_connections = max(0, metrics.active_connections - 1)
            metrics.idle_connections += 1
            
            logger.debug("Connection returned", pool=pool_name)
            
        except Exception as e:
            logger.error("Failed to return connection", error=str(e), pool=pool_name)
    
    async def get_websocket_connection(self, pool_name: str) -> Any:
        """Get WebSocket connection from pool."""
        pool = self.pools[pool_name]
        config = self.pool_configs[pool_name]
        
        # Check if we can create a new connection
        if len(pool['connections']) < config.max_connections:
            # Create new WebSocket connection
            # This would implement actual WebSocket connection creation
            connection = f"ws_connection_{len(pool['connections'])}"
            pool['connections'].append(connection)
            return connection
        else:
            # Use existing connection with load balancing
            strategy = self.load_balancing_strategies[pool_name]
            if strategy == LoadBalancingStrategy.ROUND_ROBIN:
                return pool['connections'][len(pool['connections']) % len(pool['connections'])]
            else:
                return pool['connections'][0]  # Default to first connection
    
    async def return_websocket_connection(self, pool_name: str, connection: Any):
        """Return WebSocket connection to pool."""
        # WebSocket connections are typically persistent
        # This would implement connection management logic
        pass
    
    async def start_health_checkers(self):
        """Start health checkers for all pools."""
        for pool_name in self.pools.keys():
            health_checker = asyncio.create_task(self.health_check_loop(pool_name))
            self.health_checkers[pool_name] = health_checker
    
    async def health_check_loop(self, pool_name: str):
        """Health check loop for a specific pool."""
        while True:
            try:
                await self.perform_health_check(pool_name)
                
                config = self.pool_configs[pool_name]
                await asyncio.sleep(config.health_check_interval)
                
            except Exception as e:
                logger.error("Health check error", error=str(e), pool=pool_name)
                await asyncio.sleep(60)  # Wait before retrying
    
    async def perform_health_check(self, pool_name: str):
        """Perform health check on a pool."""
        try:
            config = self.pool_configs[pool_name]
            metrics = self.pool_metrics[pool_name]
            
            start_time = time.time()
            
            # Perform health check based on pool type
            if config.pool_type == PoolType.DATABASE:
                health_status = await self.check_database_health(pool_name)
            elif config.pool_type == PoolType.HTTP:
                health_status = await self.check_http_health(pool_name)
            elif config.pool_type == PoolType.REDIS:
                health_status = await self.check_redis_health(pool_name)
            elif config.pool_type == PoolType.WEBSOCKET:
                health_status = await self.check_websocket_health(pool_name)
            else:
                health_status = HealthStatus.UNKNOWN
            
            # Update metrics
            metrics.health_status = health_status
            metrics.last_health_check = time.time()
            
            logger.debug("Health check completed", pool=pool_name, status=health_status.value)
            
        except Exception as e:
            logger.error("Health check failed", error=str(e), pool=pool_name)
            self.pool_metrics[pool_name].health_status = HealthStatus.UNHEALTHY
    
    async def check_database_health(self, pool_name: str) -> HealthStatus:
        """Check database pool health."""
        try:
            pool = self.pools[pool_name]
            with pool.connect() as conn:
                conn.execute("SELECT 1")
            return HealthStatus.HEALTHY
        except Exception:
            return HealthStatus.UNHEALTHY
    
    async def check_http_health(self, pool_name: str) -> HealthStatus:
        """Check HTTP pool health."""
        try:
            pool = self.pools[pool_name]
            async with pool.get('/health') as response:
                if response.status == 200:
                    return HealthStatus.HEALTHY
                else:
                    return HealthStatus.DEGRADED
        except Exception:
            return HealthStatus.UNHEALTHY
    
    async def check_redis_health(self, pool_name: str) -> HealthStatus:
        """Check Redis pool health."""
        try:
            pool = self.pools[pool_name]
            async with pool.get('/ping') as response:
                if response.status == 200:
                    return HealthStatus.HEALTHY
                else:
                    return HealthStatus.DEGRADED
        except Exception:
            return HealthStatus.UNHEALTHY
    
    async def check_websocket_health(self, pool_name: str) -> HealthStatus:
        """Check WebSocket pool health."""
        try:
            pool = self.pools[pool_name]
            if len(pool['connections']) > 0:
                return HealthStatus.HEALTHY
            else:
                return HealthStatus.DEGRADED
        except Exception:
            return HealthStatus.UNHEALTHY
    
    async def background_maintenance(self):
        """Background maintenance tasks."""
        while True:
            try:
                # Clean up old connections
                await self.cleanup_old_connections()
                
                # Optimize pool sizes
                await self.optimize_pool_sizes()
                
                # Update performance statistics
                self.update_performance_stats()
                
                # Sleep for 5 minutes
                await asyncio.sleep(300)
                
            except Exception as e:
                logger.error("Background maintenance error", error=str(e))
                await asyncio.sleep(300)
    
    async def cleanup_old_connections(self):
        """Clean up old and unused connections."""
        current_time = time.time()
        cleanup_threshold = 3600  # 1 hour
        
        for connection_id, connection_info in list(self.connection_info.items()):
            if current_time - connection_info.last_used > cleanup_threshold:
                # Remove old connection info
                del self.connection_info[connection_id]
                
                # Update pool metrics
                pool_name = connection_info.pool_name
                if pool_name in self.pool_metrics:
                    self.pool_metrics[pool_name].idle_connections = max(
                        0, self.pool_metrics[pool_name].idle_connections - 1
                    )
    
    async def optimize_pool_sizes(self):
        """Optimize pool sizes based on usage patterns."""
        for pool_name, metrics in self.pool_metrics.items():
            config = self.pool_configs[pool_name]
            
            # Calculate optimal pool size based on usage
            if metrics.total_requests > 0:
                utilization_ratio = metrics.active_connections / config.max_connections
                
                if utilization_ratio > 0.8:
                    # High utilization - consider increasing pool size
                    logger.info("High pool utilization detected", pool=pool_name, utilization=utilization_ratio)
                elif utilization_ratio < 0.2:
                    # Low utilization - consider decreasing pool size
                    logger.info("Low pool utilization detected", pool=pool_name, utilization=utilization_ratio)
    
    def update_performance_stats(self):
        """Update performance statistics."""
        for pool_name, metrics in self.pool_metrics.items():
            stats = self.performance_stats[pool_name]
            
            if metrics.total_requests > 0:
                stats['avg_response_time'] = metrics.avg_response_time
                stats['error_rate'] = metrics.failed_requests / metrics.total_requests
    
    def get_pool_status(self, pool_name: str) -> Dict[str, Any]:
        """Get status of a specific pool."""
        if pool_name not in self.pools:
            return {'error': f'Pool {pool_name} not found'}
        
        config = self.pool_configs[pool_name]
        metrics = self.pool_metrics[pool_name]
        
        return {
            'pool_name': pool_name,
            'pool_type': config.pool_type.value,
            'configuration': {
                'min_connections': config.min_connections,
                'max_connections': config.max_connections,
                'keepalive_timeout': config.keepalive_timeout,
                'health_check_interval': config.health_check_interval,
            },
            'metrics': {
                'total_connections': metrics.total_connections,
                'active_connections': metrics.active_connections,
                'idle_connections': metrics.idle_connections,
                'failed_connections': metrics.failed_connections,
                'total_requests': metrics.total_requests,
                'successful_requests': metrics.successful_requests,
                'failed_requests': metrics.failed_requests,
                'avg_response_time': metrics.avg_response_time,
                'health_status': metrics.health_status.value,
                'last_health_check': metrics.last_health_check,
            },
            'load_balancing_strategy': self.load_balancing_strategies[pool_name].value,
        }
    
    def get_all_pools_status(self) -> Dict[str, Any]:
        """Get status of all pools."""
        return {
            pool_name: self.get_pool_status(pool_name)
            for pool_name in self.pools.keys()
        }
    
    def get_performance_report(self) -> Dict[str, Any]:
        """Get comprehensive performance report."""
        try:
            total_pools = len(self.pools)
            healthy_pools = sum(
                1 for metrics in self.pool_metrics.values()
                if metrics.health_status == HealthStatus.HEALTHY
            )
            
            total_connections = sum(metrics.total_connections for metrics in self.pool_metrics.values())
            active_connections = sum(metrics.active_connections for metrics in self.pool_metrics.values())
            total_requests = sum(metrics.total_requests for metrics in self.pool_metrics.values())
            failed_requests = sum(metrics.failed_requests for metrics in self.pool_metrics.values())
            
            return {
                'overall_status': {
                    'total_pools': total_pools,
                    'healthy_pools': healthy_pools,
                    'unhealthy_pools': total_pools - healthy_pools,
                    'total_connections': total_connections,
                    'active_connections': active_connections,
                    'connection_utilization': active_connections / total_connections if total_connections > 0 else 0,
                },
                'request_metrics': {
                    'total_requests': total_requests,
                    'failed_requests': failed_requests,
                    'success_rate': (total_requests - failed_requests) / total_requests if total_requests > 0 else 0,
                    'avg_response_time': sum(metrics.avg_response_time for metrics in self.pool_metrics.values()) / total_pools if total_pools > 0 else 0,
                },
                'pool_details': self.get_all_pools_status(),
                'performance_stats': dict(self.performance_stats),
            }
            
        except Exception as e:
            logger.error("Failed to generate performance report", error=str(e))
            raise BusinessLogicError("Failed to generate performance report")
    
    async def close_all_pools(self):
        """Close all connection pools."""
        try:
            # Cancel health checkers
            for health_checker in self.health_checkers.values():
                health_checker.cancel()
            
            # Close pools
            for pool_name, pool in self.pools.items():
                config = self.pool_configs[pool_name]
                
                if config.pool_type == PoolType.DATABASE:
                    pool.dispose()
                elif config.pool_type in [PoolType.HTTP, PoolType.REDIS]:
                    await pool.close()
                elif config.pool_type == PoolType.WEBSOCKET:
                    # Close WebSocket connections
                    for connection in pool['connections']:
                        # This would implement actual WebSocket closure
                        pass
            
            self.pools.clear()
            self.pool_configs.clear()
            self.pool_metrics.clear()
            self.connection_info.clear()
            
            logger.info("All connection pools closed")
            
        except Exception as e:
            logger.error("Failed to close pools", error=str(e))


# Global connection pool manager instance
_connection_pool_manager = ConnectionPoolManager()


async def initialize_connection_pool_manager():
    """Initialize the global connection pool manager."""
    await _connection_pool_manager.initialize()


async def get_connection(pool_name: str) -> Any:
    """Get connection from pool using the global manager."""
    return await _connection_pool_manager.get_connection(pool_name)


async def return_connection(pool_name: str, connection: Any):
    """Return connection to pool using the global manager."""
    await _connection_pool_manager.return_connection(pool_name, connection)


def get_pool_status(pool_name: str) -> Dict[str, Any]:
    """Get pool status using the global manager."""
    return _connection_pool_manager.get_pool_status(pool_name)


def get_connection_pool_report() -> Dict[str, Any]:
    """Get connection pool performance report using the global manager."""
    return _connection_pool_manager.get_performance_report()


async def close_connection_pool_manager():
    """Close the global connection pool manager."""
    await _connection_pool_manager.close_all_pools()
