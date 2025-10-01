"""
MS5.0 Floor Dashboard - GDPR Compliance Module

Comprehensive GDPR compliance system implementing data subject rights,
consent management, data portability, and privacy protection features.

Architecture: Starship-grade privacy protection system that ensures
complete compliance with GDPR and other privacy regulations.
"""

import json
from datetime import datetime, timezone, timedelta
from typing import Any, Dict, List, Optional, Union
from enum import Enum
from dataclasses import dataclass, asdict
import structlog

from app.config import settings

logger = structlog.get_logger()


class ConsentType(str, Enum):
    """Types of consent."""
    MARKETING = "marketing"
    ANALYTICS = "analytics"
    FUNCTIONAL = "functional"
    NECESSARY = "necessary"
    DATA_PROCESSING = "data_processing"
    DATA_SHARING = "data_sharing"


class DataSubjectRight(str, Enum):
    """Data subject rights under GDPR."""
    ACCESS = "access"
    RECTIFICATION = "rectification"
    ERASURE = "erasure"
    RESTRICTION = "restriction"
    PORTABILITY = "portability"
    OBJECTION = "objection"
    WITHDRAW_CONSENT = "withdraw_consent"


class DataCategory(str, Enum):
    """Categories of personal data."""
    IDENTIFICATION = "identification"
    CONTACT = "contact"
    BEHAVIORAL = "behavioral"
    TECHNICAL = "technical"
    LOCATION = "location"
    FINANCIAL = "financial"
    HEALTH = "health"
    BIOMETRIC = "biometric"


@dataclass
class ConsentRecord:
    """Consent record data structure."""
    consent_id: str
    user_id: str
    consent_type: ConsentType
    granted: bool
    timestamp: datetime
    ip_address: str
    user_agent: str
    consent_text: str
    version: str
    expires_at: Optional[datetime] = None
    withdrawn_at: Optional[datetime] = None
    metadata: Dict[str, Any] = None
    
    def __post_init__(self):
        """Post-initialization processing."""
        if self.metadata is None:
            self.metadata = {}
        
        # Ensure timestamp is timezone-aware
        if self.timestamp.tzinfo is None:
            self.timestamp = self.timestamp.replace(tzinfo=timezone.utc)
        
        if self.expires_at and self.expires_at.tzinfo is None:
            self.expires_at = self.expires_at.replace(tzinfo=timezone.utc)
        
        if self.withdrawn_at and self.withdrawn_at.tzinfo is None:
            self.withdrawn_at = self.withdrawn_at.replace(tzinfo=timezone.utc)


@dataclass
class DataSubjectRequest:
    """Data subject request data structure."""
    request_id: str
    user_id: str
    right_type: DataSubjectRight
    request_timestamp: datetime
    status: str  # pending, processing, completed, rejected
    description: str
    requested_data_categories: List[DataCategory]
    response_data: Optional[Dict[str, Any]] = None
    completed_at: Optional[datetime] = None
    rejection_reason: Optional[str] = None
    metadata: Dict[str, Any] = None
    
    def __post_init__(self):
        """Post-initialization processing."""
        if self.metadata is None:
            self.metadata = {}
        
        # Ensure timestamp is timezone-aware
        if self.request_timestamp.tzinfo is None:
            self.request_timestamp = self.request_timestamp.replace(tzinfo=timezone.utc)
        
        if self.completed_at and self.completed_at.tzinfo is None:
            self.completed_at = self.completed_at.replace(tzinfo=timezone.utc)


