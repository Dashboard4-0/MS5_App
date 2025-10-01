/**
 * MS5.0 Floor Dashboard - Equipment Details Screen
 * 
 * This screen provides detailed information about a specific piece of equipment
 * including real-time status, maintenance history, and performance metrics.
 */

import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  RefreshControl,
  TouchableOpacity,
  Alert,
} from 'react-native';
import { useSelector, useDispatch } from 'react-redux';
import { RootState, AppDispatch } from '../../store';
import { fetchEquipmentDetails, updateEquipmentStatus } from '../../store/slices/equipmentSlice';
import Card from '../../components/common/Card';
import Button from '../../components/common/Button';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import { CircularGauge, ProgressBar, MetricCard, LineChart } from '../../components/common/DataVisualization';
import { StatusIndicator, LiveDataIndicator } from '../../components/common/RealTimeIndicators';
import { OfflineIndicator } from '../../components/common/OfflineSupport';
import usePermissions from '../../hooks/usePermissions';
import useRealTimeData from '../../hooks/useRealTimeData';
import { formatDateTime, formatDuration } from '../../utils/formatters';

// Types
interface EquipmentDetailsProps {
  route: {
    params: {
      equipmentCode: string;
    };
  };
  navigation: any;
}

interface EquipmentDetails {
  id: string;
  code: string;
  name: string;
  type: string;
  manufacturer: string;
  model: string;
  serialNumber: string;
  installationDate: string;
  status: 'Running' | 'Stopped' | 'Maintenance' | 'Error' | 'Offline';
  efficiency: number;
  availability: number;
  performance: number;
  quality: number;
  currentSpeed: number;
  targetSpeed: number;
  temperature?: number;
  pressure?: number;
  vibration?: number;
  lastMaintenance: {
    date: string;
    type: string;
    performedBy: string;
    notes: string;
  };
  nextMaintenance: {
    date: string;
    type: string;
    estimatedDuration: number;
  };
  maintenanceHistory: Array<{
    id: string;
    date: string;
    type: string;
    performedBy: string;
    duration: number;
    cost: number;
    notes: string;
  }>;
  performanceHistory: number[];
  faults: Array<{
    id: string;
    date: string;
    type: string;
    severity: 'Low' | 'Medium' | 'High' | 'Critical';
    description: string;
    resolved: boolean;
    resolvedBy?: string;
    resolvedAt?: string;
  }>;
  specifications: {
    powerRating: string;
    operatingTemperature: string;
    operatingPressure: string;
    dimensions: string;
    weight: string;
  };
  lastUpdate: Date;
}

