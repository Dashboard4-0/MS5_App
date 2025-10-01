/**
 * MS5.0 Floor Dashboard - Settings Service
 * 
 * This service handles application settings including user preferences,
 * theme settings, notification preferences, and system configuration.
 */

import { apiService } from './api';

// Types
export interface UserPreferences {
  id: string;
  userId: string;
  language: string;
  timezone: string;
  dateFormat: string;
  timeFormat: string;
  numberFormat: string;
  currency: string;
  units: 'metric' | 'imperial';
  dashboardLayout: 'grid' | 'list' | 'compact';
  defaultView: 'production' | 'oee' | 'equipment' | 'andon' | 'quality' | 'reports';
  autoRefresh: boolean;
  refreshInterval: number;
  showTooltips: boolean;
  showAnimations: boolean;
  compactMode: boolean;
  created_at: string;
  updated_at: string;
}

export interface NotificationSettings {
  id: string;
  userId: string;
  emailNotifications: boolean;
  pushNotifications: boolean;
  smsNotifications: boolean;
  notificationTypes: {
    productionAlerts: boolean;
    equipmentFaults: boolean;
    andonEvents: boolean;
    qualityIssues: boolean;
    maintenanceReminders: boolean;
    systemUpdates: boolean;
    reportReady: boolean;
  };
  notificationFrequency: 'immediate' | 'hourly' | 'daily' | 'weekly';
  quietHours: {
    enabled: boolean;
    startTime: string;
    endTime: string;
    timezone: string;
  };
  created_at: string;
  updated_at: string;
}

export interface DashboardSettings {
  id: string;
  userId: string;
  layout: 'grid' | 'list' | 'compact';
  widgets: Array<{
    id: string;
    type: string;
    position: { x: number; y: number };
    size: { width: number; height: number };
    config: Record<string, any>;
  }>;
  defaultFilters: {
    lineId?: string;
    dateRange?: { start: string; end: string };
    status?: string;
  };
  autoRefresh: boolean;
  refreshInterval: number;
  showEmptyStates: boolean;
  showLoadingStates: boolean;
  created_at: string;
  updated_at: string;
}

export interface SystemSettings {
  id: string;
  key: string;
  value: any;
  type: 'string' | 'number' | 'boolean' | 'object' | 'array';
  description?: string;
  category: 'general' | 'security' | 'performance' | 'integration' | 'maintenance';
  isEditable: boolean;
  isPublic: boolean;
  created_at: string;
  updated_at: string;
}

export interface SettingsState {
  userPreferences: UserPreferences | null;
  notificationSettings: NotificationSettings | null;
  dashboardSettings: DashboardSettings | null;
  systemSettings: SystemSettings[];
  loading: boolean;
  error: string | null;
  lastUpdate: string | null;
}

/**
 * Settings Service Class
 * 
 * Provides methods for managing application settings and user preferences.
 * Handles settings synchronization and validation.
 */
class SettingsService {
  // ============================================================================
  // USER PREFERENCES
  // ============================================================================

  /**
   * Get user preferences
   * 
   * @param userId - User ID
   * @returns Promise resolving to user preferences
   */
  async getUserPreferences(userId: string) {
    return apiService.getUserPreferences(userId);
  }

  /**
   * Update user preferences
   * 
   * @param userId - User ID
   * @param preferences - Updated preferences
   * @returns Promise resolving to updated preferences
   */
  async updateUserPreferences(userId: string, preferences: Partial<UserPreferences>) {
    return apiService.updateUserPreferences(userId, preferences);
  }

  /**
   * Reset user preferences to defaults
   * 
   * @param userId - User ID
   * @returns Promise resolving to reset preferences
   */
  async resetUserPreferences(userId: string) {
    return apiService.resetUserPreferences(userId);
  }

  // ============================================================================
  // NOTIFICATION SETTINGS
  // ============================================================================

  /**
   * Get notification settings
   * 
   * @param userId - User ID
   * @returns Promise resolving to notification settings
   */
  async getNotificationSettings(userId: string) {
    return apiService.getNotificationSettings(userId);
  }

  /**
   * Update notification settings
   * 
   * @param userId - User ID
   * @param settings - Updated notification settings
   * @returns Promise resolving to updated settings
   */
  async updateNotificationSettings(userId: string, settings: Partial<NotificationSettings>) {
    return apiService.updateNotificationSettings(userId, settings);
  }

  /**
   * Test notification settings
   * 
   * @param userId - User ID
   * @param type - Notification type to test
   * @returns Promise resolving to test result
   */
  async testNotificationSettings(userId: string, type: string) {
    return apiService.testNotificationSettings(userId, type);
  }

  // ============================================================================
  // DASHBOARD SETTINGS
  // ============================================================================

  /**
   * Get dashboard settings
   * 
   * @param userId - User ID
   * @returns Promise resolving to dashboard settings
   */
  async getDashboardSettings(userId: string) {
    return apiService.getDashboardSettings(userId);
  }

