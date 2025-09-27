/**
 * MS5.0 Floor Dashboard - Jobs Redux Slice
 * 
 * This slice manages job-related state including job assignments,
 * job status updates, and job management operations.
 */

import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit';
import { RootState } from '../index';
import { apiService } from '../../services/api';
import { JobAssignment, JobStatus } from '../../types/production';

// Types
interface JobsState {
  // Job Assignments
  myJobs: JobAssignment[];
  allJobs: JobAssignment[];
  currentJob: JobAssignment | null;
  
  // Loading states
  myJobsLoading: boolean;
  allJobsLoading: boolean;
  jobActionLoading: boolean;
  
  // Error states
  myJobsError: string | null;
  allJobsError: string | null;
  jobActionError: string | null;
  
  // UI State
  selectedJobId: string | null;
  jobFilters: {
    status?: JobStatus;
    userId?: string;
    lineId?: string;
  };
}

// Initial state
const initialState: JobsState = {
  myJobs: [],
  allJobs: [],
  currentJob: null,
  
  myJobsLoading: false,
  allJobsLoading: false,
  jobActionLoading: false,
  
  myJobsError: null,
  allJobsError: null,
  jobActionError: null,
  
  selectedJobId: null,
  jobFilters: {},
};

// Async thunks
export const fetchMyJobs = createAsyncThunk(
  'jobs/fetchMyJobs',
  async (_, { rejectWithValue }) => {
    try {
      const response = await apiService.getMyJobs();
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch my jobs');
    }
  }
);

export const fetchAllJobs = createAsyncThunk(
  'jobs/fetchAllJobs',
  async (filters?: { status?: string; userId?: string; lineId?: string }, { rejectWithValue }) => {
    try {
      const response = await apiService.getJobAssignments(filters);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch all jobs');
    }
  }
);

export const fetchJob = createAsyncThunk(
  'jobs/fetchJob',
  async (jobId: string, { rejectWithValue }) => {
    try {
      const response = await apiService.getJobAssignment(jobId);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch job');
    }
  }
);

export const acceptJob = createAsyncThunk(
  'jobs/acceptJob',
  async (jobId: string, { rejectWithValue }) => {
    try {
      const response = await apiService.acceptJob(jobId);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to accept job');
    }
  }
);

export const startJob = createAsyncThunk(
  'jobs/startJob',
  async (jobId: string, { rejectWithValue }) => {
    try {
      const response = await apiService.startJob(jobId);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to start job');
    }
  }
);

export const completeJob = createAsyncThunk(
  'jobs/completeJob',
  async (jobId: string, { rejectWithValue }) => {
    try {
      const response = await apiService.completeJob(jobId);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to complete job');
    }
  }
);

export const cancelJob = createAsyncThunk(
  'jobs/cancelJob',
  async (jobId: string, { rejectWithValue }) => {
    try {
      const response = await apiService.cancelJob(jobId);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to cancel job');
    }
  }
);

export const updateJobNotes = createAsyncThunk(
  'jobs/updateJobNotes',
  async ({ jobId, notes }: { jobId: string; notes: string }, { rejectWithValue }) => {
    try {
      const response = await apiService.updateJobAssignment(jobId, { notes });
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to update job notes');
    }
  }
);

