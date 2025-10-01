/**
 * MS5.0 Floor Dashboard - OEE Service
 * 
 * This service handles OEE-related operations including OEE calculations,
 * analytics, trends, and historical data.
 */

import { apiService } from './api';

// Types
export interface OEECalculation {
  id: string;
  lineId: string;
  lineCode: string;
  period: string;
  startTime: string;
  endTime: string;
  availability: number;
  performance: number;
  quality: number;
  oee: number;
  targetOEE: number;
  actualProduction: number;
  targetProduction: number;
  goodParts: number;
  totalParts: number;
  plannedDowntime: number;
  unplannedDowntime: number;
  setupTime: number;
  changeoverTime: number;
  created_at: string;
  updated_at: string;
}

export interface OEEMetrics {
  lineId: string;
  lineCode: string;
  currentOEE: number;
  targetOEE: number;
  availability: number;
  performance: number;
  quality: number;
  efficiency: number;
  lastUpdate: string;
  period: string;
}

export interface OEETrend {
  lineId: string;
  lineCode: string;
  period: string;
  granularity: string;
  dataPoints: {
    timestamp: string;
    oee: number;
    availability: number;
    performance: number;
    quality: number;
  }[];
  averageOEE: number;
  trend: 'increasing' | 'decreasing' | 'stable';
  changePercentage: number;
}

export interface OEELoss {
  id: string;
  lineId: string;
  lineCode: string;
  period: string;
  category: 'availability' | 'performance' | 'quality';
  subcategory: string;
  description: string;
  duration: number;
  impact: number;
  frequency: number;
  cost: number;
  rootCause?: string;
  actionTaken?: string;
  created_at: string;
  updated_at: string;
}

export interface OEEAnalytics {
  lineId: string;
  lineCode: string;
  period: string;
  overallOEE: number;
  targetOEE: number;
  availability: number;
  performance: number;
  quality: number;
  losses: OEELoss[];
  trends: OEETrend[];
  benchmarks: {
    industry: number;
    bestPractice: number;
    company: number;
  };
  recommendations: string[];
  lastUpdate: string;
}

/**
 * OEE Service Class
 * 
 * Provides methods for OEE calculations, analytics, and reporting.
 * Handles OEE data processing and trend analysis.
 */
class OEEService {
  // ============================================================================
  // OEE DATA
  // ============================================================================

  /**
   * Get OEE data
   * 
   * @param lineId - Optional line ID to filter OEE data
   * @param filters - Optional filters for period and granularity
   * @returns Promise resolving to OEE data
   */
  async getOEEData(lineId?: string, filters?: { period?: string; granularity?: string }) {
    return apiService.getOEEData(lineId, filters);
  }

  /**
   * Get current OEE
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
  // OEE CALCULATIONS
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
   * Calculate availability
   * 
   * @param operatingTime - Operating time in minutes
   * @param plannedProductionTime - Planned production time in minutes
   * @returns Availability percentage
   */
  calculateAvailability(operatingTime: number, plannedProductionTime: number): number {
    if (plannedProductionTime === 0) return 0;
    return Math.min(100, (operatingTime / plannedProductionTime) * 100);
  }

  /**
   * Calculate performance
   * 
   * @param actualProduction - Actual production quantity
   * @param targetProduction - Target production quantity
   * @param operatingTime - Operating time in minutes
   * @returns Performance percentage
   */
  calculatePerformance(actualProduction: number, targetProduction: number, operatingTime: number): number {
    if (operatingTime === 0) return 0;
    const idealProduction = (targetProduction / operatingTime) * operatingTime;
    return Math.min(100, (actualProduction / idealProduction) * 100);
  }

  /**
   * Calculate quality
   * 
   * @param goodParts - Number of good parts
   * @param totalParts - Total number of parts
   * @returns Quality percentage
   */
  calculateQuality(goodParts: number, totalParts: number): number {
    if (totalParts === 0) return 0;
    return (goodParts / totalParts) * 100;
  }

