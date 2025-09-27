/**
 * MS5.0 Floor Dashboard - Dashboard Redux Slice
 * 
 * This slice manages dashboard-related state including real-time data,
 * OEE metrics, equipment status, and dashboard configuration.
 */

import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit';
import { RootState } from '../index';
import { apiService } from '../../services/api';

// Types
interface OEEData {
  oee: number;
  availability: number;
  performance: number;
  quality: number;
  timestamp: string;
  lineId: string;
  equipmentCode: string;
}

interface EquipmentStatus {
  id: string;
  code: string;
  name: string;
  status: 'running' | 'stopped' | 'fault' | 'maintenance' | 'setup' | 'idle';
  speed: number;
  targetSpeed: number;
  efficiency: number;
  lastUpdate: string;
}

interface DowntimeEvent {
  id: string;
  equipmentCode: string;
  lineId: string;
  startTime: string;
  endTime?: string;
  duration?: number;
  reason: string;
  category: 'planned' | 'unplanned' | 'changeover' | 'maintenance';
  status: 'active' | 'resolved';
}

interface ProductionMetrics {
  lineId: string;
  currentProduction: number;
  targetProduction: number;
  efficiency: number;
  goodParts: number;
  totalParts: number;
  qualityRate: number;
  lastUpdate: string;
}

interface DashboardState {
  // Real-time data
  oeeData: OEEData[];
  equipmentStatus: EquipmentStatus[];
  downtimeEvents: DowntimeEvent[];
  productionMetrics: ProductionMetrics[];
  
  // Loading states
  oeeLoading: boolean;
  equipmentLoading: boolean;
  downtimeLoading: boolean;
  productionLoading: boolean;
  
  // Error states
  oeeError: string | null;
  equipmentError: string | null;
  downtimeError: string | null;
  productionError: string | null;
  
  // UI State
  selectedLineId: string | null;
  selectedEquipmentId: string | null;
  refreshInterval: number;
  autoRefresh: boolean;
  lastRefresh: string | null;
  
  // Dashboard configuration
  widgets: {
    oee: boolean;
    equipment: boolean;
    downtime: boolean;
    production: boolean;
    andon: boolean;
  };
  
  // Real-time connection
  isConnected: boolean;
  connectionError: string | null;
}

// Initial state
const initialState: DashboardState = {
  oeeData: [],
  equipmentStatus: [],
  downtimeEvents: [],
  productionMetrics: [],
  
  oeeLoading: false,
  equipmentLoading: false,
  downtimeLoading: false,
  productionLoading: false,
  
  oeeError: null,
  equipmentError: null,
  downtimeError: null,
  productionError: null,
  
  selectedLineId: null,
  selectedEquipmentId: null,
  refreshInterval: 30000, // 30 seconds
  autoRefresh: true,
  lastRefresh: null,
  
  widgets: {
    oee: true,
    equipment: true,
    downtime: true,
    production: true,
    andon: true,
  },
  
  isConnected: false,
  connectionError: null,
};

// Async thunks
export const fetchOEEData = createAsyncThunk(
  'dashboard/fetchOEEData',
  async (lineId?: string, { rejectWithValue }) => {
    try {
      const response = await apiService.getOEEData(lineId);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch OEE data');
    }
  }
);

export const fetchEquipmentStatus = createAsyncThunk(
  'dashboard/fetchEquipmentStatus',
  async (lineId?: string, { rejectWithValue }) => {
    try {
      const response = await apiService.getEquipmentStatus(lineId);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch equipment status');
    }
  }
);

export const fetchDowntimeEvents = createAsyncThunk(
  'dashboard/fetchDowntimeEvents',
  async (filters?: { lineId?: string; status?: string }, { rejectWithValue }) => {
    try {
      const response = await apiService.getDowntimeEvents(filters);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch downtime events');
    }
  }
);

