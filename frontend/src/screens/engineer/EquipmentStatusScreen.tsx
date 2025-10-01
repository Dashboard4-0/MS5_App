/**
 * MS5.0 Floor Dashboard - Equipment Status Screen
 * 
 * This screen provides engineers with an overview of equipment
 * status, maintenance information, and diagnostic tools.
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
import { fetchEquipmentList, updateEquipmentStatus } from '../../store/slices/equipmentSlice';
import Card from '../../components/common/Card';
import Button from '../../components/common/Button';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import { CircularGauge, MetricCard } from '../../components/common/DataVisualization';
import { StatusIndicator, LiveDataIndicator, RealTimeBadge } from '../../components/common/RealTimeIndicators';
import { OfflineIndicator } from '../../components/common/OfflineSupport';
import usePermissions from '../../hooks/usePermissions';
import useRealTimeData from '../../hooks/useRealTimeData';
import { formatDateTime } from '../../utils/formatters';
import { Permission } from '../../config/constants';

const EquipmentStatusScreen: React.FC = () => {
  const { canManageEquipment, canViewDashboard } = usePermissions();
  const [refreshing, setRefreshing] = useState(false);
  const [equipmentData, setEquipmentData] = useState({
    totalEquipment: 0,
    runningEquipment: 0,
    maintenanceRequired: 0,
    faultCount: 0,
  });

  const onRefresh = async () => {
    setRefreshing(true);
    // TODO: Fetch equipment data from API
    setTimeout(() => {
      setRefreshing(false);
    }, 1000);
  };

  useEffect(() => {
    onRefresh();
  }, []);

  if (!canViewDashboard) {
    return (
      <View style={styles.container}>
        <Text style={styles.unauthorizedText}>
          You don't have permission to view this screen.
        </Text>
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
      <View style={styles.header}>
        <Text style={styles.title}>Equipment Status</Text>
        <Text style={styles.subtitle}>Real-time equipment monitoring and diagnostics</Text>
      </View>

      {/* Equipment Metrics */}
      <View style={styles.metricsContainer}>
        <Card style={styles.metricCard}>
          <Text style={styles.metricValue}>{equipmentData.totalEquipment}</Text>
          <Text style={styles.metricLabel}>Total Equipment</Text>
        </Card>

        <Card style={styles.metricCard}>
          <Text style={[styles.metricValue, { color: '#4CAF50' }]}>
            {equipmentData.runningEquipment}
          </Text>
          <Text style={styles.metricLabel}>Running</Text>
        </Card>

        <Card style={styles.metricCard}>
          <Text style={[styles.metricValue, { color: '#FF9800' }]}>
            {equipmentData.maintenanceRequired}
          </Text>
          <Text style={styles.metricLabel}>Maintenance Required</Text>
        </Card>

        <Card style={styles.metricCard}>
          <Text style={[styles.metricValue, { color: '#f44336' }]}>
            {equipmentData.faultCount}
          </Text>
          <Text style={styles.metricLabel}>Active Faults</Text>
        </Card>
      </View>

      {/* Equipment List */}
      <Card style={styles.sectionCard}>
        <View style={styles.sectionHeader}>
          <Text style={styles.sectionTitle}>Equipment Status</Text>
          <TouchableOpacity>
            <Text style={styles.viewAllText}>View All</Text>
          </TouchableOpacity>
        </View>
        
        <View style={styles.equipmentList}>
          {/* TODO: Add equipment list */}
          <Text style={styles.emptyText}>No equipment data available</Text>
        </View>
      </Card>

      {/* Maintenance Alerts */}
      <Card style={styles.sectionCard}>
        <View style={styles.sectionHeader}>
          <Text style={styles.sectionTitle}>Maintenance Alerts</Text>
          <TouchableOpacity>
            <Text style={styles.viewAllText}>View All</Text>
          </TouchableOpacity>
        </View>
        
        <View style={styles.alertsList}>
          {equipmentData.maintenanceRequired > 0 ? (
            <Text style={styles.alertText}>
              {equipmentData.maintenanceRequired} equipment items require maintenance
            </Text>
          ) : (
            <Text style={styles.emptyText}>No maintenance alerts</Text>
          )}
        </View>
      </Card>

      {/* Quick Actions */}
      {canManageEquipment && (
        <Card style={styles.sectionCard}>
          <Text style={styles.sectionTitle}>Quick Actions</Text>
          
          <View style={styles.actionsContainer}>
            <Button
              title="Schedule Maintenance"
              onPress={() => {}}
              style={styles.actionButton}
              variant="outline"
            />
            <Button
              title="View Diagnostics"
              onPress={() => {}}
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
    backgroundColor: '#f5f5f5',
  },
  header: {
    padding: 20,
    paddingBottom: 10,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 4,
  },
  subtitle: {
    fontSize: 16,
    color: '#666',
  },
  unauthorizedText: {
    fontSize: 16,
    color: '#666',
    textAlign: 'center',
    marginTop: 50,
  },
  metricsContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    padding: 20,
    paddingTop: 10,
  },
  metricCard: {
    width: '48%',
    margin: '1%',
    padding: 16,
    alignItems: 'center',
  },
  metricValue: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#2196F3',
    marginBottom: 4,
  },
  metricLabel: {
    fontSize: 14,
    color: '#666',
    textAlign: 'center',
  },
  sectionCard: {
    margin: 20,
    marginTop: 10,
    padding: 20,
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
    color: '#333',
  },
  viewAllText: {
    fontSize: 14,
    color: '#2196F3',
  },
  equipmentList: {
    minHeight: 100,
    justifyContent: 'center',
  },
  alertsList: {
    minHeight: 60,
    justifyContent: 'center',
  },
  emptyText: {
    fontSize: 16,
    color: '#999',
    textAlign: 'center',
  },
  alertText: {
    fontSize: 16,
    color: '#FF9800',
    textAlign: 'center',
  },
  actionsContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
  },
  actionButton: {
    width: '48%',
    margin: '1%',
  },
});

export default EquipmentStatusScreen;
