"""
MS5.0 Floor Dashboard - Content Sanitization Module

Advanced content sanitization system for preventing XSS attacks and ensuring
data integrity. Designed for production-grade security with comprehensive
threat detection and neutralization.

Architecture: Starship-grade sanitization engine that treats every piece of content
as potentially malicious until proven safe.
"""

import html
import re
import json
from typing import Any, Dict, List, Optional, Union
from urllib.parse import urlparse, urljoin
import bleach
import markdown
from markupsafe import Markup, escape
import structlog

logger = structlog.get_logger()


class XSSProtection:
    """
    Comprehensive XSS protection system.
    
    Provides multiple layers of XSS protection including input sanitization,
    output encoding, and content filtering.
    """
    
    # Dangerous HTML tags and attributes
    DANGEROUS_TAGS = {
        'script', 'iframe', 'object', 'embed', 'applet', 'form', 'input',
        'textarea', 'button', 'select', 'option', 'link', 'meta', 'style',
        'base', 'frame', 'frameset', 'noframes'
    }
    
    DANGEROUS_ATTRIBUTES = {
        'onload', 'onerror', 'onclick', 'onmouseover', 'onmouseout',
        'onfocus', 'onblur', 'onchange', 'onsubmit', 'onreset',
        'onkeydown', 'onkeyup', 'onkeypress', 'onmousedown', 'onmouseup',
        'onmousemove', 'onmouseenter', 'onmouseleave', 'ondblclick',
        'oncontextmenu', 'onwheel', 'ontouchstart', 'ontouchend',
        'ontouchmove', 'ontouchcancel', 'javascript:', 'vbscript:',
        'data:', 'file:', 'ftp:', 'gopher:', 'jar:', 'mailto:', 'news:',
        'nntp:', 'sftp:', 'ssh:', 'tel:', 'telnet:', 'view-source:'
    }
    
    # Safe HTML tags for content
    SAFE_TAGS = {
        'p', 'br', 'strong', 'em', 'u', 'i', 'b', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
        'ul', 'ol', 'li', 'blockquote', 'code', 'pre', 'a', 'img', 'table',
        'thead', 'tbody', 'tr', 'th', 'td', 'div', 'span', 'hr'
    }
    
    # Safe HTML attributes
    SAFE_ATTRIBUTES = {
        'href', 'src', 'alt', 'title', 'class', 'id', 'style', 'width', 'height',
        'colspan', 'rowspan', 'align', 'valign', 'border', 'cellpadding', 'cellspacing'
    }
    
    def __init__(self):
        """Initialize XSS protection system."""
        self.bleach_config = {
            'tags': self.SAFE_TAGS,
            'attributes': {
                '*': ['class', 'id', 'style'],
                'a': ['href', 'title', 'target'],
                'img': ['src', 'alt', 'title', 'width', 'height'],
                'table': ['border', 'cellpadding', 'cellspacing', 'width'],
                'td': ['colspan', 'rowspan', 'align', 'valign'],
                'th': ['colspan', 'rowspan', 'align', 'valign']
            },
            'styles': ['color', 'background-color', 'font-size', 'font-weight', 'text-align'],
            'protocols': ['http', 'https', 'mailto'],
            'strip': True,
            'strip_comments': True
        }
    
    def sanitize_html(self, content: str) -> str:
        """
        Sanitize HTML content to prevent XSS attacks.
        
        Args:
            content: HTML content to sanitize
            
        Returns:
            Sanitized HTML content
        """
        if not content or not isinstance(content, str):
            return ""
        
        # Use bleach for comprehensive HTML sanitization
        sanitized = bleach.clean(
            content,
            tags=self.bleach_config['tags'],
            attributes=self.bleach_config['attributes'],
            styles=self.bleach_config['styles'],
            protocols=self.bleach_config['protocols'],
            strip=self.bleach_config['strip'],
            strip_comments=self.bleach_config['strip_comments']
        )
        
        # Additional security checks
        sanitized = self._remove_dangerous_patterns(sanitized)
        sanitized = self._validate_urls(sanitized)
        
        return sanitized
    
    def sanitize_text(self, content: str) -> str:
        """
        Sanitize plain text content.
        
        Args:
            content: Text content to sanitize
            
        Returns:
            Sanitized text content
        """
        if not content or not isinstance(content, str):
            return ""
        
        # HTML escape the content
        sanitized = html.escape(content, quote=True)
        
        # Remove any remaining dangerous patterns
        sanitized = self._remove_dangerous_patterns(sanitized)
        
        return sanitized
    
    def sanitize_json(self, data: Any) -> Any:
        """
        Sanitize JSON data recursively.
        
        Args:
            data: JSON data to sanitize
            
        Returns:
            Sanitized JSON data
        """
        if isinstance(data, dict):
            return {key: self.sanitize_json(value) for key, value in data.items()}
        elif isinstance(data, list):
            return [self.sanitize_json(item) for item in data]
        elif isinstance(data, str):
            return self.sanitize_text(data)
        else:
            return data
    
    def sanitize_url(self, url: str, base_url: str = None) -> str:
        """
        Sanitize and validate URL.
        
        Args:
            url: URL to sanitize
            base_url: Base URL for relative URLs
            
        Returns:
            Sanitized URL
        """
        if not url or not isinstance(url, str):
            return ""
        
        # Remove dangerous protocols
        dangerous_protocols = ['javascript:', 'vbscript:', 'data:', 'file:', 'ftp:']
        url_lower = url.lower()
        
        for protocol in dangerous_protocols:
            if url_lower.startswith(protocol):
                raise ValueError(f"Dangerous protocol detected: {protocol}")
        
        # Parse and validate URL
        try:
            parsed = urlparse(url)
            
            # Only allow http and https protocols
            if parsed.scheme and parsed.scheme not in ['http', 'https', 'mailto']:
                raise ValueError(f"Unsafe protocol: {parsed.scheme}")
            
            # If relative URL and base_url provided, make absolute
            if not parsed.scheme and base_url:
                url = urljoin(base_url, url)
                parsed = urlparse(url)
            
            return url
            
        except Exception as e:
            logger.warning("URL sanitization failed", url=url, error=str(e))
            return ""
    
    def _remove_dangerous_patterns(self, content: str) -> str:
        """Remove dangerous patterns from content."""
        # Remove script tags and their content
        content = re.sub(r'<script[^>]*>.*?</script>', '', content, flags=re.IGNORECASE | re.DOTALL)
        
        # Remove javascript: and vbscript: protocols
        content = re.sub(r'javascript:', '', content, flags=re.IGNORECASE)
        content = re.sub(r'vbscript:', '', content, flags=re.IGNORECASE)
        
        # Remove event handlers
        event_patterns = [
            r'on\w+\s*=\s*["\'][^"\']*["\']',
            r'on\w+\s*=\s*[^>\s]+'
        ]
        
        for pattern in event_patterns:
            content = re.sub(pattern, '', content, flags=re.IGNORECASE)
        
        # Remove dangerous CSS expressions
        content = re.sub(r'expression\s*\([^)]*\)', '', content, flags=re.IGNORECASE)
        content = re.sub(r'url\s*\(\s*javascript:', '', content, flags=re.IGNORECASE)
        
        return content
    
    def _validate_urls(self, content: str) -> str:
        """Validate and sanitize URLs in content."""
        # Find all URLs in href and src attributes
        url_pattern = r'(href|src)\s*=\s*["\']([^"\']*)["\']'
        
        def replace_url(match):
            attr_name = match.group(1)
            url = match.group(2)
            
            try:
                sanitized_url = self.sanitize_url(url)
                return f'{attr_name}="{sanitized_url}"'
            except ValueError:
                # Remove the attribute if URL is dangerous
                return ''
        
        return re.sub(url_pattern, replace_url, content, flags=re.IGNORECASE)


