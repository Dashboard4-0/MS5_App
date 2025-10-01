/**
 * MS5.0 Floor Dashboard - Production Service
 * 
 * This service handles production-related operations including production lines,
 * schedules, job assignments, and production management.
 */

import { apiService } from './api';

// Types
export interface ProductionLine {
  id: string;
  code: string;
  name: string;
  description?: string;
  status: 'active' | 'inactive' | 'maintenance' | 'setup';
  enabled: boolean;
  capacity: number;
  currentProduction: number;
  efficiency: number;
  lastUpdate: string;
  created_at: string;
  updated_at: string;
}

export interface ProductionSchedule {
  id: string;
  lineId: string;
  lineCode: string;
  productTypeId: string;
  productTypeName: string;
  quantity: number;
  scheduledStart: string;
  scheduledEnd: string;
  actualStart?: string;
  actualEnd?: string;
  status: 'scheduled' | 'in_progress' | 'completed' | 'cancelled' | 'paused';
  priority: 'low' | 'medium' | 'high' | 'critical';
  assignedTo?: string;
  notes?: string;
  created_at: string;
  updated_at: string;
}

export interface JobAssignment {
  id: string;
  scheduleId: string;
  lineId: string;
  lineCode: string;
  userId: string;
  userName: string;
  productTypeId: string;
  productTypeName: string;
  quantity: number;
  status: 'assigned' | 'accepted' | 'in_progress' | 'completed' | 'cancelled';
  assignedAt: string;
  acceptedAt?: string;
  startedAt?: string;
  completedAt?: string;
  notes?: string;
  qualityCheckRequired: boolean;
  qualityCheckCompleted: boolean;
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

/**
 * Production Service Class
 * 
 * Provides methods for production line management, scheduling, and job assignments.
 * All methods are designed to work seamlessly with the Redux store and handle errors gracefully.
 */
class ProductionService {
  // ============================================================================
  // PRODUCTION LINES
  // ============================================================================

  /**
   * Get all production lines
   * 
   * @param filters - Optional filters for status and enabled state
   * @returns Promise resolving to array of production lines
   */
  async getProductionLines(filters?: { status?: string; enabled?: boolean }) {
    return apiService.getProductionLines(filters);
  }

  /**
   * Get specific production line by ID
   * 
   * @param lineId - Production line ID
   * @returns Promise resolving to production line data
   */
  async getProductionLine(lineId: string) {
    return apiService.getProductionLine(lineId);
  }

  /**
   * Create new production line
   * 
   * @param lineData - Production line data
   * @returns Promise resolving to created production line
   */
  async createProductionLine(lineData: Partial<ProductionLine>) {
    return apiService.createProductionLine(lineData);
  }

  /**
   * Update production line
   * 
   * @param lineId - Production line ID
   * @param lineData - Updated production line data
   * @returns Promise resolving to updated production line
   */
  async updateProductionLine(lineId: string, lineData: Partial<ProductionLine>) {
    return apiService.updateProductionLine(lineId, lineData);
  }

  /**
   * Delete production line
   * 
   * @param lineId - Production line ID
   * @returns Promise resolving when deletion is complete
   */
  async deleteProductionLine(lineId: string) {
    return apiService.deleteProductionLine(lineId);
  }

  // ============================================================================
  // PRODUCTION SCHEDULES
  // ============================================================================

  /**
   * Get production schedules
   * 
   * @param filters - Optional filters for line ID and status
   * @returns Promise resolving to array of production schedules
   */
  async getProductionSchedules(filters?: { lineId?: string; status?: string }) {
    return apiService.getProductionSchedules(filters);
  }

  /**
   * Get specific production schedule by ID
   * 
   * @param scheduleId - Production schedule ID
   * @returns Promise resolving to production schedule data
   */
  async getProductionSchedule(scheduleId: string) {
    return apiService.getProductionSchedule(scheduleId);
  }

  /**
   * Create new production schedule
   * 
   * @param scheduleData - Production schedule data
   * @returns Promise resolving to created production schedule
   */
  async createProductionSchedule(scheduleData: Partial<ProductionSchedule>) {
    return apiService.createProductionSchedule(scheduleData);
  }

  /**
   * Update production schedule
   * 
   * @param scheduleId - Production schedule ID
   * @param scheduleData - Updated production schedule data
   * @returns Promise resolving to updated production schedule
   */
  async updateProductionSchedule(scheduleId: string, scheduleData: Partial<ProductionSchedule>) {
    return apiService.updateProductionSchedule(scheduleId, scheduleData);
  }

  /**
   * Delete production schedule
   * 
   * @param scheduleId - Production schedule ID
   * @returns Promise resolving when deletion is complete
   */
  async deleteProductionSchedule(scheduleId: string) {
    return apiService.deleteProductionSchedule(scheduleId);
  }

  // ============================================================================
  // JOB ASSIGNMENTS
  // ============================================================================

  /**
   * Get job assignments for current user
   * 
   * @returns Promise resolving to array of job assignments
   */
  async getMyJobs() {
    return apiService.getMyJobs();
  }

