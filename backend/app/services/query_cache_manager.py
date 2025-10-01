"""
MS5.0 Floor Dashboard - Advanced Query Cache Service

This module provides intelligent query caching with automatic invalidation,
cache warming, and performance optimization. Designed for cosmic-scale
performance with zero redundancy.
"""

import asyncio
import hashlib
import json
import time
from collections import defaultdict, deque
from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Dict, List, Optional, Set, Tuple, Union
from uuid import UUID

import redis.asyncio as redis
import structlog
from sqlalchemy import text

from app.config import settings
from app.database import execute_query, execute_scalar
from app.utils.exceptions import BusinessLogicError

logger = structlog.get_logger()


class CacheStrategy(Enum):
    """Cache strategy types."""
    CACHE_FIRST = "cache_first"           # Check cache first, fallback to DB
    DATABASE_FIRST = "database_first"     # Check DB first, update cache
    CACHE_ONLY = "cache_only"            # Only use cache, no DB fallback
    DATABASE_ONLY = "database_only"      # Bypass cache entirely


class CacheInvalidationReason(Enum):
    """Cache invalidation reasons."""
    TTL_EXPIRED = "ttl_expired"
    MANUAL_INVALIDATION = "manual_invalidation"
    DATA_CHANGE = "data_change"
    SCHEMA_CHANGE = "schema_change"
    MEMORY_PRESSURE = "memory_pressure"


@dataclass
class CacheEntry:
    """Cache entry with metadata."""
    key: str
    data: Any
    created_at: float
    ttl: float
    access_count: int = 0
    last_accessed: float = field(default_factory=time.time)
    tags: Set[str] = field(default_factory=set)
    dependencies: Set[str] = field(default_factory=set)


@dataclass
class CacheMetrics:
    """Cache performance metrics."""
    hits: int = 0
    misses: int = 0
    evictions: int = 0
    invalidations: int = 0
    total_requests: int = 0
    hit_ratio: float = 0.0
    avg_response_time: float = 0.0
    memory_usage: int = 0
    entry_count: int = 0