  /**
   * Update dashboard settings
   * 
   * @param userId - User ID
   * @param settings - Updated dashboard settings
   * @returns Promise resolving to updated settings
   */
  async updateDashboardSettings(userId: string, settings: Partial<DashboardSettings>) {
    return apiService.updateDashboardSettings(userId, settings);
  }

  /**
   * Reset dashboard settings to defaults
   * 
   * @param userId - User ID
   * @returns Promise resolving to reset settings
   */
  async resetDashboardSettings(userId: string) {
    return apiService.resetDashboardSettings(userId);
  }

  // ============================================================================
  // SYSTEM SETTINGS
  // ============================================================================

  /**
   * Get system settings
   * 
   * @param category - Optional category filter
   * @returns Promise resolving to system settings
   */
  async getSystemSettings(category?: string) {
    return apiService.getSystemSettings(category);
  }

  /**
   * Get specific system setting
   * 
   * @param key - Setting key
   * @returns Promise resolving to system setting
   */
  async getSystemSetting(key: string) {
    return apiService.getSystemSetting(key);
  }

  /**
   * Update system setting
   * 
   * @param key - Setting key
   * @param value - New setting value
   * @returns Promise resolving to updated setting
   */
  async updateSystemSetting(key: string, value: any) {
    return apiService.updateSystemSetting(key, value);
  }

  /**
   * Reset system setting to default
   * 
   * @param key - Setting key
   * @returns Promise resolving to reset setting
   */
  async resetSystemSetting(key: string) {
    return apiService.resetSystemSetting(key);
  }

  // ============================================================================
  // SETTINGS MANAGEMENT
  // ============================================================================

  /**
   * Export user settings
   * 
   * @param userId - User ID
   * @param format - Export format (json, yaml)
   * @returns Promise resolving to exported settings
   */
  async exportUserSettings(userId: string, format: 'json' | 'yaml' = 'json') {
    return apiService.exportUserSettings(userId, format);
  }

  /**
   * Import user settings
   * 
   * @param userId - User ID
   * @param settings - Settings to import
   * @param merge - Whether to merge with existing settings
   * @returns Promise resolving to imported settings
   */
  async importUserSettings(userId: string, settings: any, merge: boolean = false) {
    return apiService.importUserSettings(userId, settings, merge);
  }

  /**
   * Validate settings
   * 
   * @param settings - Settings to validate
   * @returns Promise resolving to validation result
   */
  async validateSettings(settings: any) {
    return apiService.validateSettings(settings);
  }

