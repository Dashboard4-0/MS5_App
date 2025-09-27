"""FastAPI endpoints for read-only telemetry access."""

from datetime import datetime
from typing import Any, Dict, List, Optional

import structlog
import uvicorn
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import PlainTextResponse
from prometheus_client import generate_latest
from pydantic import BaseModel
from sqlalchemy import text

from .config import settings
from .db import db_manager

logger = structlog.get_logger()

# FastAPI app
app = FastAPI(
    title="PLC Telemetry API",
    description="Read-only API for factory telemetry data",
    version="1.0.0",
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["GET"],
    allow_headers=["*"],
)


# Response models
class MetricValue(BaseModel):
    """Single metric value response."""
    equipment_code: str
    metric_key: str
    timestamp: datetime
    value: Any
    value_type: str
    unit: Optional[str]


class ActiveFault(BaseModel):
    """Active fault response."""
    equipment_code: str
    bit_index: int
    name: str
    description: Optional[str]
    marker: str
    timestamp: datetime
    is_active: bool


class HealthStatus(BaseModel):
    """Health check response."""
    status: str
    database: str
    timestamp: datetime


# Endpoints
@app.on_event("startup")
async def startup_event():
    """Initialize database connection on startup."""
    try:
        db_manager.connect()
        logger.info("api_database_connected")
    except Exception as e:
        logger.error("api_database_connection_failed", error=str(e))
        raise


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


@app.get("/metrics")
async def prometheus_metrics():
    """Prometheus metrics endpoint."""
    return PlainTextResponse(generate_latest())


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


@app.get("/history/{equipment_code}/{metric_key}")
async def get_metric_history(
    equipment_code: str,
    metric_key: str,
    hours: int = Query(1, ge=1, le=24, description="Hours of history to retrieve")
):
    """Get historical values for a specific metric."""
    try:
        with db_manager.get_session() as session:
            stmt = text("""
                SELECT mh.ts as timestamp,
                       mh.value_bool, mh.value_int, mh.value_real, mh.value_text, mh.value_json,
                       md.value_type
                FROM factory_telemetry.metric_def md
                JOIN factory_telemetry.metric_hist mh ON mh.metric_def_id = md.id
                WHERE md.equipment_code = :equipment_code
                  AND md.metric_key = :metric_key
                  AND mh.ts >= NOW() - INTERVAL ':hours hours'
                ORDER BY mh.ts DESC
                LIMIT 3600
            """)

            result = session.execute(stmt, {
                "equipment_code": equipment_code,
                "metric_key": metric_key,
                "hours": hours,
            })

            history = []
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

                history.append({
                    "timestamp": row.timestamp,
                    "value": value,
                })

            if not history:
                raise HTTPException(
                    status_code=404,
                    detail=f"No history found for {equipment_code}.{metric_key}"
                )

            return history

    except HTTPException:
        raise
    except Exception as e:
        logger.error("get_metric_history_failed", error=str(e))
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/context/{equipment_code}")
async def update_context(
    equipment_code: str,
    operator: Optional[str] = None,
    shift: Optional[str] = None,
    planned_stop: Optional[bool] = None,
    stop_reason: Optional[str] = None
):
    """Update context information for equipment (operator, shift, planned stop)."""
    try:
        with db_manager.get_session() as session:
            # Check if context exists
            check_stmt = text("""
                SELECT equipment_code FROM factory_telemetry.context
                WHERE equipment_code = :equipment_code
            """)
            exists = session.execute(check_stmt, {"equipment_code": equipment_code}).first()

            if exists:
                # Update existing
                update_parts = []
                params = {"equipment_code": equipment_code}

                if operator is not None:
                    update_parts.append("current_operator = :operator")
                    params["operator"] = operator

                if shift is not None:
                    update_parts.append("current_shift = :shift")
                    params["shift"] = shift

                if planned_stop is not None:
                    update_parts.append("planned_stop = :planned_stop")
                    params["planned_stop"] = planned_stop

                if stop_reason is not None:
                    update_parts.append("planned_stop_reason = :stop_reason")
                    params["stop_reason"] = stop_reason

                update_parts.append("updated_at = NOW()")

                update_stmt = text(f"""
                    UPDATE factory_telemetry.context
                    SET {', '.join(update_parts)}
                    WHERE equipment_code = :equipment_code
                """)
                session.execute(update_stmt, params)
            else:
                # Insert new
                insert_stmt = text("""
                    INSERT INTO factory_telemetry.context
                    (equipment_code, current_operator, current_shift, planned_stop, planned_stop_reason, updated_at)
                    VALUES (:equipment_code, :operator, :shift, :planned_stop, :stop_reason, NOW())
                """)
                session.execute(insert_stmt, {
                    "equipment_code": equipment_code,
                    "operator": operator or "",
                    "shift": shift or "",
                    "planned_stop": planned_stop or False,
                    "stop_reason": stop_reason or "",
                })

            session.commit()

            return {"status": "success", "equipment_code": equipment_code}

    except Exception as e:
        logger.error("update_context_failed", error=str(e))
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/equipment")
async def list_equipment():
    """List all configured equipment."""
    try:
        with db_manager.get_session() as session:
            stmt = text("""
                SELECT DISTINCT equipment_code
                FROM factory_telemetry.metric_def
                ORDER BY equipment_code
            """)

            result = session.execute(stmt)
            equipment = [row.equipment_code for row in result]

            return {"equipment": equipment}

    except Exception as e:
        logger.error("list_equipment_failed", error=str(e))
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