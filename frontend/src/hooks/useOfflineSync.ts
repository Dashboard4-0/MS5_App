/**
 * MS5.0 Floor Dashboard - Offline Synchronization Hook
 * 
 * This hook provides offline synchronization capabilities with conflict resolution,
 * queue management, and automatic retry mechanisms.
 */

import { useEffect, useState, useCallback, useRef } from 'react';
import { useSelector, useDispatch } from 'react-redux';
import { RootState } from '../store';
import { 
  syncOfflineActions,
  retryFailedActions,
  clearCompletedActions,
  addOfflineAction,
  setOnlineStatus,
  setSyncInProgress,
  setLastSync,
  setNextSync
} from '../store/slices/offlineSlice';
import { logger } from '../utils/logger';
import { OFFLINE_CONFIGURATION } from '../config/api';

interface UseOfflineSyncOptions {
  autoSync?: boolean;
  syncInterval?: number;
  maxRetries?: number;
  retryDelay?: number;
  onSyncStart?: () => void;
  onSyncComplete?: (result: any) => void;
  onSyncError?: (error: string) => void;
  onConflictDetected?: (conflicts: any[]) => void;
}

interface UseOfflineSyncReturn {
  isOnline: boolean;
  isSyncing: boolean;
  lastSync: Date | null;
  nextSync: Date | null;
  pendingActions: number;
  failedActions: number;
  completedActions: number;
  syncError: string | null;
  sync: () => Promise<void>;
  retryFailed: () => Promise<void>;
  clearCompleted: () => Promise<void>;
  addAction: (action: any) => void;
  setOnline: (online: boolean) => void;
  getSyncStatus: () => any;
}

