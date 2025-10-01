/**
 * MS5.0 Floor Dashboard - Equipment Service
 * 
 * This service handles equipment-related operations including equipment status,
 * maintenance schedules, equipment management, and equipment analytics.
 */

import { apiService } from './api';

// Types
export interface Equipment {
  id: string;
  lineId: string;
  lineCode: string;
  name: string;
  code: string;
  description?: string;
  type: string;
  manufacturer: string;
  model: string;
  serialNumber: string;
  status: 'running' | 'stopped' | 'maintenance' | 'setup' | 'fault';
  efficiency: number;
  uptime: number;
  downtime: number;
  faults: number;
  lastMaintenance?: string;
  nextMaintenance?: string;
  maintenanceInterval: number;
  created_at: string;
  updated_at: string;
}

export interface MaintenanceSchedule {
  id: string;
  equipmentId: string;
  equipmentName: string;
  type: 'preventive' | 'corrective' | 'predictive' | 'emergency';
  description: string;
  scheduledDate: string;
  completedDate?: string;
  status: 'scheduled' | 'in_progress' | 'completed' | 'cancelled' | 'overdue';
  assignedTo?: string;
  estimatedDuration: number;
  actualDuration?: number;
  cost?: number;
  notes?: string;
  created_at: string;
  updated_at: string;
}

export interface EquipmentFault {
  id: string;
  equipmentId: string;
  equipmentName: string;
  faultCode: string;
  description: string;
  severity: 'low' | 'medium' | 'high' | 'critical';
  status: 'active' | 'acknowledged' | 'resolved';
  startTime: string;
  endTime?: string;
  duration?: number;
  reportedBy: string;
  acknowledgedBy?: string;
  resolvedBy?: string;
  resolution?: string;
  notes?: string;
  created_at: string;
  updated_at: string;
}

export interface EquipmentMetrics {
  equipmentId: string;
  equipmentName: string;
  availability: number;
  efficiency: number;
  utilization: number;
  mtbf: number; // Mean Time Between Failures
  mttr: number; // Mean Time To Repair
  oee: number;
  lastUpdate: string;
}

export interface EquipmentAnalytics {
  equipmentId: string;
  equipmentName: string;
  period: string;
  metrics: EquipmentMetrics;
  trends: {
    availability: number[];
    efficiency: number[];
    utilization: number[];
  };
  faults: EquipmentFault[];
  maintenance: MaintenanceSchedule[];
  recommendations: string[];
  lastUpdate: string;
}

/**
 * Equipment Service Class
 * 
 * Provides methods for equipment management, maintenance scheduling, and analytics.
 * Handles equipment status monitoring and maintenance workflows.
 */
class EquipmentService {
  // ============================================================================
  // EQUIPMENT MANAGEMENT
  // ============================================================================

  /**
   * Get equipment list
   * 
   * @param filters - Optional filters for line ID and status
   * @returns Promise resolving to equipment list
   */
  async getEquipment(filters?: { lineId?: string; status?: string }) {
    return apiService.getEquipment(filters);
  }

  /**
   * Get specific equipment
   * 
   * @param equipmentId - Equipment ID
   * @returns Promise resolving to equipment data
   */
  async getEquipmentDetails(equipmentId: string) {
    return apiService.getEquipmentDetails(equipmentId);
  }

  /**
   * Create new equipment
   * 
   * @param equipmentData - Equipment data
   * @returns Promise resolving to created equipment
   */
  async createEquipment(equipmentData: Partial<Equipment>) {
    return apiService.createEquipment(equipmentData);
  }

  /**
   * Update equipment
   * 
   * @param equipmentId - Equipment ID
   * @param equipmentData - Updated equipment data
   * @returns Promise resolving to updated equipment
   */
  async updateEquipment(equipmentId: string, equipmentData: Partial<Equipment>) {
    return apiService.updateEquipment(equipmentId, equipmentData);
  }

  /**
   * Delete equipment
   * 
   * @param equipmentId - Equipment ID
   * @returns Promise resolving when deletion is complete
   */
  async deleteEquipment(equipmentId: string) {
    return apiService.deleteEquipment(equipmentId);
  }

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
  // MAINTENANCE SCHEDULING
  // ============================================================================

  /**
   * Get maintenance schedules
   * 
   * @param filters - Optional filters for equipment ID and status
   * @returns Promise resolving to maintenance schedules
   */
  async getMaintenanceSchedules(filters?: { equipmentId?: string; status?: string }) {
    return apiService.getMaintenanceSchedules(filters);
  }

  /**
   * Get specific maintenance schedule
   * 
   * @param scheduleId - Maintenance schedule ID
   * @returns Promise resolving to maintenance schedule data
   */
  async getMaintenanceSchedule(scheduleId: string) {
    return apiService.getMaintenanceSchedule(scheduleId);
  }

  /**
   * Create maintenance schedule
   * 
   * @param scheduleData - Maintenance schedule data
   * @returns Promise resolving to created maintenance schedule
   */
  async createMaintenanceSchedule(scheduleData: Partial<MaintenanceSchedule>) {
    return apiService.createMaintenanceSchedule(scheduleData);
  }