  /**
   * Calculate OEE loss
   * 
   * @param targetOEE - Target OEE percentage
   * @param actualOEE - Actual OEE percentage
   * @returns OEE loss percentage
   */
  calculateOEELoss(targetOEE: number, actualOEE: number): number {
    return Math.max(0, targetOEE - actualOEE);
  }

  // ============================================================================
  // OEE ANALYSIS
  // ============================================================================

  /**
   * Analyze OEE trend
   * 
   * @param dataPoints - Array of OEE data points
   * @returns Trend analysis result
   */
  analyzeOEETrend(dataPoints: { oee: number; timestamp: string }[]): {
    trend: 'increasing' | 'decreasing' | 'stable';
    changePercentage: number;
    averageOEE: number;
  } {
    if (dataPoints.length < 2) {
      return {
        trend: 'stable',
        changePercentage: 0,
        averageOEE: dataPoints[0]?.oee || 0,
      };
    }

    const sortedPoints = dataPoints.sort((a, b) => 
      new Date(a.timestamp).getTime() - new Date(b.timestamp).getTime()
    );

    const firstOEE = sortedPoints[0].oee;
    const lastOEE = sortedPoints[sortedPoints.length - 1].oee;
    const changePercentage = ((lastOEE - firstOEE) / firstOEE) * 100;

    let trend: 'increasing' | 'decreasing' | 'stable' = 'stable';
    if (Math.abs(changePercentage) > 5) {
      trend = changePercentage > 0 ? 'increasing' : 'decreasing';
    }

    const averageOEE = sortedPoints.reduce((sum, point) => sum + point.oee, 0) / sortedPoints.length;

    return {
      trend,
      changePercentage,
      averageOEE,
    };
  }

  /**
   * Identify OEE bottlenecks
   * 
   * @param availability - Availability percentage
   * @param performance - Performance percentage
   * @param quality - Quality percentage
   * @returns Bottleneck analysis result
   */
  identifyBottlenecks(availability: number, performance: number, quality: number): {
    bottleneck: 'availability' | 'performance' | 'quality' | 'none';
    impact: number;
    recommendations: string[];
  } {
    const components = [
      { name: 'availability', value: availability },
      { name: 'performance', value: performance },
      { name: 'quality', value: quality },
    ];

    const sortedComponents = components.sort((a, b) => a.value - b.value);
    const lowestComponent = sortedComponents[0];
    const highestComponent = sortedComponents[sortedComponents.length - 1];

    const impact = highestComponent.value - lowestComponent.value;
    const bottleneck = impact > 10 ? lowestComponent.name as 'availability' | 'performance' | 'quality' : 'none';

    const recommendations: string[] = [];
    if (bottleneck === 'availability') {
      recommendations.push('Reduce planned and unplanned downtime');
      recommendations.push('Improve maintenance scheduling');
      recommendations.push('Optimize changeover procedures');
    } else if (bottleneck === 'performance') {
      recommendations.push('Optimize production speed');
      recommendations.push('Reduce minor stops');
      recommendations.push('Improve operator training');
    } else if (bottleneck === 'quality') {
      recommendations.push('Improve quality control processes');
      recommendations.push('Reduce defects and rework');
      recommendations.push('Enhance operator skills');
    }

    return {
      bottleneck,
      impact,
      recommendations,
    };
  }

