/**
 * MS5.0 Floor Dashboard - Main App Navigator
 * 
 * This component handles the main navigation structure of the application
 * with role-based navigation and authentication flow.
 */

import React, { useEffect } from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createStackNavigator } from '@react-navigation/stack';
import { useSelector, useDispatch } from 'react-redux';
import { ActivityIndicator, View, StyleSheet } from 'react-native';
import { RootState, AppDispatch } from '../store';
import { selectIsAuthenticated, selectIsLoading, selectUserRole } from '../store/slices/authSlice';
import { USER_ROLES } from '../config/constants';

// Import navigators
import AuthNavigator from './AuthNavigator';
import OperatorNavigator from './OperatorNavigator';
import ManagerNavigator from './ManagerNavigator';
import EngineerNavigator from './EngineerNavigator';
import AdminNavigator from './AdminNavigator';

// Import screens
import SplashScreen from '../screens/SplashScreen';
import OfflineScreen from '../screens/OfflineScreen';

// Types
type RootStackParamList = {
  Splash: undefined;
  Auth: undefined;
  Operator: undefined;
  Manager: undefined;
  Engineer: undefined;
  Admin: undefined;
  Offline: undefined;
};

const Stack = createStackNavigator<RootStackParamList>();

const AppNavigator: React.FC = () => {
  const dispatch = useDispatch<AppDispatch>();
  const isAuthenticated = useSelector(selectIsAuthenticated);
  const isLoading = useSelector(selectIsLoading);
  const userRole = useSelector(selectUserRole);

  // Handle app initialization
  useEffect(() => {
    // TODO: Add app initialization logic
    // - Check for stored authentication tokens
    // - Validate token expiry
    // - Initialize offline data sync
    // - Set up push notifications
  }, []);

  // Show loading screen while checking authentication
  if (isLoading) {
    return <SplashScreen />;
  }

  // Determine which navigator to show based on authentication and role
  const getNavigator = () => {
    if (!isAuthenticated) {
      return 'Auth';
    }

    switch (userRole) {
      case USER_ROLES.OPERATOR:
        return 'Operator';
      case USER_ROLES.SHIFT_MANAGER:
      case USER_ROLES.PRODUCTION_MANAGER:
        return 'Manager';
      case USER_ROLES.ENGINEER:
      case USER_ROLES.MAINTENANCE:
        return 'Engineer';
      case USER_ROLES.ADMIN:
        return 'Admin';
      default:
        return 'Auth';
    }
  };

  const currentNavigator = getNavigator();

  return (
    <NavigationContainer>
      <Stack.Navigator
        screenOptions={{
          headerShown: false,
          gestureEnabled: false,
          animationEnabled: true,
        }}
        initialRouteName="Splash"
      >
        <Stack.Screen name="Splash" component={SplashScreen} />
        
        {!isAuthenticated ? (
          <Stack.Screen name="Auth" component={AuthNavigator} />
        ) : (
          <>
            {currentNavigator === 'Operator' && (
              <Stack.Screen name="Operator" component={OperatorNavigator} />
            )}
            {currentNavigator === 'Manager' && (
              <Stack.Screen name="Manager" component={ManagerNavigator} />
            )}
            {currentNavigator === 'Engineer' && (
              <Stack.Screen name="Engineer" component={EngineerNavigator} />
            )}
            {currentNavigator === 'Admin' && (
              <Stack.Screen name="Admin" component={AdminNavigator} />
            )}
          </>
        )}
        
        <Stack.Screen name="Offline" component={OfflineScreen} />
      </Stack.Navigator>
    </NavigationContainer>
  );
};

export default AppNavigator;
