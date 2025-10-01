/**
 * MS5.0 Floor Dashboard - Real-Time Data Hook
 * 
 * This hook provides real-time data synchronization for factory operations with:
 * - WebSocket integration for live updates
 * - Data caching and offline support
 * - Factory-specific optimizations
 * - Tablet-specific performance tuning
 * - Error handling and recovery
 */

import { useEffect, useState, useCallback, useRef } from 'react';
import { useWebSocket, useFactoryWebSocket } from './useWebSocket';
import { logger } from '../utils/logger';

// Real-time data configuration
interface RealTimeDataConfig {
  url: string;
  factoryNetwork?: boolean;
  tabletOptimized?: boolean;
  cacheEnabled?: boolean;
  syncInterval?: number;
  maxCacheSize?: number;
  offlineSync?: boolean;
}

// Data types for factory operations
interface ProductionData {
  lineId: string;
  status: 'running' | 'stopped' | 'maintenance' | 'error';
  speed: number;
  efficiency: number;
  quality: number;
  timestamp: number;
}

interface EquipmentData {
  equipmentId: string;
  status: 'operational' | 'warning' | 'fault' | 'maintenance';
  temperature: number;
  pressure: number;
  vibration: number;
  timestamp: number;
}

interface AndonData {
  andonId: string;
  status: 'normal' | 'warning' | 'fault' | 'escalated';
  priority: 'low' | 'medium' | 'high' | 'critical';
  message: string;
  timestamp: number;
}

interface OEEData {
  lineId: string;
  availability: number;
  performance: number;
  quality: number;
  oee: number;
  timestamp: number;
}

// Combined data interface
interface FactoryData {
  production: ProductionData[];
  equipment: EquipmentData[];
  andon: AndonData[];
  oee: OEEData[];
  lastUpdate: number;
}

// Hook return interface
interface UseRealTimeDataReturn {
  // Data state
  data: FactoryData | null;
  isLoading: boolean;
  isConnected: boolean;
  isOffline: boolean;
  lastSync: number;
  error: string | null;
  
  // Statistics
  messageCount: number;
  errorCount: number;
  cacheSize: number;
  syncLatency: number;
  
  // Methods
  refresh: () => void;
  clearCache: () => void;
  forceSync: () => void;
  getCachedData: (type: string) => any;
  
  // WebSocket integration
  sendMessage: (type: string, data: any) => void;
  subscribe: (type: string, callback: (data: any) => void) => void;
  unsubscribe: (type: string) => void;
}

/**
 * Real-Time Data Hook
 * 
 * Provides real-time factory data synchronization
 */
