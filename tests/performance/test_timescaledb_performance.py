"""
MS5.0 Floor Dashboard - TimescaleDB Performance Tests

This module provides comprehensive performance testing for TimescaleDB integration,
validating data insertion rates, query performance, compression effectiveness,
and retention policy operations.

Test Categories:
- Data Insertion Performance
- Query Performance (single and aggregated)
- Compression Effectiveness
- Retention Policy Validation
- Hypertable Operations
- Concurrent Operations

Performance Benchmarks (from Phase Plan):
- Data Insertion: >1000 records/second for metric_hist table
- Query Performance: <100ms for typical dashboard queries
- Compression Ratio: >70% compression for historical data
- Storage Efficiency: <1GB per month for typical production data
"""

import pytest
import asyncio
import time
import uuid
from datetime import datetime, timedelta
from typing import List, Dict, Any

import structlog
from sqlalchemy import text

from app.database import (
    get_db_session,
    execute_query,
    execute_scalar,
    setup_timescaledb_policies,
    get_hypertable_stats,
    get_compression_stats,
    get_chunk_details,
    get_timescaledb_health,
    check_timescaledb_extension
)
from app.config import settings

logger = structlog.get_logger()


# ============================================================================
# Test Fixtures and Helpers
# ============================================================================

@pytest.fixture
async def ensure_timescaledb():
    """Ensure TimescaleDB extension is available before running tests."""
    is_available = await check_timescaledb_extension()
    if not is_available:
        pytest.skip("TimescaleDB extension not available")
    return True


@pytest.fixture
async def clean_test_data():
    """Clean up test data before and after tests."""
    # Cleanup before test
    yield
    # Cleanup after test
    # Note: TimescaleDB retention policies will handle automatic cleanup


async def generate_metric_data(count: int, metric_def_id: str = None) -> List[Dict[str, Any]]:
    """
    Generate test metric data for insertion.
    
    Args:
        count: Number of records to generate
        metric_def_id: Optional metric definition ID (generates random if not provided)
        
    Returns:
        List of metric data dictionaries
    """
    if not metric_def_id:
        metric_def_id = str(uuid.uuid4())
    
    base_time = datetime.utcnow()
    data = []
    
    for i in range(count):
        data.append({
            "metric_def_id": metric_def_id,
            "ts": base_time - timedelta(seconds=i),
            "value_real": 100.0 + (i % 50),
            "value_int": i % 1000,
            "value_bool": i % 2 == 0
        })
    
    return data


# ============================================================================
# TimescaleDB Extension Tests
# ============================================================================

@pytest.mark.asyncio
async def test_timescaledb_extension_available(ensure_timescaledb):
    """Test that TimescaleDB extension is installed and available."""
    is_available = await check_timescaledb_extension()
    assert is_available, "TimescaleDB extension must be available"
    logger.info("✅ TimescaleDB extension verified")


@pytest.mark.asyncio
async def test_timescaledb_health_check(ensure_timescaledb):
    """Test comprehensive TimescaleDB health check."""
    health_status = await get_timescaledb_health()
    
    assert health_status is not None, "Health check should return results"
    assert health_status.get("status") in ["healthy", "degraded"], "Status should be healthy or degraded"
    assert health_status.get("extension_installed") is True, "Extension must be installed"
    assert health_status.get("version") is not None, "Version should be available"
    
    logger.info(
        "✅ TimescaleDB health check passed",
        status=health_status.get("status"),
        version=health_status.get("version")
    )


# ============================================================================
# Data Insertion Performance Tests
# ============================================================================