  /**
   * Get settings schema
   * 
   * @param category - Optional category filter
   * @returns Promise resolving to settings schema
   */
  async getSettingsSchema(category?: string) {
    return apiService.getSettingsSchema(category);
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /**
   * Get default user preferences
   * 
   * @returns Default user preferences
   */
  getDefaultUserPreferences(): Partial<UserPreferences> {
    return {
      language: 'en',
      timezone: 'UTC',
      dateFormat: 'YYYY-MM-DD',
      timeFormat: '24h',
      numberFormat: 'en-US',
      currency: 'USD',
      units: 'metric',
      dashboardLayout: 'grid',
      defaultView: 'production',
      autoRefresh: true,
      refreshInterval: 30,
      showTooltips: true,
      showAnimations: true,
      compactMode: false,
    };
  }

  /**
   * Get default notification settings
   * 
   * @returns Default notification settings
   */
  getDefaultNotificationSettings(): Partial<NotificationSettings> {
    return {
      emailNotifications: true,
      pushNotifications: true,
      smsNotifications: false,
      notificationTypes: {
        productionAlerts: true,
        equipmentFaults: true,
        andonEvents: true,
        qualityIssues: true,
        maintenanceReminders: true,
        systemUpdates: false,
        reportReady: true,
      },
      notificationFrequency: 'immediate',
      quietHours: {
        enabled: false,
        startTime: '22:00',
        endTime: '06:00',
        timezone: 'UTC',
      },
    };
  }

  /**
   * Get default dashboard settings
   * 
   * @returns Default dashboard settings
   */
  getDefaultDashboardSettings(): Partial<DashboardSettings> {
    return {
      layout: 'grid',
      widgets: [],
      defaultFilters: {},
      autoRefresh: true,
      refreshInterval: 30,
      showEmptyStates: true,
      showLoadingStates: true,
    };
  }

  /**
   * Format date according to user preferences
   * 
   * @param date - Date to format
   * @param preferences - User preferences
   * @returns Formatted date string
   */
  formatDate(date: Date | string, preferences: UserPreferences): string {
    const dateObj = typeof date === 'string' ? new Date(date) : date;
    
    switch (preferences.dateFormat) {
      case 'DD/MM/YYYY':
        return dateObj.toLocaleDateString('en-GB');
      case 'MM/DD/YYYY':
        return dateObj.toLocaleDateString('en-US');
      case 'YYYY-MM-DD':
        return dateObj.toISOString().split('T')[0];
      default:
        return dateObj.toLocaleDateString();
    }
  }

  /**
   * Format time according to user preferences
   * 
   * @param date - Date to format
   * @param preferences - User preferences
   * @returns Formatted time string
   */
  formatTime(date: Date | string, preferences: UserPreferences): string {
    const dateObj = typeof date === 'string' ? new Date(date) : date;
    
    const options: Intl.DateTimeFormatOptions = {
      hour: '2-digit',
      minute: '2-digit',
    };
    
    if (preferences.timeFormat === '12h') {
      options.hour12 = true;
    } else {
      options.hour12 = false;
    }
    
    return dateObj.toLocaleTimeString(preferences.numberFormat, options);
  }

  /**
   * Format number according to user preferences
   * 
   * @param number - Number to format
   * @param preferences - User preferences
   * @param decimals - Number of decimal places
   * @returns Formatted number string
   */
  formatNumber(number: number, preferences: UserPreferences, decimals: number = 2): string {
    return number.toLocaleString(preferences.numberFormat, {
      minimumFractionDigits: decimals,
      maximumFractionDigits: decimals,
    });
  }

  /**
   * Format currency according to user preferences
   * 
   * @param amount - Amount to format
   * @param preferences - User preferences
   * @returns Formatted currency string
   */
  formatCurrency(amount: number, preferences: UserPreferences): string {
    return new Intl.NumberFormat(preferences.numberFormat, {
      style: 'currency',
      currency: preferences.currency,
    }).format(amount);
  }

  /**
   * Get timezone offset
   * 
   * @param timezone - Timezone string
   * @returns Timezone offset in minutes
   */
  getTimezoneOffset(timezone: string): number {
    try {
      const now = new Date();
      const utc = new Date(now.getTime() + (now.getTimezoneOffset() * 60000));
      const targetTime = new Date(utc.toLocaleString('en-US', { timeZone: timezone }));
      return (targetTime.getTime() - utc.getTime()) / 60000;
    } catch (error) {
      return 0;
    }
  }

  /**
   * Convert timezone
   * 
   * @param date - Date to convert
   * @param fromTimezone - Source timezone
   * @param toTimezone - Target timezone
   * @returns Converted date
   */
  convertTimezone(date: Date | string, fromTimezone: string, toTimezone: string): Date {
    const dateObj = typeof date === 'string' ? new Date(date) : date;
    
    // Create date in source timezone
    const sourceTime = new Date(dateObj.toLocaleString('en-US', { timeZone: fromTimezone }));
    
    // Convert to target timezone
    const targetTime = new Date(sourceTime.toLocaleString('en-US', { timeZone: toTimezone }));
    
    return targetTime;
  }

  /**
   * Validate settings object
   * 
   * @param settings - Settings to validate
   * @param schema - Settings schema
   * @returns Validation result
   */
  validateSettingsObject(settings: any, schema: any): { isValid: boolean; errors: string[] } {
    const errors: string[] = [];
    
    // Basic validation logic
    if (schema.required) {
      schema.required.forEach((field: string) => {
        if (settings[field] === undefined || settings[field] === null) {
          errors.push(`${field} is required`);
        }
      });
    }
    
    // Type validation
    if (schema.properties) {
      Object.keys(schema.properties).forEach(key => {
        const property = schema.properties[key];
        const value = settings[key];
        
        if (value !== undefined && value !== null) {
          if (property.type === 'string' && typeof value !== 'string') {
            errors.push(`${key} must be a string`);
          } else if (property.type === 'number' && typeof value !== 'number') {
            errors.push(`${key} must be a number`);
          } else if (property.type === 'boolean' && typeof value !== 'boolean') {
            errors.push(`${key} must be a boolean`);
          }
        }
      });
    }
    
    return {
      isValid: errors.length === 0,
      errors,
    };
  }

  /**
   * Merge settings objects
   * 
   * @param base - Base settings object
   * @param override - Override settings object
   * @returns Merged settings object
   */
  mergeSettings(base: any, override: any): any {
    const merged = { ...base };
    
    Object.keys(override).forEach(key => {
      if (typeof override[key] === 'object' && override[key] !== null && !Array.isArray(override[key])) {
        merged[key] = this.mergeSettings(base[key] || {}, override[key]);
      } else {
        merged[key] = override[key];
      }
    });
    
    return merged;
  }

  /**
   * Get settings category color
   * 
   * @param category - Settings category
   * @returns Color code for category
   */
  getSettingsCategoryColor(category: string): string {
    const categoryColors: Record<string, string> = {
      'general': '#4CAF50',
      'security': '#F44336',
      'performance': '#FF9800',
      'integration': '#2196F3',
      'maintenance': '#9C27B0',
    };
    return categoryColors[category] || '#9E9E9E';
  }

  /**
   * Get settings category icon
   * 
   * @param category - Settings category
   * @returns Icon name for category
   */
  getSettingsCategoryIcon(category: string): string {
    const categoryIcons: Record<string, string> = {
      'general': 'settings',
      'security': 'shield',
      'performance': 'trending-up',
      'integration': 'link',
      'maintenance': 'wrench',
    };
    return categoryIcons[category] || 'circle';
  }
}

// Export singleton instance
export const settingsService = new SettingsService();
export default settingsService;
