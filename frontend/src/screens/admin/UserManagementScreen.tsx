/**
 * MS5.0 Floor Dashboard - User Management Screen
 * 
 * This screen allows administrators to manage users,
 * roles, and permissions.
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

const UserManagementScreen: React.FC = () => {
  const { canManageUsers, canViewDashboard } = usePermissions();
  const [refreshing, setRefreshing] = useState(false);
  const [users, setUsers] = useState([]);

  const onRefresh = async () => {
    setRefreshing(true);
    // TODO: Fetch users from API
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
        <Text style={styles.title}>User Management</Text>
        <Text style={styles.subtitle}>Manage users, roles, and permissions</Text>
      </View>

      {/* Quick Actions */}
      <Card style={styles.actionsCard}>
        <Text style={styles.sectionTitle}>Quick Actions</Text>
        
        <View style={styles.actionsContainer}>
          <Button
            title="Add User"
            onPress={() => {}}
            style={styles.actionButton}
            variant="outline"
          />
          <Button
            title="Manage Roles"
            onPress={() => {}}
            style={styles.actionButton}
            variant="outline"
          />
        </View>
      </Card>

      {/* Active Users */}
      <Card style={styles.sectionCard}>
        <Text style={styles.sectionTitle}>Active Users</Text>
        
        <View style={styles.usersList}>
          {users.length > 0 ? (
            users.map((user, index) => (
              <TouchableOpacity key={index} style={styles.userItem}>
                <Text style={styles.userName}>{user.name}</Text>
                <Text style={styles.userRole}>{user.role}</Text>
              </TouchableOpacity>
            ))
          ) : (
            <Text style={styles.emptyText}>No users available</Text>
          )}
        </View>
      </Card>

      {/* User Statistics */}
      <Card style={styles.sectionCard}>
        <Text style={styles.sectionTitle}>User Statistics</Text>
        
        <View style={styles.statsContainer}>
          <View style={styles.statItem}>
            <Text style={styles.statValue}>0</Text>
            <Text style={styles.statLabel}>Total Users</Text>
          </View>
          <View style={styles.statItem}>
            <Text style={styles.statValue}>0</Text>
            <Text style={styles.statLabel}>Active Users</Text>
          </View>
          <View style={styles.statItem}>
            <Text style={styles.statValue}>0</Text>
            <Text style={styles.statLabel}>Online Now</Text>
          </View>
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
  usersList: {
    minHeight: 200,
  },
  userItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 12,
    paddingHorizontal: 16,
    backgroundColor: '#f8f9fa',
    borderRadius: 8,
    marginBottom: 8,
  },
  userName: {
    fontSize: 16,
    color: '#333',
    flex: 1,
  },
  userRole: {
    fontSize: 14,
    color: '#666',
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
});

export default UserManagementScreen;
