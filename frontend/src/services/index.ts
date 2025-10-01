/**
 * MS5.0 Floor Dashboard - Services Index
 * 
 * This file exports all service modules for easy importing throughout the application.
 * Provides a centralized access point for all service functionality.
 */

// Core API Service
export { default as apiService } from './api';

// Domain-Specific Services
export { default as authService } from './authService';
export { default as productionService } from './productionService';
export { default as websocketService } from './websocketService';
export { default as dashboardService } from './dashboardService';
export { default as andonService } from './andonService';
export { default as oeeService } from './oeeService';
export { default as equipmentService } from './equipmentService';
export { default as reportsService } from './reportsService';
export { default as qualityService } from './qualityService';
export { default as settingsService } from './settingsService';
export { default as offlineService } from './offlineService';

// Service Types
export type { ApiResponse, ApiError } from './api';
export type { User, AuthState } from './authService';
export type { ProductionLine, ProductionSchedule, JobAssignment, ProductionMetrics } from './productionService';
export type { WebSocketMessage, WebSocketSubscription, WebSocketConfig, WebSocketState } from './websocketService';
export type { OEEData, EquipmentStatus, DowntimeEvent, DashboardData } from './dashboardService';
export type { AndonEvent, AndonEscalation, AndonNotification, AndonMetrics } from './andonService';
export type { OEECalculation, OEEMetrics, OEETrend, OEELoss, OEEAnalytics } from './oeeService';
export type { Equipment, MaintenanceSchedule, EquipmentFault, EquipmentMetrics, EquipmentAnalytics } from './equipmentService';
export type { ReportTemplate, ReportParameter, Report, ScheduledReport, ReportData, ReportAnalytics } from './reportsService';
export type { QualityCheck, QualityParameter, QualityCriteria, QualityRule, QualityInspection, QualityResult, QualityDefect, QualityAlert, QualityMetrics } from './qualityService';
export type { UserPreferences, NotificationSettings, DashboardSettings, SystemSettings, SettingsState } from './settingsService';
export type { OfflineAction, SyncStatus, OfflineData, ConflictResolution, OfflineMetrics } from './offlineService';

// Service Constants
export const SERVICE_CONSTANTS = {
  // API Configuration
  API_BASE_URL: process.env.REACT_APP_API_BASE_URL || 'http://localhost:8000',
  API_TIMEOUT: 30000,
  API_RETRY_ATTEMPTS: 3,
  
  // WebSocket Configuration
  WS_URL: process.env.REACT_APP_WS_URL || 'ws://localhost:8000/ws',
  WS_RECONNECT_INTERVAL: 5000,
  WS_MAX_RECONNECT_ATTEMPTS: 10,
  WS_HEARTBEAT_INTERVAL: 30000,
  
  // Offline Configuration
  OFFLINE_MAX_RETRIES: 3,
  OFFLINE_SYNC_INTERVAL: 30000,
  OFFLINE_DATA_EXPIRY: 7 * 24 * 60 * 60 * 1000, // 7 days
  
  // Cache Configuration
  CACHE_TTL: 5 * 60 * 1000, // 5 minutes
  CACHE_MAX_SIZE: 1000,
  
  // Pagination
  DEFAULT_PAGE_SIZE: 20,
  MAX_PAGE_SIZE: 100,
  
  // File Upload
  MAX_FILE_SIZE: 10 * 1024 * 1024, // 10MB
  ALLOWED_FILE_TYPES: ['image/jpeg', 'image/png', 'image/gif', 'application/pdf', 'text/csv'],
  
  // Validation
  PASSWORD_MIN_LENGTH: 8,
  USERNAME_MIN_LENGTH: 3,
  EMAIL_REGEX: /^[^\s@]+@[^\s@]+\.[^\s@]+$/,
  
  // Date Formats
  DATE_FORMATS: {
    ISO: 'YYYY-MM-DD',
    US: 'MM/DD/YYYY',
    EU: 'DD/MM/YYYY',
    DISPLAY: 'MMM DD, YYYY',
  },
  
  // Time Formats
  TIME_FORMATS: {
    '12h': 'h:mm A',
    '24h': 'HH:mm',
  },
  
  // Status Colors
  STATUS_COLORS: {
    success: '#4CAF50',
    warning: '#FF9800',
    error: '#F44336',
    info: '#2196F3',
    neutral: '#9E9E9E',
  },
  
  // Priority Levels
  PRIORITY_LEVELS: {
    low: { value: 1, color: '#4CAF50', label: 'Low' },
    medium: { value: 2, color: '#FF9800', label: 'Medium' },
    high: { value: 3, color: '#FF5722', label: 'High' },
    critical: { value: 4, color: '#F44336', label: 'Critical' },
  },
  
  // Severity Levels
  SEVERITY_LEVELS: {
    low: { value: 1, color: '#4CAF50', label: 'Low' },
    medium: { value: 2, color: '#FF9800', label: 'Medium' },
    high: { value: 3, color: '#FF5722', label: 'High' },
    critical: { value: 4, color: '#F44336', label: 'Critical' },
  },
} as const;

