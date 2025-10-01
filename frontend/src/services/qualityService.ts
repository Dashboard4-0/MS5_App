/**
 * MS5.0 Floor Dashboard - Quality Service
 * 
 * This service handles quality-related operations including quality checks,
 * inspections, defects, and quality management.
 */

import { apiService } from './api';

// Types
export interface QualityCheck {
  id: string;
  lineId: string;
  lineCode: string;
  productTypeId: string;
  productTypeName: string;
  checkType: 'incoming' | 'in_process' | 'final' | 'audit';
  status: 'pending' | 'in_progress' | 'passed' | 'failed' | 'cancelled';
  parameters: QualityParameter[];
  results: QualityResult[];
  checkedBy: string;
  checkedAt: string;
  notes?: string;
  created_at: string;
  updated_at: string;
}

export interface QualityParameter {
  id: string;
  name: string;
  type: 'numeric' | 'boolean' | 'text' | 'select';
  label: string;
  unit?: string;
  minValue?: number;
  maxValue?: number;
  targetValue?: number;
  tolerance?: number;
  options?: { value: any; label: string }[];
  required: boolean;
  criteria: QualityCriteria;
}

export interface QualityCriteria {
  id: string;
  parameterId: string;
  rule: 'within_range' | 'greater_than' | 'less_than' | 'equals' | 'not_equals' | 'contains' | 'not_contains';
  value: any;
  severity: 'low' | 'medium' | 'high' | 'critical';
  message: string;
}

export interface QualityRule {
  id: string;
  name: string;
  description?: string;
  productTypeId: string;
  productTypeName: string;
  parameters: QualityParameter[];
  isActive: boolean;
  createdBy: string;
  created_at: string;
  updated_at: string;
}

export interface QualityInspection {
  id: string;
  lineId: string;
  lineCode: string;
  productTypeId: string;
  productTypeName: string;
  inspectionType: 'routine' | 'spot' | 'audit' | 'customer';
  status: 'scheduled' | 'in_progress' | 'completed' | 'cancelled';
  scheduledDate: string;
  completedDate?: string;
  inspector: string;
  results: QualityResult[];
  defects: QualityDefect[];
  notes?: string;
  created_at: string;
  updated_at: string;
}

export interface QualityResult {
  id: string;
  parameterId: string;
  parameterName: string;
  value: any;
  unit?: string;
  status: 'pass' | 'fail' | 'warning';
  deviation?: number;
  notes?: string;
  timestamp: string;
}

export interface QualityDefect {
  id: string;
  inspectionId: string;
  defectCode: string;
  description: string;
  severity: 'low' | 'medium' | 'high' | 'critical';
  category: 'dimensional' | 'surface' | 'functional' | 'aesthetic' | 'safety';
  quantity: number;
  location?: string;
  rootCause?: string;
  correctiveAction?: string;
  status: 'open' | 'investigating' | 'resolved' | 'closed';
  reportedBy: string;
  reportedAt: string;
  resolvedBy?: string;
  resolvedAt?: string;
  notes?: string;
  created_at: string;
  updated_at: string;
}

export interface QualityAlert {
  id: string;
  lineId: string;
  lineCode: string;
  productTypeId: string;
  productTypeName: string;
  alertType: 'defect_rate' | 'parameter_deviation' | 'inspection_failure' | 'trend_anomaly';
  severity: 'low' | 'medium' | 'high' | 'critical';
  status: 'active' | 'acknowledged' | 'resolved' | 'dismissed';
  title: string;
  description: string;
  threshold: number;
  actualValue: number;
  triggeredAt: string;
  acknowledgedBy?: string;
  acknowledgedAt?: string;
  resolvedBy?: string;
  resolvedAt?: string;
  notes?: string;
  created_at: string;
  updated_at: string;
}

