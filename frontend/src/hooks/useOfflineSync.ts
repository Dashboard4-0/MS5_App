/**
 * MS5.0 Floor Dashboard - Offline Sync Hook
 * 
 * This hook provides offline-first data synchronization with:
 * - Local storage management
 * - Background sync capabilities
 * - Conflict resolution
 * - Factory environment optimization
 * - Tablet-specific offline behavior
 */

import { useEffect, useState, useCallback, useRef } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { logger } from '../utils/logger';

// Offline sync configuration
interface OfflineSyncConfig {
  storageKey: string;
  syncInterval?: number;
  maxRetries?: number;
  retryDelay?: number;
  conflictResolution?: 'server' | 'client' | 'manual';
  encryption?: boolean;
  compression?: boolean;
}

// Data item interface
interface OfflineDataItem {
  id: string;
  type: string;
  data: any;
  timestamp: number;
  version: number;
  synced: boolean;
  conflict?: boolean;
  retryCount?: number;
}

// Sync status interface
interface SyncStatus {
  isOnline: boolean;
  isSyncing: boolean;
  lastSync: number;
  pendingItems: number;
  failedItems: number;
  totalItems: number;
}

// Hook return interface
interface UseOfflineSyncReturn {
  // Status
  status: SyncStatus;
  isOnline: boolean;
  isSyncing: boolean;
  
  // Data management
  saveData: (type: string, data: any) => Promise<void>;
  getData: (type: string) => Promise<any>;
  deleteData: (type: string, id: string) => Promise<void>;
  clearData: (type: string) => Promise<void>;
  
  // Sync operations
  syncNow: () => Promise<void>;
  retryFailed: () => Promise<void>;
  resolveConflicts: (resolution: 'server' | 'client') => Promise<void>;
  
  // Utilities
  getPendingItems: () => Promise<OfflineDataItem[]>;
  getFailedItems: () => Promise<OfflineDataItem[]>;
  getStorageSize: () => Promise<number>;
  clearStorage: () => Promise<void>;
}

/**
 * Offline Sync Hook
 * 
 * Provides offline-first data synchronization
 */