// Slice
const jobsSlice = createSlice({
  name: 'jobs',
  initialState,
  reducers: {
    // Clear errors
    clearMyJobsError: (state) => {
      state.myJobsError = null;
    },
    clearAllJobsError: (state) => {
      state.allJobsError = null;
    },
    clearJobActionError: (state) => {
      state.jobActionError = null;
    },
    clearAllErrors: (state) => {
      state.myJobsError = null;
      state.allJobsError = null;
      state.jobActionError = null;
    },
    
    // Set selected job
    setSelectedJobId: (state, action: PayloadAction<string | null>) => {
      state.selectedJobId = action.payload;
    },
    
    // Set job filters
    setJobFilters: (state, action: PayloadAction<Partial<JobsState['jobFilters']>>) => {
      state.jobFilters = { ...state.jobFilters, ...action.payload };
    },
    
    // Clear job filters
    clearJobFilters: (state) => {
      state.jobFilters = {};
    },
    
    // Update job status locally
    updateJobStatus: (state, action: PayloadAction<{ jobId: string; status: JobStatus }>) => {
      const { jobId, status } = action.payload;
      
      // Update in myJobs
      const myJobIndex = state.myJobs.findIndex(job => job.id === jobId);
      if (myJobIndex !== -1) {
        state.myJobs[myJobIndex].status = status;
      }
      
      // Update in allJobs
      const allJobIndex = state.allJobs.findIndex(job => job.id === jobId);
      if (allJobIndex !== -1) {
        state.allJobs[allJobIndex].status = status;
      }
      
      // Update current job
      if (state.currentJob?.id === jobId) {
        state.currentJob.status = status;
      }
    },
    
    // Update job notes locally
    updateJobNotesLocal: (state, action: PayloadAction<{ jobId: string; notes: string }>) => {
      const { jobId, notes } = action.payload;
      
      // Update in myJobs
      const myJobIndex = state.myJobs.findIndex(job => job.id === jobId);
      if (myJobIndex !== -1) {
        state.myJobs[myJobIndex].notes = notes;
      }
      
      // Update in allJobs
      const allJobIndex = state.allJobs.findIndex(job => job.id === jobId);
      if (allJobIndex !== -1) {
        state.allJobs[allJobIndex].notes = notes;
      }
      
      // Update current job
      if (state.currentJob?.id === jobId) {
        state.currentJob.notes = notes;
      }
    },
    
    // Add job to myJobs (when assigned)
    addJobToMyJobs: (state, action: PayloadAction<JobAssignment>) => {
      const job = action.payload;
      const existingIndex = state.myJobs.findIndex(j => j.id === job.id);
      if (existingIndex === -1) {
        state.myJobs.unshift(job);
      } else {
        state.myJobs[existingIndex] = job;
      }
    },
    
    // Remove job from myJobs (when completed/cancelled)
    removeJobFromMyJobs: (state, action: PayloadAction<string>) => {
      const jobId = action.payload;
      state.myJobs = state.myJobs.filter(job => job.id !== jobId);
    },
  },
  extraReducers: (builder) => {
    // Fetch my jobs
    builder
      .addCase(fetchMyJobs.pending, (state) => {
        state.myJobsLoading = true;
        state.myJobsError = null;
      })
      .addCase(fetchMyJobs.fulfilled, (state, action) => {
        state.myJobsLoading = false;
        state.myJobs = action.payload;
      })
      .addCase(fetchMyJobs.rejected, (state, action) => {
        state.myJobsLoading = false;
        state.myJobsError = action.payload as string;
      });
    
    // Fetch all jobs
    builder
      .addCase(fetchAllJobs.pending, (state) => {
        state.allJobsLoading = true;
        state.allJobsError = null;
      })
      .addCase(fetchAllJobs.fulfilled, (state, action) => {
        state.allJobsLoading = false;
        state.allJobs = action.payload;
      })
      .addCase(fetchAllJobs.rejected, (state, action) => {
        state.allJobsLoading = false;
        state.allJobsError = action.payload as string;
      });
    
    // Fetch single job
    builder
      .addCase(fetchJob.pending, (state) => {
        state.jobActionLoading = true;
        state.jobActionError = null;
      })
      .addCase(fetchJob.fulfilled, (state, action) => {
        state.jobActionLoading = false;
        state.currentJob = action.payload;
      })
      .addCase(fetchJob.rejected, (state, action) => {
        state.jobActionLoading = false;
        state.jobActionError = action.payload as string;
      });
    
    // Accept job
    builder
      .addCase(acceptJob.pending, (state) => {
        state.jobActionLoading = true;
        state.jobActionError = null;
      })
      .addCase(acceptJob.fulfilled, (state, action) => {
        state.jobActionLoading = false;
        const job = action.payload;
        
        // Update in myJobs
        const myJobIndex = state.myJobs.findIndex(j => j.id === job.id);
        if (myJobIndex !== -1) {
          state.myJobs[myJobIndex] = job;
        }
        
        // Update in allJobs
        const allJobIndex = state.allJobs.findIndex(j => j.id === job.id);
        if (allJobIndex !== -1) {
          state.allJobs[allJobIndex] = job;
        }
        
        // Update current job
        if (state.currentJob?.id === job.id) {
          state.currentJob = job;
        }
      })
      .addCase(acceptJob.rejected, (state, action) => {
        state.jobActionLoading = false;
        state.jobActionError = action.payload as string;
      });
    
    // Start job
    builder
      .addCase(startJob.pending, (state) => {
        state.jobActionLoading = true;
        state.jobActionError = null;
      })
      .addCase(startJob.fulfilled, (state, action) => {
        state.jobActionLoading = false;
        const job = action.payload;
        
        // Update in myJobs
        const myJobIndex = state.myJobs.findIndex(j => j.id === job.id);
        if (myJobIndex !== -1) {
          state.myJobs[myJobIndex] = job;
        }
        
        // Update in allJobs
        const allJobIndex = state.allJobs.findIndex(j => j.id === job.id);
        if (allJobIndex !== -1) {
          state.allJobs[allJobIndex] = job;
        }
        
        // Update current job
        if (state.currentJob?.id === job.id) {
          state.currentJob = job;
        }
      })
      .addCase(startJob.rejected, (state, action) => {
        state.jobActionLoading = false;
        state.jobActionError = action.payload as string;
      });
    
    // Complete job
    builder
      .addCase(completeJob.pending, (state) => {
        state.jobActionLoading = true;
        state.jobActionError = null;
      })
      .addCase(completeJob.fulfilled, (state, action) => {
        state.jobActionLoading = false;
        const job = action.payload;
        
        // Update in myJobs
        const myJobIndex = state.myJobs.findIndex(j => j.id === job.id);
        if (myJobIndex !== -1) {
          state.myJobs[myJobIndex] = job;
        }
        
        // Update in allJobs
        const allJobIndex = state.allJobs.findIndex(j => j.id === job.id);
        if (allJobIndex !== -1) {
          state.allJobs[allJobIndex] = job;
        }
        
        // Update current job
        if (state.currentJob?.id === job.id) {
          state.currentJob = job;
        }
      })
      .addCase(completeJob.rejected, (state, action) => {
        state.jobActionLoading = false;
        state.jobActionError = action.payload as string;
      });
    
    // Cancel job
    builder
      .addCase(cancelJob.pending, (state) => {
        state.jobActionLoading = true;
        state.jobActionError = null;
      })
      .addCase(cancelJob.fulfilled, (state, action) => {
        state.jobActionLoading = false;
        const job = action.payload;
        
        // Update in myJobs
        const myJobIndex = state.myJobs.findIndex(j => j.id === job.id);
        if (myJobIndex !== -1) {
          state.myJobs[myJobIndex] = job;
        }
        
        // Update in allJobs
        const allJobIndex = state.allJobs.findIndex(j => j.id === job.id);
        if (allJobIndex !== -1) {
          state.allJobs[allJobIndex] = job;
        }
        
        // Update current job
        if (state.currentJob?.id === job.id) {
          state.currentJob = job;
        }
      })
      .addCase(cancelJob.rejected, (state, action) => {
        state.jobActionLoading = false;
        state.jobActionError = action.payload as string;
      });
    
    // Update job notes
    builder
      .addCase(updateJobNotes.pending, (state) => {
        state.jobActionLoading = true;
        state.jobActionError = null;
      })
      .addCase(updateJobNotes.fulfilled, (state, action) => {
        state.jobActionLoading = false;
        const job = action.payload;
        
        // Update in myJobs
        const myJobIndex = state.myJobs.findIndex(j => j.id === job.id);
        if (myJobIndex !== -1) {
          state.myJobs[myJobIndex] = job;
        }
        
        // Update in allJobs
        const allJobIndex = state.allJobs.findIndex(j => j.id === job.id);
        if (allJobIndex !== -1) {
          state.allJobs[allJobIndex] = job;
        }
        
        // Update current job
        if (state.currentJob?.id === job.id) {
          state.currentJob = job;
        }
      })
      .addCase(updateJobNotes.rejected, (state, action) => {
        state.jobActionLoading = false;
        state.jobActionError = action.payload as string;
      });
  },
});

