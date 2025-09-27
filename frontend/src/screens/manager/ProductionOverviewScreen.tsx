/**
 * MS5.0 Floor Dashboard - Production Overview Screen
 * 
 * This screen provides managers with an overview of production
 * status, key metrics, and real-time updates.
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

const ProductionOverviewScreen: React.FC = () => {
  const { canViewDashboard, canManageProduction } = usePermissions();
  const [refreshing, setRefreshing] = useState(false);
  const [productionData, setProductionData] = useState({
    totalLines: 0,
    activeLines: 0,
    totalProduction: 0,
    averageOEE: 0,
    activeAndonEvents: 0,
  });

  const onRefresh = async () => {
    setRefreshing(true);
    // TODO: Fetch production data from API
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
        <Text style={styles.title}>Production Overview</Text>
        <Text style={styles.subtitle}>Real-time production status and metrics</Text>
      </View>

      {/* Key Metrics Cards */}
      <View style={styles.metricsContainer}>
        <Card style={styles.metricCard}>
          <Text style={styles.metricValue}>{productionData.totalLines}</Text>
          <Text style={styles.metricLabel}>Total Lines</Text>
        </Card>

        <Card style={styles.metricCard}>
          <Text style={styles.metricValue}>{productionData.activeLines}</Text>
          <Text style={styles.metricLabel}>Active Lines</Text>
        </Card>

        <Card style={styles.metricCard}>
          <Text style={styles.metricValue}>{productionData.totalProduction}</Text>
          <Text style={styles.metricLabel}>Total Production</Text>
        </Card>

        <Card style={styles.metricCard}>
          <Text style={styles.metricValue}>{Math.round(productionData.averageOEE * 100)}%</Text>
          <Text style={styles.metricLabel}>Average OEE</Text>
        </Card>
      </View>

      {/* Production Lines Status */}
      <Card style={styles.sectionCard}>
        <View style={styles.sectionHeader}>
          <Text style={styles.sectionTitle}>Production Lines</Text>
          <TouchableOpacity>
            <Text style={styles.viewAllText}>View All</Text>
          </TouchableOpacity>
        </View>
        
        <View style={styles.linesList}>
          {/* TODO: Add production lines list */}
          <Text style={styles.emptyText}>No production lines available</Text>
        </View>
      </Card>

      {/* Active Andon Events */}
      <Card style={styles.sectionCard}>
        <View style={styles.sectionHeader}>
          <Text style={styles.sectionTitle}>Active Andon Events</Text>
          <TouchableOpacity>
            <Text style={styles.viewAllText}>View All</Text>
          </TouchableOpacity>
        </View>
        
        <View style={styles.andonList}>
          {productionData.activeAndonEvents > 0 ? (
            <Text style={styles.andonText}>
              {productionData.activeAndonEvents} active events requiring attention
            </Text>
          ) : (
            <Text style={styles.emptyText}>No active Andon events</Text>
          )}
        </View>
      </Card>

      {/* Quick Actions */}
      {canManageProduction && (
        <Card style={styles.sectionCard}>
          <Text style={styles.sectionTitle}>Quick Actions</Text>
          
          <View style={styles.actionsContainer}>
            <Button
              title="Create Schedule"
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
  linesList: {
    minHeight: 100,
    justifyContent: 'center',
  },
  andonList: {
    minHeight: 60,
    justifyContent: 'center',
  },
  emptyText: {
    fontSize: 16,
    color: '#999',
    textAlign: 'center',
  },
  andonText: {
    fontSize: 16,
    color: '#f44336',
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

export default ProductionOverviewScreen;
