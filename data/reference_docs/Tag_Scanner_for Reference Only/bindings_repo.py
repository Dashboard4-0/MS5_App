"""Metric definitions and bindings repository."""

import uuid
from typing import Dict, List, Optional

import structlog
from sqlalchemy import text
from sqlalchemy.orm import Session

from .config import settings

logger = structlog.get_logger()


class BindingsRepository:
    """Repository for metric definitions and bindings."""

    # Canonical metric keys
    METRIC_KEYS = [
        "running_status",
        "speed_real",
        "current_product",
        "active_alarms",
        "internal_fault",
        "upstream_fault",
        "downstream_fault",
        "planned_stop",
        "stop_reason",
        "product_count",
        "availability",
        "oee",
        "current_operator",
        "current_shift",
    ]

    # Metric type definitions
    METRIC_TYPES = {
        "running_status": "BOOL",
        "speed_real": "REAL",
        "current_product": "INT",
        "active_alarms": "JSON",
        "internal_fault": "BOOL",
        "upstream_fault": "BOOL",
        "downstream_fault": "BOOL",
        "planned_stop": "BOOL",
        "stop_reason": "TEXT",
        "product_count": "INT",
        "availability": "REAL",
        "oee": "REAL",
        "current_operator": "TEXT",
        "current_shift": "TEXT",
    }

    # Metric units
    METRIC_UNITS = {
        "speed_real": "mpm",
        "product_count": "ea",
        "availability": "%",
        "oee": "%",
    }

    def __init__(self, db_session: Session):
        """Initialize bindings repository."""
        self.session = db_session

    def bootstrap_metrics(self) -> None:
        """Bootstrap metric definitions and bindings for all equipment."""
        try:
            # Bootstrap Bagger 1
            self._bootstrap_equipment_metrics(settings.equipment_code_bagger1)
            self._bootstrap_bagger_bindings(settings.equipment_code_bagger1)

            # Bootstrap Basket Loader 1
            self._bootstrap_equipment_metrics(settings.equipment_code_basketloader1)
            self._bootstrap_basket_loader_bindings(settings.equipment_code_basketloader1)

            self.session.commit()
            logger.info("metrics_bootstrapped")

        except Exception as e:
            logger.error("metrics_bootstrap_failed", error=str(e))
            self.session.rollback()
            raise

    def _bootstrap_equipment_metrics(self, equipment_code: str) -> None:
        """Bootstrap metric definitions for an equipment."""
        for metric_key in self.METRIC_KEYS:
            metric_type = self.METRIC_TYPES[metric_key]
            unit = self.METRIC_UNITS.get(metric_key)
            description = self._get_metric_description(metric_key)

            # Check if metric already exists
            check_stmt = text("""
                SELECT id FROM factory_telemetry.metric_def
                WHERE equipment_code = :equipment_code AND metric_key = :metric_key
            """)
            result = self.session.execute(check_stmt, {
                "equipment_code": equipment_code,
                "metric_key": metric_key,
            }).first()

            if not result:
                # Insert new metric definition
                insert_stmt = text("""
                    INSERT INTO factory_telemetry.metric_def
                    (equipment_code, metric_key, value_type, unit, description)
                    VALUES (:equipment_code, :metric_key, :value_type, :unit, :description)
                """)
                self.session.execute(insert_stmt, {
                    "equipment_code": equipment_code,
                    "metric_key": metric_key,
                    "value_type": metric_type,
                    "unit": unit,
                    "description": description,
                })

    def _bootstrap_bagger_bindings(self, equipment_code: str) -> None:
        """Bootstrap PLC bindings for Bagger 1."""
        bindings = [
            # Speed bindings (primary and fallback)
            {"metric_key": "speed_real", "plc_kind": "LOGIX", "address": "MC_Avg_Speed", "parse_hint": "SCALAR"},
            {"metric_key": "speed_real", "plc_kind": "LOGIX", "address": "Avg_Speed", "parse_hint": "SCALAR_FALLBACK"},

            # Product and count bindings
            {"metric_key": "current_product", "plc_kind": "LOGIX", "address": "Current_Product", "parse_hint": "SCALAR"},
            {"metric_key": "product_count", "plc_kind": "LOGIX", "address": "Count_Blade_PEC.ACC", "parse_hint": "COUNTER_ACC"},

            # Computed metrics
            {"metric_key": "running_status", "plc_kind": "COMPUTED", "address": "-", "parse_hint": "COMPUTED"},
            {"metric_key": "active_alarms", "plc_kind": "COMPUTED", "address": "-", "parse_hint": "FAULT_DECODE"},
            {"metric_key": "internal_fault", "plc_kind": "COMPUTED", "address": "-", "parse_hint": "FAULT_MARKER"},
            {"metric_key": "upstream_fault", "plc_kind": "COMPUTED", "address": "-", "parse_hint": "FAULT_MARKER"},
            {"metric_key": "downstream_fault", "plc_kind": "COMPUTED", "address": "-", "parse_hint": "FAULT_MARKER"},
            {"metric_key": "planned_stop", "plc_kind": "COMPUTED", "address": "-", "parse_hint": "CONTEXT"},
            {"metric_key": "stop_reason", "plc_kind": "COMPUTED", "address": "-", "parse_hint": "CONTEXT"},
            {"metric_key": "availability", "plc_kind": "COMPUTED", "address": "-", "parse_hint": "ROLLING_CALC"},
            {"metric_key": "oee", "plc_kind": "COMPUTED", "address": "-", "parse_hint": "OEE_CALC"},
            {"metric_key": "current_operator", "plc_kind": "COMPUTED", "address": "-", "parse_hint": "CONTEXT"},
            {"metric_key": "current_shift", "plc_kind": "COMPUTED", "address": "-", "parse_hint": "CONTEXT"},
        ]

        self._insert_bindings(equipment_code, bindings)

        # Add special binding for fault array
        self._insert_fault_array_binding(equipment_code)

    def _bootstrap_basket_loader_bindings(self, equipment_code: str) -> None:
        """Bootstrap PLC bindings for Basket Loader 1."""
        bindings = [
            # SLC bindings (to be discovered from CSV)
            {"metric_key": "running_status", "plc_kind": "SLC", "address": "B3:0/8", "parse_hint": "BIT"},

            # Computed metrics
            {"metric_key": "speed_real", "plc_kind": "COMPUTED", "address": "-", "parse_hint": "NOT_AVAILABLE"},
            {"metric_key": "current_product", "plc_kind": "COMPUTED", "address": "-", "parse_hint": "INHERIT_PARENT"},
            {"metric_key": "active_alarms", "plc_kind": "COMPUTED", "address": "-", "parse_hint": "SLC_FAULTS"},
            {"metric_key": "internal_fault", "plc_kind": "COMPUTED", "address": "-", "parse_hint": "NOT_AVAILABLE"},
            {"metric_key": "upstream_fault", "plc_kind": "COMPUTED", "address": "-", "parse_hint": "NOT_AVAILABLE"},
            {"metric_key": "downstream_fault", "plc_kind": "COMPUTED", "address": "-", "parse_hint": "NOT_AVAILABLE"},
            {"metric_key": "planned_stop", "plc_kind": "COMPUTED", "address": "-", "parse_hint": "CONTEXT"},
            {"metric_key": "stop_reason", "plc_kind": "COMPUTED", "address": "-", "parse_hint": "CONTEXT"},
            {"metric_key": "product_count", "plc_kind": "COMPUTED", "address": "-", "parse_hint": "NOT_AVAILABLE"},
            {"metric_key": "availability", "plc_kind": "COMPUTED", "address": "-", "parse_hint": "ROLLING_CALC"},
            {"metric_key": "oee", "plc_kind": "COMPUTED", "address": "-", "parse_hint": "NOT_AVAILABLE"},
            {"metric_key": "current_operator", "plc_kind": "COMPUTED", "address": "-", "parse_hint": "CONTEXT"},
            {"metric_key": "current_shift", "plc_kind": "COMPUTED", "address": "-", "parse_hint": "CONTEXT"},
        ]

        self._insert_bindings(equipment_code, bindings)

    def _insert_bindings(self, equipment_code: str, bindings: List[Dict]) -> None:
        """Insert metric bindings."""
        for binding in bindings:
            # Get metric_def_id
            metric_stmt = text("""
                SELECT id FROM factory_telemetry.metric_def
                WHERE equipment_code = :equipment_code AND metric_key = :metric_key
            """)
            result = self.session.execute(metric_stmt, {
                "equipment_code": equipment_code,
                "metric_key": binding["metric_key"],
            }).first()

            if result:
                metric_def_id = result.id

                # Check if binding exists
                check_stmt = text("""
                    SELECT id FROM factory_telemetry.metric_binding
                    WHERE metric_def_id = :metric_def_id AND address = :address
                """)
                existing = self.session.execute(check_stmt, {
                    "metric_def_id": metric_def_id,
                    "address": binding["address"],
                }).first()

                if not existing:
                    # Insert binding
                    insert_stmt = text("""
                        INSERT INTO factory_telemetry.metric_binding
                        (metric_def_id, plc_kind, address, parse_hint)
                        VALUES (:metric_def_id, :plc_kind, :address, :parse_hint)
                    """)
                    self.session.execute(insert_stmt, {
                        "metric_def_id": metric_def_id,
                        "plc_kind": binding["plc_kind"],
                        "address": binding["address"],
                        "parse_hint": binding.get("parse_hint"),
                    })

    def _insert_fault_array_binding(self, equipment_code: str) -> None:
        """Insert special binding for fault array reading."""
        # Create a special metric for raw fault bits
        check_stmt = text("""
            SELECT id FROM factory_telemetry.metric_def
            WHERE equipment_code = :equipment_code AND metric_key = 'fault_bits_raw'
        """)
        result = self.session.execute(check_stmt, {"equipment_code": equipment_code}).first()

        if not result:
            insert_def = text("""
                INSERT INTO factory_telemetry.metric_def
                (equipment_code, metric_key, value_type, unit, description)
                VALUES (:equipment_code, 'fault_bits_raw', 'JSON', NULL, 'Raw fault bit array')
                RETURNING id
            """)
            result = self.session.execute(insert_def, {"equipment_code": equipment_code}).first()

        if result:
            metric_def_id = result.id if hasattr(result, 'id') else result[0]

            # Insert binding for Fault{64} array
            insert_binding = text("""
                INSERT INTO factory_telemetry.metric_binding
                (metric_def_id, plc_kind, address, parse_hint)
                VALUES (:metric_def_id, 'LOGIX', 'Fault{64}', 'BOOL_ARRAY')
                ON CONFLICT DO NOTHING
            """)
            self.session.execute(insert_binding, {"metric_def_id": metric_def_id})

    def _get_metric_description(self, metric_key: str) -> str:
        """Get description for a metric key."""
        descriptions = {
            "running_status": "Equipment running status based on speed, faults, and planned stops",
            "speed_real": "Current machine speed",
            "current_product": "Currently selected product",
            "active_alarms": "List of currently active fault/alarm names",
            "internal_fault": "Internal fault active flag",
            "upstream_fault": "Upstream equipment fault active flag",
            "downstream_fault": "Downstream equipment fault active flag",
            "planned_stop": "Planned production stop flag",
            "stop_reason": "Reason for production stop",
            "product_count": "Total product count",
            "availability": "Equipment availability percentage",
            "oee": "Overall Equipment Effectiveness",
            "current_operator": "Current operator name",
            "current_shift": "Current production shift",
        }
        return descriptions.get(metric_key, f"Metric: {metric_key}")

    def get_metric_bindings(self, equipment_code: str) -> Dict[str, List[Dict]]:
        """Get all metric bindings for an equipment grouped by metric key."""
        stmt = text("""
            SELECT md.metric_key, md.value_type, mb.plc_kind, mb.address,
                   mb.bit_index, mb.parse_hint, mb.transform_sql, md.id as metric_def_id
            FROM factory_telemetry.metric_def md
            LEFT JOIN factory_telemetry.metric_binding mb ON mb.metric_def_id = md.id
            WHERE md.equipment_code = :equipment_code
            ORDER BY md.metric_key, mb.plc_kind
        """)

        result = self.session.execute(stmt, {"equipment_code": equipment_code})

        bindings = {}
        for row in result:
            metric_key = row.metric_key
            if metric_key not in bindings:
                bindings[metric_key] = {
                    "metric_def_id": row.metric_def_id,
                    "value_type": row.value_type,
                    "bindings": []
                }

            if row.plc_kind:  # Only add if there's an actual binding
                bindings[metric_key]["bindings"].append({
                    "plc_kind": row.plc_kind,
                    "address": row.address,
                    "bit_index": row.bit_index,
                    "parse_hint": row.parse_hint,
                    "transform_sql": row.transform_sql,
                })

        return bindings