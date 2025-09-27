"""Enhanced FastAPI endpoints with full CRUD operations for PLC telemetry management."""

import asyncio
import hashlib
import json
import os
import uuid
from datetime import datetime
from typing import Any, Dict, List, Optional

import bcrypt
import structlog
import uvicorn
from fastapi import (
    Depends, FastAPI, HTTPException, Query, UploadFile, WebSocket, 
    WebSocketDisconnect, status
)
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import PlainTextResponse
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from prometheus_client import generate_latest
from sqlalchemy import text
import jwt

from .config import settings
from .db import db_manager
from .models import (
    ActiveFault, EquipmentCreate, EquipmentResponse, EquipmentStatus,
    EquipmentUpdate, HealthStatus, LoginRequest, LoginResponse,
    MetricCreate, MetricResponse, MetricUpdate, MetricValue, PLCResponse,
    PLCCreate, PLCUpdate, SystemHealth, UserCreate, UserResponse, UserUpdate,
    WebSocketMessage
)

logger = structlog.get_logger()

# JWT Configuration
SECRET_KEY = os.getenv("JWT_SECRET_KEY", "your-secret-key-change-in-production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

# FastAPI app
app = FastAPI(
    title="PLC Telemetry Management API",
    description="Complete API for factory telemetry data management",
    version="2.0.0",
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["*"],
)

# Security
security = HTTPBearer()

# WebSocket connection manager
class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)

    async def send_personal_message(self, message: str, websocket: WebSocket):
        await websocket.send_text(message)

    async def broadcast(self, message: str):
        for connection in self.active_connections:
            try:
                await connection.send_text(message)
            except:
                # Remove disconnected clients
                self.active_connections.remove(connection)

manager = ConnectionManager()

# Authentication functions
def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against its hash."""
    return bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password.encode('utf-8'))

def get_password_hash(password: str) -> str:
    """Hash a password."""
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')

def create_access_token(data: dict):
    """Create JWT access token."""
    to_encode = data.copy()
    expire = datetime.utcnow().timestamp() + (ACCESS_TOKEN_EXPIRE_MINUTES * 60)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Get current authenticated user."""
    try:
        payload = jwt.decode(credentials.credentials, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Could not validate credentials",
                headers={"WWW-Authenticate": "Bearer"},
            )
        return username
    except jwt.PyJWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

# Startup event
@app.on_event("startup")
async def startup_event():
    """Initialize database connection on startup."""
    try:
        db_manager.connect()
        logger.info("api_database_connected")
    except Exception as e:
        logger.error("api_database_connection_failed", error=str(e))
        raise

# Health check endpoints
@app.get("/health", response_model=HealthStatus)
async def health_check():
    """Health check endpoint."""
    try:
        with db_manager.get_session() as session:
            result = session.execute(text("SELECT 1"))
            if result:
                return HealthStatus(
                    status="healthy",
                    database="connected",
                    timestamp=datetime.utcnow(),
                )
    except Exception as e:
        logger.error("health_check_failed", error=str(e))
        return HealthStatus(
            status="unhealthy",
            database="disconnected",
            timestamp=datetime.utcnow(),
        )

@app.get("/system-health", response_model=SystemHealth)
async def system_health():
    """Detailed system health check."""
    try:
        with db_manager.get_session() as session:
            # Check database
            db_result = session.execute(text("SELECT 1"))
            db_status = "connected" if db_result else "disconnected"
            
            # Get system metrics
            uptime_query = text("SELECT EXTRACT(EPOCH FROM NOW() - MIN(ts)) as uptime FROM factory_telemetry.metric_latest")
            uptime_result = session.execute(uptime_query).fetchone()
            uptime_seconds = uptime_result[0] if uptime_result and uptime_result[0] else 0
            
            return SystemHealth(
                status="healthy" if db_status == "connected" else "unhealthy",
                database=db_status,
                websocket="connected" if manager.active_connections else "disconnected",
                timestamp=datetime.utcnow(),
                uptime_seconds=uptime_seconds,
                memory_usage_mb=0.0,  # Would need psutil for real metrics
                cpu_usage_percent=0.0
            )
    except Exception as e:
        logger.error("system_health_check_failed", error=str(e))
        return SystemHealth(
            status="unhealthy",
            database="disconnected",
            websocket="disconnected",
            timestamp=datetime.utcnow(),
            uptime_seconds=0.0,
            memory_usage_mb=0.0,
            cpu_usage_percent=0.0
        )

