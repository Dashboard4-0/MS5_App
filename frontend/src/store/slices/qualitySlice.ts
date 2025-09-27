/**
 * MS5.0 Floor Dashboard - Quality Redux Slice
 * 
 * This slice manages quality-related state including quality checks,
 * inspections, defects, and quality management operations.
 */

import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit';
import { RootState } from '../index';
import { apiService } from '../../services/api';

// Types
interface QualityCheck {
  id: string;
  lineId: string;
  equipmentCode: string;
  productTypeId: string;
  checkType: 'incoming' | 'in_process' | 'final' | 'random' | 'audit';
  checkName: string;
  description: string;
  parameters: QualityParameter[];
  frequency: {
    type: 'continuous' | 'periodic' | 'sample' | 'batch';
    interval?: number; // minutes for periodic, count for sample/batch
    sampleSize?: number; // for sample type
  };
  criteria: QualityCriteria;
  isActive: boolean;
  createdBy: string;
  createdAt: string;
  updatedAt: string;
}

interface QualityParameter {
  name: string;
  type: 'numeric' | 'boolean' | 'text' | 'select' | 'multiselect';
  label: string;
  unit?: string;
  required: boolean;
  defaultValue?: any;
  options?: string[];
  validation?: {
    min?: number;
    max?: number;
    pattern?: string;
    custom?: string;
  };
}

interface QualityCriteria {
  passCondition: 'all' | 'any' | 'custom';
  rules: QualityRule[];
  customExpression?: string;
}

interface QualityRule {
  parameter: string;
  operator: 'eq' | 'ne' | 'gt' | 'gte' | 'lt' | 'lte' | 'in' | 'nin' | 'contains' | 'regex';
  value: any;
  weight?: number; // for weighted scoring
}

interface QualityInspection {
  id: string;
  checkId: string;
  checkName: string;
  lineId: string;
  equipmentCode: string;
  productTypeId: string;
  batchId?: string;
  orderId?: string;
  inspectorId: string;
  inspectorName: string;
  inspectedAt: string;
  status: 'pending' | 'in_progress' | 'completed' | 'failed' | 'cancelled';
  results: QualityResult[];
  overallResult: 'pass' | 'fail' | 'conditional' | 'pending';
  score?: number;
  maxScore?: number;
  notes?: string;
  images?: string[];
  approvedBy?: string;
  approvedAt?: string;
  rejectedBy?: string;
  rejectedAt?: string;
  rejectionReason?: string;
}

interface QualityResult {
  parameter: string;
  parameterLabel: string;
  value: any;
  unit?: string;
  expectedValue?: any;
  tolerance?: {
    min?: number;
    max?: number;
    range?: string;
  };
  result: 'pass' | 'fail' | 'warning' | 'pending';
  score?: number;
  maxScore?: number;
  notes?: string;
}

interface QualityDefect {
  id: string;
  inspectionId?: string;
  lineId: string;
  equipmentCode: string;
  productTypeId: string;
  defectType: string;
  defectCategory: 'dimensional' | 'surface' | 'functional' | 'aesthetic' | 'safety' | 'other';
  severity: 'minor' | 'major' | 'critical' | 'cosmetic';
  description: string;
  location: string;
  quantity: number;
  detectedBy: string;
  detectedAt: string;
  status: 'open' | 'investigating' | 'resolved' | 'closed';
  rootCause?: string;
  correctiveAction?: string;
  preventiveAction?: string;
  assignedTo?: string;
  dueDate?: string;
  resolvedBy?: string;
  resolvedAt?: string;
  resolutionNotes?: string;
  images?: string[];
  cost?: number;
}

interface QualityAlert {
  id: string;
  type: 'defect_trend' | 'quality_drop' | 'inspection_failure' | 'parameter_drift' | 'custom';
  title: string;
  description: string;
  severity: 'low' | 'medium' | 'high' | 'critical';
  status: 'active' | 'acknowledged' | 'resolved' | 'dismissed';
  lineId: string;
  equipmentCode?: string;
  productTypeId?: string;
  parameters: Record<string, any>;
  threshold?: {
    parameter: string;
    operator: string;
    value: any;
  };
  triggeredAt: string;
  acknowledgedBy?: string;
  acknowledgedAt?: string;
  resolvedBy?: string;
  resolvedAt?: string;
  resolutionNotes?: string;
}

