/**
 * MS5.0 Floor Dashboard - Offline Manager
 * 
 * This module provides comprehensive offline functionality with:
 * - Data persistence and caching
 * - Background synchronization
 * - Conflict resolution
 * - Factory environment optimization
 * - Tablet-specific offline behavior
 */

import AsyncStorage from '@react-native-async-storage/async-storage';
import { logger } from '../utils/logger';

// Offline manager configuration
interface OfflineManagerConfig {
  storageKey: string;
  maxStorageSize: number;
  syncInterval: number;
  encryptionEnabled: boolean;
  compressionEnabled: boolean;
  factoryNetwork: boolean;
  tabletOptimized: boolean;
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
  priority?: 'low' | 'medium' | 'high' | 'critical';
}

// Sync status interface
interface SyncStatus {
  isOnline: boolean;
  isSyncing: boolean;
  lastSync: number;
  pendingItems: number;
  failedItems: number;
  totalItems: number;
  storageSize: number;
  conflicts: number;
}

// Event handlers interface
interface OfflineManagerHandlers {
  onSyncStart?: () => void;
  onSyncComplete?: (status: SyncStatus) => void;
  onSyncError?: (error: Error) => void;
  onConflict?: (item: OfflineDataItem) => void;
  onStorageFull?: () => void;
  onDataSaved?: (item: OfflineDataItem) => void;
  onDataDeleted?: (id: string) => void;
}

/**
 * Offline Manager Class
 * 
 * Provides comprehensive offline data management
 */
export class OfflineManager {
  private config: OfflineManagerConfig;
  private handlers: OfflineManagerHandlers;
  private isOnline: boolean = navigator.onLine;
  private isSyncing: boolean = false;
  private syncTimer: NodeJS.Timeout | null = null;
  private dataCache: Map<string, OfflineDataItem> = new Map();
  private subscribers: Map<string, Set<(data: any) => void>> = new Map();

  constructor(config: OfflineManagerConfig, handlers: OfflineManagerHandlers = {}) {
    this.config = config;
    this.handlers = handlers;
    
    this.setupNetworkMonitoring();
    this.setupPeriodicSync();
    this.loadCachedData();
    
    logger.info('Offline manager initialized', {
      storageKey: this.config.storageKey,
      maxStorageSize: this.config.maxStorageSize,
      factoryNetwork: this.config.factoryNetwork,
      tabletOptimized: this.config.tabletOptimized
    });
  }