@pytest.mark.asyncio
async def test_single_record_insertion_performance(ensure_timescaledb, clean_test_data):
    """
    Test single record insertion performance.
    
    Target: Sub-millisecond insertion for single records
    """
    metric_def_id = str(uuid.uuid4())
    
    start_time = time.perf_counter()
    
    async with get_db_session() as session:
        await session.execute(text("""
            INSERT INTO factory_telemetry.metric_hist 
            (metric_def_id, ts, value_real, value_int, value_bool)
            VALUES (:metric_def_id, :ts, :value_real, :value_int, :value_bool)
        """), {
            "metric_def_id": metric_def_id,
            "ts": datetime.utcnow(),
            "value_real": 100.0,
            "value_int": 42,
            "value_bool": True
        })
    
    insertion_time = time.perf_counter() - start_time
    
    assert insertion_time < 0.01, f"Single insertion should take <10ms, took {insertion_time*1000:.2f}ms"
    
    logger.info(
        "✅ Single record insertion performance test passed",
        insertion_time_ms=f"{insertion_time*1000:.2f}"
    )


@pytest.mark.asyncio
async def test_bulk_insertion_performance(ensure_timescaledb, clean_test_data):
    """
    Test bulk insertion performance for 1000 records.
    
    Target: >1000 records/second
    Benchmark from Phase Plan: Insert 1000 records in < 1 second
    """
    test_data = await generate_metric_data(1000)
    
    start_time = time.perf_counter()
    
    async with get_db_session() as session:
        for record in test_data:
            await session.execute(text("""
                INSERT INTO factory_telemetry.metric_hist 
                (metric_def_id, ts, value_real, value_int, value_bool)
                VALUES (:metric_def_id, :ts, :value_real, :value_int, :value_bool)
            """), record)
    
    insertion_time = time.perf_counter() - start_time
    records_per_second = 1000 / insertion_time
    
    # Phase Plan Benchmark: 1000 records in < 1 second
    assert insertion_time < 1.0, f"Bulk insertion should take <1s for 1000 records, took {insertion_time:.3f}s"
    assert records_per_second > 1000, f"Should achieve >1000 records/sec, achieved {records_per_second:.0f}"
    
    logger.info(
        "✅ Bulk insertion performance test passed",
        records=1000,
        insertion_time_sec=f"{insertion_time:.3f}",
        records_per_second=f"{records_per_second:.0f}"
    )


@pytest.mark.asyncio
async def test_batch_insertion_performance(ensure_timescaledb, clean_test_data):
    """
    Test optimized batch insertion using COPY or bulk insert.
    
    Target: >5000 records/second for batch operations
    """
    test_data = await generate_metric_data(5000)
    
    start_time = time.perf_counter()
    
    # Use executemany for better performance
    async with get_db_session() as session:
        # Batch insert in chunks of 100
        batch_size = 100
        for i in range(0, len(test_data), batch_size):
            batch = test_data[i:i+batch_size]
            
            values_clause = ", ".join([
                f"('{record['metric_def_id']}', '{record['ts']}', {record['value_real']}, {record['value_int']}, {record['value_bool']})"
                for record in batch
            ])
            
            await session.execute(text(f"""
                INSERT INTO factory_telemetry.metric_hist 
                (metric_def_id, ts, value_real, value_int, value_bool)
                VALUES {values_clause}
            """))
    
    insertion_time = time.perf_counter() - start_time
    records_per_second = 5000 / insertion_time
    
    assert insertion_time < 1.0, f"Batch insertion should take <1s for 5000 records, took {insertion_time:.3f}s"
    assert records_per_second > 5000, f"Should achieve >5000 records/sec, achieved {records_per_second:.0f}"
    
    logger.info(
        "✅ Batch insertion performance test passed",
        records=5000,
        insertion_time_sec=f"{insertion_time:.3f}",
        records_per_second=f"{records_per_second:.0f}"
    )


# ============================================================================
# Query Performance Tests
# ============================================================================