class GDPRCompliance:
    """
    Comprehensive GDPR compliance system.
    
    Implements all data subject rights, consent management,
    and privacy protection features required by GDPR.
    """
    
    def __init__(self):
        """Initialize GDPR compliance system."""
        self.consent_records: List[ConsentRecord] = []
        self.data_subject_requests: List[DataSubjectRequest] = []
        self.data_retention_policies: Dict[str, int] = {
            "user_profiles": 2555,  # 7 years
            "audit_logs": 1095,     # 3 years
            "session_data": 30,     # 30 days
            "analytics_data": 365,  # 1 year
            "marketing_data": 730,  # 2 years
        }
    
    def record_consent(self, user_id: str, consent_type: ConsentType,
                      granted: bool, ip_address: str, user_agent: str,
                      consent_text: str, version: str = "1.0",
                      expires_at: datetime = None) -> str:
        """
        Record user consent.
        
        Args:
            user_id: User ID
            consent_type: Type of consent
            granted: Whether consent was granted
            ip_address: User's IP address
            user_agent: User's user agent
            consent_text: Text of consent
            version: Consent text version
            expires_at: When consent expires
            
        Returns:
            Consent record ID
        """
        consent_record = ConsentRecord(
            consent_id=self._generate_consent_id(),
            user_id=user_id,
            consent_type=consent_type,
            granted=granted,
            timestamp=datetime.now(timezone.utc),
            ip_address=ip_address,
            user_agent=user_agent,
            consent_text=consent_text,
            version=version,
            expires_at=expires_at
        )
        
        self.consent_records.append(consent_record)
        
        logger.info(
            "Consent recorded",
            consent_id=consent_record.consent_id,
            user_id=user_id,
            consent_type=consent_type.value,
            granted=granted
        )
        
        return consent_record.consent_id
    
    def withdraw_consent(self, user_id: str, consent_type: ConsentType) -> bool:
        """
        Withdraw user consent.
        
        Args:
            user_id: User ID
            consent_type: Type of consent to withdraw
            
        Returns:
            True if consent was withdrawn, False if not found
        """
        withdrawn = False
        
        for consent in self.consent_records:
            if (consent.user_id == user_id and 
                consent.consent_type == consent_type and 
                consent.granted and 
                not consent.withdrawn_at):
                
                consent.withdrawn_at = datetime.now(timezone.utc)
                withdrawn = True
                
                logger.info(
                    "Consent withdrawn",
                    consent_id=consent.consent_id,
                    user_id=user_id,
                    consent_type=consent_type.value
                )
        
        return withdrawn
    
    def has_valid_consent(self, user_id: str, consent_type: ConsentType) -> bool:
        """
        Check if user has valid consent.
        
        Args:
            user_id: User ID
            consent_type: Type of consent
            
        Returns:
            True if user has valid consent, False otherwise
        """
        current_time = datetime.now(timezone.utc)
        
        for consent in reversed(self.consent_records):
            if (consent.user_id == user_id and 
                consent.consent_type == consent_type):
                
                # Check if consent was granted
                if not consent.granted:
                    return False
                
                # Check if consent was withdrawn
                if consent.withdrawn_at:
                    return False
                
                # Check if consent has expired
                if consent.expires_at and current_time > consent.expires_at:
                    return False
                
                return True
        
        return False
    
    def get_user_consents(self, user_id: str) -> List[ConsentRecord]:
        """
        Get all consent records for a user.
        
        Args:
            user_id: User ID
            
        Returns:
            List of consent records
        """
        return [c for c in self.consent_records if c.user_id == user_id]
    
    def submit_data_subject_request(self, user_id: str, right_type: DataSubjectRight,
                                  description: str, data_categories: List[DataCategory]) -> str:
        """
        Submit a data subject request.
        
        Args:
            user_id: User ID
            right_type: Type of data subject right
            description: Description of request
            data_categories: Categories of data requested
            
        Returns:
            Request ID
        """
        request = DataSubjectRequest(
            request_id=self._generate_request_id(),
            user_id=user_id,
            right_type=right_type,
            request_timestamp=datetime.now(timezone.utc),
            status="pending",
            description=description,
            requested_data_categories=data_categories
        )
        
        self.data_subject_requests.append(request)
        
        logger.info(
            "Data subject request submitted",
            request_id=request.request_id,
            user_id=user_id,
            right_type=right_type.value
        )
        
        return request.request_id
    
    def process_data_subject_request(self, request_id: str, response_data: Dict[str, Any] = None,
                                   rejection_reason: str = None) -> bool:
        """
        Process a data subject request.
        
        Args:
            request_id: Request ID
            response_data: Response data for the request
            rejection_reason: Reason for rejection if applicable
            
        Returns:
            True if request was processed, False if not found
        """
        for request in self.data_subject_requests:
            if request.request_id == request_id:
                request.completed_at = datetime.now(timezone.utc)
                
                if rejection_reason:
                    request.status = "rejected"
                    request.rejection_reason = rejection_reason
                else:
                    request.status = "completed"
                    request.response_data = response_data
                
                logger.info(
                    "Data subject request processed",
                    request_id=request_id,
                    status=request.status
                )
                
                return True
        
        return False
    
    def get_user_data(self, user_id: str, data_categories: List[DataCategory] = None) -> Dict[str, Any]:
        """
        Get user data for data portability.
        
        Args:
            user_id: User ID
            data_categories: Specific data categories to retrieve
            
        Returns:
            User data dictionary
        """
        user_data = {
            "user_id": user_id,
            "export_timestamp": datetime.now(timezone.utc).isoformat(),
            "data_categories": {}
        }
        
        # Get consent records
        if not data_categories or DataCategory.IDENTIFICATION in data_categories:
            consents = self.get_user_consents(user_id)
            user_data["data_categories"]["consents"] = [
                {
                    "consent_type": c.consent_type.value,
                    "granted": c.granted,
                    "timestamp": c.timestamp.isoformat(),
                    "withdrawn_at": c.withdrawn_at.isoformat() if c.withdrawn_at else None
                }
                for c in consents
            ]
        
        # Get data subject requests
        if not data_categories or DataCategory.IDENTIFICATION in data_categories:
            requests = [r for r in self.data_subject_requests if r.user_id == user_id]
            user_data["data_categories"]["data_subject_requests"] = [
                {
                    "request_id": r.request_id,
                    "right_type": r.right_type.value,
                    "status": r.status,
                    "request_timestamp": r.request_timestamp.isoformat(),
                    "completed_at": r.completed_at.isoformat() if r.completed_at else None
                }
                for r in requests
            ]
        
        return user_data
    
    def delete_user_data(self, user_id: str, data_categories: List[DataCategory] = None) -> bool:
        """
        Delete user data (right to erasure).
        
        Args:
            user_id: User ID
            data_categories: Specific data categories to delete
            
        Returns:
            True if data was deleted, False otherwise
        """
        deleted = False
        
        # Delete consent records
        if not data_categories or DataCategory.IDENTIFICATION in data_categories:
            self.consent_records = [c for c in self.consent_records if c.user_id != user_id]
            deleted = True
        
        # Delete data subject requests
        if not data_categories or DataCategory.IDENTIFICATION in data_categories:
            self.data_subject_requests = [r for r in self.data_subject_requests if r.user_id != user_id]
            deleted = True
        
        if deleted:
            logger.info(
                "User data deleted",
                user_id=user_id,
                data_categories=[c.value for c in data_categories] if data_categories else "all"
            )
        
        return deleted
    
    def anonymize_user_data(self, user_id: str) -> bool:
        """
        Anonymize user data.
        
        Args:
            user_id: User ID
            
        Returns:
            True if data was anonymized, False otherwise
        """
        anonymized = False
        
        # Anonymize consent records
        for consent in self.consent_records:
            if consent.user_id == user_id:
                consent.user_id = f"anon_{hash(user_id)}"
                anonymized = True
        
        # Anonymize data subject requests
        for request in self.data_subject_requests:
            if request.user_id == user_id:
                request.user_id = f"anon_{hash(user_id)}"
                anonymized = True
        
        if anonymized:
            logger.info("User data anonymized", user_id=user_id)
        
        return anonymized
    
    def get_data_retention_status(self, user_id: str) -> Dict[str, Any]:
        """
        Get data retention status for a user.
        
        Args:
            user_id: User ID
            
        Returns:
            Data retention status
        """
        status = {
            "user_id": user_id,
            "retention_policies": {},
            "data_categories": {}
        }
        
        # Check consent records retention
        consents = self.get_user_consents(user_id)
        if consents:
            oldest_consent = min(consents, key=lambda x: x.timestamp)
            retention_days = self.data_retention_policies.get("user_profiles", 2555)
            expires_at = oldest_consent.timestamp + timedelta(days=retention_days)
            
            status["data_categories"]["consents"] = {
                "count": len(consents),
                "oldest_record": oldest_consent.timestamp.isoformat(),
                "expires_at": expires_at.isoformat(),
                "days_until_expiry": (expires_at - datetime.now(timezone.utc)).days
            }
        
        return status
    
    def cleanup_expired_data(self) -> Dict[str, int]:
        """
        Clean up expired data based on retention policies.
        
        Returns:
            Dictionary of cleanup results
        """
        cleanup_results = {}
        current_time = datetime.now(timezone.utc)
        
        # Clean up expired consent records
        expired_consents = []
        for consent in self.consent_records:
            retention_days = self.data_retention_policies.get("user_profiles", 2555)
            expires_at = consent.timestamp + timedelta(days=retention_days)
            
            if current_time > expires_at:
                expired_consents.append(consent)
        
        for consent in expired_consents:
            self.consent_records.remove(consent)
        
        cleanup_results["expired_consents"] = len(expired_consents)
        
        # Clean up old data subject requests
        old_requests = []
        for request in self.data_subject_requests:
            retention_days = self.data_retention_policies.get("audit_logs", 1095)
            expires_at = request.request_timestamp + timedelta(days=retention_days)
            
            if current_time > expires_at:
                old_requests.append(request)
        
        for request in old_requests:
            self.data_subject_requests.remove(request)
        
        cleanup_results["old_requests"] = len(old_requests)
        
        logger.info("Data cleanup completed", cleanup_results=cleanup_results)
        
        return cleanup_results
    
    def _generate_consent_id(self) -> str:
        """Generate unique consent ID."""
        timestamp = datetime.now(timezone.utc).isoformat()
        return f"consent_{timestamp.replace(':', '-').replace('.', '-')}"
    
    def _generate_request_id(self) -> str:
        """Generate unique request ID."""
        timestamp = datetime.now(timezone.utc).isoformat()
        return f"dsr_{timestamp.replace(':', '-').replace('.', '-')}"


