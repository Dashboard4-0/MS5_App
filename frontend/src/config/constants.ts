/**
 * MS5.0 Floor Dashboard - Application Constants
 * 
 * This file contains all application constants including API endpoints,
 * configuration values, and application settings.
 */

// API Configuration
export const API_CONFIG = {
  BASE_URL: __DEV__ ? 'http://localhost:8000' : 'https://api.ms5floor.com',
  WS_URL: __DEV__ ? 'ws://localhost:8000' : 'wss://api.ms5floor.com',
  TIMEOUT: 30000,
  RETRY_ATTEMPTS: 3,
  RETRY_DELAY: 1000,
};

// WebSocket Configuration
export const WS_CONFIG = {
  HEARTBEAT_INTERVAL: 30000,
  RECONNECT_INTERVAL: 5000,
  MAX_RECONNECT_ATTEMPTS: 10,
  PING_TIMEOUT: 10000,
};

// Storage Keys
export const STORAGE_KEYS = {
  AUTH_TOKEN: 'auth_token',
  REFRESH_TOKEN: 'refresh_token',
  USER_DATA: 'user_data',
  OFFLINE_DATA: 'offline_data',
  SETTINGS: 'app_settings',
  CACHE: 'app_cache',
};

// User Roles
export const USER_ROLES = {
  ADMIN: 'admin',
  PRODUCTION_MANAGER: 'production_manager',
  SHIFT_MANAGER: 'shift_manager',
  ENGINEER: 'engineer',
  OPERATOR: 'operator',
  MAINTENANCE: 'maintenance',
  QUALITY: 'quality',
  VIEWER: 'viewer',
} as const;

// Permission Types
export const PERMISSIONS = {
  // User Management
  USER_READ: 'user:read',
  USER_WRITE: 'user:write',
  USER_DELETE: 'user:delete',
  
  // Production Management
  PRODUCTION_READ: 'production:read',
  PRODUCTION_WRITE: 'production:write',
  PRODUCTION_DELETE: 'production:delete',
  
  // Line Management
  LINE_READ: 'line:read',
  LINE_WRITE: 'line:write',
  LINE_DELETE: 'line:delete',
  
  // Schedule Management
  SCHEDULE_READ: 'schedule:read',
  SCHEDULE_WRITE: 'schedule:write',
  SCHEDULE_DELETE: 'schedule:delete',
  
  // Job Management
  JOB_READ: 'job:read',
  JOB_WRITE: 'job:write',
  JOB_ASSIGN: 'job:assign',
  JOB_ACCEPT: 'job:accept',
  JOB_START: 'job:start',
  JOB_COMPLETE: 'job:complete',
  
  // Checklist Management
  CHECKLIST_READ: 'checklist:read',
  CHECKLIST_WRITE: 'checklist:write',
  CHECKLIST_COMPLETE: 'checklist:complete',
  
  // OEE Management
  OEE_READ: 'oee:read',
  OEE_CALCULATE: 'oee:calculate',
  ANALYTICS_READ: 'analytics:read',
  
  // Downtime Management
  DOWNTIME_READ: 'downtime:read',
  DOWNTIME_WRITE: 'downtime:write',
  DOWNTIME_CONFIRM: 'downtime:confirm',
  
  // Andon Management
  ANDON_READ: 'andon:read',
  ANDON_CREATE: 'andon:create',
  ANDON_ACKNOWLEDGE: 'andon:acknowledge',
  ANDON_RESOLVE: 'andon:resolve',
  
  // Equipment Management
  EQUIPMENT_READ: 'equipment:read',
  EQUIPMENT_WRITE: 'equipment:write',
  EQUIPMENT_MAINTENANCE: 'equipment:maintenance',
  
  // Reports
  REPORTS_READ: 'reports:read',
  REPORTS_WRITE: 'reports:write',
  REPORTS_GENERATE: 'reports:generate',
  REPORTS_DELETE: 'reports:delete',
  REPORTS_SCHEDULE: 'reports:schedule',
  REPORTS_TEMPLATE_MANAGE: 'reports:template:manage',
  
  // Dashboard
  DASHBOARD_READ: 'dashboard:read',
  DASHBOARD_WRITE: 'dashboard:write',
  
  // Quality Management
  QUALITY_READ: 'quality:read',
  QUALITY_WRITE: 'quality:write',
  QUALITY_APPROVE: 'quality:approve',
  
  // Maintenance
  MAINTENANCE_READ: 'maintenance:read',
  MAINTENANCE_WRITE: 'maintenance:write',
  MAINTENANCE_SCHEDULE: 'maintenance:schedule',
  
  // System Administration
  SYSTEM_CONFIG: 'system:config',
  SYSTEM_MONITOR: 'system:monitor',
  SYSTEM_MAINTENANCE: 'system:maintenance',
} as const;