export const fetchProductionMetrics = createAsyncThunk(
  'dashboard/fetchProductionMetrics',
  async (lineId?: string, { rejectWithValue }) => {
    try {
      const response = await apiService.getProductionMetrics(lineId);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch production metrics');
    }
  }
);

export const fetchDashboardData = createAsyncThunk(
  'dashboard/fetchDashboardData',
  async (lineId?: string, { rejectWithValue }) => {
    try {
      const [oeeResponse, equipmentResponse, downtimeResponse, productionResponse] = await Promise.all([
        apiService.getOEEData(lineId),
        apiService.getEquipmentStatus(lineId),
        apiService.getDowntimeEvents({ lineId }),
        apiService.getProductionMetrics(lineId),
      ]);
      
      return {
        oeeData: oeeResponse.data,
        equipmentStatus: equipmentResponse.data,
        downtimeEvents: downtimeResponse.data,
        productionMetrics: productionResponse.data,
      };
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch dashboard data');
    }
  }
);

// Slice
const dashboardSlice = createSlice({
  name: 'dashboard',
  initialState,
  reducers: {
    // Clear errors
    clearOEEError: (state) => {
      state.oeeError = null;
    },
    clearEquipmentError: (state) => {
      state.equipmentError = null;
    },
    clearDowntimeError: (state) => {
      state.downtimeError = null;
    },
    clearProductionError: (state) => {
      state.productionError = null;
    },
    clearAllErrors: (state) => {
      state.oeeError = null;
      state.equipmentError = null;
      state.downtimeError = null;
      state.productionError = null;
      state.connectionError = null;
    },
    
    // Set selected items
    setSelectedLineId: (state, action: PayloadAction<string | null>) => {
      state.selectedLineId = action.payload;
    },
    setSelectedEquipmentId: (state, action: PayloadAction<string | null>) => {
      state.selectedEquipmentId = action.payload;
    },
    
    // Dashboard configuration
    setRefreshInterval: (state, action: PayloadAction<number>) => {
      state.refreshInterval = action.payload;
    },
    setAutoRefresh: (state, action: PayloadAction<boolean>) => {
      state.autoRefresh = action.payload;
    },
    setWidgetVisibility: (state, action: PayloadAction<{ widget: keyof DashboardState['widgets']; visible: boolean }>) => {
      const { widget, visible } = action.payload;
      state.widgets[widget] = visible;
    },
    
    // Real-time updates
    updateOEEData: (state, action: PayloadAction<OEEData>) => {
      const newData = action.payload;
      const existingIndex = state.oeeData.findIndex(
        data => data.lineId === newData.lineId && data.equipmentCode === newData.equipmentCode
      );
      
      if (existingIndex !== -1) {
        state.oeeData[existingIndex] = newData;
      } else {
        state.oeeData.push(newData);
      }
    },
    
    updateEquipmentStatus: (state, action: PayloadAction<EquipmentStatus>) => {
      const newStatus = action.payload;
      const existingIndex = state.equipmentStatus.findIndex(
        status => status.id === newStatus.id
      );
      
      if (existingIndex !== -1) {
        state.equipmentStatus[existingIndex] = newStatus;
      } else {
        state.equipmentStatus.push(newStatus);
      }
    },
    
    updateDowntimeEvent: (state, action: PayloadAction<DowntimeEvent>) => {
      const newEvent = action.payload;
      const existingIndex = state.downtimeEvents.findIndex(
        event => event.id === newEvent.id
      );
      
      if (existingIndex !== -1) {
        state.downtimeEvents[existingIndex] = newEvent;
      } else {
        state.downtimeEvents.push(newEvent);
      }
    },
    
    updateProductionMetrics: (state, action: PayloadAction<ProductionMetrics>) => {
      const newMetrics = action.payload;
      const existingIndex = state.productionMetrics.findIndex(
        metrics => metrics.lineId === newMetrics.lineId
      );
      
      if (existingIndex !== -1) {
        state.productionMetrics[existingIndex] = newMetrics;
      } else {
        state.productionMetrics.push(newMetrics);
      }
    },
    
    // Connection status
    setConnectionStatus: (state, action: PayloadAction<{ connected: boolean; error?: string }>) => {
      state.isConnected = action.payload.connected;
      state.connectionError = action.payload.error || null;
    },
    
    // Update last refresh time
    updateLastRefresh: (state) => {
      state.lastRefresh = new Date().toISOString();
    },
    
    // Clear old data
    clearOldData: (state, action: PayloadAction<{ hours: number }>) => {
      const cutoffTime = new Date(Date.now() - action.payload.hours * 60 * 60 * 1000).toISOString();
      
      state.oeeData = state.oeeData.filter(data => data.timestamp > cutoffTime);
      state.downtimeEvents = state.downtimeEvents.filter(event => event.startTime > cutoffTime);
      state.productionMetrics = state.productionMetrics.filter(metrics => metrics.lastUpdate > cutoffTime);
    },
  },
  extraReducers: (builder) => {
    // OEE Data
    builder
      .addCase(fetchOEEData.pending, (state) => {
        state.oeeLoading = true;
        state.oeeError = null;
      })
      .addCase(fetchOEEData.fulfilled, (state, action) => {
        state.oeeLoading = false;
        state.oeeData = action.payload;
        state.lastRefresh = new Date().toISOString();
      })
      .addCase(fetchOEEData.rejected, (state, action) => {
        state.oeeLoading = false;
        state.oeeError = action.payload as string;
      });
    
    // Equipment Status
    builder
      .addCase(fetchEquipmentStatus.pending, (state) => {
        state.equipmentLoading = true;
        state.equipmentError = null;
      })
      .addCase(fetchEquipmentStatus.fulfilled, (state, action) => {
        state.equipmentLoading = false;
        state.equipmentStatus = action.payload;
        state.lastRefresh = new Date().toISOString();
      })
      .addCase(fetchEquipmentStatus.rejected, (state, action) => {
        state.equipmentLoading = false;
        state.equipmentError = action.payload as string;
      });
    
    // Downtime Events
    builder
      .addCase(fetchDowntimeEvents.pending, (state) => {
        state.downtimeLoading = true;
        state.downtimeError = null;
      })
      .addCase(fetchDowntimeEvents.fulfilled, (state, action) => {
        state.downtimeLoading = false;
        state.downtimeEvents = action.payload;
        state.lastRefresh = new Date().toISOString();
      })
      .addCase(fetchDowntimeEvents.rejected, (state, action) => {
        state.downtimeLoading = false;
        state.downtimeError = action.payload as string;
      });
    
    // Production Metrics
    builder
      .addCase(fetchProductionMetrics.pending, (state) => {
        state.productionLoading = true;
        state.productionError = null;
      })
      .addCase(fetchProductionMetrics.fulfilled, (state, action) => {
        state.productionLoading = false;
        state.productionMetrics = action.payload;
        state.lastRefresh = new Date().toISOString();
      })
      .addCase(fetchProductionMetrics.rejected, (state, action) => {
        state.productionLoading = false;
        state.productionError = action.payload as string;
      });
    
    // Dashboard Data (all at once)
    builder
      .addCase(fetchDashboardData.pending, (state) => {
        state.oeeLoading = true;
        state.equipmentLoading = true;
        state.downtimeLoading = true;
        state.productionLoading = true;
        state.oeeError = null;
        state.equipmentError = null;
        state.downtimeError = null;
        state.productionError = null;
      })
      .addCase(fetchDashboardData.fulfilled, (state, action) => {
        state.oeeLoading = false;
        state.equipmentLoading = false;
        state.downtimeLoading = false;
        state.productionLoading = false;
        state.oeeData = action.payload.oeeData;
        state.equipmentStatus = action.payload.equipmentStatus;
        state.downtimeEvents = action.payload.downtimeEvents;
        state.productionMetrics = action.payload.productionMetrics;
        state.lastRefresh = new Date().toISOString();
      })
      .addCase(fetchDashboardData.rejected, (state, action) => {
        state.oeeLoading = false;
        state.equipmentLoading = false;
        state.downtimeLoading = false;
        state.productionLoading = false;
        state.oeeError = action.payload as string;
        state.equipmentError = action.payload as string;
        state.downtimeError = action.payload as string;
        state.productionError = action.payload as string;
      });
  },
});

