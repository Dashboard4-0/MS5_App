/**
 * MS5.0 Floor Dashboard - Equipment Redux Slice
 * 
 * This slice manages equipment-related state including equipment status,
 * maintenance schedules, and equipment management operations.
 */

import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit';
import { RootState } from '../index';
import { apiService } from '../../services/api';

// Types
interface Equipment {
  id: string;
  code: string;
  name: string;
  description?: string;
  type: string;
  lineId: string;
  status: 'running' | 'stopped' | 'fault' | 'maintenance' | 'setup' | 'idle';
  speed: number;
  targetSpeed: number;
  efficiency: number;
  lastUpdate: string;
  location?: string;
  manufacturer?: string;
  model?: string;
  serialNumber?: string;
  installationDate?: string;
  warrantyExpiry?: string;
  criticalityLevel: number;
  enabled: boolean;
}

interface MaintenanceSchedule {
  id: string;
  equipmentId: string;
  equipmentCode: string;
  maintenanceType: 'preventive' | 'corrective' | 'predictive' | 'emergency';
  description: string;
  scheduledDate: string;
  completedDate?: string;
  assignedTo?: string;
  status: 'scheduled' | 'in_progress' | 'completed' | 'cancelled' | 'overdue';
  priority: 'low' | 'medium' | 'high' | 'critical';
  estimatedDuration: number;
  actualDuration?: number;
  notes?: string;
  partsRequired?: string[];
  toolsRequired?: string[];
}

interface EquipmentFault {
  id: string;
  equipmentId: string;
  equipmentCode: string;
  faultCode: string;
  description: string;
  severity: 'low' | 'medium' | 'high' | 'critical';
  status: 'active' | 'acknowledged' | 'resolved';
  detectedAt: string;
  acknowledgedAt?: string;
  resolvedAt?: string;
  acknowledgedBy?: string;
  resolvedBy?: string;
  resolutionNotes?: string;
  impact: string;
  category: string;
}

interface EquipmentState {
  // Equipment
  equipment: Equipment[];
  currentEquipment: Equipment | null;
  equipmentLoading: boolean;
  equipmentError: string | null;
  
  // Maintenance
  maintenanceSchedules: MaintenanceSchedule[];
  currentMaintenance: MaintenanceSchedule | null;
  maintenanceLoading: boolean;
  maintenanceError: string | null;
  
  // Faults
  faults: EquipmentFault[];
  currentFault: EquipmentFault | null;
  faultsLoading: boolean;
  faultsError: string | null;
  
  // UI State
  selectedEquipmentId: string | null;
  selectedLineId: string | null;
  equipmentFilters: {
    status?: string;
    type?: string;
    lineId?: string;
    criticalityLevel?: number;
  };
  
  // Action states
  actionLoading: boolean;
  actionError: string | null;
}

// Initial state
const initialState: EquipmentState = {
  equipment: [],
  currentEquipment: null,
  equipmentLoading: false,
  equipmentError: null,
  
  maintenanceSchedules: [],
  currentMaintenance: null,
  maintenanceLoading: false,
  maintenanceError: null,
  
  faults: [],
  currentFault: null,
  faultsLoading: false,
  faultsError: null,
  
  selectedEquipmentId: null,
  selectedLineId: null,
  equipmentFilters: {},
  
  actionLoading: false,
  actionError: null,
};

// Async thunks
export const fetchEquipment = createAsyncThunk(
  'equipment/fetchEquipment',
  async (filters?: { status?: string; type?: string; lineId?: string; criticalityLevel?: number }, { rejectWithValue }) => {
    try {
      const response = await apiService.getEquipment(filters);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch equipment');
    }
  }
);

export const fetchEquipmentById = createAsyncThunk(
  'equipment/fetchEquipmentById',
  async (equipmentId: string, { rejectWithValue }) => {
    try {
      const response = await apiService.getEquipmentById(equipmentId);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch equipment');
    }
  }
);

export const updateEquipment = createAsyncThunk(
  'equipment/updateEquipment',
  async ({ equipmentId, updateData }: { equipmentId: string; updateData: Partial<Equipment> }, { rejectWithValue }) => {
    try {
      const response = await apiService.updateEquipment(equipmentId, updateData);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to update equipment');
    }
  }
);