export const useOfflineSync = (config: OfflineSyncConfig): UseOfflineSyncReturn => {
  // State management
  const [status, setStatus] = useState<SyncStatus>({
    isOnline: navigator.onLine,
    isSyncing: false,
    lastSync: 0,
    pendingItems: 0,
    failedItems: 0,
    totalItems: 0
  });
  
  // Refs for sync management
  const syncTimerRef = useRef<NodeJS.Timeout | null>(null);
  const isOnlineRef = useRef(navigator.onLine);
  const pendingSyncRef = useRef<Set<string>>(new Set());
  
  /**
   * Update sync status
   */
  const updateStatus = useCallback(async () => {
    try {
      const allData = await AsyncStorage.getItem(config.storageKey);
      const items: OfflineDataItem[] = allData ? JSON.parse(allData) : [];
      
      const pendingItems = items.filter(item => !item.synced && !item.conflict).length;
      const failedItems = items.filter(item => item.retryCount && item.retryCount > 0).length;
      const totalItems = items.length;
      
      setStatus(prev => ({
        ...prev,
        pendingItems,
        failedItems,
        totalItems
      }));
    } catch (error) {
      logger.error('Error updating sync status', { error });
    }
  }, [config.storageKey]);
  
  /**
   * Save data offline
   */
  const saveData = useCallback(async (type: string, data: any): Promise<void> => {
    try {
      const item: OfflineDataItem = {
        id: `${type}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
        type,
        data,
        timestamp: Date.now(),
        version: 1,
        synced: false,
        retryCount: 0
      };
      
      // Get existing data
      const existingData = await AsyncStorage.getItem(config.storageKey);
      const items: OfflineDataItem[] = existingData ? JSON.parse(existingData) : [];
      
      // Add new item
      items.push(item);
      
      // Save to storage
      await AsyncStorage.setItem(config.storageKey, JSON.stringify(items));
      
      // Update status
      await updateStatus();
      
      // Mark for sync if online
      if (isOnlineRef.current) {
        pendingSyncRef.current.add(item.id);
        syncNow();
      }
      
      logger.debug('Data saved offline', { type, id: item.id });
    } catch (error) {
      logger.error('Error saving data offline', { error, type });
      throw error;
    }
  }, [config.storageKey, updateStatus]);
  
  /**
   * Get data from offline storage
   */
  const getData = useCallback(async (type: string): Promise<any> => {
    try {
      const allData = await AsyncStorage.getItem(config.storageKey);
      const items: OfflineDataItem[] = allData ? JSON.parse(allData) : [];
      
      const filteredItems = items.filter(item => item.type === type);
      return filteredItems.map(item => item.data);
    } catch (error) {
      logger.error('Error getting offline data', { error, type });
      return [];
    }
  }, [config.storageKey]);
  
  /**
   * Delete data from offline storage
   */
  const deleteData = useCallback(async (type: string, id: string): Promise<void> => {
    try {
      const allData = await AsyncStorage.getItem(config.storageKey);
      const items: OfflineDataItem[] = allData ? JSON.parse(allData) : [];
      
      const filteredItems = items.filter(item => !(item.type === type && item.id === id));
      
      await AsyncStorage.setItem(config.storageKey, JSON.stringify(filteredItems));
      await updateStatus();
      
      logger.debug('Data deleted from offline storage', { type, id });
    } catch (error) {
      logger.error('Error deleting offline data', { error, type, id });
      throw error;
    }
  }, [config.storageKey, updateStatus]);
  
  /**
   * Clear data by type
   */
  const clearData = useCallback(async (type: string): Promise<void> => {
    try {
      const allData = await AsyncStorage.getItem(config.storageKey);
      const items: OfflineDataItem[] = allData ? JSON.parse(allData) : [];
      
      const filteredItems = items.filter(item => item.type !== type);
      
      await AsyncStorage.setItem(config.storageKey, JSON.stringify(filteredItems));
      await updateStatus();
      
      logger.debug('Data cleared from offline storage', { type });
    } catch (error) {
      logger.error('Error clearing offline data', { error, type });
      throw error;
    }
  }, [config.storageKey, updateStatus]);
  
  /**
   * Sync data with server
   */
  const syncNow = useCallback(async (): Promise<void> => {
    if (status.isSyncing || !isOnlineRef.current) {
      return;
    }
    
    setStatus(prev => ({ ...prev, isSyncing: true }));
    
    try {
      const allData = await AsyncStorage.getItem(config.storageKey);
      const items: OfflineDataItem[] = allData ? JSON.parse(allData) : [];
      
      const pendingItems = items.filter(item => !item.synced && !item.conflict);
      
      for (const item of pendingItems) {
        try {
          // Attempt to sync item
          await syncItem(item);
          
          // Mark as synced
          item.synced = true;
          item.retryCount = 0;
          
          logger.debug('Item synced successfully', { id: item.id, type: item.type });
        } catch (error) {
          // Handle sync failure
          item.retryCount = (item.retryCount || 0) + 1;
          
          if (item.retryCount >= (config.maxRetries || 3)) {
            item.conflict = true;
            logger.error('Item sync failed after max retries', { 
              id: item.id, 
              type: item.type, 
              retryCount: item.retryCount 
            });
          } else {
            logger.warn('Item sync failed, will retry', { 
              id: item.id, 
              type: item.type, 
              retryCount: item.retryCount 
            });
          }
        }
      }
      
      // Save updated items
      await AsyncStorage.setItem(config.storageKey, JSON.stringify(items));
      
      // Update status
      setStatus(prev => ({
        ...prev,
        isSyncing: false,
        lastSync: Date.now()
      }));
      
      await updateStatus();
      
      logger.info('Sync completed', {
        syncedItems: pendingItems.length,
        failedItems: items.filter(item => item.retryCount && item.retryCount > 0).length
      });
      
    } catch (error) {
      logger.error('Sync failed', { error });
      setStatus(prev => ({ ...prev, isSyncing: false }));
    }
  }, [status.isSyncing, config.storageKey, config.maxRetries, updateStatus]);
  
  /**
   * Sync individual item
   */
  const syncItem = useCallback(async (item: OfflineDataItem): Promise<void> => {
    // Simulate API call
    return new Promise((resolve, reject) => {
      setTimeout(() => {
        // Simulate random failures for testing
        if (Math.random() < 0.1) {
          reject(new Error('Simulated sync failure'));
        } else {
          resolve();
        }
      }, 100);
    });
  }, []);
  
  /**
   * Retry failed items
   */
  const retryFailed = useCallback(async (): Promise<void> => {
    try {
      const allData = await AsyncStorage.getItem(config.storageKey);
      const items: OfflineDataItem[] = allData ? JSON.parse(allData) : [];
      
      const failedItems = items.filter(item => item.retryCount && item.retryCount > 0);
      
      for (const item of failedItems) {
        item.retryCount = 0;
        item.conflict = false;
      }
      
      await AsyncStorage.setItem(config.storageKey, JSON.stringify(items));
      await updateStatus();
      
      // Trigger sync
      await syncNow();
      
      logger.info('Retrying failed items', { count: failedItems.length });
    } catch (error) {
      logger.error('Error retrying failed items', { error });
    }
  }, [config.storageKey, updateStatus, syncNow]);
  
  /**
   * Resolve conflicts
   */
  const resolveConflicts = useCallback(async (resolution: 'server' | 'client'): Promise<void> => {
    try {
      const allData = await AsyncStorage.getItem(config.storageKey);
      const items: OfflineDataItem[] = allData ? JSON.parse(allData) : [];
      
      const conflictItems = items.filter(item => item.conflict);
      
      for (const item of conflictItems) {
        if (resolution === 'server') {
          // Remove item (server wins)
          const index = items.indexOf(item);
          items.splice(index, 1);
        } else {
          // Keep item (client wins)
          item.conflict = false;
          item.synced = false;
        }
      }
      
      await AsyncStorage.setItem(config.storageKey, JSON.stringify(items));
      await updateStatus();
      
      logger.info('Conflicts resolved', { resolution, count: conflictItems.length });
    } catch (error) {
      logger.error('Error resolving conflicts', { error });
    }
  }, [config.storageKey, updateStatus]);
  
  /**
   * Get pending items
   */
  const getPendingItems = useCallback(async (): Promise<OfflineDataItem[]> => {
    try {
      const allData = await AsyncStorage.getItem(config.storageKey);
      const items: OfflineDataItem[] = allData ? JSON.parse(allData) : [];
      
      return items.filter(item => !item.synced && !item.conflict);
    } catch (error) {
      logger.error('Error getting pending items', { error });
      return [];
    }
  }, [config.storageKey]);
  
  /**
   * Get failed items
   */
  const getFailedItems = useCallback(async (): Promise<OfflineDataItem[]> => {
    try {
      const allData = await AsyncStorage.getItem(config.storageKey);
      const items: OfflineDataItem[] = allData ? JSON.parse(allData) : [];
      
      return items.filter(item => item.retryCount && item.retryCount > 0);
    } catch (error) {
      logger.error('Error getting failed items', { error });
      return [];
    }
  }, [config.storageKey]);
  
  /**
   * Get storage size
   */
  const getStorageSize = useCallback(async (): Promise<number> => {
    try {
      const allData = await AsyncStorage.getItem(config.storageKey);
      return allData ? allData.length : 0;
    } catch (error) {
      logger.error('Error getting storage size', { error });
      return 0;
    }
  }, [config.storageKey]);
  
  /**
   * Clear all storage
   */
  const clearStorage = useCallback(async (): Promise<void> => {
    try {
      await AsyncStorage.removeItem(config.storageKey);
      await updateStatus();
      
      logger.info('Offline storage cleared');
    } catch (error) {
      logger.error('Error clearing storage', { error });
      throw error;
    }
  }, [config.storageKey, updateStatus]);
  
  /**
   * Set up network monitoring
   */
  useEffect(() => {
    const handleOnline = () => {
      isOnlineRef.current = true;
      setStatus(prev => ({ ...prev, isOnline: true }));
      
      // Trigger sync when coming online
      syncNow();
    };
    
    const handleOffline = () => {
      isOnlineRef.current = false;
      setStatus(prev => ({ ...prev, isOnline: false }));
    };
    
    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);
    
    return () => {
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
    };
  }, [syncNow]);
  
  /**
   * Set up periodic sync
   */
  useEffect(() => {
    if (config.syncInterval && config.syncInterval > 0) {
      syncTimerRef.current = setInterval(() => {
        if (isOnlineRef.current) {
          syncNow();
        }
      }, config.syncInterval);
    }
    
    return () => {
      if (syncTimerRef.current) {
        clearInterval(syncTimerRef.current);
      }
    };
  }, [config.syncInterval, syncNow]);
  
  /**
   * Initial status update
   */
  useEffect(() => {
    updateStatus();
  }, [updateStatus]);
  
  return {
    // Status
    status,
    isOnline: status.isOnline,
    isSyncing: status.isSyncing,
    
    // Data management
    saveData,
    getData,
    deleteData,
    clearData,
    
    // Sync operations
    syncNow,
    retryFailed,
    resolveConflicts,
    
    // Utilities
    getPendingItems,
    getFailedItems,
    getStorageSize,
    clearStorage
  };
};

/**
 * Factory Offline Sync Hook
 * 
 * Pre-configured for factory environment
 */
export const useFactoryOfflineSync = (storageKey: string): UseOfflineSyncReturn => {
  return useOfflineSync({
    storageKey,
    syncInterval: 30000,
    maxRetries: 5,
    retryDelay: 1000,
    conflictResolution: 'server',
    encryption: true,
    compression: true
  });
};

/**
 * Tablet Offline Sync Hook
 * 
 * Pre-configured for tablet deployment
 */
export const useTabletOfflineSync = (storageKey: string): UseOfflineSyncReturn => {
  return useOfflineSync({
    storageKey,
    syncInterval: 60000,
    maxRetries: 3,
    retryDelay: 2000,
    conflictResolution: 'client',
    encryption: false,
    compression: true
  });
};

export default useOfflineSync;