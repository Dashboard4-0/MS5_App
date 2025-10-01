"""
MS5.0 Floor Dashboard - SQL Injection Prevention Module

Comprehensive SQL injection prevention system with query sanitization,
parameterized queries, and advanced threat detection.

Architecture: Starship-grade SQL injection prevention that treats every
database interaction as potentially hostile until proven safe.
"""

import re
from typing import Any, Dict, List, Optional, Union, Tuple
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession
import structlog

logger = structlog.get_logger()


class SQLInjectionPrevention:
    """
    Comprehensive SQL injection prevention system.
    
    Provides multiple layers of protection including:
    - Query sanitization
    - Parameter validation
    - Pattern detection
    - Query analysis
    """
    
    # SQL injection patterns
    SQL_INJECTION_PATTERNS = [
        # Basic SQL keywords
        r"\b(SELECT|INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|EXEC|EXECUTE)\b",
        r"\b(UNION|JOIN|INNER|OUTER|LEFT|RIGHT|FULL)\b",
        
        # Comment patterns
        r"--.*$",
        r"/\*.*?\*/",
        r"#.*$",
        
        # Boolean-based blind SQL injection
        r"\b(OR|AND)\s+\d+\s*=\s*\d+",
        r"\b(OR|AND)\s+['\"]?\w+['\"]?\s*=\s*['\"]?\w+['\"]?",
        
        # Union-based SQL injection
        r"\bUNION\s+SELECT\b",
        r"\bUNION\s+ALL\s+SELECT\b",
        
        # Time-based blind SQL injection
        r"\b(SLEEP|WAITFOR|DELAY)\s*\(",
        r"\bBENCHMARK\s*\(",
        
        # Error-based SQL injection
        r"\b(EXTRACTVALUE|UPDATEXML|FLOOR|RAND)\s*\(",
        
        # Stacked queries
        r";\s*(SELECT|INSERT|UPDATE|DELETE|DROP|CREATE|ALTER)",
        
        # Function calls
        r"\b(CHAR|ASCII|ORD|HEX|UNHEX|CONCAT|SUBSTRING|LENGTH)\s*\(",
        
        # Database-specific functions
        r"\b(LOAD_FILE|INTO\s+OUTFILE|INTO\s+DUMPFILE)\b",
        r"\b(INFORMATION_SCHEMA|SYSTEM_TABLES|MYSQL\.USER)\b",
        
        # Conditional statements
        r"\b(IF|CASE|WHEN|THEN|ELSE|END)\b",
        
        # System functions
        r"\b(USER|DATABASE|VERSION|CONNECTION_ID)\s*\(\s*\)",
        r"\b(@@VERSION|@@DATABASE|@@HOSTNAME)\b",
    ]
    
    # Dangerous SQL functions
    DANGEROUS_FUNCTIONS = {
        'LOAD_FILE', 'INTO OUTFILE', 'INTO DUMPFILE', 'EXEC', 'EXECUTE',
        'SP_EXECUTESQL', 'EVAL', 'EXECUTE_IMMEDIATE'
    }
    
    # Safe parameter patterns
    SAFE_PARAMETER_PATTERNS = {
        'uuid': r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
        'integer': r'^\d+$',
        'positive_integer': r'^[1-9]\d*$',
        'alphanumeric': r'^[a-zA-Z0-9]+$',
        'alphanumeric_with_underscore': r'^[a-zA-Z0-9_]+$',
        'equipment_code': r'^[A-Z0-9_-]+$',
        'username': r'^[a-zA-Z0-9_-]+$',
        'email': r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    }
    
    def __init__(self):
        """Initialize SQL injection prevention system."""
        self.compiled_patterns = [
            re.compile(pattern, re.IGNORECASE | re.MULTILINE | re.DOTALL)
            for pattern in self.SQL_INJECTION_PATTERNS
        ]
    
    def detect_sql_injection(self, query: str, parameters: Dict[str, Any] = None) -> Tuple[bool, List[str]]:
        """
        Detect potential SQL injection in query and parameters.
        
        Args:
            query: SQL query to analyze
            parameters: Query parameters
            
        Returns:
            Tuple of (is_safe, detected_threats)
        """
        threats = []
        
        # Check query for SQL injection patterns
        query_threats = self._analyze_query(query)
        threats.extend(query_threats)
        
        # Check parameters for SQL injection patterns
        if parameters:
            param_threats = self._analyze_parameters(parameters)
            threats.extend(param_threats)
        
        is_safe = len(threats) == 0
        
        if not is_safe:
            logger.warning(
                "SQL injection threats detected",
                query=query[:100],
                threats=threats,
                parameters=parameters
            )
        
        return is_safe, threats
    
    def sanitize_query(self, query: str) -> str:
        """
        Sanitize SQL query by removing dangerous patterns.
        
        Args:
            query: SQL query to sanitize
            
        Returns:
            Sanitized query
        """
        sanitized_query = query
        
        # Remove comments
        sanitized_query = re.sub(r"--.*$", "", sanitized_query, flags=re.MULTILINE)
        sanitized_query = re.sub(r"/\*.*?\*/", "", sanitized_query, flags=re.DOTALL)
        sanitized_query = re.sub(r"#.*$", "", sanitized_query, flags=re.MULTILINE)
        
        # Remove dangerous functions
        for func in self.DANGEROUS_FUNCTIONS:
            pattern = rf"\b{re.escape(func)}\s*\("
            sanitized_query = re.sub(pattern, "", sanitized_query, flags=re.IGNORECASE)
        
        return sanitized_query.strip()
    
    def validate_parameter(self, value: Any, param_type: str = None, 
                         pattern: str = None) -> Tuple[bool, str]:
        """
        Validate parameter value against expected type/pattern.
        
        Args:
            value: Parameter value to validate
            param_type: Expected parameter type
            pattern: Custom validation pattern
            
        Returns:
            Tuple of (is_valid, error_message)
        """
        if value is None:
            return True, ""
        
        value_str = str(value)
        
        # Check for SQL injection patterns
        for compiled_pattern in self.compiled_patterns:
            if compiled_pattern.search(value_str):
                return False, f"SQL injection pattern detected in parameter"
        
        # Type-specific validation
        if param_type and param_type in self.SAFE_PARAMETER_PATTERNS:
            expected_pattern = self.SAFE_PARAMETER_PATTERNS[param_type]
            if not re.match(expected_pattern, value_str):
                return False, f"Parameter does not match expected pattern for type '{param_type}'"
        
        # Custom pattern validation
        if pattern:
            if not re.match(pattern, value_str):
                return False, f"Parameter does not match custom pattern"
        
        return True, ""
    
    def create_parameterized_query(self, base_query: str, parameters: Dict[str, Any]) -> Tuple[str, Dict[str, Any]]:
        """
        Create parameterized query with validated parameters.
        
        Args:
            base_query: Base SQL query with placeholders
            parameters: Parameters to bind
            
        Returns:
            Tuple of (parameterized_query, validated_parameters)
        """
        validated_params = {}
        
        for key, value in parameters.items():
            # Validate parameter
            is_valid, error_msg = self.validate_parameter(value)
            
            if not is_valid:
                raise ValueError(f"Parameter '{key}' validation failed: {error_msg}")
            
            # Sanitize parameter value
            if isinstance(value, str):
                validated_params[key] = self._sanitize_string_value(value)
            else:
                validated_params[key] = value
        
        return base_query, validated_params
    
    def _analyze_query(self, query: str) -> List[str]:
        """Analyze query for SQL injection patterns."""
        threats = []
        
        for i, compiled_pattern in enumerate(self.compiled_patterns):
            matches = compiled_pattern.findall(query)
            if matches:
                threat_type = self._get_threat_type(i)
                threats.append(f"{threat_type}: {matches}")
        
        return threats
    
    def _analyze_parameters(self, parameters: Dict[str, Any]) -> List[str]:
        """Analyze parameters for SQL injection patterns."""
        threats = []
        
        for key, value in parameters.items():
            if isinstance(value, str):
                for i, compiled_pattern in enumerate(self.compiled_patterns):
                    if compiled_pattern.search(value):
                        threat_type = self._get_threat_type(i)
                        threats.append(f"{threat_type} in parameter '{key}': {value}")
        
        return threats
    
    def _get_threat_type(self, pattern_index: int) -> str:
        """Get threat type description for pattern index."""
        threat_types = [
            "SQL Keyword Injection",
            "SQL Keyword Injection",
            "Comment Injection",
            "Comment Injection",
            "Comment Injection",
            "Boolean-based Blind SQL Injection",
            "Boolean-based Blind SQL Injection",
            "Union-based SQL Injection",
            "Union-based SQL Injection",
            "Time-based Blind SQL Injection",
            "Time-based Blind SQL Injection",
            "Error-based SQL Injection",
            "Stacked Queries",
            "Function Call Injection",
            "Database-specific Function",
            "Database-specific Function",
            "Conditional Statement Injection",
            "System Function Call",
            "System Variable Access"
        ]
        
        return threat_types[min(pattern_index, len(threat_types) - 1)]
    
    def _sanitize_string_value(self, value: str) -> str:
        """Sanitize string value for safe database use."""
        # Remove null bytes
        sanitized = value.replace('\x00', '')
        
        # Limit length to prevent buffer overflow
        max_length = 10000  # Configurable limit
        if len(sanitized) > max_length:
            sanitized = sanitized[:max_length]
        
        return sanitized


