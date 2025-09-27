/**
 * MS5.0 Floor Dashboard - Schedule Management Screen
 * 
 * This screen allows managers to view and manage
 * production schedules and job assignments.
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

const ScheduleManagementScreen: React.FC = () => {
  const { canManageJobs, canViewDashboard } = usePermissions();
  const [refreshing, setRefreshing] = useState(false);
  const [schedules, setSchedules] = useState([]);

  const onRefresh = async () => {
    setRefreshing(true);
    // TODO: Fetch schedules from API
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
        <Text style={styles.title}>Schedule Management</Text>
        <Text style={styles.subtitle}>Manage production schedules and job assignments</Text>
      </View>

      {/* Quick Actions */}
      <Card style={styles.actionsCard}>
        <Text style={styles.sectionTitle}>Quick Actions</Text>
        
        <View style={styles.actionsContainer}>
          <Button
            title="Create Schedule"
            onPress={() => {}}
            style={styles.actionButton}
            variant="outline"
          />
          <Button
            title="Assign Jobs"
            onPress={() => {}}
            style={styles.actionButton}
            variant="outline"
          />
        </View>
      </Card>

      {/* Today's Schedules */}
      <Card style={styles.sectionCard}>
        <Text style={styles.sectionTitle}>Today's Schedules</Text>
        
        <View style={styles.schedulesList}>
          {schedules.length > 0 ? (
            schedules.map((schedule, index) => (
              <TouchableOpacity key={index} style={styles.scheduleItem}>
                <Text style={styles.scheduleTitle}>{schedule.title}</Text>
                <Text style={styles.scheduleStatus}>{schedule.status}</Text>
              </TouchableOpacity>
            ))
          ) : (
            <Text style={styles.emptyText}>No schedules for today</Text>
          )}
        </View>
      </Card>

      {/* Upcoming Schedules */}
      <Card style={styles.sectionCard}>
        <Text style={styles.sectionTitle}>Upcoming Schedules</Text>
        
        <View style={styles.schedulesList}>
          <Text style={styles.emptyText}>Upcoming schedules coming soon</Text>
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
  actionsCard: {
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
  actionsContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
  },
  actionButton: {
    width: '48%',
    margin: '1%',
  },
  sectionCard: {
    margin: 20,
    marginTop: 10,
    padding: 20,
  },
  schedulesList: {
    minHeight: 200,
  },
  scheduleItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 12,
    paddingHorizontal: 16,
    backgroundColor: '#f8f9fa',
    borderRadius: 8,
    marginBottom: 8,
  },
  scheduleTitle: {
    fontSize: 16,
    color: '#333',
    flex: 1,
  },
  scheduleStatus: {
    fontSize: 14,
    color: '#666',
  },
  emptyText: {
    fontSize: 16,
    color: '#999',
    textAlign: 'center',
    marginTop: 50,
  },
});

export default ScheduleManagementScreen;