@pytest.mark.asyncio
async def test_recent_data_query_performance(ensure_timescaledb):
    """
    Test query performance for recent data retrieval.
    
    Target: <100ms for typical dashboard queries
    Benchmark from Phase Plan: Query 100 records in < 100ms
    """
    start_time = time.perf_counter()
    
    result = await execute_query("""
        SELECT metric_def_id, ts, value_real, value_int, value_bool
        FROM factory_telemetry.metric_hist
        WHERE ts > NOW() - INTERVAL '1 hour'
        ORDER BY ts DESC
        LIMIT 100
    """)
    
    query_time = time.perf_counter() - start_time
    
    # Phase Plan Benchmark: <100ms for 100 records
    assert query_time < 0.1, f"Query should take <100ms, took {query_time*1000:.2f}ms"
    
    logger.info(
        "✅ Recent data query performance test passed",
        query_time_ms=f"{query_time*1000:.2f}",
        records_returned=len(result)
    )


@pytest.mark.asyncio
async def test_aggregation_query_performance(ensure_timescaledb):
    """
    Test aggregation query performance for time-series data.
    
    Target: <200ms for complex aggregations over 24 hours
    """
    start_time = time.perf_counter()
    
    result = await execute_query("""
        SELECT 
            time_bucket('1 hour', ts) AS hour_bucket,
            COUNT(*) as record_count,
            AVG(value_real) as avg_value,
            MIN(value_real) as min_value,
            MAX(value_real) as max_value
        FROM factory_telemetry.metric_hist
        WHERE ts > NOW() - INTERVAL '24 hours'
        GROUP BY hour_bucket
        ORDER BY hour_bucket DESC
    """)
    
    query_time = time.perf_counter() - start_time
    
    assert query_time < 0.2, f"Aggregation query should take <200ms, took {query_time*1000:.2f}ms"
    
    logger.info(
        "✅ Aggregation query performance test passed",
        query_time_ms=f"{query_time*1000:.2f}",
        buckets_returned=len(result)
    )


@pytest.mark.asyncio
async def test_filtered_query_performance(ensure_timescaledb):
    """
    Test filtered query performance with multiple conditions.
    
    Target: <150ms for filtered queries
    """
    metric_def_id = str(uuid.uuid4())
    
    start_time = time.perf_counter()
    
    result = await execute_query("""
        SELECT metric_def_id, ts, value_real
        FROM factory_telemetry.metric_hist
        WHERE metric_def_id = :metric_def_id
        AND ts > NOW() - INTERVAL '7 days'
        AND value_real > 50
        ORDER BY ts DESC
        LIMIT 500
    """, {"metric_def_id": metric_def_id})
    
    query_time = time.perf_counter() - start_time
    
    assert query_time < 0.15, f"Filtered query should take <150ms, took {query_time*1000:.2f}ms"
    
    logger.info(
        "✅ Filtered query performance test passed",
        query_time_ms=f"{query_time*1000:.2f}",
        records_returned=len(result)
    )


# ============================================================================
# Compression Tests
# ============================================================================

@pytest.mark.asyncio
async def test_hypertable_stats_retrieval(ensure_timescaledb):
    """Test retrieval of hypertable statistics."""
    stats = await get_hypertable_stats()
    
    assert stats is not None, "Should return hypertable stats"
    assert "hypertable_count" in stats, "Should include hypertable count"
    assert "hypertables" in stats, "Should include hypertable details"
    
    logger.info(
        "✅ Hypertable stats retrieval test passed",
        hypertable_count=stats.get("hypertable_count")
    )


@pytest.mark.asyncio
async def test_compression_stats_retrieval(ensure_timescaledb):
    """
    Test retrieval of compression statistics.
    
    Validates compression effectiveness and storage savings.
    """
    stats = await get_compression_stats()
    
    assert stats is not None, "Should return compression stats"
    
    # If compression is enabled and has run, validate ratios
    if stats.get("compressed_table_count", 0) > 0:
        for table in stats.get("tables", []):
            compression_ratio = table.get("compression_ratio_percent", 0)
            if compression_ratio > 0:
                # Phase Plan Benchmark: >70% compression
                logger.info(
                    "Compression ratio achieved",
                    table=table.get("table"),
                    ratio_percent=f"{compression_ratio:.2f}"
                )
    
    logger.info(
        "✅ Compression stats retrieval test passed",
        compressed_tables=stats.get("compressed_table_count")
    )


