/**
 * MS5.0 Floor Dashboard - Profile Screen
 * 
 * This screen displays user profile information and allows
 * users to update their profile settings.
 */

import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  Alert,
} from 'react-native';
import { useSelector, useDispatch } from 'react-redux';
import { RootState, AppDispatch } from '../../store';
import { logout } from '../../store/slices/authSlice';
import Card from '../../components/common/Card';
import Button from '../../components/common/Button';
import { USER_ROLES } from '../../config/constants';

const ProfileScreen: React.FC = () => {
  const dispatch = useDispatch<AppDispatch>();
  const { user } = useSelector((state: RootState) => state.auth);

  const handleLogout = () => {
    Alert.alert(
      'Logout',
      'Are you sure you want to logout?',
      [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Logout', style: 'destructive', onPress: () => dispatch(logout()) },
      ]
    );
  };

  const handleChangePassword = () => {
    Alert.alert('Change Password', 'Password change functionality coming soon');
  };

  const handleEditProfile = () => {
    Alert.alert('Edit Profile', 'Profile editing functionality coming soon');
  };

  if (!user) {
    return (
      <View style={styles.container}>
        <Text>No user data available</Text>
      </View>
    );
  }

  const getRoleDisplayName = (role: string) => {
    switch (role) {
      case USER_ROLES.ADMIN:
        return 'Administrator';
      case USER_ROLES.PRODUCTION_MANAGER:
        return 'Production Manager';
      case USER_ROLES.SHIFT_MANAGER:
        return 'Shift Manager';
      case USER_ROLES.ENGINEER:
        return 'Engineer';
      case USER_ROLES.OPERATOR:
        return 'Operator';
      case USER_ROLES.MAINTENANCE:
        return 'Maintenance Technician';
      case USER_ROLES.QUALITY:
        return 'Quality Control';
      case USER_ROLES.VIEWER:
        return 'Viewer';
      default:
        return role;
    }
  };

  return (
    <ScrollView style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>Profile</Text>
      </View>

      <Card style={styles.profileCard}>
        <View style={styles.avatarContainer}>
          <View style={styles.avatar}>
            <Text style={styles.avatarText}>
              {user.firstName?.[0] || user.username[0].toUpperCase()}
            </Text>
          </View>
        </View>

        <View style={styles.userInfo}>
          <Text style={styles.userName}>
            {user.firstName && user.lastName 
              ? `${user.firstName} ${user.lastName}`
              : user.username
            }
          </Text>
          <Text style={styles.userRole}>
            {getRoleDisplayName(user.role)}
          </Text>
          {user.employeeId && (
            <Text style={styles.employeeId}>
              Employee ID: {user.employeeId}
            </Text>
          )}
        </View>
      </Card>

      <Card style={styles.detailsCard}>
        <Text style={styles.sectionTitle}>Account Details</Text>
        
        <View style={styles.detailRow}>
          <Text style={styles.detailLabel}>Username</Text>
          <Text style={styles.detailValue}>{user.username}</Text>
        </View>

        <View style={styles.detailRow}>
          <Text style={styles.detailLabel}>Email</Text>
          <Text style={styles.detailValue}>{user.email || 'Not provided'}</Text>
        </View>

        <View style={styles.detailRow}>
          <Text style={styles.detailLabel}>Role</Text>
          <Text style={styles.detailValue}>{getRoleDisplayName(user.role)}</Text>
        </View>

        {user.department && (
          <View style={styles.detailRow}>
            <Text style={styles.detailLabel}>Department</Text>
            <Text style={styles.detailValue}>{user.department}</Text>
          </View>
        )}

        {user.shift && (
          <View style={styles.detailRow}>
            <Text style={styles.detailLabel}>Shift</Text>
            <Text style={styles.detailValue}>{user.shift}</Text>
          </View>
        )}
      </Card>

      <Card style={styles.actionsCard}>
        <Text style={styles.sectionTitle}>Actions</Text>
        
        <TouchableOpacity style={styles.actionButton} onPress={handleEditProfile}>
          <Text style={styles.actionButtonText}>Edit Profile</Text>
        </TouchableOpacity>

        <TouchableOpacity style={styles.actionButton} onPress={handleChangePassword}>
          <Text style={styles.actionButtonText}>Change Password</Text>
        </TouchableOpacity>
      </Card>

      <Button
        title="Logout"
        onPress={handleLogout}
        style={styles.logoutButton}
        variant="outline"
      />
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
  },
  profileCard: {
    margin: 20,
    marginBottom: 10,
    padding: 20,
    alignItems: 'center',
  },
  avatarContainer: {
    marginBottom: 16,
  },
  avatar: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: '#2196F3',
    justifyContent: 'center',
    alignItems: 'center',
  },
  avatarText: {
    fontSize: 32,
    fontWeight: 'bold',
    color: '#fff',
  },
  userInfo: {
    alignItems: 'center',
  },
  userName: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 4,
  },
  userRole: {
    fontSize: 16,
    color: '#666',
    marginBottom: 4,
  },
  employeeId: {
    fontSize: 14,
    color: '#999',
  },
  detailsCard: {
    margin: 20,
    marginTop: 10,
    marginBottom: 10,
    padding: 20,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 16,
  },
  detailRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 8,
    borderBottomWidth: 1,
    borderBottomColor: '#f0f0f0',
  },
  detailLabel: {
    fontSize: 16,
    color: '#666',
    flex: 1,
  },
  detailValue: {
    fontSize: 16,
    color: '#333',
    fontWeight: '500',
    flex: 1,
    textAlign: 'right',
  },
  actionsCard: {
    margin: 20,
    marginTop: 10,
    marginBottom: 10,
    padding: 20,
  },
  actionButton: {
    paddingVertical: 12,
    paddingHorizontal: 16,
    backgroundColor: '#f8f9fa',
    borderRadius: 8,
    marginBottom: 8,
  },
  actionButtonText: {
    fontSize: 16,
    color: '#2196F3',
    textAlign: 'center',
  },
  logoutButton: {
    margin: 20,
    marginTop: 10,
  },
});

export default ProfileScreen;