// Status Types
export const STATUS_TYPES = {
  // Production Line Status
  LINE_RUNNING: 'running',
  LINE_STOPPED: 'stopped',
  LINE_FAULT: 'fault',
  LINE_MAINTENANCE: 'maintenance',
  LINE_SETUP: 'setup',
  LINE_IDLE: 'idle',
  
  // Job Status
  JOB_ASSIGNED: 'assigned',
  JOB_ACCEPTED: 'accepted',
  JOB_IN_PROGRESS: 'in_progress',
  JOB_COMPLETED: 'completed',
  JOB_CANCELLED: 'cancelled',
  JOB_PAUSED: 'paused',
  
  // Schedule Status
  SCHEDULE_SCHEDULED: 'scheduled',
  SCHEDULE_IN_PROGRESS: 'in_progress',
  SCHEDULE_COMPLETED: 'completed',
  SCHEDULE_CANCELLED: 'cancelled',
  SCHEDULE_PAUSED: 'paused',
  
  // Andon Status
  ANDON_OPEN: 'open',
  ANDON_ACKNOWLEDGED: 'acknowledged',
  ANDON_RESOLVED: 'resolved',
  ANDON_ESCALATED: 'escalated',
} as const;

// Priority Levels
export const PRIORITY_LEVELS = {
  LOW: 'low',
  MEDIUM: 'medium',
  HIGH: 'high',
  CRITICAL: 'critical',
} as const;

// Event Types
export const EVENT_TYPES = {
  LINE_STATUS_UPDATE: 'line_status_update',
  EQUIPMENT_STATUS_CHANGE: 'equipment_status_change',
  DOWNTIME_EVENT: 'downtime_event',
  ANDON_ALERT: 'andon_alert',
  OEE_UPDATE: 'oee_update',
  JOB_UPDATE: 'job_update',
  SYSTEM_ALERT: 'system_alert',
} as const;

// OEE Thresholds
export const OEE_THRESHOLDS = {
  EXCELLENT: 0.85,
  GOOD: 0.70,
  FAIR: 0.50,
  POOR: 0.30,
};

// Animation Durations
export const ANIMATION_DURATION = {
  FAST: 200,
  NORMAL: 300,
  SLOW: 500,
  VERY_SLOW: 1000,
};

// Screen Dimensions (Tablet Optimized)
export const SCREEN_CONFIG = {
  TABLET_MIN_WIDTH: 768,
  TABLET_MIN_HEIGHT: 1024,
  LANDSCAPE_MIN_WIDTH: 1024,
  LANDSCAPE_MIN_HEIGHT: 768,
};

// Touch Targets (Accessibility)
export const TOUCH_TARGETS = {
  MIN_SIZE: 44,
  RECOMMENDED_SIZE: 48,
  LARGE_SIZE: 56,
};

// Pagination
export const PAGINATION = {
  DEFAULT_PAGE_SIZE: 20,
  LARGE_PAGE_SIZE: 50,
  MAX_PAGE_SIZE: 100,
};

// Cache Settings
export const CACHE_CONFIG = {
  DEFAULT_TTL: 300000, // 5 minutes
  LONG_TTL: 1800000,   // 30 minutes
  SHORT_TTL: 60000,    // 1 minute
  MAX_CACHE_SIZE: 50,  // MB
};

// Offline Settings
export const OFFLINE_CONFIG = {
  MAX_OFFLINE_ITEMS: 1000,
  SYNC_INTERVAL: 30000, // 30 seconds
  RETRY_SYNC_ATTEMPTS: 5,
  OFFLINE_INDICATOR_DELAY: 2000,
};

// Validation Rules
export const VALIDATION_RULES = {
  PASSWORD_MIN_LENGTH: 8,
  PASSWORD_MAX_LENGTH: 128,
  USERNAME_MIN_LENGTH: 3,
  USERNAME_MAX_LENGTH: 50,
  DESCRIPTION_MAX_LENGTH: 500,
  NOTES_MAX_LENGTH: 1000,
};

