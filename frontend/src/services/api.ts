/**
 * MS5.0 Floor Dashboard - API Service
 * 
 * This service handles all HTTP requests to the MS5.0 backend API
 * with proper error handling, authentication, and caching.
 */

import axios, { AxiosInstance, AxiosRequestConfig, AxiosResponse, AxiosError } from 'axios';
import AsyncStorage from '@react-native-async-storage/async-storage';
import NetInfo from '@react-native-netinfo/netinfo';
import { API_CONFIGURATION, INTERCEPTORS, CACHE_CONFIGURATION } from '../config/api';
import { STORAGE_KEYS } from '../config/constants';
import { showToast } from '../utils/toast';
import { logger } from '../utils/logger';

// Types
interface RequestConfig extends AxiosRequestConfig {
  skipAuth?: boolean;
  skipCache?: boolean;
  cacheKey?: string;
  retryCount?: number;
}

interface CacheEntry {
  data: any;
  timestamp: number;
  ttl: number;
}

interface ApiResponse<T = any> {
  data: T;
  success: boolean;
  message?: string;
  timestamp: string;
}

class ApiService {
  private client: AxiosInstance;
  private cache: Map<string, CacheEntry> = new Map();
  private isOnline: boolean = true;
  private pendingRequests: Map<string, Promise<any>> = new Map();

  constructor() {
    this.client = this.createClient();
    this.setupInterceptors();
    this.setupNetworkListener();
  }

  private createClient(): AxiosInstance {
    return axios.create({
      baseURL: API_CONFIGURATION.baseURL,
      timeout: API_CONFIGURATION.timeout,
      headers: API_CONFIGURATION.headers,
    });
  }

  private setupInterceptors(): void {
    // Request interceptor
    this.client.interceptors.request.use(
      async (config) => {
        // Add authentication token
        if (INTERCEPTORS.REQUEST.ADD_AUTH_TOKEN && !config.skipAuth) {
          const token = await this.getAuthToken();
          if (token) {
            config.headers.Authorization = `Bearer ${token}`;
          }
        }

        // Add timestamp
        if (INTERCEPTORS.REQUEST.ADD_TIMESTAMP) {
          config.headers['X-Timestamp'] = Date.now().toString();
        }

        // Add request ID
        if (INTERCEPTORS.REQUEST.ADD_REQUEST_ID) {
          config.headers['X-Request-ID'] = this.generateRequestId();
        }

        // Log requests in development
        if (INTERCEPTORS.REQUEST.LOG_REQUESTS && __DEV__) {
          logger.debug('API Request', {
            method: config.method?.toUpperCase(),
            url: config.url,
            headers: config.headers,
            data: config.data,
          });
        }

        return config;
      },
      (error) => {
        logger.error('Request interceptor error', error);
        return Promise.reject(error);
      }
    );

    // Response interceptor
    this.client.interceptors.response.use(
      (response) => {
        // Log responses in development
        if (INTERCEPTORS.RESPONSE.LOG_RESPONSES && __DEV__) {
          logger.debug('API Response', {
            status: response.status,
            url: response.config.url,
            data: response.data,
          });
        }

        return response;
      },
      async (error: AxiosError) => {
        // Handle errors
        if (INTERCEPTORS.RESPONSE.HANDLE_ERRORS) {
          await this.handleError(error);
        }

        // Retry on failure
        if (INTERCEPTORS.RESPONSE.RETRY_ON_FAILURE && this.shouldRetry(error)) {
          return this.retryRequest(error.config as RequestConfig);
        }

        return Promise.reject(error);
      }
    );
  }

  private setupNetworkListener(): void {
    NetInfo.addEventListener(state => {
      this.isOnline = state.isConnected ?? false;
      logger.info('Network status changed', { isOnline: this.isOnline });
    });
  }

  private async getAuthToken(): Promise<string | null> {
    try {
      return await AsyncStorage.getItem(STORAGE_KEYS.AUTH_TOKEN);
    } catch (error) {
      logger.error('Failed to get auth token', error);
      return null;
    }
  }

