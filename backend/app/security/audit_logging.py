"""
MS5.0 Floor Dashboard - Audit Logging Module

Comprehensive audit logging system for security events, user actions,
and system activities. Implements tamper-proof logging with integrity verification.

Architecture: Starship-grade audit logging that creates an immutable record
of all system activities for compliance and security monitoring.
"""

import json
import hashlib
import hmac
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Union
from enum import Enum
from dataclasses import dataclass, asdict
import structlog

from app.config import settings

logger = structlog.get_logger()


class AuditEventType(str, Enum):
    """Types of audit events."""
    # Authentication events
    LOGIN_SUCCESS = "login_success"
    LOGIN_FAILURE = "login_failure"
    LOGOUT = "logout"
    PASSWORD_CHANGE = "password_change"
    PASSWORD_RESET = "password_reset"
    TOKEN_REFRESH = "token_refresh"
    TOKEN_REVOKE = "token_revoke"
    
    # Authorization events
    PERMISSION_GRANTED = "permission_granted"
    PERMISSION_DENIED = "permission_denied"
    ROLE_CHANGE = "role_change"
    ACCESS_DENIED = "access_denied"
    
    # Data access events
    DATA_READ = "data_read"
    DATA_CREATE = "data_create"
    DATA_UPDATE = "data_update"
    DATA_DELETE = "data_delete"
    DATA_EXPORT = "data_export"
    DATA_IMPORT = "data_import"
    
    # System events
    SYSTEM_STARTUP = "system_startup"
    SYSTEM_SHUTDOWN = "system_shutdown"
    CONFIGURATION_CHANGE = "configuration_change"
    MAINTENANCE_MODE = "maintenance_mode"
    
    # Security events
    SECURITY_THREAT_DETECTED = "security_threat_detected"
    SUSPICIOUS_ACTIVITY = "suspicious_activity"
    BRUTE_FORCE_ATTEMPT = "brute_force_attempt"
    SQL_INJECTION_ATTEMPT = "sql_injection_attempt"
    XSS_ATTEMPT = "xss_attempt"
    CSRF_ATTEMPT = "csrf_attempt"
    
    # Production events
    PRODUCTION_START = "production_start"
    PRODUCTION_STOP = "production_stop"
    EQUIPMENT_FAILURE = "equipment_failure"
    MAINTENANCE_PERFORMED = "maintenance_performed"
    QUALITY_CHECK = "quality_check"
    
    # User management events
    USER_CREATED = "user_created"
    USER_UPDATED = "user_updated"
    USER_DELETED = "user_deleted"
    USER_DEACTIVATED = "user_deactivated"
    USER_REACTIVATED = "user_reactivated"


class AuditSeverity(str, Enum):
    """Audit event severity levels."""
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


