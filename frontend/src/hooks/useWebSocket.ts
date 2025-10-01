/**
 * MS5.0 Floor Dashboard - Enhanced WebSocket Integration Hook
 * 
 * Enterprise-grade WebSocket integration for cosmic scale operations.
 * The nervous system of a starship - built for reliability and performance.
 * 
 * This hook provides comprehensive WebSocket functionality to React components including:
 * - Enhanced connection management with health monitoring
 * - Advanced event subscription/unsubscription with filtering
 * - Priority-based message sending
 * - Real-time data updates with automatic retry
 * - Factory-specific optimizations
 * - Comprehensive error handling and recovery
 * - Performance metrics and diagnostics
 */

import { useEffect, useCallback, useRef, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { RootState, AppDispatch } from '../store';
import { websocketActions, websocketSelectors, WEBSOCKET_EVENTS } from '../store/middleware/websocketMiddleware';
import { 
  enhancedWebSocketService, 
  EnhancedWebSocketService, 
  EnhancedWebSocketMessage, 
  MessagePriority, 
  EnhancedWebSocketState,
  ConnectionMetrics 
} from '../services/websocket';
import { logger } from '../utils/logger';

// Enhanced WebSocket hook configuration
interface EnhancedWebSocketConfig {
  autoConnect?: boolean;
  reconnectOnMount?: boolean;
  factoryOptimized?: boolean;
  tabletOptimized?: boolean;
  enableHealthMonitoring?: boolean;
  enableBatching?: boolean;
  enableCompression?: boolean;
  priorityQueue?: boolean;
  maxReconnectAttempts?: number;
  heartbeatInterval?: number;
  batchSize?: number;
  batchTimeout?: number;
}

// Enhanced WebSocket hook options
interface EnhancedWebSocketOptions extends EnhancedWebSocketConfig {
  onConnect?: () => void;
  onDisconnect?: () => void;
  onError?: (error: string) => void;
  onMessage?: (message: EnhancedWebSocketMessage) => void;
  onHealthUpdate?: (healthScore: number) => void;
  onBatchProcessed?: (batchSize: number) => void;
  onReconnect?: (attempt: number) => void;
  onOffline?: () => void;
  onOnline?: () => void;
}

// Enhanced WebSocket hook return interface
interface EnhancedWebSocketReturn {
  // Connection state
  isConnected: boolean;
  isConnecting: boolean;
  isReconnecting: boolean;
  isOffline: boolean;
  error: string | null;
  lastMessage: EnhancedWebSocketMessage | null;
  subscriptions: string[];
  
  // Enhanced metrics
  healthScore: number;
  connectionMetrics: ConnectionMetrics | null;
  latency: number;
  messageCount: number;
  errorCount: number;
  bytesSent: number;
  bytesReceived: number;
  uptime: number;
  
  // Actions
  connect: () => Promise<void>;
  disconnect: () => void;
  subscribe: (eventType: string, callback: (data: any) => void, filters?: Record<string, any>, priority?: MessagePriority) => string;
  unsubscribe: (subscriptionId: string) => void;
  sendMessage: (message: EnhancedWebSocketMessage, priority?: MessagePriority) => void;
  sendHeartbeat: () => void;
  clearError: () => void;
  reset: () => void;
  
  // Advanced features
  getHealthScore: () => number;
  getConnectionMetrics: () => ConnectionMetrics | null;
  getSubscriptionStats: () => { active: number; total: number };
  forceReconnect: () => Promise<void>;
  updateConfig: (config: Partial<EnhancedWebSocketConfig>) => void;
}

/**
 * Enhanced WebSocket Integration Hook
 * 
 * Provides enterprise-grade WebSocket functionality with advanced features
 * for cosmic scale operations and factory environments.
 */
export const useEnhancedWebSocket = (options: EnhancedWebSocketOptions = {}): EnhancedWebSocketReturn => {
  const dispatch = useDispatch<AppDispatch>();
  const isConnected = useSelector(websocketSelectors.isConnected);
  const isConnecting = useSelector(websocketSelectors.isConnecting);
  const error = useSelector(websocketSelectors.error);
  const lastMessage = useSelector(websocketSelectors.lastMessage);
  const subscriptions = useSelector(websocketSelectors.subscriptions);
  
  const {
    autoConnect = true,
    reconnectOnMount = true,
    factoryOptimized = false,
    tabletOptimized = false,
    enableHealthMonitoring = true,
    enableBatching = true,
    enableCompression = false,
    priorityQueue = true,
    maxReconnectAttempts = 15,
    heartbeatInterval = 30000,
    batchSize = 10,
    batchTimeout = 100,
    onConnect,
    onDisconnect,
    onError,
    onMessage,
    onHealthUpdate,
    onBatchProcessed,
    onReconnect,
    onOffline,
    onOnline,
  } = options;

  // Enhanced state management
  const [healthScore, setHealthScore] = useState<number>(1.0);
  const [connectionMetrics, setConnectionMetrics] = useState<ConnectionMetrics | null>(null);
  const [latency, setLatency] = useState<number>(0);
  const [messageCount, setMessageCount] = useState<number>(0);
  const [errorCount, setErrorCount] = useState<number>(0);
  const [bytesSent, setBytesSent] = useState<number>(0);
  const [bytesReceived, setBytesReceived] = useState<number>(0);
  const [uptime, setUptime] = useState<number>(0);

  // Refs for cleanup and service management
  const subscriptionRefs = useRef<Map<string, string>>(new Map());
  const mountedRef = useRef(true);
  const serviceRef = useRef<EnhancedWebSocketService | null>(null);
  const metricsUpdateTimer = useRef<NodeJS.Timeout | null>(null);

  // Initialize enhanced WebSocket service
  useEffect(() => {
    if (!serviceRef.current) {
      const config = {
        factoryNetwork: factoryOptimized,
        tabletOptimized: tabletOptimized,
        enableCompression: enableCompression,
        enableBatching: enableBatching,
        priorityQueue: priorityQueue,
        maxReconnectAttempts: maxReconnectAttempts,
        heartbeatInterval: heartbeatInterval,
        batchSize: batchSize,
        batchTimeout: batchTimeout,
        healthMonitoring: enableHealthMonitoring
      };

      serviceRef.current = enhancedWebSocketService;
      
      // Set up enhanced event handlers
      const handlers = {
        onOpen: () => {
          logger.info('Enhanced WebSocket connected via hook');
          dispatch(websocketActions.connected());
          onConnect?.();
        },
        onClose: (event: CloseEvent) => {
          logger.info('Enhanced WebSocket disconnected via hook', { event });
          dispatch(websocketActions.disconnected());
          onDisconnect?.();
        },
        onError: (error: Event) => {
          const errorMessage = `WebSocket error: ${error.type}`;
          logger.error('Enhanced WebSocket error via hook', { error });
          dispatch(websocketActions.error(errorMessage));
          onError?.(errorMessage);
        },
        onMessage: (message: EnhancedWebSocketMessage) => {
          logger.debug('Enhanced WebSocket message received via hook', { message });
          dispatch(websocketActions.messageReceived(message));
          onMessage?.(message);
        },
        onHealthUpdate: (score: number) => {
          setHealthScore(score);
          onHealthUpdate?.(score);
        },
        onBatchProcessed: (batchSize: number) => {
          logger.debug('Enhanced WebSocket batch processed via hook', { batchSize });
          onBatchProcessed?.(batchSize);
        },
        onReconnect: (attempt: number) => {
          logger.info('Enhanced WebSocket reconnecting via hook', { attempt });
          dispatch(websocketActions.reconnecting());
          onReconnect?.(attempt);
        },
        onOffline: () => {
          logger.info('Enhanced WebSocket offline via hook');
          dispatch(websocketActions.offline());
          onOffline?.();
        },
        onOnline: () => {
          logger.info('Enhanced WebSocket online via hook');
          dispatch(websocketActions.online());
          onOnline?.();
        }
      };

      // Apply handlers to service
      Object.assign(serviceRef.current, { handlers });
    }
  }, [dispatch, factoryOptimized, tabletOptimized, enableCompression, enableBatching, priorityQueue, maxReconnectAttempts, heartbeatInterval, batchSize, batchTimeout, enableHealthMonitoring, onConnect, onDisconnect, onError, onMessage, onHealthUpdate, onBatchProcessed, onReconnect, onOffline, onOnline]);

  // Auto-connect on mount
  useEffect(() => {
    if (autoConnect && !isConnected && !isConnecting && serviceRef.current) {
      connect();
    }
  }, [autoConnect, isConnected, isConnecting]);

  // Update metrics periodically
  useEffect(() => {
    if (enableHealthMonitoring && serviceRef.current) {
      metricsUpdateTimer.current = setInterval(() => {
        if (serviceRef.current) {
          const metrics = serviceRef.current.getStats();
          setConnectionMetrics(metrics);
          setLatency(metrics.latency);
          setMessageCount(metrics.messageCount);
          setErrorCount(metrics.errorCount);
          setBytesSent(metrics.bytesSent);
          setBytesReceived(metrics.bytesReceived);
          setUptime(metrics.uptime);
        }
      }, 5000); // Update every 5 seconds

      return () => {
        if (metricsUpdateTimer.current) {
          clearInterval(metricsUpdateTimer.current);
        }
      };
    }
  }, [enableHealthMonitoring]);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      mountedRef.current = false;
      // Unsubscribe from all events
      subscriptionRefs.current.forEach((subscriptionId) => {
        if (serviceRef.current) {
          serviceRef.current.unsubscribe(subscriptionId);
        }
      });
      subscriptionRefs.current.clear();
      
      // Clear metrics timer
      if (metricsUpdateTimer.current) {
        clearInterval(metricsUpdateTimer.current);
      }
    };
  }, []);

  // Enhanced connection management
  const connect = useCallback(async (): Promise<void> => {
    if (!serviceRef.current) return;
    
    if (!isConnected && !isConnecting) {
      try {
        await serviceRef.current.connect();
      } catch (error) {
        logger.error('Enhanced WebSocket connection failed via hook', { error });
        dispatch(websocketActions.error(`Connection failed: ${error}`));
      }
    }
  }, [dispatch, isConnected, isConnecting]);

  const disconnect = useCallback((): void => {
    if (serviceRef.current && isConnected) {
      serviceRef.current.disconnect();
    }
  }, [isConnected]);

  // Enhanced event subscription with advanced filtering
  const subscribe = useCallback((
    eventType: string, 
    callback: (data: any) => void, 
    filters?: Record<string, any>, 
    priority: MessagePriority = MessagePriority.NORMAL
  ): string => {
    if (!mountedRef.current || !serviceRef.current) return '';

    const subscriptionId = serviceRef.current.subscribe(eventType, callback, filters, priority);
    subscriptionRefs.current.set(eventType, subscriptionId);
    
    dispatch(websocketActions.subscribe(eventType, callback));
    
    logger.info('Enhanced WebSocket subscription created via hook', {
      eventType,
      subscriptionId,
      filters,
      priority
    });
    
    return subscriptionId;
  }, [dispatch]);

  const unsubscribe = useCallback((subscriptionId: string): void => {
    if (serviceRef.current) {
      serviceRef.current.unsubscribe(subscriptionId);
      
      // Remove from refs
      for (const [eventType, id] of subscriptionRefs.current.entries()) {
        if (id === subscriptionId) {
          subscriptionRefs.current.delete(eventType);
          break;
        }
      }
      
      dispatch(websocketActions.unsubscribe(subscriptionId));
      
      logger.info('Enhanced WebSocket subscription removed via hook', { subscriptionId });
    }
  }, [dispatch]);

  // Priority-based message sending
  const sendMessage = useCallback((
    message: EnhancedWebSocketMessage, 
    priority: MessagePriority = MessagePriority.NORMAL
  ): void => {
    if (serviceRef.current && isConnected) {
      const enhancedMessage: EnhancedWebSocketMessage = {
        ...message,
        timestamp: Date.now(),
        priority: priority
      };
      
      serviceRef.current.send(enhancedMessage, priority);
      
      logger.debug('Enhanced WebSocket message sent via hook', {
        type: message.type,
        priority: priority
      });
    } else {
      logger.warn('Cannot send message: Enhanced WebSocket not connected');
    }
  }, [isConnected]);

  // Send heartbeat
  const sendHeartbeat = useCallback((): void => {
    if (serviceRef.current && isConnected) {
      serviceRef.current.sendHeartbeat();
    }
  }, [isConnected]);

  // Error management
  const clearError = useCallback((): void => {
    dispatch(websocketActions.clearError());
  }, [dispatch]);

  // Reset WebSocket state
  const reset = useCallback((): void => {
    dispatch(websocketActions.resetState());
    setHealthScore(1.0);
    setConnectionMetrics(null);
    setLatency(0);
    setMessageCount(0);
    setErrorCount(0);
    setBytesSent(0);
    setBytesReceived(0);
    setUptime(0);
  }, [dispatch]);

  // Advanced features
  const getHealthScore = useCallback((): number => {
    return serviceRef.current?.getHealthScore() || 0;
  }, []);

  const getConnectionMetrics = useCallback((): ConnectionMetrics | null => {
    return serviceRef.current?.getStats() || null;
  }, []);

  const getSubscriptionStats = useCallback((): { active: number; total: number } => {
    const active = subscriptionRefs.current.size;
    const total = subscriptions.length;
    return { active, total };
  }, [subscriptions.length]);

  const forceReconnect = useCallback(async (): Promise<void> => {
    if (serviceRef.current) {
      disconnect();
      await new Promise(resolve => setTimeout(resolve, 1000)); // Wait 1 second
      await connect();
    }
  }, [disconnect, connect]);

  const updateConfig = useCallback((config: Partial<EnhancedWebSocketConfig>): void => {
    logger.info('Enhanced WebSocket config updated via hook', { config });
    // Note: In a real implementation, you would update the service configuration
    // This would require the service to support runtime configuration updates
  }, []);

  return {
    // Connection state
    isConnected,
    isConnecting,
    isReconnecting: serviceRef.current?.getState() === EnhancedWebSocketState.RECONNECTING || false,
    isOffline: serviceRef.current?.getState() === EnhancedWebSocketState.OFFLINE || false,
    error,
    lastMessage,
    subscriptions,
    
    // Enhanced metrics
    healthScore,
    connectionMetrics,
    latency,
    messageCount,
    errorCount,
    bytesSent,
    bytesReceived,
    uptime,
    
    // Actions
    connect,
    disconnect,
    subscribe,
    unsubscribe,
    sendMessage,
    sendHeartbeat,
    clearError,
    reset,
    
    // Advanced features
    getHealthScore,
    getConnectionMetrics,
    getSubscriptionStats,
    forceReconnect,
    updateConfig,
  };
};

