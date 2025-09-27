"""Bagger 1 tag mapper and data collector."""

from typing import Any, Dict, List, Optional

import structlog

from .config import settings
from .plc_clients import LogixClient

logger = structlog.get_logger()


class Bagger1Mapper:
    """Maps and collects data for Bagger 1 CompactLogix PLC."""

    # Required PLC tags
    REQUIRED_TAGS = [
        "MC_Avg_Speed",
        "Avg_Speed",
        "Current_Product",
        "Product_to_Bagger",
        "Count_Blade_PEC.ACC",
        "Fault{64}",
        "AllDrivesEnabled",
        "Bagger_Enable_2",
        "StartCam",
    ]

    def __init__(self, plc_client: LogixClient):
        """Initialize Bagger 1 mapper."""
        self.plc_client = plc_client
        self.equipment_code = settings.equipment_code_bagger1
        self.last_fault_bits: List[bool] = [False] * 64

    def read_all_tags(self) -> Dict[str, Any]:
        """Read all required tags from Bagger 1 PLC."""
        try:
            # Read all tags in a single batch
            raw_data = self.plc_client.read_tags(self.REQUIRED_TAGS)

            # Process and structure the data
            processed_data = {
                "raw": raw_data,
                "processed": self._process_raw_data(raw_data),
                "equipment_code": self.equipment_code,
            }

            return processed_data

        except Exception as e:
            logger.error(
                "bagger1_read_failed",
                equipment_code=self.equipment_code,
                error=str(e),
            )
            raise

    def _process_raw_data(self, raw_data: Dict[str, Dict]) -> Dict[str, Any]:
        """Process raw PLC data into structured format."""
        processed = {}

        # Extract speed (prefer MC_Avg_Speed, fallback to Avg_Speed)
        mc_speed = self._get_tag_value(raw_data, "MC_Avg_Speed")
        avg_speed = self._get_tag_value(raw_data, "Avg_Speed")

        if mc_speed is not None:
            processed["speed_real"] = float(mc_speed)
        elif avg_speed is not None:
            processed["speed_real"] = float(avg_speed)
        else:
            processed["speed_real"] = 0.0
            logger.warning("bagger1_no_speed_data")

        # Extract current product
        current_product = self._get_tag_value(raw_data, "Current_Product")
        processed["current_product"] = current_product if current_product is not None else 0

        # Extract product to bagger (supplementary)
        product_to_bagger = self._get_tag_value(raw_data, "Product_to_Bagger")
        processed["product_to_bagger"] = product_to_bagger

        # Extract counter value
        counter_acc = self._get_tag_value(raw_data, "Count_Blade_PEC.ACC")
        processed["product_count"] = counter_acc if counter_acc is not None else 0

        # Extract fault bits
        fault_bits = self._get_tag_value(raw_data, "Fault{64}")
        if isinstance(fault_bits, list) and len(fault_bits) == 64:
            processed["fault_bits"] = fault_bits
            processed["fault_bits_changed"] = self._detect_fault_changes(fault_bits)
        else:
            processed["fault_bits"] = [False] * 64
            processed["fault_bits_changed"] = []
            logger.warning("bagger1_invalid_fault_bits", data=fault_bits)

        # Extract drive enables
        all_drives = self._get_tag_value(raw_data, "AllDrivesEnabled")
        processed["all_drives_enabled"] = bool(all_drives) if all_drives is not None else False

        bagger_enable = self._get_tag_value(raw_data, "Bagger_Enable_2")
        processed["bagger_enable"] = bool(bagger_enable) if bagger_enable is not None else False

        start_cam = self._get_tag_value(raw_data, "StartCam")
        processed["start_cam"] = bool(start_cam) if start_cam is not None else False

        # Calculate derived states
        processed["has_active_faults"] = any(processed["fault_bits"])

        return processed

    def _get_tag_value(self, raw_data: Dict, tag_name: str) -> Any:
        """Safely extract tag value from raw data."""
        if tag_name in raw_data:
            tag_data = raw_data[tag_name]
            if isinstance(tag_data, dict) and tag_data.get("error") is None:
                return tag_data.get("value")
        return None

    def _detect_fault_changes(self, current_bits: List[bool]) -> List[Dict]:
        """Detect fault bit changes from last read."""
        changes = []

        for i, (prev, curr) in enumerate(zip(self.last_fault_bits, current_bits)):
            if prev != curr:
                changes.append({
                    "bit_index": i,
                    "prev_state": prev,
                    "curr_state": curr,
                    "edge": "rising" if curr else "falling",
                })

        # Update last known state
        self.last_fault_bits = current_bits.copy()

        return changes

    def get_active_fault_indices(self, fault_bits: List[bool]) -> List[int]:
        """Get indices of all active fault bits."""
        return [i for i, bit in enumerate(fault_bits) if bit]

    def calculate_running_status(
        self,
        speed: float,
        has_faults: bool,
        planned_stop: bool = False
    ) -> bool:
        """Calculate running status based on conditions."""
        return (
            speed > settings.run_speed_min and
            not has_faults and
            not planned_stop
        )

    def get_tag_diagnostics(self) -> Dict[str, Any]:
        """Get diagnostic information about tag connectivity."""
        diagnostics = {}

        for tag in self.REQUIRED_TAGS:
            try:
                result = self.plc_client.read_tags([tag])
                if tag in result:
                    diagnostics[tag] = {
                        "readable": result[tag]["error"] is None,
                        "error": result[tag]["error"],
                    }
                else:
                    diagnostics[tag] = {
                        "readable": False,
                        "error": "Tag not found in response",
                    }
            except Exception as e:
                diagnostics[tag] = {
                    "readable": False,
                    "error": str(e),
                }

        return diagnostics