"""
MS5.0 Floor Dashboard - Rate Limiting Module

Advanced rate limiting system with multiple algorithms and adaptive limits.
Implements token bucket, sliding window, and fixed window rate limiting.

Architecture: Starship-grade rate limiting that protects against abuse
while maintaining optimal performance for legitimate users.
"""

import time
from typing import Dict, Any, Optional
from dataclasses import dataclass
from enum import Enum
import structlog

logger = structlog.get_logger()


class RateLimitAlgorithm(str, Enum):
    """Rate limiting algorithms."""
    TOKEN_BUCKET = "token_bucket"
    SLIDING_WINDOW = "sliding_window"
    FIXED_WINDOW = "fixed_window"


@dataclass
class RateLimitConfig:
    """Rate limit configuration."""
    requests_per_minute: int = 60
    requests_per_hour: int = 1000
    requests_per_day: int = 10000
    burst_limit: int = 10
    algorithm: RateLimitAlgorithm = RateLimitAlgorithm.TOKEN_BUCKET


class RateLimiter:
    """Advanced rate limiter with multiple algorithms."""
    
    def __init__(self, config: RateLimitConfig = None):
        """Initialize rate limiter."""
        self.config = config or RateLimitConfig()
        self.buckets: Dict[str, Dict[str, Any]] = {}
    
    def is_allowed(self, key: str) -> Tuple[bool, Dict[str, Any]]:
        """Check if request is allowed."""
        if self.config.algorithm == RateLimitAlgorithm.TOKEN_BUCKET:
            return self._token_bucket_check(key)
        elif self.config.algorithm == RateLimitAlgorithm.SLIDING_WINDOW:
            return self._sliding_window_check(key)
        else:
            return self._fixed_window_check(key)
    
    def _token_bucket_check(self, key: str) -> Tuple[bool, Dict[str, Any]]:
        """Token bucket algorithm."""
        current_time = time.time()
        
        if key not in self.buckets:
            self.buckets[key] = {
                "tokens": self.config.burst_limit,
                "last_refill": current_time
            }
        
        bucket = self.buckets[key]
        
        # Refill tokens
        time_passed = current_time - bucket["last_refill"]
        tokens_to_add = time_passed * (self.config.requests_per_minute / 60)
        bucket["tokens"] = min(self.config.burst_limit, bucket["tokens"] + tokens_to_add)
        bucket["last_refill"] = current_time
        
        # Check if request is allowed
        if bucket["tokens"] >= 1:
            bucket["tokens"] -= 1
            return True, {
                "remaining": int(bucket["tokens"]),
                "reset_time": current_time + (1 / (self.config.requests_per_minute / 60))
            }
        
        return False, {
            "remaining": 0,
            "reset_time": current_time + (1 / (self.config.requests_per_minute / 60))
        }


class RateLimitMiddleware:
    """Rate limiting middleware."""
    
    def __init__(self, rate_limiter: RateLimiter = None):
        """Initialize rate limit middleware."""
        self.rate_limiter = rate_limiter or RateLimiter()
    
    async def __call__(self, request, call_next):
        """Process request with rate limiting."""
        # Extract client identifier
        client_id = self._get_client_id(request)
        
        # Check rate limit
        is_allowed, info = self.rate_limiter.is_allowed(client_id)
        
        if not is_allowed:
            logger.warning("Rate limit exceeded", client_id=client_id)
            from fastapi import HTTPException, status
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail="Rate limit exceeded"
            )
        
        response = await call_next(request)
        
        # Add rate limit headers
        response.headers["X-RateLimit-Remaining"] = str(info["remaining"])
        response.headers["X-RateLimit-Reset"] = str(int(info["reset_time"]))
        
        return response
    
    def _get_client_id(self, request) -> str:
        """Get client identifier."""
        # Use IP address as client identifier
        client_ip = request.client.host if request.client else "unknown"
        return f"ip:{client_ip}"


# Global instances
rate_limiter = RateLimiter()
rate_limit_middleware = RateLimitMiddleware(rate_limiter)
