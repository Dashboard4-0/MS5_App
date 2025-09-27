/**
 * Integration tests for API service
 */

import { apiService } from '../../src/services/api';

// Mock fetch for testing
global.fetch = jest.fn();

describe('API Service Integration', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    (fetch as jest.Mock).mockClear();
  });

  describe('Authentication Integration', () => {
    it('should handle login flow', async () => {
      const mockResponse = {
        token: 'test-token',
        user: { id: '1', username: 'test', email: 'test@example.com' }
      };

      (fetch as jest.Mock).mockResolvedValueOnce({
        ok: true,
        json: async () => mockResponse,
      });

      const result = await apiService.login('test@example.com', 'password');

      expect(fetch).toHaveBeenCalledWith(
        expect.stringContaining('/api/v1/auth/login'),
        expect.objectContaining({
          method: 'POST',
          headers: expect.objectContaining({
            'Content-Type': 'application/json',
          }),
          body: JSON.stringify({
            email: 'test@example.com',
            password: 'password',
          }),
        })
      );

      expect(result).toEqual(mockResponse);
    });

    it('should handle login error', async () => {
      (fetch as jest.Mock).mockResolvedValueOnce({
        ok: false,
        status: 401,
        json: async () => ({ message: 'Invalid credentials' }),
      });

      await expect(apiService.login('test@example.com', 'wrongpassword'))
        .rejects.toThrow();
    });

    it('should handle token refresh', async () => {
      const mockResponse = { token: 'new-token' };

      (fetch as jest.Mock).mockResolvedValueOnce({
        ok: true,
        json: async () => mockResponse,
      });

      const result = await apiService.refreshToken();

      expect(fetch).toHaveBeenCalledWith(
        expect.stringContaining('/api/v1/auth/refresh'),
        expect.objectContaining({
          method: 'POST',
        })
      );

      expect(result).toEqual(mockResponse);
    });
  });

  describe('Production API Integration', () => {
    it('should fetch production lines', async () => {
      const mockLines = [
        { id: '1', name: 'Line 1', status: 'active' },
        { id: '2', name: 'Line 2', status: 'inactive' }
      ];

      (fetch as jest.Mock).mockResolvedValueOnce({
        ok: true,
        json: async () => mockLines,
      });

      const result = await apiService.getProductionLines();

      expect(fetch).toHaveBeenCalledWith(
        expect.stringContaining('/api/v1/production/lines'),
        expect.objectContaining({
          method: 'GET',
        })
      );

      expect(result).toEqual(mockLines);
    });

    it('should create production schedule', async () => {
      const scheduleData = {
        line_id: '1',
        start_time: '2024-01-01T10:00:00Z',
        end_time: '2024-01-01T18:00:00Z',
        product_type_id: '1'
      };

      const mockResponse = { id: '1', ...scheduleData };

      (fetch as jest.Mock).mockResolvedValueOnce({
        ok: true,
        json: async () => mockResponse,
      });

      const result = await apiService.createProductionSchedule(scheduleData);

      expect(fetch).toHaveBeenCalledWith(
        expect.stringContaining('/api/v1/production/schedules'),
        expect.objectContaining({
          method: 'POST',
          body: JSON.stringify(scheduleData),
        })
      );

      expect(result).toEqual(mockResponse);
    });
  });

  describe('Job Assignment Integration', () => {
    it('should fetch user jobs', async () => {
      const mockJobs = [
        { id: '1', title: 'Job 1', status: 'assigned' },
        { id: '2', title: 'Job 2', status: 'in_progress' }
      ];

      (fetch as jest.Mock).mockResolvedValueOnce({
        ok: true,
        json: async () => mockJobs,
      });

      const result = await apiService.getMyJobs();

      expect(fetch).toHaveBeenCalledWith(
        expect.stringContaining('/api/v1/jobs/my-jobs'),
        expect.objectContaining({
          method: 'GET',
        })
      );

      expect(result).toEqual(mockJobs);
    });

    it('should accept job', async () => {
      const mockResponse = { id: '1', status: 'accepted' };

      (fetch as jest.Mock).mockResolvedValueOnce({
        ok: true,
        json: async () => mockResponse,
      });

      const result = await apiService.acceptJob('1');

      expect(fetch).toHaveBeenCalledWith(
        expect.stringContaining('/api/v1/jobs/1/accept'),
        expect.objectContaining({
          method: 'POST',
        })
      );

      expect(result).toEqual(mockResponse);
    });

    it('should start job', async () => {
      const mockResponse = { id: '1', status: 'in_progress' };

      (fetch as jest.Mock).mockResolvedValueOnce({
        ok: true,
        json: async () => mockResponse,
      });

      const result = await apiService.startJob('1');

      expect(fetch).toHaveBeenCalledWith(
        expect.stringContaining('/api/v1/jobs/1/start'),
        expect.objectContaining({
          method: 'POST',
        })
      );

      expect(result).toEqual(mockResponse);
    });

    it('should complete job', async () => {
      const completionData = { notes: 'Job completed' };
      const mockResponse = { id: '1', status: 'completed' };

      (fetch as jest.Mock).mockResolvedValueOnce({
        ok: true,
        json: async () => mockResponse,
      });

      const result = await apiService.completeJob('1', completionData);

      expect(fetch).toHaveBeenCalledWith(
        expect.stringContaining('/api/v1/jobs/1/complete'),
        expect.objectContaining({
          method: 'POST',
          body: JSON.stringify(completionData),
        })
      );

      expect(result).toEqual(mockResponse);
    });
  });

  describe('OEE API Integration', () => {
    it('should fetch OEE data', async () => {
      const mockOEE = {
        oee: 0.85,
        availability: 0.9,
        performance: 0.95,
        quality: 0.95
      };

      (fetch as jest.Mock).mockResolvedValueOnce({
        ok: true,
        json: async () => mockOEE,
      });

      const result = await apiService.getOEEData('line-1');

      expect(fetch).toHaveBeenCalledWith(
        expect.stringContaining('/api/v1/oee/lines/line-1'),
        expect.objectContaining({
          method: 'GET',
        })
      );

      expect(result).toEqual(mockOEE);
    });

    it('should fetch OEE trends', async () => {
      const mockTrends = [
        { date: '2024-01-01', oee: 0.85 },
        { date: '2024-01-02', oee: 0.87 }
      ];

      (fetch as jest.Mock).mockResolvedValueOnce({
        ok: true,
        json: async () => mockTrends,
      });

      const result = await apiService.getOEETrends('line-1', 7);

      expect(fetch).toHaveBeenCalledWith(
        expect.stringContaining('/api/v1/oee/lines/line-1/trends?days=7'),
        expect.objectContaining({
          method: 'GET',
        })
      );

      expect(result).toEqual(mockTrends);
    });
  });

  describe('Andon API Integration', () => {
    it('should fetch Andon events', async () => {
      const mockEvents = [
        { id: '1', event_type: 'fault', status: 'active' },
        { id: '2', event_type: 'warning', status: 'resolved' }
      ];

      (fetch as jest.Mock).mockResolvedValueOnce({
        ok: true,
        json: async () => mockEvents,
      });

      const result = await apiService.getAndonEvents();

      expect(fetch).toHaveBeenCalledWith(
        expect.stringContaining('/api/v1/andon/events'),
        expect.objectContaining({
          method: 'GET',
        })
      );

      expect(result).toEqual(mockEvents);
    });

    it('should create Andon event', async () => {
      const eventData = {
        equipment_code: 'EQ-001',
        event_type: 'fault',
        priority: 'high',
        description: 'Equipment fault detected'
      };

      const mockResponse = { id: '1', ...eventData };

      (fetch as jest.Mock).mockResolvedValueOnce({
        ok: true,
        json: async () => mockResponse,
      });

      const result = await apiService.createAndonEvent(eventData);

      expect(fetch).toHaveBeenCalledWith(
        expect.stringContaining('/api/v1/andon/events'),
        expect.objectContaining({
          method: 'POST',
          body: JSON.stringify(eventData),
        })
      );

      expect(result).toEqual(mockResponse);
    });

    it('should acknowledge Andon event', async () => {
      const mockResponse = { id: '1', status: 'acknowledged' };

      (fetch as jest.Mock).mockResolvedValueOnce({
        ok: true,
        json: async () => mockResponse,
      });

      const result = await apiService.acknowledgeAndonEvent('1');

      expect(fetch).toHaveBeenCalledWith(
        expect.stringContaining('/api/v1/andon/events/1/acknowledge'),
        expect.objectContaining({
          method: 'POST',
        })
      );

      expect(result).toEqual(mockResponse);
    });

    it('should resolve Andon event', async () => {
      const resolutionData = { notes: 'Issue resolved' };
      const mockResponse = { id: '1', status: 'resolved' };

      (fetch as jest.Mock).mockResolvedValueOnce({
        ok: true,
        json: async () => mockResponse,
      });

      const result = await apiService.resolveAndonEvent('1', resolutionData);

      expect(fetch).toHaveBeenCalledWith(
        expect.stringContaining('/api/v1/andon/events/1/resolve'),
        expect.objectContaining({
          method: 'POST',
          body: JSON.stringify(resolutionData),
        })
      );

      expect(result).toEqual(mockResponse);
    });
  });

  describe('Error Handling Integration', () => {
    it('should handle network errors', async () => {
      (fetch as jest.Mock).mockRejectedValueOnce(new Error('Network error'));

      await expect(apiService.getProductionLines())
        .rejects.toThrow('Network error');
    });

    it('should handle HTTP errors', async () => {
      (fetch as jest.Mock).mockResolvedValueOnce({
        ok: false,
        status: 500,
        json: async () => ({ message: 'Internal server error' }),
      });

      await expect(apiService.getProductionLines())
        .rejects.toThrow();
    });

    it('should handle timeout errors', async () => {
      (fetch as jest.Mock).mockRejectedValueOnce(new Error('Request timeout'));

      await expect(apiService.getProductionLines())
        .rejects.toThrow('Request timeout');
    });

    it('should handle JSON parsing errors', async () => {
      (fetch as jest.Mock).mockResolvedValueOnce({
        ok: true,
        json: async () => { throw new Error('Invalid JSON'); },
      });

      await expect(apiService.getProductionLines())
        .rejects.toThrow();
    });
  });

  describe('Token Management Integration', () => {
    it('should include token in requests when set', async () => {
      apiService.setToken('test-token');

      (fetch as jest.Mock).mockResolvedValueOnce({
        ok: true,
        json: async () => [],
      });

      await apiService.getProductionLines();

      expect(fetch).toHaveBeenCalledWith(
        expect.any(String),
        expect.objectContaining({
          headers: expect.objectContaining({
            'Authorization': 'Bearer test-token',
          }),
        })
      );
    });

    it('should not include token when not set', async () => {
      apiService.setToken(null);

      (fetch as jest.Mock).mockResolvedValueOnce({
        ok: true,
        json: async () => [],
      });

      await apiService.getProductionLines();

      expect(fetch).toHaveBeenCalledWith(
        expect.any(String),
        expect.objectContaining({
          headers: expect.not.objectContaining({
            'Authorization': expect.any(String),
          }),
        })
      );
    });
  });

  describe('Request/Response Interceptors Integration', () => {
    it('should handle request interceptor', async () => {
      // Mock request interceptor
      const originalFetch = fetch;
      (fetch as jest.Mock).mockImplementationOnce(async (url, options) => {
        // Simulate request interceptor adding timestamp
        const modifiedOptions = {
          ...options,
          headers: {
            ...options?.headers,
            'X-Request-Time': new Date().toISOString(),
          },
        };
        return originalFetch(url, modifiedOptions);
      });

      (fetch as jest.Mock).mockResolvedValueOnce({
        ok: true,
        json: async () => [],
      });

      await apiService.getProductionLines();

      expect(fetch).toHaveBeenCalledWith(
        expect.any(String),
        expect.objectContaining({
          headers: expect.objectContaining({
            'X-Request-Time': expect.any(String),
          }),
        })
      );
    });

    it('should handle response interceptor', async () => {
      (fetch as jest.Mock).mockResolvedValueOnce({
        ok: true,
        json: async () => [],
        headers: new Headers({
          'X-Response-Time': new Date().toISOString(),
        }),
      });

      const result = await apiService.getProductionLines();

      expect(result).toEqual([]);
    });
  });
});