export interface QualityMetrics {
  lineId: string;
  lineCode: string;
  productTypeId: string;
  productTypeName: string;
  period: string;
  totalInspections: number;
  passedInspections: number;
  failedInspections: number;
  passRate: number;
  totalDefects: number;
  defectRate: number;
  averageDefectSeverity: number;
  topDefects: Array<{
    defectCode: string;
    description: string;
    count: number;
    percentage: number;
  }>;
  parameterDeviations: Array<{
    parameterName: string;
    deviationCount: number;
    averageDeviation: number;
  }>;
  lastUpdate: string;
}

/**
 * Quality Service Class
 * 
 * Provides methods for quality management, inspections, and defect tracking.
 * Handles quality data processing and alert generation.
 */
class QualityService {
  // ============================================================================
  // QUALITY CHECKS
  // ============================================================================

  /**
   * Get quality checks
   * 
   * @param filters - Optional filters for line ID and status
   * @returns Promise resolving to quality checks
   */
  async getQualityChecks(filters?: { lineId?: string; status?: string }) {
    return apiService.getQualityChecks(filters);
  }

  /**
   * Get specific quality check
   * 
   * @param checkId - Quality check ID
   * @returns Promise resolving to quality check data
   */
  async getQualityCheck(checkId: string) {
    return apiService.getQualityCheck(checkId);
  }

  /**
   * Create quality check
   * 
   * @param checkData - Quality check data
   * @returns Promise resolving to created quality check
   */
  async createQualityCheck(checkData: Partial<QualityCheck>) {
    return apiService.createQualityCheck(checkData);
  }

  /**
   * Update quality check
   * 
   * @param checkId - Quality check ID
   * @param checkData - Updated quality check data
   * @returns Promise resolving to updated quality check
   */
  async updateQualityCheck(checkId: string, checkData: Partial<QualityCheck>) {
    return apiService.updateQualityCheck(checkId, checkData);
  }

  /**
   * Complete quality check
   * 
   * @param checkId - Quality check ID
   * @param results - Quality check results
   * @param notes - Optional completion notes
   * @returns Promise resolving to completed quality check
   */
  async completeQualityCheck(checkId: string, results: QualityResult[], notes?: string) {
    return apiService.completeQualityCheck(checkId, results, notes);
  }

  /**
   * Cancel quality check
   * 
   * @param checkId - Quality check ID
   * @param reason - Cancellation reason
   * @returns Promise resolving to cancelled quality check
   */
  async cancelQualityCheck(checkId: string, reason: string) {
    return apiService.cancelQualityCheck(checkId, reason);
  }

  // ============================================================================
  // QUALITY INSPECTIONS
  // ============================================================================

  /**
   * Get quality inspections
   * 
   * @param filters - Optional filters for line ID and status
   * @returns Promise resolving to quality inspections
   */
  async getQualityInspections(filters?: { lineId?: string; status?: string }) {
    return apiService.getQualityInspections(filters);
  }

  /**
   * Get specific quality inspection
   * 
   * @param inspectionId - Quality inspection ID
   * @returns Promise resolving to quality inspection data
   */
  async getQualityInspection(inspectionId: string) {
    return apiService.getQualityInspection(inspectionId);
  }

  /**
   * Create quality inspection
   * 
   * @param inspectionData - Quality inspection data
   * @returns Promise resolving to created quality inspection
   */
  async createQualityInspection(inspectionData: Partial<QualityInspection>) {
    return apiService.createQualityInspection(inspectionData);
  }

  /**
   * Update quality inspection
   * 
   * @param inspectionId - Quality inspection ID
   * @param inspectionData - Updated quality inspection data
   * @returns Promise resolving to updated quality inspection
   */
  async updateQualityInspection(inspectionId: string, inspectionData: Partial<QualityInspection>) {
    return apiService.updateQualityInspection(inspectionId, inspectionData);
  }

  /**
   * Complete quality inspection
   * 
   * @param inspectionId - Quality inspection ID
   * @param results - Inspection results
   * @param defects - Found defects
   * @param notes - Optional completion notes
   * @returns Promise resolving to completed quality inspection
   */
  async completeQualityInspection(inspectionId: string, results: QualityResult[], defects: QualityDefect[], notes?: string) {
    return apiService.completeQualityInspection(inspectionId, results, defects, notes);
  }