// Service Utilities
export const ServiceUtils = {
  /**
   * Create API error from response
   * 
   * @param response - API response
   * @param message - Error message
   * @returns API error object
   */
  createApiError(response: Response, message: string) {
    return {
      message,
      status: response.status,
      statusText: response.statusText,
      url: response.url,
      timestamp: new Date().toISOString(),
    };
  },

  /**
   * Retry function with exponential backoff
   * 
   * @param fn - Function to retry
   * @param maxRetries - Maximum number of retries
   * @param baseDelay - Base delay in milliseconds
   * @returns Promise resolving to function result
   */
  async retryWithBackoff<T>(
    fn: () => Promise<T>,
    maxRetries: number = 3,
    baseDelay: number = 1000
  ): Promise<T> {
    let lastError: Error;
    
    for (let attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        return await fn();
      } catch (error) {
        lastError = error as Error;
        
        if (attempt === maxRetries) {
          throw lastError;
        }
        
        const delay = baseDelay * Math.pow(2, attempt);
        await new Promise(resolve => setTimeout(resolve, delay));
      }
    }
    
    throw lastError!;
  },

  /**
   * Debounce function
   * 
   * @param fn - Function to debounce
   * @param delay - Delay in milliseconds
   * @returns Debounced function
   */
  debounce<T extends (...args: any[]) => any>(fn: T, delay: number): T {
    let timeoutId: NodeJS.Timeout;
    
    return ((...args: Parameters<T>) => {
      clearTimeout(timeoutId);
      timeoutId = setTimeout(() => fn(...args), delay);
    }) as T;
  },

  /**
   * Throttle function
   * 
   * @param fn - Function to throttle
   * @param delay - Delay in milliseconds
   * @returns Throttled function
   */
  throttle<T extends (...args: any[]) => any>(fn: T, delay: number): T {
    let lastCall = 0;
    
    return ((...args: Parameters<T>) => {
      const now = Date.now();
      if (now - lastCall >= delay) {
        lastCall = now;
        return fn(...args);
      }
    }) as T;
  },

  /**
   * Format error message
   * 
   * @param error - Error object
   * @returns Formatted error message
   */
  formatErrorMessage(error: any): string {
    if (typeof error === 'string') {
      return error;
    }
    
    if (error?.message) {
      return error.message;
    }
    
    if (error?.response?.data?.message) {
      return error.response.data.message;
    }
    
    if (error?.response?.statusText) {
      return error.response.statusText;
    }
    
    return 'An unexpected error occurred';
  },

  /**
   * Check if error is network error
   * 
   * @param error - Error object
   * @returns True if network error
   */
  isNetworkError(error: any): boolean {
    return (
      error?.code === 'NETWORK_ERROR' ||
      error?.message?.includes('Network Error') ||
      error?.message?.includes('Failed to fetch') ||
      !navigator.onLine
    );
  },

  /**
   * Check if error is timeout error
   * 
   * @param error - Error object
   * @returns True if timeout error
   */
  isTimeoutError(error: any): boolean {
    return (
      error?.code === 'TIMEOUT' ||
      error?.message?.includes('timeout') ||
      error?.message?.includes('TIMEOUT')
    );
  },

  /**
   * Check if error is authentication error
   * 
   * @param error - Error object
   * @returns True if authentication error
   */
  isAuthError(error: any): boolean {
    return (
      error?.status === 401 ||
      error?.response?.status === 401 ||
      error?.message?.includes('Unauthorized') ||
      error?.message?.includes('Authentication')
    );
  },

  /**
   * Check if error is permission error
   * 
   * @param error - Error object
   * @returns True if permission error
   */
  isPermissionError(error: any): boolean {
    return (
      error?.status === 403 ||
      error?.response?.status === 403 ||
      error?.message?.includes('Forbidden') ||
      error?.message?.includes('Permission')
    );
  },

  /**
   * Check if error is validation error
   * 
   * @param error - Error object
   * @returns True if validation error
   */
  isValidationError(error: any): boolean {
    return (
      error?.status === 400 ||
      error?.response?.status === 400 ||
      error?.message?.includes('Validation') ||
      error?.message?.includes('Invalid')
    );
  },

  /**
   * Get error severity
   * 
   * @param error - Error object
   * @returns Error severity level
   */
  getErrorSeverity(error: any): 'low' | 'medium' | 'high' | 'critical' {
    if (this.isNetworkError(error) || this.isTimeoutError(error)) {
      return 'medium';
    }
    
    if (this.isAuthError(error) || this.isPermissionError(error)) {
      return 'high';
    }
    
    if (this.isValidationError(error)) {
      return 'low';
    }
    
    if (error?.status >= 500) {
      return 'critical';
    }
    
    return 'medium';
  },

  /**
   * Generate unique ID
   * 
   * @param prefix - Optional prefix
   * @returns Unique ID string
   */
  generateId(prefix?: string): string {
    const timestamp = Date.now().toString(36);
    const random = Math.random().toString(36).substr(2, 9);
    return prefix ? `${prefix}_${timestamp}_${random}` : `${timestamp}_${random}`;
  },

  /**
   * Deep clone object
   * 
   * @param obj - Object to clone
   * @returns Cloned object
   */
  deepClone<T>(obj: T): T {
    if (obj === null || typeof obj !== 'object') {
      return obj;
    }
    
    if (obj instanceof Date) {
      return new Date(obj.getTime()) as T;
    }
    
    if (obj instanceof Array) {
      return obj.map(item => this.deepClone(item)) as T;
    }
    
    if (typeof obj === 'object') {
      const cloned = {} as T;
      Object.keys(obj).forEach(key => {
        cloned[key as keyof T] = this.deepClone(obj[key as keyof T]);
      });
      return cloned;
    }
    
    return obj;
  },

  /**
   * Merge objects deeply
   * 
   * @param target - Target object
   * @param source - Source object
   * @returns Merged object
   */
  deepMerge<T>(target: T, source: Partial<T>): T {
    const result = this.deepClone(target);
    
    Object.keys(source).forEach(key => {
      const sourceValue = source[key as keyof T];
      const targetValue = result[key as keyof T];
      
      if (sourceValue !== undefined && sourceValue !== null) {
        if (typeof sourceValue === 'object' && typeof targetValue === 'object') {
          result[key as keyof T] = this.deepMerge(targetValue, sourceValue);
        } else {
          result[key as keyof T] = sourceValue;
        }
      }
    });
    
    return result;
  },

  /**
   * Sleep function
   * 
   * @param ms - Milliseconds to sleep
   * @returns Promise that resolves after delay
   */
  sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  },

  /**
   * Format bytes to human readable string
   * 
   * @param bytes - Number of bytes
   * @returns Formatted string
   */
  formatBytes(bytes: number): string {
    if (bytes === 0) return '0 B';
    
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    
    return `${parseFloat((bytes / Math.pow(k, i)).toFixed(2))} ${sizes[i]}`;
  },

  /**
   * Format duration in milliseconds to human readable string
   * 
   * @param ms - Duration in milliseconds
   * @returns Formatted string
   */
  formatDuration(ms: number): string {
    const seconds = Math.floor(ms / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);
    const days = Math.floor(hours / 24);
    
    if (days > 0) {
      return `${days}d ${hours % 24}h ${minutes % 60}m`;
    } else if (hours > 0) {
      return `${hours}h ${minutes % 60}m`;
    } else if (minutes > 0) {
      return `${minutes}m ${seconds % 60}s`;
    } else {
      return `${seconds}s`;
    }
  },
} as const;

