/**
 * MS5.0 Floor Dashboard - Offline Redux Slice
 * 
 * This slice manages offline functionality including data synchronization,
 * offline queue management, and network status monitoring.
 */

import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit';
import { RootState } from '../index';
import { apiService } from '../../services/api';

// Types
interface OfflineAction {
  id: string;
  type: string;
  payload: any;
  timestamp: string;
  retryCount: number;
  maxRetries: number;
  priority: 'low' | 'medium' | 'high' | 'critical';
  status: 'pending' | 'processing' | 'completed' | 'failed' | 'cancelled' | 'conflict';
  error?: string;
  endpoint?: string;
  method?: string;
  conflictResolution?: 'server' | 'client' | 'merge' | 'manual';
  serverVersion?: number;
  clientVersion?: number;
  lastAttempt?: string;
  nextRetry?: string;
}

interface SyncStatus {
  isOnline: boolean;
  lastSync: string | null;
  nextSync: string | null;
  syncInProgress: boolean;
  syncError: string | null;
  totalActions: number;
  pendingActions: number;
  completedActions: number;
  failedActions: number;
  conflictActions: number;
  retryActions: number;
  syncProgress: number;
  estimatedTimeRemaining: number;
}

interface OfflineData {
  [key: string]: {
    data: any;
    timestamp: string;
    version: number;
    synced: boolean;
    conflict?: boolean;
    serverVersion?: number;
    lastModified?: string;
    checksum?: string;
  };
}

interface ConflictResolution {
  actionId: string;
  conflictType: 'version' | 'data' | 'permission';
  serverData: any;
  clientData: any;
  resolution: 'server' | 'client' | 'merge' | 'manual';
  resolvedAt?: string;
  resolvedBy?: string;
}

interface OfflineState {
  // Network status
  isOnline: boolean;
  networkType: string | null;
  connectionQuality: 'poor' | 'fair' | 'good' | 'excellent';
  
  // Sync status
  syncStatus: SyncStatus;
  
  // Offline queue
  actionQueue: OfflineAction[];
  processingQueue: OfflineAction[];
  conflictQueue: OfflineAction[];
  
  // Offline data cache
  offlineData: OfflineData;
  
  // Conflict resolution
  conflicts: ConflictResolution[];
  conflictResolutionStrategy: 'server' | 'client' | 'merge' | 'manual';
  
  // Settings
  autoSync: boolean;
  syncInterval: number; // minutes
  maxRetries: number;
  retryDelay: number; // seconds
  conflictRetryDelay: number; // seconds
  batchSize: number;
  compressionEnabled: boolean;
  
  // UI State
  showOfflineIndicator: boolean;
  showSyncProgress: boolean;
  showConflictDialog: boolean;
  
  // Action states
  actionLoading: boolean;
  actionError: string | null;
  conflictLoading: boolean;
  conflictError: string | null;
}

// Initial state
const initialState: OfflineState = {
  isOnline: true,
  networkType: null,
  connectionQuality: 'good',
  
  syncStatus: {
    isOnline: true,
    lastSync: null,
    nextSync: null,
    syncInProgress: false,
    syncError: null,
    totalActions: 0,
    pendingActions: 0,
    completedActions: 0,
    failedActions: 0,
    conflictActions: 0,
    retryActions: 0,
    syncProgress: 0,
    estimatedTimeRemaining: 0,
  },
  
  actionQueue: [],
  processingQueue: [],
  conflictQueue: [],
  
  offlineData: {},
  
  conflicts: [],
  conflictResolutionStrategy: 'merge',
  
  autoSync: true,
  syncInterval: 5, // 5 minutes
  maxRetries: 3,
  retryDelay: 30, // 30 seconds
  conflictRetryDelay: 60, // 60 seconds
  batchSize: 10,
  compressionEnabled: true,
  
  showOfflineIndicator: false,
  showSyncProgress: false,
  showConflictDialog: false,
  
  actionLoading: false,
  actionError: null,
  conflictLoading: false,
  conflictError: null,
};