  /**
   * Get all job assignments
   * 
   * @param filters - Optional filters for user ID and status
   * @returns Promise resolving to array of job assignments
   */
  async getJobAssignments(filters?: { userId?: string; status?: string }) {
    return apiService.getJobAssignments(filters);
  }

  /**
   * Get specific job assignment by ID
   * 
   * @param assignmentId - Job assignment ID
   * @returns Promise resolving to job assignment data
   */
  async getJobAssignment(assignmentId: string) {
    return apiService.getJobAssignment(assignmentId);
  }

  /**
   * Create new job assignment
   * 
   * @param assignmentData - Job assignment data
   * @returns Promise resolving to created job assignment
   */
  async createJobAssignment(assignmentData: Partial<JobAssignment>) {
    return apiService.createJobAssignment(assignmentData);
  }

  /**
   * Update job assignment
   * 
   * @param assignmentId - Job assignment ID
   * @param assignmentData - Updated job assignment data
   * @returns Promise resolving to updated job assignment
   */
  async updateJobAssignment(assignmentId: string, assignmentData: Partial<JobAssignment>) {
    return apiService.updateJobAssignment(assignmentId, assignmentData);
  }

  /**
   * Accept job assignment
   * 
   * @param assignmentId - Job assignment ID
   * @returns Promise resolving to updated job assignment
   */
  async acceptJob(assignmentId: string) {
    return apiService.acceptJob(assignmentId);
  }

  /**
   * Start job assignment
   * 
   * @param assignmentId - Job assignment ID
   * @returns Promise resolving to updated job assignment
   */
  async startJob(assignmentId: string) {
    return apiService.startJob(assignmentId);
  }

  /**
   * Complete job assignment
   * 
   * @param assignmentId - Job assignment ID
   * @returns Promise resolving to updated job assignment
   */
  async completeJob(assignmentId: string) {
    return apiService.completeJob(assignmentId);
  }

  /**
   * Cancel job assignment
   * 
   * @param assignmentId - Job assignment ID
   * @returns Promise resolving to updated job assignment
   */
  async cancelJob(assignmentId: string) {
    return apiService.cancelJob(assignmentId);
  }

  // ============================================================================
  // PRODUCTION METRICS
  // ============================================================================

  /**
   * Get production metrics for dashboard
   * 
   * @param lineId - Optional line ID to filter metrics
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

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /**
   * Calculate production efficiency
   * 
   * @param actualProduction - Actual production quantity
   * @param targetProduction - Target production quantity
   * @returns Efficiency percentage
   */
  calculateEfficiency(actualProduction: number, targetProduction: number): number {
    if (targetProduction === 0) return 0;
    return Math.min(100, (actualProduction / targetProduction) * 100);
  }

  /**
   * Calculate quality rate
   * 
   * @param goodParts - Number of good parts
   * @param totalParts - Total number of parts
   * @returns Quality rate percentage
   */
  calculateQualityRate(goodParts: number, totalParts: number): number {
    if (totalParts === 0) return 0;
    return (goodParts / totalParts) * 100;
  }

  /**
   * Get production status color
   * 
   * @param status - Production status
   * @returns Color code for status
   */
  getStatusColor(status: string): string {
    const statusColors: Record<string, string> = {
      'active': '#4CAF50',
      'inactive': '#9E9E9E',
      'maintenance': '#FF9800',
      'setup': '#2196F3',
      'scheduled': '#2196F3',
      'in_progress': '#4CAF50',
      'completed': '#4CAF50',
      'cancelled': '#F44336',
      'paused': '#FF9800',
      'assigned': '#2196F3',
      'accepted': '#4CAF50',
    };
    return statusColors[status] || '#9E9E9E';
  }

  /**
   * Format production quantity
   * 
   * @param quantity - Production quantity
   * @param unit - Unit of measurement
   * @returns Formatted quantity string
   */
  formatQuantity(quantity: number, unit: string = 'units'): string {
    if (quantity >= 1000000) {
      return `${(quantity / 1000000).toFixed(1)}M ${unit}`;
    } else if (quantity >= 1000) {
      return `${(quantity / 1000).toFixed(1)}K ${unit}`;
    }
    return `${quantity.toLocaleString()} ${unit}`;
  }

  /**
   * Get time remaining for job
   * 
   * @param scheduledEnd - Scheduled end time
   * @param currentProduction - Current production quantity
   * @param targetProduction - Target production quantity
   * @returns Time remaining in minutes
   */
  getTimeRemaining(scheduledEnd: string, currentProduction: number, targetProduction: number): number {
    const endTime = new Date(scheduledEnd).getTime();
    const currentTime = Date.now();
    const timeRemaining = endTime - currentTime;
    
    if (timeRemaining <= 0) return 0;
    
    // Adjust based on production progress
    const progress = currentProduction / targetProduction;
    const adjustedTimeRemaining = timeRemaining * (1 - progress);
    
    return Math.max(0, adjustedTimeRemaining / (1000 * 60)); // Convert to minutes
  }
}

// Export singleton instance
export const productionService = new ProductionService();
export default productionService;
