/**
 * MS5.0 Floor Dashboard - Real-time Data Hook
 * 
 * This hook provides real-time data binding for production metrics,
 * OEE data, equipment status, and other live updates from the backend.
 */

import { useEffect, useState, useCallback, useRef } from 'react';
import { useSelector, useDispatch } from 'react-redux';
import { RootState } from '../store';
import { 
  updateOEEData, 
  updateEquipmentStatus, 
  updateDowntimeData,
  updateProductionData 
} from '../store/slices/dashboardSlice';
import { 
  addAndonEvent, 
  updateAndonEvent, 
  resolveAndonEvent 
} from '../store/slices/andonSlice';
import { 
  updateJobStatus, 
  addJobAssignment 
} from '../store/slices/jobsSlice';
import { EVENT_TYPES } from '../config/constants';
import { logger } from '../utils/logger';
import useWebSocket from './useWebSocket';

interface UseRealTimeDataOptions {
  lineId?: string;
  equipmentCode?: string;
  enableOEE?: boolean;
  enableEquipment?: boolean;
  enableDowntime?: boolean;
  enableProduction?: boolean;
  enableAndon?: boolean;
  enableJobs?: boolean;
  autoSubscribe?: boolean;
}

interface UseRealTimeDataReturn {
  isConnected: boolean;
  isSubscribed: boolean;
  lastUpdate: Date | null;
  error: string | null;
  subscribe: () => void;
  unsubscribe: () => void;
  refresh: () => void;
}

