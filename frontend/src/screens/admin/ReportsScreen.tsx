/**
 * MS5.0 Floor Dashboard - Admin Reports Screen
 * 
 * This screen allows administrators to view and generate
 * system-wide reports and analytics.
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

const ReportsScreen: React.FC = () => {
  const { canViewReports, canGenerateReports, canViewDashboard } = usePermissions();
  const [refreshing, setRefreshing] = useState(false);
  const [reports, setReports] = useState([]);

  const onRefresh = async () => {
    setRefreshing(true);
    // TODO: Fetch reports from API
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
        <Text style={styles.title}>System Reports</Text>
        <Text style={styles.subtitle}>View and generate system-wide reports</Text>
      </View>

      {/* Quick Actions */}
      {canGenerateReports && (
        <Card style={styles.actionsCard}>
          <Text style={styles.sectionTitle}>Quick Actions</Text>
          
          <View style={styles.actionsContainer}>
            <Button
              title="Generate Report"
              onPress={() => {}}
              style={styles.actionButton}
              variant="outline"
            />
            <Button
              title="Export Data"
              onPress={() => {}}
              style={styles.actionButton}
              variant="outline"
            />
          </View>
        </Card>
      )}

      {/* System Reports */}
      <Card style={styles.sectionCard}>
        <Text style={styles.sectionTitle}>System Reports</Text>
        
        <View style={styles.reportsList}>
          {reports.length > 0 ? (
            reports.map((report, index) => (
              <TouchableOpacity key={index} style={styles.reportItem}>
                <Text style={styles.reportTitle}>{report.title}</Text>
                <Text style={styles.reportDate}>{report.date}</Text>
              </TouchableOpacity>
            ))
          ) : (
            <Text style={styles.emptyText}>No reports available</Text>
          )}
        </View>
      </Card>

      {/* Report Templates */}
      <Card style={styles.sectionCard}>
        <Text style={styles.sectionTitle}>Report Templates</Text>
        
        <View style={styles.templatesList}>
          <TouchableOpacity style={styles.templateItem}>
            <Text style={styles.templateTitle}>System Performance Report</Text>
            <Text style={styles.templateDescription}>Overall system performance metrics</Text>
          </TouchableOpacity>
          
          <TouchableOpacity style={styles.templateItem}>
            <Text style={styles.templateTitle}>User Activity Report</Text>
            <Text style={styles.templateDescription}>User activity and engagement metrics</Text>
          </TouchableOpacity>
          
          <TouchableOpacity style={styles.templateItem}>
            <Text style={styles.templateTitle}>Security Audit Report</Text>
            <Text style={styles.templateDescription}>Security events and audit trail</Text>
          </TouchableOpacity>
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
  reportsList: {
    minHeight: 200,
  },
  reportItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 12,
    paddingHorizontal: 16,
    backgroundColor: '#f8f9fa',
    borderRadius: 8,
    marginBottom: 8,
  },
  reportTitle: {
    fontSize: 16,
    color: '#333',
    flex: 1,
  },
  reportDate: {
    fontSize: 14,
    color: '#666',
  },
  emptyText: {
    fontSize: 16,
    color: '#999',
    textAlign: 'center',
    marginTop: 50,
  },
  templatesList: {
    minHeight: 200,
  },
  templateItem: {
    paddingVertical: 16,
    paddingHorizontal: 16,
    backgroundColor: '#f8f9fa',
    borderRadius: 8,
    marginBottom: 12,
  },
  templateTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 4,
  },
  templateDescription: {
    fontSize: 14,
    color: '#666',
  },
});

export default ReportsScreen;
