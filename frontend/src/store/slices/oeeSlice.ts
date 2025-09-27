/**
 * MS5.0 Floor Dashboard - OEE Redux Slice
 * 
 * This slice manages OEE-related state including OEE calculations,
 * analytics, and historical data.
 */

import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit';
import { RootState } from '../index';
import { apiService } from '../../services/api';

// Types
interface OEECalculation {
  id: string;
  lineId: string;
  equipmentCode: string;
  calculationTime: string;
  availability: number;
  performance: number;
  quality: number;
  oee: number;
  plannedProductionTime: number;
  actualProductionTime: number;
  idealCycleTime: number;
  actualCycleTime: number;
  goodParts: number;
  totalParts: number;
}

interface OEEMetrics {
  lineId: string;
  equipmentCode: string;
  oee: number;
  availability: number;
  performance: number;
  quality: number;
  targetOEE: number;
  targetAvailability: number;
  targetPerformance: number;
  targetQuality: number;
  timestamp: string;
}

interface OEETrend {
  period: string;
  oee: number;
  availability: number;
  performance: number;
  quality: number;
  production: number;
  downtime: number;
}

interface OEELoss {
  category: string;
  description: string;
  duration: number;
  percentage: number;
  impact: 'high' | 'medium' | 'low';
}

interface OEEState {
  // Current OEE data
  currentOEE: OEEMetrics[];
  oeeCalculations: OEECalculation[];
  oeeTrends: OEETrend[];
  oeeLosses: OEELoss[];
  
  // Loading states
  oeeLoading: boolean;
  calculationsLoading: boolean;
  trendsLoading: boolean;
  lossesLoading: boolean;
  
  // Error states
  oeeError: string | null;
  calculationsError: string | null;
  trendsError: string | null;
  lossesError: string | null;
  
  // UI State
  selectedLineId: string | null;
  selectedEquipmentId: string | null;
  timeRange: {
    start: string;
    end: string;
  };
  aggregationLevel: 'hour' | 'day' | 'week' | 'month';
  
  // Filters
  filters: {
    lineId?: string;
    equipmentCode?: string;
    timeRange?: {
      start: string;
      end: string;
    };
  };
}

// Initial state
const initialState: OEEState = {
  currentOEE: [],
  oeeCalculations: [],
  oeeTrends: [],
  oeeLosses: [],
  
  oeeLoading: false,
  calculationsLoading: false,
  trendsLoading: false,
  lossesLoading: false,
  
  oeeError: null,
  calculationsError: null,
  trendsError: null,
  lossesError: null,
  
  selectedLineId: null,
  selectedEquipmentId: null,
  timeRange: {
    start: new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString(), // 24 hours ago
    end: new Date().toISOString(),
  },
  aggregationLevel: 'hour',
  
  filters: {},
};

// Async thunks
export const fetchCurrentOEE = createAsyncThunk(
  'oee/fetchCurrent',
  async (lineId?: string, { rejectWithValue }) => {
    try {
      const response = await apiService.getCurrentOEE(lineId);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch current OEE');
    }
  }
);

export const fetchOEECalculations = createAsyncThunk(
  'oee/fetchCalculations',
  async (filters?: { lineId?: string; equipmentCode?: string; startTime?: string; endTime?: string }, { rejectWithValue }) => {
    try {
      const response = await apiService.getOEECalculations(filters);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch OEE calculations');
    }
  }
);

export const fetchOEETrends = createAsyncThunk(
  'oee/fetchTrends',
  async (filters?: { lineId?: string; equipmentCode?: string; startTime?: string; endTime?: string; aggregationLevel?: string }, { rejectWithValue }) => {
    try {
      const response = await apiService.getOEETrends(filters);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch OEE trends');
    }
  }
);

export const fetchOEELosses = createAsyncThunk(
  'oee/fetchLosses',
  async (filters?: { lineId?: string; equipmentCode?: string; startTime?: string; endTime?: string }, { rejectWithValue }) => {
    try {
      const response = await apiService.getOEELosses(filters);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch OEE losses');
    }
  }
);

export const calculateOEE = createAsyncThunk(
  'oee/calculate',
  async (params: { lineId: string; equipmentCode?: string; startTime: string; endTime: string }, { rejectWithValue }) => {
    try {
      const response = await apiService.calculateOEE(params);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to calculate OEE');
    }
  }
);

export const fetchOEEAnalytics = createAsyncThunk(
  'oee/fetchAnalytics',
  async (filters?: { lineId?: string; equipmentCode?: string; startTime?: string; endTime?: string }, { rejectWithValue }) => {
    try {
      const response = await apiService.getOEEAnalytics(filters);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch OEE analytics');
    }
  }
);

