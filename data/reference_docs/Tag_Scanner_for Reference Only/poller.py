"""Main polling service with 1Hz loop."""

import asyncio
import signal
import sys
import time
from datetime import datetime
from typing import Dict, Optional

import structlog
from prometheus_client import Counter, Gauge, Histogram
from sqlalchemy import text

from .bagger1_mapper import Bagger1Mapper
from .basket_loader_mapper import BasketLoader1Mapper
from .bindings_repo import BindingsRepository
from .config import settings
from .csv_parsers import RSLogix5000Parser, SLCTagParser
from .db import db_manager
from .faults_catalog import FaultCatalogManager, FaultCatalogParser
from .plc_clients import PLCClientFactory
from .transforms import FaultEdgeDetector, MetricTransformer

# Configure structured logging
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
        structlog.processors.JSONRenderer() if settings.log_format == "json" else structlog.dev.ConsoleRenderer(),
    ],
    context_class=dict,
    logger_factory=structlog.stdlib.LoggerFactory(),
    cache_logger_on_first_use=True,
)

logger = structlog.get_logger()

# Prometheus metrics
poll_counter = Counter("plc_polls_total", "Total PLC polls", ["equipment", "status"])
poll_duration = Histogram("plc_poll_duration_seconds", "PLC poll duration", ["equipment"])
metrics_written = Counter("metrics_written_total", "Total metrics written", ["table"])
active_faults_gauge = Gauge("active_faults_count", "Number of active faults", ["equipment"])
running_status_gauge = Gauge("equipment_running", "Equipment running status", ["equipment"])


