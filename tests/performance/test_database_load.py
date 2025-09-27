"""
Performance tests for database load testing
Tests database performance under various load conditions
"""

import pytest
import asyncio
import time
import statistics
from datetime import datetime, timedelta
import uuid
import sys
import os

# Add backend to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'backend'))

from app.database import get_database


class TestDatabaseLoadPerformance:
    """Performance tests for database load testing"""
    
    @pytest.fixture
    async def db(self):
        """Get database connection"""
        return await get_database()
    
    @pytest.mark.asyncio
    async def test_database_query_performance(self, db):
        """Test database query performance"""
        
        # Test simple query performance
        query_times = []
        
        for i in range(100):
            start_time = time.time()
            
            try:
                result = await db.fetch_one("SELECT 1 as test")
                end_time = time.time()
                
                query_time = end_time - start_time
                query_times.append(query_time)
                
                # Simple query should be very fast
                assert query_time < 0.1, f"Simple query time exceeded 0.1 seconds: {query_time:.3f}s"
                
            except Exception as e:
                print(f"Query {i} failed: {e}")
        
        if query_times:
            avg_query_time = statistics.mean(query_times)
            max_query_time = max(query_times)
            
            print(f"\nDatabase Query Performance:")
            print(f"  Successful queries: {len(query_times)}/100")
            print(f"  Average query time: {avg_query_time:.3f}s")
            print(f"  Max query time: {max_query_time:.3f}s")
            
            assert avg_query_time < 0.05, f"Average query time exceeded 0.05 seconds: {avg_query_time:.3f}s"
    
    @pytest.mark.asyncio
    async def test_database_insert_performance(self, db):
        """Test database insert performance"""
        
        # Test insert performance
        insert_times = []
        
        for i in range(50):
            start_time = time.time()
            
            try:
                # Insert test data
                insert_query = """
                INSERT INTO factory_telemetry.production_lines (name, description, status)
                VALUES (%s, %s, %s)
                RETURNING id
                """
                
                result = await db.fetch_one(insert_query, (f"Perf Test Line {i}", f"Performance test line {i}", "active"))
                end_time = time.time()
                
                insert_time = end_time - start_time
                insert_times.append(insert_time)
                
                # Insert should be reasonably fast
                assert insert_time < 0.5, f"Insert time exceeded 0.5 seconds: {insert_time:.3f}s"
                
                # Cleanup
                if result:
                    await db.execute("DELETE FROM factory_telemetry.production_lines WHERE id = %s", (result["id"],))
                
            except Exception as e:
                print(f"Insert {i} failed: {e}")
        
        if insert_times:
            avg_insert_time = statistics.mean(insert_times)
            max_insert_time = max(insert_times)
            
            print(f"\nDatabase Insert Performance:")
            print(f"  Successful inserts: {len(insert_times)}/50")
            print(f"  Average insert time: {avg_insert_time:.3f}s")
            print(f"  Max insert time: {max_insert_time:.3f}s")
            
            assert avg_insert_time < 0.2, f"Average insert time exceeded 0.2 seconds: {avg_insert_time:.3f}s"
    
    @pytest.mark.asyncio
    async def test_database_update_performance(self, db):
        """Test database update performance"""
        
        # Create test data first
        test_line_id = None
        
        try:
            # Insert test line
            insert_query = """
            INSERT INTO factory_telemetry.production_lines (name, description, status)
            VALUES (%s, %s, %s)
            RETURNING id
            """
            
            result = await db.fetch_one(insert_query, ("Update Test Line", "Test line for update performance", "active"))
            test_line_id = result["id"]
            
            # Test update performance
            update_times = []
            
            for i in range(50):
                start_time = time.time()
                
                try:
                    # Update test data
                    update_query = """
                    UPDATE factory_telemetry.production_lines 
                    SET name = %s, updated_at = NOW()
                    WHERE id = %s
                    """
                    
                    await db.execute(update_query, (f"Updated Line {i}", test_line_id))
                    end_time = time.time()
                    
                    update_time = end_time - start_time
                    update_times.append(update_time)
                    
                    # Update should be reasonably fast
                    assert update_time < 0.5, f"Update time exceeded 0.5 seconds: {update_time:.3f}s"
                    
                except Exception as e:
                    print(f"Update {i} failed: {e}")
            
            if update_times:
                avg_update_time = statistics.mean(update_times)
                max_update_time = max(update_times)
                
                print(f"\nDatabase Update Performance:")
                print(f"  Successful updates: {len(update_times)}/50")
                print(f"  Average update time: {avg_update_time:.3f}s")
                print(f"  Max update time: {max_update_time:.3f}s")
                
                assert avg_update_time < 0.2, f"Average update time exceeded 0.2 seconds: {avg_update_time:.3f}s"
        
        finally:
            # Cleanup
            if test_line_id:
                await db.execute("DELETE FROM factory_telemetry.production_lines WHERE id = %s", (test_line_id,))
    
    @pytest.mark.asyncio
    async def test_database_delete_performance(self, db):
        """Test database delete performance"""
        
        # Test delete performance
        delete_times = []
        
        for i in range(50):
            start_time = time.time()
            
            try:
                # Insert test data
                insert_query = """
                INSERT INTO factory_telemetry.production_lines (name, description, status)
                VALUES (%s, %s, %s)
                RETURNING id
                """
                
                result = await db.fetch_one(insert_query, (f"Delete Test Line {i}", f"Test line for delete performance {i}", "active"))
                
                if result:
                    # Test delete
                    delete_start_time = time.time()
                    await db.execute("DELETE FROM factory_telemetry.production_lines WHERE id = %s", (result["id"],))
                    delete_end_time = time.time()
                    
                    delete_time = delete_end_time - delete_start_time
                    delete_times.append(delete_time)
                    
                    # Delete should be reasonably fast
                    assert delete_time < 0.5, f"Delete time exceeded 0.5 seconds: {delete_time:.3f}s"
                
            except Exception as e:
                print(f"Delete {i} failed: {e}")
        
        if delete_times:
            avg_delete_time = statistics.mean(delete_times)
            max_delete_time = max(delete_times)
            
            print(f"\nDatabase Delete Performance:")
            print(f"  Successful deletes: {len(delete_times)}/50")
            print(f"  Average delete time: {avg_delete_time:.3f}s")
            print(f"  Max delete time: {max_delete_time:.3f}s")
            
            assert avg_delete_time < 0.2, f"Average delete time exceeded 0.2 seconds: {avg_delete_time:.3f}s"
    
    @pytest.mark.asyncio
    async def test_database_concurrent_operations(self, db):
        """Test database performance with concurrent operations"""
        
        async def perform_operation(operation_id):
            """Perform a database operation"""
            try:
                # Insert
                insert_query = """
                INSERT INTO factory_telemetry.production_lines (name, description, status)
                VALUES (%s, %s, %s)
                RETURNING id
                """
                
                result = await db.fetch_one(insert_query, (f"Concurrent Line {operation_id}", f"Concurrent test line {operation_id}", "active"))
                
                if result:
                    line_id = result["id"]
                    
                    # Update
                    update_query = """
                    UPDATE factory_telemetry.production_lines 
                    SET name = %s, updated_at = NOW()
                    WHERE id = %s
                    """
                    
                    await db.execute(update_query, (f"Updated Concurrent Line {operation_id}", line_id))
                    
                    # Delete
                    await db.execute("DELETE FROM factory_telemetry.production_lines WHERE id = %s", (line_id,))
                    
                    return {"operation_id": operation_id, "success": True}
                
            except Exception as e:
                return {"operation_id": operation_id, "success": False, "error": str(e)}
        
        # Test with different concurrency levels
        concurrency_levels = [5, 10, 20]
        
        for concurrency in concurrency_levels:
            print(f"\nTesting {concurrency} concurrent database operations...")
            
            start_time = time.time()
            tasks = [perform_operation(i) for i in range(concurrency)]
            results = await asyncio.gather(*tasks)
            end_time = time.time()
            
            # Analyze results
            successful_operations = [r for r in results if r["success"]]
            success_rate = len(successful_operations) / concurrency
            
            print(f"Concurrency {concurrency}:")
            print(f"  Successful operations: {len(successful_operations)}/{concurrency}")
            print(f"  Success rate: {success_rate:.1%}")
            print(f"  Total time: {end_time - start_time:.3f}s")
            
            # Performance assertions
            assert success_rate >= 0.8, f"Success rate below 80%: {success_rate:.1%}"
            assert (end_time - start_time) < 10.0, f"Total time exceeded 10 seconds: {end_time - start_time:.3f}s"
    
    @pytest.mark.asyncio
    async def test_database_large_data_performance(self, db):
        """Test database performance with large data"""
        
        # Test with large data
        large_data = {
            "name": "Large Data Test Line",
            "description": "Test line with large data for performance testing",
            "status": "active",
            "metadata": {
                "large_field": "x" * 10000,  # 10KB
                "array_field": list(range(1000)),  # 1000 integers
                "nested_data": {
                    "level1": {
                        "level2": {
                            "level3": {
                                "data": "x" * 5000
                            }
                        }
                    }
                }
            }
        }
        
        # Test insert with large data
        start_time = time.time()
        
        try:
            insert_query = """
            INSERT INTO factory_telemetry.production_lines (name, description, status)
            VALUES (%s, %s, %s)
            RETURNING id
            """
            
            result = await db.fetch_one(insert_query, (large_data["name"], large_data["description"], large_data["status"]))
            end_time = time.time()
            
            insert_time = end_time - start_time
            
            print(f"\nDatabase Large Data Performance:")
            print(f"  Large data insert time: {insert_time:.3f}s")
            
            # Large data insert should still be reasonably fast
            assert insert_time < 1.0, f"Large data insert time exceeded 1 second: {insert_time:.3f}s"
            
            # Cleanup
            if result:
                await db.execute("DELETE FROM factory_telemetry.production_lines WHERE id = %s", (result["id"],))
                
        except Exception as e:
            print(f"Large data test failed: {e}")
    
    @pytest.mark.asyncio
    async def test_database_transaction_performance(self, db):
        """Test database transaction performance"""
        
        # Test transaction performance
        transaction_times = []
        
        for i in range(20):
            start_time = time.time()
            
            try:
                # Start transaction
                await db.execute("BEGIN")
                
                # Insert multiple records
                for j in range(5):
                    insert_query = """
                    INSERT INTO factory_telemetry.production_lines (name, description, status)
                    VALUES (%s, %s, %s)
                    RETURNING id
                    """
                    
                    result = await db.fetch_one(insert_query, (f"Transaction Line {i}-{j}", f"Transaction test line {i}-{j}", "active"))
                    
                    if result:
                        # Update the record
                        update_query = """
                        UPDATE factory_telemetry.production_lines 
                        SET name = %s, updated_at = NOW()
                        WHERE id = %s
                        """
                        
                        await db.execute(update_query, (f"Updated Transaction Line {i}-{j}", result["id"]))
                
                # Commit transaction
                await db.execute("COMMIT")
                end_time = time.time()
                
                transaction_time = end_time - start_time
                transaction_times.append(transaction_time)
                
                # Transaction should be reasonably fast
                assert transaction_time < 2.0, f"Transaction time exceeded 2 seconds: {transaction_time:.3f}s"
                
            except Exception as e:
                # Rollback on error
                await db.execute("ROLLBACK")
                print(f"Transaction {i} failed: {e}")
        
        if transaction_times:
            avg_transaction_time = statistics.mean(transaction_times)
            max_transaction_time = max(transaction_times)
            
            print(f"\nDatabase Transaction Performance:")
            print(f"  Successful transactions: {len(transaction_times)}/20")
            print(f"  Average transaction time: {avg_transaction_time:.3f}s")
            print(f"  Max transaction time: {max_transaction_time:.3f}s")
            
            assert avg_transaction_time < 1.0, f"Average transaction time exceeded 1 second: {avg_transaction_time:.3f}s"
        
        # Cleanup any remaining test data
        await db.execute("DELETE FROM factory_telemetry.production_lines WHERE name LIKE 'Transaction Line%'")
    
    @pytest.mark.asyncio
    async def test_database_connection_pool_performance(self, db):
        """Test database connection pool performance"""
        
        # Test multiple database operations to stress connection pool
        operation_times = []
        
        async def perform_db_operation(operation_id):
            """Perform a database operation"""
            start_time = time.time()
            
            try:
                # Simple query
                result = await db.fetch_one("SELECT %s as test", (operation_id,))
                
                # Insert
                insert_query = """
                INSERT INTO factory_telemetry.production_lines (name, description, status)
                VALUES (%s, %s, %s)
                RETURNING id
                """
                
                insert_result = await db.fetch_one(insert_query, (f"Pool Test Line {operation_id}", f"Connection pool test line {operation_id}", "active"))
                
                if insert_result:
                    # Delete
                    await db.execute("DELETE FROM factory_telemetry.production_lines WHERE id = %s", (insert_result["id"],))
                
                end_time = time.time()
                return end_time - start_time
                
            except Exception as e:
                print(f"Operation {operation_id} failed: {e}")
                return None
        
        # Test with many concurrent operations
        concurrent_operations = 100
        
        start_time = time.time()
        tasks = [perform_db_operation(i) for i in range(concurrent_operations)]
        results = await asyncio.gather(*tasks)
        end_time = time.time()
        
        # Analyze results
        successful_operations = [r for r in results if r is not None]
        
        if successful_operations:
            avg_operation_time = statistics.mean(successful_operations)
            max_operation_time = max(successful_operations)
            
            print(f"\nDatabase Connection Pool Performance:")
            print(f"  Concurrent operations: {concurrent_operations}")
            print(f"  Successful operations: {len(successful_operations)}")
            print(f"  Total time: {end_time - start_time:.3f}s")
            print(f"  Average operation time: {avg_operation_time:.3f}s")
            print(f"  Max operation time: {max_operation_time:.3f}s")
            
            # Performance assertions
            assert len(successful_operations) >= concurrent_operations * 0.9, f"Success rate below 90%: {len(successful_operations)}/{concurrent_operations}"
            assert avg_operation_time < 0.5, f"Average operation time exceeded 0.5 seconds: {avg_operation_time:.3f}s"
    
    @pytest.mark.asyncio
    async def test_database_memory_usage(self, db):
        """Test database memory usage under load"""
        
        import psutil
        import os
        
        # Get initial memory usage
        process = psutil.Process(os.getpid())
        initial_memory = process.memory_info().rss / 1024 / 1024  # MB
        
        print(f"\nInitial memory usage: {initial_memory:.2f} MB")
        
        # Perform many database operations
        for i in range(1000):
            try:
                # Simple query
                await db.fetch_one("SELECT %s as test", (i,))
                
                # Insert
                insert_query = """
                INSERT INTO factory_telemetry.production_lines (name, description, status)
                VALUES (%s, %s, %s)
                RETURNING id
                """
                
                result = await db.fetch_one(insert_query, (f"Memory Test Line {i}", f"Memory test line {i}", "active"))
                
                if result:
                    # Delete
                    await db.execute("DELETE FROM factory_telemetry.production_lines WHERE id = %s", (result["id"],))
                
            except Exception as e:
                print(f"Operation {i} failed: {e}")
        
        # Check memory usage after operations
        final_memory = process.memory_info().rss / 1024 / 1024  # MB
        memory_increase = final_memory - initial_memory
        
        print(f"Final memory usage: {final_memory:.2f} MB")
        print(f"Memory increase: {memory_increase:.2f} MB")
        
        # Memory usage should not increase excessively
        assert memory_increase < 100, f"Memory increase exceeded 100 MB: {memory_increase:.2f} MB"


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
