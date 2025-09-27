/**
 * MS5.0 Floor Dashboard - Production Redux Slice
 * 
 * This slice manages production-related state including production lines,
 * schedules, and job assignments.
 */

import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit';
import { RootState } from '../index';
import { apiService } from '../../services/api';
import { 
  ProductionLine, 
  ProductionSchedule, 
  JobAssignment,
  ProductionLineStatus,
  ScheduleStatus,
  JobStatus 
} from '../../types/production';

// Types
interface ProductionState {
  // Production Lines
  lines: ProductionLine[];
  currentLine: ProductionLine | null;
  linesLoading: boolean;
  linesError: string | null;
  
  // Production Schedules
  schedules: ProductionSchedule[];
  currentSchedule: ProductionSchedule | null;
  schedulesLoading: boolean;
  schedulesError: string | null;
  
  // Job Assignments
  jobAssignments: JobAssignment[];
  currentJob: JobAssignment | null;
  jobsLoading: boolean;
  jobsError: string | null;
  
  // UI State
  selectedLineId: string | null;
  selectedScheduleId: string | null;
  selectedJobId: string | null;
}

// Initial state
const initialState: ProductionState = {
  lines: [],
  currentLine: null,
  linesLoading: false,
  linesError: null,
  
  schedules: [],
  currentSchedule: null,
  schedulesLoading: false,
  schedulesError: null,
  
  jobAssignments: [],
  currentJob: null,
  jobsLoading: false,
  jobsError: null,
  
  selectedLineId: null,
  selectedScheduleId: null,
  selectedJobId: null,
};

// Async thunks for production lines
export const fetchProductionLines = createAsyncThunk(
  'production/fetchLines',
  async (_, { rejectWithValue }) => {
    try {
      const response = await apiService.getProductionLines();
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch production lines');
    }
  }
);

export const fetchProductionLine = createAsyncThunk(
  'production/fetchLine',
  async (lineId: string, { rejectWithValue }) => {
    try {
      const response = await apiService.getProductionLine(lineId);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch production line');
    }
  }
);

export const createProductionLine = createAsyncThunk(
  'production/createLine',
  async (lineData: Partial<ProductionLine>, { rejectWithValue }) => {
    try {
      const response = await apiService.createProductionLine(lineData);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to create production line');
    }
  }
);

export const updateProductionLine = createAsyncThunk(
  'production/updateLine',
  async ({ lineId, updateData }: { lineId: string; updateData: Partial<ProductionLine> }, { rejectWithValue }) => {
    try {
      const response = await apiService.updateProductionLine(lineId, updateData);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to update production line');
    }
  }
);

export const deleteProductionLine = createAsyncThunk(
  'production/deleteLine',
  async (lineId: string, { rejectWithValue }) => {
    try {
      await apiService.deleteProductionLine(lineId);
      return lineId;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to delete production line');
    }
  }
);

// Async thunks for production schedules
export const fetchProductionSchedules = createAsyncThunk(
  'production/fetchSchedules',
  async (filters?: { lineId?: string; status?: string }, { rejectWithValue }) => {
    try {
      const response = await apiService.getProductionSchedules(filters);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch production schedules');
    }
  }
);

export const fetchProductionSchedule = createAsyncThunk(
  'production/fetchSchedule',
  async (scheduleId: string, { rejectWithValue }) => {
    try {
      const response = await apiService.getProductionSchedule(scheduleId);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch production schedule');
    }
  }
);

export const createProductionSchedule = createAsyncThunk(
  'production/createSchedule',
  async (scheduleData: Partial<ProductionSchedule>, { rejectWithValue }) => {
    try {
      const response = await apiService.createProductionSchedule(scheduleData);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to create production schedule');
    }
  }
);

export const updateProductionSchedule = createAsyncThunk(
  'production/updateSchedule',
  async ({ scheduleId, updateData }: { scheduleId: string; updateData: Partial<ProductionSchedule> }, { rejectWithValue }) => {
    try {
      const response = await apiService.updateProductionSchedule(scheduleId, updateData);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to update production schedule');
    }
  }
);

export const deleteProductionSchedule = createAsyncThunk(
  'production/deleteSchedule',
  async (scheduleId: string, { rejectWithValue }) => {
    try {
      await apiService.deleteProductionSchedule(scheduleId);
      return scheduleId;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to delete production schedule');
    }
  }
);

// Async thunks for job assignments
export const fetchJobAssignments = createAsyncThunk(
  'production/fetchJobAssignments',
  async (filters?: { userId?: string; status?: string }, { rejectWithValue }) => {
    try {
      const response = await apiService.getJobAssignments(filters);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch job assignments');
    }
  }
);

export const fetchJobAssignment = createAsyncThunk(
  'production/fetchJobAssignment',
  async (assignmentId: string, { rejectWithValue }) => {
    try {
      const response = await apiService.getJobAssignment(assignmentId);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch job assignment');
    }
  }
);

export const createJobAssignment = createAsyncThunk(
  'production/createJobAssignment',
  async (assignmentData: Partial<JobAssignment>, { rejectWithValue }) => {
    try {
      const response = await apiService.createJobAssignment(assignmentData);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to create job assignment');
    }
  }
);