// Slice
const oeeSlice = createSlice({
  name: 'oee',
  initialState,
  reducers: {
    // Clear errors
    clearOEEError: (state) => {
      state.oeeError = null;
    },
    clearCalculationsError: (state) => {
      state.calculationsError = null;
    },
    clearTrendsError: (state) => {
      state.trendsError = null;
    },
    clearLossesError: (state) => {
      state.lossesError = null;
    },
    clearAllErrors: (state) => {
      state.oeeError = null;
      state.calculationsError = null;
      state.trendsError = null;
      state.lossesError = null;
    },
    
    // Set selected items
    setSelectedLineId: (state, action: PayloadAction<string | null>) => {
      state.selectedLineId = action.payload;
    },
    setSelectedEquipmentId: (state, action: PayloadAction<string | null>) => {
      state.selectedEquipmentId = action.payload;
    },
    
    // Set time range
    setTimeRange: (state, action: PayloadAction<{ start: string; end: string }>) => {
      state.timeRange = action.payload;
    },
    
    // Set aggregation level
    setAggregationLevel: (state, action: PayloadAction<'hour' | 'day' | 'week' | 'month'>) => {
      state.aggregationLevel = action.payload;
    },
    
    // Set filters
    setFilters: (state, action: PayloadAction<Partial<OEEState['filters']>>) => {
      state.filters = { ...state.filters, ...action.payload };
    },
    clearFilters: (state) => {
      state.filters = {};
    },
    
    // Real-time updates
    updateCurrentOEE: (state, action: PayloadAction<OEEMetrics>) => {
      const newOEE = action.payload;
      const existingIndex = state.currentOEE.findIndex(
        oee => oee.lineId === newOEE.lineId && oee.equipmentCode === newOEE.equipmentCode
      );
      
      if (existingIndex !== -1) {
        state.currentOEE[existingIndex] = newOEE;
      } else {
        state.currentOEE.push(newOEE);
      }
    },
    
    addOEECalculation: (state, action: PayloadAction<OEECalculation>) => {
      const calculation = action.payload;
      const existingIndex = state.oeeCalculations.findIndex(
        calc => calc.id === calculation.id
      );
      
      if (existingIndex !== -1) {
        state.oeeCalculations[existingIndex] = calculation;
      } else {
        state.oeeCalculations.push(calculation);
      }
    },
    
    updateOEETrends: (state, action: PayloadAction<OEETrend[]>) => {
      state.oeeTrends = action.payload;
    },
    
    updateOEELosses: (state, action: PayloadAction<OEELoss[]>) => {
      state.oeeLosses = action.payload;
    },
  },
  extraReducers: (builder) => {
    // Current OEE
    builder
      .addCase(fetchCurrentOEE.pending, (state) => {
        state.oeeLoading = true;
        state.oeeError = null;
      })
      .addCase(fetchCurrentOEE.fulfilled, (state, action) => {
        state.oeeLoading = false;
        state.currentOEE = action.payload;
      })
      .addCase(fetchCurrentOEE.rejected, (state, action) => {
        state.oeeLoading = false;
        state.oeeError = action.payload as string;
      });
    
    // OEE Calculations
    builder
      .addCase(fetchOEECalculations.pending, (state) => {
        state.calculationsLoading = true;
        state.calculationsError = null;
      })
      .addCase(fetchOEECalculations.fulfilled, (state, action) => {
        state.calculationsLoading = false;
        state.oeeCalculations = action.payload;
      })
      .addCase(fetchOEECalculations.rejected, (state, action) => {
        state.calculationsLoading = false;
        state.calculationsError = action.payload as string;
      });
    
    // OEE Trends
    builder
      .addCase(fetchOEETrends.pending, (state) => {
        state.trendsLoading = true;
        state.trendsError = null;
      })
      .addCase(fetchOEETrends.fulfilled, (state, action) => {
        state.trendsLoading = false;
        state.oeeTrends = action.payload;
      })
      .addCase(fetchOEETrends.rejected, (state, action) => {
        state.trendsLoading = false;
        state.trendsError = action.payload as string;
      });
    
    // OEE Losses
    builder
      .addCase(fetchOEELosses.pending, (state) => {
        state.lossesLoading = true;
        state.lossesError = null;
      })
      .addCase(fetchOEELosses.fulfilled, (state, action) => {
        state.lossesLoading = false;
        state.oeeLosses = action.payload;
      })
      .addCase(fetchOEELosses.rejected, (state, action) => {
        state.lossesLoading = false;
        state.lossesError = action.payload as string;
      });
    
    // Calculate OEE
    builder
      .addCase(calculateOEE.pending, (state) => {
        state.calculationsLoading = true;
        state.calculationsError = null;
      })
      .addCase(calculateOEE.fulfilled, (state, action) => {
        state.calculationsLoading = false;
        state.oeeCalculations = action.payload;
      })
      .addCase(calculateOEE.rejected, (state, action) => {
        state.calculationsLoading = false;
        state.calculationsError = action.payload as string;
      });
    
    // OEE Analytics
    builder
      .addCase(fetchOEEAnalytics.pending, (state) => {
        state.oeeLoading = true;
        state.trendsLoading = true;
        state.lossesLoading = true;
        state.oeeError = null;
        state.trendsError = null;
        state.lossesError = null;
      })
      .addCase(fetchOEEAnalytics.fulfilled, (state, action) => {
        state.oeeLoading = false;
        state.trendsLoading = false;
        state.lossesLoading = false;
        state.currentOEE = action.payload.currentOEE || state.currentOEE;
        state.oeeTrends = action.payload.trends || state.oeeTrends;
        state.oeeLosses = action.payload.losses || state.oeeLosses;
      })
      .addCase(fetchOEEAnalytics.rejected, (state, action) => {
        state.oeeLoading = false;
        state.trendsLoading = false;
        state.lossesLoading = false;
        state.oeeError = action.payload as string;
        state.trendsError = action.payload as string;
        state.lossesError = action.payload as string;
      });
  },
});