// Export actions
export const {
  clearOEEError,
  clearEquipmentError,
  clearDowntimeError,
  clearProductionError,
  clearAllErrors,
  setSelectedLineId,
  setSelectedEquipmentId,
  setRefreshInterval,
  setAutoRefresh,
  setWidgetVisibility,
  updateOEEData,
  updateEquipmentStatus,
  updateDowntimeEvent,
  updateProductionMetrics,
  setConnectionStatus,
  updateLastRefresh,
  clearOldData,
} = dashboardSlice.actions;

// Selectors
export const selectOEEData = (state: RootState) => state.dashboard.oeeData;
export const selectEquipmentStatus = (state: RootState) => state.dashboard.equipmentStatus;
export const selectDowntimeEvents = (state: RootState) => state.dashboard.downtimeEvents;
export const selectProductionMetrics = (state: RootState) => state.dashboard.productionMetrics;

export const selectOEELoading = (state: RootState) => state.dashboard.oeeLoading;
export const selectEquipmentLoading = (state: RootState) => state.dashboard.equipmentLoading;
export const selectDowntimeLoading = (state: RootState) => state.dashboard.downtimeLoading;
export const selectProductionLoading = (state: RootState) => state.dashboard.productionLoading;

export const selectOEEError = (state: RootState) => state.dashboard.oeeError;
export const selectEquipmentError = (state: RootState) => state.dashboard.equipmentError;
export const selectDowntimeError = (state: RootState) => state.dashboard.downtimeError;
export const selectProductionError = (state: RootState) => state.dashboard.productionError;

