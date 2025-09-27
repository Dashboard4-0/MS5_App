"""FastAPI endpoints for standalone SQLite version."""

import json
import os
import sqlite3
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import PlainTextResponse
from pydantic import BaseModel

# Get database path from environment or use default
DB_PATH = os.getenv("DB_PATH", "telemetry.db")

# FastAPI app
app = FastAPI(
    title="PLC Telemetry API - Standalone",
    description="Read-only API for factory telemetry data (SQLite version)",
    version="1.0.0",
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)


# Response models
class MetricValue(BaseModel):
    """Single metric value response."""
    equipment_code: str
    metric_key: str
    timestamp: str
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
    timestamp: str
    is_active: bool


class HealthStatus(BaseModel):
    """Health check response."""
    status: str
    database: str
    timestamp: str
    db_size_mb: float


def get_db_connection():
    """Get SQLite database connection."""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


@app.get("/health", response_model=HealthStatus)
async def health_check():
    """Health check endpoint."""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM metric_def")

        # Get database size
        db_size = Path(DB_PATH).stat().st_size / (1024 * 1024) if Path(DB_PATH).exists() else 0

        conn.close()

        return HealthStatus(
            status="healthy",
            database="connected",
            timestamp=datetime.utcnow().isoformat(),
            db_size_mb=round(db_size, 2)
        )
    except Exception as e:
        return HealthStatus(
            status="unhealthy",
            database="disconnected",
            timestamp=datetime.utcnow().isoformat(),
            db_size_mb=0
        )


@app.get("/latest/{equipment_code}", response_model=List[MetricValue])
async def get_latest_metrics(
    equipment_code: str,
    metric_key: Optional[str] = Query(None, description="Filter by specific metric key")
):
    """Get latest metric values for an equipment."""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        if metric_key:
            cursor.execute("""
                SELECT md.equipment_code, md.metric_key, ml.ts as timestamp,
                       ml.value_bool, ml.value_int, ml.value_real, ml.value_text, ml.value_json,
                       md.value_type, md.unit
                FROM metric_def md
                JOIN metric_latest ml ON ml.metric_def_id = md.id
                WHERE md.equipment_code = ? AND md.metric_key = ?
            """, (equipment_code, metric_key))
        else:
            cursor.execute("""
                SELECT md.equipment_code, md.metric_key, ml.ts as timestamp,
                       ml.value_bool, ml.value_int, ml.value_real, ml.value_text, ml.value_json,
                       md.value_type, md.unit
                FROM metric_def md
                JOIN metric_latest ml ON ml.metric_def_id = md.id
                WHERE md.equipment_code = ?
                ORDER BY md.metric_key
            """, (equipment_code,))

        metrics = []
        for row in cursor.fetchall():
            # Determine actual value from type
            if row["value_type"] == "BOOL":
                value = bool(row["value_bool"])
            elif row["value_type"] == "INT":
                value = row["value_int"]
            elif row["value_type"] == "REAL":
                value = row["value_real"]
            elif row["value_type"] == "TEXT":
                value = row["value_text"]
            elif row["value_type"] == "JSON":
                value = json.loads(row["value_json"]) if row["value_json"] else None
            else:
                value = None

            metrics.append(MetricValue(
                equipment_code=row["equipment_code"],
                metric_key=row["metric_key"],
                timestamp=row["timestamp"],
                value=value,
                value_type=row["value_type"],
                unit=row["unit"],
            ))

        conn.close()

        if not metrics:
            raise HTTPException(
                status_code=404,
                detail=f"No metrics found for equipment: {equipment_code}"
            )

        return metrics

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/faults/active/{equipment_code}", response_model=List[ActiveFault])
async def get_active_faults(equipment_code: str):
    """Get active faults for an equipment."""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute("""
            SELECT fa.equipment_code, fa.bit_index, fa.ts as timestamp, fa.is_active,
                   fc.name, fc.description, fc.marker
            FROM fault_active fa
            LEFT JOIN fault_catalog fc
              ON fc.equipment_code = fa.equipment_code AND fc.bit_index = fa.bit_index
            WHERE fa.equipment_code = ? AND fa.is_active = 1
            ORDER BY fa.bit_index
        """, (equipment_code,))

        faults = []
        for row in cursor.fetchall():
            faults.append(ActiveFault(
                equipment_code=row["equipment_code"],
                bit_index=row["bit_index"],
                name=row["name"] or f"Fault {row['bit_index']}",
                description=row["description"],
                marker=row["marker"] or "INTERNAL",
                timestamp=row["timestamp"],
                is_active=bool(row["is_active"]),
            ))

        conn.close()
        return faults

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/history/{equipment_code}/{metric_key}")
async def get_metric_history(
    equipment_code: str,
    metric_key: str,
    hours: int = Query(1, ge=1, le=24, description="Hours of history to retrieve")
):
    """Get historical values for a specific metric."""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Calculate timestamp threshold
        from datetime import datetime, timedelta
        threshold = (datetime.utcnow() - timedelta(hours=hours)).isoformat()

        cursor.execute("""
            SELECT mh.ts as timestamp,
                   mh.value_bool, mh.value_int, mh.value_real, mh.value_text, mh.value_json,
                   md.value_type
            FROM metric_def md
            JOIN metric_hist mh ON mh.metric_def_id = md.id
            WHERE md.equipment_code = ? AND md.metric_key = ? AND mh.ts >= ?
            ORDER BY mh.ts DESC
            LIMIT 3600
        """, (equipment_code, metric_key, threshold))

        history = []
        for row in cursor.fetchall():
            # Determine actual value from type
            if row["value_type"] == "BOOL":
                value = bool(row["value_bool"])
            elif row["value_type"] == "INT":
                value = row["value_int"]
            elif row["value_type"] == "REAL":
                value = row["value_real"]
            elif row["value_type"] == "TEXT":
                value = row["value_text"]
            elif row["value_type"] == "JSON":
                value = json.loads(row["value_json"]) if row["value_json"] else None
            else:
                value = None

            history.append({
                "timestamp": row["timestamp"],
                "value": value,
            })

        conn.close()

        if not history:
            raise HTTPException(
                status_code=404,
                detail=f"No history found for {equipment_code}.{metric_key}"
            )

        return history

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/equipment")
async def list_equipment():
    """List all configured equipment."""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        cursor.execute("""
            SELECT DISTINCT equipment_code FROM metric_def ORDER BY equipment_code
        """)

        equipment = [row[0] for row in cursor.fetchall()]

        conn.close()
        return {"equipment": equipment}

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/stats")
async def get_statistics():
    """Get database statistics."""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        stats = {}

        # Count metrics
        cursor.execute("SELECT COUNT(*) FROM metric_hist")
        stats["total_records"] = cursor.fetchone()[0]

        # Count active faults
        cursor.execute("SELECT COUNT(*) FROM fault_active WHERE is_active = 1")
        stats["active_faults"] = cursor.fetchone()[0]

        # Get date range
        cursor.execute("SELECT MIN(ts), MAX(ts) FROM metric_hist")
        row = cursor.fetchone()
        if row and row[0]:
            stats["oldest_data"] = row[0]
            stats["newest_data"] = row[1]

        # Database size
        stats["db_size_mb"] = round(Path(DB_PATH).stat().st_size / (1024 * 1024), 2)

        conn.close()
        return stats

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))