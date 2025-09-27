/**
 * MS5.0 Floor Dashboard - Andon Screen
 * 
 * This screen allows operators to create and manage
 * Andon events for production issues.
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

const AndonScreen: React.FC = () => {
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

  const handleCreateAndon = () => {
    // TODO: Navigate to Andon creation screen
    console.log('Create Andon event');
  };

  return (
    <ScrollView
      style={styles.container}
      refreshControl={
        <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
      }
    >
      <View style={styles.header}>
        <Text style={styles.title}>Andon System</Text>
        <Text style={styles.subtitle}>Report and manage production issues</Text>
      </View>

      {/* Quick Andon Button */}
      {canManageAndon && (
        <Card style={styles.andonButtonCard}>
          <Button
            title="START ANDON"
            onPress={handleCreateAndon}
            style={styles.andonButton}
            variant="primary"
          />
          <Text style={styles.andonButtonText}>
            Press to report a production issue
          </Text>
        </Card>
      )}

      {/* Active Andon Events */}
      <Card style={styles.sectionCard}>
        <Text style={styles.sectionTitle}>Active Events</Text>
        
        <View style={styles.eventsList}>
          {andonEvents.length > 0 ? (
            andonEvents.map((event, index) => (
              <TouchableOpacity key={index} style={styles.eventItem}>
                <View style={styles.eventHeader}>
                  <Text style={styles.eventTitle}>{event.title}</Text>
                  <Text style={[styles.eventPriority, { color: event.priorityColor }]}>
                    {event.priority}
                  </Text>
                </View>
                <Text style={styles.eventDescription}>{event.description}</Text>
                <Text style={styles.eventTime}>{event.time}</Text>
              </TouchableOpacity>
            ))
          ) : (
            <Text style={styles.emptyText}>No active Andon events</Text>
          )}
        </View>
      </Card>

      {/* Andon History */}
      <Card style={styles.sectionCard}>
        <Text style={styles.sectionTitle}>Recent Events</Text>
        
        <View style={styles.historyList}>
          <Text style={styles.emptyText}>Event history coming soon</Text>
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
  andonButtonCard: {
    margin: 20,
    marginTop: 10,
    padding: 20,
    alignItems: 'center',
  },
  andonButton: {
    width: '100%',
    marginBottom: 12,
  },
  andonButtonText: {
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
  eventsList: {
    minHeight: 200,
  },
  eventItem: {
    backgroundColor: '#f8f9fa',
    borderRadius: 8,
    padding: 16,
    marginBottom: 12,
  },
  eventHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  eventTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#333',
    flex: 1,
  },
  eventPriority: {
    fontSize: 14,
    fontWeight: '500',
  },
  eventDescription: {
    fontSize: 14,
    color: '#666',
    marginBottom: 8,
  },
  eventTime: {
    fontSize: 12,
    color: '#999',
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
});

export default AndonScreen;
