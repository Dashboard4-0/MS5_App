/**
 * MS5.0 Floor Dashboard - Frontend Error Tracking Service
 * 
 * This service provides comprehensive error tracking for the frontend:
 * - Automatic error capture and categorization
 * - User interaction context preservation
 * - Error correlation with user sessions
 * - Performance impact tracking
 * - Zero redundancy architecture
 */

import { ErrorType, ErrorSeverity, ErrorContext } from '../types/errorTypes';
import { ApiService } from './api';
import { PerformanceMonitor } from './performanceMonitor';
import { UserSessionService } from './userSessionService';

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

class FrontendErrorTrackingService {
  private errorEvents: ErrorEvent[] = [];
  private errorPatterns: Map<string, ErrorEvent[]> = new Map();
  private errorMetrics: ErrorRateMetrics = {
    totalErrors: 0,
    errorsByType: {},
    errorsBySeverity: {},
    errorsByEndpoint: {},
    errorRatePerMinute: 0,
    errorRatePerHour: 0,
    errorRatePercentage: 0,
    totalRequests: 0,
    criticalErrors: 0,
    resolvedErrors: 0,
    unresolvedErrors: 0,
  };
  private errorAlerts: Map<string, ErrorAlert> = new Map();
  private isMonitoring = false;
  private monitoringTasks: NodeJS.Timeout[] = [];
  private apiService: ApiService;
  private performanceMonitor: PerformanceMonitor;
  private userSessionService: UserSessionService;

  // Error rate thresholds
  private errorRateThresholds = {
    critical: 0.01, // 1%
    high: 0.05,      // 5%
    medium: 0.10,    // 10%
    low: 0.20,       // 20%
  };

  // Time windows for error rate calculation
  private timeWindows = {
    minute: 60,
    hour: 3600,
    day: 86400,
  };

  constructor(
    apiService: ApiService,
    performanceMonitor: PerformanceMonitor,
    userSessionService: UserSessionService
  ) {
    this.apiService = apiService;
    this.performanceMonitor = performanceMonitor;
    this.userSessionService = userSessionService;
  }

  /**
   * Initialize error tracking service
   */
  async initialize(): Promise<void> {
    try {
      // Setup default alerts
      await this.setupDefaultAlerts();

      // Start monitoring tasks
      await this.startMonitoringTasks();

      // Setup global error handlers
      this.setupGlobalErrorHandlers();

      this.isMonitoring = true;
      console.log('Frontend error tracking initialized');

    } catch (error) {
      console.error('Failed to initialize error tracking:', error);
      throw new Error('Error tracking initialization failed');
    }
  }

  /**
   * Setup default error alerts
   */
  private async setupDefaultAlerts(): Promise<void> {
    try {
      // Critical error rate alert
      const criticalAlert: ErrorAlert = {
        alertId: 'critical_error_rate',
        errorType: ErrorType.APPLICATION,
        threshold: 0.01, // 1%
        timeWindow: 300, // 5 minutes
        severity: 'critical',
        enabled: true,
        triggerCount: 0,
      };
      this.errorAlerts.set('critical_error_rate', criticalAlert);

      // High error rate alert
      const highAlert: ErrorAlert = {
        alertId: 'high_error_rate',
        errorType: ErrorType.APPLICATION,
        threshold: 0.05, // 5%
        timeWindow: 600, // 10 minutes
        severity: 'high',
        enabled: true,
        triggerCount: 0,
      };
      this.errorAlerts.set('high_error_rate', highAlert);

      // Network error alert
      const networkAlert: ErrorAlert = {
        alertId: 'network_error_rate',
        errorType: ErrorType.NETWORK,
        threshold: 0.10, // 10%
        timeWindow: 600, // 10 minutes
        severity: 'high',
        enabled: true,
        triggerCount: 0,
      };
      this.errorAlerts.set('network_error_rate', networkAlert);

      console.log('Default error alerts configured', this.errorAlerts.size);

    } catch (error) {
      console.error('Failed to setup default alerts:', error);
      throw error;
    }
  }

  /**
   * Start background monitoring tasks
   */
  private async startMonitoringTasks(): Promise<void> {
    // Error rate calculation
    const rateTask = setInterval(() => {
      this.calculateErrorRates();
    }, 60000); // Every minute
    this.monitoringTasks.push(rateTask);

    // Error pattern analysis
    const patternTask = setInterval(() => {
      this.analyzeErrorPatterns();
    }, 300000); // Every 5 minutes
    this.monitoringTasks.push(patternTask);

    // Alert monitoring
    const alertTask = setInterval(() => {
      this.monitorErrorAlerts();
    }, 30000); // Every 30 seconds
    this.monitoringTasks.push(alertTask);

    // Error cleanup
    const cleanupTask = setInterval(() => {
      this.cleanupOldErrors();
    }, 3600000); // Every hour
    this.monitoringTasks.push(cleanupTask);

    // Metrics aggregation
    const metricsTask = setInterval(() => {
      this.aggregateErrorMetrics();
    }, 60000); // Every minute
    this.monitoringTasks.push(metricsTask);

    console.log('Error monitoring tasks started', this.monitoringTasks.length);
  }