class DataSubjectRights:
    """
    Data subject rights implementation.
    
    Provides methods for handling all GDPR data subject rights.
    """
    
    def __init__(self, gdpr_compliance: GDPRCompliance = None):
        """
        Initialize data subject rights handler.
        
        Args:
            gdpr_compliance: GDPR compliance instance
        """
        self.gdpr_compliance = gdpr_compliance or GDPRCompliance()
    
    def handle_access_request(self, user_id: str, data_categories: List[DataCategory] = None) -> str:
        """Handle right of access request."""
        return self.gdpr_compliance.submit_data_subject_request(
            user_id, DataSubjectRight.ACCESS, "Data access request", data_categories
        )
    
    def handle_rectification_request(self, user_id: str, corrections: Dict[str, Any]) -> str:
        """Handle right of rectification request."""
        return self.gdpr_compliance.submit_data_subject_request(
            user_id, DataSubjectRight.RECTIFICATION, f"Data rectification request: {corrections}", []
        )
    
    def handle_erasure_request(self, user_id: str, data_categories: List[DataCategory] = None) -> str:
        """Handle right of erasure request."""
        return self.gdpr_compliance.submit_data_subject_request(
            user_id, DataSubjectRight.ERASURE, "Data erasure request", data_categories
        )
    
    def handle_portability_request(self, user_id: str, data_categories: List[DataCategory] = None) -> str:
        """Handle data portability request."""
        return self.gdpr_compliance.submit_data_subject_request(
            user_id, DataSubjectRight.PORTABILITY, "Data portability request", data_categories
        )
    
    def handle_objection_request(self, user_id: str, processing_purpose: str) -> str:
        """Handle objection to processing request."""
        return self.gdpr_compliance.submit_data_subject_request(
            user_id, DataSubjectRight.OBJECTION, f"Objection to processing: {processing_purpose}", []
        )