  /**
   * Cancel quality inspection
   * 
   * @param inspectionId - Quality inspection ID
   * @param reason - Cancellation reason
   * @returns Promise resolving to cancelled quality inspection
   */
  async cancelQualityInspection(inspectionId: string, reason: string) {
    return apiService.cancelQualityInspection(inspectionId, reason);
  }

  // ============================================================================
  // QUALITY DEFECTS
  // ============================================================================

  /**
   * Get quality defects
   * 
   * @param filters - Optional filters for inspection ID and status
   * @returns Promise resolving to quality defects
   */
  async getQualityDefects(filters?: { inspectionId?: string; status?: string }) {
    return apiService.getQualityDefects(filters);
  }

  /**
   * Get specific quality defect
   * 
   * @param defectId - Quality defect ID
   * @returns Promise resolving to quality defect data
   */
  async getQualityDefect(defectId: string) {
    return apiService.getQualityDefect(defectId);
  }

  /**
   * Create quality defect
   * 
   * @param defectData - Quality defect data
   * @returns Promise resolving to created quality defect
   */
  async createQualityDefect(defectData: Partial<QualityDefect>) {
    return apiService.createQualityDefect(defectData);
  }

  /**
   * Update quality defect
   * 
   * @param defectId - Quality defect ID
   * @param defectData - Updated quality defect data
   * @returns Promise resolving to updated quality defect
   */
  async updateQualityDefect(defectId: string, defectData: Partial<QualityDefect>) {
    return apiService.updateQualityDefect(defectId, defectData);
  }

  /**
   * Resolve quality defect
   * 
   * @param defectId - Quality defect ID
   * @param resolution - Resolution description
   * @param notes - Optional resolution notes
   * @returns Promise resolving to resolved quality defect
   */
  async resolveQualityDefect(defectId: string, resolution: string, notes?: string) {
    return apiService.resolveQualityDefect(defectId, resolution, notes);
  }

  /**
   * Close quality defect
   * 
   * @param defectId - Quality defect ID
   * @param notes - Optional closure notes
   * @returns Promise resolving to closed quality defect
   */
  async closeQualityDefect(defectId: string, notes?: string) {
    return apiService.closeQualityDefect(defectId, notes);
  }

  // ============================================================================
  // QUALITY ALERTS
  // ============================================================================

  /**
   * Get quality alerts
   * 
   * @param filters - Optional filters for line ID and status
   * @returns Promise resolving to quality alerts
   */
  async getQualityAlerts(filters?: { lineId?: string; status?: string }) {
    return apiService.getQualityAlerts(filters);
  }

  /**
   * Get specific quality alert
   * 
   * @param alertId - Quality alert ID
   * @returns Promise resolving to quality alert data
   */
  async getQualityAlert(alertId: string) {
    return apiService.getQualityAlert(alertId);
  }

  /**
   * Acknowledge quality alert
   * 
   * @param alertId - Quality alert ID
   * @param notes - Optional acknowledgment notes
   * @returns Promise resolving to acknowledged quality alert
   */
  async acknowledgeQualityAlert(alertId: string, notes?: string) {
    return apiService.acknowledgeQualityAlert(alertId, notes);
  }

  /**
   * Resolve quality alert
   * 
   * @param alertId - Quality alert ID
   * @param resolution - Resolution description
   * @param notes - Optional resolution notes
   * @returns Promise resolving to resolved quality alert
   */
  async resolveQualityAlert(alertId: string, resolution: string, notes?: string) {
    return apiService.resolveQualityAlert(alertId, resolution, notes);
  }

  /**
   * Dismiss quality alert
   * 
   * @param alertId - Quality alert ID
   * @param reason - Dismissal reason
   * @returns Promise resolving to dismissed quality alert
   */
  async dismissQualityAlert(alertId: string, reason: string) {
    return apiService.dismissQualityAlert(alertId, reason);
  }

  // ============================================================================
  // QUALITY METRICS
  // ============================================================================