@app.get("/metrics")
async def prometheus_metrics():
    """Prometheus metrics endpoint."""
    return PlainTextResponse(generate_latest())

# Authentication endpoints
@app.post("/auth/login", response_model=LoginResponse)
async def login(login_data: LoginRequest):
    """Authenticate user and return access token."""
    try:
        with db_manager.get_session() as session:
            # Get user from database
            user_query = text("""
                SELECT id, username, email, password_hash, role, created_at, last_login
                FROM factory_telemetry.users
                WHERE username = :username
            """)
            result = session.execute(user_query, {"username": login_data.username}).fetchone()
            
            if not result:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Incorrect username or password"
                )
            
            # Verify password
            if not verify_password(login_data.password, result.password_hash):
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Incorrect username or password"
                )
            
            # Update last login
            update_query = text("""
                UPDATE factory_telemetry.users
                SET last_login = NOW()
                WHERE id = :user_id
            """)
            session.execute(update_query, {"user_id": result.id})
            session.commit()
            
            # Create access token
            access_token = create_access_token(data={"sub": result.username})
            
            user_response = UserResponse(
                id=result.id,
                username=result.username,
                email=result.email,
                role=result.role,
                created_at=result.created_at,
                last_login=datetime.utcnow()
            )
            
            return LoginResponse(
                access_token=access_token,
                token_type="bearer",
                user=user_response
            )
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error("login_failed", error=str(e))
        raise HTTPException(status_code=500, detail="Internal server error")

# PLC Management endpoints
@app.get("/plcs", response_model=List[PLCResponse])
async def list_plcs(current_user: str = Depends(get_current_user)):
    """List all configured PLCs."""
    try:
        with db_manager.get_session() as session:
            query = text("""
                SELECT id, name, ip_address, plc_type, port, enabled, 
                       poll_interval_s, created_at, updated_at
                FROM factory_telemetry.plc_config
                ORDER BY name
            """)
            result = session.execute(query)
            
            plcs = []
            for row in result:
                plcs.append(PLCResponse(
                    id=row.id,
                    name=row.name,
                    ip_address=row.ip_address,
                    plc_type=row.plc_type,
                    port=row.port,
                    enabled=row.enabled,
                    poll_interval_s=row.poll_interval_s,
                    created_at=row.created_at,
                    updated_at=row.updated_at
                ))
            
            return plcs
            
    except Exception as e:
        logger.error("list_plcs_failed", error=str(e))
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/plcs", response_model=PLCResponse)
async def create_plc(plc_data: PLCCreate, current_user: str = Depends(get_current_user)):
    """Add new PLC to system."""
    try:
        with db_manager.get_session() as session:
            # Check if PLC with same IP/port already exists
            check_query = text("""
                SELECT id FROM factory_telemetry.plc_config
                WHERE ip_address = :ip_address AND port = :port
            """)
            existing = session.execute(check_query, {
                "ip_address": plc_data.ip_address,
                "port": plc_data.port
            }).fetchone()
            
            if existing:
                raise HTTPException(
                    status_code=400,
                    detail="PLC with this IP address and port already exists"
                )
            
            # Insert new PLC
            insert_query = text("""
                INSERT INTO factory_telemetry.plc_config 
                (name, ip_address, plc_type, port, enabled, poll_interval_s, created_at, updated_at)
                VALUES (:name, :ip_address, :plc_type, :port, :enabled, :poll_interval_s, NOW(), NOW())
                RETURNING id, name, ip_address, plc_type, port, enabled, poll_interval_s, created_at, updated_at
            """)
            
            result = session.execute(insert_query, {
                "name": plc_data.name,
                "ip_address": plc_data.ip_address,
                "plc_type": plc_data.plc_type,
                "port": plc_data.port,
                "enabled": True,
                "poll_interval_s": plc_data.poll_interval_s
            }).fetchone()
            
            session.commit()
            
            return PLCResponse(
                id=result.id,
                name=result.name,
                ip_address=result.ip_address,
                plc_type=result.plc_type,
                port=result.port,
                enabled=result.enabled,
                poll_interval_s=result.poll_interval_s,
                created_at=result.created_at,
                updated_at=result.updated_at
            )
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error("create_plc_failed", error=str(e))
        raise HTTPException(status_code=500, detail=str(e))

