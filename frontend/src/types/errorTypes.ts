/**
 * MS5.0 Floor Dashboard - Error Types Definitions
 * 
 * This module defines comprehensive error types and interfaces:
 * - Error type classifications
 * - Error severity levels
 * - Error context interfaces
 * - Error tracking utilities
 * - Zero redundancy architecture
 */

export enum ErrorType {
  APPLICATION = 'application',
  DATABASE = 'database',
  NETWORK = 'network',
  VALIDATION = 'validation',
  AUTHENTICATION = 'authentication',
  AUTHORIZATION = 'authorization',
  TIMEOUT = 'timeout',
  RATE_LIMIT = 'rate_limit',
  DEPENDENCY = 'dependency',
  SYSTEM = 'system',
  UNKNOWN = 'unknown',
}

export enum ErrorSeverity {
  LOW = 'low',
  MEDIUM = 'medium',
  HIGH = 'high',
  CRITICAL = 'critical',
}

export enum ErrorStatus {
  NEW = 'new',
  ACKNOWLEDGED = 'acknowledged',
  INVESTIGATING = 'investigating',
  RESOLVED = 'resolved',
  IGNORED = 'ignored',
}

export interface ErrorContext {
  [key: string]: any;
  type?: string;
  component?: string;
  action?: string;
  userId?: string;
  sessionId?: string;
  requestId?: string;
  endpoint?: string;
  method?: string;
  statusCode?: number;
  timestamp?: number;
  userAgent?: string;
  url?: string;
  referrer?: string;
  stackTrace?: string;
  additionalData?: Record<string, any>;
}

export interface ErrorEvent {
  errorId: string;
  errorType: ErrorType;
  severity: ErrorSeverity;
  message: string;
  stackTrace?: string;
  context: ErrorContext;
  userId?: string;
  sessionId?: string;
  requestId?: string;
  endpoint?: string;
  method?: string;
  statusCode?: number;
  timestamp: number;
  resolved: boolean;
  resolutionNotes?: string;
}

export interface ErrorRateMetrics {
  totalErrors: number;
  errorsByType: Record<string, number>;
  errorsBySeverity: Record<string, number>;
  errorsByEndpoint: Record<string, number>;
  errorRatePerMinute: number;
  errorRatePerHour: number;
  errorRatePercentage: number;
  totalRequests: number;
  criticalErrors: number;
  resolvedErrors: number;
  unresolvedErrors: number;
}

export interface ErrorAlert {
  alertId: string;
  errorType: ErrorType;
  threshold: number;
  timeWindow: number; // seconds
  severity: 'low' | 'medium' | 'high' | 'critical';
  enabled: boolean;
  lastTriggered?: number;
  triggerCount: number;
}

export interface ErrorPattern {
  pattern: string;
  errorCount: number;
  errorType: ErrorType;
  severity: ErrorSeverity;
  firstOccurrence: number;
  lastOccurrence: number;
  affectedUsers: number;
  affectedEndpoints: number;
}

export interface ErrorTrends {
  minute: {
    currentErrors: number;
    previousErrors: number;
    trendPercentage: number;
    trendDirection: 'increasing' | 'decreasing' | 'stable';
  };
  hour: {
    currentErrors: number;
    previousErrors: number;
    trendPercentage: number;
    trendDirection: 'increasing' | 'decreasing' | 'stable';
  };
  day: {
    currentErrors: number;
    previousErrors: number;
    trendPercentage: number;
    trendDirection: 'increasing' | 'decreasing' | 'stable';
  };
}

export interface ErrorRateReport {
  errorMetrics: ErrorRateMetrics;
  recentErrors: {
    count: number;
    errors: ErrorEvent[];
  };
  topErrorPatterns: ErrorPattern[];
  errorTrends: ErrorTrends;
  activeAlerts: ErrorAlert[];
  monitoringStatus: {
    isMonitoring: boolean;
    monitoringTasks: number;
    totalPatterns: number;
  };
}

export interface ErrorTrackingConfig {
  enableErrorTracking: boolean;
  trackAllErrors: boolean;
  track4xxErrors: boolean;
  track5xxErrors: boolean;
  trackTimeoutErrors: boolean;
  trackValidationErrors: boolean;
  trackPerformanceImpact: boolean;
  slowRequestThreshold: number; // seconds
  preserveRequestContext: boolean;
  preserveUserContext: boolean;
  preserveSessionContext: boolean;
  errorRateThresholds: {
    critical: number;
    high: number;
    medium: number;
    low: number;
  };
  timeWindows: {
    minute: number;
    hour: number;
    day: number;
  };
}

