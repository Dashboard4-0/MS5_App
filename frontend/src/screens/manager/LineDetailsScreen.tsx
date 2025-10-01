/**
 * MS5.0 Floor Dashboard - Line Details Screen
 * 
 * This screen provides detailed information about a specific production line
 * including real-time metrics, equipment status, and historical data.
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
import { fetchLineDetails } from '../../store/slices/productionSlice';
import Card from '../../components/common/Card';
import Button from '../../components/common/Button';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import { CircularGauge, ProgressBar, MetricCard, LineChart } from '../../components/common/DataVisualization';
import { StatusIndicator, LiveDataIndicator, RealTimeBadge } from '../../components/common/RealTimeIndicators';
import { OfflineIndicator } from '../../components/common/OfflineSupport';
import usePermissions from '../../hooks/usePermissions';
import useRealTimeData from '../../hooks/useRealTimeData';
import { formatDateTime } from '../../utils/formatters';

// Types
interface LineDetailsProps {
  route: {
    params: {
      lineId: string;
    };
  };
  navigation: any;
}

interface LineDetails {
  id: string;
  name: string;
  description: string;
  status: 'Running' | 'Stopped' | 'Maintenance' | 'Error';
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
    scheduledEnd: string;
  };
  equipment: Array<{
    id: string;
    name: string;
    code: string;
    status: 'Running' | 'Stopped' | 'Maintenance' | 'Error';
    efficiency: number;
    lastMaintenance?: string;
    nextMaintenance?: string;
  }>;
  recentProduction: number[];
  activeAndonEvents: number;
  shift: {
    current: string;
    startTime: string;
    endTime: string;
    team: Array<{
      id: string;
      name: string;
      role: string;
      status: 'Active' | 'Break' | 'Off';
    }>;
  };
  lastUpdate: Date;
}

const LineDetailsScreen: React.FC<LineDetailsProps> = ({ route, navigation }) => {
  const dispatch = useDispatch<AppDispatch>();
  const { canViewProduction } = usePermissions();
  const { lineDetails, isLoading } = useSelector((state: RootState) => state.production);
  const { isOnline } = useSelector((state: RootState) => state.offline);
  
  const [refreshing, setRefreshing] = useState(false);
  const [lineData, setLineData] = useState<LineDetails | null>(null);

  const { lineId } = route.params;

  // Real-time data hook
  const { data: realTimeData, isLive } = useRealTimeData(`line-${lineId}`);

  const onRefresh = async () => {
    setRefreshing(true);
    try {
      const result = await dispatch(fetchLineDetails(lineId)).unwrap();
      setLineData(result);
    } catch (error) {
      console.error('Failed to refresh line details:', error);
    }
    setRefreshing(false);
  };

  useEffect(() => {
    onRefresh();
  }, [lineId]);

  useEffect(() => {
    if (realTimeData) {
      setLineData(realTimeData);
    }
  }, [realTimeData]);

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

  const handleEquipmentPress = (equipmentId: string) => {
    // Navigate to equipment details
    navigation.navigate('EquipmentDetails', { equipmentId });
  };

  const handleAndonPress = () => {
    // Navigate to Andon management
    navigation.navigate('AndonManagement');
  };

  if (!canViewProduction) {
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

  if (!lineData) {
    return (
      <View style={styles.container}>
        <Text style={styles.errorText}>Failed to load line details</Text>
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
          <Text style={styles.title}>{lineData.name}</Text>
          <LiveDataIndicator isLive={isLive} />
        </View>
        <Text style={styles.subtitle}>{lineData.description}</Text>
        <Text style={styles.lastUpdate}>
          Last updated: {lineData.lastUpdate ? new Date(lineData.lastUpdate).toLocaleTimeString() : 'Never'}
        </Text>
      </View>

      {/* Line Status */}
      <Card style={styles.statusCard}>
        <View style={styles.statusHeader}>
          <Text style={styles.statusTitle}>Production Line Status</Text>
          <StatusIndicator
            status={lineData.status === 'Running' ? 'online' : 'offline'}
            label={lineData.status}
            lastUpdated={lineData.lastUpdate}
            animated={lineData.status === 'Running'}
          />
        </View>
        <View style={styles.statusDetails}>
          <Text style={[styles.statusText, { color: getStatusColor(lineData.status) }]}>
            {lineData.status}
          </Text>
          {lineData.activeAndonEvents > 0 && (
            <TouchableOpacity onPress={handleAndonPress}>
              <RealTimeBadge
                count={lineData.activeAndonEvents}
                type="andon"
              />
            </TouchableOpacity>
          )}
        </View>
      </Card>

      {/* OEE Metrics */}
      <Card style={styles.metricsCard}>
        <Text style={styles.metricsTitle}>Overall Equipment Effectiveness</Text>
        
        <View style={styles.oeeContainer}>
          <CircularGauge
            value={lineData.oee * 100}
            maxValue={100}
            size={150}
            color={lineData.oee >= 0.8 ? '#4CAF50' : lineData.oee >= 0.6 ? '#FF9800' : '#F44336'}
            label="Current OEE"
            showValue
            showPercentage
          />
        </View>
        
        <View style={styles.metricsGrid}>
          <MetricCard
            title="Availability"
            value={`${Math.round(lineData.availability * 100)}%`}
            color="#2196F3"
            trend={lineData.availability >= 0.9 ? 'up' : 'down'}
          />
          <MetricCard
            title="Performance"
            value={`${Math.round(lineData.performance * 100)}%`}
            color="#4CAF50"
            trend={lineData.performance >= 0.9 ? 'up' : 'down'}
          />
          <MetricCard
            title="Quality"
            value={`${Math.round(lineData.quality * 100)}%`}
            color="#FF9800"
            trend={lineData.quality >= 0.95 ? 'up' : 'down'}
          />
        </View>
      </Card>

      {/* Current Job */}
      {lineData.currentJob && (
        <Card style={styles.jobCard}>
          <Text style={styles.sectionTitle}>Current Job</Text>
          <View style={styles.jobInfo}>
            <Text style={styles.jobTitle}>{lineData.currentJob.title}</Text>
            <Text style={styles.jobProgress}>
              {lineData.currentJob.currentQuantity} / {lineData.currentJob.targetQuantity} units
            </Text>
            <Text style={styles.jobEndTime}>
              Scheduled end: {formatDateTime(lineData.currentJob.scheduledEnd)}
            </Text>
          </View>
          <ProgressBar
            value={lineData.currentJob.currentQuantity}
            maxValue={lineData.currentJob.targetQuantity}
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
            value={(lineData.currentSpeed / lineData.targetSpeed) * 100}
            maxValue={100}
            size={120}
            color={lineData.currentSpeed >= lineData.targetSpeed ? '#4CAF50' : '#FF9800'}
            label="Speed Efficiency"
            showValue
            showPercentage
          />
          <View style={styles.speedInfo}>
            <Text style={styles.speedValue}>{lineData.currentSpeed}</Text>
            <Text style={styles.speedUnit}>units/min</Text>
            <Text style={styles.speedTarget}>
              Target: {lineData.targetSpeed} units/min
            </Text>
          </View>
        </View>
      </Card>

      {/* Equipment Status */}
      <Card style={styles.equipmentCard}>
        <Text style={styles.sectionTitle}>Equipment Status</Text>
        {lineData.equipment && lineData.equipment.length > 0 ? (
          <View style={styles.equipmentList}>
            {lineData.equipment.map((equipment) => (
              <TouchableOpacity
                key={equipment.id}
                style={styles.equipmentItem}
                onPress={() => handleEquipmentPress(equipment.id)}
              >
                <View style={styles.equipmentInfo}>
                  <Text style={styles.equipmentName}>{equipment.name}</Text>
                  <Text style={styles.equipmentCode}>{equipment.code}</Text>
                  <Text style={styles.equipmentEfficiency}>
                    {Math.round(equipment.efficiency * 100)}% efficiency
                  </Text>
                  {equipment.nextMaintenance && (
                    <Text style={styles.maintenanceText}>
                      Next maintenance: {formatDateTime(equipment.nextMaintenance)}
                    </Text>
                  )}
                </View>
                <StatusIndicator
                  status={equipment.status === 'Running' ? 'online' : 'offline'}
                  label={equipment.status}
                  size="small"
                />
              </TouchableOpacity>
            ))}
          </View>
        ) : (
          <Text style={styles.emptyText}>No equipment data available</Text>
        )}
      </Card>

      {/* Shift Information */}
      <Card style={styles.shiftCard}>
        <Text style={styles.sectionTitle}>Current Shift</Text>
        <View style={styles.shiftInfo}>
          <Text style={styles.shiftName}>{lineData.shift.current}</Text>
          <Text style={styles.shiftTime}>
            {formatDateTime(lineData.shift.startTime)} - {formatDateTime(lineData.shift.endTime)}
          </Text>
        </View>
        
        <Text style={styles.teamTitle}>Team Members</Text>
        <View style={styles.teamList}>
          {lineData.shift.team.map((member) => (
            <View key={member.id} style={styles.teamMember}>
              <View style={styles.memberInfo}>
                <Text style={styles.memberName}>{member.name}</Text>
                <Text style={styles.memberRole}>{member.role}</Text>
              </View>
              <StatusIndicator
                status={member.status === 'Active' ? 'online' : 'offline'}
                label={member.status}
                size="small"
              />
            </View>
          ))}
        </View>
      </Card>

      {/* Production Trend */}
      {lineData.recentProduction && lineData.recentProduction.length > 0 && (
        <Card style={styles.trendCard}>
          <Text style={styles.sectionTitle}>Production Trend (Last 24 Hours)</Text>
          <LineChart
            data={lineData.recentProduction}
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
    marginBottom: 2,
  },
  jobEndTime: {
    fontSize: 12,
    color: '#9E9E9E',
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
  equipmentCode: {
    fontSize: 12,
    color: '#9E9E9E',
    marginBottom: 2,
  },
  equipmentEfficiency: {
    fontSize: 14,
    color: '#757575',
    marginBottom: 2,
  },
  maintenanceText: {
    fontSize: 12,
    color: '#FF9800',
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
  teamTitle: {
    fontSize: 16,
    fontWeight: '500',
    color: '#212121',
    marginBottom: 8,
  },
  teamList: {
    marginTop: 8,
  },
  teamMember: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 8,
    borderBottomWidth: 1,
    borderBottomColor: '#F0F0F0',
  },
  memberInfo: {
    flex: 1,
  },
  memberName: {
    fontSize: 14,
    fontWeight: '500',
    color: '#212121',
    marginBottom: 2,
  },
  memberRole: {
    fontSize: 12,
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

export default LineDetailsScreen;
