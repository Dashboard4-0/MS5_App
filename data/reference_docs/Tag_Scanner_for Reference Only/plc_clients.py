"""PLC client wrappers for pycomm3 LogixDriver and SLCDriver."""

from typing import Any, Dict, List, Optional, Union

import structlog
from pycomm3 import LogixDriver, SLCDriver
from tenacity import retry, stop_after_attempt, wait_exponential

logger = structlog.get_logger()


class BasePLCClient:
    """Base PLC client with common functionality."""

    def __init__(self, ip_address: str, name: str):
        """Initialize base PLC client."""
        self.ip_address = ip_address
        self.name = name
        self.connected = False

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=1, max=10),
    )
    def connect(self) -> bool:
        """Connect to PLC with retry logic."""
        raise NotImplementedError

    def disconnect(self) -> None:
        """Disconnect from PLC."""
        raise NotImplementedError

    def read_tags(self, tags: List[str]) -> Dict[str, Any]:
        """Read multiple tags from PLC."""
        raise NotImplementedError


class LogixClient(BasePLCClient):
    """CompactLogix/ControlLogix PLC client using LogixDriver."""

    def __init__(self, ip_address: str, name: str = "Logix PLC"):
        """Initialize Logix client."""
        super().__init__(ip_address, name)
        self.driver: Optional[LogixDriver] = None

    def connect(self) -> bool:
        """Connect to Logix PLC."""
        try:
            self.driver = LogixDriver(self.ip_address)
            self.driver.open()
            self.connected = True
            logger.info(
                "logix_plc_connected",
                name=self.name,
                ip=self.ip_address,
                controller_info=self.driver.info,
            )
            return True
        except Exception as e:
            logger.error(
                "logix_plc_connection_failed",
                name=self.name,
                ip=self.ip_address,
                error=str(e),
            )
            self.connected = False
            raise

    def disconnect(self) -> None:
        """Disconnect from Logix PLC."""
        if self.driver:
            try:
                self.driver.close()
                self.connected = False
                logger.info("logix_plc_disconnected", name=self.name)
            except Exception as e:
                logger.error("logix_plc_disconnect_failed", name=self.name, error=str(e))

    def read_tags(self, tags: List[str]) -> Dict[str, Any]:
        """Read multiple tags from Logix PLC."""
        if not self.connected or not self.driver:
            raise RuntimeError(f"PLC {self.name} not connected")

        results = {}
        try:
            # Batch read all tags at once for efficiency
            responses = self.driver.read(*tags)

            # Handle single tag read (returns single response)
            if not isinstance(responses, list):
                responses = [responses]

            for tag, response in zip(tags, responses):
                if response.error:
                    logger.warning(
                        "logix_tag_read_error",
                        name=self.name,
                        tag=tag,
                        error=response.error,
                    )
                    results[tag] = {"value": None, "error": response.error}
                else:
                    # Special handling for BOOL arrays
                    if "{" in tag and "}" in tag:
                        # BOOL array - value is already a list of booleans
                        results[tag] = {"value": response.value, "error": None}
                    elif ".ACC" in tag:
                        # Counter ACC field
                        results[tag] = {"value": response.value, "error": None}
                    else:
                        results[tag] = {"value": response.value, "error": None}

            logger.debug(
                "logix_tags_read",
                name=self.name,
                count=len(tags),
                success=sum(1 for r in results.values() if r["error"] is None),
            )
            return results

        except Exception as e:
            logger.error("logix_read_failed", name=self.name, error=str(e))
            raise

    def read_bool_array(self, tag_base: str, size: int = 64) -> List[bool]:
        """Read BOOL array from Logix PLC."""
        tag = f"{tag_base}{{{size}}}"
        result = self.read_tags([tag])

        if tag in result and result[tag]["error"] is None:
            return result[tag]["value"]
        return [False] * size


class SLCClient(BasePLCClient):
    """SLC 5/05 PLC client using SLCDriver."""

    def __init__(self, ip_address: str, name: str = "SLC PLC"):
        """Initialize SLC client."""
        super().__init__(ip_address, name)
        self.driver: Optional[SLCDriver] = None

    def connect(self) -> bool:
        """Connect to SLC PLC."""
        try:
            self.driver = SLCDriver(self.ip_address)
            self.driver.open()
            self.connected = True
            logger.info(
                "slc_plc_connected",
                name=self.name,
                ip=self.ip_address,
            )
            return True
        except Exception as e:
            logger.error(
                "slc_plc_connection_failed",
                name=self.name,
                ip=self.ip_address,
                error=str(e),
            )
            self.connected = False
            raise

    def disconnect(self) -> None:
        """Disconnect from SLC PLC."""
        if self.driver:
            try:
                self.driver.close()
                self.connected = False
                logger.info("slc_plc_disconnected", name=self.name)
            except Exception as e:
                logger.error("slc_plc_disconnect_failed", name=self.name, error=str(e))

    def read_tags(self, addresses: List[str]) -> Dict[str, Any]:
        """Read multiple addresses from SLC PLC."""
        if not self.connected or not self.driver:
            raise RuntimeError(f"PLC {self.name} not connected")

        results = {}
        try:
            # SLC reads each address individually
            for address in addresses:
                try:
                    response = self.driver.read(address)
                    if response.error:
                        logger.warning(
                            "slc_address_read_error",
                            name=self.name,
                            address=address,
                            error=response.error,
                        )
                        results[address] = {"value": None, "error": response.error}
                    else:
                        results[address] = {"value": response.value, "error": None}
                except Exception as e:
                    logger.warning(
                        "slc_address_read_exception",
                        name=self.name,
                        address=address,
                        error=str(e),
                    )
                    results[address] = {"value": None, "error": str(e)}

            logger.debug(
                "slc_addresses_read",
                name=self.name,
                count=len(addresses),
                success=sum(1 for r in results.values() if r["error"] is None),
            )
            return results

        except Exception as e:
            logger.error("slc_read_failed", name=self.name, error=str(e))
            raise

    def read_bit(self, word_address: str, bit_index: int) -> bool:
        """Read specific bit from SLC word."""
        # Format: B3:0/8 for bit 8 of word 0 in B3 file
        bit_address = f"{word_address}/{bit_index}"
        result = self.read_tags([bit_address])

        if bit_address in result and result[bit_address]["error"] is None:
            return bool(result[bit_address]["value"])
        return False


class PLCClientFactory:
    """Factory for creating PLC clients."""

    @staticmethod
    def create_logix_client(ip_address: str, name: str = "Logix PLC") -> LogixClient:
        """Create a Logix PLC client."""
        return LogixClient(ip_address, name)

    @staticmethod
    def create_slc_client(ip_address: str, name: str = "SLC PLC") -> SLCClient:
        """Create an SLC PLC client."""
        return SLCClient(ip_address, name)