export const selectSelectedLineId = (state: RootState) => state.dashboard.selectedLineId;
export const selectSelectedEquipmentId = (state: RootState) => state.dashboard.selectedEquipmentId;
export const selectRefreshInterval = (state: RootState) => state.dashboard.refreshInterval;
export const selectAutoRefresh = (state: RootState) => state.dashboard.autoRefresh;
export const selectLastRefresh = (state: RootState) => state.dashboard.lastRefresh;

export const selectWidgets = (state: RootState) => state.dashboard.widgets;
export const selectIsConnected = (state: RootState) => state.dashboard.isConnected;
export const selectConnectionError = (state: RootState) => state.dashboard.connectionError;

// Filtered selectors
export const selectOEEDataByLine = (lineId: string) => (state: RootState) =>
  state.dashboard.oeeData.filter(data => data.lineId === lineId);

export const selectEquipmentByLine = (lineId: string) => (state: RootState) =>
  state.dashboard.equipmentStatus.filter(equipment => equipment.lineId === lineId);

export const selectDowntimeByLine = (lineId: string) => (state: RootState) =>
  state.dashboard.downtimeEvents.filter(event => event.lineId === lineId);

export const selectProductionByLine = (lineId: string) => (state: RootState) =>
  state.dashboard.productionMetrics.filter(metrics => metrics.lineId === lineId);

export const selectActiveDowntimeEvents = (state: RootState) =>
  state.dashboard.downtimeEvents.filter(event => event.status === 'active');

export const selectLatestOEEData = (state: RootState) => {
  const data = state.dashboard.oeeData;
  if (data.length === 0) return null;
  
  // Sort by timestamp and return the latest
  return data.sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime())[0];
};

// Export reducer
export default dashboardSlice.reducer;