// Date/Time Formats
export const DATE_FORMATS = {
  DISPLAY: 'MMM DD, YYYY',
  SHORT: 'MM/DD/YY',
  LONG: 'MMMM DD, YYYY',
  TIME: 'HH:mm',
  DATETIME: 'MMM DD, YYYY HH:mm',
  ISO: 'YYYY-MM-DDTHH:mm:ss.SSSZ',
};

// File Upload
export const FILE_UPLOAD = {
  MAX_SIZE: 10 * 1024 * 1024, // 10MB
  ALLOWED_TYPES: ['image/jpeg', 'image/png', 'application/pdf'],
  COMPRESSION_QUALITY: 0.8,
};

// Haptic Feedback
export const HAPTIC_FEEDBACK = {
  LIGHT: 'light',
  MEDIUM: 'medium',
  HEAVY: 'heavy',
  SUCCESS: 'success',
  WARNING: 'warning',
  ERROR: 'error',
};

// Theme
export const THEME_CONFIG = {
  LIGHT: 'light',
  DARK: 'dark',
  AUTO: 'auto',
};

// Language Support
export const LANGUAGES = {
  EN: 'en',
  ES: 'es',
  FR: 'fr',
  DE: 'de',
  IT: 'it',
  PT: 'pt',
  ZH: 'zh',
  JA: 'ja',
  KO: 'ko',
};

// Default Settings
export const DEFAULT_SETTINGS = {
  theme: THEME_CONFIG.AUTO,
  language: LANGUAGES.EN,
  hapticFeedback: true,
  soundEffects: true,
  autoSync: true,
  offlineMode: true,
  notifications: true,
  locationServices: false,
  analytics: true,
};

// Error Messages
export const ERROR_MESSAGES = {
  NETWORK_ERROR: 'Network connection error. Please check your internet connection.',
  SERVER_ERROR: 'Server error. Please try again later.',
  AUTHENTICATION_ERROR: 'Authentication failed. Please log in again.',
  AUTHORIZATION_ERROR: 'You do not have permission to perform this action.',
  VALIDATION_ERROR: 'Please check your input and try again.',
  OFFLINE_ERROR: 'This feature requires an internet connection.',
  TIMEOUT_ERROR: 'Request timed out. Please try again.',
  UNKNOWN_ERROR: 'An unexpected error occurred. Please try again.',
};

// Success Messages
export const SUCCESS_MESSAGES = {
  LOGIN_SUCCESS: 'Successfully logged in',
  LOGOUT_SUCCESS: 'Successfully logged out',
  DATA_SAVED: 'Data saved successfully',
  DATA_SYNCED: 'Data synchronized successfully',
  JOB_ACCEPTED: 'Job accepted successfully',
  JOB_STARTED: 'Job started successfully',
  JOB_COMPLETED: 'Job completed successfully',
  ANDON_CREATED: 'Andon event created successfully',
  ANDON_ACKNOWLEDGED: 'Andon event acknowledged',
  ANDON_RESOLVED: 'Andon event resolved',
  REPORT_GENERATED: 'Report generated successfully',
  SETTINGS_SAVED: 'Settings saved successfully',
};

// Loading Messages
export const LOADING_MESSAGES = {
  LOADING: 'Loading...',
  SAVING: 'Saving...',
  SYNCING: 'Synchronizing...',
  AUTHENTICATING: 'Authenticating...',
  GENERATING_REPORT: 'Generating report...',
  PROCESSING: 'Processing...',
  UPLOADING: 'Uploading...',
  DOWNLOADING: 'Downloading...',
};

export type UserRole = typeof USER_ROLES[keyof typeof USER_ROLES];
export type Permission = typeof PERMISSIONS[keyof typeof PERMISSIONS];
export type StatusType = typeof STATUS_TYPES[keyof typeof STATUS_TYPES];
export type PriorityLevel = typeof PRIORITY_LEVELS[keyof typeof PRIORITY_LEVELS];
export type EventType = typeof EVENT_TYPES[keyof typeof EVENT_TYPES];
export type Theme = typeof THEME_CONFIG[keyof typeof THEME_CONFIG];
export type Language = typeof LANGUAGES[keyof typeof LANGUAGES];