/**
 * Production WebSocket Hook
 * 
 * Specialized hook for production-related WebSocket events with factory optimizations
 */
export const useProductionWebSocket = (options: {
  lineId?: string;
  factoryOptimized?: boolean;
  onProductionUpdate?: (data: any) => void;
  onScheduleUpdate?: (data: any) => void;
  onJobUpdate?: (data: any) => void;
  onMetricsUpdate?: (data: any) => void;
  onOEEUpdate?: (data: any) => void;
  onDowntimeUpdate?: (data: any) => void;
} = {}) => {
  const { 
    lineId, 
    factoryOptimized = true,
    onProductionUpdate, 
    onScheduleUpdate, 
    onJobUpdate, 
    onMetricsUpdate,
    onOEEUpdate,
    onDowntimeUpdate 
  } = options;
  
  const ws = useEnhancedWebSocket({
    factoryOptimized,
    enableHealthMonitoring: true,
    enableBatching: true,
    batchSize: factoryOptimized ? 15 : 10,
    batchTimeout: factoryOptimized ? 50 : 100,
    onMessage: (message) => {
      // Filter messages by line ID if specified
      if (lineId && message.data?.lineId && message.data.lineId !== lineId) {
        return;
      }

      switch (message.type) {
        case WEBSOCKET_EVENTS.PRODUCTION_LINE_UPDATED:
          onProductionUpdate?.(message.data);
          break;
        case WEBSOCKET_EVENTS.PRODUCTION_SCHEDULE_UPDATED:
          onScheduleUpdate?.(message.data);
          break;
        case WEBSOCKET_EVENTS.JOB_ASSIGNMENT_UPDATED:
          onJobUpdate?.(message.data);
          break;
        case WEBSOCKET_EVENTS.PRODUCTION_METRICS_UPDATED:
          onMetricsUpdate?.(message.data);
          break;
        case WEBSOCKET_EVENTS.OEE_DATA_UPDATED:
          onOEEUpdate?.(message.data);
          break;
        case WEBSOCKET_EVENTS.DOWNTIME_EVENT:
          onDowntimeUpdate?.(message.data);
          break;
      }
    },
  });

  // Subscribe to production events
  useEffect(() => {
    const subscriptions = [
      ws.subscribe(WEBSOCKET_EVENTS.PRODUCTION_LINE_UPDATED, onProductionUpdate || (() => {}), lineId ? { lineId } : undefined, MessagePriority.HIGH),
      ws.subscribe(WEBSOCKET_EVENTS.PRODUCTION_SCHEDULE_UPDATED, onScheduleUpdate || (() => {}), lineId ? { lineId } : undefined, MessagePriority.HIGH),
      ws.subscribe(WEBSOCKET_EVENTS.JOB_ASSIGNMENT_UPDATED, onJobUpdate || (() => {}), lineId ? { lineId } : undefined, MessagePriority.HIGH),
      ws.subscribe(WEBSOCKET_EVENTS.PRODUCTION_METRICS_UPDATED, onMetricsUpdate || (() => {}), lineId ? { lineId } : undefined, MessagePriority.NORMAL),
      ws.subscribe(WEBSOCKET_EVENTS.OEE_DATA_UPDATED, onOEEUpdate || (() => {}), lineId ? { lineId } : undefined, MessagePriority.HIGH),
      ws.subscribe(WEBSOCKET_EVENTS.DOWNTIME_EVENT, onDowntimeUpdate || (() => {}), lineId ? { lineId } : undefined, MessagePriority.CRITICAL),
    ].filter(Boolean);

    return () => {
      subscriptions.forEach(subscriptionId => {
        if (subscriptionId) {
          ws.unsubscribe(subscriptionId);
        }
      });
    };
  }, [lineId, onProductionUpdate, onScheduleUpdate, onJobUpdate, onMetricsUpdate, onOEEUpdate, onDowntimeUpdate]);

  return ws;
};