export const updateJobAssignment = createAsyncThunk(
  'production/updateJobAssignment',
  async ({ assignmentId, updateData }: { assignmentId: string; updateData: Partial<JobAssignment> }, { rejectWithValue }) => {
    try {
      const response = await apiService.updateJobAssignment(assignmentId, updateData);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to update job assignment');
    }
  }
);

export const acceptJob = createAsyncThunk(
  'production/acceptJob',
  async (assignmentId: string, { rejectWithValue }) => {
    try {
      const response = await apiService.acceptJob(assignmentId);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to accept job');
    }
  }
);

export const startJob = createAsyncThunk(
  'production/startJob',
  async (assignmentId: string, { rejectWithValue }) => {
    try {
      const response = await apiService.startJob(assignmentId);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to start job');
    }
  }
);

export const completeJob = createAsyncThunk(
  'production/completeJob',
  async (assignmentId: string, { rejectWithValue }) => {
    try {
      const response = await apiService.completeJob(assignmentId);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to complete job');
    }
  }
);

// Slice
const productionSlice = createSlice({
  name: 'production',
  initialState,
  reducers: {
    // Clear errors
    clearLinesError: (state) => {
      state.linesError = null;
    },
    clearSchedulesError: (state) => {
      state.schedulesError = null;
    },
    clearJobsError: (state) => {
      state.jobsError = null;
    },
    
    // Set selected items
    setSelectedLineId: (state, action: PayloadAction<string | null>) => {
      state.selectedLineId = action.payload;
    },
    setSelectedScheduleId: (state, action: PayloadAction<string | null>) => {
      state.selectedScheduleId = action.payload;
    },
    setSelectedJobId: (state, action: PayloadAction<string | null>) => {
      state.selectedJobId = action.payload;
    },
    
    // Update line status
    updateLineStatus: (state, action: PayloadAction<{ lineId: string; status: ProductionLineStatus }>) => {
      const { lineId, status } = action.payload;
      const line = state.lines.find(l => l.id === lineId);
      if (line) {
        line.status = status;
      }
      if (state.currentLine?.id === lineId) {
        state.currentLine.status = status;
      }
    },
    
    // Update schedule status
    updateScheduleStatus: (state, action: PayloadAction<{ scheduleId: string; status: ScheduleStatus }>) => {
      const { scheduleId, status } = action.payload;
      const schedule = state.schedules.find(s => s.id === scheduleId);
      if (schedule) {
        schedule.status = status;
      }
      if (state.currentSchedule?.id === scheduleId) {
        state.currentSchedule.status = status;
      }
    },
    
    // Update job status
    updateJobStatus: (state, action: PayloadAction<{ jobId: string; status: JobStatus }>) => {
      const { jobId, status } = action.payload;
      const job = state.jobAssignments.find(j => j.id === jobId);
      if (job) {
        job.status = status;
      }
      if (state.currentJob?.id === jobId) {
        state.currentJob.status = status;
      }
    },
  },
  extraReducers: (builder) => {
    // Production Lines
    builder
      .addCase(fetchProductionLines.pending, (state) => {
        state.linesLoading = true;
        state.linesError = null;
      })
      .addCase(fetchProductionLines.fulfilled, (state, action) => {
        state.linesLoading = false;
        state.lines = action.payload;
      })
      .addCase(fetchProductionLines.rejected, (state, action) => {
        state.linesLoading = false;
        state.linesError = action.payload as string;
      })
      
      .addCase(fetchProductionLine.pending, (state) => {
        state.linesLoading = true;
        state.linesError = null;
      })
      .addCase(fetchProductionLine.fulfilled, (state, action) => {
        state.linesLoading = false;
        state.currentLine = action.payload;
      })
      .addCase(fetchProductionLine.rejected, (state, action) => {
        state.linesLoading = false;
        state.linesError = action.payload as string;
      })
      
      .addCase(createProductionLine.fulfilled, (state, action) => {
        state.lines.unshift(action.payload);
      })
      
      .addCase(updateProductionLine.fulfilled, (state, action) => {
        const index = state.lines.findIndex(line => line.id === action.payload.id);
        if (index !== -1) {
          state.lines[index] = action.payload;
        }
        if (state.currentLine?.id === action.payload.id) {
          state.currentLine = action.payload;
        }
      })
      
      .addCase(deleteProductionLine.fulfilled, (state, action) => {
        state.lines = state.lines.filter(line => line.id !== action.payload);
        if (state.currentLine?.id === action.payload) {
          state.currentLine = null;
        }
      });
    
    // Production Schedules
    builder
      .addCase(fetchProductionSchedules.pending, (state) => {
        state.schedulesLoading = true;
        state.schedulesError = null;
      })
      .addCase(fetchProductionSchedules.fulfilled, (state, action) => {
        state.schedulesLoading = false;
        state.schedules = action.payload;
      })
      .addCase(fetchProductionSchedules.rejected, (state, action) => {
        state.schedulesLoading = false;
        state.schedulesError = action.payload as string;
      })
      
      .addCase(fetchProductionSchedule.pending, (state) => {
        state.schedulesLoading = true;
        state.schedulesError = null;
      })
      .addCase(fetchProductionSchedule.fulfilled, (state, action) => {
        state.schedulesLoading = false;
        state.currentSchedule = action.payload;
      })
      .addCase(fetchProductionSchedule.rejected, (state, action) => {
        state.schedulesLoading = false;
        state.schedulesError = action.payload as string;
      })
      
      .addCase(createProductionSchedule.fulfilled, (state, action) => {
        state.schedules.unshift(action.payload);
      })
      
      .addCase(updateProductionSchedule.fulfilled, (state, action) => {
        const index = state.schedules.findIndex(schedule => schedule.id === action.payload.id);
        if (index !== -1) {
          state.schedules[index] = action.payload;
        }
        if (state.currentSchedule?.id === action.payload.id) {
          state.currentSchedule = action.payload;
        }
      })
      
      .addCase(deleteProductionSchedule.fulfilled, (state, action) => {
        state.schedules = state.schedules.filter(schedule => schedule.id !== action.payload);
        if (state.currentSchedule?.id === action.payload) {
          state.currentSchedule = null;
        }
      });
    
    // Job Assignments
    builder
      .addCase(fetchJobAssignments.pending, (state) => {
        state.jobsLoading = true;
        state.jobsError = null;
      })
      .addCase(fetchJobAssignments.fulfilled, (state, action) => {
        state.jobsLoading = false;
        state.jobAssignments = action.payload;
      })
      .addCase(fetchJobAssignments.rejected, (state, action) => {
        state.jobsLoading = false;
        state.jobsError = action.payload as string;
      })
      
      .addCase(fetchJobAssignment.pending, (state) => {
        state.jobsLoading = true;
        state.jobsError = null;
      })
      .addCase(fetchJobAssignment.fulfilled, (state, action) => {
        state.jobsLoading = false;
        state.currentJob = action.payload;
      })
      .addCase(fetchJobAssignment.rejected, (state, action) => {
        state.jobsLoading = false;
        state.jobsError = action.payload as string;
      })
      
      .addCase(createJobAssignment.fulfilled, (state, action) => {
        state.jobAssignments.unshift(action.payload);
      })
      
      .addCase(updateJobAssignment.fulfilled, (state, action) => {
        const index = state.jobAssignments.findIndex(job => job.id === action.payload.id);
        if (index !== -1) {
          state.jobAssignments[index] = action.payload;
        }
        if (state.currentJob?.id === action.payload.id) {
          state.currentJob = action.payload;
        }
      })
      
      .addCase(acceptJob.fulfilled, (state, action) => {
        const index = state.jobAssignments.findIndex(job => job.id === action.payload.id);
        if (index !== -1) {
          state.jobAssignments[index] = action.payload;
        }
        if (state.currentJob?.id === action.payload.id) {
          state.currentJob = action.payload;
        }
      })
      
      .addCase(startJob.fulfilled, (state, action) => {
        const index = state.jobAssignments.findIndex(job => job.id === action.payload.id);
        if (index !== -1) {
          state.jobAssignments[index] = action.payload;
        }
        if (state.currentJob?.id === action.payload.id) {
          state.currentJob = action.payload;
        }
      })
      
      .addCase(completeJob.fulfilled, (state, action) => {
        const index = state.jobAssignments.findIndex(job => job.id === action.payload.id);
        if (index !== -1) {
          state.jobAssignments[index] = action.payload;
        }
        if (state.currentJob?.id === action.payload.id) {
          state.currentJob = action.payload;
        }
      });
  },
});