@app.put("/plcs/{plc_id}", response_model=PLCResponse)
async def update_plc(plc_id: str, plc_data: PLCUpdate, current_user: str = Depends(get_current_user)):
    """Update PLC configuration."""
    try:
        with db_manager.get_session() as session:
            # Check if PLC exists
            check_query = text("SELECT id FROM factory_telemetry.plc_config WHERE id = :plc_id")
            existing = session.execute(check_query, {"plc_id": plc_id}).fetchone()
            
            if not existing:
                raise HTTPException(status_code=404, detail="PLC not found")
            
            # Build update query dynamically
            update_fields = []
            params = {"plc_id": plc_id}
            
            if plc_data.name is not None:
                update_fields.append("name = :name")
                params["name"] = plc_data.name
            if plc_data.ip_address is not None:
                update_fields.append("ip_address = :ip_address")
                params["ip_address"] = plc_data.ip_address
            if plc_data.plc_type is not None:
                update_fields.append("plc_type = :plc_type")
                params["plc_type"] = plc_data.plc_type
            if plc_data.port is not None:
                update_fields.append("port = :port")
                params["port"] = plc_data.port
            if plc_data.enabled is not None:
                update_fields.append("enabled = :enabled")
                params["enabled"] = plc_data.enabled
            if plc_data.poll_interval_s is not None:
                update_fields.append("poll_interval_s = :poll_interval_s")
                params["poll_interval_s"] = plc_data.poll_interval_s
            
            if not update_fields:
                raise HTTPException(status_code=400, detail="No fields to update")
            
            update_fields.append("updated_at = NOW()")
            
            update_query = text(f"""
                UPDATE factory_telemetry.plc_config
                SET {', '.join(update_fields)}
                WHERE id = :plc_id
                RETURNING id, name, ip_address, plc_type, port, enabled, poll_interval_s, created_at, updated_at
            """)
            
            result = session.execute(update_query, params).fetchone()
            session.commit()
            
            return PLCResponse(
                id=result.id,
                name=result.name,
                ip_address=result.ip_address,
                plc_type=result.plc_type,
                port=result.port,
                enabled=result.enabled,
                poll_interval_s=result.poll_interval_s,
                created_at=result.created_at,
                updated_at=result.updated_at
            )
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error("update_plc_failed", error=str(e))
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/plcs/{plc_id}")
async def delete_plc(plc_id: str, current_user: str = Depends(get_current_user)):
    """Remove PLC from system."""
    try:
        with db_manager.get_session() as session:
            # Check if PLC exists
            check_query = text("SELECT id FROM factory_telemetry.plc_config WHERE id = :plc_id")
            existing = session.execute(check_query, {"plc_id": plc_id}).fetchone()
            
            if not existing:
                raise HTTPException(status_code=404, detail="PLC not found")
            
            # Check if PLC is used by any equipment
            equipment_query = text("""
                SELECT COUNT(*) FROM factory_telemetry.equipment_config
                WHERE plc_id = :plc_id
            """)
            equipment_count = session.execute(equipment_query, {"plc_id": plc_id}).fetchone()[0]
            
            if equipment_count > 0:
                raise HTTPException(
                    status_code=400,
                    detail="Cannot delete PLC that is used by equipment"
                )
            
            # Delete PLC
            delete_query = text("DELETE FROM factory_telemetry.plc_config WHERE id = :plc_id")
            session.execute(delete_query, {"plc_id": plc_id})
            session.commit()
            
            return {"message": "PLC deleted successfully"}
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error("delete_plc_failed", error=str(e))
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/plcs/{plc_id}/test-connection")
async def test_plc_connection(plc_id: str, current_user: str = Depends(get_current_user)):
    """Test PLC connection."""
    try:
        with db_manager.get_session() as session:
            # Get PLC details
            plc_query = text("""
                SELECT name, ip_address, plc_type, port
                FROM factory_telemetry.plc_config
                WHERE id = :plc_id
            """)
            plc = session.execute(plc_query, {"plc_id": plc_id}).fetchone()
            
            if not plc:
                raise HTTPException(status_code=404, detail="PLC not found")
            
            # Here you would implement actual PLC connection testing
            # For now, we'll simulate a connection test
            import socket
            
            try:
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(5)
                result = sock.connect_ex((plc.ip_address, plc.port))
                sock.close()
                
                if result == 0:
                    return {"status": "success", "message": "Connection successful"}
                else:
                    return {"status": "failed", "message": "Connection failed"}
            except Exception as e:
                return {"status": "failed", "message": f"Connection error: {str(e)}"}
                
    except HTTPException:
        raise
    except Exception as e:
        logger.error("test_plc_connection_failed", error=str(e))
        raise HTTPException(status_code=500, detail=str(e))

