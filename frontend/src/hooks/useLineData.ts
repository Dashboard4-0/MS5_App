/**
 * MS5.0 Floor Dashboard - Line Data Hook
 * 
 * This hook provides real-time data binding for a specific production line,
 * including OEE, equipment status, downtime, and production metrics.
 */

import { useEffect, useState, useCallback, useRef } from 'react';
import { useSelector, useDispatch } from 'react-redux';
import { RootState } from '../store';
import { 
  updateOEEData, 
  updateEquipmentStatus, 
  updateDowntimeData,
  updateProductionData,
  setSelectedLineId
} from '../store/slices/dashboardSlice';
import { 
  addAndonEvent, 
  updateAndonEvent, 
  resolveAndonEvent 
} from '../store/slices/andonSlice';
import { EVENT_TYPES } from '../config/constants';
import { logger } from '../utils/logger';
import useWebSocket from './useWebSocket';

interface UseLineDataOptions {
  lineId: string;
  enableOEE?: boolean;
  enableEquipment?: boolean;
  enableDowntime?: boolean;
  enableProduction?: boolean;
  enableAndon?: boolean;
  autoSubscribe?: boolean;
  refreshInterval?: number;
}

interface UseLineDataReturn {
  isConnected: boolean;
  isSubscribed: boolean;
  lastUpdate: Date | null;
  error: string | null;
  lineData: any;
  subscribe: () => void;
  unsubscribe: () => void;
  refresh: () => void;
  setLineId: (newLineId: string) => void;
}