interface QualityMetrics {
  lineId: string;
  productTypeId: string;
  period: {
    start: string;
    end: string;
  };
  totalInspections: number;
  passedInspections: number;
  failedInspections: number;
  passRate: number;
  totalDefects: number;
  defectsByCategory: Record<string, number>;
  defectsBySeverity: Record<string, number>;
  averageScore: number;
  trend: 'improving' | 'stable' | 'declining';
  alerts: number;
  criticalAlerts: number;
}

interface QualityState {
  // Quality Checks
  checks: QualityCheck[];
  currentCheck: QualityCheck | null;
  checksLoading: boolean;
  checksError: string | null;
  
  // Inspections
  inspections: QualityInspection[];
  currentInspection: QualityInspection | null;
  inspectionsLoading: boolean;
  inspectionsError: string | null;
  
  // Defects
  defects: QualityDefect[];
  currentDefect: QualityDefect | null;
  defectsLoading: boolean;
  defectsError: string | null;
  
  // Alerts
  alerts: QualityAlert[];
  currentAlert: QualityAlert | null;
  alertsLoading: boolean;
  alertsError: string | null;
  
  // Metrics
  metrics: { [key: string]: QualityMetrics };
  metricsLoading: boolean;
  metricsError: string | null;
  
  // UI State
  selectedLineId: string | null;
  selectedProductTypeId: string | null;
  selectedCheckType: string | null;
  qualityFilters: {
    status?: string;
    checkType?: string;
    defectCategory?: string;
    severity?: string;
    dateRange?: {
      start: string;
      end: string;
    };
    inspectorId?: string;
  };
  
  // Action states
  actionLoading: boolean;
  actionError: string | null;
}

// Initial state
const initialState: QualityState = {
  checks: [],
  currentCheck: null,
  checksLoading: false,
  checksError: null,
  
  inspections: [],
  currentInspection: null,
  inspectionsLoading: false,
  inspectionsError: null,
  
  defects: [],
  currentDefect: null,
  defectsLoading: false,
  defectsError: null,
  
  alerts: [],
  currentAlert: null,
  alertsLoading: false,
  alertsError: null,
  
  metrics: {},
  metricsLoading: false,
  metricsError: null,
  
  selectedLineId: null,
  selectedProductTypeId: null,
  selectedCheckType: null,
  qualityFilters: {},
  
  actionLoading: false,
  actionError: null,
};

// Async thunks
export const fetchQualityChecks = createAsyncThunk(
  'quality/fetchChecks',
  async (filters?: { lineId?: string; checkType?: string; isActive?: boolean }, { rejectWithValue }) => {
    try {
      const response = await apiService.getQualityChecks(filters);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch quality checks');
    }
  }
);

export const fetchQualityCheck = createAsyncThunk(
  'quality/fetchCheck',
  async (checkId: string, { rejectWithValue }) => {
    try {
      const response = await apiService.getQualityCheck(checkId);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch quality check');
    }
  }
);

export const createQualityCheck = createAsyncThunk(
  'quality/createCheck',
  async (checkData: Partial<QualityCheck>, { rejectWithValue }) => {
    try {
      const response = await apiService.createQualityCheck(checkData);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to create quality check');
    }
  }
);

export const updateQualityCheck = createAsyncThunk(
  'quality/updateCheck',
  async ({ checkId, updateData }: { checkId: string; updateData: Partial<QualityCheck> }, { rejectWithValue }) => {
    try {
      const response = await apiService.updateQualityCheck(checkId, updateData);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to update quality check');
    }
  }
);

export const deleteQualityCheck = createAsyncThunk(
  'quality/deleteCheck',
  async (checkId: string, { rejectWithValue }) => {
    try {
      await apiService.deleteQualityCheck(checkId);
      return checkId;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to delete quality check');
    }
  }
);

export const fetchQualityInspections = createAsyncThunk(
  'quality/fetchInspections',
  async (filters?: { lineId?: string; checkId?: string; status?: string; dateRange?: { start: string; end: string } }, { rejectWithValue }) => {
    try {
      const response = await apiService.getQualityInspections(filters);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch quality inspections');
    }
  }
);

export const fetchQualityInspection = createAsyncThunk(
  'quality/fetchInspection',
  async (inspectionId: string, { rejectWithValue }) => {
    try {
      const response = await apiService.getQualityInspection(inspectionId);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch quality inspection');
    }
  }
);