// Export actions
export const {
  clearLinesError,
  clearSchedulesError,
  clearJobsError,
  setSelectedLineId,
  setSelectedScheduleId,
  setSelectedJobId,
  updateLineStatus,
  updateScheduleStatus,
  updateJobStatus,
} = productionSlice.actions;

// Selectors
export const selectProductionLines = (state: RootState) => state.production.lines;
export const selectCurrentLine = (state: RootState) => state.production.currentLine;
export const selectLinesLoading = (state: RootState) => state.production.linesLoading;
export const selectLinesError = (state: RootState) => state.production.linesError;

export const selectProductionSchedules = (state: RootState) => state.production.schedules;
export const selectCurrentSchedule = (state: RootState) => state.production.currentSchedule;
export const selectSchedulesLoading = (state: RootState) => state.production.schedulesLoading;
export const selectSchedulesError = (state: RootState) => state.production.schedulesError;

export const selectJobAssignments = (state: RootState) => state.production.jobAssignments;
export const selectCurrentJob = (state: RootState) => state.production.currentJob;
export const selectJobsLoading = (state: RootState) => state.production.jobsLoading;
export const selectJobsError = (state: RootState) => state.production.jobsError;

export const selectSelectedLineId = (state: RootState) => state.production.selectedLineId;
export const selectSelectedScheduleId = (state: RootState) => state.production.selectedScheduleId;
export const selectSelectedJobId = (state: RootState) => state.production.selectedJobId;

// Export reducer
export default productionSlice.reducer;
