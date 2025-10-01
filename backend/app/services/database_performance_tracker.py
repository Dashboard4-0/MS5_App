"""
MS5.0 Floor Dashboard - Database Performance Tracking Service

This module provides comprehensive database performance monitoring with:
- Query performance analysis
- Index usage monitoring
- Connection pool tracking
- Slow query detection
- Optimization recommendations
- Zero redundancy architecture
"""

import asyncio
import time
from collections import defaultdict, deque
from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Dict, List, Optional, Set, Tuple, Union
from uuid import UUID

import structlog
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import execute_query, execute_scalar, get_db_session
from app.services.application_performance_monitor import record_metric, increment_counter
from app.utils.exceptions import BusinessLogicError

logger = structlog.get_logger()


class QueryType(Enum):
    """Database query types."""
    SELECT = "SELECT"
    INSERT = "INSERT"
    UPDATE = "UPDATE"
    DELETE = "DELETE"
    CREATE = "CREATE"
    DROP = "DROP"
    ALTER = "ALTER"
    OTHER = "OTHER"


class IndexType(Enum):
    """Database index types."""
    BTREE = "btree"
    HASH = "hash"
    GIN = "gin"
    GIST = "gist"
    BRIN = "brin"
    UNIQUE = "unique"
    PRIMARY = "primary"


class QueryComplexity(Enum):
    """Query complexity levels."""
    SIMPLE = "simple"
    MODERATE = "moderate"
    COMPLEX = "complex"
    CRITICAL = "critical"


@dataclass
class QueryMetrics:
    """Database query performance metrics."""
    query_id: str
    query_text: str
    query_type: QueryType
    table_name: str
    execution_time: float
    rows_returned: int
    rows_examined: int
    complexity: QueryComplexity
    index_usage: List[str] = field(default_factory=list)
    missing_indexes: List[str] = field(default_factory=list)
    table_scans: List[str] = field(default_factory=list)
    timestamp: float = field(default_factory=time.time)
    connection_id: Optional[str] = None
    user_id: Optional[str] = None


@dataclass
class IndexMetrics:
    """Database index performance metrics."""
    index_name: str
    table_name: str
    index_type: IndexType
    size_bytes: int
    usage_count: int
    hit_ratio: float
    last_used: float
    is_redundant: bool = False
    optimization_score: float = 0.0


@dataclass
class ConnectionPoolMetrics:
    """Database connection pool metrics."""
    pool_name: str
    total_connections: int
    active_connections: int
    idle_connections: int
    waiting_connections: int
    max_connections: int
    connection_timeout: float
    avg_connection_time: float
    connection_errors: int
    last_reset: float


@dataclass
class DatabaseHealthMetrics:
    """Database health metrics."""
    database_name: str
    size_bytes: int
    active_connections: int
    long_running_queries: int
    deadlocks: int
    lock_waits: int
    cache_hit_ratio: float
    index_usage_ratio: float
    fragmentation_level: float
    last_vacuum: float
    last_analyze: float