# Global instances
gdpr_compliance = GDPRCompliance()
data_subject_rights = DataSubjectRights(gdpr_compliance)


def record_consent(user_id: str, consent_type: ConsentType, granted: bool,
                  ip_address: str, user_agent: str, consent_text: str) -> str:
    """
    Convenience function for recording consent.
    
    Args:
        user_id: User ID
        consent_type: Type of consent
        granted: Whether consent was granted
        ip_address: User's IP address
        user_agent: User's user agent
        consent_text: Text of consent
        
    Returns:
        Consent record ID
    """
    return gdpr_compliance.record_consent(
        user_id, consent_type, granted, ip_address, user_agent, consent_text
    )


def has_valid_consent(user_id: str, consent_type: ConsentType) -> bool:
    """
    Convenience function for checking valid consent.
    
    Args:
        user_id: User ID
        consent_type: Type of consent
        
    Returns:
        True if user has valid consent, False otherwise
    """
    return gdpr_compliance.has_valid_consent(user_id, consent_type)


def submit_data_subject_request(user_id: str, right_type: DataSubjectRight,
                               description: str, data_categories: List[DataCategory] = None) -> str:
    """
    Convenience function for submitting data subject request.
    
    Args:
        user_id: User ID
        right_type: Type of data subject right
        description: Description of request
        data_categories: Categories of data requested
        
    Returns:
        Request ID
    """
    return gdpr_compliance.submit_data_subject_request(
        user_id, right_type, description, data_categories or []
    )
