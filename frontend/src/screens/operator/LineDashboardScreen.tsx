/**
 * MS5.0 Floor Dashboard - Line Dashboard Screen
 * 
 * This screen provides operators with real-time production line
 * status, OEE metrics, and equipment information.
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
import { fetchLineDashboardData } from '../../store/slices/dashboardSlice';
import Card from '../../components/common/Card';
import Button from '../../components/common/Button';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import { CircularGauge, ProgressBar, MetricCard, LineChart } from '../../components/common/DataVisualization';
import { StatusIndicator, LiveDataIndicator, RealTimeBadge } from '../../components/common/RealTimeIndicators';
import { OfflineIndicator } from '../../components/common/OfflineSupport';
import usePermissions from '../../hooks/usePermissions';
import useRealTimeData from '../../hooks/useRealTimeData';

// Types
interface DashboardData {
  lineStatus: 'Running' | 'Stopped' | 'Maintenance' | 'Error';
  oee: number;
  availability: number;
  performance: number;
  quality: number;
  currentSpeed: number;
  targetSpeed: number;
  currentJob?: {
    id: string;
    title: string;
    progress: number;
    targetQuantity: number;
    currentQuantity: number;
  };
  equipment: Array<{
    id: string;
    name: string;
    status: 'Running' | 'Stopped' | 'Maintenance' | 'Error';
    efficiency: number;
  }>;
  recentProduction: number[];
  activeAndonEvents: number;
  lastUpdate: Date;
}

const LineDashboardScreen: React.FC = () => {
  const dispatch = useDispatch<AppDispatch>();
  const { canViewDashboard } = usePermissions();
  const { dashboardData, isLoading, error } = useSelector((state: RootState) => state.dashboard);
  const { isOnline, lastSync } = useSelector((state: RootState) => state.offline);
  
  const [refreshing, setRefreshing] = useState(false);
  const [localData, setLocalData] = useState<DashboardData | null>(null);

  // Real-time data hook
  const { data: realTimeData, isLive } = useRealTimeData('line-dashboard');

  const onRefresh = async () => {
    setRefreshing(true);
    try {
      await dispatch(fetchLineDashboardData()).unwrap();
    } catch (error) {
      console.error('Failed to refresh dashboard data:', error);
    }
    setRefreshing(false);
  };

  useEffect(() => {
    onRefresh();
  }, []);

  useEffect(() => {
    if (realTimeData) {
      setLocalData(realTimeData);
    }
  }, [realTimeData]);

  const data = localData || dashboardData;

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

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'Running':
        return 'play-circle';
      case 'Stopped':
        return 'pause-circle';
      case 'Maintenance':
        return 'build';
      case 'Error':
        return 'error';
      default:
        return 'help';
    }
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
        <Text style={styles.errorText}>Failed to load dashboard data</Text>
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
          <Text style={styles.title}>Line Dashboard</Text>
          <LiveDataIndicator isLive={isLive} />
        </View>
        <Text style={styles.subtitle}>Real-time production monitoring</Text>
        <Text style={styles.lastUpdate}>
          Last updated: {data.lastUpdate ? new Date(data.lastUpdate).toLocaleTimeString() : 'Never'}
        </Text>
      </View>

      {/* Line Status */}
      <Card style={styles.statusCard}>
        <View style={styles.statusHeader}>
          <Text style={styles.statusTitle}>Production Line Status</Text>
          <StatusIndicator
            status={data.lineStatus === 'Running' ? 'online' : 'offline'}
            label={data.lineStatus}
            lastUpdated={data.lastUpdate}
            animated={data.lineStatus === 'Running'}
          />
        </View>
        <View style={styles.statusDetails}>
          <Text style={[styles.statusText, { color: getStatusColor(data.lineStatus) }]}>
            {data.lineStatus}
          </Text>
          {data.activeAndonEvents > 0 && (
            <RealTimeBadge
              count={data.activeAndonEvents}
              type="andon"
              onPress={() => {/* Navigate to Andon screen */}}
            />
          )}
        </View>
      </Card>

      {/* OEE Metrics */}
      <Card style={styles.metricsCard}>
        <Text style={styles.metricsTitle}>Overall Equipment Effectiveness</Text>
        
        <View style={styles.oeeContainer}>
          <CircularGauge
            value={data.oee * 100}
            maxValue={100}
            size={150}
            color={data.oee >= 0.8 ? '#4CAF50' : data.oee >= 0.6 ? '#FF9800' : '#F44336'}
            label="Current OEE"
            showValue
            showPercentage
          />
        </View>
        
        <View style={styles.metricsGrid}>
          <MetricCard
            title="Availability"
            value={`${Math.round(data.availability * 100)}%`}
            color="#2196F3"
            trend={data.availability >= 0.9 ? 'up' : 'down'}
          />
          <MetricCard
            title="Performance"
            value={`${Math.round(data.performance * 100)}%`}
            color="#4CAF50"
            trend={data.performance >= 0.9 ? 'up' : 'down'}
          />
          <MetricCard
            title="Quality"
            value={`${Math.round(data.quality * 100)}%`}
            color="#FF9800"
            trend={data.quality >= 0.95 ? 'up' : 'down'}
          />
        </View>
      </Card>

      {/* Current Job */}
      {data.currentJob && (
        <Card style={styles.jobCard}>
          <Text style={styles.sectionTitle}>Current Job</Text>
          <View style={styles.jobInfo}>
            <Text style={styles.jobTitle}>{data.currentJob.title}</Text>
            <Text style={styles.jobProgress}>
              {data.currentJob.currentQuantity} / {data.currentJob.targetQuantity} units
            </Text>
          </View>
          <ProgressBar
            value={data.currentJob.currentQuantity}
            maxValue={data.currentJob.targetQuantity}
            label="Job Progress"
            color="#2196F3"
            showValue
            showPercentage
          />
        </Card>
      )}

      {/* Speed Information */}
      <Card style={styles.speedCard}>
        <Text style={styles.speedTitle}>Production Speed</Text>
        <View style={styles.speedContainer}>
          <CircularGauge
            value={(data.currentSpeed / data.targetSpeed) * 100}
            maxValue={100}
            size={120}
            color={data.currentSpeed >= data.targetSpeed ? '#4CAF50' : '#FF9800'}
            label="Speed Efficiency"
            showValue
            showPercentage
          />
          <View style={styles.speedInfo}>
            <Text style={styles.speedValue}>{data.currentSpeed}</Text>
            <Text style={styles.speedUnit}>units/min</Text>
            <Text style={styles.speedTarget}>
              Target: {data.targetSpeed} units/min
            </Text>
          </View>
        </View>
      </Card>

      {/* Equipment Status */}
      <Card style={styles.equipmentCard}>
        <Text style={styles.sectionTitle}>Equipment Status</Text>
        {data.equipment && data.equipment.length > 0 ? (
          <View style={styles.equipmentList}>
            {data.equipment.map((equipment) => (
              <View key={equipment.id} style={styles.equipmentItem}>
                <View style={styles.equipmentInfo}>
                  <Text style={styles.equipmentName}>{equipment.name}</Text>
                  <Text style={styles.equipmentEfficiency}>
                    {Math.round(equipment.efficiency * 100)}% efficiency
                  </Text>
                </View>
                <StatusIndicator
                  status={equipment.status === 'Running' ? 'online' : 'offline'}
                  label={equipment.status}
                  size="small"
                />
              </View>
            ))}
          </View>
        ) : (
          <Text style={styles.emptyText}>No equipment data available</Text>
        )}
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
  statusCard: {
    margin: 16,
    marginTop: 8,
    padding: 16,
  },
  statusHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  statusTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#212121',
  },
  statusDetails: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  statusText: {
    fontSize: 16,
    fontWeight: '500',
  },
  metricsCard: {
    margin: 16,
    marginTop: 8,
    padding: 16,
  },
  metricsTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#212121',
    marginBottom: 16,
    textAlign: 'center',
  },
  oeeContainer: {
    alignItems: 'center',
    marginBottom: 20,
  },
  metricsGrid: {
    flexDirection: 'row',
    justifyContent: 'space-around',
  },
  jobCard: {
    margin: 16,
    marginTop: 8,
    padding: 16,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#212121',
    marginBottom: 12,
  },
  jobInfo: {
    marginBottom: 12,
  },
  jobTitle: {
    fontSize: 16,
    fontWeight: '500',
    color: '#212121',
    marginBottom: 4,
  },
  jobProgress: {
    fontSize: 14,
    color: '#757575',
  },
  speedCard: {
    margin: 16,
    marginTop: 8,
    padding: 16,
  },
  speedTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#212121',
    marginBottom: 16,
    textAlign: 'center',
  },
  speedContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
  },
  speedInfo: {
    marginLeft: 20,
    alignItems: 'center',
  },
  speedValue: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#2196F3',
  },
  speedUnit: {
    fontSize: 14,
    color: '#757575',
    marginTop: 2,
  },
  speedTarget: {
    fontSize: 12,
    color: '#757575',
    marginTop: 4,
  },
  equipmentCard: {
    margin: 16,
    marginTop: 8,
    padding: 16,
  },
  equipmentList: {
    marginTop: 8,
  },
  equipmentItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#F0F0F0',
  },
  equipmentInfo: {
    flex: 1,
  },
  equipmentName: {
    fontSize: 16,
    fontWeight: '500',
    color: '#212121',
    marginBottom: 2,
  },
  equipmentEfficiency: {
    fontSize: 14,
    color: '#757575',
  },
  trendCard: {
    margin: 16,
    marginTop: 8,
    padding: 16,
  },
  emptyText: {
    fontSize: 16,
    color: '#9E9E9E',
    textAlign: 'center',
    marginTop: 20,
  },
});

export default LineDashboardScreen;
