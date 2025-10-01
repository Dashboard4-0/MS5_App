"""
MS5.0 Floor Dashboard - Access Control Validation Module

Enhanced access control validation system with session management,
privilege escalation detection, and comprehensive authorization checks.

Architecture: Starship-grade access control that implements defense in depth
with multiple layers of authorization and session security.
"""

import secrets
import hashlib
from datetime import datetime, timezone, timedelta
from typing import Any, Dict, List, Optional, Set, Tuple
from enum import Enum
from dataclasses import dataclass, asdict
import structlog

from app.config import settings
from app.auth.permissions import UserRole, Permission, UserContext

logger = structlog.get_logger()


class SessionStatus(str, Enum):
    """Session status types."""
    ACTIVE = "active"
    EXPIRED = "expired"
    REVOKED = "revoked"
    SUSPICIOUS = "suspicious"
    LOCKED = "locked"


class AccessViolationType(str, Enum):
    """Types of access violations."""
    UNAUTHORIZED_ACCESS = "unauthorized_access"
    PRIVILEGE_ESCALATION = "privilege_escalation"
    SESSION_HIJACKING = "session_hijacking"
    BRUTE_FORCE = "brute_force"
    SUSPICIOUS_ACTIVITY = "suspicious_activity"
    RATE_LIMIT_EXCEEDED = "rate_limit_exceeded"


@dataclass
class Session:
    """User session data structure."""
    session_id: str
    user_id: str
    created_at: datetime
    last_activity: datetime
    expires_at: datetime
    ip_address: str
    user_agent: str
    status: SessionStatus
    permissions: Set[Permission]
    role: UserRole
    metadata: Dict[str, Any] = None
    
    def __post_init__(self):
        """Post-initialization processing."""
        if self.metadata is None:
            self.metadata = {}
        
        # Ensure timestamps are timezone-aware
        if self.created_at.tzinfo is None:
            self.created_at = self.created_at.replace(tzinfo=timezone.utc)
        
        if self.last_activity.tzinfo is None:
            self.last_activity = self.last_activity.replace(tzinfo=timezone.utc)
        
        if self.expires_at.tzinfo is None:
            self.expires_at = self.expires_at.replace(tzinfo=timezone.utc)


@dataclass
class AccessViolation:
    """Access violation record."""
    violation_id: str
    user_id: Optional[str]
    session_id: Optional[str]
    violation_type: AccessViolationType
    timestamp: datetime
    ip_address: str
    user_agent: str
    resource: str
    action: str
    details: Dict[str, Any]
    severity: str
    metadata: Dict[str, Any] = None
    
    def __post_init__(self):
        """Post-initialization processing."""
        if self.metadata is None:
            self.metadata = {}
        
        # Ensure timestamp is timezone-aware
        if self.timestamp.tzinfo is None:
            self.timestamp = self.timestamp.replace(tzinfo=timezone.utc)