// Export actions
export const {
  clearMyJobsError,
  clearAllJobsError,
  clearJobActionError,
  clearAllErrors,
  setSelectedJobId,
  setJobFilters,
  clearJobFilters,
  updateJobStatus,
  updateJobNotesLocal,
  addJobToMyJobs,
  removeJobFromMyJobs,
} = jobsSlice.actions;

// Selectors
export const selectMyJobs = (state: RootState) => state.jobs.myJobs;
export const selectAllJobs = (state: RootState) => state.jobs.allJobs;
export const selectCurrentJob = (state: RootState) => state.jobs.currentJob;

export const selectMyJobsLoading = (state: RootState) => state.jobs.myJobsLoading;
export const selectAllJobsLoading = (state: RootState) => state.jobs.allJobsLoading;
export const selectJobActionLoading = (state: RootState) => state.jobs.jobActionLoading;

export const selectMyJobsError = (state: RootState) => state.jobs.myJobsError;
export const selectAllJobsError = (state: RootState) => state.jobs.allJobsError;
export const selectJobActionError = (state: RootState) => state.jobs.jobActionError;

export const selectSelectedJobId = (state: RootState) => state.jobs.selectedJobId;
export const selectJobFilters = (state: RootState) => state.jobs.jobFilters;

// Filtered selectors
export const selectMyJobsByStatus = (status: JobStatus) => (state: RootState) => 
  state.jobs.myJobs.filter(job => job.status === status);

export const selectAllJobsByStatus = (status: JobStatus) => (state: RootState) => 
  state.jobs.allJobs.filter(job => job.status === status);

export const selectJobsByLine = (lineId: string) => (state: RootState) => 
  state.jobs.allJobs.filter(job => job.lineId === lineId);

// Export reducer
export default jobsSlice.reducer;