export interface ErrorNotification {
  alertId: string;
  errorType: ErrorType;
  severity: ErrorSeverity;
  threshold: number;
  currentRate: number;
  errorCount: number;
  message: string;
  timestamp: number;
  notificationChannels: string[];
}

export interface ErrorResolution {
  errorId: string;
  resolvedBy: string;
  resolutionNotes: string;
  resolutionTimestamp: number;
  resolutionType: 'fixed' | 'workaround' | 'ignored' | 'duplicate';
}

export interface ErrorAnalytics {
  errorFrequency: Record<string, number>;
  errorTrends: ErrorTrends;
  topErrorSources: Array<{
    source: string;
    errorCount: number;
    errorRate: number;
  }>;
  errorImpactAnalysis: {
    userImpact: number;
    systemImpact: number;
    businessImpact: number;
  };
  errorResolutionMetrics: {
    averageResolutionTime: number;
    resolutionRate: number;
    escalationRate: number;
  };
}

export interface ErrorDashboardData {
  errorRateReport: ErrorRateReport;
  errorAnalytics: ErrorAnalytics;
  activeAlerts: ErrorAlert[];
  recentErrors: ErrorEvent[];
  errorTrends: ErrorTrends;
  systemHealth: {
    overallHealth: 'healthy' | 'warning' | 'critical';
    errorRate: number;
    criticalErrors: number;
    unresolvedErrors: number;
  };
}

// Error tracking utilities
export class ErrorTrackingUtils {
  /**
   * Classify error by type
   */
  static classifyError(error: Error): ErrorType {
    const errorName = error.constructor.name;
    
    if (errorName.includes('Validation') || errorName.includes('TypeError')) {
      return ErrorType.VALIDATION;
    }
    
    if (errorName.includes('Network') || errorName.includes('Fetch')) {
      return ErrorType.NETWORK;
    }
    
    if (errorName.includes('Timeout')) {
      return ErrorType.TIMEOUT;
    }
    
    if (errorName.includes('Auth') || errorName.includes('Unauthorized')) {
      return ErrorType.AUTHENTICATION;
    }
    
    if (errorName.includes('Permission') || errorName.includes('Forbidden')) {
      return ErrorType.AUTHORIZATION;
    }
    
    if (errorName.includes('Database') || errorName.includes('SQL')) {
      return ErrorType.DATABASE;
    }
    
    if (errorName.includes('RateLimit') || errorName.includes('Throttle')) {
      return ErrorType.RATE_LIMIT;
    }
    
    return ErrorType.APPLICATION;
  }

  /**
   * Classify error by severity
   */
  static classifySeverity(error: Error, context?: ErrorContext): ErrorSeverity {
    const errorName = error.constructor.name;
    const message = error.message.toLowerCase();
    
    // Critical errors
    if (errorName.includes('Critical') || 
        message.includes('critical') ||
        message.includes('fatal') ||
        message.includes('system down')) {
      return ErrorSeverity.CRITICAL;
    }
    
    // High severity errors
    if (errorName.includes('Error') || 
        message.includes('error') ||
        message.includes('failed') ||
        message.includes('exception')) {
      return ErrorSeverity.HIGH;
    }
    
    // Medium severity errors
    if (errorName.includes('Warning') || 
        message.includes('warning') ||
        message.includes('caution') ||
        message.includes('issue')) {
      return ErrorSeverity.MEDIUM;
    }
    
    // Low severity errors
    return ErrorSeverity.LOW;
  }

  /**
   * Generate error pattern key
   */
  static generatePatternKey(errorType: ErrorType, severity: ErrorSeverity, endpoint?: string): string {
    const keyParts = [
      errorType,
      severity,
      endpoint || 'unknown',
    ];
    return keyParts.join(':');
  }

  /**
   * Extract error context from error object
   */
  static extractErrorContext(error: Error, additionalContext?: Record<string, any>): ErrorContext {
    return {
      type: error.constructor.name,
      message: error.message,
      stackTrace: error.stack,
      timestamp: Date.now(),
      url: window.location.href,
      userAgent: navigator.userAgent,
      referrer: document.referrer,
      ...additionalContext,
    };
  }