const EquipmentDetailsScreen: React.FC<EquipmentDetailsProps> = ({ route, navigation }) => {
  const dispatch = useDispatch<AppDispatch>();
  const { canViewEquipment, canManageEquipment } = usePermissions();
  const { equipmentDetails, isLoading } = useSelector((state: RootState) => state.equipment);
  const { isOnline } = useSelector((state: RootState) => state.offline);
  
  const [refreshing, setRefreshing] = useState(false);
  const [equipment, setEquipment] = useState<EquipmentDetails | null>(null);

  const { equipmentCode } = route.params;

  // Real-time data hook
  const { data: realTimeData, isLive } = useRealTimeData(`equipment-${equipmentCode}`);

  const onRefresh = async () => {
    setRefreshing(true);
    try {
      const result = await dispatch(fetchEquipmentDetails(equipmentCode)).unwrap();
      setEquipment(result);
    } catch (error) {
      console.error('Failed to refresh equipment details:', error);
    }
    setRefreshing(false);
  };

  useEffect(() => {
    onRefresh();
  }, [equipmentCode]);

  useEffect(() => {
    if (realTimeData) {
      setEquipment(realTimeData);
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
      case 'Offline':
        return '#757575';
      default:
        return '#9E9E9E';
    }
  };

  const getSeverityColor = (severity: string) => {
    switch (severity) {
      case 'Low':
        return '#4CAF50';
      case 'Medium':
        return '#FF9800';
      case 'High':
        return '#F44336';
      case 'Critical':
        return '#9C27B0';
      default:
        return '#757575';
    }
  };

  const handleStatusUpdate = async (newStatus: string) => {
    if (!equipment) return;

    Alert.alert(
      'Update Equipment Status',
      `Are you sure you want to change the status to ${newStatus}?`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Update',
          onPress: async () => {
            try {
              await dispatch(updateEquipmentStatus({
                equipmentCode,
                status: newStatus,
              })).unwrap();
              Alert.alert('Success', 'Equipment status updated successfully');
              await onRefresh();
            } catch (error) {
              Alert.alert('Error', 'Failed to update equipment status');
            }
          },
        },
      ]
    );
  };

  const handleMaintenancePress = () => {
    // Navigate to maintenance screen
    navigation.navigate('Maintenance', { equipmentCode });
  };

  const handleFaultPress = (faultId: string) => {
    // Navigate to fault details
    navigation.navigate('FaultDetails', { faultId });
  };

  if (!canViewEquipment) {
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

  if (!equipment) {
    return (
      <View style={styles.container}>
        <Text style={styles.errorText}>Failed to load equipment details</Text>
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
          <Text style={styles.title}>{equipment.name}</Text>
          <LiveDataIndicator isLive={isLive} />
        </View>
        <Text style={styles.subtitle}>{equipment.code} - {equipment.type}</Text>
        <Text style={styles.lastUpdate}>
          Last updated: {equipment.lastUpdate ? new Date(equipment.lastUpdate).toLocaleTimeString() : 'Never'}
        </Text>
      </View>

      {/* Equipment Status */}
      <Card style={styles.statusCard}>
        <View style={styles.statusHeader}>
          <Text style={styles.statusTitle}>Equipment Status</Text>
          <StatusIndicator
            status={equipment.status === 'Running' ? 'online' : 'offline'}
            label={equipment.status}
            lastUpdated={equipment.lastUpdate}
            animated={equipment.status === 'Running'}
          />
        </View>
        <View style={styles.statusDetails}>
          <Text style={[styles.statusText, { color: getStatusColor(equipment.status) }]}>
            {equipment.status}
          </Text>
          {canManageEquipment && (
            <Button
              title="Update Status"
              onPress={() => {/* Show status update modal */}}
              variant="outline"
              size="small"
            />
          )}
        </View>
      </Card>

      {/* Performance Metrics */}
      <Card style={styles.metricsCard}>
        <Text style={styles.sectionTitle}>Performance Metrics</Text>
        
        <View style={styles.oeeContainer}>
          <CircularGauge
            value={equipment.efficiency * 100}
            maxValue={100}
            size={150}
            color={equipment.efficiency >= 0.8 ? '#4CAF50' : equipment.efficiency >= 0.6 ? '#FF9800' : '#F44336'}
            label="Efficiency"
            showValue
            showPercentage
          />
        </View>
        
        <View style={styles.metricsGrid}>
          <MetricCard
            title="Availability"
            value={`${Math.round(equipment.availability * 100)}%`}
            color="#2196F3"
            trend={equipment.availability >= 0.9 ? 'up' : 'down'}
          />
          <MetricCard
            title="Performance"
            value={`${Math.round(equipment.performance * 100)}%`}
            color="#4CAF50"
            trend={equipment.performance >= 0.9 ? 'up' : 'down'}
          />
          <MetricCard
            title="Quality"
            value={`${Math.round(equipment.quality * 100)}%`}
            color="#FF9800"
            trend={equipment.quality >= 0.95 ? 'up' : 'down'}
          />
        </View>
      </Card>

      {/* Operating Parameters */}
      <Card style={styles.parametersCard}>
        <Text style={styles.sectionTitle}>Operating Parameters</Text>
        
        <View style={styles.parametersGrid}>
          <View style={styles.parameterItem}>
            <Text style={styles.parameterLabel}>Current Speed:</Text>
            <Text style={styles.parameterValue}>{equipment.currentSpeed} units/min</Text>
          </View>
          <View style={styles.parameterItem}>
            <Text style={styles.parameterLabel}>Target Speed:</Text>
            <Text style={styles.parameterValue}>{equipment.targetSpeed} units/min</Text>
          </View>
          {equipment.temperature && (
            <View style={styles.parameterItem}>
              <Text style={styles.parameterLabel}>Temperature:</Text>
              <Text style={styles.parameterValue}>{equipment.temperature}°C</Text>
            </View>
          )}
          {equipment.pressure && (
            <View style={styles.parameterItem}>
              <Text style={styles.parameterLabel}>Pressure:</Text>
              <Text style={styles.parameterValue}>{equipment.pressure} bar</Text>
            </View>
          )}
          {equipment.vibration && (
            <View style={styles.parameterItem}>
              <Text style={styles.parameterLabel}>Vibration:</Text>
              <Text style={styles.parameterValue}>{equipment.vibration} mm/s</Text>
            </View>
          )}
        </View>
      </Card>

      {/* Maintenance Information */}
      <Card style={styles.maintenanceCard}>
        <View style={styles.sectionHeader}>
          <Text style={styles.sectionTitle}>Maintenance</Text>
          <TouchableOpacity onPress={handleMaintenancePress}>
            <Text style={styles.viewAllText}>View All</Text>
          </TouchableOpacity>
        </View>
        
        <View style={styles.maintenanceInfo}>
          <View style={styles.maintenanceItem}>
            <Text style={styles.maintenanceLabel}>Last Maintenance:</Text>
            <Text style={styles.maintenanceValue}>
              {formatDateTime(equipment.lastMaintenance.date)}
            </Text>
            <Text style={styles.maintenanceDetails}>
              {equipment.lastMaintenance.type} by {equipment.lastMaintenance.performedBy}
            </Text>
          </View>
          
          <View style={styles.maintenanceItem}>
            <Text style={styles.maintenanceLabel}>Next Maintenance:</Text>
            <Text style={styles.maintenanceValue}>
              {formatDateTime(equipment.nextMaintenance.date)}
            </Text>
            <Text style={styles.maintenanceDetails}>
              {equipment.nextMaintenance.type} (Est. {equipment.nextMaintenance.estimatedDuration}h)
            </Text>
          </View>
        </View>
      </Card>

      {/* Active Faults */}
      {equipment.faults && equipment.faults.filter(f => !f.resolved).length > 0 && (
        <Card style={styles.faultsCard}>
          <Text style={styles.sectionTitle}>Active Faults</Text>
          
          {equipment.faults.filter(f => !f.resolved).map((fault) => (
            <TouchableOpacity
              key={fault.id}
              style={styles.faultItem}
              onPress={() => handleFaultPress(fault.id)}
            >
              <View style={styles.faultHeader}>
                <Text style={styles.faultType}>{fault.type}</Text>
                <View style={[styles.severityBadge, { backgroundColor: getSeverityColor(fault.severity) }]}>
                  <Text style={styles.severityText}>{fault.severity}</Text>
                </View>
              </View>
              <Text style={styles.faultDescription}>{fault.description}</Text>
              <Text style={styles.faultDate}>
                Reported: {formatDateTime(fault.date)}
              </Text>
            </TouchableOpacity>
          ))}
        </Card>
      )}

      {/* Equipment Specifications */}
      <Card style={styles.specsCard}>
        <Text style={styles.sectionTitle}>Specifications</Text>
        
        <View style={styles.specsGrid}>
          <View style={styles.specItem}>
            <Text style={styles.specLabel}>Manufacturer:</Text>
            <Text style={styles.specValue}>{equipment.manufacturer}</Text>
          </View>
          <View style={styles.specItem}>
            <Text style={styles.specLabel}>Model:</Text>
            <Text style={styles.specValue}>{equipment.model}</Text>
          </View>
          <View style={styles.specItem}>
            <Text style={styles.specLabel}>Serial Number:</Text>
            <Text style={styles.specValue}>{equipment.serialNumber}</Text>
          </View>
          <View style={styles.specItem}>
            <Text style={styles.specLabel}>Installation Date:</Text>
            <Text style={styles.specValue}>{formatDateTime(equipment.installationDate)}</Text>
          </View>
          <View style={styles.specItem}>
            <Text style={styles.specLabel}>Power Rating:</Text>
            <Text style={styles.specValue}>{equipment.specifications.powerRating}</Text>
          </View>
          <View style={styles.specItem}>
            <Text style={styles.specLabel}>Operating Temperature:</Text>
            <Text style={styles.specValue}>{equipment.specifications.operatingTemperature}</Text>
          </View>
        </View>
      </Card>

      {/* Performance Trend */}
      {equipment.performanceHistory && equipment.performanceHistory.length > 0 && (
        <Card style={styles.trendCard}>
          <Text style={styles.sectionTitle}>Performance Trend (Last 24 Hours)</Text>
          <LineChart
            data={equipment.performanceHistory}
            height={200}
            color="#2196F3"
            showGrid
            showValues
          />
        </Card>
      )}

      {/* Action Buttons */}
      {canManageEquipment && (
        <View style={styles.actionsContainer}>
          <Button
            title="Schedule Maintenance"
            onPress={handleMaintenancePress}
            variant="primary"
            style={styles.actionButton}
          />
          <Button
            title="Report Fault"
            onPress={() => {/* Navigate to fault reporting */}}
            variant="outline"
            style={styles.actionButton}
          />
        </View>
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
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#212121',
    marginBottom: 12,
  },
  oeeContainer: {
    alignItems: 'center',
    marginBottom: 20,
  },
  metricsGrid: {
    flexDirection: 'row',
    justifyContent: 'space-around',
  },
  parametersCard: {
    margin: 16,
    marginTop: 8,
    padding: 16,
  },
  parametersGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
  },
  parameterItem: {
    width: '50%',
    marginBottom: 12,
  },
  parameterLabel: {
    fontSize: 14,
    color: '#757575',
    fontWeight: '500',
  },
  parameterValue: {
    fontSize: 14,
    color: '#212121',
    marginTop: 2,
  },
  maintenanceCard: {
    margin: 16,
    marginTop: 8,
    padding: 16,
  },
  sectionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  viewAllText: {
    fontSize: 14,
    color: '#2196F3',
  },
  maintenanceInfo: {
    marginTop: 8,
  },
  maintenanceItem: {
    marginBottom: 16,
  },
  maintenanceLabel: {
    fontSize: 14,
    color: '#757575',
    fontWeight: '500',
  },
  maintenanceValue: {
    fontSize: 16,
    color: '#212121',
    marginTop: 2,
  },
  maintenanceDetails: {
    fontSize: 12,
    color: '#9E9E9E',
    marginTop: 2,
  },
  faultsCard: {
    margin: 16,
    marginTop: 8,
    padding: 16,
  },
  faultItem: {
    backgroundColor: '#FFFFFF',
    padding: 12,
    marginBottom: 8,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#E0E0E0',
  },
  faultHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 4,
  },
  faultType: {
    fontSize: 16,
    fontWeight: '500',
    color: '#212121',
  },
  severityBadge: {
    paddingHorizontal: 8,
    paddingVertical: 2,
    borderRadius: 8,
  },
  severityText: {
    fontSize: 10,
    color: '#FFFFFF',
    fontWeight: '600',
  },
  faultDescription: {
    fontSize: 14,
    color: '#757575',
    marginBottom: 4,
  },
  faultDate: {
    fontSize: 12,
    color: '#9E9E9E',
  },
  specsCard: {
    margin: 16,
    marginTop: 8,
    padding: 16,
  },
  specsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
  },
  specItem: {
    width: '50%',
    marginBottom: 12,
  },
  specLabel: {
    fontSize: 14,
    color: '#757575',
    fontWeight: '500',
  },
  specValue: {
    fontSize: 14,
    color: '#212121',
    marginTop: 2,
  },
  trendCard: {
    margin: 16,
    marginTop: 8,
    padding: 16,
  },
  actionsContainer: {
    padding: 16,
  },
  actionButton: {
    marginVertical: 4,
  },
});

export default EquipmentDetailsScreen;