export const fetchMaintenanceSchedules = createAsyncThunk(
  'equipment/fetchMaintenanceSchedules',
  async (filters?: { equipmentId?: string; status?: string; priority?: string }, { rejectWithValue }) => {
    try {
      const response = await apiService.getMaintenanceSchedules(filters);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch maintenance schedules');
    }
  }
);

export const fetchMaintenanceSchedule = createAsyncThunk(
  'equipment/fetchMaintenanceSchedule',
  async (scheduleId: string, { rejectWithValue }) => {
    try {
      const response = await apiService.getMaintenanceSchedule(scheduleId);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch maintenance schedule');
    }
  }
);

export const createMaintenanceSchedule = createAsyncThunk(
  'equipment/createMaintenanceSchedule',
  async (scheduleData: Partial<MaintenanceSchedule>, { rejectWithValue }) => {
    try {
      const response = await apiService.createMaintenanceSchedule(scheduleData);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to create maintenance schedule');
    }
  }
);

export const updateMaintenanceSchedule = createAsyncThunk(
  'equipment/updateMaintenanceSchedule',
  async ({ scheduleId, updateData }: { scheduleId: string; updateData: Partial<MaintenanceSchedule> }, { rejectWithValue }) => {
    try {
      const response = await apiService.updateMaintenanceSchedule(scheduleId, updateData);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to update maintenance schedule');
    }
  }
);

export const completeMaintenance = createAsyncThunk(
  'equipment/completeMaintenance',
  async ({ scheduleId, actualDuration, notes }: { scheduleId: string; actualDuration: number; notes?: string }, { rejectWithValue }) => {
    try {
      const response = await apiService.completeMaintenance(scheduleId, actualDuration, notes);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to complete maintenance');
    }
  }
);

export const fetchEquipmentFaults = createAsyncThunk(
  'equipment/fetchFaults',
  async (filters?: { equipmentId?: string; status?: string; severity?: string }, { rejectWithValue }) => {
    try {
      const response = await apiService.getEquipmentFaults(filters);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch equipment faults');
    }
  }
);

export const fetchEquipmentFault = createAsyncThunk(
  'equipment/fetchFault',
  async (faultId: string, { rejectWithValue }) => {
    try {
      const response = await apiService.getEquipmentFault(faultId);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch equipment fault');
    }
  }
);

export const acknowledgeFault = createAsyncThunk(
  'equipment/acknowledgeFault',
  async (faultId: string, { rejectWithValue }) => {
    try {
      const response = await apiService.acknowledgeFault(faultId);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to acknowledge fault');
    }
  }
);

export const resolveFault = createAsyncThunk(
  'equipment/resolveFault',
  async ({ faultId, resolutionNotes }: { faultId: string; resolutionNotes: string }, { rejectWithValue }) => {
    try {
      const response = await apiService.resolveFault(faultId, resolutionNotes);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to resolve fault');
    }
  }
);

