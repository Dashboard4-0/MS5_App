/**
 * MS5.0 Floor Dashboard - Reports Service
 * 
 * This service handles report-related operations including report generation,
 * templates, scheduling, and report management.
 */

import { apiService } from './api';

// Types
export interface ReportTemplate {
  id: string;
  name: string;
  description?: string;
  category: 'production' | 'oee' | 'equipment' | 'andon' | 'quality' | 'maintenance' | 'custom';
  type: 'summary' | 'detailed' | 'analytics' | 'trend' | 'comparison';
  parameters: ReportParameter[];
  format: 'pdf' | 'excel' | 'csv' | 'json';
  isActive: boolean;
  createdBy: string;
  created_at: string;
  updated_at: string;
}

export interface ReportParameter {
  name: string;
  type: 'string' | 'number' | 'date' | 'boolean' | 'select';
  label: string;
  required: boolean;
  defaultValue?: any;
  options?: { value: any; label: string }[];
  validation?: {
    min?: number;
    max?: number;
    pattern?: string;
  };
}

export interface Report {
  id: string;
  templateId: string;
  templateName: string;
  name: string;
  description?: string;
  parameters: Record<string, any>;
  status: 'pending' | 'generating' | 'completed' | 'failed' | 'cancelled';
  progress: number;
  generatedAt?: string;
  completedAt?: string;
  fileUrl?: string;
  fileSize?: number;
  error?: string;
  createdBy: string;
  created_at: string;
  updated_at: string;
}

export interface ScheduledReport {
  id: string;
  templateId: string;
  templateName: string;
  name: string;
  description?: string;
  parameters: Record<string, any>;
  schedule: {
    frequency: 'daily' | 'weekly' | 'monthly' | 'quarterly' | 'yearly';
    dayOfWeek?: number; // 0-6 for weekly
    dayOfMonth?: number; // 1-31 for monthly
    time: string; // HH:MM format
    timezone: string;
  };
  isActive: boolean;
  lastRun?: string;
  nextRun?: string;
  emailRecipients: string[];
  createdBy: string;
  created_at: string;
  updated_at: string;
}

export interface ReportData {
  reportId: string;
  data: any;
  metadata: {
    generatedAt: string;
    generatedBy: string;
    parameters: Record<string, any>;
    recordCount: number;
    dataRange: {
      start: string;
      end: string;
    };
  };
}

export interface ReportAnalytics {
  totalReports: number;
  reportsByStatus: Record<string, number>;
  reportsByCategory: Record<string, number>;
  reportsByType: Record<string, number>;
  averageGenerationTime: number;
  mostUsedTemplates: Array<{
    templateId: string;
    templateName: string;
    usageCount: number;
  }>;
  lastUpdate: string;
}

/**
 * Reports Service Class
 * 
 * Provides methods for report generation, template management, and scheduling.
 * Handles report data processing and file generation.
 */
class ReportsService {
  // ============================================================================
  // REPORT TEMPLATES
  // ============================================================================

  /**
   * Get report templates
   * 
   * @param filters - Optional filters for category and type
   * @returns Promise resolving to report templates
   */
  async getReportTemplates(filters?: { category?: string; type?: string }) {
    return apiService.getReportTemplates(filters);
  }

  /**
   * Get specific report template
   * 
   * @param templateId - Report template ID
   * @returns Promise resolving to report template data
   */
  async getReportTemplate(templateId: string) {
    return apiService.getReportTemplate(templateId);
  }

  /**
   * Create report template
   * 
   * @param templateData - Report template data
   * @returns Promise resolving to created report template
   */
  async createReportTemplate(templateData: Partial<ReportTemplate>) {
    return apiService.createReportTemplate(templateData);
  }

  /**
   * Update report template
   * 
   * @param templateId - Report template ID
   * @param templateData - Updated report template data
   * @returns Promise resolving to updated report template
   */
  async updateReportTemplate(templateId: string, templateData: Partial<ReportTemplate>) {
    return apiService.updateReportTemplate(templateId, templateData);
  }