  /**
   * Calculate error rate
   */
  static calculateErrorRate(errorCount: number, totalRequests: number): number {
    return totalRequests > 0 ? errorCount / totalRequests : 0;
  }

  /**
   * Format error rate as percentage
   */
  static formatErrorRate(errorRate: number): string {
    return `${(errorRate * 100).toFixed(2)}%`;
  }

  /**
   * Check if error rate exceeds threshold
   */
  static exceedsThreshold(errorRate: number, threshold: number): boolean {
    return errorRate > threshold;
  }

  /**
   * Get error rate color based on severity
   */
  static getErrorRateColor(errorRate: number, thresholds: Record<string, number>): string {
    if (errorRate >= thresholds.critical) return '#dc3545'; // Red
    if (errorRate >= thresholds.high) return '#fd7e14';    // Orange
    if (errorRate >= thresholds.medium) return '#ffc107';  // Yellow
    return '#28a745'; // Green
  }

  /**
   * Get error severity color
   */
  static getSeverityColor(severity: ErrorSeverity): string {
    switch (severity) {
      case ErrorSeverity.CRITICAL:
        return '#dc3545'; // Red
      case ErrorSeverity.HIGH:
        return '#fd7e14'; // Orange
      case ErrorSeverity.MEDIUM:
        return '#ffc107'; // Yellow
      case ErrorSeverity.LOW:
        return '#28a745'; // Green
      default:
        return '#6c757d'; // Gray
    }
  }

  /**
   * Get error severity icon
   */
  static getSeverityIcon(severity: ErrorSeverity): string {
    switch (severity) {
      case ErrorSeverity.CRITICAL:
        return '🚨';
      case ErrorSeverity.HIGH:
        return '⚠️';
      case ErrorSeverity.MEDIUM:
        return '⚠️';
      case ErrorSeverity.LOW:
        return 'ℹ️';
      default:
        return '❓';
    }
  }

  /**
   * Format error timestamp
   */
  static formatTimestamp(timestamp: number): string {
    return new Date(timestamp).toLocaleString();
  }

  /**
   * Calculate time since error
   */
  static getTimeSince(timestamp: number): string {
    const now = Date.now();
    const diff = now - timestamp;
    
    if (diff < 60000) return 'Just now';
    if (diff < 3600000) return `${Math.floor(diff / 60000)} minutes ago`;
    if (diff < 86400000) return `${Math.floor(diff / 3600000)} hours ago`;
    return `${Math.floor(diff / 86400000)} days ago`;
  }

  /**
   * Truncate error message
   */
  static truncateMessage(message: string, maxLength: number = 100): string {
    if (message.length <= maxLength) return message;
    return message.substring(0, maxLength) + '...';
  }

  /**
   * Sanitize error data for logging
   */
  static sanitizeErrorData(errorData: any): any {
    if (typeof errorData !== 'object' || errorData === null) {
      return errorData;
    }

    const sanitized: any = {};
    const sensitiveKeys = ['password', 'token', 'key', 'secret', 'auth'];

    for (const [key, value] of Object.entries(errorData)) {
      const lowerKey = key.toLowerCase();
      if (sensitiveKeys.some(sensitive => lowerKey.includes(sensitive))) {
        sanitized[key] = '[REDACTED]';
      } else if (typeof value === 'object' && value !== null) {
        sanitized[key] = this.sanitizeErrorData(value);
      } else {
        sanitized[key] = value;
      }
    }

    return sanitized;
  }
}

// Default error tracking configuration
export const DEFAULT_ERROR_TRACKING_CONFIG: ErrorTrackingConfig = {
  enableErrorTracking: true,
  trackAllErrors: true,
  track4xxErrors: true,
  track5xxErrors: true,
  trackTimeoutErrors: true,
  trackValidationErrors: true,
  trackPerformanceImpact: true,
  slowRequestThreshold: 5.0,
  preserveRequestContext: true,
  preserveUserContext: true,
  preserveSessionContext: true,
  errorRateThresholds: {
    critical: 0.01, // 1%
    high: 0.05,     // 5%
    medium: 0.10,   // 10%
    low: 0.20,      // 20%
  },
  timeWindows: {
    minute: 60,
    hour: 3600,
    day: 86400,
  },
};

// Export all types and utilities
export default {
  ErrorType,
  ErrorSeverity,
  ErrorStatus,
  ErrorTrackingUtils,
  DEFAULT_ERROR_TRACKING_CONFIG,
};