export const useLineData = (options: UseLineDataOptions): UseLineDataReturn => {
  const {
    lineId,
    enableOEE = true,
    enableEquipment = true,
    enableDowntime = true,
    enableProduction = true,
    enableAndon = true,
    autoSubscribe = true,
    refreshInterval = 30000 // 30 seconds
  } = options;

  const dispatch = useDispatch();
  const { user } = useSelector((state: RootState) => state.auth);
  const dashboardState = useSelector((state: RootState) => state.dashboard);
  const andonState = useSelector((state: RootState) => state.andon);
  
  const [isSubscribed, setIsSubscribed] = useState(false);
  const [lastUpdate, setLastUpdate] = useState<Date | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [currentLineId, setCurrentLineId] = useState(lineId);
  
  const subscriptionsRef = useRef<Set<string>>(new Set());
  const refreshIntervalRef = useRef<NodeJS.Timeout | null>(null);
  
  const { isConnected, subscribe: wsSubscribe, unsubscribe: wsUnsubscribe } = useWebSocket({
    autoConnect: true,
    onError: (error) => setError(error)
  });

  // Get line-specific data from store
  const lineData = {
    oee: dashboardState.oeeData.filter(data => data.lineId === currentLineId),
    equipment: dashboardState.equipmentStatus.filter(status => status.lineId === currentLineId),
    downtime: dashboardState.downtimeData.filter(data => data.lineId === currentLineId),
    production: dashboardState.productionData.filter(data => data.lineId === currentLineId),
    andon: andonState.events.filter(event => event.lineId === currentLineId),
    lastUpdate
  };

  // Handle line status updates
  const handleLineStatusUpdate = useCallback((data: any) => {
    if (data.line_id !== currentLineId) return;
    
    try {
      dispatch(updateProductionData(data));
      setLastUpdate(new Date());
      setError(null);
      logger.debug('Line status updated via line data hook', { lineId: currentLineId, data });
    } catch (err) {
      logger.error('Error updating line status', err);
      setError('Failed to update line status');
    }
  }, [dispatch, currentLineId]);

  // Handle OEE updates for this line
  const handleOEEUpdate = useCallback((data: any) => {
    if (data.line_id !== currentLineId) return;
    
    try {
      dispatch(updateOEEData(data));
      setLastUpdate(new Date());
      setError(null);
      logger.debug('OEE data updated via line data hook', { lineId: currentLineId, data });
    } catch (err) {
      logger.error('Error updating OEE data', err);
      setError('Failed to update OEE data');
    }
  }, [dispatch, currentLineId]);

  // Handle equipment status updates for this line
  const handleEquipmentStatusUpdate = useCallback((data: any) => {
    if (data.line_id !== currentLineId) return;
    
    try {
      dispatch(updateEquipmentStatus(data));
      setLastUpdate(new Date());
      setError(null);
      logger.debug('Equipment status updated via line data hook', { lineId: currentLineId, data });
    } catch (err) {
      logger.error('Error updating equipment status', err);
      setError('Failed to update equipment status');
    }
  }, [dispatch, currentLineId]);

  // Handle downtime events for this line
  const handleDowntimeEvent = useCallback((data: any) => {
    if (data.line_id !== currentLineId) return;
    
    try {
      dispatch(updateDowntimeData(data));
      setLastUpdate(new Date());
      setError(null);
      logger.debug('Downtime data updated via line data hook', { lineId: currentLineId, data });
    } catch (err) {
      logger.error('Error updating downtime data', err);
      setError('Failed to update downtime data');
    }
  }, [dispatch, currentLineId]);

  // Handle Andon events for this line
  const handleAndonEvent = useCallback((data: any) => {
    if (data.line_id !== currentLineId) return;
    
    try {
      if (data.event_type === 'new') {
        dispatch(addAndonEvent(data));
      } else if (data.event_type === 'update') {
        dispatch(updateAndonEvent(data));
      } else if (data.event_type === 'resolve') {
        dispatch(resolveAndonEvent(data.id));
      }
      
      setLastUpdate(new Date());
      setError(null);
      logger.debug('Andon event updated via line data hook', { lineId: currentLineId, data });
    } catch (err) {
      logger.error('Error updating Andon event', err);
      setError('Failed to update Andon event');
    }
  }, [dispatch, currentLineId]);

  // Subscribe to line-specific data
  const subscribe = useCallback(() => {
    if (!isConnected) {
      logger.warn('Cannot subscribe to line data: WebSocket not connected');
      return;
    }

    try {
      // Subscribe to line status updates
      const lineSubscriptionId = wsSubscribe(EVENT_TYPES.LINE_STATUS_UPDATE, handleLineStatusUpdate);
      subscriptionsRef.current.add(lineSubscriptionId);

      // Subscribe to OEE updates
      if (enableOEE) {
        const oeeSubscriptionId = wsSubscribe(EVENT_TYPES.OEE_UPDATE, handleOEEUpdate);
        subscriptionsRef.current.add(oeeSubscriptionId);
      }

      // Subscribe to equipment status updates
      if (enableEquipment) {
        const equipmentSubscriptionId = wsSubscribe(EVENT_TYPES.EQUIPMENT_STATUS_CHANGE, handleEquipmentStatusUpdate);
        subscriptionsRef.current.add(equipmentSubscriptionId);
      }

      // Subscribe to downtime events
      if (enableDowntime) {
        const downtimeSubscriptionId = wsSubscribe(EVENT_TYPES.DOWNTIME_EVENT, handleDowntimeEvent);
        subscriptionsRef.current.add(downtimeSubscriptionId);
      }

      // Subscribe to production updates
      if (enableProduction) {
        const productionSubscriptionId = wsSubscribe(EVENT_TYPES.PRODUCTION_UPDATE, handleLineStatusUpdate);
        subscriptionsRef.current.add(productionSubscriptionId);
      }

      // Subscribe to Andon events
      if (enableAndon) {
        const andonSubscriptionId = wsSubscribe(EVENT_TYPES.ANDON_ALERT, handleAndonEvent);
        subscriptionsRef.current.add(andonSubscriptionId);
      }

      setIsSubscribed(true);
      setError(null);
      logger.info('Subscribed to line data', { 
        lineId: currentLineId, 
        subscriptions: Array.from(subscriptionsRef.current) 
      });

    } catch (err) {
      logger.error('Failed to subscribe to line data', err);
      setError('Failed to subscribe to line data');
    }
  }, [
    isConnected,
    currentLineId,
    enableOEE,
    enableEquipment,
    enableDowntime,
    enableProduction,
    enableAndon,
    wsSubscribe,
    handleLineStatusUpdate,
    handleOEEUpdate,
    handleEquipmentStatusUpdate,
    handleDowntimeEvent,
    handleAndonEvent
  ]);

  // Unsubscribe from line data
  const unsubscribe = useCallback(() => {
    try {
      subscriptionsRef.current.forEach((subscriptionId) => {
        wsUnsubscribe(subscriptionId);
      });
      subscriptionsRef.current.clear();
      
      setIsSubscribed(false);
      setError(null);
      logger.info('Unsubscribed from line data', { lineId: currentLineId });
    } catch (err) {
      logger.error('Failed to unsubscribe from line data', err);
      setError('Failed to unsubscribe from line data');
    }
  }, [wsUnsubscribe, currentLineId]);

  // Refresh data (re-subscribe)
  const refresh = useCallback(() => {
    unsubscribe();
    setTimeout(() => {
      subscribe();
    }, 100);
  }, [subscribe, unsubscribe]);

  // Set new line ID
  const setLineId = useCallback((newLineId: string) => {
    if (newLineId !== currentLineId) {
      unsubscribe();
      setCurrentLineId(newLineId);
      dispatch(setSelectedLineId(newLineId));
      
      // Re-subscribe with new line ID
      setTimeout(() => {
        subscribe();
      }, 100);
    }
  }, [currentLineId, unsubscribe, dispatch, subscribe]);

  // Setup refresh interval
  useEffect(() => {
    if (refreshInterval > 0) {
      refreshIntervalRef.current = setInterval(() => {
        if (isSubscribed) {
          refresh();
        }
      }, refreshInterval);
    }

    return () => {
      if (refreshIntervalRef.current) {
        clearInterval(refreshIntervalRef.current);
        refreshIntervalRef.current = null;
      }
    };
  }, [refreshInterval, isSubscribed, refresh]);

  // Auto-subscribe when connected
  useEffect(() => {
    if (autoSubscribe && isConnected && !isSubscribed) {
      subscribe();
    }
  }, [autoSubscribe, isConnected, isSubscribed, subscribe]);

  // Update line ID when prop changes
  useEffect(() => {
    if (lineId !== currentLineId) {
      setLineId(lineId);
    }
  }, [lineId, currentLineId, setLineId]);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      unsubscribe();
      if (refreshIntervalRef.current) {
        clearInterval(refreshIntervalRef.current);
      }
    };
  }, [unsubscribe]);

  return {
    isConnected,
    isSubscribed,
    lastUpdate,
    error,
    lineData,
    subscribe,
    unsubscribe,
    refresh,
    setLineId
  };
};

export default useLineData;
