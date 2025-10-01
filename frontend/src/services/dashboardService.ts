/**
 * MS5.0 Floor Dashboard - Dashboard Service
 * 
 * This service handles dashboard-related operations including OEE data,
 * equipment status, downtime events, and production metrics.
 */

import { apiService } from './api';

// Types
export interface OEEData {
  lineId: string;
  lineCode: string;
  availability: number;
  performance: number;
  quality: number;
  oee: number;
  targetOEE: number;
  lastUpdate: string;
  period: string;
  granularity: string;
}

export interface EquipmentStatus {
  id: string;
  lineId: string;
  lineCode: string;
  name: string;
  status: 'running' | 'stopped' | 'maintenance' | 'setup' | 'fault';
  efficiency: number;
  lastUpdate: string;
  uptime: number;
  downtime: number;
  faults: number;
}

export interface DowntimeEvent {
  id: string;
  lineId: string;
  lineCode: string;
  equipmentId: string;
  equipmentName: string;
  startTime: string;
  endTime?: string;
  duration?: number;
  reason: string;
  category: 'planned' | 'unplanned' | 'maintenance' | 'setup' | 'fault';
  status: 'active' | 'resolved';
  assignedTo?: string;
  notes?: string;
  created_at: string;
  updated_at: string;
}

export interface ProductionMetrics {
  lineId: string;
  lineCode: string;
  currentProduction: number;
  targetProduction: number;
  efficiency: number;
  goodParts: number;
  totalParts: number;
  qualityRate: number;
  downtimeMinutes: number;
  lastUpdate: string;
}

export interface DashboardData {
  oeeData: OEEData[];
  equipmentStatus: EquipmentStatus[];
  downtimeEvents: DowntimeEvent[];
  productionMetrics: ProductionMetrics[];
  lastUpdate: string;
}

/**
 * Dashboard Service Class
 * 
 * Provides methods for fetching and managing dashboard data.
 * Handles OEE calculations, equipment monitoring, and production metrics.
 */
class DashboardService {
  // ============================================================================
  // OEE DATA
  // ============================================================================

  /**
   * Get OEE data for dashboard
   * 
   * @param lineId - Optional line ID to filter OEE data
   * @param filters - Optional filters for period and granularity
   * @returns Promise resolving to OEE data
   */
  async getOEEData(lineId?: string, filters?: { period?: string; granularity?: string }) {
    return apiService.getOEEData(lineId, filters);
  }

  /**
   * Get current OEE data
   * 
   * @param lineId - Optional line ID to filter current OEE
   * @returns Promise resolving to current OEE data
   */
  async getCurrentOEE(lineId?: string) {
    return apiService.getCurrentOEE(lineId);
  }

  /**
   * Get OEE calculations
   * 
   * @param filters - Optional filters for line ID and date range
   * @returns Promise resolving to OEE calculations
   */
  async getOEECalculations(filters?: { lineId?: string; dateRange?: { start: string; end: string } }) {
    return apiService.getOEECalculations(filters);
  }

  /**
   * Get OEE trends
   * 
   * @param filters - Optional filters for line ID and aggregation level
   * @returns Promise resolving to OEE trends
   */
  async getOEETrends(filters?: { lineId?: string; aggregationLevel?: string }) {
    return apiService.getOEETrends(filters);
  }

  /**
   * Get OEE losses
   * 
   * @param filters - Optional filters for line ID and date range
   * @returns Promise resolving to OEE losses
   */
  async getOEELosses(filters?: { lineId?: string; dateRange?: { start: string; end: string } }) {
    return apiService.getOEELosses(filters);
  }

  /**
   * Calculate OEE
   * 
   * @param lineId - Line ID for OEE calculation
   * @returns Promise resolving to OEE calculation result
   */
  async calculateOEE(lineId: string) {
    return apiService.calculateOEE(lineId);
  }

  /**
   * Get OEE analytics
   * 
   * @param filters - Optional filters for line ID and date range
   * @returns Promise resolving to OEE analytics
   */
  async getOEEAnalytics(filters?: { lineId?: string; dateRange?: { start: string; end: string } }) {
    return apiService.getOEEAnalytics(filters);
  }