class QuerySanitizer:
    """
    Advanced query sanitization system.
    
    Provides safe query construction and parameter binding.
    """
    
    def __init__(self, sql_injection_prevention: SQLInjectionPrevention = None):
        """
        Initialize query sanitizer.
        
        Args:
            sql_injection_prevention: SQL injection prevention instance
        """
        self.sql_injection_prevention = sql_injection_prevention or SQLInjectionPrevention()
    
    async def execute_safe_query(self, session: AsyncSession, query: str, 
                                parameters: Dict[str, Any] = None) -> Any:
        """
        Execute query with comprehensive safety checks.
        
        Args:
            session: Database session
            query: SQL query
            parameters: Query parameters
            
        Returns:
            Query result
            
        Raises:
            ValueError: If query or parameters are unsafe
        """
        # Validate query and parameters
        is_safe, threats = self.sql_injection_prevention.detect_sql_injection(query, parameters)
        
        if not is_safe:
            raise ValueError(f"Unsafe query detected: {threats}")
        
        # Create parameterized query
        safe_query, safe_params = self.sql_injection_prevention.create_parameterized_query(
            query, parameters or {}
        )
        
        # Execute query
        try:
            result = await session.execute(text(safe_query), safe_params)
            return result
        except Exception as e:
            logger.error(
                "Safe query execution failed",
                query=safe_query[:100],
                parameters=safe_params,
                error=str(e)
            )
            raise
    
    def build_safe_select_query(self, table: str, columns: List[str] = None,
                               where_clause: str = None, 
                               parameters: Dict[str, Any] = None) -> Tuple[str, Dict[str, Any]]:
        """
        Build safe SELECT query.
        
        Args:
            table: Table name
            columns: Column names to select
            where_clause: WHERE clause with placeholders
            parameters: Parameters for WHERE clause
            
        Returns:
            Tuple of (query, parameters)
        """
        # Validate table name
        if not re.match(r'^[a-zA-Z_][a-zA-Z0-9_]*$', table):
            raise ValueError(f"Invalid table name: {table}")
        
        # Build SELECT clause
        if columns:
            # Validate column names
            for col in columns:
                if not re.match(r'^[a-zA-Z_][a-zA-Z0-9_]*$', col):
                    raise ValueError(f"Invalid column name: {col}")
            select_clause = ", ".join(columns)
        else:
            select_clause = "*"
        
        # Build query
        query = f"SELECT {select_clause} FROM {table}"
        
        # Add WHERE clause if provided
        if where_clause:
            query += f" WHERE {where_clause}"
        
        # Validate parameters
        safe_params = {}
        if parameters:
            for key, value in parameters.items():
                is_valid, error_msg = self.sql_injection_prevention.validate_parameter(value)
                if not is_valid:
                    raise ValueError(f"Parameter '{key}' validation failed: {error_msg}")
                safe_params[key] = value
        
        return query, safe_params
    
    def build_safe_insert_query(self, table: str, data: Dict[str, Any]) -> Tuple[str, Dict[str, Any]]:
        """
        Build safe INSERT query.
        
        Args:
            table: Table name
            data: Data to insert
            
        Returns:
            Tuple of (query, parameters)
        """
        # Validate table name
        if not re.match(r'^[a-zA-Z_][a-zA-Z0-9_]*$', table):
            raise ValueError(f"Invalid table name: {table}")
        
        if not data:
            raise ValueError("No data provided for INSERT")
        
        # Validate column names and values
        columns = []
        values = []
        parameters = {}
        
        for key, value in data.items():
            # Validate column name
            if not re.match(r'^[a-zA-Z_][a-zA-Z0-9_]*$', key):
                raise ValueError(f"Invalid column name: {key}")
            
            # Validate value
            is_valid, error_msg = self.sql_injection_prevention.validate_parameter(value)
            if not is_valid:
                raise ValueError(f"Value for column '{key}' validation failed: {error_msg}")
            
            columns.append(key)
            values.append(f":{key}")
            parameters[key] = value
        
        query = f"INSERT INTO {table} ({', '.join(columns)}) VALUES ({', '.join(values)})"
        
        return query, parameters
    
    def build_safe_update_query(self, table: str, data: Dict[str, Any],
                               where_clause: str, 
                               where_parameters: Dict[str, Any] = None) -> Tuple[str, Dict[str, Any]]:
        """
        Build safe UPDATE query.
        
        Args:
            table: Table name
            data: Data to update
            where_clause: WHERE clause with placeholders
            where_parameters: Parameters for WHERE clause
            
        Returns:
            Tuple of (query, parameters)
        """
        # Validate table name
        if not re.match(r'^[a-zA-Z_][a-zA-Z0-9_]*$', table):
            raise ValueError(f"Invalid table name: {table}")
        
        if not data:
            raise ValueError("No data provided for UPDATE")
        
        # Build SET clause
        set_clauses = []
        parameters = {}
        
        for key, value in data.items():
            # Validate column name
            if not re.match(r'^[a-zA-Z_][a-zA-Z0-9_]*$', key):
                raise ValueError(f"Invalid column name: {key}")
            
            # Validate value
            is_valid, error_msg = self.sql_injection_prevention.validate_parameter(value)
            if not is_valid:
                raise ValueError(f"Value for column '{key}' validation failed: {error_msg}")
            
            set_clauses.append(f"{key} = :{key}")
            parameters[key] = value
        
        # Add WHERE parameters
        if where_parameters:
            for key, value in where_parameters.items():
                is_valid, error_msg = self.sql_injection_prevention.validate_parameter(value)
                if not is_valid:
                    raise ValueError(f"WHERE parameter '{key}' validation failed: {error_msg}")
                parameters[key] = value
        
        query = f"UPDATE {table} SET {', '.join(set_clauses)} WHERE {where_clause}"
        
        return query, parameters


# Global instances
sql_injection_prevention = SQLInjectionPrevention()
query_sanitizer = QuerySanitizer(sql_injection_prevention)


def detect_sql_injection(query: str, parameters: Dict[str, Any] = None) -> Tuple[bool, List[str]]:
    """
    Convenience function for SQL injection detection.
    
    Args:
        query: SQL query
        parameters: Query parameters
        
    Returns:
        Tuple of (is_safe, threats)
    """
    return sql_injection_prevention.detect_sql_injection(query, parameters)


def validate_sql_parameter(value: Any, param_type: str = None, pattern: str = None) -> Tuple[bool, str]:
    """
    Convenience function for parameter validation.
    
    Args:
        value: Parameter value
        param_type: Parameter type
        pattern: Validation pattern
        
    Returns:
        Tuple of (is_valid, error_message)
    """
    return sql_injection_prevention.validate_parameter(value, param_type, pattern)