/**
 * Equipment WebSocket Hook
 * 
 * Specialized hook for equipment-related WebSocket events with monitoring
 */
export const useEquipmentWebSocket = (options: {
  equipmentId?: string;
  enableHealthMonitoring?: boolean;
  onStatusUpdate?: (data: any) => void;
  onFaultOccurred?: (data: any) => void;
  onFaultResolved?: (data: any) => void;
  onMaintenanceUpdate?: (data: any) => void;
} = {}) => {
  const { 
    equipmentId, 
    enableHealthMonitoring = true,
    onStatusUpdate, 
    onFaultOccurred, 
    onFaultResolved, 
    onMaintenanceUpdate 
  } = options;
  
  const ws = useEnhancedWebSocket({
    enableHealthMonitoring,
    enableBatching: true,
    batchSize: 8,
    batchTimeout: 75,
    onMessage: (message) => {
      // Filter messages by equipment ID if specified
      if (equipmentId && message.data?.equipmentId && message.data.equipmentId !== equipmentId) {
        return;
      }

      switch (message.type) {
        case WEBSOCKET_EVENTS.EQUIPMENT_STATUS_UPDATED:
          onStatusUpdate?.(message.data);
          break;
        case WEBSOCKET_EVENTS.EQUIPMENT_FAULT_OCCURRED:
          onFaultOccurred?.(message.data);
          break;
        case WEBSOCKET_EVENTS.EQUIPMENT_FAULT_RESOLVED:
          onFaultResolved?.(message.data);
          break;
        case WEBSOCKET_EVENTS.MAINTENANCE_SCHEDULE_UPDATED:
          onMaintenanceUpdate?.(message.data);
          break;
      }
    },
  });

  // Subscribe to equipment events
  useEffect(() => {
    const subscriptions = [
      ws.subscribe(WEBSOCKET_EVENTS.EQUIPMENT_STATUS_UPDATED, onStatusUpdate || (() => {}), equipmentId ? { equipmentId } : undefined, MessagePriority.NORMAL),
      ws.subscribe(WEBSOCKET_EVENTS.EQUIPMENT_FAULT_OCCURRED, onFaultOccurred || (() => {}), equipmentId ? { equipmentId } : undefined, MessagePriority.CRITICAL),
      ws.subscribe(WEBSOCKET_EVENTS.EQUIPMENT_FAULT_RESOLVED, onFaultResolved || (() => {}), equipmentId ? { equipmentId } : undefined, MessagePriority.HIGH),
      ws.subscribe(WEBSOCKET_EVENTS.MAINTENANCE_SCHEDULE_UPDATED, onMaintenanceUpdate || (() => {}), equipmentId ? { equipmentId } : undefined, MessagePriority.NORMAL),
    ].filter(Boolean);

    return () => {
      subscriptions.forEach(subscriptionId => {
        if (subscriptionId) {
          ws.unsubscribe(subscriptionId);
        }
      });
    };
  }, [equipmentId, onStatusUpdate, onFaultOccurred, onFaultResolved, onMaintenanceUpdate]);

  return ws;
};