export const useRealTimeData = (config: RealTimeDataConfig): UseRealTimeDataReturn => {
  // State management
  const [data, setData] = useState<FactoryData | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [lastSync, setLastSync] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [cacheSize, setCacheSize] = useState(0);
  const [syncLatency, setSyncLatency] = useState(0);
  
  // Refs for data management
  const dataCacheRef = useRef<Map<string, any>>(new Map());
  const subscribersRef = useRef<Map<string, Set<(data: any) => void>>>(new Map());
  const syncTimerRef = useRef<NodeJS.Timeout | null>(null);
  const lastSyncTimeRef = useRef<number>(0);
  
  // WebSocket integration
  const webSocket = useFactoryWebSocket(config.url, {
    onMessage: (message) => {
      handleWebSocketMessage(message);
    },
    onConnect: () => {
      setIsLoading(false);
      setError(null);
      requestInitialData();
    },
    onDisconnect: () => {
      setError('Connection lost');
    },
    onError: (error) => {
      setError('Connection error');
      logger.error('WebSocket error in real-time data', { error });
    }
  });
  
  /**
   * Handle WebSocket messages
   */
  const handleWebSocketMessage = useCallback((message: any) => {
    const startTime = Date.now();
    
    try {
      switch (message.type) {
        case 'production_update':
          updateProductionData(message.data);
          break;
        case 'equipment_update':
          updateEquipmentData(message.data);
          break;
        case 'andon_update':
          updateAndonData(message.data);
          break;
        case 'oee_update':
          updateOEEData(message.data);
          break;
        case 'factory_status':
          updateFactoryStatus(message.data);
          break;
        case 'sync_complete':
          handleSyncComplete(message.data);
          break;
        default:
          logger.debug('Unknown message type', { type: message.type });
      }
      
      // Update sync latency
      setSyncLatency(Date.now() - startTime);
      setLastSync(Date.now());
      
    } catch (error) {
      logger.error('Error handling WebSocket message', { error, message });
      setError('Data processing error');
    }
  }, []);
  
  /**
   * Update production data
   */
  const updateProductionData = useCallback((newData: ProductionData[]) => {
    setData(prevData => {
      if (!prevData) {
        return {
          production: newData,
          equipment: [],
          andon: [],
          oee: [],
          lastUpdate: Date.now()
        };
      }
      
      return {
        ...prevData,
        production: newData,
        lastUpdate: Date.now()
      };
    });
    
    // Cache the data
    if (config.cacheEnabled) {
      dataCacheRef.current.set('production', newData);
      updateCacheSize();
    }
    
    // Notify subscribers
    notifySubscribers('production', newData);
  }, [config.cacheEnabled]);
  
  /**
   * Update equipment data
   */
  const updateEquipmentData = useCallback((newData: EquipmentData[]) => {
    setData(prevData => {
      if (!prevData) {
        return {
          production: [],
          equipment: newData,
          andon: [],
          oee: [],
          lastUpdate: Date.now()
        };
      }
      
      return {
        ...prevData,
        equipment: newData,
        lastUpdate: Date.now()
      };
    });
    
    // Cache the data
    if (config.cacheEnabled) {
      dataCacheRef.current.set('equipment', newData);
      updateCacheSize();
    }
    
    // Notify subscribers
    notifySubscribers('equipment', newData);
  }, [config.cacheEnabled]);
  
  /**
   * Update andon data
   */
  const updateAndonData = useCallback((newData: AndonData[]) => {
    setData(prevData => {
      if (!prevData) {
        return {
          production: [],
          equipment: [],
          andon: newData,
          oee: [],
          lastUpdate: Date.now()
        };
      }
      
      return {
        ...prevData,
        andon: newData,
        lastUpdate: Date.now()
      };
    });
    
    // Cache the data
    if (config.cacheEnabled) {
      dataCacheRef.current.set('andon', newData);
      updateCacheSize();
    }
    
    // Notify subscribers
    notifySubscribers('andon', newData);
  }, [config.cacheEnabled]);
  
  /**
   * Update OEE data
   */
  const updateOEEData = useCallback((newData: OEEData[]) => {
    setData(prevData => {
      if (!prevData) {
        return {
          production: [],
          equipment: [],
          andon: [],
          oee: newData,
          lastUpdate: Date.now()
        };
      }
      
      return {
        ...prevData,
        oee: newData,
        lastUpdate: Date.now()
      };
    });
    
    // Cache the data
    if (config.cacheEnabled) {
      dataCacheRef.current.set('oee', newData);
      updateCacheSize();
    }
    
    // Notify subscribers
    notifySubscribers('oee', newData);
  }, [config.cacheEnabled]);
  
  /**
   * Update factory status
   */
  const updateFactoryStatus = useCallback((status: any) => {
    setData(prevData => ({
      ...prevData,
      lastUpdate: Date.now()
    }));
    
    // Notify subscribers
    notifySubscribers('status', status);
  }, []);
  
  /**
   * Handle sync complete
   */
  const handleSyncComplete = useCallback((syncData: any) => {
    setLastSync(Date.now());
    setError(null);
    
    logger.info('Real-time data sync complete', {
      timestamp: Date.now(),
      dataTypes: Object.keys(syncData)
    });
  }, []);
  
  /**
   * Request initial data
   */
  const requestInitialData = useCallback(() => {
    if (webSocket.isConnected) {
      webSocket.send({
        type: 'request_data',
        data: {
          types: ['production', 'equipment', 'andon', 'oee'],
          timestamp: Date.now()
        }
      });
    }
  }, [webSocket]);
  
  /**
   * Update cache size
   */
  const updateCacheSize = useCallback(() => {
    const size = dataCacheRef.current.size;
    setCacheSize(size);
    
    // Limit cache size
    if (config.maxCacheSize && size > config.maxCacheSize) {
      const keys = Array.from(dataCacheRef.current.keys());
      const keysToDelete = keys.slice(0, size - config.maxCacheSize);
      keysToDelete.forEach(key => dataCacheRef.current.delete(key));
      setCacheSize(config.maxCacheSize);
    }
  }, [config.maxCacheSize]);
  
  /**
   * Notify subscribers
   */
  const notifySubscribers = useCallback((type: string, data: any) => {
    const subscribers = subscribersRef.current.get(type);
    if (subscribers) {
      subscribers.forEach(callback => {
        try {
          callback(data);
        } catch (error) {
          logger.error('Error in subscriber callback', { error, type });
        }
      });
    }
  }, []);
  
  /**
   * Refresh data
   */
  const refresh = useCallback(() => {
    setIsLoading(true);
    requestInitialData();
  }, [requestInitialData]);
  
  /**
   * Clear cache
   */
  const clearCache = useCallback(() => {
    dataCacheRef.current.clear();
    setCacheSize(0);
  }, []);
  
  /**
   * Force sync
   */
  const forceSync = useCallback(() => {
    if (webSocket.isConnected) {
      webSocket.send({
        type: 'force_sync',
        data: {
          timestamp: Date.now()
        }
      });
    }
  }, [webSocket]);
  
  /**
   * Get cached data
   */
  const getCachedData = useCallback((type: string): any => {
    return dataCacheRef.current.get(type);
  }, []);
  
  /**
   * Send message
   */
  const sendMessage = useCallback((type: string, data: any) => {
    if (webSocket.isConnected) {
      webSocket.send({ type, data, timestamp: Date.now() });
    }
  }, [webSocket]);
  
  /**
   * Subscribe to data updates
   */
  const subscribe = useCallback((type: string, callback: (data: any) => void) => {
    if (!subscribersRef.current.has(type)) {
      subscribersRef.current.set(type, new Set());
    }
    subscribersRef.current.get(type)!.add(callback);
  }, []);
  
  /**
   * Unsubscribe from data updates
   */
  const unsubscribe = useCallback((type: string) => {
    subscribersRef.current.delete(type);
  }, []);
  
  // Set up periodic sync
  useEffect(() => {
    if (config.syncInterval && config.syncInterval > 0) {
      syncTimerRef.current = setInterval(() => {
        if (webSocket.isConnected) {
          forceSync();
        }
      }, config.syncInterval);
    }
    
    return () => {
      if (syncTimerRef.current) {
        clearInterval(syncTimerRef.current);
      }
    };
  }, [config.syncInterval, forceSync, webSocket.isConnected]);
  
  // Load cached data on mount
  useEffect(() => {
    if (config.cacheEnabled) {
      const cachedData = {
        production: dataCacheRef.current.get('production') || [],
        equipment: dataCacheRef.current.get('equipment') || [],
        andon: dataCacheRef.current.get('andon') || [],
        oee: dataCacheRef.current.get('oee') || [],
        lastUpdate: Date.now()
      };
      
      setData(cachedData);
      setIsLoading(false);
    }
  }, [config.cacheEnabled]);
  
  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (syncTimerRef.current) {
        clearInterval(syncTimerRef.current);
      }
      subscribersRef.current.clear();
    };
  }, []);
  
  return {
    // Data state
    data,
    isLoading,
    isConnected: webSocket.isConnected,
    isOffline: webSocket.isOffline,
    lastSync,
    error,
    
    // Statistics
    messageCount: webSocket.messageCount,
    errorCount: webSocket.errorCount,
    cacheSize,
    syncLatency,
    
    // Methods
    refresh,
    clearCache,
    forceSync,
    getCachedData,
    
    // WebSocket integration
    sendMessage,
    subscribe,
    unsubscribe
  };
};

/**
 * Factory Real-Time Data Hook
 * 
 * Pre-configured for factory environment
 */
export const useFactoryRealTimeData = (url: string): UseRealTimeDataReturn => {
  return useRealTimeData({
    url,
    factoryNetwork: true,
    tabletOptimized: true,
    cacheEnabled: true,
    syncInterval: 30000,
    maxCacheSize: 1000,
    offlineSync: true
  });
};

/**
 * Tablet Real-Time Data Hook
 * 
 * Pre-configured for tablet deployment
 */
export const useTabletRealTimeData = (url: string): UseRealTimeDataReturn => {
  return useRealTimeData({
    url,
    factoryNetwork: false,
    tabletOptimized: true,
    cacheEnabled: true,
    syncInterval: 60000,
    maxCacheSize: 500,
    offlineSync: true
  });
};

export default useRealTimeData;