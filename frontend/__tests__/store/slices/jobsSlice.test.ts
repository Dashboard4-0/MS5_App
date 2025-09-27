/**
 * Unit tests for jobs slice
 */

import { configureStore } from '@reduxjs/toolkit';
import jobsSlice, {
  fetchMyJobs,
  acceptJob,
  startJob,
  completeJob,
  createJobAssignment,
  updateJobStatus,
  clearError,
} from '../../src/store/slices/jobsSlice';

// Mock API service
jest.mock('../../src/services/api', () => ({
  apiService: {
    getMyJobs: jest.fn(),
    acceptJob: jest.fn(),
    startJob: jest.fn(),
    completeJob: jest.fn(),
    createJobAssignment: jest.fn(),
    updateJobStatus: jest.fn(),
  },
}));

import { apiService } from '../../src/services/api';

describe('jobsSlice', () => {
  let store: ReturnType<typeof configureStore>;

  beforeEach(() => {
    store = configureStore({
      reducer: {
        jobs: jobsSlice,
      },
    });
    jest.clearAllMocks();
  });

  describe('initial state', () => {
    it('has correct initial state', () => {
      const state = store.getState().jobs;
      expect(state).toEqual({
        jobs: [],
        isLoading: false,
        error: null,
        selectedJob: null,
        filters: {
          status: 'all',
          priority: 'all',
          assignedTo: 'all',
        },
      });
    });
  });

  describe('fetchMyJobs', () => {
    it('handles fetchMyJobs.pending', () => {
      store.dispatch(fetchMyJobs.pending('', undefined));
      const state = store.getState().jobs;
      
      expect(state.isLoading).toBe(true);
      expect(state.error).toBeNull();
    });

    it('handles fetchMyJobs.fulfilled', () => {
      const mockJobs = [
        { id: '1', title: 'Job 1', status: 'assigned' },
        { id: '2', title: 'Job 2', status: 'in_progress' },
      ];
      
      store.dispatch(fetchMyJobs.fulfilled(mockJobs, '', undefined));
      const state = store.getState().jobs;
      
      expect(state.isLoading).toBe(false);
      expect(state.jobs).toEqual(mockJobs);
      expect(state.error).toBeNull();
    });

    it('handles fetchMyJobs.rejected', () => {
      const errorMessage = 'Failed to fetch jobs';
      
      store.dispatch(fetchMyJobs.rejected(new Error(errorMessage), '', undefined));
      const state = store.getState().jobs;
      
      expect(state.isLoading).toBe(false);
      expect(state.error).toBe(errorMessage);
    });
  });

  describe('acceptJob', () => {
    it('handles acceptJob.pending', () => {
      store.dispatch(acceptJob.pending('', 'job-1'));
      const state = store.getState().jobs;
      
      expect(state.isLoading).toBe(true);
      expect(state.error).toBeNull();
    });

    it('handles acceptJob.fulfilled', () => {
      const mockJob = { id: '1', title: 'Job 1', status: 'accepted' };
      
      store.dispatch(acceptJob.fulfilled(mockJob, '', 'job-1'));
      const state = store.getState().jobs;
      
      expect(state.isLoading).toBe(false);
      expect(state.jobs).toContainEqual(mockJob);
      expect(state.error).toBeNull();
    });

    it('handles acceptJob.rejected', () => {
      const errorMessage = 'Failed to accept job';
      
      store.dispatch(acceptJob.rejected(new Error(errorMessage), '', 'job-1'));
      const state = store.getState().jobs;
      
      expect(state.isLoading).toBe(false);
      expect(state.error).toBe(errorMessage);
    });
  });

  describe('startJob', () => {
    it('handles startJob.pending', () => {
      store.dispatch(startJob.pending('', 'job-1'));
      const state = store.getState().jobs;
      
      expect(state.isLoading).toBe(true);
      expect(state.error).toBeNull();
    });

    it('handles startJob.fulfilled', () => {
      const mockJob = { id: '1', title: 'Job 1', status: 'in_progress' };
      
      store.dispatch(startJob.fulfilled(mockJob, '', 'job-1'));
      const state = store.getState().jobs;
      
      expect(state.isLoading).toBe(false);
      expect(state.jobs).toContainEqual(mockJob);
      expect(state.error).toBeNull();
    });

    it('handles startJob.rejected', () => {
      const errorMessage = 'Failed to start job';
      
      store.dispatch(startJob.rejected(new Error(errorMessage), '', 'job-1'));
      const state = store.getState().jobs;
      
      expect(state.isLoading).toBe(false);
      expect(state.error).toBe(errorMessage);
    });
  });

  describe('completeJob', () => {
    it('handles completeJob.pending', () => {
      store.dispatch(completeJob.pending('', { jobId: 'job-1', completionData: {} }));
      const state = store.getState().jobs;
      
      expect(state.isLoading).toBe(true);
      expect(state.error).toBeNull();
    });

    it('handles completeJob.fulfilled', () => {
      const mockJob = { id: '1', title: 'Job 1', status: 'completed' };
      
      store.dispatch(completeJob.fulfilled(mockJob, '', { jobId: 'job-1', completionData: {} }));
      const state = store.getState().jobs;
      
      expect(state.isLoading).toBe(false);
      expect(state.jobs).toContainEqual(mockJob);
      expect(state.error).toBeNull();
    });

    it('handles completeJob.rejected', () => {
      const errorMessage = 'Failed to complete job';
      
      store.dispatch(completeJob.rejected(new Error(errorMessage), '', { jobId: 'job-1', completionData: {} }));
      const state = store.getState().jobs;
      
      expect(state.isLoading).toBe(false);
      expect(state.error).toBe(errorMessage);
    });
  });

  describe('createJobAssignment', () => {
    it('handles createJobAssignment.pending', () => {
      store.dispatch(createJobAssignment.pending('', {}));
      const state = store.getState().jobs;
      
      expect(state.isLoading).toBe(true);
      expect(state.error).toBeNull();
    });

    it('handles createJobAssignment.fulfilled', () => {
      const mockJob = { id: '1', title: 'New Job', status: 'assigned' };
      
      store.dispatch(createJobAssignment.fulfilled(mockJob, '', {}));
      const state = store.getState().jobs;
      
      expect(state.isLoading).toBe(false);
      expect(state.jobs).toContainEqual(mockJob);
      expect(state.error).toBeNull();
    });

    it('handles createJobAssignment.rejected', () => {
      const errorMessage = 'Failed to create job assignment';
      
      store.dispatch(createJobAssignment.rejected(new Error(errorMessage), '', {}));
      const state = store.getState().jobs;
      
      expect(state.isLoading).toBe(false);
      expect(state.error).toBe(errorMessage);
    });
  });

  describe('updateJobStatus', () => {
    it('handles updateJobStatus.pending', () => {
      store.dispatch(updateJobStatus.pending('', { jobId: 'job-1', status: 'in_progress' }));
      const state = store.getState().jobs;
      
      expect(state.isLoading).toBe(true);
      expect(state.error).toBeNull();
    });

    it('handles updateJobStatus.fulfilled', () => {
      const mockJob = { id: '1', title: 'Job 1', status: 'in_progress' };
      
      store.dispatch(updateJobStatus.fulfilled(mockJob, '', { jobId: 'job-1', status: 'in_progress' }));
      const state = store.getState().jobs;
      
      expect(state.isLoading).toBe(false);
      expect(state.jobs).toContainEqual(mockJob);
      expect(state.error).toBeNull();
    });

    it('handles updateJobStatus.rejected', () => {
      const errorMessage = 'Failed to update job status';
      
      store.dispatch(updateJobStatus.rejected(new Error(errorMessage), '', { jobId: 'job-1', status: 'in_progress' }));
      const state = store.getState().jobs;
      
      expect(state.isLoading).toBe(false);
      expect(state.error).toBe(errorMessage);
    });
  });

  describe('clearError', () => {
    it('clears error state', () => {
      // First set an error
      store.dispatch(fetchMyJobs.rejected(new Error('Test error'), '', undefined));
      expect(store.getState().jobs.error).toBe('Test error');
      
      // Then clear it
      store.dispatch(clearError());
      expect(store.getState().jobs.error).toBeNull();
    });
  });

  describe('selectors', () => {
    it('selectJobs returns jobs array', () => {
      const mockJobs = [
        { id: '1', title: 'Job 1', status: 'assigned' },
        { id: '2', title: 'Job 2', status: 'in_progress' },
      ];
      
      store.dispatch(fetchMyJobs.fulfilled(mockJobs, '', undefined));
      const state = store.getState().jobs;
      
      expect(state.jobs).toEqual(mockJobs);
    });

    it('selectIsLoading returns loading state', () => {
      store.dispatch(fetchMyJobs.pending('', undefined));
      const state = store.getState().jobs;
      
      expect(state.isLoading).toBe(true);
    });

    it('selectError returns error state', () => {
      const errorMessage = 'Test error';
      store.dispatch(fetchMyJobs.rejected(new Error(errorMessage), '', undefined));
      const state = store.getState().jobs;
      
      expect(state.error).toBe(errorMessage);
    });
  });
});
