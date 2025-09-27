/**
 * MS5.0 Floor Dashboard - Andon Resolution Screen
 * 
 * This screen allows engineers to view and resolve
 * Andon events that require technical attention.
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

const AndonResolutionScreen: React.FC = () => {
  const { canManageAndon, canViewDashboard } = usePermissions();
  const [refreshing, setRefreshing] = useState(false);
  const [andonEvents, setAndonEvents] = useState([]);

  const onRefresh = async () => {
    setRefreshing(true);
    // TODO: Fetch Andon events from API
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
        <Text style={styles.title}>Andon Resolution</Text>
        <Text style={styles.subtitle}>Resolve Andon events requiring technical attention</Text>
      </View>

      {/* Active Events */}
      <Card style={styles.sectionCard}>
        <Text style={styles.sectionTitle}>Active Events</Text>
        
        <View style={styles.eventsList}>
          {andonEvents.length > 0 ? (
            andonEvents.map((event, index) => (
              <TouchableOpacity key={index} style={styles.eventItem}>
                <Text style={styles.eventTitle}>{event.title}</Text>
                <Text style={styles.eventPriority}>{event.priority}</Text>
              </TouchableOpacity>
            ))
          ) : (
            <Text style={styles.emptyText}>No active Andon events</Text>
          )}
        </View>
      </Card>

      {/* Event Statistics */}
      <Card style={styles.sectionCard}>
        <Text style={styles.sectionTitle}>Resolution Statistics</Text>
        
        <View style={styles.statsContainer}>
          <View style={styles.statItem}>
            <Text style={styles.statValue}>0</Text>
            <Text style={styles.statLabel}>Open Events</Text>
          </View>
          <View style={styles.statItem}>
            <Text style={styles.statValue}>0</Text>
            <Text style={styles.statLabel}>Resolved Today</Text>
          </View>
          <View style={styles.statItem}>
            <Text style={styles.statValue}>0</Text>
            <Text style={styles.statLabel}>Avg. Resolution Time</Text>
          </View>
        </View>
      </Card>

      {/* Quick Actions */}
      <Card style={styles.sectionCard}>
        <Text style={styles.sectionTitle}>Quick Actions</Text>
        
        <View style={styles.actionsContainer}>
          <Button
            title="Acknowledge Event"
            onPress={() => {}}
            style={styles.actionButton}
            variant="outline"
          />
          <Button
            title="Mark as Resolved"
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
  eventsList: {
    minHeight: 200,
  },
  eventItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 12,
    paddingHorizontal: 16,
    backgroundColor: '#f8f9fa',
    borderRadius: 8,
    marginBottom: 8,
  },
  eventTitle: {
    fontSize: 16,
    color: '#333',
    flex: 1,
  },
  eventPriority: {
    fontSize: 14,
    color: '#f44336',
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

export default AndonResolutionScreen;