class SessionManager:
    """
    Comprehensive session management system.
    
    Provides secure session handling with timeout management,
    concurrent session limits, and security monitoring.
    """
    
    def __init__(self, session_timeout: int = 3600, max_concurrent_sessions: int = 5):
        """
        Initialize session manager.
        
        Args:
            session_timeout: Session timeout in seconds
            max_concurrent_sessions: Maximum concurrent sessions per user
        """
        self.session_timeout = session_timeout
        self.max_concurrent_sessions = max_concurrent_sessions
        self.sessions: Dict[str, Session] = {}
        self.user_sessions: Dict[str, List[str]] = {}  # user_id -> session_ids
    
    def create_session(self, user_id: str, ip_address: str, user_agent: str,
                      permissions: Set[Permission], role: UserRole) -> str:
        """
        Create a new user session.
        
        Args:
            user_id: User ID
            ip_address: User's IP address
            user_agent: User's user agent
            permissions: User permissions
            role: User role
            
        Returns:
            Session ID
        """
        # Check concurrent session limit
        if self._exceeds_concurrent_limit(user_id):
            self._revoke_oldest_session(user_id)
        
        session_id = self._generate_session_id()
        current_time = datetime.now(timezone.utc)
        
        session = Session(
            session_id=session_id,
            user_id=user_id,
            created_at=current_time,
            last_activity=current_time,
            expires_at=current_time + timedelta(seconds=self.session_timeout),
            ip_address=ip_address,
            user_agent=user_agent,
            status=SessionStatus.ACTIVE,
            permissions=permissions,
            role=role
        )
        
        self.sessions[session_id] = session
        
        # Track user sessions
        if user_id not in self.user_sessions:
            self.user_sessions[user_id] = []
        self.user_sessions[user_id].append(session_id)
        
        logger.info(
            "Session created",
            session_id=session_id,
            user_id=user_id,
            role=role.value
        )
        
        return session_id
    
    def validate_session(self, session_id: str, ip_address: str = None,
                       user_agent: str = None) -> Tuple[bool, Optional[Session]]:
        """
        Validate a session.
        
        Args:
            session_id: Session ID
            ip_address: Current IP address
            user_agent: Current user agent
            
        Returns:
            Tuple of (is_valid, session)
        """
        if session_id not in self.sessions:
            return False, None
        
        session = self.sessions[session_id]
        current_time = datetime.now(timezone.utc)
        
        # Check if session is expired
        if current_time > session.expires_at:
            session.status = SessionStatus.EXPIRED
            return False, None
        
        # Check if session is revoked
        if session.status != SessionStatus.ACTIVE:
            return False, None
        
        # Check for session hijacking (IP/User-Agent change)
        if ip_address and session.ip_address != ip_address:
            logger.warning(
                "Potential session hijacking detected",
                session_id=session_id,
                original_ip=session.ip_address,
                current_ip=ip_address
            )
            session.status = SessionStatus.SUSPICIOUS
            return False, None
        
        if user_agent and session.user_agent != user_agent:
            logger.warning(
                "User agent change detected",
                session_id=session_id,
                original_ua=session.user_agent,
                current_ua=user_agent
            )
            # This might be legitimate (browser update), so we don't revoke immediately
        
        # Update last activity
        session.last_activity = current_time
        
        # Extend session if needed
        if current_time > session.expires_at - timedelta(minutes=5):
            session.expires_at = current_time + timedelta(seconds=self.session_timeout)
        
        return True, session
    
    def revoke_session(self, session_id: str, reason: str = "manual_revoke") -> bool:
        """
        Revoke a session.
        
        Args:
            session_id: Session ID
            reason: Reason for revocation
            
        Returns:
            True if session was revoked, False if not found
        """
        if session_id not in self.sessions:
            return False
        
        session = self.sessions[session_id]
        session.status = SessionStatus.REVOKED
        
        # Remove from user sessions
        if session.user_id in self.user_sessions:
            self.user_sessions[session.user_id].remove(session_id)
        
        logger.info(
            "Session revoked",
            session_id=session_id,
            user_id=session.user_id,
            reason=reason
        )
        
        return True
    
    def revoke_user_sessions(self, user_id: str, reason: str = "user_logout") -> int:
        """
        Revoke all sessions for a user.
        
        Args:
            user_id: User ID
            reason: Reason for revocation
            
        Returns:
            Number of sessions revoked
        """
        if user_id not in self.user_sessions:
            return 0
        
        session_ids = self.user_sessions[user_id].copy()
        revoked_count = 0
        
        for session_id in session_ids:
            if self.revoke_session(session_id, reason):
                revoked_count += 1
        
        logger.info(
            "User sessions revoked",
            user_id=user_id,
            revoked_count=revoked_count,
            reason=reason
        )
        
        return revoked_count
    
    def cleanup_expired_sessions(self) -> int:
        """
        Clean up expired sessions.
        
        Returns:
            Number of sessions cleaned up
        """
        current_time = datetime.now(timezone.utc)
        expired_sessions = []
        
        for session_id, session in self.sessions.items():
            if current_time > session.expires_at:
                expired_sessions.append(session_id)
        
        for session_id in expired_sessions:
            session = self.sessions[session_id]
            session.status = SessionStatus.EXPIRED
            
            # Remove from user sessions
            if session.user_id in self.user_sessions:
                self.user_sessions[session.user_id].remove(session_id)
        
        logger.info(f"Cleaned up {len(expired_sessions)} expired sessions")
        return len(expired_sessions)
    
    def get_user_sessions(self, user_id: str) -> List[Session]:
        """Get all active sessions for a user."""
        if user_id not in self.user_sessions:
            return []
        
        sessions = []
        for session_id in self.user_sessions[user_id]:
            if session_id in self.sessions:
                sessions.append(self.sessions[session_id])
        
        return sessions
    
    def _exceeds_concurrent_limit(self, user_id: str) -> bool:
        """Check if user exceeds concurrent session limit."""
        if user_id not in self.user_sessions:
            return False
        
        active_sessions = 0
        for session_id in self.user_sessions[user_id]:
            if (session_id in self.sessions and 
                self.sessions[session_id].status == SessionStatus.ACTIVE):
                active_sessions += 1
        
        return active_sessions >= self.max_concurrent_sessions
    
    def _revoke_oldest_session(self, user_id: str):
        """Revoke the oldest session for a user."""
        if user_id not in self.user_sessions:
            return
        
        sessions = []
        for session_id in self.user_sessions[user_id]:
            if (session_id in self.sessions and 
                self.sessions[session_id].status == SessionStatus.ACTIVE):
                sessions.append(self.sessions[session_id])
        
        if sessions:
            oldest_session = min(sessions, key=lambda x: x.created_at)
            self.revoke_session(oldest_session.session_id, "concurrent_limit_exceeded")
    
    def _generate_session_id(self) -> str:
        """Generate unique session ID."""
        random_part = secrets.token_urlsafe(32)
        timestamp = datetime.now(timezone.utc).isoformat()
        return f"session_{timestamp.replace(':', '-').replace('.', '-')}_{random_part}"


