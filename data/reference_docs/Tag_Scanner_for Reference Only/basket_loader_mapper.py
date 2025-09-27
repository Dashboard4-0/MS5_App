"""Basket Loader 1 tag mapper and data collector."""

from typing import Any, Dict, List, Optional

import structlog

from .config import settings
from .csv_parsers import SLCTagParser
from .plc_clients import SLCClient

logger = structlog.get_logger()


class BasketLoader1Mapper:
    """Maps and collects data for Basket Loader 1 SLC 5/05 PLC."""

    # Key SLC addresses (discovered from CSV or defaults)
    DEFAULT_ADDRESSES = {
        "auto_cycle": "B3:0/8",     # AUTO_CYCLE_IND
        "manual_mode": "B3:0/2",    # MANUAL_MODE_IND
        "fault_reset": "O:8/4",     # Fault reset output
    }

    def __init__(self, plc_client: SLCClient, csv_parser: Optional[SLCTagParser] = None):
        """Initialize Basket Loader 1 mapper."""
        self.plc_client = plc_client
        self.csv_parser = csv_parser
        self.equipment_code = settings.equipment_code_basketloader1
        self.addresses = self._discover_addresses()

    def _discover_addresses(self) -> Dict[str, str]:
        """Discover SLC addresses from CSV if available."""
        addresses = self.DEFAULT_ADDRESSES.copy()

        if self.csv_parser:
            try:
                tags = self.csv_parser.parse()

                # Find AUTO_CYCLE_IND
                auto_cycle = self.csv_parser.find_by_symbol("AUTO_CYCLE_IND")
                if auto_cycle:
                    addresses["auto_cycle"] = auto_cycle["address"]
                    logger.info("discovered_auto_cycle", address=auto_cycle["address"])

                # Find MANUAL_MODE_IND
                manual_mode = self.csv_parser.find_by_symbol("MANUAL_MODE_IND")
                if manual_mode:
                    addresses["manual_mode"] = manual_mode["address"]
                    logger.info("discovered_manual_mode", address=manual_mode["address"])

                # Find fault-related tags
                fault_tags = self.csv_parser.find_by_description_contains("FAULT")
                for i, fault in enumerate(fault_tags[:5]):  # Limit to 5 fault tags
                    addresses[f"fault_{i}"] = fault["address"]
                    logger.info(f"discovered_fault_{i}", address=fault["address"])

                # Find speed/count registers (N7:*)
                for tag in tags:
                    if tag["address"].startswith("N7:"):
                        desc_lower = tag["description"].lower()
                        if "speed" in desc_lower:
                            addresses["speed"] = tag["address"]
                            logger.info("discovered_speed", address=tag["address"])
                            break
                        elif "count" in desc_lower:
                            addresses["count"] = tag["address"]
                            logger.info("discovered_count", address=tag["address"])

            except Exception as e:
                logger.warning(
                    "basket_loader_csv_discovery_failed",
                    error=str(e),
                    using_defaults=True,
                )

        return addresses

    def read_all_tags(self) -> Dict[str, Any]:
        """Read all configured addresses from Basket Loader 1 PLC."""
        try:
            # Get list of addresses to read
            addresses_to_read = list(self.addresses.values())

            # Read all addresses
            raw_data = self.plc_client.read_tags(addresses_to_read)

            # Process and structure the data
            processed_data = {
                "raw": raw_data,
                "processed": self._process_raw_data(raw_data),
                "equipment_code": self.equipment_code,
                "addresses": self.addresses,
            }

            return processed_data

        except Exception as e:
            logger.error(
                "basket_loader_read_failed",
                equipment_code=self.equipment_code,
                error=str(e),
            )
            raise

    def _process_raw_data(self, raw_data: Dict[str, Dict]) -> Dict[str, Any]:
        """Process raw SLC data into structured format."""
        processed = {}

        # Extract auto cycle status
        auto_cycle_addr = self.addresses.get("auto_cycle")
        if auto_cycle_addr:
            auto_cycle = self._get_address_value(raw_data, auto_cycle_addr)
            processed["auto_cycle"] = bool(auto_cycle) if auto_cycle is not None else False
        else:
            processed["auto_cycle"] = False

        # Extract manual mode status
        manual_mode_addr = self.addresses.get("manual_mode")
        if manual_mode_addr:
            manual_mode = self._get_address_value(raw_data, manual_mode_addr)
            processed["manual_mode"] = bool(manual_mode) if manual_mode is not None else False
        else:
            processed["manual_mode"] = False

        # Determine running status (auto cycle on, manual mode off)
        processed["running_status"] = processed["auto_cycle"] and not processed["manual_mode"]

        # Extract speed if available
        speed_addr = self.addresses.get("speed")
        if speed_addr:
            speed = self._get_address_value(raw_data, speed_addr)
            processed["speed_real"] = float(speed) if speed is not None else 0.0
        else:
            processed["speed_real"] = None  # Not available

        # Extract count if available
        count_addr = self.addresses.get("count")
        if count_addr:
            count = self._get_address_value(raw_data, count_addr)
            processed["product_count"] = int(count) if count is not None else 0
        else:
            processed["product_count"] = None  # Not available

        # Extract fault states
        faults = []
        fault_active = False
        for key, addr in self.addresses.items():
            if key.startswith("fault_"):
                fault_val = self._get_address_value(raw_data, addr)
                if fault_val:
                    fault_active = True
                    faults.append({
                        "address": addr,
                        "key": key,
                        "active": bool(fault_val),
                    })

        processed["faults"] = faults
        processed["has_active_faults"] = fault_active

        return processed

    def _get_address_value(self, raw_data: Dict, address: str) -> Any:
        """Safely extract address value from raw data."""
        if address in raw_data:
            addr_data = raw_data[address]
            if isinstance(addr_data, dict) and addr_data.get("error") is None:
                return addr_data.get("value")
        return None

    def calculate_running_status(
        self,
        auto_cycle: bool,
        manual_mode: bool,
        has_faults: bool,
        planned_stop: bool = False
    ) -> bool:
        """Calculate running status based on SLC conditions."""
        return (
            auto_cycle and
            not manual_mode and
            not has_faults and
            not planned_stop
        )

    def get_active_alarms(self, faults: List[Dict]) -> List[str]:
        """Get list of active alarm descriptions."""
        alarms = []
        for fault in faults:
            if fault.get("active"):
                # Try to get description from CSV parser
                desc = fault["key"]
                if self.csv_parser:
                    tag_info = self.csv_parser.find_by_address(fault["address"])
                    if tag_info:
                        desc = tag_info.get("description", desc)
                alarms.append(desc)
        return alarms

    def get_diagnostic_info(self) -> Dict[str, Any]:
        """Get diagnostic information about SLC connectivity."""
        diagnostics = {
            "equipment_code": self.equipment_code,
            "discovered_addresses": len(self.addresses),
            "addresses": {},
        }

        for key, address in self.addresses.items():
            try:
                result = self.plc_client.read_tags([address])
                if address in result:
                    diagnostics["addresses"][key] = {
                        "address": address,
                        "readable": result[address]["error"] is None,
                        "error": result[address]["error"],
                    }
                else:
                    diagnostics["addresses"][key] = {
                        "address": address,
                        "readable": False,
                        "error": "Address not found in response",
                    }
            except Exception as e:
                diagnostics["addresses"][key] = {
                    "address": address,
                    "readable": False,
                    "error": str(e),
                }

        return diagnostics