export const createQualityInspection = createAsyncThunk(
  'quality/createInspection',
  async (inspectionData: Partial<QualityInspection>, { rejectWithValue }) => {
    try {
      const response = await apiService.createQualityInspection(inspectionData);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to create quality inspection');
    }
  }
);

export const updateQualityInspection = createAsyncThunk(
  'quality/updateInspection',
  async ({ inspectionId, updateData }: { inspectionId: string; updateData: Partial<QualityInspection> }, { rejectWithValue }) => {
    try {
      const response = await apiService.updateQualityInspection(inspectionId, updateData);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to update quality inspection');
    }
  }
);

export const completeQualityInspection = createAsyncThunk(
  'quality/completeInspection',
  async ({ inspectionId, results, overallResult, score, notes }: { inspectionId: string; results: QualityResult[]; overallResult: string; score?: number; notes?: string }, { rejectWithValue }) => {
    try {
      const response = await apiService.completeQualityInspection(inspectionId, results, overallResult, score, notes);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to complete quality inspection');
    }
  }
);

export const approveQualityInspection = createAsyncThunk(
  'quality/approveInspection',
  async (inspectionId: string, { rejectWithValue }) => {
    try {
      const response = await apiService.approveQualityInspection(inspectionId);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to approve quality inspection');
    }
  }
);

export const rejectQualityInspection = createAsyncThunk(
  'quality/rejectInspection',
  async ({ inspectionId, rejectionReason }: { inspectionId: string; rejectionReason: string }, { rejectWithValue }) => {
    try {
      const response = await apiService.rejectQualityInspection(inspectionId, rejectionReason);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to reject quality inspection');
    }
  }
);

export const fetchQualityDefects = createAsyncThunk(
  'quality/fetchDefects',
  async (filters?: { lineId?: string; defectCategory?: string; severity?: string; status?: string; dateRange?: { start: string; end: string } }, { rejectWithValue }) => {
    try {
      const response = await apiService.getQualityDefects(filters);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch quality defects');
    }
  }
);

export const fetchQualityDefect = createAsyncThunk(
  'quality/fetchDefect',
  async (defectId: string, { rejectWithValue }) => {
    try {
      const response = await apiService.getQualityDefect(defectId);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch quality defect');
    }
  }
);

export const createQualityDefect = createAsyncThunk(
  'quality/createDefect',
  async (defectData: Partial<QualityDefect>, { rejectWithValue }) => {
    try {
      const response = await apiService.createQualityDefect(defectData);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to create quality defect');
    }
  }
);

export const updateQualityDefect = createAsyncThunk(
  'quality/updateDefect',
  async ({ defectId, updateData }: { defectId: string; updateData: Partial<QualityDefect> }, { rejectWithValue }) => {
    try {
      const response = await apiService.updateQualityDefect(defectId, updateData);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to update quality defect');
    }
  }
);

export const resolveQualityDefect = createAsyncThunk(
  'quality/resolveDefect',
  async ({ defectId, resolutionNotes }: { defectId: string; resolutionNotes: string }, { rejectWithValue }) => {
    try {
      const response = await apiService.resolveQualityDefect(defectId, resolutionNotes);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to resolve quality defect');
    }
  }
);

export const fetchQualityAlerts = createAsyncThunk(
  'quality/fetchAlerts',
  async (filters?: { status?: string; severity?: string; lineId?: string }, { rejectWithValue }) => {
    try {
      const response = await apiService.getQualityAlerts(filters);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch quality alerts');
    }
  }
);

export const acknowledgeQualityAlert = createAsyncThunk(
  'quality/acknowledgeAlert',
  async (alertId: string, { rejectWithValue }) => {
    try {
      const response = await apiService.acknowledgeQualityAlert(alertId);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to acknowledge quality alert');
    }
  }
);

export const resolveQualityAlert = createAsyncThunk(
  'quality/resolveAlert',
  async ({ alertId, resolutionNotes }: { alertId: string; resolutionNotes: string }, { rejectWithValue }) => {
    try {
      const response = await apiService.resolveQualityAlert(alertId, resolutionNotes);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to resolve quality alert');
    }
  }
);

export const fetchQualityMetrics = createAsyncThunk(
  'quality/fetchMetrics',
  async ({ lineId, productTypeId, period }: { lineId: string; productTypeId?: string; period: { start: string; end: string } }, { rejectWithValue }) => {
    try {
      const response = await apiService.getQualityMetrics(lineId, productTypeId, period);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch quality metrics');
    }
  }
);