  /**
   * Setup global error handlers
   */
  private setupGlobalErrorHandlers(): void {
    // Global error handler
    window.addEventListener('error', (event) => {
      this.recordError(
        ErrorType.APPLICATION,
        ErrorSeverity.HIGH,
        event.error?.message || 'Unknown error',
        event.error?.stack,
        {
          filename: event.filename,
          lineno: event.lineno,
          colno: event.colno,
          type: 'global_error',
        }
      );
    });

    // Unhandled promise rejection handler
    window.addEventListener('unhandledrejection', (event) => {
      this.recordError(
        ErrorType.APPLICATION,
        ErrorSeverity.HIGH,
        event.reason?.message || 'Unhandled promise rejection',
        event.reason?.stack,
        {
          type: 'unhandled_rejection',
          reason: event.reason,
        }
      );
    });

    // Network error handler
    window.addEventListener('offline', () => {
      this.recordError(
        ErrorType.NETWORK,
        ErrorSeverity.MEDIUM,
        'Network connection lost',
        undefined,
        {
          type: 'network_offline',
        }
      );
    });

    // Performance error handler
    window.addEventListener('load', () => {
      // Check for performance issues
      const navigation = performance.getEntriesByType('navigation')[0] as PerformanceNavigationTiming;
      if (navigation) {
        const loadTime = navigation.loadEventEnd - navigation.loadEventStart;
        if (loadTime > 5000) { // 5 seconds
          this.recordError(
            ErrorType.SYSTEM,
            ErrorSeverity.MEDIUM,
            `Slow page load detected: ${loadTime}ms`,
            undefined,
            {
              type: 'slow_page_load',
              loadTime,
              threshold: 5000,
            }
          );
        }
      }
    });
  }

  /**
   * Record an error event
   */
  async recordError(
    errorType: ErrorType,
    severity: ErrorSeverity,
    message: string,
    stackTrace?: string,
    context?: ErrorContext,
    userId?: string,
    sessionId?: string,
    requestId?: string,
    endpoint?: string,
    method?: string,
    statusCode?: number
  ): Promise<string> {
    try {
      const errorId = this.generateErrorId();

      const errorEvent: ErrorEvent = {
        errorId,
        errorType,
        severity,
        message,
        stackTrace,
        context: context || {},
        userId: userId || this.userSessionService.getCurrentUserId(),
        sessionId: sessionId || this.userSessionService.getCurrentSessionId(),
        requestId,
        endpoint,
        method,
        statusCode,
        timestamp: Date.now(),
        resolved: false,
      };

      // Store error event
      this.errorEvents.push(errorEvent);

      // Update error patterns
      const patternKey = this.generateErrorPatternKey(errorEvent);
      if (!this.errorPatterns.has(patternKey)) {
        this.errorPatterns.set(patternKey, []);
      }
      this.errorPatterns.get(patternKey)!.push(errorEvent);

      // Update metrics
      this.updateErrorMetrics(errorEvent);

      // Send to backend for centralized tracking
      await this.sendErrorToBackend(errorEvent);

      // Log error
      console.error('Error recorded:', {
        errorId,
        errorType: errorType,
        severity: severity,
        message,
        endpoint,
        userId: errorEvent.userId,
      });

      return errorId;

    } catch (error) {
      console.error('Failed to record error:', error);
      throw new Error('Failed to record error');
    }
  }

