"""Database models and connection management."""

import uuid
from datetime import datetime
from typing import Any, Dict, List, Optional

import structlog
from sqlalchemy import (
    JSON,
    BigInteger,
    Boolean,
    CheckConstraint,
    Column,
    DateTime,
    Double,
    ForeignKey,
    Index,
    Integer,
    MetaData,
    String,
    Table,
    Text,
    UniqueConstraint,
    create_engine,
    text,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.engine import Engine
from sqlalchemy.orm import Session, sessionmaker
from tenacity import retry, stop_after_attempt, wait_exponential

from .config import settings

logger = structlog.get_logger()

# Define metadata
metadata = MetaData(schema="factory_telemetry")

# Tables
metric_def = Table(
    "metric_def",
    metadata,
    Column("id", UUID(as_uuid=True), primary_key=True, default=uuid.uuid4),
    Column("equipment_code", Text, nullable=False),
    Column("metric_key", Text, nullable=False),
    Column("value_type", Text, nullable=False),
    Column("unit", Text, nullable=True),
    Column("description", Text, nullable=False),
    CheckConstraint("value_type IN ('BOOL','INT','REAL','TEXT','JSON')", name="ck_value_type"),
    UniqueConstraint("equipment_code", "metric_key", name="uq_equipment_metric"),
)

metric_binding = Table(
    "metric_binding",
    metadata,
    Column("id", UUID(as_uuid=True), primary_key=True, default=uuid.uuid4),
    Column("metric_def_id", UUID(as_uuid=True), ForeignKey("metric_def.id", ondelete="CASCADE"), nullable=False),
    Column("plc_kind", Text, nullable=False),
    Column("address", Text, nullable=False),
    Column("bit_index", Integer, nullable=True),
    Column("parse_hint", Text, nullable=True),
    Column("transform_sql", Text, nullable=True),
    CheckConstraint("plc_kind IN ('LOGIX','SLC','COMPUTED')", name="ck_plc_kind"),
)

metric_latest = Table(
    "metric_latest",
    metadata,
    Column("metric_def_id", UUID(as_uuid=True), ForeignKey("metric_def.id", ondelete="CASCADE"), primary_key=True),
    Column("ts", DateTime(timezone=True), nullable=False),
    Column("value_bool", Boolean, nullable=True),
    Column("value_int", BigInteger, nullable=True),
    Column("value_real", Double, nullable=True),
    Column("value_text", Text, nullable=True),
    Column("value_json", JSON, nullable=True),
)

metric_hist = Table(
    "metric_hist",
    metadata,
    Column("id", BigInteger, primary_key=True, autoincrement=True),
    Column("metric_def_id", UUID(as_uuid=True), ForeignKey("metric_def.id", ondelete="CASCADE"), nullable=False),
    Column("ts", DateTime(timezone=True), nullable=False),
    Column("value_bool", Boolean, nullable=True),
    Column("value_int", BigInteger, nullable=True),
    Column("value_real", Double, nullable=True),
    Column("value_text", Text, nullable=True),
    Column("value_json", JSON, nullable=True),
    Index("ix_metric_hist_def_ts", "metric_def_id", "ts"),
)

fault_catalog = Table(
    "fault_catalog",
    metadata,
    Column("id", UUID(as_uuid=True), primary_key=True, default=uuid.uuid4),
    Column("equipment_code", Text, nullable=False),
    Column("bit_index", Integer, nullable=False),
    Column("name", Text, nullable=False),
    Column("description", Text, nullable=True),
    Column("marker", Text, nullable=False),
    CheckConstraint("bit_index BETWEEN 0 AND 63", name="ck_bit_index"),
    CheckConstraint("marker IN ('INTERNAL','UPSTREAM','DOWNSTREAM')", name="ck_marker"),
    UniqueConstraint("equipment_code", "bit_index", name="uq_equipment_bit"),
)

fault_active = Table(
    "fault_active",
    metadata,
    Column("equipment_code", Text, primary_key=True),
    Column("bit_index", Integer, primary_key=True),
    Column("ts", DateTime(timezone=True), nullable=False),
    Column("is_active", Boolean, nullable=False),
)

fault_event = Table(
    "fault_event",
    metadata,
    Column("id", BigInteger, primary_key=True, autoincrement=True),
    Column("equipment_code", Text, nullable=False),
    Column("bit_index", Integer, nullable=False),
    Column("ts_on", DateTime(timezone=True), nullable=False),
    Column("ts_off", DateTime(timezone=True), nullable=True),
)

context = Table(
    "context",
    metadata,
    Column("equipment_code", Text, primary_key=True),
    Column("current_operator", Text, nullable=True),
    Column("current_shift", Text, nullable=True),
    Column("planned_stop", Boolean, nullable=False, default=False),
    Column("planned_stop_reason", Text, nullable=True),
    Column("updated_at", DateTime(timezone=True), nullable=False, default=datetime.utcnow),
)


class DatabaseManager:
    """Manage database connections and operations."""

    def __init__(self):
        """Initialize database manager."""
        self.engine: Optional[Engine] = None
        self.session_factory: Optional[sessionmaker] = None

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=2, max=10),
    )
    def connect(self) -> None:
        """Connect to database with retry logic."""
        try:
            self.engine = create_engine(
                settings.db_url_sync,
                pool_size=10,
                max_overflow=20,
                pool_pre_ping=True,
                pool_recycle=3600,
            )
            self.session_factory = sessionmaker(bind=self.engine)

            # Test connection
            with self.engine.connect() as conn:
                conn.execute(text("SELECT 1"))

            logger.info("database_connected", url=settings.db_url_sync.split("@")[-1])
        except Exception as e:
            logger.error("database_connection_failed", error=str(e))
            raise

    def execute_migrations(self) -> None:
        """Execute database migrations."""
        try:
            migration_path = settings.bagger_tags_csv.parent.parent / "migrations" / "001_init_telemetry.sql"

            with open(migration_path, "r") as f:
                migration_sql = f.read()

            with self.engine.begin() as conn:
                # Split and execute statements
                for statement in migration_sql.split(";"):
                    if statement.strip():
                        conn.execute(text(statement))

            logger.info("migrations_executed")
        except Exception as e:
            logger.error("migration_failed", error=str(e))
            raise

    def get_session(self) -> Session:
        """Get a database session."""
        if not self.session_factory:
            raise RuntimeError("Database not connected")
        return self.session_factory()

    def upsert_metric_latest(
        self,
        session: Session,
        metric_def_id: uuid.UUID,
        ts: datetime,
        value: Any,
        value_type: str,
    ) -> None:
        """Upsert latest metric value."""
        value_dict = self._prepare_value_dict(value, value_type)
        value_dict["metric_def_id"] = metric_def_id
        value_dict["ts"] = ts

        stmt = text("""
            INSERT INTO factory_telemetry.metric_latest (metric_def_id, ts, value_bool, value_int, value_real, value_text, value_json)
            VALUES (:metric_def_id, :ts, :value_bool, :value_int, :value_real, :value_text, :value_json)
            ON CONFLICT (metric_def_id) DO UPDATE SET
                ts = EXCLUDED.ts,
                value_bool = EXCLUDED.value_bool,
                value_int = EXCLUDED.value_int,
                value_real = EXCLUDED.value_real,
                value_text = EXCLUDED.value_text,
                value_json = EXCLUDED.value_json
        """)

        session.execute(stmt, value_dict)

    def insert_metric_hist(
        self,
        session: Session,
        metric_def_id: uuid.UUID,
        ts: datetime,
        value: Any,
        value_type: str,
    ) -> None:
        """Insert historical metric value."""
        value_dict = self._prepare_value_dict(value, value_type)
        value_dict["metric_def_id"] = metric_def_id
        value_dict["ts"] = ts

        stmt = text("""
            INSERT INTO factory_telemetry.metric_hist (metric_def_id, ts, value_bool, value_int, value_real, value_text, value_json)
            VALUES (:metric_def_id, :ts, :value_bool, :value_int, :value_real, :value_text, :value_json)
        """)

        session.execute(stmt, value_dict)

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
            value_dict["value_bool"] = value
        elif value_type == "INT":
            value_dict["value_int"] = value
        elif value_type == "REAL":
            value_dict["value_real"] = value
        elif value_type == "TEXT":
            value_dict["value_text"] = value
        elif value_type == "JSON":
            value_dict["value_json"] = value

        return value_dict

    def get_metric_definitions(self, session: Session, equipment_code: str) -> List[Dict[str, Any]]:
        """Get metric definitions for an equipment."""
        stmt = text("""
            SELECT md.id, md.metric_key, md.value_type, md.unit, md.description,
                   mb.plc_kind, mb.address, mb.bit_index, mb.parse_hint, mb.transform_sql
            FROM factory_telemetry.metric_def md
            LEFT JOIN factory_telemetry.metric_binding mb ON mb.metric_def_id = md.id
            WHERE md.equipment_code = :equipment_code
        """)

        result = session.execute(stmt, {"equipment_code": equipment_code})
        return [dict(row._mapping) for row in result]

    def upsert_fault_active(
        self,
        session: Session,
        equipment_code: str,
        bit_index: int,
        ts: datetime,
        is_active: bool,
    ) -> None:
        """Upsert active fault status."""
        stmt = text("""
            INSERT INTO factory_telemetry.fault_active (equipment_code, bit_index, ts, is_active)
            VALUES (:equipment_code, :bit_index, :ts, :is_active)
            ON CONFLICT (equipment_code, bit_index) DO UPDATE SET
                ts = EXCLUDED.ts,
                is_active = EXCLUDED.is_active
        """)

        session.execute(stmt, {
            "equipment_code": equipment_code,
            "bit_index": bit_index,
            "ts": ts,
            "is_active": is_active,
        })

    def manage_fault_event(
        self,
        session: Session,
        equipment_code: str,
        bit_index: int,
        ts: datetime,
        is_active: bool,
        prev_active: bool,
    ) -> None:
        """Manage fault event edges."""
        if not prev_active and is_active:
            # Rising edge - new fault
            stmt = text("""
                INSERT INTO factory_telemetry.fault_event (equipment_code, bit_index, ts_on, duration_s)
                VALUES (:equipment_code, :bit_index, :ts_on, NULL)
            """)
            session.execute(stmt, {
                "equipment_code": equipment_code,
                "bit_index": bit_index,
                "ts_on": ts,
            })
        elif prev_active and not is_active:
            # Falling edge - fault cleared
            stmt = text("""
                UPDATE factory_telemetry.fault_event
                SET ts_off = :ts_off,
                    duration_s = EXTRACT(EPOCH FROM :ts_off - ts_on)
                WHERE equipment_code = :equipment_code
                  AND bit_index = :bit_index
                  AND ts_off IS NULL
                ORDER BY ts_on DESC
                LIMIT 1
            """)
            session.execute(stmt, {
                "equipment_code": equipment_code,
                "bit_index": bit_index,
                "ts_off": ts,
            })


# Singleton instance
db_manager = DatabaseManager()