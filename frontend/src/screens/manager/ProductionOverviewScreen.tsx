/**
 * MS5.0 Floor Dashboard - Production Overview Screen
 * 
 * This screen provides managers with an overview of production
 * status, key metrics, and real-time updates.
 */

import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  RefreshControl,
  TouchableOpacity,
} from 'react-native';
import { useSelector, useDispatch } from 'react-redux';
import { RootState, AppDispatch } from '../../store';
import { fetchProductionOverview } from '../../store/slices/productionSlice';
import Card from '../../components/common/Card';
import Button from '../../components/common/Button';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import { CircularGauge, ProgressBar, MetricCard, LineChart } from '../../components/common/DataVisualization';
import { StatusIndicator, LiveDataIndicator, RealTimeBadge } from '../../components/common/RealTimeIndicators';
import { OfflineIndicator } from '../../components/common/OfflineSupport';
import usePermissions from '../../hooks/usePermissions';
import useRealTimeData from '../../hooks/useRealTimeData';
import { Permission } from '../../config/constants';

// Types
interface ProductionOverviewData {
  totalLines: number;
  activeLines: number;
  totalProduction: number;
  averageOEE: number;
  activeAndonEvents: number;
  lines: Array<{
    id: string;
    name: string;
    status: 'Running' | 'Stopped' | 'Maintenance' | 'Error';
    oee: number;
    currentSpeed: number;
    targetSpeed: number;
    currentJob?: {
      id: string;
      title: string;
      progress: number;
    };
  }>;
  recentProduction: number[];
  shiftInfo: {
    current: string;
    startTime: string;
    endTime: string;
    teamCount: number;
    activeOperators: number;
  };
  lastUpdate: Date;
}