# Equipment Management endpoints
@app.get("/equipment", response_model=List[EquipmentResponse])
async def list_equipment(current_user: str = Depends(get_current_user)):
    """List all configured equipment."""
    try:
        with db_manager.get_session() as session:
            query = text("""
                SELECT ec.id, ec.equipment_code, ec.name, ec.description, ec.plc_id, 
                       ec.enabled, ec.created_at, ec.updated_at,
                       pc.id as plc_id, pc.name as plc_name, pc.ip_address, pc.plc_type, 
                       pc.port, pc.enabled as plc_enabled, pc.poll_interval_s, 
                       pc.created_at as plc_created_at, pc.updated_at as plc_updated_at
                FROM factory_telemetry.equipment_config ec
                LEFT JOIN factory_telemetry.plc_config pc ON ec.plc_id = pc.id
                ORDER BY ec.name
            """)
            result = session.execute(query)
            
            equipment = []
            for row in result:
                plc_data = None
                if row.plc_id:
                    plc_data = PLCResponse(
                        id=row.plc_id,
                        name=row.plc_name,
                        ip_address=row.ip_address,
                        plc_type=row.plc_type,
                        port=row.port,
                        enabled=row.plc_enabled,
                        poll_interval_s=row.poll_interval_s,
                        created_at=row.plc_created_at,
                        updated_at=row.plc_updated_at
                    )
                
                equipment.append(EquipmentResponse(
                    id=row.id,
                    equipment_code=row.equipment_code,
                    name=row.name,
                    description=row.description,
                    plc_id=row.plc_id,
                    enabled=row.enabled,
                    created_at=row.created_at,
                    updated_at=row.updated_at,
                    plc=plc_data
                ))
            
            return equipment
            
    except Exception as e:
        logger.error("list_equipment_failed", error=str(e))
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/equipment/detailed", response_model=List[EquipmentStatus])
async def get_detailed_equipment(current_user: str = Depends(get_current_user)):
    """Get detailed equipment information with status."""
    try:
        with db_manager.get_session() as session:
            # Get equipment with latest metrics
            query = text("""
                SELECT DISTINCT ec.equipment_code, ec.name,
                       COALESCE(ml_speed.value_real, 0) as speed,
                       CASE 
                           WHEN COALESCE(ml_faults.value_bool, false) THEN 'fault'
                           WHEN COALESCE(ml_speed.value_real, 0) > 0 THEN 'running'
                           ELSE 'stopped'
                       END as status,
                       COALESCE(ml_faults.value_bool, false) as has_faults,
                       COALESCE(ml_speed.ts, NOW()) as last_update
                FROM factory_telemetry.equipment_config ec
                LEFT JOIN factory_telemetry.metric_def md_speed ON ec.equipment_code = md_speed.equipment_code AND md_speed.metric_key = 'speed_real'
                LEFT JOIN factory_telemetry.metric_latest ml_speed ON md_speed.id = ml_speed.metric_def_id
                LEFT JOIN factory_telemetry.metric_def md_faults ON ec.equipment_code = md_faults.equipment_code AND md_faults.metric_key = 'has_active_faults'
                LEFT JOIN factory_telemetry.metric_latest ml_faults ON md_faults.id = ml_faults.metric_def_id
                WHERE ec.enabled = true
                ORDER BY ec.name
            """)
            result = session.execute(query)
            
            equipment_status = []
            for row in result:
                # Get active faults for this equipment
                faults_query = text("""
                    SELECT fc.name
                    FROM factory_telemetry.fault_active fa
                    LEFT JOIN factory_telemetry.fault_catalog fc ON fa.equipment_code = fc.equipment_code AND fa.bit_index = fc.bit_index
                    WHERE fa.equipment_code = :equipment_code AND fa.is_active = true
                """)
                faults_result = session.execute(faults_query, {"equipment_code": row.equipment_code})
                active_faults = [fault[0] for fault in faults_result if fault[0]]
                
                equipment_status.append(EquipmentStatus(
                    equipment_code=row.equipment_code,
                    name=row.name,
                    status=row.status,
                    speed=row.speed,
                    has_faults=row.has_faults,
                    active_faults=active_faults,
                    last_update=row.last_update
                ))
            
            return equipment_status
            
    except Exception as e:
        logger.error("get_detailed_equipment_failed", error=str(e))
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/equipment", response_model=EquipmentResponse)
async def create_equipment(equipment_data: EquipmentCreate, current_user: str = Depends(get_current_user)):
    """Add new equipment to monitoring."""
    try:
        with db_manager.get_session() as session:
            # Check if equipment code already exists
            check_query = text("""
                SELECT id FROM factory_telemetry.equipment_config
                WHERE equipment_code = :equipment_code
            """)
            existing = session.execute(check_query, {"equipment_code": equipment_data.equipment_code}).fetchone()
            
            if existing:
                raise HTTPException(
                    status_code=400,
                    detail="Equipment with this code already exists"
                )
            
            # Check if PLC exists
            if equipment_data.plc_id:
                plc_query = text("SELECT id FROM factory_telemetry.plc_config WHERE id = :plc_id")
                plc_exists = session.execute(plc_query, {"plc_id": equipment_data.plc_id}).fetchone()
                if not plc_exists:
                    raise HTTPException(status_code=400, detail="PLC not found")
            
            # Insert new equipment
            insert_query = text("""
                INSERT INTO factory_telemetry.equipment_config 
                (equipment_code, name, description, plc_id, enabled, created_at, updated_at)
                VALUES (:equipment_code, :name, :description, :plc_id, :enabled, NOW(), NOW())
                RETURNING id, equipment_code, name, description, plc_id, enabled, created_at, updated_at
            """)
            
            result = session.execute(insert_query, {
                "equipment_code": equipment_data.equipment_code,
                "name": equipment_data.name,
                "description": equipment_data.description,
                "plc_id": equipment_data.plc_id,
                "enabled": equipment_data.enabled
            }).fetchone()
            
            session.commit()
            
            return EquipmentResponse(
                id=result.id,
                equipment_code=result.equipment_code,
                name=result.name,
                description=result.description,
                plc_id=result.plc_id,
                enabled=result.enabled,
                created_at=result.created_at,
                updated_at=result.updated_at
            )
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error("create_equipment_failed", error=str(e))
        raise HTTPException(status_code=500, detail=str(e))