export const useOfflineSync = (options: UseOfflineSyncOptions = {}): UseOfflineSyncReturn => {
  const {
    autoSync = true,
    syncInterval = OFFLINE_CONFIGURATION.SYNC_INTERVAL,
    maxRetries = OFFLINE_CONFIGURATION.RETRY_SYNC_ATTEMPTS,
    retryDelay = 30000, // 30 seconds
    onSyncStart,
    onSyncComplete,
    onSyncError,
    onConflictDetected
  } = options;

  const dispatch = useDispatch();
  const offlineState = useSelector((state: RootState) => state.offline);
  const [syncError, setSyncError] = useState<string | null>(null);
  
  const syncIntervalRef = useRef<NodeJS.Timeout | null>(null);
  const retryTimeoutRef = useRef<NodeJS.Timeout | null>(null);
  const conflictResolutionRef = useRef<Map<string, any>>(new Map());

  // Get sync status
  const getSyncStatus = useCallback(() => {
    return {
      isOnline: offlineState.isOnline,
      isSyncing: offlineState.syncStatus.syncInProgress,
      lastSync: offlineState.syncStatus.lastSync,
      nextSync: offlineState.syncStatus.nextSync,
      pendingActions: offlineState.syncStatus.pendingActions,
      failedActions: offlineState.syncStatus.failedActions,
      completedActions: offlineState.syncStatus.completedActions,
      totalActions: offlineState.syncStatus.totalActions,
      syncError: offlineState.syncStatus.syncError
    };
  }, [offlineState]);

  // Handle sync start
  const handleSyncStart = useCallback(() => {
    dispatch(setSyncInProgress(true));
    setSyncError(null);
    onSyncStart?.();
    logger.info('Offline sync started');
  }, [dispatch, onSyncStart]);

  // Handle sync complete
  const handleSyncComplete = useCallback((result: any) => {
    dispatch(setSyncInProgress(false));
    dispatch(setLastSync(new Date().toISOString()));
    
    // Calculate next sync time
    const nextSyncTime = new Date(Date.now() + syncInterval);
    dispatch(setNextSync(nextSyncTime.toISOString()));
    
    onSyncComplete?.(result);
    logger.info('Offline sync completed', result);
  }, [dispatch, syncInterval, onSyncComplete]);

  // Handle sync error
  const handleSyncError = useCallback((error: string) => {
    dispatch(setSyncInProgress(false));
    setSyncError(error);
    onSyncError?.(error);
    logger.error('Offline sync error', error);
  }, [dispatch, onSyncError]);

  // Perform sync
  const sync = useCallback(async () => {
    if (offlineState.syncStatus.syncInProgress) {
      logger.warn('Sync already in progress');
      return;
    }

    if (!offlineState.isOnline) {
      logger.warn('Cannot sync: offline');
      return;
    }

    try {
      handleSyncStart();
      const result = await dispatch(syncOfflineActions()).unwrap();
      handleSyncComplete(result);
    } catch (error: any) {
      handleSyncError(error.message || 'Sync failed');
    }
  }, [offlineState.syncStatus.syncInProgress, offlineState.isOnline, dispatch, handleSyncStart, handleSyncComplete, handleSyncError]);

  // Retry failed actions
  const retryFailed = useCallback(async () => {
    if (offlineState.syncStatus.failedActions === 0) {
      logger.info('No failed actions to retry');
      return;
    }

    try {
      const result = await dispatch(retryFailedActions()).unwrap();
      logger.info('Failed actions retried', result);
    } catch (error: any) {
      logger.error('Failed to retry actions', error);
      setSyncError(error.message || 'Retry failed');
    }
  }, [offlineState.syncStatus.failedActions, dispatch]);

  // Clear completed actions
  const clearCompleted = useCallback(async () => {
    if (offlineState.syncStatus.completedActions === 0) {
      logger.info('No completed actions to clear');
      return;
    }

    try {
      const result = await dispatch(clearCompletedActions()).unwrap();
      logger.info('Completed actions cleared', result);
    } catch (error: any) {
      logger.error('Failed to clear completed actions', error);
      setSyncError(error.message || 'Clear failed');
    }
  }, [offlineState.syncStatus.completedActions, dispatch]);

  // Add offline action
  const addAction = useCallback((action: any) => {
    try {
      dispatch(addOfflineAction(action));
      logger.debug('Offline action added', action);
    } catch (error: any) {
      logger.error('Failed to add offline action', error);
      setSyncError(error.message || 'Add action failed');
    }
  }, [dispatch]);

  // Set online status
  const setOnline = useCallback((online: boolean) => {
    dispatch(setOnlineStatus(online));
    logger.info('Online status changed', { online });
  }, [dispatch]);

  // Conflict resolution
  const resolveConflict = useCallback((actionId: string, resolution: any) => {
    conflictResolutionRef.current.set(actionId, resolution);
    logger.debug('Conflict resolution set', { actionId, resolution });
  }, []);

  // Auto-sync setup
  useEffect(() => {
    if (autoSync && offlineState.isOnline) {
      // Initial sync
      if (offlineState.syncStatus.pendingActions > 0) {
        sync();
      }

      // Setup periodic sync
      syncIntervalRef.current = setInterval(() => {
        if (offlineState.syncStatus.pendingActions > 0 && !offlineState.syncStatus.syncInProgress) {
          sync();
        }
      }, syncInterval);

      // Setup retry mechanism for failed actions
      if (offlineState.syncStatus.failedActions > 0) {
        retryTimeoutRef.current = setTimeout(() => {
          retryFailed();
        }, retryDelay);
      }
    }

    return () => {
      if (syncIntervalRef.current) {
        clearInterval(syncIntervalRef.current);
        syncIntervalRef.current = null;
      }
      if (retryTimeoutRef.current) {
        clearTimeout(retryTimeoutRef.current);
        retryTimeoutRef.current = null;
      }
    };
  }, [
    autoSync,
    offlineState.isOnline,
    offlineState.syncStatus.pendingActions,
    offlineState.syncStatus.failedActions,
    offlineState.syncStatus.syncInProgress,
    syncInterval,
    retryDelay,
    sync,
    retryFailed
  ]);

  // Network status monitoring
  useEffect(() => {
    const handleOnline = () => {
      setOnline(true);
      // Trigger sync when coming back online
      if (offlineState.syncStatus.pendingActions > 0) {
        setTimeout(() => sync(), 1000);
      }
    };

    const handleOffline = () => {
      setOnline(false);
    };

    window.addEventListener('online', handleOnline);
    window.addEventListener('offline', handleOffline);

    return () => {
      window.removeEventListener('online', handleOnline);
      window.removeEventListener('offline', handleOffline);
    };
  }, [setOnline, offlineState.syncStatus.pendingActions, sync]);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (syncIntervalRef.current) {
        clearInterval(syncIntervalRef.current);
      }
      if (retryTimeoutRef.current) {
        clearTimeout(retryTimeoutRef.current);
      }
    };
  }, []);

  return {
    isOnline: offlineState.isOnline,
    isSyncing: offlineState.syncStatus.syncInProgress,
    lastSync: offlineState.syncStatus.lastSync ? new Date(offlineState.syncStatus.lastSync) : null,
    nextSync: offlineState.syncStatus.nextSync ? new Date(offlineState.syncStatus.nextSync) : null,
    pendingActions: offlineState.syncStatus.pendingActions,
    failedActions: offlineState.syncStatus.failedActions,
    completedActions: offlineState.syncStatus.completedActions,
    syncError: syncError || offlineState.syncStatus.syncError,
    sync,
    retryFailed,
    clearCompleted,
    addAction,
    setOnline,
    getSyncStatus
  };
};

export default useOfflineSync;
