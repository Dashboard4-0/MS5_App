/**
 * MS5.0 Floor Dashboard - API Configuration
 * 
 * This file contains API endpoint definitions and configuration
 * for communicating with the MS5.0 backend services.
 */

import { API_CONFIG } from './constants';

// Base API endpoints
export const API_ENDPOINTS = {
  // Authentication
  AUTH: {
    LOGIN: '/api/v1/auth/login',
    REFRESH: '/api/v1/auth/refresh',
    LOGOUT: '/api/v1/auth/logout',
    PROFILE: '/api/v1/auth/profile',
    CHANGE_PASSWORD: '/api/v1/auth/change-password',
  },
  
  // Production Management
  PRODUCTION: {
    LINES: '/api/v1/production/lines',
    LINE_BY_ID: (id: string) => `/api/v1/production/lines/${id}`,
    SCHEDULES: '/api/v1/production/schedules',
    SCHEDULE_BY_ID: (id: string) => `/api/v1/production/schedules/${id}`,
    STATISTICS: '/api/v1/production/statistics',
  },
  
  // Job Management
  JOBS: {
    MY_JOBS: '/api/v1/jobs/my-jobs',
    JOB_BY_ID: (id: string) => `/api/v1/jobs/${id}`,
    ACCEPT: (id: string) => `/api/v1/jobs/${id}/accept`,
    START: (id: string) => `/api/v1/jobs/${id}/start`,
    COMPLETE: (id: string) => `/api/v1/jobs/${id}/complete`,
    CANCEL: (id: string) => `/api/v1/jobs/${id}/cancel`,
    PAUSE: (id: string) => `/api/v1/jobs/${id}/pause`,
    RESUME: (id: string) => `/api/v1/jobs/${id}/resume`,
  },
  
  // OEE & Analytics
  OEE: {
    LINES: (id: string) => `/api/v1/oee/lines/${id}`,
    EQUIPMENT: (code: string) => `/api/v1/oee/equipment/${code}`,
    CALCULATE: '/api/v1/oee/calculate',
    HISTORICAL: '/api/v1/oee/historical',
    TRENDS: '/api/v1/oee/trends',
  },
  
  // Andon System
  ANDON: {
    EVENTS: '/api/v1/andon/events',
    EVENT_BY_ID: (id: string) => `/api/v1/andon/events/${id}`,
    ACKNOWLEDGE: (id: string) => `/api/v1/andon/events/${id}/acknowledge`,
    RESOLVE: (id: string) => `/api/v1/andon/events/${id}/resolve`,
    ESCALATION_TREE: '/api/v1/andon/escalation-tree',
    STATISTICS: '/api/v1/andon/statistics',
  },
  
  // Equipment Management
  EQUIPMENT: {
    STATUS: '/api/v1/equipment/status',
    EQUIPMENT_BY_CODE: (code: string) => `/api/v1/equipment/${code}/status`,
    FAULTS: (code: string) => `/api/v1/equipment/${code}/faults`,
    MAINTENANCE: '/api/v1/equipment/maintenance',
    DIAGNOSTICS: '/api/v1/equipment/diagnostics',
  },
  
  // Dashboard
  DASHBOARD: {
    LINES: '/api/v1/dashboard/lines',
    LINE_BY_ID: (id: string) => `/api/v1/dashboard/lines/${id}`,
    LINE_STATUS: (id: string) => `/api/v1/dashboard/lines/${id}/status`,
    LINE_OEE: (id: string) => `/api/v1/dashboard/lines/${id}/oee`,
    LINE_DOWNTIME: (id: string) => `/api/v1/dashboard/lines/${id}/downtime`,
    OVERVIEW: '/api/v1/dashboard/overview',
    KPIS: '/api/v1/dashboard/kpis',
  },
  
  // Reports
  REPORTS: {
    PRODUCTION: '/api/v1/reports/production',
    GENERATE: '/api/v1/reports/production/generate',
    REPORT_BY_ID: (id: string) => `/api/v1/reports/production/${id}`,
    PDF: (id: string) => `/api/v1/reports/production/${id}/pdf`,
    CUSTOM: '/api/v1/reports/custom',
    TEMPLATES: '/api/v1/reports/templates',
  },
  
  // Checklists
  CHECKLISTS: {
    TEMPLATES: '/api/v1/checklists/templates',
    COMPLETE: '/api/v1/checklists/complete',
    COMPLETION_BY_ID: (id: string) => `/api/v1/checklists/${id}`,
  },
  
  // Downtime Management
  DOWNTIME: {
    EVENTS: '/api/v1/downtime/events',
    EVENT_BY_ID: (id: string) => `/api/v1/downtime/events/${id}`,
    REASONS: '/api/v1/downtime/reasons',
    STATISTICS: '/api/v1/downtime/statistics',
  },
  
  // Quality Management
  QUALITY: {
    CHECKS: '/api/v1/quality/checks',
    DEFECTS: '/api/v1/quality/defects',
    CODES: '/api/v1/quality/codes',
    STATISTICS: '/api/v1/quality/statistics',
  },
  
  // Maintenance
  MAINTENANCE: {
    WORK_ORDERS: '/api/v1/maintenance/work-orders',
    TASKS: '/api/v1/maintenance/tasks',
    SCHEDULES: '/api/v1/maintenance/schedules',
    STATISTICS: '/api/v1/maintenance/statistics',
  },
  
  // Users
  USERS: {
    PROFILE: '/api/v1/users/profile',
    ROLES: '/api/v1/users/roles',
    PERMISSIONS: '/api/v1/users/permissions',
    TEAM: '/api/v1/users/team',
  },
  
  // WebSocket
  WEBSOCKET: {
    CONNECTION: '/ws',
    SUBSCRIBE_LINE: (id: string) => `/ws?line_id=${id}`,
    SUBSCRIBE_EQUIPMENT: (code: string) => `/ws?equipment_code=${code}`,
  },
  
  // Health Check
  HEALTH: {
    BASIC: '/health',
    DETAILED: '/health/detailed',
    METRICS: '/metrics',
  },
} as const;