// Slice
const equipmentSlice = createSlice({
  name: 'equipment',
  initialState,
  reducers: {
    // Clear errors
    clearEquipmentError: (state) => {
      state.equipmentError = null;
    },
    clearMaintenanceError: (state) => {
      state.maintenanceError = null;
    },
    clearFaultsError: (state) => {
      state.faultsError = null;
    },
    clearActionError: (state) => {
      state.actionError = null;
    },
    clearAllErrors: (state) => {
      state.equipmentError = null;
      state.maintenanceError = null;
      state.faultsError = null;
      state.actionError = null;
    },
    
    // Set selected items
    setSelectedEquipmentId: (state, action: PayloadAction<string | null>) => {
      state.selectedEquipmentId = action.payload;
    },
    setSelectedLineId: (state, action: PayloadAction<string | null>) => {
      state.selectedLineId = action.payload;
    },
    
    // Set filters
    setEquipmentFilters: (state, action: PayloadAction<Partial<EquipmentState['equipmentFilters']>>) => {
      state.equipmentFilters = { ...state.equipmentFilters, ...action.payload };
    },
    clearEquipmentFilters: (state) => {
      state.equipmentFilters = {};
    },
    
    // Real-time updates
    updateEquipmentStatus: (state, action: PayloadAction<{ equipmentId: string; status: Equipment['status']; speed?: number; efficiency?: number }>) => {
      const { equipmentId, status, speed, efficiency } = action.payload;
      const equipment = state.equipment.find(eq => eq.id === equipmentId);
      
      if (equipment) {
        equipment.status = status;
        if (speed !== undefined) equipment.speed = speed;
        if (efficiency !== undefined) equipment.efficiency = efficiency;
        equipment.lastUpdate = new Date().toISOString();
      }
      
      if (state.currentEquipment?.id === equipmentId) {
        state.currentEquipment.status = status;
        if (speed !== undefined) state.currentEquipment.speed = speed;
        if (efficiency !== undefined) state.currentEquipment.efficiency = efficiency;
        state.currentEquipment.lastUpdate = new Date().toISOString();
      }
    },
    
    addEquipmentFault: (state, action: PayloadAction<EquipmentFault>) => {
      const fault = action.payload;
      const existingIndex = state.faults.findIndex(f => f.id === fault.id);
      
      if (existingIndex !== -1) {
        state.faults[existingIndex] = fault;
      } else {
        state.faults.unshift(fault);
      }
    },
    
    updateEquipmentFault: (state, action: PayloadAction<EquipmentFault>) => {
      const fault = action.payload;
      const existingIndex = state.faults.findIndex(f => f.id === fault.id);
      
      if (existingIndex !== -1) {
        state.faults[existingIndex] = fault;
      }
      
      if (state.currentFault?.id === fault.id) {
        state.currentFault = fault;
      }
    },
    
    addMaintenanceSchedule: (state, action: PayloadAction<MaintenanceSchedule>) => {
      const schedule = action.payload;
      const existingIndex = state.maintenanceSchedules.findIndex(s => s.id === schedule.id);
      
      if (existingIndex !== -1) {
        state.maintenanceSchedules[existingIndex] = schedule;
      } else {
        state.maintenanceSchedules.push(schedule);
      }
    },
    
    updateMaintenanceSchedule: (state, action: PayloadAction<MaintenanceSchedule>) => {
      const schedule = action.payload;
      const existingIndex = state.maintenanceSchedules.findIndex(s => s.id === schedule.id);
      
      if (existingIndex !== -1) {
        state.maintenanceSchedules[existingIndex] = schedule;
      }
      
      if (state.currentMaintenance?.id === schedule.id) {
        state.currentMaintenance = schedule;
      }
    },
  },
  extraReducers: (builder) => {
    // Equipment
    builder
      .addCase(fetchEquipment.pending, (state) => {
        state.equipmentLoading = true;
        state.equipmentError = null;
      })
      .addCase(fetchEquipment.fulfilled, (state, action) => {
        state.equipmentLoading = false;
        state.equipment = action.payload;
      })
      .addCase(fetchEquipment.rejected, (state, action) => {
        state.equipmentLoading = false;
        state.equipmentError = action.payload as string;
      })
      
      .addCase(fetchEquipmentById.pending, (state) => {
        state.equipmentLoading = true;
        state.equipmentError = null;
      })
      .addCase(fetchEquipmentById.fulfilled, (state, action) => {
        state.equipmentLoading = false;
        state.currentEquipment = action.payload;
      })
      .addCase(fetchEquipmentById.rejected, (state, action) => {
        state.equipmentLoading = false;
        state.equipmentError = action.payload as string;
      })
      
      .addCase(updateEquipment.fulfilled, (state, action) => {
        const equipment = action.payload;
        const index = state.equipment.findIndex(eq => eq.id === equipment.id);
        if (index !== -1) {
          state.equipment[index] = equipment;
        }
        if (state.currentEquipment?.id === equipment.id) {
          state.currentEquipment = equipment;
        }
      });
    
    // Maintenance Schedules
    builder
      .addCase(fetchMaintenanceSchedules.pending, (state) => {
        state.maintenanceLoading = true;
        state.maintenanceError = null;
      })
      .addCase(fetchMaintenanceSchedules.fulfilled, (state, action) => {
        state.maintenanceLoading = false;
        state.maintenanceSchedules = action.payload;
      })
      .addCase(fetchMaintenanceSchedules.rejected, (state, action) => {
        state.maintenanceLoading = false;
        state.maintenanceError = action.payload as string;
      })
      
      .addCase(fetchMaintenanceSchedule.pending, (state) => {
        state.maintenanceLoading = true;
        state.maintenanceError = null;
      })
      .addCase(fetchMaintenanceSchedule.fulfilled, (state, action) => {
        state.maintenanceLoading = false;
        state.currentMaintenance = action.payload;
      })
      .addCase(fetchMaintenanceSchedule.rejected, (state, action) => {
        state.maintenanceLoading = false;
        state.maintenanceError = action.payload as string;
      })
      
      .addCase(createMaintenanceSchedule.fulfilled, (state, action) => {
        state.maintenanceSchedules.push(action.payload);
      })
      
      .addCase(updateMaintenanceSchedule.fulfilled, (state, action) => {
        const schedule = action.payload;
        const index = state.maintenanceSchedules.findIndex(s => s.id === schedule.id);
        if (index !== -1) {
          state.maintenanceSchedules[index] = schedule;
        }
        if (state.currentMaintenance?.id === schedule.id) {
          state.currentMaintenance = schedule;
        }
      })
      
      .addCase(completeMaintenance.pending, (state) => {
        state.actionLoading = true;
        state.actionError = null;
      })
      .addCase(completeMaintenance.fulfilled, (state, action) => {
        state.actionLoading = false;
        const schedule = action.payload;
        const index = state.maintenanceSchedules.findIndex(s => s.id === schedule.id);
        if (index !== -1) {
          state.maintenanceSchedules[index] = schedule;
        }
        if (state.currentMaintenance?.id === schedule.id) {
          state.currentMaintenance = schedule;
        }
      })
      .addCase(completeMaintenance.rejected, (state, action) => {
        state.actionLoading = false;
        state.actionError = action.payload as string;
      });
    
    // Equipment Faults
    builder
      .addCase(fetchEquipmentFaults.pending, (state) => {
        state.faultsLoading = true;
        state.faultsError = null;
      })
      .addCase(fetchEquipmentFaults.fulfilled, (state, action) => {
        state.faultsLoading = false;
        state.faults = action.payload;
      })
      .addCase(fetchEquipmentFaults.rejected, (state, action) => {
        state.faultsLoading = false;
        state.faultsError = action.payload as string;
      })
      
      .addCase(fetchEquipmentFault.pending, (state) => {
        state.faultsLoading = true;
        state.faultsError = null;
      })
      .addCase(fetchEquipmentFault.fulfilled, (state, action) => {
        state.faultsLoading = false;
        state.currentFault = action.payload;
      })
      .addCase(fetchEquipmentFault.rejected, (state, action) => {
        state.faultsLoading = false;
        state.faultsError = action.payload as string;
      })
      
      .addCase(acknowledgeFault.pending, (state) => {
        state.actionLoading = true;
        state.actionError = null;
      })
      .addCase(acknowledgeFault.fulfilled, (state, action) => {
        state.actionLoading = false;
        const fault = action.payload;
        const index = state.faults.findIndex(f => f.id === fault.id);
        if (index !== -1) {
          state.faults[index] = fault;
        }
        if (state.currentFault?.id === fault.id) {
          state.currentFault = fault;
        }
      })
      .addCase(acknowledgeFault.rejected, (state, action) => {
        state.actionLoading = false;
        state.actionError = action.payload as string;
      })
      
      .addCase(resolveFault.pending, (state) => {
        state.actionLoading = true;
        state.actionError = null;
      })
      .addCase(resolveFault.fulfilled, (state, action) => {
        state.actionLoading = false;
        const fault = action.payload;
        const index = state.faults.findIndex(f => f.id === fault.id);
        if (index !== -1) {
          state.faults[index] = fault;
        }
        if (state.currentFault?.id === fault.id) {
          state.currentFault = fault;
        }
      })
      .addCase(resolveFault.rejected, (state, action) => {
        state.actionLoading = false;
        state.actionError = action.payload as string;
      });
  },
});