const ProductionOverviewScreen: React.FC = () => {
  const dispatch = useDispatch<AppDispatch>();
  const { canViewDashboard, canManageProduction } = usePermissions();
  const { productionOverview, isLoading } = useSelector((state: RootState) => state.production);
  const { isOnline } = useSelector((state: RootState) => state.offline);
  
  const [refreshing, setRefreshing] = useState(false);
  const [overviewData, setOverviewData] = useState<ProductionOverviewData | null>(null);

  // Real-time data hook
  const { data: realTimeData, isLive } = useRealTimeData('production-overview');

  const onRefresh = async () => {
    setRefreshing(true);
    try {
      const result = await dispatch(fetchProductionOverview()).unwrap();
      setOverviewData(result);
    } catch (error) {
      console.error('Failed to refresh production overview:', error);
    }
    setRefreshing(false);
  };

  useEffect(() => {
    onRefresh();
  }, []);

  useEffect(() => {
    if (realTimeData) {
      setOverviewData(realTimeData);
    }
  }, [realTimeData]);

  const data = overviewData || productionOverview;

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'Running':
        return '#4CAF50';
      case 'Stopped':
        return '#9E9E9E';
      case 'Maintenance':
        return '#2196F3';
      case 'Error':
        return '#F44336';
      default:
        return '#9E9E9E';
    }
  };

  const handleLinePress = (lineId: string) => {
    // Navigate to line details
    // navigation.navigate('LineDetails', { lineId });
  };

  const handleAndonPress = () => {
    // Navigate to Andon management
    // navigation.navigate('AndonManagement');
  };

  if (!canViewDashboard) {
    return (
      <View style={styles.container}>
        <Text style={styles.unauthorizedText}>
          You don't have permission to view this screen.
        </Text>
      </View>
    );
  }

  if (isLoading && !refreshing) {
    return <LoadingSpinner />;
  }

  if (!data) {
    return (
      <View style={styles.container}>
        <Text style={styles.errorText}>Failed to load production overview</Text>
        <Button title="Retry" onPress={onRefresh} />
      </View>
    );
  }

  return (
    <ScrollView
      style={styles.container}
      refreshControl={
        <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
      }
    >
      {/* Offline Indicator */}
      <OfflineIndicator
        isOffline={!isOnline}
        pendingSyncCount={0}
        showPendingCount={false}
      />

      {/* Header */}
      <View style={styles.header}>
        <View style={styles.headerTop}>
          <Text style={styles.title}>Production Overview</Text>
          <LiveDataIndicator isLive={isLive} />
        </View>
        <Text style={styles.subtitle}>Real-time production status and metrics</Text>
        <Text style={styles.lastUpdate}>
          Last updated: {data.lastUpdate ? new Date(data.lastUpdate).toLocaleTimeString() : 'Never'}
        </Text>
      </View>

      {/* Key Metrics Cards */}
      <View style={styles.metricsContainer}>
        <MetricCard
          title="Total Lines"
          value={data.totalLines}
          color="#2196F3"
          trend="neutral"
        />
        <MetricCard
          title="Active Lines"
          value={data.activeLines}
          color="#4CAF50"
          trend={data.activeLines >= data.totalLines * 0.8 ? 'up' : 'down'}
        />
        <MetricCard
          title="Total Production"
          value={data.totalProduction}
          unit="units"
          color="#FF9800"
          trend="up"
        />
        <MetricCard
          title="Average OEE"
          value={`${Math.round(data.averageOEE * 100)}%`}
          color="#9C27B0"
          trend={data.averageOEE >= 0.8 ? 'up' : 'down'}
        />
      </View>

      {/* Overall OEE Gauge */}
      <Card style={styles.oeeCard}>
        <Text style={styles.sectionTitle}>Overall Equipment Effectiveness</Text>
        <View style={styles.oeeContainer}>
          <CircularGauge
            value={data.averageOEE * 100}
            maxValue={100}
            size={150}
            color={data.averageOEE >= 0.8 ? '#4CAF50' : data.averageOEE >= 0.6 ? '#FF9800' : '#F44336'}
            label="Average OEE"
            showValue
            showPercentage
          />
        </View>
      </Card>

      {/* Production Lines Status */}
      <Card style={styles.sectionCard}>
        <View style={styles.sectionHeader}>
          <Text style={styles.sectionTitle}>Production Lines</Text>
          <TouchableOpacity onPress={() => {/* Navigate to all lines */}}>
            <Text style={styles.viewAllText}>View All</Text>
          </TouchableOpacity>
        </View>
        
        {data.lines && data.lines.length > 0 ? (
          <View style={styles.linesList}>
            {data.lines.map((line) => (
              <TouchableOpacity
                key={line.id}
                style={styles.lineItem}
                onPress={() => handleLinePress(line.id)}
              >
                <View style={styles.lineInfo}>
                  <Text style={styles.lineName}>{line.name}</Text>
                  <Text style={styles.lineStatus}>
                    {line.currentJob ? line.currentJob.title : 'No active job'}
                  </Text>
                  {line.currentJob && (
                    <Text style={styles.lineProgress}>
                      {Math.round(line.currentJob.progress)}% complete
                    </Text>
                  )}
                </View>
                
                <View style={styles.lineMetrics}>
                  <StatusIndicator
                    status={line.status === 'Running' ? 'online' : 'offline'}
                    label={line.status}
                    size="small"
                  />
                  <Text style={styles.lineOEE}>
                    OEE: {Math.round(line.oee * 100)}%
                  </Text>
                  <Text style={styles.lineSpeed}>
                    {line.currentSpeed}/{line.targetSpeed} units/min
                  </Text>
                </View>
              </TouchableOpacity>
            ))}
          </View>
        ) : (
          <Text style={styles.emptyText}>No production lines available</Text>
        )}
      </Card>

      {/* Active Andon Events */}
      <Card style={styles.sectionCard}>
        <View style={styles.sectionHeader}>
          <Text style={styles.sectionTitle}>Active Andon Events</Text>
          <TouchableOpacity onPress={handleAndonPress}>
            <Text style={styles.viewAllText}>View All</Text>
          </TouchableOpacity>
        </View>
        
        <View style={styles.andonContainer}>
          {data.activeAndonEvents > 0 ? (
            <TouchableOpacity onPress={handleAndonPress}>
              <RealTimeBadge
                count={data.activeAndonEvents}
                type="andon"
              />
            </TouchableOpacity>
          ) : (
            <Text style={styles.emptyText}>No active Andon events</Text>
          )}
        </View>
      </Card>

      {/* Shift Information */}
      <Card style={styles.shiftCard}>
        <Text style={styles.sectionTitle}>Current Shift</Text>
        <View style={styles.shiftInfo}>
          <Text style={styles.shiftName}>{data.shiftInfo.current}</Text>
          <Text style={styles.shiftTime}>
            {new Date(data.shiftInfo.startTime).toLocaleTimeString()} - {new Date(data.shiftInfo.endTime).toLocaleTimeString()}
          </Text>
        </View>
        
        <View style={styles.shiftMetrics}>
          <MetricCard
            title="Team Members"
            value={data.shiftInfo.teamCount}
            color="#2196F3"
          />
          <MetricCard
            title="Active Operators"
            value={data.shiftInfo.activeOperators}
            color="#4CAF50"
          />
        </View>
      </Card>

      {/* Production Trend */}
      {data.recentProduction && data.recentProduction.length > 0 && (
        <Card style={styles.trendCard}>
          <Text style={styles.sectionTitle}>Production Trend (Last 24 Hours)</Text>
          <LineChart
            data={data.recentProduction}
            height={200}
            color="#2196F3"
            showGrid
            showValues
          />
        </Card>
      )}

      {/* Quick Actions */}
      {canManageProduction && (
        <Card style={styles.sectionCard}>
          <Text style={styles.sectionTitle}>Quick Actions</Text>
          
          <View style={styles.actionsContainer}>
            <Button
              title="Create Schedule"
              onPress={() => {/* Navigate to schedule creation */}}
              style={styles.actionButton}
              variant="outline"
            />
            <Button
              title="View Reports"
              onPress={() => {/* Navigate to reports */}}
              style={styles.actionButton}
              variant="outline"
            />
            <Button
              title="Manage Team"
              onPress={() => {/* Navigate to team management */}}
              style={styles.actionButton}
              variant="outline"
            />
            <Button
              title="Andon Management"
              onPress={handleAndonPress}
              style={styles.actionButton}
              variant="outline"
            />
          </View>
        </Card>
      )}
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F5F5F5',
  },
  header: {
    backgroundColor: '#FFFFFF',
    padding: 20,
    borderBottomWidth: 1,
    borderBottomColor: '#E0E0E0',
  },
  headerTop: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 4,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#212121',
  },
  subtitle: {
    fontSize: 16,
    color: '#757575',
    marginBottom: 4,
  },
  lastUpdate: {
    fontSize: 12,
    color: '#9E9E9E',
  },
  unauthorizedText: {
    fontSize: 16,
    color: '#757575',
    textAlign: 'center',
    marginTop: 50,
  },
  errorText: {
    fontSize: 16,
    color: '#F44336',
    textAlign: 'center',
    marginTop: 50,
  },
  metricsContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    padding: 16,
    justifyContent: 'space-between',
  },
  oeeCard: {
    margin: 16,
    marginTop: 8,
    padding: 16,
  },
  oeeContainer: {
    alignItems: 'center',
    paddingVertical: 20,
  },
  sectionCard: {
    margin: 16,
    marginTop: 8,
    padding: 16,
  },
  sectionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 16,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#212121',
  },
  viewAllText: {
    fontSize: 14,
    color: '#2196F3',
  },
  linesList: {
    marginTop: 8,
  },
  lineItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 12,
    paddingHorizontal: 16,
    backgroundColor: '#FFFFFF',
    borderRadius: 8,
    marginBottom: 8,
    borderWidth: 1,
    borderColor: '#E0E0E0',
  },
  lineInfo: {
    flex: 1,
  },
  lineName: {
    fontSize: 16,
    fontWeight: '500',
    color: '#212121',
    marginBottom: 2,
  },
  lineStatus: {
    fontSize: 14,
    color: '#757575',
    marginBottom: 2,
  },
  lineProgress: {
    fontSize: 12,
    color: '#2196F3',
  },
  lineMetrics: {
    alignItems: 'flex-end',
  },
  lineOEE: {
    fontSize: 12,
    color: '#757575',
    marginTop: 4,
  },
  lineSpeed: {
    fontSize: 12,
    color: '#757575',
    marginTop: 2,
  },
  andonContainer: {
    alignItems: 'center',
    paddingVertical: 20,
  },
  shiftCard: {
    margin: 16,
    marginTop: 8,
    padding: 16,
  },
  shiftInfo: {
    marginBottom: 16,
  },
  shiftName: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#212121',
    marginBottom: 4,
  },
  shiftTime: {
    fontSize: 14,
    color: '#757575',
  },
  shiftMetrics: {
    flexDirection: 'row',
    justifyContent: 'space-around',
  },
  trendCard: {
    margin: 16,
    marginTop: 8,
    padding: 16,
  },
  actionsContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
  },
  actionButton: {
    width: '48%',
    marginVertical: 4,
  },
  emptyText: {
    fontSize: 16,
    color: '#9E9E9E',
    textAlign: 'center',
    marginTop: 20,
  },
});

export default ProductionOverviewScreen;
