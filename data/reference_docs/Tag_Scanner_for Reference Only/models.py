"""Pydantic models for API requests and responses."""

from datetime import datetime
from typing import Any, Dict, List, Optional
from uuid import UUID

from pydantic import BaseModel, Field, EmailStr


# PLC Models
class PLCCreate(BaseModel):
    """Model for creating a new PLC."""
    name: str = Field(..., min_length=1, max_length=100)
    ip_address: str = Field(..., regex=r'^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$')
    plc_type: str = Field(..., regex=r'^(LOGIX|SLC)$')
    port: int = Field(default=44818, ge=1, le=65535)
    poll_interval_s: float = Field(default=1.0, ge=0.1, le=60.0)


class PLCUpdate(BaseModel):
    """Model for updating a PLC."""
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    ip_address: Optional[str] = Field(None, regex=r'^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$')
    plc_type: Optional[str] = Field(None, regex=r'^(LOGIX|SLC)$')
    port: Optional[int] = Field(None, ge=1, le=65535)
    enabled: Optional[bool] = None
    poll_interval_s: Optional[float] = Field(None, ge=0.1, le=60.0)


class PLCResponse(BaseModel):
    """Model for PLC response."""
    id: UUID
    name: str
    ip_address: str
    plc_type: str
    port: int
    enabled: bool
    poll_interval_s: float
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


# Equipment Models
class EquipmentCreate(BaseModel):
    """Model for creating new equipment."""
    equipment_code: str = Field(..., min_length=1, max_length=50)
    name: str = Field(..., min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=500)
    plc_id: UUID
    enabled: bool = Field(default=True)


class EquipmentUpdate(BaseModel):
    """Model for updating equipment."""
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=500)
    plc_id: Optional[UUID] = None
    enabled: Optional[bool] = None


class EquipmentResponse(BaseModel):
    """Model for equipment response."""
    id: UUID
    equipment_code: str
    name: str
    description: Optional[str]
    plc_id: Optional[UUID]
    enabled: bool
    created_at: datetime
    updated_at: datetime
    plc: Optional[PLCResponse] = None

    class Config:
        from_attributes = True


# Metric Models
class MetricCreate(BaseModel):
    """Model for creating a new metric."""
    metric_key: str = Field(..., min_length=1, max_length=100)
    value_type: str = Field(..., regex=r'^(BOOL|INT|REAL|TEXT|JSON)$')
    unit: Optional[str] = Field(None, max_length=20)
    description: str = Field(..., min_length=1, max_length=500)
    display_name: Optional[str] = Field(None, max_length=100)
    min_value: Optional[float] = None
    max_value: Optional[float] = None
    warning_threshold: Optional[float] = None
    alarm_threshold: Optional[float] = None
    unit_display: Optional[str] = Field(None, max_length=20)


class MetricUpdate(BaseModel):
    """Model for updating a metric."""
    value_type: Optional[str] = Field(None, regex=r'^(BOOL|INT|REAL|TEXT|JSON)$')
    unit: Optional[str] = Field(None, max_length=20)
    description: Optional[str] = Field(None, min_length=1, max_length=500)
    display_name: Optional[str] = Field(None, max_length=100)
    enabled: Optional[bool] = None
    min_value: Optional[float] = None
    max_value: Optional[float] = None
    warning_threshold: Optional[float] = None
    alarm_threshold: Optional[float] = None
    unit_display: Optional[str] = Field(None, max_length=20)


class MetricResponse(BaseModel):
    """Model for metric response."""
    id: UUID
    equipment_code: str
    metric_key: str
    value_type: str
    unit: Optional[str]
    description: str
    enabled: bool
    display_name: Optional[str]
    min_value: Optional[float]
    max_value: Optional[float]
    warning_threshold: Optional[float]
    alarm_threshold: Optional[float]
    unit_display: Optional[str]

    class Config:
        from_attributes = True


# User Models
class UserCreate(BaseModel):
    """Model for creating a new user."""
    username: str = Field(..., min_length=3, max_length=50)
    email: EmailStr
    password: str = Field(..., min_length=8, max_length=100)
    role: str = Field(default='operator', regex=r'^(admin|operator|viewer)$')


class UserUpdate(BaseModel):
    """Model for updating a user."""
    username: Optional[str] = Field(None, min_length=3, max_length=50)
    email: Optional[EmailStr] = None
    role: Optional[str] = Field(None, regex=r'^(admin|operator|viewer)$')


class UserResponse(BaseModel):
    """Model for user response."""
    id: UUID
    username: str
    email: str
    role: str
    created_at: datetime
    last_login: Optional[datetime]

    class Config:
        from_attributes = True


# Authentication Models
class LoginRequest(BaseModel):
    """Model for login request."""
    username: str
    password: str


class LoginResponse(BaseModel):
    """Model for login response."""
    access_token: str
    token_type: str = "bearer"
    user: UserResponse


# WebSocket Models
class WebSocketMessage(BaseModel):
    """Model for WebSocket messages."""
    type: str
    payload: Dict[str, Any]
    timestamp: datetime = Field(default_factory=datetime.utcnow)


# Response Models
class EquipmentStatus(BaseModel):
    """Model for equipment status in dashboard."""
    equipment_code: str
    name: str
    status: str  # running, stopped, fault, maintenance
    speed: Optional[float] = None
    has_faults: bool = False
    active_faults: List[str] = []
    last_update: datetime


class SystemHealth(BaseModel):
    """Model for system health check."""
    status: str
    database: str
    websocket: str
    timestamp: datetime
    uptime_seconds: float
    memory_usage_mb: float
    cpu_usage_percent: float
