/**
 * MS5.0 Floor Dashboard - Hooks Index
 * 
 * This file exports all custom hooks for easy importing.
 */

export { default as usePermissions } from './usePermissions';
export { default as useWebSocket } from './useWebSocket';
export { default as useRealTimeData } from './useRealTimeData';
export { default as useLineData } from './useLineData';
export { default as useOfflineSync } from './useOfflineSync';
export { default as usePushNotifications } from './usePushNotifications';

// Re-export types for convenience
export type { UseWebSocketOptions, UseWebSocketReturn } from './useWebSocket';
export type { UseRealTimeDataOptions, UseRealTimeDataReturn } from './useRealTimeData';
export type { UseLineDataOptions, UseLineDataReturn } from './useLineData';
export type { UseOfflineSyncOptions, UseOfflineSyncReturn } from './useOfflineSync';
export type { UsePushNotificationsOptions, UsePushNotificationsReturn } from './usePushNotifications';