// Async thunks
export const syncOfflineActions = createAsyncThunk(
  'offline/syncOfflineActions',
  async (_, { rejectWithValue, getState }) => {
    try {
      const state = getState() as RootState;
      const pendingActions = state.offline.actionQueue.filter(action => action.status === 'pending');
      
      if (pendingActions.length === 0) {
        return { synced: 0, failed: 0, conflicts: 0 };
      }
      
      let synced = 0;
      let failed = 0;
      let conflicts = 0;
      
      // Process actions in batches
      const batchSize = state.offline.batchSize;
      for (let i = 0; i < pendingActions.length; i += batchSize) {
        const batch = pendingActions.slice(i, i + batchSize);
        
        for (const action of batch) {
          try {
            const result = await processOfflineActionWithConflictResolution(action, state.offline);
            
            if (result.status === 'conflict') {
              conflicts++;
            } else if (result.status === 'completed') {
              synced++;
            } else {
              failed++;
            }
          } catch (error) {
            failed++;
            console.error(`Failed to sync action ${action.id}:`, error);
          }
        }
      }
      
      return { synced, failed, conflicts };
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to sync offline actions');
    }
  }
);

export const resolveConflict = createAsyncThunk(
  'offline/resolveConflict',
  async ({ actionId, resolution }: { actionId: string; resolution: 'server' | 'client' | 'merge' }, { rejectWithValue, getState }) => {
    try {
      const state = getState() as RootState;
      const action = state.offline.actionQueue.find(a => a.id === actionId);
      const conflict = state.offline.conflicts.find(c => c.actionId === actionId);
      
      if (!action || !conflict) {
        throw new Error('Action or conflict not found');
      }
      
      // Apply conflict resolution
      const resolvedData = applyConflictResolution(conflict, resolution);
      
      // Retry the action with resolved data
      const result = await processOfflineActionWithConflictResolution({
        ...action,
        payload: resolvedData,
        conflictResolution: resolution
      }, state.offline);
      
      return { actionId, resolution, result };
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to resolve conflict');
    }
  }
);

export const batchSyncActions = createAsyncThunk(
  'offline/batchSyncActions',
  async (actionIds: string[], { rejectWithValue, getState }) => {
    try {
      const state = getState() as RootState;
      const actions = state.offline.actionQueue.filter(action => actionIds.includes(action.id));
      
      if (actions.length === 0) {
        return { synced: 0, failed: 0, conflicts: 0 };
      }
      
      let synced = 0;
      let failed = 0;
      let conflicts = 0;
      
      // Process batch with compression if enabled
      const batchData = state.offline.compressionEnabled ? 
        compressBatchData(actions) : 
        actions;
      
      const result = await processBatchOfflineActions(batchData, state.offline);
      
      return result;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to batch sync actions');
    }
  }
);

export const retryFailedActions = createAsyncThunk(
  'offline/retryFailedActions',
  async (_, { rejectWithValue, getState }) => {
    try {
      const state = getState() as RootState;
      const failedActions = state.offline.actionQueue.filter(action => action.status === 'failed');
      
      if (failedActions.length === 0) {
        return { retried: 0 };
      }
      
      let retried = 0;
      
      for (const action of failedActions) {
        if (action.retryCount < action.maxRetries) {
          // Reset action for retry
          action.status = 'pending';
          action.retryCount++;
          action.error = undefined;
          retried++;
        }
      }
      
      return { retried };
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to retry failed actions');
    }
  }
);

export const clearCompletedActions = createAsyncThunk(
  'offline/clearCompletedActions',
  async (_, { rejectWithValue, getState }) => {
    try {
      const state = getState() as RootState;
      const completedActions = state.offline.actionQueue.filter(action => action.status === 'completed');
      
      return { cleared: completedActions.length };
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to clear completed actions');
    }
  }
);

