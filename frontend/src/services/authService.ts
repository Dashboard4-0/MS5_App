/**
 * MS5.0 Floor Dashboard - Authentication Service
 * 
 * This service handles authentication-related operations including login,
 * logout, token management, and user profile management.
 */

import { apiService } from './api';

// Types
export interface LoginCredentials {
  username: string;
  password: string;
}

export interface LoginResponse {
  access_token: string;
  refresh_token: string;
  token_type: string;
  expires_in: number;
  user: User;
}

export interface User {
  id: string;
  username: string;
  email: string;
  first_name?: string;
  last_name?: string;
  employee_id?: string;
  role: string;
  permissions: string[];
  department?: string;
  shift?: string;
  skills?: string[];
  certifications?: string[];
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface RefreshTokenResponse {
  access_token: string;
  refresh_token: string;
  token_type: string;
  expires_in: number;
}

export interface PasswordChangeData {
  current_password: string;
  new_password: string;
}

/**
 * Authentication Service Class
 * 
 * Provides methods for user authentication, token management, and profile operations.
 * All methods are designed to work seamlessly with the Redux store and handle errors gracefully.
 */
class AuthService {
  /**
   * Authenticate user with username and password
   * 
   * @param credentials - User login credentials
   * @returns Promise resolving to login response with tokens and user data
   */
  async login(credentials: LoginCredentials) {
    return apiService.login(credentials);
  }

  /**
   * Logout current user
   * 
   * @returns Promise resolving when logout is complete
   */
  async logout() {
    return apiService.logout();
  }

  /**
   * Refresh authentication token
   * 
   * @param refreshToken - Current refresh token
   * @returns Promise resolving to new token data
   */
  async refreshToken(refreshToken: string) {
    return apiService.refreshToken(refreshToken);
  }

  /**
   * Get current user profile
   * 
   * @returns Promise resolving to user profile data
   */
  async getCurrentUser() {
    return apiService.getCurrentUser();
  }

  /**
   * Update user profile
   * 
   * @param profileData - Profile data to update
   * @returns Promise resolving to updated user profile
   */
  async updateProfile(profileData: Partial<User>) {
    return apiService.updateProfile(profileData);
  }

  /**
   * Change user password
   * 
   * @param passwordData - Current and new password
   * @returns Promise resolving when password change is complete
   */
  async changePassword(passwordData: PasswordChangeData) {
    return apiService.changePassword(passwordData);
  }

  /**
   * Check if user has specific permission
   * 
   * @param permission - Permission to check
   * @param userPermissions - User's permissions array
   * @returns Boolean indicating if user has permission
   */
  hasPermission(permission: string, userPermissions: string[]): boolean {
    return userPermissions.includes(permission);
  }

  /**
   * Check if user has any of the specified roles
   * 
   * @param roles - Array of roles to check
   * @param userRole - User's current role
   * @returns Boolean indicating if user has any of the roles
   */
  hasAnyRole(roles: string[], userRole: string): boolean {
    return roles.includes(userRole);
  }

  /**
   * Check if user has specific role
   * 
   * @param role - Role to check
   * @param userRole - User's current role
   * @returns Boolean indicating if user has the role
   */
  hasRole(role: string, userRole: string): boolean {
    return userRole === role;
  }

  /**
   * Validate token expiration
   * 
   * @param expiresAt - Token expiration timestamp
   * @returns Boolean indicating if token is still valid
   */
  isTokenValid(expiresAt: string): boolean {
    const expirationTime = new Date(expiresAt).getTime();
    const currentTime = Date.now();
    return currentTime < expirationTime;
  }

  /**
   * Get time until token expires
   * 
   * @param expiresAt - Token expiration timestamp
   * @returns Number of milliseconds until expiration
   */
  getTimeUntilExpiration(expiresAt: string): number {
    const expirationTime = new Date(expiresAt).getTime();
    const currentTime = Date.now();
    return Math.max(0, expirationTime - currentTime);
  }

  /**
   * Format user display name
   * 
   * @param user - User object
   * @returns Formatted display name
   */
  getDisplayName(user: User): string {
    if (user.first_name && user.last_name) {
      return `${user.first_name} ${user.last_name}`;
    }
    return user.username;
  }

  /**
   * Get user initials for avatar
   * 
   * @param user - User object
   * @returns User initials
   */
  getInitials(user: User): string {
    if (user.first_name && user.last_name) {
      return `${user.first_name[0]}${user.last_name[0]}`.toUpperCase();
    }
    return user.username.substring(0, 2).toUpperCase();
  }
}

// Export singleton instance
export const authService = new AuthService();
export default authService;
