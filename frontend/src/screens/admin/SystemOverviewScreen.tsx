/**
 * MS5.0 Floor Dashboard - System Overview Screen
 * 
 * This screen provides administrators with system-wide metrics,
 * user management, and system configuration options.
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
import { useSelector } from 'react-redux';
import { RootState } from '../../store';
import Card from '../../components/common/Card';
import Button from '../../components/common/Button';
import usePermissions from '../../hooks/usePermissions';
import { Permission } from '../../config/constants';

const SystemOverviewScreen: React.FC = () => {
  const { canManageSystem, canManageUsers, canViewDashboard } = usePermissions();
  const [refreshing, setRefreshing] = useState(false);
  const [systemData, setSystemData] = useState({
    totalUsers: 0,
    activeUsers: 0,
    systemUptime: 0,
    totalProductionLines: 0,
    systemHealth: 'Good',
  });

  const onRefresh = async () => {
    setRefreshing(true);
    // TODO: Fetch system data from API
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
        <Text style={styles.title}>System Overview</Text>
        <Text style={styles.subtitle}>System-wide metrics and administration</Text>
      </View>

      {/* System Metrics */}
      <View style={styles.metricsContainer}>
        <Card style={styles.metricCard}>
          <Text style={styles.metricValue}>{systemData.totalUsers}</Text>
          <Text style={styles.metricLabel}>Total Users</Text>
        </Card>

        <Card style={styles.metricCard}>
          <Text style={[styles.metricValue, { color: '#4CAF50' }]}>
            {systemData.activeUsers}
          </Text>
          <Text style={styles.metricLabel}>Active Users</Text>
        </Card>

        <Card style={styles.metricCard}>
          <Text style={styles.metricValue}>{systemData.totalProductionLines}</Text>
          <Text style={styles.metricLabel}>Production Lines</Text>
        </Card>

        <Card style={styles.metricCard}>
          <Text style={[
            styles.metricValue,
            { color: systemData.systemHealth === 'Good' ? '#4CAF50' : '#f44336' }
          ]}>
            {systemData.systemHealth}
          </Text>
          <Text style={styles.metricLabel}>System Health</Text>
        </Card>
      </View>

      {/* System Status */}
      <Card style={styles.sectionCard}>
        <View style={styles.sectionHeader}>
          <Text style={styles.sectionTitle}>System Status</Text>
          <TouchableOpacity>
            <Text style={styles.viewAllText}>View Details</Text>
          </TouchableOpacity>
        </View>
        
        <View style={styles.statusList}>
          <View style={styles.statusRow}>
            <Text style={styles.statusLabel}>Database</Text>
            <Text style={[styles.statusValue, { color: '#4CAF50' }]}>Online</Text>
          </View>
          <View style={styles.statusRow}>
            <Text style={styles.statusLabel}>API Server</Text>
            <Text style={[styles.statusValue, { color: '#4CAF50' }]}>Online</Text>
          </View>
          <View style={styles.statusRow}>
            <Text style={styles.statusLabel}>WebSocket</Text>
            <Text style={[styles.statusValue, { color: '#4CAF50' }]}>Connected</Text>
          </View>
        </View>
      </Card>

      {/* User Management */}
      {canManageUsers && (
        <Card style={styles.sectionCard}>
          <View style={styles.sectionHeader}>
            <Text style={styles.sectionTitle}>User Management</Text>
            <TouchableOpacity>
              <Text style={styles.viewAllText}>Manage Users</Text>
            </TouchableOpacity>
          </View>
          
          <View style={styles.userStats}>
            <Text style={styles.userStatsText}>
              {systemData.totalUsers} total users, {systemData.activeUsers} currently active
            </Text>
          </View>
        </Card>
      )}

      {/* System Configuration */}
      {canManageSystem && (
        <Card style={styles.sectionCard}>
          <Text style={styles.sectionTitle}>System Configuration</Text>
          
          <View style={styles.actionsContainer}>
            <Button
              title="System Settings"
              onPress={() => {}}
              style={styles.actionButton}
              variant="outline"
            />
            <Button
              title="User Roles"
              onPress={() => {}}
              style={styles.actionButton}
              variant="outline"
            />
          </View>
        </Card>
      )}

      {/* Quick Actions */}
      <Card style={styles.sectionCard}>
        <Text style={styles.sectionTitle}>Quick Actions</Text>
        
        <View style={styles.actionsContainer}>
          <Button
            title="Generate Report"
            onPress={() => {}}
            style={styles.actionButton}
            variant="outline"
          />
          <Button
            title="System Logs"
            onPress={() => {}}
            style={styles.actionButton}
            variant="outline"
          />
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
  statusList: {
    minHeight: 100,
  },
  statusRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 8,
    borderBottomWidth: 1,
    borderBottomColor: '#f0f0f0',
  },
  statusLabel: {
    fontSize: 16,
    color: '#666',
  },
  statusValue: {
    fontSize: 16,
    fontWeight: '500',
  },
  userStats: {
    minHeight: 60,
    justifyContent: 'center',
  },
  userStatsText: {
    fontSize: 16,
    color: '#666',
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

export default SystemOverviewScreen;
