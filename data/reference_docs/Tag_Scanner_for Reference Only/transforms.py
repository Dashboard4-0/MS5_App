"""Data transformation and calculation utilities."""

import json
from collections import deque
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional, Tuple

import structlog

from .config import settings

logger = structlog.get_logger()


class MetricTransformer:
    """Transform raw PLC data into canonical metrics."""

    def __init__(self, fault_catalog: Dict[int, Dict] = None):
        """Initialize metric transformer."""
        self.fault_catalog = fault_catalog or {}
        self.availability_buffer = AvailabilityCalculator()

    def transform_bagger_metrics(
        self,
        raw_data: Dict[str, Any],
        context_data: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Transform Bagger 1 raw data into canonical metrics."""
        processed = raw_data.get("processed", {})
        metrics = {}

        # Speed metric
        metrics["speed_real"] = processed.get("speed_real", 0.0)

        # Product metric
        metrics["current_product"] = processed.get("current_product", 0)

        # Count metric
        metrics["product_count"] = processed.get("product_count", 0)

        # Fault processing
        fault_bits = processed.get("fault_bits", [False] * 64)
        fault_analysis = self._analyze_faults(fault_bits)

        metrics["active_alarms"] = fault_analysis["active_alarms"]
        metrics["internal_fault"] = fault_analysis["internal_fault"]
        metrics["upstream_fault"] = fault_analysis["upstream_fault"]
        metrics["downstream_fault"] = fault_analysis["downstream_fault"]

        # Context metrics
        metrics["planned_stop"] = context_data.get("planned_stop", False)
        metrics["stop_reason"] = context_data.get("planned_stop_reason", "")
        metrics["current_operator"] = context_data.get("current_operator", "")
        metrics["current_shift"] = context_data.get("current_shift", "")

        # Running status
        metrics["running_status"] = self._calculate_running_status(
            speed=metrics["speed_real"],
            has_faults=processed.get("has_active_faults", False),
            planned_stop=metrics["planned_stop"]
        )

        # Availability calculation
        metrics["availability"] = self.availability_buffer.update(
            metrics["running_status"],
            metrics["planned_stop"]
        )

        # OEE calculation
        metrics["oee"] = self._calculate_oee(
            availability=metrics["availability"],
            speed_real=metrics["speed_real"],
            target_speed=settings.target_speed_bagger1,
            quality=None  # Not available yet
        )

        # Add raw fault bits for storage
        metrics["fault_bits_raw"] = fault_bits

        return metrics

    def transform_basket_loader_metrics(
        self,
        raw_data: Dict[str, Any],
        context_data: Dict[str, Any],
        parent_product: Optional[int] = None
    ) -> Dict[str, Any]:
        """Transform Basket Loader 1 raw data into canonical metrics."""
        processed = raw_data.get("processed", {})
        metrics = {}

        # Speed metric (may not be available)
        metrics["speed_real"] = processed.get("speed_real", 0.0)

        # Product metric (inherit from parent Bagger)
        metrics["current_product"] = parent_product or 0

        # Count metric (may not be available)
        metrics["product_count"] = processed.get("product_count", 0)

        # Fault processing (simplified for SLC)
        faults = processed.get("faults", [])
        active_alarms = [f["key"] for f in faults if f.get("active")]

        metrics["active_alarms"] = active_alarms
        metrics["internal_fault"] = len(active_alarms) > 0
        metrics["upstream_fault"] = False  # Not categorized for SLC
        metrics["downstream_fault"] = False  # Not categorized for SLC

        # Context metrics
        metrics["planned_stop"] = context_data.get("planned_stop", False)
        metrics["stop_reason"] = context_data.get("planned_stop_reason", "")
        metrics["current_operator"] = context_data.get("current_operator", "")
        metrics["current_shift"] = context_data.get("current_shift", "")

        # Running status (based on SLC bits)
        metrics["running_status"] = processed.get("running_status", False)

        # Availability calculation
        metrics["availability"] = self.availability_buffer.update(
            metrics["running_status"],
            metrics["planned_stop"]
        )

        # OEE not calculated for Basket Loader (dependent equipment)
        metrics["oee"] = None

        return metrics

    def _analyze_faults(self, fault_bits: List[bool]) -> Dict[str, Any]:
        """Analyze fault bits and categorize them."""
        active_alarms = []
        internal_fault = False
        upstream_fault = False
        downstream_fault = False

        for i, bit_active in enumerate(fault_bits):
            if bit_active:
                fault_info = self.fault_catalog.get(i, {
                    "name": f"Fault {i}",
                    "description": "Unknown fault",
                    "marker": "INTERNAL"
                })

                active_alarms.append(fault_info["name"])

                marker = fault_info.get("marker", "INTERNAL")
                if marker == "INTERNAL":
                    internal_fault = True
                elif marker == "UPSTREAM":
                    upstream_fault = True
                elif marker == "DOWNSTREAM":
                    downstream_fault = True

        return {
            "active_alarms": active_alarms,
            "internal_fault": internal_fault,
            "upstream_fault": upstream_fault,
            "downstream_fault": downstream_fault,
        }

    def _calculate_running_status(
        self,
        speed: float,
        has_faults: bool,
        planned_stop: bool
    ) -> bool:
        """Calculate running status based on conditions."""
        return (
            speed > settings.run_speed_min and
            not has_faults and
            not planned_stop
        )

    def _calculate_oee(
        self,
        availability: float,
        speed_real: float,
        target_speed: float,
        quality: Optional[float] = None
    ) -> Optional[float]:
        """Calculate OEE (Overall Equipment Effectiveness)."""
        if quality is None:
            # Cannot calculate OEE without quality data
            logger.debug("oee_quality_not_available")
            return None

        if target_speed <= 0:
            logger.warning("oee_invalid_target_speed", target_speed=target_speed)
            return None

        # Performance = actual speed / target speed (capped at 1.0)
        performance = min(1.0, speed_real / target_speed) if speed_real > 0 else 0.0

        # OEE = Availability × Performance × Quality
        oee = availability * performance * quality

        return round(oee, 4)  # Return as percentage decimal (0.0 - 1.0)

    def prepare_metric_values(
        self,
        metrics: Dict[str, Any],
        metric_definitions: Dict[str, Dict]
    ) -> List[Tuple[str, Any, str]]:
        """Prepare metric values for database storage."""
        prepared = []

        for metric_key, metric_info in metric_definitions.items():
            if metric_key in metrics:
                value = metrics[metric_key]
                value_type = metric_info["value_type"]

                # Convert list to JSON for active_alarms
                if metric_key == "active_alarms" and isinstance(value, list):
                    value = json.dumps(value)
                elif metric_key == "fault_bits_raw" and isinstance(value, list):
                    value = json.dumps(value)

                # Skip None values for metrics that aren't available
                if value is not None:
                    prepared.append((
                        metric_info["metric_def_id"],
                        value,
                        value_type
                    ))

        return prepared


class AvailabilityCalculator:
    """Calculate rolling availability metrics."""

    def __init__(self, window_seconds: int = 3600):
        """Initialize availability calculator with rolling window."""
        self.window_seconds = window_seconds
        self.buffer = deque(maxlen=window_seconds)
        self.last_availability = 1.0

    def update(self, running: bool, planned_stop: bool) -> float:
        """Update availability with new status and return current percentage."""
        # Add current state to buffer
        self.buffer.append({
            "running": running,
            "planned_stop": planned_stop,
            "timestamp": datetime.utcnow()
        })

        # Calculate availability
        if len(self.buffer) < 2:
            # Not enough data yet
            return 1.0 if running else 0.0

        # Count productive vs available time
        productive_seconds = 0
        available_seconds = 0

        for entry in self.buffer:
            if not entry["planned_stop"]:
                available_seconds += 1
                if entry["running"]:
                    productive_seconds += 1

        if available_seconds == 0:
            # All planned stops
            self.last_availability = 1.0
        else:
            self.last_availability = productive_seconds / available_seconds

        return round(self.last_availability, 4)

    def get_current(self) -> float:
        """Get current availability without updating."""
        return self.last_availability


class FaultEdgeDetector:
    """Detect fault state transitions for event logging."""

    def __init__(self):
        """Initialize fault edge detector."""
        self.previous_states: Dict[str, Dict[int, bool]] = {}

    def detect_edges(
        self,
        equipment_code: str,
        current_faults: List[bool]
    ) -> List[Dict[str, Any]]:
        """Detect rising and falling edges in fault states."""
        if equipment_code not in self.previous_states:
            self.previous_states[equipment_code] = {
                i: False for i in range(len(current_faults))
            }

        edges = []
        prev_states = self.previous_states[equipment_code]

        for i, curr_state in enumerate(current_faults):
            prev_state = prev_states.get(i, False)

            if prev_state != curr_state:
                edges.append({
                    "bit_index": i,
                    "edge_type": "rising" if curr_state else "falling",
                    "is_active": curr_state,
                    "timestamp": datetime.utcnow()
                })

            # Update previous state
            prev_states[i] = curr_state

        return edges