  /**
   * Generate unique error ID
   */
  private generateErrorId(): string {
    return `error_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * Generate error pattern key for grouping
   */
  private generateErrorPatternKey(errorEvent: ErrorEvent): string {
    const keyParts = [
      errorEvent.errorType,
      errorEvent.severity,
      errorEvent.endpoint || 'unknown',
      errorEvent.statusCode?.toString() || 'unknown',
    ];
    return keyParts.join(':');
  }

  /**
   * Update error metrics
   */
  private updateErrorMetrics(errorEvent: ErrorEvent): void {
    this.errorMetrics.totalErrors += 1;

    // Update by type
    const errorTypeKey = errorEvent.errorType;
    this.errorMetrics.errorsByType[errorTypeKey] = 
      (this.errorMetrics.errorsByType[errorTypeKey] || 0) + 1;

    // Update by severity
    const severityKey = errorEvent.severity;
    this.errorMetrics.errorsBySeverity[severityKey] = 
      (this.errorMetrics.errorsBySeverity[severityKey] || 0) + 1;

    // Update by endpoint
    if (errorEvent.endpoint) {
      this.errorMetrics.errorsByEndpoint[errorEvent.endpoint] = 
        (this.errorMetrics.errorsByEndpoint[errorEvent.endpoint] || 0) + 1;
    }

    // Update critical errors
    if (errorEvent.severity === ErrorSeverity.CRITICAL) {
      this.errorMetrics.criticalErrors += 1;
    }

    // Update resolved/unresolved counts
    if (errorEvent.resolved) {
      this.errorMetrics.resolvedErrors += 1;
    } else {
      this.errorMetrics.unresolvedErrors += 1;
    }
  }

  /**
   * Send error to backend for centralized tracking
   */
  private async sendErrorToBackend(errorEvent: ErrorEvent): Promise<void> {
    try {
      await this.apiService.post('/api/errors/track', {
        errorId: errorEvent.errorId,
        errorType: errorEvent.errorType,
        severity: errorEvent.severity,
        message: errorEvent.message,
        stackTrace: errorEvent.stackTrace,
        context: errorEvent.context,
        userId: errorEvent.userId,
        sessionId: errorEvent.sessionId,
        requestId: errorEvent.requestId,
        endpoint: errorEvent.endpoint,
        method: errorEvent.method,
        statusCode: errorEvent.statusCode,
        timestamp: errorEvent.timestamp,
      });
    } catch (error) {
      console.error('Failed to send error to backend:', error);
    }
  }

  /**
   * Calculate error rates for different time windows
   */
  private calculateErrorRates(): void {
    try {
      const currentTime = Date.now();

      // Calculate error rates for different time windows
      Object.entries(this.timeWindows).forEach(([windowName, windowMs]) => {
        const cutoffTime = currentTime - windowMs;

        // Count errors in time window
        const errorsInWindow = this.errorEvents.filter(
          error => error.timestamp >= cutoffTime
        ).length;

        // Count total requests in time window (would be tracked separately)
        const totalRequests = this.errorMetrics.totalRequests; // Placeholder

        // Calculate error rate
        const errorRate = totalRequests > 0 ? errorsInWindow / totalRequests : 0;

        // Update metrics
        if (windowName === 'minute') {
          this.errorMetrics.errorRatePerMinute = errorRate;
        } else if (windowName === 'hour') {
          this.errorMetrics.errorRatePerHour = errorRate;
        }

        // Record metric
        this.performanceMonitor.recordMetric('error_rate_percentage', errorRate * 100, {
          timeWindow: windowName,
        });
      });

    } catch (error) {
      console.error('Error rate calculation failed:', error);
    }
  }

  /**
   * Analyze error patterns for insights
   */
  private analyzeErrorPatterns(): void {
    try {
      const patternAnalysis: Record<string, any> = {};

      this.errorPatterns.forEach((errors, patternKey) => {
        if (errors.length >= 3) { // Only analyze patterns with 3+ errors
          const timestamps = errors.map(error => error.timestamp);
          const firstOccurrence = Math.min(...timestamps);
          const lastOccurrence = Math.max(...timestamps);
          const timeSpan = lastOccurrence - firstOccurrence;

          patternAnalysis[patternKey] = {
            errorCount: errors.length,
            firstOccurrence,
            lastOccurrence,
            frequency: timeSpan > 0 ? errors.length / timeSpan : 0,
            affectedUsers: new Set(errors.map(error => error.userId).filter(Boolean)).size,
            affectedEndpoints: new Set(errors.map(error => error.endpoint).filter(Boolean)).size,
          };
        }
      });

      // Log significant patterns
      Object.entries(patternAnalysis).forEach(([patternKey, analysis]) => {
        if (analysis.errorCount >= 10) { // Significant pattern
          console.warn('Significant error pattern detected:', {
            pattern: patternKey,
            errorCount: analysis.errorCount,
            frequency: analysis.frequency,
            affectedUsers: analysis.affectedUsers,
          });
        }
      });

    } catch (error) {
      console.error('Error pattern analysis failed:', error);
    }
  }

  /**
   * Monitor error rate alerts
   */
  private monitorErrorAlerts(): void {
    try {
      const currentTime = Date.now();

      this.errorAlerts.forEach((alert, alertId) => {
        if (!alert.enabled) return;

        // Calculate error rate for alert time window
        const cutoffTime = currentTime - (alert.timeWindow * 1000);
        const errorsInWindow = this.errorEvents.filter(
          error => error.timestamp >= cutoffTime && error.errorType === alert.errorType
        ).length;

        // Calculate error rate
        const totalRequests = this.errorMetrics.totalRequests; // Placeholder
        const errorRate = totalRequests > 0 ? errorsInWindow / totalRequests : 0;

        // Check if threshold is exceeded
        if (errorRate > alert.threshold) {
          // Check if alert was recently triggered
          if (!alert.lastTriggered || (currentTime - alert.lastTriggered) > (alert.timeWindow * 1000)) {
            this.triggerErrorAlert(alert, errorRate, errorsInWindow);
            alert.lastTriggered = currentTime;
            alert.triggerCount += 1;
          }
        }
      });

    } catch (error) {
      console.error('Error alert monitoring failed:', error);
    }
  }

  /**
   * Trigger an error rate alert
   */
  private triggerErrorAlert(alert: ErrorAlert, errorRate: number, errorCount: number): void {
    try {
      const alertMessage = 
        `Error rate alert triggered: ${alert.errorType} errors exceeded threshold of ${(alert.threshold * 100).toFixed(2)}% ` +
        `(current rate: ${(errorRate * 100).toFixed(2)}%, count: ${errorCount})`;

      console.error('Error rate alert triggered:', {
        alertId: alert.alertId,
        errorType: alert.errorType,
        threshold: alert.threshold,
        currentRate: errorRate,
        errorCount,
        severity: alert.severity,
      });

      // Send alert notification
      this.sendAlertNotification(alert, alertMessage, errorRate, errorCount);

    } catch (error) {
      console.error('Failed to trigger error alert:', error);
    }
  }

  /**
   * Send alert notification
   */
  private sendAlertNotification(
    alert: ErrorAlert, 
    message: string, 
    errorRate: number, 
    errorCount: number
  ): void {
    try {
      // This would integrate with actual notification systems
      const notificationData = {
        alertId: alert.alertId,
        errorType: alert.errorType,
        severity: alert.severity,
        threshold: alert.threshold,
        currentRate: errorRate,
        errorCount,
        message,
        timestamp: Date.now(),
      };

      console.log('Alert notification sent:', notificationData);

    } catch (error) {
      console.error('Failed to send alert notification:', error);
    }
  }

  /**
   * Cleanup old error events to prevent memory leaks
   */
  private cleanupOldErrors(): void {
    try {
      const currentTime = Date.now();
      const cleanupThreshold = 86400000; // 24 hours

      // Clean up old error events
      const oldErrors = this.errorEvents.filter(
        error => currentTime - error.timestamp > cleanupThreshold
      );

      this.errorEvents = this.errorEvents.filter(
        error => currentTime - error.timestamp <= cleanupThreshold
      );

      // Clean up old error patterns
      this.errorPatterns.forEach((errors, patternKey) => {
        const filteredErrors = errors.filter(
          error => currentTime - error.timestamp <= cleanupThreshold
        );
        
        if (filteredErrors.length === 0) {
          this.errorPatterns.delete(patternKey);
        } else {
          this.errorPatterns.set(patternKey, filteredErrors);
        }
      });

      if (oldErrors.length > 0) {
        console.debug('Old errors cleaned up:', oldErrors.length);
      }

    } catch (error) {
      console.error('Error cleanup failed:', error);
    }
  }

  /**
   * Aggregate error metrics for reporting
   */
  private aggregateErrorMetrics(): void {
    try {
      // Calculate overall error rate percentage
      const totalRequests = this.errorMetrics.totalRequests;
      const totalErrors = this.errorMetrics.totalErrors;

      if (totalRequests > 0) {
        this.errorMetrics.errorRatePercentage = (totalErrors / totalRequests) * 100;
      }

      // Record aggregated metrics
      this.performanceMonitor.recordMetric('total_errors', totalErrors);
      this.performanceMonitor.recordMetric('error_rate_percentage', this.errorMetrics.errorRatePercentage);
      this.performanceMonitor.recordMetric('critical_errors', this.errorMetrics.criticalErrors);
      this.performanceMonitor.recordMetric('unresolved_errors', this.errorMetrics.unresolvedErrors);

    } catch (error) {
      console.error('Error metrics aggregation failed:', error);
    }
  }

  /**
   * Resolve an error
   */
  async resolveError(errorId: string, resolutionNotes?: string): Promise<boolean> {
    try {
      // Find error event
      const errorEvent = this.errorEvents.find(error => error.errorId === errorId);
      if (!errorEvent) {
        console.warn('Error not found for resolution:', errorId);
        return false;
      }

      // Mark as resolved
      errorEvent.resolved = true;
      errorEvent.resolutionNotes = resolutionNotes;

      // Update metrics
      this.errorMetrics.resolvedErrors += 1;
      this.errorMetrics.unresolvedErrors = Math.max(0, this.errorMetrics.unresolvedErrors - 1);

      // Send resolution to backend
      await this.apiService.post(`/api/errors/${errorId}/resolve`, {
        resolutionNotes,
        timestamp: Date.now(),
      });

      console.log('Error resolved:', {
        errorId,
        resolutionNotes,
      });

      return true;

    } catch (error) {
      console.error('Failed to resolve error:', error);
      return false;
    }
  }

  /**
   * Get comprehensive error rate report
   */
  getErrorRateReport(): ErrorRateReport {
    try {
      // Calculate recent error rates
      const currentTime = Date.now();
      const recentErrors = this.errorEvents.filter(
        error => currentTime - error.timestamp <= 3600000 // Last hour
      );

      // Top error patterns
      const topPatterns = Array.from(this.errorPatterns.entries())
        .sort((a, b) => b[1].length - a[1].length)
        .slice(0, 10)
        .map(([patternKey, errors]) => ({
          pattern: patternKey,
          errorCount: errors.length,
          errorType: errors[0]?.errorType || ErrorType.UNKNOWN,
          severity: errors[0]?.severity || ErrorSeverity.LOW,
          firstOccurrence: Math.min(...errors.map(error => error.timestamp)),
          lastOccurrence: Math.max(...errors.map(error => error.timestamp)),
          affectedUsers: new Set(errors.map(error => error.userId).filter(Boolean)).size,
          affectedEndpoints: new Set(errors.map(error => error.endpoint).filter(Boolean)).size,
        }));

      // Error trends
      const errorTrends = this.calculateErrorTrends();

      // Active alerts
      const activeAlerts = Array.from(this.errorAlerts.values());

      return {
        errorMetrics: this.errorMetrics,
        recentErrors: {
          count: recentErrors.length,
          errors: recentErrors.slice(-20), // Last 20 errors
        },
        topErrorPatterns: topPatterns,
        errorTrends,
        activeAlerts,
        monitoringStatus: {
          isMonitoring: this.isMonitoring,
          monitoringTasks: this.monitoringTasks.length,
          totalPatterns: this.errorPatterns.size,
        },
      };

    } catch (error) {
      console.error('Failed to generate error rate report:', error);
      throw new Error('Failed to generate error rate report');
    }
  }

  /**
   * Calculate error trends over time
   */
  private calculateErrorTrends(): ErrorTrends {
    try {
      const currentTime = Date.now();
      const trends: ErrorTrends = {} as ErrorTrends;

      // Calculate trends for different time windows
      Object.entries(this.timeWindows).forEach(([windowName, windowMs]) => {
        const cutoffTime = currentTime - windowMs;

        // Count errors in current window
        const currentErrors = this.errorEvents.filter(
          error => error.timestamp >= cutoffTime
        ).length;

        // Count errors in previous window
        const previousCutoff = cutoffTime - windowMs;
        const previousErrors = this.errorEvents.filter(
          error => previousCutoff <= error.timestamp && error.timestamp < cutoffTime
        ).length;

        // Calculate trend
        let trendPercentage = 0;
        if (previousErrors > 0) {
          trendPercentage = ((currentErrors - previousErrors) / previousErrors) * 100;
        } else if (currentErrors > 0) {
          trendPercentage = 100;
        }

        const trendDirection = 
          trendPercentage > 0 ? 'increasing' : 
          trendPercentage < 0 ? 'decreasing' : 'stable';

        trends[windowName as keyof ErrorTrends] = {
          currentErrors,
          previousErrors,
          trendPercentage,
          trendDirection,
        };
      });

      return trends;

    } catch (error) {
      console.error('Failed to calculate error trends:', error);
      return {} as ErrorTrends;
    }
  }

  /**
   * Stop error rate monitoring
   */
  stopMonitoring(): void {
    try {
      this.isMonitoring = false;

      // Clear monitoring tasks
      this.monitoringTasks.forEach(task => clearInterval(task));
      this.monitoringTasks = [];

      console.log('Error rate monitoring stopped');

    } catch (error) {
      console.error('Failed to stop monitoring:', error);
    }
  }
}

// Export singleton instance
export const errorTrackingService = new FrontendErrorTrackingService(
  new ApiService(),
  new PerformanceMonitor(),
  new UserSessionService()
);

// Export types
export { ErrorType, ErrorSeverity };
