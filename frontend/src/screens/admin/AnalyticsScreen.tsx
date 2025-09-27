/**
 * MS5.0 Floor Dashboard - Analytics Screen
 * 
 * This screen provides administrators with system-wide
 * analytics and performance metrics.
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

const AnalyticsScreen: React.FC = () => {
  const { canViewDashboard } = usePermissions();
  const [refreshing, setRefreshing] = useState(false);
  const [analytics, setAnalytics] = useState([]);

  const onRefresh = async () => {
    setRefreshing(true);
    // TODO: Fetch analytics from API
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
        <Text style={styles.title}>Analytics</Text>
        <Text style={styles.subtitle}>System-wide analytics and performance metrics</Text>
      </View>

      {/* Key Metrics */}
      <View style={styles.metricsContainer}>
        <Card style={styles.metricCard}>
          <Text style={styles.metricValue}>0</Text>
          <Text style={styles.metricLabel}>Total Users</Text>
        </Card>

        <Card style={styles.metricCard}>
          <Text style={styles.metricValue}>0</Text>
          <Text style={styles.metricLabel}>Active Sessions</Text>
        </Card>

        <Card style={styles.metricCard}>
          <Text style={styles.metricValue}>0</Text>
          <Text style={styles.metricLabel}>Production Lines</Text>
        </Card>

        <Card style={styles.metricCard}>
          <Text style={styles.metricValue}>0</Text>
          <Text style={styles.metricLabel}>System Uptime</Text>
        </Card>
      </View>

      {/* Performance Analytics */}
      <Card style={styles.sectionCard}>
        <Text style={styles.sectionTitle}>Performance Analytics</Text>
        
        <View style={styles.analyticsList}>
          <Text style={styles.emptyText}>Performance analytics coming soon</Text>
        </View>
      </Card>

      {/* User Analytics */}
      <Card style={styles.sectionCard}>
        <Text style={styles.sectionTitle}>User Analytics</Text>
        
        <View style={styles.analyticsList}>
          <Text style={styles.emptyText}>User analytics coming soon</Text>
        </View>
      </Card>

      {/* Quick Actions */}
      <Card style={styles.sectionCard}>
        <Text style={styles.sectionTitle}>Quick Actions</Text>
        
        <View style={styles.actionsContainer}>
          <Button
            title="Export Analytics"
            onPress={() => {}}
            style={styles.actionButton}
            variant="outline"
          />
          <Button
            title="Generate Report"
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
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 16,
  },
  analyticsList: {
    minHeight: 200,
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

export default AnalyticsScreen;