  private generateRequestId(): string {
    return `req_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  private shouldRetry(error: AxiosError): boolean {
    if (!error.config) return false;
    
    const config = error.config as RequestConfig;
    const retryCount = config.retryCount || 0;
    
    return (
      retryCount < API_CONFIGURATION.retryAttempts &&
      (error.code === 'NETWORK_ERROR' || 
       error.response?.status === 500 ||
       error.response?.status === 502 ||
       error.response?.status === 503 ||
       error.response?.status === 504)
    );
  }

  private async retryRequest(config: RequestConfig): Promise<any> {
    const retryCount = (config.retryCount || 0) + 1;
    const delay = API_CONFIGURATION.retryDelay * Math.pow(2, retryCount - 1);
    
    logger.info('Retrying request', { 
      url: config.url, 
      retryCount, 
      delay 
    });

    await new Promise(resolve => setTimeout(resolve, delay));
    
    return this.request({
      ...config,
      retryCount,
    });
  }

  private async handleError(error: AxiosError): Promise<void> {
    const { response, request, message } = error;
    
    if (response) {
      // Server responded with error status
      const { status, data } = response;
      
      switch (status) {
        case 401:
          await this.handleUnauthorized();
          break;
        case 403:
          showToast('You do not have permission to perform this action', 'error');
          break;
        case 404:
          showToast('Resource not found', 'error');
          break;
        case 422:
          showToast('Please check your input and try again', 'error');
          break;
        case 500:
          showToast('Server error. Please try again later', 'error');
          break;
        default:
          showToast('An error occurred. Please try again', 'error');
      }
      
      logger.error('API Error Response', {
        status,
        data,
        url: response.config?.url,
      });
    } else if (request) {
      // Request was made but no response received
      if (!this.isOnline) {
        showToast('No internet connection. Please check your network.', 'error');
      } else {
        showToast('Network error. Please try again.', 'error');
      }
      
      logger.error('API Network Error', {
        message,
        url: request.url,
      });
    } else {
      // Something else happened
      logger.error('API Unknown Error', { message });
      showToast('An unexpected error occurred', 'error');
    }
  }

  private async handleUnauthorized(): Promise<void> {
    try {
      // Try to refresh token
      const refreshToken = await AsyncStorage.getItem(STORAGE_KEYS.REFRESH_TOKEN);
      if (refreshToken) {
        const response = await this.post('/api/v1/auth/refresh', {
          refresh_token: refreshToken,
        });
        
        if (response.success) {
          await AsyncStorage.setItem(STORAGE_KEYS.AUTH_TOKEN, response.data.access_token);
          return;
        }
      }
      
      // If refresh fails, clear tokens and redirect to login
      await this.clearAuthTokens();
      // TODO: Navigate to login screen
      
    } catch (error) {
      logger.error('Token refresh failed', error);
      await this.clearAuthTokens();
      // TODO: Navigate to login screen
    }
  }

  private async clearAuthTokens(): Promise<void> {
    try {
      await AsyncStorage.multiRemove([
        STORAGE_KEYS.AUTH_TOKEN,
        STORAGE_KEYS.REFRESH_TOKEN,
        STORAGE_KEYS.USER_DATA,
      ]);
    } catch (error) {
      logger.error('Failed to clear auth tokens', error);
    }
  }

  private getCacheKey(config: RequestConfig): string {
    if (config.cacheKey) return config.cacheKey;
    
    const { method = 'GET', url, params, data } = config;
    return `${method}:${url}:${JSON.stringify(params || {})}:${JSON.stringify(data || {})}`;
  }

  private getCachedData(key: string): any | null {
    if (!CACHE_CONFIGURATION.ENABLED) return null;
    
    const entry = this.cache.get(key);
    if (!entry) return null;
    
    const now = Date.now();
    if (now - entry.timestamp > entry.ttl) {
      this.cache.delete(key);
      return null;
    }
    
    return entry.data;
  }

  private setCachedData(key: string, data: any, ttl: number = CACHE_CONFIGURATION.DEFAULT_TTL): void {
    if (!CACHE_CONFIGURATION.ENABLED) return;
    
    this.cache.set(key, {
      data,
      timestamp: Date.now(),
      ttl,
    });
  }

  private async request<T = any>(config: RequestConfig): Promise<ApiResponse<T>> {
    const cacheKey = this.getCacheKey(config);
    
    // Check cache first
    if (!config.skipCache && config.method?.toLowerCase() === 'get') {
      const cachedData = this.getCachedData(cacheKey);
      if (cachedData) {
        logger.debug('Cache hit', { key: cacheKey });
        return cachedData;
      }
    }

    // Check if request is already pending
    if (this.pendingRequests.has(cacheKey)) {
      logger.debug('Request already pending', { key: cacheKey });
      return this.pendingRequests.get(cacheKey)!;
    }

    // Make request
    const requestPromise = this.client.request<T>(config)
      .then((response: AxiosResponse<T>) => {
        const apiResponse: ApiResponse<T> = {
          data: response.data,
          success: true,
          timestamp: new Date().toISOString(),
        };

        // Cache successful GET requests
        if (!config.skipCache && config.method?.toLowerCase() === 'get') {
          this.setCachedData(cacheKey, apiResponse);
        }

        return apiResponse;
      })
      .catch((error: AxiosError) => {
        const apiResponse: ApiResponse<T> = {
          data: null as T,
          success: false,
          message: error.message,
          timestamp: new Date().toISOString(),
        };

        return apiResponse;
      })
      .finally(() => {
        this.pendingRequests.delete(cacheKey);
      });

    this.pendingRequests.set(cacheKey, requestPromise);
    return requestPromise;
  }

  // Public methods
  async get<T = any>(url: string, config?: RequestConfig): Promise<ApiResponse<T>> {
    return this.request<T>({ ...config, method: 'GET', url });
  }

  async post<T = any>(url: string, data?: any, config?: RequestConfig): Promise<ApiResponse<T>> {
    return this.request<T>({ ...config, method: 'POST', url, data });
  }

  async put<T = any>(url: string, data?: any, config?: RequestConfig): Promise<ApiResponse<T>> {
    return this.request<T>({ ...config, method: 'PUT', url, data });
  }

  async patch<T = any>(url: string, data?: any, config?: RequestConfig): Promise<ApiResponse<T>> {
    return this.request<T>({ ...config, method: 'PATCH', url, data });
  }

  async delete<T = any>(url: string, config?: RequestConfig): Promise<ApiResponse<T>> {
    return this.request<T>({ ...config, method: 'DELETE', url });
  }

  // Utility methods
  clearCache(): void {
    this.cache.clear();
    logger.info('Cache cleared');
  }

  getCacheSize(): number {
    return this.cache.size;
  }

  isConnected(): boolean {
    return this.isOnline;
  }

  // File upload
  async uploadFile<T = any>(
    url: string, 
    file: { uri: string; type: string; name: string }, 
    data?: any,
    config?: RequestConfig
  ): Promise<ApiResponse<T>> {
    const formData = new FormData();
    formData.append('file', {
      uri: file.uri,
      type: file.type,
      name: file.name,
    } as any);

    if (data) {
      Object.keys(data).forEach(key => {
        formData.append(key, data[key]);
      });
    }

    return this.request<T>({
      ...config,
      method: 'POST',
      url,
      data: formData,
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    });
  }

  // ============================================================================
  // AUTHENTICATION API
  // ============================================================================

  async login(credentials: { username: string; password: string }): Promise<ApiResponse<{
    access_token: string;
    refresh_token: string;
    user: any;
  }>> {
    return this.post('/api/v1/auth/login', credentials, { skipAuth: true });
  }

  async logout(): Promise<ApiResponse<void>> {
    return this.post('/api/v1/auth/logout');
  }

  async refreshToken(refreshToken: string): Promise<ApiResponse<{
    access_token: string;
    refresh_token: string;
  }>> {
    return this.post('/api/v1/auth/refresh', { refresh_token: refreshToken }, { skipAuth: true });
  }

  async getCurrentUser(): Promise<ApiResponse<any>> {
    return this.get('/api/v1/auth/me');
  }

  async updateProfile(profileData: any): Promise<ApiResponse<any>> {
    return this.put('/api/v1/auth/profile', profileData);
  }

  async changePassword(passwordData: { current_password: string; new_password: string }): Promise<ApiResponse<void>> {
    return this.post('/api/v1/auth/change-password', passwordData);
  }

  // ============================================================================
  // PRODUCTION API
  // ============================================================================

  async getProductionLines(filters?: { status?: string; enabled?: boolean }): Promise<ApiResponse<any[]>> {
    const params = new URLSearchParams();
    if (filters?.status) params.append('status', filters.status);
    if (filters?.enabled !== undefined) params.append('enabled', filters.enabled.toString());
    
    return this.get(`/api/v1/production/lines?${params.toString()}`);
  }

  async getProductionLine(lineId: string): Promise<ApiResponse<any>> {
    return this.get(`/api/v1/production/lines/${lineId}`);
  }

  async createProductionLine(lineData: any): Promise<ApiResponse<any>> {
    return this.post('/api/v1/production/lines', lineData);
  }

  async updateProductionLine(lineId: string, lineData: any): Promise<ApiResponse<any>> {
    return this.put(`/api/v1/production/lines/${lineId}`, lineData);
  }

  async deleteProductionLine(lineId: string): Promise<ApiResponse<void>> {
    return this.delete(`/api/v1/production/lines/${lineId}`);
  }

  async getProductionSchedules(lineId?: string): Promise<ApiResponse<any[]>> {
    const url = lineId ? `/api/v1/production/schedules?line_id=${lineId}` : '/api/v1/production/schedules';
    return this.get(url);
  }

  async getProductionSchedule(scheduleId: string): Promise<ApiResponse<any>> {
    return this.get(`/api/v1/production/schedules/${scheduleId}`);
  }

  async createProductionSchedule(scheduleData: any): Promise<ApiResponse<any>> {
    return this.post('/api/v1/production/schedules', scheduleData);
  }

  async updateProductionSchedule(scheduleId: string, scheduleData: any): Promise<ApiResponse<any>> {
    return this.put(`/api/v1/production/schedules/${scheduleId}`, scheduleData);
  }

  async deleteProductionSchedule(scheduleId: string): Promise<ApiResponse<void>> {
    return this.delete(`/api/v1/production/schedules/${scheduleId}`);
  }

  // ============================================================================
  // JOB ASSIGNMENT API
  // ============================================================================

  async getMyJobs(): Promise<ApiResponse<any[]>> {
    return this.get('/api/v1/production/job-assignments');
  }

  async getJobAssignment(assignmentId: string): Promise<ApiResponse<any>> {
    return this.get(`/api/v1/production/job-assignments/${assignmentId}`);
  }

  async createJobAssignment(assignmentData: any): Promise<ApiResponse<any>> {
    return this.post('/api/v1/production/job-assignments', assignmentData);
  }

  async updateJobAssignment(assignmentId: string, assignmentData: any): Promise<ApiResponse<any>> {
    return this.put(`/api/v1/production/job-assignments/${assignmentId}`, assignmentData);
  }

  async acceptJob(assignmentId: string): Promise<ApiResponse<any>> {
    return this.post(`/api/v1/production/job-assignments/${assignmentId}/accept`);
  }

  async startJob(assignmentId: string): Promise<ApiResponse<any>> {
    return this.post(`/api/v1/production/job-assignments/${assignmentId}/start`);
  }

  async completeJob(assignmentId: string): Promise<ApiResponse<any>> {
    return this.post(`/api/v1/production/job-assignments/${assignmentId}/complete`);
  }

  // ============================================================================
  // DASHBOARD API
  // ============================================================================

  async getLineStatus(lineId: string): Promise<ApiResponse<any>> {
    return this.get(`/api/v1/dashboard/lines/${lineId}/status`);
  }

  async getEquipmentStatus(equipmentCode: string): Promise<ApiResponse<any>> {
    return this.get(`/api/v1/dashboard/equipment/${equipmentCode}/status`);
  }

  async getDashboardMetrics(filters?: { lineId?: string; period?: string }): Promise<ApiResponse<any>> {
    const params = new URLSearchParams();
    if (filters?.lineId) params.append('line_id', filters.lineId);
    if (filters?.period) params.append('period', filters.period);
    
    return this.get(`/api/v1/dashboard/metrics?${params.toString()}`);
  }

  async getProductionSummary(filters?: { lineId?: string; dateRange?: { start: string; end: string } }): Promise<ApiResponse<any>> {
    const params = new URLSearchParams();
    if (filters?.lineId) params.append('line_id', filters.lineId);
    if (filters?.dateRange) {
      params.append('start_date', filters.dateRange.start);
      params.append('end_date', filters.dateRange.end);
    }
    
    return this.get(`/api/v1/dashboard/production-summary?${params.toString()}`);
  }

  // ============================================================================
  // ANDON API
  // ============================================================================

  async getAndonEvents(filters?: { status?: string; priority?: string; lineId?: string }): Promise<ApiResponse<any[]>> {
    const params = new URLSearchParams();
    if (filters?.status) params.append('status', filters.status);
    if (filters?.priority) params.append('priority', filters.priority);
    if (filters?.lineId) params.append('line_id', filters.lineId);
    
    return this.get(`/api/v1/andon/events?${params.toString()}`);
  }

  async getAndonEvent(eventId: string): Promise<ApiResponse<any>> {
    return this.get(`/api/v1/andon/events/${eventId}`);
  }

  async createAndonEvent(eventData: any): Promise<ApiResponse<any>> {
    return this.post('/api/v1/andon/events', eventData);
  }

  async acknowledgeAndonEvent(eventId: string): Promise<ApiResponse<any>> {
    return this.post(`/api/v1/andon/events/${eventId}/acknowledge`);
  }

  async resolveAndonEvent(eventId: string, resolutionNotes: string): Promise<ApiResponse<any>> {
    return this.post(`/api/v1/andon/events/${eventId}/resolve`, { resolution_notes: resolutionNotes });
  }

  // ============================================================================
  // OEE API
  // ============================================================================

  async getOEEData(lineId: string, filters?: { period?: string; granularity?: string }): Promise<ApiResponse<any>> {
    const params = new URLSearchParams();
    if (filters?.period) params.append('period', filters.period);
    if (filters?.granularity) params.append('granularity', filters.granularity);
    
    return this.get(`/api/v1/oee/lines/${lineId}?${params.toString()}`);
  }

  async getOEEHistory(lineId: string, filters?: { startDate: string; endDate: string; granularity?: string }): Promise<ApiResponse<any[]>> {
    const params = new URLSearchParams();
    params.append('start_date', filters?.startDate || '');
    params.append('end_date', filters?.endDate || '');
    if (filters?.granularity) params.append('granularity', filters.granularity);
    
    return this.get(`/api/v1/oee/lines/${lineId}/history?${params.toString()}`);
  }

  async getOEEBreakdown(lineId: string, filters?: { period?: string }): Promise<ApiResponse<any>> {
    const params = new URLSearchParams();
    if (filters?.period) params.append('period', filters.period);
    
    return this.get(`/api/v1/oee/lines/${lineId}/breakdown?${params.toString()}`);
  }

  // ============================================================================
  // EQUIPMENT API
  // ============================================================================

  async getEquipment(filters?: { status?: string; type?: string; lineId?: string; criticalityLevel?: number }): Promise<ApiResponse<any[]>> {
    const params = new URLSearchParams();
    if (filters?.status) params.append('status', filters.status);
    if (filters?.type) params.append('type', filters.type);
    if (filters?.lineId) params.append('line_id', filters.lineId);
    if (filters?.criticalityLevel) params.append('criticality_level', filters.criticalityLevel.toString());
    
    return this.get(`/api/v1/equipment?${params.toString()}`);
  }

  async getEquipmentById(equipmentId: string): Promise<ApiResponse<any>> {
    return this.get(`/api/v1/equipment/${equipmentId}`);
  }

  async updateEquipment(equipmentId: string, updateData: any): Promise<ApiResponse<any>> {
    return this.put(`/api/v1/equipment/${equipmentId}`, updateData);
  }

  async getMaintenanceSchedules(filters?: { equipmentId?: string; status?: string; priority?: string }): Promise<ApiResponse<any[]>> {
    const params = new URLSearchParams();
    if (filters?.equipmentId) params.append('equipment_id', filters.equipmentId);
    if (filters?.status) params.append('status', filters.status);
    if (filters?.priority) params.append('priority', filters.priority);
    
    return this.get(`/api/v1/equipment/maintenance-schedules?${params.toString()}`);
  }

  async getMaintenanceSchedule(scheduleId: string): Promise<ApiResponse<any>> {
    return this.get(`/api/v1/equipment/maintenance-schedules/${scheduleId}`);
  }

  async createMaintenanceSchedule(scheduleData: any): Promise<ApiResponse<any>> {
    return this.post('/api/v1/equipment/maintenance-schedules', scheduleData);
  }

  async updateMaintenanceSchedule(scheduleId: string, scheduleData: any): Promise<ApiResponse<any>> {
    return this.put(`/api/v1/equipment/maintenance-schedules/${scheduleId}`, scheduleData);
  }

  async completeMaintenance(scheduleId: string, actualDuration: number, notes?: string): Promise<ApiResponse<any>> {
    return this.post(`/api/v1/equipment/maintenance-schedules/${scheduleId}/complete`, {
      actual_duration: actualDuration,
      notes,
    });
  }

  async getEquipmentFaults(filters?: { equipmentId?: string; status?: string; severity?: string }): Promise<ApiResponse<any[]>> {
    const params = new URLSearchParams();
    if (filters?.equipmentId) params.append('equipment_id', filters.equipmentId);
    if (filters?.status) params.append('status', filters.status);
    if (filters?.severity) params.append('severity', filters.severity);
    
    return this.get(`/api/v1/equipment/faults?${params.toString()}`);
  }

  async getEquipmentFault(faultId: string): Promise<ApiResponse<any>> {
    return this.get(`/api/v1/equipment/faults/${faultId}`);
  }

  async acknowledgeFault(faultId: string): Promise<ApiResponse<any>> {
    return this.post(`/api/v1/equipment/faults/${faultId}/acknowledge`);
  }

  async resolveFault(faultId: string, resolutionNotes: string): Promise<ApiResponse<any>> {
    return this.post(`/api/v1/equipment/faults/${faultId}/resolve`, { resolution_notes: resolutionNotes });
  }

  // ============================================================================
  // REPORTS API
  // ============================================================================

  async getReportTemplates(filters?: { category?: string; type?: string; isActive?: boolean }): Promise<ApiResponse<any[]>> {
    const params = new URLSearchParams();
    if (filters?.category) params.append('category', filters.category);
    if (filters?.type) params.append('type', filters.type);
    if (filters?.isActive !== undefined) params.append('is_active', filters.isActive.toString());
    
    return this.get(`/api/v1/reports/templates?${params.toString()}`);
  }

  async getReportTemplate(templateId: string): Promise<ApiResponse<any>> {
    return this.get(`/api/v1/reports/templates/${templateId}`);
  }

  async createReportTemplate(templateData: any): Promise<ApiResponse<any>> {
    return this.post('/api/v1/reports/templates', templateData);
  }

  async updateReportTemplate(templateId: string, templateData: any): Promise<ApiResponse<any>> {
    return this.put(`/api/v1/reports/templates/${templateId}`, templateData);
  }

  async deleteReportTemplate(templateId: string): Promise<ApiResponse<void>> {
    return this.delete(`/api/v1/reports/templates/${templateId}`);
  }

  async getReports(filters?: { status?: string; category?: string; type?: string; dateRange?: { start: string; end: string } }): Promise<ApiResponse<any[]>> {
    const params = new URLSearchParams();
    if (filters?.status) params.append('status', filters.status);
    if (filters?.category) params.append('category', filters.category);
    if (filters?.type) params.append('type', filters.type);
    if (filters?.dateRange) {
      params.append('start_date', filters.dateRange.start);
      params.append('end_date', filters.dateRange.end);
    }
    
    return this.get(`/api/v1/reports?${params.toString()}`);
  }

  async getReport(reportId: string): Promise<ApiResponse<any>> {
    return this.get(`/api/v1/reports/${reportId}`);
  }

  async generateReport(templateId: string, parameters: Record<string, any>, name: string, description?: string): Promise<ApiResponse<any>> {
    return this.post('/api/v1/reports/generate', {
      template_id: templateId,
      parameters,
      name,
      description,
    });
  }

  async downloadReport(reportId: string): Promise<ApiResponse<{ fileUrl: string }>> {
    return this.get(`/api/v1/reports/${reportId}/download`);
  }

  async deleteReport(reportId: string): Promise<ApiResponse<void>> {
    return this.delete(`/api/v1/reports/${reportId}`);
  }

  async getScheduledReports(filters?: { isActive?: boolean }): Promise<ApiResponse<any[]>> {
    const params = new URLSearchParams();
    if (filters?.isActive !== undefined) params.append('is_active', filters.isActive.toString());
    
    return this.get(`/api/v1/reports/scheduled?${params.toString()}`);
  }

  async getScheduledReport(scheduledReportId: string): Promise<ApiResponse<any>> {
    return this.get(`/api/v1/reports/scheduled/${scheduledReportId}`);
  }

  async createScheduledReport(scheduledReportData: any): Promise<ApiResponse<any>> {
    return this.post('/api/v1/reports/scheduled', scheduledReportData);
  }

  async updateScheduledReport(scheduledReportId: string, scheduledReportData: any): Promise<ApiResponse<any>> {
    return this.put(`/api/v1/reports/scheduled/${scheduledReportId}`, scheduledReportData);
  }

  async deleteScheduledReport(scheduledReportId: string): Promise<ApiResponse<void>> {
    return this.delete(`/api/v1/reports/scheduled/${scheduledReportId}`);
  }

  async toggleScheduledReport(scheduledReportId: string): Promise<ApiResponse<any>> {
    return this.post(`/api/v1/reports/scheduled/${scheduledReportId}/toggle`);
  }

  async getReportData(reportId: string): Promise<ApiResponse<any>> {
    return this.get(`/api/v1/reports/${reportId}/data`);
  }

  // ============================================================================
  // QUALITY API
  // ============================================================================

  async getQualityChecks(filters?: { lineId?: string; checkType?: string; isActive?: boolean }): Promise<ApiResponse<any[]>> {
    const params = new URLSearchParams();
    if (filters?.lineId) params.append('line_id', filters.lineId);
    if (filters?.checkType) params.append('check_type', filters.checkType);
    if (filters?.isActive !== undefined) params.append('is_active', filters.isActive.toString());
    
    return this.get(`/api/v1/quality/checks?${params.toString()}`);
  }

  async getQualityCheck(checkId: string): Promise<ApiResponse<any>> {
    return this.get(`/api/v1/quality/checks/${checkId}`);
  }

  async createQualityCheck(checkData: any): Promise<ApiResponse<any>> {
    return this.post('/api/v1/quality/checks', checkData);
  }

  async updateQualityCheck(checkId: string, checkData: any): Promise<ApiResponse<any>> {
    return this.put(`/api/v1/quality/checks/${checkId}`, checkData);
  }

  async deleteQualityCheck(checkId: string): Promise<ApiResponse<void>> {
    return this.delete(`/api/v1/quality/checks/${checkId}`);
  }

  async getQualityInspections(filters?: { lineId?: string; checkId?: string; status?: string; dateRange?: { start: string; end: string } }): Promise<ApiResponse<any[]>> {
    const params = new URLSearchParams();
    if (filters?.lineId) params.append('line_id', filters.lineId);
    if (filters?.checkId) params.append('check_id', filters.checkId);
    if (filters?.status) params.append('status', filters.status);
    if (filters?.dateRange) {
      params.append('start_date', filters.dateRange.start);
      params.append('end_date', filters.dateRange.end);
    }
    
    return this.get(`/api/v1/quality/inspections?${params.toString()}`);
  }

  async getQualityInspection(inspectionId: string): Promise<ApiResponse<any>> {
    return this.get(`/api/v1/quality/inspections/${inspectionId}`);
  }

  async createQualityInspection(inspectionData: any): Promise<ApiResponse<any>> {
    return this.post('/api/v1/quality/inspections', inspectionData);
  }

  async updateQualityInspection(inspectionId: string, inspectionData: any): Promise<ApiResponse<any>> {
    return this.put(`/api/v1/quality/inspections/${inspectionId}`, inspectionData);
  }

  async completeQualityInspection(inspectionId: string, results: any[], overallResult: string, score?: number, notes?: string): Promise<ApiResponse<any>> {
    return this.post(`/api/v1/quality/inspections/${inspectionId}/complete`, {
      results,
      overall_result: overallResult,
      score,
      notes,
    });
  }

  async approveQualityInspection(inspectionId: string): Promise<ApiResponse<any>> {
    return this.post(`/api/v1/quality/inspections/${inspectionId}/approve`);
  }

  async rejectQualityInspection(inspectionId: string, rejectionReason: string): Promise<ApiResponse<any>> {
    return this.post(`/api/v1/quality/inspections/${inspectionId}/reject`, { rejection_reason: rejectionReason });
  }

  async getQualityDefects(filters?: { lineId?: string; defectCategory?: string; severity?: string; status?: string; dateRange?: { start: string; end: string } }): Promise<ApiResponse<any[]>> {
    const params = new URLSearchParams();
    if (filters?.lineId) params.append('line_id', filters.lineId);
    if (filters?.defectCategory) params.append('defect_category', filters.defectCategory);
    if (filters?.severity) params.append('severity', filters.severity);
    if (filters?.status) params.append('status', filters.status);
    if (filters?.dateRange) {
      params.append('start_date', filters.dateRange.start);
      params.append('end_date', filters.dateRange.end);
    }
    
    return this.get(`/api/v1/quality/defects?${params.toString()}`);
  }

  async getQualityDefect(defectId: string): Promise<ApiResponse<any>> {
    return this.get(`/api/v1/quality/defects/${defectId}`);
  }

  async createQualityDefect(defectData: any): Promise<ApiResponse<any>> {
    return this.post('/api/v1/quality/defects', defectData);
  }

  async updateQualityDefect(defectId: string, defectData: any): Promise<ApiResponse<any>> {
    return this.put(`/api/v1/quality/defects/${defectId}`, defectData);
  }

  async resolveQualityDefect(defectId: string, resolutionNotes: string): Promise<ApiResponse<any>> {
    return this.post(`/api/v1/quality/defects/${defectId}/resolve`, { resolution_notes: resolutionNotes });
  }

  async getQualityAlerts(filters?: { status?: string; severity?: string; lineId?: string }): Promise<ApiResponse<any[]>> {
    const params = new URLSearchParams();
    if (filters?.status) params.append('status', filters.status);
    if (filters?.severity) params.append('severity', filters.severity);
    if (filters?.lineId) params.append('line_id', filters.lineId);
    
    return this.get(`/api/v1/quality/alerts?${params.toString()}`);
  }

  async acknowledgeQualityAlert(alertId: string): Promise<ApiResponse<any>> {
    return this.post(`/api/v1/quality/alerts/${alertId}/acknowledge`);
  }

  async resolveQualityAlert(alertId: string, resolutionNotes: string): Promise<ApiResponse<any>> {
    return this.post(`/api/v1/quality/alerts/${alertId}/resolve`, { resolution_notes: resolutionNotes });
  }

  async getQualityMetrics(lineId: string, productTypeId?: string, period: { start: string; end: string }): Promise<ApiResponse<any>> {
    const params = new URLSearchParams();
    params.append('start_date', period.start);
    params.append('end_date', period.end);
    if (productTypeId) params.append('product_type_id', productTypeId);
    
    return this.get(`/api/v1/quality/metrics/${lineId}?${params.toString()}`);
  }

  // ============================================================================
  // DOWNTIME API
  // ============================================================================

  async getDowntimeEvents(filters?: { lineId?: string; equipmentCode?: string; status?: string; dateRange?: { start: string; end: string } }): Promise<ApiResponse<any[]>> {
    const params = new URLSearchParams();
    if (filters?.lineId) params.append('line_id', filters.lineId);
    if (filters?.equipmentCode) params.append('equipment_code', filters.equipmentCode);
    if (filters?.status) params.append('status', filters.status);
    if (filters?.dateRange) {
      params.append('start_date', filters.dateRange.start);
      params.append('end_date', filters.dateRange.end);
    }
    
    return this.get(`/api/v1/downtime/events?${params.toString()}`);
  }

  async getDowntimeEvent(eventId: string): Promise<ApiResponse<any>> {
    return this.get(`/api/v1/downtime/events/${eventId}`);
  }

  async createDowntimeEvent(eventData: any): Promise<ApiResponse<any>> {
    return this.post('/api/v1/downtime/events', eventData);
  }

  async updateDowntimeEvent(eventId: string, eventData: any): Promise<ApiResponse<any>> {
    return this.put(`/api/v1/downtime/events/${eventId}`, eventData);
  }

  async endDowntimeEvent(eventId: string, endTime: string, notes?: string): Promise<ApiResponse<any>> {
    return this.post(`/api/v1/downtime/events/${eventId}/end`, {
      end_time: endTime,
      notes,
    });
  }

  async confirmDowntimeEvent(eventId: string, confirmedBy: string, notes?: string): Promise<ApiResponse<any>> {
    return this.post(`/api/v1/downtime/events/${eventId}/confirm`, {
      confirmed_by: confirmedBy,
      notes,
    });
  }

  // ============================================================================
  // CHECKLIST API
  // ============================================================================

  async getChecklists(filters?: { lineId?: string; equipmentCode?: string; isActive?: boolean }): Promise<ApiResponse<any[]>> {
    const params = new URLSearchParams();
    if (filters?.lineId) params.append('line_id', filters.lineId);
    if (filters?.equipmentCode) params.append('equipment_code', filters.equipmentCode);
    if (filters?.isActive !== undefined) params.append('is_active', filters.isActive.toString());
    
    return this.get(`/api/v1/checklists?${params.toString()}`);
  }

  async getChecklist(checklistId: string): Promise<ApiResponse<any>> {
    return this.get(`/api/v1/checklists/${checklistId}`);
  }

  async createChecklist(checklistData: any): Promise<ApiResponse<any>> {
    return this.post('/api/v1/checklists', checklistData);
  }

  async updateChecklist(checklistId: string, checklistData: any): Promise<ApiResponse<any>> {
    return this.put(`/api/v1/checklists/${checklistId}`, checklistData);
  }

  async deleteChecklist(checklistId: string): Promise<ApiResponse<void>> {
    return this.delete(`/api/v1/checklists/${checklistId}`);
  }

  async getChecklistInstances(filters?: { checklistId?: string; status?: string; assignedTo?: string; dateRange?: { start: string; end: string } }): Promise<ApiResponse<any[]>> {
    const params = new URLSearchParams();
    if (filters?.checklistId) params.append('checklist_id', filters.checklistId);
    if (filters?.status) params.append('status', filters.status);
    if (filters?.assignedTo) params.append('assigned_to', filters.assignedTo);
    if (filters?.dateRange) {
      params.append('start_date', filters.dateRange.start);
      params.append('end_date', filters.dateRange.end);
    }
    
    return this.get(`/api/v1/checklists/instances?${params.toString()}`);
  }

  async getChecklistInstance(instanceId: string): Promise<ApiResponse<any>> {
    return this.get(`/api/v1/checklists/instances/${instanceId}`);
  }

  async createChecklistInstance(instanceData: any): Promise<ApiResponse<any>> {
    return this.post('/api/v1/checklists/instances', instanceData);
  }

  async completeChecklistInstance(instanceId: string, responses: any[], notes?: string): Promise<ApiResponse<any>> {
    return this.post(`/api/v1/checklists/instances/${instanceId}/complete`, {
      responses,
      notes,
    });
  }

  // ============================================================================
  // WEBSOCKET API
  // ============================================================================

  async getWebSocketToken(): Promise<ApiResponse<{ token: string }>> {
    return this.get('/api/v1/websocket/token');
  }

  // ============================================================================
  // SYSTEM API
  // ============================================================================

  async getSystemHealth(): Promise<ApiResponse<any>> {
    return this.get('/api/v1/system/health');
  }

  async getSystemMetrics(): Promise<ApiResponse<any>> {
    return this.get('/api/v1/system/metrics');
  }

  async getSystemLogs(filters?: { level?: string; component?: string; dateRange?: { start: string; end: string } }): Promise<ApiResponse<any[]>> {
    const params = new URLSearchParams();
    if (filters?.level) params.append('level', filters.level);
    if (filters?.component) params.append('component', filters.component);
    if (filters?.dateRange) {
      params.append('start_date', filters.dateRange.start);
      params.append('end_date', filters.dateRange.end);
    }
    
    return this.get(`/api/v1/system/logs?${params.toString()}`);
  }
}

// Export singleton instance
export const apiService = new ApiService();
export default apiService;