export const downloadOfflineData = createAsyncThunk(
  'offline/downloadOfflineData',
  async (dataKeys: string[], { rejectWithValue }) => {
    try {
      const offlineData: OfflineData = {};
      
      for (const key of dataKeys) {
        try {
          const response = await apiService.get(`/api/v1/offline/${key}`);
          offlineData[key] = {
            data: response.data,
            timestamp: new Date().toISOString(),
            version: 1,
            synced: true,
          };
        } catch (error) {
          console.error(`Failed to download offline data for ${key}:`, error);
        }
      }
      
      return offlineData;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to download offline data');
    }
  }
);

export const uploadOfflineData = createAsyncThunk(
  'offline/uploadOfflineData',
  async (dataKey: string, { rejectWithValue, getState }) => {
    try {
      const state = getState() as RootState;
      const data = state.offline.offlineData[dataKey];
      
      if (!data) {
        throw new Error(`No offline data found for key: ${dataKey}`);
      }
      
      await apiService.post(`/api/v1/offline/${dataKey}`, data.data);
      
      return { key: dataKey, synced: true };
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to upload offline data');
    }
  }
);

// Helper function to process offline actions
async function processOfflineAction(action: OfflineAction): Promise<void> {
  // Simulate API call based on action type
  const delay = Math.random() * 1000; // Random delay between 0-1 second
  await new Promise(resolve => setTimeout(resolve, delay));
  
  // Simulate occasional failures
  if (Math.random() < 0.1) { // 10% failure rate
    throw new Error('Simulated API failure');
  }
}

async function processOfflineActionWithConflictResolution(action: OfflineAction, state: OfflineState): Promise<{ status: string; conflict?: ConflictResolution }> {
  try {
    // Simulate API call with conflict detection
    const delay = Math.random() * 1000;
    await new Promise(resolve => setTimeout(resolve, delay));
    
    // Simulate conflict detection (5% chance)
    if (Math.random() < 0.05) {
      const conflict: ConflictResolution = {
        actionId: action.id,
        conflictType: 'version',
        serverData: { ...action.payload, version: (action.serverVersion || 0) + 1 },
        clientData: action.payload,
        resolution: state.conflictResolutionStrategy
      };
      
      return { status: 'conflict', conflict };
    }
    
    // Simulate 10% failure rate
    if (Math.random() < 0.1) {
      throw new Error('Simulated API failure');
    }
    
    return { status: 'completed' };
  } catch (error) {
    return { status: 'failed' };
  }
}

function applyConflictResolution(conflict: ConflictResolution, resolution: 'server' | 'client' | 'merge'): any {
  switch (resolution) {
    case 'server':
      return conflict.serverData;
    case 'client':
      return conflict.clientData;
    case 'merge':
      // Simple merge strategy - prefer server data for conflicts
      return { ...conflict.clientData, ...conflict.serverData };
    default:
      return conflict.clientData;
  }
}

function compressBatchData(actions: OfflineAction[]): any {
  // Simple compression - in real implementation, use proper compression
  return {
    compressed: true,
    count: actions.length,
    data: actions.map(action => ({
      id: action.id,
      type: action.type,
      payload: action.payload
    }))
  };
}

async function processBatchOfflineActions(batchData: any, state: OfflineState): Promise<{ synced: number; failed: number; conflicts: number }> {
  try {
    // Simulate batch API call
    await new Promise(resolve => setTimeout(resolve, 200));
    
    // Simulate batch processing results
    const total = batchData.compressed ? batchData.count : batchData.length;
    const synced = Math.floor(total * 0.8);
    const conflicts = Math.floor(total * 0.1);
    const failed = total - synced - conflicts;
    
    return { synced, failed, conflicts };
  } catch (error) {
    return { synced: 0, failed: batchData.compressed ? batchData.count : batchData.length, conflicts: 0 };
  }
}

