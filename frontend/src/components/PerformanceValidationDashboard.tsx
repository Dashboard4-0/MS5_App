/**
 * MS5.0 Floor Dashboard - Performance Validation Dashboard Component
 * 
 * This component provides a comprehensive performance validation dashboard:
 * - Real-time performance validation
 * - Validation status visualization
 * - Performance target monitoring
 * - Validation history and trends
 * - Zero redundancy architecture
 */

import React, { useState, useEffect, useCallback, useMemo } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  RefreshControl,
  Alert,
  Dimensions,
} from 'react-native';
import { LineChart, BarChart, PieChart } from 'react-native-chart-kit';
import { MaterialIcons } from '@expo/vector-icons';

import { ApiService } from '../services/api';
import { useUXMetrics } from '../hooks/useUXMetrics';

interface PerformanceValidationDashboardProps {
  onValidationSelect?: (validationId: string) => void;
  onTargetSelect?: (targetId: string) => void;
  refreshInterval?: number;
  showDetails?: boolean;
}

interface ValidationDashboardData {
  currentStatus: {
    overallStatus: 'passed' | 'warning' | 'failed';
    overallSeverity: 'low' | 'medium' | 'high' | 'critical';
    healthScore: number;
    lastValidation: number;
  };
  summary: {
    totalAreas: number;
    passedAreas: number;
    warningAreas: number;
    failedAreas: number;
    criticalIssues: number;
    highIssues: number;
    mediumIssues: number;
    lowIssues: number;
  };
  areas: Array<{
    area: string;
    status: 'passed' | 'warning' | 'failed';
    severity: 'low' | 'medium' | 'high' | 'critical';
    targetCount: number;
    passedTargets: number;
    warningTargets: number;
    failedTargets: number;
  }>;
  recommendations: string[];
  metrics: {
    totalAreasValidated: number;
    passedAreas: number;
    warningAreas: number;
    failedAreas: number;
    totalTargets: number;
    passedTargets: number;
    warningTargets: number;
    failedTargets: number;
  };
}