class DatabasePerformanceTracker:
    """Comprehensive database performance tracking system."""
    
    def __init__(self):
        self.query_metrics: deque = deque(maxlen=10000)
        self.index_metrics: Dict[str, IndexMetrics] = {}
        self.connection_pool_metrics: Dict[str, ConnectionPoolMetrics] = {}
        self.database_health_metrics: Dict[str, DatabaseHealthMetrics] = {}
        self.slow_queries: deque = deque(maxlen=1000)
        self.query_patterns: Dict[str, int] = defaultdict(int)
        self.table_statistics: Dict[str, Dict[str, Any]] = defaultdict(lambda: {
            'query_count': 0,
            'avg_execution_time': 0.0,
            'total_rows_returned': 0,
            'index_usage_count': 0,
        })
        
        # Performance thresholds
        self.slow_query_threshold = 1.0  # seconds
        self.complex_query_threshold = 5.0  # seconds
        self.critical_query_threshold = 10.0  # seconds
        
        # Monitoring configuration
        self.monitoring_enabled = True
        self.collection_interval = 60  # seconds
        self.analysis_interval = 300  # seconds
        
        # Background tasks
        self.monitoring_tasks: List[asyncio.Task] = []
    
    async def initialize(self):
        """Initialize database performance tracking."""
        try:
            # Start monitoring tasks
            await self.start_monitoring_tasks()
            
            # Initialize baseline metrics
            await self.collect_baseline_metrics()
            
            logger.info("Database performance tracking initialized")
            
        except Exception as e:
            logger.error("Failed to initialize database performance tracking", error=str(e))
            raise BusinessLogicError("Database performance tracking initialization failed")
    
    async def start_monitoring_tasks(self):
        """Start background monitoring tasks."""
        # Query metrics collection
        query_task = asyncio.create_task(self.collect_query_metrics())
        self.monitoring_tasks.append(query_task)
        
        # Index metrics collection
        index_task = asyncio.create_task(self.collect_index_metrics())
        self.monitoring_tasks.append(index_task)
        
        # Connection pool monitoring
        pool_task = asyncio.create_task(self.monitor_connection_pools())
        self.monitoring_tasks.append(pool_task)
        
        # Database health monitoring
        health_task = asyncio.create_task(self.monitor_database_health())
        self.monitoring_tasks.append(health_task)
        
        # Performance analysis
        analysis_task = asyncio.create_task(self.analyze_performance())
        self.monitoring_tasks.append(analysis_task)
        
        logger.info("Database monitoring tasks started", task_count=len(self.monitoring_tasks))
    
    async def collect_baseline_metrics(self):
        """Collect baseline database metrics."""
        try:
            # Get database size
            size_query = """
            SELECT pg_size_pretty(pg_database_size(current_database())) as size,
                   pg_database_size(current_database()) as size_bytes
            """
            size_result = await execute_scalar(size_query)
            
            # Get connection count
            connection_query = """
            SELECT count(*) as active_connections 
            FROM pg_stat_activity 
            WHERE state = 'active'
            """
            connection_result = await execute_scalar(connection_query)
            
            # Get index count
            index_query = """
            SELECT count(*) as index_count
            FROM pg_indexes 
            WHERE schemaname = 'factory_telemetry'
            """
            index_result = await execute_scalar(index_query)
            
            logger.info(
                "Baseline metrics collected",
                database_size=size_result,
                active_connections=connection_result,
                index_count=index_result
            )
            
        except Exception as e:
            logger.error("Failed to collect baseline metrics", error=str(e))
    
    async def collect_query_metrics(self):
        """Collect query performance metrics."""
        while self.monitoring_enabled:
            try:
                # Get active queries
                active_queries_query = """
                SELECT 
                    pid,
                    usename,
                    application_name,
                    client_addr,
                    state,
                    query_start,
                    query,
                    state_change
                FROM pg_stat_activity 
                WHERE state = 'active' 
                AND query NOT LIKE '%pg_stat_activity%'
                AND query_start < NOW() - INTERVAL '1 second'
                """
                
                active_queries = await execute_query(active_queries_query)
                
                for query_info in active_queries:
                    execution_time = time.time() - query_info['query_start'].timestamp()
                    
                    # Analyze query
                    query_metrics = await self.analyze_query(
                        query_info['query'],
                        execution_time,
                        query_info['pid'],
                        query_info['usename']
                    )
                    
                    if query_metrics:
                        self.query_metrics.append(query_metrics)
                        
                        # Track slow queries
                        if execution_time > self.slow_query_threshold:
                            self.slow_queries.append(query_metrics)
                        
                        # Update table statistics
                        self.update_table_statistics(query_metrics)
                        
                        # Record metrics
                        record_metric('database_query_duration', execution_time, {
                            'query_type': query_metrics.query_type.value,
                            'table': query_metrics.table_name,
                            'complexity': query_metrics.complexity.value
                        })
                
                # Sleep for collection interval
                await asyncio.sleep(self.collection_interval)
                
            except Exception as e:
                logger.error("Query metrics collection error", error=str(e))
                await asyncio.sleep(self.collection_interval)
    
    async def analyze_query(self, query_text: str, execution_time: float, connection_id: str, user_id: str) -> Optional[QueryMetrics]:
        """Analyze query performance."""
        try:
            # Extract query information
            query_type = self.extract_query_type(query_text)
            table_name = self.extract_table_name(query_text)
            complexity = self.analyze_query_complexity(query_text)
            
            # Get execution plan
            explain_query = f"EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) {query_text}"
            try:
                explain_result = await execute_query(explain_query)
                execution_plan = explain_result[0][0] if explain_result else {}
            except Exception:
                execution_plan = {}
            
            # Extract metrics from execution plan
            rows_returned = execution_plan.get('Plan', {}).get('Actual Rows', 0)
            rows_examined = execution_plan.get('Plan', {}).get('Plan Rows', 0)
            index_usage = self.extract_index_usage(execution_plan)
            missing_indexes = self.identify_missing_indexes(query_text, execution_plan)
            table_scans = self.extract_table_scans(execution_plan)
            
            query_metrics = QueryMetrics(
                query_id=f"query_{int(time.time() * 1000)}",
                query_text=query_text[:200] + "..." if len(query_text) > 200 else query_text,
                query_type=query_type,
                table_name=table_name,
                execution_time=execution_time,
                rows_returned=rows_returned,
                rows_examined=rows_examined,
                complexity=complexity,
                index_usage=index_usage,
                missing_indexes=missing_indexes,
                table_scans=table_scans,
                connection_id=connection_id,
                user_id=user_id
            )
            
            return query_metrics
            
        except Exception as e:
            logger.error("Query analysis failed", error=str(e))
            return None
    
    def extract_query_type(self, query: str) -> QueryType:
        """Extract query type from SQL."""
        query_upper = query.strip().upper()
        for query_type in QueryType:
            if query_upper.startswith(query_type.value):
                return query_type
        return QueryType.OTHER
    
    def extract_table_name(self, query: str) -> str:
        """Extract table name from SQL."""
        import re
        
        # Look for FROM clause
        from_match = re.search(r'FROM\s+factory_telemetry\.(\w+)', query, re.IGNORECASE)
        if from_match:
            return from_match.group(1)
        
        # Look for INTO clause
        into_match = re.search(r'INTO\s+factory_telemetry\.(\w+)', query, re.IGNORECASE)
        if into_match:
            return into_match.group(1)
        
        # Look for UPDATE clause
        update_match = re.search(r'UPDATE\s+factory_telemetry\.(\w+)', query, re.IGNORECASE)
        if update_match:
            return update_match.group(1)
        
        return 'unknown'
    
    def analyze_query_complexity(self, query: str) -> QueryComplexity:
        """Analyze query complexity."""
        import re
        
        complexity_score = 0
        query_upper = query.upper()
        
        # Count complexity factors
        complexity_factors = {
            r'\bJOIN\b': 2,
            r'\bUNION\b': 3,
            r'\bGROUP BY\b': 2,
            r'\bORDER BY\b': 1,
            r'\bHAVING\b': 2,
            r'\bDISTINCT\b': 1,
            r'\bEXISTS\b': 3,
            r'\bIN\b.*\(.*SELECT': 3,
            r'\bCOUNT\b.*\*': 2,
            r'\bSUM\b|\bAVG\b|\bMIN\b|\bMAX\b': 2,
            r'\bCASE\b': 2,
            r'\bWHEN\b': 1,
        }
        
        for pattern, weight in complexity_factors.items():
            matches = len(re.findall(pattern, query_upper))
            complexity_score += matches * weight
        
        # Additional complexity factors
        if 'factory_telemetry.oee_calculations' in query:
            complexity_score += 2  # Large table
        if 'factory_telemetry.metric_hist' in query:
            complexity_score += 3  # Time-series table
        
        if complexity_score <= 2:
            return QueryComplexity.SIMPLE
        elif complexity_score <= 5:
            return QueryComplexity.MODERATE
        elif complexity_score <= 10:
            return QueryComplexity.COMPLEX
        else:
            return QueryComplexity.CRITICAL
    
    def extract_index_usage(self, execution_plan: Dict) -> List[str]:
        """Extract index usage from execution plan."""
        indexes = []
        
        def extract_indexes_recursive(plan_node: Dict):
            node_type = plan_node.get('Node Type', '')
            if 'Index' in node_type:
                index_name = plan_node.get('Index Name', '')
                if index_name:
                    indexes.append(index_name)
            
            # Recursively check child plans
            for child in plan_node.get('Plans', []):
                extract_indexes_recursive(child)
        
        if 'Plan' in execution_plan:
            extract_indexes_recursive(execution_plan['Plan'])
        
        return indexes
    
    def identify_missing_indexes(self, query: str, execution_plan: Dict) -> List[str]:
        """Identify missing indexes."""
        missing_indexes = []
        
        import re
        
        # Look for sequential scans
        def find_seq_scans(plan_node: Dict):
            if plan_node.get('Node Type') == 'Seq Scan':
                relation_name = plan_node.get('Relation Name', '')
                if relation_name:
                    missing_indexes.append(relation_name)
            
            for child in plan_node.get('Plans', []):
                find_seq_scans(child)
        
        if 'Plan' in execution_plan:
            find_seq_scans(execution_plan['Plan'])
        
        return missing_indexes
    
    def extract_table_scans(self, execution_plan: Dict) -> List[str]:
        """Extract table scan information."""
        scans = []
        
        def extract_scans_recursive(plan_node: Dict):
            node_type = plan_node.get('Node Type', '')
            if 'Scan' in node_type:
                relation_name = plan_node.get('Relation Name', '')
                if relation_name:
                    scans.append(relation_name)
            
            for child in plan_node.get('Plans', []):
                extract_scans_recursive(child)
        
        if 'Plan' in execution_plan:
            extract_scans_recursive(execution_plan['Plan'])
        
        return scans
    
    def update_table_statistics(self, query_metrics: QueryMetrics):
        """Update table statistics."""
        table_name = query_metrics.table_name
        stats = self.table_statistics[table_name]
        
        stats['query_count'] += 1
        stats['total_rows_returned'] += query_metrics.rows_returned
        stats['index_usage_count'] += len(query_metrics.index_usage)
        
        # Update average execution time
        total_time = stats['avg_execution_time'] * (stats['query_count'] - 1) + query_metrics.execution_time
        stats['avg_execution_time'] = total_time / stats['query_count']
    
    async def collect_index_metrics(self):
        """Collect index performance metrics."""
        while self.monitoring_enabled:
            try:
                # Get index usage statistics
                index_stats_query = """
                SELECT 
                    schemaname,
                    tablename,
                    indexname,
                    idx_tup_read,
                    idx_tup_fetch,
                    idx_scan,
                    pg_size_pretty(pg_relation_size(indexrelid)) as size,
                    pg_relation_size(indexrelid) as size_bytes
                FROM pg_stat_user_indexes 
                WHERE schemaname = 'factory_telemetry'
                ORDER BY idx_scan DESC
                """
                
                index_stats = await execute_query(index_stats_query)
                
                for stat in index_stats:
                    index_name = stat['indexname']
                    table_name = stat['tablename']
                    
                    # Calculate hit ratio
                    total_reads = stat['idx_tup_read']
                    total_fetches = stat['idx_tup_fetch']
                    hit_ratio = total_fetches / total_reads if total_reads > 0 else 0.0
                    
                    # Determine index type
                    index_type = self.determine_index_type(index_name)
                    
                    # Calculate optimization score
                    optimization_score = self.calculate_index_optimization_score(stat)
                    
                    index_metrics = IndexMetrics(
                        index_name=index_name,
                        table_name=table_name,
                        index_type=index_type,
                        size_bytes=stat['size_bytes'],
                        usage_count=stat['idx_scan'],
                        hit_ratio=hit_ratio,
                        last_used=time.time(),
                        optimization_score=optimization_score
                    )
                    
                    self.index_metrics[index_name] = index_metrics
                
                # Sleep for collection interval
                await asyncio.sleep(self.collection_interval)
                
            except Exception as e:
                logger.error("Index metrics collection error", error=str(e))
                await asyncio.sleep(self.collection_interval)
    
    def determine_index_type(self, index_name: str) -> IndexType:
        """Determine index type from name."""
        if 'unique' in index_name.lower():
            return IndexType.UNIQUE
        elif 'primary' in index_name.lower():
            return IndexType.PRIMARY
        elif 'gin' in index_name.lower():
            return IndexType.GIN
        elif 'gist' in index_name.lower():
            return IndexType.GIST
        elif 'brin' in index_name.lower():
            return IndexType.BRIN
        elif 'hash' in index_name.lower():
            return IndexType.HASH
        else:
            return IndexType.BTREE
    
    def calculate_index_optimization_score(self, stat: Dict) -> float:
        """Calculate index optimization score."""
        score = 0.0
        
        # Usage score (0-40 points)
        usage_score = min(40, stat['idx_scan'] / 100)
        score += usage_score
        
        # Hit ratio score (0-30 points)
        total_reads = stat['idx_tup_read']
        total_fetches = stat['idx_tup_fetch']
        hit_ratio = total_fetches / total_reads if total_reads > 0 else 0.0
        score += hit_ratio * 30
        
        # Size efficiency score (0-30 points)
        size_bytes = stat['size_bytes']
        if size_bytes < 1024 * 1024:  # Less than 1MB
            score += 30
        elif size_bytes < 10 * 1024 * 1024:  # Less than 10MB
            score += 20
        elif size_bytes < 100 * 1024 * 1024:  # Less than 100MB
            score += 10
        
        return min(100, score)
    
    async def monitor_connection_pools(self):
        """Monitor database connection pools."""
        while self.monitoring_enabled:
            try:
                # Get connection pool statistics
                pool_stats_query = """
                SELECT 
                    datname,
                    count(*) as total_connections,
                    count(*) FILTER (WHERE state = 'active') as active_connections,
                    count(*) FILTER (WHERE state = 'idle') as idle_connections,
                    count(*) FILTER (WHERE state = 'idle in transaction') as waiting_connections
                FROM pg_stat_activity 
                WHERE datname = current_database()
                GROUP BY datname
                """
                
                pool_stats = await execute_query(pool_stats_query)
                
                for stat in pool_stats:
                    pool_name = stat['datname']
                    
                    pool_metrics = ConnectionPoolMetrics(
                        pool_name=pool_name,
                        total_connections=stat['total_connections'],
                        active_connections=stat['active_connections'],
                        idle_connections=stat['idle_connections'],
                        waiting_connections=stat['waiting_connections'],
                        max_connections=100,  # Would be configured
                        connection_timeout=30.0,
                        avg_connection_time=0.0,  # Would be calculated
                        connection_errors=0,  # Would be tracked
                        last_reset=time.time()
                    )
                    
                    self.connection_pool_metrics[pool_name] = pool_metrics
                
                # Sleep for collection interval
                await asyncio.sleep(self.collection_interval)
                
            except Exception as e:
                logger.error("Connection pool monitoring error", error=str(e))
                await asyncio.sleep(self.collection_interval)
    
    async def monitor_database_health(self):
        """Monitor database health metrics."""
        while self.monitoring_enabled:
            try:
                # Get database health metrics
                health_query = """
                SELECT 
                    current_database() as database_name,
                    pg_size_pretty(pg_database_size(current_database())) as size,
                    pg_database_size(current_database()) as size_bytes,
                    count(*) FILTER (WHERE state = 'active') as active_connections,
                    count(*) FILTER (WHERE query_start < NOW() - INTERVAL '5 minutes') as long_running_queries
                FROM pg_stat_activity 
                WHERE datname = current_database()
                """
                
                health_result = await execute_query(health_query)
                
                if health_result:
                    health_data = health_result[0]
                    
                    # Get additional health metrics
                    cache_hit_ratio = await self.get_cache_hit_ratio()
                    index_usage_ratio = await self.get_index_usage_ratio()
                    
                    health_metrics = DatabaseHealthMetrics(
                        database_name=health_data['database_name'],
                        size_bytes=health_data['size_bytes'],
                        active_connections=health_data['active_connections'],
                        long_running_queries=health_data['long_running_queries'],
                        deadlocks=0,  # Would be tracked
                        lock_waits=0,  # Would be tracked
                        cache_hit_ratio=cache_hit_ratio,
                        index_usage_ratio=index_usage_ratio,
                        fragmentation_level=0.0,  # Would be calculated
                        last_vacuum=time.time(),
                        last_analyze=time.time()
                    )
                    
                    self.database_health_metrics[health_data['database_name']] = health_metrics
                
                # Sleep for collection interval
                await asyncio.sleep(self.collection_interval)
                
            except Exception as e:
                logger.error("Database health monitoring error", error=str(e))
                await asyncio.sleep(self.collection_interval)
    
    async def get_cache_hit_ratio(self) -> float:
        """Get database cache hit ratio."""
        try:
            cache_query = """
            SELECT 
                sum(blks_hit) as cache_hits,
                sum(blks_hit + blks_read) as total_blocks
            FROM pg_stat_database 
            WHERE datname = current_database()
            """
            
            cache_result = await execute_query(cache_query)
            if cache_result:
                cache_hits = cache_result[0]['cache_hits']
                total_blocks = cache_result[0]['total_blocks']
                return cache_hits / total_blocks if total_blocks > 0 else 0.0
            
            return 0.0
            
        except Exception as e:
            logger.error("Failed to get cache hit ratio", error=str(e))
            return 0.0
    
    async def get_index_usage_ratio(self) -> float:
        """Get index usage ratio."""
        try:
            index_query = """
            SELECT 
                count(*) as total_indexes,
                count(*) FILTER (WHERE idx_scan > 0) as used_indexes
            FROM pg_stat_user_indexes 
            WHERE schemaname = 'factory_telemetry'
            """
            
            index_result = await execute_query(index_query)
            if index_result:
                total_indexes = index_result[0]['total_indexes']
                used_indexes = index_result[0]['used_indexes']
                return used_indexes / total_indexes if total_indexes > 0 else 0.0
            
            return 0.0
            
        except Exception as e:
            logger.error("Failed to get index usage ratio", error=str(e))
            return 0.0
    
    async def analyze_performance(self):
        """Analyze performance and generate recommendations."""
        while self.monitoring_enabled:
            try:
                # Analyze slow queries
                await self.analyze_slow_queries()
                
                # Analyze index usage
                await self.analyze_index_usage()
                
                # Generate optimization recommendations
                await self.generate_optimization_recommendations()
                
                # Sleep for analysis interval
                await asyncio.sleep(self.analysis_interval)
                
            except Exception as e:
                logger.error("Performance analysis error", error=str(e))
                await asyncio.sleep(self.analysis_interval)
    
    async def analyze_slow_queries(self):
        """Analyze slow queries for optimization opportunities."""
        try:
            if not self.slow_queries:
                return
            
            # Group slow queries by table
            slow_queries_by_table = defaultdict(list)
            for query in self.slow_queries:
                slow_queries_by_table[query.table_name].append(query)
            
            # Analyze each table's slow queries
            for table_name, queries in slow_queries_by_table.items():
                if len(queries) >= 3:  # Table has multiple slow queries
                    logger.warning(
                        "Multiple slow queries detected for table",
                        table=table_name,
                        slow_query_count=len(queries),
                        avg_execution_time=sum(q.execution_time for q in queries) / len(queries)
                    )
                    
                    # Record metric
                    record_metric('slow_queries_per_table', len(queries), {'table': table_name})
            
        except Exception as e:
            logger.error("Slow query analysis failed", error=str(e))
    
    async def analyze_index_usage(self):
        """Analyze index usage for optimization opportunities."""
        try:
            unused_indexes = []
            low_usage_indexes = []
            
            for index_name, metrics in self.index_metrics.items():
                if metrics.usage_count == 0:
                    unused_indexes.append(index_name)
                elif metrics.usage_count < 10:  # Low usage threshold
                    low_usage_indexes.append(index_name)
            
            if unused_indexes:
                logger.warning("Unused indexes detected", unused_indexes=unused_indexes)
                record_metric('unused_indexes_count', len(unused_indexes))
            
            if low_usage_indexes:
                logger.info("Low usage indexes detected", low_usage_indexes=low_usage_indexes)
                record_metric('low_usage_indexes_count', len(low_usage_indexes))
            
        except Exception as e:
            logger.error("Index usage analysis failed", error=str(e))
    
    async def generate_optimization_recommendations(self):
        """Generate database optimization recommendations."""
        try:
            recommendations = []
            
            # Check for missing indexes
            missing_indexes = set()
            for query in self.slow_queries:
                missing_indexes.update(query.missing_indexes)
            
            if missing_indexes:
                recommendations.append({
                    'type': 'missing_indexes',
                    'priority': 'high',
                    'description': f'Missing indexes detected for tables: {", ".join(missing_indexes)}',
                    'impact': 'High - Will improve query performance significantly'
                })
            
            # Check for unused indexes
            unused_indexes = [name for name, metrics in self.index_metrics.items() if metrics.usage_count == 0]
            if unused_indexes:
                recommendations.append({
                    'type': 'unused_indexes',
                    'priority': 'medium',
                    'description': f'Unused indexes detected: {", ".join(unused_indexes)}',
                    'impact': 'Medium - Will reduce storage overhead and improve write performance'
                })
            
            # Check for connection pool issues
            for pool_name, metrics in self.connection_pool_metrics.items():
                if metrics.active_connections / metrics.max_connections > 0.8:
                    recommendations.append({
                        'type': 'connection_pool',
                        'priority': 'high',
                        'description': f'Connection pool {pool_name} utilization high: {metrics.active_connections}/{metrics.max_connections}',
                        'impact': 'High - May cause connection timeouts'
                    })
            
            if recommendations:
                logger.info("Database optimization recommendations generated", count=len(recommendations))
                record_metric('optimization_recommendations_count', len(recommendations))
            
        except Exception as e:
            logger.error("Optimization recommendations generation failed", error=str(e))
    
    def get_performance_report(self) -> Dict[str, Any]:
        """Get comprehensive database performance report."""
        try:
            # Query performance summary
            total_queries = len(self.query_metrics)
            slow_queries_count = len(self.slow_queries)
            avg_execution_time = (
                sum(q.execution_time for q in self.query_metrics) / total_queries
                if total_queries > 0 else 0
            )
            
            # Index performance summary
            total_indexes = len(self.index_metrics)
            unused_indexes = sum(1 for m in self.index_metrics.values() if m.usage_count == 0)
            avg_index_score = (
                sum(m.optimization_score for m in self.index_metrics.values()) / total_indexes
                if total_indexes > 0 else 0
            )
            
            # Connection pool summary
            total_connections = sum(m.total_connections for m in self.connection_pool_metrics.values())
            active_connections = sum(m.active_connections for m in self.connection_pool_metrics.values())
            
            # Database health summary
            health_summary = {}
            for db_name, health in self.database_health_metrics.items():
                health_summary[db_name] = {
                    'size_bytes': health.size_bytes,
                    'active_connections': health.active_connections,
                    'long_running_queries': health.long_running_queries,
                    'cache_hit_ratio': health.cache_hit_ratio,
                    'index_usage_ratio': health.index_usage_ratio,
                }
            
            # Top slow queries
            top_slow_queries = sorted(
                self.slow_queries,
                key=lambda q: q.execution_time,
                reverse=True
            )[:10]
            
            # Top tables by query count
            top_tables = sorted(
                self.table_statistics.items(),
                key=lambda x: x[1]['query_count'],
                reverse=True
            )[:10]
            
            return {
                'query_performance': {
                    'total_queries': total_queries,
                    'slow_queries_count': slow_queries_count,
                    'avg_execution_time': avg_execution_time,
                    'slow_query_threshold': self.slow_query_threshold,
                    'top_slow_queries': [
                        {
                            'query_id': q.query_id,
                            'table_name': q.table_name,
                            'execution_time': q.execution_time,
                            'complexity': q.complexity.value,
                            'missing_indexes': q.missing_indexes
                        }
                        for q in top_slow_queries
                    ]
                },
                'index_performance': {
                    'total_indexes': total_indexes,
                    'unused_indexes': unused_indexes,
                    'avg_optimization_score': avg_index_score,
                    'index_metrics': {
                        name: {
                            'table_name': metrics.table_name,
                            'index_type': metrics.index_type.value,
                            'usage_count': metrics.usage_count,
                            'hit_ratio': metrics.hit_ratio,
                            'optimization_score': metrics.optimization_score,
                            'size_bytes': metrics.size_bytes
                        }
                        for name, metrics in self.index_metrics.items()
                    }
                },
                'connection_pools': {
                    'total_connections': total_connections,
                    'active_connections': active_connections,
                    'utilization_ratio': active_connections / total_connections if total_connections > 0 else 0,
                    'pool_metrics': {
                        name: {
                            'total_connections': metrics.total_connections,
                            'active_connections': metrics.active_connections,
                            'idle_connections': metrics.idle_connections,
                            'waiting_connections': metrics.waiting_connections,
                            'max_connections': metrics.max_connections
                        }
                        for name, metrics in self.connection_pool_metrics.items()
                    }
                },
                'database_health': health_summary,
                'table_statistics': {
                    name: {
                        'query_count': stats['query_count'],
                        'avg_execution_time': stats['avg_execution_time'],
                        'total_rows_returned': stats['total_rows_returned'],
                        'index_usage_count': stats['index_usage_count']
                    }
                    for name, stats in top_tables
                },
                'monitoring_status': {
                    'monitoring_enabled': self.monitoring_enabled,
                    'monitoring_tasks': len(self.monitoring_tasks),
                    'collection_interval': self.collection_interval,
                    'analysis_interval': self.analysis_interval
                }
            }
            
        except Exception as e:
            logger.error("Failed to generate performance report", error=str(e))
            raise BusinessLogicError("Failed to generate performance report")
    
    async def stop_monitoring(self):
        """Stop database performance monitoring."""
        try:
            self.monitoring_enabled = False
            
            # Cancel monitoring tasks
            for task in self.monitoring_tasks:
                task.cancel()
            
            # Wait for tasks to complete
            await asyncio.gather(*self.monitoring_tasks, return_exceptions=True)
            
            self.monitoring_tasks.clear()
            
            logger.info("Database performance monitoring stopped")
            
        except Exception as e:
            logger.error("Failed to stop monitoring", error=str(e))


# Global database performance tracker instance
_database_performance_tracker = DatabasePerformanceTracker()


async def initialize_database_performance_tracking():
    """Initialize the global database performance tracker."""
    await _database_performance_tracker.initialize()


def get_database_performance_report() -> Dict[str, Any]:
    """Get database performance report using the global tracker."""
    return _database_performance_tracker.get_performance_report()


async def stop_database_performance_tracking():
    """Stop the global database performance tracker."""
    await _database_performance_tracker.stop_monitoring()