  /**
   * Delete report template
   * 
   * @param templateId - Report template ID
   * @returns Promise resolving when deletion is complete
   */
  async deleteReportTemplate(templateId: string) {
    return apiService.deleteReportTemplate(templateId);
  }

  // ============================================================================
  // REPORT GENERATION
  // ============================================================================

  /**
   * Generate report
   * 
   * @param templateId - Report template ID
   * @param parameters - Report parameters
   * @param name - Report name
   * @param description - Optional report description
   * @returns Promise resolving to report generation result
   */
  async generateReport(templateId: string, parameters: Record<string, any>, name: string, description?: string) {
    return apiService.generateReport(templateId, parameters, name, description);
  }

  /**
   * Get report status
   * 
   * @param reportId - Report ID
   * @returns Promise resolving to report status
   */
  async getReportStatus(reportId: string) {
    return apiService.getReportStatus(reportId);
  }

  /**
   * Get report data
   * 
   * @param reportId - Report ID
   * @returns Promise resolving to report data
   */
  async getReportData(reportId: string) {
    return apiService.getReportData(reportId);
  }

  /**
   * Download report
   * 
   * @param reportId - Report ID
   * @returns Promise resolving to report download URL
   */
  async downloadReport(reportId: string) {
    return apiService.downloadReport(reportId);
  }

  /**
   * Cancel report generation
   * 
   * @param reportId - Report ID
   * @returns Promise resolving when cancellation is complete
   */
  async cancelReport(reportId: string) {
    return apiService.cancelReport(reportId);
  }

  // ============================================================================
  // REPORT MANAGEMENT
  // ============================================================================

  /**
   * Get reports
   * 
   * @param filters - Optional filters for status and template ID
   * @returns Promise resolving to reports
   */
  async getReports(filters?: { status?: string; templateId?: string }) {
    return apiService.getReports(filters);
  }

  /**
   * Get specific report
   * 
   * @param reportId - Report ID
   * @returns Promise resolving to report data
   */
  async getReport(reportId: string) {
    return apiService.getReport(reportId);
  }

  /**
   * Delete report
   * 
   * @param reportId - Report ID
   * @returns Promise resolving when deletion is complete
   */
  async deleteReport(reportId: string) {
    return apiService.deleteReport(reportId);
  }

  /**
   * Get user reports
   * 
   * @param userId - User ID
   * @param filters - Optional filters for status and date range
   * @returns Promise resolving to user reports
   */
  async getUserReports(userId: string, filters?: { status?: string; dateRange?: { start: string; end: string } }) {
    return apiService.getUserReports(userId, filters);
  }

  // ============================================================================
  // SCHEDULED REPORTS
  // ============================================================================

  /**
   * Get scheduled reports
   * 
   * @param filters - Optional filters for template ID and active status
   * @returns Promise resolving to scheduled reports
   */
  async getScheduledReports(filters?: { templateId?: string; isActive?: boolean }) {
    return apiService.getScheduledReports(filters);
  }

  /**
   * Get specific scheduled report
   * 
   * @param scheduledReportId - Scheduled report ID
   * @returns Promise resolving to scheduled report data
   */
  async getScheduledReport(scheduledReportId: string) {
    return apiService.getScheduledReport(scheduledReportId);
  }

  /**
   * Create scheduled report
   * 
   * @param scheduledReportData - Scheduled report data
   * @returns Promise resolving to created scheduled report
   */
  async createScheduledReport(scheduledReportData: Partial<ScheduledReport>) {
    return apiService.createScheduledReport(scheduledReportData);
  }

  /**
   * Update scheduled report
   * 
   * @param scheduledReportId - Scheduled report ID
   * @param scheduledReportData - Updated scheduled report data
   * @returns Promise resolving to updated scheduled report
   */
  async updateScheduledReport(scheduledReportId: string, scheduledReportData: Partial<ScheduledReport>) {
    return apiService.updateScheduledReport(scheduledReportId, scheduledReportData);
  }

  /**
   * Delete scheduled report
   * 
   * @param scheduledReportId - Scheduled report ID
   * @returns Promise resolving when deletion is complete
   */
  async deleteScheduledReport(scheduledReportId: string) {
    return apiService.deleteScheduledReport(scheduledReportId);
  }