const PerformanceValidationDashboard: React.FC<PerformanceValidationDashboardProps> = ({
  onValidationSelect,
  onTargetSelect,
  refreshInterval = 60000,
  showDetails = true,
}) => {
  const [dashboardData, setDashboardData] = useState<ValidationDashboardData | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [selectedView, setSelectedView] = useState<'overview' | 'areas' | 'targets' | 'trends'>('overview');
  const [validationHistory, setValidationHistory] = useState<any[]>([]);
  const [validationTrends, setValidationTrends] = useState<any>(null);

  const apiService = useMemo(() => new ApiService(), []);
  const { recordUXMetric } = useUXMetrics();

  const screenWidth = Dimensions.get('window').width;

  /**
   * Load dashboard data
   */
  const loadDashboardData = useCallback(async () => {
    try {
      setError(null);
      const response = await apiService.get('/api/performance/validation/dashboard');
      setDashboardData(response.data);
      
      // Record UX metric
      recordUXMetric('validation_dashboard_load_time', Date.now());
      
    } catch (err) {
      console.error('Failed to load validation dashboard data:', err);
      setError('Failed to load dashboard data');
    }
  }, [apiService, recordUXMetric]);

  /**
   * Load validation history
   */
  const loadValidationHistory = useCallback(async () => {
    try {
      const response = await apiService.get('/api/performance/validation/history?limit=10');
      setValidationHistory(response.data.validations || []);
    } catch (err) {
      console.error('Failed to load validation history:', err);
    }
  }, [apiService]);

  /**
   * Load validation trends
   */
  const loadValidationTrends = useCallback(async () => {
    try {
      const response = await apiService.get('/api/performance/validation/trends?time_range=7d');
      setValidationTrends(response.data);
    } catch (err) {
      console.error('Failed to load validation trends:', err);
    }
  }, [apiService]);

  /**
   * Refresh dashboard data
   */
  const handleRefresh = useCallback(async () => {
    setRefreshing(true);
    await Promise.all([
      loadDashboardData(),
      loadValidationHistory(),
      loadValidationTrends(),
    ]);
    setRefreshing(false);
  }, [loadDashboardData, loadValidationHistory, loadValidationTrends]);

  /**
   * Load initial data
   */
  useEffect(() => {
    loadDashboardData();
    loadValidationHistory();
    loadValidationTrends();
  }, [loadDashboardData, loadValidationHistory, loadValidationTrends]);

  /**
   * Setup auto-refresh
   */
  useEffect(() => {
    if (refreshInterval > 0) {
      const interval = setInterval(loadDashboardData, refreshInterval);
      return () => clearInterval(interval);
    }
  }, [loadDashboardData, refreshInterval]);

  /**
   * Handle validation selection
   */
  const handleValidationSelect = useCallback((validationId: string) => {
    if (onValidationSelect) {
      onValidationSelect(validationId);
    }
  }, [onValidationSelect]);

  /**
   * Handle target selection
   */
  const handleTargetSelect = useCallback((targetId: string) => {
    if (onTargetSelect) {
      onTargetSelect(targetId);
    }
  }, [onTargetSelect]);

  /**
   * Run new validation
   */
  const handleRunValidation = useCallback(async () => {
    try {
      setLoading(true);
      const response = await apiService.post('/api/performance/validation/validate', {
        include_details: true,
        include_recommendations: true,
        include_metrics: true,
      });
      
      // Refresh dashboard data
      await loadDashboardData();
      
      Alert.alert('Success', 'Performance validation completed successfully');
      
    } catch (err) {
      console.error('Failed to run validation:', err);
      Alert.alert('Error', 'Failed to run performance validation');
    } finally {
      setLoading(false);
    }
  }, [apiService, loadDashboardData]);

  /**
   * Get status color
   */
  const getStatusColor = useCallback((status: string) => {
    switch (status) {
      case 'passed':
        return '#28a745';
      case 'warning':
        return '#ffc107';
      case 'failed':
        return '#dc3545';
      default:
        return '#6c757d';
    }
  }, []);

  /**
   * Get severity color
   */
  const getSeverityColor = useCallback((severity: string) => {
    switch (severity) {
      case 'critical':
        return '#dc3545';
      case 'high':
        return '#fd7e14';
      case 'medium':
        return '#ffc107';
      case 'low':
        return '#28a745';
      default:
        return '#6c757d';
    }
  }, []);

  /**
   * Get status icon
   */
  const getStatusIcon = useCallback((status: string) => {
    switch (status) {
      case 'passed':
        return 'check-circle';
      case 'warning':
        return 'warning';
      case 'failed':
        return 'error';
      default:
        return 'help';
    }
  }, []);

  /**
   * Format timestamp
   */
  const formatTimestamp = useCallback((timestamp: number) => {
    return new Date(timestamp).toLocaleString();
  }, []);

  /**
   * Get time since
   */
  const getTimeSince = useCallback((timestamp: number) => {
    const now = Date.now();
    const diff = now - timestamp;
    
    if (diff < 60000) return 'Just now';
    if (diff < 3600000) return `${Math.floor(diff / 60000)} minutes ago`;
    if (diff < 86400000) return `${Math.floor(diff / 3600000)} hours ago`;
    return `${Math.floor(diff / 86400000)} days ago`;
  }, []);

  /**
   * Render overview section
   */
  const renderOverview = useCallback(() => {
    if (!dashboardData) return null;

    const { currentStatus, summary } = dashboardData;

    return (
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Performance Validation Overview</Text>
        
        {/* Current Status */}
        <View style={styles.statusContainer}>
          <View style={[
            styles.statusCard,
            { backgroundColor: getStatusColor(currentStatus.overallStatus) }
          ]}>
            <MaterialIcons 
              name={getStatusIcon(currentStatus.overallStatus)} 
              size={24} 
              color="white" 
            />
            <Text style={styles.statusText}>
              {currentStatus.overallStatus.toUpperCase()}
            </Text>
            <Text style={styles.severityText}>
              {currentStatus.overallSeverity.toUpperCase()}
            </Text>
          </View>
        </View>

        {/* Health Score */}
        <View style={styles.healthScoreContainer}>
          <Text style={styles.healthScoreLabel}>Health Score</Text>
          <Text style={styles.healthScoreValue}>{currentStatus.healthScore.toFixed(1)}%</Text>
          <View style={styles.healthScoreBar}>
            <View 
              style={[
                styles.healthScoreFill,
                { 
                  width: `${currentStatus.healthScore}%`,
                  backgroundColor: getStatusColor(currentStatus.overallStatus)
                }
              ]} 
            />
          </View>
        </View>

        {/* Summary Metrics */}
        <View style={styles.metricsContainer}>
          <View style={styles.metricCard}>
            <Text style={styles.metricValue}>{summary.totalAreas}</Text>
            <Text style={styles.metricLabel}>Total Areas</Text>
          </View>
          <View style={styles.metricCard}>
            <Text style={styles.metricValue}>{summary.passedAreas}</Text>
            <Text style={styles.metricLabel}>Passed</Text>
          </View>
          <View style={styles.metricCard}>
            <Text style={styles.metricValue}>{summary.warningAreas}</Text>
            <Text style={styles.metricLabel}>Warnings</Text>
          </View>
          <View style={styles.metricCard}>
            <Text style={styles.metricValue}>{summary.failedAreas}</Text>
            <Text style={styles.metricLabel}>Failed</Text>
          </View>
        </View>

        {/* Issues Breakdown */}
        <View style={styles.issuesContainer}>
          <Text style={styles.issuesTitle}>Issues by Severity</Text>
          <View style={styles.issuesChart}>
            <PieChart
              data={[
                {
                  name: 'Critical',
                  population: summary.criticalIssues,
                  color: '#dc3545',
                  legendFontColor: '#7F7F7F',
                  legendFontSize: 12,
                },
                {
                  name: 'High',
                  population: summary.highIssues,
                  color: '#fd7e14',
                  legendFontColor: '#7F7F7F',
                  legendFontSize: 12,
                },
                {
                  name: 'Medium',
                  population: summary.mediumIssues,
                  color: '#ffc107',
                  legendFontColor: '#7F7F7F',
                  legendFontSize: 12,
                },
                {
                  name: 'Low',
                  population: summary.lowIssues,
                  color: '#28a745',
                  legendFontColor: '#7F7F7F',
                  legendFontSize: 12,
                },
              ]}
              width={screenWidth - 80}
              height={200}
              chartConfig={{
                color: (opacity = 1) => `rgba(220, 53, 69, ${opacity})`,
              }}
              accessor="population"
              backgroundColor="transparent"
              paddingLeft="15"
              style={styles.chart}
            />
          </View>
        </View>

        {/* Last Validation */}
        <View style={styles.lastValidationContainer}>
          <Text style={styles.lastValidationLabel}>Last Validation</Text>
          <Text style={styles.lastValidationTime}>
            {getTimeSince(currentStatus.lastValidation)}
          </Text>
        </View>
      </View>
    );
  }, [dashboardData, getStatusColor, getStatusIcon, getTimeSince, screenWidth]);

  /**
   * Render areas section
   */
  const renderAreas = useCallback(() => {
    if (!dashboardData) return null;

    const { areas } = dashboardData;

    return (
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Validation Areas</Text>
        
        {areas.map((area, index) => (
          <TouchableOpacity
            key={area.area}
            style={styles.areaCard}
            onPress={() => handleValidationSelect(area.area)}
          >
            <View style={styles.areaHeader}>
              <MaterialIcons 
                name={getStatusIcon(area.status)} 
                size={20} 
                color={getStatusColor(area.status)} 
              />
              <Text style={styles.areaName}>{area.area}</Text>
              <Text style={[
                styles.areaSeverity,
                { color: getSeverityColor(area.severity) }
              ]}>
                {area.severity}
              </Text>
            </View>
            
            <View style={styles.areaMetrics}>
              <View style={styles.areaMetric}>
                <Text style={styles.areaMetricValue}>{area.targetCount}</Text>
                <Text style={styles.areaMetricLabel}>Targets</Text>
              </View>
              <View style={styles.areaMetric}>
                <Text style={[styles.areaMetricValue, { color: '#28a745' }]}>
                  {area.passedTargets}
                </Text>
                <Text style={styles.areaMetricLabel}>Passed</Text>
              </View>
              <View style={styles.areaMetric}>
                <Text style={[styles.areaMetricValue, { color: '#ffc107' }]}>
                  {area.warningTargets}
                </Text>
                <Text style={styles.areaMetricLabel}>Warnings</Text>
              </View>
              <View style={styles.areaMetric}>
                <Text style={[styles.areaMetricValue, { color: '#dc3545' }]}>
                  {area.failedTargets}
                </Text>
                <Text style={styles.areaMetricLabel}>Failed</Text>
              </View>
            </View>
          </TouchableOpacity>
        ))}
      </View>
    );
  }, [dashboardData, handleValidationSelect, getStatusIcon, getStatusColor, getSeverityColor]);

  /**
   * Render targets section
   */
  const renderTargets = useCallback(() => {
    if (!dashboardData) return null;

    const { metrics } = dashboardData;

    return (
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Performance Targets</Text>
        
        {/* Targets Summary */}
        <View style={styles.targetsSummary}>
          <View style={styles.targetSummaryCard}>
            <Text style={styles.targetSummaryValue}>{metrics.totalTargets}</Text>
            <Text style={styles.targetSummaryLabel}>Total Targets</Text>
          </View>
          <View style={styles.targetSummaryCard}>
            <Text style={[styles.targetSummaryValue, { color: '#28a745' }]}>
              {metrics.passedTargets}
            </Text>
            <Text style={styles.targetSummaryLabel}>Passed</Text>
          </View>
          <View style={styles.targetSummaryCard}>
            <Text style={[styles.targetSummaryValue, { color: '#ffc107' }]}>
              {metrics.warningTargets}
            </Text>
            <Text style={styles.targetSummaryLabel}>Warnings</Text>
          </View>
          <View style={styles.targetSummaryCard}>
            <Text style={[styles.targetSummaryValue, { color: '#dc3545' }]}>
              {metrics.failedTargets}
            </Text>
            <Text style={styles.targetSummaryLabel}>Failed</Text>
          </View>
        </View>

        {/* Targets Chart */}
        <View style={styles.chartContainer}>
          <Text style={styles.chartTitle}>Targets Status Distribution</Text>
          <BarChart
            data={{
              labels: ['Passed', 'Warnings', 'Failed'],
              datasets: [{
                data: [metrics.passedTargets, metrics.warningTargets, metrics.failedTargets],
              }],
            }}
            width={screenWidth - 40}
            height={200}
            chartConfig={{
              backgroundColor: '#ffffff',
              backgroundGradientFrom: '#ffffff',
              backgroundGradientTo: '#ffffff',
              decimalPlaces: 0,
              color: (opacity = 1) => `rgba(220, 53, 69, ${opacity})`,
              labelColor: (opacity = 1) => `rgba(0, 0, 0, ${opacity})`,
              style: {
                borderRadius: 16,
              },
              propsForDots: {
                r: '4',
                strokeWidth: '2',
                stroke: '#dc3545',
              },
            }}
            style={styles.chart}
          />
        </View>

        {/* Recommendations */}
        <View style={styles.recommendationsContainer}>
          <Text style={styles.recommendationsTitle}>Top Recommendations</Text>
          {dashboardData.recommendations.slice(0, 5).map((recommendation, index) => (
            <View key={index} style={styles.recommendationCard}>
              <MaterialIcons name="lightbulb" size={16} color="#ffc107" />
              <Text style={styles.recommendationText}>{recommendation}</Text>
            </View>
          ))}
        </View>
      </View>
    );
  }, [dashboardData, screenWidth]);

  /**
   * Render trends section
   */
  const renderTrends = useCallback(() => {
    if (!validationTrends) return null;

    const { trends } = validationTrends;

    return (
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Validation Trends</Text>
        
        {/* Health Score Trend */}
        <View style={styles.chartContainer}>
          <Text style={styles.chartTitle}>Health Score Trend (7 Days)</Text>
          <LineChart
            data={{
              labels: ['6d ago', '5d ago', '4d ago', '3d ago', '2d ago', '1d ago', 'Today'],
              datasets: [{
                data: trends.health_score,
                color: (opacity = 1) => `rgba(40, 167, 69, ${opacity})`,
                strokeWidth: 2,
              }],
            }}
            width={screenWidth - 40}
            height={200}
            chartConfig={{
              backgroundColor: '#ffffff',
              backgroundGradientFrom: '#ffffff',
              backgroundGradientTo: '#ffffff',
              decimalPlaces: 0,
              color: (opacity = 1) => `rgba(40, 167, 69, ${opacity})`,
              labelColor: (opacity = 1) => `rgba(0, 0, 0, ${opacity})`,
              style: {
                borderRadius: 16,
              },
              propsForDots: {
                r: '4',
                strokeWidth: '2',
                stroke: '#28a745',
              },
            }}
            bezier
            style={styles.chart}
          />
        </View>

        {/* Status Trend */}
        <View style={styles.chartContainer}>
          <Text style={styles.chartTitle}>Status Distribution Trend</Text>
          <LineChart
            data={{
              labels: ['6d ago', '5d ago', '4d ago', '3d ago', '2d ago', '1d ago', 'Today'],
              datasets: [
                {
                  data: trends.overall_status.passed,
                  color: (opacity = 1) => `rgba(40, 167, 69, ${opacity})`,
                  strokeWidth: 2,
                },
                {
                  data: trends.overall_status.warning,
                  color: (opacity = 1) => `rgba(255, 193, 7, ${opacity})`,
                  strokeWidth: 2,
                },
                {
                  data: trends.overall_status.failed,
                  color: (opacity = 1) => `rgba(220, 53, 69, ${opacity})`,
                  strokeWidth: 2,
                },
              ],
            }}
            width={screenWidth - 40}
            height={200}
            chartConfig={{
              backgroundColor: '#ffffff',
              backgroundGradientFrom: '#ffffff',
              backgroundGradientTo: '#ffffff',
              decimalPlaces: 0,
              color: (opacity = 1) => `rgba(220, 53, 69, ${opacity})`,
              labelColor: (opacity = 1) => `rgba(0, 0, 0, ${opacity})`,
              style: {
                borderRadius: 16,
              },
              propsForDots: {
                r: '4',
                strokeWidth: '2',
                stroke: '#dc3545',
              },
            }}
            bezier
            style={styles.chart}
          />
        </View>

        {/* Recent Validations */}
        <View style={styles.recentValidationsContainer}>
          <Text style={styles.recentValidationsTitle}>Recent Validations</Text>
          {validationHistory.slice(0, 5).map((validation, index) => (
            <TouchableOpacity
              key={validation.validation_id}
              style={styles.recentValidationCard}
              onPress={() => handleValidationSelect(validation.validation_id)}
            >
              <View style={styles.recentValidationHeader}>
                <MaterialIcons 
                  name={getStatusIcon(validation.overall_status)} 
                  size={16} 
                  color={getStatusColor(validation.overall_status)} 
                />
                <Text style={styles.recentValidationId}>
                  {validation.validation_id.substring(0, 8)}...
                </Text>
                <Text style={styles.recentValidationTime}>
                  {getTimeSince(validation.timestamp * 1000)}
                </Text>
              </View>
              <Text style={styles.recentValidationStatus}>
                {validation.overall_status.toUpperCase()} - {validation.overall_severity.toUpperCase()}
              </Text>
              <Text style={styles.recentValidationSummary}>
                {validation.passed_areas}/{validation.total_areas} areas passed
              </Text>
            </TouchableOpacity>
          ))}
        </View>
      </View>
    );
  }, [validationTrends, validationHistory, handleValidationSelect, getStatusIcon, getStatusColor, getTimeSince, screenWidth]);

  /**
   * Render loading state
   */
  if (loading) {
    return (
      <View style={styles.loadingContainer}>
        <MaterialIcons name="refresh" size={48} color="#6c757d" />
        <Text style={styles.loadingText}>Loading validation dashboard...</Text>
      </View>
    );
  }

  /**
   * Render error state
   */
  if (error) {
    return (
      <View style={styles.errorContainer}>
        <MaterialIcons name="error" size={48} color="#dc3545" />
        <Text style={styles.errorText}>{error}</Text>
        <TouchableOpacity style={styles.retryButton} onPress={handleRefresh}>
          <Text style={styles.retryButtonText}>Retry</Text>
        </TouchableOpacity>
      </View>
    );
  }

  /**
   * Render main content
   */
  return (
    <ScrollView
      style={styles.container}
      refreshControl={
        <RefreshControl refreshing={refreshing} onRefresh={handleRefresh} />
      }
    >
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.title}>Performance Validation Dashboard</Text>
        <View style={styles.headerActions}>
          <TouchableOpacity style={styles.runValidationButton} onPress={handleRunValidation}>
            <MaterialIcons name="play-arrow" size={20} color="#ffffff" />
            <Text style={styles.runValidationButtonText}>Run Validation</Text>
          </TouchableOpacity>
        </View>
        <View style={styles.viewSelector}>
          {(['overview', 'areas', 'targets', 'trends'] as const).map((view) => (
            <TouchableOpacity
              key={view}
              style={[
                styles.viewButton,
                selectedView === view && styles.viewButtonActive
              ]}
              onPress={() => setSelectedView(view)}
            >
              <Text style={[
                styles.viewButtonText,
                selectedView === view && styles.viewButtonTextActive
              ]}>
                {view.charAt(0).toUpperCase() + view.slice(1)}
              </Text>
            </TouchableOpacity>
          ))}
        </View>
      </View>

      {/* Content */}
      {selectedView === 'overview' && renderOverview()}
      {selectedView === 'areas' && renderAreas()}
      {selectedView === 'targets' && renderTargets()}
      {selectedView === 'trends' && renderTrends()}
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f8f9fa',
  },
  header: {
    backgroundColor: '#ffffff',
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#e9ecef',
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#212529',
    marginBottom: 16,
  },
  headerActions: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    marginBottom: 16,
  },
  runValidationButton: {
    backgroundColor: '#007bff',
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 8,
  },
  runValidationButtonText: {
    color: '#ffffff',
    fontSize: 14,
    fontWeight: '600',
    marginLeft: 4,
  },
  viewSelector: {
    flexDirection: 'row',
    backgroundColor: '#f8f9fa',
    borderRadius: 8,
    padding: 4,
  },
  viewButton: {
    flex: 1,
    paddingVertical: 8,
    paddingHorizontal: 12,
    borderRadius: 6,
    alignItems: 'center',
  },
  viewButtonActive: {
    backgroundColor: '#007bff',
  },
  viewButtonText: {
    fontSize: 14,
    fontWeight: '500',
    color: '#6c757d',
  },
  viewButtonTextActive: {
    color: '#ffffff',
  },
  section: {
    backgroundColor: '#ffffff',
    margin: 16,
    borderRadius: 12,
    padding: 16,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#212529',
    marginBottom: 16,
  },
  statusContainer: {
    alignItems: 'center',
    marginBottom: 24,
  },
  statusCard: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderRadius: 8,
    minWidth: 120,
    justifyContent: 'center',
  },
  statusText: {
    color: '#ffffff',
    fontSize: 16,
    fontWeight: 'bold',
    marginLeft: 8,
  },
  severityText: {
    color: '#ffffff',
    fontSize: 12,
    marginLeft: 8,
  },
  healthScoreContainer: {
    alignItems: 'center',
    marginBottom: 24,
  },
  healthScoreLabel: {
    fontSize: 16,
    fontWeight: '600',
    color: '#212529',
    marginBottom: 8,
  },
  healthScoreValue: {
    fontSize: 32,
    fontWeight: 'bold',
    color: '#212529',
    marginBottom: 8,
  },
  healthScoreBar: {
    width: '100%',
    height: 8,
    backgroundColor: '#e9ecef',
    borderRadius: 4,
    overflow: 'hidden',
  },
  healthScoreFill: {
    height: '100%',
    borderRadius: 4,
  },
  metricsContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
    marginBottom: 24,
  },
  metricCard: {
    backgroundColor: '#f8f9fa',
    borderRadius: 8,
    padding: 16,
    alignItems: 'center',
    width: '48%',
    marginBottom: 8,
  },
  metricValue: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#212529',
  },
  metricLabel: {
    fontSize: 12,
    color: '#6c757d',
    marginTop: 4,
  },
  issuesContainer: {
    marginBottom: 24,
  },
  issuesTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#212529',
    marginBottom: 12,
  },
  issuesChart: {
    alignItems: 'center',
  },
  chartContainer: {
    marginBottom: 24,
  },
  chartTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#212529',
    marginBottom: 12,
  },
  chart: {
    borderRadius: 16,
  },
  lastValidationContainer: {
    alignItems: 'center',
  },
  lastValidationLabel: {
    fontSize: 14,
    color: '#6c757d',
    marginBottom: 4,
  },
  lastValidationTime: {
    fontSize: 16,
    fontWeight: '600',
    color: '#212529',
  },
  areaCard: {
    backgroundColor: '#f8f9fa',
    borderRadius: 8,
    padding: 12,
    marginBottom: 8,
  },
  areaHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 8,
  },
  areaName: {
    fontSize: 16,
    fontWeight: '600',
    color: '#212529',
    flex: 1,
    marginLeft: 8,
  },
  areaSeverity: {
    fontSize: 12,
    fontWeight: '600',
  },
  areaMetrics: {
    flexDirection: 'row',
    justifyContent: 'space-around',
  },
  areaMetric: {
    alignItems: 'center',
  },
  areaMetricValue: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#212529',
  },
  areaMetricLabel: {
    fontSize: 10,
    color: '#6c757d',
    marginTop: 2,
  },
  targetsSummary: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
    marginBottom: 24,
  },
  targetSummaryCard: {
    backgroundColor: '#f8f9fa',
    borderRadius: 8,
    padding: 16,
    alignItems: 'center',
    width: '48%',
    marginBottom: 8,
  },
  targetSummaryValue: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#212529',
  },
  targetSummaryLabel: {
    fontSize: 12,
    color: '#6c757d',
    marginTop: 4,
  },
  recommendationsContainer: {
    marginTop: 16,
  },
  recommendationsTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#212529',
    marginBottom: 12,
  },
  recommendationCard: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    backgroundColor: '#f8f9fa',
    borderRadius: 8,
    padding: 12,
    marginBottom: 8,
  },
  recommendationText: {
    fontSize: 14,
    color: '#212529',
    flex: 1,
    marginLeft: 8,
  },
  recentValidationsContainer: {
    marginTop: 16,
  },
  recentValidationsTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#212529',
    marginBottom: 12,
  },
  recentValidationCard: {
    backgroundColor: '#f8f9fa',
    borderRadius: 8,
    padding: 12,
    marginBottom: 8,
  },
  recentValidationHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 4,
  },
  recentValidationId: {
    fontSize: 14,
    fontWeight: '600',
    color: '#212529',
    flex: 1,
    marginLeft: 8,
  },
  recentValidationTime: {
    fontSize: 12,
    color: '#6c757d',
  },
  recentValidationStatus: {
    fontSize: 14,
    color: '#212529',
    marginBottom: 2,
  },
  recentValidationSummary: {
    fontSize: 12,
    color: '#6c757d',
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#f8f9fa',
  },
  loadingText: {
    fontSize: 16,
    color: '#6c757d',
    marginTop: 16,
  },
  errorContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#f8f9fa',
    padding: 32,
  },
  errorText: {
    fontSize: 16,
    color: '#dc3545',
    textAlign: 'center',
    marginTop: 16,
    marginBottom: 24,
  },
  retryButton: {
    backgroundColor: '#007bff',
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 8,
  },
  retryButtonText: {
    color: '#ffffff',
    fontSize: 16,
    fontWeight: '600',
  },
});

export default PerformanceValidationDashboard;
