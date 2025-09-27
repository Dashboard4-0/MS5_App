/**
 * MS5.0 Floor Dashboard - Permissions Hook
 * 
 * This hook provides easy access to permission checking functions
 * and user role information for components.
 */

import { useSelector } from 'react-redux';
import { RootState } from '../store';
import { UserRole, Permission } from '../config/constants';
import { 
  hasPermission, 
  hasAnyPermission, 
  hasAllPermissions, 
  hasRole, 
  hasAnyRole,
  getRolePermissions,
  getAccessibleScreens,
  getNavigationPermissions
} from '../services/permissions';

export const usePermissions = () => {
  const state = useSelector((state: RootState) => state);
  const userRole = state.auth.user?.role;
  const isAuthenticated = state.auth.isAuthenticated;

  // Permission checking functions
  const checkPermission = (permission: Permission): boolean => {
    if (!userRole) return false;
    return hasPermission(userRole, permission);
  };

  const checkAnyPermission = (permissions: Permission[]): boolean => {
    if (!userRole) return false;
    return hasAnyPermission(userRole, permissions);
  };

  const checkAllPermissions = (permissions: Permission[]): boolean => {
    if (!userRole) return false;
    return hasAllPermissions(userRole, permissions);
  };

  // Role checking functions
  const checkRole = (role: UserRole): boolean => {
    if (!userRole) return false;
    return hasRole(userRole, role);
  };

  const checkAnyRole = (roles: UserRole[]): boolean => {
    if (!userRole) return false;
    return hasAnyRole(userRole, roles);
  };

  // Get user permissions
  const getUserPermissions = (): Permission[] => {
    if (!userRole) return [];
    return getRolePermissions(userRole);
  };

  // Get accessible screens
  const getAccessibleScreensForUser = (): string[] => {
    if (!userRole) return [];
    return getAccessibleScreens(userRole);
  };

  // Get navigation permissions
  const getNavigationPermissionsForUser = () => {
    if (!userRole) return {
      canViewDashboard: false,
      canManageProduction: false,
      canManageJobs: false,
      canManageEquipment: false,
      canManageAndon: false,
      canViewReports: false,
      canGenerateReports: false,
      canManageUsers: false,
      canManageSystem: false,
    };
    return getNavigationPermissions(userRole);
  };

  // Check if screen is accessible
  const isScreenAccessible = (screenName: string): boolean => {
    if (!userRole) return false;
    const accessibleScreens = getAccessibleScreens(userRole);
    return accessibleScreens.includes(screenName);
  };

  // Common permission checks
  const canViewDashboard = checkPermission(Permission.DASHBOARD_READ);
  const canManageProduction = checkAnyPermission([
    Permission.PRODUCTION_READ,
    Permission.PRODUCTION_WRITE
  ]);
  const canManageJobs = checkAnyPermission([
    Permission.JOB_READ,
    Permission.JOB_WRITE,
    Permission.JOB_ASSIGN
  ]);
  const canManageEquipment = checkAnyPermission([
    Permission.EQUIPMENT_READ,
    Permission.EQUIPMENT_WRITE,
    Permission.EQUIPMENT_MAINTENANCE
  ]);
  const canManageAndon = checkAnyPermission([
    Permission.ANDON_READ,
    Permission.ANDON_CREATE,
    Permission.ANDON_ACKNOWLEDGE,
    Permission.ANDON_RESOLVE
  ]);
  const canViewReports = checkPermission(Permission.REPORT_READ);
  const canGenerateReports = checkPermission(Permission.REPORT_GENERATE);
  const canManageUsers = checkAnyPermission([
    Permission.USER_READ,
    Permission.USER_WRITE
  ]);
  const canManageSystem = checkAnyPermission([
    Permission.SYSTEM_CONFIG,
    Permission.SYSTEM_MONITOR
  ]);

  return {
    // User info
    userRole,
    isAuthenticated,
    
    // Permission checking functions
    checkPermission,
    checkAnyPermission,
    checkAllPermissions,
    
    // Role checking functions
    checkRole,
    checkAnyRole,
    
    // Data access
    getUserPermissions,
    getAccessibleScreensForUser,
    getNavigationPermissionsForUser,
    isScreenAccessible,
    
    // Common permission checks
    canViewDashboard,
    canManageProduction,
    canManageJobs,
    canManageEquipment,
    canManageAndon,
    canViewReports,
    canGenerateReports,
    canManageUsers,
    canManageSystem,
  };
};

export default usePermissions;