class ContentSanitizer:
    """
    Comprehensive content sanitization system.
    
    Provides sanitization for various content types including HTML, text,
    JSON, and URLs with configurable security levels.
    """
    
    def __init__(self, security_level: str = "high"):
        """
        Initialize content sanitizer.
        
        Args:
            security_level: Security level ("low", "medium", "high", "maximum")
        """
        self.security_level = security_level
        self.xss_protection = XSSProtection()
        
        # Configure sanitization based on security level
        self._configure_security_level()
    
    def sanitize(self, content: Any, content_type: str = "text") -> Any:
        """
        Sanitize content based on its type.
        
        Args:
            content: Content to sanitize
            content_type: Type of content ("html", "text", "json", "url")
            
        Returns:
            Sanitized content
        """
        if content is None:
            return None
        
        sanitization_methods = {
            "html": self.sanitize_html,
            "text": self.sanitize_text,
            "json": self.sanitize_json,
            "url": self.sanitize_url
        }
        
        if content_type not in sanitization_methods:
            raise ValueError(f"Unknown content type: {content_type}")
        
        return sanitization_methods[content_type](content)
    
    def sanitize_html(self, content: str) -> str:
        """Sanitize HTML content."""
        return self.xss_protection.sanitize_html(content)
    
    def sanitize_text(self, content: str) -> str:
        """Sanitize text content."""
        return self.xss_protection.sanitize_text(content)
    
    def sanitize_json(self, data: Any) -> Any:
        """Sanitize JSON data."""
        return self.xss_protection.sanitize_json(data)
    
    def sanitize_url(self, url: str, base_url: str = None) -> str:
        """Sanitize URL."""
        return self.xss_protection.sanitize_url(url, base_url)
    
    def sanitize_user_input(self, data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Sanitize user input data comprehensively.
        
        Args:
            data: User input data to sanitize
            
        Returns:
            Sanitized data
        """
        sanitized_data = {}
        
        for key, value in data.items():
            # Determine content type based on field name
            content_type = self._determine_content_type(key, value)
            
            try:
                sanitized_data[key] = self.sanitize(value, content_type)
            except Exception as e:
                logger.warning(
                    "Content sanitization failed",
                    field=key,
                    content_type=content_type,
                    error=str(e)
                )
                # Fall back to text sanitization
                sanitized_data[key] = self.sanitize_text(str(value))
        
        return sanitized_data
    
    def _configure_security_level(self):
        """Configure sanitization based on security level."""
        if self.security_level == "maximum":
            # Maximum security - strip all HTML
            self.xss_protection.bleach_config['tags'] = set()
            self.xss_protection.bleach_config['attributes'] = {}
        elif self.security_level == "high":
            # High security - minimal HTML allowed
            self.xss_protection.bleach_config['tags'] = {'p', 'br', 'strong', 'em'}
            self.xss_protection.bleach_config['attributes'] = {'*': ['class']}
        elif self.security_level == "medium":
            # Medium security - standard HTML allowed
            pass  # Use default configuration
        elif self.security_level == "low":
            # Low security - more HTML allowed
            self.xss_protection.bleach_config['tags'].update({
                'iframe', 'embed', 'object', 'form', 'input', 'textarea'
            })
            self.xss_protection.bleach_config['attributes']['*'].extend([
                'onclick', 'onload', 'onerror'
            ])
        else:
            raise ValueError(f"Invalid security level: {self.security_level}")
    
    def _determine_content_type(self, field_name: str, value: Any) -> str:
        """Determine content type based on field name and value."""
        field_lower = field_name.lower()
        
        # URL fields
        if any(keyword in field_lower for keyword in ['url', 'link', 'href', 'src']):
            return "url"
        
        # HTML fields
        if any(keyword in field_lower for keyword in ['html', 'content', 'description', 'body']):
            return "html"
        
        # JSON fields
        if isinstance(value, (dict, list)):
            return "json"
        
        # Default to text
        return "text"


# Global sanitizer instances
default_sanitizer = ContentSanitizer(security_level="high")
maximum_sanitizer = ContentSanitizer(security_level="maximum")


def sanitize_content(content: Any, content_type: str = "text", 
                    security_level: str = "high") -> Any:
    """
    Convenience function for content sanitization.
    
    Args:
        content: Content to sanitize
        content_type: Type of content
        security_level: Security level for sanitization
        
    Returns:
        Sanitized content
    """
    if security_level == "maximum":
        sanitizer = maximum_sanitizer
    else:
        sanitizer = default_sanitizer
    
    return sanitizer.sanitize(content, content_type)


def sanitize_user_input(data: Dict[str, Any], security_level: str = "high") -> Dict[str, Any]:
    """
    Convenience function for user input sanitization.
    
    Args:
        data: User input data
        security_level: Security level for sanitization
        
    Returns:
        Sanitized data
    """
    if security_level == "maximum":
        sanitizer = maximum_sanitizer
    else:
        sanitizer = default_sanitizer
    
    return sanitizer.sanitize_user_input(data)