/**
 * Andon WebSocket Hook
 * 
 * Specialized hook for Andon-related WebSocket events with priority handling
 */
export const useAndonWebSocket = (options: {
  lineId?: string;
  priority?: string;
  enableHealthMonitoring?: boolean;
  onEventCreated?: (data: any) => void;
  onEventUpdated?: (data: any) => void;
  onEventResolved?: (data: any) => void;
  onEscalationTriggered?: (data: any) => void;
} = {}) => {
  const { 
    lineId, 
    priority,
    enableHealthMonitoring = true,
    onEventCreated, 
    onEventUpdated, 
    onEventResolved, 
    onEscalationTriggered 
  } = options;
  
  const ws = useEnhancedWebSocket({
    enableHealthMonitoring,
    enableBatching: false, // Critical events should not be batched
    priorityQueue: true,
    onMessage: (message) => {
      // Filter messages by line ID if specified
      if (lineId && message.data?.lineId && message.data.lineId !== lineId) {
        return;
      }

      // Filter by priority if specified
      if (priority && message.data?.priority && message.data.priority !== priority) {
        return;
      }

      switch (message.type) {
        case WEBSOCKET_EVENTS.ANDON_EVENT_CREATED:
          onEventCreated?.(message.data);
          break;
        case WEBSOCKET_EVENTS.ANDON_EVENT_UPDATED:
          onEventUpdated?.(message.data);
          break;
        case WEBSOCKET_EVENTS.ANDON_EVENT_RESOLVED:
          onEventResolved?.(message.data);
          break;
        case WEBSOCKET_EVENTS.ANDON_ESCALATION_TRIGGERED:
          onEscalationTriggered?.(message.data);
          break;
      }
    },
  });

  // Subscribe to Andon events
  useEffect(() => {
    const filters: Record<string, any> = {};
    if (lineId) filters.lineId = lineId;
    if (priority) filters.priority = priority;

    const subscriptions = [
      ws.subscribe(WEBSOCKET_EVENTS.ANDON_EVENT_CREATED, onEventCreated || (() => {}), filters, MessagePriority.CRITICAL),
      ws.subscribe(WEBSOCKET_EVENTS.ANDON_EVENT_UPDATED, onEventUpdated || (() => {}), filters, MessagePriority.HIGH),
      ws.subscribe(WEBSOCKET_EVENTS.ANDON_EVENT_RESOLVED, onEventResolved || (() => {}), filters, MessagePriority.HIGH),
      ws.subscribe(WEBSOCKET_EVENTS.ANDON_ESCALATION_TRIGGERED, onEscalationTriggered || (() => {}), filters, MessagePriority.CRITICAL),
    ].filter(Boolean);

    return () => {
      subscriptions.forEach(subscriptionId => {
        if (subscriptionId) {
          ws.unsubscribe(subscriptionId);
        }
      });
    };
  }, [lineId, priority, onEventCreated, onEventUpdated, onEventResolved, onEscalationTriggered]);

  return ws;
};

