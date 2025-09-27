"""SQLite database manager for standalone deployment."""

import sqlite3
import uuid
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional

import structlog
from tenacity import retry, stop_after_attempt, wait_exponential

from .config import settings

logger = structlog.get_logger()


class SQLiteManager:
    """Manage SQLite database connections and operations."""

    def __init__(self, db_path: str = "telemetry.db"):
        """Initialize SQLite database manager."""
        self.db_path = Path(db_path)
        self.connection: Optional[sqlite3.Connection] = None

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=2, max=10),
    )
    def connect(self) -> None:
        """Connect to SQLite database."""
        try:
            # Create database directory if it doesn't exist
            self.db_path.parent.mkdir(parents=True, exist_ok=True)

            # Connect with row factory for dict-like access
            self.connection = sqlite3.connect(
                str(self.db_path),
                check_same_thread=False,
                isolation_level=None  # Autocommit mode
            )
            self.connection.row_factory = sqlite3.Row

            # Enable foreign keys
            self.connection.execute("PRAGMA foreign_keys = ON")

            # Optimize for performance
            self.connection.execute("PRAGMA journal_mode = WAL")
            self.connection.execute("PRAGMA synchronous = NORMAL")
            self.connection.execute("PRAGMA cache_size = 10000")
            self.connection.execute("PRAGMA temp_store = MEMORY")

            logger.info("sqlite_connected", path=str(self.db_path))
        except Exception as e:
            logger.error("sqlite_connection_failed", error=str(e))
            raise

    def execute_migrations(self) -> None:
        """Execute database migrations for SQLite."""
        try:
            cursor = self.connection.cursor()

            # Create schema equivalent (use prefixed table names)
            migrations = [
                # Metric definitions
                """CREATE TABLE IF NOT EXISTS metric_def (
                    id TEXT PRIMARY KEY,
                    equipment_code TEXT NOT NULL,
                    metric_key TEXT NOT NULL,
                    value_type TEXT NOT NULL CHECK (value_type IN ('BOOL','INT','REAL','TEXT','JSON')),
                    unit TEXT,
                    description TEXT NOT NULL,
                    UNIQUE (equipment_code, metric_key)
                )""",

                # Metric bindings
                """CREATE TABLE IF NOT EXISTS metric_binding (
                    id TEXT PRIMARY KEY,
                    metric_def_id TEXT NOT NULL REFERENCES metric_def(id) ON DELETE CASCADE,
                    plc_kind TEXT NOT NULL CHECK (plc_kind IN ('LOGIX','SLC','COMPUTED')),
                    address TEXT NOT NULL,
                    bit_index INTEGER,
                    parse_hint TEXT,
                    transform_sql TEXT
                )""",

                # Latest metrics
                """CREATE TABLE IF NOT EXISTS metric_latest (
                    metric_def_id TEXT PRIMARY KEY REFERENCES metric_def(id) ON DELETE CASCADE,
                    ts TIMESTAMP NOT NULL,
                    value_bool INTEGER,
                    value_int INTEGER,
                    value_real REAL,
                    value_text TEXT,
                    value_json TEXT
                )""",

                # Historical metrics
                """CREATE TABLE IF NOT EXISTS metric_hist (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    metric_def_id TEXT NOT NULL REFERENCES metric_def(id) ON DELETE CASCADE,
                    ts TIMESTAMP NOT NULL,
                    value_bool INTEGER,
                    value_int INTEGER,
                    value_real REAL,
                    value_text TEXT,
                    value_json TEXT
                )""",

                # Create index for historical data
                """CREATE INDEX IF NOT EXISTS idx_metric_hist_def_ts
                   ON metric_hist (metric_def_id, ts DESC)""",

                # Fault catalog
                """CREATE TABLE IF NOT EXISTS fault_catalog (
                    id TEXT PRIMARY KEY,
                    equipment_code TEXT NOT NULL,
                    bit_index INTEGER NOT NULL CHECK (bit_index BETWEEN 0 AND 63),
                    name TEXT NOT NULL,
                    description TEXT,
                    marker TEXT NOT NULL CHECK (marker IN ('INTERNAL','UPSTREAM','DOWNSTREAM')),
                    UNIQUE (equipment_code, bit_index)
                )""",

                # Active faults
                """CREATE TABLE IF NOT EXISTS fault_active (
                    equipment_code TEXT NOT NULL,
                    bit_index INTEGER NOT NULL,
                    ts TIMESTAMP NOT NULL,
                    is_active INTEGER NOT NULL,
                    PRIMARY KEY (equipment_code, bit_index)
                )""",

                # Fault events
                """CREATE TABLE IF NOT EXISTS fault_event (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    equipment_code TEXT NOT NULL,
                    bit_index INTEGER NOT NULL,
                    ts_on TIMESTAMP NOT NULL,
                    ts_off TIMESTAMP,
                    duration_s REAL
                )""",

                # Context
                """CREATE TABLE IF NOT EXISTS context (
                    equipment_code TEXT PRIMARY KEY,
                    current_operator TEXT,
                    current_shift TEXT,
                    planned_stop INTEGER NOT NULL DEFAULT 0,
                    planned_stop_reason TEXT,
                    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                )""",

                # Views for convenient access
                """CREATE VIEW IF NOT EXISTS v_equipment_latest AS
                SELECT md.equipment_code, md.metric_key, ml.ts,
                       COALESCE(ml.value_text,
                                CASE
                                    WHEN ml.value_bool IS NOT NULL THEN CAST(ml.value_bool AS TEXT)
                                    WHEN ml.value_int IS NOT NULL THEN CAST(ml.value_int AS TEXT)
                                    WHEN ml.value_real IS NOT NULL THEN CAST(ml.value_real AS TEXT)
                                    ELSE ml.value_json
                                END) AS value,
                       ml.value_bool, ml.value_int, ml.value_real, ml.value_json
                FROM metric_def md
                JOIN metric_latest ml ON ml.metric_def_id = md.id""",

                """CREATE VIEW IF NOT EXISTS v_faults_active AS
                SELECT f.*, c.name, c.description, c.marker
                FROM fault_active f
                LEFT JOIN fault_catalog c
                  ON c.equipment_code=f.equipment_code AND c.bit_index=f.bit_index
                WHERE f.is_active = 1"""
            ]

            for migration in migrations:
                cursor.execute(migration)

            self.connection.commit()
            logger.info("sqlite_migrations_executed")

        except Exception as e:
            logger.error("sqlite_migration_failed", error=str(e))
            raise

    def get_session(self):
        """Return connection for compatibility with PostgreSQL version."""
        return self.connection

    def upsert_metric_latest(
        self,
        session,
        metric_def_id: str,
        ts: datetime,
        value: Any,
        value_type: str,
    ) -> None:
        """Upsert latest metric value."""
        value_dict = self._prepare_value_dict(value, value_type)

        cursor = session.cursor()
        cursor.execute("""
            INSERT OR REPLACE INTO metric_latest
            (metric_def_id, ts, value_bool, value_int, value_real, value_text, value_json)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (
            metric_def_id,
            ts.isoformat(),
            value_dict["value_bool"],
            value_dict["value_int"],
            value_dict["value_real"],
            value_dict["value_text"],
            value_dict["value_json"]
        ))

    def insert_metric_hist(
        self,
        session,
        metric_def_id: str,
        ts: datetime,
        value: Any,
        value_type: str,
    ) -> None:
        """Insert historical metric value."""
        value_dict = self._prepare_value_dict(value, value_type)

        cursor = session.cursor()
        cursor.execute("""
            INSERT INTO metric_hist
            (metric_def_id, ts, value_bool, value_int, value_real, value_text, value_json)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (
            metric_def_id,
            ts.isoformat(),
            value_dict["value_bool"],
            value_dict["value_int"],
            value_dict["value_real"],
            value_dict["value_text"],
            value_dict["value_json"]
        ))

    def _prepare_value_dict(self, value: Any, value_type: str) -> Dict[str, Any]:
        """Prepare value dictionary for database insert."""
        value_dict = {
            "value_bool": None,
            "value_int": None,
            "value_real": None,
            "value_text": None,
            "value_json": None,
        }

        if value_type == "BOOL":
            value_dict["value_bool"] = 1 if value else 0
        elif value_type == "INT":
            value_dict["value_int"] = value
        elif value_type == "REAL":
            value_dict["value_real"] = value
        elif value_type == "TEXT":
            value_dict["value_text"] = value
        elif value_type == "JSON":
            value_dict["value_json"] = value if isinstance(value, str) else str(value)

        return value_dict

    def get_metric_definitions(self, session, equipment_code: str) -> List[Dict[str, Any]]:
        """Get metric definitions for an equipment."""
        cursor = session.cursor()
        cursor.execute("""
            SELECT md.id, md.metric_key, md.value_type, md.unit, md.description,
                   mb.plc_kind, mb.address, mb.bit_index, mb.parse_hint, mb.transform_sql
            FROM metric_def md
            LEFT JOIN metric_binding mb ON mb.metric_def_id = md.id
            WHERE md.equipment_code = ?
        """, (equipment_code,))

        return [dict(row) for row in cursor.fetchall()]

    def upsert_fault_active(
        self,
        session,
        equipment_code: str,
        bit_index: int,
        ts: datetime,
        is_active: bool,
    ) -> None:
        """Upsert active fault status."""
        cursor = session.cursor()
        cursor.execute("""
            INSERT OR REPLACE INTO fault_active
            (equipment_code, bit_index, ts, is_active)
            VALUES (?, ?, ?, ?)
        """, (equipment_code, bit_index, ts.isoformat(), 1 if is_active else 0))

    def manage_fault_event(
        self,
        session,
        equipment_code: str,
        bit_index: int,
        ts: datetime,
        is_active: bool,
        prev_active: bool,
    ) -> None:
        """Manage fault event edges."""
        cursor = session.cursor()

        if not prev_active and is_active:
            # Rising edge - new fault
            cursor.execute("""
                INSERT INTO fault_event (equipment_code, bit_index, ts_on)
                VALUES (?, ?, ?)
            """, (equipment_code, bit_index, ts.isoformat()))

        elif prev_active and not is_active:
            # Falling edge - fault cleared
            cursor.execute("""
                UPDATE fault_event
                SET ts_off = ?,
                    duration_s = (julianday(?) - julianday(ts_on)) * 86400
                WHERE equipment_code = ?
                  AND bit_index = ?
                  AND ts_off IS NULL
                ORDER BY ts_on DESC
                LIMIT 1
            """, (ts.isoformat(), ts.isoformat(), equipment_code, bit_index))

    def close(self):
        """Close database connection."""
        if self.connection:
            self.connection.close()


# Singleton instance
db_manager = SQLiteManager()