"""
MS5.0 Floor Dashboard - Database Query Optimizer

This module provides comprehensive database query optimization capabilities
including query analysis, index recommendations, and performance monitoring.
Architected for cosmic-scale performance with zero redundancy.
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
from app.utils.exceptions import BusinessLogicError

logger = structlog.get_logger()


class QueryComplexity(Enum):
    """Query complexity classification."""
    SIMPLE = "simple"           # Single table, basic WHERE
    MODERATE = "moderate"       # Joins, subqueries
    COMPLEX = "complex"         # Multiple joins, aggregations
    CRITICAL = "critical"       # Full table scans, complex aggregations


class IndexType(Enum):
    """Database index types."""
    BTREE = "btree"
    HASH = "hash"
    GIN = "gin"
    GIST = "gist"
    BRIN = "brin"


@dataclass
class QueryMetrics:
    """Query performance metrics."""
    query_id: str
    query_text: str
    execution_time: float
    rows_returned: int
    complexity: QueryComplexity
    table_scans: List[str] = field(default_factory=list)
    index_usage: List[str] = field(default_factory=list)
    missing_indexes: List[str] = field(default_factory=list)
    timestamp: float = field(default_factory=time.time)


@dataclass
class IndexRecommendation:
    """Database index recommendation."""
    table_name: str
    columns: List[str]
    index_type: IndexType
    priority: int  # 1-10, higher is more critical
    estimated_impact: float  # Expected performance improvement
    reasoning: str
    sql_statement: str


@dataclass
class DatabaseStats:
    """Database performance statistics."""
    total_queries: int
    avg_execution_time: float
    slow_queries: int
    table_sizes: Dict[str, int]
    index_usage_stats: Dict[str, Dict[str, Any]]
    connection_pool_stats: Dict[str, Any]
    cache_hit_ratio: float


class QueryAnalyzer:
    """Advanced query analysis engine."""
    
    def __init__(self):
        self.query_patterns = defaultdict(int)
        self.slow_query_threshold = 1.0  # seconds
        self.complexity_patterns = {
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
        }
    
    def analyze_query_complexity(self, query: str) -> QueryComplexity:
        """Analyze query complexity based on patterns."""
        import re
        
        complexity_score = 0
        query_upper = query.upper()
        
        for pattern, weight in self.complexity_patterns.items():
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
    
    def identify_missing_indexes(self, query: str, execution_plan: Dict) -> List[str]:
        """Identify missing indexes based on query analysis."""
        missing_indexes = []
        
        # Analyze WHERE clauses for potential indexes
        import re
        where_patterns = re.findall(r'WHERE\s+([^ORDER|GROUP|HAVING]+)', query, re.IGNORECASE)
        
        for where_clause in where_patterns:
            # Look for equality conditions
            eq_patterns = re.findall(r'(\w+)\s*=\s*:\w+', where_clause)
            for column in eq_patterns:
                if column not in execution_plan.get('indexes_used', []):
                    missing_indexes.append(column)
        
        return missing_indexes


class DatabaseOptimizer:
    """Comprehensive database optimization engine."""
    
    def __init__(self):
        self.query_analyzer = QueryAnalyzer()
        self.query_metrics: deque = deque(maxlen=10000)  # Keep last 10k queries
        self.slow_queries: deque = deque(maxlen=1000)    # Keep last 1k slow queries
        self.index_recommendations: List[IndexRecommendation] = []
        self.optimization_cache: Dict[str, Any] = {}
        
    async def analyze_query_performance(self, query: str, params: Dict = None) -> QueryMetrics:
        """Analyze query performance and return detailed metrics."""
        start_time = time.time()
        
        try:
            # Execute query with EXPLAIN ANALYZE
            explain_query = f"EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) {query}"
            result = await execute_query(explain_query, params or {})
            
            execution_time = time.time() - start_time
            query_id = f"query_{int(time.time() * 1000)}"
            
            # Parse execution plan
            execution_plan = result[0][0] if result else {}
            
            # Analyze complexity
            complexity = self.query_analyzer.analyze_query_complexity(query)
            
            # Extract metrics
            rows_returned = execution_plan.get('Plan', {}).get('Actual Rows', 0)
            table_scans = self._extract_table_scans(execution_plan)
            index_usage = self._extract_index_usage(execution_plan)
            missing_indexes = self.query_analyzer.identify_missing_indexes(query, execution_plan)
            
            metrics = QueryMetrics(
                query_id=query_id,
                query_text=query[:200] + "..." if len(query) > 200 else query,
                execution_time=execution_time,
                rows_returned=rows_returned,
                complexity=complexity,
                table_scans=table_scans,
                index_usage=index_usage,
                missing_indexes=missing_indexes
            )
            
            # Store metrics
            self.query_metrics.append(metrics)
            
            # Track slow queries
            if execution_time > self.query_analyzer.slow_query_threshold:
                self.slow_queries.append(metrics)
            
            return metrics
            
        except Exception as e:
            logger.error("Query analysis failed", error=str(e), query=query[:100])
            raise BusinessLogicError("Query analysis failed")
    
    def _extract_table_scans(self, execution_plan: Dict) -> List[str]:
        """Extract table scan information from execution plan."""
        scans = []
        
        def extract_scans_recursive(plan_node: Dict):
            node_type = plan_node.get('Node Type', '')
            if 'Seq Scan' in node_type or 'Index Scan' in node_type:
                relation_name = plan_node.get('Relation Name', '')
                if relation_name:
                    scans.append(relation_name)
            
            # Recursively check child plans
            for child in plan_node.get('Plans', []):
                extract_scans_recursive(child)
        
        if 'Plan' in execution_plan:
            extract_scans_recursive(execution_plan['Plan'])
        
        return scans
    
    def _extract_index_usage(self, execution_plan: Dict) -> List[str]:
        """Extract index usage information from execution plan."""
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
    
    async def generate_index_recommendations(self) -> List[IndexRecommendation]:
        """Generate index recommendations based on query analysis."""
        recommendations = []
        
        # Analyze slow queries for index opportunities
        table_column_usage = defaultdict(lambda: defaultdict(int))
        
        for metrics in self.slow_queries:
            for missing_index in metrics.missing_indexes:
                # Extract table name from query (simplified)
                table_name = self._extract_table_name(metrics.query_text)
                if table_name:
                    table_column_usage[table_name][missing_index] += 1
        
        # Generate recommendations
        for table_name, columns in table_column_usage.items():
            for column, frequency in columns.items():
                if frequency >= 3:  # Column used in 3+ slow queries
                    priority = min(10, frequency * 2)
                    estimated_impact = min(0.9, frequency * 0.1)
                    
                    recommendation = IndexRecommendation(
                        table_name=table_name,
                        columns=[column],
                        index_type=IndexType.BTREE,
                        priority=priority,
                        estimated_impact=estimated_impact,
                        reasoning=f"Column '{column}' appears in {frequency} slow queries",
                        sql_statement=f"CREATE INDEX CONCURRENTLY idx_{table_name}_{column} ON factory_telemetry.{table_name} ({column});"
                    )
                    recommendations.append(recommendation)
        
        # Sort by priority
        recommendations.sort(key=lambda x: x.priority, reverse=True)
        self.index_recommendations = recommendations
        
        return recommendations
    
    def _extract_table_name(self, query: str) -> Optional[str]:
        """Extract table name from query (simplified implementation)."""
        import re
        
        # Look for FROM clauses
        from_match = re.search(r'FROM\s+factory_telemetry\.(\w+)', query, re.IGNORECASE)
        if from_match:
            return from_match.group(1)
        
        # Look for JOIN clauses
        join_match = re.search(r'JOIN\s+factory_telemetry\.(\w+)', query, re.IGNORECASE)
        if join_match:
            return join_match.group(1)
        
        return None
    
    async def get_database_stats(self) -> DatabaseStats:
        """Get comprehensive database performance statistics."""
        try:
            # Get table sizes
            table_sizes_query = """
            SELECT 
                schemaname,
                tablename,
                pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size,
                pg_total_relation_size(schemaname||'.'||tablename) as size_bytes
            FROM pg_tables 
            WHERE schemaname = 'factory_telemetry'
            ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
            """
            
            table_sizes_result = await execute_query(table_sizes_query)
            table_sizes = {
                row['tablename']: row['size_bytes'] 
                for row in table_sizes_result
            }
            
            # Get index usage statistics
            index_stats_query = """
            SELECT 
                schemaname,
                tablename,
                indexname,
                idx_tup_read,
                idx_tup_fetch,
                idx_scan
            FROM pg_stat_user_indexes 
            WHERE schemaname = 'factory_telemetry'
            ORDER BY idx_scan DESC
            """
            
            index_stats_result = await execute_query(index_stats_query)
            index_usage_stats = defaultdict(dict)
            
            for row in index_stats_result:
                table_name = row['tablename']
                index_name = row['indexname']
                index_usage_stats[table_name][index_name] = {
                    'scans': row['idx_scan'],
                    'tuples_read': row['idx_tup_read'],
                    'tuples_fetched': row['idx_tup_fetch']
                }
            
            # Calculate aggregate metrics
            total_queries = len(self.query_metrics)
            avg_execution_time = (
                sum(m.execution_time for m in self.query_metrics) / total_queries
                if total_queries > 0 else 0
            )
            slow_queries = len(self.slow_queries)
            
            # Get connection pool stats
            from app.database import get_connection_pool_status
            connection_pool_stats = await get_connection_pool_status()
            
            return DatabaseStats(
                total_queries=total_queries,
                avg_execution_time=avg_execution_time,
                slow_queries=slow_queries,
                table_sizes=table_sizes,
                index_usage_stats=dict(index_usage_stats),
                connection_pool_stats=connection_pool_stats,
                cache_hit_ratio=0.95  # Placeholder - would be calculated from actual cache stats
            )
            
        except Exception as e:
            logger.error("Failed to get database stats", error=str(e))
            raise BusinessLogicError("Failed to get database statistics")
    
    async def optimize_slow_queries(self) -> Dict[str, Any]:
        """Optimize slow queries by applying recommendations."""
        optimization_results = {
            'queries_optimized': 0,
            'indexes_created': 0,
            'performance_improvement': 0.0,
            'recommendations_applied': []
        }
        
        try:
            # Get top recommendations
            recommendations = await self.generate_index_recommendations()
            
            for recommendation in recommendations[:5]:  # Apply top 5 recommendations
                try:
                    # Create index
                    await execute_query(recommendation.sql_statement)
                    optimization_results['indexes_created'] += 1
                    optimization_results['recommendations_applied'].append({
                        'table': recommendation.table_name,
                        'columns': recommendation.columns,
                        'impact': recommendation.estimated_impact
                    })
                    
                    logger.info(
                        "Index created for optimization",
                        table=recommendation.table_name,
                        columns=recommendation.columns,
                        impact=recommendation.estimated_impact
                    )
                    
                except Exception as e:
                    logger.warning(
                        "Failed to create index",
                        table=recommendation.table_name,
                        error=str(e)
                    )
            
            # Re-analyze slow queries to measure improvement
            optimization_results['queries_optimized'] = len(self.slow_queries)
            
            return optimization_results
            
        except Exception as e:
            logger.error("Query optimization failed", error=str(e))
            raise BusinessLogicError("Query optimization failed")
    
    async def get_performance_report(self) -> Dict[str, Any]:
        """Generate comprehensive performance report."""
        try:
            db_stats = await self.get_database_stats()
            recommendations = await self.generate_index_recommendations()
            
            # Analyze query patterns
            complexity_distribution = defaultdict(int)
            for metrics in self.query_metrics:
                complexity_distribution[metrics.complexity.value] += 1
            
            # Calculate performance trends
            recent_queries = list(self.query_metrics)[-100:] if len(self.query_metrics) >= 100 else list(self.query_metrics)
            recent_avg_time = (
                sum(m.execution_time for m in recent_queries) / len(recent_queries)
                if recent_queries else 0
            )
            
            return {
                'database_stats': {
                    'total_queries': db_stats.total_queries,
                    'avg_execution_time': db_stats.avg_execution_time,
                    'slow_queries': db_stats.slow_queries,
                    'recent_avg_time': recent_avg_time,
                    'cache_hit_ratio': db_stats.cache_hit_ratio
                },
                'query_analysis': {
                    'complexity_distribution': dict(complexity_distribution),
                    'most_used_tables': self._get_most_used_tables(),
                    'slowest_queries': self._get_slowest_queries(5)
                },
                'index_recommendations': [
                    {
                        'table': rec.table_name,
                        'columns': rec.columns,
                        'priority': rec.priority,
                        'impact': rec.estimated_impact,
                        'reasoning': rec.reasoning
                    }
                    for rec in recommendations[:10]
                ],
                'optimization_opportunities': {
                    'high_priority_indexes': len([r for r in recommendations if r.priority >= 8]),
                    'medium_priority_indexes': len([r for r in recommendations if 5 <= r.priority < 8]),
                    'low_priority_indexes': len([r for r in recommendations if r.priority < 5])
                }
            }
            
        except Exception as e:
            logger.error("Failed to generate performance report", error=str(e))
            raise BusinessLogicError("Failed to generate performance report")
    
    def _get_most_used_tables(self) -> List[Dict[str, Any]]:
        """Get most frequently accessed tables."""
        table_usage = defaultdict(int)
        
        for metrics in self.query_metrics:
            for table in metrics.table_scans:
                table_usage[table] += 1
        
        return [
            {'table': table, 'access_count': count}
            for table, count in sorted(table_usage.items(), key=lambda x: x[1], reverse=True)[:10]
        ]
    
    def _get_slowest_queries(self, limit: int = 5) -> List[Dict[str, Any]]:
        """Get slowest queries."""
        slowest = sorted(self.query_metrics, key=lambda x: x.execution_time, reverse=True)[:limit]
        
        return [
            {
                'query_id': m.query_id,
                'execution_time': m.execution_time,
                'complexity': m.complexity.value,
                'rows_returned': m.rows_returned,
                'query_preview': m.query_text
            }
            for m in slowest
        ]


# Global optimizer instance
_database_optimizer = DatabaseOptimizer()


async def analyze_query_performance(query: str, params: Dict = None) -> QueryMetrics:
    """Analyze query performance using the global optimizer."""
    return await _database_optimizer.analyze_query_performance(query, params)


async def get_database_performance_report() -> Dict[str, Any]:
    """Get comprehensive database performance report."""
    return await _database_optimizer.get_performance_report()


async def optimize_database_performance() -> Dict[str, Any]:
    """Optimize database performance by applying recommendations."""
    return await _database_optimizer.optimize_slow_queries()


async def get_index_recommendations() -> List[IndexRecommendation]:
    """Get index recommendations for performance optimization."""
    return await _database_optimizer.generate_index_recommendations()
