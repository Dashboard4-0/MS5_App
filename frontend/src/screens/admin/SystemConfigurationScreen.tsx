/**
 * MS5.0 Floor Dashboard - System Configuration Screen
 * 
 * This screen allows administrators to configure
 * system settings and parameters.
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

const SystemConfigurationScreen: React.FC = () => {
  const { canManageSystem, canViewDashboard } = usePermissions();
  const [refreshing, setRefreshing] = useState(false);
  const [configurations, setConfigurations] = useState([]);

  const onRefresh = async () => {
    setRefreshing(true);
    // TODO: Fetch configurations from API
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
        <Text style={styles.title}>System Configuration</Text>
        <Text style={styles.subtitle}>Configure system settings and parameters</Text>
      </View>

      {/* Configuration Categories */}
      <Card style={styles.sectionCard}>
        <Text style={styles.sectionTitle}>Configuration Categories</Text>
        
        <View style={styles.categoriesList}>
          <TouchableOpacity style={styles.categoryItem}>
            <Text style={styles.categoryTitle}>General Settings</Text>
            <Text style={styles.categoryDescription}>Basic system configuration</Text>
          </TouchableOpacity>
          
          <TouchableOpacity style={styles.categoryItem}>
            <Text style={styles.categoryTitle}>User Management</Text>
            <Text style={styles.categoryDescription}>User roles and permissions</Text>
          </TouchableOpacity>
          
          <TouchableOpacity style={styles.categoryItem}>
            <Text style={styles.categoryTitle}>Production Settings</Text>
            <Text style={styles.categoryDescription}>Production line configuration</Text>
          </TouchableOpacity>
          
          <TouchableOpacity style={styles.categoryItem}>
            <Text style={styles.categoryTitle}>Notification Settings</Text>
            <Text style={styles.categoryDescription}>Alert and notification configuration</Text>
          </TouchableOpacity>
        </View>
      </Card>

      {/* System Status */}
      <Card style={styles.sectionCard}>
        <Text style={styles.sectionTitle}>System Status</Text>
        
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

      {/* Quick Actions */}
      <Card style={styles.sectionCard}>
        <Text style={styles.sectionTitle}>Quick Actions</Text>
        
        <View style={styles.actionsContainer}>
          <Button
            title="Backup System"
            onPress={() => {}}
            style={styles.actionButton}
            variant="outline"
          />
          <Button
            title="Restore Settings"
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
  categoriesList: {
    minHeight: 200,
  },
  categoryItem: {
    paddingVertical: 16,
    paddingHorizontal: 16,
    backgroundColor: '#f8f9fa',
    borderRadius: 8,
    marginBottom: 12,
  },
  categoryTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 4,
  },
  categoryDescription: {
    fontSize: 14,
    color: '#666',
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
  actionsContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
  },
  actionButton: {
    width: '48%',
    margin: '1%',
  },
});

export default SystemConfigurationScreen;