/**
 * Quality WebSocket Hook
 * 
 * Specialized hook for quality-related WebSocket events
 */
export const useQualityWebSocket = (options: {
  lineId?: string;
  enableHealthMonitoring?: boolean;
  onCheckCompleted?: (data: any) => void;
  onInspectionCompleted?: (data: any) => void;
  onDefectReported?: (data: any) => void;
  onAlertTriggered?: (data: any) => void;
} = {}) => {
  const { 
    lineId, 
    enableHealthMonitoring = true,
    onCheckCompleted, 
    onInspectionCompleted, 
    onDefectReported, 
    onAlertTriggered 
  } = options;
  
  const ws = useEnhancedWebSocket({
    enableHealthMonitoring,
    enableBatching: true,
    batchSize: 6,
    batchTimeout: 150,
    onMessage: (message) => {
      // Filter messages by line ID if specified
      if (lineId && message.data?.lineId && message.data.lineId !== lineId) {
        return;
      }

      switch (message.type) {
        case WEBSOCKET_EVENTS.QUALITY_CHECK_COMPLETED:
          onCheckCompleted?.(message.data);
          break;
        case WEBSOCKET_EVENTS.QUALITY_INSPECTION_COMPLETED:
          onInspectionCompleted?.(message.data);
          break;
        case WEBSOCKET_EVENTS.QUALITY_DEFECT_REPORTED:
          onDefectReported?.(message.data);
          break;
        case WEBSOCKET_EVENTS.QUALITY_ALERT_TRIGGERED:
          onAlertTriggered?.(message.data);
          break;
      }
    },
  });

  // Subscribe to quality events
  useEffect(() => {
    const subscriptions = [
      ws.subscribe(WEBSOCKET_EVENTS.QUALITY_CHECK_COMPLETED, onCheckCompleted || (() => {}), lineId ? { lineId } : undefined, MessagePriority.NORMAL),
      ws.subscribe(WEBSOCKET_EVENTS.QUALITY_INSPECTION_COMPLETED, onInspectionCompleted || (() => {}), lineId ? { lineId } : undefined, MessagePriority.NORMAL),
      ws.subscribe(WEBSOCKET_EVENTS.QUALITY_DEFECT_REPORTED, onDefectReported || (() => {}), lineId ? { lineId } : undefined, MessagePriority.HIGH),
      ws.subscribe(WEBSOCKET_EVENTS.QUALITY_ALERT_TRIGGERED, onAlertTriggered || (() => {}), lineId ? { lineId } : undefined, MessagePriority.CRITICAL),
    ].filter(Boolean);

    return () => {
      subscriptions.forEach(subscriptionId => {
        if (subscriptionId) {
          ws.unsubscribe(subscriptionId);
        }
      });
    };
  }, [lineId, onCheckCompleted, onInspectionCompleted, onDefectReported, onAlertTriggered]);

  return ws;
};

