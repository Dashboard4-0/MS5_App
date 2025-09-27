"""
Integration tests for database integration
Tests database operations and data integrity
"""

import pytest
import asyncio
from datetime import datetime, timedelta
import uuid
import sys
import os

# Add backend to path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'backend'))

from app.database import get_database
from app.services.production_service import ProductionService
from app.services.oee_calculator import OEECalculator
from app.services.andon_service import AndonService


class TestDatabaseIntegration:
    """Integration tests for database operations"""
    
    @pytest.fixture
    async def db(self):
        """Get database connection"""
        return await get_database()
    
    @pytest.fixture
    def production_service(self):
        """Create production service instance"""
        return ProductionService()
    
    @pytest.fixture
    def oee_calculator(self):
        """Create OEE calculator instance"""
        return OEECalculator()
    
    @pytest.fixture
    def andon_service(self):
        """Create Andon service instance"""
        return AndonService()
    
    @pytest.mark.asyncio
    async def test_database_connection(self, db):
        """Test database connection is working"""
        # Test basic query
        result = await db.fetch_one("SELECT 1 as test")
        assert result is not None
        assert result["test"] == 1
    
    @pytest.mark.asyncio
    async def test_production_lines_crud(self, db):
        """Test production lines CRUD operations"""
        # Create
        line_data = {
            "name": "Test Line",
            "description": "Test Production Line",
            "status": "active"
        }
        
        create_query = """
        INSERT INTO factory_telemetry.production_lines (name, description, status)
        VALUES (%(name)s, %(description)s, %(status)s)
        RETURNING id, name, description, status, created_at
        """
        
        result = await db.fetch_one(create_query, line_data)
        assert result is not None
        assert result["name"] == line_data["name"]
        assert result["status"] == line_data["status"]
        
        line_id = result["id"]
        
        # Read
        read_query = "SELECT * FROM factory_telemetry.production_lines WHERE id = %s"
        result = await db.fetch_one(read_query, (line_id,))
        assert result is not None
        assert result["name"] == line_data["name"]
        
        # Update
        update_data = {"name": "Updated Test Line", "status": "inactive"}
        update_query = """
        UPDATE factory_telemetry.production_lines 
        SET name = %(name)s, status = %(status)s, updated_at = NOW()
        WHERE id = %(id)s
        RETURNING *
        """
        
        result = await db.fetch_one(update_query, {**update_data, "id": line_id})
        assert result is not None
        assert result["name"] == update_data["name"]
        assert result["status"] == update_data["status"]
        
        # Delete
        delete_query = "DELETE FROM factory_telemetry.production_lines WHERE id = %s"
        await db.execute(delete_query, (line_id,))
        
        # Verify deletion
        result = await db.fetch_one(read_query, (line_id,))
        assert result is None
    
    @pytest.mark.asyncio
    async def test_equipment_config_crud(self, db):
        """Test equipment configuration CRUD operations"""
        # Create production line first
        line_data = {
            "name": "Test Line for Equipment",
            "description": "Test Line",
            "status": "active"
        }
        
        line_query = """
        INSERT INTO factory_telemetry.production_lines (name, description, status)
        VALUES (%(name)s, %(description)s, %(status)s)
        RETURNING id
        """
        
        line_result = await db.fetch_one(line_query, line_data)
        line_id = line_result["id"]
        
        # Create equipment config
        equipment_data = {
            "equipment_code": "EQ-TEST-001",
            "equipment_name": "Test Equipment",
            "equipment_type": "production",
            "production_line_id": line_id,
            "ideal_cycle_time": 1.0,
            "target_speed": 100.0,
            "oee_targets": {"availability": 0.9, "performance": 0.9, "quality": 0.95}
        }
        
        create_query = """
        INSERT INTO factory_telemetry.equipment_config 
        (equipment_code, equipment_name, equipment_type, production_line_id, 
         ideal_cycle_time, target_speed, oee_targets)
        VALUES (%(equipment_code)s, %(equipment_name)s, %(equipment_type)s, 
                %(production_line_id)s, %(ideal_cycle_time)s, %(target_speed)s, %(oee_targets)s)
        RETURNING *
        """
        
        result = await db.fetch_one(create_query, equipment_data)
        assert result is not None
        assert result["equipment_code"] == equipment_data["equipment_code"]
        assert result["production_line_id"] == line_id
        
        equipment_id = result["id"]
        
        # Test foreign key constraint
        read_query = """
        SELECT ec.*, pl.name as line_name 
        FROM factory_telemetry.equipment_config ec
        JOIN factory_telemetry.production_lines pl ON ec.production_line_id = pl.id
        WHERE ec.id = %s
        """
        
        result = await db.fetch_one(read_query, (equipment_id,))
        assert result is not None
        assert result["line_name"] == line_data["name"]
        
        # Cleanup
        await db.execute("DELETE FROM factory_telemetry.equipment_config WHERE id = %s", (equipment_id,))
        await db.execute("DELETE FROM factory_telemetry.production_lines WHERE id = %s", (line_id,))
    
    @pytest.mark.asyncio
    async def test_job_assignments_crud(self, db):
        """Test job assignments CRUD operations"""
        # Create user first
        user_data = {
            "username": "testuser",
            "email": "test@example.com",
            "password_hash": "hashedpassword",
            "role": "operator",
            "first_name": "Test",
            "last_name": "User"
        }
        
        user_query = """
        INSERT INTO factory_telemetry.users 
        (username, email, password_hash, role, first_name, last_name)
        VALUES (%(username)s, %(email)s, %(password_hash)s, %(role)s, %(first_name)s, %(last_name)s)
        RETURNING id
        """
        
        user_result = await db.fetch_one(user_query, user_data)
        user_id = user_result["id"]
        
        # Create job assignment
        job_data = {
            "user_id": user_id,
            "job_type": "production",
            "title": "Test Job",
            "description": "Test job assignment",
            "priority": "high",
            "status": "assigned"
        }
        
        create_query = """
        INSERT INTO factory_telemetry.job_assignments 
        (user_id, job_type, title, description, priority, status)
        VALUES (%(user_id)s, %(job_type)s, %(title)s, %(description)s, %(priority)s, %(status)s)
        RETURNING *
        """
        
        result = await db.fetch_one(create_query, job_data)
        assert result is not None
        assert result["title"] == job_data["title"]
        assert result["user_id"] == user_id
        
        job_id = result["id"]
        
        # Test job lifecycle
        # Accept job
        accept_query = """
        UPDATE factory_telemetry.job_assignments 
        SET status = 'accepted', accepted_at = NOW()
        WHERE id = %s
        RETURNING *
        """
        
        result = await db.fetch_one(accept_query, (job_id,))
        assert result["status"] == "accepted"
        assert result["accepted_at"] is not None
        
        # Start job
        start_query = """
        UPDATE factory_telemetry.job_assignments 
        SET status = 'in_progress', started_at = NOW()
        WHERE id = %s
        RETURNING *
        """
        
        result = await db.fetch_one(start_query, (job_id,))
        assert result["status"] == "in_progress"
        assert result["started_at"] is not None
        
        # Complete job
        complete_query = """
        UPDATE factory_telemetry.job_assignments 
        SET status = 'completed', completed_at = NOW(), completion_notes = %s
        WHERE id = %s
        RETURNING *
        """
        
        result = await db.fetch_one(complete_query, ("Job completed successfully", job_id))
        assert result["status"] == "completed"
        assert result["completed_at"] is not None
        assert result["completion_notes"] == "Job completed successfully"
        
        # Cleanup
        await db.execute("DELETE FROM factory_telemetry.job_assignments WHERE id = %s", (job_id,))
        await db.execute("DELETE FROM factory_telemetry.users WHERE id = %s", (user_id,))
    
    @pytest.mark.asyncio
    async def test_andon_events_crud(self, db):
        """Test Andon events CRUD operations"""
        # Create Andon event
        event_data = {
            "equipment_code": "EQ-TEST-001",
            "line_id": str(uuid.uuid4()),
            "event_type": "fault",
            "priority": "high",
            "description": "Test Andon event",
            "status": "active"
        }
        
        create_query = """
        INSERT INTO factory_telemetry.andon_events 
        (equipment_code, line_id, event_type, priority, description, status)
        VALUES (%(equipment_code)s, %(line_id)s, %(event_type)s, %(priority)s, %(description)s, %(status)s)
        RETURNING *
        """
        
        result = await db.fetch_one(create_query, event_data)
        assert result is not None
        assert result["event_type"] == event_data["event_type"]
        assert result["priority"] == event_data["priority"]
        
        event_id = result["id"]
        
        # Test event lifecycle
        # Acknowledge event
        acknowledge_query = """
        UPDATE factory_telemetry.andon_events 
        SET status = 'acknowledged', acknowledged_at = NOW()
        WHERE id = %s
        RETURNING *
        """
        
        result = await db.fetch_one(acknowledge_query, (event_id,))
        assert result["status"] == "acknowledged"
        assert result["acknowledged_at"] is not None
        
        # Resolve event
        resolve_query = """
        UPDATE factory_telemetry.andon_events 
        SET status = 'resolved', resolved_at = NOW(), resolution_notes = %s
        WHERE id = %s
        RETURNING *
        """
        
        result = await db.fetch_one(resolve_query, ("Issue resolved", event_id))
        assert result["status"] == "resolved"
        assert result["resolved_at"] is not None
        assert result["resolution_notes"] == "Issue resolved"
        
        # Cleanup
        await db.execute("DELETE FROM factory_telemetry.andon_events WHERE id = %s", (event_id,))
    
    @pytest.mark.asyncio
    async def test_oee_calculations_crud(self, db):
        """Test OEE calculations CRUD operations"""
        # Create OEE calculation
        oee_data = {
            "equipment_code": "EQ-TEST-001",
            "line_id": str(uuid.uuid4()),
            "oee": 0.85,
            "availability": 0.9,
            "performance": 0.95,
            "quality": 0.95,
            "calculated_at": datetime.now()
        }
        
        create_query = """
        INSERT INTO factory_telemetry.oee_calculations 
        (equipment_code, line_id, oee, availability, performance, quality, calculated_at)
        VALUES (%(equipment_code)s, %(line_id)s, %(oee)s, %(availability)s, %(performance)s, %(quality)s, %(calculated_at)s)
        RETURNING *
        """
        
        result = await db.fetch_one(create_query, oee_data)
        assert result is not None
        assert result["oee"] == oee_data["oee"]
        assert result["availability"] == oee_data["availability"]
        assert result["performance"] == oee_data["performance"]
        assert result["quality"] == oee_data["quality"]
        
        calculation_id = result["id"]
        
        # Test OEE calculation retrieval
        read_query = """
        SELECT * FROM factory_telemetry.oee_calculations 
        WHERE equipment_code = %s
        ORDER BY calculated_at DESC
        LIMIT 1
        """
        
        result = await db.fetch_one(read_query, (oee_data["equipment_code"],))
        assert result is not None
        assert result["equipment_code"] == oee_data["equipment_code"]
        
        # Cleanup
        await db.execute("DELETE FROM factory_telemetry.oee_calculations WHERE id = %s", (calculation_id,))
    
    @pytest.mark.asyncio
    async def test_downtime_events_crud(self, db):
        """Test downtime events CRUD operations"""
        # Create downtime event
        downtime_data = {
            "equipment_code": "EQ-TEST-001",
            "line_id": str(uuid.uuid4()),
            "start_time": datetime.now(),
            "end_time": datetime.now() + timedelta(minutes=30),
            "duration_minutes": 30,
            "category": "unplanned",
            "description": "Test downtime event"
        }
        
        create_query = """
        INSERT INTO factory_telemetry.downtime_events 
        (equipment_code, line_id, start_time, end_time, duration_minutes, category, description)
        VALUES (%(equipment_code)s, %(line_id)s, %(start_time)s, %(end_time)s, %(duration_minutes)s, %(category)s, %(description)s)
        RETURNING *
        """
        
        result = await db.fetch_one(create_query, downtime_data)
        assert result is not None
        assert result["equipment_code"] == downtime_data["equipment_code"]
        assert result["duration_minutes"] == downtime_data["duration_minutes"]
        assert result["category"] == downtime_data["category"]
        
        downtime_id = result["id"]
        
        # Test downtime event retrieval
        read_query = """
        SELECT * FROM factory_telemetry.downtime_events 
        WHERE equipment_code = %s
        ORDER BY start_time DESC
        LIMIT 1
        """
        
        result = await db.fetch_one(read_query, (downtime_data["equipment_code"],))
        assert result is not None
        assert result["equipment_code"] == downtime_data["equipment_code"]
        
        # Cleanup
        await db.execute("DELETE FROM factory_telemetry.downtime_events WHERE id = %s", (downtime_id,))
    
    @pytest.mark.asyncio
    async def test_data_integrity_constraints(self, db):
        """Test database integrity constraints"""
        # Test foreign key constraint violation
        invalid_job_data = {
            "user_id": str(uuid.uuid4()),  # Non-existent user
            "job_type": "production",
            "title": "Test Job",
            "status": "assigned"
        }
        
        create_query = """
        INSERT INTO factory_telemetry.job_assignments 
        (user_id, job_type, title, status)
        VALUES (%(user_id)s, %(job_type)s, %(title)s, %(status)s)
        """
        
        # This should raise a foreign key constraint error
        with pytest.raises(Exception):
            await db.execute(create_query, invalid_job_data)
    
    @pytest.mark.asyncio
    async def test_transaction_rollback(self, db):
        """Test transaction rollback functionality"""
        # Start transaction
        await db.execute("BEGIN")
        
        try:
            # Insert data
            test_data = {
                "name": "Transaction Test Line",
                "description": "Test Line",
                "status": "active"
            }
            
            insert_query = """
            INSERT INTO factory_telemetry.production_lines (name, description, status)
            VALUES (%(name)s, %(description)s, %(status)s)
            RETURNING id
            """
            
            result = await db.fetch_one(insert_query, test_data)
            line_id = result["id"]
            
            # Simulate error
            raise Exception("Simulated error")
            
        except Exception:
            # Rollback transaction
            await db.execute("ROLLBACK")
        
        # Verify data was not committed
        read_query = "SELECT * FROM factory_telemetry.production_lines WHERE id = %s"
        result = await db.fetch_one(read_query, (line_id,))
        assert result is None
    
    @pytest.mark.asyncio
    async def test_concurrent_access(self, db):
        """Test concurrent database access"""
        async def create_line(line_num):
            line_data = {
                "name": f"Concurrent Line {line_num}",
                "description": f"Test Line {line_num}",
                "status": "active"
            }
            
            insert_query = """
            INSERT INTO factory_telemetry.production_lines (name, description, status)
            VALUES (%(name)s, %(description)s, %(status)s)
            RETURNING id
            """
            
            result = await db.fetch_one(insert_query, line_data)
            return result["id"]
        
        # Create multiple lines concurrently
        tasks = [create_line(i) for i in range(5)]
        line_ids = await asyncio.gather(*tasks)
        
        # Verify all lines were created
        assert len(line_ids) == 5
        assert all(line_id is not None for line_id in line_ids)
        
        # Cleanup
        for line_id in line_ids:
            await db.execute("DELETE FROM factory_telemetry.production_lines WHERE id = %s", (line_id,))


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