// Export actions
export const {
  clearEquipmentError,
  clearMaintenanceError,
  clearFaultsError,
  clearActionError,
  clearAllErrors,
  setSelectedEquipmentId,
  setSelectedLineId,
  setEquipmentFilters,
  clearEquipmentFilters,
  updateEquipmentStatus,
  addEquipmentFault,
  updateEquipmentFault,
  addMaintenanceSchedule,
  updateMaintenanceSchedule,
} = equipmentSlice.actions;

// Selectors
export const selectEquipment = (state: RootState) => state.equipment.equipment;
export const selectCurrentEquipment = (state: RootState) => state.equipment.currentEquipment;
export const selectEquipmentLoading = (state: RootState) => state.equipment.equipmentLoading;
export const selectEquipmentError = (state: RootState) => state.equipment.equipmentError;

export const selectMaintenanceSchedules = (state: RootState) => state.equipment.maintenanceSchedules;
export const selectCurrentMaintenance = (state: RootState) => state.equipment.currentMaintenance;
export const selectMaintenanceLoading = (state: RootState) => state.equipment.maintenanceLoading;
export const selectMaintenanceError = (state: RootState) => state.equipment.maintenanceError;

export const selectFaults = (state: RootState) => state.equipment.faults;
export const selectCurrentFault = (state: RootState) => state.equipment.currentFault;
export const selectFaultsLoading = (state: RootState) => state.equipment.faultsLoading;
export const selectFaultsError = (state: RootState) => state.equipment.faultsError;