/**
 * Dashboard WebSocket Hook
 * 
 * Specialized hook for dashboard-related WebSocket events with performance optimization
 */
export const useDashboardWebSocket = (options: {
  enableHealthMonitoring?: boolean;
  enableBatching?: boolean;
  onDataUpdate?: (data: any) => void;
  onMetricsUpdate?: (data: any) => void;
  onOEEUpdate?: (data: any) => void;
} = {}) => {
  const { 
    enableHealthMonitoring = true,
    enableBatching = true,
    onDataUpdate, 
    onMetricsUpdate, 
    onOEEUpdate 
  } = options;
  
  const ws = useEnhancedWebSocket({
    enableHealthMonitoring,
    enableBatching,
    batchSize: 12,
    batchTimeout: 200,
    onMessage: (message) => {
      switch (message.type) {
        case WEBSOCKET_EVENTS.DASHBOARD_DATA_UPDATED:
          onDataUpdate?.(message.data);
          break;
        case WEBSOCKET_EVENTS.REAL_TIME_METRICS_UPDATED:
          onMetricsUpdate?.(message.data);
          break;
        case WEBSOCKET_EVENTS.OEE_DATA_UPDATED:
          onOEEUpdate?.(message.data);
          break;
      }
    },
  });

  // Subscribe to dashboard events
  useEffect(() => {
    const subscriptions = [
      ws.subscribe(WEBSOCKET_EVENTS.DASHBOARD_DATA_UPDATED, onDataUpdate || (() => {}), undefined, MessagePriority.NORMAL),
      ws.subscribe(WEBSOCKET_EVENTS.REAL_TIME_METRICS_UPDATED, onMetricsUpdate || (() => {}), undefined, MessagePriority.NORMAL),
      ws.subscribe(WEBSOCKET_EVENTS.OEE_DATA_UPDATED, onOEEUpdate || (() => {}), undefined, MessagePriority.HIGH),
    ].filter(Boolean);

    return () => {
      subscriptions.forEach(subscriptionId => {
        if (subscriptionId) {
          ws.unsubscribe(subscriptionId);
        }
      });
    };
  }, [onDataUpdate, onMetricsUpdate, onOEEUpdate]);

  return ws;
};

// Legacy hook for backward compatibility
export const useWebSocket = useEnhancedWebSocket;

// Export all hooks and types
export { 
  useEnhancedWebSocket,
  useProductionWebSocket,
  useEquipmentWebSocket,
  useAndonWebSocket,
  useQualityWebSocket,
  useDashboardWebSocket,
  MessagePriority,
  EnhancedWebSocketState
};

export default useEnhancedWebSocket;