  /**
   * Calculate OEE improvement potential
   * 
   * @param currentOEE - Current OEE percentage
   * @param targetOEE - Target OEE percentage
   * @param industryBenchmark - Industry benchmark OEE percentage
   * @returns Improvement potential analysis
   */
  calculateImprovementPotential(
    currentOEE: number,
    targetOEE: number,
    industryBenchmark: number
  ): {
    potential: number;
    gap: number;
    priority: 'high' | 'medium' | 'low';
  } {
    const gap = targetOEE - currentOEE;
    const potential = industryBenchmark - currentOEE;
    
    let priority: 'high' | 'medium' | 'low' = 'low';
    if (gap > 20) priority = 'high';
    else if (gap > 10) priority = 'medium';

    return {
      potential,
      gap,
      priority,
    };
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

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
   * Get component status color
   * 
   * @param component - Component name
   * @param value - Component value
   * @returns Color code for component status
   */
  getComponentStatusColor(component: string, value: number): string {
    const thresholds: Record<string, { good: number; warning: number }> = {
      'availability': { good: 90, warning: 80 },
      'performance': { good: 95, warning: 85 },
      'quality': { good: 99, warning: 95 },
    };

    const threshold = thresholds[component];
    if (!threshold) return '#9E9E9E';

    if (value >= threshold.good) return '#4CAF50';
    if (value >= threshold.warning) return '#FF9800';
    return '#F44336';
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
   * Format OEE component
   * 
   * @param component - Component value
   * @returns Formatted component string
   */
  formatComponent(component: number): string {
    return `${component.toFixed(1)}%`;
  }

  /**
   * Get OEE grade
   * 
   * @param oee - OEE percentage
   * @returns OEE grade string
   */
  getOEEGrade(oee: number): string {
    if (oee >= 90) return 'A+';
    if (oee >= 80) return 'A';
    if (oee >= 70) return 'B';
    if (oee >= 60) return 'C';
    if (oee >= 50) return 'D';
    return 'F';
  }

  /**
   * Get OEE grade color
   * 
   * @param oee - OEE percentage
   * @returns Color code for OEE grade
   */
  getOEEGradeColor(oee: number): string {
    if (oee >= 90) return '#4CAF50';
    if (oee >= 80) return '#8BC34A';
    if (oee >= 70) return '#FFC107';
    if (oee >= 60) return '#FF9800';
    if (oee >= 50) return '#FF5722';
    return '#F44336';
  }

  /**
   * Calculate OEE score
   * 
   * @param oee - OEE percentage
   * @param targetOEE - Target OEE percentage
   * @returns OEE score (0-100)
   */
  calculateOEEScore(oee: number, targetOEE: number): number {
    if (targetOEE === 0) return 0;
    return Math.min(100, (oee / targetOEE) * 100);
  }

  /**
   * Get OEE trend icon
   * 
   * @param trend - OEE trend
   * @returns Icon name for trend
   */
  getOEETrendIcon(trend: 'increasing' | 'decreasing' | 'stable'): string {
    const trendIcons: Record<string, string> = {
      'increasing': 'trending-up',
      'decreasing': 'trending-down',
      'stable': 'trending-flat',
    };
    return trendIcons[trend] || 'trending-flat';
  }

  /**
   * Get OEE trend color
   * 
   * @param trend - OEE trend
   * @returns Color code for trend
   */
  getOEETrendColor(trend: 'increasing' | 'decreasing' | 'stable'): string {
    const trendColors: Record<string, string> = {
      'increasing': '#4CAF50',
      'decreasing': '#F44336',
      'stable': '#9E9E9E',
    };
    return trendColors[trend] || '#9E9E9E';
  }

  /**
   * Format OEE loss
   * 
   * @param loss - OEE loss percentage
   * @returns Formatted loss string
   */
  formatOEELoss(loss: number): string {
    return `${loss.toFixed(1)}%`;
  }

  /**
   * Get OEE priority level
   * 
   * @param oee - OEE percentage
   * @param targetOEE - Target OEE percentage
   * @returns Priority level string
   */
  getOEEPriorityLevel(oee: number, targetOEE: number): string {
    const gap = targetOEE - oee;
    if (gap > 20) return 'Critical';
    if (gap > 10) return 'High';
    if (gap > 5) return 'Medium';
    return 'Low';
  }
}

// Export singleton instance
export const oeeService = new OEEService();
export default oeeService;
