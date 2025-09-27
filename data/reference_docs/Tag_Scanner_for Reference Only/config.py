"""Configuration management using Pydantic Settings."""

from pathlib import Path
from typing import Optional

from pydantic import Field, PostgresDsn, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application configuration."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # PLC Configuration
    plc_bagger1_ip: str = Field(default="16.191.1.131", description="Bagger 1 CompactLogix IP")
    plc_basketloader1_ip: str = Field(default="16.191.1.140", description="Basket Loader 1 SLC IP")

    # Database Configuration
    db_url: PostgresDsn = Field(
        default="postgresql+psycopg://user:password@localhost:5432/telemetry",
        description="PostgreSQL connection string"
    )

    # File Paths
    bagger_tags_csv: Path = Field(
        default=Path("./data/BaggerSlicer_1_07_10_14-Controller-Tags.CSV"),
        description="Path to Bagger RSLogix 5000 tag export"
    )
    basket_loader_tags_csv: Path = Field(
        default=Path("./data/KM2566MC1_06_03_15.CSV"),
        description="Path to Basket Loader SLC tag export"
    )
    bagger_faults_file: Path = Field(
        default=Path("./data/Bagger 1 Fault Messages.csv"),
        description="Path to Bagger fault messages file"
    )

    # Polling Configuration
    poll_interval_s: float = Field(default=1.0, ge=0.1, le=60, description="Polling interval in seconds")
    run_speed_min: float = Field(default=1.0, ge=0, description="Minimum speed to consider running")
    target_speed_bagger1: float = Field(default=100.0, ge=0, description="Target speed for Bagger 1")

    # Equipment Codes
    equipment_code_bagger1: str = Field(default="BP01.PACK.BAG1", description="Equipment code for Bagger 1")
    equipment_code_basketloader1: str = Field(default="BP01.PACK.BAG1.BL", description="Equipment code for Basket Loader 1")

    # API Configuration
    api_port: int = Field(default=8000, ge=1024, le=65535, description="API port")
    api_host: str = Field(default="0.0.0.0", description="API host")

    # Logging
    log_level: str = Field(default="INFO", description="Log level")
    log_format: str = Field(default="json", description="Log format (json or text)")

    # Retry Configuration
    max_retries: int = Field(default=3, ge=1, le=10, description="Max retry attempts")
    retry_delay: float = Field(default=1.0, ge=0.1, le=60, description="Initial retry delay")
    retry_max_delay: float = Field(default=30.0, ge=1, le=300, description="Max retry delay")

    @field_validator("bagger_tags_csv", "basket_loader_tags_csv", "bagger_faults_file", mode="before")
    def validate_path(cls, v):
        """Convert string paths to Path objects."""
        if isinstance(v, str):
            return Path(v)
        return v

    @property
    def db_url_sync(self) -> str:
        """Return synchronous database URL."""
        return str(self.db_url)


# Singleton instance
settings = Settings()