// Export actions
export const {
  clearOEEError,
  clearCalculationsError,
  clearTrendsError,
  clearLossesError,
  clearAllErrors,
  setSelectedLineId,
  setSelectedEquipmentId,
  setTimeRange,
  setAggregationLevel,
  setFilters,
  clearFilters,
  updateCurrentOEE,
  addOEECalculation,
  updateOEETrends,
  updateOEELosses,
} = oeeSlice.actions;

// Selectors
export const selectCurrentOEE = (state: RootState) => state.oee.currentOEE;
export const selectOEECalculations = (state: RootState) => state.oee.oeeCalculations;
export const selectOEETrends = (state: RootState) => state.oee.oeeTrends;
export const selectOEELosses = (state: RootState) => state.oee.oeeLosses;

export const selectOEELoading = (state: RootState) => state.oee.oeeLoading;
export const selectCalculationsLoading = (state: RootState) => state.oee.calculationsLoading;
export const selectTrendsLoading = (state: RootState) => state.oee.trendsLoading;
export const selectLossesLoading = (state: RootState) => state.oee.lossesLoading;

export const selectOEEError = (state: RootState) => state.oee.oeeError;
export const selectCalculationsError = (state: RootState) => state.oee.calculationsError;
export const selectTrendsError = (state: RootState) => state.oee.trendsError;
export const selectLossesError = (state: RootState) => state.oee.lossesError;

export const selectSelectedLineId = (state: RootState) => state.oee.selectedLineId;
export const selectSelectedEquipmentId = (state: RootState) => state.oee.selectedEquipmentId;
export const selectTimeRange = (state: RootState) => state.oee.timeRange;
export const selectAggregationLevel = (state: RootState) => state.oee.aggregationLevel;
export const selectFilters = (state: RootState) => state.oee.filters;

// Filtered selectors
export const selectOEEByLine = (lineId: string) => (state: RootState) =>
  state.oee.currentOEE.filter(oee => oee.lineId === lineId);

export const selectOEEByEquipment = (equipmentCode: string) => (state: RootState) =>
  state.oee.currentOEE.filter(oee => oee.equipmentCode === equipmentCode);

export const selectCalculationsByLine = (lineId: string) => (state: RootState) =>
  state.oee.oeeCalculations.filter(calc => calc.lineId === lineId);

export const selectCalculationsByEquipment = (equipmentCode: string) => (state: RootState) =>
  state.oee.oeeCalculations.filter(calc => calc.equipmentCode === equipmentCode);

export const selectTrendsByLine = (lineId: string) => (state: RootState) =>
  state.oee.oeeTrends.filter(trend => trend.lineId === lineId);

export const selectLossesByLine = (lineId: string) => (state: RootState) =>
  state.oee.oeeLosses.filter(loss => loss.lineId === lineId);

// Computed selectors
export const selectAverageOEE = (state: RootState) => {
  const oeeData = state.oee.currentOEE;
  if (oeeData.length === 0) return 0;
  
  const totalOEE = oeeData.reduce((sum, oee) => sum + oee.oee, 0);
  return totalOEE / oeeData.length;
};

export const selectAverageAvailability = (state: RootState) => {
  const oeeData = state.oee.currentOEE;
  if (oeeData.length === 0) return 0;
  
  const totalAvailability = oeeData.reduce((sum, oee) => sum + oee.availability, 0);
  return totalAvailability / oeeData.length;
};

export const selectAveragePerformance = (state: RootState) => {
  const oeeData = state.oee.currentOEE;
  if (oeeData.length === 0) return 0;
  
  const totalPerformance = oeeData.reduce((sum, oee) => sum + oee.performance, 0);
  return totalPerformance / oeeData.length;
};

export const selectAverageQuality = (state: RootState) => {
  const oeeData = state.oee.currentOEE;
  if (oeeData.length === 0) return 0;
  
  const totalQuality = oeeData.reduce((sum, oee) => sum + oee.quality, 0);
  return totalQuality / oeeData.length;
};

export const selectOEEStatus = (oee: number) => {
  if (oee >= 0.85) return 'excellent';
  if (oee >= 0.70) return 'good';
  if (oee >= 0.50) return 'fair';
  return 'poor';
};

// Export reducer
export default oeeSlice.reducer;