export const selectSelectedEquipmentId = (state: RootState) => state.equipment.selectedEquipmentId;
export const selectSelectedLineId = (state: RootState) => state.equipment.selectedLineId;
export const selectEquipmentFilters = (state: RootState) => state.equipment.equipmentFilters;

export const selectActionLoading = (state: RootState) => state.equipment.actionLoading;
export const selectActionError = (state: RootState) => state.equipment.actionError;

// Filtered selectors
export const selectEquipmentByLine = (lineId: string) => (state: RootState) =>
  state.equipment.equipment.filter(eq => eq.lineId === lineId);

export const selectEquipmentByStatus = (status: string) => (state: RootState) =>
  state.equipment.equipment.filter(eq => eq.status === status);

export const selectEquipmentByType = (type: string) => (state: RootState) =>
  state.equipment.equipment.filter(eq => eq.type === type);

export const selectMaintenanceByEquipment = (equipmentId: string) => (state: RootState) =>
  state.equipment.maintenanceSchedules.filter(schedule => schedule.equipmentId === equipmentId);

export const selectFaultsByEquipment = (equipmentId: string) => (state: RootState) =>
  state.equipment.faults.filter(fault => fault.equipmentId === equipmentId);

export const selectActiveFaults = (state: RootState) =>
  state.equipment.faults.filter(fault => fault.status === 'active');

export const selectCriticalFaults = (state: RootState) =>
  state.equipment.faults.filter(fault => fault.severity === 'critical' && fault.status !== 'resolved');

export const selectOverdueMaintenance = (state: RootState) =>
  state.equipment.maintenanceSchedules.filter(schedule => 
    schedule.status === 'scheduled' && 
    new Date(schedule.scheduledDate) < new Date()
  );

// Computed selectors
export const selectEquipmentEfficiency = (state: RootState) => {
  const equipment = state.equipment.equipment;
  if (equipment.length === 0) return 0;
  
  const totalEfficiency = equipment.reduce((sum, eq) => sum + eq.efficiency, 0);
  return totalEfficiency / equipment.length;
};

export const selectRunningEquipment = (state: RootState) =>
  state.equipment.equipment.filter(eq => eq.status === 'running');

export const selectFaultyEquipment = (state: RootState) =>
  state.equipment.equipment.filter(eq => eq.status === 'fault');

export const selectMaintenanceEquipment = (state: RootState) =>
  state.equipment.equipment.filter(eq => eq.status === 'maintenance');

// Export reducer
export default equipmentSlice.reducer;
