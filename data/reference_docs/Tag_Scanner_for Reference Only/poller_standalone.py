"""Standalone poller using SQLite database."""

import asyncio
import json
import os
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Dict, Optional

import structlog

# Import SQLite manager instead of PostgreSQL
from .bagger1_mapper import Bagger1Mapper
from .basket_loader_mapper import BasketLoader1Mapper
from .bindings_repo import BindingsRepository
from .csv_parsers import RSLogix5000Parser, SLCTagParser
from .db_sqlite import SQLiteManager
from .faults_catalog import FaultCatalogManager, FaultCatalogParser
from .plc_clients import PLCClientFactory
from .transforms import FaultEdgeDetector, MetricTransformer

# Configure logging
structlog.configure(
    processors=[
        structlog.stdlib.filter_by_level,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.UnicodeDecoder(),
        structlog.dev.ConsoleRenderer(),
    ],
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger()


class StandalonePoller:
    """Standalone telemetry poller using SQLite."""

    def __init__(self, db_path: str = "telemetry.db", data_dir: str = "data"):
        """Initialize standalone poller."""
        self.db_path = db_path
        self.data_dir = Path(data_dir)
        self.running = False
        self.db_manager = SQLiteManager(db_path)

        # PLC clients
        self.bagger_client = None
        self.basket_loader_client = None
        self.bagger_mapper = None
        self.basket_loader_mapper = None
        self.transformer = None
        self.fault_detector = FaultEdgeDetector()
        self.last_bagger_product = None

        # Configuration from environment or defaults
        self.plc_bagger_ip = os.getenv("PLC_BAGGER1_IP", "16.191.1.131")
        self.plc_basketloader_ip = os.getenv("PLC_BASKETLOADER1_IP", "16.191.1.140")
        self.poll_interval = float(os.getenv("POLL_INTERVAL_S", "1"))
        self.equipment_code_bagger = os.getenv("EQUIPMENT_CODE_BAGGER1", "BP01.PACK.BAG1")
        self.equipment_code_basketloader = os.getenv("EQUIPMENT_CODE_BASKETLOADER1", "BP01.PACK.BAG1.BL")

    async def initialize(self) -> None:
        """Initialize all components."""
        try:
            logger.info("initializing_standalone_poller")

            # Connect to SQLite database
            self.db_manager.connect()
            self.db_manager.execute_migrations()

            # Bootstrap metric definitions using SQLite connection
            conn = self.db_manager.get_session()
            self._bootstrap_metrics(conn)

            # Load fault catalog
            fault_catalog = self._load_fault_catalog(conn)

            # Initialize transformer with fault catalog
            self.transformer = MetricTransformer(fault_catalog)

            # Initialize PLC clients
            self.bagger_client = PLCClientFactory.create_logix_client(
                self.plc_bagger_ip,
                "Bagger 1"
            )
            self.bagger_client.connect()

            self.basket_loader_client = PLCClientFactory.create_slc_client(
                self.plc_basketloader_ip,
                "Basket Loader 1"
            )
            self.basket_loader_client.connect()

            # Initialize mappers
            self.bagger_mapper = Bagger1Mapper(self.bagger_client)

            # Parse SLC tags if available
            slc_csv_path = self.data_dir / "KM2566MC1_06_03_15.CSV"
            slc_parser = None
            if slc_csv_path.exists():
                slc_parser = SLCTagParser(slc_csv_path)

            self.basket_loader_mapper = BasketLoader1Mapper(
                self.basket_loader_client,
                slc_parser
            )

            logger.info("standalone_poller_initialized")

        except Exception as e:
            logger.error("initialization_failed", error=str(e))
            raise

    def _bootstrap_metrics(self, conn) -> None:
        """Bootstrap metric definitions in SQLite."""
        try:
            cursor = conn.cursor()

            # Define metrics for both equipment
            metric_keys = [
                "running_status", "speed_real", "current_product", "active_alarms",
                "internal_fault", "upstream_fault", "downstream_fault",
                "planned_stop", "stop_reason", "product_count",
                "availability", "oee", "current_operator", "current_shift"
            ]

            metric_types = {
                "running_status": "BOOL", "speed_real": "REAL", "current_product": "INT",
                "active_alarms": "JSON", "internal_fault": "BOOL", "upstream_fault": "BOOL",
                "downstream_fault": "BOOL", "planned_stop": "BOOL", "stop_reason": "TEXT",
                "product_count": "INT", "availability": "REAL", "oee": "REAL",
                "current_operator": "TEXT", "current_shift": "TEXT"
            }

            for equipment_code in [self.equipment_code_bagger, self.equipment_code_basketloader]:
                for metric_key in metric_keys:
                    metric_id = str(uuid.uuid4())
                    cursor.execute("""
                        INSERT OR IGNORE INTO metric_def
                        (id, equipment_code, metric_key, value_type, unit, description)
                        VALUES (?, ?, ?, ?, ?, ?)
                    """, (
                        metric_id,
                        equipment_code,
                        metric_key,
                        metric_types[metric_key],
                        None,
                        f"{metric_key} for {equipment_code}"
                    ))

            conn.commit()
            logger.info("metrics_bootstrapped")

        except Exception as e:
            logger.error("metrics_bootstrap_failed", error=str(e))
            raise

    def _load_fault_catalog(self, conn) -> Dict:
        """Load fault catalog from CSV."""
        try:
            fault_csv_path = self.data_dir / "Bagger 1 Fault Messages.csv"
            if not fault_csv_path.exists():
                logger.warning("fault_catalog_not_found", path=str(fault_csv_path))
                return {}

            parser = FaultCatalogParser(fault_csv_path, self.equipment_code_bagger)
            faults = parser.parse()

            # Store in database
            cursor = conn.cursor()
            for fault in faults:
                cursor.execute("""
                    INSERT OR REPLACE INTO fault_catalog
                    (id, equipment_code, bit_index, name, description, marker)
                    VALUES (?, ?, ?, ?, ?, ?)
                """, (
                    str(uuid.uuid4()),
                    self.equipment_code_bagger,
                    fault["bit_index"],
                    fault["name"],
                    fault["description"],
                    fault["marker"]
                ))

            conn.commit()

            # Return as dict for transformer
            return {
                fault["bit_index"]: fault
                for fault in faults
            }

        except Exception as e:
            logger.error("fault_catalog_load_failed", error=str(e))
            return {}

    async def run(self) -> None:
        """Run main polling loop."""
        self.running = True
        await self.initialize()

        logger.info(
            "starting_poll_loop",
            interval_s=self.poll_interval,
        )

        while self.running:
            cycle_start = time.time()

            try:
                await self._poll_cycle()
            except Exception as e:
                logger.error("poll_cycle_error", error=str(e))

            # Calculate sleep time to maintain polling rate
            cycle_duration = time.time() - cycle_start
            sleep_time = max(0, self.poll_interval - cycle_duration)

            if sleep_time > 0:
                await asyncio.sleep(sleep_time)
            else:
                logger.warning(
                    "poll_cycle_slow",
                    duration=cycle_duration,
                    target=self.poll_interval,
                )

    async def _poll_cycle(self) -> None:
        """Execute single polling cycle."""
        ts = datetime.utcnow()
        conn = self.db_manager.get_session()

        try:
            # Get context data
            context_bagger = self._get_context(conn, self.equipment_code_bagger)
            context_basket = self._get_context(conn, self.equipment_code_basketloader)

            # Poll Bagger 1
            bagger_metrics = await self._poll_bagger(context_bagger)
            if bagger_metrics:
                self.last_bagger_product = bagger_metrics.get("current_product")
                await self._store_metrics(
                    conn,
                    self.equipment_code_bagger,
                    bagger_metrics,
                    ts
                )

            # Poll Basket Loader 1
            basket_metrics = await self._poll_basket_loader(
                context_basket,
                self.last_bagger_product
            )
            if basket_metrics:
                await self._store_metrics(
                    conn,
                    self.equipment_code_basketloader,
                    basket_metrics,
                    ts
                )

            conn.commit()

        except Exception as e:
            logger.error("poll_cycle_failed", error=str(e))
            conn.rollback()

    async def _poll_bagger(self, context_data: Dict) -> Optional[Dict]:
        """Poll Bagger 1 PLC."""
        try:
            # Read PLC tags
            raw_data = self.bagger_mapper.read_all_tags()

            # Transform to metrics
            metrics = self.transformer.transform_bagger_metrics(raw_data, context_data)

            # Detect fault edges
            fault_bits = raw_data["processed"].get("fault_bits", [False] * 64)
            edges = self.fault_detector.detect_edges(
                self.equipment_code_bagger,
                fault_bits
            )

            # Process fault edges
            if edges:
                await self._process_fault_edges(
                    self.equipment_code_bagger,
                    edges
                )

            return metrics

        except Exception as e:
            logger.error("bagger_poll_failed", error=str(e))
            return None

    async def _poll_basket_loader(
        self,
        context_data: Dict,
        parent_product: Optional[int]
    ) -> Optional[Dict]:
        """Poll Basket Loader 1 PLC."""
        try:
            # Read PLC tags
            raw_data = self.basket_loader_mapper.read_all_tags()

            # Transform to metrics
            metrics = self.transformer.transform_basket_loader_metrics(
                raw_data,
                context_data,
                parent_product
            )

            return metrics

        except Exception as e:
            logger.error("basket_loader_poll_failed", error=str(e))
            return None

    async def _store_metrics(
        self,
        conn,
        equipment_code: str,
        metrics: Dict,
        ts: datetime
    ) -> None:
        """Store metrics in SQLite database."""
        try:
            cursor = conn.cursor()

            # Get metric definitions
            cursor.execute("""
                SELECT id, metric_key, value_type
                FROM metric_def
                WHERE equipment_code = ?
            """, (equipment_code,))

            for row in cursor.fetchall():
                metric_id = row[0]
                metric_key = row[1]
                value_type = row[2]

                if metric_key in metrics:
                    value = metrics[metric_key]

                    # Convert list to JSON for active_alarms
                    if metric_key == "active_alarms" and isinstance(value, list):
                        value = json.dumps(value)

                    # Store in database
                    if value is not None:
                        self.db_manager.upsert_metric_latest(
                            conn,
                            metric_id,
                            ts,
                            value,
                            value_type
                        )
                        self.db_manager.insert_metric_hist(
                            conn,
                            metric_id,
                            ts,
                            value,
                            value_type
                        )

        except Exception as e:
            logger.error(
                "metrics_storage_failed",
                equipment_code=equipment_code,
                error=str(e),
            )
            raise

    async def _process_fault_edges(
        self,
        equipment_code: str,
        edges: list
    ) -> None:
        """Process fault edge transitions."""
        conn = self.db_manager.get_session()

        for edge in edges:
            self.db_manager.upsert_fault_active(
                conn,
                equipment_code,
                edge["bit_index"],
                edge["timestamp"],
                edge["is_active"]
            )

            self.db_manager.manage_fault_event(
                conn,
                equipment_code,
                edge["bit_index"],
                edge["timestamp"],
                edge["is_active"],
                edge["edge_type"] == "falling"
            )

    def _get_context(self, conn, equipment_code: str) -> Dict:
        """Get context data for equipment."""
        cursor = conn.cursor()
        cursor.execute("""
            SELECT current_operator, current_shift, planned_stop, planned_stop_reason
            FROM context
            WHERE equipment_code = ?
        """, (equipment_code,))

        row = cursor.fetchone()
        if row:
            return {
                "current_operator": row[0],
                "current_shift": row[1],
                "planned_stop": bool(row[2]),
                "planned_stop_reason": row[3],
            }

        return {
            "current_operator": "",
            "current_shift": "",
            "planned_stop": False,
            "planned_stop_reason": "",
        }

    async def shutdown(self) -> None:
        """Gracefully shutdown the poller."""
        logger.info("shutting_down_poller")
        self.running = False

        if self.bagger_client:
            self.bagger_client.disconnect()

        if self.basket_loader_client:
            self.basket_loader_client.disconnect()

        if self.db_manager:
            self.db_manager.close()


# Required import
import uuid