class TelemetryPoller:
    """Main telemetry polling service."""

    def __init__(self):
        """Initialize telemetry poller."""
        self.running = False
        self.bagger_client = None
        self.basket_loader_client = None
        self.bagger_mapper = None
        self.basket_loader_mapper = None
        self.transformer = None
        self.fault_detector = FaultEdgeDetector()
        self.last_bagger_product = None

    async def initialize(self) -> None:
        """Initialize all components."""
        try:
            logger.info("initializing_telemetry_poller")

            # Connect to database
            db_manager.connect()
            db_manager.execute_migrations()

            # Bootstrap metric definitions
            with db_manager.get_session() as session:
                bindings_repo = BindingsRepository(session)
                bindings_repo.bootstrap_metrics()

                # Load fault catalog
                fault_parser = FaultCatalogParser(
                    settings.bagger_faults_file,
                    settings.equipment_code_bagger1
                )
                fault_catalog_data = fault_parser.parse()

                fault_manager = FaultCatalogManager(session)
                fault_manager.upsert_fault_catalog(
                    settings.equipment_code_bagger1,
                    fault_catalog_data
                )

                # Get fault catalog for transformer
                fault_catalog = fault_manager.get_fault_catalog(settings.equipment_code_bagger1)

            # Initialize transformer with fault catalog
            self.transformer = MetricTransformer(fault_catalog)

            # Initialize PLC clients
            self.bagger_client = PLCClientFactory.create_logix_client(
                settings.plc_bagger1_ip,
                "Bagger 1"
            )
            self.bagger_client.connect()

            self.basket_loader_client = PLCClientFactory.create_slc_client(
                settings.plc_basketloader1_ip,
                "Basket Loader 1"
            )
            self.basket_loader_client.connect()

            # Initialize mappers
            self.bagger_mapper = Bagger1Mapper(self.bagger_client)

            # Parse SLC tags if available
            slc_parser = None
            if settings.basket_loader_tags_csv.exists():
                slc_parser = SLCTagParser(settings.basket_loader_tags_csv)

            self.basket_loader_mapper = BasketLoader1Mapper(
                self.basket_loader_client,
                slc_parser
            )

            logger.info("telemetry_poller_initialized")

        except Exception as e:
            logger.error("initialization_failed", error=str(e))
            raise

    async def run(self) -> None:
        """Run main polling loop."""
        self.running = True
        logger.info(
            "starting_poll_loop",
            interval_s=settings.poll_interval_s,
        )

        while self.running:
            cycle_start = time.time()

            try:
                await self._poll_cycle()
            except Exception as e:
                logger.error("poll_cycle_error", error=str(e))
                poll_counter.labels(equipment="all", status="error").inc()

            # Calculate sleep time to maintain 1Hz
            cycle_duration = time.time() - cycle_start
            sleep_time = max(0, settings.poll_interval_s - cycle_duration)

            if sleep_time > 0:
                await asyncio.sleep(sleep_time)
            else:
                logger.warning(
                    "poll_cycle_slow",
                    duration=cycle_duration,
                    target=settings.poll_interval_s,
                )

    async def _poll_cycle(self) -> None:
        """Execute single polling cycle."""
        ts = datetime.utcnow()

        # Get database session
        with db_manager.get_session() as session:
            # Get metric bindings
            bindings_repo = BindingsRepository(session)
            bagger_bindings = bindings_repo.get_metric_bindings(settings.equipment_code_bagger1)
            basket_bindings = bindings_repo.get_metric_bindings(settings.equipment_code_basketloader1)

            # Get context data
            context_bagger = self._get_context(session, settings.equipment_code_bagger1)
            context_basket = self._get_context(session, settings.equipment_code_basketloader1)

            # Poll Bagger 1
            bagger_metrics = await self._poll_bagger(context_bagger)
            if bagger_metrics:
                self.last_bagger_product = bagger_metrics.get("current_product")
                await self._store_metrics(
                    session,
                    settings.equipment_code_bagger1,
                    bagger_metrics,
                    bagger_bindings,
                    ts
                )

            # Poll Basket Loader 1
            basket_metrics = await self._poll_basket_loader(
                context_basket,
                self.last_bagger_product
            )
            if basket_metrics:
                await self._store_metrics(
                    session,
                    settings.equipment_code_basketloader1,
                    basket_metrics,
                    basket_bindings,
                    ts
                )

            session.commit()

    async def _poll_bagger(self, context_data: Dict) -> Optional[Dict]:
        """Poll Bagger 1 PLC."""
        try:
            with poll_duration.labels(equipment="bagger1").time():
                # Read PLC tags
                raw_data = self.bagger_mapper.read_all_tags()

                # Transform to metrics
                metrics = self.transformer.transform_bagger_metrics(raw_data, context_data)

                # Update Prometheus gauges
                active_faults = len(metrics.get("active_alarms", []))
                active_faults_gauge.labels(equipment="bagger1").set(active_faults)
                running_status_gauge.labels(equipment="bagger1").set(
                    1 if metrics.get("running_status") else 0
                )

                # Detect fault edges
                fault_bits = raw_data["processed"].get("fault_bits", [False] * 64)
                edges = self.fault_detector.detect_edges(
                    settings.equipment_code_bagger1,
                    fault_bits
                )

                # Process fault edges
                if edges:
                    await self._process_fault_edges(
                        settings.equipment_code_bagger1,
                        edges
                    )

                poll_counter.labels(equipment="bagger1", status="success").inc()
                return metrics

        except Exception as e:
            logger.error("bagger_poll_failed", error=str(e))
            poll_counter.labels(equipment="bagger1", status="error").inc()
            return None

    async def _poll_basket_loader(
        self,
        context_data: Dict,
        parent_product: Optional[int]
    ) -> Optional[Dict]:
        """Poll Basket Loader 1 PLC."""
        try:
            with poll_duration.labels(equipment="basketloader1").time():
                # Read PLC tags
                raw_data = self.basket_loader_mapper.read_all_tags()

                # Transform to metrics
                metrics = self.transformer.transform_basket_loader_metrics(
                    raw_data,
                    context_data,
                    parent_product
                )

                # Update Prometheus gauges
                active_faults = len(metrics.get("active_alarms", []))
                active_faults_gauge.labels(equipment="basketloader1").set(active_faults)
                running_status_gauge.labels(equipment="basketloader1").set(
                    1 if metrics.get("running_status") else 0
                )

                poll_counter.labels(equipment="basketloader1", status="success").inc()
                return metrics

        except Exception as e:
            logger.error("basket_loader_poll_failed", error=str(e))
            poll_counter.labels(equipment="basketloader1", status="error").inc()
            return None

    async def _store_metrics(
        self,
        session,
        equipment_code: str,
        metrics: Dict,
        bindings: Dict,
        ts: datetime
    ) -> None:
        """Store metrics in database."""
        try:
            # Prepare metric values
            prepared_values = self.transformer.prepare_metric_values(metrics, bindings)

            for metric_def_id, value, value_type in prepared_values:
                # Upsert to latest table
                db_manager.upsert_metric_latest(
                    session,
                    metric_def_id,
                    ts,
                    value,
                    value_type
                )

                # Insert to history table
                db_manager.insert_metric_hist(
                    session,
                    metric_def_id,
                    ts,
                    value,
                    value_type
                )

            metrics_written.labels(table="latest").inc(len(prepared_values))
            metrics_written.labels(table="history").inc(len(prepared_values))

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
        with db_manager.get_session() as session:
            for edge in edges:
                # Update fault_active table
                db_manager.upsert_fault_active(
                    session,
                    equipment_code,
                    edge["bit_index"],
                    edge["timestamp"],
                    edge["is_active"]
                )

                # Manage fault events
                db_manager.manage_fault_event(
                    session,
                    equipment_code,
                    edge["bit_index"],
                    edge["timestamp"],
                    edge["is_active"],
                    edge["edge_type"] == "falling"  # Previous state
                )

            session.commit()

    def _get_context(self, session, equipment_code: str) -> Dict:
        """Get context data for equipment."""
        stmt = text("""
            SELECT current_operator, current_shift, planned_stop, planned_stop_reason
            FROM factory_telemetry.context
            WHERE equipment_code = :equipment_code
        """)

        result = session.execute(stmt, {"equipment_code": equipment_code}).first()

        if result:
            return {
                "current_operator": result.current_operator,
                "current_shift": result.current_shift,
                "planned_stop": result.planned_stop,
                "planned_stop_reason": result.planned_stop_reason,
            }

        # Return defaults if no context found
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

        # Disconnect PLC clients
        if self.bagger_client:
            self.bagger_client.disconnect()

        if self.basket_loader_client:
            self.basket_loader_client.disconnect()


async def main():
    """Main entry point."""
    poller = TelemetryPoller()

    # Setup signal handlers
    def signal_handler(sig, frame):
        logger.info("signal_received", signal=sig)
        asyncio.create_task(poller.shutdown())

    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    try:
        await poller.initialize()
        await poller.run()
    except Exception as e:
        logger.error("poller_error", error=str(e))
        sys.exit(1)
    finally:
        await poller.shutdown()


if __name__ == "__main__":
    asyncio.run(main())