class QueryCacheManager:
    """Advanced query cache manager with intelligent invalidation."""
    
    def __init__(self):
        self.redis_client: Optional[redis.Redis] = None
        self.local_cache: Dict[str, CacheEntry] = {}
        self.cache_metrics = CacheMetrics()
        self.invalidation_triggers: Dict[str, Set[str]] = defaultdict(set)
        self.access_patterns: deque = deque(maxlen=10000)
        self.max_local_cache_size = 1000
        self.cache_warming_queue: deque = deque()
        
        # Cache configuration
        self.default_ttl = 300  # 5 minutes
        self.max_ttl = 3600     # 1 hour
        self.min_ttl = 60       # 1 minute
        
    async def initialize(self):
        """Initialize cache manager with Redis connection."""
        try:
            if settings.REDIS_URL:
                self.redis_client = redis.from_url(
                    settings.REDIS_URL,
                    encoding="utf-8",
                    decode_responses=True,
                    socket_connect_timeout=5,
                    socket_timeout=5,
                    retry_on_timeout=True
                )
                
                # Test connection
                await self.redis_client.ping()
                logger.info("Query cache manager initialized with Redis")
            else:
                logger.warning("Redis not configured, using local cache only")
                
        except Exception as e:
            logger.error("Failed to initialize cache manager", error=str(e))
            self.redis_client = None
    
    def _generate_cache_key(self, query: str, params: Dict = None) -> str:
        """Generate cache key from query and parameters."""
        # Normalize query (remove extra whitespace, sort parameters)
        normalized_query = " ".join(query.split())
        
        # Create hash of query + params
        cache_data = {
            "query": normalized_query,
            "params": params or {}
        }
        
        cache_string = json.dumps(cache_data, sort_keys=True)
        return f"query:{hashlib.sha256(cache_string.encode()).hexdigest()}"
    
    def _extract_table_dependencies(self, query: str) -> Set[str]:
        """Extract table dependencies from query."""
        import re
        
        tables = set()
        
        # Extract FROM clauses
        from_matches = re.findall(r'FROM\s+factory_telemetry\.(\w+)', query, re.IGNORECASE)
        tables.update(from_matches)
        
        # Extract JOIN clauses
        join_matches = re.findall(r'JOIN\s+factory_telemetry\.(\w+)', query, re.IGNORECASE)
        tables.update(join_matches)
        
        # Extract UPDATE clauses
        update_matches = re.findall(r'UPDATE\s+factory_telemetry\.(\w+)', query, re.IGNORECASE)
        tables.update(update_matches)
        
        # Extract INSERT clauses
        insert_matches = re.findall(r'INSERT\s+INTO\s+factory_telemetry\.(\w+)', query, re.IGNORECASE)
        tables.update(insert_matches)
        
        # Extract DELETE clauses
        delete_matches = re.findall(r'DELETE\s+FROM\s+factory_telemetry\.(\w+)', query, re.IGNORECASE)
        tables.update(delete_matches)
        
        return tables
    
    async def get_cached_query(
        self, 
        query: str, 
        params: Dict = None,
        strategy: CacheStrategy = CacheStrategy.CACHE_FIRST,
        ttl: Optional[int] = None
    ) -> Optional[Any]:
        """Get cached query result."""
        cache_key = self._generate_cache_key(query, params)
        start_time = time.time()
        
        try:
            # Update metrics
            self.cache_metrics.total_requests += 1
            
            # Try local cache first
            if cache_key in self.local_cache:
                entry = self.local_cache[cache_key]
                
                # Check TTL
                if time.time() - entry.created_at < entry.ttl:
                    entry.access_count += 1
                    entry.last_accessed = time.time()
                    self.cache_metrics.hits += 1
                    
                    # Record access pattern
                    self.access_patterns.append({
                        'key': cache_key,
                        'timestamp': time.time(),
                        'access_count': entry.access_count
                    })
                    
                    logger.debug("Cache hit (local)", key=cache_key)
                    return entry.data
                else:
                    # TTL expired, remove from local cache
                    del self.local_cache[cache_key]
            
            # Try Redis cache
            if self.redis_client:
                try:
                    cached_data = await self.redis_client.get(cache_key)
                    if cached_data:
                        data = json.loads(cached_data)
                        self.cache_metrics.hits += 1
                        
                        # Store in local cache for faster access
                        self.local_cache[cache_key] = CacheEntry(
                            key=cache_key,
                            data=data,
                            created_at=time.time(),
                            ttl=ttl or self.default_ttl,
                            access_count=1,
                            tags=self._extract_table_dependencies(query)
                        )
                        
                        logger.debug("Cache hit (Redis)", key=cache_key)
                        return data
                        
                except Exception as e:
                    logger.warning("Redis cache error", error=str(e))
            
            # Cache miss
            self.cache_metrics.misses += 1
            logger.debug("Cache miss", key=cache_key)
            return None
            
        except Exception as e:
            logger.error("Cache retrieval error", error=str(e), key=cache_key)
            return None
        finally:
            # Update response time metrics
            response_time = time.time() - start_time
            self.cache_metrics.avg_response_time = (
                (self.cache_metrics.avg_response_time * (self.cache_metrics.total_requests - 1) + response_time) /
                self.cache_metrics.total_requests
            )
    
    async def set_cached_query(
        self, 
        query: str, 
        data: Any, 
        params: Dict = None,
        ttl: Optional[int] = None,
        tags: Optional[Set[str]] = None
    ) -> bool:
        """Set cached query result."""
        cache_key = self._generate_cache_key(query, params)
        cache_ttl = ttl or self.default_ttl
        
        try:
            # Extract table dependencies for invalidation
            table_dependencies = self._extract_table_dependencies(query)
            if tags:
                table_dependencies.update(tags)
            
            # Create cache entry
            entry = CacheEntry(
                key=cache_key,
                data=data,
                created_at=time.time(),
                ttl=cache_ttl,
                access_count=1,
                tags=table_dependencies,
                dependencies=table_dependencies
            )
            
            # Store in local cache
            self.local_cache[cache_key] = entry
            
            # Store in Redis cache
            if self.redis_client:
                try:
                    await self.redis_client.setex(
                        cache_key,
                        cache_ttl,
                        json.dumps(data, default=str)
                    )
                except Exception as e:
                    logger.warning("Redis cache set error", error=str(e))
            
            # Update invalidation triggers
            for table in table_dependencies:
                self.invalidation_triggers[table].add(cache_key)
            
            logger.debug("Query cached", key=cache_key, ttl=cache_ttl)
            return True
            
        except Exception as e:
            logger.error("Cache set error", error=str(e), key=cache_key)
            return False
    
    async def invalidate_by_table(self, table_name: str) -> int:
        """Invalidate all cached queries that depend on a table."""
        invalidated_count = 0
        
        try:
            # Get affected cache keys
            affected_keys = self.invalidation_triggers.get(table_name, set())
            
            # Remove from local cache
            for key in affected_keys:
                if key in self.local_cache:
                    del self.local_cache[key]
                    invalidated_count += 1
            
            # Remove from Redis cache
            if self.redis_client and affected_keys:
                try:
                    await self.redis_client.delete(*affected_keys)
                except Exception as e:
                    logger.warning("Redis invalidation error", error=str(e))
            
            # Clear invalidation triggers
            if table_name in self.invalidation_triggers:
                del self.invalidation_triggers[table_name]
            
            self.cache_metrics.invalidations += invalidated_count
            
            logger.info(
                "Cache invalidated by table",
                table=table_name,
                count=invalidated_count
            )
            
            return invalidated_count
            
        except Exception as e:
            logger.error("Cache invalidation error", error=str(e), table=table_name)
            return 0
    
    async def invalidate_by_pattern(self, pattern: str) -> int:
        """Invalidate cached queries matching a pattern."""
        invalidated_count = 0
        
        try:
            import re
            pattern_regex = re.compile(pattern, re.IGNORECASE)
            
            # Find matching keys in local cache
            matching_keys = [
                key for key in self.local_cache.keys()
                if pattern_regex.search(key)
            ]
            
            # Remove from local cache
            for key in matching_keys:
                del self.local_cache[key]
                invalidated_count += 1
            
            # Remove from Redis cache
            if self.redis_client and matching_keys:
                try:
                    await self.redis_client.delete(*matching_keys)
                except Exception as e:
                    logger.warning("Redis pattern invalidation error", error=str(e))
            
            self.cache_metrics.invalidations += invalidated_count
            
            logger.info(
                "Cache invalidated by pattern",
                pattern=pattern,
                count=invalidated_count
            )
            
            return invalidated_count
            
        except Exception as e:
            logger.error("Pattern invalidation error", error=str(e), pattern=pattern)
            return 0
    
    async def warm_cache(self, queries: List[Tuple[str, Dict]]) -> Dict[str, Any]:
        """Warm cache with frequently used queries."""
        warming_results = {
            'queries_warmed': 0,
            'successful_warms': 0,
            'failed_warms': 0,
            'total_time': 0.0
        }
        
        start_time = time.time()
        
        try:
            for query, params in queries:
                try:
                    # Execute query
                    result = await execute_query(query, params)
                    
                    # Cache result
                    await self.set_cached_query(query, result, params)
                    
                    warming_results['successful_warms'] += 1
                    
                except Exception as e:
                    logger.warning("Cache warming failed", error=str(e), query=query[:100])
                    warming_results['failed_warms'] += 1
                
                warming_results['queries_warmed'] += 1
            
            warming_results['total_time'] = time.time() - start_time
            
            logger.info(
                "Cache warming completed",
                queries_warmed=warming_results['queries_warmed'],
                successful=warming_results['successful_warms'],
                failed=warming_results['failed_warms']
            )
            
            return warming_results
            
        except Exception as e:
            logger.error("Cache warming error", error=str(e))
            raise BusinessLogicError("Cache warming failed")
    
    async def cleanup_expired_entries(self) -> int:
        """Clean up expired cache entries."""
        current_time = time.time()
        expired_keys = []
        
        # Find expired entries in local cache
        for key, entry in self.local_cache.items():
            if current_time - entry.created_at >= entry.ttl:
                expired_keys.append(key)
        
        # Remove expired entries
        for key in expired_keys:
            del self.local_cache[key]
        
        self.cache_metrics.evictions += len(expired_keys)
        
        logger.debug("Expired entries cleaned up", count=len(expired_keys))
        return len(expired_keys)
    
    async def optimize_cache_memory(self) -> Dict[str, Any]:
        """Optimize cache memory usage by evicting least recently used entries."""
        optimization_results = {
            'entries_evicted': 0,
            'memory_freed': 0,
            'cache_size_before': len(self.local_cache),
            'cache_size_after': 0
        }
        
        try:
            # If cache is over limit, evict least recently used entries
            if len(self.local_cache) > self.max_local_cache_size:
                # Sort by last accessed time
                sorted_entries = sorted(
                    self.local_cache.items(),
                    key=lambda x: x[1].last_accessed
                )
                
                # Evict oldest entries
                entries_to_evict = len(self.local_cache) - self.max_local_cache_size
                for key, entry in sorted_entries[:entries_to_evict]:
                    del self.local_cache[key]
                    optimization_results['entries_evicted'] += 1
            
            optimization_results['cache_size_after'] = len(self.local_cache)
            
            logger.info(
                "Cache memory optimized",
                evicted=optimization_results['entries_evicted'],
                size_before=optimization_results['cache_size_before'],
                size_after=optimization_results['cache_size_after']
            )
            
            return optimization_results
            
        except Exception as e:
            logger.error("Cache optimization error", error=str(e))
            raise BusinessLogicError("Cache optimization failed")
    
    def get_cache_metrics(self) -> CacheMetrics:
        """Get current cache performance metrics."""
        # Calculate hit ratio
        if self.cache_metrics.total_requests > 0:
            self.cache_metrics.hit_ratio = (
                self.cache_metrics.hits / self.cache_metrics.total_requests
            )
        
        # Update entry count
        self.cache_metrics.entry_count = len(self.local_cache)
        
        return self.cache_metrics
    
    async def get_cache_report(self) -> Dict[str, Any]:
        """Get comprehensive cache performance report."""
        try:
            metrics = self.get_cache_metrics()
            
            # Analyze access patterns
            recent_accesses = list(self.access_patterns)[-1000:] if len(self.access_patterns) >= 1000 else list(self.access_patterns)
            
            # Get most accessed keys
            key_access_counts = defaultdict(int)
            for access in recent_accesses:
                key_access_counts[access['key']] += 1
            
            most_accessed = sorted(
                key_access_counts.items(),
                key=lambda x: x[1],
                reverse=True
            )[:10]
            
            return {
                'metrics': {
                    'hits': metrics.hits,
                    'misses': metrics.misses,
                    'hit_ratio': metrics.hit_ratio,
                    'total_requests': metrics.total_requests,
                    'avg_response_time': metrics.avg_response_time,
                    'evictions': metrics.evictions,
                    'invalidations': metrics.invalidations,
                    'entry_count': metrics.entry_count
                },
                'access_patterns': {
                    'most_accessed_keys': [
                        {'key': key, 'access_count': count}
                        for key, count in most_accessed
                    ],
                    'total_unique_keys': len(key_access_counts)
                },
                'cache_status': {
                    'local_cache_size': len(self.local_cache),
                    'max_local_cache_size': self.max_local_cache_size,
                    'redis_connected': self.redis_client is not None,
                    'invalidation_triggers': len(self.invalidation_triggers)
                }
            }
            
        except Exception as e:
            logger.error("Failed to generate cache report", error=str(e))
            raise BusinessLogicError("Failed to generate cache report")


# Global cache manager instance
_query_cache_manager = QueryCacheManager()


async def initialize_query_cache():
    """Initialize the global query cache manager."""
    await _query_cache_manager.initialize()


async def get_cached_query(
    query: str, 
    params: Dict = None,
    strategy: CacheStrategy = CacheStrategy.CACHE_FIRST,
    ttl: Optional[int] = None
) -> Optional[Any]:
    """Get cached query result using the global cache manager."""
    return await _query_cache_manager.get_cached_query(query, params, strategy, ttl)


async def set_cached_query(
    query: str, 
    data: Any, 
    params: Dict = None,
    ttl: Optional[int] = None,
    tags: Optional[Set[str]] = None
) -> bool:
    """Set cached query result using the global cache manager."""
    return await _query_cache_manager.set_cached_query(query, data, params, ttl, tags)


async def invalidate_cache_by_table(table_name: str) -> int:
    """Invalidate cache by table using the global cache manager."""
    return await _query_cache_manager.invalidate_by_table(table_name)


async def get_cache_performance_report() -> Dict[str, Any]:
    """Get cache performance report using the global cache manager."""
    return await _query_cache_manager.get_cache_report()
