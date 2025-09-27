"""CSV parsers for RSLogix 5000 and SLC tag export files."""

import csv
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import pandas as pd
import structlog

logger = structlog.get_logger()


class RSLogix5000Parser:
    """Parser for RSLogix 5000 tag export CSV files."""

    def __init__(self, csv_path: Path):
        """Initialize parser with CSV file path."""
        self.csv_path = csv_path
        self.tags: Dict[str, Tuple[str, str]] = {}

    def parse(self) -> Dict[str, Tuple[str, str]]:
        """Parse RSLogix 5000 CSV and return dict of {tag_name: (datatype, description)}."""
        if not self.csv_path.exists():
            logger.error("rslogix_csv_not_found", path=str(self.csv_path))
            return {}

        try:
            with open(self.csv_path, "r", encoding="utf-8-sig") as f:
                lines = f.readlines()

            # Skip remark lines and find header
            header_idx = -1
            for i, line in enumerate(lines):
                if "TYPE,SCOPE,NAME,DESCRIPTION,DATATYPE" in line:
                    header_idx = i
                    break

            if header_idx == -1:
                logger.error("rslogix_csv_header_not_found", path=str(self.csv_path))
                return {}

            # Parse CSV from header onwards
            reader = csv.DictReader(lines[header_idx:])
            for row in reader:
                if row.get("NAME") and row.get("DATATYPE"):
                    tag_name = row["NAME"].strip()
                    datatype = row["DATATYPE"].strip()
                    description = row.get("DESCRIPTION", "").strip()
                    self.tags[tag_name] = (datatype, description)

            logger.info("rslogix_csv_parsed", path=str(self.csv_path), tag_count=len(self.tags))
            return self.tags

        except Exception as e:
            logger.error("rslogix_csv_parse_error", path=str(self.csv_path), error=str(e))
            return {}

    def get_tag_info(self, tag_name: str) -> Optional[Tuple[str, str]]:
        """Get datatype and description for a specific tag."""
        return self.tags.get(tag_name)

    def find_tags_by_type(self, datatype: str) -> List[str]:
        """Find all tags with a specific datatype."""
        return [
            tag_name
            for tag_name, (tag_type, _) in self.tags.items()
            if tag_type == datatype
        ]


class SLCTagParser:
    """Parser for SLC tag export CSV files."""

    def __init__(self, csv_path: Path):
        """Initialize parser with CSV file path."""
        self.csv_path = csv_path
        self.tags: List[Dict[str, str]] = []

    def parse(self) -> List[Dict[str, str]]:
        """Parse SLC CSV and return list of {address, symbol, description}."""
        if not self.csv_path.exists():
            logger.error("slc_csv_not_found", path=str(self.csv_path))
            return []

        try:
            # SLC CSV has no header, columns are:
            # address, ?, symbol, desc1, desc2, desc3, ...
            with open(self.csv_path, "r", encoding="utf-8-sig") as f:
                reader = csv.reader(f)
                for row in reader:
                    if len(row) >= 3:
                        address = row[0].strip()
                        symbol = row[2].strip() if len(row) > 2 else ""

                        # Concatenate all description columns (from index 3 onwards)
                        description_parts = [col.strip() for col in row[3:] if col.strip()]
                        description = " - ".join(description_parts)

                        if address:  # Only add if address is not empty
                            self.tags.append({
                                "address": address,
                                "symbol": symbol,
                                "description": description,
                            })

            logger.info("slc_csv_parsed", path=str(self.csv_path), tag_count=len(self.tags))
            return self.tags

        except Exception as e:
            logger.error("slc_csv_parse_error", path=str(self.csv_path), error=str(e))
            return []

    def find_by_symbol(self, symbol: str) -> Optional[Dict[str, str]]:
        """Find tag by symbol name."""
        for tag in self.tags:
            if tag["symbol"] == symbol:
                return tag
        return None

    def find_by_address(self, address: str) -> Optional[Dict[str, str]]:
        """Find tag by address."""
        for tag in self.tags:
            if tag["address"] == address:
                return tag
        return None

    def find_by_description_contains(self, keyword: str) -> List[Dict[str, str]]:
        """Find tags where description contains keyword."""
        keyword_lower = keyword.lower()
        return [
            tag
            for tag in self.tags
            if keyword_lower in tag["description"].lower()
        ]


class TagMappingParser:
    """Combined parser for tag mappings from both PLC types."""

    def __init__(self, rslogix_path: Optional[Path] = None, slc_path: Optional[Path] = None):
        """Initialize combined parser."""
        self.rslogix_parser = RSLogix5000Parser(rslogix_path) if rslogix_path else None
        self.slc_parser = SLCTagParser(slc_path) if slc_path else None

    def parse_all(self) -> Dict[str, any]:
        """Parse all configured CSV files."""
        results = {}

        if self.rslogix_parser:
            results["rslogix_tags"] = self.rslogix_parser.parse()

        if self.slc_parser:
            results["slc_tags"] = self.slc_parser.parse()

        return results

    def get_bagger_tags(self) -> Dict[str, str]:
        """Get specific Bagger 1 tags we need to monitor."""
        if not self.rslogix_parser:
            return {}

        self.rslogix_parser.parse()

        # Define the tags we need for Bagger 1
        required_tags = [
            "Avg_Speed",
            "MC_Avg_Speed",
            "Current_Product",
            "Product_to_Bagger",
            "Count_Blade_PEC",
            "Fault",
            "AllDrivesEnabled",
            "Bagger_Enable_2",
            "StartCam",
        ]

        mapped_tags = {}
        for tag_name in required_tags:
            info = self.rslogix_parser.get_tag_info(tag_name)
            if info:
                datatype, description = info
                mapped_tags[tag_name] = {
                    "datatype": datatype,
                    "description": description,
                }

        return mapped_tags

    def get_basket_loader_tags(self) -> Dict[str, str]:
        """Get specific Basket Loader 1 tags we need to monitor."""
        if not self.slc_parser:
            return {}

        self.slc_parser.parse()

        # Look for key operational indicators
        mapped_tags = {}

        # Find AUTO_CYCLE_IND
        auto_cycle = self.slc_parser.find_by_symbol("AUTO_CYCLE_IND")
        if auto_cycle:
            mapped_tags["AUTO_CYCLE_IND"] = auto_cycle

        # Find MANUAL_MODE_IND
        manual_mode = self.slc_parser.find_by_symbol("MANUAL_MODE_IND")
        if manual_mode:
            mapped_tags["MANUAL_MODE_IND"] = manual_mode

        # Find any fault-related bits
        fault_tags = self.slc_parser.find_by_description_contains("FAULT")
        for tag in fault_tags[:5]:  # Limit to first 5 fault tags
            mapped_tags[f"FAULT_{tag['symbol'] or tag['address']}"] = tag

        # Find any speed/count registers (N7:*)
        for tag in self.slc_parser.tags:
            if tag["address"].startswith("N7:"):
                if "speed" in tag["description"].lower() or "count" in tag["description"].lower():
                    mapped_tags[f"DATA_{tag['symbol'] or tag['address']}"] = tag
                    if len(mapped_tags) > 10:  # Limit total tags
                        break

        return mapped_tags