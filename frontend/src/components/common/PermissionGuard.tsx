/**
 * MS5.0 Floor Dashboard - Permission Guard Component
 * 
 * This component provides permission-based access control for screens
 * and features, hiding or disabling content based on user permissions.
 */

import React from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { useSelector } from 'react-redux';
import { RootState } from '../../store';
import { UserRole, Permission } from '../../config/constants';
import { checkPermission, checkAnyPermission, checkAllPermissions, checkRole, checkAnyRole } from '../../services/permissions';

interface PermissionGuardProps {
  children: React.ReactNode;
  permission?: Permission;
  permissions?: Permission[];
  requireAll?: boolean;
  role?: UserRole;
  roles?: UserRole[];
  requireAnyRole?: boolean;
  fallback?: React.ReactNode;
  showFallback?: boolean;
  disabled?: boolean;
  onUnauthorized?: () => void;
}

const PermissionGuard: React.FC<PermissionGuardProps> = ({
  children,
  permission,
  permissions,
  requireAll = false,
  role,
  roles,
  requireAnyRole = false,
  fallback,
  showFallback = true,
  disabled = false,
  onUnauthorized,
}) => {
  const state = useSelector((state: RootState) => state);

  // Check if user is authenticated
  if (!state.auth.isAuthenticated || !state.auth.user) {
    return showFallback ? (
      <View style={styles.unauthorizedContainer}>
        <Text style={styles.unauthorizedText}>Please log in to access this feature.</Text>
      </View>
    ) : null;
  }

  let hasAccess = true;

  // Check permission-based access
  if (permission) {
    hasAccess = hasAccess && checkPermission(state, permission);
  }

  if (permissions && permissions.length > 0) {
    if (requireAll) {
      hasAccess = hasAccess && checkAllPermissions(state, permissions);
    } else {
      hasAccess = hasAccess && checkAnyPermission(state, permissions);
    }
  }

  // Check role-based access
  if (role) {
    hasAccess = hasAccess && checkRole(state, role);
  }

  if (roles && roles.length > 0) {
    if (requireAnyRole) {
      hasAccess = hasAccess && checkAnyRole(state, roles);
    } else {
      hasAccess = hasAccess && checkAllPermissions(state, permissions || []);
    }
  }

  // Handle unauthorized access
  if (!hasAccess) {
    if (onUnauthorized) {
      onUnauthorized();
    }

    if (showFallback) {
      return fallback || (
        <View style={styles.unauthorizedContainer}>
          <Text style={styles.unauthorizedText}>
            You don't have permission to access this feature.
          </Text>
        </View>
      );
    }

    return null;
  }

  // Render children with optional disabled state
  if (disabled) {
    return (
      <View style={styles.disabledContainer}>
        {children}
      </View>
    );
  }

  return <>{children}</>;
};

const styles = StyleSheet.create({
  unauthorizedContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
    backgroundColor: '#f5f5f5',
  },
  unauthorizedText: {
    fontSize: 16,
    color: '#666',
    textAlign: 'center',
    marginBottom: 10,
  },
  disabledContainer: {
    opacity: 0.5,
  },
});

export default PermissionGuard;
