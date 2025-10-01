/**
 * MS5.0 Floor Dashboard - Error Tracking Dashboard Component
 * 
 * This component provides a comprehensive error tracking dashboard:
 * - Real-time error monitoring
 * - Error rate visualization
 * - Error pattern analysis
 * - Alert management
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
import { ErrorTrackingService } from '../services/errorTrackingService';
import { ErrorType, ErrorSeverity, ErrorTrackingUtils } from '../types/errorTypes';
import { useUXMetrics } from '../hooks/useUXMetrics';

interface ErrorDashboardProps {
  onErrorSelect?: (errorId: string) => void;
  onAlertSelect?: (alertId: string) => void;
  refreshInterval?: number;
  showDetails?: boolean;
}

interface ErrorDashboardData {
  errorRateReport: {
    errorMetrics: {
      totalErrors: number;
      errorsByType: Record<string, number>;
      errorsBySeverity: Record<string, number>;
      errorsByEndpoint: Record<string, number>;
      errorRatePerMinute: number;
      errorRatePerHour: number;
      errorRatePercentage: number;
      criticalErrors: number;
      resolvedErrors: number;
      unresolvedErrors: number;
    };
    recentErrors: {
      count: number;
      errors: Array<{
        errorId: string;
        errorType: string;
        severity: string;
        message: string;
        endpoint?: string;
        timestamp: number;
        resolved: boolean;
      }>;
    };
    topErrorPatterns: Array<{
      pattern: string;
      errorCount: number;
      errorType: string;
      severity: string;
      firstOccurrence: number;
      lastOccurrence: number;
    }>;
    errorTrends: {
      minute: {
        currentErrors: number;
        previousErrors: number;
        trendPercentage: number;
        trendDirection: 'increasing' | 'decreasing' | 'stable';
      };
      hour: {
        currentErrors: number;
        previousErrors: number;
        trendPercentage: number;
        trendDirection: 'increasing' | 'decreasing' | 'stable';
      };
      day: {
        currentErrors: number;
        previousErrors: number;
        trendPercentage: number;
        trendDirection: 'increasing' | 'decreasing' | 'stable';
      };
    };
    activeAlerts: Array<{
      alertId: string;
      errorType: string;
      threshold: number;
      timeWindow: number;
      severity: string;
      enabled: boolean;
      lastTriggered?: number;
      triggerCount: number;
    }>;
    monitoringStatus: {
      isMonitoring: boolean;
      monitoringTasks: number;
      totalPatterns: number;
    };
  };
  systemHealth: {
    overallHealth: 'healthy' | 'warning' | 'critical';
    errorRate: number;
    criticalErrors: number;
    unresolvedErrors: number;
  };
}

const ErrorTrackingDashboard: React.FC<ErrorDashboardProps> = ({
  onErrorSelect,
  onAlertSelect,
  refreshInterval = 30000,
  showDetails = true,
}) => {
  const [dashboardData, setDashboardData] = useState<ErrorDashboardData | null>(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [selectedTimeWindow, setSelectedTimeWindow] = useState<'minute' | 'hour' | 'day'>('hour');
  const [selectedView, setSelectedView] = useState<'overview' | 'patterns' | 'alerts' | 'trends'>('overview');

  const apiService = useMemo(() => new ApiService(), []);
  const errorTrackingService = useMemo(() => new ErrorTrackingService(), []);
  const { recordUXMetric } = useUXMetrics();

  const screenWidth = Dimensions.get('window').width;

  /**
   * Load dashboard data
   */
  const loadDashboardData = useCallback(async () => {
    try {
      setError(null);
      const response = await apiService.get('/api/errors/dashboard');
      setDashboardData(response.data);
      
      // Record UX metric
      recordUXMetric('error_dashboard_load_time', Date.now());
      
    } catch (err) {
      console.error('Failed to load error dashboard data:', err);
      setError('Failed to load dashboard data');
    }
  }, [apiService, recordUXMetric]);

  /**
   * Refresh dashboard data
   */
  const handleRefresh = useCallback(async () => {
    setRefreshing(true);
    await loadDashboardData();
    setRefreshing(false);
  }, [loadDashboardData]);

  /**
   * Load initial data
   */
  useEffect(() => {
    loadDashboardData();
  }, [loadDashboardData]);

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
   * Handle error selection
   */
  const handleErrorSelect = useCallback((errorId: string) => {
    if (onErrorSelect) {
      onErrorSelect(errorId);
    }
  }, [onErrorSelect]);

  /**
   * Handle alert selection
   */
  const handleAlertSelect = useCallback((alertId: string) => {
    if (onAlertSelect) {
      onAlertSelect(alertId);
    }
  }, [onAlertSelect]);

  /**
   * Resolve error
   */
  const handleResolveError = useCallback(async (errorId: string) => {
    try {
      await apiService.post(`/api/errors/${errorId}/resolve`, {
        resolution_notes: 'Resolved via dashboard',
      });
      
      // Refresh data
      await loadDashboardData();
      
      Alert.alert('Success', 'Error resolved successfully');
      
    } catch (err) {
      console.error('Failed to resolve error:', err);
      Alert.alert('Error', 'Failed to resolve error');
    }
  }, [apiService, loadDashboardData]);

  /**
   * Get health status color
   */
  const getHealthStatusColor = useCallback((health: string) => {
    switch (health) {
      case 'healthy':
        return '#28a745';
      case 'warning':
        return '#ffc107';
      case 'critical':
        return '#dc3545';
      default:
        return '#6c757d';
    }
  }, []);

  /**
   * Get health status icon
   */
  const getHealthStatusIcon = useCallback((health: string) => {
    switch (health) {
      case 'healthy':
        return 'check-circle';
      case 'warning':
        return 'warning';
      case 'critical':
        return 'error';
      default:
        return 'help';
    }
  }, []);

  /**
   * Format error rate
   */
  const formatErrorRate = useCallback((rate: number) => {
    return `${(rate * 100).toFixed(2)}%`;
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
    return ErrorTrackingUtils.getTimeSince(timestamp);
  }, []);

  /**
   * Render overview section
   */
  const renderOverview = useCallback(() => {
    if (!dashboardData) return null;

    const { errorRateReport, systemHealth } = dashboardData;
    const { errorMetrics } = errorRateReport;

    return (
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>System Health Overview</Text>
        
        {/* Health Status */}
        <View style={styles.healthStatusContainer}>
          <View style={[
            styles.healthStatusCard,
            { backgroundColor: getHealthStatusColor(systemHealth.overallHealth) }
          ]}>
            <MaterialIcons 
              name={getHealthStatusIcon(systemHealth.overallHealth)} 
              size={24} 
              color="white" 
            />
            <Text style={styles.healthStatusText}>
              {systemHealth.overallHealth.toUpperCase()}
            </Text>
          </View>
        </View>

        {/* Key Metrics */}
        <View style={styles.metricsContainer}>
          <View style={styles.metricCard}>
            <Text style={styles.metricValue}>{errorMetrics.totalErrors}</Text>
            <Text style={styles.metricLabel}>Total Errors</Text>
          </View>
          <View style={styles.metricCard}>
            <Text style={styles.metricValue}>{errorMetrics.criticalErrors}</Text>
            <Text style={styles.metricLabel}>Critical Errors</Text>
          </View>
          <View style={styles.metricCard}>
            <Text style={styles.metricValue}>{errorMetrics.unresolvedErrors}</Text>
            <Text style={styles.metricLabel}>Unresolved</Text>
          </View>
          <View style={styles.metricCard}>
            <Text style={styles.metricValue}>
              {formatErrorRate(errorMetrics.errorRatePercentage / 100)}
            </Text>
            <Text style={styles.metricLabel}>Error Rate</Text>
          </View>
        </View>

        {/* Error Rate Chart */}
        <View style={styles.chartContainer}>
          <Text style={styles.chartTitle}>Error Rate Over Time</Text>
          <LineChart
            data={{
              labels: ['1h ago', '45m ago', '30m ago', '15m ago', 'Now'],
              datasets: [{
                data: [
                  errorMetrics.errorRatePerHour * 100,
                  errorMetrics.errorRatePerHour * 100 * 0.8,
                  errorMetrics.errorRatePerHour * 100 * 0.6,
                  errorMetrics.errorRatePerHour * 100 * 0.4,
                  errorMetrics.errorRatePerHour * 100,
                ],
                color: (opacity = 1) => `rgba(220, 53, 69, ${opacity})`,
                strokeWidth: 2,
              }],
            }}
            width={screenWidth - 40}
            height={200}
            chartConfig={{
              backgroundColor: '#ffffff',
              backgroundGradientFrom: '#ffffff',
              backgroundGradientTo: '#ffffff',
              decimalPlaces: 2,
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
      </View>
    );
  }, [dashboardData, getHealthStatusColor, getHealthStatusIcon, formatErrorRate, screenWidth]);

  /**
   * Render patterns section
   */
  const renderPatterns = useCallback(() => {
    if (!dashboardData) return null;

    const { errorRateReport } = dashboardData;
    const { topErrorPatterns, errorMetrics } = errorRateReport;

    return (
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Error Patterns</Text>
        
        {/* Error Types Chart */}
        <View style={styles.chartContainer}>
          <Text style={styles.chartTitle}>Errors by Type</Text>
          <PieChart
            data={Object.entries(errorMetrics.errorsByType).map(([type, count]) => ({
              name: type,
              population: count,
              color: ErrorTrackingUtils.getSeverityColor(ErrorSeverity.HIGH),
              legendFontColor: '#7F7F7F',
              legendFontSize: 12,
            }))}
            width={screenWidth - 40}
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

        {/* Top Patterns */}
        <View style={styles.patternsContainer}>
          <Text style={styles.patternsTitle}>Top Error Patterns</Text>
          {topErrorPatterns.slice(0, 5).map((pattern, index) => (
            <TouchableOpacity
              key={pattern.pattern}
              style={styles.patternCard}
              onPress={() => handleErrorSelect(pattern.pattern)}
            >
              <View style={styles.patternHeader}>
                <Text style={styles.patternIndex}>#{index + 1}</Text>
                <Text style={styles.patternType}>{pattern.errorType}</Text>
                <Text style={styles.patternSeverity}>{pattern.severity}</Text>
              </View>
              <Text style={styles.patternCount}>{pattern.errorCount} occurrences</Text>
              <Text style={styles.patternTime}>
                Last: {getTimeSince(pattern.lastOccurrence)}
              </Text>
            </TouchableOpacity>
          ))}
        </View>
      </View>
    );
  }, [dashboardData, handleErrorSelect, getTimeSince, screenWidth]);

  /**
   * Render alerts section
   */
  const renderAlerts = useCallback(() => {
    if (!dashboardData) return null;

    const { errorRateReport } = dashboardData;
    const { activeAlerts } = errorRateReport;

    return (
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Active Alerts</Text>
        
        {activeAlerts.length === 0 ? (
          <View style={styles.noAlertsContainer}>
            <MaterialIcons name="check-circle" size={48} color="#28a745" />
            <Text style={styles.noAlertsText}>No active alerts</Text>
          </View>
        ) : (
          <View style={styles.alertsContainer}>
            {activeAlerts.map((alert) => (
              <TouchableOpacity
                key={alert.alertId}
                style={styles.alertCard}
                onPress={() => handleAlertSelect(alert.alertId)}
              >
                <View style={styles.alertHeader}>
                  <MaterialIcons 
                    name="warning" 
                    size={20} 
                    color={ErrorTrackingUtils.getSeverityColor(alert.severity as ErrorSeverity)} 
                  />
                  <Text style={styles.alertId}>{alert.alertId}</Text>
                  <Text style={styles.alertSeverity}>{alert.severity}</Text>
                </View>
                <Text style={styles.alertType}>{alert.errorType}</Text>
                <Text style={styles.alertThreshold}>
                  Threshold: {formatErrorRate(alert.threshold)}
                </Text>
                <Text style={styles.alertTriggers}>
                  Triggered {alert.triggerCount} times
                </Text>
              </TouchableOpacity>
            ))}
          </View>
        )}
      </View>
    );
  }, [dashboardData, handleAlertSelect, formatErrorRate]);

  /**
   * Render trends section
   */
  const renderTrends = useCallback(() => {
    if (!dashboardData) return null;

    const { errorRateReport } = dashboardData;
    const { errorTrends } = errorRateReport;

    return (
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Error Trends</Text>
        
        {/* Trend Cards */}
        <View style={styles.trendsContainer}>
          {Object.entries(errorTrends).map(([timeWindow, trend]) => (
            <View key={timeWindow} style={styles.trendCard}>
              <Text style={styles.trendTitle}>{timeWindow.toUpperCase()}</Text>
              <Text style={styles.trendValue}>{trend.currentErrors}</Text>
              <Text style={styles.trendLabel}>Current Errors</Text>
              <View style={styles.trendDirection}>
                <MaterialIcons 
                  name={trend.trendDirection === 'increasing' ? 'trending-up' : 
                        trend.trendDirection === 'decreasing' ? 'trending-down' : 'trending-flat'} 
                  size={16} 
                  color={trend.trendDirection === 'increasing' ? '#dc3545' : 
                         trend.trendDirection === 'decreasing' ? '#28a745' : '#6c757d'} 
                />
                <Text style={[
                  styles.trendPercentage,
                  { color: trend.trendDirection === 'increasing' ? '#dc3545' : 
                           trend.trendDirection === 'decreasing' ? '#28a745' : '#6c757d' }
                ]}>
                  {trend.trendPercentage.toFixed(1)}%
                </Text>
              </View>
            </View>
          ))}
        </View>

        {/* Recent Errors */}
        <View style={styles.recentErrorsContainer}>
          <Text style={styles.recentErrorsTitle}>Recent Errors</Text>
          {errorRateReport.recentErrors.errors.slice(0, 5).map((error) => (
            <TouchableOpacity
              key={error.errorId}
              style={styles.recentErrorCard}
              onPress={() => handleErrorSelect(error.errorId)}
            >
              <View style={styles.recentErrorHeader}>
                <MaterialIcons 
                  name="error" 
                  size={16} 
                  color={ErrorTrackingUtils.getSeverityColor(error.severity as ErrorSeverity)} 
                />
                <Text style={styles.recentErrorType}>{error.errorType}</Text>
                <Text style={styles.recentErrorTime}>
                  {getTimeSince(error.timestamp)}
                </Text>
              </View>
              <Text style={styles.recentErrorMessage}>
                {ErrorTrackingUtils.truncateMessage(error.message, 60)}
              </Text>
              {error.endpoint && (
                <Text style={styles.recentErrorEndpoint}>{error.endpoint}</Text>
              )}
            </TouchableOpacity>
          ))}
        </View>
      </View>
    );
  }, [dashboardData, handleErrorSelect, getTimeSince]);

  /**
   * Render loading state
   */
  if (loading) {
    return (
      <View style={styles.loadingContainer}>
        <MaterialIcons name="refresh" size={48} color="#6c757d" />
        <Text style={styles.loadingText}>Loading error dashboard...</Text>
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
        <Text style={styles.title}>Error Tracking Dashboard</Text>
        <View style={styles.viewSelector}>
          {(['overview', 'patterns', 'alerts', 'trends'] as const).map((view) => (
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
      {selectedView === 'patterns' && renderPatterns()}
      {selectedView === 'alerts' && renderAlerts()}
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
  healthStatusContainer: {
    alignItems: 'center',
    marginBottom: 24,
  },
  healthStatusCard: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderRadius: 8,
    minWidth: 120,
    justifyContent: 'center',
  },
  healthStatusText: {
    color: '#ffffff',
    fontSize: 16,
    fontWeight: 'bold',
    marginLeft: 8,
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
  patternsContainer: {
    marginTop: 16,
  },
  patternsTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#212529',
    marginBottom: 12,
  },
  patternCard: {
    backgroundColor: '#f8f9fa',
    borderRadius: 8,
    padding: 12,
    marginBottom: 8,
  },
  patternHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 4,
  },
  patternIndex: {
    fontSize: 12,
    fontWeight: 'bold',
    color: '#6c757d',
    marginRight: 8,
  },
  patternType: {
    fontSize: 14,
    fontWeight: '600',
    color: '#212529',
    flex: 1,
  },
  patternSeverity: {
    fontSize: 12,
    color: '#6c757d',
  },
  patternCount: {
    fontSize: 14,
    color: '#212529',
    marginBottom: 2,
  },
  patternTime: {
    fontSize: 12,
    color: '#6c757d',
  },
  noAlertsContainer: {
    alignItems: 'center',
    padding: 32,
  },
  noAlertsText: {
    fontSize: 16,
    color: '#28a745',
    marginTop: 8,
  },
  alertsContainer: {
    marginTop: 16,
  },
  alertCard: {
    backgroundColor: '#f8f9fa',
    borderRadius: 8,
    padding: 12,
    marginBottom: 8,
  },
  alertHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 4,
  },
  alertId: {
    fontSize: 14,
    fontWeight: '600',
    color: '#212529',
    flex: 1,
    marginLeft: 8,
  },
  alertSeverity: {
    fontSize: 12,
    color: '#6c757d',
  },
  alertType: {
    fontSize: 14,
    color: '#212529',
    marginBottom: 2,
  },
  alertThreshold: {
    fontSize: 12,
    color: '#6c757d',
    marginBottom: 2,
  },
  alertTriggers: {
    fontSize: 12,
    color: '#6c757d',
  },
  trendsContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
    marginBottom: 24,
  },
  trendCard: {
    backgroundColor: '#f8f9fa',
    borderRadius: 8,
    padding: 16,
    alignItems: 'center',
    width: '48%',
    marginBottom: 8,
  },
  trendTitle: {
    fontSize: 12,
    fontWeight: '600',
    color: '#6c757d',
    marginBottom: 4,
  },
  trendValue: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#212529',
  },
  trendLabel: {
    fontSize: 10,
    color: '#6c757d',
    marginBottom: 4,
  },
  trendDirection: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  trendPercentage: {
    fontSize: 12,
    fontWeight: '600',
    marginLeft: 4,
  },
  recentErrorsContainer: {
    marginTop: 16,
  },
  recentErrorsTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#212529',
    marginBottom: 12,
  },
  recentErrorCard: {
    backgroundColor: '#f8f9fa',
    borderRadius: 8,
    padding: 12,
    marginBottom: 8,
  },
  recentErrorHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 4,
  },
  recentErrorType: {
    fontSize: 14,
    fontWeight: '600',
    color: '#212529',
    flex: 1,
    marginLeft: 8,
  },
  recentErrorTime: {
    fontSize: 12,
    color: '#6c757d',
  },
  recentErrorMessage: {
    fontSize: 14,
    color: '#212529',
    marginBottom: 2,
  },
  recentErrorEndpoint: {
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

export default ErrorTrackingDashboard;