  /**
   * Activate scheduled report
   * 
   * @param scheduledReportId - Scheduled report ID
   * @returns Promise resolving to activated scheduled report
   */
  async activateScheduledReport(scheduledReportId: string) {
    return apiService.activateScheduledReport(scheduledReportId);
  }

  /**
   * Deactivate scheduled report
   * 
   * @param scheduledReportId - Scheduled report ID
   * @returns Promise resolving to deactivated scheduled report
   */
  async deactivateScheduledReport(scheduledReportId: string) {
    return apiService.deactivateScheduledReport(scheduledReportId);
  }

  // ============================================================================
  // REPORT ANALYTICS
  // ============================================================================

  /**
   * Get report analytics
   * 
   * @param filters - Optional filters for date range
   * @returns Promise resolving to report analytics
   */
  async getReportAnalytics(filters?: { dateRange?: { start: string; end: string } }) {
    return apiService.getReportAnalytics(filters);
  }

  /**
   * Get report usage statistics
   * 
   * @param filters - Optional filters for date range and user ID
   * @returns Promise resolving to report usage statistics
   */
  async getReportUsageStatistics(filters?: { dateRange?: { start: string; end: string }; userId?: string }) {
    return apiService.getReportUsageStatistics(filters);
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /**
   * Get report status color
   * 
   * @param status - Report status
   * @returns Color code for report status
   */
  getReportStatusColor(status: string): string {
    const statusColors: Record<string, string> = {
      'pending': '#2196F3',
      'generating': '#FF9800',
      'completed': '#4CAF50',
      'failed': '#F44336',
      'cancelled': '#9E9E9E',
    };
    return statusColors[status] || '#9E9E9E';
  }

  /**
   * Get report category color
   * 
   * @param category - Report category
   * @returns Color code for report category
   */
  getReportCategoryColor(category: string): string {
    const categoryColors: Record<string, string> = {
      'production': '#4CAF50',
      'oee': '#2196F3',
      'equipment': '#FF9800',
      'andon': '#F44336',
      'quality': '#9C27B0',
      'maintenance': '#FF5722',
      'custom': '#9E9E9E',
    };
    return categoryColors[category] || '#9E9E9E';
  }

  /**
   * Get report type color
   * 
   * @param type - Report type
   * @returns Color code for report type
   */
  getReportTypeColor(type: string): string {
    const typeColors: Record<string, string> = {
      'summary': '#4CAF50',
      'detailed': '#2196F3',
      'analytics': '#FF9800',
      'trend': '#9C27B0',
      'comparison': '#FF5722',
    };
    return typeColors[type] || '#9E9E9E';
  }

  /**
   * Get report format icon
   * 
   * @param format - Report format
   * @returns Icon name for report format
   */
  getReportFormatIcon(format: string): string {
    const formatIcons: Record<string, string> = {
      'pdf': 'file-text',
      'excel': 'file-spreadsheet',
      'csv': 'file-text',
      'json': 'code',
    };
    return formatIcons[format] || 'file';
  }

  /**
   * Get report status icon
   * 
   * @param status - Report status
   * @returns Icon name for report status
   */
  getReportStatusIcon(status: string): string {
    const statusIcons: Record<string, string> = {
      'pending': 'clock',
      'generating': 'loader',
      'completed': 'check-circle',
      'failed': 'x-circle',
      'cancelled': 'minus-circle',
    };
    return statusIcons[status] || 'circle';
  }

  /**
   * Format file size
   * 
   * @param bytes - File size in bytes
   * @returns Formatted file size string
   */
  formatFileSize(bytes: number): string {
    if (bytes === 0) return '0 B';
    
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    
    return `${parseFloat((bytes / Math.pow(k, i)).toFixed(2))} ${sizes[i]}`;
  }

  /**
   * Format report generation time
   * 
   * @param startTime - Report generation start time
   * @param endTime - Report generation end time
   * @returns Formatted generation time string
   */
  formatGenerationTime(startTime: string, endTime: string): string {
    const start = new Date(startTime);
    const end = new Date(endTime);
    const duration = end.getTime() - start.getTime();
    
    const seconds = Math.floor(duration / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);
    
    if (hours > 0) {
      return `${hours}h ${minutes % 60}m ${seconds % 60}s`;
    } else if (minutes > 0) {
      return `${minutes}m ${seconds % 60}s`;
    } else {
      return `${seconds}s`;
    }
  }

  /**
   * Get report priority level
   * 
   * @param status - Report status
   * @param age - Report age in hours
   * @returns Priority level string
   */
  getReportPriorityLevel(status: string, age: number): string {
    if (status === 'failed') return 'Critical';
    if (status === 'generating' && age > 2) return 'High';
    if (status === 'pending' && age > 1) return 'Medium';
    return 'Low';
  }

  /**
   * Get schedule frequency text
   * 
   * @param frequency - Schedule frequency
   * @param dayOfWeek - Day of week (for weekly)
   * @param dayOfMonth - Day of month (for monthly)
   * @returns Formatted frequency text
   */
  getScheduleFrequencyText(frequency: string, dayOfWeek?: number, dayOfMonth?: number): string {
    const dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    
    switch (frequency) {
      case 'daily':
        return 'Daily';
      case 'weekly':
        return `Weekly on ${dayNames[dayOfWeek || 0]}`;
      case 'monthly':
        return `Monthly on day ${dayOfMonth || 1}`;
      case 'quarterly':
        return 'Quarterly';
      case 'yearly':
        return 'Yearly';
      default:
        return frequency;
    }
  }

  /**
   * Get next run time
   * 
   * @param schedule - Schedule configuration
   * @returns Next run time string
   */
  getNextRunTime(schedule: ScheduledReport['schedule']): string {
    const now = new Date();
    const nextRun = new Date(now);
    
    switch (schedule.frequency) {
      case 'daily':
        nextRun.setDate(now.getDate() + 1);
        break;
      case 'weekly':
        const daysUntilNext = (schedule.dayOfWeek || 0) - now.getDay();
        nextRun.setDate(now.getDate() + (daysUntilNext <= 0 ? daysUntilNext + 7 : daysUntilNext));
        break;
      case 'monthly':
        nextRun.setMonth(now.getMonth() + 1);
        nextRun.setDate(schedule.dayOfMonth || 1);
        break;
      case 'quarterly':
        nextRun.setMonth(now.getMonth() + 3);
        break;
      case 'yearly':
        nextRun.setFullYear(now.getFullYear() + 1);
        break;
    }
    
    const [hours, minutes] = schedule.time.split(':');
    nextRun.setHours(parseInt(hours), parseInt(minutes), 0, 0);
    
    return nextRun.toISOString();
  }

  /**
   * Validate report parameters
   * 
   * @param parameters - Report parameters
   * @param template - Report template
   * @returns Validation result
   */
  validateReportParameters(parameters: Record<string, any>, template: ReportTemplate): {
    isValid: boolean;
    errors: string[];
  } {
    const errors: string[] = [];
    
    template.parameters.forEach(param => {
      const value = parameters[param.name];
      
      if (param.required && (value === undefined || value === null || value === '')) {
        errors.push(`${param.label} is required`);
      }
      
      if (value !== undefined && value !== null && value !== '') {
        if (param.type === 'number' && typeof value !== 'number') {
          errors.push(`${param.label} must be a number`);
        }
        
        if (param.type === 'date' && !(value instanceof Date) && !Date.parse(value)) {
          errors.push(`${param.label} must be a valid date`);
        }
        
        if (param.validation) {
          if (param.validation.min !== undefined && value < param.validation.min) {
            errors.push(`${param.label} must be at least ${param.validation.min}`);
          }
          
          if (param.validation.max !== undefined && value > param.validation.max) {
            errors.push(`${param.label} must be at most ${param.validation.max}`);
          }
          
          if (param.validation.pattern && !new RegExp(param.validation.pattern).test(value)) {
            errors.push(`${param.label} format is invalid`);
          }
        }
      }
    });
    
    return {
      isValid: errors.length === 0,
      errors,
    };
  }
}

// Export singleton instance
export const reportsService = new ReportsService();
export default reportsService;
