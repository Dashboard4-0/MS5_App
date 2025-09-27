"""Fault catalog parser and processor."""

import csv
import zipfile
from pathlib import Path
from typing import Dict, List, Optional

import pandas as pd
import structlog
from sqlalchemy import text
from sqlalchemy.orm import Session

logger = structlog.get_logger()


class FaultCatalogParser:
    """Parser for fault messages catalog."""

    def __init__(self, file_path: Path, equipment_code: str):
        """Initialize fault catalog parser."""
        self.file_path = file_path
        self.equipment_code = equipment_code
        self.faults: List[Dict] = []

    def parse(self) -> List[Dict]:
        """Parse fault catalog from CSV or Numbers file."""
        if not self.file_path.exists():
            logger.warning("fault_catalog_not_found", path=str(self.file_path))
            return self._generate_fallback_catalog()

        # Check if it's a Numbers file
        if self._is_numbers_file():
            return self._parse_numbers_file()
        else:
            return self._parse_csv_file()

    def _is_numbers_file(self) -> bool:
        """Check if file is an Apple Numbers document."""
        try:
            with open(self.file_path, "rb") as f:
                header = f.read(4)
                return header == b"PK\x03\x04"  # ZIP file header
        except Exception:
            return False

    def _parse_numbers_file(self) -> List[Dict]:
        """Parse Apple Numbers file."""
        try:
            # Try to use numbers-parser if available
            import numbers_parser

            doc = numbers_parser.Document(str(self.file_path))
            sheets = doc.sheets
            if not sheets:
                logger.error("numbers_file_no_sheets", path=str(self.file_path))
                return self._generate_fallback_catalog()

            # Get the first table from the first sheet
            table = sheets[0].tables[0]
            data = table.rows(values_only=True)

            # Parse rows assuming columns: bit_index, name, description, marker
            for row in data[1:]:  # Skip header
                if len(row) >= 4:
                    try:
                        bit_index = int(row[0]) if row[0] else None
                        if bit_index is not None and 0 <= bit_index <= 63:
                            self.faults.append({
                                "bit_index": bit_index,
                                "name": str(row[1]) if row[1] else f"Fault {bit_index}",
                                "description": str(row[2]) if row[2] else "Unknown",
                                "marker": self._validate_marker(str(row[3]) if row[3] else "INTERNAL"),
                            })
                    except (ValueError, IndexError):
                        continue

            logger.info("numbers_file_parsed", path=str(self.file_path), fault_count=len(self.faults))
            return self.faults if self.faults else self._generate_fallback_catalog()

        except ImportError:
            logger.error(
                "numbers_parser_not_installed",
                path=str(self.file_path),
                instruction="Please install numbers-parser or export file to CSV",
            )
            return self._generate_fallback_catalog()
        except Exception as e:
            logger.error("numbers_parse_error", path=str(self.file_path), error=str(e))
            return self._generate_fallback_catalog()

    def _parse_csv_file(self) -> List[Dict]:
        """Parse CSV fault catalog file."""
        try:
            # Try to read CSV with pandas for better handling
            df = pd.read_csv(self.file_path)

            # Try to identify columns
            columns_lower = [col.lower() for col in df.columns]

            # Find column indices
            bit_col = self._find_column(columns_lower, ["bit", "index", "bit_index", "bit index"])
            name_col = self._find_column(columns_lower, ["name", "fault", "alarm", "message"])
            desc_col = self._find_column(columns_lower, ["description", "desc", "text"])
            marker_col = self._find_column(columns_lower, ["marker", "type", "category", "source"])

            if bit_col is None:
                # Try to infer if first column is numeric
                if df.iloc[:, 0].dtype in ["int64", "float64"]:
                    bit_col = 0

            if bit_col is None:
                logger.error("csv_bit_column_not_found", path=str(self.file_path))
                return self._generate_fallback_catalog()

            # Parse rows
            for _, row in df.iterrows():
                try:
                    bit_index = int(row.iloc[bit_col])
                    if 0 <= bit_index <= 63:
                        name = str(row.iloc[name_col]) if name_col is not None else f"Fault {bit_index}"
                        desc = str(row.iloc[desc_col]) if desc_col is not None else "Unknown"
                        marker = str(row.iloc[marker_col]) if marker_col is not None else "INTERNAL"

                        self.faults.append({
                            "bit_index": bit_index,
                            "name": name.strip(),
                            "description": desc.strip(),
                            "marker": self._validate_marker(marker.strip()),
                        })
                except (ValueError, IndexError):
                    continue

            logger.info("csv_file_parsed", path=str(self.file_path), fault_count=len(self.faults))
            return self.faults if self.faults else self._generate_fallback_catalog()

        except Exception as e:
            logger.error("csv_parse_error", path=str(self.file_path), error=str(e))
            return self._generate_fallback_catalog()

    def _find_column(self, columns: List[str], keywords: List[str]) -> Optional[int]:
        """Find column index by keywords."""
        for keyword in keywords:
            for i, col in enumerate(columns):
                if keyword in col:
                    return i
        return None

    def _validate_marker(self, marker: str) -> str:
        """Validate and normalize fault marker."""
        marker_upper = marker.upper()
        if marker_upper in ["INTERNAL", "UPSTREAM", "DOWNSTREAM"]:
            return marker_upper
        elif "UP" in marker_upper:
            return "UPSTREAM"
        elif "DOWN" in marker_upper:
            return "DOWNSTREAM"
        else:
            return "INTERNAL"

    def _generate_fallback_catalog(self) -> List[Dict]:
        """Generate fallback fault catalog."""
        logger.warning(
            "using_fallback_fault_catalog",
            equipment_code=self.equipment_code,
            reason="Could not parse fault file, using auto-generated catalog",
        )

        faults = []
        for i in range(64):
            faults.append({
                "bit_index": i,
                "name": f"Fault {i}",
                "description": "Unknown fault - please provide proper fault catalog",
                "marker": "INTERNAL",
            })
        return faults