export const useRealTimeData = (options: UseRealTimeDataOptions = {}): UseRealTimeDataReturn => {
  const {
    lineId,
    equipmentCode,
    enableOEE = true,
    enableEquipment = true,
    enableDowntime = true,
    enableProduction = true,
    enableAndon = true,
    enableJobs = true,
    autoSubscribe = true
  } = options;

  const dispatch = useDispatch();
  const { user } = useSelector((state: RootState) => state.auth);
  const [isSubscribed, setIsSubscribed] = useState(false);
  const [lastUpdate, setLastUpdate] = useState<Date | null>(null);
  const [error, setError] = useState<string | null>(null);
  
  const subscriptionsRef = useRef<Set<string>>(new Set());
  const { isConnected, subscribe: wsSubscribe, unsubscribe: wsUnsubscribe } = useWebSocket({
    autoConnect: true,
    onError: (error) => setError(error)
  });

  // Handle OEE updates
  const handleOEEUpdate = useCallback((data: any) => {
    try {
      dispatch(updateOEEData(data));
      setLastUpdate(new Date());
      setError(null);
      logger.debug('OEE data updated via real-time hook', data);
    } catch (err) {
      logger.error('Error updating OEE data', err);
      setError('Failed to update OEE data');
    }
  }, [dispatch]);

  // Handle equipment status updates
  const handleEquipmentStatusUpdate = useCallback((data: any) => {
    try {
      dispatch(updateEquipmentStatus(data));
      setLastUpdate(new Date());
      setError(null);
      logger.debug('Equipment status updated via real-time hook', data);
    } catch (err) {
      logger.error('Error updating equipment status', err);
      setError('Failed to update equipment status');
    }
  }, [dispatch]);

  // Handle downtime events
  const handleDowntimeEvent = useCallback((data: any) => {
    try {
      dispatch(updateDowntimeData(data));
      setLastUpdate(new Date());
      setError(null);
      logger.debug('Downtime data updated via real-time hook', data);
    } catch (err) {
      logger.error('Error updating downtime data', err);
      setError('Failed to update downtime data');
    }
  }, [dispatch]);

  // Handle production updates
  const handleProductionUpdate = useCallback((data: any) => {
    try {
      dispatch(updateProductionData(data));
      setLastUpdate(new Date());
      setError(null);
      logger.debug('Production data updated via real-time hook', data);
    } catch (err) {
      logger.error('Error updating production data', err);
      setError('Failed to update production data');
    }
  }, [dispatch]);

  // Handle Andon events
  const handleAndonEvent = useCallback((data: any) => {
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
      logger.debug('Andon event updated via real-time hook', data);
    } catch (err) {
      logger.error('Error updating Andon event', err);
      setError('Failed to update Andon event');
    }
  }, [dispatch]);

  // Handle job updates
  const handleJobUpdate = useCallback((data: any) => {
    try {
      if (data.event_type === 'assigned') {
        dispatch(addJobAssignment(data));
      } else {
        dispatch(updateJobStatus(data));
      }
      
      setLastUpdate(new Date());
      setError(null);
      logger.debug('Job data updated via real-time hook', data);
    } catch (err) {
      logger.error('Error updating job data', err);
      setError('Failed to update job data');
    }
  }, [dispatch]);

  // Subscribe to real-time data
  const subscribe = useCallback(() => {
    if (!isConnected) {
      logger.warn('Cannot subscribe to real-time data: WebSocket not connected');
      return;
    }

    try {
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
        const productionSubscriptionId = wsSubscribe(EVENT_TYPES.PRODUCTION_UPDATE, handleProductionUpdate);
        subscriptionsRef.current.add(productionSubscriptionId);
      }

      // Subscribe to Andon events
      if (enableAndon) {
        const andonSubscriptionId = wsSubscribe(EVENT_TYPES.ANDON_ALERT, handleAndonEvent);
        subscriptionsRef.current.add(andonSubscriptionId);
      }

      // Subscribe to job updates
      if (enableJobs) {
        const jobSubscriptionId = wsSubscribe(EVENT_TYPES.JOB_UPDATE, handleJobUpdate);
        subscriptionsRef.current.add(jobSubscriptionId);
      }

      // Subscribe to line-specific updates if lineId provided
      if (lineId) {
        const lineSubscriptionId = wsSubscribe(EVENT_TYPES.LINE_STATUS_UPDATE, (data) => {
          if (data.line_id === lineId) {
            handleProductionUpdate(data);
          }
        });
        subscriptionsRef.current.add(lineSubscriptionId);
      }

      // Subscribe to equipment-specific updates if equipmentCode provided
      if (equipmentCode) {
        const equipmentSubscriptionId = wsSubscribe(EVENT_TYPES.EQUIPMENT_STATUS_CHANGE, (data) => {
          if (data.equipment_code === equipmentCode) {
            handleEquipmentStatusUpdate(data);
          }
        });
        subscriptionsRef.current.add(equipmentSubscriptionId);
      }

      setIsSubscribed(true);
      setError(null);
      logger.info('Subscribed to real-time data', { 
        lineId, 
        equipmentCode, 
        subscriptions: Array.from(subscriptionsRef.current) 
      });

    } catch (err) {
      logger.error('Failed to subscribe to real-time data', err);
      setError('Failed to subscribe to real-time data');
    }
  }, [
    isConnected,
    enableOEE,
    enableEquipment,
    enableDowntime,
    enableProduction,
    enableAndon,
    enableJobs,
    lineId,
    equipmentCode,
    wsSubscribe,
    handleOEEUpdate,
    handleEquipmentStatusUpdate,
    handleDowntimeEvent,
    handleProductionUpdate,
    handleAndonEvent,
    handleJobUpdate
  ]);

  // Unsubscribe from real-time data
  const unsubscribe = useCallback(() => {
    try {
      subscriptionsRef.current.forEach((subscriptionId) => {
        wsUnsubscribe(subscriptionId);
      });
      subscriptionsRef.current.clear();
      
      setIsSubscribed(false);
      setError(null);
      logger.info('Unsubscribed from real-time data');
    } catch (err) {
      logger.error('Failed to unsubscribe from real-time data', err);
      setError('Failed to unsubscribe from real-time data');
    }
  }, [wsUnsubscribe]);

  // Refresh data (re-subscribe)
  const refresh = useCallback(() => {
    unsubscribe();
    setTimeout(() => {
      subscribe();
    }, 100);
  }, [subscribe, unsubscribe]);

  // Auto-subscribe when connected
  useEffect(() => {
    if (autoSubscribe && isConnected && !isSubscribed) {
      subscribe();
    }
  }, [autoSubscribe, isConnected, isSubscribed, subscribe]);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      unsubscribe();
    };
  }, [unsubscribe]);

  return {
    isConnected,
    isSubscribed,
    lastUpdate,
    error,
    subscribe,
    unsubscribe,
    refresh
  };
};

export default useRealTimeData;
