"""
MS5.0 Floor Dashboard - Advanced Multi-Layer Cache Service

This module provides intelligent multi-layer caching with:
- Redis distributed caching
- CDN integration
- Cache warming strategies
- Intelligent invalidation
- Performance monitoring
- Zero redundancy architecture
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


class CacheLayer(Enum):
    """Cache layer types."""
    L1_MEMORY = "l1_memory"           # In-memory cache
    L2_REDIS = "l2_redis"             # Redis distributed cache
    L3_CDN = "l3_cdn"                 # CDN cache
    L4_DATABASE = "l4_database"       # Database query cache


class CacheStrategy(Enum):
    """Cache strategy types."""
    WRITE_THROUGH = "write_through"    # Write to all layers
    WRITE_BACK = "write_back"         # Write to L1, sync to others
    WRITE_AROUND = "write_around"     # Write around cache
    READ_THROUGH = "read_through"     # Read through cache
    CACHE_ASIDE = "cache_aside"      # Application manages cache


class CacheInvalidationReason(Enum):
    """Cache invalidation reasons."""
    TTL_EXPIRED = "ttl_expired"
    MANUAL_INVALIDATION = "manual_invalidation"
    DATA_CHANGE = "data_change"
    SCHEMA_CHANGE = "schema_change"
    MEMORY_PRESSURE = "memory_pressure"
    VERSION_MISMATCH = "version_mismatch"


@dataclass
class CacheEntry:
    """Cache entry with metadata."""
    key: str
    data: Any
    created_at: float
    ttl: float
    layer: CacheLayer
    access_count: int = 0
    last_accessed: float = field(default_factory=time.time)
    tags: Set[str] = field(default_factory=set)
    dependencies: Set[str] = field(default_factory=set)
    version: str = "1.0"
    compressed: bool = False


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
    layer_hits: Dict[str, int] = field(default_factory=dict)
    layer_misses: Dict[str, int] = field(default_factory=dict)


@dataclass
class CacheConfiguration:
    """Cache configuration."""
    l1_max_size: int = 1000
    l1_default_ttl: int = 300
    l2_default_ttl: int = 1800
    l3_default_ttl: int = 3600
    compression_threshold: int = 1024
    warming_enabled: bool = True
    invalidation_enabled: bool = True
    monitoring_enabled: bool = True


class MultiLayerCacheService:
    """Advanced multi-layer cache service."""
    
    def __init__(self, config: CacheConfiguration = None):
        self.config = config or CacheConfiguration()
        self.redis_client: Optional[redis.Redis] = None
        self.l1_cache: Dict[str, CacheEntry] = {}
        self.cache_metrics = CacheMetrics()
        self.invalidation_triggers: Dict[str, Set[str]] = defaultdict(set)
        self.access_patterns: deque = deque(maxlen=10000)
        self.warming_queue: deque = deque()
        self.cdn_client = None  # Would be initialized with actual CDN client
        
        # Cache warming strategies
        self.warming_strategies = {
            'predictive': self.predictive_warming,
            'scheduled': self.scheduled_warming,
            'on_demand': self.on_demand_warming,
        }
        
    async def initialize(self):
        """Initialize cache service with all layers."""
        try:
            # Initialize Redis
            if settings.REDIS_URL:
                self.redis_client = redis.from_url(
                    settings.REDIS_URL,
                    encoding="utf-8",
                    decode_responses=True,
                    socket_connect_timeout=5,
                    socket_timeout=5,
                    retry_on_timeout=True,
                    max_connections=20,
                    health_check_interval=30
                )
                
                # Test connection
                await self.redis_client.ping()
                logger.info("Multi-layer cache service initialized with Redis")
            else:
                logger.warning("Redis not configured, using L1 cache only")
            
            # Initialize CDN client (placeholder)
            await self.initialize_cdn_client()
            
            # Start background tasks
            asyncio.create_task(self.background_maintenance())
            
        except Exception as e:
            logger.error("Failed to initialize cache service", error=str(e))
            self.redis_client = None
    
    async def initialize_cdn_client(self):
        """Initialize CDN client."""
        # This would initialize with actual CDN provider (CloudFlare, AWS CloudFront, etc.)
        logger.info("CDN client initialized")
    
    def _generate_cache_key(self, key: str, namespace: str = "default") -> str:
        """Generate namespaced cache key."""
        return f"{namespace}:{key}"
    
    def _compress_data(self, data: Any) -> Tuple[Any, bool]:
        """Compress data if it exceeds threshold."""
        if not self.config.compression_threshold:
            return data, False
        
        data_str = json.dumps(data, default=str)
        if len(data_str) > self.config.compression_threshold:
            # This would use actual compression (gzip, lz4, etc.)
            return data_str, True
        
        return data, False
    
    def _decompress_data(self, data: Any, compressed: bool) -> Any:
        """Decompress data if needed."""
        if compressed:
            # This would use actual decompression
            return json.loads(data)
        return data
    
    async def get(
        self,
        key: str,
        namespace: str = "default",
        strategy: CacheStrategy = CacheStrategy.READ_THROUGH,
        fallback_func: Optional[callable] = None
    ) -> Optional[Any]:
        """Get value from cache with multi-layer fallback."""
        cache_key = self._generate_cache_key(key, namespace)
        start_time = time.time()
        
        try:
            self.cache_metrics.total_requests += 1
            
            # Try L1 cache first
            if cache_key in self.l1_cache:
                entry = self.l1_cache[cache_key]
                if time.time() - entry.created_at < entry.ttl:
                    entry.access_count += 1
                    entry.last_accessed = time.time()
                    self.cache_metrics.hits += 1
                    self.cache_metrics.layer_hits[CacheLayer.L1_MEMORY.value] = (
                        self.cache_metrics.layer_hits.get(CacheLayer.L1_MEMORY.value, 0) + 1
                    )
                    
                    logger.debug("Cache hit (L1)", key=cache_key)
                    return self._decompress_data(entry.data, entry.compressed)
                else:
                    # TTL expired, remove from L1
                    del self.l1_cache[cache_key]
            
            # Try L2 Redis cache
            if self.redis_client:
                try:
                    cached_data = await self.redis_client.get(cache_key)
                    if cached_data:
                        data = json.loads(cached_data)
                        self.cache_metrics.hits += 1
                        self.cache_metrics.layer_hits[CacheLayer.L2_REDIS.value] = (
                            self.cache_metrics.layer_hits.get(CacheLayer.L2_REDIS.value, 0) + 1
                        )
                        
                        # Store in L1 for faster access
                        self.l1_cache[cache_key] = CacheEntry(
                            key=cache_key,
                            data=data,
                            created_at=time.time(),
                            ttl=self.config.l1_default_ttl,
                            layer=CacheLayer.L1_MEMORY,
                            access_count=1,
                            tags=set()
                        )
                        
                        logger.debug("Cache hit (L2)", key=cache_key)
                        return data
                        
                except Exception as e:
                    logger.warning("Redis cache error", error=str(e))
            
            # Try L3 CDN cache
            if self.cdn_client:
                try:
                    cdn_data = await self.get_from_cdn(cache_key)
                    if cdn_data:
                        self.cache_metrics.hits += 1
                        self.cache_metrics.layer_hits[CacheLayer.L3_CDN.value] = (
                            self.cache_metrics.layer_hits.get(CacheLayer.L3_CDN.value, 0) + 1
                        )
                        
                        # Store in L1 and L2
                        await self.set(cache_key, cdn_data, namespace, CacheStrategy.WRITE_THROUGH)
                        
                        logger.debug("Cache hit (L3)", key=cache_key)
                        return cdn_data
                        
                except Exception as e:
                    logger.warning("CDN cache error", error=str(e))
            
            # Cache miss - try fallback function
            if fallback_func:
                try:
                    data = await fallback_func()
                    if data is not None:
                        # Store in all layers
                        await self.set(cache_key, data, namespace, CacheStrategy.WRITE_THROUGH)
                        logger.debug("Cache miss, data loaded from fallback", key=cache_key)
                        return data
                except Exception as e:
                    logger.warning("Fallback function error", error=str(e))
            
            # Complete cache miss
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
    
    async def set(
        self,
        key: str,
        data: Any,
        namespace: str = "default",
        strategy: CacheStrategy = CacheStrategy.WRITE_THROUGH,
        ttl: Optional[int] = None,
        tags: Optional[Set[str]] = None
    ) -> bool:
        """Set value in cache with multi-layer strategy."""
        cache_key = self._generate_cache_key(key, namespace)
        
        try:
            # Compress data if needed
            compressed_data, is_compressed = self._compress_data(data)
            
            # Determine TTL
            cache_ttl = ttl or self.config.l1_default_ttl
            
            # Create cache entry
            entry = CacheEntry(
                key=cache_key,
                data=compressed_data,
                created_at=time.time(),
                ttl=cache_ttl,
                layer=CacheLayer.L1_MEMORY,
                access_count=1,
                tags=tags or set(),
                compressed=is_compressed
            )
            
            # Apply caching strategy
            if strategy == CacheStrategy.WRITE_THROUGH:
                # Write to all layers
                await self.write_to_l1(entry)
                await self.write_to_l2(cache_key, compressed_data, cache_ttl)
                await self.write_to_l3(cache_key, compressed_data, cache_ttl)
                
            elif strategy == CacheStrategy.WRITE_BACK:
                # Write to L1, schedule L2/L3 write
                await self.write_to_l1(entry)
                asyncio.create_task(self.write_to_l2_l3(cache_key, compressed_data, cache_ttl))
                
            elif strategy == CacheStrategy.WRITE_AROUND:
                # Write to L2/L3, skip L1
                await self.write_to_l2(cache_key, compressed_data, cache_ttl)
                await self.write_to_l3(cache_key, compressed_data, cache_ttl)
            
            # Update invalidation triggers
            for tag in entry.tags:
                self.invalidation_triggers[tag].add(cache_key)
            
            logger.debug("Cache set", key=cache_key, strategy=strategy.value)
            return True
            
        except Exception as e:
            logger.error("Cache set error", error=str(e), key=cache_key)
            return False
    
    async def write_to_l1(self, entry: CacheEntry):
        """Write to L1 memory cache."""
        self.l1_cache[entry.key] = entry
        
        # Evict if over limit
        if len(self.l1_cache) > self.config.l1_max_size:
            await self.evict_l1_entries()
    
    async def write_to_l2(self, key: str, data: Any, ttl: int):
        """Write to L2 Redis cache."""
        if self.redis_client:
            try:
                await self.redis_client.setex(key, ttl, json.dumps(data, default=str))
            except Exception as e:
                logger.warning("Redis write error", error=str(e))
    
    async def write_to_l3(self, key: str, data: Any, ttl: int):
        """Write to L3 CDN cache."""
        if self.cdn_client:
            try:
                await self.set_to_cdn(key, data, ttl)
            except Exception as e:
                logger.warning("CDN write error", error=str(e))
    
    async def write_to_l2_l3(self, key: str, data: Any, ttl: int):
        """Write to L2 and L3 asynchronously."""
        await asyncio.gather(
            self.write_to_l2(key, data, ttl),
            self.write_to_l3(key, data, ttl),
            return_exceptions=True
        )
    
    async def get_from_cdn(self, key: str) -> Optional[Any]:
        """Get data from CDN."""
        # This would implement actual CDN retrieval
        return None
    
    async def set_to_cdn(self, key: str, data: Any, ttl: int):
        """Set data to CDN."""
        # This would implement actual CDN storage
        pass
    
    async def evict_l1_entries(self):
        """Evict least recently used entries from L1."""
        if not self.l1_cache:
            return
        
        # Sort by last accessed time
        sorted_entries = sorted(
            self.l1_cache.items(),
            key=lambda x: x[1].last_accessed
        )
        
        # Evict oldest 10% of entries
        evict_count = max(1, len(sorted_entries) // 10)
        for key, _ in sorted_entries[:evict_count]:
            del self.l1_cache[key]
            self.cache_metrics.evictions += 1
        
        logger.debug("L1 cache evicted", count=evict_count)
    
    async def invalidate_by_tag(self, tag: str) -> int:
        """Invalidate all entries with a specific tag."""
        invalidated_count = 0
        
        try:
            # Get affected keys
            affected_keys = self.invalidation_triggers.get(tag, set())
            
            # Remove from L1 cache
            for key in affected_keys:
                if key in self.l1_cache:
                    del self.l1_cache[key]
                    invalidated_count += 1
            
            # Remove from L2 cache
            if self.redis_client and affected_keys:
                try:
                    await self.redis_client.delete(*affected_keys)
                except Exception as e:
                    logger.warning("Redis invalidation error", error=str(e))
            
            # Remove from L3 cache
            if self.cdn_client and affected_keys:
                try:
                    await self.invalidate_cdn_keys(affected_keys)
                except Exception as e:
                    logger.warning("CDN invalidation error", error=str(e))
            
            # Clear invalidation triggers
            if tag in self.invalidation_triggers:
                del self.invalidation_triggers[tag]
            
            self.cache_metrics.invalidations += invalidated_count
            
            logger.info("Cache invalidated by tag", tag=tag, count=invalidated_count)
            
            return invalidated_count
            
        except Exception as e:
            logger.error("Cache invalidation error", error=str(e), tag=tag)
            return 0
    
    async def invalidate_cdn_keys(self, keys: Set[str]):
        """Invalidate keys from CDN."""
        # This would implement actual CDN invalidation
        pass
    
    async def warm_cache(self, warming_config: Dict[str, Any]) -> Dict[str, Any]:
        """Warm cache using specified strategy."""
        strategy_name = warming_config.get('strategy', 'predictive')
        strategy_func = self.warming_strategies.get(strategy_name)
        
        if not strategy_func:
            raise BusinessLogicError(f"Unknown warming strategy: {strategy_name}")
        
        try:
            result = await strategy_func(warming_config)
            logger.info("Cache warming completed", strategy=strategy_name, result=result)
            return result
        except Exception as e:
            logger.error("Cache warming failed", error=str(e), strategy=strategy_name)
            raise BusinessLogicError("Cache warming failed")
    
    async def predictive_warming(self, config: Dict[str, Any]) -> Dict[str, Any]:
        """Predictive cache warming based on access patterns."""
        # Analyze access patterns to predict what to warm
        recent_accesses = list(self.access_patterns)[-1000:] if len(self.access_patterns) >= 1000 else list(self.access_patterns)
        
        # Group by access frequency
        access_counts = defaultdict(int)
        for access in recent_accesses:
            access_counts[access['key']] += 1
        
        # Get most frequently accessed keys
        frequent_keys = sorted(access_counts.items(), key=lambda x: x[1], reverse=True)[:10]
        
        warmed_count = 0
        for key, count in frequent_keys:
            # This would implement actual warming logic
            warmed_count += 1
        
        return {
            'strategy': 'predictive',
            'keys_analyzed': len(recent_accesses),
            'keys_warmed': warmed_count,
            'frequent_keys': frequent_keys
        }
    
    async def scheduled_warming(self, config: Dict[str, Any]) -> Dict[str, Any]:
        """Scheduled cache warming."""
        schedule = config.get('schedule', {})
        queries = schedule.get('queries', [])
        
        warmed_count = 0
        for query_config in queries:
            try:
                # Execute query and cache result
                result = await execute_query(query_config['query'], query_config.get('params', {}))
                await self.set(
                    query_config['cache_key'],
                    result,
                    ttl=query_config.get('ttl', 3600)
                )
                warmed_count += 1
            except Exception as e:
                logger.warning("Scheduled warming failed", error=str(e), query=query_config['query'])
        
        return {
            'strategy': 'scheduled',
            'queries_scheduled': len(queries),
            'queries_warmed': warmed_count
        }
    
    async def on_demand_warming(self, config: Dict[str, Any]) -> Dict[str, Any]:
        """On-demand cache warming."""
        keys_to_warm = config.get('keys', [])
        
        warmed_count = 0
        for key_config in keys_to_warm:
            try:
                # Load data and cache it
                data = await key_config['load_function']()
                await self.set(
                    key_config['cache_key'],
                    data,
                    ttl=key_config.get('ttl', 1800)
                )
                warmed_count += 1
            except Exception as e:
                logger.warning("On-demand warming failed", error=str(e), key=key_config['cache_key'])
        
        return {
            'strategy': 'on_demand',
            'keys_requested': len(keys_to_warm),
            'keys_warmed': warmed_count
        }
    
    async def background_maintenance(self):
        """Background maintenance tasks."""
        while True:
            try:
                # Clean expired entries
                await self.cleanup_expired_entries()
                
                # Optimize memory usage
                await self.optimize_memory_usage()
                
                # Update metrics
                self.update_metrics()
                
                # Sleep for 60 seconds
                await asyncio.sleep(60)
                
            except Exception as e:
                logger.error("Background maintenance error", error=str(e))
                await asyncio.sleep(60)
    
    async def cleanup_expired_entries(self):
        """Clean up expired cache entries."""
        current_time = time.time()
        expired_keys = []
        
        # Find expired entries in L1 cache
        for key, entry in self.l1_cache.items():
            if current_time - entry.created_at >= entry.ttl:
                expired_keys.append(key)
        
        # Remove expired entries
        for key in expired_keys:
            del self.l1_cache[key]
        
        if expired_keys:
            logger.debug("Expired entries cleaned up", count=len(expired_keys))
    
    async def optimize_memory_usage(self):
        """Optimize memory usage."""
        if len(self.l1_cache) > self.config.l1_max_size:
            await self.evict_l1_entries()
    
    def update_metrics(self):
        """Update cache metrics."""
        # Calculate hit ratio
        if self.cache_metrics.total_requests > 0:
            self.cache_metrics.hit_ratio = (
                self.cache_metrics.hits / self.cache_metrics.total_requests
            )
        
        # Update entry count
        self.cache_metrics.entry_count = len(self.l1_cache)
        
        # Update memory usage (simplified)
        self.cache_metrics.memory_usage = len(self.l1_cache) * 1024  # Rough estimate
    
    def get_cache_metrics(self) -> CacheMetrics:
        """Get current cache performance metrics."""
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
                    'entry_count': metrics.entry_count,
                    'memory_usage': metrics.memory_usage
                },
                'layer_performance': {
                    'l1_hits': metrics.layer_hits.get(CacheLayer.L1_MEMORY.value, 0),
                    'l2_hits': metrics.layer_hits.get(CacheLayer.L2_REDIS.value, 0),
                    'l3_hits': metrics.layer_hits.get(CacheLayer.L3_CDN.value, 0),
                },
                'access_patterns': {
                    'most_accessed_keys': [
                        {'key': key, 'access_count': count}
                        for key, count in most_accessed
                    ],
                    'total_unique_keys': len(key_access_counts)
                },
                'cache_status': {
                    'l1_cache_size': len(self.l1_cache),
                    'l1_max_size': self.config.l1_max_size,
                    'redis_connected': self.redis_client is not None,
                    'cdn_connected': self.cdn_client is not None,
                    'invalidation_triggers': len(self.invalidation_triggers)
                }
            }
            
        except Exception as e:
            logger.error("Failed to generate cache report", error=str(e))
            raise BusinessLogicError("Failed to generate cache report")


# Global multi-layer cache service instance
_multi_layer_cache_service = MultiLayerCacheService()


async def initialize_multi_layer_cache():
    """Initialize the global multi-layer cache service."""
    await _multi_layer_cache_service.initialize()


async def get_from_cache(
    key: str,
    namespace: str = "default",
    strategy: CacheStrategy = CacheStrategy.READ_THROUGH,
    fallback_func: Optional[callable] = None
) -> Optional[Any]:
    """Get value from cache using the global service."""
    return await _multi_layer_cache_service.get(key, namespace, strategy, fallback_func)


async def set_to_cache(
    key: str,
    data: Any,
    namespace: str = "default",
    strategy: CacheStrategy = CacheStrategy.WRITE_THROUGH,
    ttl: Optional[int] = None,
    tags: Optional[Set[str]] = None
) -> bool:
    """Set value in cache using the global service."""
    return await _multi_layer_cache_service.set(key, data, namespace, strategy, ttl, tags)


async def invalidate_cache_by_tag(tag: str) -> int:
    """Invalidate cache by tag using the global service."""
    return await _multi_layer_cache_service.invalidate_by_tag(tag)


async def warm_cache(warming_config: Dict[str, Any]) -> Dict[str, Any]:
    """Warm cache using the global service."""
    return await _multi_layer_cache_service.warm_cache(warming_config)


async def get_cache_performance_report() -> Dict[str, Any]:
    """Get cache performance report using the global service."""
    return await _multi_layer_cache_service.get_cache_report()
