/**
 * MS5.0 Floor Dashboard - Maintenance Screen
 * 
 * This screen allows engineers to view and manage
 * maintenance work orders and tasks.
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

const MaintenanceScreen: React.FC = () => {
  const { canManageEquipment, canViewDashboard } = usePermissions();
  const [refreshing, setRefreshing] = useState(false);
  const [workOrders, setWorkOrders] = useState([]);

  const onRefresh = async () => {
    setRefreshing(true);
    // TODO: Fetch work orders from API
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
        <Text style={styles.title}>Maintenance</Text>
        <Text style={styles.subtitle}>Manage maintenance work orders and tasks</Text>
      </View>

      {/* Work Orders */}
      <Card style={styles.sectionCard}>
        <Text style={styles.sectionTitle}>Work Orders</Text>
        
        <View style={styles.workOrdersList}>
          {workOrders.length > 0 ? (
            workOrders.map((order, index) => (
              <TouchableOpacity key={index} style={styles.workOrderItem}>
                <Text style={styles.workOrderTitle}>{order.title}</Text>
                <Text style={styles.workOrderStatus}>{order.status}</Text>
              </TouchableOpacity>
            ))
          ) : (
            <Text style={styles.emptyText}>No work orders available</Text>
          )}
        </View>
      </Card>

      {/* Maintenance Statistics */}
      <Card style={styles.sectionCard}>
        <Text style={styles.sectionTitle}>Maintenance Statistics</Text>
        
        <View style={styles.statsContainer}>
          <View style={styles.statItem}>
            <Text style={styles.statValue}>0</Text>
            <Text style={styles.statLabel}>Open Orders</Text>
          </View>
          <View style={styles.statItem}>
            <Text style={styles.statValue}>0</Text>
            <Text style={styles.statLabel}>Completed Today</Text>
          </View>
          <View style={styles.statItem}>
            <Text style={styles.statValue}>0</Text>
            <Text style={styles.statLabel}>Overdue</Text>
          </View>
        </View>
      </Card>

      {/* Quick Actions */}
      <Card style={styles.sectionCard}>
        <Text style={styles.sectionTitle}>Quick Actions</Text>
        
        <View style={styles.actionsContainer}>
          <Button
            title="Create Work Order"
            onPress={() => {}}
            style={styles.actionButton}
            variant="outline"
          />
          <Button
            title="Schedule Maintenance"
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
  sectionCard: {
    margin: 20,
    marginTop: 10,
    padding: 20,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 16,
  },
  workOrdersList: {
    minHeight: 200,
  },
  workOrderItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 12,
    paddingHorizontal: 16,
    backgroundColor: '#f8f9fa',
    borderRadius: 8,
    marginBottom: 8,
  },
  workOrderTitle: {
    fontSize: 16,
    color: '#333',
    flex: 1,
  },
  workOrderStatus: {
    fontSize: 14,
    color: '#666',
  },
  emptyText: {
    fontSize: 16,
    color: '#999',
    textAlign: 'center',
    marginTop: 50,
  },
  statsContainer: {
    flexDirection: 'row',
    justifyContent: 'space-around',
  },
  statItem: {
    alignItems: 'center',
  },
  statValue: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#2196F3',
    marginBottom: 4,
  },
  statLabel: {
    fontSize: 14,
    color: '#666',
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

export default MaintenanceScreen;