# WebSocket endpoint
@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket endpoint for real-time data streaming."""
    await manager.connect(websocket)
    try:
        while True:
            # Keep connection alive and send periodic updates
            await asyncio.sleep(1)
            
            # Get latest equipment status
            with db_manager.get_session() as session:
                query = text("""
                    SELECT ec.equipment_code, ec.name,
                           COALESCE(ml_speed.value_real, 0) as speed,
                           CASE 
                               WHEN COALESCE(ml_faults.value_bool, false) THEN 'fault'
                               WHEN COALESCE(ml_speed.value_real, 0) > 0 THEN 'running'
                               ELSE 'stopped'
                           END as status
                    FROM factory_telemetry.equipment_config ec
                    LEFT JOIN factory_telemetry.metric_def md_speed ON ec.equipment_code = md_speed.equipment_code AND md_speed.metric_key = 'speed_real'
                    LEFT JOIN factory_telemetry.metric_latest ml_speed ON md_speed.id = ml_speed.metric_def_id
                    LEFT JOIN factory_telemetry.metric_def md_faults ON ec.equipment_code = md_faults.equipment_code AND md_faults.metric_key = 'has_active_faults'
                    LEFT JOIN factory_telemetry.metric_latest ml_faults ON md_faults.id = ml_faults.metric_def_id
                    WHERE ec.enabled = true
                """)
                result = session.execute(query)
                
                equipment_data = []
                for row in result:
                    equipment_data.append({
                        "equipment_code": row.equipment_code,
                        "name": row.name,
                        "speed": row.speed,
                        "status": row.status
                    })
                
                message = WebSocketMessage(
                    type="equipment_status",
                    payload={"equipment": equipment_data}
                )
                
                await manager.send_personal_message(message.json(), websocket)
                
    except WebSocketDisconnect:
        manager.disconnect(websocket)

# Legacy endpoints (from original API)
@app.get("/latest/{equipment_code}", response_model=List[MetricValue])
async def get_latest_metrics(
    equipment_code: str,
    metric_key: Optional[str] = Query(None, description="Filter by specific metric key")
):
    """Get latest metric values for an equipment."""
    try:
        with db_manager.get_session() as session:
            if metric_key:
                stmt = text("""
                    SELECT md.equipment_code, md.metric_key, ml.ts as timestamp,
                           ml.value_bool, ml.value_int, ml.value_real, ml.value_text, ml.value_json,
                           md.value_type, md.unit
                    FROM factory_telemetry.metric_def md
                    JOIN factory_telemetry.metric_latest ml ON ml.metric_def_id = md.id
                    WHERE md.equipment_code = :equipment_code
                      AND md.metric_key = :metric_key
                """)
                result = session.execute(stmt, {
                    "equipment_code": equipment_code,
                    "metric_key": metric_key,
                })
            else:
                stmt = text("""
                    SELECT md.equipment_code, md.metric_key, ml.ts as timestamp,
                           ml.value_bool, ml.value_int, ml.value_real, ml.value_text, ml.value_json,
                           md.value_type, md.unit
                    FROM factory_telemetry.metric_def md
                    JOIN factory_telemetry.metric_latest ml ON ml.metric_def_id = md.id
                    WHERE md.equipment_code = :equipment_code
                    ORDER BY md.metric_key
                """)
                result = session.execute(stmt, {"equipment_code": equipment_code})

            metrics = []
            for row in result:
                # Determine actual value from type
                if row.value_type == "BOOL":
                    value = row.value_bool
                elif row.value_type == "INT":
                    value = row.value_int
                elif row.value_type == "REAL":
                    value = row.value_real
                elif row.value_type == "TEXT":
                    value = row.value_text
                elif row.value_type == "JSON":
                    value = row.value_json
                else:
                    value = None

                metrics.append(MetricValue(
                    equipment_code=row.equipment_code,
                    metric_key=row.metric_key,
                    timestamp=row.timestamp,
                    value=value,
                    value_type=row.value_type,
                    unit=row.unit,
                ))

            if not metrics:
                raise HTTPException(
                    status_code=404,
                    detail=f"No metrics found for equipment: {equipment_code}"
                )

            return metrics

    except HTTPException:
        raise
    except Exception as e:
        logger.error("get_latest_metrics_failed", error=str(e))
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/faults/active/{equipment_code}", response_model=List[ActiveFault])
async def get_active_faults(equipment_code: str):
    """Get active faults for an equipment."""
    try:
        with db_manager.get_session() as session:
            stmt = text("""
                SELECT fa.equipment_code, fa.bit_index, fa.ts as timestamp, fa.is_active,
                       fc.name, fc.description, fc.marker
                FROM factory_telemetry.fault_active fa
                LEFT JOIN factory_telemetry.fault_catalog fc
                  ON fc.equipment_code = fa.equipment_code AND fc.bit_index = fa.bit_index
                WHERE fa.equipment_code = :equipment_code
                  AND fa.is_active = true
                ORDER BY fa.bit_index
            """)

            result = session.execute(stmt, {"equipment_code": equipment_code})

            faults = []
            for row in result:
                faults.append(ActiveFault(
                    equipment_code=row.equipment_code,
                    bit_index=row.bit_index,
                    name=row.name or f"Fault {row.bit_index}",
                    description=row.description,
                    marker=row.marker or "INTERNAL",
                    timestamp=row.timestamp,
                    is_active=row.is_active,
                ))

            return faults

    except Exception as e:
        logger.error("get_active_faults_failed", error=str(e))
        raise HTTPException(status_code=500, detail=str(e))

def run_api():
    """Run the FastAPI server."""
    uvicorn.run(
        app,
        host=settings.api_host,
        port=settings.api_port,
        log_level=settings.log_level.lower(),
    )

if __name__ == "__main__":
    run_api()
