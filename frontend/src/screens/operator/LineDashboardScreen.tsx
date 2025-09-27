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
} from 'react-native';
import { useSelector } from 'react-redux';
import { RootState } from '../../store';
import Card from '../../components/common/Card';
import usePermissions from '../../hooks/usePermissions';

const LineDashboardScreen: React.FC = () => {
  const { canViewDashboard } = usePermissions();
  const [refreshing, setRefreshing] = useState(false);
  const [dashboardData, setDashboardData] = useState({
    lineStatus: 'Running',
    oee: 0.85,
    availability: 0.92,
    performance: 0.95,
    quality: 0.95,
    currentSpeed: 120,
    targetSpeed: 150,
  });

  const onRefresh = async () => {
    setRefreshing(true);
    // TODO: Fetch dashboard data from API
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
        <Text style={styles.title}>Line Dashboard</Text>
        <Text style={styles.subtitle}>Real-time production monitoring</Text>
      </View>

      {/* Line Status */}
      <Card style={styles.statusCard}>
        <View style={styles.statusHeader}>
          <Text style={styles.statusTitle}>Production Line Status</Text>
          <View style={[styles.statusIndicator, { backgroundColor: '#4CAF50' }]} />
        </View>
        <Text style={styles.statusText}>{dashboardData.lineStatus}</Text>
      </Card>

      {/* OEE Metrics */}
      <Card style={styles.metricsCard}>
        <Text style={styles.metricsTitle}>Overall Equipment Effectiveness</Text>
        <View style={styles.oeeContainer}>
          <Text style={styles.oeeValue}>{Math.round(dashboardData.oee * 100)}%</Text>
        </View>
        
        <View style={styles.metricsRow}>
          <View style={styles.metricItem}>
            <Text style={styles.metricValue}>{Math.round(dashboardData.availability * 100)}%</Text>
            <Text style={styles.metricLabel}>Availability</Text>
          </View>
          <View style={styles.metricItem}>
            <Text style={styles.metricValue}>{Math.round(dashboardData.performance * 100)}%</Text>
            <Text style={styles.metricLabel}>Performance</Text>
          </View>
          <View style={styles.metricItem}>
            <Text style={styles.metricValue}>{Math.round(dashboardData.quality * 100)}%</Text>
            <Text style={styles.metricLabel}>Quality</Text>
          </View>
        </View>
      </Card>

      {/* Speed Information */}
      <Card style={styles.speedCard}>
        <Text style={styles.speedTitle}>Current Speed</Text>
        <View style={styles.speedContainer}>
          <Text style={styles.speedValue}>{dashboardData.currentSpeed}</Text>
          <Text style={styles.speedUnit}>units/min</Text>
        </View>
        <Text style={styles.speedTarget}>
          Target: {dashboardData.targetSpeed} units/min
        </Text>
      </Card>

      {/* Equipment Status */}
      <Card style={styles.equipmentCard}>
        <Text style={styles.equipmentTitle}>Equipment Status</Text>
        <View style={styles.equipmentList}>
          <Text style={styles.emptyText}>Equipment status coming soon</Text>
        </View>
      </Card>
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
  statusCard: {
    margin: 20,
    marginTop: 10,
    padding: 20,
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
    color: '#333',
  },
  statusIndicator: {
    width: 12,
    height: 12,
    borderRadius: 6,
  },
  statusText: {
    fontSize: 16,
    color: '#4CAF50',
    fontWeight: '500',
  },
  metricsCard: {
    margin: 20,
    marginTop: 10,
    padding: 20,
  },
  metricsTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 16,
    textAlign: 'center',
  },
  oeeContainer: {
    alignItems: 'center',
    marginBottom: 20,
  },
  oeeValue: {
    fontSize: 48,
    fontWeight: 'bold',
    color: '#2196F3',
  },
  metricsRow: {
    flexDirection: 'row',
    justifyContent: 'space-around',
  },
  metricItem: {
    alignItems: 'center',
  },
  metricValue: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 4,
  },
  metricLabel: {
    fontSize: 14,
    color: '#666',
  },
  speedCard: {
    margin: 20,
    marginTop: 10,
    padding: 20,
  },
  speedTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 16,
    textAlign: 'center',
  },
  speedContainer: {
    flexDirection: 'row',
    alignItems: 'baseline',
    justifyContent: 'center',
    marginBottom: 8,
  },
  speedValue: {
    fontSize: 36,
    fontWeight: 'bold',
    color: '#2196F3',
  },
  speedUnit: {
    fontSize: 16,
    color: '#666',
    marginLeft: 8,
  },
  speedTarget: {
    fontSize: 14,
    color: '#666',
    textAlign: 'center',
  },
  equipmentCard: {
    margin: 20,
    marginTop: 10,
    padding: 20,
  },
  equipmentTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 16,
  },
  equipmentList: {
    minHeight: 100,
    justifyContent: 'center',
  },
  emptyText: {
    fontSize: 16,
    color: '#999',
    textAlign: 'center',
  },
});

export default LineDashboardScreen;