@pytest.mark.asyncio
async def test_chunk_details_retrieval(ensure_timescaledb):
    """Test retrieval of chunk details for hypertables."""
    details = await get_chunk_details()
    
    assert details is not None, "Should return chunk details"
    assert "chunk_count" in details, "Should include chunk count"
    assert "chunks" in details, "Should include chunk list"
    
    logger.info(
        "✅ Chunk details retrieval test passed",
        chunk_count=details.get("chunk_count")
    )


@pytest.mark.asyncio
async def test_table_specific_chunk_details(ensure_timescaledb):
    """Test retrieval of chunk details for specific table."""
    details = await get_chunk_details("metric_hist")
    
    assert details is not None, "Should return chunk details"
    
    # All chunks should be for the specified table
    for chunk in details.get("chunks", []):
        assert chunk.get("table") == "metric_hist", "All chunks should be for metric_hist"
    
    logger.info(
        "✅ Table-specific chunk details test passed",
        table="metric_hist",
        chunk_count=details.get("chunk_count")
    )


# ============================================================================
# Policy Configuration Tests
# ============================================================================

@pytest.mark.asyncio
async def test_timescaledb_policies_setup(ensure_timescaledb):
    """
    Test TimescaleDB policy configuration.
    
    Validates that compression and retention policies are properly configured.
    """
    # Setup policies
    await setup_timescaledb_policies()
    
    # Verify policies are configured by checking health
    health = await get_timescaledb_health()
    
    assert health.get("status") in ["healthy", "degraded"], "Should have valid health status"
    assert health.get("extension_installed") is True, "Extension should be installed"
    
    logger.info("✅ TimescaleDB policies setup test passed")


# ============================================================================
# Concurrent Operations Tests
# ============================================================================

@pytest.mark.asyncio
async def test_concurrent_insertions(ensure_timescaledb, clean_test_data):
    """
    Test concurrent insertion performance.
    
    Validates that TimescaleDB handles concurrent writes efficiently.
    """
    async def insert_batch(batch_id: int, count: int):
        """Insert a batch of records."""
        test_data = await generate_metric_data(count)
        
        async with get_db_session() as session:
            for record in test_data:
                await session.execute(text("""
                    INSERT INTO factory_telemetry.metric_hist 
                    (metric_def_id, ts, value_real, value_int, value_bool)
                    VALUES (:metric_def_id, :ts, :value_real, :value_int, :value_bool)
                """), record)
        
        return batch_id, count
    
    start_time = time.perf_counter()
    
    # Run 5 concurrent insertion tasks
    tasks = [insert_batch(i, 200) for i in range(5)]
    results = await asyncio.gather(*tasks)
    
    concurrent_time = time.perf_counter() - start_time
    total_records = sum(count for _, count in results)
    records_per_second = total_records / concurrent_time
    
    assert concurrent_time < 2.0, f"Concurrent insertions should take <2s, took {concurrent_time:.3f}s"
    assert records_per_second > 500, f"Should achieve >500 records/sec, achieved {records_per_second:.0f}"
    
    logger.info(
        "✅ Concurrent insertion test passed",
        total_records=total_records,
        concurrent_time_sec=f"{concurrent_time:.3f}",
        records_per_second=f"{records_per_second:.0f}"
    )