// Slice
const qualitySlice = createSlice({
  name: 'quality',
  initialState,
  reducers: {
    // Clear errors
    clearChecksError: (state) => {
      state.checksError = null;
    },
    clearInspectionsError: (state) => {
      state.inspectionsError = null;
    },
    clearDefectsError: (state) => {
      state.defectsError = null;
    },
    clearAlertsError: (state) => {
      state.alertsError = null;
    },
    clearMetricsError: (state) => {
      state.metricsError = null;
    },
    clearActionError: (state) => {
      state.actionError = null;
    },
    clearAllErrors: (state) => {
      state.checksError = null;
      state.inspectionsError = null;
      state.defectsError = null;
      state.alertsError = null;
      state.metricsError = null;
      state.actionError = null;
    },
    
    // Set selected items
    setSelectedLineId: (state, action: PayloadAction<string | null>) => {
      state.selectedLineId = action.payload;
    },
    setSelectedProductTypeId: (state, action: PayloadAction<string | null>) => {
      state.selectedProductTypeId = action.payload;
    },
    setSelectedCheckType: (state, action: PayloadAction<string | null>) => {
      state.selectedCheckType = action.payload;
    },
    
    // Set filters
    setQualityFilters: (state, action: PayloadAction<Partial<QualityState['qualityFilters']>>) => {
      state.qualityFilters = { ...state.qualityFilters, ...action.payload };
    },
    clearQualityFilters: (state) => {
      state.qualityFilters = {};
    },
    
    // Real-time updates
    addQualityInspection: (state, action: PayloadAction<QualityInspection>) => {
      const inspection = action.payload;
      const existingIndex = state.inspections.findIndex(i => i.id === inspection.id);
      
      if (existingIndex !== -1) {
        state.inspections[existingIndex] = inspection;
      } else {
        state.inspections.unshift(inspection);
      }
    },
    
    updateQualityInspection: (state, action: PayloadAction<QualityInspection>) => {
      const inspection = action.payload;
      const existingIndex = state.inspections.findIndex(i => i.id === inspection.id);
      
      if (existingIndex !== -1) {
        state.inspections[existingIndex] = inspection;
      }
      
      if (state.currentInspection?.id === inspection.id) {
        state.currentInspection = inspection;
      }
    },
    
    addQualityDefect: (state, action: PayloadAction<QualityDefect>) => {
      const defect = action.payload;
      const existingIndex = state.defects.findIndex(d => d.id === defect.id);
      
      if (existingIndex !== -1) {
        state.defects[existingIndex] = defect;
      } else {
        state.defects.unshift(defect);
      }
    },
    
    updateQualityDefect: (state, action: PayloadAction<QualityDefect>) => {
      const defect = action.payload;
      const existingIndex = state.defects.findIndex(d => d.id === defect.id);
      
      if (existingIndex !== -1) {
        state.defects[existingIndex] = defect;
      }
      
      if (state.currentDefect?.id === defect.id) {
        state.currentDefect = defect;
      }
    },
    
    addQualityAlert: (state, action: PayloadAction<QualityAlert>) => {
      const alert = action.payload;
      const existingIndex = state.alerts.findIndex(a => a.id === alert.id);
      
      if (existingIndex !== -1) {
        state.alerts[existingIndex] = alert;
      } else {
        state.alerts.unshift(alert);
      }
    },
    
    updateQualityAlert: (state, action: PayloadAction<QualityAlert>) => {
      const alert = action.payload;
      const existingIndex = state.alerts.findIndex(a => a.id === alert.id);
      
      if (existingIndex !== -1) {
        state.alerts[existingIndex] = alert;
      }
      
      if (state.currentAlert?.id === alert.id) {
        state.currentAlert = alert;
      }
    },
  },
  extraReducers: (builder) => {
    // Quality Checks
    builder
      .addCase(fetchQualityChecks.pending, (state) => {
        state.checksLoading = true;
        state.checksError = null;
      })
      .addCase(fetchQualityChecks.fulfilled, (state, action) => {
        state.checksLoading = false;
        state.checks = action.payload;
      })
      .addCase(fetchQualityChecks.rejected, (state, action) => {
        state.checksLoading = false;
        state.checksError = action.payload as string;
      })
      
      .addCase(fetchQualityCheck.pending, (state) => {
        state.checksLoading = true;
        state.checksError = null;
      })
      .addCase(fetchQualityCheck.fulfilled, (state, action) => {
        state.checksLoading = false;
        state.currentCheck = action.payload;
      })
      .addCase(fetchQualityCheck.rejected, (state, action) => {
        state.checksLoading = false;
        state.checksError = action.payload as string;
      })
      
      .addCase(createQualityCheck.fulfilled, (state, action) => {
        state.checks.push(action.payload);
      })
      
      .addCase(updateQualityCheck.fulfilled, (state, action) => {
        const check = action.payload;
        const index = state.checks.findIndex(c => c.id === check.id);
        if (index !== -1) {
          state.checks[index] = check;
        }
        if (state.currentCheck?.id === check.id) {
          state.currentCheck = check;
        }
      })
      
      .addCase(deleteQualityCheck.fulfilled, (state, action) => {
        const checkId = action.payload;
        state.checks = state.checks.filter(c => c.id !== checkId);
        if (state.currentCheck?.id === checkId) {
          state.currentCheck = null;
        }
      });
    
    // Quality Inspections
    builder
      .addCase(fetchQualityInspections.pending, (state) => {
        state.inspectionsLoading = true;
        state.inspectionsError = null;
      })
      .addCase(fetchQualityInspections.fulfilled, (state, action) => {
        state.inspectionsLoading = false;
        state.inspections = action.payload;
      })
      .addCase(fetchQualityInspections.rejected, (state, action) => {
        state.inspectionsLoading = false;
        state.inspectionsError = action.payload as string;
      })
      
      .addCase(fetchQualityInspection.pending, (state) => {
        state.inspectionsLoading = true;
        state.inspectionsError = null;
      })
      .addCase(fetchQualityInspection.fulfilled, (state, action) => {
        state.inspectionsLoading = false;
        state.currentInspection = action.payload;
      })
      .addCase(fetchQualityInspection.rejected, (state, action) => {
        state.inspectionsLoading = false;
        state.inspectionsError = action.payload as string;
      })
      
      .addCase(createQualityInspection.fulfilled, (state, action) => {
        state.inspections.unshift(action.payload);
      })
      
      .addCase(updateQualityInspection.fulfilled, (state, action) => {
        const inspection = action.payload;
        const index = state.inspections.findIndex(i => i.id === inspection.id);
        if (index !== -1) {
          state.inspections[index] = inspection;
        }
        if (state.currentInspection?.id === inspection.id) {
          state.currentInspection = inspection;
        }
      })
      
      .addCase(completeQualityInspection.fulfilled, (state, action) => {
        const inspection = action.payload;
        const index = state.inspections.findIndex(i => i.id === inspection.id);
        if (index !== -1) {
          state.inspections[index] = inspection;
        }
        if (state.currentInspection?.id === inspection.id) {
          state.currentInspection = inspection;
        }
      })
      
      .addCase(approveQualityInspection.fulfilled, (state, action) => {
        const inspection = action.payload;
        const index = state.inspections.findIndex(i => i.id === inspection.id);
        if (index !== -1) {
          state.inspections[index] = inspection;
        }
        if (state.currentInspection?.id === inspection.id) {
          state.currentInspection = inspection;
        }
      })
      
      .addCase(rejectQualityInspection.fulfilled, (state, action) => {
        const inspection = action.payload;
        const index = state.inspections.findIndex(i => i.id === inspection.id);
        if (index !== -1) {
          state.inspections[index] = inspection;
        }
        if (state.currentInspection?.id === inspection.id) {
          state.currentInspection = inspection;
        }
      });
    
    // Quality Defects
    builder
      .addCase(fetchQualityDefects.pending, (state) => {
        state.defectsLoading = true;
        state.defectsError = null;
      })
      .addCase(fetchQualityDefects.fulfilled, (state, action) => {
        state.defectsLoading = false;
        state.defects = action.payload;
      })
      .addCase(fetchQualityDefects.rejected, (state, action) => {
        state.defectsLoading = false;
        state.defectsError = action.payload as string;
      })
      
      .addCase(fetchQualityDefect.pending, (state) => {
        state.defectsLoading = true;
        state.defectsError = null;
      })
      .addCase(fetchQualityDefect.fulfilled, (state, action) => {
        state.defectsLoading = false;
        state.currentDefect = action.payload;
      })
      .addCase(fetchQualityDefect.rejected, (state, action) => {
        state.defectsLoading = false;
        state.defectsError = action.payload as string;
      })
      
      .addCase(createQualityDefect.fulfilled, (state, action) => {
        state.defects.unshift(action.payload);
      })
      
      .addCase(updateQualityDefect.fulfilled, (state, action) => {
        const defect = action.payload;
        const index = state.defects.findIndex(d => d.id === defect.id);
        if (index !== -1) {
          state.defects[index] = defect;
        }
        if (state.currentDefect?.id === defect.id) {
          state.currentDefect = defect;
        }
      })
      
      .addCase(resolveQualityDefect.fulfilled, (state, action) => {
        const defect = action.payload;
        const index = state.defects.findIndex(d => d.id === defect.id);
        if (index !== -1) {
          state.defects[index] = defect;
        }
        if (state.currentDefect?.id === defect.id) {
          state.currentDefect = defect;
        }
      });
    
    // Quality Alerts
    builder
      .addCase(fetchQualityAlerts.pending, (state) => {
        state.alertsLoading = true;
        state.alertsError = null;
      })
      .addCase(fetchQualityAlerts.fulfilled, (state, action) => {
        state.alertsLoading = false;
        state.alerts = action.payload;
      })
      .addCase(fetchQualityAlerts.rejected, (state, action) => {
        state.alertsLoading = false;
        state.alertsError = action.payload as string;
      })
      
      .addCase(acknowledgeQualityAlert.fulfilled, (state, action) => {
        const alert = action.payload;
        const index = state.alerts.findIndex(a => a.id === alert.id);
        if (index !== -1) {
          state.alerts[index] = alert;
        }
        if (state.currentAlert?.id === alert.id) {
          state.currentAlert = alert;
        }
      })
      
      .addCase(resolveQualityAlert.fulfilled, (state, action) => {
        const alert = action.payload;
        const index = state.alerts.findIndex(a => a.id === alert.id);
        if (index !== -1) {
          state.alerts[index] = alert;
        }
        if (state.currentAlert?.id === alert.id) {
          state.currentAlert = alert;
        }
      });
    
    // Quality Metrics
    builder
      .addCase(fetchQualityMetrics.pending, (state) => {
        state.metricsLoading = true;
        state.metricsError = null;
      })
      .addCase(fetchQualityMetrics.fulfilled, (state, action) => {
        state.metricsLoading = false;
        const metrics = action.payload;
        const key = `${metrics.lineId}_${metrics.productTypeId || 'all'}`;
        state.metrics[key] = metrics;
      })
      .addCase(fetchQualityMetrics.rejected, (state, action) => {
        state.metricsLoading = false;
        state.metricsError = action.payload as string;
      });
  },
});

