/**
 * Unit tests for API service
 */

import { apiService } from '../../src/services/api';

// Mock axios
jest.mock('axios');
const axios = require('axios');

describe('ApiService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    axios.create.mockReturnValue(axios);
  });

  describe('Authentication API', () => {
    it('login calls correct endpoint', async () => {
      const mockResponse = { data: { token: 'test-token', user: { id: '1', username: 'test' } } };
      axios.post.mockResolvedValue(mockResponse);

      const result = await apiService.login('test@example.com', 'password');

      expect(axios.post).toHaveBeenCalledWith('/api/v1/auth/login', {
        email: 'test@example.com',
        password: 'password',
      });
      expect(result).toEqual(mockResponse.data);
    });

    it('logout calls correct endpoint', async () => {
      const mockResponse = { data: { message: 'Logged out successfully' } };
      axios.post.mockResolvedValue(mockResponse);

      const result = await apiService.logout();

      expect(axios.post).toHaveBeenCalledWith('/api/v1/auth/logout');
      expect(result).toEqual(mockResponse.data);
    });

    it('refreshToken calls correct endpoint', async () => {
      const mockResponse = { data: { token: 'new-token' } };
      axios.post.mockResolvedValue(mockResponse);

      const result = await apiService.refreshToken();

      expect(axios.post).toHaveBeenCalledWith('/api/v1/auth/refresh');
      expect(result).toEqual(mockResponse.data);
    });

    it('getProfile calls correct endpoint', async () => {
      const mockResponse = { data: { id: '1', username: 'test', email: 'test@example.com' } };
      axios.get.mockResolvedValue(mockResponse);

      const result = await apiService.getProfile();

      expect(axios.get).toHaveBeenCalledWith('/api/v1/auth/profile');
      expect(result).toEqual(mockResponse.data);
    });
  });

  describe('Production API', () => {
    it('getProductionLines calls correct endpoint', async () => {
      const mockResponse = { data: [{ id: '1', name: 'Line 1' }] };
      axios.get.mockResolvedValue(mockResponse);

      const result = await apiService.getProductionLines();

      expect(axios.get).toHaveBeenCalledWith('/api/v1/production/lines');
      expect(result).toEqual(mockResponse.data);
    });

    it('getProductionSchedules calls correct endpoint', async () => {
      const mockResponse = { data: [{ id: '1', line_id: '1', status: 'scheduled' }] };
      axios.get.mockResolvedValue(mockResponse);

      const result = await apiService.getProductionSchedules();

      expect(axios.get).toHaveBeenCalledWith('/api/v1/production/schedules');
      expect(result).toEqual(mockResponse.data);
    });

    it('createProductionSchedule calls correct endpoint', async () => {
      const scheduleData = { line_id: '1', start_time: '2024-01-01T10:00:00Z' };
      const mockResponse = { data: { id: '1', ...scheduleData } };
      axios.post.mockResolvedValue(mockResponse);

      const result = await apiService.createProductionSchedule(scheduleData);

      expect(axios.post).toHaveBeenCalledWith('/api/v1/production/schedules', scheduleData);
      expect(result).toEqual(mockResponse.data);
    });
  });

  describe('Job Assignment API', () => {
    it('getMyJobs calls correct endpoint', async () => {
      const mockResponse = { data: [{ id: '1', title: 'Job 1', status: 'assigned' }] };
      axios.get.mockResolvedValue(mockResponse);

      const result = await apiService.getMyJobs();

      expect(axios.get).toHaveBeenCalledWith('/api/v1/jobs/my-jobs');
      expect(result).toEqual(mockResponse.data);
    });

    it('acceptJob calls correct endpoint', async () => {
      const mockResponse = { data: { id: '1', status: 'accepted' } };
      axios.post.mockResolvedValue(mockResponse);

      const result = await apiService.acceptJob('1');

      expect(axios.post).toHaveBeenCalledWith('/api/v1/jobs/1/accept');
      expect(result).toEqual(mockResponse.data);
    });

    it('startJob calls correct endpoint', async () => {
      const mockResponse = { data: { id: '1', status: 'in_progress' } };
      axios.post.mockResolvedValue(mockResponse);

      const result = await apiService.startJob('1');

      expect(axios.post).toHaveBeenCalledWith('/api/v1/jobs/1/start');
      expect(result).toEqual(mockResponse.data);
    });

    it('completeJob calls correct endpoint', async () => {
      const completionData = { notes: 'Job completed' };
      const mockResponse = { data: { id: '1', status: 'completed' } };
      axios.post.mockResolvedValue(mockResponse);

      const result = await apiService.completeJob('1', completionData);

      expect(axios.post).toHaveBeenCalledWith('/api/v1/jobs/1/complete', completionData);
      expect(result).toEqual(mockResponse.data);
    });
  });

  describe('OEE API', () => {
    it('getOEEData calls correct endpoint', async () => {
      const mockResponse = { data: { oee: 0.85, availability: 0.9, performance: 0.95, quality: 0.95 } };
      axios.get.mockResolvedValue(mockResponse);

      const result = await apiService.getOEEData('line-1');

      expect(axios.get).toHaveBeenCalledWith('/api/v1/oee/lines/line-1');
      expect(result).toEqual(mockResponse.data);
    });

    it('getOEETrends calls correct endpoint', async () => {
      const mockResponse = { data: [{ date: '2024-01-01', oee: 0.85 }] };
      axios.get.mockResolvedValue(mockResponse);

      const result = await apiService.getOEETrends('line-1', 7);

      expect(axios.get).toHaveBeenCalledWith('/api/v1/oee/lines/line-1/trends?days=7');
      expect(result).toEqual(mockResponse.data);
    });
  });

  describe('Andon API', () => {
    it('getAndonEvents calls correct endpoint', async () => {
      const mockResponse = { data: [{ id: '1', event_type: 'fault', status: 'active' }] };
      axios.get.mockResolvedValue(mockResponse);

      const result = await apiService.getAndonEvents();

      expect(axios.get).toHaveBeenCalledWith('/api/v1/andon/events');
      expect(result).toEqual(mockResponse.data);
    });

    it('createAndonEvent calls correct endpoint', async () => {
      const eventData = { equipment_code: 'EQ-001', event_type: 'fault', priority: 'high' };
      const mockResponse = { data: { id: '1', ...eventData } };
      axios.post.mockResolvedValue(mockResponse);

      const result = await apiService.createAndonEvent(eventData);

      expect(axios.post).toHaveBeenCalledWith('/api/v1/andon/events', eventData);
      expect(result).toEqual(mockResponse.data);
    });

    it('acknowledgeAndonEvent calls correct endpoint', async () => {
      const mockResponse = { data: { id: '1', status: 'acknowledged' } };
      axios.post.mockResolvedValue(mockResponse);

      const result = await apiService.acknowledgeAndonEvent('1');

      expect(axios.post).toHaveBeenCalledWith('/api/v1/andon/events/1/acknowledge');
      expect(result).toEqual(mockResponse.data);
    });

    it('resolveAndonEvent calls correct endpoint', async () => {
      const resolutionData = { notes: 'Issue resolved' };
      const mockResponse = { data: { id: '1', status: 'resolved' } };
      axios.post.mockResolvedValue(mockResponse);

      const result = await apiService.resolveAndonEvent('1', resolutionData);

      expect(axios.post).toHaveBeenCalledWith('/api/v1/andon/events/1/resolve', resolutionData);
      expect(result).toEqual(mockResponse.data);
    });
  });

  describe('Error Handling', () => {
    it('handles network errors gracefully', async () => {
      const networkError = new Error('Network Error');
      axios.get.mockRejectedValue(networkError);

      await expect(apiService.getProductionLines()).rejects.toThrow('Network Error');
    });

    it('handles API errors gracefully', async () => {
      const apiError = {
        response: {
          status: 400,
          data: { message: 'Bad Request' }
        }
      };
      axios.get.mockRejectedValue(apiError);

      await expect(apiService.getProductionLines()).rejects.toThrow();
    });

    it('handles timeout errors gracefully', async () => {
      const timeoutError = new Error('Request timeout');
      axios.get.mockRejectedValue(timeoutError);

      await expect(apiService.getProductionLines()).rejects.toThrow('Request timeout');
    });
  });

  describe('Token Management', () => {
    it('sets token correctly', () => {
      apiService.setToken('test-token');
      expect(axios.defaults.headers.common['Authorization']).toBe('Bearer test-token');
    });

    it('clears token correctly', () => {
      apiService.setToken(null);
      expect(axios.defaults.headers.common['Authorization']).toBeUndefined();
    });
  });
});