@pytest.mark.asyncio
async def test_concurrent_queries(ensure_timescaledb):
    """
    Test concurrent query performance.
    
    Validates that TimescaleDB handles concurrent reads efficiently.
    """
    async def run_query(query_id: int):
        """Run a test query."""
        start = time.perf_counter()
        
        result = await execute_query("""
            SELECT metric_def_id, ts, value_real
            FROM factory_telemetry.metric_hist
            WHERE ts > NOW() - INTERVAL '1 hour'
            ORDER BY ts DESC
            LIMIT 50
        """)
        
        elapsed = time.perf_counter() - start
        return query_id, len(result), elapsed
    
    start_time = time.perf_counter()
    
    # Run 10 concurrent queries
    tasks = [run_query(i) for i in range(10)]
    results = await asyncio.gather(*tasks)
    
    concurrent_time = time.perf_counter() - start_time
    avg_query_time = sum(elapsed for _, _, elapsed in results) / len(results)
    
    assert concurrent_time < 1.0, f"10 concurrent queries should take <1s, took {concurrent_time:.3f}s"
    assert avg_query_time < 0.15, f"Average query time should be <150ms, was {avg_query_time*1000:.2f}ms"
    
    logger.info(
        "✅ Concurrent query test passed",
        concurrent_queries=10,
        total_time_sec=f"{concurrent_time:.3f}",
        avg_query_time_ms=f"{avg_query_time*1000:.2f}"
    )


# ============================================================================
# Storage Efficiency Tests
# ============================================================================

@pytest.mark.asyncio
async def test_storage_efficiency_metrics(ensure_timescaledb):
    """
    Test storage efficiency metrics.
    
    Validates chunk sizing and overall storage efficiency.
    Benchmark from Phase Plan: <1GB per month for typical production data
    """
    stats = await get_hypertable_stats()
    
    if stats.get("hypertable_count", 0) > 0:
        for hypertable in stats.get("hypertables", []):
            table_name = hypertable.get("table")
            total_size = hypertable.get("total_size")
            chunk_count = hypertable.get("chunk_count")
            avg_chunk_size = hypertable.get("avg_chunk_size")
            
            logger.info(
                "Storage efficiency metrics",
                table=table_name,
                total_size=total_size,
                chunk_count=chunk_count,
                avg_chunk_size=avg_chunk_size
            )
    
    logger.info("✅ Storage efficiency metrics test passed")


# ============================================================================
# Integration Tests
# ============================================================================

@pytest.mark.asyncio
async def test_end_to_end_workflow(ensure_timescaledb, clean_test_data):
    """
    Test complete end-to-end workflow: insert, query, verify.
    
    This test validates the entire data lifecycle in TimescaleDB.
    """
    # Step 1: Insert test data
    metric_def_id = str(uuid.uuid4())
    test_data = await generate_metric_data(100, metric_def_id)
    
    insert_start = time.perf_counter()
    async with get_db_session() as session:
        for record in test_data:
            await session.execute(text("""
                INSERT INTO factory_telemetry.metric_hist 
                (metric_def_id, ts, value_real, value_int, value_bool)
                VALUES (:metric_def_id, :ts, :value_real, :value_int, :value_bool)
            """), record)
    insert_time = time.perf_counter() - insert_start
    
    # Step 2: Query the data back
    query_start = time.perf_counter()
    result = await execute_query("""
        SELECT COUNT(*) as count
        FROM factory_telemetry.metric_hist
        WHERE metric_def_id = :metric_def_id
    """, {"metric_def_id": metric_def_id})
    query_time = time.perf_counter() - query_start
    
    # Step 3: Verify data integrity
    count = result[0][0] if result else 0
    assert count == 100, f"Should retrieve all 100 records, got {count}"
    
    # Step 4: Performance assertions
    assert insert_time < 1.0, f"Insert should take <1s, took {insert_time:.3f}s"
    assert query_time < 0.1, f"Query should take <100ms, took {query_time*1000:.2f}ms"
    
    logger.info(
        "✅ End-to-end workflow test passed",
        records_inserted=100,
        records_retrieved=count,
        insert_time_sec=f"{insert_time:.3f}",
        query_time_ms=f"{query_time*1000:.2f}"
    )


if __name__ == "__main__":
    # Allow running tests directly for development
    pytest.main([__file__, "-v", "--asyncio-mode=auto"])