  /**
   * Get quality metrics
   * 
   * @param filters - Optional filters for line ID and date range
   * @returns Promise resolving to quality metrics
   */
  async getQualityMetrics(filters?: { lineId?: string; dateRange?: { start: string; end: string } }) {
    return apiService.getQualityMetrics(filters);
  }

  /**
   * Get quality analytics
   * 
   * @param filters - Optional filters for line ID and date range
   * @returns Promise resolving to quality analytics
   */
  async getQualityAnalytics(filters?: { lineId?: string; dateRange?: { start: string; end: string } }) {
    return apiService.getQualityAnalytics(filters);
  }

  /**
   * Get quality trends
   * 
   * @param filters - Optional filters for line ID and date range
   * @returns Promise resolving to quality trends
   */
  async getQualityTrends(filters?: { lineId?: string; dateRange?: { start: string; end: string } }) {
    return apiService.getQualityTrends(filters);
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /**
   * Get check type color
   * 
   * @param checkType - Quality check type
   * @returns Color code for check type
   */
  getCheckTypeColor(checkType: string): string {
    const typeColors: Record<string, string> = {
      'incoming': '#2196F3',
      'in_process': '#FF9800',
      'final': '#4CAF50',
      'audit': '#9C27B0',
    };
    return typeColors[checkType] || '#9E9E9E';
  }

  /**
   * Get inspection type color
   * 
   * @param inspectionType - Quality inspection type
   * @returns Color code for inspection type
   */
  getInspectionTypeColor(inspectionType: string): string {
    const typeColors: Record<string, string> = {
      'routine': '#4CAF50',
      'spot': '#FF9800',
      'audit': '#9C27B0',
      'customer': '#2196F3',
    };
    return typeColors[inspectionType] || '#9E9E9E';
  }

  /**
   * Get defect severity color
   * 
   * @param severity - Defect severity
   * @returns Color code for defect severity
   */
  getDefectSeverityColor(severity: string): string {
    const severityColors: Record<string, string> = {
      'low': '#4CAF50',
      'medium': '#FF9800',
      'high': '#FF5722',
      'critical': '#F44336',
    };
    return severityColors[severity] || '#9E9E9E';
  }

  /**
   * Get defect category color
   * 
   * @param category - Defect category
   * @returns Color code for defect category
   */
  getDefectCategoryColor(category: string): string {
    const categoryColors: Record<string, string> = {
      'dimensional': '#2196F3',
      'surface': '#FF9800',
      'functional': '#F44336',
      'aesthetic': '#9C27B0',
      'safety': '#F44336',
    };
    return categoryColors[category] || '#9E9E9E';
  }

  /**
   * Get alert severity color
   * 
   * @param severity - Alert severity
   * @returns Color code for alert severity
   */
  getAlertSeverityColor(severity: string): string {
    const severityColors: Record<string, string> = {
      'low': '#4CAF50',
      'medium': '#FF9800',
      'high': '#FF5722',
      'critical': '#F44336',
    };
    return severityColors[severity] || '#9E9E9E';
  }

  /**
   * Get result status color
   * 
   * @param status - Result status
   * @returns Color code for result status
   */
  getResultStatusColor(status: string): string {
    const statusColors: Record<string, string> = {
      'pass': '#4CAF50',
      'fail': '#F44336',
      'warning': '#FF9800',
    };
    return statusColors[status] || '#9E9E9E';
  }

  /**
   * Calculate pass rate
   * 
   * @param passed - Number of passed inspections
   * @param total - Total number of inspections
   * @returns Pass rate percentage
   */
  calculatePassRate(passed: number, total: number): number {
    if (total === 0) return 0;
    return (passed / total) * 100;
  }

  /**
   * Calculate defect rate
   * 
   * @param defects - Number of defects
   * @param total - Total number of units inspected
   * @returns Defect rate percentage
   */
  calculateDefectRate(defects: number, total: number): number {
    if (total === 0) return 0;
    return (defects / total) * 100;
  }

  /**
   * Calculate average defect severity
   * 
   * @param defects - Array of defects with severity
   * @returns Average defect severity score
   */
  calculateAverageDefectSeverity(defects: Array<{ severity: string }>): number {
    if (defects.length === 0) return 0;
    
    const severityScores: Record<string, number> = {
      'low': 1,
      'medium': 2,
      'high': 3,
      'critical': 4,
    };
    
    const totalScore = defects.reduce((sum, defect) => {
      return sum + (severityScores[defect.severity] || 0);
    }, 0);
    
    return totalScore / defects.length;
  }

  /**
   * Format pass rate
   * 
   * @param passRate - Pass rate percentage
   * @returns Formatted pass rate string
   */
  formatPassRate(passRate: number): string {
    return `${passRate.toFixed(1)}%`;
  }

  /**
   * Format defect rate
   * 
   * @param defectRate - Defect rate percentage
   * @returns Formatted defect rate string
   */
  formatDefectRate(defectRate: number): string {
    return `${defectRate.toFixed(2)}%`;
  }

  /**
   * Get quality grade
   * 
   * @param passRate - Pass rate percentage
   * @returns Quality grade string
   */
  getQualityGrade(passRate: number): string {
    if (passRate >= 99) return 'A+';
    if (passRate >= 95) return 'A';
    if (passRate >= 90) return 'B';
    if (passRate >= 85) return 'C';
    if (passRate >= 80) return 'D';
    return 'F';
  }

  /**
   * Get quality grade color
   * 
   * @param passRate - Pass rate percentage
   * @returns Color code for quality grade
   */
  getQualityGradeColor(passRate: number): string {
    if (passRate >= 99) return '#4CAF50';
    if (passRate >= 95) return '#8BC34A';
    if (passRate >= 90) return '#FFC107';
    if (passRate >= 85) return '#FF9800';
    if (passRate >= 80) return '#FF5722';
    return '#F44336';
  }

  /**
   * Get check type icon
   * 
   * @param checkType - Quality check type
   * @returns Icon name for check type
   */
  getCheckTypeIcon(checkType: string): string {
    const typeIcons: Record<string, string> = {
      'incoming': 'package',
      'in_process': 'settings',
      'final': 'check-circle',
      'audit': 'shield-check',
    };
    return typeIcons[checkType] || 'circle';
  }

  /**
   * Get inspection type icon
   * 
   * @param inspectionType - Quality inspection type
   * @returns Icon name for inspection type
   */
  getInspectionTypeIcon(inspectionType: string): string {
    const typeIcons: Record<string, string> = {
      'routine': 'calendar',
      'spot': 'target',
      'audit': 'shield-check',
      'customer': 'user-check',
    };
    return typeIcons[inspectionType] || 'circle';
  }

  /**
   * Get defect severity icon
   * 
   * @param severity - Defect severity
   * @returns Icon name for defect severity
   */
  getDefectSeverityIcon(severity: string): string {
    const severityIcons: Record<string, string> = {
      'low': 'info',
      'medium': 'alert-circle',
      'high': 'alert-triangle',
      'critical': 'alert-octagon',
    };
    return severityIcons[severity] || 'circle';
  }

  /**
   * Get alert type icon
   * 
   * @param alertType - Alert type
   * @returns Icon name for alert type
   */
  getAlertTypeIcon(alertType: string): string {
    const typeIcons: Record<string, string> = {
      'defect_rate': 'trending-up',
      'parameter_deviation': 'alert-triangle',
      'inspection_failure': 'x-circle',
      'trend_anomaly': 'activity',
    };
    return typeIcons[alertType] || 'circle';
  }

  /**
   * Get quality priority level
   * 
   * @param passRate - Pass rate percentage
   * @param defectRate - Defect rate percentage
   * @returns Priority level string
   */
  getQualityPriorityLevel(passRate: number, defectRate: number): string {
    if (passRate < 80 || defectRate > 5) return 'Critical';
    if (passRate < 90 || defectRate > 2) return 'High';
    if (passRate < 95 || defectRate > 1) return 'Medium';
    return 'Low';
  }
}

// Export singleton instance
export const qualityService = new QualityService();
export default qualityService;