  /**
   * Update maintenance schedule
   * 
   * @param scheduleId - Maintenance schedule ID
   * @param scheduleData - Updated maintenance schedule data
   * @returns Promise resolving to updated maintenance schedule
   */
  async updateMaintenanceSchedule(scheduleId: string, scheduleData: Partial<MaintenanceSchedule>) {
    return apiService.updateMaintenanceSchedule(scheduleId, scheduleData);
  }

  /**
   * Complete maintenance schedule
   * 
   * @param scheduleId - Maintenance schedule ID
   * @param notes - Optional completion notes
   * @returns Promise resolving to completed maintenance schedule
   */
  async completeMaintenanceSchedule(scheduleId: string, notes?: string) {
    return apiService.completeMaintenanceSchedule(scheduleId, notes);
  }

  /**
   * Cancel maintenance schedule
   * 
   * @param scheduleId - Maintenance schedule ID
   * @param reason - Cancellation reason
   * @returns Promise resolving to cancelled maintenance schedule
   */
  async cancelMaintenanceSchedule(scheduleId: string, reason: string) {
    return apiService.cancelMaintenanceSchedule(scheduleId, reason);
  }

  // ============================================================================
  // EQUIPMENT FAULTS
  // ============================================================================

  /**
   * Get equipment faults
   * 
   * @param filters - Optional filters for equipment ID and status
   * @returns Promise resolving to equipment faults
   */
  async getEquipmentFaults(filters?: { equipmentId?: string; status?: string }) {
    return apiService.getEquipmentFaults(filters);
  }

  /**
   * Get specific equipment fault
   * 
   * @param faultId - Equipment fault ID
   * @returns Promise resolving to equipment fault data
   */
  async getEquipmentFault(faultId: string) {
    return apiService.getEquipmentFault(faultId);
  }

  /**
   * Create equipment fault
   * 
   * @param faultData - Equipment fault data
   * @returns Promise resolving to created equipment fault
   */
  async createEquipmentFault(faultData: Partial<EquipmentFault>) {
    return apiService.createEquipmentFault(faultData);
  }

  /**
   * Update equipment fault
   * 
   * @param faultId - Equipment fault ID
   * @param faultData - Updated equipment fault data
   * @returns Promise resolving to updated equipment fault
   */
  async updateEquipmentFault(faultId: string, faultData: Partial<EquipmentFault>) {
    return apiService.updateEquipmentFault(faultId, faultData);
  }

  /**
   * Acknowledge equipment fault
   * 
   * @param faultId - Equipment fault ID
   * @param notes - Optional acknowledgment notes
   * @returns Promise resolving to acknowledged equipment fault
   */
  async acknowledgeEquipmentFault(faultId: string, notes?: string) {
    return apiService.acknowledgeEquipmentFault(faultId, notes);
  }

  /**
   * Resolve equipment fault
   * 
   * @param faultId - Equipment fault ID
   * @param resolution - Resolution description
   * @param notes - Optional resolution notes
   * @returns Promise resolving to resolved equipment fault
   */
  async resolveEquipmentFault(faultId: string, resolution: string, notes?: string) {
    return apiService.resolveEquipmentFault(faultId, resolution, notes);
  }

  // ============================================================================
  // EQUIPMENT ANALYTICS
  // ============================================================================

  /**
   * Get equipment metrics
   * 
   * @param equipmentId - Equipment ID
   * @param filters - Optional filters for date range
   * @returns Promise resolving to equipment metrics
   */
  async getEquipmentMetrics(equipmentId: string, filters?: { dateRange?: { start: string; end: string } }) {
    return apiService.getEquipmentMetrics(equipmentId, filters);
  }

  /**
   * Get equipment analytics
   * 
   * @param equipmentId - Equipment ID
   * @param filters - Optional filters for date range
   * @returns Promise resolving to equipment analytics
   */
  async getEquipmentAnalytics(equipmentId: string, filters?: { dateRange?: { start: string; end: string } }) {
    return apiService.getEquipmentAnalytics(equipmentId, filters);
  }