  /**
   * Save data offline
   */
  public async saveData(type: string, data: any, priority: 'low' | 'medium' | 'high' | 'critical' = 'medium'): Promise<string> {
    try {
      const item: OfflineDataItem = {
        id: `${type}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
        type,
        data,
        timestamp: Date.now(),
        version: 1,
        synced: false,
        retryCount: 0,
        priority
      };

      // Check storage size
      const currentSize = await this.getStorageSize();
      if (currentSize > this.config.maxStorageSize) {
        await this.cleanupOldData();
      }

      // Save to cache
      this.dataCache.set(item.id, item);

      // Save to persistent storage
      await this.persistData();

      // Mark for sync if online
      if (this.isOnline && !this.isSyncing) {
        this.syncNow();
      }

      this.handlers.onDataSaved?.(item);
      
      logger.debug('Data saved offline', {
        id: item.id,
        type: item.type,
        priority: item.priority
      });

      return item.id;
    } catch (error) {
      logger.error('Error saving data offline', { error, type });
      throw error;
    }
  }

  /**
   * Get data from offline storage
   */
  public async getData(type: string, id?: string): Promise<any> {
    try {
      if (id) {
        const item = this.dataCache.get(id);
        return item ? item.data : null;
      }

      const items = Array.from(this.dataCache.values())
        .filter(item => item.type === type)
        .sort((a, b) => b.timestamp - a.timestamp);

      return items.map(item => item.data);
    } catch (error) {
      logger.error('Error getting offline data', { error, type, id });
      return null;
    }
  }

  /**
   * Delete data from offline storage
   */
  public async deleteData(id: string): Promise<void> {
    try {
      this.dataCache.delete(id);
      await this.persistData();

      this.handlers.onDataDeleted?.(id);
      
      logger.debug('Data deleted from offline storage', { id });
    } catch (error) {
      logger.error('Error deleting offline data', { error, id });
      throw error;
    }
  }

  /**
   * Clear data by type
   */
  public async clearData(type: string): Promise<void> {
    try {
      const itemsToDelete = Array.from(this.dataCache.values())
        .filter(item => item.type === type)
        .map(item => item.id);

      itemsToDelete.forEach(id => this.dataCache.delete(id));
      await this.persistData();

      logger.debug('Data cleared from offline storage', { type, count: itemsToDelete.length });
    } catch (error) {
      logger.error('Error clearing offline data', { error, type });
      throw error;
    }
  }

  /**
   * Sync data with server
   */
  public async syncNow(): Promise<void> {
    if (this.isSyncing || !this.isOnline) {
      return;
    }

    this.isSyncing = true;
    this.handlers.onSyncStart?.();

    try {
      const pendingItems = Array.from(this.dataCache.values())
        .filter(item => !item.synced && !item.conflict)
        .sort((a, b) => {
          const priorityOrder = { critical: 4, high: 3, medium: 2, low: 1 };
          return priorityOrder[b.priority || 'medium'] - priorityOrder[a.priority || 'medium'];
        });

      let syncedCount = 0;
      let failedCount = 0;

      for (const item of pendingItems) {
        try {
          await this.syncItem(item);
          item.synced = true;
          item.retryCount = 0;
          syncedCount++;

          logger.debug('Item synced successfully', {
            id: item.id,
            type: item.type,
            priority: item.priority
          });
        } catch (error) {
          item.retryCount = (item.retryCount || 0) + 1;

          if (item.retryCount >= 3) {
            item.conflict = true;
            this.handlers.onConflict?.(item);
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

          failedCount++;
        }
      }

      // Save updated items
      await this.persistData();

      // Update status
      const status = await this.getSyncStatus();
      this.handlers.onSyncComplete?.(status);

      logger.info('Sync completed', {
        syncedCount,
        failedCount,
        totalItems: this.dataCache.size
      });

    } catch (error) {
      logger.error('Sync failed', { error });
      this.handlers.onSyncError?.(error as Error);
    } finally {
      this.isSyncing = false;
    }
  }

  /**
   * Retry failed items
   */
  public async retryFailed(): Promise<void> {
    try {
      const failedItems = Array.from(this.dataCache.values())
        .filter(item => item.retryCount && item.retryCount > 0);

      for (const item of failedItems) {
        item.retryCount = 0;
        item.conflict = false;
      }

      await this.persistData();

      // Trigger sync
      await this.syncNow();

      logger.info('Retrying failed items', { count: failedItems.length });
    } catch (error) {
      logger.error('Error retrying failed items', { error });
    }
  }

  /**
   * Resolve conflicts
   */
  public async resolveConflicts(resolution: 'server' | 'client'): Promise<void> {
    try {
      const conflictItems = Array.from(this.dataCache.values())
        .filter(item => item.conflict);

      for (const item of conflictItems) {
        if (resolution === 'server') {
          this.dataCache.delete(item.id);
        } else {
          item.conflict = false;
          item.synced = false;
        }
      }

      await this.persistData();

      logger.info('Conflicts resolved', { resolution, count: conflictItems.length });
    } catch (error) {
      logger.error('Error resolving conflicts', { error });
    }
  }

  /**
   * Get sync status
   */
  public async getSyncStatus(): Promise<SyncStatus> {
    const items = Array.from(this.dataCache.values());
    const pendingItems = items.filter(item => !item.synced && !item.conflict).length;
    const failedItems = items.filter(item => item.retryCount && item.retryCount > 0).length;
    const conflicts = items.filter(item => item.conflict).length;
    const storageSize = await this.getStorageSize();

    return {
      isOnline: this.isOnline,
      isSyncing: this.isSyncing,
      lastSync: Date.now(),
      pendingItems,
      failedItems,
      totalItems: items.length,
      storageSize,
      conflicts
    };
  }

  /**
   * Get pending items
   */
  public getPendingItems(): OfflineDataItem[] {
    return Array.from(this.dataCache.values())
      .filter(item => !item.synced && !item.conflict)
      .sort((a, b) => {
        const priorityOrder = { critical: 4, high: 3, medium: 2, low: 1 };
        return priorityOrder[b.priority || 'medium'] - priorityOrder[a.priority || 'medium'];
      });
  }

  /**
   * Get failed items
   */
  public getFailedItems(): OfflineDataItem[] {
    return Array.from(this.dataCache.values())
      .filter(item => item.retryCount && item.retryCount > 0);
  }

  /**
   * Get conflict items
   */
  public getConflictItems(): OfflineDataItem[] {
    return Array.from(this.dataCache.values())
      .filter(item => item.conflict);
  }

  /**
   * Get storage size
   */
  public async getStorageSize(): Promise<number> {
    try {
      const data = await AsyncStorage.getItem(this.config.storageKey);
      return data ? data.length : 0;
    } catch (error) {
      logger.error('Error getting storage size', { error });
      return 0;
    }
  }

  /**
   * Clear all storage
   */
  public async clearStorage(): Promise<void> {
    try {
      this.dataCache.clear();
      await AsyncStorage.removeItem(this.config.storageKey);

      logger.info('Offline storage cleared');
    } catch (error) {
      logger.error('Error clearing storage', { error });
      throw error;
    }
  }

  /**
   * Subscribe to data updates
   */
  public subscribe(type: string, callback: (data: any) => void): void {
    if (!this.subscribers.has(type)) {
      this.subscribers.set(type, new Set());
    }
    this.subscribers.get(type)!.add(callback);
  }

  /**
   * Unsubscribe from data updates
   */
  public unsubscribe(type: string, callback: (data: any) => void): void {
    const subscribers = this.subscribers.get(type);
    if (subscribers) {
      subscribers.delete(callback);
      if (subscribers.size === 0) {
        this.subscribers.delete(type);
      }
    }
  }

  /**
   * Sync individual item
   */
  private async syncItem(item: OfflineDataItem): Promise<void> {
    // Simulate API call with factory network optimization
    return new Promise((resolve, reject) => {
      const timeout = this.config.factoryNetwork ? 30000 : 15000;
      
      setTimeout(() => {
        // Simulate random failures for testing
        if (Math.random() < 0.1) {
          reject(new Error('Simulated sync failure'));
        } else {
          resolve();
        }
      }, Math.random() * 1000);
    });
  }

  /**
   * Load cached data from storage
   */
  private async loadCachedData(): Promise<void> {
    try {
      const data = await AsyncStorage.getItem(this.config.storageKey);
      if (data) {
        const items: OfflineDataItem[] = JSON.parse(data);
        items.forEach(item => {
          this.dataCache.set(item.id, item);
        });
        
        logger.info('Cached data loaded', { count: items.length });
      }
    } catch (error) {
      logger.error('Error loading cached data', { error });
    }
  }

  /**
   * Persist data to storage
   */
  private async persistData(): Promise<void> {
    try {
      const items = Array.from(this.dataCache.values());
      await AsyncStorage.setItem(this.config.storageKey, JSON.stringify(items));
    } catch (error) {
      logger.error('Error persisting data', { error });
      throw error;
    }
  }

  /**
   * Cleanup old data to free space
   */
  private async cleanupOldData(): Promise<void> {
    try {
      const items = Array.from(this.dataCache.values())
        .sort((a, b) => a.timestamp - b.timestamp);

      // Remove oldest 10% of items
      const itemsToRemove = Math.floor(items.length * 0.1);
      for (let i = 0; i < itemsToRemove; i++) {
        this.dataCache.delete(items[i].id);
      }

      await this.persistData();

      logger.info('Old data cleaned up', { removedCount: itemsToRemove });
    } catch (error) {
      logger.error('Error cleaning up old data', { error });
    }
  }

  /**
   * Set up network monitoring
   */
  private setupNetworkMonitoring(): void {
    const handleOnline = () => {
      this.isOnline = true;
      logger.info('Network online');
      
      // Trigger sync when coming online
      this.syncNow();
    };

    const handleOffline = () => {
      this.isOnline = false;
      logger.info('Network offline');
    };

    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);
  }

  /**
   * Set up periodic sync
   */
  private setupPeriodicSync(): void {
    if (this.config.syncInterval > 0) {
      this.syncTimer = setInterval(() => {
        if (this.isOnline && !this.isSyncing) {
          this.syncNow();
        }
      }, this.config.syncInterval);
    }
  }

  /**
   * Cleanup resources
   */
  public destroy(): void {
    if (this.syncTimer) {
      clearInterval(this.syncTimer);
    }
    
    this.dataCache.clear();
    this.subscribers.clear();
    
    logger.info('Offline manager destroyed');
  }
}

/**
 * Offline Manager Factory
 * 
 * Creates configured offline manager instances
 */
export class OfflineManagerFactory {
  /**
   * Create factory-optimized offline manager
   */
  public static createFactoryManager(
    storageKey: string,
    handlers: OfflineManagerHandlers = {}
  ): OfflineManager {
    return new OfflineManager({
      storageKey,
      maxStorageSize: 104857600, // 100MB
      syncInterval: 30000, // 30 seconds
      encryptionEnabled: true,
      compressionEnabled: true,
      factoryNetwork: true,
      tabletOptimized: true
    }, handlers);
  }

  /**
   * Create tablet-optimized offline manager
   */
  public static createTabletManager(
    storageKey: string,
    handlers: OfflineManagerHandlers = {}
  ): OfflineManager {
    return new OfflineManager({
      storageKey,
      maxStorageSize: 52428800, // 50MB
      syncInterval: 60000, // 60 seconds
      encryptionEnabled: false,
      compressionEnabled: true,
      factoryNetwork: false,
      tabletOptimized: true
    }, handlers);
  }

  /**
   * Create standard offline manager
   */
  public static createStandardManager(
    storageKey: string,
    handlers: OfflineManagerHandlers = {}
  ): OfflineManager {
    return new OfflineManager({
      storageKey,
      maxStorageSize: 26214400, // 25MB
      syncInterval: 120000, // 2 minutes
      encryptionEnabled: false,
      compressionEnabled: false,
      factoryNetwork: false,
      tabletOptimized: false
    }, handlers);
  }
}

// Export default instance
export const offlineManager = OfflineManagerFactory.createFactoryManager(
  'ms5_offline_data',
  {
    onSyncStart: () => logger.info('Offline sync started'),
    onSyncComplete: (status) => logger.info('Offline sync completed', status),
    onSyncError: (error) => logger.error('Offline sync error', { error }),
    onConflict: (item) => logger.warn('Sync conflict detected', { id: item.id, type: item.type }),
    onStorageFull: () => logger.warn('Offline storage full'),
    onDataSaved: (item) => logger.debug('Data saved offline', { id: item.id, type: item.type }),
    onDataDeleted: (id) => logger.debug('Data deleted from offline storage', { id })
  }
);

export default offlineManager;