// Export actions
export const {
  clearChecksError,
  clearInspectionsError,
  clearDefectsError,
  clearAlertsError,
  clearMetricsError,
  clearActionError,
  clearAllErrors,
  setSelectedLineId,
  setSelectedProductTypeId,
  setSelectedCheckType,
  setQualityFilters,
  clearQualityFilters,
  addQualityInspection,
  updateQualityInspection,
  addQualityDefect,
  updateQualityDefect,
  addQualityAlert,
  updateQualityAlert,
} = qualitySlice.actions;

// Selectors
export const selectChecks = (state: RootState) => state.quality.checks;
export const selectCurrentCheck = (state: RootState) => state.quality.currentCheck;
export const selectChecksLoading = (state: RootState) => state.quality.checksLoading;
export const selectChecksError = (state: RootState) => state.quality.checksError;

export const selectInspections = (state: RootState) => state.quality.inspections;
export const selectCurrentInspection = (state: RootState) => state.quality.currentInspection;
export const selectInspectionsLoading = (state: RootState) => state.quality.inspectionsLoading;
export const selectInspectionsError = (state: RootState) => state.quality.inspectionsError;

export const selectDefects = (state: RootState) => state.quality.defects;
export const selectCurrentDefect = (state: RootState) => state.quality.currentDefect;
export const selectDefectsLoading = (state: RootState) => state.quality.defectsLoading;
export const selectDefectsError = (state: RootState) => state.quality.defectsError;