class AccessControlValidator:
    """
    Enhanced access control validation system.
    
    Provides comprehensive authorization checks with privilege escalation
    detection and access violation monitoring.
    """
    
    def __init__(self, session_manager: SessionManager = None):
        """
        Initialize access control validator.
        
        Args:
            session_manager: Session manager instance
        """
        self.session_manager = session_manager or SessionManager()
        self.access_violations: List[AccessViolation] = []
        self.rate_limits: Dict[str, Dict[str, Any]] = {}  # user_id -> rate limit data
    
    def validate_access(self, user_context: UserContext, resource: str, action: str,
                       required_permission: Permission = None) -> Tuple[bool, Optional[str]]:
        """
        Validate user access to a resource.
        
        Args:
            user_context: User context
            resource: Resource being accessed
            action: Action being performed
            required_permission: Required permission
            
        Returns:
            Tuple of (is_authorized, error_message)
        """
        # Check if user is active
        if not user_context:
            return False, "User context not provided"
        
        # Check required permission
        if required_permission and not user_context.has_permission(required_permission):
            self._record_access_violation(
                user_context.user_id,
                AccessViolationType.UNAUTHORIZED_ACCESS,
                resource,
                action,
                f"Missing required permission: {required_permission.value}"
            )
            return False, f"Missing required permission: {required_permission.value}"
        
        # Check rate limits
        if not self._check_rate_limit(user_context.user_id, resource, action):
            self._record_access_violation(
                user_context.user_id,
                AccessViolationType.RATE_LIMIT_EXCEEDED,
                resource,
                action,
                "Rate limit exceeded"
            )
            return False, "Rate limit exceeded"
        
        # Check for suspicious activity patterns
        if self._detect_suspicious_activity(user_context.user_id, resource, action):
            self._record_access_violation(
                user_context.user_id,
                AccessViolationType.SUSPICIOUS_ACTIVITY,
                resource,
                action,
                "Suspicious activity pattern detected"
            )
            return False, "Suspicious activity detected"
        
        return True, None
    
    def validate_session_access(self, session_id: str, resource: str, action: str,
                              ip_address: str = None, user_agent: str = None) -> Tuple[bool, Optional[Session]]:
        """
        Validate session-based access.
        
        Args:
            session_id: Session ID
            resource: Resource being accessed
            action: Action being performed
            ip_address: Current IP address
            user_agent: Current user agent
            
        Returns:
            Tuple of (is_authorized, session)
        """
        # Validate session
        is_valid, session = self.session_manager.validate_session(session_id, ip_address, user_agent)
        
        if not is_valid:
            return False, None
        
        # Check rate limits
        if not self._check_rate_limit(session.user_id, resource, action):
            self._record_access_violation(
                session.user_id,
                AccessViolationType.RATE_LIMIT_EXCEEDED,
                resource,
                action,
                "Rate limit exceeded"
            )
            return False, None
        
        return True, session
    
    def detect_privilege_escalation(self, user_id: str, attempted_permission: Permission,
                                  current_permissions: Set[Permission]) -> bool:
        """
        Detect privilege escalation attempts.
        
        Args:
            user_id: User ID
            attempted_permission: Permission being attempted
            current_permissions: User's current permissions
            
        Returns:
            True if privilege escalation detected, False otherwise
        """
        # Check if user is trying to access permission they don't have
        if attempted_permission not in current_permissions:
            self._record_access_violation(
                user_id,
                AccessViolationType.PRIVILEGE_ESCALATION,
                "permissions",
                "escalate",
                f"Attempted to access permission: {attempted_permission.value}"
            )
            return True
        
        return False
    
    def get_access_violations(self, user_id: str = None, violation_type: AccessViolationType = None,
                             start_time: datetime = None, end_time: datetime = None) -> List[AccessViolation]:
        """
        Get access violations with filtering.
        
        Args:
            user_id: Filter by user ID
            violation_type: Filter by violation type
            start_time: Filter by start time
            end_time: Filter by end time
            
        Returns:
            List of matching violations
        """
        filtered_violations = self.access_violations
        
        if user_id:
            filtered_violations = [v for v in filtered_violations if v.user_id == user_id]
        
        if violation_type:
            filtered_violations = [v for v in filtered_violations if v.violation_type == violation_type]
        
        if start_time:
            filtered_violations = [v for v in filtered_violations if v.timestamp >= start_time]
        
        if end_time:
            filtered_violations = [v for v in filtered_violations if v.timestamp <= end_time]
        
        return sorted(filtered_violations, key=lambda x: x.timestamp, reverse=True)
    
    def _check_rate_limit(self, user_id: str, resource: str, action: str) -> bool:
        """Check if user exceeds rate limits."""
        current_time = datetime.now(timezone.utc)
        key = f"{user_id}:{resource}:{action}"
        
        if key not in self.rate_limits:
            self.rate_limits[key] = {
                "count": 0,
                "window_start": current_time,
                "last_request": current_time
            }
        
        rate_data = self.rate_limits[key]
        
        # Reset window if needed (1 minute windows)
        if current_time - rate_data["window_start"] > timedelta(minutes=1):
            rate_data["count"] = 0
            rate_data["window_start"] = current_time
        
        # Check rate limit (100 requests per minute)
        if rate_data["count"] >= 100:
            return False
        
        rate_data["count"] += 1
        rate_data["last_request"] = current_time
        
        return True
    
    def _detect_suspicious_activity(self, user_id: str, resource: str, action: str) -> bool:
        """Detect suspicious activity patterns."""
        # Get recent violations for user
        recent_violations = [
            v for v in self.access_violations
            if v.user_id == user_id and 
            v.timestamp > datetime.now(timezone.utc) - timedelta(minutes=10)
        ]
        
        # If user has more than 5 violations in last 10 minutes, flag as suspicious
        if len(recent_violations) > 5:
            return True
        
        # Check for rapid-fire requests to sensitive resources
        if resource in ["admin", "user_management", "system_config"]:
            recent_requests = [
                v for v in recent_violations
                if v.resource == resource
            ]
            
            if len(recent_requests) > 3:
                return True
        
        return False
    
    def _record_access_violation(self, user_id: str, violation_type: AccessViolationType,
                               resource: str, action: str, details: str):
        """Record an access violation."""
        violation = AccessViolation(
            violation_id=self._generate_violation_id(),
            user_id=user_id,
            session_id=None,
            violation_type=violation_type,
            timestamp=datetime.now(timezone.utc),
            ip_address="",  # Will be set by caller
            user_agent="",  # Will be set by caller
            resource=resource,
            action=action,
            details={"message": details},
            severity="high" if violation_type in [
                AccessViolationType.PRIVILEGE_ESCALATION,
                AccessViolationType.SESSION_HIJACKING
            ] else "medium"
        )
        
        self.access_violations.append(violation)
        
        logger.warning(
            "Access violation recorded",
            violation_id=violation.violation_id,
            user_id=user_id,
            violation_type=violation_type.value,
            resource=resource,
            action=action
        )
    
    def _generate_violation_id(self) -> str:
        """Generate unique violation ID."""
        timestamp = datetime.now(timezone.utc).isoformat()
        return f"violation_{timestamp.replace(':', '-').replace('.', '-')}"


# Global instances
session_manager = SessionManager()
access_control_validator = AccessControlValidator(session_manager)


def create_user_session(user_id: str, ip_address: str, user_agent: str,
                       permissions: Set[Permission], role: UserRole) -> str:
    """
    Convenience function for creating user session.
    
    Args:
        user_id: User ID
        ip_address: User's IP address
        user_agent: User's user agent
        permissions: User permissions
        role: User role
        
    Returns:
        Session ID
    """
    return session_manager.create_session(user_id, ip_address, user_agent, permissions, role)


def validate_user_access(user_context: UserContext, resource: str, action: str,
                        required_permission: Permission = None) -> Tuple[bool, Optional[str]]:
    """
    Convenience function for validating user access.
    
    Args:
        user_context: User context
        resource: Resource being accessed
        action: Action being performed
        required_permission: Required permission
        
    Returns:
        Tuple of (is_authorized, error_message)
    """
    return access_control_validator.validate_access(user_context, resource, action, required_permission)