  // ============================================================================
  // EQUIPMENT STATUS
  // ============================================================================

  /**
   * Get equipment status
   * 
   * @param lineId - Optional line ID to filter equipment status
   * @returns Promise resolving to equipment status data
   */
  async getEquipmentStatus(lineId?: string) {
    return apiService.getEquipmentStatus(lineId);
  }

  /**
   * Get equipment details
   * 
   * @param equipmentId - Equipment ID
   * @returns Promise resolving to equipment details
   */
  async getEquipmentDetails(equipmentId: string) {
    return apiService.getEquipmentDetails(equipmentId);
  }

  /**
   * Get equipment history
   * 
   * @param equipmentId - Equipment ID
   * @param filters - Optional filters for date range
   * @returns Promise resolving to equipment history
   */
  async getEquipmentHistory(equipmentId: string, filters?: { dateRange?: { start: string; end: string } }) {
    return apiService.getEquipmentHistory(equipmentId, filters);
  }

  // ============================================================================
  // DOWNTIME EVENTS
  // ============================================================================

  /**
   * Get downtime events
   * 
   * @param filters - Optional filters for line ID and status
   * @returns Promise resolving to downtime events
   */
  async getDowntimeEvents(filters?: { lineId?: string; status?: string }) {
    return apiService.getDowntimeEvents(filters);
  }

  /**
   * Get specific downtime event
   * 
   * @param eventId - Downtime event ID
   * @returns Promise resolving to downtime event data
   */
  async getDowntimeEvent(eventId: string) {
    return apiService.getDowntimeEvent(eventId);
  }

  /**
   * Create downtime event
   * 
   * @param eventData - Downtime event data
   * @returns Promise resolving to created downtime event
   */
  async createDowntimeEvent(eventData: Partial<DowntimeEvent>) {
    return apiService.createDowntimeEvent(eventData);
  }

  /**
   * Update downtime event
   * 
   * @param eventId - Downtime event ID
   * @param eventData - Updated downtime event data
   * @returns Promise resolving to updated downtime event
   */
  async updateDowntimeEvent(eventId: string, eventData: Partial<DowntimeEvent>) {
    return apiService.updateDowntimeEvent(eventId, eventData);
  }

  /**
   * Resolve downtime event
   * 
   * @param eventId - Downtime event ID
   * @returns Promise resolving to resolved downtime event
   */
  async resolveDowntimeEvent(eventId: string) {
    return apiService.resolveDowntimeEvent(eventId);
  }

  // ============================================================================
  // PRODUCTION METRICS
  // ============================================================================

  /**
   * Get production metrics
   * 
   * @param lineId - Optional line ID to filter production metrics
   * @returns Promise resolving to production metrics
   */
  async getProductionMetrics(lineId?: string) {
    return apiService.getProductionMetrics(lineId);
  }

  /**
   * Get production summary
   * 
   * @param filters - Optional filters for line ID and date range
   * @returns Promise resolving to production summary
   */
  async getProductionSummary(filters?: { lineId?: string; dateRange?: { start: string; end: string } }) {
    return apiService.getProductionSummary(filters);
  }

  /**
   * Get production trends
   * 
   * @param filters - Optional filters for line ID and aggregation level
   * @returns Promise resolving to production trends
   */
  async getProductionTrends(filters?: { lineId?: string; aggregationLevel?: string }) {
    return apiService.getProductionTrends(filters);
  }

  // ============================================================================
  // DASHBOARD DATA
  // ============================================================================

  /**
   * Get complete dashboard data
   * 
   * @param filters - Optional filters for line ID and date range
   * @returns Promise resolving to complete dashboard data
   */
  async getDashboardData(filters?: { lineId?: string; dateRange?: { start: string; end: string } }) {
    return apiService.getDashboardData(filters);
  }

