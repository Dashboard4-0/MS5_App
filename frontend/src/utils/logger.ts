/**
 * MS5.0 Floor Dashboard - Logger Utility
 * 
 * Centralized logging utility for the application with different log levels
 * and structured logging for better debugging and monitoring.
 */

import { Platform } from 'react-native';

// Log levels
export enum LogLevel {
  DEBUG = 0,
  INFO = 1,
  WARN = 2,
  ERROR = 3,
}

// Log entry interface
interface LogEntry {
  level: LogLevel;
  message: string;
  timestamp: string;
  data?: any;
  source?: string;
  userId?: string;
  sessionId?: string;
}

class Logger {
  private logLevel: LogLevel;
  private isEnabled: boolean;
  private logs: LogEntry[] = [];
  private maxLogs: number = 1000;

  constructor() {
    this.logLevel = __DEV__ ? LogLevel.DEBUG : LogLevel.INFO;
    this.isEnabled = true;
  }

  private shouldLog(level: LogLevel): boolean {
    return this.isEnabled && level >= this.logLevel;
  }

  private createLogEntry(level: LogLevel, message: string, data?: any, source?: string): LogEntry {
    return {
      level,
      message,
      timestamp: new Date().toISOString(),
      data,
      source,
      // TODO: Add userId and sessionId from Redux store
    };
  }

  private addLog(entry: LogEntry): void {
    this.logs.push(entry);
    
    // Keep only the last maxLogs entries
    if (this.logs.length > this.maxLogs) {
      this.logs.shift();
    }

    // Console output for development
    if (__DEV__) {
      const { level, message, timestamp, data } = entry;
      const levelName = LogLevel[level];
      
      const logMessage = `[${timestamp}] ${levelName}: ${message}`;
      
      switch (level) {
        case LogLevel.DEBUG:
          console.log(logMessage, data || '');
          break;
        case LogLevel.INFO:
          console.info(logMessage, data || '');
          break;
        case LogLevel.WARN:
          console.warn(logMessage, data || '');
          break;
        case LogLevel.ERROR:
          console.error(logMessage, data || '');
          break;
      }
    }
  }

  debug(message: string, data?: any, source?: string): void {
    if (this.shouldLog(LogLevel.DEBUG)) {
      this.addLog(this.createLogEntry(LogLevel.DEBUG, message, data, source));
    }
  }

  info(message: string, data?: any, source?: string): void {
    if (this.shouldLog(LogLevel.INFO)) {
      this.addLog(this.createLogEntry(LogLevel.INFO, message, data, source));
    }
  }

  warn(message: string, data?: any, source?: string): void {
    if (this.shouldLog(LogLevel.WARN)) {
      this.addLog(this.createLogEntry(LogLevel.WARN, message, data, source));
    }
  }

  error(message: string, data?: any, source?: string): void {
    if (this.shouldLog(LogLevel.ERROR)) {
      this.addLog(this.createLogEntry(LogLevel.ERROR, message, data, source));
    }
  }

  // Specialized logging methods
  apiRequest(method: string, url: string, data?: any): void {
    this.debug('API Request', {
      method,
      url,
      data,
      platform: Platform.OS,
    }, 'API');
  }

  apiResponse(method: string, url: string, status: number, data?: any): void {
    const level = status >= 400 ? LogLevel.ERROR : LogLevel.INFO;
    this.addLog(this.createLogEntry(level, 'API Response', {
      method,
      url,
      status,
      data,
      platform: Platform.OS,
    }, 'API'));
  }

  userAction(action: string, data?: any): void {
    this.info('User Action', {
      action,
      data,
      platform: Platform.OS,
    }, 'USER');
  }

  navigation(from: string, to: string, data?: any): void {
    this.debug('Navigation', {
      from,
      to,
      data,
      platform: Platform.OS,
    }, 'NAVIGATION');
  }

  performance(operation: string, duration: number, data?: any): void {
    this.info('Performance', {
      operation,
      duration,
      data,
      platform: Platform.OS,
    }, 'PERFORMANCE');
  }

  errorBoundary(error: Error, errorInfo: any): void {
    this.error('Error Boundary', {
      error: error.message,
      stack: error.stack,
      errorInfo,
      platform: Platform.OS,
    }, 'ERROR_BOUNDARY');
  }

  websocket(event: string, data?: any): void {
    this.debug('WebSocket Event', {
      event,
      data,
      platform: Platform.OS,
    }, 'WEBSOCKET');
  }

  offline(action: string, data?: any): void {
    this.info('Offline Action', {
      action,
      data,
      platform: Platform.OS,
    }, 'OFFLINE');
  }

  // Configuration methods
  setLogLevel(level: LogLevel): void {
    this.logLevel = level;
  }

  setEnabled(enabled: boolean): void {
    this.isEnabled = enabled;
  }

  setMaxLogs(maxLogs: number): void {
    this.maxLogs = maxLogs;
  }

  // Log retrieval methods
  getLogs(level?: LogLevel, limit?: number): LogEntry[] {
    let filteredLogs = this.logs;
    
    if (level !== undefined) {
      filteredLogs = this.logs.filter(log => log.level === level);
    }
    
    if (limit !== undefined) {
      filteredLogs = filteredLogs.slice(-limit);
    }
    
    return filteredLogs;
  }

  getLogsBySource(source: string, limit?: number): LogEntry[] {
    let filteredLogs = this.logs.filter(log => log.source === source);
    
    if (limit !== undefined) {
      filteredLogs = filteredLogs.slice(-limit);
    }
    
    return filteredLogs;
  }

  clearLogs(): void {
    this.logs = [];
  }

  exportLogs(): string {
    return JSON.stringify(this.logs, null, 2);
  }

  // Error tracking
  trackError(error: Error, context?: any): void {
    this.error('Error Tracked', {
      message: error.message,
      stack: error.stack,
      context,
      platform: Platform.OS,
    }, 'ERROR_TRACKING');
  }

  // Performance tracking
  trackPerformance<T>(operation: string, fn: () => T, data?: any): T {
    const start = Date.now();
    try {
      const result = fn();
      const duration = Date.now() - start;
      this.performance(operation, duration, data);
      return result;
    } catch (error) {
      const duration = Date.now() - start;
      this.performance(operation, duration, { ...data, error: error.message });
      throw error;
    }
  }

  async trackAsyncPerformance<T>(operation: string, fn: () => Promise<T>, data?: any): Promise<T> {
    const start = Date.now();
    try {
      const result = await fn();
      const duration = Date.now() - start;
      this.performance(operation, duration, data);
      return result;
    } catch (error) {
      const duration = Date.now() - start;
      this.performance(operation, duration, { ...data, error: error.message });
      throw error;
    }
  }
}

// Create and export singleton instance
export const logger = new Logger();
export default logger;