// API Configuration
export const API_CONFIGURATION = {
  baseURL: API_CONFIG.BASE_URL,
  timeout: API_CONFIG.TIMEOUT,
  retryAttempts: API_CONFIG.RETRY_ATTEMPTS,
  retryDelay: API_CONFIG.RETRY_DELAY,
  headers: {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  },
};

// WebSocket Configuration
export const WS_CONFIGURATION = {
  baseURL: API_CONFIG.WS_URL,
  heartbeatInterval: 30000,
  reconnectInterval: 5000,
  maxReconnectAttempts: 10,
  pingTimeout: 10000,
};

// Request/Response Interceptors
export const INTERCEPTORS = {
  REQUEST: {
    ADD_AUTH_TOKEN: true,
    ADD_TIMESTAMP: true,
    ADD_REQUEST_ID: true,
    LOG_REQUESTS: __DEV__,
  },
  RESPONSE: {
    LOG_RESPONSES: __DEV__,
    HANDLE_ERRORS: true,
    RETRY_ON_FAILURE: true,
    CACHE_RESPONSES: true,
  },
};

// Cache Configuration
export const CACHE_CONFIGURATION = {
  ENABLED: true,
  DEFAULT_TTL: 300000, // 5 minutes
  MAX_SIZE: 50, // MB
  STRATEGIES: {
    NETWORK_FIRST: 'network-first',
    CACHE_FIRST: 'cache-first',
    CACHE_ONLY: 'cache-only',
    NETWORK_ONLY: 'network-only',
  },
};

// Offline Configuration
export const OFFLINE_CONFIGURATION = {
  ENABLED: true,
  SYNC_INTERVAL: 30000, // 30 seconds
  MAX_OFFLINE_ITEMS: 1000,
  RETRY_SYNC_ATTEMPTS: 5,
  QUEUE_PRIORITY: {
    HIGH: 1,
    MEDIUM: 2,
    LOW: 3,
  },
};

// File Upload Configuration
export const FILE_UPLOAD_CONFIGURATION = {
  MAX_SIZE: 10 * 1024 * 1024, // 10MB
  ALLOWED_TYPES: ['image/jpeg', 'image/png', 'application/pdf'],
  COMPRESSION_QUALITY: 0.8,
  CHUNK_SIZE: 1024 * 1024, // 1MB chunks
  RETRY_ATTEMPTS: 3,
};

// Pagination Configuration
export const PAGINATION_CONFIGURATION = {
  DEFAULT_PAGE_SIZE: 20,
  MAX_PAGE_SIZE: 100,
  PAGE_PARAM: 'page',
  SIZE_PARAM: 'size',
  SORT_PARAM: 'sort',
  FILTER_PARAM: 'filter',
};

// Error Handling Configuration
export const ERROR_HANDLING_CONFIGURATION = {
  SHOW_TOAST: true,
  LOG_ERRORS: true,
  RETRY_AUTOMATICALLY: true,
  FALLBACK_MESSAGES: true,
  TIMEOUT_HANDLING: true,
};

// Performance Configuration
export const PERFORMANCE_CONFIGURATION = {
  ENABLE_METRICS: true,
  LOG_PERFORMANCE: __DEV__,
  OPTIMIZE_IMAGES: true,
  LAZY_LOADING: true,
  PREFETCH_DATA: true,
  DEBOUNCE_DELAY: 300,
};

export type APIEndpoint = typeof API_ENDPOINTS;
export type CacheStrategy = typeof CACHE_CONFIGURATION.STRATEGIES[keyof typeof CACHE_CONFIGURATION.STRATEGIES];
export type QueuePriority = typeof OFFLINE_CONFIGURATION.QUEUE_PRIORITY[keyof typeof OFFLINE_CONFIGURATION.QUEUE_PRIORITY];
