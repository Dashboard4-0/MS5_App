/**
 * MS5.0 Floor Dashboard - Checklist Screen
 * 
 * This screen allows operators to view and complete
 * pre-start checklists for their assigned jobs.
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

const ChecklistScreen: React.FC = () => {
  const { canViewDashboard } = usePermissions();
  const [refreshing, setRefreshing] = useState(false);
  const [checklists, setChecklists] = useState([]);

  const onRefresh = async () => {
    setRefreshing(true);
    // TODO: Fetch checklists from API
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
        <Text style={styles.title}>Pre-start Checklists</Text>
        <Text style={styles.subtitle}>Complete checklists for your assigned jobs</Text>
      </View>

      <Card style={styles.sectionCard}>
        <Text style={styles.sectionTitle}>Available Checklists</Text>
        
        <View style={styles.checklistList}>
          {checklists.length > 0 ? (
            checklists.map((checklist, index) => (
              <TouchableOpacity key={index} style={styles.checklistItem}>
                <Text style={styles.checklistTitle}>{checklist.name}</Text>
                <Text style={styles.checklistStatus}>{checklist.status}</Text>
              </TouchableOpacity>
            ))
          ) : (
            <Text style={styles.emptyText}>No checklists available</Text>
          )}
        </View>
      </Card>

      <Card style={styles.sectionCard}>
        <Text style={styles.sectionTitle}>Quick Actions</Text>
        
        <View style={styles.actionsContainer}>
          <Button
            title="Start New Checklist"
            onPress={() => {}}
            style={styles.actionButton}
            variant="outline"
          />
          <Button
            title="View Completed"
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
  checklistList: {
    minHeight: 200,
  },
  checklistItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 12,
    paddingHorizontal: 16,
    backgroundColor: '#f8f9fa',
    borderRadius: 8,
    marginBottom: 8,
  },
  checklistTitle: {
    fontSize: 16,
    color: '#333',
    flex: 1,
  },
  checklistStatus: {
    fontSize: 14,
    color: '#666',
  },
  emptyText: {
    fontSize: 16,
    color: '#999',
    textAlign: 'center',
    marginTop: 50,
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

export default ChecklistScreen;