export const selectAlerts = (state: RootState) => state.quality.alerts;
export const selectCurrentAlert = (state: RootState) => state.quality.currentAlert;
export const selectAlertsLoading = (state: RootState) => state.quality.alertsLoading;
export const selectAlertsError = (state: RootState) => state.quality.alertsError;

export const selectMetrics = (state: RootState) => state.quality.metrics;
export const selectMetricsLoading = (state: RootState) => state.quality.metricsLoading;
export const selectMetricsError = (state: RootState) => state.quality.metricsError;

export const selectSelectedLineId = (state: RootState) => state.quality.selectedLineId;
export const selectSelectedProductTypeId = (state: RootState) => state.quality.selectedProductTypeId;
export const selectSelectedCheckType = (state: RootState) => state.quality.selectedCheckType;
export const selectQualityFilters = (state: RootState) => state.quality.qualityFilters;

export const selectActionLoading = (state: RootState) => state.quality.actionLoading;
export const selectActionError = (state: RootState) => state.quality.actionError;

// Filtered selectors
export const selectChecksByLine = (lineId: string) => (state: RootState) =>
  state.quality.checks.filter(check => check.lineId === lineId);

export const selectChecksByType = (checkType: string) => (state: RootState) =>
  state.quality.checks.filter(check => check.checkType === checkType);

