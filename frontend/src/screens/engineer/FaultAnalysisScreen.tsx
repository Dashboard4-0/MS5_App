/**
 * MS5.0 Floor Dashboard - Fault Analysis Screen
 * 
 * This screen allows engineers to view and analyze
 * equipment faults and diagnostic information.
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

const FaultAnalysisScreen: React.FC = () => {
  const { canManageEquipment, canViewDashboard } = usePermissions();
  const [refreshing, setRefreshing] = useState(false);
  const [faults, setFaults] = useState([]);

  const onRefresh = async () => {
    setRefreshing(true);
    // TODO: Fetch faults from API
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
        <Text style={styles.title}>Fault Analysis</Text>
        <Text style={styles.subtitle}>Analyze equipment faults and diagnostics</Text>
      </View>

      {/* Active Faults */}
      <Card style={styles.sectionCard}>
        <Text style={styles.sectionTitle}>Active Faults</Text>
        
        <View style={styles.faultsList}>
          {faults.length > 0 ? (
            faults.map((fault, index) => (
              <TouchableOpacity key={index} style={styles.faultItem}>
                <Text style={styles.faultTitle}>{fault.title}</Text>
                <Text style={styles.faultSeverity}>{fault.severity}</Text>
              </TouchableOpacity>
            ))
          ) : (
            <Text style={styles.emptyText}>No active faults</Text>
          )}
        </View>
      </Card>

      {/* Fault History */}
      <Card style={styles.sectionCard}>
        <Text style={styles.sectionTitle}>Fault History</Text>
        
        <View style={styles.historyList}>
          <Text style={styles.emptyText}>Fault history coming soon</Text>
        </View>
      </Card>

      {/* Quick Actions */}
      <Card style={styles.sectionCard}>
        <Text style={styles.sectionTitle}>Quick Actions</Text>
        
        <View style={styles.actionsContainer}>
          <Button
            title="Run Diagnostics"
            onPress={() => {}}
            style={styles.actionButton}
            variant="outline"
          />
          <Button
            title="View Reports"
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
  faultsList: {
    minHeight: 200,
  },
  faultItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 12,
    paddingHorizontal: 16,
    backgroundColor: '#f8f9fa',
    borderRadius: 8,
    marginBottom: 8,
  },
  faultTitle: {
    fontSize: 16,
    color: '#333',
    flex: 1,
  },
  faultSeverity: {
    fontSize: 14,
    color: '#f44336',
  },
  historyList: {
    minHeight: 100,
    justifyContent: 'center',
  },
  emptyText: {
    fontSize: 16,
    color: '#999',
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

export default FaultAnalysisScreen;