  /**
   * Get dashboard summary
   * 
   * @param filters - Optional filters for line ID and date range
   * @returns Promise resolving to dashboard summary
   */
  async getDashboardSummary(filters?: { lineId?: string; dateRange?: { start: string; end: string } }) {
    return apiService.getDashboardSummary(filters);
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /**
   * Calculate OEE from components
   * 
   * @param availability - Availability percentage
   * @param performance - Performance percentage
   * @param quality - Quality percentage
   * @returns Calculated OEE percentage
   */
  calculateOEE(availability: number, performance: number, quality: number): number {
    return (availability * performance * quality) / 10000;
  }

  /**
   * Get OEE status color
   * 
   * @param oee - OEE percentage
   * @param targetOEE - Target OEE percentage
   * @returns Color code for OEE status
   */
  getOEEStatusColor(oee: number, targetOEE: number): string {
    if (oee >= targetOEE) return '#4CAF50'; // Green
    if (oee >= targetOEE * 0.8) return '#FF9800'; // Orange
    return '#F44336'; // Red
  }

  /**
   * Get equipment status color
   * 
   * @param status - Equipment status
   * @returns Color code for equipment status
   */
  getEquipmentStatusColor(status: string): string {
    const statusColors: Record<string, string> = {
      'running': '#4CAF50',
      'stopped': '#9E9E9E',
      'maintenance': '#FF9800',
      'setup': '#2196F3',
      'fault': '#F44336',
    };
    return statusColors[status] || '#9E9E9E';
  }

  /**
   * Get downtime category color
   * 
   * @param category - Downtime category
   * @returns Color code for downtime category
   */
  getDowntimeCategoryColor(category: string): string {
    const categoryColors: Record<string, string> = {
      'planned': '#2196F3',
      'unplanned': '#F44336',
      'maintenance': '#FF9800',
      'setup': '#9C27B0',
      'fault': '#F44336',
    };
    return categoryColors[category] || '#9E9E9E';
  }

  /**
   * Format OEE percentage
   * 
   * @param oee - OEE percentage
   * @returns Formatted OEE string
   */
  formatOEE(oee: number): string {
    return `${oee.toFixed(1)}%`;
  }

  /**
   * Format efficiency percentage
   * 
   * @param efficiency - Efficiency percentage
   * @returns Formatted efficiency string
   */
  formatEfficiency(efficiency: number): string {
    return `${efficiency.toFixed(1)}%`;
  }

  /**
   * Format duration in minutes
   * 
   * @param minutes - Duration in minutes
   * @returns Formatted duration string
   */
  formatDuration(minutes: number): string {
    if (minutes < 60) {
      return `${minutes}m`;
    } else if (minutes < 1440) {
      const hours = Math.floor(minutes / 60);
      const remainingMinutes = minutes % 60;
      return `${hours}h ${remainingMinutes}m`;
    } else {
      const days = Math.floor(minutes / 1440);
      const remainingHours = Math.floor((minutes % 1440) / 60);
      return `${days}d ${remainingHours}h`;
    }
  }

  /**
   * Get time remaining for production target
   * 
   * @param currentProduction - Current production quantity
   * @param targetProduction - Target production quantity
   * @param timeRemaining - Time remaining in minutes
   * @returns Time remaining in minutes
   */
  getTimeRemaining(currentProduction: number, targetProduction: number, timeRemaining: number): number {
    if (currentProduction >= targetProduction) return 0;
    
    const remainingProduction = targetProduction - currentProduction;
    const productionRate = currentProduction / (timeRemaining > 0 ? timeRemaining : 1);
    
    if (productionRate <= 0) return timeRemaining;
    
    return Math.ceil(remainingProduction / productionRate);
  }

  /**
   * Calculate production efficiency
   * 
   * @param actualProduction - Actual production quantity
   * @param targetProduction - Target production quantity
   * @returns Efficiency percentage
   */
  calculateProductionEfficiency(actualProduction: number, targetProduction: number): number {
    if (targetProduction === 0) return 0;
    return Math.min(100, (actualProduction / targetProduction) * 100);
  }

  /**
   * Get production status
   * 
   * @param efficiency - Production efficiency
   * @returns Production status string
   */
  getProductionStatus(efficiency: number): string {
    if (efficiency >= 100) return 'On Target';
    if (efficiency >= 90) return 'Near Target';
    if (efficiency >= 75) return 'Below Target';
    return 'Significantly Below Target';
  }
}

// Export singleton instance
export const dashboardService = new DashboardService();
export default dashboardService;