@dataclass
class AuditEvent:
    """Audit event data structure."""
    event_id: str
    event_type: AuditEventType
    timestamp: datetime
    user_id: Optional[str]
    session_id: Optional[str]
    ip_address: Optional[str]
    user_agent: Optional[str]
    resource: Optional[str]
    action: str
    details: Dict[str, Any]
    severity: AuditSeverity
    success: bool
    error_message: Optional[str] = None
    metadata: Dict[str, Any] = None
    
    def __post_init__(self):
        """Post-initialization processing."""
        if self.metadata is None:
            self.metadata = {}
        
        # Ensure timestamp is timezone-aware
        if self.timestamp.tzinfo is None:
            self.timestamp = self.timestamp.replace(tzinfo=timezone.utc)
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert audit event to dictionary."""
        data = asdict(self)
        data['timestamp'] = self.timestamp.isoformat()
        return data
    
    def to_json(self) -> str:
        """Convert audit event to JSON string."""
        return json.dumps(self.to_dict(), default=str)


class AuditLogger:
    """
    Comprehensive audit logging system.
    
    Provides tamper-proof logging with integrity verification,
    structured logging, and compliance features.
    """
    
    def __init__(self, secret_key: str = None):
        """
        Initialize audit logger.
        
        Args:
            secret_key: Secret key for integrity verification
        """
        self.secret_key = secret_key or settings.SECRET_KEY
        self.events: List[AuditEvent] = []  # In production, use persistent storage
    
    def log_event(self, event: AuditEvent) -> None:
        """
        Log an audit event.
        
        Args:
            event: Audit event to log
        """
        # Add integrity hash
        event.metadata['integrity_hash'] = self._calculate_integrity_hash(event)
        
        # Store event
        self.events.append(event)
        
        # Log to structured logger
        self._log_to_structured_logger(event)
        
        # Log critical events immediately
        if event.severity == AuditSeverity.CRITICAL:
            logger.critical(
                "Critical audit event",
                event_id=event.event_id,
                event_type=event.event_type,
                user_id=event.user_id,
                action=event.action,
                details=event.details
            )
    
    def log_authentication_event(self, event_type: AuditEventType, user_id: str,
                                ip_address: str, user_agent: str, success: bool,
                                details: Dict[str, Any] = None, error_message: str = None) -> str:
        """Log authentication-related event."""
        event = AuditEvent(
            event_id=self._generate_event_id(),
            event_type=event_type,
            timestamp=datetime.now(timezone.utc),
            user_id=user_id,
            session_id=None,  # Will be set by session manager
            ip_address=ip_address,
            user_agent=user_agent,
            resource="authentication",
            action=event_type.value,
            details=details or {},
            severity=self._get_severity_for_auth_event(event_type, success),
            success=success,
            error_message=error_message
        )
        
        self.log_event(event)
        return event.event_id
    
    def log_authorization_event(self, event_type: AuditEventType, user_id: str,
                               resource: str, action: str, success: bool,
                               details: Dict[str, Any] = None) -> str:
        """Log authorization-related event."""
        event = AuditEvent(
            event_id=self._generate_event_id(),
            event_type=event_type,
            timestamp=datetime.now(timezone.utc),
            user_id=user_id,
            session_id=None,
            ip_address=None,
            user_agent=None,
            resource=resource,
            action=action,
            details=details or {},
            severity=self._get_severity_for_authz_event(event_type, success),
            success=success
        )
        
        self.log_event(event)
        return event.event_id
    
    def log_data_access_event(self, event_type: AuditEventType, user_id: str,
                             resource: str, action: str, success: bool,
                             details: Dict[str, Any] = None) -> str:
        """Log data access event."""
        event = AuditEvent(
            event_id=self._generate_event_id(),
            event_type=event_type,
            timestamp=datetime.now(timezone.utc),
            user_id=user_id,
            session_id=None,
            ip_address=None,
            user_agent=None,
            resource=resource,
            action=action,
            details=details or {},
            severity=self._get_severity_for_data_event(event_type, success),
            success=success
        )
        
        self.log_event(event)
        return event.event_id
    
    def log_security_event(self, event_type: AuditEventType, threat_type: str,
                          ip_address: str, user_agent: str, details: Dict[str, Any] = None) -> str:
        """Log security-related event."""
        event = AuditEvent(
            event_id=self._generate_event_id(),
            event_type=event_type,
            timestamp=datetime.now(timezone.utc),
            user_id=None,
            session_id=None,
            ip_address=ip_address,
            user_agent=user_agent,
            resource="security",
            action=event_type.value,
            details=details or {},
            severity=AuditSeverity.HIGH,
            success=False
        )
        
        self.log_event(event)
        return event.event_id
    
    def log_system_event(self, event_type: AuditEventType, details: Dict[str, Any] = None) -> str:
        """Log system-related event."""
        event = AuditEvent(
            event_id=self._generate_event_id(),
            event_type=event_type,
            timestamp=datetime.now(timezone.utc),
            user_id=None,
            session_id=None,
            ip_address=None,
            user_agent=None,
            resource="system",
            action=event_type.value,
            details=details or {},
            severity=self._get_severity_for_system_event(event_type),
            success=True
        )
        
        self.log_event(event)
        return event.event_id
    
    def get_events(self, user_id: str = None, event_type: AuditEventType = None,
                  start_time: datetime = None, end_time: datetime = None,
                  severity: AuditSeverity = None) -> List[AuditEvent]:
        """
        Retrieve audit events with filtering.
        
        Args:
            user_id: Filter by user ID
            event_type: Filter by event type
            start_time: Filter by start time
            end_time: Filter by end time
            severity: Filter by severity
            
        Returns:
            List of matching audit events
        """
        filtered_events = self.events
        
        if user_id:
            filtered_events = [e for e in filtered_events if e.user_id == user_id]
        
        if event_type:
            filtered_events = [e for e in filtered_events if e.event_type == event_type]
        
        if start_time:
            filtered_events = [e for e in filtered_events if e.timestamp >= start_time]
        
        if end_time:
            filtered_events = [e for e in filtered_events if e.timestamp <= end_time]
        
        if severity:
            filtered_events = [e for e in filtered_events if e.severity == severity]
        
        return sorted(filtered_events, key=lambda x: x.timestamp, reverse=True)
    
    def verify_integrity(self, event: AuditEvent) -> bool:
        """
        Verify the integrity of an audit event.
        
        Args:
            event: Audit event to verify
            
        Returns:
            True if integrity is valid, False otherwise
        """
        stored_hash = event.metadata.get('integrity_hash')
        if not stored_hash:
            return False
        
        calculated_hash = self._calculate_integrity_hash(event)
        return hmac.compare_digest(stored_hash, calculated_hash)
    
    def export_audit_log(self, start_time: datetime = None, end_time: datetime = None) -> str:
        """
        Export audit log for compliance reporting.
        
        Args:
            start_time: Start time for export
            end_time: End time for export
            
        Returns:
            JSON string of audit events
        """
        events = self.get_events(start_time=start_time, end_time=end_time)
        
        export_data = {
            "export_timestamp": datetime.now(timezone.utc).isoformat(),
            "export_period": {
                "start": start_time.isoformat() if start_time else None,
                "end": end_time.isoformat() if end_time else None
            },
            "total_events": len(events),
            "events": [event.to_dict() for event in events]
        }
        
        return json.dumps(export_data, indent=2, default=str)
    
    def _generate_event_id(self) -> str:
        """Generate unique event ID."""
        timestamp = datetime.now(timezone.utc).isoformat()
        random_part = hashlib.sha256(f"{timestamp}{self.secret_key}".encode()).hexdigest()[:8]
        return f"audit_{timestamp.replace(':', '-').replace('.', '-')}_{random_part}"
    
    def _calculate_integrity_hash(self, event: AuditEvent) -> str:
        """Calculate integrity hash for event."""
        # Create hash of all event data except the integrity hash itself
        event_data = event.to_dict()
        event_data['metadata'] = {k: v for k, v in event_data['metadata'].items() 
                                if k != 'integrity_hash'}
        
        data_string = json.dumps(event_data, sort_keys=True, default=str)
        return hmac.new(
            self.secret_key.encode(),
            data_string.encode(),
            hashlib.sha256
        ).hexdigest()
    
    def _log_to_structured_logger(self, event: AuditEvent) -> None:
        """Log event to structured logger."""
        log_data = {
            "audit_event": True,
            "event_id": event.event_id,
            "event_type": event.event_type.value,
            "timestamp": event.timestamp.isoformat(),
            "user_id": event.user_id,
            "session_id": event.session_id,
            "ip_address": event.ip_address,
            "resource": event.resource,
            "action": event.action,
            "severity": event.severity.value,
            "success": event.success,
            "details": event.details
        }
        
        if event.error_message:
            log_data["error_message"] = event.error_message
        
        # Log at appropriate level based on severity
        if event.severity == AuditSeverity.CRITICAL:
            logger.critical("Audit event", **log_data)
        elif event.severity == AuditSeverity.HIGH:
            logger.error("Audit event", **log_data)
        elif event.severity == AuditSeverity.MEDIUM:
            logger.warning("Audit event", **log_data)
        else:
            logger.info("Audit event", **log_data)
    
    def _get_severity_for_auth_event(self, event_type: AuditEventType, success: bool) -> AuditSeverity:
        """Get severity for authentication event."""
        if not success:
            if event_type == AuditEventType.LOGIN_FAILURE:
                return AuditSeverity.MEDIUM
            return AuditSeverity.HIGH
        
        if event_type in [AuditEventType.PASSWORD_CHANGE, AuditEventType.PASSWORD_RESET]:
            return AuditSeverity.MEDIUM
        
        return AuditSeverity.LOW
    
    def _get_severity_for_authz_event(self, event_type: AuditEventType, success: bool) -> AuditSeverity:
        """Get severity for authorization event."""
        if not success:
            return AuditSeverity.HIGH
        
        if event_type == AuditEventType.ROLE_CHANGE:
            return AuditSeverity.MEDIUM
        
        return AuditSeverity.LOW
    
    def _get_severity_for_data_event(self, event_type: AuditEventType, success: bool) -> AuditSeverity:
        """Get severity for data access event."""
        if not success:
            return AuditSeverity.MEDIUM
        
        if event_type in [AuditEventType.DATA_DELETE, AuditEventType.DATA_EXPORT]:
            return AuditSeverity.MEDIUM
        
        return AuditSeverity.LOW
    
    def _get_severity_for_system_event(self, event_type: AuditEventType) -> AuditSeverity:
        """Get severity for system event."""
        if event_type in [AuditEventType.SYSTEM_STARTUP, AuditEventType.SYSTEM_SHUTDOWN]:
            return AuditSeverity.MEDIUM
        
        if event_type == AuditEventType.CONFIGURATION_CHANGE:
            return AuditSeverity.HIGH
        
        return AuditSeverity.LOW


class SecurityEventLogger:
    """
    Specialized logger for security events.
    
    Provides enhanced logging for security-related events with
    threat detection and response capabilities.
    """
    
    def __init__(self, audit_logger: AuditLogger = None):
        """
        Initialize security event logger.
        
        Args:
            audit_logger: Audit logger instance
        """
        self.audit_logger = audit_logger or AuditLogger()
        self.threat_patterns = self._initialize_threat_patterns()
    
    def log_threat_detection(self, threat_type: str, source_ip: str,
                           user_agent: str, details: Dict[str, Any]) -> str:
        """Log detected security threat."""
        return self.audit_logger.log_security_event(
            AuditEventType.SECURITY_THREAT_DETECTED,
            threat_type,
            source_ip,
            user_agent,
            details
        )
    
    def log_suspicious_activity(self, activity_type: str, user_id: str,
                               details: Dict[str, Any]) -> str:
        """Log suspicious user activity."""
        event = AuditEvent(
            event_id=self.audit_logger._generate_event_id(),
            event_type=AuditEventType.SUSPICIOUS_ACTIVITY,
            timestamp=datetime.now(timezone.utc),
            user_id=user_id,
            session_id=None,
            ip_address=None,
            user_agent=None,
            resource="security",
            action="suspicious_activity",
            details=details,
            severity=AuditSeverity.HIGH,
            success=False
        )
        
        self.audit_logger.log_event(event)
        return event.event_id
    
    def log_brute_force_attempt(self, source_ip: str, username: str,
                              attempt_count: int) -> str:
        """Log brute force attack attempt."""
        details = {
            "username": username,
            "attempt_count": attempt_count,
            "attack_type": "brute_force"
        }
        
        return self.audit_logger.log_security_event(
            AuditEventType.BRUTE_FORCE_ATTEMPT,
            "brute_force",
            source_ip,
            None,
            details
        )
    
    def log_injection_attempt(self, injection_type: str, source_ip: str,
                            user_agent: str, payload: str) -> str:
        """Log injection attack attempt."""
        details = {
            "injection_type": injection_type,
            "payload": payload[:100],  # Truncate for security
            "attack_type": "injection"
        }
        
        return self.audit_logger.log_security_event(
            AuditEventType.SQL_INJECTION_ATTEMPT if injection_type == "sql" 
            else AuditEventType.XSS_ATTEMPT,
            injection_type,
            source_ip,
            user_agent,
            details
        )
    
    def _initialize_threat_patterns(self) -> Dict[str, List[str]]:
        """Initialize threat detection patterns."""
        return {
            "sql_injection": [
                "union select", "drop table", "insert into", "update set",
                "delete from", "exec(", "execute(", "sp_executesql"
            ],
            "xss": [
                "<script", "javascript:", "onload=", "onerror=", "onclick=",
                "<iframe", "<object", "<embed"
            ],
            "path_traversal": [
                "../", "..\\", "/etc/passwd", "\\windows\\system32",
                "file://", "ftp://"
            ],
            "command_injection": [
                ";", "|", "&", "`", "$", "cat ", "ls ", "pwd ", "whoami"
            ]
        }


# Global instances
audit_logger = AuditLogger()
security_event_logger = SecurityEventLogger(audit_logger)


def log_audit_event(event_type: AuditEventType, user_id: str = None,
                   resource: str = None, action: str = None,
                   success: bool = True, details: Dict[str, Any] = None) -> str:
    """
    Convenience function for logging audit events.
    
    Args:
        event_type: Type of audit event
        user_id: User ID
        resource: Resource being accessed
        action: Action performed
        success: Whether action was successful
        details: Additional event details
        
    Returns:
        Event ID
    """
    event = AuditEvent(
        event_id=audit_logger._generate_event_id(),
        event_type=event_type,
        timestamp=datetime.now(timezone.utc),
        user_id=user_id,
        session_id=None,
        ip_address=None,
        user_agent=None,
        resource=resource,
        action=action or event_type.value,
        details=details or {},
        severity=AuditSeverity.LOW,
        success=success
    )
    
    audit_logger.log_event(event)
    return event.event_id


def log_security_threat(threat_type: str, source_ip: str, user_agent: str,
                       details: Dict[str, Any] = None) -> str:
    """
    Convenience function for logging security threats.
    
    Args:
        threat_type: Type of threat
        source_ip: Source IP address
        user_agent: User agent string
        details: Threat details
        
    Returns:
        Event ID
    """
    return security_event_logger.log_threat_detection(threat_type, source_ip, user_agent, details or {})