export const selectActiveChecks = (state: RootState) =>
  state.quality.checks.filter(check => check.isActive);

export const selectInspectionsByStatus = (status: string) => (state: RootState) =>
  state.quality.inspections.filter(inspection => inspection.status === status);

export const selectInspectionsByLine = (lineId: string) => (state: RootState) =>
  state.quality.inspections.filter(inspection => inspection.lineId === lineId);

export const selectPendingInspections = (state: RootState) =>
  state.quality.inspections.filter(inspection => inspection.status === 'pending');

export const selectCompletedInspections = (state: RootState) =>
  state.quality.inspections.filter(inspection => inspection.status === 'completed');

export const selectFailedInspections = (state: RootState) =>
  state.quality.inspections.filter(inspection => inspection.overallResult === 'fail');

export const selectDefectsByCategory = (category: string) => (state: RootState) =>
  state.quality.defects.filter(defect => defect.defectCategory === category);

export const selectDefectsBySeverity = (severity: string) => (state: RootState) =>
  state.quality.defects.filter(defect => defect.severity === severity);

export const selectOpenDefects = (state: RootState) =>
  state.quality.defects.filter(defect => defect.status === 'open');

export const selectCriticalDefects = (state: RootState) =>
  state.quality.defects.filter(defect => defect.severity === 'critical' && defect.status !== 'closed');

export const selectActiveAlerts = (state: RootState) =>
  state.quality.alerts.filter(alert => alert.status === 'active');

export const selectCriticalAlerts = (state: RootState) =>
  state.quality.alerts.filter(alert => alert.severity === 'critical' && alert.status !== 'resolved');

// Computed selectors
export const selectQualityStats = (state: RootState) => {
  const inspections = state.quality.inspections;
  const total = inspections.length;
  const passed = inspections.filter(i => i.overallResult === 'pass').length;
  const failed = inspections.filter(i => i.overallResult === 'fail').length;
  const pending = inspections.filter(i => i.status === 'pending').length;
  
  return {
    total,
    passed,
    failed,
    pending,
    passRate: total > 0 ? (passed / total) * 100 : 0,
    failRate: total > 0 ? (failed / total) * 100 : 0,
  };
};

export const selectDefectStats = (state: RootState) => {
  const defects = state.quality.defects;
  const total = defects.length;
  const open = defects.filter(d => d.status === 'open').length;
  const resolved = defects.filter(d => d.status === 'resolved').length;
  const critical = defects.filter(d => d.severity === 'critical').length;
  
  return {
    total,
    open,
    resolved,
    critical,
    resolutionRate: total > 0 ? (resolved / total) * 100 : 0,
  };
};

export const selectAlertStats = (state: RootState) => {
  const alerts = state.quality.alerts;
  const total = alerts.length;
  const active = alerts.filter(a => a.status === 'active').length;
  const resolved = alerts.filter(a => a.status === 'resolved').length;
  const critical = alerts.filter(a => a.severity === 'critical').length;
  
  return {
    total,
    active,
    resolved,
    critical,
    resolutionRate: total > 0 ? (resolved / total) * 100 : 0,
  };
};

// Export reducer
export default qualitySlice.reducer;
