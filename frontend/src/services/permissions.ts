/**
 * MS5.0 Floor Dashboard - Permission Service
 * 
 * This service handles permission checking and role-based access control
 * on the frontend, providing utilities for checking user permissions
 * and managing access to different features.
 */

import { UserRole, Permission } from '../config/constants';
import { RootState } from '../store';

// Role-Permission mapping (matches backend)
const ROLE_PERMISSIONS: Record<UserRole, Permission[]> = {
  [UserRole.ADMIN]: [
    // Admin has all permissions
    ...Object.values(Permission),
  ],
  
  [UserRole.PRODUCTION_MANAGER]: [
    Permission.PRODUCTION_READ,
    Permission.PRODUCTION_WRITE,
    Permission.PRODUCTION_DELETE,
    Permission.LINE_READ,
    Permission.LINE_WRITE,
    Permission.SCHEDULE_READ,
    Permission.SCHEDULE_WRITE,
    Permission.SCHEDULE_DELETE,
    Permission.JOB_READ,
    Permission.JOB_WRITE,
    Permission.JOB_ASSIGN,
    Permission.OEE_READ,
    Permission.OEE_CALCULATE,
    Permission.ANALYTICS_READ,
    Permission.ANDON_READ,
    Permission.ANDON_ACKNOWLEDGE,
    Permission.ANDON_RESOLVE,
    Permission.EQUIPMENT_READ,
    Permission.REPORT_READ,
    Permission.REPORT_GENERATE,
    Permission.DASHBOARD_READ,
    Permission.DASHBOARD_WRITE,
    Permission.QUALITY_READ,
    Permission.QUALITY_WRITE,
    Permission.QUALITY_APPROVE,
    Permission.MAINTENANCE_READ,
    Permission.MAINTENANCE_WRITE,
    Permission.MAINTENANCE_SCHEDULE,
  ],
  
  [UserRole.SHIFT_MANAGER]: [
    Permission.PRODUCTION_READ,
    Permission.LINE_READ,
    Permission.SCHEDULE_READ,
    Permission.SCHEDULE_WRITE,
    Permission.JOB_READ,
    Permission.JOB_WRITE,
    Permission.JOB_ASSIGN,
    Permission.OEE_READ,
    Permission.ANALYTICS_READ,
    Permission.ANDON_READ,
    Permission.ANDON_ACKNOWLEDGE,
    Permission.ANDON_RESOLVE,
    Permission.EQUIPMENT_READ,
    Permission.REPORT_READ,
    Permission.REPORT_GENERATE,
    Permission.DASHBOARD_READ,
    Permission.DASHBOARD_WRITE,
    Permission.QUALITY_READ,
    Permission.QUALITY_WRITE,
    Permission.MAINTENANCE_READ,
  ],
  
  [UserRole.ENGINEER]: [
    Permission.PRODUCTION_READ,
    Permission.LINE_READ,
    Permission.JOB_READ,
    Permission.OEE_READ,
    Permission.OEE_CALCULATE,
    Permission.ANALYTICS_READ,
    Permission.ANDON_READ,
    Permission.ANDON_ACKNOWLEDGE,
    Permission.ANDON_RESOLVE,
    Permission.EQUIPMENT_READ,
    Permission.EQUIPMENT_WRITE,
    Permission.EQUIPMENT_MAINTENANCE,
    Permission.REPORT_READ,
    Permission.REPORT_GENERATE,
    Permission.DASHBOARD_READ,
    Permission.QUALITY_READ,
    Permission.QUALITY_WRITE,
    Permission.MAINTENANCE_READ,
    Permission.MAINTENANCE_WRITE,
    Permission.MAINTENANCE_SCHEDULE,
  ],
  
  [UserRole.OPERATOR]: [
    Permission.PRODUCTION_READ,
    Permission.LINE_READ,
    Permission.JOB_READ,
    Permission.JOB_ACCEPT,
    Permission.JOB_COMPLETE,
    Permission.OEE_READ,
    Permission.ANDON_READ,
    Permission.ANDON_CREATE,
    Permission.EQUIPMENT_READ,
    Permission.DASHBOARD_READ,
    Permission.QUALITY_READ,
    Permission.QUALITY_WRITE,
    Permission.MAINTENANCE_READ,
  ],
  
  [UserRole.MAINTENANCE]: [
    Permission.PRODUCTION_READ,
    Permission.LINE_READ,
    Permission.JOB_READ,
    Permission.OEE_READ,
    Permission.ANDON_READ,
    Permission.ANDON_ACKNOWLEDGE,
    Permission.ANDON_RESOLVE,
    Permission.EQUIPMENT_READ,
    Permission.EQUIPMENT_WRITE,
    Permission.EQUIPMENT_MAINTENANCE,
    Permission.DASHBOARD_READ,
    Permission.MAINTENANCE_READ,
    Permission.MAINTENANCE_WRITE,
    Permission.MAINTENANCE_SCHEDULE,
  ],
  
  [UserRole.QUALITY]: [
    Permission.PRODUCTION_READ,
    Permission.LINE_READ,
    Permission.JOB_READ,
    Permission.OEE_READ,
    Permission.ANDON_READ,
    Permission.ANDON_CREATE,
    Permission.EQUIPMENT_READ,
    Permission.REPORT_READ,
    Permission.REPORT_GENERATE,
    Permission.DASHBOARD_READ,
    Permission.QUALITY_READ,
    Permission.QUALITY_WRITE,
    Permission.QUALITY_APPROVE,
    Permission.MAINTENANCE_READ,
  ],
  
  [UserRole.VIEWER]: [
    Permission.PRODUCTION_READ,
    Permission.LINE_READ,
    Permission.JOB_READ,
    Permission.OEE_READ,
    Permission.ANALYTICS_READ,
    Permission.ANDON_READ,
    Permission.EQUIPMENT_READ,
    Permission.REPORT_READ,
    Permission.DASHBOARD_READ,
    Permission.QUALITY_READ,
    Permission.MAINTENANCE_READ,
  ],
};

