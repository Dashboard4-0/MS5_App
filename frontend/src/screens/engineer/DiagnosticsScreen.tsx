/**
 * MS5.0 Floor Dashboard - Diagnostics Screen
 * 
 * This screen allows engineers to run diagnostics
 * and view equipment diagnostic information.
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

const DiagnosticsScreen: React.FC = () => {
  const { canManageEquipment, canViewDashboard } = usePermissions();
  const [refreshing, setRefreshing] = useState(false);
  const [diagnostics, setDiagnostics] = useState([]);

  const onRefresh = async () => {
    setRefreshing(true);
    // TODO: Fetch diagnostics from API
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
        <Text style={styles.title}>Diagnostics</Text>
        <Text style={styles.subtitle}>Run equipment diagnostics and view results</Text>
      </View>

      {/* Diagnostic Tools */}
      <Card style={styles.sectionCard}>
        <Text style={styles.sectionTitle}>Diagnostic Tools</Text>
        
        <View style={styles.toolsList}>
          <TouchableOpacity style={styles.toolItem}>
            <Text style={styles.toolTitle}>System Health Check</Text>
            <Text style={styles.toolDescription}>Run comprehensive system diagnostics</Text>
          </TouchableOpacity>
          
          <TouchableOpacity style={styles.toolItem}>
            <Text style={styles.toolTitle}>Equipment Test</Text>
            <Text style={styles.toolDescription}>Test individual equipment components</Text>
          </TouchableOpacity>
          
          <TouchableOpacity style={styles.toolItem}>
            <Text style={styles.toolTitle}>Network Diagnostics</Text>
            <Text style={styles.toolDescription}>Check network connectivity and performance</Text>
          </TouchableOpacity>
        </View>
      </Card>

      {/* Recent Diagnostics */}
      <Card style={styles.sectionCard}>
        <Text style={styles.sectionTitle}>Recent Diagnostics</Text>
        
        <View style={styles.diagnosticsList}>
          {diagnostics.length > 0 ? (
            diagnostics.map((diagnostic, index) => (
              <TouchableOpacity key={index} style={styles.diagnosticItem}>
                <Text style={styles.diagnosticTitle}>{diagnostic.title}</Text>
                <Text style={styles.diagnosticStatus}>{diagnostic.status}</Text>
              </TouchableOpacity>
            ))
          ) : (
            <Text style={styles.emptyText}>No diagnostics available</Text>
          )}
        </View>
      </Card>

      {/* Quick Actions */}
      <Card style={styles.sectionCard}>
        <Text style={styles.sectionTitle}>Quick Actions</Text>
        
        <View style={styles.actionsContainer}>
          <Button
            title="Run Full Diagnostics"
            onPress={() => {}}
            style={styles.actionButton}
            variant="outline"
          />
          <Button
            title="Export Results"
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
  toolsList: {
    minHeight: 200,
  },
  toolItem: {
    paddingVertical: 16,
    paddingHorizontal: 16,
    backgroundColor: '#f8f9fa',
    borderRadius: 8,
    marginBottom: 12,
  },
  toolTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 4,
  },
  toolDescription: {
    fontSize: 14,
    color: '#666',
  },
  diagnosticsList: {
    minHeight: 200,
  },
  diagnosticItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 12,
    paddingHorizontal: 16,
    backgroundColor: '#f8f9fa',
    borderRadius: 8,
    marginBottom: 8,
  },
  diagnosticTitle: {
    fontSize: 16,
    color: '#333',
    flex: 1,
  },
  diagnosticStatus: {
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

export default DiagnosticsScreen;