class FaultCatalogManager:
    """Manager for fault catalog database operations."""

    def __init__(self, db_session: Session):
        """Initialize fault catalog manager."""
        self.session = db_session

    def upsert_fault_catalog(self, equipment_code: str, faults: List[Dict]) -> None:
        """Upsert fault catalog entries to database."""
        try:
            # Clear existing entries for this equipment
            delete_stmt = text("""
                DELETE FROM factory_telemetry.fault_catalog
                WHERE equipment_code = :equipment_code
            """)
            self.session.execute(delete_stmt, {"equipment_code": equipment_code})

            # Insert new entries
            for fault in faults:
                insert_stmt = text("""
                    INSERT INTO factory_telemetry.fault_catalog
                    (equipment_code, bit_index, name, description, marker)
                    VALUES (:equipment_code, :bit_index, :name, :description, :marker)
                    ON CONFLICT (equipment_code, bit_index) DO UPDATE SET
                        name = EXCLUDED.name,
                        description = EXCLUDED.description,
                        marker = EXCLUDED.marker
                """)

                self.session.execute(insert_stmt, {
                    "equipment_code": equipment_code,
                    "bit_index": fault["bit_index"],
                    "name": fault["name"],
                    "description": fault["description"],
                    "marker": fault["marker"],
                })

            self.session.commit()
            logger.info(
                "fault_catalog_updated",
                equipment_code=equipment_code,
                count=len(faults),
            )

        except Exception as e:
            logger.error(
                "fault_catalog_update_failed",
                equipment_code=equipment_code,
                error=str(e),
            )
            self.session.rollback()
            raise

    def get_fault_catalog(self, equipment_code: str) -> Dict[int, Dict]:
        """Get fault catalog for equipment as dict keyed by bit index."""
        stmt = text("""
            SELECT bit_index, name, description, marker
            FROM factory_telemetry.fault_catalog
            WHERE equipment_code = :equipment_code
            ORDER BY bit_index
        """)

        result = self.session.execute(stmt, {"equipment_code": equipment_code})
        catalog = {}
        for row in result:
            catalog[row.bit_index] = {
                "name": row.name,
                "description": row.description,
                "marker": row.marker,
            }
        return catalog