/**
 * Get permissions for a specific role
 */
export const getRolePermissions = (role: UserRole): Permission[] => {
  return ROLE_PERMISSIONS[role] || [];
};

/**
 * Check if a user has a specific permission
 */
export const hasPermission = (userRole: UserRole, permission: Permission): boolean => {
  const rolePermissions = getRolePermissions(userRole);
  return rolePermissions.includes(permission);
};

/**
 * Check if a user has any of the specified permissions
 */
export const hasAnyPermission = (userRole: UserRole, permissions: Permission[]): boolean => {
  const rolePermissions = getRolePermissions(userRole);
  return permissions.some(permission => rolePermissions.includes(permission));
};

/**
 * Check if a user has all of the specified permissions
 */
export const hasAllPermissions = (userRole: UserRole, permissions: Permission[]): boolean => {
  const rolePermissions = getRolePermissions(userRole);
  return permissions.every(permission => rolePermissions.includes(permission));
};

/**
 * Check if a user has a specific role
 */
export const hasRole = (userRole: UserRole, role: UserRole): boolean => {
  return userRole === role;
};

/**
 * Check if a user has any of the specified roles
 */
export const hasAnyRole = (userRole: UserRole, roles: UserRole[]): boolean => {
  return roles.includes(userRole);
};

/**
 * Get user permissions from Redux state
 */
export const getUserPermissions = (state: RootState): Permission[] => {
  const userRole = state.auth.user?.role;
  if (!userRole) return [];
  return getRolePermissions(userRole);
};

/**
 * Check if current user has permission (using Redux state)
 */
export const checkPermission = (state: RootState, permission: Permission): boolean => {
  const userRole = state.auth.user?.role;
  if (!userRole) return false;
  return hasPermission(userRole, permission);
};

/**
 * Check if current user has any of the specified permissions
 */
export const checkAnyPermission = (state: RootState, permissions: Permission[]): boolean => {
  const userRole = state.auth.user?.role;
  if (!userRole) return false;
  return hasAnyPermission(userRole, permissions);
};