// Slice
const offlineSlice = createSlice({
  name: 'offline',
  initialState,
  reducers: {
    // Clear errors
    clearActionError: (state) => {
      state.actionError = null;
    },
    clearConflictError: (state) => {
      state.conflictError = null;
    },
    
    // Network status updates
    setOnlineStatus: (state, action: PayloadAction<boolean>) => {
      state.isOnline = action.payload;
      state.syncStatus.isOnline = action.payload;
      
      if (action.payload) {
        state.showOfflineIndicator = false;
        // Trigger sync when coming back online
        if (state.autoSync && state.actionQueue.length > 0) {
          state.syncStatus.syncInProgress = true;
        }
      } else {
        state.showOfflineIndicator = true;
        state.syncStatus.syncInProgress = false;
      }
    },
    
    setNetworkType: (state, action: PayloadAction<string>) => {
      state.networkType = action.payload;
    },
    
    setConnectionQuality: (state, action: PayloadAction<'poor' | 'fair' | 'good' | 'excellent'>) => {
      state.connectionQuality = action.payload;
    },
    
    // Action queue management
    addOfflineAction: (state, action: PayloadAction<Omit<OfflineAction, 'id' | 'timestamp' | 'retryCount' | 'status'>>) => {
      const newAction: OfflineAction = {
        ...action.payload,
        id: `action_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
        timestamp: new Date().toISOString(),
        retryCount: 0,
        status: 'pending',
      };
      
      state.actionQueue.push(newAction);
      state.syncStatus.pendingActions++;
      state.syncStatus.totalActions++;
    },
    
    updateActionStatus: (state, action: PayloadAction<{ id: string; status: OfflineAction['status']; error?: string }>) => {
      const { id, status, error } = action.payload;
      const actionIndex = state.actionQueue.findIndex(action => action.id === id);
      
      if (actionIndex !== -1) {
        const action = state.actionQueue[actionIndex];
        const oldStatus = action.status;
        action.status = status;
        
        if (error) {
          action.error = error;
        }
        
        // Update counters
        if (oldStatus === 'pending' && status !== 'pending') {
          state.syncStatus.pendingActions--;
        }
        
        if (status === 'completed') {
          state.syncStatus.completedActions++;
        } else if (status === 'failed') {
          state.syncStatus.failedActions++;
        }
      }
    },
    
    removeAction: (state, action: PayloadAction<string>) => {
      const actionId = action.payload;
      const actionIndex = state.actionQueue.findIndex(action => action.id === actionId);
      
      if (actionIndex !== -1) {
        const action = state.actionQueue[actionIndex];
        
        // Update counters
        if (action.status === 'pending') {
          state.syncStatus.pendingActions--;
        } else if (action.status === 'completed') {
          state.syncStatus.completedActions--;
        } else if (action.status === 'failed') {
          state.syncStatus.failedActions--;
        }
        
        state.actionQueue.splice(actionIndex, 1);
        state.syncStatus.totalActions--;
      }
    },
    
    clearActionQueue: (state) => {
      state.actionQueue = [];
      state.processingQueue = [];
      state.syncStatus.pendingActions = 0;
      state.syncStatus.completedActions = 0;
      state.syncStatus.failedActions = 0;
      state.syncStatus.totalActions = 0;
    },
    
    // Offline data management
    setOfflineData: (state, action: PayloadAction<{ key: string; data: any; synced?: boolean }>) => {
      const { key, data, synced = false } = action.payload;
      state.offlineData[key] = {
        data,
        timestamp: new Date().toISOString(),
        version: (state.offlineData[key]?.version || 0) + 1,
        synced,
      };
    },
    
    removeOfflineData: (state, action: PayloadAction<string>) => {
      delete state.offlineData[action.payload];
    },
    
    markDataAsSynced: (state, action: PayloadAction<string>) => {
      const key = action.payload;
      if (state.offlineData[key]) {
        state.offlineData[key].synced = true;
      }
    },
    
    // Settings
    setAutoSync: (state, action: PayloadAction<boolean>) => {
      state.autoSync = action.payload;
    },
    
    setSyncInterval: (state, action: PayloadAction<number>) => {
      state.syncInterval = action.payload;
    },
    
    setMaxRetries: (state, action: PayloadAction<number>) => {
      state.maxRetries = action.payload;
    },
    
    setRetryDelay: (state, action: PayloadAction<number>) => {
      state.retryDelay = action.payload;
    },
    
    // UI state
    setShowOfflineIndicator: (state, action: PayloadAction<boolean>) => {
      state.showOfflineIndicator = action.payload;
    },
    
    setShowSyncProgress: (state, action: PayloadAction<boolean>) => {
      state.showSyncProgress = action.payload;
    },
    
    // Sync status
    setSyncInProgress: (state, action: PayloadAction<boolean>) => {
      state.syncStatus.syncInProgress = action.payload;
    },
    
    setLastSync: (state, action: PayloadAction<string>) => {
      state.syncStatus.lastSync = action.payload;
    },
    
    setNextSync: (state, action: PayloadAction<string>) => {
      state.syncStatus.nextSync = action.payload;
    },
    
    // Conflict resolution
    addConflict: (state, action: PayloadAction<ConflictResolution>) => {
      state.conflicts.push(action.payload);
      state.syncStatus.conflictActions++;
    },
    
    resolveConflict: (state, action: PayloadAction<{ actionId: string; resolution: 'server' | 'client' | 'merge' }>) => {
      const { actionId, resolution } = action.payload;
      const conflictIndex = state.conflicts.findIndex(c => c.actionId === actionId);
      
      if (conflictIndex !== -1) {
        state.conflicts[conflictIndex].resolution = resolution;
        state.conflicts[conflictIndex].resolvedAt = new Date().toISOString();
        state.syncStatus.conflictActions--;
      }
    },
    
    removeConflict: (state, action: PayloadAction<string>) => {
      const actionId = action.payload;
      state.conflicts = state.conflicts.filter(c => c.actionId !== actionId);
    },
    
    setConflictResolutionStrategy: (state, action: PayloadAction<'server' | 'client' | 'merge' | 'manual'>) => {
      state.conflictResolutionStrategy = action.payload;
    },
    
    // Batch operations
    setBatchSize: (state, action: PayloadAction<number>) => {
      state.batchSize = action.payload;
    },
    
    setCompressionEnabled: (state, action: PayloadAction<boolean>) => {
      state.compressionEnabled = action.payload;
    },
    
    // UI state
    setShowConflictDialog: (state, action: PayloadAction<boolean>) => {
      state.showConflictDialog = action.payload;
    },
  },
  extraReducers: (builder) => {
    // Sync Offline Actions
    builder
      .addCase(syncOfflineActions.pending, (state) => {
        state.syncStatus.syncInProgress = true;
        state.syncStatus.syncError = null;
        state.actionLoading = true;
        state.actionError = null;
      })
      .addCase(syncOfflineActions.fulfilled, (state, action) => {
        state.syncStatus.syncInProgress = false;
        state.actionLoading = false;
        state.syncStatus.lastSync = new Date().toISOString();
        
        const { synced, failed, conflicts } = action.payload;
        state.syncStatus.pendingActions -= (synced + failed + conflicts);
        state.syncStatus.completedActions += synced;
        state.syncStatus.failedActions += failed;
        state.syncStatus.conflictActions += conflicts;
      })
      .addCase(syncOfflineActions.rejected, (state, action) => {
        state.syncStatus.syncInProgress = false;
        state.actionLoading = false;
        state.syncStatus.syncError = action.payload as string;
        state.actionError = action.payload as string;
      });
    
    // Retry Failed Actions
    builder
      .addCase(retryFailedActions.fulfilled, (state, action) => {
        const { retried } = action.payload;
        state.syncStatus.pendingActions += retried;
        state.syncStatus.failedActions -= retried;
      });
    
    // Clear Completed Actions
    builder
      .addCase(clearCompletedActions.fulfilled, (state, action) => {
        const { cleared } = action.payload;
        state.syncStatus.completedActions -= cleared;
        state.syncStatus.totalActions -= cleared;
      });
    
    // Download Offline Data
    builder
      .addCase(downloadOfflineData.fulfilled, (state, action) => {
        state.offlineData = { ...state.offlineData, ...action.payload };
      });
    
    // Upload Offline Data
    builder
      .addCase(uploadOfflineData.fulfilled, (state, action) => {
        const { key } = action.payload;
        if (state.offlineData[key]) {
          state.offlineData[key].synced = true;
        }
      });
  },
});

// Export actions
export const {
  clearActionError,
  clearConflictError,
  setOnlineStatus,
  setNetworkType,
  setConnectionQuality,
  addOfflineAction,
  updateActionStatus,
  removeAction,
  clearActionQueue,
  setOfflineData,
  removeOfflineData,
  markDataAsSynced,
  setAutoSync,
  setSyncInterval,
  setMaxRetries,
  setRetryDelay,
  setShowOfflineIndicator,
  setShowSyncProgress,
  setSyncInProgress,
  setLastSync,
  setNextSync,
  addConflict,
  resolveConflict,
  removeConflict,
  setConflictResolutionStrategy,
  setBatchSize,
  setCompressionEnabled,
  setShowConflictDialog,
} = offlineSlice.actions;

// Selectors
export const selectIsOnline = (state: RootState) => state.offline.isOnline;
export const selectNetworkType = (state: RootState) => state.offline.networkType;
export const selectConnectionQuality = (state: RootState) => state.offline.connectionQuality;

export const selectSyncStatus = (state: RootState) => state.offline.syncStatus;
export const selectActionQueue = (state: RootState) => state.offline.actionQueue;
export const selectProcessingQueue = (state: RootState) => state.offline.processingQueue;

export const selectOfflineData = (state: RootState) => state.offline.offlineData;
export const selectOfflineDataByKey = (key: string) => (state: RootState) => state.offline.offlineData[key];

export const selectAutoSync = (state: RootState) => state.offline.autoSync;
export const selectSyncInterval = (state: RootState) => state.offline.syncInterval;
export const selectMaxRetries = (state: RootState) => state.offline.maxRetries;
export const selectRetryDelay = (state: RootState) => state.offline.retryDelay;

export const selectShowOfflineIndicator = (state: RootState) => state.offline.showOfflineIndicator;
export const selectShowSyncProgress = (state: RootState) => state.offline.showSyncProgress;

export const selectActionLoading = (state: RootState) => state.offline.actionLoading;
export const selectActionError = (state: RootState) => state.offline.actionError;

// Computed selectors
export const selectPendingActions = (state: RootState) => 
  state.offline.actionQueue.filter(action => action.status === 'pending');

export const selectFailedActions = (state: RootState) => 
  state.offline.actionQueue.filter(action => action.status === 'failed');

export const selectCompletedActions = (state: RootState) => 
  state.offline.actionQueue.filter(action => action.status === 'completed');

export const selectActionsByPriority = (priority: OfflineAction['priority']) => (state: RootState) =>
  state.offline.actionQueue.filter(action => action.priority === priority);

export const selectUnsyncedData = (state: RootState) =>
  Object.entries(state.offline.offlineData)
    .filter(([_, data]) => !data.synced)
    .map(([key, data]) => ({ key, ...data }));

export const selectSyncProgress = (state: RootState) => {
  const { totalActions, completedActions, failedActions } = state.offline.syncStatus;
  if (totalActions === 0) return 0;
  return ((completedActions + failedActions) / totalActions) * 100;
};

// Export reducer
export default offlineSlice.reducer;