// Service Manager
export class ServiceManager {
  private static instance: ServiceManager;
  private services: Map<string, any> = new Map();
  private initialized: boolean = false;

  private constructor() {}

  static getInstance(): ServiceManager {
    if (!ServiceManager.instance) {
      ServiceManager.instance = new ServiceManager();
    }
    return ServiceManager.instance;
  }

  /**
   * Initialize all services
   */
  async initialize(): Promise<void> {
    if (this.initialized) return;

    try {
      // Initialize services in order
      await this.initializeService('api', apiService);
      await this.initializeService('auth', authService);
      await this.initializeService('production', productionService);
      await this.initializeService('websocket', websocketService);
      await this.initializeService('dashboard', dashboardService);
      await this.initializeService('andon', andonService);
      await this.initializeService('oee', oeeService);
      await this.initializeService('equipment', equipmentService);
      await this.initializeService('reports', reportsService);
      await this.initializeService('quality', qualityService);
      await this.initializeService('settings', settingsService);
      await this.initializeService('offline', offlineService);

      this.initialized = true;
      console.log('All services initialized successfully');
    } catch (error) {
      console.error('Failed to initialize services:', error);
      throw error;
    }
  }

  /**
   * Initialize a specific service
   * 
   * @param name - Service name
   * @param service - Service instance
   */
  private async initializeService(name: string, service: any): Promise<void> {
    try {
      if (service.initialize && typeof service.initialize === 'function') {
        await service.initialize();
      }
      this.services.set(name, service);
      console.log(`Service ${name} initialized`);
    } catch (error) {
      console.error(`Failed to initialize service ${name}:`, error);
      throw error;
    }
  }

  /**
   * Get service by name
   * 
   * @param name - Service name
   * @returns Service instance
   */
  getService<T>(name: string): T {
    const service = this.services.get(name);
    if (!service) {
      throw new Error(`Service ${name} not found`);
    }
    return service as T;
  }

  /**
   * Check if service is initialized
   * 
   * @param name - Service name
   * @returns True if service is initialized
   */
  isServiceInitialized(name: string): boolean {
    return this.services.has(name);
  }

  /**
   * Get all initialized services
   * 
   * @returns Map of initialized services
   */
  getAllServices(): Map<string, any> {
    return new Map(this.services);
  }

  /**
   * Reset all services
   */
  reset(): void {
    this.services.clear();
    this.initialized = false;
  }
}

// Export service manager instance
export const serviceManager = ServiceManager.getInstance();