/**
 * Check if current user has all of the specified permissions
 */
export const checkAllPermissions = (state: RootState, permissions: Permission[]): boolean => {
  const userRole = state.auth.user?.role;
  if (!userRole) return false;
  return hasAllPermissions(userRole, permissions);
};

/**
 * Check if current user has a specific role
 */
export const checkRole = (state: RootState, role: UserRole): boolean => {
  const userRole = state.auth.user?.role;
  if (!userRole) return false;
  return hasRole(userRole, role);
};

/**
 * Check if current user has any of the specified roles
 */
export const checkAnyRole = (state: RootState, roles: UserRole[]): boolean => {
  const userRole = state.auth.user?.role;
  if (!userRole) return false;
  return hasAnyRole(userRole, roles);
};

/**
 * Get accessible screens for a user role
 */
export const getAccessibleScreens = (userRole: UserRole): string[] => {
  const screens: string[] = [];
  
  // Common screens for all roles
  screens.push('Profile');
  
  // Role-specific screens
  switch (userRole) {
    case UserRole.ADMIN:
      screens.push(
        'SystemOverview',
        'UserManagement',
        'SystemConfiguration',
        'Analytics',
        'Reports'
      );
      break;
      
    case UserRole.PRODUCTION_MANAGER:
    case UserRole.SHIFT_MANAGER:
      screens.push(
        'ProductionOverview',
        'ScheduleManagement',
        'TeamManagement',
        'Reports',
        'AndonManagement'
      );
      break;
      
    case UserRole.ENGINEER:
    case UserRole.MAINTENANCE:
      screens.push(
        'EquipmentStatus',
        'FaultAnalysis',
        'Maintenance',
        'Diagnostics',
        'AndonResolution'
      );
      break;
      
    case UserRole.OPERATOR:
      screens.push(
        'MyJobs',
        'LineDashboard',
        'Checklist',
        'Andon'
      );
      break;
      
    case UserRole.QUALITY:
      screens.push(
        'QualityControl',
        'QualityReports',
        'Andon'
      );
      break;
      
    case UserRole.VIEWER:
      screens.push(
        'Dashboard',
        'Reports'
      );
      break;
  }
  
  return screens;
};

/**
 * Check if a screen is accessible to a user role
 */
export const isScreenAccessible = (userRole: UserRole, screenName: string): boolean => {
  const accessibleScreens = getAccessibleScreens(userRole);
  return accessibleScreens.includes(screenName);
};

/**
 * Get navigation permissions for a user role
 */
export const getNavigationPermissions = (userRole: UserRole) => {
  return {
    canViewDashboard: hasPermission(userRole, Permission.DASHBOARD_READ),
    canManageProduction: hasAnyPermission(userRole, [
      Permission.PRODUCTION_READ,
      Permission.PRODUCTION_WRITE
    ]),
    canManageJobs: hasAnyPermission(userRole, [
      Permission.JOB_READ,
      Permission.JOB_WRITE,
      Permission.JOB_ASSIGN
    ]),
    canManageEquipment: hasAnyPermission(userRole, [
      Permission.EQUIPMENT_READ,
      Permission.EQUIPMENT_WRITE,
      Permission.EQUIPMENT_MAINTENANCE
    ]),
    canManageAndon: hasAnyPermission(userRole, [
      Permission.ANDON_READ,
      Permission.ANDON_CREATE,
      Permission.ANDON_ACKNOWLEDGE,
      Permission.ANDON_RESOLVE
    ]),
    canViewReports: hasPermission(userRole, Permission.REPORT_READ),
    canGenerateReports: hasPermission(userRole, Permission.REPORT_GENERATE),
    canManageUsers: hasAnyPermission(userRole, [
      Permission.USER_READ,
      Permission.USER_WRITE
    ]),
    canManageSystem: hasAnyPermission(userRole, [
      Permission.SYSTEM_CONFIG,
      Permission.SYSTEM_MONITOR
    ]),
  };
};