  /**
   * Get equipment performance trends
   * 
   * @param equipmentId - Equipment ID
   * @param filters - Optional filters for date range and granularity
   * @returns Promise resolving to equipment performance trends
   */
  async getEquipmentPerformanceTrends(equipmentId: string, filters?: { dateRange?: { start: string; end: string }; granularity?: string }) {
    return apiService.getEquipmentPerformanceTrends(equipmentId, filters);
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

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
   * Get maintenance type color
   * 
   * @param type - Maintenance type
   * @returns Color code for maintenance type
   */
  getMaintenanceTypeColor(type: string): string {
    const typeColors: Record<string, string> = {
      'preventive': '#4CAF50',
      'corrective': '#F44336',
      'predictive': '#2196F3',
      'emergency': '#FF5722',
    };
    return typeColors[type] || '#9E9E9E';
  }

  /**
   * Get fault severity color
   * 
   * @param severity - Fault severity
   * @returns Color code for fault severity
   */
  getFaultSeverityColor(severity: string): string {
    const severityColors: Record<string, string> = {
      'low': '#4CAF50',
      'medium': '#FF9800',
      'high': '#FF5722',
      'critical': '#F44336',
    };
    return severityColors[severity] || '#9E9E9E';
  }

  /**
   * Calculate equipment availability
   * 
   * @param uptime - Uptime in minutes
   * @param totalTime - Total time in minutes
   * @returns Availability percentage
   */
  calculateAvailability(uptime: number, totalTime: number): number {
    if (totalTime === 0) return 0;
    return (uptime / totalTime) * 100;
  }

  /**
   * Calculate equipment efficiency
   * 
   * @param actualOutput - Actual output
   * @param targetOutput - Target output
   * @returns Efficiency percentage
   */
  calculateEfficiency(actualOutput: number, targetOutput: number): number {
    if (targetOutput === 0) return 0;
    return Math.min(100, (actualOutput / targetOutput) * 100);
  }

  /**
   * Calculate MTBF (Mean Time Between Failures)
   * 
   * @param totalUptime - Total uptime in minutes
   * @param faultCount - Number of faults
   * @returns MTBF in minutes
   */
  calculateMTBF(totalUptime: number, faultCount: number): number {
    if (faultCount === 0) return 0;
    return totalUptime / faultCount;
  }

  /**
   * Calculate MTTR (Mean Time To Repair)
   * 
   * @param totalDowntime - Total downtime in minutes
   * @param repairCount - Number of repairs
   * @returns MTTR in minutes
   */
  calculateMTTR(totalDowntime: number, repairCount: number): number {
    if (repairCount === 0) return 0;
    return totalDowntime / repairCount;
  }

  /**
   * Format equipment efficiency
   * 
   * @param efficiency - Efficiency percentage
   * @returns Formatted efficiency string
   */
  formatEfficiency(efficiency: number): string {
    return `${efficiency.toFixed(1)}%`;
  }

  /**
   * Format equipment availability
   * 
   * @param availability - Availability percentage
   * @returns Formatted availability string
   */
  formatAvailability(availability: number): string {
    return `${availability.toFixed(1)}%`;
  }

  /**
   * Format equipment uptime
   * 
   * @param uptime - Uptime in minutes
   * @returns Formatted uptime string
   */
  formatUptime(uptime: number): string {
    const hours = Math.floor(uptime / 60);
    const minutes = uptime % 60;
    return `${hours}h ${minutes}m`;
  }

  /**
   * Format equipment downtime
   * 
   * @param downtime - Downtime in minutes
   * @returns Formatted downtime string
   */
  formatDowntime(downtime: number): string {
    const hours = Math.floor(downtime / 60);
    const minutes = downtime % 60;
    return `${hours}h ${minutes}m`;
  }

  /**
   * Get equipment status icon
   * 
   * @param status - Equipment status
   * @returns Icon name for status
   */
  getEquipmentStatusIcon(status: string): string {
    const statusIcons: Record<string, string> = {
      'running': 'play-circle',
      'stopped': 'pause-circle',
      'maintenance': 'wrench',
      'setup': 'settings',
      'fault': 'alert-triangle',
    };
    return statusIcons[status] || 'circle';
  }

  /**
   * Get maintenance type icon
   * 
   * @param type - Maintenance type
   * @returns Icon name for maintenance type
   */
  getMaintenanceTypeIcon(type: string): string {
    const typeIcons: Record<string, string> = {
      'preventive': 'shield-check',
      'corrective': 'wrench',
      'predictive': 'trending-up',
      'emergency': 'alert-triangle',
    };
    return typeIcons[type] || 'circle';
  }

  /**
   * Get fault severity icon
   * 
   * @param severity - Fault severity
   * @returns Icon name for fault severity
   */
  getFaultSeverityIcon(severity: string): string {
    const severityIcons: Record<string, string> = {
      'low': 'info',
      'medium': 'alert-circle',
      'high': 'alert-triangle',
      'critical': 'alert-octagon',
    };
    return severityIcons[severity] || 'circle';
  }

  /**
   * Get equipment priority level
   * 
   * @param efficiency - Equipment efficiency
   * @param faultCount - Number of faults
   * @returns Priority level string
   */
  getEquipmentPriorityLevel(efficiency: number, faultCount: number): string {
    if (efficiency < 50 || faultCount > 10) return 'Critical';
    if (efficiency < 70 || faultCount > 5) return 'High';
    if (efficiency < 85 || faultCount > 2) return 'Medium';
    return 'Low';
  }

  /**
   * Get maintenance priority level
   * 
   * @param type - Maintenance type
   * @param daysOverdue - Days overdue
   * @returns Priority level string
   */
  getMaintenancePriorityLevel(type: string, daysOverdue: number): string {
    if (type === 'emergency') return 'Critical';
    if (daysOverdue > 7) return 'High';
    if (daysOverdue > 3) return 'Medium';
    return 'Low';
  }
}

// Export singleton instance
export const equipmentService = new EquipmentService();
export default equipmentService;
